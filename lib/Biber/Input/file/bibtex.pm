package Biber::Input::file::bibtex;
use v5.24;
use strict;
use warnings;
use sigtrap qw(handler TBSIG SEGV);

use Carp;
use Digest::MD5 qw( md5_hex );
use Text::BibTeX qw(:nameparts :joinmethods :metatypes);
use Text::BibTeX::Name;
use Text::BibTeX::NameFormat;
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
use Encode;
use File::Spec;
use File::Slurper;
use File::Temp;
use Log::Log4perl qw(:no_extra_logdie_message);
use List::AllUtils qw( :all );
use Scalar::Util qw(looks_like_number);
use URI;
use Unicode::Normalize;
use Unicode::GCString;
use Unicode::UCD qw(num);
use XML::LibXML::Simple;

my $logger = Log::Log4perl::get_logger('main');

state $cache; # state variable so it's persistent across calls to extract_entries()
use vars qw($cache);

=head2 init_cache

    Invalidate the T::B object cache. Used only in tests when e.g. we change the encoding
    settings and therefore must force a re-read of the data

=cut

sub init_cache {
  $cache = {};
}

# Determine handlers from data model
my $dm = Biber::Config->get_dm;
my $handlers = {
                'custom' => {'annotation' => \&_annotation},
                'field' => {
                            'default'  => {
                                           'code'     => \&_literal,
                                           'date'     => \&_datetime,
                                           'datepart' => \&_literal,
                                           'entrykey' => \&_literal,
                                           'integer'  => \&_literal,
                                           'key'      => \&_literal,
                                           'literal'  => \&_literal,
                                           'range'    => \&_range,
                                           'verbatim' => \&_verbatim,
                                           'uri'      => \&_uri
                                          },
                            'xsv'      => {
                                           'entrykey' => \&_xsv,
                                           'literal'  => \&_xsv,
                                           'keyword'  => \&_xsv,
                                           'option'   => \&_xsv,
                                          }
                           },
                'list' => {
                           'default'   => {
                                           'key'      => \&_list,
                                           'literal'  => \&_list,
                                           'name'     => \&_name,
                                           'verbatim' => \&_list,
                                           'uri'      => \&_urilist
                                          }
                          }
};


=head2 TBSIG

     Signal handler to catch fatal Text::BibTex SEGFAULTS. It has bugs
     and we want to say at least something if it coredumps

=cut

sub TBSIG {
  my $sig = shift;
  $logger->logdie("Caught signal: $sig\nLikely your .bib has a very bad entry which causes libbtparse to crash: $!");
}

=head2 extract_entries

   Main data extraction routine.
   Accepts a data source identifier, preprocesses the file and then
   looks for the passed keys, creating entries when it finds them and
   passes out an array of keys it didn't find.

=cut

sub extract_entries {
  my ($filename, $encoding, $keys) = @_;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my @rkeys = $keys->@*;

  if ($logger->is_trace()) {# performance tune
    $logger->trace("Entering extract_entries() in driver 'bibtex'");
  }

  # Check for empty files because they confuse btparse
  unless (check_empty($filename)) { # File is empty
    biber_warn("Data source '$filename' is empty, ignoring");
    return @rkeys;
  }

  # Check for files with no macros - they also confuse btparse
  my $tbuf;
  unless (eval {$tbuf = slurp_switchr($filename, $encoding)->$*}) {
    biber_error("Data file '$filename' cannot be read in encoding '$encoding': $@");
  }
  unless ($tbuf =~ m/\@/) {
    biber_warn("Data source '$filename' contains no BibTeX entries/macros, ignoring");
    return @rkeys;
  }

  # Get a reference to the correct sourcemap sections, if they exist
  my $smaps = [];
  # Maps are applied in order USER->STYLE->DRIVER
  if (defined(Biber::Config->getoption('sourcemap'))) {
    # User maps, allow multiple \DeclareSourcemap
    if (my @m = grep {$_->{datatype} eq 'bibtex' and $_->{level} eq 'user' } Biber::Config->getoption('sourcemap')->@* ) {
      push $smaps->@*, @m;
    }
    # Style maps
    # Allow multiple style maps from multiple \DeclareStyleSourcemap
    if (my @m = grep {$_->{datatype} eq 'bibtex' and $_->{level} eq 'style' } Biber::Config->getoption('sourcemap')->@* ) {
      push $smaps->@*, @m;
    }
    # Driver default maps
    if (my $m = first {$_->{datatype} eq 'bibtex' and $_->{level} eq 'driver'} Biber::Config->getoption('sourcemap')->@* ) {
      push $smaps->@*, $m;
    }
  }

  # Text::BibTeX can't be controlled by Log4perl so we have to do something clumsy
  # We can't redirect STDERR to a variable as libbtparse doesnt' use PerlIO, just stdio
  # so it doesn't understand this. It does understand normal file redirection though as
  # that's standard stdio.
  # The Log4Perl setup outputs only to STDOUT so redirecting all STDERR like this is
  # ok since only libbtparse will be writing there
  # Don't do this if we are debugging or tracing because some errors in libbtparse cause
  # sudden death and can't be output as the read/output of the saved STDERR is never reached.
  # so, if debugging/tracing, output STDERR errors immediately.
  my $tberr;
  my $tberr_name;
  unless ($logger->is_debug() or $logger->is_trace()) {
    $tberr = File::Temp->new(TEMPLATE => 'biber_Text_BibTeX_STDERR_XXXXX',
                             DIR      => $Biber::MASTER->biber_tempdir);
    $tberr_name = $tberr->filename;
    open OLDERR, '>&', \*STDERR;
    open STDERR, '>', $tberr_name;
  }

  # Increment the number of times each datafile has been referenced
  # For example, a datafile might be referenced in more than one section.
  # Some things find this information useful, for example, setting preambles is global
  # and so we need to know if we've already saved the preamble for a datafile.
  $cache->{counts}{$filename}++;

  # Don't read the file again if it's already cached
  unless ($cache->{data}{$filename}) {
    if ($logger->is_debug()) {# performance tune
      $logger->debug("Caching data for BibTeX format file '$filename' for section $secnum");
    }
    cache_data($filename, $encoding);
  }
  else {
    if ($logger->is_debug()) {# performance tune
      $logger->debug("Using cached data for BibTeX format file '$filename' for section $secnum");
    }
  }

  if ($section->is_allkeys) {
    if ($logger->is_debug()) {# performance tune
      $logger->debug("All citekeys will be used for section '$secnum'");
    }

    # Loop over all entries, creating objects
    while (my ($key, $entry) = each $cache->{data}{$filename}->%*) {

      # Record a key->datasource name mapping for error reporting
      $section->set_keytods($key, $filename);

      unless (create_entry($key, $entry, $filename, $smaps, \@rkeys)) {
        # if create entry returns false, remove the key from the cache
        $cache->{orig_key_order}{$filename}->@* = grep {$key ne $_} $cache->{orig_key_order}{$filename}->@*;
      }
    }

    # Loop over all aliases, creating data in section object
    # Since this is allkeys, we are guaranteed that the real entry for the alias
    # will be available
    while (my ($alias, $key) = each $cache->{data}{citekey_aliases}->%*) {
      $section->set_citekey_alias($alias, $key);
    }

    # If allkeys, push all bibdata keys into citekeys (if they are not already there).
    # We are using the special "orig_key_order" array which is used to deal with the
    # situation when sorting=none and allkeys is set. We need an array rather than the
    # keys from the bibentries hash because we need to preserve the original order of
    # the .bib as in this case the sorting sub "citeorder" means "bib order" as there are
    # no explicitly cited keys
    $section->add_citekeys($cache->{orig_key_order}{$filename}->@*);

    if ($logger->is_debug()) {# performance tune
      $logger->debug("Added all citekeys to section '$secnum': " . join(', ', $section->get_citekeys));
    }
    # Special case when allkeys but also some dynamic set entries. These keys must also be
    # in the section or they will be missed on output.
    if ($section->has_dynamic_sets) {
      $section->add_citekeys($section->dynamic_set_keys->@*);
      if ($logger->is_debug()) {# performance tune
        $logger->debug("Added dynamic sets to section '$secnum': " . join(', ', $section->dynamic_set_keys->@*));
      }
    }
  }
  else {
    # loop over all keys we're looking for and create objects
    if ($logger->is_debug()) {# performance tune
      $logger->debug('Text::BibTeX cache keys: ' . join(', ', keys $cache->{data}{$filename}->%*));
      $logger->debug('Wanted keys: ' . join(', ', $keys->@*));
    }
    foreach my $wanted_key ($keys->@*) {
      if ($logger->is_debug()) {# performance tune
        $logger->debug("Looking for key '$wanted_key' in Text::BibTeX cache");
      }

      # Record a key->datasource name mapping for error reporting
      $section->set_keytods($wanted_key, $filename);

      if (my $entry = $cache->{data}{$filename}{$wanted_key}) {
        if ($logger->is_debug()) {# performance tune
          $logger->debug("Found key '$wanted_key' in Text::BibTeX cache");
        }

        # Skip creation if it's already been done, for example, via a citekey alias
        unless ($section->bibentries->entry_exists($wanted_key)) {
          unless (create_entry($wanted_key, $entry, $filename, $smaps, \@rkeys)) {
            # if create entry returns false, remove the key from the cache and section
            $section->del_citekey($wanted_key);
            $cache->{orig_key_order}{$filename}->@* = grep {$wanted_key ne $_} $cache->{orig_key_order}{$filename}->@*;
            biber_warn("Entry with key '$wanted_key' in section '$secnum' is cited and found but not created (likely due to sourcemap)");
          }
        }
        # found a key, remove it from the list of keys we want
        @rkeys = grep {$wanted_key ne $_} @rkeys;

      }
      elsif (my $rk = $cache->{data}{citekey_aliases}{$wanted_key}) {
        $section->set_citekey_alias($wanted_key, $rk);

        # Make sure there is a real, cited entry for the citekey alias
        # just in case only the alias is cited. However, make sure that the real entry
        # is actually cited before adding to the section citekeys list in case this real
        # entry is only needed as an aliased Xref and shouldn't necessarily be in
        # the bibliography (minXrefs will take care of adding it there if necessary).
        unless ($section->bibentries->entry_exists($rk)) {
          if (my $entry = $cache->{data}{GLOBALDS}{$rk}) {# Look in cache of all datasource keys
            unless (create_entry($rk, $entry, $filename, $smaps, \@rkeys)) {
              # if create entry returns false, remove the key from the cache
              $section->del_citekey($wanted_key);
              $cache->{orig_key_order}{$filename}->@* = grep {$rk ne $_} $cache->{orig_key_order}{$filename}->@*;
            biber_warn("Entry with key '$rk' in section '$secnum' is cited and found but not created (likely due to sourcemap)");
            }
            if ($section->has_cited_citekey($wanted_key)) {
              $section->add_citekeys($rk);
            }
          }
        }

        # found an alias key, remove it from the list of keys we want
        @rkeys = grep {$wanted_key ne $_} @rkeys;

      }
      elsif (my $okey = $section->has_badcasekey($wanted_key)) {
        biber_warn("Possible typo (case mismatch) between citation and datasource keys: '$wanted_key' and '$okey' in file '$filename'");
      }

      if ($logger->is_debug()) {# performance tune
        $logger->debug('Wanted keys now: ' . join(', ', @rkeys));
      }
    }
  }

  unless ($logger->is_debug() or $logger->is_trace()) {
    open STDERR, '>&', \*OLDERR;
    close OLDERR;

    # Put any Text::BibTeX errors into the biber warnings/errors collections
    # We are parsing the libbtparse library error/warning strings a little here
    # This is not so bad as they have a clean structure (see error.c in libbtparse)
    open my $tbe, '<', $tberr_name;
    while (<$tbe>) {
      next if /overriding\sexisting\sdefinition\sof\smacro/; # ignore macro redefs
      if (/error:/) {
        chomp;
        if (/skipping\sto\snext\s"\@"/) {
          biber_error("BibTeX subsystem: $_");
        }
        else {
          biber_error("BibTeX subsystem: $_");
        }
      }
      elsif (/warning:/) {
        chomp;
        biber_warn("BibTeX subsystem: $_");
      }
    }
    close($tbe);
  }

  # Only push the preambles from the file if we haven't seen this data file before
  # and there are some preambles to push
  if ($cache->{counts}{$filename} < 2 and $cache->{preamble}{$filename}->@*) {
    push $Biber::MASTER->{preamble}->@*, $cache->{preamble}{$filename}->@*;
  }

  # Save comments if in tool mode
  if (Biber::Config->getoption('tool')) {
    if ($cache->{comments}{$filename}) {
      $Biber::MASTER->{comments} = $cache->{comments}{$filename};
    }
  }

  return @rkeys;
}

=head2 create_entry

   Create a Biber::Entry object from a Text::BibTeX object
   Be careful in here, all T::B set methods are UTF-8/NFC boundaries
   so be careful to encode(NFC()) on calls. Windows won't handle UTF-8
   in T::B btparse gracefully and will die.

=cut

sub create_entry {
  # We have to pass in $rkeys so that the new/clone operations can remove the new/clone
  # key from the list of wanted keys because new/cloned entries will never appear to the normal
  # key search loop
  my ($key, $entry, $datasource, $smaps, $rkeys) = @_;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $crret = 1; # Return value from create_entry() is used to signal some things

  if ( $entry->metatype == BTE_REGULAR ) {
    my %newentries; # In case we create a new entry in a map

    # Save entry and work on a clone so that modifications do not propagate to
    # other refsections
    my $saved_entry = $entry;
    $entry = $entry->clone;

    # Datasource mapping applied in $smap order (USER->STYLE->DRIVER)
    foreach my $smap ($smaps->@*) {
      $smap->{map_overwrite} = $smap->{map_overwrite} // 0; # default
      my $level = $smap->{level};

      foreach my $map ($smap->{map}->@*) {

        # Skip if this map element specifies a particular refsection and it is not this one
        if (exists($map->{refsection})) {
          next unless $secnum == $map->{refsection};
        }

        # Check pertype restrictions
        # Logic is "-(-P v Q)" which is equivalent to "P & -Q" but -Q is an array check so
        # messier to write than Q
        unless (not exists($map->{per_type}) or
                first {fc($_->{content}) eq fc($entry->type)} $map->{per_type}->@*) {
          next;
        }

        # Check negated pertype restrictions
        if (exists($map->{per_nottype}) and
            first {fc($_->{content}) eq fc($entry->type)} $map->{per_nottype}->@*) {
          next;
        }

        # Check per_datasource restrictions
        # Don't compare case insensitively - this might not be correct
        # Logic is "-(-P v Q)" which is equivalent to "P & -Q" but -Q is an array check so
        # messier to write than Q
        my $test_path = $datasource;
        if (File::Spec->file_name_is_absolute($test_path)) { # kpsewhich returns abs paths
          $test_path = (File::Spec->splitpath($datasource))[2];
        }
        unless (not exists($map->{per_datasource}) or
                first {$_->{content} eq $test_path} $map->{per_datasource}->@*) {
          next;
        }

        my $last_type = $entry->type; # defaults to the entrytype unless changed below
        my $last_field = undef;
        my $last_fieldval = undef;

        my @imatches; # For persisting parenthetical matches over several steps

        # Set up any mapping foreach loop
        my @maploop = ('');
        if (my $foreach = $map->{map_foreach}) {
          if (my $dslist = $DATAFIELD_SETS{$foreach}) { # datafield set list
            @maploop = $dslist->@*;
          }
          # casefold here as the field name does not come from Text::BibTeX so it might not be
          # valid in the case found in the mapping
          elsif (my $felist = $entry->get(encode('UTF-8', NFC(fc($foreach))))) { # datafield
            @maploop = split(/\s*,\s*/, $felist);
          }
          else { # explicit CSV
            @maploop = split(/\s*,\s*/, $foreach);
          }
        }

      MAP: foreach my $maploop (@maploop) {
          my $MAPUNIQVAL;
          # loop over mapping steps
          foreach my $step ($map->{map_step}->@*) {

            # entry deletion. Really only useful with allkeys or tool mode
            if ($step->{map_entry_null}) {
              if ($logger->is_debug()) { # performance tune
                $logger->debug("Source mapping (type=$level, key=$key): Ignoring entry completely");
              }
              return 0;         # don't create an entry at all
            }

            # new entry
            if (my $newkey = maploopreplace($step->{map_entry_new}, $maploop)) {
              # Now re-instate any unescaped $1 .. $9 to get round these being
              # dynamically scoped and being null when we get here from any
              # previous map_match
              $newkey =~ s/(?<!\\)\$(\d)/$imatches[$1-1]/ge;

              my $newentrytype;
              unless ($newentrytype = maploopreplace($step->{map_entry_newtype}, $maploop)) {
                biber_warn("Source mapping (type=$level, key=$key): Missing type for new entry '$newkey', skipping step ...");
                next;
              }
              if ($logger->is_debug()) { # performance tune
                $logger->debug("Source mapping (type=$level, key=$key): Creating new entry with key '$newkey'");
              }
              my $newentry = Text::BibTeX::Entry->new({binmode => 'utf-8', normalization => 'NFD'});
              $newentry->set_metatype(BTE_REGULAR);
              $newentry->set_key(encode('UTF-8', NFC($newkey)));
              $newentry->set_type(encode('UTF-8', NFC($newentrytype)));

              # found a new entry key, remove it from the list of keys we want since we
              # have "found" it by creating it
              if ($logger->is_debug()) { # performance tune
                $logger->debug("Source mapping (type=$level, key=$key): created '$newkey', removing from dependent list");
              }
              $rkeys->@* = grep {$newkey ne $_} $rkeys->@*;

              # Add to the section if explicitly nocited in the map
              if ($step->{map_entry_nocite}) {
                $section->add_nocite($newkey);
                $section->add_citekeys($newkey);
              }

              # Need to add the new key to the section if allkeys is set since all keys
              # are cleared for allkeys sections initially
              if ($section->is_allkeys) {
                $section->add_citekeys($newkey);
              }
              $newentries{$newkey} = $newentry;
            }

            # entry clone
            if (my $clonekey = maploopreplace($step->{map_entry_clone}, $maploop)) {
              # Now re-instate any unescaped $1 .. $9 to get round these being
              # dynamically scoped and being null when we get here from any
              # previous map_match
              $clonekey =~ s/(?<!\\)\$(\d)/$imatches[$1-1]/ge;

              if ($logger->is_debug()) { # performance tune
                $logger->debug("Source mapping (type=$level, key=$key): cloning entry with new key '$clonekey'");
              }
              # found a clone key, remove it from the list of keys we want since we
              # have "found" it by creating it along with its clone parent
              if ($logger->is_debug()) { # performance tune
                $logger->debug("Source mapping (type=$level, key=$key): created '$clonekey', removing from dependent list");
              }
              $rkeys->@* = grep {$clonekey ne $_} $rkeys->@*;

              # Add to the section if explicitly nocited in the map
              if ($step->{map_entry_nocite}) {
                $section->add_nocite($clonekey);
                $section->add_citekeys($clonekey);
              }

              # Need to add the clone key to the section if allkeys is set since all keys
              # are cleared for allkeys sections initially
              if ($section->is_allkeys) {
                $section->add_citekeys($clonekey);
              }
              $newentries{$clonekey} = $entry->clone;
            }

            # An entry created by map_entry_new or map_entry_clone previously can be
            # the target for field setting options
            # A newly created entry as target of operations doesn't make sense in all situations
            # so it's limited to being the target for field sets
            my $etarget;
            my $etargetkey;
            if ($etargetkey = maploopreplace($step->{map_entrytarget}, $maploop)) {
              # Now re-instate any unescaped $1 .. $9 to get round these being
              # dynamically scoped and being null when we get here from any
              # previous map_match
              $etargetkey =~ s/(?<!\\)\$(\d)/$imatches[$1-1]/ge;

              unless ($etarget = $newentries{$etargetkey}) {
                biber_warn("Source mapping (type=$level, key=$key): Dynamically created entry target '$etargetkey' does not exist skipping step ...");
                next;
              }
            }
            else {           # default is that we operate on the same entry
              $etarget = $entry;
              $etargetkey = $key;
            }

            # Entrytype map
            if (my $typesource = maploopreplace($step->{map_type_source}, $maploop)) {
              $typesource = fc($typesource);
              unless ($etarget->type eq $typesource) {
                # Skip the rest of the map if this step doesn't match and match is final
                if ($step->{map_final}) {
                  if ($logger->is_debug()) { # performance tune
                    $logger->debug("Source mapping (type=$level, key=$etargetkey): Entry type is '" . $etarget->type . "' but map wants '$typesource' and step has 'final' set, skipping rest of map ...");
                  }
                  next MAP;
                }
                else {
                  # just ignore this step
                  if ($logger->is_debug()) { # performance tune
                    $logger->debug("Source mapping (type=$level, key=$etargetkey): Entry type is '" . $etarget->type . "' but map wants '$typesource', skipping step ...");
                  }
                  next;
                }
              }
              # Change entrytype if requested
              $last_type = $etarget->type;
              my $t = fc(maploopreplace($step->{map_type_target}, $maploop));
              if ($logger->is_debug()) { # performance tune
                $logger->debug("Source mapping (type=$level, key=$etargetkey): Changing entry type from '$last_type' to $t");
              }
              $etarget->set_type(encode('UTF-8', NFC($t)));
            }

            my $fieldcontinue = 0;
            my $fieldsource;
            my $nfieldsource;
            # Negated source field map
            if ($nfieldsource = maploopreplace($step->{map_notfield}, $maploop)) {
              $nfieldsource = fc($nfieldsource);
              if ($etarget->exists($nfieldsource)) {
                if ($step->{map_final}) {
                  if ($logger->is_debug()) { # performance tune
                    $logger->debug("Source mapping (type=$level, key=$etargetkey): Field '$nfieldsource' exists and step has 'final' set, skipping rest of map ...");
                  }
                  next MAP;
                }
                else {
                  # just ignore this step
                  if ($logger->is_debug()) { # performance tune
                    $logger->debug("Source mapping (type=$level, key=$etargetkey): Field '$nfieldsource' exists, skipping step ...");
                  }
                  next;
                }
              }
              $fieldcontinue = 1;
            }

            # \cite{key}   -> is_cite(key)=true, is_specificcitekey(key)=true
            # \nocite{key} -> is_nocite(key)=true, is_specificcitekey(key)=true
            # \nocite{*}   -> is_allkeys_nocite=true
            #
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
                    $logger->debug("Source mapping (type=$level, key=$key): Key is not \\cited and step has 'final' set, skipping rest of map ...");
                  }
                  next MAP;
                }
                else {
                  # just ignore this step
                  if ($logger->is_debug()) { # performance tune
                    $logger->debug("Source mapping (type=$level, key=$key): Key is not \\cited, skipping step ...");
                  }
                  next;
                }
              }
            }

            # \nocite{key}
            if ($step->{map_entrykey_nocited}) {
              # If cited, don't want to do the allkeys_nocite check as this overrides
              if ($section->is_cite($key) or
                  (not $section->is_nocite($key) and not $section->is_allkeys_nocite)) {  # check if NOT nocited
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
              if (not $section->is_allkeys_nocite) {  # check if NOT allnocited
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
              if ($section->is_allkeys_nocite and ($section->is_cite($key) or $section->is_nocite($key))) {  # check if NOT nocited
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
            if ($fieldsource = maploopreplace($step->{map_field_source}, $maploop)) {
              $fieldsource = fc($fieldsource);

              # key is a pseudo-field. It's guaranteed to exist so
              # just check if that's what's being asked for
              unless ($fieldsource eq 'entrykey' or
                      $etarget->exists($fieldsource)) {
                # Skip the rest of the map if this step doesn't match and match is final
                if ($step->{map_final}) {
                  if ($logger->is_debug()) { # performance tune
                    $logger->debug("Source mapping (type=$level, key=$etargetkey): No field '$fieldsource' and step has 'final' set, skipping rest of map ...");
                  }
                  next MAP;
                }
                else {
                  # just ignore this step
                  if ($logger->is_debug()) { # performance tune
                    $logger->debug("Source mapping (type=$level, key=$etargetkey): No field '$fieldsource', skipping step ...");
                  }
                  next;
                }
              }
              $fieldcontinue = 1;
            }

            if ($fieldcontinue) {
              $last_field = $fieldsource;
              # $fieldsource is already casefolded, which is correct as it does not come
              # from Text::BibTeX's list of fields
              $last_fieldval = $fieldsource eq 'entrykey' ? $etarget->key : $etarget->get(encode('UTF-8', NFC($fieldsource)));

              my $negmatch = 0;
              my $nm;
              # Negated matches are a normal match with a special flag
              if ($nm = $step->{map_notmatch} or $nm = $step->{map_notmatchi}) {
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
                    $etarget->set(encode('UTF-8', NFC($fieldsource)), $rs[$i]);
                  }
                }
              }

              # map fields to targets
              if (my $m = maploopreplace($step->{map_match}, $maploop)) {
                if (defined($step->{map_replace})) { # replace can be null

                  # Can't modify entrykey
                  if ($fieldsource eq 'entrykey') {
                    if ($logger->is_debug()) { # performance tune
                      $logger->debug("Source mapping (type=$level, key=$etargetkey): Field '$fieldsource' is 'entrykey' - cannot remap the value of this field, skipping ...");
                    }
                    next;
                  }

                  my $r = maploopreplace($step->{map_replace}, $maploop);
                  if ($logger->is_debug()) { # performance tune
                    $logger->debug("Source mapping (type=$level, key=$etargetkey): Doing match/replace '$m' -> '$r' on field '$fieldsource'");
                  }
                  $etarget->set(encode('UTF-8', NFC($fieldsource)),
                                encode('UTF-8', NFC(ireplace($last_fieldval, $m, $r, $caseinsensitive))));
                }
                else {
                  # Now re-instate any unescaped $1 .. $n to get round these being
                  # dynamically scoped and being null when we get here from any
                  # previous map_match
                  # Be aware that imatch() uses m//g so @imatches can have multiple paren group
                  # captures which might be useful
                  $m =~ s/(?<!\\)\$(\d+)/$imatches[$1-1]/ge;
                  unless (@imatches = imatch($last_fieldval, $m, $negmatch, $caseinsensitive)) {
                    # Skip the rest of the map if this step doesn't match and match is final
                    if ($step->{map_final}) {
                      if ($logger->is_debug()) { # performance tune
                        $logger->debug("Source mapping (type=$level, key=$etargetkey): Field '$fieldsource' does not match '$m' and step has 'final' set, skipping rest of map ...");
                      }
                      next MAP;
                    }
                    else {
                      # just ignore this step
                      if ($logger->is_debug()) { # performance tune
                        $logger->debug("Source mapping (type=$level, key=$etargetkey): Field '$fieldsource' does not match '$m', skipping step ...");
                      }
                      next;
                    }
                  }
                }
              }

              # Set to a different target if there is one
              if (my $target = maploopreplace($step->{map_field_target}, $maploop)) {
                $target = fc($target);
                # Can't remap entry key pseudo-field
                if ($fieldsource eq 'entrykey') {
                  if ($logger->is_debug()) { # performance tune
                    $logger->debug("Source mapping (type=$level, key=$etargetkey): Field '$fieldsource' is 'entrykey'- cannot map this to a new field as you must have an entrykey, skipping ...");
                  }
                  next;
                }

                if ($etarget->exists($target)) {
                  if ($map->{map_overwrite} // $smap->{map_overwrite}) {
                    if ($logger->is_debug()) { # performance tune
                      $logger->debug("Source mapping (type=$level, key=$etargetkey): Overwriting existing field '$target'");
                    }
                  }
                  else {
                    if ($logger->is_debug()) { # performance tune
                      $logger->debug("Source mapping (type=$level, key=$etargetkey): Field '$fieldsource' is mapped to field '$target' but both are defined, skipping ...");
                    }
                    next;
                  }
                }
                # $target and $fieldsource are already casefolded, which is correct as it
                # does not come from Text::BibTeX's list of fields
                $etarget->set(encode('UTF-8', NFC($target)),
                              encode('UTF-8', NFC($entry->get(encode('UTF-8', NFC($fieldsource))))));
                $etarget->delete($fieldsource);
              }
            }

            # field changes
            if (my $field = maploopreplace($step->{map_field_set}, $maploop)) {
              $field = fc($field);
              # Deal with special tokens
              if ($step->{map_null}) {
                if ($logger->is_debug()) { # performance tune
                  $logger->debug("Source mapping (type=$level, key=$etargetkey): Deleting field '$field'");
                }
                $etarget->delete($field);
              }
              else {
                if ($etarget->exists($field)) {
                  unless ($map->{map_overwrite} // $smap->{map_overwrite}) {
                    if ($step->{map_final}) {
                      # map_final is set, ignore and skip rest of step
                      if ($logger->is_debug()) { # performance tune
                        $logger->debug("Source mapping (type=$level, key=$etargetkey): Field '$field' exists, overwrite is not set and step has 'final' set, skipping rest of map ...");
                      }
                      next MAP;
                    }
                    else {
                      # just ignore this step
                      if ($logger->is_debug()) { # performance tune
                        $logger->debug("Source mapping (type=$level, key=$etargetkey): Field '$field' exists and overwrite is not set, skipping step ...");
                      }
                      next;
                    }
                  }
                }

                my $orig = '';
                # If append or appendstrict is set, keep the original value
                # and append the new.
                if ($step->{map_append} or $step->{map_appendstrict}) {
                  # $field is already casefolded, which is correct as it does not come
                  # from Text::BibTeX's list of fields
                  $orig = $etarget->get(encode('UTF-8', NFC($field))) || '';
                }

                if ($step->{map_origentrytype}) {
                  next unless $last_type;
                  if ($logger->is_debug()) { # performance tune
                    $logger->debug("Source mapping (type=$level, key=$etargetkey): Setting field '$field' to '${orig}${last_type}'");
                  }
                  $etarget->set(encode('UTF-8', NFC($field)),
                                encode('UTF-8', NFC(appendstrict_check($step, $orig,$last_type))));
                }
                elsif ($step->{map_origfieldval}) {
                  next unless $last_fieldval;
                  if ($logger->is_debug()) { # performance tune
                    $logger->debug("Source mapping (type=$level, key=$etargetkey): Setting field '$field' to '${orig}${last_fieldval}'");
                  }
                  $etarget->set(encode('UTF-8', NFC($field)),
                                encode('UTF-8', NFC(appendstrict_check($step, $orig, $last_fieldval))));
                }
                elsif ($step->{map_origfield}) {
                  next unless $last_field;
                  if ($logger->is_debug()) { # performance tune
                    $logger->debug("Source mapping (type=$level, key=$etargetkey): Setting field '$field' to '${orig}${last_field}'");
                  }
                  $etarget->set(encode('UTF-8', NFC($field)),
                                encode('UTF-8', NFC(appendstrict_check($step, $orig, $last_field))));
                }
                else {
                  my $fv = maploopreplace($step->{map_field_value}, $maploop);
                  # Now re-instate any unescaped $1 .. $9 to get round these being
                  # dynamically scoped and being null when we get here from any
                  # previous map_match
                  $fv =~ s/(?<!\\)\$(\d)/$imatches[$1-1]/ge;
                  if ($logger->is_debug()) { # performance tune
                    $logger->debug("Source mapping (type=$level, key=$etargetkey): Setting field '$field' to '${orig}${fv}'");
                  }
                  $etarget->set(encode('UTF-8', NFC($field)),
                                encode('UTF-8', NFC(appendstrict_check($step, $orig, $fv))));
                }
              }
            }
          }
        }
      }
    }

    $crret = _create_entry($key, $entry);

    # reinstate original entry before modifications so that further refsections
    # have a clean slate
    $entry = $saved_entry;

    # Need to also instantiate fields in any new entries created by map
    while (my ($k, $e) = each %newentries) {
      _create_entry($k, $e);
    }
  }
  return $crret;
}

sub _create_entry {
  my ($k, $e) = @_;
  return 1 unless $e; # newentry might be undef
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $ds = $section->get_keytods($k);

  my $bibentry = Biber::Entry->new();

  $bibentry->set_field('citekey', $k);
  if ($logger->is_debug()) {# performance tune
    $logger->debug("Creating biber Entry object with key '$k'");
  }

  # Save pre-mapping data. Might be useful somewhere
  $bibentry->set_field('rawdata', $e->print_s);

  my $entrytype = $e->type;
  $bibentry->set_field('entrytype', fc($entrytype));

  # We put all the fields we find modulo field aliases into the object
  # validation happens later and is not datasource dependent
  foreach my $f ($e->fieldlist) {
    my $fc = fc($f);

    # We have to process local options as early as possible in order
    # to make them available for things that need them like parsename()
    if ($fc eq 'options') {
      my $value = $e->get(encode('UTF-8', NFC($f)));
      my $Srx = Biber::Config->getoption('xsvsep');
      my $S = qr/$Srx/;
      process_entry_options($k, [ split(/$S/, $value) ], $secnum);
    }

    # Now run any defined handler
    if ($dm->is_field($fc)) {
      # Check the Text::BibTeX field in case we have e.g. date = {}
      if ($e->get(encode('UTF-8', NFC($f))) ne '') {
        my $handler = _get_handler($fc);
        my $v = $handler->($bibentry, $e, $f, $k);
        if (defined($v)) {
          if ($v eq 'BIBER_SKIP_ENTRY') {# field data is bad enough to cause entry to be skipped
            return 0;
          }
          else {
            $bibentry->set_datafield($fc, $v);
          }
        }
      }
    }
    elsif (Biber::Config->getoption('validate_datamodel')) {
      biber_warn("Datamodel: $entrytype entry '$k' ($ds): Field '$f' invalid in data model - ignoring", $bibentry);
    }
  }

  $bibentry->set_field('datatype', 'bibtex');
  if ($logger->is_debug()) {# performance tune
    $logger->debug("Adding entry with key '$k' to entry list");
  }
  $section->bibentries->add_entry($k, $bibentry);
  return 1;
}

# HANDLERS
# ========

# Data annotation fields
sub _annotation {
  my ($bibentry, $entry, $field, $key) = @_;
  my $fc = fc($field); # Casefolded field which is what we need internally
  my $value = $entry->get(encode('UTF-8', NFC($field)));
  my $ann = quotemeta(Biber::Config->getoption('annotation_marker'));
  my $nam = quotemeta(Biber::Config->getoption('named_annotation_marker'));
  # Get annotation name, "default" if none
  my $name = 'default';
  if ($fc =~ s/^(.+$ann)$nam(.+)$/$1/) {
    $name = $2;
  }
  $fc =~ s/$ann$//;

  foreach my $a (split(/\s*;\s*/, $value)) {
    my ($count, $part, $annotations) = $a =~ /^\s*(\d+)?:?([^=]+)?=(.+)/;
    # Is the annotations a literal annotation?
    my $literal = 0;
    if ($annotations =~ m/^\s*"(.+)"\s*$/) {
      $literal = 1;
      $annotations = $1;
    }
    if ($part) {
      Biber::Annotation->set_annotation('part', $key, $fc, $name, $annotations, $literal, $count, $part);
    }
    elsif ($count) {
      Biber::Annotation->set_annotation('item', $key, $fc, $name, $annotations, $literal, $count);
    }
    else {
      Biber::Annotation->set_annotation('field', $key, $fc, $name, $annotations, $literal);
    }
  }
  return;
}

# Literal fields
sub _literal {
  my ($bibentry, $entry, $field, $key) = @_;
  my $fc = fc($field); # Casefolded field which is what we need internally
  my $value = $entry->get(encode('UTF-8', NFC($field)));

  # Record any XDATA and skip if we did
  if ($bibentry->add_xdata_ref($field, $value)) {
    return $value; # Return raw xdata
  }

  # If we have already split some date fields into literal fields
  # like date -> year/month/day, don't overwrite them with explicit
  # year/month
  if ($fc eq 'year') {
    return if $bibentry->get_datafield('year');
    if ($value and not looks_like_number(num($value))) {
      biber_warn("legacy year field '$value' in entry '$key' is not an integer - this will probably not sort properly.");
    }
  }
  if ($fc eq 'month') {
    return if $bibentry->get_datafield('month');
    if ($value and not looks_like_number(num($value))) {
      biber_warn("legacy month field '$value' in entry '$key' is not an integer - this will probably not sort properly.");
    }
  }

  # Deal with ISBN options
  if ($fc eq 'isbn') {
    require Business::ISBN;
    my ($vol, $dir, undef) = File::Spec->splitpath( $INC{"Business/ISBN.pm"} );
    $dir =~ s/\/$//;            # splitpath sometimes leaves a trailing '/'
    # Just in case it is already set. We also need to fake this in tests or it will
    # look for it in the blib dir
    unless (exists($ENV{ISBN_RANGE_MESSAGE})) {
      $ENV{ISBN_RANGE_MESSAGE} = File::Spec->catpath($vol, "$dir/ISBN/", 'RangeMessage.xml');
    }
    my $isbn = Business::ISBN->new($value);

    # Ignore invalid ISBNs
    if (not $isbn or not $isbn->is_valid) {
      biber_warn("ISBN '$value' in entry '$key' is invalid - run biber with '--validate_datamodel' for details.");
      return $value;
    }

    # Force to a specified format
    if (Biber::Config->getoption('isbn13')) {
      $isbn = $isbn->as_isbn13;
      $value = $isbn->isbn;
    }
    elsif (Biber::Config->getoption('isbn10')) {
      $isbn = $isbn->as_isbn10;
      $value = $isbn->isbn;
    }

    # Normalise if requested
    if (Biber::Config->getoption('isbn_normalise')) {
      $value = $isbn->as_string;
    }
  }

  # Try to sanitise months to biblatex requirements
  if ($fc eq 'month') {
    return _hack_month($value);
  }
  # Rationalise any BCP47 style langids into babel/polyglossia names
  # We need this until babel/polyglossia support proper BCP47 language/locales and then
  # biblatex needs to be changed as currently .lbx filenames are not BCP47 compliant
  elsif ($fc eq 'langid' and my $map = $LOCALE_MAP_R{$value}) {
    return $map;
  }
  else {
    return $value;
  }
}

# URI fields
sub _uri {
  my ($bibentry, $entry, $field) = @_;
  my $value = $entry->get(encode('UTF-8', NFC($field)));

  # Record any XDATA
  $bibentry->add_xdata_ref($field, $value);

  return $value;
}

# xSV field form
sub _xsv {
  my $Srx = Biber::Config->getoption('xsvsep');
  my $S = qr/$Srx/;
  my ($bibentry, $entry, $field) = @_;
  my $value = [ split(/$S/, $entry->get(encode('UTF-8', NFC($field)))) ];

  # Record any XDATA
  $bibentry->add_xdata_ref($field, $value);

  return $value ;
}

# Verbatim fields
sub _verbatim {
  my ($bibentry, $entry, $field) = @_;
  my $value = $entry->get(encode('UTF-8', NFC($field)));

  # Record any XDATA
  $bibentry->add_xdata_ref($field, $value);

  return $value;
}

# Range fields
# m-n -> [m, n]
# m   -> [m, undef]
# m-  -> [m, '']
# -n  -> ['', n]
# -   -> ['', undef]

sub _range {
  my ($bibentry, $entry, $field, $key) = @_;
  my $values_ref;
  my $value = $entry->get(encode('UTF-8', NFC($field)));

  # Record any XDATA and skip if we did
  if ($bibentry->add_xdata_ref($field, $value)) {
    return $value; # Return raw value
  }

  my @values = split(/\s*[;,]\s*/, $value);
  # If there is a range sep, then we set the end of the range even if it's null
  # If no range sep, then the end of the range is undef
  foreach my $value (@values) {
    my $ovalue = $value;
    $value =~ s/~/ /g; # Some normalisation for malformed fields
    $value =~ m/\A\s*(\P{Pd}+)\s*\z/xms ||# Simple value without range
      $value =~ m/\A\s*(\{[^\}]+\}|[^\p{Pd} ]+)\s*(\p{Pd}+)\s*(\{[^\}]+\}|\P{Pd}*)\s*\z/xms ||
        $value =~ m/\A\s*(.+)(\p{Pd}{2,})(.+)\s*\z/xms || # M-1--M-4
          $value =~ m/\A\s*(.+)(\p{Pd}+)(.+)\s*\z/xms;# blah M-1
        my $start = $1;
    my $end;
    if ($2) {
      $end = $3;
    }
    else {
      $end = undef;
    }
    $start =~ s/\A\{([^\}]+)\}\z/$1/;
    $end =~ s/\A\{([^\}]+)\}\z/$1/ if $end;
    if ($start) {
      push $values_ref->@*, [$start || '', $end];
    }
    else {
      biber_warn("Range field '$field' in entry '$key' is malformed, falling back to literal", $bibentry);
      push $values_ref->@*, [$ovalue, undef];
    }
  }
  return $values_ref;
}

# Names
sub _name {
  my ($bibentry, $entry, $field, $key) = @_;
  my $fc = fc($field); # Casefolded field which is what we need internally
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $value = $entry->get(encode('UTF-8', NFC($field)));
  my $xnamesep = Biber::Config->getoption('xnamesep');
  my $bee = $bibentry->get_field('entrytype');

  my $names = Biber::Entry::Names->new('type' => $fc);

  my @tmp = Text::BibTeX::split_list(NFC($value),# Unicode NFC boundary
                                     Biber::Config->getoption('namesep'),
                                     undef,
                                     undef,
                                     undef,
                                     {binmode => 'utf-8', normalization => 'NFD'});

  for (my $i = 0; $i <= $#tmp; $i++) {
    my $name = $tmp[$i];

    # Record any XDATA and skip if we did
    if ($bibentry->add_xdata_ref($field, $name, $i)) {
      # Add special xdata ref empty name as placeholder
      $names->add_name(Biber::Entry::Name->new(xdata => $name));
      next;
    }

    # per-namelist options
    if ($name =~ m/^(\S+)\s*$xnamesep\s*(\S+)?$/) {
      my $nlo = lc($1);
      my $nlov = $2 // 1; # bare options are just boolean numerals
      if (exists($CONFIG_SCOPEOPT_BIBLATEX{NAMELIST}{$nlo})) {
        my $oo = expand_option_input($nlo, $nlov, $CONFIG_BIBLATEX_OPTIONS{NAMELIST}{$nlo}{INPUT});

        foreach my $o ($oo->@*) {
          my $method = 'set_' . $o->[0];
          $names->$method($o->[1]);
        }
        next;
      }
    }

    # Consecutive "and" causes Text::BibTeX::Name to segfault
    unless ($name) {
      biber_warn("Name in key '$key' is empty (probably consecutive 'and'): skipping entry '$key'", $bibentry);
      $section->del_citekey($key);
      return 'BIBER_SKIP_ENTRY';
    }

    my $nps = join('|', $dm->get_constant_value('nameparts'));
    my $no;

    # extended name format
    my $xnamesep = Biber::Config->getoption('xnamesep');
    if ($name =~ m/(?:$nps)\s*$xnamesep/ and not Biber::Config->getoption('noxname')) {
      # Skip names that don't parse for some reason
      # uniquename defaults to 'false' just in case we are in tool mode otherwise
      # there are spurious uninitialised warnings

      next unless $no = parsename_x($section, $name, $fc, $key);
    }
    else { # Normal bibtex name format
      # Check for malformed names in names which aren't completely escaped
      # Too many commas
      unless ($name =~ m/\A\{\X+\}\z/xms) { # Ignore these tests for escaped names
        my @commas = $name =~ m/,/g;
        if ($#commas > 1) {
          biber_error("Name \"$name\" has too many commas, skipping entry '$key'", 1);
          $section->del_citekey($key);
          return 'BIBER_SKIP_ENTRY';
        }

        # Consecutive commas cause Text::BibTeX::Name to segfault
        if ($name =~ /,,/) {
          biber_error("Name \"$name\" is malformed (consecutive commas): skipping entry '$key'", 1);
          $section->del_citekey($key);
          return 'BIBER_SKIP_ENTRY';
        }
      }

      # Skip names that don't parse for some reason
      # unique name defaults to 0 just in case we are in tool mode otherwise there are spurious
      # uninitialised warnings
      next unless $no = parsename($section, $name, $fc);
    }

    # Deal with implied "et al" in data source
    if (lc($no->get_rawstring) eq Biber::Config->getoption('others_string')) {
      $names->set_morenames;
    }
    else {
      $names->add_name($no) if $no;
    }
  }

  # Don't set if there were no valid names due to special errors above
  return $names->count ? $names : undef;
}

# Dates
sub _datetime {
  my ($bibentry, $entry, $field, $key) = @_;
  my $datetype = $field =~ s/date\z//xmsr;
  my $date = $entry->get(encode('UTF-8', NFC($field)));
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $ds = $section->get_keytods($key);
  my $bee = $bibentry->get_field('entrytype');

  my ($sdate, $edate, $sep, $unspec) = parse_date_range($bibentry, $datetype, $date);

  # Date had unspecified format
  # This does not differ for *enddate components as these are split into ranges
  # from non-ranges only
  if ($unspec) {
    $bibentry->set_field($datetype . 'dateunspecified', $unspec);
  }

  if (defined($sdate)) { # Start date was successfully parsed
    if ($sdate) { # Start date is an object not "0"
      # Did this entry get its datepart fields from splitting an IS08601 date field?
      $bibentry->set_field("${datetype}datesplit", 1);

      # Some warnings for overwriting YEAR and MONTH from DATE
      if ($sdate->year and
          ($datetype . 'year' eq 'year') and
          $entry->get('year') and
          $sdate->year != $entry->get('year')) {
        biber_warn("Overwriting field 'year' with year value from field 'date' for entry '$key'", $bibentry);
      }
      if (not $CONFIG_DATE_PARSERS{start}->missing('month') and
          ($datetype . 'month' eq 'month') and
          $entry->get('month') and
          $sdate->month != $entry->get('month')) {
        biber_warn("Overwriting field 'month' with month value from field 'date' for entry '$key'", $bibentry);
      }

      # Save julian
      $bibentry->set_field($datetype . 'datejulian', 1) if $CONFIG_DATE_PARSERS{start}->julian;
      $bibentry->set_field($datetype . 'enddatejulian', 1) if $CONFIG_DATE_PARSERS{end}->julian;

      # Save approximate information
      $bibentry->set_field($datetype . 'dateapproximate', 1) if $CONFIG_DATE_PARSERS{start}->approximate;
      $bibentry->set_field($datetype . 'enddateapproximate', 1) if $CONFIG_DATE_PARSERS{end}->approximate;

      # Save uncertain date information
      $bibentry->set_field($datetype . 'dateuncertain', 1) if $CONFIG_DATE_PARSERS{start}->uncertain;
      $bibentry->set_field($datetype . 'enddateuncertain', 1) if $CONFIG_DATE_PARSERS{end}->uncertain;

      # Save start yeardivision date information
      if (my $yeardivision = $CONFIG_DATE_PARSERS{start}->yeardivision) {
        $bibentry->set_field($datetype . 'yeardivision', $yeardivision);
      }

      unless ($CONFIG_DATE_PARSERS{start}->missing('year')) {
        $bibentry->set_datafield($datetype . 'year',
                                 $CONFIG_DATE_PARSERS{start}->resolvescript($sdate->year));
        # Save era date information
        $bibentry->set_field($datetype . 'era', lc($sdate->secular_era));
      }

      $bibentry->set_datafield($datetype . 'month',
                               $CONFIG_DATE_PARSERS{start}->resolvescript($sdate->month))
        unless $CONFIG_DATE_PARSERS{start}->missing('month');

      $bibentry->set_datafield($datetype . 'day',
                               $CONFIG_DATE_PARSERS{start}->resolvescript($sdate->day))
        unless $CONFIG_DATE_PARSERS{start}->missing('day');

      # time
      unless ($CONFIG_DATE_PARSERS{start}->missing('time')) {
        $bibentry->set_datafield($datetype . 'hour',
                                 $CONFIG_DATE_PARSERS{start}->resolvescript($sdate->hour));
        $bibentry->set_datafield($datetype . 'minute',
                                 $CONFIG_DATE_PARSERS{start}->resolvescript($sdate->minute));
        $bibentry->set_datafield($datetype . 'second',
                                 $CONFIG_DATE_PARSERS{start}->resolvescript($sdate->second));
        unless ($sdate->time_zone->is_floating) { # ignore floating timezones
          $bibentry->set_datafield($datetype . 'timezone', tzformat($sdate->time_zone->name));
        }
      }
    }
    else { # open ended range - startdate is defined but empty
      $bibentry->set_datafield($datetype . 'year', '');
    }

    # End date can be missing
    if ($sep) {
      if (defined($edate)) { # End date was successfully parsed
        if ($edate) { # End date is an object not "0"
          # Did this entry get its datepart fields from splitting an ISO8601-2 date field?
          $bibentry->set_field("${datetype}datesplit", 1);

          unless ($CONFIG_DATE_PARSERS{end}->missing('year')) {
            $bibentry->set_datafield($datetype . 'endyear',
                                     $CONFIG_DATE_PARSERS{end}->resolvescript($edate->year));
            # Save era date information
            $bibentry->set_field($datetype . 'endera', lc($edate->secular_era));
          }

          $bibentry->set_datafield($datetype . 'endmonth',
                                   $CONFIG_DATE_PARSERS{end}->resolvescript($edate->month))
            unless $CONFIG_DATE_PARSERS{end}->missing('month');

          $bibentry->set_datafield($datetype . 'endday',
                                   $CONFIG_DATE_PARSERS{end}->resolvescript($edate->day))
            unless $CONFIG_DATE_PARSERS{end}->missing('day');

          # Save end yeardivision date information
          if (my $yeardivision = $CONFIG_DATE_PARSERS{end}->yeardivision) {
            $bibentry->set_field($datetype . 'endyeardivision', $yeardivision);
            $bibentry->set_field($datetype . 'endseaason', $yeardivision); # legacy
          }

          # must be an hour if there is a time but could be 00 so use defined()
          unless ($CONFIG_DATE_PARSERS{end}->missing('time')) {
            $bibentry->set_datafield($datetype . 'endhour',
                                     $CONFIG_DATE_PARSERS{end}->resolvescript($edate->hour));
            $bibentry->set_datafield($datetype . 'endminute',
                                    $CONFIG_DATE_PARSERS{end}->resolvescript($edate->minute));
            $bibentry->set_datafield($datetype . 'endsecond',
                                     $CONFIG_DATE_PARSERS{end}->resolvescript($edate->second));
            unless ($edate->time_zone->is_floating) { # ignore floating timezones
              $bibentry->set_datafield($datetype . 'endtimezone', tzformat($edate->time_zone->name));
            }
          }
        }
        else { # open ended range - enddate is defined but empty
          $bibentry->set_datafield($datetype . 'endyear', '');
        }
      }
      else {
        biber_warn("$bee entry '$key' ($ds): Invalid format '$date' of end date field '$field' - ignoring", $bibentry);
      }
    }
  }
  else {
    biber_warn("$bee entry '$key' ($ds): Invalid format '$date' of date field '$field' - ignoring", $bibentry);
  }
  return;
}

# Bibtex list fields with listsep separator
sub _list {
  my ($bibentry, $entry, $field) = @_;
  my $value = $entry->get(encode('UTF-8', NFC($field)));

  my @tmp = Text::BibTeX::split_list(NFC($value),# Unicode NFC boundary
                                     Biber::Config->getoption('listsep'),
                                     undef,
                                     undef,
                                     undef,
                                     {binmode => 'utf-8', normalization => 'NFD'});
  @tmp = map { (remove_outer($_))[1] } @tmp;
  my @result;

  for (my $i = 0; $i <= $#tmp; $i++) {
    my $e = $tmp[$i];

    # Record any XDATA and skip if we did
    $bibentry->add_xdata_ref($field, $e, $i);

    push @result, $e;
  }

  return [ @result ];
}

# Bibtex uri lists
sub _urilist {
  my ($bibentry, $entry, $field) = @_;
  my $value = $entry->get(encode('UTF-8', NFC($field)));

  # Unicode NFC boundary (passing to external library)
  my @tmp = Text::BibTeX::split_list(NFC($value),
                                     Biber::Config->getoption('listsep'),
                                     undef,
                                     undef,
                                     undef,
                                     {binmode => 'utf-8', normalization => 'NFD'});
  my @result;

  for (my $i = 0; $i <= $#tmp; $i++) {
    my $e = $tmp[$i];

    # Record any XDATA and skip if we did
    $bibentry->add_xdata_ref($field, $e, $i);

    push @result, $e;
  }

  return [ @result ];

}

=head2 cache_data

   Caches file data into T::B objects indexed by the original
   datasource key, decoded into UTF8

=cut

sub cache_data {
  my ($filename, $encoding) = @_;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);

  # Initialise this
  $cache->{preamble}{$filename} = [];

  # Convert/decode file
  my $pfilename = preprocess_file($filename, $encoding);

  my $bib = Text::BibTeX::File->new();
  $bib->open($pfilename, {binmode => 'utf-8', normalization => 'NFD'}) or biber_error("Cannot create Text::BibTeX::File object from $pfilename: $!");

  # Log that we found a data file
  $logger->info("Found BibTeX data source '$filename'");

  while ( my $entry = Text::BibTeX::Entry->new($bib) ) {
    if ( $entry->metatype == BTE_PREAMBLE ) {
      push $cache->{preamble}{$filename}->@*, $entry->value;
      next;
    }
    # Save comments for output in tool mode unless comment stripping is requested
    elsif ( $entry->metatype == BTE_COMMENT ) {
      if (Biber::Config->getoption('tool') and not
          Biber::Config->getoption('strip_comments') ) {
        push $cache->{comments}{$filename}->@*, process_comment($entry->value);
      }
      next;
    }
    # Record macros in T::B so we can output then properly in tool mode
    elsif ($entry->metatype == BTE_MACRODEF) {
      foreach my $f ($entry->fieldlist) {
        $RSTRINGS{$entry->get($f)} = $f;
      }
      next;
    }


    # Ignore misc BibTeX entry types we don't care about
    next if ( $entry->metatype == BTE_UNKNOWN );

    # If an entry has no key, ignore it and warn
    unless ($entry->key) {
      biber_warn("Invalid or undefined BibTeX entry key in file '$pfilename', skipping ...");
      next;
    }

    # Text::BibTeX >= 0.46 passes through all citekey bits, thus allowing UTF-8 keys
    my $key = $entry->key;

    # Check if this key has already been registered as a citekey alias, if
    # so, the key takes priority and we delete the alias
    if (exists($cache->{data}{citekey_aliases}{$key})) {
      biber_warn("Citekey alias '$key' is also a real entry key, skipping ...");
      delete($cache->{data}{citekey_aliases}{$key});
    }

    # Any secondary keys?
    # We can't do this with a driver dispatch for the IDS field as this needs
    # an entry object creating first and the whole point of aliases is that
    # there is no entry object
    if (my $ids = $entry->get('ids')) {
      my $Srx = Biber::Config->getoption('xsvsep');
      my $S = qr/$Srx/;
      foreach my $id (split(/$S/, $ids)) {

        # Skip aliases which are this very key (deep recursion ...)
        if ($id eq $key) {
          biber_warn("BAD RECURSION! Entry alias '$id' is identical to the entry key, skipping ...");
          next;
        }

        # Skip aliases which are also real entry keys
        if ($section->has_everykey($id)) {
          biber_warn("Entry alias '$id' is also a real entry key, skipping ...");
          next;
        }

        # Warn on conflicting aliases
        if (exists($cache->{data}{citekey_aliases}{$id})) {
          my $otherid = $cache->{data}{citekey_aliases}{$id};
          if ($otherid ne $key) {
            biber_warn("Entry alias '$id' already has an alias '$otherid', skipping ...");
          }
        }
        else {
          $cache->{data}{citekey_aliases}{$id} = $key;
          if ($logger->is_debug()) {# performance tune
            $logger->debug("Entry alias '$id' is an alias for citekey '$key'");
          }
        }
      }
    }

    # If we've already seen a case variant, warn
    # This is case mismatch test of datasource entries with other datasource entries
    if (my $okey = $section->has_badcasekey($key)) {
      biber_warn("Possible typo (case mismatch) between datasource keys: '$key' and '$okey' in file '$filename'");
    }

    # If we've already seen this key in a datasource, ignore it and warn unless user wants
    # duplicates
    if ($section->has_everykey($key) and not Biber::Config->getoption('noskipduplicates')) {
      biber_warn("Duplicate entry key: '$key' in file '$filename', skipping ...");
      next;
    }
    else {
      if ($section->has_everykey($key)) {
        biber_warn("Duplicate entry key: '$key' in file '$filename'");
      }
      $section->add_everykey($key);
    }

    # Bad entry
    unless ($entry->parse_ok) {
      biber_warn("Entry $key does not parse correctly");
      next;
    }

    # Cache the entry so we don't have to read the file again on next pass.
    # Two reasons - So we avoid T::B macro redef warnings and speed
    # Create a global "all datasources" cache too as this is useful in places
    $cache->{data}{GLOBALDS}{$key} = $cache->{data}{$filename}{$key} = $entry;
    # We do this as otherwise we have no way of determining the original .bib entry order
    # We need this in order to do sorting=none + allkeys because in this case, there is no
    # "citeorder" because nothing is explicitly cited and so "citeorder" means .bib order
    push $cache->{orig_key_order}{$filename}->@*, $key;
    if ($logger->is_debug()) {# performance tune
      $logger->debug("Cached Text::BibTeX entry for key '$key' from BibTeX file '$filename'");
    }
  }

  $bib->close; # If we don't do this, we can't unlink the temp file on Windows
  return;
}


=head2 preprocess_file

   Convert file to UTF-8 and potentially decode LaTeX macros to UTF-8

=cut

sub preprocess_file {
  my ($filename, $benc) = @_;

  # Put the utf8 encoded file into the global biber tempdir
  # We have to do this in case we can't write to the location of the
  # .bib file
  my $td = $Biber::MASTER->biber_tempdir;
  (undef, undef, my $fn) = File::Spec->splitpath($filename);

  # The filename that Text::BibTeX actually opens cannot be UTF-8 on Windows as there is no
  # way to do this with the correct Win32::Unicode:File calls and so we normalise to a hash
  # of the name so that it will work cross-platform.
  my $fnh = md5_hex(encode_utf8(NFC($fn)));
  my $ufilename = File::Spec->catfile($td->dirname, "${fnh}_$$.utf8");
  $logger->debug("File '$fn' is converted to UTF8 as '$ufilename'");

  # We read the file in the bib encoding and then output to UTF-8, even if it was already UTF-8,
  # just in case there was a BOM so we can delete it as it makes T::B complain
  # Might fail due to encountering characters invalid in the encoding so trap and die gracefully
  if ($benc eq 'ascii') {
    $logger->info("Reading ascii input as UTF-8");
    $benc = 'UTF-8';
  }
  my $buf;
  unless (eval{$buf = NFD(slurp_switchr($filename, $benc)->$*)}) {# Unicode NFD boundary
    biber_error("Data file '$filename' cannot be read in encoding '$benc': $@");
  }

  # strip UTF-8 BOM if it exists - this just makes T::B complain about junk characters
  $buf =~ s/\A\x{feff}//;

  # Normalise line breaks because libbtparse can't handle things like CR only
  # in some circumstances
  $buf =~ s/\R/\n/g;

  slurp_switchw($ufilename, $buf);# Unicode NFC boundary

  my $lbuf = parse_decode($ufilename);

  if ($logger->is_trace()) {# performance tune
    $logger->trace("Buffer after decoding -> '$lbuf'");
  }

  slurp_switchw($ufilename, $lbuf);# Unicode NFC boundary

  return $ufilename;
}

=head2 parse_decode

  Partially parse the .bib datasource and latex_decode the data contents.
  We do this because latex_decoding the entire buffer is difficult since
  such decoding is regexp based and since braces are used to protect data in
  .bib files, it makes it hard to do some parsing.

=cut

sub parse_decode {
  my $ufilename = shift;
  my $dmh = Biber::Config->get_dm_helpers;
  my $lbuf;

  my $bib = Text::BibTeX::File->new();
  $bib->open($ufilename, {binmode => 'utf-8', normalization => 'NFD'}) or biber_error("Cannot create Text::BibTeX::File object from $ufilename: $!");

  $logger->info("LaTeX decoding ...");

  while ( my $entry = Text::BibTeX::Entry->new($bib) ) {
  if ( $entry->metatype == BTE_REGULAR ) {
      $lbuf .= '@' . $entry->type . '{' . $entry->key . ',' . "\n";
      foreach my $f ($entry->fieldlist) {
        my $fv = $entry->get(encode('UTF-8', NFC($f))); # NFC boundary: $f is "output" to Text::BibTeX

        # Don't decode verbatim fields
        if (not first {fc($f) eq fc($_)} $dmh->{verbs}->@*) {
          $fv = Biber::LaTeX::Recode::latex_decode($fv);
        }
        $lbuf .= "  $f = {$fv},\n";
      }
      $lbuf .= "\n" . '}' . "\n\n";
    }
    elsif ($entry->metatype == BTE_PREAMBLE) {
      $lbuf .= '@PREAMBLE{"';
      $lbuf .= $entry->value;
      $lbuf .=  '"}' . "\n";
    }
    elsif ($entry->metatype == BTE_COMMENT) {
      $lbuf .= '@COMMENT{';
      $lbuf .= $entry->value;
      $lbuf .=  '}' . "\n";
    }
    elsif ($entry->metatype == BTE_MACRODEF) {
      $lbuf .= '@STRING{';
      foreach my $f ($entry->fieldlist) {
        $lbuf .= $f . ' = {' . $entry->get(encode('UTF-8', NFC($f))) . '}';
      }
      $lbuf .= "}\n";
    }
    else {
      $lbuf .= Biber::LaTeX::Recode::latex_decode($entry->print_s);
    }
  }

  # (Re-)define the old BibTeX month macros to what biblatex wants unless user stops this
  unless (Biber::Config->getoption('nostdmacros')) {
    foreach my $mon (keys %MONTHS) {
      Text::BibTeX::add_macro_text($mon, $MONTHS{$mon});
    }
  }

  $bib->close;

  return $lbuf;
}

=head2 parsename

    Given a name string, this function returns a Biber::Entry::Name object
    with all parts of the name resolved according to the BibTeX conventions.

    parsename('John Doe', 'author', 'key')
    returns an object which internally looks a bit like this:

    { given          => {string => 'John', initial => ['J']},
      family         => {string => 'Doe', initial => ['D']},
      prefix         => {string => undef, initial => undef},
      suffix         => {string => undef, initial => undef},
      id             => 32RS0Wuj0P,
      strip          => {'given'  => 0,
                         'family' => 0,
                         'prefix' => 0,
                         'suffix' => 0}
      }

=cut

sub parsename {
  my ($section, $namestr, $fieldname) = @_;

  # First sanitise the namestring due to Text::BibTeX::Name limitations on whitespace
  $namestr =~ s/\A\s*|\s*\z//xms; # leading and trailing whitespace
  # Collapse internal whitespace and escaped spaces like in "Christina A. L.\ Thiele"
  $namestr =~ s/\s+|\\\s/ /g;
  $namestr =~ s/\A\{\{+([^\{\}]+)\}+\}\z/{$1}/xms; # Allow only one enveloping set of braces

  # If requested, try to correct broken initials with no space between them.
  # This can slightly mess up some other names like {{U.K. Government}} etc.
  # btparse can't do this so we do it before name parsing
  $namestr =~ s/(\w)\.(\w)/$1. $2/g if Biber::Config->getoption('fixinits');

  my %namec;
  my $name = Text::BibTeX::Name->new({binmode => 'utf-8', normalization => 'NFD'}, NFC($namestr));

  # Formats so we can get BibTeX compatible nbsp inserted
  my $l_f = Text::BibTeX::NameFormat->new('l', 0);
  my $f_f = Text::BibTeX::NameFormat->new('f', 0);
  my $p_f = Text::BibTeX::NameFormat->new('v', 0);
  my $s_f = Text::BibTeX::NameFormat->new('j', 0);
  $l_f->set_options(BTN_LAST,  0, BTJ_MAYTIE, BTJ_NOTHING);
  $f_f->set_options(BTN_FIRST, 0, BTJ_MAYTIE, BTJ_NOTHING);
  $p_f->set_options(BTN_VON,   0, BTJ_MAYTIE, BTJ_NOTHING);
  $s_f->set_options(BTN_JR,    0, BTJ_MAYTIE, BTJ_NOTHING);

  # Generate name parts
  $namec{family} = $name->format($l_f);
  $namec{given}  = $name->format($f_f);
  $namec{prefix} = $name->format($p_f);
  $namec{suffix} = $name->format($s_f);

  # Not using Text::BibTeX for initials generation as it can't handle combining
  # chars and diacritics in general

  # basic bibtex names have a fixed data model
  foreach my $np ('prefix', 'family', 'given', 'suffix') {
    if ($namec{$np}) {
      ($namec{"${np}-strippedflag"}, $namec{"${np}-stripped"}) = remove_outer($namec{$np});

      # Protect spaces inside {} when splitting to produce initials
      my $part = $namec{$np};
      if ($namec{"${np}-strippedflag"}) {
        $part = $namec{$np} =~ s/\s+/_/gr;
      }

      # strip noinit
      $part = strip_noinit($part);

      # split on spaces/tilde outside of brace block
      $namec{"${np}-i"} = [gen_initials(split(/[\h~]+(?![^{]*\})/, $part))];
    }
  }

  my %nameparts;
  my $strip;
  foreach my $np ('prefix', 'family', 'given', 'suffix') {
    $nameparts{$np} = {string  => $namec{"${np}-stripped"} // undef,
                       initial => $namec{$np} ? $namec{"${np}-i"} : undef};
    $strip->{$np} = $namec{"${np}-strippedflag"};

    # Record max namepart lengths
    $section->set_np_length($np, length($nameparts{$np}{string})) if $nameparts{$np}{string};
    $section->set_np_length("${np}-i", length(join('', $nameparts{$np}{initial}->@*))) if $nameparts{$np}{initial};
  }

  # The "strip" entry tells us which of the name parts had outer braces
  # stripped during processing so we can add them back when printing the
  # .bbl so as to maintain maximum BibTeX compatibility
  return  Biber::Entry::Name->new(
                                  %nameparts,
                                  strip => $strip
                                 );
}

=head2 parsename_x

    Given a name string in extended format, this function returns a Biber::Entry::Name object
    with all parts of the name resolved according to the BibTeX conventions.

    parsename_x('given=John, family=Doe')
    returns an object which internally looks a bit like this:

    { given          => {string => 'John', initial => ['J']},
      family         => {string => 'Doe', initial => ['D']},
      prefix         => {string => undef, initial => undef},
      suffix         => {string => undef, initial => undef},
      id             => 32RS0Wuj0P,
      hashid         => 'someid',
      sortingnamekeytemplatename => 'template name',
    }

=cut

sub parsename_x {
  my ($section, $namestr, $fieldname, $key) = @_;
  my $xnamesep = Biber::Config->getoption('xnamesep');
  my %nps = map {$_ => 1} $dm->get_constant_value('nameparts');

  my %namec;
  my %pernameopts;
  foreach my $np (split_xsv($namestr)) {# Can have x inside records so use Text::CSV
    my ($npn, $npv) = $np =~ m/^(.+)\s*$xnamesep\s*(.+)$/x;
    $npn = lc($npn);

    # per-name options
    if (exists($CONFIG_SCOPEOPT_BIBLATEX{NAME}{$npn})) {
      my $oo = expand_option_input($npn, $npv, $CONFIG_BIBLATEX_OPTIONS{NAME}{$npn}{INPUT});

      foreach my $o ($oo->@*) {
        $pernameopts{$o->[0]} = $o->[1];
      }
      next;
    }

    unless ($nps{$npn =~ s/-i$//r} or $npn eq 'id') {# this is the hashid, not the internal unique ID
      biber_warn("Invalid namepart option '$npn' found in extended name format name '$fieldname' in entry '$key', ignoring");
      next;
    }

    if ($npn =~ m/-i$/) {
      $namec{$npn} = _split_initials($npv);
    }
    elsif ($npn eq 'id') { # hashid
      $namec{hashid} = $npv;
    }
    else {
      # Don't tie according to bibtex rules if the namepart is protected with braces
      if (has_outer($npv)) {
        $namec{$npn} = $npv;
      }
      else {
        $namec{$npn} = join_name_parts([split(/\s+/,$npv)]);
      }
    }
  }

  foreach my $np (keys %nps) {
    if (exists($namec{$np})) {
      # Generate any stripped information
      (my $s, $namec{$np}) = remove_outer($namec{$np});

      # Protect spaces inside {} when splitting to produce intials
      my $part = $namec{$np};
      if ($s) {
        $part = $namec{$np} =~ s/\s+/_/gr;
      }

      # strip noinit
      $part = strip_noinit($part);

      # Generate any initials which are missing
      if (not exists($namec{"${np}-i"})) {
        $namec{"${np}-i"} = [gen_initials(split(/[\s~]+/, $part))];
      }
    }
  }

  my %nameinfo;
  foreach my $np (keys %nps) {
    $nameinfo{$np} = {string  => $namec{$np} // undef,
                       initial => exists($namec{$np}) ? $namec{"${np}-i"} : undef};

    # Record max namepart lengths
    $section->set_np_length($np, length($nameinfo{$np}{string}))  if $nameinfo{$np}{string};
    $section->set_np_length("${np}-i", length(join('', $nameinfo{$np}{initial}->@*)))  if $nameinfo{$np}{initial};
  }

  # Add hashid if it exists
  if (exists($namec{hashid})) {
    $nameinfo{hashid} = $namec{hashid};
  }

  # The "strip" entry tells us which of the name parts had outer braces
  # stripped during processing so we can add them back when printing the
  # .bbl so as to maintain maximum BibTeX compatibility
  return  Biber::Entry::Name->new(
                                  %nameinfo,
                                  %pernameopts
                                 );
}

# Routine to try to hack month into the right biblatex format
# Especially since we support remote .bibs which we potentially have no control over
my %months = (
              'jan' => '1',
              'feb' => '2',
              'mar' => '3',
              'apr' => '4',
              'may' => '5',
              'jun' => '6',
              'jul' => '7',
              'aug' => '8',
              'sep' => '9',
              'oct' => '10',
              'nov' => '11',
              'dec' => '12'
             );

sub _hack_month {
  my $in_month = shift;
  if (my ($m) = $in_month =~ m/\A\s*((?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec).*)\s*\z/i) {
    return $months{lc(Unicode::GCString->new($m)->substr(0,3)->as_string)};
  }
  else {
    return $in_month;
  }
}

sub _get_handler {
  my $field = shift;
  my $ann = $CONFIG_META_MARKERS{annotation};
  my $nam = $CONFIG_META_MARKERS{namedannotation};
  if ($field =~ m/$ann(?:$nam.+)?$/) {
    return $handlers->{custom}{annotation};
  }
  else {
    return $handlers->{$dm->get_fieldtype($field)}{$dm->get_fieldformat($field) || 'default'}{$dm->get_datatype($field)};
  }
}

# "ab{cd}e" -> [a,b,cd,e]
sub _split_initials {
  my $npv = shift;
  my @npv;
  my $ci = 0;
  my $acc;

  foreach my $c (split(/\b{gcb}/, $npv)) {
    # entering compound initial
    if ($c eq '{') {
      $ci = 1;
    }
    # exiting compound initial, push accumulator and reset
    elsif ($c eq '}') {
      $ci = 0;
      push @npv, $acc;
      $acc = '';
    }
    else {
      if ($ci) {
        $acc .= $c;
      }
      else {
        push @npv, $c;
      }
    }
  }
  return \@npv;
}


1;

__END__

=pod

=encoding utf-8

=head1 NAME

Biber::Input::file::bibtex - look in a BibTeX file for an entry and create it if found

=head1 DESCRIPTION

Provides the extract_entries() method to get entries from a BibTeX data source
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
