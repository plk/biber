# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 4;
use Test::Differences;
unified_diff;

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

Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');
$biber->parse_ctrlfile("general.bcf");
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biblatex options
Biber::Config->setblxoption(undef,'labelnamespec', [ {content => 'shortauthor'},
                                               {content => 'author'},
                                               {content => 'shorteditor'},
                                               {content => 'editor'},
                                               {content => 'translator'}]);
Biber::Config->setblxoption(undef,'labelnamespec', [ {content => 'editor'},
                                               {content => 'translator'}], 'ENTRYTYPE', 'book');
Biber::Config->setblxoption(undef,'labelnamespec', [ {content => 'namea'},
                                               {content => 'author' }], 'ENTRYTYPE', 'misc');

# Now generate the information
$biber->prepare;
my $bibentries = $biber->sections->get_section(0)->bibentries;

eq_or_diff($bibentries->entry('angenendtsa')->get_labelname_info, 'shortauthor', 'global shortauthor' );
eq_or_diff($bibentries->entry('stdmodel')->get_labelname_info, 'author', 'global author' );
eq_or_diff($bibentries->entry('aristotle:anima')->get_labelname_info, 'editor', 'type-specific editor' );
eq_or_diff($bibentries->entry('lne1')->get_labelname_info, 'namea', 'type-specific exotic name' );
