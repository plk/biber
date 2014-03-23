# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 8;

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

$biber->parse_ctrlfile('extratitleyear.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'C');

# Now generate the information
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $main = $biber->sortlists->get_list(0, 'nty', 'entry', 'nty');
my $bibentries = $section->bibentries;

# Don't forget that the extratitleyear data is inserted after sorting
is($main->get_extratitleyeardata('L1'), '1', 'Same title, same year');
is($main->get_extratitleyeardata('L2'), '2', 'Same title, same year');
ok(is_undef($main->get_extratitledata('L3')), 'No title,  same year');
ok(is_undef($main->get_extratitleyeardata('L4')), 'Same title,  different year');
ok(is_undef($main->get_extratitleyeardata('L5')), 'Different labeltitle,  same year');
ok(is_undef($main->get_extratitleyeardata('LY1')), 'Different years due to range ends - 1');
ok(is_undef($main->get_extratitleyeardata('LY2')), 'Different years due to range ends - 1');
ok(is_undef($main->get_extratitleyeardata('LY3')), 'Different years due to range ends - 1');


