# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 11;

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

# (re)generate informtion based on option settings
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $out = $biber->get_output_obj;

is_deeply([$biber->sortlists->get_list(0, 'lname', 'entry', 'lname')->get_keys], ['K1', 'K2', 'K4', 'K3', 'K7', 'K8', 'K9', 'K10', 'K5', 'K6'], 'List - name order');
is_deeply([$biber->sortlists->get_list(0, 'lyear', 'entry', 'lyear')->get_keys], ['K4', 'K1', 'K2', 'K3', 'K6', 'K5', 'K7', 'K8', 'K9', 'K10'], 'List - year order');
is_deeply([$biber->sortlists->get_list(0, 'ltitle', 'entry', 'ltitle')->get_keys], ['K1', 'K7', 'K8', 'K9', 'K4', 'K10', 'K2', 'K6', 'K5', 'K3'], 'List - title order');
is_deeply([$biber->sortlists->get_list(0, 'lnamef1', 'entry', 'lnamef1')->get_keys], ['K2', 'K4', 'K5', 'K6'], 'List - name order (filtered) - 1');
is_deeply([$biber->sortlists->get_list(0, 'lnamef2', 'entry', 'lnamef2')->get_keys], ['K4'], 'List - name order (filtered) - 2');
is_deeply([$biber->sortlists->get_list(0, 'lnamef3', 'entry', 'lnamef3')->get_keys], ['K1', 'K2', 'K7', 'K5', 'K6'], 'List - name order (filtered) - 3');
is_deeply([$biber->sortlists->get_list(0, 'lnamef4', 'entry', 'lnamef4')->get_keys], ['K3'], 'List - name order (filtered) - 4');
is_deeply([$biber->sortlists->get_list(0, 'lnamef5', 'entry', 'lnamef5')->get_keys], ['K1', 'K3'], 'List - name order (filtered) - 5');
# Test list-local locale sorting
is_deeply([$biber->sortlists->get_list(0, 'lnameswe', 'entry', 'lnameswe')->get_keys], ['K1', 'K2', 'K4', 'K3', 'K7', 'K8', 'K9', 'K10', 'K6', 'K5'], 'List - name order (swedish)');
is_deeply([$biber->sortlists->get_list(0, 'ltitlespan', 'entry', 'ltitlespan')->get_keys], ['K1', 'K4', 'K10', 'K7', 'K8', 'K9', 'K2', 'K6', 'K5', 'K3'], 'List - title order (spanish)');
# Test sortset-local locale sorting
is_deeply([$biber->sortlists->get_list(0, 'ltitleset', 'entry', 'ltitleset')->get_keys], ['K1', 'K7', 'K9', 'K8', 'K4', 'K10', 'K2', 'K6', 'K5', 'K3'], 'List - granular locale (spanish)');

