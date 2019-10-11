# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 19;
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

$biber->parse_ctrlfile('multiscript.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('bcf', 'multiscript.bcf');

# Now generate the information
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $bibentries = $section->bibentries;
my $main = $biber->datalists->get_list('nty/global//global/global');
my $out = $biber->get_output_obj;

eq_or_diff($bibentries->entry('ms1')->get_field('title'), 'Title', 'multiscript - 1');
eq_or_diff($bibentries->entry('ms1')->get_field('title', 'translation', 'fr'), 'Titre', 'multiscript - 2');
eq_or_diff($bibentries->entry('ms1')->get_field('author', 'transliteration', 'ru-latn')->nth_mslang(2), 'ru-latn', 'multiscript - 3');
eq_or_diff($bibentries->entry('ms1')->get_field('author', 'transliteration', 'ru-latn')->nth_mslang(3), 'zh-latn', 'multiscript - 4');
eq_or_diff($bibentries->entry('ms1')->get_field('author', 'transliteration', 'ru-grek')->nth_mslang(2), 'ru-grek', 'multiscript - 5');
eq_or_diff($bibentries->entry('ms1')->get_field('author', 'transliteration', 'ru-grek')->nth_mslang(3), 'zh-grek', 'multiscript - 6');
eq_or_diff($bibentries->entry('ms1')->get_field('author')->nth_mslang(2), 'ru-cyrl', 'multiscript - 7');
eq_or_diff($bibentries->entry('ms1')->get_field('author')->nth_mslang(3), 'zh-hant', 'multiscript - 8');
eq_or_diff($bibentries->entry('ms1')->get_field('author')->nth_mslang(1), 'en-us', 'multiscript - 9');
eq_or_diff($bibentries->entry('ms1')->get_field('author', 'transliteration', 'ru-latn')->nth_mslang(1), 'en-us', 'multiscript - 10');
eq_or_diff($bibentries->entry('ms1')->get_field('author', 'transliteration', 'ru-grek')->nth_mslang(1), 'en-us', 'multiscript - 11');
eq_or_diff($bibentries->entry('ms1')->get_field('location')->nth_mslang(1), 'en-us', 'multiscript - 12');
eq_or_diff($bibentries->entry('ms1')->get_field('location')->nth_mslang(2), 'de', 'multiscript - 13');
eq_or_diff($bibentries->entry('ms1')->get_field('location', 'translation', 'fr')->nth_mslang(1), 'fr', 'multiscript - 14');
eq_or_diff($bibentries->entry('ms1')->get_field('location', 'translation', 'fr')->nth_mslang(2), 'de', 'multiscript - 15');

# biblatex source
eq_or_diff($bibentries->entry('bltx1')->get_field('author')->nth_mslang(1), 'ru-cyrl', 'multiscript - 16');
eq_or_diff($bibentries->entry('bltx1')->get_field('author')->nth_mslang(2), 'en-us', 'multiscript - 17');
eq_or_diff($bibentries->entry('bltx1')->get_field('author', 'transliteration', 'ru-Grek')->nth_mslang(1), 'ru-grek', 'multiscript - 18');
eq_or_diff($bibentries->entry('bltx1')->get_field('author', 'transliteration', 'ru-grek')->nth_mslang(2), 'en-us', 'multiscript - 19');
