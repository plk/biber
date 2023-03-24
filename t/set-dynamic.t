# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 7;
use Test::Differences;
unified_diff;

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

$biber->parse_ctrlfile('set-dynamic.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');

# Now generate the information
$biber->prepare;
my $section0 = $biber->sections->get_section(0);
my $main0 = $biber->datalists->get_list('none/global//global/global/global');
my $sh0 = $biber->datalists->get_list('shorthand/global//global/global/global', 0, 'list');

my $section1 = $biber->sections->get_section(1);
my $main1 = $biber->datalists->get_list('none/global//global/global/global', 1);
my $sh1 = $biber->datalists->get_list('shorthand/global//global/global/global', 1, 'list');

my $out = $biber->get_output_obj;

my $string1 = q|    \entry{DynSet}{set}{}{}
      \set{Dynamic1,Dynamic2,Dynamic3}
      \field{sortinit}{1}
      \field{sortinithash}{4f6aaa89bab872aa0999fec09ff8e98a}
    \endentry
|;

my $string2 = q|    \entry{Dynamic1}{book}{skipbib=true,skipbiblist=true,skiplab=true,uniquelist=false,uniquename=false}{}
      \inset{DynSet}
      \name{author}{1}{}{%
        {{hash=252caa7921a061ca92087a1a52f15b78}{%
           family={Dynamism},
           familyi={D\bibinitperiod},
           given={Derek},
           giveni={D\bibinitperiod}}}%
      }
      \strng{namehash}{252caa7921a061ca92087a1a52f15b78}
      \strng{fullhash}{252caa7921a061ca92087a1a52f15b78}
      \strng{fullhashraw}{252caa7921a061ca92087a1a52f15b78}
      \strng{bibnamehash}{252caa7921a061ca92087a1a52f15b78}
      \strng{authorbibnamehash}{252caa7921a061ca92087a1a52f15b78}
      \strng{authornamehash}{252caa7921a061ca92087a1a52f15b78}
      \strng{authorfullhash}{252caa7921a061ca92087a1a52f15b78}
      \strng{authorfullhashraw}{252caa7921a061ca92087a1a52f15b78}
      \field{sortinit}{8}
      \field{sortinithash}{a231b008ebf0ecbe0b4d96dcc159445f}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{annotation}{Some Dynamic Note}
      \field{shorthand}{d1}
      \field{title}{Doing Daring Deeds}
      \field{year}{2002}
    \endentry
|;

my $string3 = q|    \entry{Dynamic2}{book}{skipbib=true,skipbiblist=true,skiplab=true,uniquelist=false,uniquename=false}{}
      \inset{DynSet}
      \name{author}{1}{}{%
        {{hash=894a5fe6de820f5dcce84a65581667f4}{%
           family={Bunting},
           familyi={B\bibinitperiod},
           given={Brian},
           giveni={B\bibinitperiod}}}%
      }
      \strng{namehash}{894a5fe6de820f5dcce84a65581667f4}
      \strng{fullhash}{894a5fe6de820f5dcce84a65581667f4}
      \strng{fullhashraw}{894a5fe6de820f5dcce84a65581667f4}
      \strng{bibnamehash}{894a5fe6de820f5dcce84a65581667f4}
      \strng{authorbibnamehash}{894a5fe6de820f5dcce84a65581667f4}
      \strng{authornamehash}{894a5fe6de820f5dcce84a65581667f4}
      \strng{authorfullhash}{894a5fe6de820f5dcce84a65581667f4}
      \strng{authorfullhashraw}{894a5fe6de820f5dcce84a65581667f4}
      \field{sortinit}{9}
      \field{sortinithash}{0a5ebc79d83c96b6579069544c73c7d4}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{shorthand}{d2}
      \field{title}{Beautiful Birthdays}
      \field{year}{2010}
    \endentry
|;

my $string4 = q|    \entry{Dynamic3}{book}{skipbib=true,skipbiblist=true,skiplab=true,uniquelist=false,uniquename=false}{}
      \inset{DynSet}
      \name{author}{1}{}{%
        {{hash=fc3cc97631ceaecdde2aee6cc60ab42b}{%
           family={Regardless},
           familyi={R\bibinitperiod},
           given={Roger},
           giveni={R\bibinitperiod}}}%
      }
      \strng{namehash}{fc3cc97631ceaecdde2aee6cc60ab42b}
      \strng{fullhash}{fc3cc97631ceaecdde2aee6cc60ab42b}
      \strng{fullhashraw}{fc3cc97631ceaecdde2aee6cc60ab42b}
      \strng{bibnamehash}{fc3cc97631ceaecdde2aee6cc60ab42b}
      \strng{authorbibnamehash}{fc3cc97631ceaecdde2aee6cc60ab42b}
      \strng{authornamehash}{fc3cc97631ceaecdde2aee6cc60ab42b}
      \strng{authorfullhash}{fc3cc97631ceaecdde2aee6cc60ab42b}
      \strng{authorfullhashraw}{fc3cc97631ceaecdde2aee6cc60ab42b}
      \field{sortinit}{1}
      \field{sortinithash}{4f6aaa89bab872aa0999fec09ff8e98a}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{shorthand}{d3}
      \field{title}{Reckless Ravishings}
      \field{year}{2000}
    \endentry
|;

# Labelyear is now here as skiplab is not set for this entry when cited in section
# without citation of a set it is a member of
my $string5 = q|    \entry{Dynamic3}{book}{}{}
      \name{author}{1}{}{%
        {{hash=fc3cc97631ceaecdde2aee6cc60ab42b}{%
           family={Regardless},
           familyi={R\bibinitperiod},
           given={Roger},
           giveni={R\bibinitperiod}}}%
      }
      \strng{namehash}{fc3cc97631ceaecdde2aee6cc60ab42b}
      \strng{fullhash}{fc3cc97631ceaecdde2aee6cc60ab42b}
      \strng{fullhashraw}{fc3cc97631ceaecdde2aee6cc60ab42b}
      \strng{bibnamehash}{fc3cc97631ceaecdde2aee6cc60ab42b}
      \strng{authorbibnamehash}{fc3cc97631ceaecdde2aee6cc60ab42b}
      \strng{authornamehash}{fc3cc97631ceaecdde2aee6cc60ab42b}
      \strng{authorfullhash}{fc3cc97631ceaecdde2aee6cc60ab42b}
      \strng{authorfullhashraw}{fc3cc97631ceaecdde2aee6cc60ab42b}
      \field{sortinit}{1}
      \field{sortinithash}{4f6aaa89bab872aa0999fec09ff8e98a}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{shorthand}{d3}
      \field{title}{Reckless Ravishings}
      \field{year}{2000}
    \endentry
|;


# Make sure allkeys works with dynamic sets
my @allkeys = qw(dynamic1 dynamic2 dynamic3 dynset elias1955 elias1955a elias1955b static1 static2 static3 static4);
my @keys = sort map {lc()} $section0->get_citekeys;
is_deeply( \@keys, \@allkeys, 'citekeys') ;

eq_or_diff($out->get_output_entry('DynSet', $main0), $string1, 'Dynamic set test 1');
eq_or_diff($out->get_output_entry('Dynamic1', $main0), $string2, 'Dynamic set test 2');
eq_or_diff($out->get_output_entry('Dynamic2', $main0), $string3, 'Dynamic set test 3');
eq_or_diff($out->get_output_entry('Dynamic3', $main0), $string4, 'Dynamic set test 4');
eq_or_diff($out->get_output_entry('Dynamic3', $main1, 1), $string5, 'Dynamic set test 5');

eq_or_diff($out->get_output_entry('Dynamic1', $sh0), $string2, 'Dynamic set skipbiblist 1');


