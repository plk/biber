package Biber::Input::file::biblatexml;
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
use Encode;
use File::Spec;
use Log::Log4perl qw(:no_extra_logdie_message);
use base 'Exporter';
use List::AllUtils qw(first);
use XML::LibXML;
use Readonly;
use Data::Dump qw(dump);

my $logger = Log::Log4perl::get_logger('main');

Readonly::Scalar our $BIBLATEXML_NAMESPACE_URI => 'http://biblatex-biber.sourceforge.net/biblatexml';
Readonly::Scalar our $NS => 'bib';

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

  # First make sure we can find the biblatexml file
  $filename .= '.xml' unless $filename =~ /\.xml\z/xms; # Normalise filename
  my $trying_filename = $filename;
  if ($filename = locate_biber_file($filename)) {
    $logger->info("Processing biblatexml format file '$filename' for section $secnum");
  }
  else {
    $logger->logdie("Cannot find file '$trying_filename'!")
  }

  # Set up XML parser and namespace
  my $parser = XML::LibXML->new();
  my $bltxml = $parser->parse_file($filename)
    or $logger->logcroak("Can't parse file $filename");
  my $xpc = XML::LibXML::XPathContext->new($bltxml);
  $xpc->registerNs($NS, $BIBLATEXML_NAMESPACE_URI);



  if ($section->is_allkeys) {
    $logger->debug("All citekeys will be used for section '$secnum'");
    # Loop over all entries, creating objects
    foreach my $entry ($xpc->findnodes("//$NS:entry")) {
      $logger->debug(' Parsing BibLaTeXML entry object ' . $entry->nodePath);
      # We have to pass the datasource cased key to
      # create_entry() as this sub needs to know the original case of the
      # citation key so we can do case-insensitive key/entry comparisons
      # later but we need to put the original citation case when we write
      # the .bbl. If we lowercase before this, we lose this information.
      # Of course, with allkeys, "citation case" means "datasource entry case"

      # If an entry has no key, ignore it and warn
      unless ($entry->hasAttribute('id')) {
        $logger->warn("Invalid or undefined BibLaTeXML entry key in file '$filename', skipping ...");
        $biber->{warnings}++;
        next;
      }
      create_entry($biber, $entry->getAttribute('id'), $entry);
    }

    # if allkeys, push all bibdata keys into citekeys (if they are not already there)
    $section->add_citekeys($section->bibentries->sorted_keys);
    $logger->debug("Added all citekeys to section '$secnum': " . join(', ', $section->get_citekeys));
  }
  else {
    # loop over all keys we're looking for and create objects
    $logger->debug('Wanted keys: ' . join(', ', @$keys));
    foreach my $wanted_key (@$keys) {
      $logger->debug("Looking for key '$wanted_key' in BibLaTeXML file '$filename'");
      # Cache index keys are lower-cased. This next line effectively implements
      # case insensitive citekeys
      # This will also get the first match it finds
      if (my @entries = $xpc->findnodes("//$NS:entry[\@id='" . lc($wanted_key) . "']")) {
        my $entry;
        # Check to see if there is more than one entry with this key and warn if so
        if ($#entries > 0) {
          $logger->warn("Found more than one entry for key '$wanted_key' in '$filename': " .
                       join(',', map {$_->getAttribute('id')} @entries) . ' - using the first one!');
          $biber->{warnings}++;
        }
        $entry = $entries[0];

        $logger->debug("Found key '$wanted_key' in BibLaTeXML file '$filename'");
        $logger->debug(' Parsing BibLaTeXML entry object ' . $entry->nodePath);
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

   Create a Biber::Entry object from an entry found in a biblatexml data source

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

  my $fields_literal = $struc->get_field_type('literal');
  my $fields_list = $struc->get_field_type('list');
  my $fields_verbatim = $struc->get_field_type('verbatim');
  my $fields_range = $struc->get_field_type('range');
  my $fields_name = $struc->get_field_type('name');

  # Set entrytype. This may be changed later in process_aliases
  $bibentry->set_field('entrytype', $entry->getAttribute('entrytype'));

  # Special fields

  # We have to process local options as early as possible in order
  # to make them available for things that need them like name parsing
  if (_norm($entry->nodeName) eq 'options') {
    if (my $node = _resolve_mode_set($biber, $entry, 'options')) {
      $biber->process_entry_options($dskey, $node->textContent());
    }
  }

  # Literal fields
  foreach my $f ((@$fields_literal,@$fields_verbatim)) {
    # Pick out the node with the right mode
    if (my $node = _resolve_mode_set($biber, $entry, $f)) {
      $bibentry->set_datafield(_norm($node->nodeName), $node->textContent());
    }
  }

  # List fields
  foreach my $f (@$fields_list) {
    # Pick out the node with the right mode
    if (my $node = _resolve_mode_set($biber, $entry, $f)) {
      $bibentry->set_datafield(_norm($node->nodeName), _split_list($node));
    }
  }

  # Range fields
  foreach my $f (@$fields_range) {
    # Pick out the node with the right mode
    if (my $node = _resolve_mode_set($biber, $entry, $f)) {
      # List of ranges/values
      if (my @rangelist = $node->findnodes("./$NS:list/$NS:item")) {
        my $rl;
        foreach my $range (@rangelist) {
          push @$rl, _parse_range_list($range);
        }
        $bibentry->set_datafield(_norm($node->nodeName), $rl);
      }
      # Simple range
      elsif (my $range = $node->findnodes("./$NS:range")->get_node(1)) {
        $bibentry->set_datafield(_norm($node->nodeName), [ _parse_range_list($range) ]);
      }
      # simple list
      else {
        $bibentry->set_datafield(_norm($node->nodeName), $node->textContent());
      }
    }
  }

  # Name fields
  foreach my $f (@$fields_name) {
    # Pick out the node with the right mode
    if (my $node = _resolve_mode_set($biber, $entry, $f)) {
      my $useprefix = Biber::Config->getblxoption('useprefix', $bibentry->get_field('entrytype'), $lc_key);
      my $names = new Biber::Entry::Names;
      foreach my $name ($node->findnodes("./$NS:person")) {
        $names->add_element(parsename($name, $f, {useprefix => $useprefix}));
      }
      $bibentry->set_datafield($f, $names);
    }
  }

  $bibentry->set_field('datatype', 'bibtex');
  $bibentries->add_entry($lc_key, $bibentry);

  return;
}

=head2 parsename

    Given a name node, this function returns a Biber::Entry::Name object

    Returns an object which internally looks a bit like this:

    { firstname     => 'John',
      firstname_i   => 'J.',
      firstname_it  => 'J',
      lastname      => 'Doe',
      lastname_i    => 'D.',
      lastname_it   => 'D',
      prefix        => undef,
      prefix_i      => undef,
      prefix_it     => undef,
      suffix        => undef,
      suffix_i      => undef,
      suffix_it     => undef,
      namestring    => 'Doe, John',
      nameinitstring => 'Doe_J',

=cut

sub parsename {
  my ($node, $fieldname, $opts) = @_;
  $logger->debug('   Parsing BibLaTeXML name object ' . $node->nodePath);
  my $usepre = $opts->{useprefix};

  my %namec;

  foreach my $n ('last', 'first', 'prefix', 'suffix') {
    # If there is a name component node for this component ...
    if (my $nc_node = $node->findnodes("./$NS:$n")->get_node(1)) {
    # name component with parts
      if (my @parts = map {$_->textContent()} $nc_node->findnodes("./$NS:namepart")) {
        $namec{$n} = _join_name_parts(\@parts);
        $logger->debug("      Found name component '$n': " . $namec{$n});
        ($namec{"${n}_i"}, $namec{"${n}_it"}) = _gen_initials(\@parts);
      }
      # with no parts
      elsif (my $t = $nc_node->textContent()) {
        $logger->debug("      Found name component '$n': $t");
        $namec{$n} = $t;
        ($namec{"${n}_i"}, $namec{"${n}_it"}) = _gen_initials([$t]);
      }
    }
  }

  # Only warn about lastnames since there should always be one
  $logger->warn("Couldn't determine Lastname for name XPath: " . $node->nodePath) unless exists($namec{last});

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

  # Remove any trailing comma and space if, e.g. missing firstname
  # Replace any nbspes
  $namestring =~ s/,\s+\z//xms;
  $namestring =~ s/~/ /gxms;

  # Construct $nameinitstring
  my $nameinitstr = '';
  $nameinitstr .= $namec{prefix_it} . '_' if ( $usepre and exists($namec{prefix}) );
  $nameinitstr .= $namec{last} if exists($namec{last});
  $nameinitstr .= '_' . $namec{suffix_it} if exists($namec{suffix});
  $nameinitstr .= '_' . $namec{first_it} if exists($namec{first});
  $nameinitstr =~ s/\s+/_/g;
  $nameinitstr =~ s/~/_/g;

  return Biber::Entry::Name->new(
    firstname       => $namec{first} // undef,
    firstname_i     => exists($namec{first}) ? $namec{first_i} : undef,
    firstname_it    => exists($namec{first}) ? $namec{first_it} : undef,
    lastname        => $namec{last} // undef,
    lastname_i      => exists($namec{last}) ? $namec{last_i} : undef,
    lastname_it     => exists($namec{last}) ? $namec{last_it} : undef,
    prefix          => $namec{prefix} // undef,
    prefix_i        => exists($namec{prefix}) ? $namec{prefix_i} : undef,
    prefix_it       => exists($namec{prefix}) ? $namec{prefix_it} : undef,
    suffix          => $namec{suffix} // undef,
    suffix_i        => exists($namec{suffix}) ? $namec{suffix_i} : undef,
    suffix_it       => exists($namec{suffix}) ? $namec{suffix_it} : undef,
    namestring      => $namestring,
    nameinitstring  => $nameinitstr,
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

# Passed an array ref of strings, returns an array of two strings,
# the first is the TeX initials and the second the terse initials
sub _gen_initials {
  my $strings_ref = shift;
  my @strings;
  foreach my $str (@$strings_ref) {
    my $chr = substr($str, 0, 1);
    # Keep diacritics with their following characters
    if ($chr =~ m/\p{Dia}/) {
      push @strings, substr($str, 0, 2);
    }
    else {
      push @strings, substr($str, 0, 1);
    }
  }
  return (join('.~', @strings) . '.', join('', @strings));
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
sub _resolve_mode_set {
  my ($biber, $entry, $fieldname) = @_;
  my @nodelist;
  if (my $dm = Biber::Config->getoption('displaymode')) {
    if (@nodelist = $entry->findnodes("./$NS:${fieldname}[\@mode='$dm']")) {
      # Check to see if there is more than one entry with a mode and warn
      if ($#nodelist > 0) {
        $logger->warn("Found more than one mode '$dm' '$fieldname' field in entry '" .
                      $entry->getAttribute('id') . "' - using the first one!");
        $biber->{warnings}++;
      }
      return $nodelist[0];
    }
    elsif (@nodelist = $entry->findnodes("./$NS:${fieldname}[not(\@mode)]")) {
      # Check to see if there is more than one entry with a mode and warn
      if ($#nodelist > 0) {
        $logger->warn("Found more than one mode;ess '$fieldname' field in entry '" .
                      $entry->getAttribute('id') . "' - using the first one!");
        $biber->{warnings}++;
      }
      return $nodelist[0];
    }
  }
  elsif (@nodelist = $entry->findnodes("./$NS:${fieldname}[not(\@mode)]")) {
    # Check to see if there is more than one entry with a mode and warn
    if ($#nodelist > 0) {
      $logger->warn("Found more than one mode;ess '$fieldname' field in entry '" .
                    $entry->getAttribute('id') . "' - using the first one!");
      $biber->{warnings}++;
    }
    return $nodelist[0];
  }
  return undef;                 # Shouldn't get here
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
