package Biber::LangTag;
use v5.24;
use strict;
use warnings;
use parent qw(Class::Accessor);
__PACKAGE__->follow_best_practice;

use List::AllUtils qw( first );

my %bcp47parts = ('language'      => 'single',
                  'extlang'       => 'multiple',
                  'script'        => 'single',
                  'region'        => 'single',
                  'variant'       => 'multiple',
                  'extension'     => 'indexed',
                  'privateuse'    => 'multiple',
                  'grandfathered' => 'single');


# Names of simple package accessor attributes for those not created automatically
# by the option scope in the .bcf
__PACKAGE__->mk_accessors(keys %bcp47parts);

=encoding utf-8

=head1 NAME

Biber::LangTag - Biber::LangTag objects

=head2 new

    Object to manipulate BCP47 language tags

=cut

sub new {
  my ($class, %parts) = @_;
  return bless {%parts}, $class;
}

=head2 as_string

    Return the tag as a string

=cut

sub as_string {
  my $self = shift;
  my $acc = '';

  return "invalidtag" if $self->{invalid};

  if (my $s = $self->{grandfathered}) {
    return $s;
  }
  if (my $s = $self->{language}) {
    $acc .= $s;
  }
  if (my $s = $self->{extlang}) {
    foreach my $e ($s->@*) {
      $acc .= "-$e";
    }
  }
  if (my $s = $self->{script}) {
    $acc .= "-$s";
  }
  if (my $s = $self->{region}) {
    $acc .= "-$s";
  }
  if (my $s = $self->{variant}) {
    foreach my $e ($s->@*) {
      $acc .= "-$e";
    }
  }
  if (my $s = $self->{extension}) {
    foreach my $k (sort keys $s->%*) {
      $acc .= "-$k-" . $s->{$k};
    }
  }
  if (my $s = $self->{privateuse}) {
    $acc .= "-x";
    foreach my $e ($s->@*) {
      $acc .= "-$e";
    }
  }
  return $acc;
}


=head2 dump

    Dump the non-null LangTag object parts

=cut

sub dump {
  my $self = shift;
  my $parts = {};
  foreach my $part (keys %bcp47parts) {
    $parts->{$part} = $self->{$part} if defined($self->{$part});
  }
  return $parts;
}

1;

__END__

=head1 AUTHORS

Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our Github tracker at
L<https://github.com/plk/biber/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2012-2024 Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
