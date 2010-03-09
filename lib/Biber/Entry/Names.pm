package Biber::Entry::Names;

use Data::Dump;
use Biber::Config;

=encoding utf-8

=head1 NAME

Biber::Entry::Names

=head2 new

    Initialize a Biber::Entry::Names object

=cut

sub new {
  my $class = shift;
  return bless {}, $class;
}


=head2 notnull

    Test for an empty object

=cut

sub notnull {
  my $self = shift;
  my @arr = @{$self->{namelist}};
  return $#arr > -1 ? 1 : 0;
}

=head2 names

    Return ref to array of all Biber::Entry::Name objects
    in object

=cut

sub names {
  my $self = shift;
  return $self->{namelist};
}

=head2 reset_uniquelist

    Reset uniquelist to undef for a Biber::Entry::Name object

=cut

sub reset_uniquelist {
  my $self = shift;
  delete $self->{uniquelist};
  return;
}


=head2 set_uniquelist

    Add a uniquelist count to the Biber::Entry::Names object
    Sets global flag to say that some uniquelist value has changed

=cut

sub set_uniquelist {
  my $self = shift;
  my $uniquelist = shift;
  my $currval = $self->{uniquelist};
  # Set modified flag to positive if we changes something
  if (not defined($currval) or $currval != $uniquelist) {
    Biber::Config->set_unul_changed(1);
  }
  $self->{uniquelist} = $uniquelist;
  return;
}

=head2 get_uniquelist

    Get the uniquelist count from the Biber::Entry::Names
    object

=cut

sub get_uniquelist {
  my $self = shift;
  return $self->{uniquelist};
}

=head2 count_uniquelist

    Count the names in a string used to determine uniquelist.

=cut

sub count_uniquelist {
  my $self = shift;
  my $liststring = shift;
  $liststring =~ s/\|\z//xms;
  my @liststring_array = split(/\|/, $liststring);
  return $#liststring_array + 1;
}

=head2 add_element

    Add a Biber::Entry::Name object to the Biber::Entry::Names
    object

=cut

sub add_element {
  my $self = shift;
  my $name_obj = shift;
  push @{$self->{namelist}}, $name_obj;
  $name_obj->set_index($#{$self->{namelist}} + 1);
  return;
}

=head2 count_elements

    Returns the number of Biber::Entry::Name objects in the object

=cut

sub count_elements {
  my $self = shift;
  return scalar @{$self->{namelist}};
}

=head2 nth_element

    Returns the nth Biber::Entry::Name object in the object

=cut

sub nth_element {
  my $self = shift;
  my $n = shift;
  return $self->{namelist}[$n-1];
}

=head2 first_n_elements

    Returns a new Biber::Entry::Names object containing only
    the first n entries of $self

=cut

sub first_n_elements {
  my $self = shift;
  my $n = shift;
  my $uniquelist =  $self->{uniquelist};
  my $newnames =  [ splice(@{$self->{namelist}}, 0, $n) ];
  return bless  {'uniquelist' => $uniquelist, 'namelist' => $newnames},
    Biber::Entry::Names;
}

=head2 del_last_element

    Deletes the last Biber::Entry::Name object in the object

=cut

sub del_last_element {
  my $self = shift;
  $self->{namelist} = [ pop(@{$self->{namelist}}) ];
  return;
}

=head2 last_element

    Returns the last Biber::Entry::Name object in the object

=cut

sub last_element {
  my $self = shift;
  return $self->{namelist}[-1];
}

=head2 dump

    Dump a Biber::Entry::Names object for debugging purposes

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

# vim: set tabstop=2 shiftwidth=2 expandtab:
