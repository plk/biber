# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8' ;

use Test::More;
use Test::Differences;
unified_diff;

if ($ENV{BIBER_DEV_TESTS}) {
  plan tests => 2;
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
my $main = $biber->datalists->get_list('nty/global//global/global');
my $bibentries = $section->bibentries;

my $dl1 = q|    \entry{AbdelbarH98}{article}{}
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
      \strng{bibnamehash}{bb887c5d0458bfb1f3f7e6afc8d1def4}
      \strng{authorbibnamehash}{bb887c5d0458bfb1f3f7e6afc8d1def4}
      \strng{authornamehash}{bb887c5d0458bfb1f3f7e6afc8d1def4}
      \strng{authorfullhash}{bb887c5d0458bfb1f3f7e6afc8d1def4}
      \field{sortinit}{A}
      \field{sortinithash}{a3dcedd53b04d1adfd5ac303ecd5e6fa}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{year}
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

my $ssl = q|    \entry{crossley_politics_1994}{book}{}
      \name{author}{1}{}{%
        {{un=0,uniquepart=base,hash=92a23f84d2ee0a6817cf6e31edda9ac2}{%
           family={Crossley},
           familyi={C\bibinitperiod},
           given={Nick},
           giveni={N\bibinitperiod},
           givenun=0}}%
      }
      \list{language}{1}{%
        {en}%
      }
      \list{publisher}{1}{%
        {Avebury}%
      }
      \strng{namehash}{92a23f84d2ee0a6817cf6e31edda9ac2}
      \strng{fullhash}{92a23f84d2ee0a6817cf6e31edda9ac2}
      \strng{bibnamehash}{92a23f84d2ee0a6817cf6e31edda9ac2}
      \strng{authorbibnamehash}{92a23f84d2ee0a6817cf6e31edda9ac2}
      \strng{authornamehash}{92a23f84d2ee0a6817cf6e31edda9ac2}
      \strng{authorfullhash}{92a23f84d2ee0a6817cf6e31edda9ac2}
      \field{sortinit}{C}
      \field{sortinithash}{4c244ceae61406cdc0cc2ce1cb1ff703}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{year}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{shorttitle}
      \field{isbn}{9781856288866}
      \field{shorttitle}{The politics of subjectivity}
      \field{title}{The politics of subjectivity : {Between} {Foucault} and {Merleau}-{Ponty}}
      \field{year}{1994}
      \keyw{Philosophy / General,Philosophy / History \& Surveys / Modern,Subjectivity}
    \endentry
|;

eq_or_diff( $out->get_output_entry('AbdelbarH98', $main), $dl1, 'Fetch from plain bib download') ;
eq_or_diff( $out->get_output_entry('crossley_politics_1994', $main), $ssl, 'HTTPS test') ;
