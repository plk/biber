# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 1;

use Biber;
use Biber::Output::bbl;
use Log::Log4perl;
use Capture::Tiny qw(capture);
use Biber::Utils;

chdir("t/tdata");

# Set up Biber object
my $biber = Biber->new(noconf => 1);

# Note stderr is output here so we can capture it and do a cyclic crossref test
my $LEVEL = 'ERROR';
my $l4pconf = qq|
    log4perl.category.main                             = $LEVEL, Screen
    log4perl.category.screen                           = $LEVEL, Screen
    log4perl.appender.Screen                           = Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.utf8                      = 1
    log4perl.appender.Screen.Threshold                 = $LEVEL
    log4perl.appender.Screen.stderr                    = 1
    log4perl.appender.Screen.layout                    = Log::Log4perl::Layout::SimpleLayout
|;

Log::Log4perl->init(\$l4pconf);

$biber->parse_ctrlfile('inheritance-variants.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'C');
Biber::Config->setoption('nodieonerror', 1); # because there is a failing cyclic crossref check

# Now generate the information
my (undef, $stderr) = capture { $biber->prepare };
my $section = $biber->sections->get_section(0);
my $main = $biber->sortlists->get_list(0, 'entry', 'nty');
my $out = $biber->get_output_obj;


my $ms1 = q|    \entry{ms1}{inbook}{vlang=english}
      \name{labelname}{1}{}{%
        {{hash=ab072d2d4322ee1d27823c8adefeca0a}{Multiscript}{M\bibinitperiod}{Miranda}{M\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{hash=ab072d2d4322ee1d27823c8adefeca0a}{Multiscript}{M\bibinitperiod}{Miranda}{M\bibinitperiod}{}{}{}{}}%
      }
      \name{editor}{1}{}{%
        {{hash=e9e9cd902ec07bab151d805c0716e7b0}{Ink}{I\bibinitperiod}{Ian}{I\bibinitperiod}{}{}{}{}}%
      }
      \name[form=translated,lang=german]{editor}{1}{}{%
        {{hash=972f0ee3a5f949259f3b471a2a314e54}{Tinte}{T\bibinitperiod}{Jan}{J\bibinitperiod}{}{}{}{}}%
      }
      \list{publisher}{2}{%
        {Rumble}%
        {Slush}%
      }
      \strng{namehash}{ab072d2d4322ee1d27823c8adefeca0a}
      \strng{fullhash}{ab072d2d4322ee1d27823c8adefeca0a}
      \field{sortinit}{M}
      \field{sortinithash}{4203d16473bc940d4ac780773cb7c5dd}
      \field{labeltitle}{Miraculous, Meticulous, Moody}
      \field{booktitle}{Indelible, unglückliche Eigenheiten}
      \field[form=translated]{booktitle}{Indextitle}
      \strng{crossref}{ms2}
      \field{langid}{english}
      \field{number}{Erste}
      \field{title}{Miraculous, Meticulous, Moody}
      \field{userb}{nonms to nonms}
      \field{year}{1955}
    \endentry
|;

# See the absurd inheritance setup in the .bcf
is($out->get_output_entry('ms1', $main), $ms1, 'Basic test - 1');

