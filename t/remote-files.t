# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8' ;

use Test::More;
use Test::Differences;
unified_diff;

if ($ENV{BIBER_DEV_TESTS}) {
  plan tests => 1;
}
else {
  plan skip_all => 'BIBER_DEV_TESTS not set';
}

use Biber;
use Biber::Output::bbl;
use Log::Log4perl;
chdir("t/tdata") ;

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

$biber->parse_ctrlfile('remote-files.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');
Biber::Config->setoption('quiet', 1);
Biber::Config->setoption('nodieonerror', 1); # because the remote bibs might be messy

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $main = $biber->datalists->get_list('nty/global//global/global/global');
my $bibentries = $section->bibentries;

my $dl1 = q|    \entry{AbdelbarH98}{article}{}{}
      \name{author}{2}{}{%
        {{un=0,uniquepart=base,hash=03fb065ad674e2c6269f3542112e30df}{%
           family={Abdelbar},
           familyi={A\bibinitperiod},
           given={A.M.},
           giveni={A\bibinitperiod},
           givenun=0}}%
        {{un=0,uniquepart=base,hash=6ad6790ec94c4b5195bcac153b20da0e}{%
           family={Hedetniemi},
           familyi={H\bibinitperiod},
           given={S.M.},
           giveni={S\bibinitperiod},
           givenun=0}}%
      }
      \strng{namehash}{bb887c5d0458bfb1f3f7e6afc8d1def4}
      \strng{fullhash}{bb887c5d0458bfb1f3f7e6afc8d1def4}
      \strng{fullhashraw}{bb887c5d0458bfb1f3f7e6afc8d1def4}
      \strng{bibnamehash}{bb887c5d0458bfb1f3f7e6afc8d1def4}
      \strng{authorbibnamehash}{bb887c5d0458bfb1f3f7e6afc8d1def4}
      \strng{authornamehash}{bb887c5d0458bfb1f3f7e6afc8d1def4}
      \strng{authorfullhash}{bb887c5d0458bfb1f3f7e6afc8d1def4}
      \strng{authorfullhashraw}{bb887c5d0458bfb1f3f7e6afc8d1def4}
      \field{sortinit}{A}
      \field{sortinithash}{2f401846e2029bad6b3ecc16d50031e2}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{journaltitle}{Artificial Intelligence}
      \field{title}{Approximating {MAP}s for belief networks is {NP}-hard and other theorems}
      \field{volume}{102}
      \field{year}{1998}
      \field{pages}{21\bibrangedash 38}
      \range{pages}{18}
    \endentry
|;

eq_or_diff( $out->get_output_entry('AbdelbarH98', $main), $dl1, 'Fetch from plain bib download') ;
