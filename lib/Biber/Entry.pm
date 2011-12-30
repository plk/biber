package Biber::Entry;
use 5.014000;
use strict;
use warnings;

use List::Util qw( first );
use Biber::Utils;
use Biber::Constants;
use Data::Dump qw( pp );
use Log::Log4perl qw( :no_extra_logdie_message );

my $logger = Log::Log4perl::get_logger('main');

=encoding utf-8

=head1 NAME

Biber::Entry

=head2 new

    Initialize a Biber::Entry object

=cut

sub new {
  my $class = shift;
  my $obj = shift;
  my $self;
  if (defined($obj) and ref($obj) eq 'HASH') {
    $self = bless $obj, $class;
  }
  else {
    $self = bless {}, $class;
  }
  return $self;
}


=head2 TO_JSON

   Serialiser for JSON::XS::encode

=cut

sub TO_JSON {
  my $self = shift;
  my $json;
  while (my ($k, $v) = each(%{$self->{datafields}})) {
    $json->{$k} = $v;
  }
  while (my ($k, $v) = each(%{$self->{derivedfields}})) {
    $json->{$k} = $v;
  }
  return $json;
}

=head2 clone

    Clone a Biber::Entry object and return a copy
    Accepts optionally a key for the copy

=cut

sub clone {
  my $self = shift;
  my $newkey = shift;
  my $new = new Biber::Entry;
  while (my ($k, $v) = each(%{$self->{datafields}})) {
    $new->{datafields}{$k} = $v;
  }
  while (my ($k, $v) = each(%{$self->{origfields}})) {
    $new->{origfields}{$k} = $v;
  }
  # Need to add entrytype and datatype
  $new->{derivedfields}{entrytype} = $self->{derivedfields}{entrytype};
  $new->{derivedfields}{datatype} = $self->{derivedfields}{datatype};
  # put in key if specified
  if ($newkey) {
    $new->{derivedfields}{citekey} = $newkey;
  }
  return $new;
}

=head2 notnull

    Test for an empty object

=cut

sub notnull {
  my $self = shift;
  my @arr = keys %$self;
  return $#arr > -1 ? 1 : 0;
}

=head2 set_orig_field

    Set a field which came from the datasource which is then split/transformed
    into other fields. Here we save the original in case we need to look at it again
    but it is not treated as a real field any more. Such fields are of only historical
    interest in the processing in case we lose information during processing but need
    to refer back.

=cut

sub set_orig_field {
  my $self = shift;
  my ($key, $val) = @_;
  $self->{origfields}{$key} = $val;
  return;
}

=head2 get_orig_field

    Get an original field which has been subsequently split/transformed.

=cut

sub get_orig_field {
  my $self = shift;
  my $key = shift;
  return $self->{origfields}{$key} if exists($self->{origfields}{$key});
  return undef;
}


=head2 set_field

  Set/append to a derived field for a Biber::Entry object, that is, a field
  which was not an actual bibliography field

=cut

sub set_field {
  my $self = shift;
  my ($key, $val, $append) = @_;
  # All derived fields can be null
  # Only add append with seperator if append mode and there is something to append to
  if ($append and defined($self->{derivedfields}{$key})) {
    $self->{derivedfields}{$key} .= "$append$val";
  }
  # otherwise just set as normal
  else {
    $self->{derivedfields}{$key} = $val;
  }
  return;
}

=head2 get_field

    Get a field for a Biber::Entry object

=cut

sub get_field {
  my $self = shift;
  my $key = shift;
  return $self->{datafields}{$key} if exists($self->{datafields}{$key});
  return $self->{derivedfields}{$key} if exists($self->{derivedfields}{$key});
  return undef;
}

=head2 set_datafield

    Set/append to a field which is in the bib data file
    Only set to null if the field is a nullable one
    otherwise if value is null, remove the field

=cut

sub set_datafield {
  my $self = shift;
  my ($key, $val, $append) = @_;
  my $struc = Biber::Config->get_structure;
  # Only set fields which are either not null or are ok to be null
  if ( $struc->is_field_type('nullok', $key) or is_notnull($val)) {
    # Only add append with seperator if append mode and there is something to append to
    if ($append and defined($self->{datafields}{$key})) {
      $self->{datafields}{$key} .= "$append$val";
    }
    # otherwise just set as normal
    else {
      $self->{datafields}{$key} = $val;
    }
  }
  elsif (is_null($val)) {
    delete($self->{datafields}{$key});
  }
  return;
}

=head2 get_datafield

    Get a field that was in the original data file

=cut

sub get_datafield {
  my $self = shift;
  my $key = shift;
  return $self->{datafields}{$key};
}


=head2 del_field

    Delete a field in a Biber::Entry object

=cut

sub del_field {
  my $self = shift;
  my $key = shift;
  delete $self->{datafields}{$key};
  delete $self->{derivedfields}{$key};
  return;
}

=head2 del_datafield

    Delete an original data source data field in a Biber::Entry object

=cut

sub del_datafield {
  my $self = shift;
  my $key = shift;
  delete $self->{datafields}{$key};
  return;
}


=head2 field_exists

    Check whether a field exists (even if null)

=cut

sub field_exists {
  my $self = shift;
  my $key = shift;
  return (exists($self->{datafields}{$key}) or
          exists($self->{derivedfields}{$key})) ? 1 : 0;
}

=head2 datafields

    Returns a sorted array of the fields which came from the data source

=cut

sub datafields {
  my $self = shift;
  use locale;
  return sort keys %{$self->{datafields}};
}

=head2 count_datafields

    Returns the number of datafields

=cut

sub count_datafields {
  my $self = shift;
  return keys %{$self->{datafields}};
}


=head2 fields

    Returns a sorted array of all field names, including ones
    added during processing which are not necessarily fields
    which came from the data file

=cut

sub fields {
  my $self = shift;
  use locale;
  my %keys = (%{$self->{derivedfields}}, %{$self->{datafields}});
  return sort keys %keys;
}

=head2 count_fields

    Returns the number of fields

=cut

sub count_fields {
  my $self = shift;
  my %keys = (%{$self->{derivedfields}}, %{$self->{datafields}});
  return keys %keys;
}


=head2 has_keyword

    Check if a Biber::Entry object has a particular keyword in
    in the KEYWORDS field.

=cut

sub has_keyword {
  my $self = shift;
  my $keyword = shift;
  if (my $keywords = $self->{datafields}{keywords}) {
    return (first {$_ eq $keyword} split(/\s*,\s*/, $keywords)) ? 1 : 0;
  }
  else {
    return 0;
  }
  return undef; # shouldn't get here
}



=head2 add_warning

    Append a warning to a Biber::Entry object

=cut

sub add_warning {
  my $self = shift;
  my $warning = shift;
  push @{$self->{derivedfields}{warnings}}, $warning;
  return;
}


=head2 set_inherit_from

    Inherit fields from parent entry

    $entry->set_inherit_from($parententry);

    Takes a second Biber::Entry object as argument
    Tailored for set inheritance which is a straight 1:1 inheritance,
    excluding certain fields for backwards compatibility

=cut

sub set_inherit_from {
  my $self = shift;
  my $parent = shift;

  # Data source fields
  foreach my $field ($parent->datafields) {
    next if $self->field_exists($field); # Don't overwrite existing fields
    $self->set_datafield($field, $parent->get_field($field));
  }
  # Datesplit is a special non datafield and needs to be inherited for any
  # validation checks which may occur later
  if (my $ds = $parent->get_field('datesplit')) {
    $self->set_field('datesplit', $ds);
  }
  return;
}

=head2 resolve_xdata

    Recursively resolve XDATA fields in an entry

    $entry->resolve_xdata($xdata_entry);

=cut

sub resolve_xdata {
  my ($self, $xdata) = @_;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $entry_key = $self->get_field('citekey');

  foreach my $xdatum (split /\s*,\s*/, $xdata) {
    unless (my $xdatum_entry = $section->bibentry($xdatum)) {
      biber_warn("Entry '$entry_key' references XDATA entry '$xdatum' which does not exist in section $secnum");
      next;
    }
    else {
      # Skip xdata inheritance if we've already done it
      # This will only ever be between two XDATA entrytypes since we
      # always start at a non-XDATA entrytype, which we'll not look at again
      # and recursion is always between XDATA entrytypes.
      next if Biber::Config->get_inheritance('xdata', $xdatum, $entry_key);

      # record the XDATA resolve between these entries to prevent loops
      Biber::Config->set_inheritance('xdata', $xdatum, $entry_key);

      # Detect XDATA loops
      unless (Biber::Config->is_inheritance_path('xdata', $entry_key, $xdatum)) {
        if (my $recurse_xdata = $xdatum_entry->get_field('xdata')) { # recurse
          $xdatum_entry->resolve_xdata($recurse_xdata);
        }
        foreach my $field ($xdatum_entry->datafields()) { # set fields
          $self->set_datafield($field, $xdatum_entry->get_field($field));

          # Record graphing information if required
          if (Biber::Config->getoption('graph')) {
            Biber::Config->set_graph('xdata', $xdatum_entry->get_field('citekey'), $entry_key, $field, $field);
          }

          $logger->debug("Setting field '$field' in entry '$entry_key' via XDATA");
        }
      }
      else {
        biber_error("Circular XDATA inheritance between '$xdatum'<->'$entry_key'");
      }
    }
  }
}

=head2 inherit_from

    Inherit fields from parent entry (as indicated by the crossref field)

    $entry->inherit_from($parententry);

    Takes a second Biber::Entry object as argument
    Uses the crossref inheritance specifications from the .bcf

=cut

sub inherit_from {
  my ($self, $parent) = @_;

  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);

  my $target_key = $self->get_field('citekey'); # target/child key
  my $source_key = $parent->get_field('citekey'); # source/parent key

  # record the inheritance between these entries to prevent loops and repeats.
  Biber::Config->set_inheritance('crossref', $source_key, $target_key);

  # Detect crossref loops
  unless (Biber::Config->is_inheritance_path('crossref', $target_key, $source_key)) {
    # cascading crossrefs
    if (my $ppkey = $parent->get_field('crossref')) {
      $parent->inherit_from($section->bibentry($ppkey));
    }
  }
  else {
    biber_error("Circular inheritance between '$source_key'<->'$target_key'");
  }

  my $type        = $self->get_field('entrytype');
  my $parenttype  = $parent->get_field('entrytype');
  my $inheritance = Biber::Config->getblxoption('inheritance');
  my %processed;
  # get defaults
  my $defaults = $inheritance->{defaults};
  # global defaults ...
  my $inherit_all = $defaults->{inherit_all};
  my $override_target = $defaults->{override_target};
  # override with type_pair specific defaults if they exist ...
  foreach my $type_pair (@{$defaults->{type_pair}}) {
    if (($type_pair->{source} eq '*' or $type_pair->{source} eq $parenttype) and
        ($type_pair->{target} eq '*' or $type_pair->{target} eq $type)) {
      $inherit_all = $type_pair->{inherit_all} if $type_pair->{inherit_all};
      $override_target = $type_pair->{override_target} if $type_pair->{override_target};
    }
  }

  # First process any fields that have special treatment
  foreach my $inherit (@{$inheritance->{inherit}}) {
    # Match for this combination of entry and crossref parent?
    foreach my $type_pair (@{$inherit->{type_pair}}) {
    if (($type_pair->{source} eq '*' or $type_pair->{source} eq $parenttype) and
        ($type_pair->{target} eq '*' or $type_pair->{target} eq $type)) {
        foreach my $field (@{$inherit->{field}}) {
          next unless $parent->field_exists($field->{source});
          $processed{$field->{source}} = 1;
          # localise defaults according to field, if specified
          my $field_override_target = $field->{override_target} // 'false';
          # Skip this field if requested
          if ($field->{skip}) {
            $processed{$field->{source}} = 1;
          }
          # Set the field if it doesn't exist or override is requested
          elsif (not $self->field_exists($field->{target}) or
                 $field_override_target eq 'true') {
            $logger->debug("Entry '$target_key' is inheriting field '" .
                           $field->{source}.
                           "' as '" .
                           $field->{target} .
                           "' from entry '$source_key'");
            $self->set_datafield($field->{target}, $parent->get_field($field->{source}));

            # Record graphing information if required
            if (Biber::Config->getoption('graph')) {
              Biber::Config->set_graph('crossref', $source_key, $target_key, $field->{source}, $field->{target});
            }
          }
        }
      }
    }
  }

  # Now process the rest of the (original data only) fields, if necessary
  if ($inherit_all eq 'true') {
    foreach my $field ($parent->datafields) {
      next if $processed{$field}; # Skip if we have already dealt with this field above
      # Set the field if it doesn't exist or override is requested
      if (not $self->field_exists($field) or $override_target eq 'true') {
            $logger->debug("Entry '$target_key' is inheriting field '$field' from entry '$source_key'");
            $self->set_datafield($field, $parent->get_field($field));

            # Record graphing information if required
            if (Biber::Config->getoption('graph')) {
              Biber::Config->set_graph('crossref', $source_key, $target_key, $field, $field);
            }
      }
    }
  }
  # Datesplit is a special non datafield and needs to be inherited for any
  # validation checks which may occur later
  if (my $ds = $parent->get_field('datesplit')) {
    $self->set_field('datesplit', $ds);
  }

  return;
}

=head2 dump

    Dump Biber::Entry object

=cut

sub dump {
  my $self = shift;
  return pp($self);
}

1;

__END__

=head1 AUTHORS

François Charette, C<< <firmicus at ankabut.net> >>
Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2012 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
