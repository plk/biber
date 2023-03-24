# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 3;
use Test::Differences;
unified_diff;

use Biber;
use Biber::Utils;
use Biber::Output::bbl;
use Log::Log4perl;
chdir("t/tdata");

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

$biber->parse_ctrlfile('skipsg.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests
Biber::Config->setblxoption(undef, 'skiplab', 'true');
Biber::Config->setblxoption(undef, 'skibib', 'true');
Biber::Config->setblxoption(undef, 'skipbiblist', 'true');

# Biber options
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');


my $S1 = q|    \entry{S1}{book}{skipbib=false,skipbiblist=false,skiplab=false}{}
      \name{author}{2}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{%
           family={Doe},
           familyi={D\bibinitperiod},
           given={John},
           giveni={J\bibinitperiod}}}%
        {{hash=df9bf04cd41245e6d23ad7543e7fd90d}{%
           family={Abrahams},
           familyi={A\bibinitperiod},
           given={Albert},
           giveni={A\bibinitperiod}}}%
      }
      \list{publisher}{1}{%
        {Oxford}%
      }
      \strng{namehash}{8c77336299b25bdada7bf8038f46722f}
      \strng{fullhash}{8c77336299b25bdada7bf8038f46722f}
      \strng{fullhashraw}{8c77336299b25bdada7bf8038f46722f}
      \strng{bibnamehash}{8c77336299b25bdada7bf8038f46722f}
      \strng{authorbibnamehash}{8c77336299b25bdada7bf8038f46722f}
      \strng{authornamehash}{8c77336299b25bdada7bf8038f46722f}
      \strng{authorfullhash}{8c77336299b25bdada7bf8038f46722f}
      \strng{authorfullhashraw}{8c77336299b25bdada7bf8038f46722f}
      \field{extraname}{1}
      \field{labelalpha}{DA95}
      \field{sortinit}{D}
      \field{sortinithash}{6f385f66841fb5e82009dc833c761848}
      \field{extradate}{1}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \field{extraalpha}{1}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{Title 1}
      \field{year}{1995}
    \endentry
|;

my $S2 = q|    \entry{S2}{book}{skipbib=false,skiplab=false}{}
      \name{author}{2}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{%
           family={Doe},
           familyi={D\bibinitperiod},
           given={John},
           giveni={J\bibinitperiod}}}%
        {{hash=df9bf04cd41245e6d23ad7543e7fd90d}{%
           family={Abrahams},
           familyi={A\bibinitperiod},
           given={Albert},
           giveni={A\bibinitperiod}}}%
      }
      \list{publisher}{1}{%
        {Oxford}%
      }
      \strng{namehash}{8c77336299b25bdada7bf8038f46722f}
      \strng{fullhash}{8c77336299b25bdada7bf8038f46722f}
      \strng{fullhashraw}{8c77336299b25bdada7bf8038f46722f}
      \strng{bibnamehash}{8c77336299b25bdada7bf8038f46722f}
      \strng{authorbibnamehash}{8c77336299b25bdada7bf8038f46722f}
      \strng{authornamehash}{8c77336299b25bdada7bf8038f46722f}
      \strng{authorfullhash}{8c77336299b25bdada7bf8038f46722f}
      \strng{authorfullhashraw}{8c77336299b25bdada7bf8038f46722f}
      \field{extraname}{2}
      \field{labelalpha}{DA95}
      \field{sortinit}{D}
      \field{sortinithash}{6f385f66841fb5e82009dc833c761848}
      \field{extradate}{2}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \field{extraalpha}{2}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{Title 2}
      \field{year}{1995}
    \endentry
|;

my $S3 = q|    \entry{S3}{book}{}{}
      \name{author}{2}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{%
           family={Doe},
           familyi={D\bibinitperiod},
           given={John},
           giveni={J\bibinitperiod}}}%
        {{hash=df9bf04cd41245e6d23ad7543e7fd90d}{%
           family={Abrahams},
           familyi={A\bibinitperiod},
           given={Albert},
           giveni={A\bibinitperiod}}}%
      }
      \list{publisher}{1}{%
        {Oxford}%
      }
      \strng{namehash}{8c77336299b25bdada7bf8038f46722f}
      \strng{fullhash}{8c77336299b25bdada7bf8038f46722f}
      \strng{fullhashraw}{8c77336299b25bdada7bf8038f46722f}
      \strng{bibnamehash}{8c77336299b25bdada7bf8038f46722f}
      \strng{authorbibnamehash}{8c77336299b25bdada7bf8038f46722f}
      \strng{authornamehash}{8c77336299b25bdada7bf8038f46722f}
      \strng{authorfullhash}{8c77336299b25bdada7bf8038f46722f}
      \strng{authorfullhashraw}{8c77336299b25bdada7bf8038f46722f}
      \field{sortinit}{D}
      \field{sortinithash}{6f385f66841fb5e82009dc833c761848}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{Title 3}
      \field{year}{1995}
    \endentry
|;

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $main = $biber->datalists->get_list('custom/global//global/global/global');
# labels as per-entry dataonly=false
eq_or_diff( $out->get_output_entry('S1', $main), $S1, 'Global skips with entry override - 1') ;
# labels as per-entry skpiplab=false
eq_or_diff( $out->get_output_entry('S2', $main), $S2, 'Global skips with entry override - 2') ;
# no labels as global skip*=true
eq_or_diff( $out->get_output_entry('S3', $main), $S3, 'Global skips with entry override - 3') ;
