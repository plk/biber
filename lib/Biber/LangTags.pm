package Biber::LangTags;
use v5.24;
use strict;
use warnings;

use Biber::LangTag;
use Parse::RecDescent;
$::RD_AUTOACTION = q { [@item] } ;
use List::AllUtils qw( first );

# Parse::RecDescent grammar for BCP47 tags
my $rdg = q{
languagetag: (grandfathered|langtag|privateuse) eostring { $return = $item[1] }

langtag: language seporend (script seporend)(?) (region seporend)(?) (variant seporend)(s?) (extension seporend)(s?) privateuse(?)

language: ((ALPHA)(2..3) extlang)|ALPHA(4)|ALPHA(5..8)

extlang: ('-' ALPHA(3) ...seporend)(0..3)

script: ALPHA(4)

region: ALPHA(2)|DIGIT(3)

variant: alphanum(5..8)|DIGIT alphanum(3)

extension: singleton ('-' alphanum(2..8))(s)

singleton: DIGIT|/[\x{41}\x{42}\x{43}\x{44}\x{45}\x{46}\x{47}\x{48}\x{49}\x{4A}\x{4B}\x{4C}\x{4D}\x{4E}\x{4F}\x{50}\x{51}\x{52}\x{53}\x{54}\x{55}\x{56}\x{57}]/|/[\x{59}\x{5A}]/|/[\x{61}\x{62}\x{63}\x{64}\x{65}\x{66}\x{67}\x{68}\x{69}\x{6A}\x{6B}\x{6C}\x{6D}\x{6E}\x{6F}\x{70}\x{71}\x{72}\x{73}\x{74}\x{75}\x{76}\x{77}]/|/[\x{79}\x{7A}]/

privateuse: 'x' ('-' alphanum(1..8))(s)

grandfathered: irregular|regular

irregular: 'en-GB-oed'|'i-ami'|'i-bnn'|'i-default'|'i-enochian'|'i-hak'|'i-klingon'|'i-lux'|'i-mingo'|'i-navajo'|'i-pwn'|'i-tao'|'i-tay'|'i-tsu'|'sgn-BE-FR'|'sgn-BE-NL'|'sgn-CH-DE'

regular: 'art-lojban'|'cel-gaulish'|'no-bok'|'no-nyn'|'zh-guoyu'|'zh-hakka'|'zh-min'|'zh-min-nan'|'zh-xiang'

alphanum: ALPHA|DIGIT

ALPHA: /[a-zA-z]/

DIGIT: /[0-9]/

seporend: eostring|'-'
eostring: /^\Z/

};

my %bcp47parts = ('language'      => 'single',
                  'extlang'       => 'multiple',
                  'script'        => 'single',
                  'region'        => 'single',
                  'variant'       => 'multiple',
                  'extension'     => 'multiple',
                  'privateuse'    => 'multiple',
                  'grandfathered' => 'single');



=encoding utf-8

=head1 NAME

Biber::LangTags - Biber::LangTags objects


=head2 new

    Object to parse language tags and instantiate LangTag objects

=cut

sub new {
  my ($class) = @_;
  my $self = bless {}, $class;

  $self->{parser} = new Parse::RecDescent($rdg);
  return $self;
}

=head2 parse

    Parse a BCP47 tag into its components

=cut

sub parse {
  my ($self, $tag) = @_;
  my $tree = $self->{parser}->languagetag($tag);
  return undef unless defined($tree);

  return Biber::LangTag->new(_bcp47extract($tree));
}

sub _bcp47extract {
  my ($tree, $part, $tag) = @_;
  $part = $part // '';
  $tag = $tag // {};

  return unless ref($tree) eq 'ARRAY';
  return unless scalar($tree->@*) > 0;
  return if $tree->[0] eq 'seporend'; # ignore internal seps or end of tag

  # one level above terminal tokens - loop over them all
  if (ref($tree->[0]) eq 'ARRAY') {
    foreach my $t ($tree->@*) {
      _bcp47extract($t, $part, $tag);
    }
    if ($part and $bcp47parts{$part} eq 'multiple') {
      push $tag->{$part}->@*, $tag->{acc} if $tag->{acc};
    }
  }
  elsif ($tree->[0] eq 'alphanum') { # shortcut
    if ($part and $bcp47parts{$part} eq 'multiple') {
      $tag->{acc} .= $tree->[1][1];
    }
    else {
      $tag->{$part} .= $tree->[1][1];
    }
    return;
  }
  elsif ($tree->[0] eq 'ALPHA' or
         $tree->[0] eq 'DIGIT' or
         $tree->[0] eq 'irregular' or
         $tree->[0] eq 'regular') { # terminal tokens - bottom of recursion
    if ($part and $bcp47parts{$part} eq 'multiple') {
      $tag->{acc} .= $tree->[1];
    }
    else {
      $tag->{$part} .= $tree->[1];
    }
    return;
  }
  # Found a valid part, recurse with part name as context
  elsif (first {$tree->[0] eq $_} keys %bcp47parts) {
    $tag->{acc} = '';
    foreach my $t ($tree->@[1..$tree->$#*]) {
      _bcp47extract($t, $tree->[0], $tag);
    }
  }
  else {
    # Found an intermediate production, ignore and recurse
    foreach my $t ($tree->@[1..$tree->$#*]) {
      _bcp47extract($t, $part, $tag);
    }
  }
  delete($tag->{acc});
  return $tag;
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
