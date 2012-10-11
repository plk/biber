# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 6;

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

$biber->parse_ctrlfile("bibtex-forms.bcf");
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('sortlocale', 'C');
Biber::Config->setoption('fastsort', 1);

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $bibentries = $section->bibentries;
my $main = $biber->sortlists->get_list(0, 'entry', 'nty');

is($bibentries->entry('forms1')->get_field('title'), 'Мухаммад ибн муса ал-Хорезми. Около 783 – около 850', 'forms - 1');
is($bibentries->entry('forms1')->get_field('title', 'original'), 'Мухаммад ибн муса ал-Хорезми. Около 783 – около 850', 'forms - 2');
is($bibentries->entry('forms1')->get_field('title', 'romanised'), 'Mukhammad al-Khorezmi. Okolo 783 – okolo 850', 'forms - 3');
is($bibentries->entry('forms1')->get_field('title', 'translated'), 'Mukhammad al-Khorezmi. Ca. 783 – ca. 850', 'forms - 4');
is($bibentries->entry('forms1')->get_field('publisher', 'original')->[0], 'Наука', 'forms - 5');
is($bibentries->entry('forms1')->get_field('author')->nth_name(2)->get_firstname, 'Борис', 'forms - 6');
