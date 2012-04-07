# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 10;

use Biber;
use Biber::Utils;
use Biber::Output::test;
use Encode;
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

Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'C');

my $encode1 = q|    \entry{testŠ}{book}{}
      \name{labelname}{1}{}{%
        {{uniquename=0,hash=06a47edae2e847800cfd78323a0e6be8}{Encalcer}{E\bibinitperiod}{Edward}{E\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{uniquename=0,hash=06a47edae2e847800cfd78323a0e6be8}{Encalcer}{E\bibinitperiod}{Edward}{E\bibinitperiod}{}{}{}{}}%
      }
      \list{publisher}{1}{%
        {A press}%
      }
      \strng{namehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{fullhash}{06a47edae2e847800cfd78323a0e6be8}
      \field{labelalpha}{Enc99}
      \field{sortinit}{E}
      \field{labelyear}{1999}
      \true{singletitle}
      \field{title}{Šome title}
      \field{year}{1999}
    \endentry
|;

my $encode2 = q|    \entry{test1}{book}{}
      \name{labelname}{1}{}{%
        {{uniquename=0,hash=06a47edae2e847800cfd78323a0e6be8}{Encalcer}{E\bibinitperiod}{Edward}{E\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{uniquename=0,hash=06a47edae2e847800cfd78323a0e6be8}{Encalcer}{E\bibinitperiod}{Edward}{E\bibinitperiod}{}{}{}{}}%
      }
      \list{publisher}{1}{%
        {A press}%
      }
      \strng{namehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{fullhash}{06a47edae2e847800cfd78323a0e6be8}
      \field{labelalpha}{Enc99}
      \field{sortinit}{E}
      \field{labelyear}{1999}
      \true{singletitle}
      \field{title}{Söme title}
      \field{year}{1999}
    \endentry
|;

my $encode3 = q|    \entry{test1}{book}{}
      \name{labelname}{1}{}{%
        {{uniquename=0,hash=06a47edae2e847800cfd78323a0e6be8}{Encalcer}{E\bibinitperiod}{Edward}{E\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{uniquename=0,hash=06a47edae2e847800cfd78323a0e6be8}{Encalcer}{E\bibinitperiod}{Edward}{E\bibinitperiod}{}{}{}{}}%
      }
      \list{publisher}{1}{%
        {A press}%
      }
      \strng{namehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{fullhash}{06a47edae2e847800cfd78323a0e6be8}
      \field{labelalpha}{Enc99}
      \field{sortinit}{E}
      \field{labelyear}{1999}
      \true{singletitle}
      \field{title}{Żome title}
      \field{year}{1999}
    \endentry
|;

my $encode5 = q|    \entry{test}{book}{}
      \name{labelname}{1}{}{%
        {{uniquename=0,hash=06a47edae2e847800cfd78323a0e6be8}{Encalcer}{E\bibinitperiod}{Edward}{E\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{uniquename=0,hash=06a47edae2e847800cfd78323a0e6be8}{Encalcer}{E\bibinitperiod}{Edward}{E\bibinitperiod}{}{}{}{}}%
      }
      \list{publisher}{1}{%
        {A press}%
      }
      \strng{namehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{fullhash}{06a47edae2e847800cfd78323a0e6be8}
      \field{labelalpha}{Enc99}
      \field{sortinit}{E}
      \field{labelyear}{1999}
      \true{singletitle}
      \field{title}{à titlé}
      \field{year}{1999}
    \endentry
|;

my $encode6 = q|    \entry{test}{book}{}
      \name{labelname}{1}{}{%
        {{uniquename=0,hash=06a47edae2e847800cfd78323a0e6be8}{Encalcer}{E\bibinitperiod}{Edward}{E\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{uniquename=0,hash=06a47edae2e847800cfd78323a0e6be8}{Encalcer}{E\bibinitperiod}{Edward}{E\bibinitperiod}{}{}{}{}}%
      }
      \list{publisher}{1}{%
        {A press}%
      }
      \strng{namehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{fullhash}{06a47edae2e847800cfd78323a0e6be8}
      \field{labelalpha}{Enc99}
      \field{sortinit}{E}
      \field{labelyear}{1999}
      \true{singletitle}
      \field{title}{↑\`{a} titl\'{e}}
      \field{year}{1999}
    \endentry
|;

my $encode7 = q|    \entry{test}{book}{}
      \name{labelname}{1}{}{%
        {{uniquename=0,hash=06a47edae2e847800cfd78323a0e6be8}{Encalcer}{E\bibinitperiod}{Edward}{E\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{uniquename=0,hash=06a47edae2e847800cfd78323a0e6be8}{Encalcer}{E\bibinitperiod}{Edward}{E\bibinitperiod}{}{}{}{}}%
      }
      \list{publisher}{1}{%
        {A press}%
      }
      \strng{namehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{fullhash}{06a47edae2e847800cfd78323a0e6be8}
      \field{labelalpha}{Enc99}
      \field{sortinit}{E}
      \field{labelyear}{1999}
      \true{singletitle}
      \field{title}{{$\uparrow$}\`{a} titl\'{e}}
      \field{year}{1999}
    \endentry
|;


my $outvar;
my $output;

# Latin9 .bib -> UTF-8 .bbl
$biber->parse_ctrlfile('encoding1.bcf');
$biber->set_output_obj(Biber::Output::test->new());
# Biber options
Biber::Config->setoption('bibencoding', 'latin9');
Biber::Config->setoption('bblencoding', 'UTF-8');
# Now generate the information
$biber->prepare;
# Get reference to output object
$output = $biber->get_output_obj;
$output->set_output_target_file(\$outvar);
# Write the output to the target
$output->output;
is($outvar, encode(Biber::Config->getoption('bblencoding'), $encode1), 'latin9 .bib -> UTF-8 .bbl');

# UTF-8 .bib -> UTF-8 .bbl
$biber->parse_ctrlfile('encoding2.bcf');
$biber->set_output_obj(Biber::Output::test->new());
# Biber options
Biber::Config->setoption('bibencoding', 'UTF-8');
Biber::Config->setoption('bblencoding', 'UTF-8');
# Now generate the information
$biber->prepare;
# Get reference to output object
$output = $biber->get_output_obj;
$output->set_output_target_file(\$outvar);
# Write the output to the target
$output->output;
is($outvar, encode(Biber::Config->getoption('bblencoding'), $encode1), 'UTF-8 .bib -> UTF-8 .bbl');

# UTF-8 .bib -> latin1 .bbl
$biber->parse_ctrlfile('encoding5.bcf');
$biber->set_output_obj(Biber::Output::test->new());
# Biber options
Biber::Config->setoption('bibencoding', 'UTF-8');
Biber::Config->setoption('bblencoding', 'latin1');
# Now generate the information
$biber->prepare;
# Get reference to output object
$output = $biber->get_output_obj;
$output->set_output_target_file(\$outvar);
# Write the output to the target
$output->output;
is($outvar, encode(Biber::Config->getoption('bblencoding'), $encode5), 'UTF-8 .bib -> latin1 .bbl');

# UTF-8 .bib -> UTF-8 with --bblsafechars
$biber->parse_ctrlfile('encoding6.bcf');
$biber->set_output_obj(Biber::Output::test->new());
# Biber options
Biber::Config->setoption('bibencoding', 'UTF-8');
Biber::Config->setoption('bblencoding', 'UTF-8');
Biber::Config->setoption('bblsafechars', 1);
# Now generate the information
$biber->prepare;
# Get reference to output object
$output = $biber->get_output_obj;
$output->set_output_target_file(\$outvar);
# Write the output to the target
$output->output;
is($outvar, encode(Biber::Config->getoption('bblencoding'), $encode6), 'UTF-8 .bib -> UTF-8 .bbl, safechars');

# UTF-8 .bib -> UTF-8 with --bblsafechars and --bblcharsset=full
$biber->parse_ctrlfile('encoding6.bcf');
$biber->set_output_obj(Biber::Output::test->new());
# Biber options
Biber::Config->setoption('bibencoding', 'UTF-8');
Biber::Config->setoption('bblencoding', 'UTF-8');
Biber::Config->setoption('bblsafechars', 1);
Biber::LaTeX::Recode->init_schemes('full', 'full'); # Need to do this to reset
# Now generate the information
$biber->prepare;
# Get reference to output object
$output = $biber->get_output_obj;
$output->set_output_target_file(\$outvar);
# Write the output to the target
$output->output;
is($outvar, encode(Biber::Config->getoption('bblencoding'), $encode7), 'UTF-8 .bib -> UTF-8 .bbl, bblsafecharsset=full');

# UTF-8 .bib -> Latin9 .bbl
$biber->parse_ctrlfile('encoding2.bcf');
$biber->set_output_obj(Biber::Output::test->new());
# Biber options
Biber::Config->setoption('bblsafechars', 0);
Biber::Config->setoption('bibencoding', 'UTF-8');
Biber::Config->setoption('bblencoding', 'latin9');
# Now generate the information
$biber->prepare;
# Get reference to output object
$output = $biber->get_output_obj;
$output->set_output_target_file(\$outvar);
# Write the output to the target
$output->output;
is($outvar, encode(Biber::Config->getoption('bblencoding'), $encode1), 'UTF-8 .bib -> latin9 .bbl');

# latin1 .bib -> cp1252 .bbl
$biber->parse_ctrlfile('encoding3.bcf');
$biber->set_output_obj(Biber::Output::test->new());
# Biber options
Biber::Config->setoption('bibencoding', 'latin1');
Biber::Config->setoption('bblencoding', 'cp1252');
# Now generate the information
$biber->prepare;
# Get reference to output object
$output = $biber->get_output_obj;
$output->set_output_target_file(\$outvar);
# Write the output to the target
$output->output;
is($outvar, encode(Biber::Config->getoption('bblencoding'), $encode2), 'latin1 .bib -> CP1252 .bbl');

# latin2 .bib -> latin3 .bbl
$biber->parse_ctrlfile('encoding4.bcf');
$biber->set_output_obj(Biber::Output::test->new());
# Biber options
Biber::Config->setoption('bibencoding', 'latin2');
Biber::Config->setoption('bblencoding', 'latin3');
# Now generate the information
$biber->prepare;
# Get reference to output object
$output = $biber->get_output_obj;
$output->set_output_target_file(\$outvar);
# Write the output to the target
$output->output;
is($outvar, encode(Biber::Config->getoption('bblencoding'), $encode3), 'latin2 .bib -> latin3 .bbl');

# latin2 .bib -> latin1 .bbl - should fail
$biber->parse_ctrlfile('encoding4.bcf');
$biber->set_output_obj(Biber::Output::test->new());
# Biber options
Biber::Config->setoption('bibencoding', 'latin2');
Biber::Config->setoption('bblencoding', 'latin1');
# Now generate the information
$biber->prepare;
# Get reference to output object
$output = $biber->get_output_obj;
$output->set_output_target_file(\$outvar);
# Write the output to the target
# This test will generate encoding errors so redirect STDERR until it's done
open OLDERR, '>&', \*STDERR;
open STDERR, '>', '/dev/null';
$output->output;
open STDERR, '>&', \*OLDERR;
isnt($outvar, encode(Biber::Config->getoption('bblencoding'), $encode3), 'latin2 .bib -> latin1 .bbl failure');

# Custom encoding alias
# latin1 .bib -> applemacce (MacRoman) .bbl
$biber->parse_ctrlfile('encoding3.bcf');
$biber->set_output_obj(Biber::Output::test->new());
# Biber options
Biber::Config->setoption('bibencoding', 'latin1');
Biber::Config->setoption('bblencoding', 'applemacce');
# Now generate the information
$biber->prepare;
# Get reference to output object
$output = $biber->get_output_obj;
$output->set_output_target_file(\$outvar);
# Write the output to the target
$output->output;
is($outvar, encode(Biber::Config->getoption('bblencoding'), $encode2), 'latin1 .bib -> applemacce (custom alias) .bbl');

