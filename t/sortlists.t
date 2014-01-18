# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 8;

use Biber;
use Biber::Output::bbl;
use Log::Log4perl;
chdir("t/tdata");
my $S;

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

$biber->parse_ctrlfile('sortlists.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'C');

# (re)generate informtion based on option settings
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $out = $biber->get_output_obj;

is_deeply([$biber->sortlists->get_list(0, 'entry', 'lname', 'en_US')->get_keys], ['K1', 'K2', 'K4', 'K3'], 'List - name order');
is_deeply([$biber->sortlists->get_list(0, 'entry', 'lyear', 'en_US')->get_keys], ['K4', 'K1', 'K2', 'K3'], 'List - year order');
is_deeply([$biber->sortlists->get_list(0, 'entry', 'ltitle', 'en_US')->get_keys], ['K1', 'K4', 'K2', 'K3'], 'List - title order');
is_deeply([$biber->sortlists->get_list(0, 'entry', 'lnamef1', 'en_US')->get_keys], ['K2', 'K4'], 'List - name order (filtered) - 1');
is_deeply([$biber->sortlists->get_list(0, 'entry', 'lnamef2', 'en_US')->get_keys], ['K4'], 'List - name order (filtered) - 2');
is_deeply([$biber->sortlists->get_list(0, 'entry', 'lnamef3', 'en_US')->get_keys], ['K1', 'K2'], 'List - name order (filtered) - 3');
is_deeply([$biber->sortlists->get_list(0, 'entry', 'lnamef4', 'en_US')->get_keys], ['K3'], 'List - name order (filtered) - 4');
is_deeply([$biber->sortlists->get_list(0, 'entry', 'lnamef5', 'en_US')->get_keys], ['K1', 'K3'], 'List - name order (filtered) - 5');

