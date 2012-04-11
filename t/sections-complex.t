# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 64;

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
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'C');

# Biblatex options
Biber::Config->setblxoption('maxcitenames', 1);
Biber::Config->setblxoption('maxalphanames', 1);
Biber::Config->setblxoption('labelyear', undef);

# Now generate the information
$biber->prepare;
my $section0 = $biber->sections->get_section(0);
my $bibentries0 = $section0->bibentries;
my $main0 = $biber->sortlists->get_list(0, 'entry', 'MAIN');
my $section1 = $biber->sections->get_section(1);
my $main1 = $biber->sortlists->get_list(1, 'entry', 'MAIN');
my $bibentries1 = $section1->bibentries;

is($bibentries0->entry('L1')->get_field('sortlabelalpha'), 'Doe95', 'maxalphanames=1 minalphanames=1 entry L1 labelalpha');
ok(is_undef($main0->get_extraalphadata('L1')), 'maxalphanames=1 minalphanames=1 entry L1 extraalpha');
is($bibentries0->entry('L2')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L2 labelalpha');
is($main0->get_extraalphadata('L2'), '1', 'maxalphanames=1 minalphanames=1 entry L2 extraalpha');
is($bibentries0->entry('L3')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L3 labelalpha');
is($main0->get_extraalphadata('L3'), '2', 'maxalphanames=1 minalphanames=1 entry L3 extraalpha');
is($bibentries0->entry('L4')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L4 labelalpha');
is($main0->get_extraalphadata('L4'), '3', 'maxalphanames=1 minalphanames=1 entry L4 extraalpha');
is($bibentries1->entry('L5')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L5 labelalpha');
is($main1->get_extraalphadata('L5'), '1', 'maxalphanames=1 minalphanames=1 entry L5 extraalpha');
is($bibentries1->entry('L6')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L6 labelalpha');
is($main1->get_extraalphadata('L6'), '2', 'maxalphanames=1 minalphanames=1 entry L6 extraalpha');
is($bibentries1->entry('L7')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L7 labelalpha');
is($main1->get_extraalphadata('L7'), '3', 'maxalphanames=1 minalphanames=1 entry L7 extraalpha');
is($bibentries1->entry('L8')->get_field('sortlabelalpha'), 'Sha85', 'maxalphanames=1 minalphanames=1 entry L8 labelalpha');
ok(is_undef($main1->get_extraalphadata('L8')), 'maxalphanames=1 minalphanames=1 entry L8 extraalpha');

# reset options and regenerate information
Biber::Config->setblxoption('maxcitenames', 2);
Biber::Config->setblxoption('mincitenames', 1);
Biber::Config->setblxoption('maxalphanames', 2);
Biber::Config->setblxoption('minalphanames', 1);

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
$main0 = $biber->sortlists->get_list(0, 'entry', 'MAIN');
$section1 = $biber->sections->get_section(1);
$main1 = $biber->sortlists->get_list(1, 'entry', 'MAIN');
$bibentries1 = $section1->bibentries;

is($bibentries0->entry('L1')->get_field('sortlabelalpha'), 'Doe95', 'maxalphanames=2 minalphanames=1 entry L1 labelalpha');
ok(is_undef($main0->get_extraalphadata('L1')), 'maxalphanames=2 minalphanames=1 entry L1 extraalpha');
is($bibentries0->entry('L2')->get_field('sortlabelalpha'), 'DA95', 'maxalphanames=2 minalphanames=1 entry L2 labelalpha');
is($main0->get_extraalphadata('L2'), '1', 'maxalphanames=2 minalphanames=1 entry L2 extraalpha');
is($bibentries0->entry('L3')->get_field('sortlabelalpha'), 'DA95', 'maxalphanames=2 minalphanames=1 entry L3 labelalpha');
is($main0->get_extraalphadata('L3'), '2', 'maxalphanames=2 minalphanames=1 entry L3 extraalpha');
is($bibentries0->entry('L4')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=2 minalphanames=1 entry L4 labelalpha');
ok(is_undef($main0->get_extraalphadata('L4')), 'maxalphanames=2 minalphanames=1 entry L4 extraalpha');
is($bibentries1->entry('L5')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=2 minalphanames=1 entry L5 labelalpha');
is($main1->get_extraalphadata('L5'), '1', 'maxalphanames=2 minalphanames=1 entry L5 extraalpha');
is($bibentries1->entry('L6')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=2 minalphanames=1 entry L6 labelalpha');
is($main1->get_extraalphadata('L6'), '2', 'maxalphanames=2 minalphanames=1 entry L6 extraalpha');
is($bibentries1->entry('L7')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=2 minalphanames=1 entry L7 labelalpha');
is($main1->get_extraalphadata('L7'), '3', 'maxalphanames=2 minalphanames=1 entry L7 extraalpha');
is($bibentries1->entry('L8')->get_field('sortlabelalpha'), 'Sha85', 'maxalphanames=2 minalphanames=1 entry L8 labelalpha');
ok(is_undef($main1->get_extraalphadata('L8')), 'maxalphanames=2 minalphanames=1 entry L8 extraalpha');

# reset options and regenerate information
Biber::Config->setblxoption('maxcitenames', 2);
Biber::Config->setblxoption('mincitenames', 2);
Biber::Config->setblxoption('maxalphanames', 2);
Biber::Config->setblxoption('minalphanames', 2);

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
$main0 = $biber->sortlists->get_list(0, 'entry', 'MAIN');
$section1 = $biber->sections->get_section(1);
$main1 = $biber->sortlists->get_list(1, 'entry', 'MAIN');
$bibentries1 = $section1->bibentries;

is($bibentries0->entry('L1')->get_field('sortlabelalpha'), 'Doe95', 'maxalphanames=2 minalphanames=2 entry L1 labelalpha');
ok(is_undef($main0->get_extraalphadata('L1')), 'maxalphanames=2 minalphanames=2 entry L1 extraalpha');
is($bibentries0->entry('L2')->get_field('sortlabelalpha'), 'DA95', 'maxalphanames=2 minalphanames=2 entry L2 labelalpha');
is($main0->get_extraalphadata('L2'), '1', 'maxalphanames=2 minalphanames=2 entry L2 extraalpha');
is($bibentries0->entry('L3')->get_field('sortlabelalpha'), 'DA95', 'maxalphanames=2 minalphanames=2 entry L3 labelalpha');
is($main0->get_extraalphadata('L3'), '2', 'maxalphanames=2 minalphanames=2 entry L3 extraalpha');
is($bibentries0->entry('L4')->get_field('sortlabelalpha'), 'DA+95', 'maxalphanames=2 minalphanames=2 entry L4 labelalpha');
ok(is_undef($main0->get_extraalphadata('L4')), 'maxalphanames=2 minalphanames=2 entry L4 extraalpha');
is($bibentries1->entry('L5')->get_field('sortlabelalpha'), 'DA+95', 'maxalphanames=2 minalphanames=2 entry L5 labelalpha');
ok(is_undef($main1->get_extraalphadata('L5')), 'maxalphanames=2 minalphanames=2 entry L5 extraalpha');
is($bibentries1->entry('L6')->get_field('sortlabelalpha'), 'DS+95', 'maxalphanames=2 minalphanames=2 entry L6 labelalpha');
is($main1->get_extraalphadata('L6'), '1', 'maxalphanames=2 minalphanames=2 entry L6 extraalpha');
is($bibentries1->entry('L7')->get_field('sortlabelalpha'), 'DS+95', 'maxalphanames=2 minalphanames=2 entry L7 labelalpha');
is($main1->get_extraalphadata('L7'), '2', 'maxalphanames=2 minalphanames=2 entry L7 extraalpha');
is($bibentries1->entry('L8')->get_field('sortlabelalpha'), 'Sha85', 'maxalphanames=2 minalphanames=2 entry L8 labelalpha');
ok(is_undef($main1->get_extraalphadata('L8')), 'maxalphanames=2 minalphanames=2 entry L8 extraalpha');

# reset options and regenerate information
Biber::Config->setblxoption('maxcitenames', 3);
Biber::Config->setblxoption('mincitenames', 1);
Biber::Config->setblxoption('maxalphanames', 3);
Biber::Config->setblxoption('minalphanames', 1);

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
$main0 = $biber->sortlists->get_list(0, 'entry', 'MAIN');
$section1 = $biber->sections->get_section(1);
$main1 = $biber->sortlists->get_list(1, 'entry', 'MAIN');
$bibentries1 = $section1->bibentries;

is($bibentries0->entry('L1')->get_field('sortlabelalpha'), 'Doe95', 'maxalphanames=3 minalphanames=1 entry L1 labelalpha');
ok(is_undef($main0->get_extraalphadata('L1')), 'maxalphanames=3 minalphanames=1 entry L1 extraalpha');
is($bibentries0->entry('L2')->get_field('sortlabelalpha'), 'DA95', 'maxalphanames=3 minalphanames=1 entry L2 labelalpha');
is($main0->get_extraalphadata('L2'), '1', 'maxalphanames=3 minalphanames=1 entry L2 extraalpha');
is($bibentries0->entry('L3')->get_field('sortlabelalpha'), 'DA95', 'maxalphanames=3 minalphanames=1 entry L3 labelalpha');
is($main0->get_extraalphadata('L3'), '2', 'maxalphanames=3 minalphanames=1 entry L3 extraalpha');
is($bibentries0->entry('L4')->get_field('sortlabelalpha'), 'DAE95', 'maxalphanames=3 minalphanames=1 entry L4 labelalpha');
ok(is_undef($main0->get_extraalphadata('L4')), 'maxalphanames=3 minalphanames=1 entry L4 extraalpha');
is($bibentries1->entry('L5')->get_field('sortlabelalpha'), 'DAE95', 'maxalphanames=3 minalphanames=1 entry L5 labelalpha');
ok(is_undef($main1->get_extraalphadata('L5')), 'maxalphanames=3 minalphanames=1 entry L5 extraalpha');
is($bibentries1->entry('L6')->get_field('sortlabelalpha'), 'DSE95', 'maxalphanames=3 minalphanames=1 entry L6 labelalpha');
ok(is_undef($main1->get_extraalphadata('L6')), 'maxalphanames=3 minalphanames=1 entry L6 extraalpha');
is($bibentries1->entry('L7')->get_field('sortlabelalpha'), 'DSJ95', 'maxalphanames=3 minalphanames=1 entry L7 labelalpha');
ok(is_undef($main1->get_extraalphadata('L7')), 'maxalphanames=3 minalphanames=1 entry L7 extraalpha');
is($bibentries1->entry('L8')->get_field('sortlabelalpha'), 'Sha85', 'maxalphanames=3 minalphanames=1 entry L8 labelalpha');
ok(is_undef($main1->get_extraalphadata('L8')), 'maxalphanames=3 minalphanames=1 entry L8 extraalpha');

