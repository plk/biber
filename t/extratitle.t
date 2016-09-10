# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 14;
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

$biber->parse_ctrlfile('extratitle.bcf');
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
my $main = $biber->sortlists->get_list(0, 'nty/global/', 'entry', 'nty', 'global', '');
my $bibentries = $section->bibentries;

# Don't forget that the extratitle data is inserted after sorting
eq_or_diff($main->get_extratitledata('L1'), '1', 'Same name, same title - 1');
eq_or_diff($main->get_extratitledata('L2'), '2', 'Same name, same title - 2');
eq_or_diff($main->get_extratitledata('L3'), '1', 'No name, same title - 1');
eq_or_diff($main->get_extratitledata('L4'), '2', 'No name, same title - 2');
ok(is_undef($main->get_extratitledata('L5')), 'No name, same title as with name - 1');
eq_or_diff($main->get_extratitledata('L6'), '1', 'No name, same shorttitle/title - 1');
eq_or_diff($main->get_extratitledata('L7'), '2', 'No name, same shorttitle/title - 2');
ok(is_undef($bibentries->entry('L8')->get_field('singletitle')), 'Singletitle test - 1');
ok(is_undef($bibentries->entry('L9')->get_field('singletitle')), 'Singletitle test - 2');
eq_or_diff($bibentries->entry('L10')->get_field('singletitle'), '1', 'Singletitle test - 3');
ok(is_undef($bibentries->entry('L11')->get_field('singletitle')), 'Singletitle test - 4');
ok(is_undef($bibentries->entry('L12')->get_field('singletitle')), 'Singletitle test - 5');
ok(is_undef($bibentries->entry('L1')->get_field('singletitle')), 'Singletitle test - 6');
ok(is_undef($bibentries->entry('L5')->get_field('singletitle')), 'Singletitle test - 7');
