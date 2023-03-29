# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 6;

use Biber;
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

$biber->parse_ctrlfile('sort-uc.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests
Biber::Config->setoption('sortlocale', 'sv_SE.UTF-8');

# U::C Swedish tailoring
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $main = $biber->datalists->get_list('nty/global//global/global/global');
my $shs = $biber->datalists->get_list('shorthand/global//global/global/global', 0, 'list');

# Shorthands are sorted by shorthand (as per bcf)
is_deeply($main->get_keys, ['LS6','LS5','LS2','LS1','LS3','LS4'], 'U::C tailoring - 1');
is_deeply($shs->get_keys, ['LS3', 'LS4','LS2','LS1'], 'U::C tailoring - 2');

# Set sorting of shorthands to global sorting default
$shs->set_sortingtemplate(Biber::Config->getblxoption(undef,'sortingtemplate'));
$shs->set_sortingtemplatename('global');

$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply($shs->get_keys, ['LS2', 'LS1','LS3','LS4'], 'U::C tailoring - 3');


# Descending name in Swedish collation
$main->set_sortingtemplatename('dswe');

$biber->prepare;
$section = $biber->sections->get_section(0);

is_deeply($main->get_keys, ['LS3','LS4','LS1','LS2','LS5','LS6'], 'U::C tailoring descending - 1');

# Local lower before upper setting
$main->set_sortingtemplatename('ll');

$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply($main->get_keys, ['LS5', 'LS6', 'LS4', 'LS3','LS2','LS1'], 'upper_before_lower locally false');

# Local case insensitive negates the sortupper being false as this no longer
# means anything so it reverts to bib order for LS3 and LS4
# For this, have to reparse the .bcf otherwise the citekey order from previous
# test is kept for things that are not sort distinguishable
$biber->parse_ctrlfile('sort-uc.bcf');
$section = $biber->sections->get_section(0);
$main = $biber->datalists->get_list('nty/global//global/global/global');
$biber->set_output_obj(Biber::Output::bbl->new());

$main->set_sortingtemplatename('ci');
$biber->prepare;
is_deeply($main->get_keys, ['LS5', 'LS6','LS3', 'LS4','LS2','LS1'], 'sortcase locally false, upper_before_lower locally false');

