# -*- cperl -*-
use strict;
use warnings;
use Test::More tests => 5;
use Test::Differences;
unified_diff;

use Encode;
use Biber;
use Biber::Utils;
use Biber::Output::bibtex;
use Log::Log4perl;
use Unicode::Normalize;
chdir("t/tdata");
no warnings 'utf8';
use utf8;

# Set up Biber object
my $biber = Biber->new(configfile => 'tool-test.conf');
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

$biber->set_output_obj(Biber::Output::bibtex->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('tool', 1);
Biber::Config->setoption('output_resolve', 1);
Biber::Config->setoption('output_format', 'bibtex');
Biber::Config->setoption('sortlocale', 'C');

# THERE IS A CONFIG FILE BEING READ!

# Now generate the information
$ARGV[0] = 'tool.bib'; # fake this as we are not running through top-level biber program
$biber->tool_mode_setup;
$biber->prepare_tool;
my $main = $biber->sortlists->get_list(99999, Biber::Config->getblxoption('sortscheme'), 'entry', Biber::Config->getblxoption('sortscheme'));
my $out = $biber->get_output_obj;

my $t1 = q|@UNPUBLISHED{i3Š,
  ABSTRACT    = {Some abstract %50 of which is useless},
  AUTHOR      = {AAA and BBB and CCC and DDD and EEE},
  DATE        = {2003},
  INSTITUTION = {REPlaCEDte and early},
  KEYWORDS    = {keyword},
  LISTA       = {list test},
  LISTB       = {late and early},
  LOCATION    = {one and two},
  NOTE        = {i3Š},
  TITLE       = {Š title},
  USERB       = {test},
}

|;

my $t2 = q|@BOOK{xd1,
  AUTHOR    = {Edward Ellington},
  LOCATION  = {New York and London},
  NOTE      = {A Note},
  PUBLISHER = {Macmillan},
  YEAR      = {2001},
}

|;

my $t3 = q|@BOOK{b1,
  MAINSUBTITLE   = {Mainsubtitle},
  MAINTITLE      = {Maintitle},
  MAINTITLEADDON = {Maintitleaddon},
  TITLE          = {Booktitle},
  YEAR           = {1999},
}

|;

# NFD here because we are testing internals here and all internals expect NFD
eq_or_diff($out->get_output_entry(NFD('i3Š')), $t1, 'tool mode 1');
ok(is_undef($out->get_output_entry('loh')), 'tool mode 2');
eq_or_diff($out->get_output_entry('xd1',), $t2, 'tool mode 3');
eq_or_diff($out->get_output_entry('b1',), $t3, 'tool mode 4');
is_deeply([$main->get_keys], ['macmillan:pub', 'macmillan:loc', 'mv1', 'b1', 'xd1', 'macmillan', NFD('i3Š')], 'tool mode sorting');
