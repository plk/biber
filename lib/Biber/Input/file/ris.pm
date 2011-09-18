package Biber::Input::file::ris;
use feature ':5.10';
#use 5.014001;
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
use XML::LibXML::Simple;
use Readonly;
use Data::Dump qw(dump);

my $logger = Log::Log4perl::get_logger('main');
my $orig_key_order = {};

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

# Read driver config file
my $dcfxml = driver_config('ris');

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

  # If it's a remote data file, fetch it first
  if ($filename =~ m/\A(?:https?|ftp):\/\//xms) {
    $logger->info("Data source '$filename' is a remote file - fetching ...");
    require LWP::Simple;
    require File::Temp;
    $tf = File::Temp->new(TEMPLATE => 'biber_remote_data_source_XXXXX',
                          DIR => $biber->biber_tempdir,
                          SUFFIX => '.ris');
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

  # Log that we found a data file
  $logger->info("Found ris data file '$filename'");

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
      given ($1) {
        when ('TY')              { $e = {'TY' => $2} }
        when ('KW')              { push @{$e->{KW}}, $2 } # amalgamate keywords
        when ('SP')              { $e->{SPEP}{SP} = $2 }  # amalgamate page range
        when ('EP')              { $e->{SPEP}{EP} = $2 }  # amalgamate page range
        when ('A1')              { push @{$e->{A1}}, $2 } # amalgamate names
        when ('A2')              { push @{$e->{A2}}, $2 } # amalgamate names
        when ('A3')              { push @{$e->{A3}}, $2 } # amalgamate names
        when ('AU')              { push @{$e->{AU}}, $2 } # amalgamate names
        when ('ED')              { push @{$e->{ED}}, $2 } # amalgamate names
        when ('ER')              { $e->{KW} = join(',', @{$e->{KW}});
                                   push @ris_entries, $e }
        default                  { $e->{$1} = $2 }
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

      # If an entry has no key, ignore it and warn
      unless ($entry->{ID}) {
        $logger->warn("RIS entry has no ID key in file '$filename', skipping ...");
        $biber->{warnings}++;
        next;
      }

      my $ek = $entry->{ID};
      # If we've already seen a case variant, warn
      if (my $okey = $biber->has_badcasekey($ek)) {
        $logger->warn("Possible typo (case mismatch): '$ek' and '$okey' in file '$filename', skipping '$ek' ...");
      }

      # If we've already seen this key, ignore it and warn
      if ($biber->has_everykey($ek)) {
        $logger->warn("Duplicate entry key: '$ek' in file '$filename', skipping ...");
        next;
      }
      else {
        $biber->add_everykey($ek);
      }

      # We do this as otherwise we have no way of determining the origing .bib entry order
      # We need this in order to do sorting=none + allkeys because in this case, there is no
      # "citeorder" because nothing is explicitly cited and so "citeorder" means .bib order
      push @{$orig_key_order->{$filename}}, $ek;

      create_entry($biber, $ek, $entry);
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
      $logger->debug("Looking for key '$wanted_key' in RIS file '$filename'");
      if (my @entries = grep { $wanted_key eq $_->{ID} } @ris_entries) {
        if ($#entries > 0) {
          $logger->warn("Found more than one entry for key '$wanted_key' in '$filename': " .
                       join(',', map {$_->{ID}} @entries) . ' - skipping duplicates ...');
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
  my ($biber, $key, $entry) = @_;
  my $secnum = $biber->get_current_section;
  my $section = $biber->sections->get_section($secnum);
  my $struc = Biber::Config->get_structure;
  my $bibentries = $section->bibentries;
  my $bibentry = new Biber::Entry;

  $bibentry->set_field('citekey', $key);

  # Get a reference to the map option, if it exists
  my $user_map;
  if (defined(Biber::Config->getoption('map'))) {
    if (defined(Biber::Config->getoption('map')->{ris})) {
      $user_map = Biber::Config->getoption('map')->{ris};
    }
  }


  # We put all the fields we find modulo field aliases into the object.
  # Validation happens later and is not datasource dependent
FLOOP:  foreach my $f (keys %$entry) {

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
          if (first {lc($_) eq lc($entry->{TY})} @{$map->{bmap_pertype}}) {
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

      $from = $dcfxml->{fields}{field}{$f}; # handler information still comes from .dcf

      if (ref($to_map) eq 'HASH') { # complex field map
        $from = $dcfxml->{fields}{field}{lc($to_map->{bmap_target})};
        $to = lc($to_map->{bmap_target});

        # Deal with alsoset one->many maps
        while (my ($from_as, $to_as) = each %{$to_map->{alsoset}}) {
          if ($bibentry->field_exists(lc($from_as))) {
            if ($user_map->{bmap_overwrite}) {
              $biber->biber_warn($bibentry, "Overwriting existing field '$from_as' during aliasing of field '$from' to '$to' in entry '$key'");
            }
            else {
              $biber->biber_warn($bibentry, "Not overwriting existing field '$from_as' during aliasing of field '$from' to '$to' in entry '$key'");
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
      &{$handlers{$from->{handler}}}($biber, $bibentry, $entry, $f, $to, $key);
    }
    # FIELD MAPPING (ALIASES) DEFINED BY DRIVER IN DRIVER CONFIG FILE
    elsif ($from = $dcfxml->{fields}{field}{$f}) {
      $to = $f; # By default, field to set internally is the same as data source
      # Redirect any alias
      if (my $aliases = $from->{alias}) { # complex aliases with alsoset clauses
        foreach my $alias (@$aliases) {
          if (my $t = $alias->{aliasfortype}) { # type-specific alias
            if (lc($t) eq lc($entry->{TY})) {
              my $a = $alias->{aliasof};
              $logger->debug("Found alias '$a' of field '$f' in entry '$key'");
              $from = $dcfxml->{fields}{field}{$a};
              $to = $a; # Field to set internally is the alias
              last;
            }
          }
          else {
            my $a = $alias->{aliasof}; # global alias
            $logger->debug("Found alias '$a' of field '$f' in entry '$key'");
            $from = $dcfxml->{fields}{field}{$a};
            $to = $a; # Field to set internally is the alias
          }

          # Deal with additional fields to split information into (one->many map)
          foreach my $alsoset (@{$alias->{alsoset}}) {
            my $val = $alsoset->{value} // $f; # defaults to original field name if no value
            $bibentry->set_datafield($alsoset->{target}, $val);
          }

        }
      }
      elsif (my $alias = $from->{aliasof}) { # simple alias
        $logger->debug("Found alias '$alias' of field '$f' in entry '$key'");
        $from = $dcfxml->{fields}{field}{$alias};
        $to = $alias; # Field to set internally is the alias
      }
      &{$handlers{$from->{handler}}}($biber, $bibentry, $entry, $f, $to, $key);
    }
    # Default if no explicit way to set the field
    else {
      $bibentry->set_datafield($f, $entry->{$f});
    }
  }

  # Set entrytype taking note of any user aliases or aliases for this datasource driver
  # This is here so that any field alsosets take precedence over fields in the data source

  # User aliases take precedence
  if (my $eta = firstval {lc($_) eq lc($entry->{TY})} keys %{$user_map->{entrytype}}) {
    my $from = lc($entry->{TY});
    my $to = $user_map->{entrytype}{$eta};
    if (ref($to) eq 'HASH') {   # complex entrytype map
      $bibentry->set_field('entrytype', lc($to->{bmap_target}));
      while (my ($from_as, $to_as) = each %{$to->{alsoset}}) { # any extra fields to set?
        if ($bibentry->field_exists(lc($from_as))) {
          if ($user_map->{bmap_overwrite}) {
            $biber->biber_warn($bibentry, "Overwriting existing field '$from_as' during aliasing of entrytype '" . $entry->{TY} . "' to '" . lc($to->{bmap_target}) . "' in entry '$key'");
          }
          else {
            $biber->biber_warn($bibentry, "Not overwriting existing field '$from_as' during aliasing of entrytype '" . $entry->{TY} . "' to '" . lc($to->{bmap_target}) . "' in entry '$key'");
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
  elsif (my $ealias = $dcfxml->{entrytypes}{entrytype}{$entry->{TY}}) {
    $bibentry->set_field('entrytype', $ealias->{aliasof}{content});
    foreach my $alsoset (@{$ealias->{alsoset}}) {
      # drivers never overwrite existing fields
      if ($bibentry->field_exists(lc($alsoset->{target}))) {
        $biber->biber_warn($bibentry, "Not overwriting existing field '" . $alsoset->{target} . "' during aliasing of entrytype '" . $entry->{TY} . "' to '" . lc($ealias->{aliasof}{content}) . "' in entry '$key'");
        next;
      }
      $bibentry->set_datafield($alsoset->{target}, $alsoset->{value});
    }
  }
  # No alias
  else {
    $bibentry->set_field('entrytype', $entry->{TY});
  }

  $bibentry->set_field('datatype', 'ris');
  $bibentries->add_entry($key, $bibentry);

  return;
}

# Verbatim fields
sub _verbatim {
  my ($biber, $bibentry, $entry, $f, $to, $key) = @_;
  $bibentry->set_datafield($to, $entry->{$f});
  return;
}

# Range fields
sub _range {
  my ($biber, $bibentry, $entry, $f, $to, $key) = @_;
  $bibentry->set_datafield($to, _parse_range_list($entry->{$f}));
  return;
}

# Date fields
sub _date {
  my ($biber, $bibentry, $entry, $f, $to, $key) = @_;
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
  my ($biber, $bibentry, $entry, $f, $to, $key) = @_;
  my $names = $entry->{$f};
  my $names_obj = new Biber::Entry::Names;
  foreach my $name (@$names) {
    $logger->debug('Parsing RIS name');
    if ($name =~ m|\A([^,]+)\s*,?\s*([^,]+)?\s*,?\s*([^,]+)?\z|xms) {
      my $lastname = _join_name_parts(split(/\s+/, $1)) if $1;
      my $firstname = _join_name_parts(split(/\s+/, $2)) if $2;
      my $suffix = _join_name_parts(split(/\s+/, $3)) if $3;
      $logger->debug("Found name component 'lastname': $lastname") if $lastname;
      $logger->debug("Found name component 'firstname': $firstname") if $firstname;
      $logger->debug("Found name component 'suffix': $suffix") if $suffix;

      my @lni = _gen_initials(split(/\s/, $1)) if $lastname;
      my @fni = _gen_initials(split(/\s/, $2)) if $firstname;
      my @si = _gen_initials(split(/\s/, $3)) if $suffix;

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
      $nameinitstr .= '_' . join('', @si) if $suffix;
      $nameinitstr .= '_' . join('', @fni) if $firstname;
      $nameinitstr =~ s/\s+/_/g;
      $nameinitstr =~ s/~/_/g;

      my $name_obj = Biber::Entry::Name->new(
        firstname       => $firstname || undef,
        firstname_i     => $firstname ? \@fni : undef,
        lastname        => $lastname,
        lastname_i      => \@lni,
        suffix          => $suffix || undef,
        suffix_i        => $suffix ? \@si : undef,
        namestring      => $namestring,
        nameinitstring  => $nameinitstr
      );
      $names_obj->add_name($name_obj);
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

# Joins name parts using BibTeX tie algorithm. Ties are added:
#
# 1. After the first part if it is less than three characters long
# 2. Before the last part
sub _join_name_parts {
  my @parts = @_;
  # special case - 1 part
  if ($#parts == 0) {
    return $parts[0];
  }
  # special case - 2 parts
  if ($#parts == 1) {
    return $parts[0] . '~' . $parts[1];
  }
  my $namestring = $parts[0];
  $namestring .= length($parts[0]) < 3 ? '~' : ' ';
  $namestring .= join(' ', @parts[1 .. ($#parts - 1)]);
  $namestring .= '~' . $parts[$#parts];
  return $namestring;
}

# Passed an array of strings, returns an array of initials for the strings
sub _gen_initials {
  my @strings = @_;
  my @strings_out;
  foreach my $str (@strings) {
    # Deal with hyphenated name parts and normalise to a '-' character for easy
    # replacement with macro later
    if ($str =~ m/\p{Dash}/) {
      push @strings_out, join('-', _gen_initials(split(/\p{Dash}/, $str)));
    }
    elsif ($str =~ m/\s/) { # name parts with spaces
      push @strings_out, _gen_initials(split(/\s+/, $str));
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
