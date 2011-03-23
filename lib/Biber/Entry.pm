package Biber::Entry;
#use feature 'unicode_strings';

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
  # Need to add entrytype and datatype
  $new->{derivedfields}{entrytype} = $self->{derivedfields}{entrytype};
  $new->{derivedfields}{datatype} = $self->{derivedfields}{datatype};
  # put in key if specified
  if ($newkey) {
    $new->{derivedfields}{dskey} = $newkey;
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

=head2 set_datafield

    Set a field which is in the bib data file
    Only set to null if the field is a nullable one
    otherwise if value is null, remove the field

=cut

sub set_datafield {
  my $self = shift;
  my ($key, $val) = @_;
  my $struc = Biber::Config->get_structure;
  # Only set fields which are either not null or are ok to be null
  if ( $struc->is_field_type('nullok', $key) or is_notnull($val)) {
    $self->{datafields}{$key} = $val;
  }
  elsif (is_null($val)) {
    delete($self->{datafields}{$key});
  }
  return;
}


=head2 set_field

    Set a derived field for a Biber::Entry object, that is, a field which was not
    an actual bibliography field

=cut

sub set_field {
  my $self = shift;
  my ($key, $val) = @_;
  # All derived fields can be null
  $self->{derivedfields}{$key} = $val;
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

=head2 has_keyword

    Check if a Biber::Entry object has a particular keyword in
    in the KEYWORDS field.

=cut

sub has_keyword {
  my $self = shift;
  my $keyword = shift;
  if (my $keywords = $self->{datafields}{keywords}) {
    return (first {lc($_) eq lc($keyword)} split(/\s*,\s*/, $keywords)) ? 1 : 0;
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
  push @{$self->{derivedfields}{'warnings'}}, $warning;
  return;
}

=head2 set_inherit_from

    Inherit fields from parent entry

    $entry->inherit_from($parententry);

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

=head2 inherit_from

    Inherit fields from parent entry (as indicated by the crossref field)

    $entry->inherit_from($parententry);

    Takes a second Biber::Entry object as argument
    Uses the crossref inheritance specifications from the .bcf

=cut

sub inherit_from {
  my $self = shift;
  my $parent = shift;
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
          my $field_override_target = $field->{override_target}
            if $field->{override_target};
          # Skip this field if requested
          if ($field->{skip}) {
            $processed{$field->{source}} = 1;
          }
          # Set the field if it doesn't exist or override is requested
          elsif (not $self->field_exists($field->{target}) or
                 $field_override_target eq 'true') {
            $logger->debug("    Entry '" .
                           $self->get_field('dskey') .
                           "' is inheriting field '" .
                           $field->{source}.
                           "' as '" .
                           $field->{target} .
                           "' from entry '" .
                           $parent->get_field('dskey') .
                           "'");
            $self->set_datafield($field->{target}, $parent->get_field($field->{source}));
          }
        }
      }
    }
  }

  # Now process the rest of the (original data only) fields, if necessary
  if ($inherit_all eq 'true') {
    foreach my $field ($parent->datafields) {
      next if $processed{$field}; # Skip if we already dealt with this field above
      # Set the field if it doesn't exist or override is requested
      if (not $self->field_exists($field) or $override_target eq 'true') {
            $logger->debug("    Entry '" .
                           $self->get_field('dskey') .
                           "' is inheriting field '$field' from entry '" .
                           $parent->get_field('dskey') .
                           "'");
        $self->set_datafield($field, $parent->get_field($field));
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


=head1 AUTHORS

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

1;

# vim: set tabstop=2 shiftwidth=2 expandtab:
