# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 3;

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
Biber::Config->setoption('sortlocale', 'C');
Biber::Config->setoption('fastsort', 1);

# Now generate the information
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $main = $biber->sortlists->get_list(0, 'nty', 'entry', 'nty');
my $out = $biber->get_output_obj;

my $string1 = q|    \entry{Elias1955}{set}{}
      \set{Elias1955a,Elias1955b}
      \name{labelname}{1}{}{%
        {{hash=bdd4981ffb5a62685c993d6f9dec4c23}{Elias}{E\bibinitperiod}{P.}{P\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{hash=bdd4981ffb5a62685c993d6f9dec4c23}{Elias}{E\bibinitperiod}{P.}{P\bibinitperiod}{}{}{}{}}%
      }
      \strng{namehash}{bdd4981ffb5a62685c993d6f9dec4c23}
      \strng{fullhash}{bdd4981ffb5a62685c993d6f9dec4c23}
      \field{sortinit}{0}
      \field{sortinithash}{a08a9549c5c2429f8cec5d1a581b26ca}
      \field{labelyear}{1955}
      \field{labelmonth}{03}
      \field{datelabelsource}{}
      \field{labeltitle}{Predictive coding--I}
      \field{issn}{0096-1000}
      \field{journaltitle}{IRE Transactions on Information Theory}
      \field{month}{03}
      \field{number}{1}
      \field{title}{Predictive coding--I}
      \field{volume}{1}
      \field{year}{1955}
      \field{pages}{16\bibrangedash 24}
      \verb{doi}
      \verb 10.1109/TIT.1955.1055126
      \endverb
      \warn{\item Field 'crossref' is no longer needed in set entries in Biber - ignoring in entry 'Elias1955'}
    \endentry
|;

my $string2 = q|    \entry{Elias1955a}{article}{}
      \inset{Elias1955}
      \name{labelname}{1}{}{%
        {{hash=bdd4981ffb5a62685c993d6f9dec4c23}{Elias}{E\bibinitperiod}{P.}{P\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{hash=bdd4981ffb5a62685c993d6f9dec4c23}{Elias}{E\bibinitperiod}{P.}{P\bibinitperiod}{}{}{}{}}%
      }
      \strng{namehash}{bdd4981ffb5a62685c993d6f9dec4c23}
      \strng{fullhash}{bdd4981ffb5a62685c993d6f9dec4c23}
      \field{sortinit}{0}
      \field{sortinithash}{a08a9549c5c2429f8cec5d1a581b26ca}
      \field{labeltitle}{Predictive coding--I}
      \field{issn}{0096-1000}
      \field{journaltitle}{IRE Transactions on Information Theory}
      \field{month}{03}
      \field{number}{1}
      \field{title}{Predictive coding--I}
      \field{volume}{1}
      \field{year}{1955}
      \field{pages}{16\bibrangedash 24}
      \verb{doi}
      \verb 10.1109/TIT.1955.1055126
      \endverb
      \warn{\item Field 'entryset' is no longer needed in set member entries in Biber - ignoring in entry 'Elias1955a'}
    \endentry
|;

my $string3 = q|    \entry{Elias1955b}{article}{}
      \inset{Elias1955}
      \name{labelname}{1}{}{%
        {{hash=bdd4981ffb5a62685c993d6f9dec4c23}{Elias}{E\bibinitperiod}{P.}{P\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{hash=bdd4981ffb5a62685c993d6f9dec4c23}{Elias}{E\bibinitperiod}{P.}{P\bibinitperiod}{}{}{}{}}%
      }
      \strng{namehash}{bdd4981ffb5a62685c993d6f9dec4c23}
      \strng{fullhash}{bdd4981ffb5a62685c993d6f9dec4c23}
      \field{sortinit}{0}
      \field{sortinithash}{a08a9549c5c2429f8cec5d1a581b26ca}
      \field{labeltitle}{Predictive coding--II}
      \field{issn}{0096-1000}
      \field{journaltitle}{IRE Transactions on Information Theory}
      \field{month}{03}
      \field{number}{1}
      \field{title}{Predictive coding--II}
      \field{volume}{1}
      \field{year}{1955}
      \field{pages}{24\bibrangedash 33}
      \verb{doi}
      \verb 10.1109/TIT.1955.1055116
      \endverb
      \warn{\item Field 'entryset' is no longer needed in set member entries in Biber - ignoring in entry 'Elias1955b'}
    \endentry
|;

is($out->get_output_entry('Elias1955', $main), $string1, 'Legacy set test 1');
is($out->get_output_entry('Elias1955a', $main), $string2, 'Legacy set test 2');
is($out->get_output_entry('Elias1955b', $main), $string3, 'Legacy set test 3');

