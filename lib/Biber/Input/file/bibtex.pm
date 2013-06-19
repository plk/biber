package Biber::Input::file::bibtex;
use v5.16;
use strict;
use warnings;
use sigtrap qw(handler TBSIG SEGV);
use base 'Exporter';

use Carp;
use Text::BibTeX qw(:nameparts :joinmethods :metatypes);
use Text::BibTeX::Name;
use Text::BibTeX::NameFormat;
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
                'field' => {
                            'default'  => {
                                           'csv'      => \&_verbatim,
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
                            'csv'      => {
                                           'entrykey' => \&_csv,
                                           'keyword'  => \&_csv,
                                           'option'   => \&_csv,
                                          }
                           },
                'list' => {
                           'default'   => {
                                           'key'      => \&_list,
                                           'literal'  => \&_list,
                                           'name'     => \&_name
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
    if ($1) { # HTTPS
      # use IO::Socket::SSL qw(debug99); # useful for debugging SSL issues
      # We have to explicitly set the cert path because otherwise the https module
      # can't find the .pem when PAR::Packer'ed
      if (not exists($ENV{PERL_LWP_SSL_CA_FILE}) and
          not defined(Biber::Config->getoption('ssl-nointernalca'))) {
        require Mozilla::CA; # Have to explicitly require this here to get it into %INC below
        # we assume that the default CA file is in .../Mozilla/CA/cacert.pem
        (my $vol, my $dir, undef) = File::Spec->splitpath( $INC{"Mozilla/CA.pm"} );
        $dir =~ s/\/$//; # splitpath sometimes leaves a trailing '/'
        $ENV{PERL_LWP_SSL_CA_FILE} = File::Spec->catpath($vol, "$dir/CA", 'cacert.pem');
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
                               DIR => $Biber::MASTER->biber_tempdir);
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
    $logger->debug("All cached citekeys will be used for section '$secnum'");
    # Loop over all entries, creating objects
    while (my ($key, $entry) = each %{$cache->{data}{$filename}}) {

      # Record a key->datasource name mapping for error reporting
      $section->set_keytods($key, $filename);

      unless (create_entry($key, $entry, $source, $smaps)) {
        # if create entry returns false, remove the key from the cache
        @{$cache->{orig_key_order}{$filename}} = grep {$key ne $_} @{$cache->{orig_key_order}{$filename}};
      }
    }

    # Loop over all aliases, creating data in section object
    # Since this is allkeys, we are guaranteed that the real entry for the alias
    # will be available
    while (my ($alias, $key) = each %{$cache->{data}{citekey_aliases}}) {
      $section->set_citekey_alias($alias, $key);
      $logger->debug("Citekey '$alias' is an alias for citekey '$key'");
    }

    # If allkeys, push all bibdata keys into citekeys (if they are not already there).
    # We are using the special "orig_key_order" array which is used to deal with the
    # situation when sorting=none and allkeys is set. We need an array rather than the
    # keys from the bibentries hash because we need to preserve the original order of
    # the .bib as in this case the sorting sub "citeorder" means "bib order" as there are
    # no explicitly cited keys
    $section->add_citekeys(@{$cache->{orig_key_order}{$filename}});
    $logger->debug("Added all citekeys to section '$secnum': " . join(', ', $section->get_citekeys));
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
          create_entry($wanted_key, $entry, $source, $smaps);
        }
        # found a key, remove it from the list of keys we want
        @rkeys = grep {$wanted_key ne $_} @rkeys;

      }
      elsif (my $rk = $cache->{data}{citekey_aliases}{$wanted_key}) {
        $logger->debug("Citekey '${wanted_key}' is an alias for citekey '$rk'");
        $section->set_citekey_alias($wanted_key, $rk);

        # Make sure there is a real, cited entry for the citekey alias
        # just in case only the alias is cited
        unless ($section->bibentries->entry_exists($rk)) {
          if (my $entry = $cache->{data}{$filename}{$rk}) {
            create_entry($rk, $entry, $source, $smaps);
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

  return @rkeys;
}

=head2 create_entry

   Create a Biber::Entry object from a Text::BibTeX object

=cut

sub create_entry {
  my ($key, $entry, $source, $smaps) = @_;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $bibentries = $section->bibentries;
  my $bibentry = new Biber::Entry;

  $bibentry->set_field('citekey', $key);
  my $ds = $section->get_keytods($key);

  if ( $entry->metatype == BTE_REGULAR ) {

    # Save pre-mapping data. Might be useful somewhere
    $bibentry->set_field('rawdata', biber_decode_utf8($entry->print_s));

    # Datasource mapping applied in $smap order (USER->STYLE->DRIVER)
    foreach my $smap (@$smaps) {
      my $level = $smap->{level};
      $smap->{map_overwrite} = $smap->{map_overwrite} // 0; # default

    MAP:    foreach my $map (@{$smap->{map}}) {
        my $last_type = $entry->type; # defaults to the entrytype unless changed below
        my $last_field = undef;
        my $last_fieldval = undef;

        my @imatches; # For persising parenthetical matches over several steps

        # Check pertype restrictions
        unless (not exists($map->{per_type}) or
                first {lc($_->{content}) eq $entry->type} @{$map->{per_type}}) {
          next;
        }

        # Check per_datasource restrictions
        # Don't compare case insensitively - this might not be correct
        unless (not exists($map->{per_datasource}) or
                first {$_->{content} eq $source} @{$map->{per_datasource}}) {
          next;
        }

        # loop over mapping steps
        foreach my $step (@{$map->{map_step}}) {

          # entry deletion. Really only useful with allkeys or tool mode
          if ($step->{map_entry_null}) {
            $logger->debug("Source mapping (type=$level, key=$key): Ignoring entry completely");
            return 0; # don't create an entry at all
          }

          # Entrytype map
          if (my $source = $step->{map_type_source}) {
            unless ($entry->type eq lc($source)) {
              # Skip the rest of the map if this step doesn't match and match is final
              if ($step->{map_final}) {
                $logger->debug("Source mapping (type=$level, key=$key): Entry type is '" . $entry->type . "' but map wants '" . lc($source) . "' and step has 'final' set, skipping rest of map ...");
                next MAP;
              }
              else {
                # just ignore this step
                $logger->debug("Source mapping (type=$level, key=$key): Entry type is '" . $entry->type . "' but map wants '" . lc($source) . "', skipping step ...");
                next;
              }
            }
            # Change entrytype if requested
            $last_type = $entry->type;
            $logger->debug("Source mapping (type=$level, key=$key): Changing entry type from '$last_type' to " . lc($step->{map_type_target}));
            $entry->set_type(lc($step->{map_type_target}));
          }

          # Field map
          if (my $source = $step->{map_field_source}) {
            # key is a psudo-field. It's guaranteed to exist so
            # just check if that's what's being asked for
            unless (lc($source) eq 'entrykey' or
                    $entry->exists(lc($source))) {
              # Skip the rest of the map if this step doesn't match and match is final
              if ($step->{map_final}) {
                $logger->debug("Source mapping (type=$level, key=$key): No field '" . lc($source) . "' and step has 'final' set, skipping rest of map ...");
                next MAP;
              }
              else {
                # just ignore this step
                $logger->debug("Source mapping (type=$level, key=$key): No field '" . lc($source) . "', skipping step ...");
                next;
              }
            }

            $last_field = $source;
            $last_fieldval = lc($source) eq 'entrykey' ? biber_decode_utf8($entry->key) : biber_decode_utf8($entry->get(lc($source)));

            my $negmatch = 0;
            # Negated matches are a normal match with a special flag
            if (my $nm = $step->{map_notmatch}) {
              $step->{map_match} = $nm;
              $negmatch = 1;
            }

            # map fields to targets
            if (my $m = $step->{map_match}) {
              if (defined($step->{map_replace})) { # replace can be null

                # Can't modify entrykey
                if (lc($source) eq 'entrykey') {
                  $logger->debug("Source mapping (type=$level, key=$key): Field '" . lc($source) . "' is 'entrykey'- cannot remap the value of this field, skipping ...");
                  next;
                }

                my $r = $step->{map_replace};
                $logger->debug("Source mapping (type=$level, key=$key): Doing match/replace '$m' -> '$r' on field '" . lc($source) . "'");
                $entry->set(lc($source),
                            ireplace($last_fieldval, $m, $r));
              }
              else {
                unless (@imatches = imatch($last_fieldval, $m, $negmatch)) {
                  # Skip the rest of the map if this step doesn't match and match is final
                  if ($step->{map_final}) {
                    $logger->debug("Source mapping (type=$level, key=$key): Field '" . lc($source) . "' does not match '$m' and step has 'final' set, skipping rest of map ...");
                    next MAP;
                  }
                  else {
                    # just ignore this step
                    $logger->debug("Source mapping (type=$level, key=$key): Field '" . lc($source) . "' does not match '$m', skipping step ...");
                    next;
                  }
                }
              }
            }

            # Set to a different target if there is one
            if (my $target = $step->{map_field_target}) {

              # Can't remap entry key pseudo-field
              if (lc($source) eq 'entrykey') {
                $logger->debug("Source mapping (type=$level, key=$key): Field '$source' is 'entrykey'- cannot map this to a new field as you must have an entrykey, skipping ...");
                next;
              }

              if ($entry->exists(lc($target))) {
                if ($map->{map_overwrite} // $smap->{map_overwrite}) {
                  $logger->debug("Source mapping (type=$level, key=$key): Overwriting existing field '$target'");
                }
                else {
                  $logger->debug("Source mapping (type=$level, key=$key): Field '$source' is aliased to field '$target' but both are defined, skipping ...");
                  next;
                }
              }
              $entry->set(lc($target), biber_decode_utf8($entry->get(lc($source))));
              $entry->delete(lc($source));
            }
          }

          # field changes
          if (my $field = $step->{map_field_set}) {

            # Deal with special tokens
            if ($step->{map_null}) {
              $logger->debug("Source mapping (type=$level, key=$key): Deleting field '$field'");
              $entry->delete(lc($field));
            }
            else {
              if ($entry->exists(lc($field))) {
                unless ($map->{map_overwrite} // $smap->{map_overwrite}) {
                  if ($step->{map_final}) {
                    # map_final is set, ignore and skip rest of step
                    $logger->debug("Source mapping (type=$level, key=$key): Field '" . lc($field) . "' exists, overwrite is not set and step has 'final' set, skipping rest of map ...");
                    next MAP;
                  }
                  else {
                    # just ignore this step
                    $logger->debug("Source mapping (type=$level, key=$key): Field '" . lc($field) . "' exists and overwrite is not set, skipping step ...");
                    next;
                  }
                }
              }

              # If append is set, keep the original value and append the new
              my $orig = $step->{map_append} ? biber_decode_utf8($entry->get(lc($field))) : '';

              if ($step->{map_origentrytype}) {
                next unless $last_type;
                $logger->debug("Source mapping (type=$level, key=$key): Setting field '" . lc($field) . "' to '${orig}${last_type}'");
                $entry->set(lc($field), $orig . $last_type);
              }
              elsif ($step->{map_origfieldval}) {
                next unless $last_fieldval;
                $logger->debug("Source mapping (type=$level, key=$key): Setting field '" . lc($field) . "' to '${orig}${last_fieldval}'");
                $entry->set(lc($field), $orig . $last_fieldval);
              }
              elsif ($step->{map_origfield}) {
                next unless $last_field;
                $logger->debug("Source mapping (type=$level, key=$key): Setting field '" . lc($field) . "' to '${orig}${last_field}'");
                $entry->set(lc($field), $orig . $last_field);
              }
              else {
                my $fv = $step->{map_field_value};
                # Now re-instate any unescaped $1 .. $9 to get round these being
                # dynamically scoped and being null when we get here from any
                # previous map_match
                $fv =~ s/(?<!\\)\$(\d)/$imatches[$1-1]/ge;
                $logger->debug("Source mapping (type=$level, key=$key): Setting field '" . lc($field) . "' to '${orig}${fv}'");
                $entry->set(lc($field), $orig . $fv);
              }
            }
          }
        }
      }
    }

    my $entrytype = biber_decode_utf8($entry->type);

    # We put all the fields we find modulo field aliases into the object
    # validation happens later and is not datasource dependent
    foreach my $f ($entry->fieldlist) {

      # In tool mode, keep the raw data fields
      if (Biber::Config->getoption('tool')) {
        $bibentry->set_rawfield($f, biber_decode_utf8($entry->get($f)));
      }

      # We have to process local options as early as possible in order
      # to make them available for things that need them like parsename()
      if ($f eq 'options') {
        my $value = biber_decode_utf8($entry->get($f));
        process_entry_options($key, [ split(/\s*,\s*/, $value) ]);
        # Save the raw options in case we are to output another input format like
        # biblatexml
        $bibentry->set_field('rawoptions', $value);
      }

      # Now run any defined handler
      if ($dm->is_field($f)) {
        my $handler = _get_handler($f);
        &$handler($bibentry, $entry, $f, $key);
      }
      elsif (Biber::Config->getoption('validate_datamodel')) {
        biber_warn("Datamodel: Entry '$key' ($ds): Field '$f' invalid in data model - ignoring", $bibentry);
      }
    }

    $bibentry->set_field('entrytype', $entrytype);
    $bibentry->set_field('datatype', 'bibtex');
    $bibentries->add_entry($key, $bibentry);
  }

  return 1;
}

# HANDLERS
# ========
my $S = Biber::Config->getoption('mssplit');
my $fl_re = qr/\A([^$S]+)$S?(original|translated|romanised|uniform)?$S?(.+)?\z/;

# Literal fields
sub _literal {
  my ($bibentry, $entry, $f) = @_;
  my $value = biber_decode_utf8($entry->get($f));
  my ($field, $form, $lang) = $f =~ m/$fl_re/xms;
  # If we have already split some date fields into literal fields
  # like date -> year/month/day, don't overwrite them with explicit
  # year/month
  return if ($f eq 'year' and $bibentry->get_datafield('year'));
  return if ($f eq 'month' and $bibentry->get_datafield('month'));

  # Try to sanitise months to biblatex requirements
  if ($f eq 'month') {
    $bibentry->set_datafield($field, _hack_month($value), $form, $lang);
  }
  else {
    $bibentry->set_datafield($field, $value, $form, $lang);
  }
  return;
}

# URI fields
sub _uri {
  my ($bibentry, $entry, $f) = @_;
  my $value = NFC(decode_utf8($entry->get($f)));# Unicode NFC boundary (before hex encoding)
  my ($field, $form, $lang) = $f =~ m/$fl_re/xms;

  # If there are some escapes in the URI, unescape them
  if ($value =~ /\%/) {
    $value =~ s/\\%/%/g; # just in case someone BibTeX escaped the "%"
    # This is what uri_unescape() does but it's faster
    $value =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
    $value = NFC(decode_utf8($value));# Unicode NFC boundary (before hex encoding)
  }

  $value = URI->new($value)->as_string;

  $bibentry->set_datafield($field, $value, $form, $lang);
  return;
}

# CSV field form
sub _csv {
  my ($bibentry, $entry, $f) = @_;
  $bibentry->set_datafield($f, [ split(/\s*,\s*/, biber_decode_utf8($entry->get($f))) ]);
  return;
}

# Verbatim fields
sub _verbatim {
  my ($bibentry, $entry, $f) = @_;
  my $value = biber_decode_utf8($entry->get($f));
  my ($field, $form, $lang) = $f =~ m/$fl_re/xms;
  $bibentry->set_datafield($field, $value, $form, $lang);
  return;
}

# Range fields
sub _range {
  my ($bibentry, $entry, $f) = @_;
  my $values_ref;
  my $value = biber_decode_utf8($entry->get($f));
  my ($field, $form, $lang) = $f =~ m/$fl_re/xms;

  my @values = split(/\s*[;,]\s*/, $value);
  # Here the "-–" contains two different chars even though they might
  # look the same in some fonts ...
  # If there is a range sep, then we set the end of the range even if it's null
  # If no  range sep, then the end of the range is undef
  foreach my $value (@values) {
    $value =~ m/\A\s*([^\p{Pd}]+)\s*\z/xms ||# Simple value without range
      $value =~ m/\A\s*(\{[^\}]+\}|[^\p{Pd} ]+)\s*([\p{Pd}]+)\s*(\{[^\}]+\}|[^\p{Pd}]*)\s*\z/xms;
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
    push @$values_ref, [$start || '', $end];
  }
  $bibentry->set_datafield($field, $values_ref, $form, $lang);
  return;
}


# Names
sub _name {
  my ($bibentry, $entry, $f, $key) = @_;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $value = biber_decode_utf8($entry->get($f));
  my ($field, $form, $lang) = $f =~ m/$fl_re/xms;

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
    unless ($name =~ m/\A{\X+}\z/xms) { # Ignore these tests for escaped names
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

    # Skip names that don't parse for some reason (like no lastname found - see parsename())
    next unless my $no = parsename($name, $f, {useprefix => $useprefix});

    # Deal with implied "et al" in data source
    if (lc($no->get_namestring) eq Biber::Config->getoption('others_string')) {
      $names->set_morenames;
    }
    else {
      $names->add_name($no);
    }

  }
  $bibentry->set_datafield($field, $names, $form, $lang);
  return;
}

# Dates
# Date fields can't have script forms - they are just a(n ISO) standard format
sub _date {
  my ($bibentry, $entry, $f, $key) = @_;
  my $datetype = $f =~ s/date\z//xmsr;
  my $date = biber_decode_utf8($entry->get($f));
  my ($field, $form, $lang) = $f =~ m/$fl_re/xms;
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
    biber_warn("Datamodel: Entry '$key' ($ds): Invalid format '$date' of date field '$f' - ignoring", $bibentry);
  }
  return;
}

# Bibtex list fields with listsep separator
sub _list {
  my ($bibentry, $entry, $f) = @_;
  my $value = biber_decode_utf8($entry->get($f));
  my ($field, $form, $lang) = $f =~ m/$fl_re/xms;

  my @tmp = Text::BibTeX::split_list($value, Biber::Config->getoption('listsep'));
  @tmp = map { biber_decode_utf8($_) } @tmp;
  @tmp = map { remove_outer($_) } @tmp;
  $bibentry->set_datafield($field, [ @tmp ], $form, $lang);
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

    # Ignore misc BibTeX entry types we don't care about
    next if ( $entry->metatype == BTE_MACRODEF or
              $entry->metatype == BTE_UNKNOWN or
              $entry->metatype == BTE_COMMENT );

    # If an entry has no key, ignore it and warn
    unless ($entry->key) {
      biber_warn("Invalid or undefined BibTeX entry key in file '$pfilename', skipping ...");
      next;
    }

    # Text::BibTeX >= 0.46 passes through all citekey bits, thus allowing utf8 keys
    my $key = biber_decode_utf8($entry->key);

    # Check if this key has already been registered as a citekey alias, if
    # so, the key takes priority and we delete the alias
    if (exists($cache->{data}{citekey_aliases}{$key})) {
      biber_warn("Citekey alias '$key' is also a real entry key, skipping ...");
      delete($cache->{data}{citekey_aliases}{$key});
    }

    # Any secondary keys?
    # We can't do this with a driver entry for the IDS field as this needs
    # an entry object creating first and the whole point of aliases is that
    # there is no entry object
    if (my $ids = biber_decode_utf8($entry->get('ids'))) {
      foreach my $id (split(/\s*,\s*/, $ids)) {

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

    # If we've already seen this key in a datasource, ignore it and warn
    if ($section->has_everykey($key)) {
      biber_warn("Duplicate entry key: '$key' in file '$filename', skipping ...");
      next;
    }
    else {
      $section->add_everykey($key);
    }

    # Bad entry
    unless ($entry->parse_ok) {
      biber_warn("Entry $key does not parse correctly");
      next;
    }

    # Cache the entry so we don't have to read the file again on next pass.
    # Two reasons - So we avoid T::B macro redef warnings and speed
    $cache->{data}{$filename}{$key} = $entry;
    # We do this as otherwise we have no way of determining the origing .bib entry order
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

  File::Slurp::write_file($ufilename, NFC(encode('UTF-8', $buf))) or
      biber_error("Can't write $ufilename");# Unicode NFC boundary

  # Decode LaTeX to UTF8 if output is UTF-8
  if (Biber::Config->getoption('output_encoding') eq 'UTF-8') {
    my $buf = File::Slurp::read_file($ufilename) or biber_error("Can't read $ufilename");
    $buf = NFD(decode('UTF-8', $buf));# Unicode NFD boundary

    $logger->info('Decoding LaTeX character macros into UTF-8');
    $logger->trace("Buffer before decoding -> '$buf'");
    $buf = Biber::LaTeX::Recode::latex_decode($buf, strip_outer_braces => 1);
    $logger->trace("Buffer after decoding -> '$buf'");

    File::Slurp::write_file($ufilename, NFC(encode('UTF-8', $buf))) or
        biber_error("Can't write $ufilename");# Unicode NFC boundary
  }

  return $ufilename;
}

=head2 parsename

    Given a name string, this function returns a Biber::Entry::Name object
    with all parts of the name resolved according to the BibTeX conventions.

    parsename('John Doe')
    returns an object which internally looks a bit like this:

    { firstname     => 'John',
      firstname_i   => ['J'],
      lastname      => 'Doe',
      lastname_i    => ['D'],
      prefix        => undef,
      prefix_i      => undef,
      suffix        => undef,
      suffix_i      => undef,
      namestring    => 'Doe, John',
      nameinitstring => 'Doe_J',
      strip          => {'firstname' => 0,
                         'lastname'  => 0,
                         'prefix'    => 0,
                         'suffix'    => 0}
      }

=cut

sub parsename {
  my ($namestr, $fieldname, $opts, $testing) = @_;
  $logger->debug("Parsing namestring '$namestr'");
  my $usepre = $opts->{useprefix};
  # First sanitise the namestring due to Text::BibTeX::Name limitations on whitespace
  $namestr =~ s/\A\s*//xms; # leading whitespace
  $namestr =~ s/\s*\z//xms; # trailing whitespace
  $namestr =~ s/\s+/ /g;    # Collapse internal whitespace

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
  my $lastname  = biber_decode_utf8($name->format($l_f));
  my $firstname = biber_decode_utf8($name->format($f_f));
  my $prefix    = biber_decode_utf8($name->format($p_f));
  my $suffix    = biber_decode_utf8($name->format($s_f));

  # Skip the name if we can't determine last name - otherwise many other things will
  # fail later
  unless ($lastname) {
    biber_warn("Couldn't determine Last Name for name \"$namestr\" - ignoring name");
    return 0;
  }

  # Variables to hold the Text::BibTeX::NameFormat generated initials string
  my $gen_lastname_i;
  my $gen_firstname_i;
  my $gen_prefix_i;
  my $gen_suffix_i;

  # Use a copy of $name so that when we generate the
  # initials, we do so without certain things. This is easier than trying
  # hack robust initials code into btparse ...
  my $nd_namestr = strip_noinit($namestr);

  # Make initials with ties in between work. btparse doesn't understand this so replace with
  # spaces - this is fine as we are just generating initials
  $nd_namestr =~ s/(\w)\.~(\w)/$1. $2/g;

  # We use NFC here as we are "outputting" to an external module
  my $nd_name = new Text::BibTeX::Name(NFC($nd_namestr), $fieldname);

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

  $gen_lastname_i    = inits(biber_decode_utf8($nd_name->format($li_f)));
  $gen_firstname_i   = inits(biber_decode_utf8($nd_name->format($fi_f)));
  $gen_prefix_i      = inits(biber_decode_utf8($nd_name->format($pi_f)));
  $gen_suffix_i      = inits(biber_decode_utf8($nd_name->format($si_f)));

  my $namestring = '';
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
  # lastname
  my $ls;
  my $lastname_stripped;
  my $lastname_i;
  if ($lastname) {
    $lastname_i        = $gen_lastname_i;
    $lastname_stripped = remove_outer($lastname);
    $ls = $lastname ne $lastname_stripped ? 1 : 0;
    $namestring .= "$lastname_stripped, ";
  }
  # suffix
  my $ss;
  my $suffix_stripped;
  my $suffix_i;
  if ($suffix) {
    $suffix_i        = $gen_suffix_i;
    $suffix_stripped = remove_outer($suffix);
    $ss = $suffix ne $suffix_stripped ? 1 : 0;
    $namestring .= "$suffix_stripped, ";
  }
  # firstname
  my $fs;
  my $firstname_stripped;
  my $firstname_i;
  if ($firstname) {
    $firstname_i        = $gen_firstname_i;
    $firstname_stripped = remove_outer($firstname);
    $fs = $firstname ne $firstname_stripped ? 1 : 0;
    $namestring .= "$firstname_stripped";
  }

  # Remove any trailing comma and space if, e.g. missing firstname
  # Replace any nbspes
  $namestring =~ s/,\s+\z//xms;
  $namestring =~ s/~/ /gxms;

  # Construct $nameinitstring
  my $nameinitstr = '';
  $nameinitstr .= join('', @$prefix_i) . '_' if ( $usepre and $prefix );
  $nameinitstr .= $lastname if $lastname;
  $nameinitstr .= '_' . join('', @$suffix_i) if $suffix;
  $nameinitstr .= '_' . join('', @$firstname_i) if $firstname;
  $nameinitstr =~ s/\s+/_/g;
  $nameinitstr =~ s/~/_/g;

  # output is always NFC and so when testing the output of this routine, need NFC
  if ($testing) {
    if ($firstname) {
      $firstname_stripped = NFC($firstname_stripped);
      $firstname_i        = [ map {NFC($_)} @$firstname_i ];
    }
    if ($lastname) {
      $lastname_stripped  = NFC($lastname_stripped);
      $lastname_i         = [ map {NFC($_)} @$lastname_i ];
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
    firstname       => $firstname      eq '' ? undef : $firstname_stripped,
    firstname_i     => $firstname      eq '' ? undef : $firstname_i,
    lastname        => $lastname       eq '' ? undef : $lastname_stripped,
    lastname_i      => $lastname       eq '' ? undef : $lastname_i,
    prefix          => $prefix         eq '' ? undef : $prefix_stripped,
    prefix_i        => $prefix         eq '' ? undef : $prefix_i,
    suffix          => $suffix         eq '' ? undef : $suffix_stripped,
    suffix_i        => $suffix         eq '' ? undef : $suffix_i,
    namestring      => $namestring,
    nameinitstring  => $nameinitstr,
    strip           => {'firstname' => $fs,
                        'lastname'  => $ls,
                        'prefix'    => $ps,
                        'suffix'    => $ss}
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
  if ($in_month =~ m/\A\s*((?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec).*)\s*\z/i) {
    return $months{lc(Unicode::GCString->new($1)->substr(0,3)->as_string)};
  }
  else {
    return $in_month;
  }
}

sub _get_handler {
  my $field = shift;
  my $S = Biber::Config->getoption('mssplit');
  $field =~ s/$S(?:original|translated|romanised|uniform)$S?.*$//;
  if (my $h = $handlers->{CUSTOM}{$field}) {
    return $h;
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

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2013 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
