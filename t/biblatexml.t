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
my $main = $biber->datalists->get_list('custom/global//global/global');

my $bibentries = $section->bibentries;

my $l1 = q|    \entry{bltx1}{misc}{useprefix=false}
      \true{moreauthor}
      \true{morelabelname}
      \name{author}{3}{useprefix=true}{%
        {{hash=633a0b6ab963c5f044b56f06c6091c27}{%
           family={Булгаков},
           familyi={Б\\bibinitperiod},
           given={Павел\\bibnamedelima Георгиевич},
           giveni={П\\bibinitperiod\\bibinitdelim Г\\bibinitperiod},
           prefix={von},
           prefixi={v\\bibinitperiod}}}%
        {{useprefix=false,hash=0ffcce4df8f0d0eedf2c614091ba2355}{%
           family={РРозенфельд},
           familyi={Р\\bibinitperiod},
           given={Борис-ZZ\\bibnamedelima Aбрамович},
           giveni={Б\\bibinithyphendelim Z\\bibinitperiod\\bibinitdelim A\\bibinitperiod},
           prefix={von},
           prefixi={v\\bibinitperiod}}}%
        {{hash=e708d5a31534e937578abf161c867a25}{%
           family={Aхмедов},
           familyi={A\\bibinitperiod},
           given={Ашраф\\bibnamedelima Ахмедович},
           giveni={A\\bibinitperiod\\bibinitdelim А\\bibinitperiod}}}%
      }
      \name{foreword}{1}{}{%
        {{hash=0ee59e598dae22fac8e6d9d2df7e79ec}{%
           family={Brown},
           familyi={B\\bibinitperiod},
           given={John\\bibnamedelimb },
           giveni={J\\bibinitperiod}}}%
      }
      \name{translator}{1}{}{%
        {{hash=b44eba830fe9817fbe8e53c82f1cbe04}{%
           family={Smith},
           familyi={S\\bibinitperiod},
           given={Paul},
           giveni={P\\bibinitperiod}}}%
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
      \strng{namehash}{835d3352054f77020fc38705080e4596}
      \strng{fullhash}{835d3352054f77020fc38705080e4596}
      \strng{bibnamehash}{835d3352054f77020fc38705080e4596}
      \strng{authorbibnamehash}{835d3352054f77020fc38705080e4596}
      \strng{authornamehash}{835d3352054f77020fc38705080e4596}
      \strng{authorfullhash}{835d3352054f77020fc38705080e4596}
      \strng{forewordbibnamehash}{0ee59e598dae22fac8e6d9d2df7e79ec}
      \strng{forewordnamehash}{0ee59e598dae22fac8e6d9d2df7e79ec}
      \strng{forewordfullhash}{0ee59e598dae22fac8e6d9d2df7e79ec}
      \strng{translatorbibnamehash}{b44eba830fe9817fbe8e53c82f1cbe04}
      \strng{translatornamehash}{b44eba830fe9817fbe8e53c82f1cbe04}
      \strng{translatorfullhash}{b44eba830fe9817fbe8e53c82f1cbe04}
      \field{sortinit}{v}
      \field{sortinithash}{75dd7385c90b2252c3ae853a80ca853b}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{addendum}{userc}
      \field{eventday}{16}
      \field{eventendday}{17}
      \field{eventendmonth}{5}
      \field{eventendyear}{1990}
      \field{eventmonth}{5}
      \field{eventyear}{1990}
      \field{origyear}{356}
      \field{pagetotal}{240}
      \field{relatedstring}{Somestring}
      \field{relatedtype}{reprint}
      \field{series}{Научно-биографическая литература}
      \field{title}{Мухаммад ибн муса ал-Хорезми. Около 783 – около 850}
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
      \field{pages}{1\\bibrangedash 10\\bibrangessep 30\\bibrangedash 34}
      \range{pages}{15}
      \annotation{field}{author}{}{}{names-ann}
      \annotation{field}{language}{}{}{list-ann1}
      \annotation{field}{title}{}{}{field-ann1}
      \annotation{item}{author}{1}{}{name-ann1}
      \annotation{item}{author}{3}{}{name-ann2}
      \annotation{item}{language}{1}{}{item-ann1}
      \annotation{part}{author}{1}{given}{namepart-ann1}
      \annotation{part}{author}{2}{family}{namepart-ann2}
    \endentry
|;

my $l2 = q|    \entry{loopkey:a}{book}{}
      \field{sortinit}{0}
      \field{sortinithash}{168ad0c7c5ed09f1d28c6675717b5b03}
    \endentry
|;


my $bltx1 = 'mm,,,von!Булгаков!Павел Георгиевич#РРозенфельд!Борис-ZZ Aбрамович!von#Aхмедов!Ашраф Ахмедович#+,1980,0,Мухаммад ибн муса ал-Хорезми. Около 783 – около 850';

# Test::Differences doesn't like utf8 unless it's encoded here
eq_or_diff(encode_utf8($out->get_output_entry('bltx1', $main)), encode_utf8($l1), 'BibLaTeXML - 1');
eq_or_diff($section->get_citekey_alias('bltx1a1'), 'bltx1', 'Citekey aliases - 1');
eq_or_diff($section->get_citekey_alias('bltx1a2'), 'bltx1', 'Citekey aliases - 2');
eq_or_diff(encode_utf8($main->get_sortdata_for_key('bltx1')->[0]), encode_utf8($bltx1), 'useprefix at name list and name scope - 1' );
eq_or_diff(encode_utf8($out->get_output_entry('loopkey:a', $main)), encode_utf8($l2), 'BibLaTeXML automapcreate - 1');
