# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 4;

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

Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'C');
$biber->parse_ctrlfile("general1.bcf");
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biblatex options
Biber::Config->setblxoption('labelnamespec', ['shortauthor', 'author', 'shorteditor', 'editor', 'translator']);
Biber::Config->setblxoption('labelnamespec', ['editor', 'translator'], 'PER_TYPE', 'book');
Biber::Config->setblxoption('labelnamespec', ['namea', 'author'], 'PER_TYPE', 'misc');

# Now generate the information
$biber->prepare;
my $bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('angenendtsa')->get_field('labelnamename'), 'shortauthor', 'global shortauthor' );
is($bibentries->entry('stdmodel')->get_field('labelnamename'), 'author', 'global author' );
is($bibentries->entry('aristotle:anima')->get_field('labelnamename'), 'editor', 'type-specific editor' );
is($bibentries->entry('lne1')->get_field('labelnamename'), 'namea', 'type-specific exotic name' );
