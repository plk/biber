# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 3;
use Test::Differences;
unified_diff;

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

$biber->parse_ctrlfile('set-legacy.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');

# Now generate the information
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $main = $biber->datalists->get_list('none/global//global/global/global');
my $out = $biber->get_output_obj;

my $string1 = q|    \entry{Elias1955}{set}{}{}
      \set{Elias1955a,Elias1955b}
      \field{sortinit}{1}
      \field{sortinithash}{4f6aaa89bab872aa0999fec09ff8e98a}
    \endentry
|;

my $string2 = q|    \entry{Elias1955a}{article}{skipbib=true,skipbiblist=true,skiplab=true,uniquelist=false,uniquename=false}{}
      \inset{Elias1955}
      \name{author}{1}{}{%
        {{hash=68f587f427e068e26043d54745351d58}{%
           family={Elias},
           familyi={E\bibinitperiod},
           given={P.},
           giveni={P\bibinitperiod}}}%
      }
      \strng{namehash}{68f587f427e068e26043d54745351d58}
      \strng{fullhash}{68f587f427e068e26043d54745351d58}
      \strng{fullhashraw}{68f587f427e068e26043d54745351d58}
      \strng{bibnamehash}{68f587f427e068e26043d54745351d58}
      \strng{authorbibnamehash}{68f587f427e068e26043d54745351d58}
      \strng{authornamehash}{68f587f427e068e26043d54745351d58}
      \strng{authorfullhash}{68f587f427e068e26043d54745351d58}
      \strng{authorfullhashraw}{68f587f427e068e26043d54745351d58}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{issn}{0096-1000}
      \field{journaltitle}{IRE Transactions on Information Theory}
      \field{month}{3}
      \field{number}{1}
      \field{title}{Predictive coding--I}
      \field{volume}{1}
      \field{year}{1955}
      \field{pages}{16\bibrangedash 24}
      \range{pages}{9}
      \verb{doi}
      \verb 10.1109/TIT.1955.1055126
      \endverb
      \warn{\item Field 'entryset' is no longer needed in set member entries in Biber - ignoring in entry 'Elias1955a'}
    \endentry
|;

my $string3 = q|    \entry{Elias1955b}{article}{skipbib=true,skipbiblist=true,skiplab=true,uniquelist=false,uniquename=false}{}
      \inset{Elias1955}
      \name{author}{1}{}{%
        {{hash=68f587f427e068e26043d54745351d58}{%
           family={Elias},
           familyi={E\bibinitperiod},
           given={P.},
           giveni={P\bibinitperiod}}}%
      }
      \strng{namehash}{68f587f427e068e26043d54745351d58}
      \strng{fullhash}{68f587f427e068e26043d54745351d58}
      \strng{fullhashraw}{68f587f427e068e26043d54745351d58}
      \strng{bibnamehash}{68f587f427e068e26043d54745351d58}
      \strng{authorbibnamehash}{68f587f427e068e26043d54745351d58}
      \strng{authornamehash}{68f587f427e068e26043d54745351d58}
      \strng{authorfullhash}{68f587f427e068e26043d54745351d58}
      \strng{authorfullhashraw}{68f587f427e068e26043d54745351d58}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{issn}{0096-1000}
      \field{journaltitle}{IRE Transactions on Information Theory}
      \field{month}{3}
      \field{number}{1}
      \field{title}{Predictive coding--II}
      \field{volume}{1}
      \field{year}{1955}
      \field{pages}{24\bibrangedash 33}
      \range{pages}{10}
      \verb{doi}
      \verb 10.1109/TIT.1955.1055116
      \endverb
      \warn{\item Field 'entryset' is no longer needed in set member entries in Biber - ignoring in entry 'Elias1955b'}
    \endentry
|;

eq_or_diff($out->get_output_entry('Elias1955', $main), $string1, 'Legacy set test 1');
eq_or_diff($out->get_output_entry('Elias1955a', $main), $string2, 'Legacy set test 2');
eq_or_diff($out->get_output_entry('Elias1955b', $main), $string3, 'Legacy set test 3');

