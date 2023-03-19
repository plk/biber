# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 2;

use Biber;
use Biber::Output::bbl;
use Log::Log4perl;
chdir("t/tdata") ;
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

$biber->parse_ctrlfile('sort-case.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests
Biber::Config->setoption('sortcase', 1);
Biber::Config->setoption('sortupper', 1);
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');

$S = { spec => [
                [
                 {},
                 {'author'     => {}},
                ],
               ]};

my $main = $biber->datalists->get_list('custom/global//global/global/global');
$main->set_sortingtemplate($S);

$biber->prepare;
is_deeply($main->get_keys, ['CS1','CS3','CS2'], 'U::C case - 1');

$biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('sort-case.bcf');

$biber->set_output_obj(Biber::Output::bbl->new());

# Global here is sortcase=0, sortupper=1
# title is sortcase=1, sortupper=0
# So, all names are the same and it depends on title
$biber->prepare;
$main = $biber->datalists->get_list('custom/global//global/global/global');
is_deeply($main->get_keys, ['CS3','CS2','CS1'], 'U::C case - 2');

