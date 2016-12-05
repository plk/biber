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
use File::Slurp;
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
                'CUSTOM' => {'related' => \&_related},
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
  my ($source, $keys) = @_;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $bibentries = $section->bibentries;
  my $filename;
  my @rkeys = $keys->@*;
  my $tf; # Up here so that the temp file has enough scope to survive until we've
          # used it
  $logger->trace("Entering extract_entries() in driver 'biblatexml'");

  # Get a reference to the correct sourcemap sections, if they exist
  my $smaps = [];
  # Maps are applied in order USER->STYLE->DRIVER
  if (defined(Biber::Config->getoption('sourcemap'))) {
    # User maps
    if (my $m = first {$_->{datatype} eq 'biblatexml' and $_->{level} eq 'user' } @{Biber::Config->getoption('sourcemap')} ) {
      push $smaps->@*, $m;
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

  # If it's a remote data file, fetch it first
  if ($source =~ m/\A(?:http|ftp)(s?):\/\//xms) {
    $logger->info("Data source '$source' is a remote .xml - fetching ...");
    if (my $cf = $REMOTE_MAP{$source}) {
      $logger->info("Found '$source' in remote source cache");
      $filename = $cf;
    }
    else {
      if ($1) {                 # HTTPS
        # use IO::Socket::SSL qw(debug99); # useful for debugging SSL issues
        # We have to explicitly set the cert path because otherwise the https module
        # can't find the .pem when PAR::Packer'ed
        # Have to explicitly try to require Mozilla::CA here to get it into %INC below
        # It may, however, have been removed by some biber unpacked dists
        if (not exists($ENV{PERL_LWP_SSL_CA_FILE}) and
            not exists($ENV{PERL_LWP_SSL_CA_PATH}) and
            not defined(Biber::Config->getoption('ssl-nointernalca')) and
            eval {require Mozilla::CA}) {
          # we assume that the default CA file is in .../Mozilla/CA/cacert.pem
          (my $vol, my $dir, undef) = File::Spec->splitpath( $INC{"Mozilla/CA.pm"} );
          $dir =~ s/\/$//;      # splitpath sometimes leaves a trailing '/'
          $ENV{PERL_LWP_SSL_CA_FILE} = File::Spec->catpath($vol, "$dir/CA", 'cacert.pem');
        }

        # fallbacks for, e.g., linux
        unless (exists($ENV{PERL_LWP_SSL_CA_FILE})) {
          foreach my $ca_bundle (qw{
                                     /etc/ssl/certs/ca-certificates.crt
                                     /etc/pki/tls/certs/ca-bundle.crt
                                     /etc/ssl/ca-bundle.pem
                                 }) {
            next if ! -e $ca_bundle;
            $ENV{PERL_LWP_SSL_CA_FILE} = $ca_bundle;
            last;
          }
          foreach my $ca_path (qw{
                                   /etc/ssl/certs/
                                   /etc/pki/tls/
                               }) {
            next if ! -d $ca_path;
            $ENV{PERL_LWP_SSL_CA_PATH} = $ca_path;
            last;
          }
        }

        if (defined(Biber::Config->getoption('ssl-noverify-host'))) {
          $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
        }
        require LWP::Protocol::https;
      }
      require LWP::Simple;
      $tf = File::Temp->new(TEMPLATE => 'biber_remote_data_source_XXXXX',
                            DIR => $Biber::MASTER->biber_tempdir,
                            SUFFIX => '.xml');

      # Pretend to be a browser otherwise some sites refuse the default LWP UA string
      $LWP::Simple::ua->agent('Mozilla/5.0');

      my $retcode = LWP::Simple::getstore($source, $tf->filename);
      unless (LWP::Simple::is_success($retcode)) {
        biber_error("Could not fetch '$source' (HTTP code: $retcode)");
      }
      $filename = $tf->filename;
      # cache any remote so it persists and so we don't fetch it again
      $REMOTE_MAP{$source} = $filename;
    }
  }
  else {
    # Need to get the filename so we increment
    # the filename count for preambles at the bottom of this sub
    my $trying_filename = $source;
    unless ($filename = locate_biber_file($source)) {
      biber_error("Cannot find file '$source'!")
    }
  }

  # Log that we found a data file
  $logger->info("Found BibLaTeXML data file '$filename'");

  # Set up XML parser and namespace
  my $xml = File::Slurp::read_file($filename) or biber_error("Can't read file $filename");
  $xml = NFD(decode('UTF-8', $xml));# Unicode NFD boundary
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

      create_entry($key, $entry, $source, $smaps, \@rkeys);

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

          create_entry($wanted_key, $entry, $source, $smaps, \@rkeys);
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

          create_entry($key, $entry, $source, $smaps, \@rkeys);
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

                unless (_changenode($etarget, $xp_fieldsource_s, ireplace($last_fieldval, $m, $r)), \$cnerror) {
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

              # If append is set, keep the original value and append the new
              my $orig = $step->{map_append} ? $etarget->findvalue($xp_node) : '';

              if ($step->{map_origentrytype}) {
                next unless $last_type;
                if ($logger->is_debug()) {# performance tune
                  $logger->debug("Source mapping (type=$level, key=$etargetkey): Setting xpath '$xp_node_s' to '${orig}${last_type}'");
                }

                unless (_changenode($etarget, $xp_node_s, $orig . $last_type, \$cnerror)) {
                  biber_warn("Source mapping (type=$level, key=$key): $cnerror");
                }
              }
              elsif ($step->{map_origfieldval}) {
                next unless $last_fieldval;
                if ($logger->is_debug()) {# performance tune
                  $logger->debug("Source mapping (type=$level, key=$etargetkey): Setting field xpath '$xp_node_s' to '${orig}${last_fieldval}'");
                }
                unless (_changenode($etarget, $xp_node_s, $orig . $last_fieldval, \$cnerror)) {
                  biber_warn("Source mapping (type=$level, key=$etargetkey): $cnerror");
                }
              }
              elsif ($step->{map_origfield}) {
                next unless $last_field;
                if ($logger->is_debug()) {# performance tune
                  $logger->debug("Source mapping (type=$level, key=$etargetkey): Setting field xpath '$xp_node_s' to '${orig}${last_field}'");
                }
                unless (_changenode($etarget, $xp_node_s, $orig . $last_field, \$cnerror)) {
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
                unless (_changenode($etarget, $xp_node_s, $orig . $fv, \$cnerror)) {
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

    # We put all the fields we find modulo field aliases into the object.
    # Validation happens later and is not datasource dependent
    foreach my $f (uniq map { if (_norm($_->nodeName) eq 'names') { $_->getAttribute('type') }
                              else { $_->nodeName()} }  $e->findnodes('*')) {

      # We have to process local options as early as possible in order
      # to make them available for things that need them like name parsing
      if (_norm($f) eq 'options') {
        if (my $node = $entry->findnodes("./$NS:options")->get_node(1)) {
          process_entry_options($k, [ split(/\s*,\s*/, $node->textContent()) ]);
        }
      }

      # Now run any defined handler
      if ($dm->is_field(_norm($f))) {
        my $handler = _get_handler($f);
        $handler->($bibentry, $e, $f, $k);
      }
    }

    $bibentry->set_field('entrytype', $e->getAttribute('entrytype'));
    $bibentry->set_field('datatype', 'biblatexml');
    $bibentries->add_entry($k, $bibentry);
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
  foreach my $node ($entry->findnodes("./$f")) {
    # eprint is special case
    if ($f eq "$NS:eprint") {
      $bibentry->set_datafield('eprinttype', $node->getAttribute('type'));
      if (my $ec = $node->getAttribute('class')) {
        $bibentry->set_datafield('eprintclass', $ec);
      }
    }
    else {
      $bibentry->set_datafield(_norm($f), $node->textContent());
    }
    # generic annotation attribute
    if (my $string = $node->getAttribute('annotation')) {
      Biber::Annotation->set_annotation('field', $key, _norm($f), $string);
    }
  }
  return;
}

# xSV field
sub _xsv {
  my ($bibentry, $entry, $f, $key) = @_;
  foreach my $node ($entry->findnodes("./$f")) {
    $bibentry->set_datafield(_norm($f), _split_list($node, $key, $f));
    # generic annotation attribute
    if (my $string = $node->getAttribute('annotation')) {
      Biber::Annotation->set_annotation('field', $key, _norm($f), $string);
    }
  }
  return;
}


# uri fields
sub _uri {
  my ($bibentry, $entry, $f, $key) = @_;
  my $node = $entry->findnodes("./$f")->get_node(1);
  my $value = $node->textContent();

  # URL escape if it doesn't look like it already is
  # This is useful if we are generating URLs automatically with maps which may
  # contain UTF-8 from other fields
  unless ($value =~ /\%/) {
   $value = URI->new($value)->as_string;
  }
  $bibentry->set_datafield(_norm($f), $value);
  # generic annotation attribute
  if (my $string = $node->getAttribute('annotation')) {
    Biber::Annotation->set_annotation('field', $key, _norm($f), $string);
  }
  return;
}


# List fields
sub _list {
  my ($bibentry, $entry, $f, $key) = @_;
  foreach my $node ($entry->findnodes("./$f")) {
    $bibentry->set_datafield(_norm($f), _split_list($node, $key, $f));

    # generic annotation attribute
    if (my $string = $node->getAttribute('annotation')) {
      Biber::Annotation->set_annotation('field', $key, _norm($f), $string);
    }
  }
  return;
}

# Range fields
sub _range {
  my ($bibentry, $entry, $f, $key) = @_;
  foreach my $node ($entry->findnodes("./$f")) {
    # List of ranges/values
    if (my @rangelist = $node->findnodes("./$NS:list/$NS:item")) {
      my $rl;
      foreach my $range (@rangelist) {
        push $rl->@*, _parse_range_list($range);
      }
      $bibentry->set_datafield(_norm($f), $rl);
    }
  }
  return;
}

# Date fields
# NOTE - the biblatex options controlling era, circa and uncertain meta-information
# output are in the .bcf but biber does not used them as it always outputs this information
sub _datetime {
  my ($bibentry, $entry, $f, $key) = @_;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $ds = $section->get_keytods($key);

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
        # Save circa information
        $bibentry->set_field($datetype . 'datecirca', 1) if $CONFIG_DATE_PARSERS{start}->circa;

        # Save uncertain date information
        $bibentry->set_field($datetype . 'dateuncertain', 1) if $CONFIG_DATE_PARSERS{start}->uncertain;

        # Date had EDTF 5.2.2 unspecified format
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

        # Save start season date information
        if (my $season = $CONFIG_DATE_PARSERS{start}->season) {
          $bibentry->set_field($datetype . 'season', $season);
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
        biber_warn("Datamodel: Entry '$key' ($ds): Invalid format '" . $start->get_node(1)->textContent() . "' of date field '$f' range start - ignoring", $bibentry);
      }

      # End of range
      my $edate = parse_date_end($end->get_node(1)->textContent());
      if (defined($edate)) { # no parse error
        if ($edate) { # not an empty range

          # Save julian
          $bibentry->set_field($datetype . 'enddatejulian', 1) if $CONFIG_DATE_PARSERS{end}->julian;

          # Save circa information
          $bibentry->set_field($datetype . 'enddatecirca', 1) if $CONFIG_DATE_PARSERS{end}->circa;

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

          # Save end season date information
          if (my $season = $CONFIG_DATE_PARSERS{end}->season) {
            $bibentry->set_field($datetype . 'endseason', $season);
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
        biber_warn("Entry '$key' ($ds): Invalid format '" . $end->get_node(1)->textContent() . "' of date field '$f' range end - ignoring", $bibentry);
      }
    }
    else { # Simple date
      # Using high-level range parsing sub in order to get unspec
      if (my ($sdate, undef, undef, $unspec) = parse_date_range($bibentry,
                                                                $datetype,
                                                                $node->textContent())) {

        # Save julian
        $bibentry->set_field($datetype . 'datejulian', 1) if $CONFIG_DATE_PARSERS{start}->julian;
        # Save circa information
        $bibentry->set_field($datetype . 'datecirca', 1) if $CONFIG_DATE_PARSERS{start}->circa;

        # Save uncertain date information
        $bibentry->set_field($datetype . 'dateuncertain', 1) if $CONFIG_DATE_PARSERS{start}->uncertain;

        # Date had EDTF 5.2.2 unspecified format
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

        # Save start season date information
        if (my $season = $CONFIG_DATE_PARSERS{start}->season) {
          $bibentry->set_field($datetype . 'season', $season);
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
        biber_warn("Entry '$key' ($ds): Invalid format '" . $node->textContent() . "' of date field '$f' - ignoring", $bibentry);
      }
    }
  }
  return;
}

# Name fields
sub _name {
  my ($bibentry, $entry, $f, $key) = @_;

  foreach my $node ($entry->findnodes("./$NS:names[\@type='$f']")) {
    my $names = new Biber::Entry::Names;

    # Save useprefix attribute
    if ($node->hasAttribute('useprefix')) {
      $names->set_useprefix(map_boolean($node->getAttribute('useprefix'), 'tonum'));
    }

    # Save sortnamekeyscheme attribute
    if ($node->hasAttribute('sortnamekeyscheme')) {
      $names->set_sortnamekeyscheme($node->getAttribute('sortnamekeyscheme'));
    }

    my $numname = 1;
    foreach my $namenode ($node->findnodes("./$NS:name")) {

      my $useprefix;
      # Name list and higher scope useprefix option. We have to pass this into parsename
      # as the actual current scope value is needed to generate name objects
      if (defined($names->get_useprefix)) {
        $useprefix = $names->get_useprefix;
      }
      else {
        $useprefix = Biber::Config->getblxoption('useprefix', $bibentry->get_field('entrytype'), $key);
      }

      $names->add_name(parsename($namenode, $f, $key, $numname++, {useprefix => $useprefix}));
    }

    # Deal with explicit "moreenames" in data source
    if ($node->getAttribute('morenames')) {
      $names->set_morenames;
    }

    $bibentry->set_datafield(_norm($f), $names);

    # generic annotation attribute
    if (my $string = $node->getAttribute('annotation')) {
      Biber::Annotation->set_annotation('field', $key, _norm($f), $string);
    }
  }
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
      sortnamekeyscheme => 'scheme' }
      }

=cut

sub parsename {
  my ($node, $fieldname, $key, $count, $opts) = @_;
  if ($logger->is_debug()) {# performance tune
    $logger->debug('Parsing BibLaTeXML name object ' . $node->nodePath);
  }
  # We have to pass this in from higher scopes as we need to actually use the scoped
  # value in this sub as well as set the name local value in the object
  my $useprefix = $opts->{useprefix};
  my $namescope_useprefix;

  # Set name-scope useprefix attribute if it exists
  if ($node->hasAttribute('useprefix')) {
    $useprefix = $namescope_useprefix = map_boolean($node->getAttribute('useprefix'), 'tonum');
  }

  # generic annotation attribute - individual name scope
  if (my $string = $node->getAttribute('annotation')) {
    Biber::Annotation->set_annotation('item', $key, _norm($fieldname), $string, $count);
  }

  my %namec;

  foreach my $n ($dm->get_constant_value('nameparts')) { # list type so returns list
    # If there is a namepart node for this component ...
    if (my $npnode = $node->findnodes("./$NS:namepart[\@type='$n']")->get_node(1)) {

      # generic annotation attribute - namepart scope
      if (my $string = $npnode->getAttribute('annotation')) {
        Biber::Annotation->set_annotation('part', $key, _norm($fieldname), $string, $count, $n);
      }

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

  my $basenamestring = '';
  my $namestring = '';
  my $nameinitstring = '';

  # Loop over name parts required for constructing uniquename information
  # and create the strings needed for this
  #
  # Note that with the default uniquenametemplate, we don't conditionalise the *position*
  # of a prefix on the useprefix option but rather its inclusion at all. This is because, if
  # useprefix determined the position of the prefix in the uniquename strings:
  # * As a global setting, it would generate the same uniqueness information and is therefore
  #   irrelevant
  # * As a local setting (entry, namelist, name), it would lead to different uniqueness
  #   information which would be confusing

  # Use nameuniqueness template to construct uniqueness strings
  foreach my $np (@{Biber::Config->getblxoption('uniquenametemplate')}) {
    my $npn = $np->{namepart};
    if ($namec{$npn}) {
      if ($np->{use}) {         # only ever defined as 1
        next unless $opts->{"use$npn"};
      }
      $namestring .= $namec{$npn};
      if ($np->{base}) {
        $nameinitstring .= $namec{$npn};
        $basenamestring .= $namec{$npn};
      }
      else {
        $nameinitstring .= join('', @{$namec{"${npn}-i"}});
      }
    }
  }

  my %nps;
  foreach my $n ($dm->get_constant_value('nameparts')) { # list type so returns list
    $nps{$n} = {string  => $namec{$n} // undef,
                initial => exists($namec{$n}) ? $namec{"${n}-i"} : undef};
  }

  my $newname = Biber::Entry::Name->new(
                                        %nps,
                                        namestring      => $namestring,
                                        nameinitstring  => $nameinitstring,
                                        basenamestring  => $basenamestring,
                                        gender          => $node->getAttribute('gender')
                                       );

  # Set name-scope sortnamekeyscheme attribute if it exists
  if ($node->hasAttribute('sortnamekeyscheme')) {
    $newname->set_sortnamekeyscheme($node->getAttribute('sortnamekeyscheme'));
  }

  # Set name-scope useprefix if it is defined
  if (defined($namescope_useprefix)) {
    $newname->set_useprefix($namescope_useprefix);
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
  my ($node, $key, $f) = @_;
  if (my @list = $node->findnodes("./$NS:list/$NS:item")) {

    for (my $i = 0; $i <= $#list; $i++) {
      # generic annotation attribute
      if (my $string = $list[$i]->getAttribute('annotation')) {
        Biber::Annotation->set_annotation('item', $key, _norm($f), $string, $i+1);
      }
    }

    return [ map {$_->textContent()} @list ];
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

François Charette, C<< <firmicus at ankabut.net> >>
Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our Github tracker at
L<https://github.com/plk/biber/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2016 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
