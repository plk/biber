use strict;
use warnings;
use utf8;
no warnings 'utf8' ;

use Test::More tests => 8 ;

use Biber;

my $opts = { unicodebbl => 1, fastsort => 1 };
my $biber = Biber->new($opts);

isa_ok($biber, "Biber");

chdir("t/tdata") ;
$biber->parse_auxfile_v2("02-annotations_v2.aux");
$biber->{config}{biblatex}{global}{maxline} = 100000 ;

my $bibfile = $biber->config('bibdata')->[0] . ".bib";
$biber->parse_bibtex($bibfile) ;
$biber->prepare ;

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
  \count{uniquename}{0}
  \true{singletitle}
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
  \field{year}{1998}
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
  \count{uniquename}{0}
  \true{singletitle}
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
  \field{year}{1998}
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
  \field{urlday}{01}
  \field{urlmonth}{10}
  \field{urlyear}{2006}
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

my $Worman_N = { 'WN2' => 1, 'WN1' => 1 } ;

my $Gennep = { 'vGA1' => 1, 'vGJ1' => 1 } ;

is_deeply( $Biber::uniquenamecount{'Worman_N'}, $Worman_N, 'uniquename count 1') ;

is_deeply( $Biber::uniquenamecount{'Gennep'}, $Gennep, 'uniquename count 2') ;

is_deeply( [ $biber->shorthands ], [ 'kant:kpv', 'kant:ku' ], 'shorthands' ) ;

is( $biber->_print_biblatex_entry('murray'), $murray1, 'bbl with > maxnames' ) ;

$biber->{config}{biblatex}{global}{alphaothers} = '';
$biber->{config}{biblatex}{global}{sortalphaothers} = '';
$biber->prepare ;
is( $biber->_print_biblatex_entry('murray'), $murray2, 'bbl with > maxnames, empty alphaothers' ) ;

unlink "$bibfile.utf8" ;

