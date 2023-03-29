# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 18;

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

$biber->parse_ctrlfile('sort-order.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');
Biber::Config->setblxoption(undef,'labeldateparts', 0);
Biber::Config->setblxoption(undef,'labelalpha', 0);

# (re)generate information based on option settings
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $section1 = $biber->sections->get_section(1);
my $section2 = $biber->sections->get_section(2);
my $main = $biber->datalists->get_list('none/global//global/global/global');
my $main1 = $biber->datalists->get_list('none/global//global/global/global', 1);
my $main2 = $biber->datalists->get_list('none/global//global/global/global', 2);

# Testing \nocite order with sorting=none
is_deeply($main1->get_keys, ['L2', 'L1','L1A','L1B','L3','L4','L5','L6','L7','L8','L9'], 'sorting=none and \nocite{*} second');
is_deeply($main2->get_keys, ['L1','L1A','L1B','L2','L3','L4','L5','L6','L7','L8','L9'], 'sorting=none and \nocite{*} first');

is_deeply($main->get_keys, ['L2','L3','L1B','L1','L4','L5','L1A','L7','L8','L6','L9'], 'citeorder');

$main->set_sortingtemplatename('nty');

$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply($main->get_keys, ['L5','L1A','L1','L1B','L2','L3','L4','L8','L7','L6','L9'], 'nty');

$main->set_sortingtemplatename('nyt');

$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply($main->get_keys, ['L5','L1A','L1','L1B','L2','L3','L4','L8','L7','L6','L9'], 'nyt');

$main->set_sortingtemplatename('nyvt');

$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply($main->get_keys, ['L5','L1','L1A','L1B','L2','L3','L4','L8','L7','L6','L9'], 'nyvt');

# nyvt with volume padding

$main->set_sortingtemplatename('nyvtvp');

$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply($main->get_keys, ['L5','L1A','L1','L1B','L2','L3','L4','L8','L7','L6','L9'], 'nyvt with volume padding');

$main->set_sortingtemplatename('ynt');

$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
# Note that L5 is last because it has a final sortkey which maps to a  large
# int in sort fields
is_deeply($main->get_keys, ['L3','L1B','L1A','L1','L4','L2','L8','L7','L6','L9','L5'], 'ynt');

$main->set_sortingtemplatename('yntys');

$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
# Note that L5 is last because it has a final sortkey which maps to a  large
# int in sort fields
is_deeply($main->get_keys, ['L3','L1B','L1A','L1','L2','L4','L8','L7','L6','L9','L5'], 'ynt with year substring');

$main->set_sortingtemplatename('ydnt');

$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
# Note that L5 is first because it has a final sortkey which maps to a
# large int in sort fields
is_deeply($main->get_keys, ['L5','L9','L6','L7','L8','L2','L4','L1A','L1','L1B','L3'], 'ydnt');

$main->set_sortingtemplatename('et');

$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply($main->get_keys, ['L2','L3','L1B', 'L1','L1A','L4','L5','L7','L8','L6', 'L9'], 'entrytype');

$main->set_sortingtemplatename('anyt');

Biber::Config->setblxoption(undef,'labelalpha', 1);

$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply($main->get_keys, ['L1B','L1A','L1','L2','L3','L4','L5','L8','L7','L6','L9'], 'anyt');

Biber::Config->setblxoption(undef,'labelalpha', 0);

$main->set_sortingtemplatename('anyvt');

Biber::Config->setblxoption(undef,'labelalpha', 1);

$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply($main->get_keys, ['L1B','L1','L1A','L2','L3','L4','L5','L8','L7','L6','L9'], 'anyvt');

$main->set_sortingtemplatename('ndty');

$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply($main->get_keys, ['L9','L6','L7','L8','L5','L4','L3','L2','L1B','L1A','L1'], 'nty with descending n');

# Test nosort option
$main->set_sortingtemplatename('t');

# Set nosort for tests, skipping "The " in titles so L7 should sort before L6
Biber::Config->setoption('nosort', [{ name => 'settitles', value => q/\AThe\s+/ }]);

$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply($main->get_keys, ['L1A','L1','L1B','L2','L3','L4','L5','L7','L6','L9','L8'], 'nosort 1');

# Testing sorting keys which have the same order as they were cited in the same \cite*{} cmd.
# In this case, they will be tied on sorting=none and can be further sorted by other fields
$main->set_sortingtemplatename('ny');

# Have to do a citekey deletion as we are not re-reading the .bcf which would do it for us
# Otherwise, we have citekeys and allkeys which confuses fetch_data()
$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply($main->get_keys, ['L3','L2','L1B','L1','L4','L5','L1A','L7','L8','L6','L9'], 'sorting=none + year');

# Test citecount sort
$main->set_sortingtemplatename('count');

$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply($main->get_keys, ['L9','L4','L6','L7','L8','L5','L2','L1','L1A','L1B','L3'], 'citecount 1');

# Testing special case of sorting=none and allkeys because in this case "citeorder" means
# bib order
$main->set_sortingtemplatename('none');

# Have to do a citekey deletion as we are not re-reading the .bcf which would do it for us
# Otherwise, we have citekeys and allkeys which confuses fetch_data()
$section->del_citekeys;
Biber::Config->reset_keyorder(0);
$section->set_allkeys(1);
$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply($main->get_keys, ['L1','L1A','L1B','L2','L3','L4','L5','L6','L7','L8','L9'], 'sorting=none and allkeys');
