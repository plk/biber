package Biber::Entry::FieldValue;
use v5.24;
use strict;
use warnings;

use Biber::Annotation;
use Biber::Config;
use Log::Log4perl qw( :no_extra_logdie_message );
use List::Util qw( first );
no autovivification;
my $logger = Log::Log4perl::get_logger('main');


=encoding utf-8

=head1 NAME

Biber::Entry::FieldValue

=head2 new

    Initialise a Biber::Entry::FieldValue object

=cut

sub new {
  my ($class, $be, $value, $form, $lang) = @_;
  my $this = bless {}, $class;
  if ($value) {
    $this->set_value($value, $form, $lang);
  }
  return $this;
}

=head2 get_value

  Retrieve a field value for a particular form/lang

=cut

sub get_value {
  my ($self, $form, $lang) = @_;
  $form = $form // 'default';
  $lang = $lang // 'default';
  return $self->{$form}{$lang};
}

=head2 set_value

  Set a field value for a particular form/lang

=cut

sub set_value {
  my ($self, $value, $form, $lang) = @_;
  $form = $form // 'default';
  $lang = $lang // 'default';
  $self->{$form}{$lang} = $value;
  return;
}
