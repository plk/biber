# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 10;
use Test::Differences;
unified_diff;

use Biber;
use Biber::Utils;
use Biber::Output::bbl;
use Encode;
use Log::Log4perl;
use Unicode::Normalize;
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

Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');

my $encode1 = q|% $ biblatex auxiliary file $
% $ biblatex bbl format version 3.3 $
% Do not modify the above lines!
%
% This is an auxiliary file used by the 'biblatex' package.
% This file may safely be deleted. It will be recreated by
% biber as required.
%
\begingroup
\makeatletter
\@ifundefined{ver@biblatex.sty}
  {\@latex@error
     {Missing 'biblatex' package}
     {The bibliography requires the 'biblatex' package.}
      \aftergroup\endinput}
  {}
\endgroup


\refsection{0}
  \datalist[entry]{nty/global//global/global/global}
    \entry{testŠ}{book}{}{}
      \name{author}{1}{}{%
        {{un=0,uniquepart=base,hash=06a47edae2e847800cfd78323a0e6be8}{%
           family={Encalcer},
           familyi={E\bibinitperiod},
           given={Edward},
           giveni={E\bibinitperiod},
           givenun=0}}%
      }
      \list{publisher}{1}{%
        {A press}%
      }
      \strng{namehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{fullhash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{fullhashraw}{06a47edae2e847800cfd78323a0e6be8}
      \strng{bibnamehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{authorbibnamehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{authornamehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{authorfullhash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{authorfullhashraw}{06a47edae2e847800cfd78323a0e6be8}
      \field{labelalpha}{Enc99}
      \field{sortinit}{E}
      \field{sortinithash}{8da8a182d344d5b9047633dfc0cc9131}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \true{singletitle}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{Šome title}
      \field{year}{1999}
    \endentry
  \enddatalist
\endrefsection
\endinput

|;

my $encode2 = q|% $ biblatex auxiliary file $
% $ biblatex bbl format version 3.3 $
% Do not modify the above lines!
%
% This is an auxiliary file used by the 'biblatex' package.
% This file may safely be deleted. It will be recreated by
% biber as required.
%
\begingroup
\makeatletter
\@ifundefined{ver@biblatex.sty}
  {\@latex@error
     {Missing 'biblatex' package}
     {The bibliography requires the 'biblatex' package.}
      \aftergroup\endinput}
  {}
\endgroup


\refsection{0}
  \datalist[entry]{nty/global//global/global/global}
    \entry{test1}{book}{}{}
      \name{author}{1}{}{%
        {{un=0,uniquepart=base,hash=06a47edae2e847800cfd78323a0e6be8}{%
           family={Encalcer},
           familyi={E\bibinitperiod},
           given={Edward},
           giveni={E\bibinitperiod},
           givenun=0}}%
      }
      \list{publisher}{1}{%
        {A press}%
      }
      \strng{namehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{fullhash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{fullhashraw}{06a47edae2e847800cfd78323a0e6be8}
      \strng{bibnamehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{authorbibnamehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{authornamehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{authorfullhash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{authorfullhashraw}{06a47edae2e847800cfd78323a0e6be8}
      \field{labelalpha}{Enc99}
      \field{sortinit}{E}
      \field{sortinithash}{8da8a182d344d5b9047633dfc0cc9131}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \true{singletitle}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{Söme title}
      \field{year}{1999}
    \endentry
  \enddatalist
\endrefsection
\endinput

|;

my $encode3 = q|% $ biblatex auxiliary file $
% $ biblatex bbl format version 3.3 $
% Do not modify the above lines!
%
% This is an auxiliary file used by the 'biblatex' package.
% This file may safely be deleted. It will be recreated by
% biber as required.
%
\begingroup
\makeatletter
\@ifundefined{ver@biblatex.sty}
  {\@latex@error
     {Missing 'biblatex' package}
     {The bibliography requires the 'biblatex' package.}
      \aftergroup\endinput}
  {}
\endgroup


\refsection{0}
  \datalist[entry]{nty/global//global/global/global}
    \entry{test1}{book}{}{}
      \name{author}{1}{}{%
        {{un=0,uniquepart=base,hash=06a47edae2e847800cfd78323a0e6be8}{%
           family={Encalcer},
           familyi={E\bibinitperiod},
           given={Edward},
           giveni={E\bibinitperiod},
           givenun=0}}%
      }
      \list{publisher}{1}{%
        {A press}%
      }
      \strng{namehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{fullhash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{fullhashraw}{06a47edae2e847800cfd78323a0e6be8}
      \strng{bibnamehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{authorbibnamehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{authornamehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{authorfullhash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{authorfullhashraw}{06a47edae2e847800cfd78323a0e6be8}
      \field{labelalpha}{Enc99}
      \field{sortinit}{E}
      \field{sortinithash}{8da8a182d344d5b9047633dfc0cc9131}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \true{singletitle}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{Żome title}
      \field{year}{1999}
    \endentry
  \enddatalist
\endrefsection
\endinput

|;

my $encode5 = q|% $ biblatex auxiliary file $
% $ biblatex bbl format version 3.3 $
% Do not modify the above lines!
%
% This is an auxiliary file used by the 'biblatex' package.
% This file may safely be deleted. It will be recreated by
% biber as required.
%
\begingroup
\makeatletter
\@ifundefined{ver@biblatex.sty}
  {\@latex@error
     {Missing 'biblatex' package}
     {The bibliography requires the 'biblatex' package.}
      \aftergroup\endinput}
  {}
\endgroup


\refsection{0}
  \datalist[entry]{nty/global//global/global/global}
    \entry{test}{book}{}{}
      \name{author}{1}{}{%
        {{un=0,uniquepart=base,hash=06a47edae2e847800cfd78323a0e6be8}{%
           family={Encalcer},
           familyi={E\bibinitperiod},
           given={Edward},
           giveni={E\bibinitperiod},
           givenun=0}}%
      }
      \list{publisher}{1}{%
        {A press}%
      }
      \strng{namehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{fullhash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{fullhashraw}{06a47edae2e847800cfd78323a0e6be8}
      \strng{bibnamehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{authorbibnamehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{authornamehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{authorfullhash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{authorfullhashraw}{06a47edae2e847800cfd78323a0e6be8}
      \field{labelalpha}{Enc99}
      \field{sortinit}{E}
      \field{sortinithash}{8da8a182d344d5b9047633dfc0cc9131}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \true{singletitle}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{à titlé}
      \field{year}{1999}
    \endentry
  \enddatalist
\endrefsection
\endinput

|;

my $encode6 = q|% $ biblatex auxiliary file $
% $ biblatex bbl format version 3.3 $
% Do not modify the above lines!
%
% This is an auxiliary file used by the 'biblatex' package.
% This file may safely be deleted. It will be recreated by
% biber as required.
%
\begingroup
\makeatletter
\@ifundefined{ver@biblatex.sty}
  {\@latex@error
     {Missing 'biblatex' package}
     {The bibliography requires the 'biblatex' package.}
      \aftergroup\endinput}
  {}
\endgroup


\refsection{0}
  \datalist[entry]{nty/global//global/global/global}
    \entry{test}{book}{}{}
      \name{author}{1}{}{%
        {{un=0,uniquepart=base,hash=06a47edae2e847800cfd78323a0e6be8}{%
           family={Encalcer},
           familyi={E\bibinitperiod},
           given={Edward},
           giveni={E\bibinitperiod},
           givenun=0}}%
      }
      \list{publisher}{1}{%
        {A press}%
      }
      \strng{namehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{fullhash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{fullhashraw}{06a47edae2e847800cfd78323a0e6be8}
      \strng{bibnamehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{authorbibnamehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{authornamehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{authorfullhash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{authorfullhashraw}{06a47edae2e847800cfd78323a0e6be8}
      \field{labelalpha}{Enc99}
      \field{sortinit}{E}
      \field{sortinithash}{8da8a182d344d5b9047633dfc0cc9131}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \true{singletitle}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{↑\`{a} titl\'{e}}
      \field{year}{1999}
    \endentry
  \enddatalist
\endrefsection
\endinput

|;

my $encode7 = q|% $ biblatex auxiliary file $
% $ biblatex bbl format version 3.3 $
% Do not modify the above lines!
%
% This is an auxiliary file used by the 'biblatex' package.
% This file may safely be deleted. It will be recreated by
% biber as required.
%
\begingroup
\makeatletter
\@ifundefined{ver@biblatex.sty}
  {\@latex@error
     {Missing 'biblatex' package}
     {The bibliography requires the 'biblatex' package.}
      \aftergroup\endinput}
  {}
\endgroup


\refsection{0}
  \datalist[entry]{nty/global//global/global/global}
    \entry{test}{book}{}{}
      \name{author}{1}{}{%
        {{un=0,uniquepart=base,hash=06a47edae2e847800cfd78323a0e6be8}{%
           family={Encalcer},
           familyi={E\bibinitperiod},
           given={Edward},
           giveni={E\bibinitperiod},
           givenun=0}}%
      }
      \list{publisher}{1}{%
        {A press}%
      }
      \strng{namehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{fullhash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{fullhashraw}{06a47edae2e847800cfd78323a0e6be8}
      \strng{bibnamehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{authorbibnamehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{authornamehash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{authorfullhash}{06a47edae2e847800cfd78323a0e6be8}
      \strng{authorfullhashraw}{06a47edae2e847800cfd78323a0e6be8}
      \field{labelalpha}{Enc99}
      \field{sortinit}{E}
      \field{sortinithash}{8da8a182d344d5b9047633dfc0cc9131}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \true{singletitle}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{{$\uparrow$}\`{a} titl\'{e}}
      \field{year}{1999}
    \endentry
  \enddatalist
\endrefsection
\endinput

|;


my $outvar;
my $output;

sub change_ds_encoding {
  my ($name, $encoding) = @_;
  my $section = $biber->sections->get_section(0);
  my $dss = $section->get_datasources;
  foreach my $ds ($section->get_datasources->@*) {
    if ($ds->{name} eq $name) {
      $ds->{encoding} = $encoding;
    }
  }
}


# Latin9 .bib -> UTF-8 .bbl
$biber->parse_ctrlfile('encoding1.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Biber options
change_ds_encoding('encoding1.bib', 'latin9');
Biber::Config->setoption('output_encoding', 'UTF-8');

# Now generate the information
$biber->prepare;
# Get reference to output object
$output = $biber->get_output_obj;
$output->set_output_target($output->set_output_target_file(\$outvar));
# Write the output to the target
$output->output;
eq_or_diff($outvar, encode(Biber::Config->getoption('output_encoding'), $encode1), 'latin9 .bib -> UTF-8 .bbl');

# UTF-8 .bib -> UTF-8 .bbl
$biber->parse_ctrlfile('encoding2.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());
# Biber options
change_ds_encoding('encoding2.bib', 'UTF-8');
Biber::Config->setoption('output_encoding', 'UTF-8');
# Now generate the information
$biber->prepare;
# Get reference to output object
$output = $biber->get_output_obj;
$output->set_output_target($output->set_output_target_file(\$outvar));
# Write the output to the target
$output->output;
eq_or_diff($outvar, encode(Biber::Config->getoption('output_encoding'), $encode1), 'UTF-8 .bib -> UTF-8 .bbl');

# UTF-8 .bib -> latin1 .bbl
$biber->parse_ctrlfile('encoding5.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());
# Biber options
change_ds_encoding('encoding2.bib', 'UTF-8');
Biber::Config->setoption('output_encoding', 'latin1');
# Now generate the information
$biber->prepare;
# Get reference to output object
$output = $biber->get_output_obj;
$output->set_output_target($output->set_output_target_file(\$outvar));
# Write the output to the target
$output->output;
eq_or_diff($outvar, encode(Biber::Config->getoption('output_encoding'), $encode5), 'UTF-8 .bib -> latin1 .bbl');

# UTF-8 .bib -> UTF-8 with --output_safechars
$biber->parse_ctrlfile('encoding6.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());
# Biber options
change_ds_encoding('encoding6.bib', 'UTF-8');
Biber::Config->setoption('output_encoding', 'UTF-8');
Biber::Config->setoption('output_safechars', 1);
# Now generate the information
$biber->prepare;
# Get reference to output object
$output = $biber->get_output_obj;
$output->set_output_target($output->set_output_target_file(\$outvar));
# Write the output to the target
$output->output;
eq_or_diff($outvar, encode(Biber::Config->getoption('output_encoding'), $encode6), 'UTF-8 .bib -> UTF-8 .bbl, safechars');

# UTF-8 .bib -> UTF-8 with --output_safechars and --bblcharsset=full
$biber->parse_ctrlfile('encoding6.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());
# Biber options
change_ds_encoding('encoding6.bib', 'UTF-8');
Biber::Config->setoption('output_encoding', 'UTF-8');
Biber::Config->setoption('output_safechars', 1);
Biber::LaTeX::Recode->init_sets('full', 'full'); # Need to do this to reset
# Now generate the information
$biber->prepare;
# Get reference to output object
$output = $biber->get_output_obj;
$output->set_output_target($output->set_output_target_file(\$outvar));
# Write the output to the target
$output->output;
eq_or_diff($outvar, encode(Biber::Config->getoption('output_encoding'), $encode7), 'UTF-8 .bib -> UTF-8 .bbl, output_safecharsset=full');

# UTF-8 .bib -> Latin9 .bbl
$biber->parse_ctrlfile('encoding2.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());
# Biber options
Biber::Config->setoption('output_safechars', 0);
change_ds_encoding('encoding2.bib', 'UTF-8');
Biber::Config->setoption('output_encoding', 'latin9');
# Now generate the information
$biber->prepare;
# Get reference to output object
$output = $biber->get_output_obj;
$output->set_output_target($output->set_output_target_file(\$outvar));
# Write the output to the target
$output->output;
eq_or_diff($outvar, encode(Biber::Config->getoption('output_encoding'), $encode1), 'UTF-8 .bib -> latin9 .bbl');

# latin1 .bib -> cp1252 .bbl
$biber->parse_ctrlfile('encoding3.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());
# Biber options
change_ds_encoding('encoding3.bib', 'latin1');
Biber::Config->setoption('output_encoding', 'cp1252');
# Now generate the information
$biber->prepare;
# Get reference to output object
$output = $biber->get_output_obj;
$output->set_output_target($output->set_output_target_file(\$outvar));
# Write the output to the target
$output->output;
eq_or_diff($outvar, encode(Biber::Config->getoption('output_encoding'), $encode2), 'latin1 .bib -> CP1252 .bbl');

# latin2 .bib -> latin3 .bbl
$biber->parse_ctrlfile('encoding4.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());
# Biber options
change_ds_encoding('encoding4.bib', 'latin2');
Biber::Config->setoption('output_encoding', 'latin3');
# Now generate the information
$biber->prepare;
# Get reference to output object
$output = $biber->get_output_obj;
$output->set_output_target($output->set_output_target_file(\$outvar));
# Write the output to the target
$output->output;
eq_or_diff($outvar, encode(Biber::Config->getoption('output_encoding'), $encode3), 'latin2 .bib -> latin3 .bbl');

# latin2 .bib -> latin1 .bbl - should fail
$biber->parse_ctrlfile('encoding4.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());
# Biber options
change_ds_encoding('encoding4.bib', 'latin2');
Biber::Config->setoption('output_encoding', 'latin1');
# Now generate the information
$biber->prepare;
# Get reference to output object
$output = $biber->get_output_obj;
$output->set_output_target($output->set_output_target_file(\$outvar));
# Write the output to the target
# This test will generate encoding errors so redirect STDERR until it's done
open OLDERR, '>&', \*STDERR;
open STDERR, '>', '/dev/null';
$output->output;
open STDERR, '>&', \*OLDERR;
isnt($outvar, encode(Biber::Config->getoption('output_encoding'), $encode3), 'latin2 .bib -> latin1 .bbl failure');

# Custom encoding alias
# latin1 .bib -> applemacce (MacRoman) .bbl
$biber->parse_ctrlfile('encoding3.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());
# Biber options
change_ds_encoding('encoding3.bib', 'latin1');
Biber::Config->setoption('output_encoding', 'applemacce');
# Now generate the information
$biber->prepare;
# Get reference to output object
$output = $biber->get_output_obj;
$output->set_output_target($output->set_output_target_file(\$outvar));
# Write the output to the target
$output->output;
eq_or_diff($outvar, encode(Biber::Config->getoption('output_encoding'), $encode2), 'latin1 .bib -> applemacce (custom alias) .bbl');

