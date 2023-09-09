# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 6;
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

$biber->parse_ctrlfile('set-static.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');

# Now generate the information
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $main = $biber->datalists->get_list('nty/global//global/global/global');
my $main1 = $biber->datalists->get_list('none/global//global/global/global', 1);
my $out = $biber->get_output_obj;

# Notes that \set is in nty order due to sortsets=true in .bcf
my $string1 = q|    \entry{Static1}{set}{}{}
      \set{Static2,Static4,Static3}
      \field{sortinit}{B}
      \field{sortinithash}{d7095fff47cda75ca2589920aae98399}
      \field{annotation}{Some notes}
      \field{shorthand}{STAT1}
    \endentry
|;

my $string2 = q|    \entry{Static2}{book}{skipbib=true,skipbiblist=true,skiplab=true,uniquelist=false,uniquename=false}{}
      \inset{Static1}
      \name{author}{1}{}{%
        {{hash=43874d80d7ce68027102819f16c47df1}{%
           family={Bumble},
           familyi={B\bibinitperiod},
           given={Brian},
           giveni={B\bibinitperiod}}}%
      }
      \strng{namehash}{43874d80d7ce68027102819f16c47df1}
      \strng{fullhash}{43874d80d7ce68027102819f16c47df1}
      \strng{fullhashraw}{43874d80d7ce68027102819f16c47df1}
      \strng{bibnamehash}{43874d80d7ce68027102819f16c47df1}
      \strng{authorbibnamehash}{43874d80d7ce68027102819f16c47df1}
      \strng{authornamehash}{43874d80d7ce68027102819f16c47df1}
      \strng{authorfullhash}{43874d80d7ce68027102819f16c47df1}
      \strng{authorfullhashraw}{43874d80d7ce68027102819f16c47df1}
      \field{sortinit}{B}
      \field{sortinithash}{d7095fff47cda75ca2589920aae98399}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{annotation}{Some Blessed Note}
      \field{title}{Blessed Brains}
      \field{year}{2001}
    \endentry
|;

my $string3 = q|    \entry{Static3}{book}{skipbib=true,skipbiblist=true,skiplab=true,uniquelist=false,uniquename=false}{}
      \inset{Static1}
      \name{author}{1}{}{%
        {{hash=22dafa5cd57bb5dd7f3e3bab98fd539c}{%
           family={Dingle},
           familyi={D\bibinitperiod},
           given={Derek},
           giveni={D\bibinitperiod}}}%
      }
      \strng{namehash}{22dafa5cd57bb5dd7f3e3bab98fd539c}
      \strng{fullhash}{22dafa5cd57bb5dd7f3e3bab98fd539c}
      \strng{fullhashraw}{22dafa5cd57bb5dd7f3e3bab98fd539c}
      \strng{bibnamehash}{22dafa5cd57bb5dd7f3e3bab98fd539c}
      \strng{authorbibnamehash}{22dafa5cd57bb5dd7f3e3bab98fd539c}
      \strng{authornamehash}{22dafa5cd57bb5dd7f3e3bab98fd539c}
      \strng{authorfullhash}{22dafa5cd57bb5dd7f3e3bab98fd539c}
      \strng{authorfullhashraw}{22dafa5cd57bb5dd7f3e3bab98fd539c}
      \field{sortinit}{D}
      \field{sortinithash}{6f385f66841fb5e82009dc833c761848}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{Castles and Crime}
      \field{year}{2002}
    \endentry
|;

my $string4 = q|    \entry{Static4}{book}{skipbib=true,skipbiblist=true,skiplab=true,uniquelist=false,uniquename=false}{}
      \inset{Static1}
      \name{author}{1}{}{%
        {{hash=da80091c8cd89e5269bd55af1bd5d2fa}{%
           family={Crenellation},
           familyi={C\bibinitperiod},
           given={Clive},
           giveni={C\bibinitperiod}}}%
      }
      \strng{namehash}{da80091c8cd89e5269bd55af1bd5d2fa}
      \strng{fullhash}{da80091c8cd89e5269bd55af1bd5d2fa}
      \strng{fullhashraw}{da80091c8cd89e5269bd55af1bd5d2fa}
      \strng{bibnamehash}{da80091c8cd89e5269bd55af1bd5d2fa}
      \strng{authorbibnamehash}{da80091c8cd89e5269bd55af1bd5d2fa}
      \strng{authornamehash}{da80091c8cd89e5269bd55af1bd5d2fa}
      \strng{authorfullhash}{da80091c8cd89e5269bd55af1bd5d2fa}
      \strng{authorfullhashraw}{da80091c8cd89e5269bd55af1bd5d2fa}
      \field{sortinit}{C}
      \field{sortinithash}{4d103a86280481745c9c897c925753c0}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{Dungeons, Dark and Dangerous}
      \field{year}{2005}
    \endentry
|;

# Labelyear is now here as skiplab is not set for this entry when cited in section
# without citation of a set it is a member of
my $string5 = q|    \entry{Static2}{book}{}{}
      \name{author}{1}{}{%
        {{hash=43874d80d7ce68027102819f16c47df1}{%
           family={Bumble},
           familyi={B\bibinitperiod},
           given={Brian},
           giveni={B\bibinitperiod}}}%
      }
      \strng{namehash}{43874d80d7ce68027102819f16c47df1}
      \strng{fullhash}{43874d80d7ce68027102819f16c47df1}
      \strng{fullhashraw}{43874d80d7ce68027102819f16c47df1}
      \strng{bibnamehash}{43874d80d7ce68027102819f16c47df1}
      \strng{authorbibnamehash}{43874d80d7ce68027102819f16c47df1}
      \strng{authornamehash}{43874d80d7ce68027102819f16c47df1}
      \strng{authorfullhash}{43874d80d7ce68027102819f16c47df1}
      \strng{authorfullhashraw}{43874d80d7ce68027102819f16c47df1}
      \field{sortinit}{1}
      \field{sortinithash}{4f6aaa89bab872aa0999fec09ff8e98a}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{annotation}{Some Blessed Note}
      \field{title}{Blessed Brains}
      \field{year}{2001}
    \endentry
|;


eq_or_diff($out->get_output_entry('Static1', $main), $string1, 'Static set test 1');
eq_or_diff($out->get_output_entry('Static2', $main), $string2, 'Static set test 2');
eq_or_diff($out->get_output_entry('Static3', $main), $string3, 'Static set test 3');
eq_or_diff($out->get_output_entry('Static4', $main), $string4, 'Static set test 4');
eq_or_diff($out->get_output_entry('Static2', $main1, 1), $string5, 'Static set test 5');

is_deeply($biber->datalists->get_lists_by_attrs(section                    => 0,
                                                name                       => 'shorthand:shorthand/global//global/global/global',
                                                type                       => 'list',
                                                sortingtemplatename        => 'shorthand',
                                                sortingnamekeytemplatename => 'global',
                                                labelprefix                => '',
                                                uniquenametemplatename     => 'global',
                                                labelalphanametemplatename => 'global',
                                                namehashtemplatename       => 'global')->[0]->get_keys, ['Static2', 'Static3', 'Static4', 'Static1'], 'Shorthand - sets');
