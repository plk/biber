# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 5;
use Test::Differences;
unified_diff;

use Biber;
use Biber::Output::bbl;
use Log::Log4perl;
use Capture::Tiny qw(capture);
use Encode;

chdir("t/tdata") ;

# USING CAPTURE - DEBUGGING PRINTS, DUMPS WON'T BE VISIBLE UNLESS YOU PRINT $stderr
# AT THE END!

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

$biber->parse_ctrlfile('xdata.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');
Biber::Config->setoption('nodieonerror', 1); # because there is a cyclic xdata check

# Now generate the information
my ($stdout, $stderr) = capture { $biber->prepare };
my $section = $biber->sections->get_section(0);
my $main = $biber->datalists->get_list('nty/global//global/global');
my $out = $biber->get_output_obj;

my $xd1 = q|    \entry{xd1}{book}{}
      \name{author}{1}{}{%
        {{hash=51db4bfd331cba22959ce2d224c517cd}{%
           family={Ellington},
           familyi={E\bibinitperiod},
           given={Edward},
           giveni={E\bibinitperiod}}}%
      }
      \list{location}{2}{%
        {New York}%
        {London}%
      }
      \list{publisher}{1}{%
        {Macmillan}%
      }
      \strng{namehash}{51db4bfd331cba22959ce2d224c517cd}
      \strng{fullhash}{51db4bfd331cba22959ce2d224c517cd}
      \strng{bibnamehash}{51db4bfd331cba22959ce2d224c517cd}
      \strng{authorbibnamehash}{51db4bfd331cba22959ce2d224c517cd}
      \strng{authornamehash}{51db4bfd331cba22959ce2d224c517cd}
      \strng{authorfullhash}{51db4bfd331cba22959ce2d224c517cd}
      \field{extraname}{2}
      \field{sortinit}{E}
      \field{sortinithash}{f615fb9c6fba11c6f962fb3fd599810e}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{note}{A Note}
      \field{year}{2007}
      \field{dateera}{ce}
    \endentry
|;

my $xd2 = q|    \entry{xd2}{book}{}
      \name{author}{1}{}{%
        {{hash=68539e0ce4922cc4957c6cabf35e6fc8}{%
           family={Pillington},
           familyi={P\bibinitperiod},
           given={Peter},
           giveni={P\bibinitperiod}}}%
      }
      \list{location}{2}{%
        {New York}%
        {London}%
      }
      \list{publisher}{1}{%
        {Routledge}%
      }
      \strng{namehash}{68539e0ce4922cc4957c6cabf35e6fc8}
      \strng{fullhash}{68539e0ce4922cc4957c6cabf35e6fc8}
      \strng{bibnamehash}{68539e0ce4922cc4957c6cabf35e6fc8}
      \strng{authorbibnamehash}{68539e0ce4922cc4957c6cabf35e6fc8}
      \strng{authornamehash}{68539e0ce4922cc4957c6cabf35e6fc8}
      \strng{authorfullhash}{68539e0ce4922cc4957c6cabf35e6fc8}
      \field{sortinit}{P}
      \field{sortinithash}{8d51b3d5b78d75b54308d706b9bbe285}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{abstract}{An abstract}
      \field{addendum}{Москва}
      \field{note}{A Note}
      \field{venue}{venue}
      \field{year}{2003}
      \field{dateera}{ce}
    \endentry
|;

# Test::Differences doesn't like utf8 unless it's encoded here
eq_or_diff($out->get_output_entry('xd1', $main), $xd1, 'xdata test - 1');
eq_or_diff(encode_utf8($out->get_output_entry('xd2', $main)), encode_utf8($xd2), 'xdata test - 2');
# XDATA entries should not be output at all
eq_or_diff($out->get_output_entry('macmillan', $main), undef, 'xdata test - 3');
eq_or_diff($out->get_output_entry('macmillan:pub', $main), undef, 'xdata test - 4');
chomp $stderr;
eq_or_diff($stderr, "ERROR - Circular XDATA inheritance between 'loop'<->'loop:3'", 'Cyclic xdata error check');
#print $stdout;
#print $stderr;


