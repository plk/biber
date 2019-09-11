# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 8;
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

$biber->parse_ctrlfile('maps.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $bibentries = $section->bibentries;

# Explictly cited ARTICLE, not deleted by map
ok(defined($bibentries->entry('maps1')), 'Maps test - 1' );
# \nocite{*} ARTICLE, deleted by map
ok(is_undef($bibentries->entry('maps2')), 'Maps test - 2' );
# \nocite{*} COLLECTION, not deleted by map
ok(defined($bibentries->entry('maps3')), 'Maps test - 3' );
# \nocited{*} BOOK, deleted by map
ok(is_undef($bibentries->entry('maps4')), 'Maps test - 4' );
# Specifically cited ARTICLE, field set
eq_or_diff($bibentries->entry('maps1')->get_field('verba'), 'somevalue', 'Maps test - 5' );
ok(is_undef($bibentries->entry('maps3')->get_field('verba')), 'Maps test - 6' );
eq_or_diff($bibentries->entry('maps1')->get_field('verbb'), 'somevalue1', 'Maps test - 7' );
ok(is_undef($bibentries->entry('maps3')->get_field('verbb')), 'Maps test - 8' );
