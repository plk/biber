use strict;
use warnings;
use utf8;
no warnings 'utf8' ;

use Test::More tests => 3 ;

use Biber;

my $opts = { unicodebbl => 0, useprd => 1 };
my $biber = Biber->new($opts);
$biber->{config}->{maxline} = 100000 ;
   
isa_ok($biber, "Biber");

chdir("t/tdata") ;
$biber->parse_auxfile("02-annotations.aux");

$biber->{config}->{maxline} = 100000 ;

my $bibfile = $biber->config('bibdata')->[0] . ".bib";
$biber->parse_bibtex($bibfile) ;
$biber->prepare ;

my $setaksin = q|\entry{set:aksin}{article}{}
  \inset{set}
  \name{author}{7}{%
    {{Aks{\i}n}{A}{{\"O}zge}{{\"O}}{}{}{}{}}%
    {{T{\"u}rkmen}{T}{Hayati}{H}{}{}{}{}}%
    {{Artok}{A}{Levent}{L}{}{}{}{}}%
    {{{\k{C}}etinkaya}{{\k{C}}}{Bekir}{B}{}{}{}{}}%
    {{Ni}{N}{Chaoying}{C}{}{}{}{}}%
    {{B{\"u}y{\"u}kg{\"u}ng{\"o}r}{B}{Orhan}{O}{}{}{}{}}%
    {{{\"O}zkal}{{\"O}}{Erhan}{E}{}{}{}{}}%
  }
  \strng{namehash}{AO+1}
  \strng{fullhash}{AOTHALCBNCBOOE1}
  \field{labelalpha}{Aks+06}
  \field{sortinit}{A}
  \count{uniquename}{0}
  \true{singletitle}
  \field{title}{Effect of immobilization on catalytic characteristics of saturated Pd-N-heterocyclic carbenes in Mizoroki-Heck reactions}
  \field{indextitle}{Effect of immobilization on catalytic characteristics}
  \field{journaltitle}{J.~Organomet. Chem.}
  \field{number}{13}
  \field{volume}{691}
  \field{pages}{3027\bibrangedash 3036}
  \field{year}{2006}
\endentry

| ;

my $markey = q|\entry{markey}{online}{}
  \name{author}{1}{%
    {{Markey}{M}{Nicolas}{N}{}{}{}{}}%
  }
  \strng{namehash}{MN1}
  \strng{fullhash}{MN1}
  \field{labelalpha}{Mar05}
  \field{sortinit}{M}
  \count{uniquename}{0}
  \true{singletitle}
  \field{title}{Tame the BeaST}
  \field{subtitle}{The B to X of BibTeX}
  \field{annotation}{An \texttt{online} entry for a tutorial. Note the format of the \texttt{date} field (\texttt{yyyy-mm-dd}) in the database file. It is also possible to use the fields \texttt{day}\slash \texttt{month}\slash \texttt{year} instead.}
  \field{day}{16}
  \field{month}{10}
  \field{version}{1.3}
  \field{hyphenation}{american}
  \field{year}{2005}
  \verb{url}
  \verb http://tug.ctan.org/tex-archive/info/bibtex/tamethebeast/ttb_en.pdf
  \endverb
\endentry

| ;

is( $biber->_print_biblatex_entry('set:aksin'), $setaksin, 'bbl entry 1' ) ;
is( $biber->_print_biblatex_entry('markey'), $markey, 'bbl entry 2' ) ;

