package Biber::Section;

=encoding utf-8

=head1 NAME

Biber::Section

=head2 new

    Initialize a Biber::Section object

=cut

sub new {
  my ($class, %params) = @_;
  my $self = bless {%params}, $class;
  return $self;
}

=head2 set_citekeys

    Sets the citekeys in a Biber::Section object

=cut

sub set_citekeys {
  my $self = shift;
  my $keys = shift;
  $self->{citekeys} = $keys;
  return;
}

=head2 set_orig_order_citekeys

    Sets the original order of citekeys in a Biber::Section object

=cut

sub set_orig_order_citekeys {
  my $self = shift;
  my $keys = shift;
  $self->{orig_order_citekeys} = $keys;
  return;
}


=head2 get_citekeys

    Gets the citekeys of a Biber::Section object
    Returns a normal array

=cut

sub get_citekeys {
  my $self = shift;
  return @{$self->{citekeys}};
}

=head2 get_orig_order_citekeys

    Gets the citekeys of a Biber::Section object in their original order
    This is just to ensure we have a method that will return this, just in
    case we mess about with the order at some point. This is needed by
    citeorder sorting.

=cut

sub get_orig_order_citekeys {
  my $self = shift;
  return $self->{orig_order_citekeys};
}

=head2 has_citekey

    Returns true when $key is in the Biber::Section object

=cut

sub has_citekey {
  my $self = shift;
  my $key = shift;
  return defined ( first { lc($_) eq lc($key) } @{$self->get_citekeys} ) ? 1 : 0;
}


=head2 del_citekey

    Deletes a citekey from a Biber::Section object

=cut

sub del_citekey {
  my $self = shift;
  my $key = shift;
  return unless $self->has_citekey($key);
  $self->{citekeys}            = [ map {$_ ne $key} @{$self->{citekeys}} ];
  $self->{orig_order_citekeys} = [ map {$_ ne $key} @{$self->{orig_order_citekeys}} ];
  return;
}

=head2 add_citekey

    Adds citekey $key to the Biber::Section object

=cut

sub add_citekey {
  my $self = shift;
  my $key = shift;
  return if $self->has_citekey($key);
  my @citekeys = $self->citekeys;
  my @orig_order_citekeys = $self->orig_order_citekeys;
  $self->{citekeys} = [@citekeys, $key];
  $self->{orig_order_citekeys} = [@orig_order_citekeys, $key];
  return;
}


=head2 number

    Gets the section number of a Biber::Section object

=cut

sub number {
  my $self = shift;
  return $self->{number};
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
