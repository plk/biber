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

$biber->parse_ctrlfile('sort-uc.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests
Biber::Config->setoption('sortlocale', 'sv_SE');

# U::C Swedish tailoring
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $main = $biber->sortlists->get_list(0, 'entry', 'MAIN');
my $shs = $biber->sortlists->get_list(0, 'shorthand', 'SHORTHANDS');

# Shorthands are sorted by shorthand (as per bcf)
is_deeply([$main->get_keys], ['LS2','LS1','LS3','LS4'], 'U::C tailoring - 1');
is_deeply([$shs->get_keys], ['LS3', 'LS4','LS2','LS1'], 'U::C tailoring - 2');

# Set sorting of shorthands to global sorting default
$shs->set_sortscheme(Biber::Config->getblxoption('sorting'));

$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply([$shs->get_keys], ['LS2', 'LS1','LS3','LS4'], 'U::C tailoring - 3');


# Descending name in Swedish collation
$S = [
                                                    [
                                                     {},
                                                     {'presort'    => {}}
                                                    ],
                                                    [
                                                     {final        => 1},
                                                     {'sortkey'    => {}}
                                                    ],
                                                    [
                                                     {sort_direction => 'descending'},
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ]
                                                   ];

$main->set_sortscheme($S);

$biber->prepare;
$section = $biber->sections->get_section(0);

is_deeply([$main->get_keys], ['LS3','LS4','LS1','LS2'], 'U::C tailoring descending - 1');

# Local lower before upper setting
$S = [
                                                    [
                                                     {sortupper => 0},
                                                     {'title'   => {}}
                                                    ]
                                                   ];

$main->set_sortscheme($S);

$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply([$main->get_keys], ['LS4', 'LS3','LS2','LS1'], 'upper_before_lower locally false');

# Local case insensitive negates the sortupper being false as this no longer
# means anything so it reverts to bib order for LS3 and LS4
# For this, have to reparse the .bcf otherwise the citekey order from previous
# test is kept for things that are not sort distinguishable
$biber->parse_ctrlfile('sort-uc.bcf');
$section = $biber->sections->get_section(0);
$main = $biber->sortlists->get_list(0, 'entry', 'MAIN');
$biber->set_output_obj(Biber::Output::bbl->new());
$S = [
                                                    [
                                                     {sortupper => 0,
                                                      sortcase  => 0},
                                                     {'title'   => {}}
                                                    ]
                                                   ];

$main->set_sortscheme($S);
$biber->prepare;
is_deeply([$main->get_keys], ['LS3', 'LS4','LS2','LS1'], 'sortcase locally false, upper_before_lower locally false');

