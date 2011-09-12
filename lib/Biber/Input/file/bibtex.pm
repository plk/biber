package Biber::Input::file::bibtex;
use feature ':5.10';
#use 5.014001;
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

state $cache; # state variable so it's persistent across calles to extract_entries()
use vars qw($cache);

=head2 init_cache

    Invalidate the T::B object cache. Used only in tests when we change the encoding
    settings and therefore must force a re-read of the data

=cut

sub init_cache {
  $cache = {};
}

# Handlers for field types
# The names of these have nothing to do whatever with the biblatex field types
# They just started out copying them - they are categories of this specific
# data source date types
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
  $logger->logdie("Caught signal: $sig\nLikely your .bib has a bad entry: $!");
}

=head2 extract_entries

   Main data extraction routine.
   Accepts a data source identifier, preprocesses the file and then
   looks for the passed keys, creating entries when it finds them and
   passes out an array of keys it didn't find.

=cut

sub extract_entries {
  my ($biber, $filename, $keys) = @_;
  my $secnum = $biber->get_current_section;
  my $section = $biber->sections->get_section($secnum);
  my $bibentries = $section->bibentries;
  my @rkeys = @$keys;
  my $tf; # Up here so that the temp file has enough scope to survive until we've
          # used it
  $logger->trace("Entering extract_entries()");

  # If it's a remote data file, fetch it first
  if ($filename =~ m/\A(?:https?|ftp):\/\//xms) {
    $logger->info("Data source '$filename' is a remote .bib - fetching ...");
    require LWP::Simple;
    $tf = File::Temp->new(TEMPLATE => 'biber_remote_data_source_XXXXX',
                          DIR => $biber->biber_tempdir,
                          SUFFIX => '.bib');
    unless (LWP::Simple::is_success(LWP::Simple::getstore($filename, $tf->filename))) {
      $logger->logdie ("Could not fetch file '$filename'");
    }
    $filename = $tf->filename;
  }
  else {
    # Need to get the filename even if using cache so we increment
    # the filename count for preambles at the bottom of this sub
    my $trying_filename = $filename;
    unless ($filename = locate_biber_file($filename)) {
      $logger->logdie("Cannot find file '$trying_filename'!")
    }
  }

  # Log that we found a data file
  $logger->info("Found bibtex data file '$filename'");

  # Text::BibTeX can't be controlled by Log4perl so we have to do something clumsy
  if (Biber::Config->getoption('quiet')) {
    open OLDERR, '>&', \*STDERR;
    open STDERR, '>', '/dev/null';
  }

  # Increment the number of times each datafile has been referenced
  # For example, a datafile might be referenced in more than one section.
  # Some things find this information useful, for example, setting preambles is global
  # and so we need to know if we've already saved the preamble for a datafile.
  $cache->{counts}{$filename}++;

  # Don't read the file again if it's already cached
  unless ($cache->{data}{$filename}) {
    $logger->debug("Caching data for bibtex format file '$filename' for section $secnum");
    cache_data($biber, $filename);
  }
  else {
    $logger->debug("Using cached data for bibtex format file '$filename' for section $secnum");
  }

  if ($section->is_allkeys) {
    $logger->debug("All cached citekeys will be used for section '$secnum'");
    # Loop over all entries, creating objects
    while (my (undef, $entry) = each %{$cache->{data}{$filename}}) {

      # We have to pass the datasource cased (and UTF-8ed) key to
      # create_entry() as this sub needs to know the datasource case of the
      # citation key so we can save it for output later after all the case-insensitive
      # work. If we lowercase before this, we lose this information.
      create_entry($biber, decode_utf8($entry->key), $entry);
    }

    # if allkeys, push all bibdata keys into citekeys (if they are not already there)
    # We are using the special "orig_key_order" array which is used to deal with the
    # sitiation when sorting=non and allkeys is set. We need an array rather than the
    # keys from the bibentries hash because we need to preserver the original order of
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
      # Cache index keys are lower-cased. This next line effectively implements
      # case insensitive citekeys
      if (my $entry = $cache->{data}{$filename}{lc($wanted_key)}) {
        $logger->debug("Found key '$wanted_key' in Text::BibTeX cache");
        # See comment above about the importance of the case of the key
        # passed to create_entry()
        create_entry($biber, decode_utf8($entry->key), $entry);
        # found a key, remove it from the list of keys we want
        @rkeys = grep {$wanted_key ne $_} @rkeys;
      }
      $logger->debug('Wanted keys now: ' . join(', ', @rkeys));
    }
  }

  if (Biber::Config->getoption('quiet')) {
    open STDERR, '>&', \*OLDERR;
  }

  # Only push the preambles from the file if we haven't seen this data file before
  # and there are some preambles to push
  if ($cache->{counts}{$filename} < 2 and @{$cache->{preamble}{$filename}}) {
    push @{$biber->{preamble}}, @{$cache->{preamble}{$filename}};
  }

  return @rkeys;
}

=head2 create_entry

   Create a Biber::Entry object from a Text::BibTeX object

=cut

sub create_entry {
  my ($biber, $dskey, $entry) = @_;
  my $secnum = $biber->get_current_section;
  my $section = $biber->sections->get_section($secnum);
  my $bibentries = $section->bibentries;
  my $bibentry = new Biber::Entry;

  # Key casing is tricky. We need to note:
  #
  # Key matching is case-insensitive (BibTeX compat requirement)
  # In the .bbl, we should use the datasource case for the key
  # We don't care about the case of the citations themselves
  $bibentry->set_field('citekey', $dskey);

  # We also record the datasource key in original case in the section object
  # because there are certain places which need this
  # (for example shorthand list output) which need to output the key in the
  # right case but which have no access to entry objects
  $section->add_dskey($dskey);

  # Get a reference to the map option, if it exists
  my $user_map;
  if (defined(Biber::Config->getoption('map'))) {
    if (defined(Biber::Config->getoption('map')->{bibtex})) {
      $user_map = Biber::Config->getoption('map')->{bibtex};
    }
  }

  if ( $entry->metatype == BTE_REGULAR ) {

    # We put all the fields we find modulo field aliases into the object
    # validation happens later and is not datasource dependent
FLOOP:  foreach my $f ($entry->fieldlist) {

      # We have to process local options as early as possible in order
      # to make them available for things that need them like parsename()
      if ($f eq 'options') {
        my $value = decode_utf8($entry->get($f));
        $biber->process_entry_options($dskey, $value);
      }

      # FIELD MAPPING (ALIASES) DEFINED BY USER IN CONFIG FILE OR .bcf
      my $from;
      my $to;
      if ($user_map and
          my $field = firstval {lc($_) eq lc($f)} (keys %{$user_map->{field}},
                                                   keys %{$user_map->{globalfield}})) {

        # Enforce matching per-type mappings before global ones
        my $to_map;
        if (my $map = $user_map->{field}{$field}) {
          if (exists($map->{bmap_pertype})) {

            # Canonicalise pertype, can be a list Config::General is not clever enough
            # to do this, annoyingly
            if (ref($map->{bmap_pertype}) ne 'ARRAY') {
              $map->{bmap_pertype} = [ $map->{bmap_pertype} ];
            }

            # Now see if the per_type conditions match
            if (first {lc($_) eq lc($entry->type)} @{$map->{bmap_pertype}}) {
              $to_map = $user_map->{field}{$field}
            }
            else {
              $to_map = $user_map->{globalfield}{$field};
            }
          }
        }
        else {
          $to_map = $user_map->{globalfield}{$field};
        }

        # In case per_type doesn't match and there is no global map for this field
        next FLOOP unless defined($to_map);

        # handler information still comes from .dcf
        $from = $dcfxml->{fields}{field}{$f};

        if (ref($to_map) eq 'HASH') { # complex field map
          $from = $dcfxml->{fields}{field}{lc($to_map->{bmap_target})};
          $to = lc($to_map->{bmap_target});

          # Deal with alsoset one->many maps
          while (my ($from_as, $to_as) = each %{$to_map->{alsoset}}) {
            if ($bibentry->field_exists(lc($from_as))) {
              if ($user_map->{bmap_overwrite}) {
                $biber->biber_warn($bibentry, "Overwriting existing field '$from_as' during aliasing of field '" . lc($field) . "' to '$to' in entry '$dskey'");
              }
              else {
                $biber->biber_warn($bibentry, "Not overwriting existing field '$from_as' during aliasing of field '" . lc($field) . "' to '$to' in entry '$dskey'");
                next;
              }
            }
            # Deal with special tokens
            given (lc($to_as)) {
              when ('bmap_origfield') {
                $bibentry->set_datafield(lc($from_as), $f);
              }
              when ('bmap_null') {
                $bibentry->del_datafield(lc($from_as));
                # 'future' delete in case it's not set yet
                $bibentry->block_datafield(lc($from_as));
              }
              default {
                $bibentry->set_datafield(lc($from_as), $to_as);
              }
            }
          }

          # map fields to targets
          if (lc($to_map->{bmap_target}) eq 'bmap_null') { # fields to ignore
            next FLOOP;
          }
        }
        else { # simple field map
          $to = lc($to_map);
          if ($to eq 'bmap_null') { # fields to ignore
            next FLOOP;
          }
          else { # normal simple field map
            $from = $dcfxml->{fields}{field}{$to};
          }
        }

        # Now run any defined handler
        &{$handlers{$from->{handler}}}($biber, $bibentry, $entry, $f, $to, $dskey);
      }
      # FIELD MAPPING (ALIASES) DEFINED BY DRIVER IN DRIVER CONFIG FILE
      elsif ($from = $dcfxml->{fields}{field}{$f}) {
        $to = $f; # By default, field to set internally is the same as data source

        # Redirect any alias
        if (my $aliases = $from->{alias}) { # complex aliases with alsoset clauses
          foreach my $alias (@$aliases) {
            if (my $t = $alias->{aliasfortype}) { # type-specific alias
              if (lc($t) eq lc($entry->type)) {
                my $a = $alias->{aliasof};
                $logger->debug("Found alias '$a' of field '$f' in entry '$dskey'");
                # If both a field and its alias is set, warn and delete alias field
                if ($entry->exists($a)) {
                  $biber->biber_warn($bibentry, "Field '$f' is aliased to field '$a' but both are defined in entry with key '$dskey' - skipping alias");
                  next;
                }
                $from = $dcfxml->{fields}{field}{$a};
                $to = $a;  # Field to set internally is the alias
                last;
              }
            }
            else {
              my $a = $alias->{aliasof}; # global alias
              $logger->debug("Found alias '$a' of field '$f' in entry '$dskey'");
              # If both a field and its alias is set, warn and delete alias field
              if ($entry->exists($a)) {
                $biber->biber_warn($bibentry, "Field '$f' is aliased to field '$a' but both are defined in entry with key '$dskey' - skipping alias");
                next;
              }
              $from = $dcfxml->{fields}{field}{$a};
              $to = $a; # Field to set internally is the alias
            }

            # Deal with additional fields to split information into (one->many map)
            foreach my $alsoset (@{$alias->{alsoset}}) {
              # If both a field and an alsoset field are set, warn and ignore alsoset
              if ($entry->exists($alsoset->{target})) {
                $biber->biber_warn($bibentry, "Field '" . $alsoset->{target}. "' is supposed to be additionally set but it already exists - ignoring");
                next;
              }
              my $val = $alsoset->{value} // $f; # defaults to original field name if no value
              $bibentry->set_datafield($alsoset->{target}, $val);
            }
          }
        }
        elsif (my $alias = $from->{aliasof}) { # simple alias
          $logger->debug("Found alias '$alias' of field '$f' in entry '$dskey'");
          if ($entry->exists($alias)) {
            $biber->biber_warn($bibentry, "Field '$f' is aliased to field '$alias' but both are defined in entry with key '$dskey' - skipping alias");
            next;
          }
          $from = $dcfxml->{fields}{field}{$alias};
          $to = $alias; # Field to set internally is the alias
        }

        # Now run any defined handler
        &{$handlers{$from->{handler}}}($biber, $bibentry, $entry, $f, $to, $dskey);
      }
      # Default if no explicit way to set the field
      else {
        my $value = decode_utf8($entry->get($f));
        $bibentry->set_datafield($f, $value);
      }
    }

    # Set entrytype taking note of any user aliases or aliases for this datasource driver
    # This is here so that any field alsosets take precedence over fields in the data source

    # User aliases take precedence
    if (my $eta = firstval {lc($_) eq lc($entry->type)} keys %{$user_map->{entrytype}}) {
      my $from = lc($entry->type);
      my $to = $user_map->{entrytype}{$eta};
      if (ref($to) eq 'HASH') { # complex entrytype map
        $bibentry->set_field('entrytype', lc($to->{bmap_target}));
        while (my ($from_as, $to_as) = each %{$to->{alsoset}}) {
          if ($bibentry->field_exists(lc($from_as))) {
            if ($user_map->{bmap_overwrite}) {
              $biber->biber_warn($bibentry, "Overwriting existing field '$from_as' during aliasing of entrytype '" . $entry->type . "' to '" . lc($to->{bmap_target}) . "' in entry '$dskey'");
            }
            else {
              $biber->biber_warn($bibentry, "Not overwriting existing field '$from_as' during aliasing of entrytype '" . $entry->type . "' to '" . lc($to->{bmap_target}) . "' in entry '$dskey'");
              next;
            }
          }
          # Deal with special "BMAP_ORIGENTRYTYPE" token
          my $to_val = lc($to_as) eq 'bmap_origentrytype' ?
            $from : $to_as;
          $bibentry->set_datafield(lc($from_as), $to_val);
        }
      }
      else { # simple entrytype map
        $bibentry->set_field('entrytype', lc($to));
      }
    }
    # Driver aliases
    elsif (my $ealias = $dcfxml->{entrytypes}{entrytype}{lc($entry->type)}) {
      $bibentry->set_field('entrytype', $ealias->{aliasof}{content});
      foreach my $alsoset (@{$ealias->{alsoset}}) {
        # drivers never overwrite existing fields
        if ($bibentry->field_exists(lc($alsoset->{target}))) {
          $biber->biber_warn($bibentry, "Not overwriting existing field '" . $alsoset->{target} . "' during aliasing of entrytype '" . $entry->type . "' to '" . lc($ealias->{aliasof}{content}) . "' in entry '$dskey'");
          next;
        }
        $bibentry->set_datafield($alsoset->{target}, $alsoset->{value});
      }
    }
    # No alias
    else {
      $bibentry->set_field('entrytype', $entry->type);
    }

    $bibentry->set_field('datatype', 'bibtex');
    $bibentries->add_entry(lc($dskey), $bibentry);
  }

  return;
}



# Literal fields
sub _literal {
  my ($biber, $bibentry, $entry, $f, $to, $dskey) = @_;
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
  my ($biber, $bibentry, $entry, $f, $to, $dskey) = @_;
  my $value = decode_utf8($entry->get($f));
  $bibentry->set_datafield($to, $value);
  return;
}

# Range fields
sub _range {
  my ($biber, $bibentry, $entry, $f, $to, $dskey) = @_;
  my $values_ref;
  my @values = split(/\s*,\s*/, decode_utf8($entry->get($f)));
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
  my ($biber, $bibentry, $entry, $f, $to, $dskey) = @_;
  my $secnum = $biber->get_current_section;
  my $section = $biber->sections->get_section($secnum);
  my @tmp = $entry->split($f);
  my $lc_key = lc($dskey);
  my $useprefix = Biber::Config->getblxoption('useprefix', $bibentry->get_field('entrytype'), $lc_key);
  my $names = new Biber::Entry::Names;
  foreach my $name (@tmp) {

    # Consecutive "and" causes Text::BibTeX::Name to segfault
    unless ($name) {
      $biber->biber_warn($bibentry, "Name in key '$dskey' is empty (probably consecutive 'and'): skipping name");
      $section->del_citekey($dskey);
      next;
    }

    $name = decode_utf8($name);

    # Check for malformed names in names which aren't completely escaped

    # Too many commas
    unless ($name =~ m/\A{.+}\z/xms) { # Ignore these tests for escaped names
      my @commas = $name =~ m/,/g;
      if ($#commas > 1) {
        $biber->biber_warn($bibentry, "Name \"$name\" has too many commas: skipping name");
        $section->del_citekey($dskey);
        next;
      }

      # Consecutive commas cause Text::BibTeX::Name to segfault
      if ($name =~ /,,/) {
        $biber->biber_warn($bibentry, "Name \"$name\" is malformed (consecutive commas): skipping name");
        $section->del_citekey($dskey);
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
  my ($biber, $bibentry, $entry, $f, $to, $dskey) = @_;
  my ($datetype) = $f =~ m/\A(.*)date\z/xms;
  my $date = decode_utf8($entry->get($f));
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
      $biber->biber_warn($bibentry, "Overwriting field 'year' with year value from field 'date' for entry '$dskey'");
    }
    if ($bmonth and
        ($datetype . 'month' eq 'month') and
        $entry->get('month')) {
      $biber->biber_warn($bibentry, "Overwriting field 'month' with month value from field 'date' for entry '$dskey'");
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
    $biber->biber_warn($bibentry, "Invalid format '$date' of date field '$f' in entry '$dskey' - ignoring");
  }
  return;
}

# List fields
sub _list {
  my ($biber, $bibentry, $entry, $f, $to, $dskey) = @_;
  my @tmp = $entry->split($f);

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
  my ($biber, $filename) = @_;
  # Initialise this
  $cache->{preamble}{$filename} = [];

  # Convert/decode file
  my $pfilename = preprocess_file($biber, $filename);

  my $bib = Text::BibTeX::File->new( $pfilename, '<' )
    or $logger->logdie("Cannot create Text::BibTeX::File object from $pfilename: $!");

  while ( my $entry = new Text::BibTeX::Entry $bib ) {
    if ( $entry->metatype == BTE_PREAMBLE ) {
      push @{$cache->{preamble}{$filename}}, decode_utf8($entry->value);
      next;
    }

    # Ignore misc bibtex entry types we don't care about
    next if ( $entry->metatype == BTE_MACRODEF or $entry->metatype == BTE_UNKNOWN
              or $entry->metatype == BTE_COMMENT );

    # If an entry has no key, ignore it and warn
    unless ($entry->key) {
      $logger->warn("Invalid or undefined BibTeX entry key in file '$pfilename', skipping ...");
      next;
    }

    # Text::BibTeX >= 0.46 passes through all citekey bits, thus allowing utf8 keys
    my $dskey = decode_utf8($entry->key);

    # If we've already seen this key, ignore it and warn
    # Note the calls to lc() - we don't care about case when detecting duplicates
    if  (my $orig = first {lc($_) eq lc($dskey)} @{$biber->get_everykey}) {
      $logger->warn("Duplicate entry keys: '$orig' and '$dskey' in file '$filename', skipping '$dskey' ...");
      next;
    }
    else {
      $biber->add_everykey($dskey);
    }

    # Bad entry
    unless ($entry->parse_ok) {
      $logger->warn("Entry $dskey does not parse correctly: skipping");
      next;
    }

    # Cache the entry so we don't have to read the file again on next pass.
    # Two reasons - So we avoid T::B macro redef warnings and speed
    $cache->{data}{$filename}{lc($dskey)} = $entry;
    # We do this as otherwise we have no way of determining the origing .bib entry order
    # We need this in order to do sorting=none + allkeys because in this case, there is no
    # "citeorder" because nothing is explicitly cited and so "citeorder" means .bib order
    push @{$cache->{orig_key_order}{$filename}}, $dskey;
    $logger->debug("Cached Text::BibTeX entry for key '$dskey' from bibtex file '$filename'");
  }

  $bib->close; # If we don't do this, we can't unlink the temp file on Windows

  return;
}


=head2 preprocess_file

   Convert file to UTF-8 and potentially decode LaTeX macros to UTF-8

=cut

sub preprocess_file {
  my ($biber, $filename) = @_;
  my $secnum = $biber->get_current_section;
  my $section = $biber->sections->get_section($secnum);

  # Put the utf8 encoded file into the global biber tempdir
  # We have to do this in case we can't write to the location of the
  # .bib file
  my $td = $biber->biber_tempdir;
  (undef, undef, my $fn) = File::Spec->splitpath($filename);
  my $ufilename = File::Spec->catfile($td->dirname, "${fn}_$$.utf8");

  # bib encoding is not UTF-8
  if (Biber::Config->getoption('bibencoding') ne 'UTF-8') {
    require File::Slurp::Unicode;
    my $buf = File::Slurp::Unicode::read_file($filename, encoding => Biber::Config->getoption('bibencoding'))
      or $logger->logdie("Can't read $filename");

    File::Slurp::Unicode::write_file($ufilename, {encoding => 'UTF-8'}, $buf)
        or $logger->logdie("Can't write $ufilename");

  }
  else {
    File::Copy::copy($filename, $ufilename)
        or $logger->logdie("Can't write $ufilename");
  }

  # Decode LaTeX to UTF8 if output is UTF-8
  if (Biber::Config->getoption('bblencoding') eq 'UTF-8') {
    require File::Slurp::Unicode;
    my $buf = File::Slurp::Unicode::read_file($ufilename, encoding => 'UTF-8')
      or $logger->logdie("Can't read $ufilename");
    $logger->info('Decoding LaTeX character macros into UTF-8');
    $buf = Biber::LaTeX::Recode::latex_decode($buf, strip_outer_braces => 1);
    File::Slurp::Unicode::write_file($ufilename, {encoding => 'UTF-8'}, $buf)
        or $logger->logdie("Can't write $ufilename");
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
  $logger->debug("   Parsing namestring '$namestr'");
  my $usepre = $opts->{useprefix};
  # First sanitise the namestring due to Text::BibTeX::Name limitations on whitespace
  $namestr =~ s/\A\s*//xms; # leading whitespace
  $namestr =~ s/\s*\z//xms; # trailing whitespace
  $namestr =~ s/\s+/ /g;    # Collapse internal whitespace

  open OLDERR, '>&', \*STDERR;
  open STDERR, '>', '/dev/null';
  my $name = new Text::BibTeX::Name($namestr);
  open STDERR, '>&', \*OLDERR;

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
  $logger->warn("Couldn't determine Last Name for name \"$namestr\"") unless $lastname;

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

Provides the extract_entries() method to get entries from a bibtex data source
and instantiate Biber::Entry objects for what it finds

=head1 AUTHOR

François Charette, C<< <firmicus at gmx.net> >>
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
