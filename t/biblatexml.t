# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';
use Text::Diff::Config;
$Text::Diff::Config::Output_Unicode = 1;


use Test::More tests => 4;
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
Biber::Config->setoption('bcf', 'biblatexml.bcf');

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $main = $biber->sortlists->get_list(0, 'nty/global', 'entry', 'nty', 'global');
my $bibentries = $section->bibentries;

my $l1 = q|    \entry{bltx1}{book}{useprefix=false}
      \true{moreauthor}
      \name{author}{3}{useprefix=true}{%
        {{hash=d16c52bc219d448d5f07dc865d5c4f54}{Булгаков}{Б\\bibinitperiod}{Павел\\bibnamedelima Георгиевич}{П\\bibinitperiod\\bibinitdelim Г\\bibinitperiod}{von}{v\\bibinitperiod}{}{}}%
        {{hash=9f2c2b41c55d40495140c437adb24c7f}{Розенфельд}{Р\\bibinitperiod}{Борис-ZZ\\bibnamedelima Aбрамович}{Б\\bibinithyphendelim Z\\bibinitperiod\\bibinitdelim A\\bibinitperiod}{von}{v\\bibinitperiod}{}{}}%
        {{hash=e708d5a31534e937578abf161c867a25}{Aхмедов}{A\bibinitperiod}{Ашраф\bibnamedelima Ахмедович}{А\bibinitperiod\bibinitdelim А\bibinitperiod}{}{}{}{}}%
      }
      \list{language}{1}{%
        {russian}%
      }
      \list{location}{1}{%
        {Москва}%
      }
      \list{publisher}{1}{%
        {Наука}%
      }
      \strng{namehash}{b5cf3ab49063f1ac8cf913eb3527f38e}
      \strng{fullhash}{d934abc5fadc45af86b9fc5160209def}
      \field{sortinit}{v}
      \field{sortinithash}{d18f5ce25ce0b5ca7f924e3f6c04870e}
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
      \field{title}{Мухаммад ибн муса ал-Хорезми. Около 783 – около 850}
      \field{urlday}{01}
      \field{urlendyear}{}
      \field{urlmonth}{07}
      \field{urlyear}{1991}
      \field{year}{1983}
      \field{pages}{1\\bibrangedash 10\\bibrangessep 30\\bibrangedash 34}
      \range{pages}{15}
    \endentry
|;
my $bltx1 = "mm,,,von!Булгаков!Павел Георгиевич#Розенфельд!БорисZZ Aбрамович!von#Aхмедов!Ашраф Ахмедович,1983,0000,Мухаммад ибн муса алХорезми Около 783 около 850";

# Test::Differences doesn't like utf8 unless it's encoded here
eq_or_diff(encode_utf8($out->get_output_entry('bltx1', $main)), encode_utf8($l1), 'BibLaTeXML - 1');
eq_or_diff($section->get_citekey_alias('bltx1a1'), 'bltx1', 'Citekey aliases - 1');
eq_or_diff($section->get_citekey_alias('bltx1a2'), 'bltx1', 'Citekey aliases - 2');
eq_or_diff(encode_utf8($main->get_sortdata('bltx1')->[0]), encode_utf8($bltx1), 'useprefix at name list and name scope - 1' );
