package Biber::Section::List;

use Biber::Utils;
use List::Util qw( first );

=encoding utf-8

=head1 NAME

Biber::Section::List

=head2 new

    Initialize a Biber::Section::List object

=cut

sub new {
  my ($class, %params) = @_;
  my $self = bless {%params}, $class;
  return $self;
}

=head2 set_label

    Sets the label of a section list

=cut

sub set_label {
  my $self = shift;
  my $label = shift;
  $self->{label} = lc($label);
  return;
}

=head2 get_label

    Gets the label of a section list

=cut

sub get_label {
  my $self = shift;
  return $self->{label};
}


=head2 set_sortspec

    Sets the sortspec of a list

=cut

sub set_sortspec {
  my $self = shift;
  my $sortspec = shift;
  $self->{sortspec} = $sortspec;
  return;
}

=head2 get_sortspec

    Gets the sortspec of a list

=cut

sub get_sortspec {
  my $self = shift;
  return $self->{sortspec};
}


=head2 add_filter

    Adds a filter to a list object

=cut

sub add_filter {
  my $self = shift;
  my ($type, $values) = @_;
  $self->{filters}{$type} = [ split(/\s*,\s*/,$values) ];
  return;
}

=head2 get_filter

    Gets a specific filter from a list object

=cut

sub get_filter {
  my $self = shift;
  my $type = shift;
  return $self->{filters}{$type};
}

=head2 get_filters

    Gets all filters for a list object

=cut

sub get_filters {
  my $self = shift;
  return $self->{filters};
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
