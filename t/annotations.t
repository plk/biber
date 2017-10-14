# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 1;
use Test::Differences;
unified_diff;

use Biber;
use Biber::Utils;
use Biber::Output::bbl;
use Log::Log4perl;
use Unicode::Normalize;
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


Biber::Config->setoption('annotation_marker', '-an');
# This is cached at load time so we need to alter the cache too
$Biber::Config::CONFIG_META_MARKERS{annotation} = quotemeta(Biber::Config->getoption('annotation_marker'));
$biber->parse_ctrlfile('annotations.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $main = $biber->datalists->get_list('nty/global//global/global');

my $ann1 = q|    \entry{ann1}{misc}{}
      \name{author}{3}{}{%
        {{hash=89a9e5097e11e595700540379c9b3a6b}{%
           family={Last1},
           familyi={L\\bibinitperiod},
           given={First1},
           giveni={F\\bibinitperiod}}}%
        {{hash=7475b6b7b3c24a2ac6bd4d146cdc74dc}{%
           family={Last2},
           familyi={L\\bibinitperiod},
           given={First2},
           giveni={F\\bibinitperiod}}}%
        {{hash=fd3dffa06a5d1f89c512841df1ccf4d0}{%
           family={Last3},
           familyi={L\\bibinitperiod},
           given={First3},
           giveni={F\\bibinitperiod}}}%
      }
      \list{language}{2}{%
        {english}%
        {french}%
      }
      \strng{namehash}{90ae96c82de92e36949bc64254bbde0c}
      \strng{fullhash}{90ae96c82de92e36949bc64254bbde0c}
      \strng{bibnamehash}{90ae96c82de92e36949bc64254bbde0c}
      \strng{authorbibnamehash}{90ae96c82de92e36949bc64254bbde0c}
      \strng{authornamehash}{90ae96c82de92e36949bc64254bbde0c}
      \strng{authorfullhash}{90ae96c82de92e36949bc64254bbde0c}
      \field{sortinit}{L}
      \field{sortinithash}{7bba64db83423e3c29ad597f3b682cf3}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{The Title}
      \annotation{field}{language}{}{}{ann4}
      \annotation{field}{title}{}{}{one, two}
      \annotation{item}{author}{2}{}{corresponding}
      \annotation{item}{language}{1}{}{ann1}
      \annotation{item}{language}{2}{}{ann2, ann3}
      \annotation{part}{author}{1}{family}{student}
    \endentry
|;

eq_or_diff( $out->get_output_entry('ann1', $main), $ann1, 'Annotations - 1' );

