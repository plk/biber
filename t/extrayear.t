# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 22;
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

$biber->parse_ctrlfile('extrayear.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');

# Biblatex options
Biber::Config->setblxoption('maxcitenames', 1);
Biber::Config->setblxoption('maxbibnames', 1);

# Now generate the information
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $main = $biber->datalists->get_list('nty/global//global/global');
my $bibentries = $section->bibentries;

eq_or_diff($main->get_extrayeardata_for_key('L1'), '1', 'Entry L1 - one name, first in 1995');
eq_or_diff($main->get_extrayeardata_for_key('L2'), '2', 'Entry L2 - one name, second in 1995');
eq_or_diff($main->get_extrayeardata_for_key('L3'), '3', 'Entry L3 - one name, third in 1995');
eq_or_diff($main->get_extrayeardata_for_key('L4'), '1', 'Entry L4 - two names, first in 1995');
eq_or_diff($main->get_extrayeardata_for_key('L5'), '2', 'Entry L5 - two names, second in 1995');
eq_or_diff($main->get_extrayeardata_for_key('L6'), '1', 'Entry L6 - two names, first in 1996');
eq_or_diff($main->get_extrayeardata_for_key('L7'), '2', 'Entry L7 - two names, second in 1996');
eq_or_diff($main->get_extrayeardata_for_key('nodate1'), '1', 'Same name, no year 1');
eq_or_diff($main->get_extrayeardata_for_key('nodate2'), '2', 'Same name, no year 2');
ok(is_undef($main->get_extrayeardata_for_key('L8')), 'Entry L8 - one name, only in year');
ok(is_undef($main->get_extrayeardata_for_key('L9')), 'Entry L9 - No name, same year as another with no name');
ok(is_undef($main->get_extrayeardata_for_key('L10')), 'Entry L10 - No name, same year as another with no name');
eq_or_diff($main->get_extrayeardata_for_key('companion1'), '1', 'Entry companion1 - names truncated to same as another entry in same year');
eq_or_diff($main->get_extrayeardata_for_key('companion2'), '2', 'Entry companion2 - names truncated to same as another entry in same year');
ok(is_undef($main->get_extrayeardata_for_key('companion3')), 'Entry companion3 - one name, same year as truncated names');
eq_or_diff($main->get_extrayeardata_for_key('vangennep'), '2', 'Entry vangennep - useprefix does makes it different');
eq_or_diff($main->get_extrayeardata_for_key('gennep'), '1', 'Entry gennep - different from prefix name');
ok(is_undef($main->get_extrayeardata_for_key('LY1')), 'Date range means no extrayear - 1');
ok(is_undef($main->get_extrayeardata_for_key('LY2')), 'Date range means no extrayear - 2');
ok(is_undef($main->get_extrayeardata_for_key('LY3')), 'Date range means no extrayear - 3');

# Test for labeldatesource literal string
eq_or_diff($bibentries->entry('nodate1')->get_field('labeldatesource'), 'nodate', 'Labeldatesource string - 1');
eq_or_diff($bibentries->entry('nodate2')->get_field('labeldatesource'), 'nodate', 'Labeldatesource string - 2');

