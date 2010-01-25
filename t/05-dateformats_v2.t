use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 33;

use Biber;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

chdir("t/tdata");

my $bibfile;
my $biber = Biber->new;
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('locale', 'C');
$biber->parse_auxfile_v2('50-dateformats_v2.aux');
$bibfile = Biber::Config->getoption('bibdata')->[0] . '.bib';
$biber->parse_bibtex($bibfile);

Biber::Config->setblxoption('labelyear', [ 'year' ]);
$biber->prepare;

my $l1 = q|\item Invalid format of field 'year' - ignoring field
\item Invalid format of field 'origdate' - ignoring field
\item Invalid format of field 'urldate' - ignoring field
\item Value out of bounds for field/date component 'month' - ignoring
|;
my $l2 = q|\item Invalid format of field 'origdate' - ignoring field
|;
my $l3 = q|\item Invalid format of field 'urldate' - ignoring field
|;
my $l4 = q|\item Invalid format of field 'date' - ignoring field
|;
my $l5 = q|\item Invalid format of field 'date' - ignoring field
|;
my $l6 = q|\item Value out of bounds for field/date component 'month' - ignoring
|;
my $l7 = q|\item Value out of bounds for field/date component 'eventday' - ignoring
|;
my $l8 = q|\item Invalid format of field 'year' - ignoring field
\item Invalid format of field 'month' - ignoring field
|;

my $l11 = q|\item Field conflict - both 'date' and 'year' used - ignoring field 'year'
|;
my $l12 = q|\item Field conflict - both 'date' and 'month' used - ignoring field 'month'
|;

my $l13c = q|\entry{L13}{book}{}
  \name{author}{2}{%
    {{Doe}{D.}{John}{J.}{}{}{}{}}%
    {{Abrahams}{A.}{Albert}{A.}{}{}{}{}}%
  }
  \list{publisher}{1}{%
    {Oxford}%
  }
  \strng{namehash}{DJAA1}
  \strng{fullhash}{DJAA1}
  \field{sortinit}{D}
  \field{extrayear}{4}
  \field{labelyear}{1996}
  \count{uniquename}{0}
  \field{year}{1996}
  \field{month}{01}
  \field{day}{01}
  \field{title}{Title 2}
\endentry

|;

my $l14 = q|\entry{L14}{book}{}
  \name{author}{2}{%
    {{Doe}{D.}{John}{J.}{}{}{}{}}%
    {{Abrahams}{A.}{Albert}{A.}{}{}{}{}}%
  }
  \list{publisher}{1}{%
    {Oxford}%
  }
  \strng{namehash}{DJAA1}
  \strng{fullhash}{DJAA1}
  \field{sortinit}{D}
  \field{extrayear}{5}
  \field{labelyear}{1996}
  \count{uniquename}{0}
  \field{year}{1996}
  \field{endyear}{1996}
  \field{month}{12}
  \field{endmonth}{12}
  \field{day}{10}
  \field{endday}{12}
  \field{title}{Title 2}
\endentry

|;

my $l15 = q|\entry{L15}{book}{}
  \name{author}{2}{%
    {{Doe}{D.}{John}{J.}{}{}{}{}}%
    {{Abrahams}{A.}{Albert}{A.}{}{}{}{}}%
  }
  \list{publisher}{1}{%
    {Oxford}%
  }
  \strng{namehash}{DJAA1}
  \strng{fullhash}{DJAA1}
  \field{sortinit}{D}
  \field{extrayear}{6}
  \count{uniquename}{0}
  \field{title}{Title 2}
\endentry

|;

my $l16 = q|\entry{l16}{book}{}
  \name{author}{2}{%
    {{Doe}{D.}{John}{J.}{}{}{}{}}%
    {{Abrahams}{A.}{Albert}{A.}{}{}{}{}}%
  }
  \list{publisher}{1}{%
    {Oxford}%
  }
  \strng{namehash}{DJAA1}
  \strng{fullhash}{DJAA1}
  \field{sortinit}{D}
  \field{extrayear}{7}
  \field{labelyear}{1996}
  \count{uniquename}{0}
  \field{eventyear}{1996}
  \field{eventmonth}{01}
  \field{eventday}{01}
  \field{title}{Title 2}
\endentry

|;

my $l17 = q|\entry{l17}{book}{}
  \name{author}{2}{%
    {{Doe}{D.}{John}{J.}{}{}{}{}}%
    {{Abrahams}{A.}{Albert}{A.}{}{}{}{}}%
  }
  \list{publisher}{1}{%
    {Oxford}%
  }
  \strng{namehash}{DJAA1}
  \strng{fullhash}{DJAA1}
  \field{sortinit}{D}
  \field{extrayear}{6}
  \field{labelyear}{1996}
  \count{uniquename}{0}
  \field{year}{1996}
  \field{endyear}{1996}
  \field{origyear}{1998}
  \field{origendyear}{1998}
  \field{eventyear}{1998}
  \field{eventendyear}{2004}
  \field{month}{12}
  \field{endmonth}{12}
  \field{origmonth}{12}
  \field{origendmonth}{12}
  \field{eventmonth}{12}
  \field{eventendmonth}{12}
  \field{day}{10}
  \field{endday}{12}
  \field{origday}{10}
  \field{origendday}{12}
  \field{eventday}{10}
  \field{eventendday}{12}
  \field{title}{Title 2}
\endentry

|;

my $l17c = q|\entry{l17}{book}{}
  \name{author}{2}{%
    {{Doe}{D.}{John}{J.}{}{}{}{}}%
    {{Abrahams}{A.}{Albert}{A.}{}{}{}{}}%
  }
  \list{publisher}{1}{%
    {Oxford}%
  }
  \strng{namehash}{DJAA1}
  \strng{fullhash}{DJAA1}
  \field{sortinit}{D}
  \field{extrayear}{6}
  \field{labelyear}{1998}
  \count{uniquename}{0}
  \field{year}{1996}
  \field{endyear}{1996}
  \field{origyear}{1998}
  \field{origendyear}{1998}
  \field{eventyear}{1998}
  \field{eventendyear}{2004}
  \field{month}{12}
  \field{endmonth}{12}
  \field{origmonth}{12}
  \field{origendmonth}{12}
  \field{eventmonth}{12}
  \field{eventendmonth}{12}
  \field{day}{10}
  \field{endday}{12}
  \field{origday}{10}
  \field{origendday}{12}
  \field{eventday}{10}
  \field{eventendday}{12}
  \field{title}{Title 2}
\endentry

|;

my $l17e = q|\entry{l17}{book}{}
  \name{author}{2}{%
    {{Doe}{D.}{John}{J.}{}{}{}{}}%
    {{Abrahams}{A.}{Albert}{A.}{}{}{}{}}%
  }
  \list{publisher}{1}{%
    {Oxford}%
  }
  \strng{namehash}{DJAA1}
  \strng{fullhash}{DJAA1}
  \field{sortinit}{D}
  \field{extrayear}{6}
  \field{labelyear}{1998\bibdatedash 2004}
  \count{uniquename}{0}
  \field{year}{1996}
  \field{endyear}{1996}
  \field{origyear}{1998}
  \field{origendyear}{1998}
  \field{eventyear}{1998}
  \field{eventendyear}{2004}
  \field{month}{12}
  \field{endmonth}{12}
  \field{origmonth}{12}
  \field{origendmonth}{12}
  \field{eventmonth}{12}
  \field{eventendmonth}{12}
  \field{day}{10}
  \field{endday}{12}
  \field{origday}{10}
  \field{origendday}{12}
  \field{eventday}{10}
  \field{eventendday}{12}
  \field{title}{Title 2}
\endentry

|;


is($biber->{bib}{l1}{warnings}, $l1, 'Date format test 1' ) ;
ok(! defined($biber->{bib}{l1}{origyear}), 'Date format test 1a - ORIGYEAR undef since ORIGDATE is bad' ) ;
ok(! defined($biber->{bib}{l1}{urlyear}), 'Date format test 1b - URLYEAR undef since URLDATE is bad' ) ;
ok(! defined($biber->{bib}{l1}{month}), 'Date format test 1c - MONTH undef since not integer' ) ;
is($biber->{bib}{l2}{warnings}, $l2, 'Date format test 2' ) ;
is($biber->{bib}{l3}{warnings}, $l3, 'Date format test 3' ) ;
is($biber->{bib}{l4}{warnings}, $l4, 'Date format test 4' ) ;
is($biber->{bib}{l5}{warnings}, $l5, 'Date format test 5' ) ;
is($biber->{bib}{l6}{warnings}, $l6, 'Date format test 6' ) ;
is($biber->{bib}{l7}{warnings}, $l7, 'Date format test 7' ) ;
is($biber->{bib}{l8}{warnings}, $l8, 'Date format test 8' ) ;
ok(! defined($biber->{bib}{l8}{year}), 'Date format test 8a - YEAR undef since not integer' ) ;
ok(! defined($biber->{bib}{l8}{month}), 'Date format test 8b - MONTH undef since not integer' ) ;
ok(! defined($biber->{bib}{l9}{warnings}), 'Date format test 9' ) ;
ok(! defined($biber->{bib}{l10}{warnings}), 'Date format test 10' ) ;
is($biber->{bib}{l11}{warnings}, $l11, 'Date format test 11' ) ;
is($biber->{bib}{l11}{year}, '1996', 'Date format test 11a - DATE overrides YEAR' ) ;
is($biber->{bib}{l12}{warnings}, $l12, 'Date format test 12' ) ;
is($biber->{bib}{l12}{month}, '01', 'Date format test 12a - DATE overrides MONTH' ) ;
is($biber->{bib}{l13}{endyear}, '', 'Date format test 13 - range with no end' ) ;
ok(! defined($biber->{bib}{l13}{endmonth}), 'Date format test 13a - ENDMONTH undef for open-ended range' ) ;
ok(! defined($biber->{bib}{l13}{endday}), 'Date format test 13b - ENDDAY undef for open-ended range' ) ;
is( $biber->_print_biblatex_entry('l13'), $l13c, 'Date format test 13c - labelyear open-ended range' ) ;
is( $biber->_print_biblatex_entry('l14'), $l14, 'Date format test 14 - labelyear same as YEAR when ENDYEAR == YEAR') ;
is( $biber->_print_biblatex_entry('l15'), $l15, 'Date format test 15 - labelyear should be undef, no DATE or YEAR') ;

Biber::Config->setblxoption('labelyear', [ 'year', 'eventyear', 'origyear' ]);
delete $biber->{bib}{l17}{year};
delete $biber->{bib}{l17}{month};
$biber->prepare;

is($biber->{bib}{l16}{labelyearname}, 'eventyear', 'Date format test 16 - labelyearname = eventyear' ) ;
is($biber->_print_biblatex_entry('l16'), $l16, 'Date format test 16a - labelyear = eventyear value' ) ;
is($biber->{bib}{l17}{labelyearname}, 'year', 'Date format test 17 - labelyearname = YEAR' ) ;
is($biber->_print_biblatex_entry('l17'), $l17, 'Date format test 17a - labelyear = YEAR value when ENDYEAR is the same and ORIGYEAR is also present' ) ;


Biber::Config->setblxoption('labelyear', [ 'origyear', 'year', 'eventyear' ]);
delete $biber->{bib}{l17}{year};
delete $biber->{bib}{l17}{month};
$biber->prepare;

is($biber->{bib}{l17}{labelyearname}, 'origyear', 'Date format test 17b - labelyearname = ORIGYEAR' ) ;
is($biber->_print_biblatex_entry('l17'), $l17c, 'Date format test 17c - labelyear = ORIGYEAR value when ENDORIGYEAR is the same and YEAR is also present' ) ;

Biber::Config->setblxoption('labelyear', [ 'eventyear', 'year', 'origyear' ], 'PER_TYPE', 'book');
delete $biber->{bib}{l17}{year};
delete $biber->{bib}{l17}{month};
$biber->prepare;

is($biber->{bib}{l17}{labelyearname}, 'eventyear', 'Date format test 17d - labelyearname = EVENTYEAR' ) ;
is($biber->_print_biblatex_entry('l17'), $l17e, 'Date format test 17e - labelyear = ORIGYEAR-ORIGENDYEAR' ) ;


unlink "$bibfile.utf8";
