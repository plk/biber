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
  if (_norm($f->nodeName) eq 'options') {
    $biber->process_entry_options($dskey, $f->textContent());
  }

  # Literal fields
  foreach my $f ((@$fields_literal,@$fields_verbatim)) {
    # Pick out the node with the right mode
    my $node = _resolve_mode_set($entry, $f);
    $bibentry->set_datafield(_norm($node->nodeName), $node->textContent());
  }

  # List fields
  foreach my $f (@$fields_list) {
    # Pick out the node with the right mode
    my $node = _resolve_mode_set($entry, $f);
    $bibentry->set_datafield(_norm($node->nodeName), _split_list($node));
  }

  # Range fields
  foreach my $f (@$fields_range) {
    # Pick out the node with the right mode
    my $node = _resolve_mode_set($entry, $f);
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

  # Name fields
  foreach my $f (@$fields_name) {
    # Pick out the node with the right mode
    my $node = _resolve_mode_set($entry, $f);
    # name fields
    my $useprefix = Biber::Config->getblxoption('useprefix', $bibentry->get_field('entrytype'), $lc_key);
    my $names = new Biber::Entry::Names;
    foreach my $name ($node->findnodes("./$NS:person")) {
      $names->add_element(parsename($name, $f, {useprefix => $useprefix}));
    }
    $bibentry->set_datafield($f, $names);
  }

    # else {
    #   # Name fields are decoded during parsing, others here
    #   @tmp = map { decode_utf8($_) } @tmp;
    #   @tmp = map { remove_outer($_) } @tmp;
    #   $bibentry->set_datafield($f, [ @tmp ]);


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
      strip          => {'firstname' => 0,
                         'lastname'  => 0,
                         'prefix'    => 0,
                         'suffix'    => 0}
      }

=cut

sub parsename {
  my ($node, $fieldname, $opts) = @_;
  $logger->debug("   Parsing BibLaTeXML name object ...");
  my $usepre = $opts->{useprefix};

  my $lastname;
  my $firstname;
  my $prefix;
  my $suffix;
  my $lastname_i;
  my $lastname_it;
  my $firstname_i;
  my $firstname_it;
  my $prefix_i;
  my $prefix_it;
  my $suffix_i;
  my $suffix_it;

  if (my @parts = $rangenode->findnodes("./$NS:lastname/$NS:namepart->textContent()")) {
    $lastname = _join_name_parts(\@parts);
    ($lastname_i, $lastname_it) = _gen_initials(\@parts);
  }
  if (my $n = $rangenode->findnodes("./$NS:firstname/$NS:namepart->textContent()")) {
    $firstname = _join_name_parts(\@parts);
    ($firstname_i, $firstname_it) = _gen_initials(\@parts);
  }
  if (my $n = $rangenode->findnodes("./$NS:prefix/$NS:namepart->textContent()")) {
    $prefix = _join_name_parts(\@parts);
    ($prefix_i, $prefix_it) = _gen_initials(\@parts);
  }
  if (my $n = $rangenode->findnodes("./$NS:suffix/$NS:namepart->textContent()")) {
    $suffix = _join_name_parts(\@parts);
    ($suffix_i, $suffix_it) = _gen_initials(\@parts);
  }



  # # first name doesn't need this customisation as it's automatic for
  # # an abbreviated first name format but we'll do it anyway for consistency
  # my $nd_name = new Text::BibTeX::Name(strip_nosort($namestr, $fieldname));

  # # Period following normal initials
  # $li_f->set_text(BTN_LAST,  undef, undef, undef, '.');
  # $fi_f->set_text(BTN_FIRST, undef, undef, undef, '.');
  # $pi_f->set_text(BTN_VON,   undef, undef, undef, '.');
  # $si_f->set_text(BTN_JR,    undef, undef, undef, '.');
  # $li_f->set_options(BTN_LAST,  1, BTJ_MAYTIE, BTJ_NOTHING);
  # $fi_f->set_options(BTN_FIRST, 1, BTJ_MAYTIE, BTJ_NOTHING);
  # $pi_f->set_options(BTN_VON,   1, BTJ_MAYTIE, BTJ_NOTHING);
  # $si_f->set_options(BTN_JR,    1, BTJ_MAYTIE, BTJ_NOTHING);

  # # Nothing following truncated initials
  # $lit_f->set_text(BTN_LAST,  undef, undef, undef, '');
  # $fit_f->set_text(BTN_FIRST, undef, undef, undef, '');
  # $pit_f->set_text(BTN_VON,   undef, undef, undef, '');
  # $sit_f->set_text(BTN_JR,    undef, undef, undef, '');
  # $lit_f->set_options(BTN_LAST,  1, BTJ_NOTHING, BTJ_NOTHING);
  # $fit_f->set_options(BTN_FIRST, 1, BTJ_NOTHING, BTJ_NOTHING);
  # $pit_f->set_options(BTN_VON,   1, BTJ_NOTHING, BTJ_NOTHING);
  # $sit_f->set_options(BTN_JR,    1, BTJ_NOTHING, BTJ_NOTHING);

  # $gen_lastname_i    = decode_utf8($nd_name->format($li_f));
  # $gen_lastname_it   = decode_utf8($nd_name->format($lit_f));
  # $gen_firstname_i   = decode_utf8($nd_name->format($fi_f));
  # $gen_firstname_it  = decode_utf8($nd_name->format($fit_f));
  # $gen_prefix_i      = decode_utf8($nd_name->format($pi_f));
  # $gen_prefix_it     = decode_utf8($nd_name->format($pit_f));
  # $gen_suffix_i      = decode_utf8($nd_name->format($si_f));
  # $gen_suffix_it     = decode_utf8($nd_name->format($sit_f));

  # # Only warn about lastnames since there should always be one
  # $logger->warn("Couldn't determine Last Name for name \"$namestr\"") unless $lastname;

  # my $namestring = '';
  # # prefix
  # my $ps;
  # my $prefix_stripped;
  # my $prefix_i;
  # my $prefix_it;
  # if ($prefix) {
  #   $prefix_i        = $gen_prefix_i;
  #   $prefix_it       = $gen_prefix_it;
  #   $prefix_stripped = remove_outer($prefix);
  #   $ps = $prefix ne $prefix_stripped ? 1 : 0;
  #   $namestring .= "$prefix_stripped ";
  # }
  # # lastname
  # my $ls;
  # my $lastname_stripped;
  # my $lastname_i;
  # my $lastname_it;
  # if ($lastname) {
  #   $lastname_i        = $gen_lastname_i;
  #   $lastname_it       = $gen_lastname_it;
  #   $lastname_stripped = remove_outer($lastname);
  #   $ls = $lastname ne $lastname_stripped ? 1 : 0;
  #   $namestring .= "$lastname_stripped, ";
  # }
  # # suffix
  # my $ss;
  # my $suffix_stripped;
  # my $suffix_i;
  # my $suffix_it;
  # if ($suffix) {
  #   $suffix_i        = $gen_suffix_i;
  #   $suffix_it       = $gen_suffix_it;
  #   $suffix_stripped = remove_outer($suffix);
  #   $ss = $suffix ne $suffix_stripped ? 1 : 0;
  #   $namestring .= "$suffix_stripped, ";
  # }
  # # firstname
  # my $fs;
  # my $firstname_stripped;
  # my $firstname_i;
  # my $firstname_it;
  # if ($firstname) {
  #   $firstname_i        = $gen_firstname_i;
  #   $firstname_it       = $gen_firstname_it;
  #   $firstname_stripped = remove_outer($firstname);
  #   $fs = $firstname ne $firstname_stripped ? 1 : 0;
  #   $namestring .= "$firstname_stripped";
  # }

  # # Remove any trailing comma and space if, e.g. missing firstname
  # # Replace any nbspes
  # $namestring =~ s/,\s+\z//xms;
  # $namestring =~ s/~/ /gxms;

  # # Construct $nameinitstring
  # my $nameinitstr = '';
  # $nameinitstr .= $prefix_it . '_' if ( $usepre and $prefix );
  # $nameinitstr .= $lastname if $lastname;
  # $nameinitstr .= '_' . $suffix_it if $suffix;
  # $nameinitstr .= '_' . $firstname_it if $firstname;
  # $nameinitstr =~ s/\s+/_/g;
  # $nameinitstr =~ s/~/_/g;

  # # The "strip" entry tells us which of the name parts had outer braces
  # # stripped during processing so we can add them back when printing the
  # # .bbl so as to maintain maximum BibTeX compatibility
  # return Biber::Entry::Name->new(
  #   firstname       => $firstname      eq '' ? undef : $firstname_stripped,
  #   firstname_i     => $firstname      eq '' ? undef : $firstname_i,
  #   firstname_it    => $firstname      eq '' ? undef : $firstname_it,
  #   lastname        => $lastname       eq '' ? undef : $lastname_stripped,
  #   lastname_i      => $lastname       eq '' ? undef : $lastname_i,
  #   lastname_it     => $lastname       eq '' ? undef : $lastname_it,
  #   prefix          => $prefix         eq '' ? undef : $prefix_stripped,
  #   prefix_i        => $prefix         eq '' ? undef : $prefix_i,
  #   prefix_it       => $prefix         eq '' ? undef : $prefix_it,
  #   suffix          => $suffix         eq '' ? undef : $suffix_stripped,
  #   suffix_i        => $suffix         eq '' ? undef : $suffix_i,
  #   suffix_it       => $suffix         eq '' ? undef : $suffix_it,
  #   namestring      => $namestring,
  #   nameinitstring  => $nameinitstr,
  #   strip           => {'firstname' => $fs,
  #                       'lastname'  => $ls,
  #                       'prefix'    => $ps,
  #                       'suffix'    => $ss}
  #   );
}




# Joins name parts using BibTeX tie algorithm. Ties are added:
#
# 1. After the first part if it is less than three characters long
# 2. Before the last part
sub _join_name_parts {
  my $parts = shift;
  my $namestring = $parts->[0];
  $namestring .= length($parts->[0]) < 3 ? '~' : ' ';
  $namestring .= join(' ', @$parts[1 .. $#{$parts}-1]);
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
  return [ map {$_->textContent()} $node->findnodes("./$NS:item") ];
}


# Given an entry and a fieldname, returns the field node with the right language mode
sub _resolve_mode_set {
  my ($entry, $fieldname) = @_;
  if ($dm = Biber::Config->getoption('displaymode')) {
    if (my $nodelist = $entry->findnodes("./$NS:${fieldname}[\@mode='$dm']")) {
      return $nodelist->get_node(1);
    }
    else {
      return $entry->findnodes("./$NS:${fieldname}[not(\@mode)]")->get_pos(1);
    }
  }
  else {
    return $entry->findnodes("./$NS:${fieldname}[not(\@mode)]")->get_pos(1);
  }
  return undef; # Shouldn't get here
}





  foreach my $node (@nodes) {
    my $found_node;
    if (not $node->hasAttribute('mode')) {
    }

    if (lc($node->getAttribute('mode')) eq lc($dm)) {
      $found_node = $f;
    }
    else {
      # skip modes if we don't want one
      $found_node = $f unless $f->hasAttribute('mode');
    }

  }
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
