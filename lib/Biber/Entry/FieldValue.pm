package Biber::Entry::FieldValue;
use v5.24;
use strict;
use warnings;

use Biber::Annotation;
use Biber::Config;
use Biber::Utils;
use Log::Log4perl qw( :no_extra_logdie_message );
use List::Util qw( first );
no autovivification;
my $logger = Log::Log4perl::get_logger('main');

=encoding utf-8

=head1 NAME

Biber::Entry::FieldValue

=head2 new

    Initialise a Biber::Entry::FieldValue object
    Used to store alternates of multiscript fields

=cut

sub new {
  my ($class, $key, $value, $form, $lang) = @_;
  my $this = bless {key => $key}, $class;
  if (defined($value)) {
    $this->set_value($value, $form, $lang);
  }
  return $this;
}

=head2 get_value

  Retrieve a field value for a particular form/lang

=cut

sub get_value {
  my ($self, $form, $lang) = @_;
  $form = fc($form // 'default');
  $lang = fc($lang // Biber::Config->get_mslang($self->{key}));
  return $self->{alternates}{$form}{$lang};
}

=head2 set_value

  Set a field value for a particular form/lang

=cut

sub set_value {
  my ($self, $value, $form, $lang) = @_;
  $form = fc($form // 'default');
  $lang = fc($lang // Biber::Config->get_mslang($self->{key}));
  $self->{alternates}{$form}{$lang} = $value;
  return;
}

=head2 get_alternates

  Retrieve (sorted) alternates for a particular field

=cut

sub get_alternates {
  my $self = shift;
  my $alternates = [];
  foreach my $form (sort keys $self->{alternates}->%*) {
    foreach my $lang (sort keys $self->{alternates}{$form}->%*) {
      push $alternates->@*, {form => $form, lang => $lang, val => $self->{alternates}{$form}{$lang}};
    }
  }
  return $alternates;
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
