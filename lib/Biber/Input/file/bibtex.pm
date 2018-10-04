package Biber::Input::file::bibtex;
use v5.24;
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
use File::Slurper;
use File::Temp;
use Log::Log4perl qw(:no_extra_logdie_message);
use List::AllUtils qw( :all );
use Scalar::Util qw(looks_like_number);
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
  my ($source, $encoding, $keys) = @_;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $filename;
  my @rkeys = $keys->@*;
  my $tf; # Up here so that the temp file has enough scope to survive until we've used it
  if ($logger->is_trace()) {# performance tune
    $logger->trace("Entering extract_entries() in driver 'bibtex'");
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

  # If it's a remote data file, fetch it first
  if ($source =~ m/\A(?:http|ftp)(s?):\/\//xms) {
    $logger->info("Data source '$source' is a remote BibTeX data source - fetching ...");
    if (my $cf = $REMOTE_MAP{$source}) {
      $logger->info("Found '$source' in remote source cache");
      $filename = $cf;
    }
    else {
      if ($1) { # HTTPS/FTPS
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

      unless (create_entry($key, $entry, $source, $smaps, \@rkeys)) {
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
          create_entry($wanted_key, $entry, $source, $smaps, \@rkeys);
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
            create_entry($rk, $entry, $source, $smaps, \@rkeys);
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
        biber_error("BibTeX subsystem: $_");
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

    MAP: foreach my $map ($smap->{map}->@*) {

        # Skip if this map element specifies a particular refsection and it is not this one
        if (exists($map->{refsection})) {
          next unless $secnum == $map->{refsection};
        }

        # Check pertype restrictions
        # Logic is "-(-P v Q)" which is equivalent to "P & -Q" but -Q is an array check so
        # messier to write than Q
        unless (not exists($map->{per_type}) or
                first {lc($_->{content}) eq $entry->type} $map->{per_type}->@*) {
          next;
        }

        # Check negated pertype restrictions
        if (exists($map->{per_nottype}) and
            first {lc($_->{content}) eq $entry->type} $map->{per_nottype}->@*) {
          next;
        }

        # Check per_datasource restrictions
        # Don't compare case insensitively - this might not be correct
        # Logic is "-(-P v Q)" which is equivalent to "P & -Q" but -Q is an array check so
        # messier to write than Q
        unless (not exists($map->{per_datasource}) or
                first {$_->{content} eq $datasource} $map->{per_datasource}->@*) {
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
            @maploop = $dslist->@*;
          }
          elsif (my $felist = $entry->get(lc($foreach))) { # datafield
            @maploop = split(/\s*,\s*/, $felist);
          }
          else {                # explicit CSV
            @maploop = split(/\s*,\s*/, $foreach);
          }
        }

        foreach my $maploop (@maploop) {
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
              my $newentry = Text::BibTeX::Entry->new();
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
              $typesource = lc($typesource);
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
              my $t = lc(maploopreplace($step->{map_type_target}, $maploop));
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
              $nfieldsource = lc($nfieldsource);
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

            # Field map
            if ($fieldsource = maploopreplace($step->{map_field_source}, $maploop)) {
              $fieldsource = lc($fieldsource);

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
              $last_fieldval = $fieldsource eq 'entrykey' ? $etarget->key : $etarget->get($fieldsource);

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

              # map fields to targets
              if (my $m = maploopreplace($step->{map_match}, $maploop)) {
                if (defined($step->{map_replace})) { # replace can be null

                  # Can't modify entrykey
                  if ($fieldsource eq 'entrykey') {
                    if ($logger->is_debug()) { # performance tune
                      $logger->debug("Source mapping (type=$level, key=$etargetkey): Field '$fieldsource' is 'entrykey'- cannot remap the value of this field, skipping ...");
                    }
                    next;
                  }

                  my $r = maploopreplace($step->{map_replace}, $maploop);
                  if ($logger->is_debug()) { # performance tune
                    $logger->debug("Source mapping (type=$level, key=$etargetkey): Doing match/replace '$m' -> '$r' on field '$fieldsource'");
                  }
                  $etarget->set($fieldsource,
                                encode('UTF-8', NFC(ireplace($last_fieldval, $m, $r, $caseinsensitive))));
                }
                else {
                  # Now re-instate any unescaped $1 .. $9 to get round these being
                  # dynamically scoped and being null when we get here from any
                  # previous map_match
                  # Be aware that imatch() uses m//g so @imatches can have multiple paren group
                  # captures which might be useful
                  $m =~ s/(?<!\\)\$(\d)/$imatches[$1-1]/ge;
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
                $target = lc($target);
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
                $etarget->set($target, encode('UTF-8', NFC($entry->get($fieldsource))));
                $etarget->delete($fieldsource);
              }
            }

            # field changes
            if (my $field = maploopreplace($step->{map_field_set}, $maploop)) {
              $field = lc($field);
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

                  # If append is set, keep the original value and append the new
                  my $orig = $step->{map_append} ? $etarget->get($field) : '';

                if ($step->{map_origentrytype}) {
                  next unless $last_type;
                  if ($logger->is_debug()) { # performance tune
                    $logger->debug("Source mapping (type=$level, key=$etargetkey): Setting field '$field' to '${orig}${last_type}'");
                  }
                  $etarget->set($field, encode('UTF-8', NFC($orig . $last_type)));
                }
                elsif ($step->{map_origfieldval}) {
                  next unless $last_fieldval;
                  if ($logger->is_debug()) { # performance tune
                    $logger->debug("Source mapping (type=$level, key=$etargetkey): Setting field '$field' to '${orig}${last_fieldval}'");
                  }
                  $etarget->set($field, encode('UTF-8', NFC($orig . $last_fieldval)));
                }
                elsif ($step->{map_origfield}) {
                  next unless $last_field;
                  if ($logger->is_debug()) { # performance tune
                    $logger->debug("Source mapping (type=$level, key=$etargetkey): Setting field '$field' to '${orig}${last_field}'");
                  }
                  $etarget->set($field, encode('UTF-8', NFC($orig . $last_field)));
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
                  $etarget->set($field, encode('UTF-8', NFC($orig . $fv)));
                }
              }
            }
          }
        }
      }
    }

    _create_entry($key, $entry);

    # reinstate original entry before modifications so that further refsections
    # have a clean slate
    $entry = $saved_entry;

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

  my $bibentry = Biber::Entry->new();

  $bibentry->set_field('citekey', $k);
  if ($logger->is_debug()) {# performance tune
    $logger->debug("Creating biber Entry object with key '$k'");
  }

  # Save pre-mapping data. Might be useful somewhere
  $bibentry->set_field('rawdata', $e->print_s);

  my $entrytype = $e->type;

  # We put all the fields we find modulo field aliases into the object
  # validation happens later and is not datasource dependent
  foreach my $f ($e->fieldlist) {

    # We have to process local options as early as possible in order
    # to make them available for things that need them like parsename()
    if ($f eq 'options') {
      my $value = $e->get($f);
      my $Srx = Biber::Config->getoption('xsvsep');
      my $S = qr/$Srx/;
      process_entry_options($k, [ split(/$S/, $value) ]);
    }

    # Now run any defined handler
    if ($dm->is_field($f)) {
      my $handler = _get_handler($f);
      my $v = $handler->($bibentry, $e, $f, $k);

      # Don't set datafields with empty contents like 'language = {}'
      if (defined($v) and $e->get($f) ne '') {
        $bibentry->set_datafield($f, $v);
      }
    }
    elsif (Biber::Config->getoption('validate_datamodel')) {
      biber_warn("Datamodel: Entry '$k' ($ds): Field '$f' invalid in data model - ignoring", $bibentry);
    }
  }

  $bibentry->set_field('entrytype', $entrytype);
  $bibentry->set_field('datatype', 'bibtex');
  if ($logger->is_debug()) {# performance tune
    $logger->debug("Adding entry with key '$k' to entry list");
  }
  $section->bibentries->add_entry($k, $bibentry);
  return;
}

# HANDLERS
# ========

# Data annotation fields
sub _annotation {
  my ($bibentry, $entry, $field, $key) = @_;
  my $value = $entry->get($field);
  my $ann = quotemeta(Biber::Config->getoption('annotation_marker'));
  my $nam = quotemeta(Biber::Config->getoption('named_annotation_marker'));
  # Get annotation name, "default" if none
  my $name = 'default';
  if ($field =~ s/^(.+$ann)$nam(.+)$/$1/) {
    $name = $2;
  }
  $field =~ s/$ann$//;

  foreach my $a (split(/\s*;\s*/, $value)) {
    my ($count, $part, $annotations) = $a =~ /^\s*(\d+)?:?([^=]+)?=(.+)/;
    # Is the annotations a literal annotation?
    my $literal = 0;
    if ($annotations =~ m/^\s*"(.+)"\s*$/) {
      $literal = 1;
      $annotations = $1;
    }
    if ($part) {
      Biber::Annotation->set_annotation('part', $key, $field, $name, $annotations, $literal, $count, $part);
    }
    elsif ($count) {
      Biber::Annotation->set_annotation('item', $key, $field, $name, $annotations, $literal, $count);
    }
    else {
      Biber::Annotation->set_annotation('field', $key, $field, $name, $annotations, $literal);
    }
  }
  return;
}

# Literal fields
sub _literal {
  my ($bibentry, $entry, $field, $key) = @_;
  my $value = $entry->get($field);

  # If we have already split some date fields into literal fields
  # like date -> year/month/day, don't overwrite them with explicit
  # year/month
  if ($field eq 'year') {
    return if $bibentry->get_datafield('year');
    if ($value and not looks_like_number($value)and not $entry->get('sortyear')) {
      biber_warn("year field '$value' in entry '$key' is not an integer - this will probably not sort properly.");
    }
  }
  if ($field eq 'month') {
    return if $bibentry->get_datafield('month');
    if ($value and not looks_like_number($value)) {
      biber_warn("month field '$value' in entry '$key' is not an integer - this will probably not sort properly.");
    }
  }

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
  if ($field eq 'month') {
    return _hack_month($value);
  }
  # Rationalise any bcp47 style langids into babel/polyglossia names
  # biblatex will convert these back again when loading .lbx files
  # We need this until babel/polyglossia support proper bcp47 language/locales
  elsif ($field eq 'langid' and my $map = $LOCALE_MAP_R{$value}) {
    return $map;
  }
  else {
    return $value;
  }
}

# URI fields
sub _uri {
  my ($bibentry, $entry, $field) = @_;
  my $value = $entry->get($field);
  return $value;
}

# xSV field form
sub _xsv {
  my $Srx = Biber::Config->getoption('xsvsep');
  my $S = qr/$Srx/;
  my ($bibentry, $entry, $field) = @_;
  return [ split(/$S/, $entry->get($field)) ];
}

# Verbatim fields
sub _verbatim {
  my ($bibentry, $entry, $field) = @_;
  my $value = $entry->get($field);
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
  my $value = $entry->get($field);

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
    $end =~ s/\A\{([^\}]+)\}\z/$1/;
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
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $value = $entry->get($field);
  my $xnamesep = Biber::Config->getoption('xnamesep');

  my @tmp = Text::BibTeX::split_list(NFC($value),# Unicode NFC boundary
                                     Biber::Config->getoption('namesep'),
                                     undef,
                                     undef,
                                     undef,
                                     {binmode => 'utf-8', normalization => 'NFD'});

  my $useprefix = Biber::Config->getblxoption('useprefix', $bibentry->get_field('entrytype'), $key);
  my $un = Biber::Config->getblxoption('uniquename', $bibentry->get_field('entrytype'), $key);

  my $names = Biber::Entry::Names->new();

  foreach my $name (@tmp) {

    # per-namelist options
    if ($name =~ m/^(\S+)\s*$xnamesep\s*(\S+)?$/) {
      my $nlo = lc($1);
      my $nlov = $2 // 1; # bare options are just boolean numerals
      if ($CONFIG_SCOPEOPT_BIBLATEX{NAMELIST}->{$nlo}) {
        if ($CONFIG_OPTTYPE_BIBLATEX{$nlo} and
            $CONFIG_OPTTYPE_BIBLATEX{$nlo} eq 'boolean') {
          $nlov = map_boolean($nlov, 'tonum');
      }
        my $oo = expand_option($nlo, $nlov, $CONFIG_BIBLATEX_NAMELIST_OPTIONS{$nlo}->{INPUT});

        foreach my $o ($oo->@*) {
          my $method = 'set_' . $o->[0];
          $names->$method($o->[1]);
        }
        next;
      }
    }

    # Consecutive "and" causes Text::BibTeX::Name to segfault
    unless ($name) {
      biber_warn("Name in key '$key' is empty (probably consecutive 'and'): skipping name", $bibentry);
      $section->del_citekey($key);
      next;
    }

    my $nps = join('|', $dm->get_constant_value('nameparts'));
    my $no;

    # extended name format
    my $xnamesep = Biber::Config->getoption('xnamesep');
    if ($name =~ m/(?:$nps)\s*$xnamesep/ and not Biber::Config->getoption('noxname')) {
      # Skip names that don't parse for some reason
      # uniquename defaults to 0 just in case we are in tool mode otherwise there are spurious
      # uninitialised warnings

      next unless $no = parsename_x($name,
                                    $field,
                                    {useprefix => $useprefix,
                                     uniquename => ($un // 0)},
                                    $key);
    }
    else { # Normal bibtex name format
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

      # Skip names that don't parse for some reason
      # unique name defaults to 0 just in case we are in tool mode otherwise there are spurious
      # uninitialised warnings
      next unless $no = parsename($name, $field);
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
  return $names->count_names ? $names : undef;
}

# Dates
sub _datetime {
  my ($bibentry, $entry, $field, $key) = @_;
  my $datetype = $field =~ s/date\z//xmsr;
  my $date = $entry->get($field);
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $ds = $section->get_keytods($key);

  my ($sdate, $edate, $sep, $unspec) = parse_date_range($bibentry, $datetype, $date);

  # Date had EDTF 5.2.2 unspecified format
  # This does not differ for *enddate components as these are split into ranges
  # from non-ranges only
  if ($unspec) {
    $bibentry->set_field($datetype . 'dateunspecified', $unspec);
  }

  if (defined($sdate)) { # Start date was successfully parsed
    if ($sdate) { # Start date is an object not "0"
      # Did this entry get its datepart fields from splitting an EDTF date field?
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

      # Save start season date information
      if (my $season = $CONFIG_DATE_PARSERS{start}->season) {
        $bibentry->set_field($datetype . 'season', $season);
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

      # time
      unless ($CONFIG_DATE_PARSERS{start}->missing('time')) {
        $bibentry->set_datafield($datetype . 'hour', $sdate->hour);
        $bibentry->set_datafield($datetype . 'minute', $sdate->minute);
        $bibentry->set_datafield($datetype . 'second', $sdate->second);
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
          # Did this entry get its datepart fields from splitting an EDTF date field?
          $bibentry->set_field("${datetype}datesplit", 1);

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
        else { # open ended range - enddate is defined but empty
          $bibentry->set_datafield($datetype . 'endyear', '');
        }
      }
      else {
        biber_warn("Entry '$key' ($ds): Invalid format '$date' of end date field '$field' - ignoring", $bibentry);
      }
    }
  }
  else {
    biber_warn("Entry '$key' ($ds): Invalid format '$date' of date field '$field' - ignoring", $bibentry);
  }
  return;
}

# Bibtex list fields with listsep separator
sub _list {
  my ($bibentry, $entry, $field) = @_;
  my $value = $entry->get($field);
  my @tmp = Text::BibTeX::split_list(NFC($value),# Unicode NFC boundary
                                     Biber::Config->getoption('listsep'),
                                     undef,
                                     undef,
                                     undef,
                                     {binmode => 'utf-8', normalization => 'NFD'});
  @tmp = map { (remove_outer($_))[1] } @tmp;
  return [ @tmp ];
}

# Bibtex uri lists
sub _urilist {
  my ($bibentry, $entry, $field) = @_;
  my $value = $entry->get($field);
  # Unicode NFC boundary (passing to external library)
  my @tmp = Text::BibTeX::split_list(NFC($value),
                                     Biber::Config->getoption('listsep'),
                                     undef,
                                     undef,
                                     undef,
                                     {binmode => 'utf-8', normalization => 'NFD'});
  return [ @tmp ];
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
    if ( $entry->metatype == BTE_COMMENT ) {
      if (Biber::Config->getoption('tool') and not
          Biber::Config->getoption('strip_comments') ) {
        push $cache->{comments}{$filename}->@*, process_comment($entry->value);
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
        if (fc($id) eq fc($key)) {
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
  my $ufilename = File::Spec->catfile($td->dirname, "${fn}_$$.utf8");

  # We read the file in the bib encoding and then output to UTF-8, even if it was already UTF-8,
  # just in case there was a BOM so we can delete it as it makes T::B complain
  # Might fail due to encountering characters invalid in the encoding so trap and die gracefully
  if ($benc eq 'ascii') {
    $logger->info("Reading ascii input as UTF-8");
    $benc = 'UTF-8';
  }
  my $buf;
  unless (eval{$buf = NFD(File::Slurper::read_text($filename, $benc))}) {# Unicode NFD boundary
    biber_error("Data file '$filename' cannot be read in encoding '$benc': $@");
  }

  # strip UTF-8 BOM if it exists - this just makes T::B complain about junk characters
  $buf =~ s/\A\x{feff}//;

  # A MAC (CR only) format file with a comment in the first line will confuse
  # Text::BibTeX as it will just see one comment line and find no entries
  # So, if we find an initial comment line with a carriage return at the end, remove it.
  $buf =~ s/\A\s*\%[^\r]+\r//ms;

  File::Slurper::write_text($ufilename, NFC($buf));# Unicode NFC boundary

  my $lbuf = parse_decode($ufilename);

  if ($logger->is_trace()) {# performance tune
    $logger->trace("Buffer after decoding -> '$lbuf'");
  }

  File::Slurper::write_text($ufilename, NFC($lbuf));# Unicode NFC boundary

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
        my $fv = $entry->get($f);

        # Don't decode verbatim fields
        if (not first {fc($f) eq fc($_)} $dmh->{verbs}->@*) {
          $fv = Biber::LaTeX::Recode::latex_decode($fv);
        }
        $lbuf .= "  $f = {$fv},\n";
      }
      $lbuf .= "\n" . '}' . "\n\n";
    }
    elsif ($entry->metatype == BTE_PREAMBLE) {
      $lbuf .= '@PREAMBLE{"' . Biber::LaTeX::Recode::latex_decode($entry->value) . '"}' . "\n";
    }
    elsif ($entry->metatype == BTE_COMMENT) {
      $lbuf .= '@COMMENT{' . Biber::LaTeX::Recode::latex_decode($entry->value) . '}' . "\n";
    }
    elsif ($entry->metatype == BTE_MACRODEF) {
      $lbuf .= '@STRING{';
      foreach my $f ($entry->fieldlist) {
        $lbuf .= $f . ' = {' . Biber::LaTeX::Recode::latex_decode($entry->get($f)) . '}';
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
  my ($namestr, $fieldname) = @_;

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
  my $name = Text::BibTeX::Name->new({binmode => 'utf-8', normalization => 'NFD'}, $namestr);

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

  # Use a copy of $name so that when we generate the
  # initials, we do so without certain things. This is easier than trying
  # hack robust initials code into btparse ...
  my $nd_namestr = strip_noinit($namestr);

  # Make initials with ties in between work. btparse doesn't understand this so replace with
  # spaces - this is fine as we are just generating initials
  $nd_namestr =~ s/\.~\s*/. /g;

  my $nd_name = Text::BibTeX::Name->new({binmode => 'utf-8', normalization => 'NFD'}, $nd_namestr, $fieldname);

  # Initials formats
  my $li_f = Text::BibTeX::NameFormat->new('l', 1);
  my $fi_f = Text::BibTeX::NameFormat->new('f', 1);
  my $pi_f = Text::BibTeX::NameFormat->new('v', 1);
  my $si_f = Text::BibTeX::NameFormat->new('j', 1);

  # Initials generated with forced tie so we can make an array
  $li_f->set_text(BTN_LAST,  undef, undef, undef, '');
  $fi_f->set_text(BTN_FIRST, undef, undef, undef, '');
  $pi_f->set_text(BTN_VON,   undef, undef, undef, '');
  $si_f->set_text(BTN_JR,    undef, undef, undef, '');
  $li_f->set_options(BTN_LAST,  1, BTJ_FORCETIE, BTJ_NOTHING);
  $fi_f->set_options(BTN_FIRST, 1, BTJ_FORCETIE, BTJ_NOTHING);
  $pi_f->set_options(BTN_VON,   1, BTJ_FORCETIE, BTJ_NOTHING);
  $si_f->set_options(BTN_JR,    1, BTJ_FORCETIE, BTJ_NOTHING);

  $namec{'family-i'} = inits($nd_name->format($li_f));
  $namec{'given-i'}  = inits($nd_name->format($fi_f));
  $namec{'prefix-i'} = inits($nd_name->format($pi_f));
  $namec{'suffix-i'} = inits($nd_name->format($si_f));

  # basic bibtex names have a fixed data model
  foreach my $np ('prefix', 'family', 'given', 'suffix') {
    if ($namec{$np}) {
      ($namec{"${np}-strippedflag"}, $namec{"${np}-stripped"}) = remove_outer($namec{$np});
    }
  }

  my %nameparts;
  my $strip;
  foreach my $np ('prefix', 'family', 'given', 'suffix') {
    $nameparts{$np} = {string  => $namec{"${np}-stripped"} // undef,
                       initial => $namec{$np} ? $namec{"${np}-i"} : undef};
    $strip->{$np} = $namec{"${np}-strippedflag"};
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
      sortingnamekeytemplatename => 'template name',
    }

=cut

sub parsename_x {
  my ($namestr, $fieldname, $opts, $key) = @_;
  my $xnamesep = Biber::Config->getoption('xnamesep');
  my %nps = map {$_ => 1} $dm->get_constant_value('nameparts');

  my %namec;
  my %pernameopts;
  foreach my $np (split_xsv($namestr)) {# Can have x inside records so use Text::CSV
    my ($npn, $npv) = $np =~ m/^(.+)\s*$xnamesep\s*(.+)$/x;
    $npn = lc($npn);

    # per-name options
    if ($CONFIG_SCOPEOPT_BIBLATEX{NAME}->{$npn}) {
      if ($CONFIG_OPTTYPE_BIBLATEX{$npn} and
          $CONFIG_OPTTYPE_BIBLATEX{$npn} eq 'boolean') {
        $npv = map_boolean($npv, 'tonum');
      }
      my $oo = expand_option($npn, $npv, $CONFIG_BIBLATEX_NAME_OPTIONS{$npn}->{INPUT});

      foreach my $o ($oo->@*) {
        $pernameopts{$o->[0]} = $o->[1];
      }
      next;
    }

    unless ($nps{$npn =~ s/-i$//r}) {
      biber_warn("Invalid namepart '$npn' found in extended name format name '$fieldname' in entry '$key', ignoring");
      next;
    }

    if ($npn =~ m/-i$/) {
      $namec{$npn} = _split_initials($npv);
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

  my %nameparts;
  foreach my $n (keys %nps) {
    $nameparts{$n} = {string  => $namec{$n} // undef,
                      initial => exists($namec{$n}) ? $namec{"${n}-i"} : undef};
  }

  # The "strip" entry tells us which of the name parts had outer braces
  # stripped during processing so we can add them back when printing the
  # .bbl so as to maintain maximum BibTeX compatibility
  return  Biber::Entry::Name->new(
                                  %nameparts,
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

François Charette, C<< <firmicus at ankabut.net> >>
Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our Github tracker at
L<https://github.com/plk/biber/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2018 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
