# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 7;
use Test::Differences;
unified_diff;

use Biber;
use Biber::Utils;
use Biber::Output::bbl;
use Log::Log4perl;
use Unicode::Normalize;
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

$biber->parse_ctrlfile('labelalphaname.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Biber options
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');

# Biblatex options

# Now generate the information, saving per-entry options or they are deleted
$biber->prepare;

my $main = $biber->datalists->get_list('custom/global//global/global/global');
my $main1 = $biber->datalists->get_list('custom/global//global/test1/global');
my $main2 = $biber->datalists->get_list('custom/global//global/test5/global');

eq_or_diff($main->get_labelalphadata_for_key('lant1'), 'Smi', 'labelalphaname global template');
eq_or_diff($main1->get_labelalphadata_for_key('lant1'), 'AS', 'labelalphaname dlist template');
eq_or_diff($main->get_labelalphadata_for_key('lant2'), 'ArSm', 'labelalphaname entry template');
eq_or_diff($main->get_labelalphadata_for_key('lant3'), 'ArtSmi', 'labelalphaname namelist template');
eq_or_diff($main->get_labelalphadata_for_key('lant4'), 'ArthSmit', 'labelalphaname name template');
eq_or_diff($main2->get_labelalphadata_for_key('lant5'), 'GRW', 'labelalphaname name template compound');
eq_or_diff($main2->get_labelalphadata_for_key('lant6'), 'GRW', 'labelalphaname name template hyphen');
