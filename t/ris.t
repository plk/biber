# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8' ;

use Test::More tests => 2;
use Test::Differences;
unified_diff;

use Biber;
use Biber::Output::bbl;
use Log::Log4perl;
chdir("t/tdata") ;

# Set up Biber object
my $biber = Biber->new( configfile => 'biber-test.conf');
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

$biber->parse_ctrlfile('ris.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');
Biber::Config->setoption('fastsort', 1);

# THERE IS A CONFIG FILE BEING READ TO TEST USER MAPS TOO!

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $main = $biber->sortlists->get_list(0, 'nty/global', 'entry', 'nty', 'global');
my $bibentries = $section->bibentries;

my $l1 = q|    \entry{test1}{report}{}
      \name{author}{5}{}{%
        {{uniquename=0,hash=35fb6a7132629790580cd2c9c0a5ab87}{%
           family={Baldwin},
           family_i={B\bibinitperiod},
           given={S.A.},
           given_i={S\bibinitperiod}}}%
        {{uniquename=0,hash=f8b1ae371652de603e137e413b55de78}{%
           family={Fugaccia},
           family_i={F\bibinitperiod},
           given={I.},
           given_i={I\bibinitperiod}}}%
        {{uniquename=0,hash=86957f40459ed948ee1b4ff0ec7740f6}{%
           family={Brown},
           family_i={B\bibinitperiod},
           given={D.R.},
           given_i={D\bibinitperiod}}}%
        {{uniquename=0,hash=baf6c971e311fa61ec2f75e93531016e}{%
           family={Brown},
           family_i={B\bibinitperiod},
           given={L.V.},
           given_i={L\bibinitperiod}}}%
        {{uniquename=0,hash=bd289ff4276c0fc8c16a49161011c5da}{%
           family={Scheff},
           family_i={S\bibinitperiod},
           given={S.W.},
           given_i={S\bibinitperiod}}}%
      }
      \strng{namehash}{deae9fead6c78a99d3f38159b0710b1f}
      \strng{fullhash}{bde87bef9bb3834837786f78acfebc54}
      \field{sortinit}{B}
      \field{sortinithash}{4ecbea03efd0532989d3836d1a048c32}
      \field{labelyear}{1996}
      \field{datelabelsource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{journaltitle}{J.Neurosurgery}
      \field{title}{Blood-brain barrier breach following cortical contusion in the rat}
      \field{volume}{85}
      \field{year}{1996}
      \field{pages}{476\bibrangedash 481}
      \range{pages}{6}
      \keyw{cortical contusion,blood-brain barrier,horseradish peroxidase,head trauma,hippocampus,rat}
    \endentry
|;

my $l2 = q|    \entry{test2}{inbook}{}
      \name{author}{1}{}{%
        {{uniquename=0,hash=f2574dc91f1242eb0e7507a71730631b}{%
           family={Smith},
           family_i={S\bibinitperiod},
           suffix={III},
           suffix_i={I\bibinitperiod},
           given={John\bibnamedelima Frederick},
           given_i={J\bibinitperiod\bibinitdelim F\bibinitperiod}}}%
      }
      \name{editor}{1}{}{%
        {{hash=c889e5c69d0c445e8f3bb0fe1ea7a19c}{%
           family={Brown},
           family_i={B\bibinitperiod},
           given={Alan},
           given_i={A\bibinitperiod}}}%
      }
      \strng{namehash}{f2574dc91f1242eb0e7507a71730631b}
      \strng{fullhash}{f2574dc91f1242eb0e7507a71730631b}
      \field{sortinit}{S}
      \field{sortinithash}{fd1e7c5ab79596b13dbbb67f8d70fb5a}
      \field{labelyear}{1996}
      \field{labelmonth}{03}
      \field{labelday}{12}
      \field{datelabelsource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{day}{12}
      \field{month}{03}
      \field{title}{Sometitle}
      \field{year}{1996}
      \field{pages}{1\bibrangedash 20}
      \range{pages}{20}
      \keyw{somevalue}
    \endentry
|;

eq_or_diff( $out->get_output_entry('test1', $main), $l1, 'Basic RIS test - 1') ;
eq_or_diff( $out->get_output_entry('test2', $main), $l2, 'Basic RIS test - 2') ;

