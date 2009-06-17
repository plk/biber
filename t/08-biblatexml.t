use strict;
use warnings;
use utf8;
no warnings 'utf8' ;

use Test::More tests => 14 ;

use Biber;

my $biber = Biber->new();
   
isa_ok($biber, "Biber");

chdir("t/tdata") ;
$biber->parse_auxfile('02-annotations_biblatexml.aux');

my $bibfile = $biber->config('bibdata')->[0] ;
$biber->parse_biblatexml($bibfile) ;
$biber->prepare ;

is($biber->{bib}->{moraux}->{title}, 'Le \mkbibemph{De Anima} dans la tradition grecque', 'title 1') ;
is($biber->{bib}->{moraux}->{sorttitle}, 'De Anima dans la tradition grecque', 'sorttitle 1') ;
is($biber->{bib}->{moraux}->{indextitle}, '\mkbibemph{De Anima} dans la tradition grecque, Le', 'indextitle 1') ;
is($biber->{bib}->{moraux}->{indexsorttitle}, 'De Anima dans la tradition grecque, Le', 'indexsorttitle 1') ;

is($biber->{bib}->{vangennep}->{title}, 'Les rites de passage', 'title 2') ;
is($biber->{bib}->{vangennep}->{sorttitle}, 'rites de passage', 'sorttitle 2') ;
is($biber->{bib}->{vangennep}->{indextitle}, 'rites de passage, Les', 'indextitle 2') ;

is($biber->{bib}->{worman}->{title}, 'The Cast of Character', 'title 3') ;
is($biber->{bib}->{worman}->{sorttitle}, 'Cast of Character', 'sorttitle 3') ;
is($biber->{bib}->{worman}->{indextitle}, 'Cast of Character, The', 'indextitle 3') ;

is($biber->{bib}->{'pseudo-einstein'}->{title}, 'Die große \mkbibsuperscript{Φ}–Kovarianz: \mkbibquote{Unsinn²} der Stringtheorie', 'title 4') ;
is($biber->{bib}->{'pseudo-einstein'}->{sorttitle}, 'große Φ–Kovarianz: Unsinn² der Stringtheorie', 'sorttitle 4') ;
is($biber->{bib}->{'pseudo-einstein'}->{indextitle}, 'große \mkbibsuperscript{Φ}–Kovarianz: \mkbibquote{Unsinn²} der Stringtheorie, Die', 'indextitle 4') ;
