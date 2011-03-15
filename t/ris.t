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

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $main = $section->get_list('MAIN');
my $bibentries = $section->bibentries;

my $l1 = q|  \entry{test1}{article}{}
    \name{labelname}{5}{%
      {{Baldwin}{B\bibinitperiod}{S.A.}{S\bibinitperiod}{}{}{}{}}%
      {{Fugaccia}{F\bibinitperiod}{I.}{I\bibinitperiod}{}{}{}{}}%
      {{Brown}{B\bibinitperiod}{D.R.}{D\bibinitperiod}{}{}{}{}}%
      {{Brown}{B\bibinitperiod}{L.V.}{L\bibinitperiod}{}{}{}{}}%
      {{Scheff}{S\bibinitperiod}{S.W.}{S\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{5}{%
      {{Baldwin}{B\bibinitperiod}{S.A.}{S\bibinitperiod}{}{}{}{}}%
      {{Fugaccia}{F\bibinitperiod}{I.}{I\bibinitperiod}{}{}{}{}}%
      {{Brown}{B\bibinitperiod}{D.R.}{D\bibinitperiod}{}{}{}{}}%
      {{Brown}{B\bibinitperiod}{L.V.}{L\bibinitperiod}{}{}{}{}}%
      {{Scheff}{S\bibinitperiod}{S.W.}{S\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{BS+1}
    \strng{fullhash}{BSFIBDBLSS1}
    \field{sortinit}{B}
    \count{uniquename}{0}
    \field{abstract}{Adult Fisher 344 rats were subjected to a unilateral impact to the dorsal cortex above the hippocampus at 3.5 m/sec with a 2 mm cortical depression. This caused severe cortical damage and neuronal loss in hippocampus subfields CA1, CA3 and hilus. Breakdown of the blood-brain barrier (BBB) was assessed by injecting the protein horseradish peroxidase (HRP) 5 minutes prior to or at various times following injury (5 minutes, 1, 2, 6, 12 hours, 1, 2, 5, and 10 days). Animals were killed 1 hour after HRP injection and brain sections were reacted with diaminobenzidine to visualize extravascular accumulation of the protein. Maximum staining occurred in animals injected with HRP 5 minutes prior to or 5 minutes after cortical contusion. Staining at these time points was observed in the ipsilateral hippocampus. Some modest staining occurred in the dorsal contralateral cortex near the superior sagittal sinus. Cortical HRP stain gradually decreased at increasing time intervals postinjury. By 10 days, no HRP stain was observed in any area of the brain. In the ipsilateral hippocampus, HRP stain was absent by 3 hours postinjury and remained so at the 6- and 12- hour time points. Surprisingly, HRP stain was again observed in the ipsilateral hippocampus 1 and 2 days following cortical contusion, indicating a biphasic opening of the BBB following head trauma and a possible second wave of secondary brain damage days after the contusion injury. These data indicate regions not initially destroyed by cortical impact, but evidencing BBB breach, may be accessible to neurotrophic factors administered intravenously both immediately and days after brain trauma.}
    \field{journaltitle}{J.Neurosurg.}
    \field{volume}{85}
    \field{pages}{476\bibrangedash 481}
    \keyw{cortical contusion,blood-brain barrier,horseradish peroxidase,head trauma,hippocampus,rat}
  \endentry

|;

my $l2 = q|  \entry{test2}{book}{}
    \name{labelname}{1}{%
      {{Smith}{S\bibinitperiod}{John\bibnamedelima Frederick}{J\bibinitperiod\bibinitdelim F\bibinitperiod}{}{}{III}{I\bibinitperiod}}%
    }
    \name{author}{1}{%
      {{Smith}{S\bibinitperiod}{John\bibnamedelima Frederick}{J\bibinitperiod\bibinitdelim F\bibinitperiod}{}{}{III}{I\bibinitperiod}}%
    }
    \name{editor}{1}{%
      {{Brown}{B\bibinitperiod}{Alan}{A\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{SIJF1}
    \strng{fullhash}{SIJF1}
    \field{sortinit}{S}
    \count{uniquename}{0}
    \field{pages}{1\bibrangedash 20}
    \keyw{keyword}
  \endentry

|;

is( $out->get_output_entry($main,'test1'), $l1, 'Basic RIS test - 1') ;
is( $out->get_output_entry($main,'test2'), $l2, 'Basic RIS test - 2') ;

unlink <*.utf8>;

