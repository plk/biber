package Biber::Entry::Name;

=encoding utf-8

=head1 NAME

Biber::Entry::Name

=head2 new

    Initialize a Biber::Entry::Name object

=cut

sub new {
  my $class = shift;
  return bless {}, $class;
}


=head2 set_namepart

    Set a name part for a Biber::Entry::Name object

=cut

sub set_namepart {
  my $self = shift;
  my ($key, $val) = @_;
  $self->{$key} = $val;
  return;
}

=head2 get_namepart

    Get a name part for a Biber::Entry::Name object

=cut

sub get_namepart {
  my $self = shift;
  my $key = shift;
  return $self->{$key};
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

# vim: set tabstop=4 shiftwidth=4 expandtab:


