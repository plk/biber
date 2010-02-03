package Biber::Entry;

=encoding utf-8

=head1 NAME

Biber::Entry

=head2 new

    Initialize a Biber::Entry object

=cut

sub new {
  my $class = shift;
  my ($obj) = @_;
  my $self;
  if (defined($obj) and ref($obj) eq 'HASH') {
    $self = bless $obj, $class;
  }
  else {
    $self = bless {}, $class;
  }
  return $self;
}

=head2 set_field

    Set a field for a Biber::Entry object

=cut

sub set_field {
  my $self = shift;
  my ($key, $val) = @_;
  $self->{$key} = $val;
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

=head2 fields

    Returns a sorted array of the Biber::Entry object fields

=cut

sub fields {
  my $self = shift;
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

=head1 AUTHORS

François Charette, C<< <firmicus at gmx.net> >>
Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2010 François Charette and Philip Kime, all rights reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

=cut

1;

# vim: set tabstop=2 shiftwidth=2 expandtab:
