use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 14;

use Biber;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

chdir("t/tdata");

my $bibfile;
my $biber = Biber->new;
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('locale', 'C');
$biber->parse_auxfile_v2('names.aux');
$bibfile = Biber::Config->getoption('bibdata')->[0] . '.bib';
$biber->parse_bibtex($bibfile);
$biber->prepare;

my $l1 = q|\entry{l1}{book}{}
  \name{author}{1}{%
    {{Adler}{A.}{Alfred}{A.}{}{}{}{}}%
  }
  \strng{namehash}{AA1}
  \strng{fullhash}{AA1}
  \field{sortinit}{A}
  \count{uniquename}{0}
\endentry

|;

my $l2 = q|\entry{l2}{book}{}
  \name{author}{1}{%
    {{Bull}{B.}{Bertie~B.}{B.~B.}{}{}{}{}}%
  }
  \strng{namehash}{BBB1}
  \strng{fullhash}{BBB1}
  \field{sortinit}{B}
  \count{uniquename}{0}
\endentry

|;

my $l3 = q|\entry{l3}{book}{}
  \name{author}{1}{%
    {{Crop}{C.}{C.~Z.}{C.~Z.}{}{}{}{}}%
  }
  \strng{namehash}{CCZ1}
  \strng{fullhash}{CCZ1}
  \field{sortinit}{C}
  \count{uniquename}{0}
\endentry

|;

my $l4 = q|\entry{l4}{book}{}
  \name{author}{1}{%
    {{Decket}{D.}{Derek D}{D.~D.}{}{}{}{}}%
  }
  \strng{namehash}{DDD1}
  \strng{fullhash}{DDD1}
  \field{sortinit}{D}
  \count{uniquename}{0}
\endentry

|;

my $l5 = q|\entry{l5}{book}{}
  \name{author}{1}{%
    {{Eel}{E.}{Egbert}{E.}{von}{v.}{}{}}%
  }
  \strng{namehash}{EE1}
  \strng{fullhash}{EE1}
  \field{sortinit}{E}
  \count{uniquename}{0}
\endentry

|;

my $l6 = q|\entry{l6}{book}{}
  \name{author}{1}{%
    {{Frome}{F.}{Francis}{F.}{van~der~valt}{v.~d.~v.}{}{}}%
  }
  \strng{namehash}{FF1}
  \strng{fullhash}{FF1}
  \field{sortinit}{F}
  \count{uniquename}{0}
\endentry

|;

my $l7 = q|\entry{l7}{book}{}
  \name{author}{1}{%
    {{Gloom}{G.}{Gregory~R.}{G.~R.}{van}{v.}{}{}}%
  }
  \strng{namehash}{GGR1}
  \strng{fullhash}{GGR1}
  \field{sortinit}{G}
  \count{uniquename}{0}
\endentry

|;

my $l8 = q|\entry{l8}{book}{}
  \name{author}{1}{%
    {{Henkel}{H.}{Henry~F.}{H.~F.}{van}{v.}{}{}}%
  }
  \strng{namehash}{HHF1}
  \strng{fullhash}{HHF1}
  \field{sortinit}{H}
  \count{uniquename}{0}
\endentry

|;

my $l9 = q|\entry{l9}{book}{}
  \name{author}{1}{%
    {{Iliad~Ipswich}{I.~I.}{Ian}{I.}{}{}{}{}}%
  }
  \strng{namehash}{III1}
  \strng{fullhash}{III1}
  \field{sortinit}{I}
  \count{uniquename}{0}
\endentry

|;

my $l10 = q|\entry{l10}{book}{}
  \name{author}{1}{%
    {{Jolly}{J.}{James}{J.}{}{}{III}{I.}}%
  }
  \strng{namehash}{JIJ1}
  \strng{fullhash}{JIJ1}
  \field{sortinit}{J}
  \count{uniquename}{0}
\endentry

|;

my $l11 = q|\entry{l11}{book}{}
  \name{author}{1}{%
    {{Kluster}{K.}{Kevin}{K.}{van}{v.}{Jr.}{J.}}%
  }
  \strng{namehash}{KJK1}
  \strng{fullhash}{KJK1}
  \field{sortinit}{K}
  \count{uniquename}{0}
\endentry

|;

my $l12 = q|\entry{l12}{book}{}
  \name{author}{1}{%
    {{Vall{\'e}e~Poussin}{V.~P.}{Charles Louis Xavier Joseph}{C.~L.~X.~J.}{de~la}{d.~l.}{}{}}%
  }
  \strng{namehash}{VPCLXJ1}
  \strng{fullhash}{VPCLXJ1}
  \field{sortinit}{V}
  \count{uniquename}{0}
\endentry

|;

my $l13 = q|\entry{l13}{book}{}
  \name{author}{1}{%
    {{Van~de~Graaff}{V.~d.~G.}{R.~J.}{R.~J.}{}{}{}{}}%
  }
  \strng{namehash}{VdGRJ1}
  \strng{fullhash}{VdGRJ1}
  \field{sortinit}{V}
  \count{uniquename}{0}
\endentry

|;

my $l14 = q|\entry{l14}{book}{}
  \name{author}{1}{%
    {{St~John-Mollusc}{S.~J.}{Oliver}{O.}{}{}{}{}}%
  }
  \strng{namehash}{SJMO1}
  \strng{fullhash}{SJMO1}
  \field{sortinit}{S}
  \count{uniquename}{0}
\endentry

|;


is( $biber->_print_biblatex_entry('l1'), $l1, 'First Last') ;
is( $biber->_print_biblatex_entry('l2'), $l2, 'First Initial. Last') ;
is( $biber->_print_biblatex_entry('l3'), $l3, 'Initial. Initial. Last') ;
is( $biber->_print_biblatex_entry('l4'), $l4, 'First Initial Last') ;
is( $biber->_print_biblatex_entry('l5'), $l5, 'First prefix Last') ;
is( $biber->_print_biblatex_entry('l6'), $l6, 'First prefix prefix Last') ;
is( $biber->_print_biblatex_entry('l7'), $l7, 'First Initial. prefix Last') ;
is( $biber->_print_biblatex_entry('l8'), $l8, 'First Initial prefix Last') ;
is( $biber->_print_biblatex_entry('l9'), $l9, 'First {Last Last}') ;
is( $biber->_print_biblatex_entry('l10'), $l10, 'Last, Suffix, First') ;
is( $biber->_print_biblatex_entry('l11'), $l11, 'prefix Last, Suffix, First') ;
is( $biber->_print_biblatex_entry('l12'), $l12, 'First First First First prefix prefix Last Last') ;
is( $biber->_print_biblatex_entry('l13'), $l13, 'Last Last Last, Initial. Initial.');
is( $biber->_print_biblatex_entry('l14'), $l14, 'Last Last-Last, First');

unlink "$bibfile.utf8";
