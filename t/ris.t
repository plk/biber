use strict;
use warnings;
use utf8;
no warnings 'utf8' ;

use Test::More tests => 2;

use Biber;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
chdir("t/tdata") ;

# Set up Biber object
my $biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('ris.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'C');
Biber::Config->setoption('ignore', { ris => "N2" } ); # skip abstract


# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $main = $section->get_list('MAIN');
my $bibentries = $section->bibentries;

my $l1 = q|  \entry{test1}{article}{}
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
    \field{journaltitle}{J.Neurosurg.}
    \field{volume}{85}
    \field{pages}{476\bibrangedash 481}
    \keyw{cortical contusion,blood-brain barrier,horseradish peroxidase,head trauma,hippocampus,rat}
  \endentry

|;

my $l2 = q|  \entry{test2}{book}{}
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
    \field{pages}{1\bibrangedash 20}
    \keyw{keyword}
  \endentry

|;

is( $out->get_output_entry($main,'test1'), $l1, 'Basic RIS test - 1') ;
is( $out->get_output_entry($main,'test2'), $l2, 'Basic RIS test - 2') ;

