# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 68;
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

$biber->parse_ctrlfile('sections-complex.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');

# Biblatex options
Biber::Config->setblxoption(undef,'maxcitenames', 1);
Biber::Config->setblxoption(undef,'maxalphanames', 1);
Biber::Config->setblxoption(undef,'labeldateparts', 0);

# Now generate the information
$biber->prepare;
my $section0 = $biber->sections->get_section(0);
my $bibentries0 = $section0->bibentries;
my $main0 = $biber->datalists->get_list('custom/global//global/global/global');
my $section1 = $biber->sections->get_section(1);
my $main1 = $biber->datalists->get_list('custom/global//global/global/global', 1);

my $bibentries1 = $section1->bibentries;

eq_or_diff($main0->get_entryfield('L1', 'sortlabelalpha'), 'Doe95', 'maxalphanames=1 minalphanames=1 entry L1 labelalpha');
ok(is_undef($main0->get_extraalphadata_for_key('L1')), 'maxalphanames=1 minalphanames=1 entry L1 extraalpha');
eq_or_diff($main0->get_entryfield('L2', 'sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L2 labelalpha');
eq_or_diff($main0->get_extraalphadata_for_key('L2'), '1', 'maxalphanames=1 minalphanames=1 entry L2 extraalpha');
eq_or_diff($main0->get_entryfield('L3', 'sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L3 labelalpha');
eq_or_diff($main0->get_extraalphadata_for_key('L3'), '2', 'maxalphanames=1 minalphanames=1 entry L3 extraalpha');
eq_or_diff($main0->get_entryfield('L4', 'sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L4 labelalpha');
eq_or_diff($main0->get_extraalphadata_for_key('L4'), '3', 'maxalphanames=1 minalphanames=1 entry L4 extraalpha');
eq_or_diff($main1->get_entryfield('L5', 'sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L5 labelalpha');
eq_or_diff($main1->get_extraalphadata_for_key('L5'), '1', 'maxalphanames=1 minalphanames=1 entry L5 extraalpha');
eq_or_diff($main1->get_entryfield('L6', 'sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L6 labelalpha');
eq_or_diff($main1->get_extraalphadata_for_key('L6'), '2', 'maxalphanames=1 minalphanames=1 entry L6 extraalpha');
eq_or_diff($main1->get_entryfield('L7', 'sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L7 labelalpha');
eq_or_diff($main1->get_extraalphadata_for_key('L7'), '3', 'maxalphanames=1 minalphanames=1 entry L7 extraalpha');
eq_or_diff($main1->get_entryfield('L8', 'sortlabelalpha'), 'Sha85', 'maxalphanames=1 minalphanames=1 entry L8 labelalpha');
ok(is_undef($main1->get_extraalphadata_for_key('L8')), 'maxalphanames=1 minalphanames=1 entry L8 extraalpha');

# reset options and regenerate information
Biber::Config->setblxoption(undef,'maxcitenames', 2);
Biber::Config->setblxoption(undef,'mincitenames', 1);
Biber::Config->setblxoption(undef,'maxalphanames', 2);
Biber::Config->setblxoption(undef,'minalphanames', 1);

for (my $i=1; $i<5; $i++) {
  $bibentries0->entry("L$i")->del_field('sortlabelalpha');
  $bibentries0->entry("L$i")->del_field('labelalpha');
  $main0->set_extraalphadata_for_key("L$i", undef);
}
for (my $i=5; $i<9; $i++) {
  $bibentries1->entry("L$i")->del_field('sortlabelalpha');
  $bibentries1->entry("L$i")->del_field('labelalpha');
  $main1->set_extraalphadata_for_key("L$i", undef);
}
$biber->prepare;
$section0 = $biber->sections->get_section(0);
$bibentries0 = $section0->bibentries;
$main0 = $biber->datalists->get_list('custom/global//global/global/global');
$section1 = $biber->sections->get_section(1);
$main1 = $biber->datalists->get_list('custom/global//global/global/global', 1);

$bibentries1 = $section1->bibentries;

eq_or_diff($main0->get_entryfield('L1', 'sortlabelalpha'), 'Doe95', 'maxalphanames=2 minalphanames=1 entry L1 labelalpha');
ok(is_undef($main0->get_extraalphadata_for_key('L1')), 'maxalphanames=2 minalphanames=1 entry L1 extraalpha');
eq_or_diff($main0->get_entryfield('L2', 'sortlabelalpha'), 'DA95', 'maxalphanames=2 minalphanames=1 entry L2 labelalpha');
eq_or_diff($main0->get_extraalphadata_for_key('L2'), '1', 'maxalphanames=2 minalphanames=1 entry L2 extraalpha');
eq_or_diff($main0->get_entryfield('L3', 'sortlabelalpha'), 'DA95', 'maxalphanames=2 minalphanames=1 entry L3 labelalpha');
eq_or_diff($main0->get_extraalphadata_for_key('L3'), '2', 'maxalphanames=2 minalphanames=1 entry L3 extraalpha');
eq_or_diff($main0->get_entryfield('L4', 'sortlabelalpha'), 'Doe+95', 'maxalphanames=2 minalphanames=1 entry L4 labelalpha');
ok(is_undef($main0->get_extraalphadata_for_key('L4')), 'maxalphanames=2 minalphanames=1 entry L4 extraalpha');
eq_or_diff($main1->get_entryfield('L5', 'sortlabelalpha'), 'Doe+95', 'maxalphanames=2 minalphanames=1 entry L5 labelalpha');
eq_or_diff($main1->get_extraalphadata_for_key('L5'), '1', 'maxalphanames=2 minalphanames=1 entry L5 extraalpha');
eq_or_diff($main1->get_entryfield('L6', 'sortlabelalpha'), 'Doe+95', 'maxalphanames=2 minalphanames=1 entry L6 labelalpha');
eq_or_diff($main1->get_extraalphadata_for_key('L6'), '2', 'maxalphanames=2 minalphanames=1 entry L6 extraalpha');
eq_or_diff($main1->get_entryfield('L7', 'sortlabelalpha'), 'Doe+95', 'maxalphanames=2 minalphanames=1 entry L7 labelalpha');
eq_or_diff($main1->get_extraalphadata_for_key('L7'), '3', 'maxalphanames=2 minalphanames=1 entry L7 extraalpha');
eq_or_diff($main1->get_entryfield('L8', 'sortlabelalpha'), 'Sha85', 'maxalphanames=2 minalphanames=1 entry L8 labelalpha');
ok(is_undef($main1->get_extraalphadata_for_key('L8')), 'maxalphanames=2 minalphanames=1 entry L8 extraalpha');

# reset options and regenerate information
Biber::Config->setblxoption(undef,'maxcitenames', 2);
Biber::Config->setblxoption(undef,'mincitenames', 2);
Biber::Config->setblxoption(undef,'maxalphanames', 2);
Biber::Config->setblxoption(undef,'minalphanames', 2);

for (my $i=1; $i<5; $i++) {
  $bibentries0->entry("L$i")->del_field('sortlabelalpha');
  $bibentries0->entry("L$i")->del_field('labelalpha');
  $main0->set_extraalphadata_for_key("L$i", undef);
}
for (my $i=5; $i<9; $i++) {
  $bibentries1->entry("L$i")->del_field('sortlabelalpha');
  $bibentries1->entry("L$i")->del_field('labelalpha');
  $main1->set_extraalphadata_for_key("L$i", undef);
}
$biber->prepare;
$section0 = $biber->sections->get_section(0);
$bibentries0 = $section0->bibentries;
$main0 = $biber->datalists->get_list('custom/global//global/global/global');
$section1 = $biber->sections->get_section(1);
$main1 = $biber->datalists->get_list('custom/global//global/global/global', 1);
$bibentries1 = $section1->bibentries;

eq_or_diff($main0->get_entryfield('L1', 'sortlabelalpha'), 'Doe95', 'maxalphanames=2 minalphanames=2 entry L1 labelalpha');
ok(is_undef($main0->get_extraalphadata_for_key('L1')), 'maxalphanames=2 minalphanames=2 entry L1 extraalpha');
eq_or_diff($main0->get_entryfield('L2', 'sortlabelalpha'), 'DA95', 'maxalphanames=2 minalphanames=2 entry L2 labelalpha');
eq_or_diff($main0->get_extraalphadata_for_key('L2'), '1', 'maxalphanames=2 minalphanames=2 entry L2 extraalpha');
eq_or_diff($main0->get_entryfield('L3', 'sortlabelalpha'), 'DA95', 'maxalphanames=2 minalphanames=2 entry L3 labelalpha');
eq_or_diff($main0->get_extraalphadata_for_key('L3'), '2', 'maxalphanames=2 minalphanames=2 entry L3 extraalpha');
eq_or_diff($main0->get_entryfield('L4', 'sortlabelalpha'), 'DA+95', 'maxalphanames=2 minalphanames=2 entry L4 labelalpha');
ok(is_undef($main0->get_extraalphadata_for_key('L4')), 'maxalphanames=2 minalphanames=2 entry L4 extraalpha');
eq_or_diff($main1->get_entryfield('L5', 'sortlabelalpha'), 'DA+95', 'maxalphanames=2 minalphanames=2 entry L5 labelalpha');
ok(is_undef($main1->get_extraalphadata_for_key('L5')), 'maxalphanames=2 minalphanames=2 entry L5 extraalpha');
eq_or_diff($main1->get_entryfield('L6', 'sortlabelalpha'), 'DS+95', 'maxalphanames=2 minalphanames=2 entry L6 labelalpha');
eq_or_diff($main1->get_extraalphadata_for_key('L6'), '1', 'maxalphanames=2 minalphanames=2 entry L6 extraalpha');
eq_or_diff($main1->get_entryfield('L7', 'sortlabelalpha'), 'DS+95', 'maxalphanames=2 minalphanames=2 entry L7 labelalpha');
eq_or_diff($main1->get_extraalphadata_for_key('L7'), '2', 'maxalphanames=2 minalphanames=2 entry L7 extraalpha');
eq_or_diff($main1->get_entryfield('L8', 'sortlabelalpha'), 'Sha85', 'maxalphanames=2 minalphanames=2 entry L8 labelalpha');
ok(is_undef($main1->get_extraalphadata_for_key('L8')), 'maxalphanames=2 minalphanames=2 entry L8 extraalpha');

# reset options and regenerate information
Biber::Config->setblxoption(undef,'maxcitenames', 3);
Biber::Config->setblxoption(undef,'mincitenames', 1);
Biber::Config->setblxoption(undef,'maxalphanames', 3);
Biber::Config->setblxoption(undef,'minalphanames', 1);

for (my $i=1; $i<5; $i++) {
  $bibentries0->entry("L$i")->del_field('sortlabelalpha');
  $bibentries0->entry("L$i")->del_field('labelalpha');
  $main0->set_extraalphadata_for_key("L$i", undef);
}
for (my $i=5; $i<9; $i++) {
  $bibentries1->entry("L$i")->del_field('sortlabelalpha');
  $bibentries1->entry("L$i")->del_field('labelalpha');
  $main1->set_extraalphadata_for_key("L$i", undef);
}

$biber->prepare;
$section0 = $biber->sections->get_section(0);
$bibentries0 = $section0->bibentries;
$main0 = $biber->datalists->get_list('custom/global//global/global/global');
$section1 = $biber->sections->get_section(1);
$main1 = $biber->datalists->get_list('custom/global//global/global/global', 1);
$bibentries1 = $section1->bibentries;

eq_or_diff($main0->get_entryfield('L1', 'sortlabelalpha'), 'Doe95', 'maxalphanames=3 minalphanames=1 entry L1 labelalpha');
ok(is_undef($main0->get_extraalphadata_for_key('L1')), 'maxalphanames=3 minalphanames=1 entry L1 extraalpha');
eq_or_diff($main0->get_entryfield('L2', 'sortlabelalpha'), 'DA95', 'maxalphanames=3 minalphanames=1 entry L2 labelalpha');
eq_or_diff($main0->get_extraalphadata_for_key('L2'), '1', 'maxalphanames=3 minalphanames=1 entry L2 extraalpha');
eq_or_diff($main0->get_entryfield('L3', 'sortlabelalpha'), 'DA95', 'maxalphanames=3 minalphanames=1 entry L3 labelalpha');
eq_or_diff($main0->get_extraalphadata_for_key('L3'), '2', 'maxalphanames=3 minalphanames=1 entry L3 extraalpha');
eq_or_diff($main0->get_entryfield('L4', 'sortlabelalpha'), 'DAE95', 'maxalphanames=3 minalphanames=1 entry L4 labelalpha');
ok(is_undef($main0->get_extraalphadata_for_key('L4')), 'maxalphanames=3 minalphanames=1 entry L4 extraalpha');
eq_or_diff($main1->get_entryfield('L5', 'sortlabelalpha'), 'DAE95', 'maxalphanames=3 minalphanames=1 entry L5 labelalpha');
ok(is_undef($main1->get_extraalphadata_for_key('L5')), 'maxalphanames=3 minalphanames=1 entry L5 extraalpha');
eq_or_diff($main1->get_entryfield('L6', 'sortlabelalpha'), 'DSE95', 'maxalphanames=3 minalphanames=1 entry L6 labelalpha');
ok(is_undef($main1->get_extraalphadata_for_key('L6')), 'maxalphanames=3 minalphanames=1 entry L6 extraalpha');
eq_or_diff($main1->get_entryfield('L7', 'sortlabelalpha'), 'DSJ95', 'maxalphanames=3 minalphanames=1 entry L7 labelalpha');
ok(is_undef($main1->get_extraalphadata_for_key('L7')), 'maxalphanames=3 minalphanames=1 entry L7 extraalpha');
eq_or_diff($main1->get_entryfield('L8', 'sortlabelalpha'), 'Sha85', 'maxalphanames=3 minalphanames=1 entry L8 labelalpha');
ok(is_undef($main1->get_extraalphadata_for_key('L8')), 'maxalphanames=3 minalphanames=1 entry L8 extraalpha');
ok(is_undef($bibentries0->entry('m1')->get_field('keywords')), 'map refsection - 1');
eq_or_diff($bibentries0->entry('m1')->get_field('title'), 'Film title 1', 'map refsection - 2');
eq_or_diff($bibentries1->entry('m1')->get_field('keywords'), ['thing'], 'map refsection- 3');
eq_or_diff($bibentries1->entry('m1')->get_field('title'), 'Film title 11', 'map refsection - 4');
