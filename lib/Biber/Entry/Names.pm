package Biber::Entry::Names;

use Data::Dump;

=encoding utf-8

=head1 NAME

Biber::Entry::Names

=head2 new

    Initialize a Biber::Entry::Names object

=cut

sub new {
  my $class = shift;
  return bless [], $class;
}


=head2 names

    Return ref to array of all Biber::Entry::Names objects
    in object

=cut

sub names {
  my $self = shift;
  return $self;
}

=head2 add_name

    Add a Biber::Entry::Name object to the Biber::Entry::Names
    object

=cut

sub add_name {
  my $self = shift;
  my $name_obj = shift;
  push @$self, $name_obj;
  return;
}

=head2 count_names

    Returns the number of Biber::Entry::Name objects in the object

=cut

sub count_names {
  my $self = shift;
  return scalar @$self;
}

=head2 nth_name

    Returns the nth Biber::Entry::Name object in the object

=cut

sub nth_name {
  my $self = shift;
  my $n = shift;
  return @$self[$n-1];
}

=head2 del_last_name

    Deletes the last Biber::Entry::Name object in the object

=cut

sub del_last_name {
  my $self = shift;
  $self = [ pop(@$self) ];
  return;
}


=head2 last_name

    Returns the last Biber::Entry::Name object in the object

=cut

sub last_name {
  my $self = shift;
  return @$self[-1];
}

=head2 dump

    Dump a Biber::Entry::Name object for debuggig purposes

=cut

sub dump {
  my $self = shift;
  dd($self);
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

# vim: set tabstop=4 shiftwidth=4 expandtab:


