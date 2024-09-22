package Biber::Sections;
use v5.24;
use strict;
use warnings;

=encoding utf-8

=head1 NAME

Biber::Sections - Biber::Sections objects

=head2 new

    Initialize a Biber::Sections object

=cut

sub new {
  my ($class) = @_;
  my $self = bless {}, $class;
  return $self;
}

=head2 get_num_sections

    Gets the number of Biber::Section objects

=cut

sub get_num_sections {
  my $self = shift;
  my @keys = keys $self->%*;
  return $#keys + 1;
}


=head2 get_section

    Gets a Biber::Section by number from the Biber::Sections object

=cut

sub get_section {
  my $self = shift;
  my $number = shift;
  return $self->{$number};
}

=head2 get_sections

    Gets an sorted array ref of all Biber::Section objects

=cut

sub get_sections {
  my $self = shift;
  return [ sort {$a->number <=> $b->number} values $self->%* ];
}


=head2 add_section

    Adds a Biber::Section to the Biber::Sections object

=cut

sub add_section {
  my $self = shift;
  my $section = shift;
  my $number = $section->number;
  $self->{$number} = $section;
  return;
}

=head2 delete_section

    Deletes a section
    Mainly used in test scripts

=cut

sub delete_section {
  my $self = shift;
  my $section = shift;
  my $number = $section->number;
  delete $self->{$number};
  return;
}

1;

__END__

=head1 AUTHORS

Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our Github tracker at
L<https://github.com/plk/biber/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2012 François Charette and Philip Kime, all rights reserved.
Copyright 2012-2024 Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
