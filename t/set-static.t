# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 5;

use Biber;
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

$biber->parse_ctrlfile('set-static.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('sortlocale', 'C');
Biber::Config->setoption('fastsort', 1);

# Now generate the information
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $main = $biber->sortlists->get_list(0, 'nty', 'entry', 'nty');
my $out = $biber->get_output_obj;

my $string1 = q|    \entry{Static1}{set}{}
      \set{Static2,Static3,Static4}
      \name{labelname}{1}{}{%
        {{hash=43874d80d7ce68027102819f16c47df1}{Bumble}{B\bibinitperiod}{Brian}{B\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{hash=43874d80d7ce68027102819f16c47df1}{Bumble}{B\bibinitperiod}{Brian}{B\bibinitperiod}{}{}{}{}}%
      }
      \strng{namehash}{43874d80d7ce68027102819f16c47df1}
      \strng{fullhash}{43874d80d7ce68027102819f16c47df1}
      \field{sortinit}{0}
      \field{sortinithash}{a08a9549c5c2429f8cec5d1a581b26ca}
      \field{labelyear}{2001}
      \field{datelabelsource}{}
      \field{labeltitle}{Blessed Brains}
      \field{annotation}{Some notes}
      \field{title}{Blessed Brains}
      \field{year}{2001}
    \endentry
|;

my $string2 = q|    \entry{Static2}{book}{}
      \inset{Static1}
      \name{labelname}{1}{}{%
        {{hash=43874d80d7ce68027102819f16c47df1}{Bumble}{B\bibinitperiod}{Brian}{B\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{hash=43874d80d7ce68027102819f16c47df1}{Bumble}{B\bibinitperiod}{Brian}{B\bibinitperiod}{}{}{}{}}%
      }
      \strng{namehash}{43874d80d7ce68027102819f16c47df1}
      \strng{fullhash}{43874d80d7ce68027102819f16c47df1}
      \field{sortinit}{0}
      \field{sortinithash}{a08a9549c5c2429f8cec5d1a581b26ca}
      \field{labeltitle}{Blessed Brains}
      \field{annotation}{Some Blessed Note}
      \field{title}{Blessed Brains}
      \field{year}{2001}
    \endentry
|;

my $string3 = q|    \entry{Static3}{book}{}
      \inset{Static1}
      \name{labelname}{1}{}{%
        {{hash=da80091c8cd89e5269bd55af1bd5d2fa}{Crenellation}{C\bibinitperiod}{Clive}{C\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{hash=da80091c8cd89e5269bd55af1bd5d2fa}{Crenellation}{C\bibinitperiod}{Clive}{C\bibinitperiod}{}{}{}{}}%
      }
      \strng{namehash}{da80091c8cd89e5269bd55af1bd5d2fa}
      \strng{fullhash}{da80091c8cd89e5269bd55af1bd5d2fa}
      \field{sortinit}{0}
      \field{sortinithash}{a08a9549c5c2429f8cec5d1a581b26ca}
      \field{labeltitle}{Castles and Crime}
      \field{title}{Castles and Crime}
      \field{year}{2002}
    \endentry
|;

my $string4 = q|    \entry{Static4}{book}{}
      \inset{Static1}
      \name{labelname}{1}{}{%
        {{hash=22dafa5cd57bb5dd7f3e3bab98fd539c}{Dingle}{D\bibinitperiod}{Derek}{D\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{hash=22dafa5cd57bb5dd7f3e3bab98fd539c}{Dingle}{D\bibinitperiod}{Derek}{D\bibinitperiod}{}{}{}{}}%
      }
      \strng{namehash}{22dafa5cd57bb5dd7f3e3bab98fd539c}
      \strng{fullhash}{22dafa5cd57bb5dd7f3e3bab98fd539c}
      \field{sortinit}{0}
      \field{sortinithash}{a08a9549c5c2429f8cec5d1a581b26ca}
      \field{labeltitle}{Dungeons, Dark and Dangerous}
      \field{title}{Dungeons, Dark and Dangerous}
      \field{year}{2005}
    \endentry
|;

# Labelyear is now here as skiplab is not set for this entry when cited in section
# without citation of a set it is a member of
my $string5 = q|    \entry{Static2}{book}{}
      \name{labelname}{1}{}{%
        {{hash=43874d80d7ce68027102819f16c47df1}{Bumble}{B\bibinitperiod}{Brian}{B\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{hash=43874d80d7ce68027102819f16c47df1}{Bumble}{B\bibinitperiod}{Brian}{B\bibinitperiod}{}{}{}{}}%
      }
      \strng{namehash}{43874d80d7ce68027102819f16c47df1}
      \strng{fullhash}{43874d80d7ce68027102819f16c47df1}
      \field{sortinit}{0}
      \field{sortinithash}{a08a9549c5c2429f8cec5d1a581b26ca}
      \field{labelyear}{2001}
      \field{datelabelsource}{}
      \field{labeltitle}{Blessed Brains}
      \field{annotation}{Some Blessed Note}
      \field{title}{Blessed Brains}
      \field{year}{2001}
    \endentry
|;


is($out->get_output_entry('Static1', $main), $string1, 'Static set test 1');
is($out->get_output_entry('Static2', $main), $string2, 'Static set test 2');
is($out->get_output_entry('Static3', $main), $string3, 'Static set test 3');
is($out->get_output_entry('Static4', $main), $string4, 'Static set test 4');
is($out->get_output_entry('Static2', $main, 1), $string5, 'Static set test 5');

