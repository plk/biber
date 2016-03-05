# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8' ;

use Test::More;
use Test::Differences;
unified_diff;

if ($ENV{BIBER_DEV_TESTS}) {
  plan tests => 3;
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
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('quiet', 1);
Biber::Config->setoption('nodieonerror', 1); # because the remote bibs might be messy

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $main = $biber->sortlists->get_list(0, 'nty/global/', 'entry', 'nty', 'global', '');
my $bibentries = $section->bibentries;

my $cu1 = q|    \entry{citeulike:8283461}{article}{}
      \name{author}{4}{}{%
        {{uniquename=0,hash=aba7750b7045425a3cf8573f7710ec18}{%
           family={Marazziti},
           family_i={M\bibinitperiod},
           given={D.},
           given_i={D\bibinitperiod}}}%
        {{uniquename=0,hash=1f2c257ff6c86cffeb33019b6d8598c5}{%
           family={Akiskal},
           family_i={A\\bibinitperiod},
           given={H.\bibnamedelimi S.},
           given_i={H\bibinitperiod\bibinitdelim S\bibinitperiod}}}%
        {{uniquename=0,hash=e1b1769dbb6e7d04008811b49cd745a9}{%
           family={Rossi},
           family_i={R\bibinitperiod},
           given={A.},
           given_i={A\bibinitperiod}}}%
        {{uniquename=0,hash=b1d8ec8b73d39a27898e50cfa3e3c676}{%
           family={Cassano},
           family_i={C\bibinitperiod},
           given={G.\bibnamedelimi B.},
           given_i={G\bibinitperiod\bibinitdelim B\bibinitperiod}}}%
      }
      \strng{namehash}{7f19319e09aa3239f02eb31ec7a4aa8b}
      \strng{fullhash}{ee363ce5e21ebe022f83aae896dd47f9}
      \field{sortinit}{M}
      \field{sortinithash}{2684bec41e9697b92699b46491061da2}
      \field{labelyear}{1999}
      \field{labelmonth}{05}
      \field{datelabelsource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{abstract}{{BACKGROUND}: The evolutionary consequences of love are so important that there must be some long-established biological process regulating it. Recent findings suggest that the serotonin ({5-HT}) transporter might be linked to both neuroticism and sexual behaviour as well as to obsessive-compulsive disorder ({OCD}). The similarities between an overvalued idea, such as that typical of subjects in the early phase of a love relationship, and obsession, prompted us to explore the possibility that the two conditions might share alterations at the level of the {5-HT} transporter. {METHODS}: Twenty subjects who had recently (within the previous 6 months) fallen in love, 20 unmedicated {OCD} patients and 20 normal controls, were included in the study. The {5-HT} transporter was evaluated with the specific binding of {3H}-paroxetine ({3H}-Par) to platelet membranes. {RESULTS}: The results showed that the density of {3H}-Par binding sites was significantly lower in subjects who had recently fallen in love and in {OCD} patients than in controls. {DISCUSSION}: The main finding of the present study is that subjects who were in the early romantic phase of a love relationship were not different from {OCD} patients in terms of the density of the platelet {5-HT} transporter, which proved to be significantly lower than in the normal controls. This would suggest common neurochemical changes involving the {5-HT} system, linked to psychological dimensions shared by the two conditions, perhaps at an ideational level.}
      \field{issn}{0033-2917}
      \field{journaltitle}{Psychological medicine}
      \field{month}{05}
      \field{number}{3}
      \field{title}{Alteration of the platelet serotonin transporter in romantic love.}
      \field{volume}{29}
      \field{year}{1999}
      \field{pages}{741\bibrangedash 745}
      \range{pages}{5}
      \verb{url}
      \verb http://www.biomedexperts.com/Abstract.bme/10405096
      \endverb
      \keyw{love,romantic}
    \endentry
|;

my $dl1 = q|    \entry{AbdelbarH98}{article}{}
      \name{author}{2}{}{%
        {{uniquename=0,hash=14c582ce40292affd427311ca8e3bc9c}{%
           family={Abdelbar},
           family_i={A\bibinitperiod},
           given={A.M.},
           given_i={A\bibinitperiod}}}%
        {{uniquename=0,hash=558ac9729b484b6f378e45a86582ea1d}{%
           family={Hedetniemi},
           family_i={H\bibinitperiod},
           given={S.M.},
           given_i={S\bibinitperiod}}}%
      }
      \strng{namehash}{01599a4cb58316d64208b12a07741765}
      \strng{fullhash}{01599a4cb58316d64208b12a07741765}
      \field{sortinit}{A}
      \field{sortinithash}{b685c7856330eaee22789815b49de9bb}
      \field{labelyear}{1998}
      \field{datelabelsource}{}
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

my $ssl = q|    \entry{merleau-ponty_philosophe_2010}{incollection}{}
      \name{author}{1}{}{%
        {{uniquename=0,hash=83d062f99d033839537243075d75bad2}{%
           family={Merleau-Ponty},
           family_i={M\bibinithyphendelim P\bibinitperiod},
           given={Maurice},
           given_i={M\bibinitperiod}}}%
      }
      \name{editor}{1}{}{%
        {{hash=ff5f90046157eecef0c22da4dac6486e}{%
           family={Lefort},
           family_i={L\bibinitperiod},
           given={Claude},
           given_i={C\bibinitperiod}}}%
      }
      \list{language}{1}{%
        {Fransk}%
      }
      \list{location}{1}{%
        {Paris}%
      }
      \list{publisher}{1}{%
        {Éditions Gallimard}%
      }
      \strng{namehash}{83d062f99d033839537243075d75bad2}
      \strng{fullhash}{83d062f99d033839537243075d75bad2}
      \field{sortinit}{M}
      \field{sortinithash}{2684bec41e9697b92699b46491061da2}
      \field{labelyear}{2010}
      \field{datelabelsource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{booktitle}{Œuvres}
      \field{title}{Le philosophe et son ombre}
      \field{year}{2010}
      \field{pages}{1267\bibrangedash 1289}
      \range{pages}{23}
      \keyw{Husserl,Edmund,autrui,chair,constitution,intercorporéité,l'impensé,ouverture}
    \endentry
|;


eq_or_diff( $out->get_output_entry('citeulike:8283461', $main), $cu1, 'Fetch from citeulike') ;
eq_or_diff( $out->get_output_entry('AbdelbarH98', $main), $dl1, 'Fetch from plain bib download') ;
eq_or_diff( $out->get_output_entry('merleau-ponty_philosophe_2010', $main), $ssl, 'HTTPS test') ;
