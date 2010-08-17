package Biber::Entry;
use List::Util qw( first );
use Biber::Utils;
use Biber::Constants;
use Data::Dump qw( pp );

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

=head2 notnull

    Test for an empty object

=cut

sub notnull {
  my $self = shift;
  my @arr = keys %$self;
  return $#arr > -1 ? 1 : 0;
}

=head2 set_field

    Set a field for a Biber::Entry object

=cut

sub set_field {
  my $self = shift;
  my ($key, $val) = @_;
  # Only set fields which are either not null or are ok to be null
  if ( first { $key eq $_ } @NULL_OK or is_notnull($val)) {
    $self->{$key} = $val;
  }
  return;
}

=head2 get_field

    Get a field for a Biber::Entry object

=cut

sub get_field {
  my $self = shift;
  my $key = shift;
  return $self->{$key};
}

=head2 del_field

    Delete a field in a Biber::Entry object

=cut

sub del_field {
  my $self = shift;
  my $key = shift;
  delete $self->{$key};
  return;
}

=head2 field_exists

    Check whether a field exists (even if null)

=cut

sub field_exists {
  my $self = shift;
  my $key = shift;
  return exists $self->{$key} ? 1 : 0;
}

=head2 fields

    Returns a sorted array of the Biber::Entry object fields

=cut

sub fields {
  my $self = shift;
  use locale;
  return sort keys %$self;
}

=head2 add_warning

    Append a warning to a Biber::Entry object

=cut

sub add_warning {
  my $self = shift;
  my $warning = shift;
  push @{$self->{'warnings'}}, $warning;
  return;
}

=head2 inherit_from

    Inherit fields from parent entry (as indicated by the crossref field)

    $entry->inherit_from($parententry);

    Takes a second Biber::Entry object as argument

=cut

sub inherit_from {
  my ($self, $parent) = @_;

  my $type = $self->get_field('entrytype');

  if ($type =~ /\Ain(proceedings|collection|book)\z/xms) {

    # inherit all that is undefined, except title etc
    foreach my $field ($parent->fields) {
      next if $field =~ /title/;
      if (not $self->get_field($field)) {
        $self->set_field($field, $parent->get_field($field));
      }
    }

    # inherit title etc as booktitle etc
    $self->set_field('booktitle', $parent->get_field('title'));
    if ($parent->get_field('titleaddon')) {
      $self->get_field('booktitleaddon', $parent->get_field('titleaddon'));
    }
    if ($parent->get_field('subtitle')) {
      $self->get_field('booksubtitle', $parent->get_field('subtitle'));
    }
  }
  elsif ($type eq 'inbook') {
    $self->get_field('bookauthor', $parent->get_field('author'));
  }
  else { # inherits all
    foreach my $field ($parent->fields) {
      if (not $self->get_field($field)) {
        $self->set_field($field, $parent->get_field($field));
      }
    }
  }
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

Copyright 2009-2010 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

1;

# vim: set tabstop=2 shiftwidth=2 expandtab:
