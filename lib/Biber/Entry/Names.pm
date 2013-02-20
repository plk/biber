package Biber::Entry::Names;
use v5.16;
use strict;
use warnings;

use Data::Dump;
use Biber::Config;
use Log::Log4perl qw( :no_extra_logdie_message );
use Storable qw( dclone );
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

# sub TO_JSON {
#   my $self = shift;
#   foreach my $n (@$self){
#     $json->{$k} = $v;
#   }
#   return [ map {$_} @$self ];
# }

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
  my ($namelist, $maxcn, $mincn) = @_;
  my $uniquelist = $self->count_uniquelist($namelist);
  my $num_names = $self->count_names;
  my $currval = $self->{uniquelist};

  # Set modified flag to positive if we changed something
  if (not defined($currval) or $currval != $uniquelist) {
    Biber::Config->set_unul_changed(1);
  }

  # Special case $uniquelist <=1 is meaningless
  return if $uniquelist <= 1;

  # Don't set uniquelist unless the list is longer than maxcitenames as it was therefore
  # never truncated to mincitenames in the first place and uniquelist is a "local mincitenames"
  return unless $self->count_names > $maxcn;

  # No disambiguation needed if uniquelist is <= mincitenames as this makes no sense
  # since it implies that disambiguation beyond mincitenames was needed.
  # This doesn't apply when the list length is mincitenames as maxmanes therefore
  # (since it can't be less than mincitenames) could also be the same as the list length
  # and this is a special case where we need to preserve uniquelist (see comments in
  # create_uniquelist_info())
  # $uniquelist cannot be undef or 0 either since every list occurs at least once.
  # This guarantees that uniquelist, when set, is >1 because mincitenames cannot
  # be <1
  return if $uniquelist <= $mincn and not $mincn == $self->count_names;

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
             Biber::Config->get_uniquelistcount_final($namelist) > 1 and
             # nothing differs from $namelist in last place
             not Biber::Config->list_differs_last($namelist) and
             # nothing else is the same to last position but is longer
             not Biber::Config->list_differs_superset($namelist)
            );

  # If there are more names than uniquelist, reduce it by one unless
  # there is another list which differs at uniquelist and is at least as long
  # so we get:
  #
  # AAA and BBB and CCC
  # AAA and BBB and CCC et al
  #
  # instead of
  #
  # AAA and BBB and CCC
  # AAA and BBB and CCC and DDD et al
  #
  # BUT, we also want
  #
  # AAA and BBB and CCC
  # AAA and BBB and CCC and DDD et al
  # AAA and BBB and CCC and EEE et al

  if ($num_names > $uniquelist and
      not Biber::Config->list_differs_nth($namelist, $uniquelist)) {
    $uniquelist--;
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
  my $namelist = shift;
  return $#$namelist + 1;
}

=head2 set_visible_cite

    Set the number of cite visible names as per the different uniquelist, max/mincitenames etc

=cut

sub set_visible_cite {
  my $self = shift;
  my $visibility = shift;
  $self->{visibility} = $visibility;
  return
}

=head2 set_visible_bib

    Set the number of bib visible names as per the different uniquelist, max/minbibnames etc

=cut

sub set_visible_bib {
  my $self = shift;
  my $visibility = shift;
  $self->{visibility_bib} = $visibility;
  return
}

=head2 set_visible_alpha

    Set the number of alpha visible names as per the different uniquelist, max/minalphanames etc

=cut

sub set_visible_alpha {
  my $self = shift;
  my $visibility = shift;
  $self->{visibility_alpha} = $visibility;
  return
}


=head2 get_visible_cite

    Get the number of visible names as per the different uniquelist, max/mincitenames etc

=cut

sub get_visible_cite {
  my $self = shift;
  return $self->{visibility};
}

=head2 get_visible_bib

    Get the number of bib visible names as per the different uniquelist, max/minbibnames etc

=cut

sub get_visible_bib {
  my $self = shift;
  return $self->{visibility_bib};
}

=head2 get_visible_alpha

    Get the number of alpha visible names as per the different uniquelist, max/minalphanames etc

=cut

sub get_visible_alpha {
  my $self = shift;
  return $self->{visibility_alpha};
}



=head2 add_name

    Add a Biber::Entry::Name object to the Biber::Entry::Names
    object

=cut

sub add_name {
  my $self = shift;
  my $name_obj = shift;
  push @{$self->{namelist}}, $name_obj;
  $name_obj->set_index($#{$self->{namelist}} + 1);
  return;
}

=head2 set_morenames

    Sets a flag to say that we had a "and others" in the data

=cut

sub set_morenames {
  my $self = shift;
  $self->{morenames} = 1;
  return;
}

=head2 get_morenames

    Gets the morenames flag

=cut

sub get_morenames {
  my $self = shift;
  return $self->{morenames} ? 1 : 0;
}



=head2 count_names

    Returns the number of Biber::Entry::Name objects in the object

=cut

sub count_names {
  my $self = shift;
  return scalar @{$self->{namelist}};
}

=head2 nth_name

    Returns the nth Biber::Entry::Name object in the object or the last one
    if n > total names

=cut

sub nth_name {
  my $self = shift;
  my $n = shift;
  my $size = @{$self->{namelist}};
  return $self->{namelist}[$n > $size ? $size-1 : $n-1];
}

=head2 first_n_names

    Returns an array ref of Biber::Entry::Name objects containing only
    the first n Biber::Entry::Name objects or all names if n > total names

=cut

sub first_n_names {
  my $self = shift;
  my $n = shift;
  my $size = @{$self->{namelist}};
  return [ @{$self->{namelist}}[0 .. ($n > $size ? $size-1 : $n-1)] ];
}

=head2 del_last_name

    Deletes the last Biber::Entry::Name object in the object

=cut

sub del_last_name {
  my $self = shift;
  pop(@{$self->{namelist}}); # Don't want the return value of this!
  return;
}

=head2 last_name

    Returns the last Biber::Entry::Name object in the object

=cut

sub last_name {
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

1;

__END__

=head1 AUTHORS

François Charette, C<< <firmicus at ankabut.net> >>
Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2013 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
