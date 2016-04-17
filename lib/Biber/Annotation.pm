package Biber::Annotation;
use v5.16;
use strict;
use warnings;

use Biber::Config;
use Biber::Constants;
use Biber::Utils;
use Log::Log4perl qw( :no_extra_logdie_message );
use List::Util qw( first );
no autovivification;
my $logger = Log::Log4perl::get_logger('main');

=encoding utf-8

=head1 ANNOTATION

Biber::Entry::Annotation

=head2 new

    Initialise a Biber::Annotation object, optionally with key=>value arguments.

=cut

sub new {
  my ($class, %params) = @_;
  if (%params) {
    my $ann = {};
    foreach my $attr ('scope', 'key', 'value') {
      if (exists $params{$attr}) {
        $ann->{$attr} = $params{$attr};
      }
    }
    return bless $ann, $class;
  } else {
    return bless {}, $class;
  }
}


=head2 set_annotation

  Record an annotation for a scope and citekey

=cut

sub set_annotation {
  my ($self, $scope, $key, $field, $value, $count, $part) = @_;
  if ($scope eq 'field' or $scope eq 'list' or $scope eq 'names') {
    $self->{$scope}{$key}{$field} = $value;
  }
  elsif ($scope eq 'listitem' or $scope eq 'name') {
    $self->{$scope}{$key}{$field}{$count} = $value;
  }
  elsif ($scope eq 'namepart') {
    $self->{$scope}{$key}{$field}{$count}{$part} = $value;
  }
  return;
}

=head2 get_annotation

  Retrieve an annotation for a scope and citekey

=cut

sub get_annotation {
  my ($self, $scope, $key, $field, $value, $count, $part) = @_;
  if ($scope eq 'field' or $scope eq 'plainlist' or $scope eq 'namelist') {
    return $self->{$scope}{$key}{$field};
  }
  elsif ($scope eq 'listitem' or $scope eq 'name') {
    return $self->{$scope}{$key}{$field}{$count};
  }
  elsif ($scope eq 'namepart') {
    return $self->{$scope}{$key}{$field}{$count}{$part};
  }
  return undef;
}


1;
