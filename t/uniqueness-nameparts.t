# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 4;
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

$biber->parse_ctrlfile('uniqueness-nameparts.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');

# Biblatex options
Biber::Config->setblxoption('uniquename', 2);

# Now generate the information
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $bibentries = $section->bibentries;
my $main = $biber->sortlists->get_list(0, 'nty/global/', 'entry', 'nty', 'global' ,'');

# Basic uniquename and hash testing
eq_or_diff($bibentries->entry('un1')->get_field('author')->nth_name(1)->get_uniquename, ['middle', 'init'], 'Uniquename namepart - 1');
eq_or_diff($bibentries->entry('un2')->get_field('author')->nth_name(1)->get_uniquename, ['middle', 'full'], 'Uniquename namepart - 2');
eq_or_diff($bibentries->entry('un3')->get_field('author')->nth_name(1)->get_uniquename, ['middle', 'full'], 'Uniquename namepart - 3');
eq_or_diff($bibentries->entry('un4')->get_field('author')->nth_name(1)->get_uniquename, ['given', 'init'], 'Uniquename namepart - 4');
