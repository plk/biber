package Biber::Entry::Names;
use v5.24;
use strict;
use warnings;
use parent qw(Class::Accessor);
__PACKAGE__->follow_best_practice;
no autovivification;

use Data::Dump;
use Data::Uniqid qw (suniqid);
use Biber::Config;
use Log::Log4perl qw( :no_extra_logdie_message );
my $logger = Log::Log4perl::get_logger('main');

# Names of simple package accessor attributes for those not created automatically
# by the option scope in the .bcf
__PACKAGE__->mk_accessors(qw (
                              id
                            ));

=encoding utf-8

=head1 NAME

Biber::Entry::Names

=head2 new

    Initialize a Biber::Entry::Names object

=cut

sub new {
  my $class = shift;
  return bless {namelist => [],
                id       => suniqid}, $class;
}


=head2 TO_JSON

   Serialiser for JSON::XS::encode

=cut

# sub TO_JSON {
#   my $self = shift;
#   foreach my $n ($self->@*){
#     $json->{$k} = $v;
#   }
#   return [ map {$_} $self->@* ];
# }

=head2 notnull

    Test for an empty object

=cut

sub notnull {
  my $self = shift;
  my @arr = $self->{namelist}->@*;
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

=head2 add_name

    Add a Biber::Entry::Name object to the Biber::Entry::Names
    object

=cut

sub add_name {
  my $self = shift;
  my $name_obj = shift;
  push $self->{namelist}->@*, $name_obj;
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
  return scalar $self->{namelist}->@*;
}

=head2 nth_name

    Returns the nth Biber::Entry::Name object in the object or the last one
    if n > total names

=cut

sub nth_name {
  my $self = shift;
  my $n = shift;
  my $size = $self->{namelist}->@*;
  return $self->{namelist}[$n > $size ? $size-1 : $n-1];
}

=head2 first_n_names

    Returns an array ref of Biber::Entry::Name objects containing only
    the first n Biber::Entry::Name objects or all names if n > total names

=cut

sub first_n_names {
  my $self = shift;
  my $n = shift;
  my $size = $self->{namelist}->@*;
  return [ $self->{namelist}->@[0 .. ($n > $size ? $size-1 : $n-1)] ];
}

=head2 del_last_name

    Deletes the last Biber::Entry::Name object in the object

=cut

sub del_last_name {
  my $self = shift;
  pop($self->{namelist}->@*); # Don't want the return value of this!
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

Please report any bugs or feature requests on our Github tracker at
L<https://github.com/plk/biber/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2019 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
