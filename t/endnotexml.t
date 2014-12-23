# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 2;
use Test::Differences;
unified_diff;

use Biber;
use Biber::Output::bbl;
use Log::Log4perl;
chdir("t/tdata");

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

$biber->parse_ctrlfile('endnotexml.bcf');
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

# Mapped to "report" via user mapping to test user mappings
# Also created "usera" with original entrytype
my $l1 = q|    \entry{fpvfswdz9sw5e0edvxix5z26vxadptrzxfwa:42}{report}{}
      \name{author}{3}{}{%
        {{hash=5ed7d7f80cf3fd74517bb9c96a1d6ffa}{Alegria}{A\bibinitperiod}{M.}{M\bibinitperiod}{}{}{}{}}%
        {{hash=418031013857fb1f059185242baea41f}{Perez}{P\bibinitperiod}{D.\bibnamedelimi J.}{D\bibinitperiod\bibinitdelim J\bibinitperiod}{}{}{}{}}%
        {{hash=d016356435e41f9f216cd5ad5414be6c}{Williams}{W\bibinitperiod}{S.}{S\bibinitperiod}{}{}{}{}}%
      }
      \list{language}{1}{%
        {eng}%
      }
      \strng{namehash}{bb7cc58ecd32f38238f8c0ee2107e097}
      \strng{fullhash}{bb7cc58ecd32f38238f8c0ee2107e097}
      \field{sortinit}{A}
      \field{sortinithash}{b685c7856330eaee22789815b49de9bb}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{edition}{2003/10/01}
      \field{isbn}{0278-2715 (Print)}
      \field{label}{Journal Article}
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
      \field{subtitle}{Health Aff (Millwood)}
      \field{title}{The role of public policies in reducing mental health status disparities for people of color}
      \field{volume}{22}
      \field{pages}{51\bibrangedash 66}
      \range{pages}{16}
      \keyw{{Adult},{Child},{Education, Special/economics/legislation & jurisprudence},{Health Policy/ legislation & jurisprudence},{Health Services Accessibility/statistics & numerical data},{Health Services Needs and Demand},{Housing/economics/legislation & jurisprudence},{Humans},{Income Tax/legislation & jurisprudence},{Mental Disorders/economics/ ethnology/therapy},{Mental Health Services/economics/ organization & administration},{Minority Groups/ statistics & numerical data},{Poverty},{Social Conditions},{Socioeconomic Factors},{Sociology, Medical},{United States/epidemiology}}
      \warn{\item Datamodel: Entry 'fpvfswdz9sw5e0edvxix5z26vxadptrzxfwa:42' (endnote.xml): Invalid format 'Sep-Oct' of date field 'date' - ignoring}
    \endentry
|;

my $l2 = q|    \entry{fpvfswdz9sw5e0edvxix5z26vxadptrzxfwa:47}{report}{}
      \name{author}{1}{}{%
        {{hash=346ad1f92291bef45511d3eb23e3df34}{Amico}{A\bibinitperiod}{Sir\bibnamedelimb Kevin}{K\bibinitperiod}{R}{R\bibinitperiod}{}{}{Jr}{J\bibinitperiod}}%
      }
      \list{language}{1}{%
        {eng}%
      }
      \strng{namehash}{346ad1f92291bef45511d3eb23e3df34}
      \strng{fullhash}{346ad1f92291bef45511d3eb23e3df34}
      \field{sortinit}{A}
      \field{sortinithash}{b685c7856330eaee22789815b49de9bb}
      \field{labelyear}{2009}
      \field{labelmonth}{03}
      \field{labelday}{14}
      \field{datelabelsource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{shorttitle}
      \field{day}{14}
      \field{edition}{2009/07/18}
      \field{isbn}{1541-0048 (Electronic)}
      \field{label}{Journal Article}
      \field{month}{03}
      \field{note}{Amico, K Rivet
Review
United States
American journal of public health
Am J Public Health. 2009 Sep;99(9):1567-75. Epub 2009 Jul 16.}
      \field{number}{9}
      \field{shorttitle}{PTA}
      \field{subtitle}{Am J Public Health}
      \field{title}{Percent total attrition: a poor metric for study rigor in hosted intervention designs}
      \field{volume}{99}
      \field{year}{2009}
      \field{pages}{1567\bibrangedash 75}
      \range{pages}{9}
      \verb{eprint}
      \verb AJPH.2008.134767
      \endverb
      \verb{url}
      \verb http://www.sun.com
      \endverb
      \keyw{{Health Promotion},{Humans},{Intervention Studies},{Outcome Assessment (Health Care)/methods},{Patient Dropouts},{Patient Selection},{Reproducibility of Results},{Research Design}}
    \endentry
|;

eq_or_diff( $out->get_output_entry('fpvfswdz9sw5e0edvxix5z26vxadptrzxfwa:42', $main), $l1, 'Basic Endnote XML test - 1') ;
eq_or_diff( $out->get_output_entry('fpvfswdz9sw5e0edvxix5z26vxadptrzxfwa:47', $main), $l2, 'Basic Endnote XML test - 2') ;
