use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More;
use Biber;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

if ( eval "require Text::BibTeX; 1") {
    plan( tests => 11 );
} 
else {
    plan( skip_all => "Text::BibTeX unavailable! Skipping parsing with Biber::BibTeX" );
}

my $opts = { unicodebbl => 1, fastsort => 1 };
my $biber = Biber->new($opts);

use_ok( 'Biber::BibTeX' );

isa_ok($biber, "Biber");

chdir("t/tdata");
$biber->parse_auxfile_v2("02-annotations_v2.aux");

my $bibfile = Biber::Config->getoption('bibdata')->[0] . ".bib";
$biber->parse_bibtex($bibfile);
$biber->prepare;

my $murray1 = q|\entry{murray}{article}{}
  \name{author}{14}{%
    {{Hostetler}{H}{Michael~J.}{MJ}{}{}{}{}}%
    {{Wingate}{W}{Julia~E.}{JE}{}{}{}{}}%
    {{Zhong}{Z}{Chuan-Jian}{C}{}{}{}{}}%
    {{Harris}{H}{Jay~E.}{JE}{}{}{}{}}%
    {{Vachet}{V}{Richard~W.}{RW}{}{}{}{}}%
    {{Clark}{C}{Michael~R.}{MR}{}{}{}{}}%
    {{Londono}{L}{J.~David}{JD}{}{}{}{}}%
    {{Green}{G}{Stephen~J.}{SJ}{}{}{}{}}%
    {{Stokes}{S}{Jennifer~J.}{JJ}{}{}{}{}}%
    {{Wignall}{W}{George~D.}{GD}{}{}{}{}}%
    {{Glish}{G}{Gary~L.}{GL}{}{}{}{}}%
    {{Porter}{P}{Marc~D.}{MD}{}{}{}{}}%
    {{Evans}{E}{Neal~D.}{ND}{}{}{}{}}%
    {{Murray}{M}{Royce~W.}{RW}{}{}{}{}}%
  }
  \strng{namehash}{HMJ+1}
  \strng{fullhash}{HMJWJEZCJHJEVRWCMRLJDGSJSJJWGDGGLPMDENDMRW1}
  \field{labelalpha}{Hos\textbf{+}98}
  \field{sortinit}{H}
  \field{labelyear}{1998}
  \count{uniquename}{0}
  \true{singletitle}
  \field{year}{1998}
  \field{title}{Alkanethiolate gold cluster molecules with core diameters from 1.5 to 5.2~nm}
  \field{subtitle}{Core and monolayer properties as a function of core size}
  \field{shorttitle}{Alkanethiolate gold cluster molecules}
  \field{indextitle}{Alkanethiolate gold cluster molecules}
  \field{journaltitle}{Langmuir}
  \field{annotation}{An \texttt{article} entry with \arabic{author} authors. By default, long author and editor lists are automatically truncated. This is configurable}
  \field{number}{1}
  \field{volume}{14}
  \field{hyphenation}{american}
  \field{pages}{17\bibrangedash 30}
\endentry

|;

my $murray2 = q|\entry{murray}{article}{}
  \name{author}{14}{%
    {{Hostetler}{H}{Michael~J.}{MJ}{}{}{}{}}%
    {{Wingate}{W}{Julia~E.}{JE}{}{}{}{}}%
    {{Zhong}{Z}{Chuan-Jian}{C}{}{}{}{}}%
    {{Harris}{H}{Jay~E.}{JE}{}{}{}{}}%
    {{Vachet}{V}{Richard~W.}{RW}{}{}{}{}}%
    {{Clark}{C}{Michael~R.}{MR}{}{}{}{}}%
    {{Londono}{L}{J.~David}{JD}{}{}{}{}}%
    {{Green}{G}{Stephen~J.}{SJ}{}{}{}{}}%
    {{Stokes}{S}{Jennifer~J.}{JJ}{}{}{}{}}%
    {{Wignall}{W}{George~D.}{GD}{}{}{}{}}%
    {{Glish}{G}{Gary~L.}{GL}{}{}{}{}}%
    {{Porter}{P}{Marc~D.}{MD}{}{}{}{}}%
    {{Evans}{E}{Neal~D.}{ND}{}{}{}{}}%
    {{Murray}{M}{Royce~W.}{RW}{}{}{}{}}%
  }
  \strng{namehash}{HMJ+1}
  \strng{fullhash}{HMJWJEZCJHJEVRWCMRLJDGSJSJJWGDGGLPMDENDMRW1}
  \field{labelalpha}{Hos98}
  \field{sortinit}{H}
  \field{labelyear}{1998}
  \count{uniquename}{0}
  \true{singletitle}
  \field{year}{1998}
  \field{title}{Alkanethiolate gold cluster molecules with core diameters from 1.5 to 5.2~nm}
  \field{subtitle}{Core and monolayer properties as a function of core size}
  \field{shorttitle}{Alkanethiolate gold cluster molecules}
  \field{indextitle}{Alkanethiolate gold cluster molecules}
  \field{journaltitle}{Langmuir}
  \field{annotation}{An \texttt{article} entry with \arabic{author} authors. By default, long author and editor lists are automatically truncated. This is configurable}
  \field{number}{1}
  \field{volume}{14}
  \field{hyphenation}{american}
  \field{pages}{17\bibrangedash 30}
\endentry

|;


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
  \field{labelalpha}{Aks\textbf{+}06}
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

my $jaffe = q|\entry{jaffe}{collection}{}
  \name{editor}{1}{%
    {{Jaffé}{J}{Philipp}{P}{}{}{}{}}%
  }
  \name{editora}{3}{%
    {{Loewenfeld}{L}{Samuel}{S}{}{}{}{}}%
    {{Kaltenbrunner}{K}{Ferdinand}{F}{}{}{}{}}%
    {{Ewald}{E}{Paul}{P}{}{}{}{}}%
  }
  \list{location}{1}{%
    {Leipzig}%
  }
  \strng{namehash}{JP1}
  \strng{fullhash}{JP1}
  \field{labelalpha}{Jaf85}
  \field{sortinit}{J}
  \field{labelyear}{1885\bibdatedash 1888}
  \count{uniquename}{0}
  \true{singletitle}
  \field{year}{1885}
  \field{endyear}{1888}
  \field{title}{Regesta Pontificum Romanorum ab condita ecclesia ad annum post Christum natum \textsc{mcxcviii}}
  \field{shorttitle}{Regesta Pontificum Romanorum}
  \field{indextitle}{Regesta Pontificum Romanorum}
  \field{annotation}{A \texttt{collection} entry with \texttt{edition} and \texttt{volumes} fields. Note the \texttt{editortype} field handling the redactor}
  \field{edition}{2}
  \field{volumes}{2}
  \field{editoratype}{redactor}
  \field{editoraclass}{vol}
\endentry

|;

my $pimentel1 = q|\entry{pimentel00}{thesis}{}
  \name{author}{1}{%
    {{Pimentel}{P}{Joseph~J.}{JJ}{}{}{Jr.}{J}}%
  }
  \list{institution}{1}{%
    {University of Michigan}%
  }
  \strng{namehash}{PJJ1}
  \strng{fullhash}{PJJ1}
  \field{labelalpha}{Pim00}
  \field{sortinit}{P}
  \field{labelyear}{2000}
  \count{uniquename}{0}
  \true{singletitle}
  \field{year}{2000}
  \field{title}{Sociolinguistic Reflections of Privatization and Globalization: The {Arabic} of {Egyptian} newspaper advertisements}
\endentry

|;

is( $biber->_print_biblatex_entry('set:aksin'), $setaksin, 'bbl entry 1' ) ;
is( $biber->_print_biblatex_entry('markey'), $markey, 'bbl entry 2' ) ;
is( $biber->_print_biblatex_entry('jaffe'), $jaffe, 'bbl entry 3' ) ;
is( $biber->_print_biblatex_entry('pimentel00'), $pimentel1, 'bbl entry 4 - Suffix test 1' ) ;

my $Worman_N = { 'WN2' => 1, 'WN1' => 1 } ;

my $Gennep = { 'vGA1' => 1, 'vGJ1' => 1 } ;

is_deeply( Biber::Config->getstate('uniquenamecount', 'Worman_N'), $Worman_N, 'uniquename count 1') ;

is_deeply( Biber::Config->getstate('uniquenamecount', 'Gennep'), $Gennep, 'uniquename count 2') ;

is_deeply( [ $biber->shorthands ], [ 'kant:kpv', 'kant:ku' ], 'shorthands' ) ;

is( $biber->_print_biblatex_entry('murray'), $murray1, 'bbl with > maxnames' ) ;

Biber::Config->setblxoption('alphaothers', '');
Biber::Config->setblxoption('sortalphaothers', '');
$biber->prepare ;
is( $biber->_print_biblatex_entry('murray'), $murray2, 'bbl with > maxnames, empty alphaothers' ) ;

unlink "$bibfile.utf8" ;

