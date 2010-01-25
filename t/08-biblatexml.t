use strict;
use warnings;
use utf8;
no warnings 'utf8' ;

use Test::More tests => 18 ;

use Biber;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

my $biber = Biber->new();
   
isa_ok($biber, "Biber");

chdir("t/tdata") ;
$biber->parse_auxfile('02-annotations_biblatexml.aux');

my $bibfile = Biber::Config->getoption('bibdata')->[0] ;
$biber->parse_biblatexml($bibfile) ;
$biber->prepare ;

is($biber->{bib}->{moraux}->{title}, 'Le \mkbibemph{De Anima} dans la tradition grecque', 'title 1') ;
is($biber->{bib}->{moraux}->{sorttitle}, 'De Anima dans la tradition grecque', 'sorttitle 1') ;
is($biber->{bib}->{moraux}->{indextitle}, '\mkbibemph{De Anima} dans la tradition grecque, Le', 'indextitle 1') ;
is($biber->{bib}->{moraux}->{indexsorttitle}, 'De Anima dans la tradition grecque, Le', 'indexsorttitle 1') ;
my $morauxannotation = q|This is a typical \mkbibquote{\texttt{inproceedings}} entry. Note the \texttt{booksubtitle}, \texttt{shorttitle}, \texttt{indextitle}, and \texttt{indexsorttitle} fields| ;
is($biber->{bib}->{moraux}->{annotation}, $morauxannotation, 'other field 1');

is($biber->{bib}->{vangennep}->{title}, 'Les rites de passage', 'title 2') ;
is($biber->{bib}->{vangennep}->{sorttitle}, 'rites de passage', 'sorttitle 2') ;
is($biber->{bib}->{vangennep}->{indextitle}, 'rites de passage, Les', 'indextitle 2') ;

is($biber->{bib}->{worman}->{title}, 'The Cast of Character', 'title 3') ;
is($biber->{bib}->{worman}->{sorttitle}, 'Cast of Character', 'sorttitle 3') ;
is($biber->{bib}->{worman}->{indextitle}, 'Cast of Character, The', 'indextitle 3') ;

is($biber->{bib}->{'pseudo-einstein'}->{title}, 'Die große \mkbibsuperscript{Φ}–Kovarianz: \mkbibquote{Unsinn²} der Stringtheorie', 'title 4') ;
is($biber->{bib}->{'pseudo-einstein'}->{sorttitle}, 'große Φ–Kovarianz: Unsinn² der Stringtheorie', 'sorttitle 4') ;
is($biber->{bib}->{'pseudo-einstein'}->{indextitle}, 'große \mkbibsuperscript{Φ}–Kovarianz: \mkbibquote{Unsinn²} der Stringtheorie, Die', 'indextitle 4') ;

is($biber->{bib}->{nested}->{title}, 'Le remue-ménage \mkbibquote{\mkbibsuperscript{X\mkbibsuperscript{O\mkbibsuperscript{O}}}philique}', 'title 4') ;
is($biber->{bib}->{nested}->{sorttitle}, 'remue-ménage philique', 'sorttitle 4') ;
is($biber->{bib}->{nested}->{indextitle}, 'remue-ménage \mkbibquote{\mkbibsuperscript{X\mkbibsuperscript{O\mkbibsuperscript{O}}}philique}, Le', 'indextitle 4') ;

