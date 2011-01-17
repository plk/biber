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
  $xpc->registerNs('bib', $BIBLATEXML_NAMESPACE_URI);



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

  # all field nodes for this entry
  my @flist = $entry->childNodes;

  # here we find those field nodes that do not require splitting
  my @flistnosplit;
  foreach my $f (@flist) {
    push @flistnosplit, $f if first {lc($f->nodeName) eq $_} @{$struc->get_field_type('split')};
  }

  foreach my $f (@flistnosplit) {
    my $found_node;
    if ($dm = Biber::Config->getoption('displaymode')) {
      if (lc($f->getAttribute('mode')) eq lc($dm)) {
        $found_node = $f;
      }
    }
    else {
      # skip modes if we don't want one
      $found_node = $f unless $f->hasAttribute('mode');
    }
    $bibentry->set_datafield(lc($f->nodeName), $f->text()) if $found_node;

    # We have to process local options as early as possible in order
    # to make them available for things that need them like parsename()
    if (lc($f->nodeName) eq 'options') {
      $biber->process_entry_options($bibentry);
    }
  }

  # Set entrytype. This may be changed later in process_aliases
  $bibentry->set_field('entrytype', $entry->type);

  # Now fields that do require splitting
  foreach my $f ( @{$struc->get_field_type('split')} ) {
    next unless $entry->exists($f);
    my @tmp = $entry->split($f);

    if ($struc->is_field_type('name', $f)) {
      my $useprefix = Biber::Config->getblxoption('useprefix', $bibentry->get_field('entrytype'), $lc_key);
      my $names = new Biber::Entry::Names;
      foreach my $name (@tmp) {

        # Consecutive "and" causes Text::BibTeX::Name to segfault
        unless ($name) {
          $logger->warn("Name in key '$dskey' is empty (probably consecutive 'and'): skipping name");
          $biber->{warnings}++;
          $section->del_citekey($dskey);
          next;
        }

        $name = decode_utf8($name);

        # Check for malformed names in names which aren't completely escaped

        # Too many commas
        unless ($name =~ m/\A{.+}\z/xms) { # Ignore these tests for escaped names
          my @commas = $name =~ m/,/g;
          if ($#commas > 1) {
            $logger->warn("Name \"$name\" has too many commas: skipping entry $dskey");
            $biber->{warnings}++;
            $section->del_citekey($dskey);
            next;
          }

          # Consecutive commas cause Text::BibTeX::Name to segfault
          if ($name =~ /,,/) {
            $logger->warn("Name \"$name\" is malformed (consecutive commas): skipping entry $dskey");
            $biber->{warnings}++;
            $section->del_citekey($dskey);
            return;
          }
        }

        $names->add_element(parsename($name, $f, {useprefix => $useprefix}));
      }
      $bibentry->set_datafield($f, $names);

    }
    else {
      # Name fields are decoded during parsing, others here
      @tmp = map { decode_utf8($_) } @tmp;
      @tmp = map { remove_outer($_) } @tmp;
      $bibentry->set_datafield($f, [ @tmp ]);
    }
  }
  $bibentry->set_field('datatype', 'bibtex');
  $bibentries->add_entry($lc_key, $bibentry);

  return;
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
