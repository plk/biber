# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 8;
use Test::Differences;
unified_diff;

use Biber;
use Biber::Utils;
use Biber::Output::bbl;
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

$biber->parse_ctrlfile('uniqueness-nameparts.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');

# Biblatex options
Biber::Config->setblxoption('uniquename', 2);

# Now generate the information
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $bibentries = $section->bibentries;
my $main = $biber->sortlists->get_list(0, 'nty/global/', 'entry', 'nty', 'global' ,'');
my $out = $biber->get_output_obj;
my $un1 = q|    \entry{un1}{article}{}
      \name{author}{1}{}{%
        {{uniquename=1,hash=329d8f9192ea3349d700160c9ddb505d}{%
           family={Smith},
           familyi={S\bibinitperiod},
           familyun=0,
           given={John},
           giveni={J\bibinitperiod},
           givenun=1,
           middle={Simon},
           middlei={S\bibinitperiod},
           middleun=1}}%
      }
      \strng{namehash}{329d8f9192ea3349d700160c9ddb505d}
      \strng{fullhash}{329d8f9192ea3349d700160c9ddb505d}
      \strng{bibnamehash}{329d8f9192ea3349d700160c9ddb505d}
      \strng{authorbibnamehash}{329d8f9192ea3349d700160c9ddb505d}
      \strng{authornamehash}{329d8f9192ea3349d700160c9ddb505d}
      \strng{authorfullhash}{329d8f9192ea3349d700160c9ddb505d}
      \field{labelalpha}{Smi}
      \field{sortinit}{S}
      \field{sortinithash}{3c1547c63380458f8ca90e40ed14b83e}
      \field{extraalpha}{2}
      \field{labelnamesource}{author}
    \endentry
|;

my $un2 = q|    \entry{un2}{article}{}
      \name{author}{1}{}{%
        {{uniquename=2,hash=7551114aede4ef69e4b3683039801706}{%
           family={Smith},
           familyi={S\bibinitperiod},
           familyun=0,
           given={John},
           giveni={J\bibinitperiod},
           givenun=1,
           middle={Alan},
           middlei={A\bibinitperiod},
           middleun=2}}%
      }
      \strng{namehash}{7551114aede4ef69e4b3683039801706}
      \strng{fullhash}{7551114aede4ef69e4b3683039801706}
      \strng{bibnamehash}{7551114aede4ef69e4b3683039801706}
      \strng{authorbibnamehash}{7551114aede4ef69e4b3683039801706}
      \strng{authornamehash}{7551114aede4ef69e4b3683039801706}
      \strng{authorfullhash}{7551114aede4ef69e4b3683039801706}
      \field{labelalpha}{Smi}
      \field{sortinit}{S}
      \field{sortinithash}{3c1547c63380458f8ca90e40ed14b83e}
      \field{extraalpha}{3}
      \field{labelnamesource}{author}
    \endentry
|;

my $un3 = q|    \entry{un3}{article}{}
      \name{author}{1}{}{%
        {{uniquename=2,hash=401aebda288799a7c757526242d8c9fc}{%
           family={Smith},
           familyi={S\bibinitperiod},
           familyun=0,
           given={John},
           giveni={J\bibinitperiod},
           givenun=1,
           middle={Arthur},
           middlei={A\bibinitperiod},
           middleun=2}}%
      }
      \strng{namehash}{401aebda288799a7c757526242d8c9fc}
      \strng{fullhash}{401aebda288799a7c757526242d8c9fc}
      \strng{bibnamehash}{401aebda288799a7c757526242d8c9fc}
      \strng{authorbibnamehash}{401aebda288799a7c757526242d8c9fc}
      \strng{authornamehash}{401aebda288799a7c757526242d8c9fc}
      \strng{authorfullhash}{401aebda288799a7c757526242d8c9fc}
      \field{labelalpha}{Smi}
      \field{sortinit}{S}
      \field{sortinithash}{3c1547c63380458f8ca90e40ed14b83e}
      \field{extraalpha}{4}
      \field{labelnamesource}{author}
    \endentry
|;

my $un4 = q|    \entry{un4}{article}{}
      \name{author}{1}{}{%
        {{uniquename=1,hash=f6038a264619efefd49c7daac56424ca}{%
           family={Smith},
           familyi={S\bibinitperiod},
           familyun=0,
           given={Alan},
           giveni={A\bibinitperiod},
           givenun=1,
           middle={Simon},
           middlei={S\bibinitperiod},
           middleun=0}}%
      }
      \strng{namehash}{f6038a264619efefd49c7daac56424ca}
      \strng{fullhash}{f6038a264619efefd49c7daac56424ca}
      \strng{bibnamehash}{f6038a264619efefd49c7daac56424ca}
      \strng{authorbibnamehash}{f6038a264619efefd49c7daac56424ca}
      \strng{authornamehash}{f6038a264619efefd49c7daac56424ca}
      \strng{authorfullhash}{f6038a264619efefd49c7daac56424ca}
      \field{labelalpha}{Smi}
      \field{sortinit}{S}
      \field{sortinithash}{3c1547c63380458f8ca90e40ed14b83e}
      \field{extraalpha}{1}
      \field{labelnamesource}{author}
    \endentry
|;

eq_or_diff($bibentries->entry('un1')->get_field('author')->nth_name(1)->get_uniquename, ['middle', 'init'], 'Uniquename namepart - 1');
eq_or_diff($bibentries->entry('un2')->get_field('author')->nth_name(1)->get_uniquename, ['middle', 'full'], 'Uniquename namepart - 2');
eq_or_diff($bibentries->entry('un3')->get_field('author')->nth_name(1)->get_uniquename, ['middle', 'full'], 'Uniquename namepart - 3');
eq_or_diff($bibentries->entry('un4')->get_field('author')->nth_name(1)->get_uniquename, ['given', 'init'], 'Uniquename namepart - 4');
eq_or_diff($out->get_output_entry('un1', $main), $un1, 'Uniquename namepart - 5');
eq_or_diff($out->get_output_entry('un2', $main), $un2, 'Uniquename namepart - 6');
eq_or_diff($out->get_output_entry('un3', $main), $un3, 'Uniquename namepart - 7');
eq_or_diff($out->get_output_entry('un4', $main), $un4, 'Uniquename namepart - 8');
