# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 2;

use Biber;
use Biber::Utils;
use Biber::Output::tool;
use Log::Log4perl;
chdir("t/tdata");

# Set up Biber object
my $biber = Biber->new( configfile => 'biber-test.conf');
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

$biber->set_output_obj(Biber::Output::tool->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('tool', 1);
Biber::Config->setoption('sortlocale', 'C');
Biber::Config->setoption('fastsort', 1);

# THERE IS A CONFIG FILE BEING READ TO TEST USER MAPS TOO!

# Now generate the information
$ARGV[0] = 'examples.bib'; # fake this as we are not runing through top-level biber program
$biber->tool_mode_setup;
$biber->prepare;
my $out = $biber->get_output_obj;

my $t1 = q|@unpublished{i1,
  author = {AAA and BBB and CCC and DDD and EEE},
  title = {A title},
  date = {2003},
  lista = {list test},
  listb = {REPlacedte and early},
  keywords = {keyw1, keyw2},
  userd = {test},
  institution = {REPlaCEDte and early},
  note = {i1},
}

|;

is( $out->get_output_entry('i1'), $t1, 'tool mode 1' ) ;
ok(is_undef($out->get_output_entry('loh')), 'tool mode 2' );

