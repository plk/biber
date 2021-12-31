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
use Storable qw(dclone);
no autovivification;
my $logger = Log::Log4perl::get_logger('main');

# Static class data
my $ANN = {};

=encoding utf-8

=head1 NAME

Biber::Entry::Annotation - Biber::Annotation objects

=head2 set_annotation

  Record an annotation for a scope and citekey

=cut

sub set_annotation {
  shift; # class method so don't care about class name
  my ($scope, $key, $field, $form, $lang, $name, $value, $literal, $count, $part) = @_;
  $name = $name // 'default';
  $form = $form // 'default';
  $lang = $lang // Biber::Config->get_mslang($key);

  if ($scope eq 'field') {
    $ANN->{field}{$key}{$field}{$form}{$lang}{$name}{value} = $value;
    $ANN->{field}{$key}{$field}{$form}{$lang}{$name}{literal} = $literal; # Record if this annotation is a literal
  }
  elsif ($scope eq 'item') {
    $ANN->{item}{$key}{$field}{$form}{$lang}{$name}{$count}{value} = $value;
    $ANN->{item}{$key}{$field}{$form}{$lang}{$name}{$count}{literal} = $literal; # Record if this annotation is a literal

    # mslang is a special multiscript annotation only occurring in item annotations
    if ($name eq 'mslang') {
      Biber::Config->add_lang($value);
    }

  }
  elsif ($scope eq 'part') {
    $ANN->{part}{$key}{$field}{$form}{$lang}{$name}{$count}{$part}{value} = $value;
    $ANN->{part}{$key}{$field}{$form}{$lang}{$name}{$count}{$part}{literal} = $literal; # Record if this annotation is a literal
  }

  # For easy checking later whether or not a field is annotated
  $ANN->{fields}{$key}{$field}{$form}{$lang} = 1;

  # Record all annotation names for a field
  unless (first {fc($_) eq fc($name)} $ANN->{names}{$key}{$field}{$form}{$lang}->@*) {
    push $ANN->{names}{$key}{$field}{$form}{$lang}->@*, $name;
  }

  # Record all fields annotated with a name
  unless (first {fc($_->[0]) eq fc($field) and
                   fc($_->[1]) eq fc($form) and
                     fc($_->[2]) eq fc($lang)} $ANN->{fieldswithname}{$key}{$name}->@*) {
    push $ANN->{fieldswithname}{$key}{$name}->@*, [$field, $form, $lang];
  }

  # Record all forms/langs for an annotation
  $ANN->{ms}{$key}{$field}{$form}{$lang}{$name} = 1;

  return;
}

=head2 copy_annotations

  Copy all annotations from one entry to another

=cut

sub copy_annotations {
  shift; # class method so don't care about class name
  my ($sourcekey, $targetkey) = @_;
  $ANN->{field}{$targetkey} = dclone($ANN->{field}{$sourcekey}) if exists($ANN->{field}{$sourcekey});
  $ANN->{fields}{$targetkey} = dclone($ANN->{fields}{$sourcekey}) if exists($ANN->{fields}{$sourcekey});
  $ANN->{item}{$targetkey} = dclone($ANN->{item}{$sourcekey}) if exists($ANN->{item}{$sourcekey});
  $ANN->{part}{$targetkey} = dclone($ANN->{part}{$sourcekey}) if exists($ANN->{part}{$sourcekey});
  $ANN->{names}{$targetkey} = dclone($ANN->{names}{$sourcekey}) if exists($ANN->{names}{$sourcekey});
  $ANN->{fieldswithname}{$targetkey} = dclone($ANN->{fieldswithname}{$sourcekey}) if exists($ANN->{fieldswithname}{$sourcekey});
  $ANN->{ms}{$targetkey} = dclone($ANN->{ms}{$sourcekey}) if exists($ANN->{ms}{$sourcekey});

  return;
}

=head2 get_annotation

  Retrieve an specific annotation for a scope, citekey and name

=cut

sub get_annotation {
  shift; # class method so don't care about class name
  my ($scope, $key, $field, $form, $lang, $name, $count, $part) = @_;
  $name = $name // 'default';
  $form = $form // 'default';
  $lang = $lang // Biber::Config->get_mslang($key);
  if ($scope eq 'field') {
    return $ANN->{field}{$key}{$field}{$form}{$lang}{$name}{value};
  }
  elsif ($scope eq 'item') {
    return $ANN->{item}{$key}{$field}{$form}{$lang}{$name}{$count}{value};
  }
  elsif ($scope eq 'part') {
    return $ANN->{part}{$key}{$field}{$form}{$lang}{$name}{$count}{$part}{value};
  }
  return undef;
}

=head2 get_annotation_forms

  Retrieve all multiscript forms for an annotation

=cut

sub get_annotation_forms {
  shift; # class method so don't care about class name
  my ($key, $field) = @_;
  return sort keys $ANN->{ms}{$key}{$field}->%*;
}

=head2 get_annotation_langs

  Retrieve all multiscript langs for an annotation form

=cut

sub get_annotation_langs {
  shift; # class method so don't care about class name
  my ($key, $field, $form) = @_;
  $form = $form // 'default';
  return sort keys $ANN->{ms}{$key}{$field}{$form}->%*;
}

=head2 get_annotation_names

  Retrieve all annotation names for a citekey and field

=cut

sub get_annotation_names {
  shift; # class method so don't care about class name
  my ($key, $field, $form, $lang) = @_;
  $form = $form // 'default';
  $lang = $lang // Biber::Config->get_mslang($key);
  return $ANN->{names}{$key}{$field}{$form}{$lang}->@*;
}

=head2 get_annotations

  Retrieve all annotations for a scope and citekey

=cut

sub get_annotations {
  shift; # class method so don't care about class name
  my ($scope, $key, $field, $form, $lang) = @_;
  $form = $form // 'default';
  $lang = $lang // Biber::Config->get_mslang($key);
  return sort keys $ANN->{$scope}{$key}{$field}{$form}{$lang}->%*;
}

=head2 is_literal_annotation

  Check if an annotation is a literal annotation

=cut

sub is_literal_annotation {
  shift; # class method so don't care about class name
  my ($scope, $key, $field, $form, $lang, $name, $count, $part) = @_;
  $name = $name // 'default';
  $form = $form // 'default';
  $lang = $lang // Biber::Config->get_mslang($key);
  if ($scope eq 'field') {
    return $ANN->{field}{$key}{$field}{$form}{$lang}{$name}{literal};
  }
  elsif ($scope eq 'item') {
    return $ANN->{item}{$key}{$field}{$form}{$lang}{$name}{$count}{literal};
  }
  elsif ($scope eq 'part') {
    return $ANN->{part}{$key}{$field}{$form}{$lang}{$name}{$count}{$part}{literal};
  }
  return undef;
}

=head2 fields_with_named_annotation

  Returns array ref of fields with a given named annotation in an entry

=cut

sub fields_with_named_annotation {
  shift; # class method so don't care about class name
  my ($key, $name) = @_;
  return $ANN->{fieldswithname}{$key}{$name} // [];
}

=head2 is_annotated_field

  Returns boolean to say if a field is annotated

=cut

sub is_annotated_field {
  shift; # class method so don't care about class name
  my ($key, $field, $form, $lang) = @_;
  $form = $form // 'default';
  $lang = $lang // Biber::Config->get_mslang($key);
  return $ANN->{fields}{$key}{$field}{$form}{$lang};
}

=head2 get_field_annotation

  Retrieve 'field' scope annotation for a field. There will only be one.

=cut

sub get_field_annotation {
  shift; # class method so don't care about class name
  my ($key, $field, $name, $form, $lang) = @_;
  $name = $name // 'default';
  $form = $form // 'default';
  $lang = $lang // Biber::Config->get_mslang($key);
  return $ANN->{field}{$key}{$field}{$form}{$lang}{$name}{value};
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

  Retrieve the itemcounts for a particular scope, key, field and name

=cut

sub get_annotated_items {
  shift; # class method so don't care about class name
  my ($scope, $key, $field, $name, $form, $lang) = @_;
  $name = $name // 'default';
  $form = $form // 'default';
  $lang = $lang // Biber::Config->get_mslang($key);
  return sort keys $ANN->{$scope}{$key}{$field}{$form}{$lang}{$name}->%*;
}

=head2 get_annotated_parts

  Retrieve the parts for a particular scope, key, field, name and itemcount

=cut

sub get_annotated_parts {
  shift; # class method so don't care about class name
  my ($scope, $key, $field, $name, $count, $form, $lang) = @_;
  $name = $name // 'default';
  $form = $form // 'default';
  $lang = $lang // Biber::Config->get_mslang($key);
  return sort keys $ANN->{$scope}{$key}{$field}{$form}{$lang}{$name}{$count}->%*;
}

=head2 del_annotation

  Deletes an annotation

=cut

sub del_annotation {
  my ($key, $field, $name, $form, $lang) = @_;
  $form = $form // 'default';
  $lang = $lang // Biber::Config->get_mslang($key);
  delete $ANN->{field}{$key}{$field}{$form}{$lang}{$name};
  delete $ANN->{item}{$key}{$field}{$form}{$lang}{$name};
  delete $ANN->{part}{$key}{$field}{$form}{$lang}{$name};

  $ANN->{names}{$key}{$field}{$form}{$lang} = [grep {$_ ne $name} $ANN->{names}{$key}{$field}{$form}{$lang}->@*];

  delete $ANN->{fieldswithname}{$key}{$name};
  delete $ANN->{ms}{$key}{$field}{$form}{$lang}{$name};

  return;
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

Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our Github tracker at
L<https://github.com/plk/biber/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2012-2022 Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
