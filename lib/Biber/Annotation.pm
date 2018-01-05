package Biber::Annotation;
use v5.24;
use strict;
use warnings;

use Biber::Config;
use Biber::Constants;
use Data::Dump;
use Biber::Utils;
use Log::Log4perl qw( :no_extra_logdie_message );
use List::Util qw( first );
no autovivification;
my $logger = Log::Log4perl::get_logger('main');

# Static class data
my $ANN = {};

=encoding utf-8

=head1 ANNOTATION

Biber::Entry::Annotation

=head2 set_annotation

  Record an annotation for a scope and citekey

=cut

sub set_annotation {
  shift; # class method so don't care about class name
  my ($scope, $key, $field, $value, $count, $part) = @_;
  if ($scope eq 'field') {
    $ANN->{field}{$key}{$field} = $value;
  }
  elsif ($scope eq 'item') {
    $ANN->{item}{$key}{$field}{$count} = $value;
  }
  elsif ($scope eq 'part') {
    $ANN->{part}{$key}{$field}{$count}{$part} = $value;
  }
  # For easy checking later whether or not a field is annotated
  $ANN->{fields}{$key}{$field} = 1;
  return;
}

=head2 get_annotation

  Retrieve an annotation for a scope and citekey

=cut

sub get_annotation {
  shift; # class method so don't care about class name
  my ($scope, $key, $field, $count, $part) = @_;
  if ($scope eq 'field') {
    return $ANN->{field}{$key}{$field};
  }
  elsif ($scope eq 'item') {
    return $ANN->{item}{$key}{$field}{$count};
  }
  elsif ($scope eq 'part') {
    return $ANN->{part}{$key}{$field}{$count}{$part};
  }
  return undef;
}

=head2 is_annotated_field

  Returns boolean to say if a field is annotated

=cut

sub is_annotated_field {
  shift; # class method so don't care about class name
  my ($key, $field) = @_;
  return $ANN->{fields}{$key}{$field};
}

=head2 get_field_annotation

  Retrieve 'field' scope annotation for a field. There will only be one.

=cut

sub get_field_annotation {
  shift; # class method so don't care about class name
  my ($key, $field) = @_;
  return $ANN->{field}{$key}{$field};
}

=head2 get_annotated_fields

  Retrieve all annotated fields for a particular scope for a key

=cut

sub get_annotated_fields {
  shift; # class method so don't care about class name
  my ($scope, $key) = @_;
  return sort keys $ANN->{$scope}{$key}->%*;
}

=head2 get_annotated_items

  Retrieve the itemcounts for for a particular scope, key and field

=cut

sub get_annotated_items {
  shift; # class method so don't care about class name
  my ($scope, $key, $field) = @_;
  return sort keys $ANN->{$scope}{$key}{$field}->%*;
}

=head2 get_annotated_parts

  Retrieve the parts for for a particular scope, key, field and itemcount

=cut

sub get_annotated_parts {
  shift; # class method so don't care about class name
  my ($scope, $key, $field, $count) = @_;
  return sort keys $ANN->{$scope}{$key}{$field}{$count}->%*;
}

=head2 dump

    Dump config information (for debugging)

=cut

sub dump {
  shift; # class method so don't care about class name
  dd($ANN);
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

Copyright 2009-2018 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
