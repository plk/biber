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

my $dl1 = q|    \entry{SchillerCND2010}{article}{}{}
      \name{author}{4}{}{%
        {{un=0,uniquepart=base,hash=c606849f9ce94faa18c52562c39b6f92}{%
           family={Schiller},
           familyi={S\bibinitperiod},
           given={Todd\bibnamedelima W.},
           giveni={T\bibinitperiod\bibinitdelim W\bibinitperiod},
           givenun=0}}%
        {{un=0,uniquepart=base,hash=20154ea5f879b7b3256febae2ee215b6}{%
           family={Chen},
           familyi={C\bibinitperiod},
           given={Yixin},
           giveni={Y\bibinitperiod},
           givenun=0}}%
        {{un=0,uniquepart=base,hash=47c2d9d369b1f19efa50d61551e7a69b}{%
           family={El\bibnamedelima Naqa},
           familyi={E\bibinitperiod\bibinitdelim N\bibinitperiod},
           given={Issam},
           giveni={I\bibinitperiod},
           givenun=0}}%
        {{un=0,uniquepart=base,hash=f967f6b51246cf632661681073e1b6d8}{%
           family={Deasy},
           familyi={D\bibinitperiod},
           given={Joseph\bibnamedelima O.},
           giveni={J\bibinitperiod\bibinitdelim O\bibinitperiod},
           givenun=0}}%
      }
      \strng{namehash}{cc9430ab59f948048f76cb58659fc218}
      \strng{fullhash}{104a7a1c8b6937b5c35dc05b94f446b9}
      \strng{fullhashraw}{104a7a1c8b6937b5c35dc05b94f446b9}
      \strng{bibnamehash}{cc9430ab59f948048f76cb58659fc218}
      \strng{authorbibnamehash}{cc9430ab59f948048f76cb58659fc218}
      \strng{authornamehash}{cc9430ab59f948048f76cb58659fc218}
      \strng{authorfullhash}{104a7a1c8b6937b5c35dc05b94f446b9}
      \strng{authorfullhashraw}{104a7a1c8b6937b5c35dc05b94f446b9}
      \field{sortinit}{S}
      \field{sortinithash}{b164b07b29984b41daf1e85279fbc5ab}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{journaltitle}{Neurocomputing}
      \field{month}{6}
      \field{number}{10-12}
      \field{title}{Modeling Radiation-induced Lung Injury Risk with an Ensemble of Support Vector Machines}
      \field{volume}{73}
      \field{year}{2010}
      \verb{doi}
      \verb 10.1016/j.neucom.2009.09.023
      \endverb
    \endentry
|;

eq_or_diff( $out->get_output_entry('SchillerCND2010', $main), $dl1, 'Fetch from plain bib download') ;
