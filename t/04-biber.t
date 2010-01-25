use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More;
use Biber;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

if ($ENV{TEST_BIBTEX_PRD} or ! eval "require Text::BibTeX; 1") {
    plan( tests => 4);
}
else {
    plan( skip_all => "Skipping parsing with Biber::BibTeX::PRD" );
}

my $opts = { unicodebbl => 0, useprd => 1 };
my $biber = Biber->new($opts);

use_ok( 'Biber::BibTeX::PRD' );

isa_ok($biber, "Biber");

chdir("t/tdata");
$biber->parse_auxfile("02-annotations.aux");
Biber::Config->setblxoption('sortalphaothers', '+');

my $bibfile = Biber::Config->getoption('bibdata')->[0] . ".bib";
$biber->parse_bibtex($bibfile);
$biber->prepare;

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
  \field{labelyear}{2006}
  \count{uniquename}{0}
  \true{singletitle}
  \field{year}{2006}
  \field{month}{02}
  \field{title}{Effect of immobilization on catalytic characteristics of saturated Pd-N-heterocyclic carbenes in Mizoroki-Heck reactions}
  \field{indextitle}{Effect of immobilization on catalytic characteristics}
  \field{journaltitle}{J.~Organomet. Chem.}
  \field{number}{13}
  \field{volume}{691}
  \field{pages}{3027\bibrangedash 3036}
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
  \field{labelyear}{2005\bibdatedash 2006}
  \count{uniquename}{0}
  \true{singletitle}
  \field{year}{2005}
  \field{endyear}{2006}
  \field{origyear}{2004}
  \field{origendyear}{2004}
  \field{urlyear}{2006}
  \field{month}{10}
  \field{endmonth}{12}
  \field{origmonth}{02}
  \field{origendmonth}{10}
  \field{urlmonth}{10}
  \field{day}{16}
  \field{endday}{14}
  \field{origday}{13}
  \field{origendday}{11}
  \field{urlday}{01}
  \field{title}{Tame the BeaST}
  \field{subtitle}{The B to X of BibTeX}
  \field{annotation}{An \texttt{online} entry for a tutorial. Note the format of the \texttt{date} field (\texttt{yyyy-mm-dd}) in the database file. It is also possible to use the fields \texttt{day}\slash \texttt{month}\slash \texttt{year} instead.}
  \field{version}{1.3}
  \field{hyphenation}{american}
  \verb{url}
  \verb http://tug.ctan.org/tex-archive/info/bibtex/tamethebeast/ttb_en.pdf
  \endverb
\endentry

| ;

is( $biber->_print_biblatex_entry('set:aksin'), $setaksin, 'bbl entry 1' ) ;
is( $biber->_print_biblatex_entry('markey'), $markey, 'bbl entry 2' ) ;

