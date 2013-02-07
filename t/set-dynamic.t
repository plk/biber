# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 7;

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
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'C');

# Now generate the information
$biber->prepare;
my $section0 = $biber->sections->get_section(0);
my $main0 = $biber->sortlists->get_list(0, 'entry', 'nty');
my $sh0 = $biber->sortlists->get_list(0, 'shorthand', 'shorthand');
my $section1 = $biber->sections->get_section(1);
my $main1 = $biber->sortlists->get_list(1, 'entry', 'nty');
my $sh1 = $biber->sortlists->get_list(1, 'shorthand', 'shorthand');
my $out = $biber->get_output_obj;

my $string1 = q|    \entry{DynSet}{set}{}
      \set{Dynamic1,Dynamic2,Dynamic3}
      \name{form=original,lang=default}{labelname}{1}{}{%
        {{hash=252caa7921a061ca92087a1a52f15b78}{Dynamism}{D\bibinitperiod}{Derek}{D\bibinitperiod}{}{}{}{}}%
      }
      \name{form=original,lang=default}{author}{1}{}{%
        {{hash=252caa7921a061ca92087a1a52f15b78}{Dynamism}{D\bibinitperiod}{Derek}{D\bibinitperiod}{}{}{}{}}%
      }
      \strng{namehash}{252caa7921a061ca92087a1a52f15b78}
      \strng{fullhash}{252caa7921a061ca92087a1a52f15b78}
      \field{form=original,lang=default}{sortinit}{0}
      \field{form=original,lang=default}{labelyear}{2002}
      \field{form=original,lang=default}{labeltitle}{Doing Daring Deeds}
      \field{form=original,lang=default}{annotation}{Some Dynamic Note}
      \field{form=original,lang=default}{shorthand}{d1}
      \field{form=original,lang=default}{title}{Doing Daring Deeds}
      \field{form=original,lang=default}{year}{2002}
    \endentry
|;

my $string2 = q|    \entry{Dynamic1}{book}{}
      \inset{DynSet}
      \name{form=original,lang=default}{labelname}{1}{}{%
        {{hash=252caa7921a061ca92087a1a52f15b78}{Dynamism}{D\bibinitperiod}{Derek}{D\bibinitperiod}{}{}{}{}}%
      }
      \name{form=original,lang=default}{author}{1}{}{%
        {{hash=252caa7921a061ca92087a1a52f15b78}{Dynamism}{D\bibinitperiod}{Derek}{D\bibinitperiod}{}{}{}{}}%
      }
      \strng{namehash}{252caa7921a061ca92087a1a52f15b78}
      \strng{fullhash}{252caa7921a061ca92087a1a52f15b78}
      \field{form=original,lang=default}{sortinit}{0}
      \field{form=original,lang=default}{labeltitle}{Doing Daring Deeds}
      \field{form=original,lang=default}{annotation}{Some Dynamic Note}
      \field{form=original,lang=default}{shorthand}{d1}
      \field{form=original,lang=default}{title}{Doing Daring Deeds}
      \field{form=original,lang=default}{year}{2002}
    \endentry
|;

my $string3 = q|    \entry{Dynamic2}{book}{}
      \inset{DynSet}
      \name{form=original,lang=default}{labelname}{1}{}{%
        {{hash=894a5fe6de820f5dcce84a65581667f4}{Bunting}{B\bibinitperiod}{Brian}{B\bibinitperiod}{}{}{}{}}%
      }
      \name{form=original,lang=default}{author}{1}{}{%
        {{hash=894a5fe6de820f5dcce84a65581667f4}{Bunting}{B\bibinitperiod}{Brian}{B\bibinitperiod}{}{}{}{}}%
      }
      \strng{namehash}{894a5fe6de820f5dcce84a65581667f4}
      \strng{fullhash}{894a5fe6de820f5dcce84a65581667f4}
      \field{form=original,lang=default}{sortinit}{0}
      \field{form=original,lang=default}{labeltitle}{Beautiful Birthdays}
      \field{form=original,lang=default}{shorthand}{d2}
      \field{form=original,lang=default}{title}{Beautiful Birthdays}
      \field{form=original,lang=default}{year}{2010}
    \endentry
|;

my $string4 = q|    \entry{Dynamic3}{book}{}
      \inset{DynSet}
      \name{form=original,lang=default}{labelname}{1}{}{%
        {{hash=fc3cc97631ceaecdde2aee6cc60ab42b}{Regardless}{R\bibinitperiod}{Roger}{R\bibinitperiod}{}{}{}{}}%
      }
      \name{form=original,lang=default}{author}{1}{}{%
        {{hash=fc3cc97631ceaecdde2aee6cc60ab42b}{Regardless}{R\bibinitperiod}{Roger}{R\bibinitperiod}{}{}{}{}}%
      }
      \strng{namehash}{fc3cc97631ceaecdde2aee6cc60ab42b}
      \strng{fullhash}{fc3cc97631ceaecdde2aee6cc60ab42b}
      \field{form=original,lang=default}{sortinit}{0}
      \field{form=original,lang=default}{labeltitle}{Reckless Ravishings}
      \field{form=original,lang=default}{shorthand}{d3}
      \field{form=original,lang=default}{title}{Reckless Ravishings}
      \field{form=original,lang=default}{year}{2000}
    \endentry
|;

# Labelyear is now here as skiplab is not set for this entry when cited in section
# without citation of a set it is a member of
my $string5 = q|    \entry{Dynamic3}{book}{}
      \name{form=original,lang=default}{labelname}{1}{}{%
        {{hash=fc3cc97631ceaecdde2aee6cc60ab42b}{Regardless}{R\bibinitperiod}{Roger}{R\bibinitperiod}{}{}{}{}}%
      }
      \name{form=original,lang=default}{author}{1}{}{%
        {{hash=fc3cc97631ceaecdde2aee6cc60ab42b}{Regardless}{R\bibinitperiod}{Roger}{R\bibinitperiod}{}{}{}{}}%
      }
      \strng{namehash}{fc3cc97631ceaecdde2aee6cc60ab42b}
      \strng{fullhash}{fc3cc97631ceaecdde2aee6cc60ab42b}
      \field{form=original,lang=default}{sortinit}{0}
      \field{form=original,lang=default}{labelyear}{2000}
      \field{form=original,lang=default}{labeltitle}{Reckless Ravishings}
      \field{form=original,lang=default}{shorthand}{d3}
      \field{form=original,lang=default}{title}{Reckless Ravishings}
      \field{form=original,lang=default}{year}{2000}
    \endentry
|;

is($out->get_output_entry('DynSet', $main0), $string1, 'Dynamic set test 1');
is($out->get_output_entry('Dynamic1', $main0), $string2, 'Dynamic set test 2');
is($out->get_output_entry('Dynamic2', $main0), $string3, 'Dynamic set test 3');
is($out->get_output_entry('Dynamic3', $main0), $string4, 'Dynamic set test 4');
is($out->get_output_entry('Dynamic3', $main0, 1), $string5, 'Dynamic set test 5');
is_deeply([$sh0->get_keys], ['DynSet'], 'Dynamic set skiplos 1');
is_deeply([$sh1->get_keys], ['Dynamic3'], 'Dynamic set skiplos 2');

