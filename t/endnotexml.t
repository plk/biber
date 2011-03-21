use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 2;

use Biber;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
chdir("t/tdata");

# Set up Biber object
my $biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('endnotexml.bcf');
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

my $l1 = q|  \entry{fpvfswdz9sw5e0edvxix5z26vxadptrzxfwa:42}{article}{}
    \name{labelname}{3}{%
      {{Alegria}{A\bibinitperiod}{M.}{M\bibinitperiod}{}{}{}{}}%
      {{Perez}{P\bibinitperiod}{D.\bibnamedelimi J.}{D\bibinitperiod\bibinitdelim J\bibinitperiod}{}{}{}{}}%
      {{Williams}{W\bibinitperiod}{S.}{S\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{3}{%
      {{Alegria}{A\bibinitperiod}{M.}{M\bibinitperiod}{}{}{}{}}%
      {{Perez}{P\bibinitperiod}{D.\bibnamedelimi J.}{D\bibinitperiod\bibinitdelim J\bibinitperiod}{}{}{}{}}%
      {{Williams}{W\bibinitperiod}{S.}{S\bibinitperiod}{}{}{}{}}%
    }
    \list{language}{1}{%
      {eng}%
    }
    \strng{namehash}{AMPDJWS1}
    \strng{fullhash}{AMPDJWS1}
    \field{sortinit}{A}
    \field{labelyear}{2003}
    \field{abstract}{Ethnic and racial disparities in mental health are driven by social factors such as housing, education, and income. Many of these social factors are different for minorities than they are for whites. Policies that address gaps in these social factors therefore can address mental health status disparities. We analyze three policies and their impact on minorities: the Individuals with Disability Education Act, Section 8 housing vouchers, and the Earned Income Tax Credit. Two of the three policies appear to have been effective in reducing social inequalities between whites and minorities. Expansion of public policies can be the mechanism to eliminate mental health status disparities for minorities.}
    \field{edition}{2003/10/01}
    \field{issn}{0278-2715 (Print)}
    \field{journaltitle}{Health Aff (Millwood)}
    \field{note}{Alegria, Margarita
Perez, Debra Joy
Williams, Sandra
P01H510803/United States PHS
P01MH59876/MH/United States NIMH
Comparative Study
Research Support, U.S. Gov't, P.H.S.
United States
Health affairs (Project Hope)
Health Aff (Millwood). 2003 Sep-Oct;22(5):51-64.}
    \field{number}{5}
    \field{title}{The role of public policies in reducing mental health status disparities for people of color}
    \field{volume}{22}
    \field{year}{2003}
    \field{pages}{51\bibrangedash 64}
    \keyw{{Adult},{Child},{Education, Special/economics/legislation \& jurisprudence},{Health Policy/ legislation \& jurisprudence},{Health Services Accessibility/statistics \& numerical data},{Health Services Needs and Demand},{Housing/economics/legislation \& jurisprudence},{Humans},{Income Tax/legislation \& jurisprudence},{Mental Disorders/economics/ ethnology/therapy},{Mental Health Services/economics/ organization \& administration},{Minority Groups/ statistics \& numerical data},{Poverty},{Social Conditions},{Socioeconomic Factors},{Sociology, Medical},{United States/epidemiology}}
    \warn{\item Invalid format 'Sep-Oct' of date field 'pub-dates' in entry 'fpvfswdz9sw5e0edvxix5z26vxadptrzxfwa:42' - ignoring}
  \endentry

|;

my $l2 = q|  \entry{fpvfswdz9sw5e0edvxix5z26vxadptrzxfwa:47}{article}{}
    \name{labelname}{1}{%
      {{Amico}{A\bibinitperiod}{Sir\bibnamedelimb Kevin}{K\bibinitperiod}{R}{R\bibinitperiod}{}{}{Jr}{J\bibinitperiod}}%
    }
    \name{author}{1}{%
      {{Amico}{A\bibinitperiod}{Sir\bibnamedelimb Kevin}{K\bibinitperiod}{R}{R\bibinitperiod}{}{}{Jr}{J\bibinitperiod}}%
    }
    \list{language}{1}{%
      {eng}%
    }
    \strng{namehash}{AJKR1}
    \strng{fullhash}{AJKR1}
    \field{sortinit}{A}
    \field{labelyear}{2009}
    \field{abstract}{Health behavior interventions delivered at point of service include those that yoke an intervention protocol with existing systems of care (e.g., clinical care, social work, or case management). Though beneficial in a number of ways, such "hosted" intervention studies may be unable to retain participants that specifically discontinue their use of the hosting service. In light of recent practices that use percent total attrition as indicative of methodological flaws, hosted interventions targeting hard-to-reach populations may be excluded from consideration in effective intervention compendiums or research synthesis because of high attrition rates that may in fact be secondary to the natural flow of service use or unrelated to differential attrition or internal design flaws. Better methods to characterize rigor are needed.}
    \field{day}{14}
    \field{edition}{2009/07/18}
    \field{issn}{1541-0048 (Electronic)}
    \field{journaltitle}{Am J Public Health}
    \field{month}{03}
    \field{note}{Amico, K Rivet
Review
United States
American journal of public health
Am J Public Health. 2009 Sep;99(9):1567-75. Epub 2009 Jul 16.}
    \field{number}{9}
    \field{shorttitle}{PTA}
    \field{title}{Percent total attrition: a poor metric for study rigor in hosted intervention designs}
    \field{volume}{99}
    \field{year}{2009}
    \field{pages}{1567\bibrangedash 75}
    \verb{eprint}
    \verb AJPH.2008.134767
    \endverb
    \verb{url}
    \verb http://www.sun.com
    \endverb
    \keyw{{Health Promotion},{Humans},{Intervention Studies},{Outcome Assessment (Health Care)/methods},{Patient Dropouts},{Patient Selection},{Reproducibility of Results},{Research Design}}
    \warn{\item Invalid format 'Sep' of date field 'pub-dates' in entry 'fpvfswdz9sw5e0edvxix5z26vxadptrzxfwa:47' - ignoring}
  \endentry

|;

is( $out->get_output_entry($main, 'fpvfswdz9sw5e0edvxix5z26vxadptrzxfwa:42'), $l1, 'Basic Endnote XML test - 1') ;
is( $out->get_output_entry($main, 'fpvfswdz9sw5e0edvxix5z26vxadptrzxfwa:47'), $l2, 'Basic Endnote XML test - 2') ;

unlink <*.utf8>;
