package Biber::Input::file::bibtex;
use v5.16;
use strict;
use warnings;
use sigtrap qw(handler TBSIG SEGV);

use Carp;
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
use File::Slurp;
use File::Temp;
use Log::Log4perl qw(:no_extra_logdie_message);
use List::AllUtils qw( :all );
use URI;
use Unicode::Normalize;
use Unicode::GCString;
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
                'CUSTOM' => {'annotation' => \&_annotation},
                'field' => {
                            'default'  => {
                                           'code'     => \&_literal,
                                           'date'     => \&_date,
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
  my ($source, $keys) = @_;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $filename;
  my @rkeys = @$keys;
  my $tf; # Up here so that the temp file has enough scope to survive until we've used it
  $logger->trace("Entering extract_entries() in driver 'bibtex'");

  # Get a reference to the correct sourcemap sections, if they exist
  my $smaps = [];
  # Maps are applied in order USER->STYLE->DRIVER
  if (defined(Biber::Config->getoption('sourcemap'))) {
    # User maps
    if (my $m = first {$_->{datatype} eq 'bibtex' and $_->{level} eq 'user' } @{Biber::Config->getoption('sourcemap')} ) {
      push @$smaps, $m;
    }
    # Style maps
    if (my $m = first {$_->{datatype} eq 'bibtex' and $_->{level} eq 'style' } @{Biber::Config->getoption('sourcemap')} ) {
      push @$smaps, $m;
    }
    # Driver default maps
    if (my $m = first {$_->{datatype} eq 'bibtex' and $_->{level} eq 'driver'} @{Biber::Config->getoption('sourcemap')} ) {
      push @$smaps, $m;
    }
  }

  # If it's a remote data file, fetch it first
  if ($source =~ m/\A(?:http|ftp)(s?):\/\//xms) {
    $logger->info("Data source '$source' is a remote BibTeX data source - fetching ...");
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
                            SUFFIX => '.bib');
      unless (LWP::Simple::is_success(LWP::Simple::getstore($source, $tf->filename))) {
        biber_error("Could not fetch '$source'");
      }
      $filename = $tf->filename;
      # cache any remote so it persists and so we don't fetch it again
      $REMOTE_MAP{$source} = $filename;
    }
  }
  else {
    # Need to get the filename even if using cache so we increment
    # the filename count for preambles at the bottom of this sub
    unless ($filename = locate_biber_file($source)) {
      biber_error("Cannot find '$source'!")
    }
  }

  # Text::BibTeX can't be controlled by Log4perl so we have to do something clumsy
  # We can't redirect STDERR to a variable as libbtparse doesnt' use PerlIO, just stdio
  # so it doesn't understand this. It does understand normal file redirection though as
  # that's standard stdio.
  # The Log4Perl setup outputs only to STDOUT so redirecting all STDERR like this is
  # ok since only libbtparse will be writing there
  my $tberr = File::Temp->new(TEMPLATE => 'biber_Text_BibTeX_STDERR_XXXXX',
                              DIR      => $Biber::MASTER->biber_tempdir);
  my $tberr_name = $tberr->filename;
  open OLDERR, '>&', \*STDERR;
  open STDERR, '>', $tberr_name;

  # Increment the number of times each datafile has been referenced
  # For example, a datafile might be referenced in more than one section.
  # Some things find this information useful, for example, setting preambles is global
  # and so we need to know if we've already saved the preamble for a datafile.
  $cache->{counts}{$filename}++;

  # Don't read the file again if it's already cached
  unless ($cache->{data}{$filename}) {
    $logger->debug("Caching data for BibTeX format file '$filename' for section $secnum");
    cache_data($filename);
  }
  else {
    $logger->debug("Using cached data for BibTeX format file '$filename' for section $secnum");
  }

  if ($section->is_allkeys) {
    $logger->debug("All citekeys will be used for section '$secnum'");
    # Loop over all entries, creating objects
    while (my ($key, $entry) = each %{$cache->{data}{$filename}}) {

      # Record a key->datasource name mapping for error reporting
      $section->set_keytods($key, $filename);

      unless (create_entry($key, $entry, $source, $smaps, \@rkeys)) {
        # if create entry returns false, remove the key from the cache
        @{$cache->{orig_key_order}{$filename}} = grep {$key ne $_} @{$cache->{orig_key_order}{$filename}};
      }
    }

    # Loop over all aliases, creating data in section object
    # Since this is allkeys, we are guaranteed that the real entry for the alias
    # will be available
    while (my ($alias, $key) = each %{$cache->{data}{citekey_aliases}}) {
      $section->set_citekey_alias($alias, $key);
    }

    # If allkeys, push all bibdata keys into citekeys (if they are not already there).
    # We are using the special "orig_key_order" array which is used to deal with the
    # situation when sorting=none and allkeys is set. We need an array rather than the
    # keys from the bibentries hash because we need to preserve the original order of
    # the .bib as in this case the sorting sub "citeorder" means "bib order" as there are
    # no explicitly cited keys
    $section->add_citekeys(@{$cache->{orig_key_order}{$filename}});
    $logger->debug("Added all citekeys to section '$secnum': " . join(', ', $section->get_citekeys));
    # Special case when allkeys but also some dynamic set entries. These keys must also be
    # in the section or they will be missed on output.
    if ($section->has_dynamic_sets) {
      $section->add_citekeys(@{$section->dynamic_set_keys});
      $logger->debug("Added dynamic sets to section '$secnum': " . join(', ', @{$section->dynamic_set_keys}));
    }
  }
  else {
    # loop over all keys we're looking for and create objects
    $logger->debug('Text::BibTeX cache keys: ' . join(', ', keys %{$cache->{data}{$filename}}));
    $logger->debug('Wanted keys: ' . join(', ', @$keys));
    foreach my $wanted_key (@$keys) {
      $logger->debug("Looking for key '$wanted_key' in Text::BibTeX cache");

      # Record a key->datasource name mapping for error reporting
      $section->set_keytods($wanted_key, $filename);

      if (my $entry = $cache->{data}{$filename}{$wanted_key}) {
        $logger->debug("Found key '$wanted_key' in Text::BibTeX cache");

        # Skip creation if it's already been done, for example, via a citekey alias
        unless ($section->bibentries->entry_exists($wanted_key)) {
          create_entry($wanted_key, $entry, $source, $smaps, \@rkeys);
        }
        # found a key, remove it from the list of keys we want
        @rkeys = grep {$wanted_key ne $_} @rkeys;

      }
      elsif (my $rk = $cache->{data}{citekey_aliases}{$wanted_key}) {
        $section->set_citekey_alias($wanted_key, $rk);

        # Make sure there is a real, cited entry for the citekey alias
        # just in case only the alias is cited
        unless ($section->bibentries->entry_exists($rk)) {
          if (my $entry = $cache->{data}{GLOBALDS}{$rk}) {# Look in cache of all datasource keys
            create_entry($rk, $entry, $source, $smaps, \@rkeys);
            $section->add_citekeys($rk);
          }
        }

        # found an alias key, remove it from the list of keys we want
        @rkeys = grep {$wanted_key ne $_} @rkeys;

      }
      elsif (my $okey = $section->has_badcasekey($wanted_key)) {
        biber_warn("Possible typo (case mismatch) between citation and datasource keys: '$wanted_key' and '$okey' in file '$filename'");
      }

      $logger->debug('Wanted keys now: ' . join(', ', @rkeys));
    }
  }

  open STDERR, '>&', \*OLDERR;
  close OLDERR;

  # Put any Text::BibTeX errors into the biber warnings/errors collections
  # We are parsing the libbtparse library error/warning strings a little here
  # This is not so bad as they have a clean structure (see error.c in libbtparse)
  open my $tbe, '<', $tberr_name;
  while (<$tbe>) {
    if (/error:/) {
      chomp;
      biber_error("BibTeX subsystem: $_");
    }
    elsif (/warning:/) {
      chomp;
      biber_warn("BibTeX subsystem: $_");
    }
  }
  close($tbe);

  # Only push the preambles from the file if we haven't seen this data file before
  # and there are some preambles to push
  if ($cache->{counts}{$filename} < 2 and @{$cache->{preamble}{$filename}}) {
    push @{$Biber::MASTER->{preamble}}, @{$cache->{preamble}{$filename}};
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

  if ( $entry->metatype == BTE_REGULAR ) {
    my %newentries; # In case we create a new entry in a map

    # Only process maps once for each entry in the cache. The cache is persistent across
    # refsections and so the first refsection will process sourcemaps and alter the cache.
    unless ($cache->{data}{$key}{mapdone}) {
      # Datasource mapping applied in $smap order (USER->STYLE->DRIVER)
      foreach my $smap (@$smaps) {
        $smap->{map_overwrite} = $smap->{map_overwrite} // 0; # default
        my $level = $smap->{level};

      MAP: foreach my $map (@{$smap->{map}}) {

          # Check pertype restrictions
          # Logic is "-(-P v Q)" which is equivalent to "P & -Q" but -Q is an array check so
          # messier to write than Q
          unless (not exists($map->{per_type}) or
                  first {lc($_->{content}) eq $entry->type} @{$map->{per_type}}) {
            next;
          }

          # Check negated pertype restrictions
          if (exists($map->{per_nottype}) and
              first {lc($_->{content}) eq $entry->type} @{$map->{per_nottype}}) {
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

          my $last_type = $entry->type; # defaults to the entrytype unless changed below
          my $last_field = undef;
          my $last_fieldval = undef;

          my @imatches; # For persisting parenthetical matches over several steps

          # Set up any mapping foreach loop
          my @maploop = ('');
          if (my $foreach = $map->{map_foreach}) {
            if (my $dslist = $DATAFIELD_SETS{lc($foreach)}) { # datafield set list
              @maploop = @$dslist;
            }
            elsif (my $felist = $entry->get(lc($foreach))) { # datafield
              @maploop = split(/\s*,\s*/, $felist);
            }
            else {              # explicit CSV
              @maploop = split(/\s*,\s*/, $foreach);
            }
          }

          foreach my $maploop (@maploop) {
            my $MAPUNIQVAL;
            # loop over mapping steps
            foreach my $step (@{$map->{map_step}}) {

              # entry deletion. Really only useful with allkeys or tool mode
              if ($step->{map_entry_null}) {
                $logger->debug("Source mapping (type=$level, key=$key): Ignoring entry completely");
                return 0;       # don't create an entry at all
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
                $logger->debug("Source mapping (type=$level, key=$key): Creating new entry with key '$newkey'");
                my $newentry = new Text::BibTeX::Entry;
                $newentry->set_metatype(BTE_REGULAR);
                $newentry->set_key(encode('UTF-8', NFC($newkey)));
                $newentry->set_type(encode('UTF-8', NFC($newentrytype)));

                # found a new entry key, remove it from the list of keys we want since we
                # have "found" it by creating it
                $logger->debug("Source mapping (type=$level, key=$key): created '$newkey', removing from dependent list");
                @$rkeys = grep {$newkey ne $_} @$rkeys;

                # Need to add the clone key to the section if allkeys is set since all keys
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

                $logger->debug("Source mapping (type=$level, key=$key): cloning entry with new key '$clonekey'");
                # found a clone key, remove it from the list of keys we want since we
                # have "found" it by creating it along with its clone parent
                $logger->debug("Source mapping (type=$level, key=$key): created '$clonekey', removing from dependent list");
                @$rkeys = grep {$clonekey ne $_} @$rkeys;

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
              else {         # default is that we operate on the same entry
                $etarget = $entry;
                $etargetkey = $key;
              }

              # Entrytype map
              if (my $typesource = maploopreplace($step->{map_type_source}, $maploop)) {
                $typesource = lc($typesource);
                unless ($etarget->type eq $typesource) {
                  # Skip the rest of the map if this step doesn't match and match is final
                  if ($step->{map_final}) {
                    $logger->debug("Source mapping (type=$level, key=$etargetkey): Entry type is '" . $etarget->type . "' but map wants '$typesource' and step has 'final' set, skipping rest of map ...");
                    next MAP;
                  }
                  else {
                    # just ignore this step
                    $logger->debug("Source mapping (type=$level, key=$etargetkey): Entry type is '" . $etarget->type . "' but map wants '$typesource', skipping step ...");
                    next;
                  }
                }
                # Change entrytype if requested
                $last_type = $etarget->type;
                my $t = lc(maploopreplace($step->{map_type_target}, $maploop));
                $logger->debug("Source mapping (type=$level, key=$etargetkey): Changing entry type from '$last_type' to $t");
                $etarget->set_type(encode('UTF-8', NFC($t)));
              }

              # Field map
              if (my $fieldsource = maploopreplace($step->{map_field_source}, $maploop)) {
                $fieldsource = lc($fieldsource);

                # key is a pseudo-field. It's guaranteed to exist so
                # just check if that's what's being asked for
                unless ($fieldsource eq 'entrykey' or
                        $etarget->exists($fieldsource)) {
                  # Skip the rest of the map if this step doesn't match and match is final
                  if ($step->{map_final}) {
                    $logger->debug("Source mapping (type=$level, key=$etargetkey): No field '$fieldsource' and step has 'final' set, skipping rest of map ...");
                    next MAP;
                  }
                  else {
                    # just ignore this step
                    $logger->debug("Source mapping (type=$level, key=$etargetkey): No field '$fieldsource', skipping step ...");
                    next;
                  }
                }

                $last_field = $fieldsource;
                $last_fieldval = $fieldsource eq 'entrykey' ? biber_decode_utf8($etarget->key) : biber_decode_utf8($etarget->get($fieldsource));

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
                    if ($fieldsource eq 'entrykey') {
                      $logger->debug("Source mapping (type=$level, key=$etargetkey): Field '$fieldsource' is 'entrykey'- cannot remap the value of this field, skipping ...");
                      next;
                    }

                    my $r = maploopreplace($step->{map_replace}, $maploop);
                    $logger->debug("Source mapping (type=$level, key=$etargetkey): Doing match/replace '$m' -> '$r' on field '$fieldsource'");
                    $etarget->set($fieldsource,
                                  encode('UTF-8', NFC(ireplace($last_fieldval, $m, $r))));
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
                        $logger->debug("Source mapping (type=$level, key=$etargetkey): Field '$fieldsource' does not match '$m' and step has 'final' set, skipping rest of map ...");
                        next MAP;
                      }
                      else {
                        # just ignore this step
                        $logger->debug("Source mapping (type=$level, key=$etargetkey): Field '$fieldsource' does not match '$m', skipping step ...");
                        next;
                      }
                    }
                  }
                }

                # Set to a different target if there is one
                if (my $target = maploopreplace($step->{map_field_target}, $maploop)) {
                  $target = lc($target);
                  # Can't remap entry key pseudo-field
                  if ($fieldsource eq 'entrykey') {
                    $logger->debug("Source mapping (type=$level, key=$etargetkey): Field '$fieldsource' is 'entrykey'- cannot map this to a new field as you must have an entrykey, skipping ...");
                    next;
                  }

                  if ($etarget->exists($target)) {
                    if ($map->{map_overwrite} // $smap->{map_overwrite}) {
                      $logger->debug("Source mapping (type=$level, key=$etargetkey): Overwriting existing field '$target'");
                    }
                    else {
                      $logger->debug("Source mapping (type=$level, key=$etargetkey): Field '$fieldsource' is mapped to field '$target' but both are defined, skipping ...");
                      next;
                    }
                  }
                  $etarget->set($target, encode('UTF-8', NFC(biber_decode_utf8($entry->get($fieldsource)))));
                  $etarget->delete($fieldsource);
                }
              }

              # field changes
              if (my $field = maploopreplace($step->{map_field_set}, $maploop)) {
                $field = lc($field);
                # Deal with special tokens
                if ($step->{map_null}) {
                  $logger->debug("Source mapping (type=$level, key=$etargetkey): Deleting field '$field'");
                  $etarget->delete($field);
                }
                else {
                  if ($etarget->exists($field)) {
                    unless ($map->{map_overwrite} // $smap->{map_overwrite}) {
                      if ($step->{map_final}) {
                        # map_final is set, ignore and skip rest of step
                        $logger->debug("Source mapping (type=$level, key=$etargetkey): Field '$field' exists, overwrite is not set and step has 'final' set, skipping rest of map ...");
                        next MAP;
                      }
                      else {
                        # just ignore this step
                        $logger->debug("Source mapping (type=$level, key=$etargetkey): Field '$field' exists and overwrite is not set, skipping step ...");
                        next;
                      }
                    }
                  }

                  # If append is set, keep the original value and append the new
                  my $orig = $step->{map_append} ? biber_decode_utf8($etarget->get($field)) : '';

                  if ($step->{map_origentrytype}) {
                    next unless $last_type;
                    $logger->debug("Source mapping (type=$level, key=$etargetkey): Setting field '$field' to '${orig}${last_type}'");
                    $etarget->set($field, encode('UTF-8', NFC($orig . $last_type)));
                  }
                  elsif ($step->{map_origfieldval}) {
                    next unless $last_fieldval;
                    $logger->debug("Source mapping (type=$level, key=$etargetkey): Setting field '$field' to '${orig}${last_fieldval}'");
                    $etarget->set($field, encode('UTF-8', NFC($orig . $last_fieldval)));
                  }
                  elsif ($step->{map_origfield}) {
                    next unless $last_field;
                    $logger->debug("Source mapping (type=$level, key=$etargetkey): Setting field '$field' to '${orig}${last_field}'");
                    $etarget->set($field, encode('UTF-8', NFC($orig . $last_field)));
                  }
                  else {
                    my $fv = maploopreplace($step->{map_field_value}, $maploop);
                    # Now re-instate any unescaped $1 .. $9 to get round these being
                    # dynamically scoped and being null when we get here from any
                    # previous map_match
                    $fv =~ s/(?<!\\)\$(\d)/$imatches[$1-1]/ge;
                    $logger->debug("Source mapping (type=$level, key=$etargetkey): Setting field '$field' to '${orig}${fv}'");
                    $etarget->set($field, encode('UTF-8', NFC($orig . $fv)));
                  }
                }
              }
            }
          }
        }
      }

      # Register that we've processed maps for this entry
      $cache->{data}{$key}{mapdone} = 1;
    }

    _create_entry($key, $entry);

    # Need to also instantiate fields in any new entries created by map
    while (my ($k, $e) = each %newentries) {
      _create_entry($k, $e);
    }
  }
  return 1;
}

sub _create_entry {
  my ($k, $e) = @_;
  return unless $e; # newentry might be undef
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $ds = $section->get_keytods($k);

  my $bibentry = new Biber::Entry;

  $bibentry->set_field('citekey', $k);
  $logger->debug("Creating biber Entry object with key '$k'");

  # Save pre-mapping data. Might be useful somewhere
  $bibentry->set_field('rawdata', biber_decode_utf8($e->print_s));

  my $entrytype = biber_decode_utf8($e->type);

  # We put all the fields we find modulo field aliases into the object
  # validation happens later and is not datasource dependent
  foreach my $f ($e->fieldlist) {

    # In tool mode, keep the raw data fields
    if (Biber::Config->getoption('tool')) {
      $bibentry->set_rawfield($f, biber_decode_utf8($e->get($f)));
    }

    # We have to process local options as early as possible in order
    # to make them available for things that need them like parsename()
    if ($f eq 'options') {
      my $value = biber_decode_utf8($e->get($f));
      my $Srx = Biber::Config->getoption('xsvsep');
      my $S = qr/$Srx/;
      process_entry_options($k, [ split(/$S/, $value) ]);
      # Save the raw options in case we are to output another input format like
      # biblatexml
      $bibentry->set_field('rawoptions', $value);
    }

    # Now run any defined handler
    if ($dm->is_field($f)) {
      my $handler = _get_handler($f);
      &$handler($bibentry, $e, $f, $k);
    }
    elsif (Biber::Config->getoption('validate_datamodel')) {
      biber_warn("Datamodel: Entry '$k' ($ds): Field '$f' invalid in data model - ignoring", $bibentry);
    }
  }

  $bibentry->set_field('entrytype', $entrytype);
  $bibentry->set_field('datatype', 'bibtex');
  $logger->debug("Adding entry with key '$k' to entry list");
  $section->bibentries->add_entry($k, $bibentry);
  return;
}

# HANDLERS
# ========

# Data annotation fields
sub _annotation {
  my ($bibentry, $entry, $field, $key) = @_;
  my $value = biber_decode_utf8($entry->get($field));
  my $ann = quotemeta(Biber::Config->getoption('annotation_marker'));
  $field =~ s/$ann$//;
  foreach my $a (split(/\s*;\s*/, $value)) {
    my ($count, $part, $annotations) = $a =~ /^\s*(\d+)?:?([^=]+)?=(.+)/;
    if ($part) {
      Biber::Annotation->set_annotation('part', $key, $field, $annotations, $count, $part);
    }
    elsif ($count) {
      Biber::Annotation->set_annotation('item', $key, $field, $annotations, $count);
    }
    else {
      Biber::Annotation->set_annotation('field', $key, $field, $annotations);
    }
  }
  return;
}

# Literal fields
sub _literal {
  my ($bibentry, $entry, $field, $key) = @_;
  my $value = biber_decode_utf8($entry->get($field));

  # If we have already split some date fields into literal fields
  # like date -> year/month/day, don't overwrite them with explicit
  # year/month
  return if ($field eq 'year' and $bibentry->get_datafield('year'));
  return if ($field eq 'month' and $bibentry->get_datafield('month'));

  # Deal with ISBN options
  if ($field eq 'isbn') {
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
      $bibentry->set_datafield($field, $value);
      return;
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
  if ($field eq 'month') {
    $bibentry->set_datafield($field, _hack_month($value));
  }
  # Rationalise any bcp47 style langids into babel/polyglossia names
  # biblatex will convert these back again when loading .lbx files
  # We need this until babel/polyglossia support proper bcp47 language/locales
  elsif ($field eq 'langid' and my $map = $LOCALE_MAP_R{$value}) {
    $bibentry->set_datafield($field, $map);
  }
  else {
    $bibentry->set_datafield($field, $value);
  }
  return;
}

# URI fields
sub _uri {
  my ($bibentry, $entry, $field) = @_;
  my $value = NFC(decode_utf8($entry->get($field)));# Unicode NFC boundary (before hex encoding)
  $bibentry->set_datafield($field, URI->new($value)->as_string); # Performs url encoding
  return;
}

# xSV field form
sub _xsv {
  my $Srx = Biber::Config->getoption('xsvsep');
  my $S = qr/$Srx/;
  my ($bibentry, $entry, $field) = @_;
  $bibentry->set_datafield($field, [ split(/$S/, biber_decode_utf8($entry->get($field))) ]);
  return;
}

# Verbatim fields
sub _verbatim {
  my ($bibentry, $entry, $field) = @_;
  my $value = biber_decode_utf8($entry->get($field));
  $bibentry->set_datafield($field, $value);
  return;
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
  my $value = biber_decode_utf8($entry->get($field));

  my @values = split(/\s*[;,]\s*/, $value);
  # If there is a range sep, then we set the end of the range even if it's null
  # If no range sep, then the end of the range is undef
  foreach my $value (@values) {
    $value =~ m/\A\s*(\P{Pd}+)\s*\z/xms ||# Simple value without range
      $value =~ m/\A\s*(\{[^\}]+\}|[^\p{Pd} ]+)\s*(\p{Pd}+)\s*(\{[^\}]+\}|\P{Pd}*)\s*\z/xms ||
        $value =~ m/\A\s*(.+)(\p{Pd}{2,})(.+)\s*\z/xms;# M-1--M-4
    my $start = $1;
    my $end;
    if ($2) {
      $end = $3;
    }
    else {
      $end = undef;
    }
    $start =~ s/\A\{([^\}]+)\}\z/$1/;
    $end =~ s/\A\{([^\}]+)\}\z/$1/;
    biber_warn("Range field '$field' in entry '$key' is malformed, skipping", $bibentry) unless $start;
    push @$values_ref, [$start || '', $end];
  }
  $bibentry->set_datafield($field, $values_ref);
  return;
}


# Names
sub _name {
  my ($bibentry, $entry, $field, $key) = @_;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $value = biber_decode_utf8($entry->get($field));

  # @tmp is bytes again now
  my @tmp = Text::BibTeX::split_list($value, Biber::Config->getoption('namesep'));

  my $useprefix = Biber::Config->getblxoption('useprefix', $bibentry->get_field('entrytype'), $key);
  my $names = new Biber::Entry::Names;
  foreach my $name (@tmp) {

    # Consecutive "and" causes Text::BibTeX::Name to segfault
    unless ($name) {
      biber_warn("Name in key '$key' is empty (probably consecutive 'and'): skipping name", $bibentry);
      $section->del_citekey($key);
      next;
    }

    $name = biber_decode_utf8($name);

    # Check for malformed names in names which aren't completely escaped

    # Too many commas
    unless ($name =~ m/\A\{\X+\}\z/xms) { # Ignore these tests for escaped names
      my @commas = $name =~ m/,/g;
      if ($#commas > 1) {
        biber_warn("Name \"$name\" has too many commas: skipping name", $bibentry);
        $section->del_citekey($key);
        next;
      }

      # Consecutive commas cause Text::BibTeX::Name to segfault
      if ($name =~ /,,/) {
        biber_warn("Name \"$name\" is malformed (consecutive commas): skipping name", $bibentry);
        $section->del_citekey($key);
        next;
      }
    }

    # Skip names that don't parse for some reason (like no family found - see parsename())
    next unless my $no = parsename($name, $field, {useprefix => $useprefix});

    # Deal with implied "et al" in data source
    if (lc($no->get_namestring) eq Biber::Config->getoption('others_string')) {
      $names->set_morenames;
    }
    else {
      $names->add_name($no);
    }

  }
  $bibentry->set_datafield($field, $names);
  return;
}

# Dates
sub _date {
  my ($bibentry, $entry, $field, $key) = @_;
  my $datetype = $field =~ s/date\z//xmsr;
  my $date = biber_decode_utf8($entry->get($field));
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $ds = $section->get_keytods($key);

  if (my ($byear, $bmonth, $bday, $r, $eyear, $emonth, $eday) = parse_date($date)) {
    # Did this entry get its year/month fields from splitting an ISO8601 date field?
    # We only need to know this for date, year/month as year/month can also
    # be explicitly set. This is useful to know in various places.
    $bibentry->set_field('datesplit', 1) if $datetype eq '';
    # Some warnings for overwriting YEAR and MONTH from DATE
    if ($byear and
        ($datetype . 'year' eq 'year') and
        $entry->get('year')) {
      biber_warn("Overwriting field 'year' with year value from field 'date' for entry '$key'", $bibentry);
    }
    if ($bmonth and
        ($datetype . 'month' eq 'month') and
        $entry->get('month')) {
      biber_warn("Overwriting field 'month' with month value from field 'date' for entry '$key'", $bibentry);
    }

    $bibentry->set_datafield($datetype . 'year', $byear)      if $byear;
    $bibentry->set_datafield($datetype . 'month', $bmonth)    if $bmonth;
    $bibentry->set_datafield($datetype . 'day', $bday)        if $bday;
    $bibentry->set_datafield($datetype . 'endmonth', $emonth) if $emonth;
    $bibentry->set_datafield($datetype . 'endday', $eday)     if $eday;
    if ($r and $eyear) {        # normal range
      $bibentry->set_datafield($datetype . 'endyear', $eyear);
    }
    elsif ($r and not $eyear) { # open ended range - endyear is defined but empty
      $bibentry->set_datafield($datetype . 'endyear', '');
    }
  }
  else {
    biber_warn("Datamodel: Entry '$key' ($ds): Invalid format '$date' of date field '$field' - ignoring", $bibentry);
  }
  return;
}

# Bibtex list fields with listsep separator
sub _list {
  my ($bibentry, $entry, $field) = @_;
  my $value = biber_decode_utf8($entry->get($field));

  my @tmp = Text::BibTeX::split_list($value, Biber::Config->getoption('listsep'));
  @tmp = map { biber_decode_utf8($_) } @tmp;
  @tmp = map { remove_outer($_) } @tmp;
  $bibentry->set_datafield($field, [ @tmp ]);
  return;
}

# Bibtex uri lists
sub _urilist {
  my ($bibentry, $entry, $field) = @_;
  my $value = NFC(decode_utf8($entry->get($field)));# Unicode NFC boundary (before hex encoding)
  my @tmp = Text::BibTeX::split_list($value, Biber::Config->getoption('listsep'));
  @tmp = map {
    # If there are some escapes in the URI, unescape them
    if ($_ =~ /\%/) {
      $_ =~ s/\\%/%/g; # just in case someone BibTeX escaped the "%"
      # This is what uri_unescape() does but it's faster
      $_ =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
    }
    $_;
  } @tmp;

  @tmp = map { URI->new($_)->as_string } @tmp;

  $bibentry->set_datafield($field, [ @tmp ]);
  return;
}


=head2 cache_data

   Caches file data into T::B objects indexed by the original
   datasource key, decoded into UTF8

=cut

sub cache_data {
  my $filename = shift;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);

  # Initialise this
  $cache->{preamble}{$filename} = [];

  # Convert/decode file
  my $pfilename = preprocess_file($filename);

  my $bib = Text::BibTeX::File->new( $pfilename, '<' )
    or biber_error("Cannot create Text::BibTeX::File object from $pfilename: $!");

  # Log that we found a data file
  $logger->info("Found BibTeX data source '$filename'");

  while ( my $entry = new Text::BibTeX::Entry $bib ) {
    if ( $entry->metatype == BTE_PREAMBLE ) {
      push @{$cache->{preamble}{$filename}}, biber_decode_utf8($entry->value);
      next;
    }

    # Save comments for output in tool mode unless comment stripping is requested
    if ( $entry->metatype == BTE_COMMENT ) {
      if (Biber::Config->getoption('tool') and not
          Biber::Config->getoption('strip_comments') ) {
        push @{$cache->{comments}{$filename}}, process_comment(biber_decode_utf8($entry->value));
      }
      next;
    }

    # Ignore misc BibTeX entry types we don't care about
    next if ( $entry->metatype == BTE_MACRODEF or
              $entry->metatype == BTE_UNKNOWN );

    # If an entry has no key, ignore it and warn
    unless ($entry->key) {
      biber_warn("Invalid or undefined BibTeX entry key in file '$pfilename', skipping ...");
      next;
    }

    # Text::BibTeX >= 0.46 passes through all citekey bits, thus allowing UTF-8 keys
    my $key = biber_decode_utf8($entry->key);

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
    if (my $ids = biber_decode_utf8($entry->get('ids'))) {
      my $Srx = Biber::Config->getoption('xsvsep');
      my $S = qr/$Srx/;
      foreach my $id (split(/$S/, $ids)) {

        # Skip aliases which are also real entry keys
        if ($section->has_everykey($id)) {
          biber_warn("Citekey alias '$id' is also a real entry key, skipping ...");
          next;
        }

        # Warn on conflicting aliases
        if (exists($cache->{data}{citekey_aliases}{$id})) {
          my $otherid = $cache->{data}{citekey_aliases}{$id};
          if ($otherid ne $key) {
            biber_warn("Citekey alias '$id' already has an alias '$otherid', skipping ...");
          }
        }
        else {
          $cache->{data}{citekey_aliases}{$id} = $key;
          $logger->debug("Citekey '$id' is an alias for citekey '$key'");
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
    push @{$cache->{orig_key_order}{$filename}}, $key;
    $logger->debug("Cached Text::BibTeX entry for key '$key' from BibTeX file '$filename'");
  }

  $bib->close; # If we don't do this, we can't unlink the temp file on Windows
  return;
}


=head2 preprocess_file

   Convert file to UTF-8 and potentially decode LaTeX macros to UTF-8

=cut

sub preprocess_file {
  my $filename = shift;

  # Put the utf8 encoded file into the global biber tempdir
  # We have to do this in case we can't write to the location of the
  # .bib file
  my $td = $Biber::MASTER->biber_tempdir;
  (undef, undef, my $fn) = File::Spec->splitpath($filename);
  my $ufilename = File::Spec->catfile($td->dirname, "${fn}_$$.utf8");

  # We read the file in the bib encoding and then output to UTF-8, even if it was already UTF-8,
  # just in case there was a BOM so we can delete it as it makes T::B complain
  # Don't use File::Slurp binmode option - it's completely broken - see module RT queue
  my $buf = File::Slurp::read_file($filename) or biber_error("Can't read $filename");
  $buf = NFD(decode(Biber::Config->getoption('input_encoding'), $buf));# Unicode NFD boundary

  # strip UTF-8 BOM if it exists - this just makes T::B complain about junk characters
  $buf =~ s/\A\x{feff}//;

  File::Slurp::write_file($ufilename, encode('UTF-8', NFC($buf))) or
      biber_error("Can't write $ufilename");# Unicode NFC boundary

  # Always decode LaTeX to UTF8
  my $lbuf = File::Slurp::read_file($ufilename) or biber_error("Can't read $ufilename");
  $lbuf = NFD(decode('UTF-8', $lbuf));# Unicode NFD boundary

  $logger->info('Decoding LaTeX character macros into UTF-8');
  $logger->trace("Buffer before decoding -> '$lbuf'");
  $lbuf = Biber::LaTeX::Recode::latex_decode($lbuf);
  $logger->trace("Buffer after decoding -> '$lbuf'");

  File::Slurp::write_file($ufilename, encode('UTF-8', NFC($lbuf))) or
      biber_error("Can't write $ufilename");# Unicode NFC boundary

  return $ufilename;
}

=head2 parsename

    Given a name string, this function returns a Biber::Entry::Name object
    with all parts of the name resolved according to the BibTeX conventions.

    parsename('John Doe')
    returns an object which internally looks a bit like this:

    { given          => {string => 'John', initial => ['J']},
      family         => {string => 'Doe', initial => ['D']},
      prefix         => {string => undef, initial => undef},
      suffix         => {string => undef, initial => undef},
      namestring     => 'Doe, John',
      nameinitstring => 'Doe_J',
      strip          => {'given'  => 0,
                         'family' => 0,
                         'prefix' => 0,
                         'suffix' => 0}
      }

=cut

sub parsename {
  my ($namestr, $fieldname, $opts, $testing) = @_;
  my $usepre = $opts->{useprefix};
  # First sanitise the namestring due to Text::BibTeX::Name limitations on whitespace
  $namestr =~ s/\A\s*|\s*\z//xms; # leading and trailing whitespace
  # Collapse internal whitespace and escaped spaces like in "Christina A. L.\ Thiele"
  $namestr =~ s/\s+|\\\s/ /g;
  $namestr =~ s/\A\{\{+([^{}]+)\}+\}\z/{$1}/xms; # Allow only one enveloping set of braces

  # If requested, try to correct broken initials with no space between them.
  # This can slightly mess up some other names like {{U.K. Government}} etc.
  # btparse can't do this so we do it before name parsing
  $namestr =~ s/(\w)\.(\w)/$1. $2/g if Biber::Config->getoption('fixinits');

  my $name = new Text::BibTeX::Name($namestr);

  # Formats so we can get BibTeX compatible nbsp inserted
  my $l_f = new Text::BibTeX::NameFormat('l', 0);
  my $f_f = new Text::BibTeX::NameFormat('f', 0);
  my $p_f = new Text::BibTeX::NameFormat('v', 0);
  my $s_f = new Text::BibTeX::NameFormat('j', 0);
  $l_f->set_options(BTN_LAST,  0, BTJ_MAYTIE, BTJ_NOTHING);
  $f_f->set_options(BTN_FIRST, 0, BTJ_MAYTIE, BTJ_NOTHING);
  $p_f->set_options(BTN_VON,   0, BTJ_MAYTIE, BTJ_NOTHING);
  $s_f->set_options(BTN_JR,    0, BTJ_MAYTIE, BTJ_NOTHING);

  # Generate name parts
  my $family = biber_decode_utf8($name->format($l_f));
  my $given  = biber_decode_utf8($name->format($f_f));
  my $prefix = biber_decode_utf8($name->format($p_f));
  my $suffix = biber_decode_utf8($name->format($s_f));

  # Variables to hold the Text::BibTeX::NameFormat generated initials string
  my $gen_family_i;
  my $gen_given_i;
  my $gen_prefix_i;
  my $gen_suffix_i;

  # Use a copy of $name so that when we generate the
  # initials, we do so without certain things. This is easier than trying
  # hack robust initials code into btparse ...
  my $nd_namestr = strip_noinit($namestr);

  # Make initials with ties in between work. btparse doesn't understand this so replace with
  # spaces - this is fine as we are just generating initials
  $nd_namestr =~ s/\.~\s*/. /g;

  my $nd_name = new Text::BibTeX::Name($nd_namestr, $fieldname);

  # Initials formats
  my $li_f = new Text::BibTeX::NameFormat('l', 1);
  my $fi_f = new Text::BibTeX::NameFormat('f', 1);
  my $pi_f = new Text::BibTeX::NameFormat('v', 1);
  my $si_f = new Text::BibTeX::NameFormat('j', 1);

  # Initials generated with forced tie so we can make an array
  $li_f->set_text(BTN_LAST,  undef, undef, undef, '');
  $fi_f->set_text(BTN_FIRST, undef, undef, undef, '');
  $pi_f->set_text(BTN_VON,   undef, undef, undef, '');
  $si_f->set_text(BTN_JR,    undef, undef, undef, '');
  $li_f->set_options(BTN_LAST,  1, BTJ_FORCETIE, BTJ_NOTHING);
  $fi_f->set_options(BTN_FIRST, 1, BTJ_FORCETIE, BTJ_NOTHING);
  $pi_f->set_options(BTN_VON,   1, BTJ_FORCETIE, BTJ_NOTHING);
  $si_f->set_options(BTN_JR,    1, BTJ_FORCETIE, BTJ_NOTHING);

  $gen_family_i = inits(biber_decode_utf8($nd_name->format($li_f)));
  $gen_given_i  = inits(biber_decode_utf8($nd_name->format($fi_f)));
  $gen_prefix_i = inits(biber_decode_utf8($nd_name->format($pi_f)));
  $gen_suffix_i = inits(biber_decode_utf8($nd_name->format($si_f)));

  my $namestring = '';

  # Don't add suffix to namestring or nameinitstring as these are used for uniquename
  # disambiguation which should only care about family + any prefix (if useprefix=true).
  # See biblatex github tracker #306.

  # prefix
  my $ps;
  my $prefix_stripped;
  my $prefix_i;
  if ($prefix) {
    $prefix_i        = $gen_prefix_i;
    $prefix_stripped = remove_outer($prefix);
    $ps = $prefix ne $prefix_stripped ? 1 : 0;
    $namestring .= "$prefix_stripped ";
  }
  # family name
  my $fs;
  my $family_stripped;
  my $family_i;
  if ($family) {
    $family_i        = $gen_family_i;
    $family_stripped = remove_outer($family);
    $fs = $family ne $family_stripped ? 1 : 0;
    $namestring .= "$family_stripped, ";
  }
  # suffix
  my $ss;
  my $suffix_stripped;
  my $suffix_i;
  if ($suffix) {
    $suffix_i        = $gen_suffix_i;
    $suffix_stripped = remove_outer($suffix);
    $ss = $suffix ne $suffix_stripped ? 1 : 0;
  }
  # given name
  my $gs;
  my $given_stripped;
  my $given_i;
  if ($given) {
    $given_i        = $gen_given_i;
    $given_stripped = remove_outer($given);
    $gs = $given ne $given_stripped ? 1 : 0;
    $namestring .= "$given_stripped";
  }

  # Remove any trailing comma and space if, e.g. missing given
  # Replace any nbspes
  $namestring =~ s/,\s+\z//xms;
  $namestring =~ s/\s*~\s*/ /gxms;

  # Construct $nameinitstring
  my $nameinitstr = '';
  $nameinitstr .= join('', @$prefix_i) . '_' if ( $usepre and $prefix );
  $nameinitstr .= $family if $family;
  $nameinitstr .= '_' . join('', @$given_i) if $given;
  $nameinitstr =~ s/\s+|~/_/g;

  # output is always NFC and so when testing the output of this routine, need NFC
  if ($testing) {
    if ($given) {
      $given_stripped = NFC($given_stripped);
      $given_i        = [ map {NFC($_)} @$given_i ];
    }
    if ($family) {
      $family_stripped  = NFC($family_stripped);
      $family_i         = [ map {NFC($_)} @$family_i ];
    }
    if ($prefix) {
      $prefix_stripped    = NFC($prefix_stripped);
      $prefix_i           = [ map {NFC($_)} @$prefix_i ];
    }
    if ($suffix) {
      $suffix_stripped    = NFC($suffix_stripped);
      $suffix_i           = [ map {NFC($_)} @$suffix_i ];
    }
    if ($namestring) {
      $namestring = NFC($namestring);
    }
    if ($nameinitstr) {
      $nameinitstr = NFC($nameinitstr);
    }
  }

  # The "strip" entry tells us which of the name parts had outer braces
  # stripped during processing so we can add them back when printing the
  # .bbl so as to maintain maximum BibTeX compatibility
  return Biber::Entry::Name->new(
    given           => {string  => $given  eq '' ? undef : $given_stripped,
                        initial => $given  eq '' ? undef : $given_i},
    family          => {string  => $family eq '' ? undef : $family_stripped,
                        initial => $family eq '' ? undef : $family_i},
    prefix          => {string  => $prefix eq '' ? undef : $prefix_stripped,
                        initial => $prefix eq '' ? undef : $prefix_i},
    suffix          => {string  => $suffix eq '' ? undef : $suffix_stripped,
                        initial => $suffix eq '' ? undef : $suffix_i},
    namestring      => $namestring,
    nameinitstring  => $nameinitstr,
    strip           => {'given'  => $gs,
                        'family' => $fs,
                        'prefix' => $ps,
                        'suffix' => $ss}
    );
}

# Routine to try to hack month into the right biblatex format
# Especially since we support remote .bibs which we potentially have no control over
my %months = (
              'jan' => '01',
              'feb' => '02',
              'mar' => '03',
              'apr' => '04',
              'may' => '05',
              'jun' => '06',
              'jul' => '07',
              'aug' => '08',
              'sep' => '09',
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
  my $ann = quotemeta(Biber::Config->getoption('annotation_marker'));
  if ($field =~ qr/$ann$/) {
    return $handlers->{CUSTOM}{annotation};
  }
  else {
    return $handlers->{$dm->get_fieldtype($field)}{$dm->get_fieldformat($field) || 'default'}{$dm->get_datatype($field)};
  }
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
