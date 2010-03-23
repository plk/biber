package Biber::Sections;

=encoding utf-8

=head1 NAME

Biber::Sections

=head2 new

    Initialize a Biber::Sections object

=cut

sub new {
  my ($class) = @_;
  my $self = bless {}, $class;
  return $self;
}

=head2 get_section

    Gets a Biber::Section by number from the Biber::Sections object

=cut

sub get_section {
  my $self = shift;
  my $number = shift;
  return $self->{$number};
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
