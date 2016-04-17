package Biber::Annotation;
use v5.16;
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
    $ANN->{$scope}{$key}{$field} = $value;
  }
  elsif ($scope eq 'item') {
    $ANN->{$scope}{$key}{$field}{$count} = $value;
  }
  elsif ($scope eq 'part') {
    $ANN->{$scope}{$key}{$field}{$count}{$part} = $value;
  }
  return;
}

=head2 get_annotation

  Retrieve an annotation for a scope and citekey

=cut

sub get_annotation {
  shift; # class method so don't care about class name
  my ($scope, $key, $field, $count, $part) = @_;
  if ($scope eq 'field') {
    return $ANN->{$scope}{$key}{$field};
  }
  elsif ($scope eq 'item') {
    return $ANN->{$scope}{$key}{$field}{$count};
  }
  elsif ($scope eq 'part') {
    return $ANN->{$scope}{$key}{$field}{$count}{$part};
  }
  return undef;
}

=head2 get_annotated_fields

  Retrieve all annotated fields for a particular scope for a key

=cut

sub get_annotated_fields {
  shift; # class method so don't care about class name
  my ($scope, $key) = @_;
  return sort keys %{$ANN->{$scope}{$key}};
}

=head2 get_annotated_items

  Retrieve the itemcounts for for a particular scope, key and field

=cut

sub get_annotated_items {
  shift; # class method so don't care about class name
  my ($scope, $key, $field) = @_;
  return sort keys %{$ANN->{$scope}{$key}{$field}};
}

=head2 get_annotated_parts

  Retrieve the parts for for a particular scope, key, field and itemcount

=cut

sub get_annotated_parts {
  shift; # class method so don't care about class name
  my ($scope, $key, $field, $count) = @_;
  return sort keys %{$ANN->{$scope}{$key}{$field}{$count}};
}

=head2 dump

    Dump config information (for debugging)

=cut

sub dump {
  shift; # class method so don't care about class name
  dd($ANN);
}


1;
