# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 3;

use Biber;
use Biber::Output::bbl;
use Log::Log4perl;
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
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'C');

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $main = $biber->sortlists->get_list(0, 'entry', 'nty');
my $bibentries = $section->bibentries;

my $l1 = q|    \entry{origmode}{book}{}
      \true{morelabelname}
      \name{form=original,lang=default}{labelname}{3}{}{%
        {{hash=7b4da3df896da456361ae44dc651770a}{Булгаков}{Б\bibinitperiod}{Павел\bibnamedelima Георгиевич}{П\bibinitperiod\bibinitdelim Г\bibinitperiod}{}{}{}{}}%
        {{hash=ee55ff3b0e4268cfb193143e86c283a9}{Розенфельд}{Р\bibinitperiod}{Борис-ZZ\bibnamedelima Aбрамович}{Б\bibinithyphendelim Z\bibinitperiod\bibinitdelim A\bibinitperiod}{Билл}{Б\bibinitperiod}{}{}{}{}}%
        {{hash=e708d5a31534e937578abf161c867a25}{Aхмедов}{A\bibinitperiod}{Ашраф\bibnamedelima Ахмедович}{А\bibinitperiod\bibinitdelim А\bibinitperiod}{}{}{}{}}%
      }
      \true{moreauthor}
      \name{form=uniform,lang=default}{author}{3}{}{%
        {{hash=eebdb6e8831004ef71d26f7c2b77f3d1}{Bulgakov}{B\bibinitperiod}{Pavel\bibnamedelima G.}{P\bibinitperiod\bibinitdelim G\bibinitperiod}{}{}{}{}}%
        {{hash=aa7443826b696f2ac320d278f0fe5f5a}{Rozenfeld}{R\bibinitperiod}{Boris\bibnamedelima A.}{B\bibinitperiod\bibinitdelim A\bibinitperiod}{Bill}{B\bibinitperiod}{}{}{}{}}%
        {{hash=7d83f818351bce3d953d5056ee449a81}{Akhmedov}{A\bibinitperiod}{Ashraf\bibnamedelima A.}{A\bibinitperiod\bibinitdelim A\bibinitperiod}{}{}{}{}}%
      }
      \name{form=original,lang=default}{author}{3}{}{%
        {{hash=7b4da3df896da456361ae44dc651770a}{Булгаков}{Б\bibinitperiod}{Павел\bibnamedelima Георгиевич}{П\bibinitperiod\bibinitdelim Г\bibinitperiod}{}{}{}{}}%
        {{hash=ee55ff3b0e4268cfb193143e86c283a9}{Розенфельд}{Р\bibinitperiod}{Борис-ZZ\bibnamedelima Aбрамович}{Б\bibinithyphendelim Z\bibinitperiod\bibinitdelim A\bibinitperiod}{Билл}{Б\bibinitperiod}{}{}{}{}}%
        {{hash=e708d5a31534e937578abf161c867a25}{Aхмедов}{A\bibinitperiod}{Ашраф\bibnamedelima Ахмедович}{А\bibinitperiod\bibinitdelim А\bibinitperiod}{}{}{}{}}%
      }
      \list{form=original,lang=default}{language}{1}{%
        {Russian}%
      }
      \list{form=uniform,lang=default}{location}{1}{%
        {Moscow}%
      }
      \list{form=original,lang=default}{location}{1}{%
        {Москва}%
      }
      \list{form=romanised,lang=default}{location}{1}{%
        {Moskva}%
      }
      \list{form=original,lang=default}{publisher}{1}{%
        {Наука}%
      }
      \list{form=romanised,lang=default}{publisher}{1}{%
        {Nauka}%
      }
      \list{form=translated,lang=default}{publisher}{1}{%
        {Science}%
      }
      \strng{namehash}{80e524d8402a5619e59ea67ea2d937a5}
      \strng{fullhash}{afcf3a11058ba0a3fc7609c2a29ae6da}
      \field{form=original,lang=default}{sortinit}{Б}
      \field{form=original,lang=default}{labelyear}{1983}
      \field{form=original,lang=default}{labeltitle}{Мухаммад ибн муса ал-Хорезми. Около 783 – около 850}
      \field{form=original,lang=default}{eventday}{16}
      \field{form=original,lang=default}{eventendday}{17}
      \field{form=original,lang=default}{eventendmonth}{05}
      \field{form=original,lang=default}{eventendyear}{1990}
      \field{form=original,lang=default}{eventmonth}{05}
      \field{form=original,lang=default}{eventyear}{1990}
      \field{form=original,lang=default}{origday}{02}
      \field{form=original,lang=default}{origmonth}{04}
      \field{form=original,lang=default}{origyear}{1985}
      \field{form=original,lang=default}{pagetotal}{240}
      \field{form=original,lang=default}{series}{Научно-биографическая литература}
      \field{form=romanised,lang=default}{series}{Nauchno-biograficheskaya literatura}
      \field{form=original,lang=default}{title}{Мухаммад ибн муса ал-Хорезми. Около 783 – около 850}
      \field{form=romanised,lang=default}{title}{Mukhammad al-Khorezmi. Okolo 783 – okolo 850}
      \field{form=translated,lang=default}{title}{Mukhammad al-Khorezmi. Ca. 783 – ca. 850}
      \field{form=original,lang=default}{urlday}{01}
      \field{form=original,lang=default}{urlendyear}{}
      \field{form=original,lang=default}{urlmonth}{07}
      \field{form=original,lang=default}{urlyear}{1991}
      \field{form=original,lang=default}{year}{1983}
    \endentry
|;

is( $out->get_output_entry('origmode', $main), $l1, 'BibLaTeXML displaymode test - 1');
is($section->get_citekey_alias('origmodea1'), 'origmode', 'Citekey aliases - 1');
is($section->get_citekey_alias('origmodea2'), 'origmode', 'Citekey aliases - 2');
