package Biber::Entry::Names;
use feature ':5.10';
#use feature 'unicode_strings';

use Data::Dump;
use Biber::Config;
use Log::Log4perl qw( :no_extra_logdie_message );
my $logger = Log::Log4perl::get_logger('main');

=encoding utf-8

=head1 NAME

Biber::Entry::Names

=head2 new

    Initialize a Biber::Entry::Names object

=cut

sub new {
  my $class = shift;
  return bless {namelist => []}, $class;
}


=head2 TO_JSON

   Serialiser for JSON::XS::encode

=cut

sub TO_JSON {
  my $self = shift;
  foreach $n (@$self){
    $json->{$k} = $v;
  }
  return [ map {$_} @$self ];
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
  my $namelist = shift;
  my $uniquelist = $self->count_uniquelist($namelist);
  my $currval = $self->{uniquelist};
  my $minn = Biber::Config->getblxoption('minnames');

  # Set modified flag to positive if we changed something
  if (not defined($currval) or $currval != $uniquelist) {
    Biber::Config->set_unul_changed(1);
  }

  # No disambiguation needed if uniquelist is <= minnames as this makes no sense
  # - we will just use minnames as the truncation point and it's misleading to set
  # uniquelist since this implies that disambiguation beyond minnames was needed.
  # $uniquelist cannot be undef or 0 either since every list occurs at least once.
  # This guarantees that uniquelist, when set, is >1 because minnames cannot
  # be less than 1
  return if $uniquelist <= $minn;

  # Special case.
  # No point disambiguating with uniquelist lists which have the same count
  # for the complete list as this means they are the same list. So, if this
  # is the case, don't set uniquelist at all. BUT, only do this if there is nothing
  # else which these identical lists need disambiguating from:
  #
  # * Assume last index of list is x
  # * Must not be any other list identical apart from position x
  # * Must not be any other list identical up to position x but also longer
  return if (
             # if final count > 1 (identical lists)
             Biber::Config->get_final_uniquelistcount($namelist) > 1 and
             # nothing differs from $namelist in last place
             not Biber::Config->list_differs_last($namelist) and
             # nothing else is the same to last position but is longer
             not Biber::Config->list_differs_superset($namelist)
            );

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
  my $namelist = shift;
  return $#$namelist + 1;
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
  pop(@{$self->{namelist}}); # Don't want the return value of this!
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

Copyright 2009-2011 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

1;

# vim: set tabstop=2 shiftwidth=2 expandtab:
