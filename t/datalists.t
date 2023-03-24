# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 15;
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

$biber->parse_ctrlfile('datalists.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());
my $main = $biber->datalists->get_lists_by_attrs(section          => 0,
                                       name                       => 'lname',
                                       type                       => 'entry',
                                       sortingtemplatename        => 'lname',
                                       sortingnamekeytemplatename => 'given',
                                       labelprefix                => '',
                                       uniquenametemplatename     => 'global',
                                       labelalphanametemplatename => 'global')->[0];

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests
Biber::Config->setoption('bcf', 'datalists.bcf');

# (re)generate informtion based on option settings
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $out = $biber->get_output_obj;

is_deeply($biber->datalists->get_lists_by_attrs(section           => 0,
                                       name                       => 'lname',
                                       type                       => 'entry',
                                       sortingtemplatename        => 'lname',
                                       sortingnamekeytemplatename => 'global',
                                       labelprefix                => '',
                                       uniquenametemplatename     => 'global',
                                       labelalphanametemplatename => 'global')->[0]->get_keys, ['K11', 'K1', 'K2', 'K4', 'K3', 'K7', 'K8', 'K9', 'K10', 'K12', 'K5', 'K6'], 'List - name order');

is_deeply($biber->datalists->get_lists_by_attrs(section           => 0,
                                       name                       => 'lyear',
                                       type                       => 'entry',
                                       sortingtemplatename        => 'lyeard',
                                       sortingnamekeytemplatename => 'global',
                                       labelprefix                => '',
                                       uniquenametemplatename     => 'global',
                                       labelalphanametemplatename => 'global')->[0]->get_keys, ['K8', 'K9', 'K10', 'K4', 'K1', 'K11', 'K12', 'K2', 'K3', 'K6', 'K5', 'K7'], 'List - year order');


is_deeply($biber->datalists->get_lists_by_attrs(section           => 0,
                                       name                       => 'ltitle',
                                       type                       => 'entry',
                                       sortingtemplatename        => 'ltitle',
                                       sortingnamekeytemplatename => 'global',
                                       labelprefix                => '',
                                       uniquenametemplatename     => 'global',
                                       labelalphanametemplatename => 'global')->[0]->get_keys, ['K1', 'K7', 'K8', 'K9', 'K4', 'K10', 'K2', 'K11', 'K6', 'K5', 'K12', 'K3'], 'List - title order');

is_deeply($biber->datalists->get_lists_by_attrs(section           => 0,
                                       name                       => 'lnamef1',
                                       type                       => 'entry',
                                       sortingtemplatename        => 'lname',
                                       sortingnamekeytemplatename => 'global',
                                       labelprefix                => '',
                                       uniquenametemplatename     => 'global',
                                       labelalphanametemplatename => 'global')->[0]->get_keys, ['K11', 'K2', 'K4', 'K12', 'K5', 'K6'], 'List - name order (filtered) - 1');

is_deeply($biber->datalists->get_lists_by_attrs(section           => 0,
                                       name                       => 'lnamef2',
                                       type                       => 'entry',
                                       sortingtemplatename        => 'lname',
                                       sortingnamekeytemplatename => 'global',
                                       labelprefix                => '',
                                       uniquenametemplatename     => 'global',
                                       labelalphanametemplatename => 'global')->[0]->get_keys, ['K4'], 'List - name order (filtered) - 2');

is_deeply($biber->datalists->get_lists_by_attrs(section           => 0,
                                       name                       => 'lnamef3',
                                       type                       => 'entry',
                                       sortingtemplatename        => 'lname',
                                       sortingnamekeytemplatename => 'global',
                                       labelprefix                => '',
                                       uniquenametemplatename     => 'global',
                                       labelalphanametemplatename => 'global')->[0]->get_keys, ['K11', 'K1', 'K2', 'K7', 'K12', 'K5', 'K6'], 'List - name order (filtered) - 3');


is_deeply($biber->datalists->get_lists_by_attrs(section           => 0,
                                       name                       => 'lnamef4',
                                       type                       => 'entry',
                                       sortingtemplatename        => 'lname',
                                       sortingnamekeytemplatename => 'global',
                                       labelprefix                => '',
                                       uniquenametemplatename     => 'global',
                                       labelalphanametemplatename => 'global')->[0]->get_keys, ['K3'], 'List - name order (filtered) - 4');

is_deeply($biber->datalists->get_lists_by_attrs(section           => 0,
                                       name                       => 'lnamef5',
                                       type                       => 'entry',
                                       sortingtemplatename        => 'lname',
                                       sortingnamekeytemplatename => 'global',
                                       labelprefix                => '',
                                       uniquenametemplatename     => 'global',
                                       labelalphanametemplatename => 'global')->[0]->get_keys, ['K1', 'K3'], 'List - name order (filtered) - 5');

# Test list-local locale sorting
is_deeply($biber->datalists->get_lists_by_attrs(section           => 0,
                                       name                       => 'lnameswe',
                                       type                       => 'entry',
                                       sortingtemplatename        => 'lnameswe',
                                       sortingnamekeytemplatename => 'global',
                                       labelprefix                => '',
                                       uniquenametemplatename     => 'global',
                                       labelalphanametemplatename => 'global')->[0]->get_keys, ['K11', 'K1', 'K2', 'K4', 'K3', 'K7', 'K8', 'K9', 'K10', 'K12', 'K6', 'K5'], 'List - name order (swedish)');

is_deeply($biber->datalists->get_lists_by_attrs(section           => 0,
                                       name                       => 'ltitlespan',
                                       type                       => 'entry',
                                       sortingtemplatename        => 'ltitlespan',
                                       sortingnamekeytemplatename => 'global',
                                       labelprefix                => '',
                                       uniquenametemplatename     => 'global',
                                       labelalphanametemplatename => 'global')->[0]->get_keys, ['K1', 'K4', 'K10', 'K7', 'K8', 'K9', 'K2', 'K11', 'K6', 'K5', 'K12', 'K3'], 'List - title order (spanish)');

# Test sortset-local locale sorting
is_deeply($biber->datalists->get_lists_by_attrs(section           => 0,
                                       name                       => 'ltitleset',
                                       type                       => 'entry',
                                       sortingtemplatename        => 'ltitleset',
                                       sortingnamekeytemplatename => 'global',
                                       labelprefix                => '',
                                       uniquenametemplatename     => 'global',
                                       labelalphanametemplatename => 'global')->[0]->get_keys, ['K1', 'K7', 'K9', 'K8', 'K4', 'K10', 'K2', 'K11', 'K6', 'K5', 'K12', 'K3'], 'List - granular locale (spanish)');

# Testing sorting name key templates
# Note that:
# * K6 has an entry scope override which makes it sort with family first despite the
#   'given' name key template using the given name first.
# * K11 has a name list scope override which forces "aaa" literal first
# * K12 has a name scope override which forces "Z" literal first
is_deeply($biber->datalists->get_lists_by_attrs(section           => 0,
                                       name                       => 'lname',
                                       type                       => 'entry',
                                       sortingtemplatename        => 'lname',
                                       sortingnamekeytemplatename => 'given',
                                       labelprefix                => '',
                                       uniquenametemplatename     => 'global',
                                       labelalphanametemplatename => 'global')->[0]->get_keys, ['K11', 'K1', 'K2', 'K4', 'K3', 'K7', 'K5', 'K8', 'K9', 'K10', 'K12', 'K6'], 'List - sorting name key templates - 1');

my $K11 = q|    \entry{K11}{book}{}{}
      \name{author}{1}{sortingnamekeytemplatename=snk1}{%
        {{hash=4edc280a0ef229f9c061e3b121b17482}{%
           family={Xanax},
           familyi={X\bibinitperiod},
           given={Xavier},
           giveni={X\bibinitperiod}}}%
      }
      \list{location}{1}{%
        {Moscow}%
      }
      \list{publisher}{1}{%
        {Publisher}%
      }
      \strng{namehash}{4edc280a0ef229f9c061e3b121b17482}
      \strng{fullhash}{4edc280a0ef229f9c061e3b121b17482}
      \strng{fullhashraw}{4edc280a0ef229f9c061e3b121b17482}
      \strng{bibnamehash}{4edc280a0ef229f9c061e3b121b17482}
      \strng{authorbibnamehash}{4edc280a0ef229f9c061e3b121b17482}
      \strng{authornamehash}{4edc280a0ef229f9c061e3b121b17482}
      \strng{authorfullhash}{4edc280a0ef229f9c061e3b121b17482}
      \strng{authorfullhashraw}{4edc280a0ef229f9c061e3b121b17482}
      \field{sortinit}{a}
      \field{sortinithash}{2f401846e2029bad6b3ecc16d50031e2}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{One}
      \field{year}{1983}
      \field{dateera}{ce}
    \endentry
|;

my $K12 = q|    \entry{K12}{book}{}{}
      \name{author}{1}{}{%
        {{sortingnamekeytemplatename=snk2,hash=a846a485fc9cbb59b0ebeedd6ac637e4}{%
           family={Allen},
           familyi={A\bibinitperiod},
           given={Arthur},
           giveni={A\bibinitperiod}}}%
      }
      \list{location}{1}{%
        {Moscow}%
      }
      \list{publisher}{1}{%
        {Publisher}%
      }
      \strng{namehash}{a846a485fc9cbb59b0ebeedd6ac637e4}
      \strng{fullhash}{a846a485fc9cbb59b0ebeedd6ac637e4}
      \strng{fullhashraw}{a846a485fc9cbb59b0ebeedd6ac637e4}
      \strng{bibnamehash}{a846a485fc9cbb59b0ebeedd6ac637e4}
      \strng{authorbibnamehash}{a846a485fc9cbb59b0ebeedd6ac637e4}
      \strng{authornamehash}{a846a485fc9cbb59b0ebeedd6ac637e4}
      \strng{authorfullhash}{a846a485fc9cbb59b0ebeedd6ac637e4}
      \strng{authorfullhashraw}{a846a485fc9cbb59b0ebeedd6ac637e4}
      \field{sortinit}{Z}
      \field{sortinithash}{96892c0b0a36bb8557c40c49813d48b3}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{Two}
      \field{year}{1983}
      \field{dateera}{ce}
    \endentry
|;

eq_or_diff($out->get_output_entry('K11', $main), $K11, 'datalist output - 1');
eq_or_diff($out->get_output_entry('K12', $main), $K12, 'datalist output - 2');

# Testing dates
is_deeply($biber->datalists->get_lists_by_attrs(section           => 1,
                                       name                       => 'ldates',
                                       type                       => 'entry',
                                       sortingtemplatename        => 'lyear',
                                       sortingnamekeytemplatename => 'global',
                                       labelprefix                => '',
                                       uniquenametemplatename     => 'global',
                                       labelalphanametemplatename => 'global')->[0]->get_keys, ['D3', 'D2', 'D1', 'D5', 'D6', 'D7', 'D4'], 'List - dates');
