package Biber::Input::file::endnotexml;
use feature ':5.10';
#use feature 'unicode_strings';
use strict;
use warnings;
use Carp;

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
use Digest::MD5 qw( md5_hex );
use File::Spec;
use Log::Log4perl qw(:no_extra_logdie_message);
use base 'Exporter';
use List::AllUtils qw( :all );
use XML::LibXML;
use XML::LibXML::Simple;
use Data::Dump qw(dump);
use Text::BibTeX qw(:nameparts :joinmethods :metatypes);
use Text::BibTeX::Name;
use Text::BibTeX::NameFormat;

##### This is based on Endnote X4 #####

my $logger = Log::Log4perl::get_logger('main');

# Handlers for field types
my %handlers = (
                'name'        => \&_name,
                'date'        => \&_date,
                'range'       => \&_range,
                'literal'     => \&_literal,
                'list'        => \&_list,
                'keywords'    => \&_keywords,
);

# Read driver config file
my $dcfxml = driver_config('endnotexml');

=head2 extract_entries

   Main data extraction routine.
   Accepts a data source identifier (filename in this case),
   preprocesses the file and then looks for the passed keys,
   creating entries when it finds them and passes out an
   array of keys it didn't find.

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
    $logger->info("Data source '$filename' is a remote .xml - fetching ...");
    require LWP::Simple;
    require File::Temp;
    $tf = File::Temp->new(TEMPLATE => 'biber_remote_data_source_XXXXX',
                          DIR => $biber->biber_tempdir,
                          SUFFIX => '.xml');
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
  $logger->info("Found endnotexml data file '$filename'");

  # Set up XML parser and namespaces
  my $parser = XML::LibXML->new();
  my $enxml = $parser->parse_file($filename)
    or $logger->logcroak("Can't parse file $filename");
  my $xpc = XML::LibXML::XPathContext->new($enxml);

  if ($section->is_allkeys) {
    $logger->debug("All citekeys will be used for section '$secnum'");
    # Loop over all entries, creating objects
    foreach my $entry ($xpc->findnodes("/xml/records/record")) {
      $logger->debug('Parsing Endnote XML entry object ' . $entry->nodePath);
      # We have to pass the datasource cased key to
      # create_entry() as this sub needs to know the original case of the
      # citation key so we can do case-insensitive key/entry comparisons
      # later but we need to put the original citation case when we write
      # the .bbl. If we lowercase before this, we lose this information.
      # Of course, with allkeys, "citation case" means "datasource entry case"

      # If an entry has no key, ignore it and warn
      unless ($entry->findvalue('./rec-number')) {
        $logger->warn("Invalid or undefined entry ID in file '$filename', skipping ...");
        $biber->{warnings}++;
        next;
      }

      my $dbdid = $entry->findvalue('./foreign-keys/key/@dbd-id');
      my $key = $entry->findvalue('./rec-number');

      create_entry($biber, "$dbdid:$key", $entry);
    }

    # if allkeys, push all bibdata keys into citekeys (if they are not already there)
    $section->add_citekeys($section->bibentries->sorted_keys);
    $logger->debug("Added all citekeys to section '$secnum': " . join(', ', $section->get_citekeys));
  }
  else {
    # loop over all keys we're looking for and create objects
    $logger->debug('Wanted keys: ' . join(', ', @$keys));
    foreach my $wanted_key (@$keys) {
      $logger->debug("Looking for key '$wanted_key' in Endnote XML file '$filename'");
      # Cache index keys are lower-cased. This next line effectively implements
      # case insensitive citekeys
      # This will also get the first match it finds

      # Split key into parts
      my ($dbid, $num) = split(/:/, $wanted_key);

      if (my @entries = $xpc->findnodes("/xml/records/record[rec-number[text()='$num']][foreign-keys/key[\@db-id='$dbid']]")) {
        my $entry;
        # Check to see if there is more than one entry with this key and warn if so
        if ($#entries > 0) {
          $logger->warn("Found more than one entry for key '$wanted_key' in '$dbid:$num' - using the first one!");
          $biber->{warnings}++;
        }
        $entry = $entries[0];

        $logger->debug("Found key '$wanted_key' in Endnote XML file '$filename'");
        $logger->debug('Parsing Endnote XML entry object ' . $entry->nodePath);
        # See comment above about the importance of the case of the key
        # passed to create_entry()
        create_entry($biber, $wanted_key, $entry);
        # found a key, remove it from the list of keys we want
        @rkeys = grep {$wanted_key ne $_} @rkeys;
      }
      $logger->debug('Wanted keys now: ' . join(', ', @rkeys));
    }
  }

  return @rkeys;
}


=head2 create_entry

   Create a Biber::Entry object from an entry found in a Endnote
   XML data source

=cut

sub create_entry {
  my ($biber, $dskey, $entry) = @_;
  my $secnum = $biber->get_current_section;
  my $section = $biber->sections->get_section($secnum);
  my $struc = Biber::Config->get_structure;
  my $bibentries = $section->bibentries;

  # Want a version of the key that is the same case as any citations which
  # reference it, in case they are different. We use this as the .bbl
  # entry key
  # In case of allkeys, this will just be the datasource key as ->get_citekeys
  # returns an empty list
  my $citekey = first {lc($dskey) eq lc($_)} $section->get_citekeys;
  $citekey = $dskey unless $citekey;
  my $lc_key = lc($dskey);

  my $bibentry = new Biber::Entry;
  # We record the original keys of both the datasource and citation. They may differ in case.
  $bibentry->set_field('dskey', $dskey);
  $bibentry->set_field('citekey', $citekey);
  # We also record the datasource key in original case in the section object
  # because there are certain places which need this
  # (for example shorthand list output) which need to output the key in the
  # right case but which have no access to entry objects
  $section->add_dskey($dskey);

  # Get a reference to the map option, if it exists
  my $user_map;
  if (defined(Biber::Config->getoption('map'))) {
    if (defined(Biber::Config->getoption('map')->{endnotexml})) {
      $user_map = Biber::Config->getoption('map')->{endnotexml};
    }
  }

  my $itype = $entry->findvalue('./ref-type/@name');

  # We put all the fields we find modulo field aliases into the object.
  # Validation happens later and is not datasource dependent
  # the findnodes() on the entry is complex as some fields are not at the top
  # level of the entry, which is annoying. This is a trade-off between having special handlers
  # for the top-level nodes and forcing the right nodes to be visible to this loop, which
  # is what we do here as these nodes have special aliases we want visible in the .dcf. If we
  # did it all in special handlers, it would all be invisible in the .dcf
FLOOP:  foreach my $f (uniq map {$_->nodeName()} $entry->findnodes('(./*|./titles/*|./contributors/*|./urls/web-urls/*|./dates/*)')) {

    # FIELD MAPPING (ALIASES) DEFINED BY USER IN CONFIG FILE
    my $from;
    my $to;
    if ($user_map and
        my $field = firstval {lc($_) eq lc($f)} (keys %{$user_map->{field}},
                                                 keys %{$user_map->{globalfield}})) {
      # next line short-circuit OR enforces per-type before global field mappings
      my $to_map = $user_map->{field}{$field} || $user_map->{globalfield}{$field};
      $from = $dcfxml->{fields}{field}{$f}; # handler information still comes from .dcf

      if (ref($to_map) eq 'HASH') { # complex field map
        $from = $dcfxml->{fields}{field}{lc($to_map->{bmap_target})};
        $to = lc($to_map->{bmap_target});

          # Canonicalise pertype, can be a list Config::General is not clever enough
          # to do this, annoyingly
          if (defined($to_map->{bmap_pertype}) and
             ref($to_map->{bmap_pertype}) ne 'ARRAY') {
            $to_map->{bmap_pertype} = [ $to_map->{bmap_pertype} ];
          }
          # If it's a global alias or a per-type alias which matches.
          if (not defined($to_map->{bmap_pertype}) or
              (defined($to_map->{bmap_pertype}) and
               first {lc($_) eq lc($itype)} @{$to_map->{bmap_pertype}})) {

          # Deal with alsoset one->many maps
          while (my ($from_as, $to_as) = each %{$to_map->{alsoset}}) {
            if ($bibentry->field_exists(lc($from_as))) {
              $biber->biber_warn($bibentry, "Overwriting existing field '$from_as' during aliasing of field '$from' to '$to'");
            }
            # Deal with special "BMAP_ORIGFIELD" token
            my $to_val = lc($to_as) eq 'bmap_origfield' ? $f : $to_as;
            $bibentry->set_datafield(lc($from_as), $to_val);
          }

          # map fields to targets
          if (lc($to_map->{bmap_target}) eq 'bmap_null') { # fields to ignore
            next FLOOP;
          }
        }
      }
      else {                    # simple field map
        $to = lc($to_map);
        if ($to eq 'bmap_null') { # fields to ignore
          next FLOOP;
        }
        else {                  # normal simple field map
          $from = $dcfxml->{fields}{field}{$to};
        }
      }

      # Now run any defined handler
      &{$handlers{$from->{handler}}}($biber, $bibentry, $entry, $f, $to, $dskey);
    }
    # FIELD MAPPING (ALIASES) DEFINED BY DRIVER IN DRIVER CONFIG FILE
    # ignore fields not in .dcf - this means "titles", "contributors" "urls/web-urls" are
    # skipped but their children are not
    elsif ($from = $dcfxml->{fields}{field}{$f}) {
      $to = $f; # By default, field to set internally is the same as data source
      # Redirect any alias
      if (my $aliases = $from->{alias}) { # complex aliases
        foreach my $alias (@$aliases) {
          if (my $t = $alias->{aliasfortype}) { # type-specific alias
            if (lc($t) eq lc($itype)) {
              my $a = $alias->{aliasof};
              $logger->debug("Found alias '$a' of field '$f' in entry '$dskey'");
              $from = $dcfxml->{fields}{field}{$a};
              $to = $a;  # Field to set internally is the alias
              last;
            }
          }
          else {
            my $a = $alias->{aliasof}; # global alias
            $logger->debug("Found alias '$a' of field '$f' in entry '$dskey'");
            $from = $dcfxml->{fields}{field}{$a};
            $to = $a;  # Field to set internally is the alias
          }

          # Deal with additional fields to split information into (one->many map)
          foreach my $alsoset (@{$alias->{alsoset}}) {
            my $val = $alsoset->{value} // $f; # defaults to original field name if no value
            $bibentry->set_datafield($alsoset->{target}, $val);
          }
        }
      }
      elsif (my $a = $from->{aliasof}) { # simple, global only alias
        $logger->debug("Found alias '$a' of field '$f' in entry '$dskey'");
        $from = $dcfxml->{fields}{field}{$a};
        $to = $a;  # Field to set internally is the alias
      }
      &{$handlers{$from->{handler}}}($biber, $bibentry, $entry, $f, $to, $dskey);
    }
  }

  # Set entrytype taking note of any user aliases or aliases for this datasource driver
  # This is here so that any field alsosets take precedence over fields in the data source

  # User aliases take precedence
  if (my $eta = firstval {lc($_) eq lc($itype)} keys %{$user_map->{entrytype}}) {
    my $from = lc($itype);
    my $to = $user_map->{entrytype}{$eta};
    if (ref($to) eq 'HASH') {   # complex entrytype map
      $bibentry->set_field('entrytype', lc($to->{bmap_target}));
      while (my ($from_as, $to_as) = each %{$to->{alsoset}}) { # any extra fields to set?
        if ($bibentry->field_exists(lc($from_as))) {
          $biber->biber_warn($bibentry, "Overwriting existing field '$from_as' during aliasing of entrytype '$itype' to '" . lc($to->{bmap_target}) . "'");
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
  elsif (my $ealias = $dcfxml->{entrytypes}{entrytype}{$itype}) {
    $bibentry->set_field('entrytype', $ealias->{aliasof}{content});
    foreach my $alsoset (@{$ealias->{alsoset}}) {
      if ($bibentry->field_exists(lc($alsoset->{target}))) {
        $biber->biber_warn($bibentry, "Overwriting existing field '" . $alsoset->{target} . "' during aliasing of entrytype '$itype' to '" . lc($ealias->{aliasof}{content}) . "'");
      }
      $bibentry->set_datafield($alsoset->{target}, $alsoset->{value});
    }
  }
  # No alias
  else {
    $bibentry->set_field('entrytype', $itype);
  }

  $bibentry->set_field('datatype', 'endnotexml');
  $bibentries->add_entry($lc_key, $bibentry);

  return;
}

# List fields
sub _list {
  my ($biber, $bibentry, $entry, $f, $to, $dskey) = @_;
  $bibentry->set_datafield($to, [ _norm($entry->findvalue("./$f")) ]);
  return;
}

# literal fields
sub _literal {
  my ($biber, $bibentry, $entry, $f, $to, $dskey) = @_;
  $bibentry->set_datafield($to, _norm($entry->findvalue("(./$f|./titles/$f|./contributors/$f|./urls/web-urls/$f)")));
  return;
}

# Range fields
sub _range {
  my ($biber, $bibentry, $entry, $f, $to, $dskey) = @_;
  my $values_ref;
  my @values = split(/\s*,\s*/, _norm($entry->findvalue("./$f")));
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

# Date fields
sub _date {
  my ($biber, $bibentry, $entry, $f, $to, $dskey) = @_;
  my $daten = $entry->findnodes("./dates/$f")->get_node(1);
  # Use Endnote explicit date attributes, if present
  # It's not clear if Endnote actually uses these attributes
  if ($daten->hasAttribute('year')) {
    if ($daten->hasAttribute('year')) {
      $bibentry->set_datafield('year', $daten->getAttribute('year'));
    }
    if ($daten->hasAttribute('month')) {
      $bibentry->set_datafield('month', $daten->getAttribute('month'));
    }
    if ($daten->hasAttribute('day')) {
      $bibentry->set_datafield('day', $daten->getAttribute('day'));
    }
    return;
  }
  else {
    my $date = _norm($entry->findvalue("./dates/$f"));
    # We are not validating dates here, just syntax parsing
    my $date_re = qr/(\d{4}) # year
                     (?:-(\d{2}))? # month
                     (?:-(\d{2}))? # day
                    /xms;
    if (my ($byear, $bmonth, $bday, $r, $eyear, $emonth, $eday) =
        $date =~ m|\A$date_re(/)?(?:$date_re)?\z|xms) {

      $bibentry->set_datafield('year',     $byear)      if $byear;
      $bibentry->set_datafield('month',    $bmonth)     if $bmonth;
      $bibentry->set_datafield('day',      $bday)       if $bday;
      $bibentry->set_datafield('endmonth', $emonth)     if $emonth;
      $bibentry->set_datafield('endday',   $eday)       if $eday;
      if ($r and $eyear) {      # normal range
        $bibentry->set_datafield('endyear', $eyear);
      }
      elsif ($r and not $eyear) { # open ended range - endyear is defined but empty
        $bibentry->set_datafield('endyear', '');
      }
    }
    else {
      $biber->biber_warn($bibentry, "Invalid format '$date' of date field '$f' in entry '$dskey' - ignoring");
    }
    return;
  }
}

# Name fields
sub _name {
  my ($biber, $bibentry, $entry, $f, $to, $dskey) = @_;
  my $names = new Biber::Entry::Names;
  my $useprefix = Biber::Config->getblxoption('useprefix', $bibentry->get_field('entrytype'), $dskey);
  foreach my $name ($entry->findnodes("./contributors/$f/*")) {
    $names->add_name(parsename($name, $f, {useprefix => $useprefix}));
  }
  $bibentry->set_datafield($to, $names);
  return;
}

sub _keywords {
  my ($biber, $bibentry, $entry, $f, $to, $dskey) = @_;
  if (my @s = $entry->findnodes("./$f/keyword")) {
    my @kws;
    foreach my $s (@s) {
      push @kws, '{'._norm($s->textContent()).'}';
    }
    $bibentry->set_datafield('keywords', join(',', @kws));
  }
  return;
}

=head2 parsename

    Given a name node, this function returns a Biber::Entry::Name object

    Returns an object which internally looks a bit like this:

    { firstname     => 'John',
      firstname_i   => 'J',
      middlename    => 'Fred',
      middlename_i  => 'F',
      lastname      => 'Doe',
      lastname_i    => 'D',
      prefix        => undef,
      prefix_i      => undef,
      suffix        => undef,
      suffix_i      => undef,
      namestring    => 'Doe, John Fred',
      nameinitstring => 'Doe_JF',

=cut

sub parsename {
  my ($node, $fieldname, $opts) = @_;
  $logger->debug('Parsing Endnote XML name object ' . $node->nodePath);
  my $usepre = $opts->{useprefix};

  my %namec;

  # Assume that we are using the Endnote name attrs if we find a 'last-name' attr
  # It's not clear if Endnote actually ever uses these even though they are in the
  # DTD
  if ($node->hasAttribute('last-name')) {
    foreach my $n ('last-name', 'first-name', 'suffix', 'corp-name', 'initials', 'middle-initial', 'title', 'salutation') {
      # If there is a name attribute for this component ...
      # This is all guessing as I've never seen Endnote export this
      if ($node->hasAttribute($n)) {
        my $np = $node->getAttribute($n);
        if ($n eq 'last-name') {
          $namec{last} = $np;
          $namec{last_i} = [_gen_initials($np)];
        }
        elsif ($n eq 'first-name') {
          $namec{first} = $np;
          $namec{first_i} = [_gen_initials($np)];
        }
        elsif ($n eq 'suffix') {
          $namec{suffix} = $np;
          $namec{suffix_i} = [_gen_initials($np)];
        }
        elsif ($n eq 'corp-name') {
          $namec{last} = $np;
          $namec{last_i} = [_gen_initials($np)];
        }
        elsif ($n eq 'initials') {
          $namec{first_i} = $np;
        }
        elsif ($n eq 'middle-initial') {
          my $mi = $np;
          $mi =~ s/\s*\.//g;
          $namec{middle} = $np;
          $namec{middle_i} = [ $mi ];
        }
        elsif ($n eq 'title' or $n eq 'salutation') {
          $namec{first} = "$np " . $namec{first};
        }
      }
    }
  # Only warn about lastnames since there should always be one
    $logger->warn("Couldn't determine Lastname for name XPath: " . $node->nodePath) unless exists($namec{last});

    my $namestring = '';

    # lastname
    if (my $l = $namec{last}) {
      $namestring .= "$l, ";
    }

    # suffix
    if (my $s = $namec{suffix}) {
      $namestring .= "$s, ";
    }

    # firstname
    if (my $f = $namec{first}) {
      $namestring .= "$f";
    }

    # middlename
    if (my $m = $namec{middle}) {
      $namestring .= "$m, ";
    }

    # Remove any trailing comma and space if, e.g. missing firstname
    $namestring =~ s/,\s+\z//xms;

    # Construct $nameinitstring
    my $nameinitstr = '';
    $nameinitstr .= $namec{last} if exists($namec{last});
    $nameinitstr .= '_' . join('', @{$namec{suffix_i}}) if exists($namec{suffix});
    $nameinitstr .= '_' . join('', @{$namec{first_i}}) if exists($namec{first});
    $nameinitstr .= '_' . join('', @{$namec{middle_i}}) if exists($namec{middle});
    $nameinitstr =~ s/\s+/_/g;

    return Biber::Entry::Name->new(
      firstname       => $namec{first} // undef,
      firstname_i     => exists($namec{first}) ? $namec{first_i} : undef,
      middlename      => $namec{middle} // undef,
      middlename_i    => exists($namec{middle}) ? $namec{middle_i} : undef,
      lastname        => $namec{last} // undef,
      lastname_i      => exists($namec{last}) ? $namec{last_i} : undef,
      suffix          => $namec{suffix} // undef,
      suffix_i        => exists($namec{suffix}) ? $namec{suffix_i} : undef,
      namestring      => $namestring,
      nameinitstring  => $nameinitstr,
    );
  }
  else { # parse with bibtex library because Endnote XML is rubbish
    my $namestr = $node->textContent();

    # First sanitise the namestring due to Text::BibTeX::Name limitations on whitespace
    $namestr =~ s/\A\s*//xms;   # leading whitespace
    $namestr =~ s/\s*\z//xms;   # trailing whitespace
    $namestr =~ s/\s+/ /g;      # Collapse internal whitespace

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
    my $lastname  = $name->format($l_f);
    my $firstname = $name->format($f_f);
    my $prefix    = $name->format($p_f);
    my $suffix    = $name->format($s_f);

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

    $gen_lastname_i    = inits($nd_name->format($li_f));
    $gen_firstname_i   = inits($nd_name->format($fi_f));
    $gen_prefix_i      = inits($nd_name->format($pi_f));
    $gen_suffix_i      = inits($nd_name->format($si_f));

    # Only warn about lastnames since there should always be one
    $logger->warn("Couldn't determine Last Name for name \"$namestr\"") unless $lastname;

    my $namestring = '';
    # prefix
    my $ps;
    my $prefix_stripped;
    my $prefix_i;
    if ($prefix) {
      $prefix_i = $gen_prefix_i;
      $namestring .= "$prefix ";
    }
    # lastname
    my $ls;
    my $lastname_stripped;
    my $lastname_i;
    if ($lastname) {
      $lastname_i = $gen_lastname_i;
      $namestring .= "$lastname, ";
    }
    # suffix
    my $ss;
    my $suffix_stripped;
    my $suffix_i;
    if ($suffix) {
      $suffix_i = $gen_suffix_i;
      $namestring .= "$suffix, ";
    }
    # firstname
    my $fs;
    my $firstname_stripped;
    my $firstname_i;
    if ($firstname) {
      $firstname_i = $gen_firstname_i;
      $namestring .= "$firstname";
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
      firstname       => $firstname      eq '' ? undef : $firstname,
      firstname_i     => $firstname      eq '' ? undef : $firstname_i,
      lastname        => $lastname       eq '' ? undef : $lastname,
      lastname_i      => $lastname       eq '' ? undef : $lastname_i,
      prefix          => $prefix         eq '' ? undef : $prefix,
      prefix_i        => $prefix         eq '' ? undef : $prefix_i,
      suffix          => $suffix         eq '' ? undef : $suffix,
      suffix_i        => $suffix         eq '' ? undef : $suffix_i,
      namestring      => $namestring,
      nameinitstring  => $nameinitstr
    );
  }
}

# Passed an array ref of strings, returns an array ref of initials
sub _gen_initials {
  my @strings = @_;
  my @strings_out;
  foreach my $str (@strings) {
    # Deal with hyphenated name parts and normalise to a '-' character for easy
    # replacement with macro later
    if ($str =~ m/\p{Dash}/) {
      push @strings_out, join('-', _gen_initials(split(/\p{Dash}/, $str)));
    }
    else {
      my $chr = substr($str, 0, 1);
      # Keep diacritics with their following characters
      if ($chr =~ m/\p{Dia}/) {
        push @strings_out, substr($str, 0, 2);
      }
      else {
        push @strings_out, $chr;
      }
    }
  }
  return @strings_out;
}



# Do some sanitising on LaTeX special chars since this can't be nicely done by the parser
sub _norm {
  my $t = shift;
  return undef unless $t;
  $t =~ s/\A[\n\s]+//xms;
  $t =~ s/[\n\s]+\z//xms;
  return $t;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Biber::Input::file::endnotexml - look in a Zotero RDFXML file for an entry and create it if found

=head1 DESCRIPTION

Provides the extract_entries() method to get entries from a biblatexml data source
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

# vim: set tabstop=2 shiftwidth=2 expandtab:
