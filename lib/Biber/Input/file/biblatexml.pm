package Biber::Input::file::biblatexml;
use v5.24;
use strict;
use warnings;

use Carp;
use Biber::Annotation;
use Biber::Constants;
use Biber::DataModel;
use Biber::Entries;
use Biber::Entry;
use Biber::Entry::Names;
use Biber::Entry::Name;
use Biber::Sections;
use Biber::Section;
use Biber::Utils;
use Biber::Config;
use Data::Uniqid qw ( suniqid );
use Encode;
use File::Spec;
use File::Slurper;
use File::Temp;
use Log::Log4perl qw(:no_extra_logdie_message);
use List::AllUtils qw( uniq first );
use XML::LibXML;
use XML::LibXML::Simple;
use Data::Dump qw(dump);
use Unicode::Normalize;
use Unicode::GCString;
use URI;

my $logger = Log::Log4perl::get_logger('main');
my $orig_key_order = {};

my $BIBLATEXML_NAMESPACE_URI = 'http://biblatex-biber.sourceforge.net/biblatexml';
my $NS = 'bltx';

# Determine handlers from data model
my $dm = Biber::Config->get_dm;
my $handlers = {
                'CUSTOM' => {'related' => \&_related,
                             'annotation' => \&_annotation},
                'field' => {
                            'default' => {
                                          'code'     => \&_literal,
                                          'date'     => \&_datetime,
                                          'entrykey' => \&_literal,
                                          'integer'  => \&_literal,
                                          'key'      => \&_literal,
                                          'literal'  => \&_literal,
                                          'range'    => \&_range,
                                          'verbatim' => \&_literal,
                                          'uri'      => \&_uri
                                         },
                            'xsv'     => {
                                           'entrykey' => \&_xsv,
                                           'keyword'  => \&_xsv,
                                           'option'   => \&_xsv,
                                         }
                           },
                'list' => {
                           'default' => {
                                         'entrykey' => \&_list,
                                         'key'      => \&_list,
                                         'literal'  => \&_list,
                                         'name'     => \&_name
                                        }
                          }
};

=head2 extract_entries

   Main data extraction routine.
   Accepts a data source identifier (filename in this case),
   preprocesses the file and then looks for the passed keys,
   creating entries when it finds them and passes out an
   array of keys it didn't find.

=cut

sub extract_entries {
  # $encoding is ignored as it is always assumed to be UTF-8 for XML
  my ($filename, $encoding, $keys) = @_;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $bibentries = $section->bibentries;

  my @rkeys = $keys->@*;

  $logger->trace("Entering extract_entries() in driver 'biblatexml'");

  # Check for empty files because they confuse btparse
  unless (check_empty($filename)) { # File is empty
    biber_warn("Data source '$filename' is empty, ignoring");
    return @rkeys;
  }

  # Get a reference to the correct sourcemap sections, if they exist
  my $smaps = [];
  # Maps are applied in order USER->STYLE->DRIVER
  if (defined(Biber::Config->getoption('sourcemap'))) {
    # User maps
    if (my @m = grep {$_->{datatype} eq 'biblatexml' and $_->{level} eq 'user' } @{Biber::Config->getoption('sourcemap')} ) {
      push $smaps->@*, @m;
    }
    # Style maps
    # Allow multiple style maps from multiple \DeclareStyleSourcemap
    if (my @m = grep {$_->{datatype} eq 'biblatexml' and $_->{level} eq 'style' } @{Biber::Config->getoption('sourcemap')} ) {
      push $smaps->@*, @m;
    }
    # Driver default maps
    if (my $m = first {$_->{datatype} eq 'biblatexml' and $_->{level} eq 'driver'} @{Biber::Config->getoption('sourcemap')} ) {
      push $smaps->@*, $m;
    }
  }

  # Log that we found a data file
  $logger->info("Found BibLaTeXML data file '$filename'");

  # Set up XML parser and namespace
  my $xml = slurp_switchr($filename)->$*;
  $xml = NFD($xml);# Unicode NFD boundary
  my $bltxml = XML::LibXML->load_xml(string => $xml);
  my $xpc = XML::LibXML::XPathContext->new($bltxml);
  $xpc->registerNs($NS, $BIBLATEXML_NAMESPACE_URI);

  if ($section->is_allkeys) {
    if ($logger->is_debug()) {# performance tune
      $logger->debug("All citekeys will be used for section '$secnum'");
    }
    # Loop over all entries, creating objects
    foreach my $entry ($xpc->findnodes("/$NS:entries/$NS:entry")) {
      if ($logger->is_debug()) {# performance tune
        $logger->debug('Parsing BibLaTeXML entry object ' . $entry->nodePath);
      }

      # If an entry has no key, ignore it and warn
      unless ($entry->hasAttribute('id')) {
        biber_warn("Invalid or undefined BibLaTeXML entry key in file '$filename', skipping ...");
        next;
      }

      my $key = $entry->getAttribute('id');

      # Check if this key has already been registered as a citekey alias, if
      # so, the key takes priority and we delete the alias
      if ($section->get_citekey_alias($key)) {
        biber_warn("Citekey alias '$key' is also a real entry key, skipping ...");
        $section->get_citekey_alias($key);
      }

      # Any secondary keys?
      # We can't do this with a driver entry for the IDS field as this needs
      # an entry object creating first and the whole point of aliases is that
      # there is no entry object
      foreach my $id ($entry->findnodes("./$NS:ids/$NS:key")) {
        my $idstr = $id->textContent();

        # Skip aliases which are also real entry keys
        if ($section->has_everykey($idstr)) {
          biber_warn("Citekey alias '$idstr' is also a real entry key, skipping ...");
          next;
        }

        # Warn on conflicting aliases
        if (my $otherid = $section->get_citekey_alias($idstr)) {
          if ($otherid ne $key) {
            biber_warn("Citekey alias '$idstr' already has an alias '$otherid', skipping ...");
          }
        }
        else {
          # Since this is allkeys, we are guaranteed that the real entry for the alias
          # will be available
          $section->set_citekey_alias($idstr, $key);
          if ($logger->is_debug()) {# performance tune
            $logger->debug("Citekey '$idstr' is an alias for citekey '$key'");
          }
        }
      }

      # If we've already seen a case variant, warn
      if (my $okey = $section->has_badcasekey($key)) {
        biber_warn("Possible typo (case mismatch): '$key' and '$okey' in file '$filename', skipping '$key' ...");
      }

      # If we've already seen this key, ignore it and warn
      if ($section->has_everykey($key)) {
        biber_warn("Duplicate entry key: '$key' in file '$filename', skipping ...");
        next;
      }
      else {
        $section->add_everykey($key);
      }

      # Record a key->datasource name mapping for error reporting
      $section->set_keytods($key, $filename);

      create_entry($key, $entry, $filename, $smaps, \@rkeys);

      # We do this as otherwise we have no way of determining the origing .bib entry order
      # We need this in order to do sorting=none + allkeys because in this case, there is no
      # "citeorder" because nothing is explicitly cited and so "citeorder" means .bib order
      push @{$orig_key_order->{$filename}}, $key;

    }

    # if allkeys, push all bibdata keys into citekeys (if they are not already there)
    # We are using the special "orig_key_order" array which is used to deal with the
    # situation when sorting=none and allkeys is set. We need an array rather than the
    # keys from the bibentries hash because we need to preserver the original order of
    # the .bib as in this case the sorting sub "citeorder" means "bib order" as there are
    # no explicitly cited keys
    $section->add_citekeys(@{$orig_key_order->{$filename}});
    if ($logger->is_debug()) {# performance tune
      $logger->debug("Added all citekeys to section '$secnum': " . join(', ', $section->get_citekeys));
    }
  }
  else {
    # loop over all keys we're looking for and create objects
    if ($logger->is_debug()) {# performance tune
      $logger->debug('Wanted keys: ' . join(', ', $keys->@*));
    }
    foreach my $wanted_key ($keys->@*) {

      if ($logger->is_debug()) {# performance tune
        $logger->debug("Looking for key '$wanted_key' in BibLaTeXML file '$filename'");
      }
      if (my @entries = $xpc->findnodes("/$NS:entries/$NS:entry[\@id='$wanted_key']")) {
        # Check to see if there is more than one entry with this key and warn if so
        if ($#entries > 0) {
          biber_warn("Found more than one entry for key '$wanted_key' in '$filename': " .
                       join(',', map {$_->getAttribute('id')} @entries) . ' - skipping duplicates ...');
        }
        my $entry = $entries[0];

        if ($logger->is_debug()) {# performance tune
          $logger->debug("Found key '$wanted_key' in BibLaTeXML file '$filename'");
          $logger->debug('Parsing BibLaTeXML entry object ' . $entry->nodePath);
        }
        # See comment above about the importance of the case of the key
        # passed to create_entry()
        # Skip creation if it's already been done, for example, via a citekey alias
        unless ($section->bibentries->entry_exists($wanted_key)) {

          # Record a key->datasource name mapping for error reporting
          $section->set_keytods($wanted_key, $filename);

          create_entry($wanted_key, $entry, $filename, $smaps, \@rkeys);
        }
        # found a key, remove it from the list of keys we want
        @rkeys = grep {$wanted_key ne $_} @rkeys;
      }
      elsif ($xpc->findnodes("/$NS:entries/$NS:entry/$NS:id[text()='$wanted_key']")) {
        my $key = $xpc->findnodes("/$NS:entries/$NS:entry/\@id");
        if ($logger->is_debug()) {# performance tune
          $logger->debug("Citekey '$wanted_key' is an alias for citekey '$key'");
        }
        $section->set_citekey_alias($wanted_key, $key);

        # Make sure there is a real, cited entry for the citekey alias
        # just in case only the alias is cited
        unless ($section->bibentries->entry_exists($key)) {
          my $entry = $xpc->findnodes("/$NS:entries/$NS:entry/[\@id='$key']");

          # Record a key->datasource name mapping for error reporting
          $section->set_keytods($key, $filename);

          create_entry($key, $entry, $filename, $smaps, \@rkeys);
          $section->add_citekeys($key);
        }

        # found a key, remove it from the list of keys we want
        @rkeys = grep {$wanted_key ne $_} @rkeys;
      }
      if ($logger->is_debug()) {# performance tune
        $logger->debug('Wanted keys now: ' . join(', ', @rkeys));
      }
    }
  }

  return @rkeys;
}


=head2 create_entry

   Create a Biber::Entry object from an entry found in a biblatexml data source

=cut

sub create_entry {
  my ($key, $entry, $datasource, $smaps, $rkeys) = @_;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);

  my $dm = Biber::Config->get_dm;
  my $bibentries = $section->bibentries;

  my %newentries; # In case we create a new entry in a map

  # Datasource mapping applied in $smap order (USER->STYLE->DRIVER)
  foreach my $smap ($smaps->@*) {
    $smap->{map_overwrite} = $smap->{map_overwrite} // 0; # default
    my $level = $smap->{level};

  MAP:    foreach my $map (@{$smap->{map}}) {

      # Skip if this map element specifies a particular refsection and it is not this one
      if (exists($map->{refsection})) {
        next unless $secnum == $map->{refsection};
      }

      # defaults to the entrytype unless changed below
      my $last_type = $entry->getAttribute('entrytype');
      my $last_field = undef;
      my $last_fieldval = undef;
      my $cnerror;

      my @imatches; # For persisting parenthetical matches over several steps

      # Check pertype restrictions
      # Logic is "-(-P v Q)" which is equivalent to "P & -Q" but -Q is an array check so
      # messier to write than Q
      unless (not exists($map->{per_type}) or
              first {lc($_->{content}) eq $entry->type} @{$map->{per_type}}) {
        next;
      }

      # Check negated pertype restrictions
      if (exists($map->{per_nottype}) and
          first {lc($_->{content}) eq $entry->getAttribute('entrytype')} @{$map->{per_nottype}}) {
        next;
      }

      # Check per_datasource restrictions
      # Don't compare case insensitively - this might not be correct
      # Logic is "-(-P v Q)" which is equivalent to "P & -Q" but -Q is an array check so
      # messier to write than Q
      unless (not exists($map->{per_datasource}) or
              first {$_->{content} eq $datasource} @{$map->{per_datasource}}) {
        next;
      }

      # Set up any mapping foreach loop
      my @maploop = ('');
      if (my $foreach = $map->{map_foreach}) {
        # just a field name, make it XPATH
        if ($foreach !~ m|/|) {
          $foreach = "./bltx:$foreach";
        }

        if (my $felist = $entry->findnodes($foreach)) {
          @maploop = split(/\s*,\s*/, $felist);
        }
      }

      foreach my $maploop (@maploop) {
        my $MAPUNIQVAL;
        # loop over mapping steps
        foreach my $step (@{$map->{map_step}}) {

          # entry deletion. Really only useful with allkeys or tool mode
          if ($step->{map_entry_null}) {
            if ($logger->is_debug()) {# performance tune
              $logger->debug("Source mapping (type=$level, key=$key): Ignoring entry completely");
            }
            return 0;           # don't create an entry at all
          }

          # new entry
          if (my $newkey = maploopreplace($step->{map_entry_new}, $maploop)) {
            my $newentrytype;
            unless ($newentrytype = maploopreplace($step->{map_entry_newtype}, $maploop)) {
              biber_warn("Source mapping (type=$level, key=$key): Missing type for new entry '$newkey', skipping step ...");
              next;
            }
            if ($logger->is_debug()) {# performance tune
              $logger->debug("Source mapping (type=$level, key=$key): Creating new entry with key '$newkey'");
            }
            my $newentry = XML::LibXML::Element->new("$NS:entry");
            $newentry->setAttribute('id', NFC($newkey));
            $newentry->setAttribute('entrytype', NFC($newentrytype));

            # found a new entry key, remove it from the list of keys we want since we
            # have "found" it by creating it
            $rkeys->@* = grep {$newkey ne $_} $rkeys->@*;

            # for allkeys sections initially
            if ($section->is_allkeys) {
              $section->add_citekeys($newkey);
            }
            $newentries{$newkey} = $newentry;
          }

          # entry clone
          if (my $prefix = maploopreplace($step->{map_entry_clone}, $maploop)) {
            if ($logger->is_debug()) {# performance tune
              $logger->debug("Source mapping (type=$level, key=$key): cloning entry with prefix '$prefix'");
            }
            # Create entry with no sourcemapping to avoid recursion
            create_entry("$prefix$key", $entry);

            # found a prefix clone key, remove it from the list of keys we want since we
            # have "found" it by creating it along with its clone parent
            $rkeys->@* = grep {"$prefix$key" ne $_} $rkeys->@*;
            # Need to add the clone key to the section if allkeys is set since all keys are cleared
            # for allkeys sections initially
            if ($section->is_allkeys) {
              $section->add_citekeys("$prefix$key");
            }
          }

          # An entry created by map_entry_new previously can be the target for field setting
          # options
          # A newly created entry as target of operations doesn't make sense in all situations
          # so it's limited to being the target for field sets
          my $etarget;
          my $etargetkey;
          if ($etargetkey = maploopreplace($step->{map_entrytarget}, $maploop)) {
            unless ($etarget = $newentries{$etargetkey}) {
              biber_warn("Source mapping (type=$level, key=$key): Dynamically created entry target '$etargetkey' does not exist skipping step ...");
              next;
            }
          }
          else {             # default is that we operate on the same entry
            $etarget = $entry;
            $etargetkey = $key;
          }

          # Entrytype map
          if (my $typesource = maploopreplace($step->{map_type_source}, $maploop)) {
            $typesource = lc($typesource);
            unless ($etarget->getAttribute('entrytype') eq $typesource) {
              # Skip the rest of the map if this step doesn't match and match is final
              if ($step->{map_final}) {
                if ($logger->is_debug()) {# performance tune
                  $logger->debug("Source mapping (type=$level, key=$etargetkey): Entry type is '" . $etarget->getAttribute('entrytype') . "' but map wants '$typesource' and step has 'final' set, skipping rest of map ...");
                }
                next MAP;
              }
              else {
                # just ignore this step
                if ($logger->is_debug()) {# performance tune
                  $logger->debug("Source mapping (type=$level, key=$etargetkey): Entry type is '" . $etarget->getAttribute('entrytype') . "' but map wants '$typesource', skipping step ...");
                }
                next;
              }
            }
            # Change entrytype if requested
            $last_type = $etarget->getAttribute('entrytype');
            my $t = lc(maploopreplace($step->{map_type_target}, $maploop));
            if ($logger->is_debug()) {# performance tune
              $logger->debug("Source mapping (type=$level, key=$etargetkey): Changing entry type from '$last_type' to $t");
            }
            $etarget->setAttribute('entrytype', NFC($t));
          }

          my $fieldcontinue = 0;
          my $xp_nfieldsource_s;
          my $xp_nfieldsource;
          my $xp_fieldsource_s;
          my $xp_fieldsource;
          # Negated source field map
          if ($xp_nfieldsource_s = _getpath(maploopreplace($step->{map_notfield}, $maploop))) {
            $xp_nfieldsource = XML::LibXML::XPathExpression->new($xp_nfieldsource_s);

            if ($etarget->exists($xp_nfieldsource)) {
              if ($step->{map_final}) {
                if ($logger->is_debug()) {# performance tune
                  $logger->debug("Source mapping (type=$level, key=$etargetkey): Field xpath '$xp_nfieldsource_s' exists and step has 'final' set, skipping rest of map ...");
                }
                next MAP;
              }
              else {
                # just ignore this step
                if ($logger->is_debug()) {# performance tune
                  $logger->debug("Source mapping (type=$level, key=$etargetkey): Field xpath '$xp_nfieldsource_s' exists, skipping step ...");
                }
                next;
              }
            }
            $fieldcontinue = 1;
          }

          # \cite{key}   -> is_cite(key)=true, is_specificcitekey(key)=true
          # \nocite{key} -> is_nocite(key)=true, is_specificcitekey(key)=true
          # \nocite{*}   -> is_allkeys_nocite=true
          # Check entry cited/nocited verbs

          # \cite{key} or \nocite{key}
          if ($step->{map_entrykey_citedornocited}) {
            if (not $section->is_specificcitekey($key)) { # check if NOT \cited{} and NOT \nocited{}
              if ($step->{map_final}) {
                if ($logger->is_debug()) { # performance tune
                  $logger->debug("Source mapping (type=$level, key=$key): Key is neither \\cited nor \\nocited and step has 'final' set, skipping rest of map ...");
                }
                next MAP;
              }
              else {
                # just ignore this step
                if ($logger->is_debug()) { # performance tune
                  $logger->debug("Source mapping (type=$level, key=$key): Key is neither \\cited nor \\nocited, skipping step ...");
                }
                next;
              }
            }
          }

          # \cite{key}
          if ($step->{map_entrykey_cited}) {
            if (not $section->is_cite($key)) { # check if NOT cited
              if ($step->{map_final}) {
                if ($logger->is_debug()) { # performance tune
                  $logger->debug("Source mapping (type=$level, key=$key): Key is not explicitly \\cited and step has 'final' set, skipping rest of map ...");
                }
                next MAP;
              }
              else {
                # just ignore this step
                if ($logger->is_debug()) { # performance tune
                  $logger->debug("Source mapping (type=$level, key=$key): Key is not explicitly \\cited, skipping step ...");
                }
                next;
              }
            }
          }

          # \nocite{key}
          if ($step->{map_entrykey_nocited}) {
            # If cited, don't want to do the allkeys_nocite check as this overrides
            if ($section->is_cite($key) or
                (not $section->is_nocite($key) and not $section->is_allkeys_nocite)) { # check if NOT nocited
              if ($step->{map_final}) {
                if ($logger->is_debug()) { # performance tune
                  $logger->debug("Source mapping (type=$level, key=$key): Key is not \\nocited and step has 'final' set, skipping rest of map ...");
                }
                next MAP;
              }
              else {
                # just ignore this step
                if ($logger->is_debug()) { # performance tune
                  $logger->debug("Source mapping (type=$level, key=$key): Key is not \\nocited, skipping step ...");
                }
                next;
              }
            }
          }

          # \nocite{key} or \nocite{*}
          if ($step->{map_entrykey_allnocited}) {
            if (not $section->is_allkeys_nocite) { # check if NOT allnoncited
              if ($step->{map_final}) {
                if ($logger->is_debug()) { # performance tune
                  $logger->debug("Source mapping (type=$level, key=$key): Key is not \\nocite{*}'ed and step has 'final' set, skipping rest of map ...");
                }
                next MAP;
              }
              else {
                # just ignore this step
                if ($logger->is_debug()) { # performance tune
                  $logger->debug("Source mapping (type=$level, key=$key): Key is not \\nocite{*}'ed, skipping step ...");
                }
                next;
              }
            }
          }

          # \nocite{*}
          if ($step->{map_entrykey_starnocited}) {
            if ($section->is_allkeys_nocite and ($section->is_cite($key) or $section->is_nocite($key))) { # check if NOT nocited
              if ($step->{map_final}) {
                if ($logger->is_debug()) { # performance tune
                  $logger->debug("Source mapping (type=$level, key=$key): Key is \\nocite{*}'ed but also either \\cite'd or explicitly \\nocited and step has 'final' set, skipping rest of map ...");
                }
                next MAP;
              }
              else {
                # just ignore this step
                if ($logger->is_debug()) { # performance tune
                  $logger->debug("Source mapping (type=$level, key=$key): Key is \\nocite{*}'ed but also either \\cite'd or explicitly \\nocited, skipping step ...");
                }
                next;
              }
            }
          }

          # Field map
          if ($xp_fieldsource_s = _getpath(maploopreplace($step->{map_field_source}, $maploop))) {
            $xp_fieldsource = XML::LibXML::XPathExpression->new($xp_fieldsource_s);

            # key is a pseudo-field. It's guaranteed to exist so
            # just check if that's what's being asked for
            unless ($etarget->exists($xp_fieldsource)) {
              # Skip the rest of the map if this step doesn't match and match is final
              if ($step->{map_final}) {
                if ($logger->is_debug()) {# performance tune
                  $logger->debug("Source mapping (type=$level, key=$etargetkey): No field xpath '$xp_fieldsource_s' and step has 'final' set, skipping rest of map ...");
                }
                next MAP;
              }
              else {
                # just ignore this step
                if ($logger->is_debug()) {# performance tune
                  $logger->debug("Source mapping (type=$level, key=$etargetkey): No field xpath '$xp_fieldsource_s', skipping step ...");
                }
                next;
              }
            }
            $fieldcontinue = 1;
          }

          if ($fieldcontinue) {
            $last_field = $etarget->findnodes($xp_fieldsource)->get_node(1)->nodeName;
            $last_fieldval = $etarget->findvalue($xp_fieldsource);

            my $negmatch = 0;
            # Negated matches are a normal match with a special flag
            if (my $nm = $step->{map_notmatch}) {
              $step->{map_match} = $nm;
              $negmatch = 1;
            }

            my $caseinsensitive = 0;
            my $mi;
            # Case insensitive matches are a normal match with a special flag
            if ($mi = $step->{map_matchi} or $mi = $step->{map_notmatchi}) {
              $step->{map_match} = $mi;
              $caseinsensitive = 1;
            }

            my $caseinsensitives = 0;
            my $mis;
            # Case insensitive matches are normal matches with a special flag
            if ($mis = $step->{map_matchesi}) {
              $step->{map_matches} = $mis;
              $caseinsensitives = 1;
            }

            if (my $ms = $step->{map_matches}) {
              my @ms = split(/\s*,\s*/,$ms);
              my @rs = split(/\s*,\s*/,$step->{map_replace});
              unless (scalar(@ms) == scalar(@rs)) {
                $logger->debug("Source mapping (type=$level, key=$etargetkey): Different number of fixed matches vs replaces, skipping ...");
                next;
              }
              for (my $i = 0; $i <= $#ms; $i++) {
                if (($caseinsensitives and fc($last_fieldval) eq fc($ms[$i]))
                    or ($last_fieldval eq $ms[$i])) {
                  $etarget->set(encode('UTF-8', NFC($xp_fieldsource_s)), $rs[$i]);
                }
              }
            }

            # map fields to targets
            if (my $m = maploopreplace($step->{map_match}, $maploop)) {
              if (defined($step->{map_replace})) { # replace can be null

                # Can't modify entrykey
                if (lc($xp_fieldsource_s) eq './@id') {
                if ($logger->is_debug()) {# performance tune
                  $logger->debug("Source mapping (type=$level, key=$etargetkey): Field xpath '$xp_fieldsource_s' is entrykey- cannot remap the value of this field, skipping ...");
                }
                next;
                }

                my $r = maploopreplace($step->{map_replace}, $maploop);
                if ($logger->is_debug()) {# performance tune
                  $logger->debug("Source mapping (type=$level, key=$etargetkey): Doing match/replace '$m' -> '$r' on field xpath '$xp_fieldsource_s'");
                }

                unless (_changenode($etarget, $xp_fieldsource_s, ireplace($last_fieldval, $m, $r, $caseinsensitive)), \$cnerror) {
                  biber_warn("Source mapping (type=$level, key=$etargetkey): $cnerror");
                }
              }
              else {
                # Now re-instate any unescaped $1 .. $9 to get round these being
                # dynamically scoped and being null when we get here from any
                # previous map_match
                # Be aware that imatch() uses m//g so @imatches can have multiple paren group
                # captures which might be useful
                $m =~ s/(?<!\\)\$(\d)/$imatches[$1-1]/ge;
                unless (@imatches = imatch($last_fieldval, $m, $negmatch)) {
                  # Skip the rest of the map if this step doesn't match and match is final
                  if ($step->{map_final}) {
                    if ($logger->is_debug()) {# performance tune
                      $logger->debug("Source mapping (type=$level, key=$etargetkey): Field xpath '$xp_fieldsource_s' does not match '$m' and step has 'final' set, skipping rest of map ...");
                    }
                    next MAP;
                  }
                  else {
                    # just ignore this step
                    if ($logger->is_debug()) {# performance tune
                      $logger->debug("Source mapping (type=$level, key=$etargetkey): Field xpath '$xp_fieldsource_s' does not match '$m', skipping step ...");
                    }
                    next;
                  }
                }
              }
            }

            # Set to a different target if there is one
            if (my $xp_target_s = _getpath(maploopreplace($step->{map_field_target}, $maploop))) {
              my $xp_target = XML::LibXML::XPathExpression->new($xp_target_s);

              # Can't remap entry key pseudo-field
              if (lc($xp_target_s) eq './@id') {
                if ($logger->is_debug()) {# performance tune
                  $logger->debug("Source mapping (type=$level, key=$etargetkey): Field xpath '$xp_fieldsource_s' is entrykey - cannot map this to a new field as you must have an entrykey, skipping ...");
                }
                next;
              }

            if ($etarget->exists($xp_target)) {
                if ($map->{map_overwrite} // $smap->{map_overwrite}) {
                  if ($logger->is_debug()) {# performance tune
                    $logger->debug("Source mapping (type=$level, key=$etargetkey): Overwriting existing field xpath '$xp_target_s'");
                  }
                }
                else {
                  if ($logger->is_debug()) {# performance tune
                    $logger->debug("Source mapping (type=$level, key=$etargetkey): Field xpath '$xp_fieldsource_s' is mapped to field xpath '$xp_target_s' but both are defined, skipping ...");
                  }
                  next;
                }
              }
              unless (_changenode($etarget, $xp_target_s, $xp_fieldsource_s, \$cnerror)) {
                biber_warn("Source mapping (type=$level, key=$key): $cnerror");
              }
              $etarget->findnodes($xp_fieldsource)->get_node(1)->unbindNode();
            }
          }

          # field changes
          if (my $xp_node_s = _getpath(maploopreplace($step->{map_field_set}, $maploop))) {
            my $xp_node = XML::LibXML::XPathExpression->new($xp_node_s);

            # Deal with special tokens
            if ($step->{map_null}) {
              if ($logger->is_debug()) {# performance tune
                $logger->debug("Source mapping (type=$level, key=$etargetkey): Deleting field xpath '$xp_node_s'");
              }
              $etarget->findnodes($xp_node)->get_node(1)->unbindNode();
            }
            else {
              if ($etarget->exists($xp_node)) {
                unless ($map->{map_overwrite} // $smap->{map_overwrite}) {
                  if ($step->{map_final}) {
                    # map_final is set, ignore and skip rest of step
                    if ($logger->is_debug()) {# performance tune
                      $logger->debug("Source mapping (type=$level, key=$etargetkey): Field xpath '$xp_node_s' exists, overwrite is not set and step has 'final' set, skipping rest of map ...");
                    }
                    next MAP;
                  }
                  else {
                    # just ignore this step
                    if ($logger->is_debug()) {# performance tune
                      $logger->debug("Source mapping (type=$level, key=$etargetkey): Field xpath '$xp_node_s' exists and overwrite is not set, skipping step ...");
                    }
                    next;
                  }
                }
              }

              my $orig = '';
              # If append or appendstrict is set, keep the original value
              # and append the new.
              if ($step->{map_append} or $step->{map_appendstrict}) {
                $orig = $etarget->findvalue($xp_node) || '';
              }

              if ($step->{map_origentrytype}) {
                next unless $last_type;
                if ($logger->is_debug()) {# performance tune
                  $logger->debug("Source mapping (type=$level, key=$etargetkey): Setting xpath '$xp_node_s' to '${orig}${last_type}'");
                }

                unless (_changenode($etarget, $xp_node_s, appendstrict_check($step, $orig, $last_type), \$cnerror)) {
                  biber_warn("Source mapping (type=$level, key=$key): $cnerror");
                }
              }
              elsif ($step->{map_origfieldval}) {
                next unless $last_fieldval;
                if ($logger->is_debug()) {# performance tune
                  $logger->debug("Source mapping (type=$level, key=$etargetkey): Setting field xpath '$xp_node_s' to '${orig}${last_fieldval}'");
                }
                unless (_changenode($etarget, $xp_node_s, appendstrict_check($step, $orig, $last_fieldval), \$cnerror)) {
                  biber_warn("Source mapping (type=$level, key=$etargetkey): $cnerror");
                }
              }
              elsif ($step->{map_origfield}) {
                next unless $last_field;
                if ($logger->is_debug()) {# performance tune
                  $logger->debug("Source mapping (type=$level, key=$etargetkey): Setting field xpath '$xp_node_s' to '${orig}${last_field}'");
                }
                unless (_changenode($etarget, $xp_node_s, appendstrict_check($step, $orig, $last_field), \$cnerror)) {
                  biber_warn("Source mapping (type=$level, key=$etargetkey): $cnerror");
                }
              }
              else {
                my $fv = maploopreplace($step->{map_field_value}, $maploop);
                # Now re-instate any unescaped $1 .. $9 to get round these being
                # dynamically scoped and being null when we get here from any
                # previous map_match
                $fv =~ s/(?<!\\)\$(\d)/$imatches[$1-1]/ge;
                if ($logger->is_debug()) {# performance tune
                  $logger->debug("Source mapping (type=$level, key=$etargetkey): Setting field xpath '$xp_node_s' to '${orig}${fv}'");
                }
                unless (_changenode($etarget, $xp_node_s, appendstrict_check($step, $orig, $fv), \$cnerror)) {
                  biber_warn("Source mapping (type=$level, key=$key): $cnerror");
                }
              }
            }
          }
        }
      }
    }
  }

  # Need to also instantiate fields in any new entries created by map
  foreach my $e ($entry, values %newentries) {
    next unless $e;             # newentry might be undef

    my $bibentry = new Biber::Entry;
    my $k = $e->getAttribute('id');
    $bibentry->set_field('citekey', $k);
    if ($logger->is_debug()) {# performance tune
      $logger->debug("Creating entry with key '$k'");
    }

    $bibentry->set_field('entrytype', $e->getAttribute('entrytype'));

    # We put all the fields we find modulo field aliases into the object.
    # Validation happens later and is not datasource dependent
    foreach my $f (uniq map { if (_norm($_->nodeName) eq 'names') { $_->getAttribute('type') }
                              else { $_->nodeName()} }  $e->findnodes('*')) {

      # We have to process local options as early as possible in order
      # to make them available for things that need them like name parsing
      if (_norm($f) eq 'options') {
        if (my $node = $entry->findnodes("./$NS:options")->get_node(1)) {
          process_entry_options($k, [ split(/\s*,\s*/, $node->textContent()) ], $secnum);
        }
      }

      # Now run any defined handler
      if ($dm->is_field(_norm($f))) {
        my $handler = _get_handler($f);
        $handler->($bibentry, $e, $f, $k);
      }
    }

    $bibentry->set_field('datatype', 'biblatexml');
    $bibentries->add_entry($k, $bibentry);
  }
  return;
}

# Annotations are special - there is a literal field and also more complex annotations
sub _annotation {
  my ($bibentry, $entry, $f, $key) = @_;
  foreach my $node ($entry->findnodes("./$f")) {
    my $field = $node->getAttribute('field');
    my $name = $node->getAttribute('name') || 'default';
    my $literal = $node->getAttribute('literal') || '0';
    my $ann = $node->textContent();
    my $item = $node->getAttribute('item');
    my $part = $node->getAttribute('part');
    if ($field) {# Complex metadata annotation for another field
      if ($part) {
        Biber::Annotation->set_annotation('part', $key, $field, $name, $ann, $literal, $item, $part);
      }
      elsif ($item) {
        Biber::Annotation->set_annotation('item', $key, $field, $name, $ann, $literal, $item);
      }
      else {
        Biber::Annotation->set_annotation('field', $key, $field, $name, $ann, $literal);
      }
    }
    else {# Generic entry annotation
      $bibentry->set_datafield(_norm($f), $node->textContent());
    }
  }
  return;
}

# Related entries
sub _related {
  my ($bibentry, $entry, $f, $key) = @_;
  my $Srx = Biber::Config->getoption('xsvsep');
  my $S = qr/$Srx/;
  my $node = $entry->findnodes("./$f")->get_node(1);
  foreach my $item ($node->findnodes("./$NS:list/$NS:item")) {
    $bibentry->set_datafield('related', [ split(/$S/, $item->getAttribute('ids')) ]);
    $bibentry->set_datafield('relatedtype', $item->getAttribute('type'));
    if (my $string = $item->getAttribute('string')) {
      $bibentry->set_datafield('relatedstring', $string);
    }
    if (my $string = $item->getAttribute('options')) {
      $bibentry->set_datafield('relatedoptions',
                               [ split(/$S/, $item->getAttribute('relatedoptions')) ]);
    }
  }
  return;
}

# literal fields
sub _literal {
  my ($bibentry, $entry, $f, $key) = @_;
  my $node = $entry->findnodes("./$f")->get_node(1);
  my $setval = $node->textContent();
  my $xdmi = Biber::Config->getoption('xdatamarker');
  my $xnsi = Biber::Config->getoption('xnamesep');

  # XDATA is special, if found, set it
  if (my $xdatav = $node->getAttribute('xdata')) {
    $xdatav = "$xdmi$xnsi$xdatav"; # normalise to same as bibtex input
    $bibentry->add_xdata_ref(_norm($f), $xdatav);
    $setval = $xdatav;
  }

  # eprint is special case
  if ($f eq "$NS:eprint") {
    $bibentry->set_datafield('eprinttype', $node->getAttribute('type'));
    if (my $ec = $node->getAttribute('class')) {
      $bibentry->set_datafield('eprintclass', $ec);
    }
  }
  else {
    $bibentry->set_datafield(_norm($f), $setval);
  }

  return;
}

# xSV field
sub _xsv {
  my ($bibentry, $entry, $f, $key) = @_;
  my $node = $entry->findnodes("./$f")->get_node(1);

  # XDATA is special
  if (fc(_norm($f)) eq 'xdata') {
    # Just split with no XDATA setting on list items
    my $value = _split_list($bibentry, $node, $key, $f, 1);
    $bibentry->add_xdata_ref('xdata', $value);
    $bibentry->set_datafield(_norm($f), $value);
  }
  else {
    $bibentry->set_datafield(_norm($f), _split_list($bibentry, $node, $key, $f));
  }

  return;
}


# uri fields
sub _uri {
  my ($bibentry, $entry, $f, $key) = @_;
  my $node = $entry->findnodes("./$f")->get_node(1);
  my $setval = $node->textContent();
  my $xdmi = Biber::Config->getoption('xdatamarker');
  my $xnsi = Biber::Config->getoption('xnamesep');

  # XDATA is special, if found, set it
  if (my $xdatav = $node->getAttribute('xdata')) {
    $xdatav = "$xdmi$xnsi$xdatav"; # normalise to same as bibtex input
    $bibentry->add_xdata_ref(_norm($f), $xdatav);
    $setval = $xdatav;
  }
  else {
    # URL escape if it doesn't look like it already is
    # This is useful if we are generating URLs automatically with maps which may
    # contain UTF-8 from other fields
    unless ($setval =~ /\%/) {
      $setval = URI->new($setval)->as_string;
    }
  }

  $bibentry->set_datafield(_norm($f), $setval);

  return;
}


# List fields
sub _list {
  my ($bibentry, $entry, $f, $key) = @_;
  my $node = $entry->findnodes("./$f")->get_node(1);

  $bibentry->set_datafield(_norm($f), _split_list($bibentry, $node, $key, $f));

  return;
}

# Range fields
sub _range {
  my ($bibentry, $entry, $f, $key) = @_;
  my $node = $entry->findnodes("./$f")->get_node(1);
  my $xdmi = Biber::Config->getoption('xdatamarker');
  my $xnsi = Biber::Config->getoption('xnamesep');

  # XDATA is special, if found, set it
  if (my $xdatav = $node->getAttribute('xdata')) {
    $xdatav = "$xdmi$xnsi$xdatav"; # normalise to same as bibtex input
    $bibentry->add_xdata_ref(_norm($f), $xdatav);
    $bibentry->set_datafield(_norm($f), [$xdatav]);
    return;
  }

  # List of ranges/values
  if (my @rangelist = $node->findnodes("./$NS:list/$NS:item")) {
    my $rl;
    foreach my $range (@rangelist) {
      push $rl->@*, _parse_range_list($range);
    }
    $bibentry->set_datafield(_norm($f), $rl);
  }

  return;
}

# Date fields
# NOTE - the biblatex options controlling era, approximate and uncertain meta-information
# output are in the .bcf but biber does not used them as it always outputs this information
sub _datetime {
  my ($bibentry, $entry, $f, $key) = @_;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $ds = $section->get_keytods($key);
  my $bee = $bibentry->get_field('entrytype');

  foreach my $node ($entry->findnodes("./$f")) {

    my $datetype = $node->getAttribute('type') // '';

    $bibentry->set_field("${datetype}datesplit", 1);

    if (my $start = $node->findnodes("./$NS:start")) { # Date range
      my $end = $node->findnodes("./$NS:end");

      # Start of range
      # Using high-level range parsing sub in order to get unspec
      if (my ($sdate, undef, undef, $unspec) = parse_date_range($bibentry,
                                                                $datetype,
                                                                $start->get_node(1)->textContent())) {

        # Save julian
        $bibentry->set_field($datetype . 'datejulian', 1) if $CONFIG_DATE_PARSERS{start}->julian;
        # Save approximate information
        $bibentry->set_field($datetype . 'dateapproximate', 1) if $CONFIG_DATE_PARSERS{start}->approximate;

        # Save uncertain date information
        $bibentry->set_field($datetype . 'dateuncertain', 1) if $CONFIG_DATE_PARSERS{start}->uncertain;

        # Date had ISO8601-2 unspecified format
        # This does not differ for *enddate components as these are split into ranges
        # from non-ranges only
        if ($unspec) {
          $bibentry->set_field($datetype . 'dateunspecified', $unspec);
        }

        unless ($CONFIG_DATE_PARSERS{start}->missing('year')) {
          $bibentry->set_datafield($datetype . 'year', $sdate->year);
          # Save era date information
          $bibentry->set_field($datetype . 'era', lc($sdate->secular_era));
        }

        $bibentry->set_datafield($datetype . 'month', $sdate->month)
          unless $CONFIG_DATE_PARSERS{start}->missing('month');

        $bibentry->set_datafield($datetype . 'day', $sdate->day)
          unless $CONFIG_DATE_PARSERS{start}->missing('day');

        # Save start yeardivision date information
        if (my $yeardivision = $CONFIG_DATE_PARSERS{start}->yeardivision) {
          $bibentry->set_field($datetype . 'yeardivision', $yeardivision);
        }

        # must be an hour if there is a time but could be 00 so use defined()
        unless ($CONFIG_DATE_PARSERS{start}->missing('time')) {
          $bibentry->set_datafield($datetype . 'hour', $sdate->hour);
          $bibentry->set_datafield($datetype . 'minute', $sdate->minute);
          $bibentry->set_datafield($datetype . 'second', $sdate->second);
          unless ($sdate->time_zone->is_floating) { # ignore floating timezones
            $bibentry->set_datafield($datetype . 'timezone', tzformat($sdate->time_zone->name));
          }
        }
      }
      else {
        biber_warn("Datamodel: $bee entry '$key' ($ds): Invalid format '" . $start->get_node(1)->textContent() . "' of date field '$f' range start - ignoring", $bibentry);
      }

      # End of range
      my $edate = parse_date_end($end->get_node(1)->textContent());
      if (defined($edate)) { # no parse error
        if ($edate) { # not an empty range

          # Save julian
          $bibentry->set_field($datetype . 'enddatejulian', 1) if $CONFIG_DATE_PARSERS{end}->julian;

          # Save approximate information
          $bibentry->set_field($datetype . 'enddateapproximate', 1) if $CONFIG_DATE_PARSERS{end}->approximate;

          # Save uncertain date information
          $bibentry->set_field($datetype . 'enddateuncertain', 1) if $CONFIG_DATE_PARSERS{end}->uncertain;

          unless ($CONFIG_DATE_PARSERS{end}->missing('year')) {
            $bibentry->set_datafield($datetype . 'endyear', $edate->year);
            # Save era date information
            $bibentry->set_field($datetype . 'endera', lc($edate->secular_era));
          }

          $bibentry->set_datafield($datetype . 'endmonth', $edate->month)
            unless $CONFIG_DATE_PARSERS{end}->missing('month');

          $bibentry->set_datafield($datetype . 'endday', $edate->day)
            unless $CONFIG_DATE_PARSERS{end}->missing('day');

          # Save end yeardivision date information
          if (my $yeardivision = $CONFIG_DATE_PARSERS{end}->yeardivision) {
            $bibentry->set_field($datetype . 'endyeardivision', $yeardivision);
          }

          # must be an hour if there is a time but could be 00 so use defined()
          unless ($CONFIG_DATE_PARSERS{end}->missing('time')) {
            $bibentry->set_datafield($datetype . 'endhour', $edate->hour);
            $bibentry->set_datafield($datetype . 'endminute', $edate->minute);
            $bibentry->set_datafield($datetype . 'endsecond', $edate->second);
            unless ($edate->time_zone->is_floating) { # ignore floating timezones
              $bibentry->set_datafield($datetype . 'endtimezone', tzformat($edate->time_zone->name));
            }
          }
        }
        else { # open ended range - edate is defined but empty
          $bibentry->set_datafield($datetype . 'endyear', '');
        }
      }
      else {
        biber_warn("$bee entry '$key' ($ds): Invalid format '" . $end->get_node(1)->textContent() . "' of date field '$f' range end - ignoring", $bibentry);
      }
    }
    else { # Simple date
      # Using high-level range parsing sub in order to get unspec
      if (my ($sdate, undef, undef, $unspec) = parse_date_range($bibentry,
                                                                $datetype,
                                                                $node->textContent())) {

        # Save julian
        $bibentry->set_field($datetype . 'datejulian', 1) if $CONFIG_DATE_PARSERS{start}->julian;
        # Save approximate information
        $bibentry->set_field($datetype . 'dateapproximate', 1) if $CONFIG_DATE_PARSERS{start}->approximate;

        # Save uncertain date information
        $bibentry->set_field($datetype . 'dateuncertain', 1) if $CONFIG_DATE_PARSERS{start}->uncertain;

        # Date had ISO8601-2 unspecified format
        # This does not differ for *enddate components as these are split into ranges
        # from non-ranges only
        if ($unspec) {
          $bibentry->set_field($datetype . 'dateunspecified', $unspec);
        }

        unless ($CONFIG_DATE_PARSERS{start}->missing('year')) {
          $bibentry->set_datafield($datetype . 'year', $sdate->year);
          # Save era date information
          $bibentry->set_field($datetype . 'era', lc($sdate->secular_era));
        }

        $bibentry->set_datafield($datetype . 'month', $sdate->month)
          unless $CONFIG_DATE_PARSERS{start}->missing('month');

        $bibentry->set_datafield($datetype . 'day', $sdate->day)
          unless $CONFIG_DATE_PARSERS{start}->missing('day');

        # Save start yeardivision date information
        if (my $yeardivision = $CONFIG_DATE_PARSERS{start}->yeardivision) {
          $bibentry->set_field($datetype . 'yeardivision', $yeardivision);
        }

        # must be an hour if there is a time but could be 00 so use defined()
        unless ($CONFIG_DATE_PARSERS{start}->missing('time')) {
          $bibentry->set_datafield($datetype . 'hour', $sdate->hour);
          $bibentry->set_datafield($datetype . 'minute', $sdate->minute);
          $bibentry->set_datafield($datetype . 'second', $sdate->second);
          unless ($sdate->time_zone->is_floating) { # ignore floating timezones
            $bibentry->set_datafield($datetype . 'timezone', tzformat($sdate->time_zone->name));
          }
        }
      }
      else {
        biber_warn("$bee entry '$key' ($ds): Invalid format '" . $node->textContent() . "' of date field '$f' - ignoring", $bibentry);
      }
    }
  }
  return;
}

# Name fields
sub _name {
  my ($bibentry, $entry, $f, $key) = @_;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $bee = $bibentry->get_field('entrytype');
  my $node = $entry->findnodes("./$NS:names[\@type='$f']")->get_node(1);
  my $xdmi = Biber::Config->getoption('xdatamarker');
  my $xnsi = Biber::Config->getoption('xnamesep');

  my $names = Biber::Entry::Names->new('type' => $f);

  # per-namelist options
  foreach my $nlo (keys $CONFIG_SCOPEOPT_BIBLATEX{NAMELIST}->%*) {
    if ($node->hasAttribute($nlo)) {
      my $nlov = $node->getAttribute($nlo);
      my $oo = expand_option_input($nlo, $nlov, $CONFIG_BIBLATEX_OPTIONS{NAMELIST}{$nlo}{INPUT});

      foreach my $o ($oo->@*) {
        my $method = 'set_' . $o->[0];
        $names->$method($o->[1]);
      }
    }
  }

  my @names = $node->findnodes("./$NS:name");
  for (my $i = 0; $i <= $#names; $i++) {
    my $namenode = $names[$i];

    # XDATA is special, if found, set it
    if (my $xdatav = $namenode->getAttribute('xdata')) {
      $xdatav = "$xdmi$xnsi$xdatav"; # normalise to same as bibtex input
      if ($bibentry->add_xdata_ref(_norm($f), $xdatav, $i)) {
        # Add special xdata ref empty name as placeholder
        $names->add_name(Biber::Entry::Name->new(xdata => $xdatav));
        next;
      }
    }

    $names->add_name(parsename($section, $namenode, $f, $key, $i+1));
  }

  # Deal with explicit "moreenames" in data source
  if ($node->getAttribute('morenames')) {
    $names->set_morenames;
  }

  $bibentry->set_datafield(_norm($f), $names);

  return;
}

=head2 parsename

    Given a name node, this function returns a Biber::Entry::Name object

    Returns an object which internally looks a bit like this:

    { given             => {string => 'John', initial => ['J']},
      family            => {string => 'Doe', initial => ['D']},
      middle            => {string => 'Fred', initial => ['F']},
      prefix            => {string => undef, initial => undef},
      suffix            => {string => undef, initial => undef},
      basenamestring    => 'Doe',
      namestring        => 'Doe, John Fred',
      nameinitstring    => 'Doe_JF',
      gender            => sm,
      useprefix         => 1,
      hashid            => 'someid',
      sortingnamekeytemplatename => 'templatename'
    }

=cut

sub parsename {
  my ($section, $node, $fieldname, $key, $count) = @_;
  if ($logger->is_debug()) {# performance tune
    $logger->debug('Parsing BibLaTeXML name object ' . $node->nodePath);
  }

  my %namec;

  foreach my $n ($dm->get_constant_value('nameparts')) { # list type so returns list
    # If there is a namepart node for this component ...
    if (my $npnode = $node->findnodes("./$NS:namepart[\@type='$n']")->get_node(1)) {

      # name component with parts
      if (my @npnodes =  $npnode->findnodes("./$NS:namepart")) {
        my @parts = map {$_->textContent()} @npnodes;
        $namec{$n} = join_name_parts(\@parts);
        if ($logger->is_debug()) {# performance tune
          $logger->debug("Found namepart '$n': " . $namec{$n});
        }
        my @partinits;
        foreach my $part (@npnodes) {
          if (my $pi = $part->getAttribute('initial')) {
            push @partinits, $pi;
          }
          else {
            push @partinits, gen_initials($part->textContent());
          }
        }
        $namec{"${n}-i"} = \@partinits;
      }
      # with no parts
      elsif (my $t = $npnode->textContent()) {
        $namec{$n} = $t;
        if ($logger->is_debug()) {# performance tune
          $logger->debug("Found namepart '$n': $t");
        }
        if (my $ni = $node->getAttribute('initial')) {
          $namec{"${n}-i"} = [$ni];
        }
        else {
          $namec{"${n}-i"} = [gen_initials($t)];
        }
      }
    }
  }

  my %nameinfo;
  foreach my $np ($dm->get_constant_value('nameparts')) { # list type so returns list
    $nameinfo{$np} = {string  => $namec{$np} // undef,
                       initial => exists($namec{$np}) ? $namec{"${np}-i"} : undef};

    # Record max namepart lengths
    $section->set_np_length($np, length($nameinfo{$np}{string}))  if $nameinfo{$np}{string};
    $section->set_np_length("${np}-i", length(join('', $nameinfo{$np}{initial}->@*))) if $nameinfo{$np}{initial};
  }

  my $newname = Biber::Entry::Name->new(
                                        %nameinfo,
                                        gender => $node->getAttribute('gender'),
                                        hashid => $node->getAttribute('id')
                                       );

  # per-name options
  foreach my $no (keys $CONFIG_SCOPEOPT_BIBLATEX{NAME}->%*) {
    if ($node->hasAttribute($no)) {
      my $nov = $node->getAttribute($no);
      my $oo = expand_option_input($no, $nov, $CONFIG_BIBLATEX_OPTIONS{NAME}{$no}{INPUT});

      foreach my $o ($oo->@*) {
        my $method = 'set_' . $o->[0];
        $newname->$method($o->[1]);
      }
    }
  }

  return $newname;
}

# parses a range and returns a ref to an array of start and end values
sub _parse_range_list {
  my $rangenode = shift;
  my $start = '';
  my $end = '';
  if (my $s = $rangenode->findnodes("./$NS:start")) {
    $start = $s->get_node(1)->textContent();
  }
  if (my $e = $rangenode->findnodes("./$NS:end")) {
    $end = $e->get_node(1)->textContent();
  }
  return [$start, $end];
}



# Splits a list field into an array ref
sub _split_list {
  my ($bibentry, $node, $key, $f, $noxdata) = @_;
  my $xdmi = Biber::Config->getoption('xdatamarker');
  my $xnsi = Biber::Config->getoption('xnamesep');

  if (my @list = $node->findnodes("./$NS:list/$NS:item")) {

    my @result;

    for (my $i = 0; $i <= $#list; $i++) {

      # Record any XDATA and skip if we did
      # If this field itself is XDATA, don't analyse XDATA further, just split and return
      if (my $xdatav = $list[$i]->getAttribute('xdata')) {
        $xdatav = "$xdmi$xnsi$xdatav"; # normalise to same as bibtex input
        $bibentry->add_xdata_ref(_norm($f), $xdatav, $i) unless $noxdata;
        push @result, $xdatav;
      }
      else {
        push @result, $list[$i]->textContent();
      }
    }

    return [ @result ];
  }
  else {
    return [ $node->textContent() ];
  }
}

# normalise a node name as they have a namsespace and might not be lowercase
sub _norm {
  my $name = lc(shift);
  $name =~ s/\A$NS://xms;
  return $name;
}

sub _get_handler {
  my $field = shift;

  if (my $h = $handlers->{CUSTOM}{_norm($field)}) {
    return $h;
  }
  else {
    return $handlers->{$dm->get_fieldtype(_norm($field))}{$dm->get_fieldformat(_norm($field)) || 'default'}{$dm->get_datatype(_norm($field))};
  }
}


# Changes node $xp_target_s (XPATH 1.0) to $value in the biblatexml entry $e, puts errors
# into $error. Quite complicated because of the various node types that can be changed and
# also due to the requirements of creating new targets when then don't exist.
sub _changenode {
  my ($e, $xp_target_s, $value, $error) = @_;

  # names are special and can be specified by just the string
  if ($dm->is_field($value)) {
    my $dmv = $dm->get_dm_for_field($value);
    if ($dmv->{fieldtype} eq 'list' and $dmv->{datatype} eq 'name') {
      $value = _getpath($value);
    }
  }

  # $value can be an XPATH or just a string.
  my $nodeval = 0;
  if ($value =~ m|/|) {
    $value = $e->findnodes($value)->get_node(1)->cloneNode(1);
    $nodeval = 1;
  }

  # target already exists
  if (my $n = $e->findnodes($xp_target_s)->get_node(1)) {
    # set attribute value
    if ($n->nodeType == XML_ATTRIBUTE_NODE) {
      if ($nodeval) {
        $$error = "Tried to replace '$xp_target_s' Atribute node with complex data";
        return 0;
      }
      $n->setValue(NFC($value));
    }
    # Set element
    elsif ($n->nodeType == XML_ELEMENT_NODE) {
      # if value is a node, remove target child nodes and replace with value child nodes
      if ($nodeval) {
        $n->removeChildNodes();
        foreach my $cn ($value->childNodes) {
          $n->appendChild($cn);
        }
      }
      # value is just a string, replace target text content with value string
      else {
        $n->findnodes('./text()')->get_node(1)->setData(NFC($value));
      }
    }
    # target is a text node, just replace string
    elsif ($n->nodeType == XML_TEXT_NODE) {
      if ($nodeval) {
        $$error = "Tried to replace '$xp_target_s' Text node with complex data";
        return 0;
      }
      $n->setData(NFC($value));
    }
  }
  else {
    my @nodes = split(m|/|, $xp_target_s =~ s|^\./||r);
    my $nodepath = '.';
    my $nodeparent = '.';
    for (my $i = 0; $i <= $#nodes; $i++) {
      my $node = $nodes[$i];
      $nodepath .= "/$node";
      unless ($e->findnodes($nodepath)) {
        my $parent = $e->findnodes($nodeparent)->get_node(1);
        # Element
        my $f;
        if (my ($np) = $node =~ m|^bltx:([^/]+)|) {
          # names are special
          $f = $np;
          if ($np =~ /names\[\@type\s*=\s*'(.+)'\]/) {
            $f = $1;
          }
          if ($dm->field_is_fieldtype('list', $f) and
              $dm->field_is_datatype('name', $f)) {
            my $newnode = $parent->appendChild(XML::LibXML::Element->new('names'));
            $newnode->setNamespace($BIBLATEXML_NAMESPACE_URI, 'bltx');
            $newnode->setAttribute('type', $f);
            if ($i == $#nodes) { # terminal node
              if ($nodeval) {
                foreach my $cn ($value->childNodes) {
                  $newnode->appendChild($cn);
                }
              }
              else {
                $$error = "Tried to map to complex target '$xp_target_s' with string value";
                return 0;
              }
            }
          }
          else {
            my $newnode = $parent->appendChild(XML::LibXML::Element->new($node =~ s|^bltx:||r));
            $newnode->setNamespace($BIBLATEXML_NAMESPACE_URI, 'bltx');
            if ($i == $#nodes) { # terminal node
              $newnode->appendTextNode(NFC($value));
            }
          }
        }
        # Attribute
        elsif ($node =~ m/^@/) {
          if ($i == $#nodes) {
            $parent->setAttribute($node =~ s|^@||r, NFC($value));
          }
        }
        # Text
        elsif ($node =~ m/text\(\)$/) {
          if ($i == $#nodes) {
            $parent->appendTextNode(NFC($value));
          }
        }
      }
      $nodeparent .= "/$node";
    }
  }
  return 1;
}

sub _getpath {
  my $string = shift;
  return undef unless $string;
  my $dm = Biber::Config->get_dm;
  if ($string =~ m|/|) {
    return $string;             # presumably already XPath
  }
  else {
    if ($dm->is_field($string)) {
      my $dms = $dm->get_dm_for_field($string);
      if ($dms->{fieldtype} eq 'list' and $dms->{datatype} eq 'name') {
        return "./bltx:names[\@type='$string']";
      }
      else {
        return "./bltx:$string";
      }
    }
    else {
      return $string; # not a field, presumably just a string value
    }
  }
}


1;

__END__

=pod

=encoding utf-8

=head1 NAME

Biber::Input::file::biblatexml - look in a BibLaTeXML file for an entry and create it if found

=head1 DESCRIPTION

Provides the extract_entries() method to get entries from a biblatexml data source
and instantiate Biber::Entry objects for what it finds

=head1 AUTHOR

Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our Github tracker at
L<https://github.com/plk/biber/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2012 François Charette and Philip Kime, all rights reserved.
Copyright 2012-2024 Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
