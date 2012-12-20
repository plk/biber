# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 31;

use Biber;
use Biber::Output::bbl;
use Biber::Utils;
use Log::Log4perl;
chdir("t/tdata");

# Set up Biber object
my $biber = Biber->new(noconf => 1);
my $LEVEL = 'ERROR';
my $l4pconf = qq|
    log4perl.category.main                             = $LEVEL, Screen
    log4perl.category.screen                           = $LEVEL, Screen
    log4perl.appender.Screen                           = Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.utf8                      = 1
    log4perl.appender.Screen.Threshold                 = $LEVEL
    log4perl.appender.Screen.stderr                    = 0
    log4perl.appender.Screen.layout                    = Log::Log4perl::Layout::SimpleLayout
|;
Log::Log4perl->init(\$l4pconf);

$biber->parse_ctrlfile('dm-dateformats.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'C');
Biber::Config->setoption('validate_datamodel', 1);

# Biblatex options
Biber::Config->setblxoption('labelyearspec', [ {content => 'year'} ]);

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $main = $biber->sortlists->get_list(0, 'entry', 'nty');
my $bibentries = $section->bibentries;
my $l1 = [ "Invalid format '1985-1030' of date field 'origdate' in entry 'L1' - ignoring",
           "Invalid format '1.5.1998' of date field 'urldate' in entry 'L1' - ignoring",
           "Invalid date value 'YYYY/14/DD' - ignoring its components in entry 'L1'" ];
my $l2 = [ "Invalid format '1995-1230' of date field 'origdate' in entry 'L2' - ignoring" ];
my $l3 = [ "Invalid format '1.5.1988' of date field 'urldate' in entry 'L3' - ignoring" ];
my $l4 = [ "Invalid format '1995-1-04' of date field 'date' in entry 'L4' - ignoring",
           "Missing mandatory field - one of 'date, year' must be defined in entry 'L4'" ];
my $l5 = [ "Invalid format '1995-10-4' of date field 'date' in entry 'L5' - ignoring",
           "Missing mandatory field - one of 'date, year' must be defined in entry 'L5'" ];
my $l6 = [ "Invalid date value '1996/13/03' - ignoring its components in entry 'L6'" ];
my $l7 = [ "Invalid date value '1996/10/35' - ignoring its components in entry 'L7'" ];
my $l11 = [ "Overwriting field 'year' with year value from field 'date' for entry 'L11'"];
my $l12 = [ "Overwriting field 'month' with month value from field 'date' for entry 'L12'" ];

my $l13c = q|    \entry{L13}{book}{}
      \name{labelname}{2}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
        {{hash=df9bf04cd41245e6d23ad7543e7fd90d}{Abrahams}{A\bibinitperiod}{Albert}{A\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{2}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
        {{hash=df9bf04cd41245e6d23ad7543e7fd90d}{Abrahams}{A\bibinitperiod}{Albert}{A\bibinitperiod}{}{}{}{}}%
      }
      \list{publisher}{1}{%
        {Oxford}%
      }
      \strng{namehash}{8c77336299b25bdada7bf8038f46722f}
      \strng{fullhash}{8c77336299b25bdada7bf8038f46722f}
      \field{sortinit}{D}
      \field{extrayear}{3}
      \field{labelyear}{1996}
      \field{labeltitle}{Title 2}
      \field{day}{01}
      \field{endyear}{}
      \field{month}{01}
      \field{title}{Title 2}
      \field{year}{1996}
    \endentry
|;

my $l14 = q|    \entry{L14}{book}{}
      \name{labelname}{2}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
        {{hash=df9bf04cd41245e6d23ad7543e7fd90d}{Abrahams}{A\bibinitperiod}{Albert}{A\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{2}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
        {{hash=df9bf04cd41245e6d23ad7543e7fd90d}{Abrahams}{A\bibinitperiod}{Albert}{A\bibinitperiod}{}{}{}{}}%
      }
      \list{publisher}{1}{%
        {Oxford}%
      }
      \strng{namehash}{8c77336299b25bdada7bf8038f46722f}
      \strng{fullhash}{8c77336299b25bdada7bf8038f46722f}
      \field{sortinit}{D}
      \field{extrayear}{4}
      \field{labelyear}{1996}
      \field{labeltitle}{Title 2}
      \field{day}{10}
      \field{endday}{12}
      \field{endmonth}{12}
      \field{endyear}{1996}
      \field{month}{12}
      \field{title}{Title 2}
      \field{year}{1996}
    \endentry
|;

my $l15 = q|    \entry{L15}{book}{}
      \name{labelname}{2}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
        {{hash=df9bf04cd41245e6d23ad7543e7fd90d}{Abrahams}{A\bibinitperiod}{Albert}{A\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{2}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
        {{hash=df9bf04cd41245e6d23ad7543e7fd90d}{Abrahams}{A\bibinitperiod}{Albert}{A\bibinitperiod}{}{}{}{}}%
      }
      \list{publisher}{1}{%
        {Oxford}%
      }
      \strng{namehash}{8c77336299b25bdada7bf8038f46722f}
      \strng{fullhash}{8c77336299b25bdada7bf8038f46722f}
      \field{sortinit}{D}
      \field{extrayear}{4}
      \field{labeltitle}{Title 2}
      \field{title}{Title 2}
      \warn{\item Missing mandatory field - one of 'date, year' must be defined in entry 'L15'}
    \endentry
|;

my $l16 = q|    \entry{L16}{proceedings}{}
      \name{labelname}{2}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
        {{hash=df9bf04cd41245e6d23ad7543e7fd90d}{Abrahams}{A\bibinitperiod}{Albert}{A\bibinitperiod}{}{}{}{}}%
      }
      \name{editor}{2}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
        {{hash=df9bf04cd41245e6d23ad7543e7fd90d}{Abrahams}{A\bibinitperiod}{Albert}{A\bibinitperiod}{}{}{}{}}%
      }
      \list{publisher}{1}{%
        {Oxford}%
      }
      \strng{namehash}{8c77336299b25bdada7bf8038f46722f}
      \strng{fullhash}{8c77336299b25bdada7bf8038f46722f}
      \field{sortinit}{D}
      \field{extrayear}{6}
      \field{labelyear}{1996}
      \field{labeltitle}{Title 2}
      \field{eventday}{01}
      \field{eventmonth}{01}
      \field{eventyear}{1996}
      \field{title}{Title 2}
      \warn{\item Missing mandatory field - one of 'date, year' must be defined in entry 'L16'}
    \endentry
|;

my $l17 = q|    \entry{L17}{proceedings}{}
      \name{labelname}{2}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
        {{hash=df9bf04cd41245e6d23ad7543e7fd90d}{Abrahams}{A\bibinitperiod}{Albert}{A\bibinitperiod}{}{}{}{}}%
      }
      \name{editor}{2}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
        {{hash=df9bf04cd41245e6d23ad7543e7fd90d}{Abrahams}{A\bibinitperiod}{Albert}{A\bibinitperiod}{}{}{}{}}%
      }
      \list{publisher}{1}{%
        {Oxford}%
      }
      \strng{namehash}{8c77336299b25bdada7bf8038f46722f}
      \strng{fullhash}{8c77336299b25bdada7bf8038f46722f}
      \field{sortinit}{D}
      \field{extrayear}{5}
      \field{labelyear}{1996}
      \field{labeltitle}{Title 2}
      \field{day}{10}
      \field{endday}{12}
      \field{endmonth}{12}
      \field{endyear}{1996}
      \field{eventday}{10}
      \field{eventendday}{12}
      \field{eventendmonth}{12}
      \field{eventendyear}{2004}
      \field{eventmonth}{12}
      \field{eventyear}{1998}
      \field{month}{12}
      \field{origday}{10}
      \field{origendday}{12}
      \field{origendmonth}{12}
      \field{origendyear}{1998}
      \field{origmonth}{12}
      \field{origyear}{1998}
      \field{title}{Title 2}
      \field{year}{1996}
    \endentry
|;

my $l17c = q|    \entry{L17}{proceedings}{}
      \name{labelname}{2}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
        {{hash=df9bf04cd41245e6d23ad7543e7fd90d}{Abrahams}{A\bibinitperiod}{Albert}{A\bibinitperiod}{}{}{}{}}%
      }
      \name{editor}{2}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
        {{hash=df9bf04cd41245e6d23ad7543e7fd90d}{Abrahams}{A\bibinitperiod}{Albert}{A\bibinitperiod}{}{}{}{}}%
      }
      \list{publisher}{1}{%
        {Oxford}%
      }
      \strng{namehash}{8c77336299b25bdada7bf8038f46722f}
      \strng{fullhash}{8c77336299b25bdada7bf8038f46722f}
      \field{sortinit}{D}
      \field{labelyear}{1998}
      \field{labeltitle}{Title 2}
      \field{day}{10}
      \field{endday}{12}
      \field{endmonth}{12}
      \field{endyear}{1996}
      \field{eventday}{10}
      \field{eventendday}{12}
      \field{eventendmonth}{12}
      \field{eventendyear}{2004}
      \field{eventmonth}{12}
      \field{eventyear}{1998}
      \field{month}{12}
      \field{origday}{10}
      \field{origendday}{12}
      \field{origendmonth}{12}
      \field{origendyear}{1998}
      \field{origmonth}{12}
      \field{origyear}{1998}
      \field{title}{Title 2}
      \field{year}{1996}
    \endentry
|;

my $l17e = q|    \entry{L17}{proceedings}{}
      \name{labelname}{2}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
        {{hash=df9bf04cd41245e6d23ad7543e7fd90d}{Abrahams}{A\bibinitperiod}{Albert}{A\bibinitperiod}{}{}{}{}}%
      }
      \name{editor}{2}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
        {{hash=df9bf04cd41245e6d23ad7543e7fd90d}{Abrahams}{A\bibinitperiod}{Albert}{A\bibinitperiod}{}{}{}{}}%
      }
      \list{publisher}{1}{%
        {Oxford}%
      }
      \strng{namehash}{8c77336299b25bdada7bf8038f46722f}
      \strng{fullhash}{8c77336299b25bdada7bf8038f46722f}
      \field{sortinit}{D}
      \field{labelyear}{1998\bibdatedash 2004}
      \field{labeltitle}{Title 2}
      \field{day}{10}
      \field{endday}{12}
      \field{endmonth}{12}
      \field{endyear}{1996}
      \field{eventday}{10}
      \field{eventendday}{12}
      \field{eventendmonth}{12}
      \field{eventendyear}{2004}
      \field{eventmonth}{12}
      \field{eventyear}{1998}
      \field{month}{12}
      \field{origday}{10}
      \field{origendday}{12}
      \field{origendmonth}{12}
      \field{origendyear}{1998}
      \field{origmonth}{12}
      \field{origyear}{1998}
      \field{title}{Title 2}
      \field{year}{1996}
    \endentry
|;

is_deeply($bibentries->entry('L1')->get_field('warnings'), $l1, 'Date values test 1' ) ;
ok(is_undef($bibentries->entry('L1')->get_field('origyear')), 'Date values test 1a - ORIGYEAR undef since ORIGDATE is bad' ) ;
ok(is_undef($bibentries->entry('L1')->get_field('urlyear')), 'Date values test 1b - URLYEAR undef since URLDATE is bad' ) ;
ok(is_undef($bibentries->entry('L1')->get_field('month')), 'Date values test 1c - MONTH undef since not integer' ) ;
is_deeply($bibentries->entry('L2')->get_field('warnings'), $l2, 'Date values test 2' ) ;
is_deeply($bibentries->entry('L3')->get_field('warnings'), $l3, 'Date values test 3' ) ;
is_deeply($bibentries->entry('L4')->get_field('warnings'), $l4, 'Date values test 4' ) ;
is_deeply($bibentries->entry('L5')->get_field('warnings'), $l5, 'Date values test 5' ) ;
is_deeply($bibentries->entry('L6')->get_field('warnings'), $l6, 'Date values test 6' ) ;
is_deeply($bibentries->entry('L7')->get_field('warnings'), $l7, 'Date values test 7' ) ;
is($bibentries->entry('L8')->get_field('month'), '01', 'Date values test 8b - MONTH hacked to integer' ) ;
ok(is_undef($bibentries->entry('L9')->get_field('warnings')), 'Date values test 9' ) ;
ok(is_undef($bibentries->entry('L10')->get_field('warnings')), 'Date values test 10' ) ;
is_deeply($bibentries->entry('L11')->get_field('warnings'), $l11, 'Date values test 11' );
is($bibentries->entry('L11')->get_field('year'), '1996', 'Date values test 11a - DATE overrides YEAR' ) ;
is_deeply($bibentries->entry('L12')->get_field('warnings'), $l12, 'Date values test 12' );
is($bibentries->entry('L12')->get_field('month'), '01', 'Date values test 12a - DATE overrides MONTH' ) ;
# it means something if endyear is defined but null ("1935-")
ok(is_def_and_null($bibentries->entry('L13')->get_field('endyear')), 'Date values test 13 - range with no end' ) ;
ok(is_undef($bibentries->entry('L13')->get_field('endmonth')), 'Date values test 13a - ENDMONTH undef for open-ended range' ) ;
ok(is_undef($bibentries->entry('L13')->get_field('endday')), 'Date values test 13b - ENDDAY undef for open-ended range' ) ;
is( $out->get_output_entry('L13', $main), $l13c, 'Date values test 13c - labelyear open-ended range' ) ;
is( $out->get_output_entry('L14', $main), $l14, 'Date values test 14 - labelyear same as YEAR when ENDYEAR == YEAR') ;
is( $out->get_output_entry('L15', $main), $l15, 'Date values test 15 - labelyear should be undef, no DATE or YEAR') ;

# reset options and regenerate information
Biber::Config->setblxoption('labelyearspec', [ {content => 'year'},
                                               {content => 'eventyear'},
                                               {content => 'origyear'} ]);
$bibentries->del_entry('L17');
$bibentries->del_entry('L16');
$biber->prepare;
$out = $biber->get_output_obj;

is($bibentries->entry('L16')->get_labelyear_info->{field}, 'eventyear', 'Date values test 16 - labelyearname = eventyear when YEAR is (mistakenly) missing' ) ;
is($out->get_output_entry('L16', $main), $l16, 'Date values test 16a - labelyear = EVENTYEAR value when YEAR is (mistakenly) missing' );
is($bibentries->entry('L17')->get_labelyear_info->{field}, 'year', 'Date values test 17 - labelyearname = YEAR' ) ;
is($out->get_output_entry('L17', $main), $l17, 'Date values test 17a - labelyear = YEAR value when ENDYEAR is the same and ORIGYEAR is also present' ) ;

# reset options and regenerate information
Biber::Config->setblxoption('labelyearspec', [ {content => 'origyear'},
                                               {content => 'year'},
                                               {content => 'eventyear'} ]);
$bibentries->del_entry('L17');
$biber->prepare;
$out = $biber->get_output_obj;

is($bibentries->entry('L17')->get_labelyear_info->{field}, 'origyear', 'Date values test 17b - labelyearname = ORIGYEAR' ) ;
is($out->get_output_entry('L17', $main), $l17c, 'Date values test 17c - labelyear = ORIGYEAR value when ENDORIGYEAR is the same and YEAR is also present' ) ;

# reset options and regenerate information
Biber::Config->setblxoption('labelyearspec', [ {content => 'eventyear'},
                                               {content => 'year'},
                                               {content => 'origyear'} ], 'PER_TYPE', 'proceedings');
$bibentries->del_entry('L17');
$biber->prepare;
$out = $biber->get_output_obj;

is($bibentries->entry('L17')->get_labelyear_info->{field}, 'eventyear', 'Date values test 17d - labelyearname = EVENTYEAR' ) ;
is($out->get_output_entry('L17', $main), $l17e, 'Date values test 17e - labelyear = ORIGYEAR-ORIGENDYEAR' ) ;

