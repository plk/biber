package Biber::Entry::List;
use v5.24;
use strict;
use warnings;
use parent qw(Class::Accessor);
__PACKAGE__->follow_best_practice;

use Biber::Config;
use Log::Log4perl qw( :no_extra_logdie_message );
use List::Util qw( first );
no autovivification;
my $logger = Log::Log4perl::get_logger('main');

# Names of simple package accessor attributes for those not created automatically
# by the option scope in the .bcf
__PACKAGE__->mk_accessors(qw (
                               items
                            ));

=encoding utf-8

=head1 NAME

Biber::Entry::List

=head2 new

    Initialise a Biber::Entry::List object with optional array ref as initial values

=cut

sub new {
  my ($class, $list) = @_;
  if ($list) {
    return bless {items => $list}, $class;
  }
  else {
    return bless {}, $class;
  }
}


=head2 notnull

    Test for an empty list

=cut

sub notnull {
  my $self = shift;
  return $self->{items}->$#* > -1 ? 1 : 0;
}


=head2 add_item

    Add an item to the Biber::Entry::List object

=cut

sub add_item {
  my ($self, $item) = @_;
  push $self->{items}->@*, $item;
  return;
}

=head2 remove_item

    Remove an item from the Biber::Entry::List object

=cut

sub remove_item {
  my ($self, $item) = @_;
  $self->{items} = [ grep {$_ ne $item} $self->{items}->@* ];
  return;
}

=head2 replace_item

    Replace an item at a position (1-based)
    with a provided one

=cut

sub replace_item {
  my ($self, $item, $position) = @_;
  $self->{items}[$position-1] = $item;
  return;
}

=head2 splice

    Splice a Biber::Entry::List into a Biber::Entry::List object at a
    position (1-based)

=cut

sub splice {
  my ($self, $listobj, $position) = @_;
  splice($self->{items}->@*, $position-1, 1, $listobj->{items}->@*);
  return;
}

=head2 set_moreitems

    Sets a flag to say that we had a "and others" in the data

=cut

sub set_moreitems {
  my $self = shift;
  $self->{moreitems} = 1;
  return;
}

=head2 get_moreitems

    Gets the moreitems property

=cut

sub get_moreitems {
  my $self = shift;
  return $self->{moreitems} ? 1 : 0;
}

=head2 count

    Returns the number of items in the list

=cut

sub count {
  my $self = shift;
  return scalar $self->{items}->@*;
}

=head2 is_nth_item

    Returns boolean to say of there is an nth item

=cut

sub is_nth_item {
  my ($self, $n) = @_;
  # name n is 1-based, don't go into negative indices
  return $self->{items}[($n == 0) ? 0 : $n-1];
}

=head2 nth_item

    Returns the nth item in the list or undef if there is no such item

=cut

sub nth_item {
  my ($self, $n) = @_;
  return undef if $n > $self->{items}->@*;
  return $self->{items}[$n-1];
}

=head2 first_n_items

    Returns an array ref of items containing only
    the first n items or all items if n > total items

=cut

sub first_n_items {
  my ($self, $n) = @_;
  my $size = $self->{items}->@*;
  return [ $self->{items}->@[0 .. ($n > $size ? $size-1 : $n-1)] ];
}

=head2 del_last_item

    Deletes the last item in the list

=cut

sub del_last_item {
  my $self = shift;
  pop($self->{items}->@*); # Don't want the return value of this!
  return;
}

=head2 last_item

    Returns the last item in the list

=cut

sub last_item {
  my $self = shift;
  return $self->{items}[-1];
}

=head2 get_xdata

    Get any xdata reference information for a list

=cut

sub get_xdata {
  my $self = shift;
  return $self->{xdata} || '';
}

=head2 nth_mslang

  Get the mslang of the nth element of the list

=cut

sub nth_mslang {
  my ($self, $n) = @_;
  return $self->{mslang}[$n-1];
}

=head2 set_nth_mslang

  Set the mslang of the nth element of the list

=cut

sub set_nth_mslang {
  my ($self, $n, $mslang) = @_;
  $self->{mslang}[$n-1] = $mslang;
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
Copyright 2012-2019 Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
