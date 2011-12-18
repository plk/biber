package Biber::Input::file::biblatexml;
use 5.014000;
use strict;
use warnings;
use base 'Exporter';

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
use Encode;
use File::Spec;
use Log::Log4perl qw(:no_extra_logdie_message);
use List::AllUtils qw( :all );
use XML::LibXML;
use XML::LibXML::Simple;
use Readonly;
use Data::Dump qw(dump);

my $logger = Log::Log4perl::get_logger('main');
my $orig_key_order = {};

Readonly::Scalar our $BIBLATEXML_NAMESPACE_URI => 'http://biblatex-biber.sourceforge.net/biblatexml';
Readonly::Scalar our $NS => 'bib';

# Handlers for field types
# The names of these have nothing to do whatever with the biblatex field types
# They just started out copying them - they are categories of this specific
# data source date types
my %handlers = (
                'date'     => \&_date,
                'list'     => \&_list,
                'name'     => \&_name,
                'range'    => \&_range,
                'related'  => \&_related,
                'verbatim' => \&_verbatim
);

# Read driver config file
my $dcfxml = driver_config('biblatexml');

=head2 extract_entries

   Main data extraction routine.
   Accepts a data source identifier (filename in this case),
   preprocesses the file and then looks for the passed keys,
   creating entries when it finds them and passes out an
   array of keys it didn't find.

=cut

sub extract_entries {
  my ($filename, $keys) = @_;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $bibentries = $section->bibentries;
  my @rkeys = @$keys;
  my $tf; # Up here so that the temp file has enough scope to survive until we've
          # used it
  $logger->trace("Entering extract_entries() in driver 'biblatexml'");

  # If it's a remote data file, fetch it first
  if ($filename =~ m/\A(?:https?|ftp):\/\//xms) {
    $logger->info("Data source '$filename' is a remote .xml - fetching ...");
    require LWP::Simple;
    require File::Temp;
    $tf = File::Temp->new(TEMPLATE => 'biber_remote_data_source_XXXXX',
                          DIR => $Biber::MASTER->biber_tempdir,
                          SUFFIX => '.xml');
    unless (LWP::Simple::is_success(LWP::Simple::getstore($filename, $tf->filename))) {
      biber_error("Could not fetch file '$filename'");
    }
    $filename = $tf->filename;
  }
  else {
    # Need to get the filename so we increment
    # the filename count for preambles at the bottom of this sub
    my $trying_filename = $filename;
    unless ($filename = locate_biber_file($filename)) {
      biber_error("Cannot find file '$trying_filename'!")
    }
  }

  # Log that we found a data file
  $logger->info("Found BibLaTeXML data file '$filename'");

  # Set up XML parser and namespace
  my $parser = XML::LibXML->new();
  my $bltxml = $parser->parse_file($filename)
    or biber_error("Can't parse file $filename");
  my $xpc = XML::LibXML::XPathContext->new($bltxml);
  $xpc->registerNs($NS, $BIBLATEXML_NAMESPACE_URI);

  if ($section->is_allkeys) {
    $logger->debug("All citekeys will be used for section '$secnum'");
    # Loop over all entries, creating objects
    foreach my $entry ($xpc->findnodes("//$NS:entry")) {
      $logger->debug('Parsing BibLaTeXML entry object ' . $entry->nodePath);

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
      foreach my $id ($entry->findnodes("./$NS:id")) {
        my $ids = $id->textContent();

        # Skip aliases which are also real entry keys
        if ($section->has_everykey($ids)) {
          biber_warn("Citekey alias '$ids' is also a real entry key, skipping ...");
          next;
        }


        # Warn on conflicting aliases
        if (my $otherid = $section->get_citekey_alias($ids)) {
          if ($otherid ne $key) {
            biber_warn("Citekey alias '$ids' already has an alias '$otherid', skipping ...");
          }
        }
        else {
          # Since this is allkeys, we are guaranteed that the real entry for the alias
          # will be available
          $section->set_citekey_alias($ids, $key);
          $logger->debug("Citekey '$ids' is an alias for citekey '$key'");
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

      create_entry($key, $entry);

      # We do this as otherwise we have no way of determining the origing .bib entry order
      # We need this in order to do sorting=none + allkeys because in this case, there is no
      # "citeorder" because nothing is explicitly cited and so "citeorder" means .bib order
      push @{$orig_key_order->{$filename}}, $key;

    }

    # if allkeys, push all bibdata keys into citekeys (if they are not already there)
    # We are using the special "orig_key_order" array which is used to deal with the
    # sitiation when sorting=non and allkeys is set. We need an array rather than the
    # keys from the bibentries hash because we need to preserver the original order of
    # the .bib as in this case the sorting sub "citeorder" means "bib order" as there are
    # no explicitly cited keys
    $section->add_citekeys(@{$orig_key_order->{$filename}});
    $logger->debug("Added all citekeys to section '$secnum': " . join(', ', $section->get_citekeys));
  }
  else {
    # loop over all keys we're looking for and create objects
    $logger->debug('Wanted keys: ' . join(', ', @$keys));
    foreach my $wanted_key (@$keys) {
      $logger->debug("Looking for key '$wanted_key' in BibLaTeXML file '$filename'");
      if (my @entries = $xpc->findnodes("//$NS:entry[\@id='$wanted_key']")) {
        # Check to see if there is more than one entry with this key and warn if so
        if ($#entries > 0) {
          biber_warn("Found more than one entry for key '$wanted_key' in '$filename': " .
                       join(',', map {$_->getAttribute('id')} @entries) . ' - skipping duplicates ...');
        }
        my $entry = $entries[0];

        $logger->debug("Found key '$wanted_key' in BibLaTeXML file '$filename'");
        $logger->debug('Parsing BibLaTeXML entry object ' . $entry->nodePath);
        # See comment above about the importance of the case of the key
        # passed to create_entry()
        # Skip creation if it's already been done, for example, via a citekey alias
        unless ($section->bibentries->entry_exists($wanted_key)) {
          create_entry($wanted_key, $entry);
        }
        # found a key, remove it from the list of keys we want
        @rkeys = grep {$wanted_key ne $_} @rkeys;
      }
      elsif ($xpc->findnodes("//$NS:entry/$NS:id[text()='$wanted_key']")) {
        my $key = $xpc->findnodes("//$NS:entry/\@id");
        $logger->debug("Citekey '$wanted_key' is an alias for citekey '$key'");
        $section->set_citekey_alias($wanted_key, $key);

        # Make sure there is a real, cited entry for the citekey alias
        # just in case only the alias is cited
        unless ($section->bibentries->entry_exists($key)) {
          my $entry = $xpc->findnodes("//$NS:entry/[\@id='$key']");
          create_entry($key, $entry);
          $section->add_citekeys($key);
        }

        # found a key, remove it from the list of keys we want
        @rkeys = grep {$wanted_key ne $_} @rkeys;
      }
      $logger->debug('Wanted keys now: ' . join(', ', @rkeys));
    }
  }

  return @rkeys;
}


=head2 create_entry

   Create a Biber::Entry object from an entry found in a biblatexml data source

=cut

sub create_entry {
  my ($key, $entry) = @_;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);

  my $struc = Biber::Config->get_structure;
  my $bibentries = $section->bibentries;
  my $bibentry = new Biber::Entry;

  $bibentry->set_field('citekey', $key);

  # Some entry attributes
  if (my $hp = $entry->getAttribute('howpublished')) {
    $bibentry->set_datafield('howpublished', $hp);
  }
  # displaymode is set as an option so we benefit from option scope handling
  if (my $mode = $entry->getAttribute('mode')) {
    Biber::Config->setblxoption('displaymode', {'*' => [ $mode ] }, 'PER_ENTRY', $key);
  }

  # We put all the fields we find modulo field aliases into the object.
  # Validation happens later and is not datasource dependent
FLOOP:  foreach my $f (uniq map {$_->nodeName()} $entry->findnodes('*')) {

    # We have to process local options as early as possible in order
    # to make them available for things that need them like name parsing
    if (_norm($entry->nodeName) eq 'options') {
      if (my $node = _resolve_display_mode($entry, 'options')) {
        $Biber::MASTER->process_entry_options($key, $node->textContent());
        # Save the raw options in case we are to output another input format like
        # biblatexml
        $bibentry->set_field('rawoptions', $node->textContent());
      }
    }

    if (my $fm = $dcfxml->{fields}{field}{_norm($f)}) {
      # No aliases processed here as this data source is supposed to be a 1:1 mapping
      # of the biblatex data model
      &{$handlers{$fm->{handler}}}($bibentry, $entry, $f, $f, $key);
    }
    # Default if no explicit way to set the field
    else {
      my $node = _resolve_display_mode($entry, $f);
      my $value = $node->textContent();
      $bibentry->set_datafield($f, $value);
    }
  }

  $bibentry->set_field('entrytype', $entry->getAttribute('entrytype'));
  $bibentry->set_field('datatype', 'biblatexml');
  $bibentries->add_entry($key, $bibentry);

  return;
}

# Related entries
sub _related {
  my ($bibentry, $entry, $f, $to, $key) = @_;
  # Pick out the node with the right mode
  my $node = _resolve_display_mode($entry, $f, $key);
  # TODO
  # Current biblatex data model doesn't allow for multiple items here
  foreach my $item ($node->findnodes("./$NS:item")) {
    $bibentry->set_datafield('related', $item->getAttribute('ids'));
    $bibentry->set_datafield('relatedtype', $item->getAttribute('type'));
    if (my $string = $item->getAttribute('string')) {
      $bibentry->set_datafield('relatedstring', $string);
    }
  }
  return;
}

# Verbatim fields
sub _verbatim {
  my ($bibentry, $entry, $f, $to, $key) = @_;
  # Pick out the node with the right mode
  my $node = _resolve_display_mode($entry, $f, $key);

  # eprint is special case
  if ($f eq "$NS:eprint") {
    $bibentry->set_datafield('eprinttype', $node->getAttribute('type'));
    if (my $ec = $node->getAttribute('class')) {
      $bibentry->set_datafield('eprintclass', $ec);
    }
  }
  else {
    $bibentry->set_datafield(_norm($to), $node->textContent());
  }
  return;
}

# List fields
sub _list {
  my ($bibentry, $entry, $f, $to, $key) = @_;
  # Pick out the node with the right mode
  my $node = _resolve_display_mode($entry, $f, $key);
  $bibentry->set_datafield(_norm($to), _split_list($node));
  return;
}

# Range fields
sub _range {
  my ($bibentry, $entry, $f, $to, $key) = @_;
  # Pick out the node with the right mode
  my $node = _resolve_display_mode($entry, $f, $key);
  # List of ranges/values
  if (my @rangelist = $node->findnodes("./$NS:list/$NS:item")) {
    my $rl;
    foreach my $range (@rangelist) {
      push @$rl, _parse_range_list($range);
    }
    $bibentry->set_datafield(_norm($to), $rl);
  }
  # Simple range
  elsif (my $range = $node->findnodes("./$NS:range")->get_node(1)) {
    $bibentry->set_datafield(_norm($to), [ _parse_range_list($range) ]);
  }
  # simple list
  else {
    $bibentry->set_datafield(_norm($to), $node->textContent());
  }
  return;
}

# Date fields
sub _date {
  my ($bibentry, $entry, $f, $to, $key) = @_;
  foreach my $node ($entry->findnodes("./$f")) {
    my $datetype = $node->getAttribute('datetype') // '';
    # We are not validating dates here, just syntax parsing
    my $date_re = qr/(\d{4}) # year
                     (?:-(\d{2}))? # month
                     (?:-(\d{2}))? # day
                    /xms;
    if (my $start = $node->findnodes("./$NS:start")) { # Date range
      my $end = $node->findnodes("./$NS:end");
      # Start of range
      if (my ($byear, $bmonth, $bday) =
          $start->get_node(1)->textContent() =~ m|\A$date_re\z|xms) {
        $bibentry->set_datafield($datetype . 'year', $byear)      if $byear;
        $bibentry->set_datafield($datetype . 'month', $bmonth)    if $bmonth;
        $bibentry->set_datafield($datetype . 'day', $bday)        if $bday;
      }
      else {
        biber_warn("Invalid format '" . $start->get_node(1)->textContent() . "' of date field '$f' range start in entry '$key' - ignoring", $bibentry);
      }

      # End of range
      if (my ($eyear, $emonth, $eday) =
          $end->get_node(1)->textContent() =~ m|\A(?:$date_re)?\z|xms) {
        $bibentry->set_datafield($datetype . 'endmonth', $emonth)    if $emonth;
        $bibentry->set_datafield($datetype . 'endday', $eday)        if $eday;
        if ($eyear) {           # normal range
          $bibentry->set_datafield($datetype . 'endyear', $eyear);
        }
        else {            # open ended range - endyear is defined but empty
          $bibentry->set_datafield($datetype . 'endyear', '');
        }
      }
      else {
        biber_warn("Invalid format '" . $end->get_node(1)->textContent() . "' of date field '$f' range end in entry '$key' - ignoring", $bibentry);
      }
    }
    else { # Simple date
      if (my ($byear, $bmonth, $bday) =
          $node->textContent() =~ m|\A$date_re\z|xms) {
        # did this entry get its year/month fields from splitting an ISO8601 date field?
        # We only need to know this for date, year/month as year/month can also
        # be explicitly set. It makes a difference on how we do any potential future
        # date validation
        $bibentry->set_field('datesplit', 1) if $datetype eq '';
        $bibentry->set_datafield($datetype . 'year', $byear)      if $byear;
        $bibentry->set_datafield($datetype . 'month', $bmonth)    if $bmonth;
        $bibentry->set_datafield($datetype . 'day', $bday)        if $bday;
      }
      else {
        biber_warn("Invalid format '" . $node->textContent() . "' of date field '$f' in entry '$key' - ignoring", $bibentry);
      }
    }
  }
  return;
}

# Name fields
sub _name {
  my ($bibentry, $entry, $f, $to, $key) = @_;
  # Pick out the node with the right mode
  my $node = _resolve_display_mode($entry, $f, $key);
  my $useprefix = Biber::Config->getblxoption('useprefix', $bibentry->get_field('entrytype'), $key);
  my $names = new Biber::Entry::Names;
  foreach my $name ($node->findnodes("./$NS:person")) {
    $names->add_name(parsename($name, $f, {useprefix => $useprefix}));
  }

  # Deal with explicit "moreenames" in data source
  if ($node->getAttribute('morenames')) {
    $names->set_morenames;
  }

  $bibentry->set_datafield(_norm($to), $names);
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
      gender         => sm

=cut

sub parsename {
  my ($node, $fieldname, $opts) = @_;
  $logger->debug('Parsing BibLaTeXML name object ' . $node->nodePath);
  my $usepre = $opts->{useprefix};

  my %namec;

  if ( $node->firstChild->nodeName eq '#text' and
       not $node->findnodes("./$NS:last")) {
    $namec{last} = $node->textContent();
    if (my $ni = $node->getAttribute('initial')) {
      $namec{last_i} = [$ni];
    }
    else {
      $namec{last_i} = [_gen_initials($namec{last})];
    }
  }
  else {
    foreach my $n ('last', 'first', 'middle', 'prefix', 'suffix') {
      # If there is a name component node for this component ...
      if (my $nc_node = $node->findnodes("./$NS:$n")->get_node(1)) {
        # name component with parts
        if (my @parts = map {$_->textContent()} $nc_node->findnodes("./$NS:namepart")) {
          $namec{$n} = _join_name_parts(\@parts);
          $logger->debug("Found name component '$n': " . $namec{$n});
          if (my $ni = $node->getAttribute('initial')) {
            $namec{"${n}_i"} = [$ni];
          }
          else {
            $namec{"${n}_i"} = [_gen_initials(@parts)];
          }
        }
        # with no parts
        elsif (my $t = $nc_node->textContent()) {
          $namec{$n} = $t;
          $logger->debug("Found name component '$n': $t");
          if (my $ni = $node->getAttribute('initial')) {
            $namec{"${n}_i"} = [$ni];
          }
          else {
            $namec{"${n}_i"} = [_gen_initials($t)];
          }
        }
      }
    }
  }

  # Only warn about lastnames since there should always be one
  biber_warn("Couldn't determine Lastname for name XPath: " . $node->nodePath) unless exists($namec{last});

  my $namestring = '';

  # prefix
  if (my $p = $namec{prefix}) {
    $namestring .= "$p ";
  }

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
  $nameinitstr .= join('', @{$namec{prefix_i}}) . '_' if ( $usepre and exists($namec{prefix}) );
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
    prefix          => $namec{prefix} // undef,
    prefix_i        => exists($namec{prefix}) ? $namec{prefix_i} : undef,
    suffix          => $namec{suffix} // undef,
    suffix_i        => exists($namec{suffix}) ? $namec{suffix_i} : undef,
    namestring      => $namestring,
    nameinitstring  => $nameinitstr,
    gender          => $node->getAttribute('gender')

    );
}

# Joins name parts using BibTeX tie algorithm. Ties are added:
#
# 1. After the first part if it is less than three characters long
# 2. Before the last part
sub _join_name_parts {
  my $parts = shift;
  # special case - 1 part
  if ($#{$parts} == 0) {
    return $parts->[0];
  }
  # special case - 2 parts
  if ($#{$parts} == 1) {
    return $parts->[0] . '~' . $parts->[1];
  }
  my $namestring = $parts->[0];
  $namestring .= length($parts->[0]) < 3 ? '~' : ' ';
  $namestring .= join(' ', @$parts[1 .. ($#{$parts} - 1)]);
  $namestring .= '~' . $parts->[$#{$parts}];
  return $namestring;
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
  my $node = shift;
  if (my @list = $node->findnodes("./$NS:item")) {
    return [ map {$_->textContent()} @list ];
  }
  else {
    return [ $node->textContent() ];
  }
}


# Given an entry and a fieldname, returns the field node with the right language mode
sub _resolve_display_mode {
  my ($entry, $fieldname, $key) = @_;
  my @nodelist;
  my $dm = Biber::Config->getblxoption('displaymode', $entry->getAttribute('entrytype'), $key);
  $logger->debug("Resolving display mode for '$fieldname' in node " . $entry->nodePath );
  # Either a fieldname specific mode or the default or a last-ditch fallback
  my $modelist = $dm->{_norm($fieldname)} || $dm->{'*'} || ['original'];
  # Make sure there is an 'original' fallback in the list
  push @$modelist, 'original' unless first {$_ eq 'original'} @$modelist;
  foreach my $mode (@$modelist) {
    my $modeattr;
    # mode is omissable if it is "original"
    if ($mode eq 'original') {
      $mode = 'original';
      $modeattr = "\@mode='$mode' or not(\@mode)"
    }
    else {
      $modeattr = "\@mode='$mode'"
    }
    $logger->debug("Found display mode '$mode' for field '$fieldname'");
    if (@nodelist = $entry->findnodes("./${fieldname}[$modeattr]")) {
      # Check to see if there is more than one entry with a mode and warn
      if ($#nodelist > 0) {
        biber_warn("Found more than one mode '$mode' '$fieldname' field in entry '" .
                   $entry->getAttribute('id') . "' - skipping duplicates ...");
      }
      return $nodelist[0];
    }
  }
  return undef; # Shouldn't get here
}

# normalise a node name as they have a namsespace and might not be lowercase
sub _norm {
  my $name = lc(shift);
  $name =~ s/\A$NS://xms;
  return $name;
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
