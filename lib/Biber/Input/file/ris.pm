package Biber::Input::file::ris;
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
use Encode;
use File::Spec;
use Log::Log4perl qw(:no_extra_logdie_message);
use base 'Exporter';
use List::AllUtils qw(first uniq);
use XML::LibXML::Simple;
use Readonly;
use Data::Dump qw(dump);
use Switch;

my $logger = Log::Log4perl::get_logger('main');

# Handlers for field types
# The names of these have nothing to do whatever with the biblatex field types
# They just started out copying them - they are categories of this specific
# data source date types
my %handlers = (
                'date'     => \&_date,
                'name'     => \&_name,
                'range'    => \&_range,
                'verbatim' => \&_verbatim
);

# we assume that the driver config file is in the same dir as the driver:
(my $vol, my $driver_path, undef) = File::Spec->splitpath( $INC{"Biber/Input/file/ris.pm"} );

# Deal with the strange world of Par::Packer paths, see similar code in Biber.pm
my $dcf;
if ($driver_path =~ m|/par\-| and $driver_path !~ m|/inc|) { # a mangled PAR @INC path
  $dcf = File::Spec->catpath($vol, "$driver_path/inc/lib/Biber/Input/file", 'ris.dcf');
}
else {
  $dcf = File::Spec->catpath($vol, $driver_path, 'ris.dcf');
}

# Read driver config file
my $dcfxml = XML::LibXML::Simple::XMLin($dcf,
                                        'ForceContent' => 1,
                                        'ForceArray' => [
                                                         qr/\Aentry-type\z/,
                                                         qr/\Afield\z/,
                                                        ],
                                        'NsStrip' => 1,
                                        'KeyAttr' => ['name']);

# Check we have the right driver
unless ($dcfxml->{driver} eq 'ris') {
  $logger->logdie("Expected driver config type 'ris', got '" . $dcfxml->{driver} . "'");
}



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
  my $tf;

  $logger->trace("Entering extract_entries()");

  # If it's a remote file, fetch it first
  if ($filename =~ m/\A(?:https?|ftp):\/\//xms) {
    $logger->info("Data source '$filename' is a remote file - fetching ...");
    require LWP::Simple;
    require File::Temp;
    $tf = File::Temp->new(SUFFIX => '.ris');
    unless (LWP::Simple::is_success(LWP::Simple::getstore($filename, $tf->filename))) {
      $logger->logdie ("Could not fetch file '$filename'");
    }
    $filename = $tf->filename;
  }
  else {
    my $trying_filename = $filename;
    unless ($filename = locate_biber_file($filename)) {
      $logger->logdie("Cannot find file '$trying_filename'!")
    }
  }

  # pre-process into something a little more sensible, dealing with the multi-line
  # fields in RIS
  require IO::File;
  my $ris = new IO::File;
  $ris->open("< $filename");
  my $e;
  my @ris_entries;
  my $last_tag;
  while(<$ris>) {
    if (m/\A([A-Z][A-Z0-9])\s\s\-\s*(.+)?\n\z/xms) {
      $last_tag = $1;
      switch ($1) {
        case 'TY'                { $e = {'TY' => $2};  }
        case 'KW'                { push @{$e->{KW}}, $2 } # amalgamate keywords
        case 'SP'                { $e->{SPEP}{SP} = $2 } # amalgamate page range
        case 'EP'                { $e->{SPEP}{EP} = $2 } # amalgamate page range
        case 'A1'                { push @{$e->{A1}}, $2 } # amalgamate names
        case 'A2'                { push @{$e->{A2}}, $2 } # amalgamate names
        case 'A3'                { push @{$e->{A3}}, $2 } # amalgamate names
        case 'AU'                { push @{$e->{AU}}, $2 } # amalgamate names
        case 'ED'                { push @{$e->{ED}}, $2 } # amalgamate names
        case 'ER'                { $e->{KW} = join(',', @{$e->{KW}});
                                   push @ris_entries, $e }
        else                     { $e->{$1} = $2 }
      }
    }
    elsif (m/\A(.+)\n\z/xms) { # Deal with stupid line continuations
      $e->{$last_tag} .= " $1";
    }
  }
  $ris->close;
  undef $ris;

  if ($section->is_allkeys) {
    $logger->debug("All citekeys will be used for section '$secnum'");
    # Loop over all entries, creating objects
    foreach my $entry (@ris_entries) {
      $logger->debug('Parsing RIS entry object ' . $entry->{ID});
      # We have to pass the datasource cased key to
      # create_entry() as this sub needs to know the original case of the
      # citation key so we can do case-insensitive key/entry comparisons
      # later but we need to put the original citation case when we write
      # the .bbl. If we lowercase before this, we lose this information.
      # Of course, with allkeys, "citation case" means "datasource entry case"

      # If an entry has no key, ignore it and warn
      unless ($entry->{ID}) {
        $logger->warn("RIS entry has no ID key in file '$filename', skipping ...");
        $biber->{warnings}++;
        next;
      }
      create_entry($biber, $entry->{ID}, $entry);
    }

    # if allkeys, push all bibdata keys into citekeys (if they are not already there)
    $section->add_citekeys($section->bibentries->sorted_keys);
    $logger->debug("Added all citekeys to section '$secnum': " . join(', ', $section->get_citekeys));
  }
  else {
    # loop over all keys we're looking for and create objects
    $logger->debug('Wanted keys: ' . join(', ', @$keys));
    foreach my $wanted_key (@$keys) {
      $logger->debug("Looking for key '$wanted_key' in RIS file '$filename'");
      # Cache index keys are lower-cased. This next line effectively implements
      # case insensitive citekeys
      # This will also get the first match it finds
      if (my @entries = grep { lc($wanted_key) eq lc($_->{ID}) } @ris_entries) {
        if ($#entries > 0) {
          $logger->warn("Found more than one entry for key '$wanted_key' in '$filename' - using the first one!");
          $biber->{warnings}++;
        }
        my $entry = $entries[0];

        $logger->debug("Found key '$wanted_key' in RIS file '$filename'");
        $logger->debug('Parsing RIS entry object ' . $entry->{ID});
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

  # Set entrytype taking note of any aliases for this datasource driver
  if (my $ealias = $dcfxml->{'entry-types'}{'entry-type'}{$entry->{TY}}) {
    $bibentry->set_field('entrytype', $ealias->{aliasof}{content});
    if (my $alsoset = $ealias->{alsoset}) {
      unless ($bibentry->field_exists($alsoset->{target})) {
        $bibentry->set_field($alsoset->{target}, $alsoset->{value});
      }
    }
  }
  else {
    $bibentry->set_field('entrytype', $entry->{TY});
  }

  # We put all the fields we find modulo field aliases into the object.
  # Validation happens later and is not datasource dependent
  foreach my $f (keys %$entry) {

    if (my $fm = $dcfxml->{fields}{field}{$f}) {
      my $to = $f; # By default, field to set internally is the same as data source
      # Redirect any alias
      if (my $alias = $fm->{aliasof}) {
        $logger->debug("Found alias '$alias' of field '$f' in entry '$dskey'");
        $fm = $dcfxml->{fields}{field}{$alias};
        $to = $alias; # Field to set internally is the alias
      }
      &{$handlers{$fm->{handler}}}($biber, $bibentry, $entry, $f, $to, $dskey);
    }
    # Default if no explicit way to set the field
    else {
      $bibentry->set_datafield($f, $entry->{$f});
    }
  }

  $bibentry->set_field('datatype', 'ris');
  $bibentries->add_entry($lc_key, $bibentry);

  return;
}

# Verbatim fields
sub _verbatim {
  my ($biber, $bibentry, $entry, $f, $to, $dskey) = @_;
  $bibentry->set_datafield($to, $entry->{$f});
  return;
}

# Range fields
sub _range {
  my ($biber, $bibentry, $entry, $f, $to, $dskey) = @_;
  $bibentry->set_datafield($to, _parse_range_list($entry->{$f}));
  return;
}

# Date fields
sub _date {
  my ($biber, $bibentry, $entry, $f, $to, $dskey) = @_;
  my $date = $entry->{$f};
  if ($date =~ m|\A([0-9]{4})/([0-9]{2})/([0-9]{2}/([^\n]+))\z|xms) {
    $bibentry->set_datafield('year', $1);
    $bibentry->set_datafield('month', $2);
    $bibentry->set_datafield('day', $3);
  }
  elsif ($date =~ m|\A([0-9])\z|xms) {
    $bibentry->set_datafield('year', $1);
  }
  else {
    $logger->warn("Invalid RIS date format: '$date' - ignoring");
  }
  return;
}

# Name fields
sub _name {
  my ($biber, $bibentry, $entry, $f, $to, $dskey) = @_;
  my $names = $entry->{$f};
  my $names_obj = new Biber::Entry::Names;
  foreach my $name (@$names) {
    $logger->debug('Parsing RIS name');
    if ($name =~ m|\A([^,]+)\s*,?\s*([^,]+)?\s*,?\s*([^,]+)?\z|xms) {
      my $lastname = $1;
      my $firstname = $2;
      my $suffix = $3;
      $logger->debug("Found name component 'lastname': $lastname") if $lastname;
      $logger->debug("Found name component 'firstname': $firstname") if $firstname;
      $logger->debug("Found name component 'suffix': $suffix") if $suffix;

      my @fni = _gen_initials([split(/\s/, $firstname)]) if $firstname;
      my @lni = _gen_initials([split(/\s/, $lastname)]) if $lastname;
      my @si = _gen_initials([split(/\s/, $suffix)]) if $suffix;

      my $namestring = '';

      # lastname
      $namestring .= "$lastname, ";

      # suffix
      $namestring .= "$suffix, " if $suffix;

      # firstname
      $namestring .= $firstname if $firstname;

      # Remove any trailing comma and space if, e.g. missing firstname
      # Replace any nbspes
      $namestring =~ s/,\s+\z//xms;
      $namestring =~ s/~/ /gxms;

      # Construct $nameinitstring
      my $nameinitstr = '';
      $nameinitstr .= $lastname if $lastname;
      $nameinitstr .= '_' . $si[1] if $suffix;
      $nameinitstr .= '_' . $fni[1] if $firstname;
      $nameinitstr =~ s/\s+/_/g;
      $nameinitstr =~ s/~/_/g;

      my $name_obj = Biber::Entry::Name->new(
        firstname       => $firstname || undef,
        firstname_i     => $firstname ? $fni[0] : undef,
        firstname_it    => $firstname ? $fni[1] : undef,
        lastname        => $lastname,
        lastname_i      => $lni[0],
        lastname_it     => $lni[1],
        suffix          => $suffix || undef,
        suffix_i        => $suffix ? $si[0] : undef,
        suffix_it       => $suffix ? $si[1] : undef,
        namestring      => $namestring,
        nameinitstring  => $nameinitstr
      );
      $names_obj->add_element($name_obj);
      $bibentry->set_datafield($to, $names_obj);

      # Special case
      if ($f eq 'A3') {
        $bibentry->set_datafield('editortype', 'series');
      }
    }
    else {
      $logger->warn("Invalid RIS name format: '$name' - ignoring");
    }
  }
  return;

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
  return (join('.' . Biber::Config->getoption('joins')->{inits}, @strings) . '.',
          join('', @strings));
}


# parses a range and returns a ref to an array of start and end values
sub _parse_range_list {
  my $range = shift;
  my $start = $range->{SP} || '';
  my $end = $range->{EP} || '';
  return [[$start, $end]];
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
