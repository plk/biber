use strict;
use warnings;
use utf8;
no warnings 'utf8';

#use Test::More skip_all => 'bltxml not working yet';
use Test::More tests => 1;

use Biber;
use Biber::Input::file::bibtex;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
chdir("t/tdata");

# Set up Biber object
my $biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('biblatexml.bcf');
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

my $l1 = q|  \entry{BulgakovRozenfeld:1983}{book}{}
    \name{labelname}{3}{%
      {{Булгаков}{Б\bibinitperiod}{Павел\bibnbnamedelim Георгиевич}{П\bibinitperiod\bibinitdelim Г\bibinitperiod}{}{}{}{}}%
      {{Розенфельд}{Р\bibinitperiod}{Борис-ZZ\bibnbnamedelim Aбрамович}{Б\bibinithyphendelim Z\bibinitperiod\bibinitdelim A\bibinitperiod}{Билл}{Б\bibinitperiod}{}{}{}{}}%
      {{Aхмедов}{A\bibinitperiod}{Ашраф\bibnbnamedelim Ахмедович}{А\bibinitperiod\bibinitdelim А\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{3}{%
      {{Булгаков}{Б\bibinitperiod}{Павел\bibnbnamedelim Георгиевич}{П\bibinitperiod\bibinitdelim Г\bibinitperiod}{}{}{}{}}%
      {{Розенфельд}{Р\bibinitperiod}{Борис-ZZ\bibnbnamedelim Aбрамович}{Б\bibinithyphendelim Z\bibinitperiod\bibinitdelim A\bibinitperiod}{Билл}{Б\bibinitperiod}{}{}{}{}}%
      {{Aхмедов}{A\bibinitperiod}{Ашраф\bibnbnamedelim Ахмедович}{А\bibinitperiod\bibinitdelim А\bibinitperiod}{}{}{}{}}%
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
    \strng{namehash}{БПГРБ-ZAБAАА1}
    \strng{fullhash}{БПГРБ-ZAБAАА1}
    \field{sortinit}{Б}
    \field{labelyear}{1983}
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
    \field{series}{Научно-биографическая литература}
    \field{title}{Mukhammad al-Khorezmi. Ca. 783 – ca. 850}
    \field{urlday}{01}
    \field{urlendyear}{}
    \field{urlmonth}{07}
    \field{urlyear}{1991}
    \field{year}{1983}
  \endentry

|;

is( $out->get_output_entry($main, 'bulgakovrozenfeld:1983'), $l1, 'Basic BibLaTeXML test - 1') ;

unlink <*.utf8>;
