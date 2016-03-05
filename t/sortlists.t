# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 14;
use Test::Differences;
unified_diff;

use Biber;
use Biber::Output::bbl;
use Log::Log4perl;
chdir("t/tdata");
my $S;

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

$biber->parse_ctrlfile('sortlists.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());
my $main = $biber->sortlists->get_list(0, 'lname', 'entry', 'lname', 'given', '');

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests
Biber::Config->setoption('bcf', 'sortlists.bcf');

# (re)generate informtion based on option settings
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $out = $biber->get_output_obj;

is_deeply([$biber->sortlists->get_list(0, 'lname', 'entry', 'lname', 'global', '')->get_keys], ['K11', 'K1', 'K2', 'K4', 'K3', 'K7', 'K8', 'K9', 'K10', 'K12', 'K5', 'K6'], 'List - name order');
is_deeply([$biber->sortlists->get_list(0, 'lyear', 'entry', 'lyear', 'global', '')->get_keys], ['K4', 'K1', 'K11', 'K12', 'K2', 'K3', 'K6', 'K5', 'K7', 'K8', 'K9', 'K10'], 'List - year order');
is_deeply([$biber->sortlists->get_list(0, 'ltitle', 'entry', 'ltitle', 'global', '')->get_keys], ['K1', 'K7', 'K8', 'K9', 'K4', 'K10', 'K2', 'K11', 'K6', 'K5', 'K12', 'K3'], 'List - title order');
is_deeply([$biber->sortlists->get_list(0, 'lnamef1', 'entry', 'lnamef1', 'global', '')->get_keys], ['K11', 'K2', 'K4', 'K12', 'K5', 'K6'], 'List - name order (filtered) - 1');
is_deeply([$biber->sortlists->get_list(0, 'lnamef2', 'entry', 'lnamef2', 'global', '')->get_keys], ['K4'], 'List - name order (filtered) - 2');
is_deeply([$biber->sortlists->get_list(0, 'lnamef3', 'entry', 'lnamef3', 'global', '')->get_keys], ['K11', 'K1', 'K2', 'K7', 'K12', 'K5', 'K6'], 'List - name order (filtered) - 3');
is_deeply([$biber->sortlists->get_list(0, 'lnamef4', 'entry', 'lnamef4', 'global', '')->get_keys], ['K3'], 'List - name order (filtered) - 4');
is_deeply([$biber->sortlists->get_list(0, 'lnamef5', 'entry', 'lnamef5', 'global', '')->get_keys], ['K1', 'K3'], 'List - name order (filtered) - 5');

# Test list-local locale sorting
is_deeply([$biber->sortlists->get_list(0, 'lnameswe', 'entry', 'lnameswe', 'global', '')->get_keys], ['K11', 'K1', 'K2', 'K4', 'K3', 'K7', 'K8', 'K9', 'K10', 'K12', 'K6', 'K5'], 'List - name order (swedish)');
is_deeply([$biber->sortlists->get_list(0, 'ltitlespan', 'entry', 'ltitlespan', 'global', '')->get_keys], ['K1', 'K4', 'K10', 'K7', 'K8', 'K9', 'K2', 'K11', 'K6', 'K5', 'K12', 'K3'], 'List - title order (spanish)');

# Test sortset-local locale sorting
is_deeply([$biber->sortlists->get_list(0, 'ltitleset', 'entry', 'ltitleset', 'global', '')->get_keys], ['K1', 'K7', 'K9', 'K8', 'K4', 'K10', 'K2', 'K11', 'K6', 'K5', 'K12', 'K3'], 'List - granular locale (spanish)');

# Testing sorting name key schemes
# Note that:
# * K6 has an entry scope override which makes it sort with family first despite the
#   'given' name key scheme using the given name first.
# * K11 has a name list scope override which forces "a" literal first
# * K12 has a name scope override which forces "Z" literal first
is_deeply([$biber->sortlists->get_list(0, 'lname', 'entry', 'lname', 'given', '')->get_keys], ['K11', 'K1', 'K2', 'K4', 'K3', 'K7', 'K5', 'K8', 'K9', 'K10', 'K12', 'K6'], 'List - sorting name key schemes - 1');

my $K11 = q|    \entry{K11}{book}{}
      \name{author}{1}{sortnamekeyscheme=snk1}{%
        {{hash=4edc280a0ef229f9c061e3b121b17482}{%
           family={Xanax},
           family_i={X\bibinitperiod},
           given={Xavier},
           given_i={X\bibinitperiod}}}%
      }
      \list{location}{1}{%
        {Moscow}%
      }
      \list{publisher}{1}{%
        {Publisher}%
      }
      \strng{namehash}{4edc280a0ef229f9c061e3b121b17482}
      \strng{fullhash}{4edc280a0ef229f9c061e3b121b17482}
      \field{sortinit}{a}
      \field{sortinithash}{b685c7856330eaee22789815b49de9bb}
      \field{labelyear}{1983}
      \field{datelabelsource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{One}
      \field{year}{1983}
    \endentry
|;

my $K12 = q|    \entry{K12}{book}{}
      \name{author}{1}{}{%
        {{sortnamekeyscheme=snk2,hash=a846a485fc9cbb59b0ebeedd6ac637e4}{%
           family={Allen},
           family_i={A\bibinitperiod},
           given={Arthur},
           given_i={A\bibinitperiod}}}%
      }
      \list{location}{1}{%
        {Moscow}%
      }
      \list{publisher}{1}{%
        {Publisher}%
      }
      \strng{namehash}{a846a485fc9cbb59b0ebeedd6ac637e4}
      \strng{fullhash}{a846a485fc9cbb59b0ebeedd6ac637e4}
      \field{sortinit}{Z}
      \field{sortinithash}{fdda4caaa6b5fa63e0c081dcb159543a}
      \field{labelyear}{1983}
      \field{datelabelsource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{Two}
      \field{year}{1983}
    \endentry
|;

eq_or_diff($out->get_output_entry('K11', $main), $K11, 'sortlist output - 1');
eq_or_diff($out->get_output_entry('K12', $main), $K12, 'sortlist output - 2');
