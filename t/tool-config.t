# -*- cperl -*-
use strict;
use warnings;
use Test::More tests => 12;
use Test::Differences;
unified_diff;

use Encode;
use Biber;
use Biber::Utils;
use Biber::Output::bibtex;
use Log::Log4perl;
use Unicode::Normalize;
use XML::LibXML;
use Cwd 'abs_path';
use List::Util qw( first );

no warnings 'utf8';
use utf8;

chdir("t/tdata");

# Set up Biber object
my $biber = Biber->new(tool => 1,
                       configtool => abs_path('../../data/biber-tool.conf'),
                       configfile => 'tool-testconfig.conf');

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
$biber->set_output_obj(Biber::Output::bibtex->new());
# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('tool', 1);

# THERE IS A CONFIG FILE BEING READ!

# Now generate the information
$ARGV[0] = 'tool.bib'; # fake this as we are not running through top-level biber program
$biber->tool_mode_setup;
$biber->prepare_tool;
my $dm = Biber::Config->get_dm;
eq_or_diff(Biber::Config->getoption('mincrossrefs'), 5, 'Options 1');
eq_or_diff(Biber::Config->getoption('listsep'), 'and', 'Options 2');
is_deeply (Biber::Config->getblxoption(0, 'sortingtemplate'), {tool => { locale => undef, spec => [[{}, { citeorderX => {} }]] }}, 'Options 3');
# This is only in the user conf datamodel
ok((first {$_ eq 'newliteralfield'} $dm->get_fields_of_type('field', 'literal')->@*), 'Options 4');
ok($dm->is_field_for_entrytype('article', 'newliteralfield'), 'Options 5');
ok($dm->is_field_for_entrytype('xyz', 'author'), 'Options 6');
ok($dm->is_field_for_entrytype('xyz', 'file'), 'Options 7');
ok($dm->is_field_for_entrytype('xyz', 'abc'), 'Options 8');
ok($dm->is_field_for_entrytype('article', 'abc'), 'Options 9');
ok($dm->is_field_for_entrytype('book', 'bookzzz'), 'Options 10');
ok($dm->is_field_for_entrytype('article', 'bookzzz')==0, 'Options 11');
ok((first {$_ eq 'month'} $dm->get_fields_of_type('field', 'literal')->@*), 'Options 12');
