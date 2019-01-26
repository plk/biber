# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 6;
use Test::Differences;
unified_diff;

use Biber;
use Biber::Utils;
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

$biber->parse_ctrlfile('truncation.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');

# Now generate the information
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $main = $biber->datalists->get_list('nty/global//global/global');
my $out = $biber->get_output_obj;

my $us2s = q|    \entry{us2}{book}{}
      \true{moreauthor}
      \true{morelabelname}
      \name{author}{1}{}{%
        {{uniquename=0,uniquepart=base,hash=6a9b0705c275273262103333472cc656}{%
           family={Elk},
           familyi={E\bibinitperiod},
           given={Anne},
           giveni={A\bibinitperiod},
           givenun=0}}%
      }
      \strng{namehash}{40a337fc8d6319ae5a7b50f6324781ec}
      \strng{fullhash}{40a337fc8d6319ae5a7b50f6324781ec}
      \strng{bibnamehash}{40a337fc8d6319ae5a7b50f6324781ec}
      \strng{authorbibnamehash}{40a337fc8d6319ae5a7b50f6324781ec}
      \strng{authornamehash}{40a337fc8d6319ae5a7b50f6324781ec}
      \strng{authorfullhash}{40a337fc8d6319ae5a7b50f6324781ec}
      \field{labelalpha}{Elk\\textbf{+}72}
      \field{sortinit}{E}
      \field{sortinithash}{c554bd1a0b76ea92b9f105fe36d9c7b0}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{A Theory on Einiosauruses}
      \field{year}{1972}
      \field{dateera}{ce}
    \endentry
|;

my $us4s = q|    \entry{us4}{book}{}
      \name{author}{4}{uniquelist=2}{%
        {{uniquename=0,uniquepart=base,hash=e06f6e5a8c1d5204dea326aa5f4f8d17}{%
           family={Uthor},
           familyi={U\bibinitperiod},
           given={Anne},
           giveni={A\bibinitperiod},
           givenun=0}}%
        {{uniquename=0,uniquepart=base,hash=0868588743cd096fcda1144f2d3dd258}{%
           family={Ditor},
           familyi={D\bibinitperiod},
           given={Editha},
           giveni={E\bibinitperiod},
           givenun=0}}%
        {{uniquename=0,uniquepart=base,hash=7b10345a9314a9ba279e795d29f0a304}{%
           family={Writer},
           familyi={W\bibinitperiod},
           given={William},
           giveni={W\bibinitperiod},
           givenun=0}}%
        {{uniquename=0,uniquepart=base,hash=d6cfb2b8c4b3f9440ec4642438129367}{%
           family={Doe},
           familyi={D\bibinitperiod},
           given={Jane},
           giveni={J\bibinitperiod},
           givenun=0}}%
      }
      \strng{namehash}{b2de9f7c80527a94dd931e1ef2b25f80}
      \strng{fullhash}{fe131471bcc6dda25dc02e0dd6a7c488}
      \strng{bibnamehash}{b2de9f7c80527a94dd931e1ef2b25f80}
      \strng{authorbibnamehash}{b2de9f7c80527a94dd931e1ef2b25f80}
      \strng{authornamehash}{b2de9f7c80527a94dd931e1ef2b25f80}
      \strng{authorfullhash}{fe131471bcc6dda25dc02e0dd6a7c488}
      \field{extraname}{1}
      \field{labelalpha}{Uth\textbf{+}00}
      \field{sortinit}{U}
      \field{sortinithash}{77a6935510e008adcf5b555e7b4f0711}
      \field{extradate}{1}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \field{extraalpha}{1}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{Title A}
      \field{year}{2000}
      \field{dateera}{ce}
    \endentry
|;

my $us2w = q|    \entry{us2}{book}{}
      \true{moreauthor}
      \true{morelabelname}
      \name{author}{1}{}{%
        {{uniquename=0,uniquepart=base,hash=6a9b0705c275273262103333472cc656}{%
           family={Elk},
           familyi={E\bibinitperiod},
           given={Anne},
           giveni={A\bibinitperiod},
           givenun=0}}%
      }
      \strng{namehash}{6a9b0705c275273262103333472cc656}
      \strng{fullhash}{40a337fc8d6319ae5a7b50f6324781ec}
      \strng{bibnamehash}{6a9b0705c275273262103333472cc656}
      \strng{authorbibnamehash}{6a9b0705c275273262103333472cc656}
      \strng{authornamehash}{6a9b0705c275273262103333472cc656}
      \strng{authorfullhash}{40a337fc8d6319ae5a7b50f6324781ec}
      \field{extraname}{2}
      \field{labelalpha}{Elk\textbf{+}72}
      \field{sortinit}{E}
      \field{sortinithash}{c554bd1a0b76ea92b9f105fe36d9c7b0}
      \field{extradate}{2}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{A Theory on Einiosauruses}
      \field{year}{1972}
      \field{dateera}{ce}
    \endentry
|;

my $us4w = q|    \entry{us4}{book}{}
      \name{author}{4}{uniquelist=2}{%
        {{uniquename=0,uniquepart=base,hash=e06f6e5a8c1d5204dea326aa5f4f8d17}{%
           family={Uthor},
           familyi={U\bibinitperiod},
           given={Anne},
           giveni={A\bibinitperiod},
           givenun=0}}%
        {{uniquename=0,uniquepart=base,hash=0868588743cd096fcda1144f2d3dd258}{%
           family={Ditor},
           familyi={D\bibinitperiod},
           given={Editha},
           giveni={E\bibinitperiod},
           givenun=0}}%
        {{uniquename=0,uniquepart=base,hash=7b10345a9314a9ba279e795d29f0a304}{%
           family={Writer},
           familyi={W\bibinitperiod},
           given={William},
           giveni={W\bibinitperiod},
           givenun=0}}%
        {{uniquename=0,uniquepart=base,hash=d6cfb2b8c4b3f9440ec4642438129367}{%
           family={Doe},
           familyi={D\bibinitperiod},
           given={Jane},
           giveni={J\bibinitperiod},
           givenun=0}}%
      }
      \strng{namehash}{757e5c90bbe4adb86dc2cc78f96ef2fd}
      \strng{fullhash}{fe131471bcc6dda25dc02e0dd6a7c488}
      \strng{bibnamehash}{757e5c90bbe4adb86dc2cc78f96ef2fd}
      \strng{authorbibnamehash}{757e5c90bbe4adb86dc2cc78f96ef2fd}
      \strng{authornamehash}{757e5c90bbe4adb86dc2cc78f96ef2fd}
      \strng{authorfullhash}{fe131471bcc6dda25dc02e0dd6a7c488}
      \field{extraname}{1}
      \field{labelalpha}{Uth\textbf{+}00}
      \field{sortinit}{U}
      \field{sortinithash}{77a6935510e008adcf5b555e7b4f0711}
      \field{extradate}{1}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \field{extraalpha}{1}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{Title A}
      \field{year}{2000}
      \field{dateera}{ce}
    \endentry
|;


# Should be different to us1 and us3 respectively with default (uniqueliststrength=strong)
eq_or_diff( $out->get_output_entry('us2', $main), $us2s, 'Uniqueliststrength - 1') ;
eq_or_diff( $out->get_output_entry('us4', $main), $us4s, 'Uniqueliststrength - 2') ;

Biber::Config->setblxoption(undef,'uniqueliststrength', 1);
$biber->prepare;
$section = $biber->sections->get_section(0);
$main = $biber->datalists->get_list('nty/global//global/global');
$out = $biber->get_output_obj;

# namehash now the same as us1 and us3 respectively with (uniqueliststrength=weak)
eq_or_diff( $out->get_output_entry('us2', $main), $us2w, 'Uniqueliststrength - 3') ;
eq_or_diff( $out->get_output_entry('us4', $main), $us4w, 'Uniqueliststrength - 4') ;




# Testing minsortnamesstrict
Biber::Config->setblxoption(undef,'uniquelist', 0);
$biber->prepare;
$section = $biber->sections->get_section(0);
$main = $biber->datalists->get_list('nty/global//global/global');
$out = $biber->get_output_obj;

# Sorting with minsortnamesstrict=false
is_deeply($main->get_keys, ['us1', 'us2','us3', 'us4', 'us5'], 'Default minsortnamesstrict=false');

Biber::Config->setblxoption(undef,'minsortnamesstrict', 1);
$biber->prepare;
$section = $biber->sections->get_section(0);
$main = $biber->datalists->get_list('nty/global//global/global');
$out = $biber->get_output_obj;

# Sorting with minsortnamesstrict=true
is_deeply($main->get_keys, ['us1', 'us2','us4', 'us3', 'us5'], 'Default minsortnamesstrict=true');

