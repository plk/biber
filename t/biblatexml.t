# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';
use Text::Diff::Config;
$Text::Diff::Config::Output_Unicode = 1;

use Test::More tests => 5;
use Test::Differences;
unified_diff;

use Biber;
use Biber::Output::bbl;
use Log::Log4perl;
use Encode;

chdir("t/tdata");

# Set up Biber object
# THERE ARE MAPS IN THE BCF
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
Biber::Config->setoption('bcf', 'biblatexml.bcf');

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $main = $biber->datalists->get_list('custom/global//global/global/global');

my $bibentries = $section->bibentries;

my $l1 = q|    \entry{bltx1}{misc}{useprefix=false}{}
      \true{moreauthor}
      \true{morelabelname}
      \name[default][en-us]{author}{3}{useprefix=true}{%
        {{hash=bdef740dab20c2b52a3b6e0563c42bdb}{%
           family={Булгаков},
           familyi={Б\bibinitperiod},
           given={Павел\bibnamedelima Георгиевич},
           giveni={П\bibinitperiod\bibinitdelim Г\bibinitperiod},
           prefix={von},
           prefixi={v\bibinitperiod}}}%
        {{useprefix=false,hash=485f1e5d5e81a43fe067b440706c4979}{%
           family={РРозенфельд},
           familyi={Р\bibinitperiod},
           given={Борис-ZZ\bibnamedelima Aбрамович},
           giveni={Б\bibinithyphendelim Z\bibinitperiod\bibinitdelim A\bibinitperiod},
           prefix={von},
           prefixi={v\bibinitperiod}}}%
        {{hash=39dcc744aabf73006cb446d70a1beea2}{%
           family={Aхмедов},
           familyi={A\bibinitperiod},
           given={Ашраф\bibnamedelima Ахмедович},
           giveni={A\bibinitperiod\bibinitdelim А\bibinitperiod}}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Булгаков},
          familydefaulten-usi={Б\bibinitperiod},
          givendefaulten-us={Павел\bibnamedelima Георгиевич},
          givendefaulten-usi={П\bibinitperiod\bibinitdelim Г\bibinitperiod},
          prefixdefaulten-us={von},
          prefixdefaulten-usi={v\bibinitperiod}
      }
      \namepartms{author}{2}{%
          familydefaulten-us={РРозенфельд},
          familydefaulten-usi={Р\bibinitperiod},
          givendefaulten-us={Борис-ZZ\bibnamedelima Aбрамович},
          givendefaulten-usi={Б\bibinithyphendelim Z\bibinitperiod\bibinitdelim A\bibinitperiod},
          prefixdefaulten-us={von},
          prefixdefaulten-usi={v\bibinitperiod}
      }
      \namepartms{author}{3}{%
          familydefaulten-us={Aхмедов},
          familydefaulten-usi={A\bibinitperiod},
          givendefaulten-us={Ашраф\bibnamedelima Ахмедович},
          givendefaulten-usi={A\bibinitperiod\bibinitdelim А\bibinitperiod}
      }
      \name[default][en-us]{foreword}{1}{}{%
        {{hash=88354d4ba914f2ded2574386a2493996}{%
           family={Brown},
           familyi={B\bibinitperiod},
           given={John},
           giveni={J\bibinitperiod}}}%
      }
      \namepartms{foreword}{1}{%
          familydefaulten-us={Brown},
          familydefaulten-usi={B\bibinitperiod},
          givendefaulten-us={John},
          givendefaulten-usi={J\bibinitperiod}
      }
      \name[default][en-us]{translator}{1}{}{%
        {{hash=b44eba830fe9817fbe8e53c82f1cbe04}{%
           family={Smith},
           familyi={S\bibinitperiod},
           given={Paul},
           giveni={P\bibinitperiod}}}%
      }
      \namepartms{translator}{1}{%
          familydefaulten-us={Smith},
          familydefaulten-usi={S\bibinitperiod},
          givendefaulten-us={Paul},
          givendefaulten-usi={P\bibinitperiod}
      }
      \list{language}{1}{%
        {russian}%
      }
      \list[default][en-us]{location}{1}{%
        {Москва}%
      }
      \listitemms{location}{1}{%
        defaulten-us={Москва}
      }
      \list[default][en-us]{publisher}{1}{%
        {Наука}%
      }
      \listitemms{publisher}{1}{%
        defaulten-us={Наука}
      }
      \strng{namehash}{3400c73d7bf3e361d36350deb4832ad7}
      \strng{fullhash}{3400c73d7bf3e361d36350deb4832ad7}
      \strng{fullhashraw}{3400c73d7bf3e361d36350deb4832ad7}
      \strng{bibnamehash}{3400c73d7bf3e361d36350deb4832ad7}
      \strng{authordefaulten-usbibnamehash}{3400c73d7bf3e361d36350deb4832ad7}
      \strng{authordefaulten-usnamehash}{3400c73d7bf3e361d36350deb4832ad7}
      \strng{authordefaulten-usfullhash}{3400c73d7bf3e361d36350deb4832ad7}
      \strng{authordefaulten-usfullhashraw}{3400c73d7bf3e361d36350deb4832ad7}
      \strng{foreworddefaulten-usbibnamehash}{88354d4ba914f2ded2574386a2493996}
      \strng{foreworddefaulten-usnamehash}{88354d4ba914f2ded2574386a2493996}
      \strng{foreworddefaulten-usfullhash}{88354d4ba914f2ded2574386a2493996}
      \strng{foreworddefaulten-usfullhashraw}{a7a73749ea467229221b7e9cbf870988}
      \strng{translatordefaulten-usbibnamehash}{b44eba830fe9817fbe8e53c82f1cbe04}
      \strng{translatordefaulten-usnamehash}{b44eba830fe9817fbe8e53c82f1cbe04}
      \strng{translatordefaulten-usfullhash}{b44eba830fe9817fbe8e53c82f1cbe04}
      \strng{translatordefaulten-usfullhashraw}{b44eba830fe9817fbe8e53c82f1cbe04}
      \field{sortinit}{v}
      \strng{sortinithash}{afb52128e5b4dc4b843768c0113d673b}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{addendum}{userc}
      \field{eventday}{16}
      \field{eventendday}{17}
      \field{eventendmonth}{5}
      \field{eventendyear}{1990}
      \field{eventmonth}{5}
      \field{eventyear}{1990}
      \field{origyear}{356}
      \field{pagetotal}{240}
      \field[default][en-us]{series}{Научно-биографическая литература}
      \field[default][en-us]{title}{Мухаммад ибн муса ал-Хорезми. Около 783 – около 850}
      \field{urlendyear}{}
      \field{urlyear}{1991}
      \field{userb}{usera}
      \field{userd}{userc}
      \field{usere}{a}
      \field{year}{1980}
      \field{dateunspecified}{yearindecade}
      \field{dateera}{ce}
      \field{eventenddateera}{ce}
      \field{eventdateera}{ce}
      \field{origdateera}{bce}
      \true{urldatecirca}
      \field{urldateera}{ce}
      \field{pages}{1\bibrangedash 10\bibrangessep 30\bibrangedash 34}
      \range{pages}{15}
      \annotation[default][en-us]{field}{author}{alt}{}{}{0}{names-ann3}
      \annotation[default][en-us]{field}{author}{default}{}{}{0}{names-ann}
      \annotation{field}{language}{default}{}{}{0}{list-ann1}
      \annotation[default][en-us]{field}{title}{default}{}{}{0}{field-ann1}
      \annotation[default][en-us]{item}{author}{default}{1}{}{0}{name-ann1}
      \annotation[default][en-us]{item}{author}{default}{3}{}{0}{name-ann2}
      \annotation{item}{language}{default}{1}{}{0}{item-ann1}
      \annotation[default][en-us]{part}{author}{default}{1}{given}{1}{namepart-ann1}
      \annotation[default][en-us]{part}{author}{default}{2}{family}{0}{namepart-ann2}
    \endentry
|;

my $l2 = q|    \entry{loopkey:a}{book}{}{}
      \field{sortinit}{0}
      \strng{sortinithash}{c5602f03f17cc894ea7a6362c3cb0e13}
    \endentry
|;


my $bltx1 = 'mm,,,vonБулгаков   Павел Георгиевич  РРозенфельдБорис-ZZ AбрамовичvonAхмедов    Ашраф Ахмедович   ,1980,0,Мухаммад ибн муса ал-Хорезми. Около 783 – около 850';

# Test::Differences doesn't like utf8 unless it's encoded here
eq_or_diff(encode_utf8($out->get_output_entry('bltx1', $main)), encode_utf8($l1), 'BibLaTeXML - 1');
eq_or_diff($section->get_citekey_alias('bltx1a1'), 'bltx1', 'Citekey aliases - 1');
eq_or_diff($section->get_citekey_alias('bltx1a2'), 'bltx1', 'Citekey aliases - 2');
eq_or_diff(encode_utf8($main->get_sortdata_for_key('bltx1')->[0]), encode_utf8($bltx1), 'useprefix at name list and name scope - 1' );
eq_or_diff(encode_utf8($out->get_output_entry('loopkey:a', $main)), encode_utf8($l2), 'BibLaTeXML automapcreate - 1');
