use strict;
use warnings;
use utf8;
no warnings 'utf8' ;

use Test::More tests => 6 ;

use Biber;

my $opts = { unicodebbl => 1, fastsort => 1 };
my $biber = Biber->new($opts);
   
isa_ok($biber, "Biber");

chdir("t/tdata") ;
$biber->parse_auxfile("02-annotations.aux");

my $bibfile = $biber->config('bibdata')->[0] . ".bib";
$biber->parse_bibtex($bibfile) ;
$biber->prepare ;

my $setaksin = q|\entry{set:aksin}{article}{}
  \inset{set}
  \name{author}{7}{%
    {{Aksın}{A}{Özge}{Ö}{}{}{}{}}%
    {{Türkmen}{T}{Hayati}{H}{}{}{}{}}%
    {{Artok}{A}{Levent}{L}{}{}{}{}}%
    {{C̨etinkaya}{C}{Bekir}{B}{}{}{}{}}%
    {{Ni}{N}{Chaoying}{C}{}{}{}{}}%
    {{Büyükgüngör}{B}{Orhan}{O}{}{}{}{}}%
    {{Özkal}{Ö}{Erhan}{E}{}{}{}{}}%
  }
  \strng{namehash}{AÖ+1}
  \strng{fullhash}{AÖTHALC̨BNCBOÖE1}
  \field{labelalpha}{Aks+06}
  \field{sortinit}{A}
  \count{uniquename}{0}
  \true{singletitle}
  \field{indextitle}{Effect of immobilization on catalytic characteristics}
  \field{journaltitle}{J.~Organomet. Chem.}
  \field{number}{13}
  \field{title}{Effect of immobilization on catalytic characteristics of saturated Pd-N-heterocyclic carbenes in Mizoroki-Heck reactions}
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
  \field{annotation}{An \texttt{online} entry for a tutorial. Note the format of the \texttt{date} field (\texttt{yyyy-mm-dd}) in the database file. It is also possible to use the fields \texttt{day}\slash \texttt{month}\slash \texttt{year} instead.}
  \field{day}{16}
  \field{month}{10}
  \field{subtitle}{The B to X of BibTeX}
  \field{title}{Tame the BeaST}
  \field{version}{1.3}
  \field{hyphenation}{american}
  \field{sorttitle}{Tame the Beast}
  \field{year}{2005}
  \verb{url}
  \verb http://tug.ctan.org/tex-archive/info/bibtex/tamethebeast/ttb_en.pdf
  \endverb
\endentry

| ;

is( $biber->_print_biblatex_entry('set:aksin'), $setaksin, 'bbl entry 1' ) ;
is( $biber->_print_biblatex_entry('markey'), $markey, 'bbl entry 2' ) ;

my $Worman_N = { 'WN2' => 1, 'WN1' => 1 } ;
my $Gennep = { 'vGA1' => 1, 'vGJ1' => 1 } ;
is_deeply( $Biber::uniquenamecount{'Worman_N'}, $Worman_N, 'uniquename count 1') ;
is_deeply( $Biber::uniquenamecount{'Gennep'}, $Gennep, 'uniquename count 2') ;

is_deeply( [ $biber->shorthands ], [ 'kant:kpv', 'kant:ku' ], 'shorthands' ) ;

unlink "$bibfile.utf8" ;

