# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8' ;

use Test::More tests => 2;

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
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'C');

# THERE IS A CONFIG FILE BEING READ TO TEST USER MAPS TOO!

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $main = $biber->sortlists->get_list(0, 'nty', 'entry', 'nty');
my $bibentries = $section->bibentries;

my $l1 = q|    \entry{test1}{report}{}
      \name{labelname}{5}{}{%
        {{uniquename=0,hash=35fb6a7132629790580cd2c9c0a5ab87}{Baldwin}{B\bibinitperiod}{S.A.}{S\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=f8b1ae371652de603e137e413b55de78}{Fugaccia}{F\bibinitperiod}{I.}{I\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=86957f40459ed948ee1b4ff0ec7740f6}{Brown}{B\bibinitperiod}{D.R.}{D\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=baf6c971e311fa61ec2f75e93531016e}{Brown}{B\bibinitperiod}{L.V.}{L\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=bd289ff4276c0fc8c16a49161011c5da}{Scheff}{S\bibinitperiod}{S.W.}{S\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{5}{}{%
        {{uniquename=0,hash=35fb6a7132629790580cd2c9c0a5ab87}{Baldwin}{B\bibinitperiod}{S.A.}{S\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=f8b1ae371652de603e137e413b55de78}{Fugaccia}{F\bibinitperiod}{I.}{I\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=86957f40459ed948ee1b4ff0ec7740f6}{Brown}{B\bibinitperiod}{D.R.}{D\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=baf6c971e311fa61ec2f75e93531016e}{Brown}{B\bibinitperiod}{L.V.}{L\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=bd289ff4276c0fc8c16a49161011c5da}{Scheff}{S\bibinitperiod}{S.W.}{S\bibinitperiod}{}{}{}{}}%
      }
      \strng{namehash}{deae9fead6c78a99d3f38159b0710b1f}
      \strng{fullhash}{bde87bef9bb3834837786f78acfebc54}
      \field{sortinit}{B}
      \field{sortinithash}{1a3a21dbed09540af12d49a0b14f4751}
      \field{labelyear}{1996}
      \field{datelabelsource}{}
      \field{labeltitle}{Blood-brain barrier breach following cortical contusion in the rat}
      \field{journaltitle}{J.Neurosurgery}
      \field{title}{Blood-brain barrier breach following cortical contusion in the rat}
      \field{volume}{85}
      \field{year}{1996}
      \field{pages}{476\bibrangedash 481}
      \keyw{cortical contusion,blood-brain barrier,horseradish peroxidase,head trauma,hippocampus,rat}
    \endentry
|;

my $l2 = q|    \entry{test2}{inbook}{}
      \name{labelname}{1}{}{%
        {{uniquename=0,hash=f2574dc91f1242eb0e7507a71730631b}{Smith}{S\bibinitperiod}{John\bibnamedelima Frederick}{J\bibinitperiod\bibinitdelim F\bibinitperiod}{}{}{III}{I\bibinitperiod}}%
      }
      \name{author}{1}{}{%
        {{uniquename=0,hash=f2574dc91f1242eb0e7507a71730631b}{Smith}{S\bibinitperiod}{John\bibnamedelima Frederick}{J\bibinitperiod\bibinitdelim F\bibinitperiod}{}{}{III}{I\bibinitperiod}}%
      }
      \name{editor}{1}{}{%
        {{hash=c889e5c69d0c445e8f3bb0fe1ea7a19c}{Brown}{B\bibinitperiod}{Alan}{A\bibinitperiod}{}{}{}{}}%
      }
      \strng{namehash}{f2574dc91f1242eb0e7507a71730631b}
      \strng{fullhash}{f2574dc91f1242eb0e7507a71730631b}
      \field{sortinit}{S}
      \field{sortinithash}{4125bb4c3a0eb3eaee3ea6da32eb70c8}
      \field{labelyear}{1996}
      \field{labelmonth}{03}
      \field{labelday}{12}
      \field{datelabelsource}{}
      \field{labeltitle}{Sometitle}
      \field{day}{12}
      \field{month}{03}
      \field{title}{Sometitle}
      \field{year}{1996}
      \field{pages}{1\bibrangedash 20}
      \keyw{somevalue}
    \endentry
|;

is( $out->get_output_entry('test1', $main), $l1, 'Basic RIS test - 1') ;
is( $out->get_output_entry('test2', $main), $l2, 'Basic RIS test - 2') ;

