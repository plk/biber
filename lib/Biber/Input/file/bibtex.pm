package Biber::Input::file::bibtex;
use 5.014000;
use strict;
use warnings;
use sigtrap qw(handler TBSIG SEGV);
use base 'Exporter';

use Carp;
use Text::BibTeX qw(:nameparts :joinmethods :metatypes);
use Text::BibTeX::Name;
use Text::BibTeX::NameFormat;
use Biber::Constants;
use Biber::Entries;
use Biber::Entry;
use Biber::Entry::Names;
use Biber::Entry::Name;
use Biber::Sections;
use Biber::Section;
use Biber::Structure;
use Biber::Utils;
use Biber::Config;
use Encode;
use File::Spec;
use File::Temp;
use Log::Log4perl qw(:no_extra_logdie_message);
use List::AllUtils qw( :all );
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

# Handlers for field types
# The names of these have nothing to do whatever with the biblatex field types
# They just started out copying them - they are categories of this specific
# data source data types
my %handlers = (
                'date'     => \&_date,
                'list'     => \&_list,
                'literal'  => \&_literal,
                'name'     => \&_name,
                'range'    => \&_range,
                'verbatim' => \&_verbatim
);


# Read driver config file
my $dcfxml = driver_config('bibtex');

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

  # If it's a remote data file, fetch it first
  if ($source =~ m/\A(?:https?|ftp):\/\//xms) {
    $logger->info("Data source '$source' is a remote BibTeX data source - fetching ...");
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
      create_entry($key, $entry, $source);
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
    # sitiation when sorting=none and allkeys is set. We need an array rather than the
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
      if (my $entry = $cache->{data}{$filename}{$wanted_key}) {
        $logger->debug("Found key '$wanted_key' in Text::BibTeX cache");
        # Skip creation if it's already been done, for example, via a citekey alias
        unless ($section->bibentries->entry_exists($wanted_key)) {
          create_entry($wanted_key, $entry, $source);
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
            create_entry($rk, $entry, $source);
            $section->add_citekeys($rk);
          }
        }

        # found a key, remove it from the list of keys we want
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
  my ($key, $entry, $source) = @_;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $bibentries = $section->bibentries;
  my $bibentry = new Biber::Entry;

  $bibentry->set_field('citekey', $key);

  # Get a reference to the sourcemap option, if it exists
  my $user_map;
  if (defined(Biber::Config->getoption('sourcemap'))) {
    if (my $m = first {$_->{datatype} eq 'bibtex'} @{Biber::Config->getoption('sourcemap')} ) {
      $user_map = $m;
    }
  }

  if ( $entry->metatype == BTE_REGULAR ) {
    # DATASOURCE MAPPING DEFINED BY USER IN CONFIG FILE OR .bcf
MAP:    foreach my $map (@{$user_map->{map}}) {
      my $last_type = undef;
      my $last_field = undef;
      my $last_fieldval = undef;

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

        # Entrytype map
        if (my $source = $step->{map_type_source}) {
          unless ($entry->type eq lc($source) or  $source eq '*') {
            # Skip the rest of the map if this step doesn't match
            if ($step->{map_final}) {
              next MAP;
            }
            else {
              # just ignore this step
              next;
            }
          }
          # Change entrytype if requested
          $last_type = $entry->type;
          $entry->set_type(lc($step->{map_type_target}));
        }

        # Field map
        if (my $source = $step->{map_field_source}) {
          unless ($entry->exists(lc($source))) {
            # Skip the rest of the map if this step doesn't match
            if ($step->{map_final}) {
              next MAP;
            }
            else {
              # just ignore this step
              next;
            }
          }

          $last_field = $source;
          $last_fieldval = decode_utf8($entry->get(lc($source)));

          # map fields to targets
          if (my $m = $step->{map_match}) {
            if (my $r = $step->{map_replace}) {
              $entry->set(lc($step->{map_field_source}),
                          ireplace($last_fieldval, $m, $r));
            }
            else {
              unless (imatch($last_fieldval, $m)) {
                # Skip the rest of the map if this step doesn't match
                if ($step->{map_final}) {
                  next MAP;
                }
                else {
                  # just ignore this step
                  next;
                }
              }
            }
          }
          elsif ($step->{map_null}) {
            $entry->delete(lc($source));
            next;
          }
          elsif ($step->{map_origentrytype}) {
            next unless $last_type;
            $entry->set(lc($source), $last_type);
            next;
          }

          # Set to a different target if there is one
          if (my $target = $step->{map_field_target}) {
            if ($entry->exists(lc($target))) {
              if ($map->{map_overwrite} // $user_map->{map_overwrite}) {
                biber_warn("Overwriting existing field '$target' while processing entry '$key'", $bibentry);
              }
              else {
                biber_warn("Not overwriting existing field '$target' while processing entry '$key'", $bibentry);
                next;
              }
            }
            $entry->set(lc($target), decode_utf8($entry->get(lc($source))));
            $entry->delete(lc($source));
          }
        }

        # field creation
        if (my $field = $step->{map_field_set}) {

          # Deal with special tokens
          if ($step->{map_null}) {
            $entry->delete(lc($field));
          }
          if ($entry->exists(lc($field))) {
            if ($map->{map_overwrite} // $user_map->{map_overwrite}) {
              biber_warn("Overwriting existing field '$field' while processing entry '$key'", $bibentry);
            }
            else {
              biber_warn("Not overwriting existing field '$field' while processing entry '$key'", $bibentry);
              next;
            }
          }

          if ($step->{map_origentrytype}) {
            next unless $last_type;
            $entry->set(lc($field), $last_type);
          }
          elsif ($step->{map_origfieldval}) {
            next unless $last_fieldval;
            $entry->set(lc($field), $last_fieldval);
          }
          elsif ($step->{map_origfield}) {
            next unless $last_field;
            $entry->set(lc($field), $last_field);
          }
          else {
            $entry->set(lc($field), $step->{map_field_value});
          }
        }
      }
    }

    # We put all the fields we find modulo field aliases into the object
    # validation happens later and is not datasource dependent
FLOOP:  foreach my $f ($entry->fieldlist) {

      # We have to process local options as early as possible in order
      # to make them available for things that need them like parsename()
      if ($f eq 'options') {
        my $value = decode_utf8($entry->get($f));
        $Biber::MASTER->process_entry_options($key, $value);
        # Save the raw options in case we are to output another input format like
        # biblatexml
        $bibentry->set_field('rawoptions', $value);
      }

      # FIELD MAPPING (ALIASES) DEFINED BY DRIVER IN DRIVER CONFIG FILE
      if (my $from = $dcfxml->{fields}{field}{$f}) {
        my $to = $f; # By default, field to set internally is the same as data source

        # Redirect any alias
        if (my $aliases = $from->{alias}) { # complex aliases with alsoset clauses
          foreach my $alias (@$aliases) {
            if (my $t = $alias->{aliasfortype}) { # type-specific alias
              if (lc($t) eq lc($entry->type)) {
                my $a = $alias->{aliasof};
                $logger->debug("Found alias '$a' of field '$f' in entry '$key'");
                # If both a field and its alias is set, warn and delete alias field
                if ($entry->exists($a)) {
                  biber_warn("Field '$f' is aliased to field '$a' but both are defined in entry with key '$key' - skipping alias", $bibentry);
                  next;
                }
                $from = $dcfxml->{fields}{field}{$a};
                $to = $a;  # Field to set internally is the alias
                last;
              }
            }
            else {
              my $a = $alias->{aliasof}; # global alias
              $logger->debug("Found alias '$a' of field '$f' in entry '$key'");
              # If both a field and its alias is set, warn and delete alias field
              if ($entry->exists($a)) {
                biber_warn("Field '$f' is aliased to field '$a' but both are defined in entry with key '$key' - skipping alias", $bibentry);
                next;
              }
              $from = $dcfxml->{fields}{field}{$a};
              $to = $a; # Field to set internally is the alias
            }

            # Deal with additional fields to split information into (one->many map)
            foreach my $alsoset (@{$alias->{alsoset}}) {
              # If both a field and an alsoset field are set, warn and ignore alsoset
              if ($entry->exists($alsoset->{target})) {
                biber_warn("Field '" . $alsoset->{target}. "' is supposed to be additionally set but it already exists - ignoring", $bibentry);
                next;
              }
              my $val = $alsoset->{value} // $f; # defaults to original field name if no value
              $bibentry->set_datafield($alsoset->{target}, $val);
            }
          }
        }
        elsif (my $alias = $from->{aliasof}) { # simple alias
          $logger->debug("Found alias '$alias' of field '$f' in entry '$key'");
          if ($entry->exists($alias)) {
            biber_warn("Field '$f' is aliased to field '$alias' but both are defined in entry with key '$key' - skipping alias", $bibentry);
            next;
          }
          $from = $dcfxml->{fields}{field}{$alias};
          $to = $alias; # Field to set internally is the alias
        }
        # Now run any defined handler
        &{$handlers{$from->{handler}}}($bibentry, $entry, $f, $to, $key);

      }

      # Default if no explicit way to set the field
      else {
        my $value = decode_utf8($entry->get($f));
        $bibentry->set_datafield($f, $value);
      }
    }

    # Driver aliases
    if (my $ealias = $dcfxml->{entrytypes}{entrytype}{lc($entry->type)}) {
      $bibentry->set_field('entrytype', $ealias->{aliasof}{content});
      foreach my $alsoset (@{$ealias->{alsoset}}) {
        # drivers never overwrite existing fields
        if ($bibentry->field_exists(lc($alsoset->{target}))) {
          biber_warn("Not overwriting existing field '" . $alsoset->{target} . "' during aliasing of entrytype '" . $entry->type . "' to '" . lc($ealias->{aliasof}{content}) . "' in entry '$key'", $bibentry);
          next;
        }
        $bibentry->set_datafield($alsoset->{target}, $alsoset->{value});
      }
    }
    else { # No alias
      $bibentry->set_field('entrytype', $entry->type);
    }

    $bibentry->set_field('datatype', 'bibtex');
    $bibentries->add_entry($key, $bibentry);
  }

  return;
}

# HANDLERS
# ========

# Literal fields
sub _literal {
  my ($bibentry, $entry, $f, $to, $key) = @_;
  my $value = decode_utf8($entry->get($f));

  # If we have already split some date fields into literal fields
  # like date -> year/month/day, don't overwrite them with explicit
  # year/month
  return if ($to eq 'year' and $bibentry->get_datafield('year'));
  return if ($to eq 'month' and $bibentry->get_datafield('month'));

  # Try to sanitise months to biblatex requirements
  if ($to eq 'month') {
    $bibentry->set_datafield($to, _hack_month($value));
  }
  else {
    $bibentry->set_datafield($to, $value);
  }
  return;
}

# Verbatim fields
sub _verbatim {
  my ($bibentry, $entry, $f, $to, $key) = @_;
  my $value = decode_utf8($entry->get($f));

  $bibentry->set_datafield($to, $value);
  return;
}

# Range fields
sub _range {
  my ($bibentry, $entry, $f, $to, $key) = @_;
  my $values_ref;
  my $value = decode_utf8($entry->get($f));

  my @values = split(/\s*,\s*/, $value);
  # Here the "-–" contains two different chars even though they might
  # look the same in some fonts ...
  # If there is a range sep, then we set the end of the range even if it's null
  # If no  range sep, then the end of the range is undef
  foreach my $value (@values) {
    $value =~ m/\A\s*([^-–]+)([-–]*)([^-–]*)\s*\z/xms;
    my $end;
    if ($2) {
      $end = $3;
    }
    else {
      $end = undef;
    }
    push @$values_ref, [$1 || '', $end];
  }
  $bibentry->set_datafield($to, $values_ref);
  return;
}


# Names
sub _name {
  my ($bibentry, $entry, $f, $to, $key) = @_;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $value = decode_utf8($entry->get($f));

  my @tmp = Text::BibTeX::split_list($value, 'and');
  my $useprefix = Biber::Config->getblxoption('useprefix', $bibentry->get_field('entrytype'), $key);
  my $names = new Biber::Entry::Names;
  foreach my $name (@tmp) {

    # Consecutive "and" causes Text::BibTeX::Name to segfault
    unless ($name) {
      biber_warn("Name in key '$key' is empty (probably consecutive 'and'): skipping name", $bibentry);
      $section->del_citekey($key);
      next;
    }

    $name = decode_utf8($name);

    # Check for malformed names in names which aren't completely escaped

    # Too many commas
    unless ($name =~ m/\A{.+}\z/xms) { # Ignore these tests for escaped names
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

    my $no = parsename($name, $f, {useprefix => $useprefix});

    # Deal with "and others" in data source
    if (lc($no->get_namestring) eq 'others') {
      $names->set_morenames;
    }
    else {
      $names->add_name($no);
    }

  }
  $bibentry->set_datafield($to, $names);
  return;
}

# Dates
sub _date {
  my ($bibentry, $entry, $f, $to, $key) = @_;
  my ($datetype) = $f =~ m/\A(.*)date\z/xms;
  my $date = decode_utf8($entry->get($f));
  # Just in case we need to look at the original field later
  # an "orig_field" is not counted as current data in the entry
  $bibentry->set_orig_field($f, $f);

  # We are not validating dates here, just syntax parsing
  my $date_re = qr/(\d{4}) # year
                   (?:-(\d{2}))? # month
                   (?:-(\d{2}))? # day
                  /xms;
  if (my ($byear, $bmonth, $bday, $r, $eyear, $emonth, $eday) =
      $date =~ m|\A$date_re(/)?(?:$date_re)?\z|xms) {
    # did this entry get its year/month fields from splitting an ISO8601 date field?
    # We only need to know this for date, year/month as year/month can also
    # be explicitly set. It makes a difference on how we do any potential future
    # date validation
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
    biber_warn("Invalid format '$date' of date field '$f' in entry '$key' - ignoring", $bibentry);
  }
  return;
}

# List fields
sub _list {
  my ($bibentry, $entry, $f, $to, $key) = @_;
  my $value = decode_utf8($entry->get($f));

  my @tmp = Text::BibTeX::split_list($value, 'and');
  @tmp = map { decode_utf8($_) } @tmp;
  @tmp = map { remove_outer($_) } @tmp;
  $bibentry->set_datafield($to, [ @tmp ]);
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
      push @{$cache->{preamble}{$filename}}, decode_utf8($entry->value);
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
    my $key = decode_utf8($entry->key);

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
    if (my $ids = decode_utf8($entry->get('ids'))) {
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
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);

  # Put the utf8 encoded file into the global biber tempdir
  # We have to do this in case we can't write to the location of the
  # .bib file
  my $td = $Biber::MASTER->biber_tempdir;
  (undef, undef, my $fn) = File::Spec->splitpath($filename);
  my $ufilename = File::Spec->catfile($td->dirname, "${fn}_$$.utf8");

  # bib encoding is not UTF-8
  if (Biber::Config->getoption('bibencoding') ne 'UTF-8') {
    require File::Slurp::Unicode;
    my $buf = File::Slurp::Unicode::read_file($filename, encoding => Biber::Config->getoption('bibencoding'))
      or biber_error("Can't read $filename");

    File::Slurp::Unicode::write_file($ufilename, {encoding => 'UTF-8'}, $buf)
        or biber_error("Can't write $ufilename");

  }
  else {
    File::Copy::copy($filename, $ufilename)
        or biber_error("Can't write $ufilename");
  }

  # Decode LaTeX to UTF8 if output is UTF-8
  if (Biber::Config->getoption('bblencoding') eq 'UTF-8') {
    require File::Slurp::Unicode;
    my $buf = File::Slurp::Unicode::read_file($ufilename, encoding => 'UTF-8')
      or biber_error("Can't read $ufilename");
    $logger->info('Decoding LaTeX character macros into UTF-8');
    $buf = Biber::LaTeX::Recode::latex_decode($buf, strip_outer_braces => 1);
    File::Slurp::Unicode::write_file($ufilename, {encoding => 'UTF-8'}, $buf)
        or biber_error("Can't write $ufilename");
    $logger->info('Finished Decoding LaTeX character macros into UTF-8');
  }

  return $ufilename;
}

=head2 parsename

    Given a name string, this function returns a Biber::Entry::Name object
    with all parts of the name resolved according to the BibTeX conventions.

    parsename('John Doe')
    returns an object which internally looks a bit like this:

    { firstname     => 'John',
      firstname_i   => 'J.',
      lastname      => 'Doe',
      lastname_i    => 'D.',
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
  my ($namestr, $fieldname, $opts) = @_;
  $logger->debug("Parsing namestring '$namestr'");
  my $usepre = $opts->{useprefix};
  # First sanitise the namestring due to Text::BibTeX::Name limitations on whitespace
  $namestr =~ s/\A\s*//xms; # leading whitespace
  $namestr =~ s/\s*\z//xms; # trailing whitespace
  $namestr =~ s/\s+/ /g;    # Collapse internal whitespace

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
  my $lastname  = decode_utf8($name->format($l_f));
  my $firstname = decode_utf8($name->format($f_f));
  my $prefix    = decode_utf8($name->format($p_f));
  my $suffix    = decode_utf8($name->format($s_f));

  # Variables to hold the Text::BibTeX::NameFormat generated initials string
  my $gen_lastname_i;
  my $gen_firstname_i;
  my $gen_prefix_i;
  my $gen_suffix_i;

  # Use a copy of $name so that when we generate the
  # initials, we do so without certain things. This is easier than trying
  # hack robust initials code into btparse ...
  # This is a hard-coded hack
  my $nd_namestr = $namestr;
  $nd_namestr =~ s/\b\p{L}{2}\p{Pd}//gxms; # strip prefices
  $nd_namestr =~ s/[\x{2bf}\x{2018}]//gxms; # strip specific diacritics
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

  $gen_lastname_i    = inits(decode_utf8($nd_name->format($li_f)));
  $gen_firstname_i   = inits(decode_utf8($nd_name->format($fi_f)));
  $gen_prefix_i      = inits(decode_utf8($nd_name->format($pi_f)));
  $gen_suffix_i      = inits(decode_utf8($nd_name->format($si_f)));

  # Only warn about lastnames since there should always be one
  biber_warn("Couldn't determine Last Name for name \"$namestr\"") unless $lastname;

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
    return $months{lc(substr($1,0,3))};
  }
  else {
    return $in_month;
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

Copyright 2009-2011 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
