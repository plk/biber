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
$biber->parse_auxfile('annotations_biblatexml.aux');

my $bibfile = Biber::Config->getoption('bibdata')->[0] ;
$biber->parse_biblatexml($bibfile) ;
$biber->prepare ;
my $bibentries = $biber->bib;

is($bibentries->entry('moraux')->get_field('title'), 'Le \mkbibemph{De Anima} dans la tradition grecque', 'title 1') ;
is($bibentries->entry('moraux')->get_field('sorttitle'), 'De Anima dans la tradition grecque', 'sorttitle 1') ;
is($bibentries->entry('moraux')->get_field('indextitle'), '\mkbibemph{De Anima} dans la tradition grecque, Le', 'indextitle 1') ;
is($bibentries->entry('moraux')->get_field('indexsorttitle'), 'De Anima dans la tradition grecque, Le', 'indexsorttitle 1') ;
my $morauxannotation = q|This is a typical \mkbibquote{\texttt{inproceedings}} entry. Note the \texttt{booksubtitle}, \texttt{shorttitle}, \texttt{indextitle}, and \texttt{indexsorttitle} fields| ;
is($bibentries->entry('moraux')->get_field('annotation'), $morauxannotation, 'other field 1');

is($bibentries->entry('vangennep')->get_field('title'), 'Les rites de passage', 'title 2') ;
is($bibentries->entry('vangennep')->get_field('sorttitle'), 'rites de passage', 'sorttitle 2') ;
is($bibentries->entry('vangennep')->get_field('indextitle'), 'rites de passage, Les', 'indextitle 2') ;

is($bibentries->entry('worman')->get_field('title'), 'The Cast of Character', 'title 3') ;
is($bibentries->entry('worman')->get_field('sorttitle'), 'Cast of Character', 'sorttitle 3') ;
is($bibentries->entry('worman')->get_field('indextitle'), 'Cast of Character, The', 'indextitle 3') ;

is($bibentries->entry('pseudo-einstein')->get_field('title'), 'Die große \mkbibsuperscript{Φ}–Kovarianz: \mkbibquote{Unsinn²} der Stringtheorie', 'title 4') ;
is($bibentries->entry('pseudo-einstein')->get_field('sorttitle'), 'große Φ–Kovarianz: Unsinn² der Stringtheorie', 'sorttitle 4') ;
is($bibentries->entry('pseudo-einstein')->get_field('indextitle'), 'große \mkbibsuperscript{Φ}–Kovarianz: \mkbibquote{Unsinn²} der Stringtheorie, Die', 'indextitle 4') ;

is($bibentries->entry('nested')->get_field('title'), 'Le remue-ménage \mkbibquote{\mkbibsuperscript{X\mkbibsuperscript{O\mkbibsuperscript{O}}}philique}', 'title 4') ;
is($bibentries->entry('nested')->get_field('sorttitle'), 'remue-ménage philique', 'sorttitle 4') ;
is($bibentries->entry('nested')->get_field('indextitle'), 'remue-ménage \mkbibquote{\mkbibsuperscript{X\mkbibsuperscript{O\mkbibsuperscript{O}}}philique}, Le', 'indextitle 4') ;

