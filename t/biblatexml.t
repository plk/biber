# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';
use Text::Diff::Config;
$Text::Diff::Config::Output_Unicode = 1;

use Test::More tests => 3;
use Test::Differences;
unified_diff;

use Biber;
use Biber::Output::bbl;
use Log::Log4perl;
use Encode;

chdir("t/tdata");

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
$biber->parse_ctrlfile('biblatexml.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');
Biber::Config->setoption('fastsort', 1);

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $main = $biber->sortlists->get_list(0, 'nty', 'entry', 'nty');
my $bibentries = $section->bibentries;

my $l1 = q|    \entry{bltx1}{book}{}
      \true{moreauthor}
      \name{author}{3}{}{%
        {{hash=7b4da3df896da456361ae44dc651770a}{Булгаков}{Б\bibinitperiod}{Павел\bibnamedelima Георгиевич}{П\bibinitperiod\bibinitdelim Г\bibinitperiod}{}{}{}{}}%
        {{hash=ee55ff3b0e4268cfb193143e86c283a9}{Розенфельд}{Р\bibinitperiod}{Борис-ZZ\bibnamedelima Aбрамович}{Б\bibinithyphendelim Z\bibinitperiod\bibinitdelim A\bibinitperiod}{Билл}{Б\bibinitperiod}{}{}{}{}}%
        {{hash=e708d5a31534e937578abf161c867a25}{Aхмедов}{A\bibinitperiod}{Ашраф\bibnamedelima Ахмедович}{А\bibinitperiod\bibinitdelim А\bibinitperiod}{}{}{}{}}%
      }
      \list{language}{1}{%
        {Russian}%
      }
      \list{location}{1}{%
        {Москва}%
      }
      \list{publisher}{1}{%
        {Наука}%
      }
      \strng{namehash}{80e524d8402a5619e59ea67ea2d937a5}
      \strng{fullhash}{afcf3a11058ba0a3fc7609c2a29ae6da}
      \field{sortinit}{Б}
      \field{sortinithash}{161dbde41bd990699d9b7ff419202d50}
      \field{labelyear}{1983}
      \field{datelabelsource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{eventday}{16}
      \field{eventendday}{17}
      \field{eventendmonth}{05}
      \field{eventendyear}{1990}
      \field{eventmonth}{05}
      \field{eventyear}{1990}
      \field{origday}{02}
      \field{origmonth}{04}
      \field{origyear}{1985}
      \field{pagetotal}{240}
      \field{relatedstring}{Somestring}
      \field{relatedtype}{reprint}
      \field{series}{Научно-биографическая литература}
      \field{title}{Mukhammad al-Khorezmi. Ca. 783 – ca. 850}
      \field{urlday}{01}
      \field{urlendyear}{}
      \field{urlmonth}{07}
      \field{urlyear}{1991}
      \field{year}{1983}
    \endentry
|;

# Test::Differences doesn't like utf8 unless it's encoded here
eq_or_diff(encode_utf8($out->get_output_entry('bltx1', $main)), encode_utf8($l1), 'BibLaTeXML - 1');
eq_or_diff($section->get_citekey_alias('bltx1a1'), 'bltx1', 'Citekey aliases - 1');
eq_or_diff($section->get_citekey_alias('bltx1a2'), 'bltx1', 'Citekey aliases - 2');
