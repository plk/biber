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
$biber->parse_ctrlfile('remote-files.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'C');
Biber::Config->setoption('quiet', 1);

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $main = $section->get_list('MAIN');
my $bibentries = $section->bibentries;

my $cu1 = q|  \entry{citeulike:8283461}{article}{}
    \name{labelname}{4}{}{%
      {{uniquename=0}{Marazziti}{M\bibinitperiod}{D.}{D\bibinitperiod}{}{}{}{}}%
      {{uniquename=0}{Akiskal}{A\bibinitperiod}{H.\bibnamedelimi S.}{H\bibinitperiod\bibinitdelim S\bibinitperiod}{}{}{}{}}%
      {{uniquename=0}{Rossi}{R\bibinitperiod}{A.}{A\bibinitperiod}{}{}{}{}}%
      {{uniquename=0}{Cassano}{C\bibinitperiod}{G.\bibnamedelimi B.}{G\bibinitperiod\bibinitdelim B\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{4}{}{%
      {{}{Marazziti}{M\bibinitperiod}{D.}{D\bibinitperiod}{}{}{}{}}%
      {{}{Akiskal}{A\bibinitperiod}{H.\bibnamedelimi S.}{H\bibinitperiod\bibinitdelim S\bibinitperiod}{}{}{}{}}%
      {{}{Rossi}{R\bibinitperiod}{A.}{A\bibinitperiod}{}{}{}{}}%
      {{}{Cassano}{C\bibinitperiod}{G.\bibnamedelimi B.}{G\bibinitperiod\bibinitdelim B\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{MD+1}
    \strng{fullhash}{MDAHSRACGB1}
    \field{sortinit}{M}
    \field{labelyear}{1999}
    \field{abstract}{{BACKGROUND}: The evolutionary consequences of love are so important that there must be some long-established biological process regulating it. Recent findings suggest that the serotonin ({5-HT}) transporter might be linked to both neuroticism and sexual behaviour as well as to obsessive-compulsive disorder ({OCD}). The similarities between an overvalued idea, such as that typical of subjects in the early phase of a love relationship, and obsession, prompted us to explore the possibility that the two conditions might share alterations at the level of the {5-HT} transporter. {METHODS}: Twenty subjects who had recently (within the previous 6 months) fallen in love, 20 unmedicated {OCD} patients and 20 normal controls, were included in the study. The {5-HT} transporter was evaluated with the specific binding of {3H}-paroxetine ({3H}-Par) to platelet membranes. {RESULTS}: The results showed that the density of {3H}-Par binding sites was significantly lower in subjects who had recently fallen in love and in {OCD} patients than in controls. {DISCUSSION}: The main finding of the present study is that subjects who were in the early romantic phase of a love relationship were not different from {OCD} patients in terms of the density of the platelet {5-HT} transporter, which proved to be significantly lower than in the normal controls. This would suggest common neurochemical changes involving the {5-HT} system, linked to psychological dimensions shared by the two conditions, perhaps at an ideational level.}
    \field{issn}{0033-2917}
    \field{journaltitle}{Psychological medicine}
    \field{month}{05}
    \field{number}{3}
    \field{title}{Alteration of the platelet serotonin transporter in romantic love.}
    \field{volume}{29}
    \field{year}{1999}
    \field{pages}{741\bibrangedash 745}
    \verb{url}
    \verb http://www.biomedexperts.com/Abstract.bme/10405096
    \endverb
    \keyw{love, romantic}
  \endentry

|;

my $dl1 = q|  \entry{AbdelbarH98}{article}{}
    \name{labelname}{2}{}{%
      {{uniquename=0}{Abdelbar}{A\bibinitperiod}{A.M.}{A\bibinitperiod}{}{}{}{}}%
      {{uniquename=0}{Hedetniemi}{H\bibinitperiod}{S.M.}{S\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{2}{}{%
      {{}{Abdelbar}{A\bibinitperiod}{A.M.}{A\bibinitperiod}{}{}{}{}}%
      {{}{Hedetniemi}{H\bibinitperiod}{S.M.}{S\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{AAHS1}
    \strng{fullhash}{AAHS1}
    \field{sortinit}{A}
    \field{labelyear}{1998}
    \field{journaltitle}{Artificial Intelligence}
    \field{title}{Approximating {MAP}s for belief networks is {NP}-hard and other theorems}
    \field{volume}{102}
    \field{year}{1998}
    \field{pages}{21\bibrangedash 38}
  \endentry

|;

is( $out->get_output_entry($main,'citeulike:8283461'), $cu1, 'Fetch from citeulike') ;
is( $out->get_output_entry($main,'AbdelbarH98'), $dl1, 'Fetch from plain bib download') ;


