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
my $bibentries = $biber->bib;

my $l1 = [ "Invalid format of field 'year' - ignoring field",
           "Invalid format of field 'origdate' - ignoring field",
           "Invalid format of field 'urldate' - ignoring field",
           "Value out of bounds for field/date component 'month' - ignoring" ];
my $l2 = [ "Invalid format of field 'origdate' - ignoring field" ];
my $l3 = [ "Invalid format of field 'urldate' - ignoring field" ];
my $l4 = [ "Invalid format of field 'date' - ignoring field" ];
my $l5 = [ "Invalid format of field 'date' - ignoring field" ];
my $l6 = [ "Value out of bounds for field/date component 'month' - ignoring" ];
my $l7 = [ "Value out of bounds for field/date component 'eventday' - ignoring" ];
my $l8 = [ "Invalid format of field 'year' - ignoring field",
           "Invalid format of field 'month' - ignoring field" ];
my $l11 = [ "Field conflict - both 'date' and 'year' used - ignoring field 'year'" ];
my $l12 = [ "Field conflict - both 'date' and 'month' used - ignoring field 'month'" ];

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


is_deeply($bibentries->entry('l1')->get_field('warnings'), $l1, 'Date format test 1' ) ;
is($bibentries->entry('l1')->get_field('origyear'), '', 'Date format test 1a - ORIGYEAR undef since ORIGDATE is bad' ) ;
is($bibentries->entry('l1')->get_field('urlyear'), '', 'Date format test 1b - URLYEAR undef since URLDATE is bad' ) ;
is($bibentries->entry('l1')->get_field('month'), '', 'Date format test 1c - MONTH undef since not integer' ) ;
is_deeply($bibentries->entry('l2')->get_field('warnings'), $l2, 'Date format test 2' ) ;
is_deeply($bibentries->entry('l3')->get_field('warnings'), $l3, 'Date format test 3' ) ;
is_deeply($bibentries->entry('l4')->get_field('warnings'), $l4, 'Date format test 4' ) ;
is_deeply($bibentries->entry('l5')->get_field('warnings'), $l5, 'Date format test 5' ) ;
is_deeply($bibentries->entry('l6')->get_field('warnings'), $l6, 'Date format test 6' ) ;
is_deeply($bibentries->entry('l7')->get_field('warnings'), $l7, 'Date format test 7' ) ;
is_deeply($bibentries->entry('l8')->get_field('warnings'), $l8, 'Date format test 8' ) ;
is($bibentries->entry('l8')->get_field('year'), '', 'Date format test 8a - YEAR undef since not integer' ) ;
is($bibentries->entry('l8')->get_field('month'), '', 'Date format test 8b - MONTH undef since not integer' ) ;
is($bibentries->entry('l9')->get_field('warnings'), '', 'Date format test 9' ) ;
is($bibentries->entry('l10')->get_field('warnings'), '', 'Date format test 10' ) ;
is_deeply($bibentries->entry('l11')->get_field('warnings'), $l11, 'Date format test 11' );
is($bibentries->entry('l11')->get_field('year'), '1996', 'Date format test 11a - DATE overrides YEAR' ) ;
is_deeply($bibentries->entry('l12')->get_field('warnings'), $l12, 'Date format test 12' );
is($bibentries->entry('l12')->get_field('month'), '01', 'Date format test 12a - DATE overrides MONTH' ) ;
is($bibentries->entry('l13')->get_field('endyear'), '', 'Date format test 13 - range with no end' ) ;
is($bibentries->entry('l13')->get_field('endmonth'), '', 'Date format test 13a - ENDMONTH undef for open-ended range' ) ;
is($bibentries->entry('l13')->get_field('endday'), '', 'Date format test 13b - ENDDAY undef for open-ended range' ) ;
is( $biber->_print_biblatex_entry('l13'), $l13c, 'Date format test 13c - labelyear open-ended range' ) ;
is( $biber->_print_biblatex_entry('l14'), $l14, 'Date format test 14 - labelyear same as YEAR when ENDYEAR == YEAR') ;
is( $biber->_print_biblatex_entry('l15'), $l15, 'Date format test 15 - labelyear should be undef, no DATE or YEAR') ;

Biber::Config->setblxoption('labelyear', [ 'year', 'eventyear', 'origyear' ]);
$bibentries->entry('l17')->del_field('year');
$bibentries->entry('l17')->del_field('month');
$biber->prepare;

is($bibentries->entry('l16')->get_field('labelyearname'), 'eventyear', 'Date format test 16 - labelyearname = eventyear' ) ;
is($biber->_print_biblatex_entry('l16'), $l16, 'Date format test 16a - labelyear = eventyear value' ) ;
is($bibentries->entry('l17')->get_field('labelyearname'), 'year', 'Date format test 17 - labelyearname = YEAR' ) ;
is($biber->_print_biblatex_entry('l17'), $l17, 'Date format test 17a - labelyear = YEAR value when ENDYEAR is the same and ORIGYEAR is also present' ) ;


Biber::Config->setblxoption('labelyear', [ 'origyear', 'year', 'eventyear' ]);
$bibentries->entry('l17')->del_field('year');
$bibentries->entry('l17')->del_field('month');
$biber->prepare;

is($bibentries->entry('l17')->get_field('labelyearname'), 'origyear', 'Date format test 17b - labelyearname = ORIGYEAR' ) ;
is($biber->_print_biblatex_entry('l17'), $l17c, 'Date format test 17c - labelyear = ORIGYEAR value when ENDORIGYEAR is the same and YEAR is also present' ) ;

Biber::Config->setblxoption('labelyear', [ 'eventyear', 'year', 'origyear' ], 'PER_TYPE', 'book');
$bibentries->entry('l17')->del_field('year');
$bibentries->entry('l17')->del_field('month');
$biber->prepare;

is($bibentries->entry('l17')->get_field('labelyearname'), 'eventyear', 'Date format test 17d - labelyearname = EVENTYEAR' ) ;
is($biber->_print_biblatex_entry('l17'), $l17e, 'Date format test 17e - labelyear = ORIGYEAR-ORIGENDYEAR' ) ;


unlink "$bibfile.utf8";
