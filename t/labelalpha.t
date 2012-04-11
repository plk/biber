# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 101;

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

$biber->parse_ctrlfile('labelalpha.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'C');

# Biblatex options
Biber::Config->setblxoption('maxalphanames', 1);
Biber::Config->setblxoption('maxcitenames', 1);
Biber::Config->setblxoption('labelyear', undef);

# Now generate the information
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $main = $biber->sortlists->get_list(0, 'entry', 'MAIN');
my $bibentries = $section->bibentries;

is($bibentries->entry('L1')->get_field('sortlabelalpha'), 'Doe95', 'maxalphanames=1 minalphanames=1 entry L1 labelalpha');
ok(is_undef($main->get_extraalphadata('l1')), 'maxalphanames=1 minalphanames=1 entry L1 extraalpha');
is($bibentries->entry('L2')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L2 labelalpha');
is($main->get_extraalphadata('L2'), '1', 'maxalphanames=1 minalphanames=1 entry L2 extraalpha');
is($bibentries->entry('L3')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L3 labelalpha');
is($main->get_extraalphadata('L3'), '2', 'maxalphanames=1 minalphanames=1 entry L3 extraalpha');
is($bibentries->entry('L4')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L4 labelalpha');
is($main->get_extraalphadata('L4'), '3', 'maxalphanames=1 minalphanames=1 entry L4 extraalpha');
is($bibentries->entry('L5')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L5 labelalpha');
is($main->get_extraalphadata('L5'), '4', 'maxalphanames=1 minalphanames=1 entry L5 extraalpha');
is($bibentries->entry('L6')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L6 labelalpha');
is($main->get_extraalphadata('L6'), '5', 'maxalphanames=1 minalphanames=1 entry L6 extraalpha');
is($bibentries->entry('L7')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L7 labelalpha');
is($main->get_extraalphadata('L7'), '6', 'maxalphanames=1 minalphanames=1 entry L7 extraalpha');
is($bibentries->entry('L8')->get_field('sortlabelalpha'), 'Sha85', 'maxalphanames=1 minalphanames=1 entry L8 labelalpha');
ok(is_undef($main->get_extraalphadata('L8')), 'maxalphanames=1 minalphanames=1 entry L8 extraalpha');
ok(is_undef($main->get_extraalphadata('L9')), 'L9 extraalpha unset due to shorthand');
ok(is_undef($main->get_extraalphadata('L10')), 'L10 extraalpha unset due to shorthand');
is($main->get_extraalphadata('knuth:ct'), '1', 'YEAR with range needs label differentiating from individual volumes - 1');
is($main->get_extraalphadata('knuth:ct:a'), '2', 'YEAR with range needs label differentiating from individual volumes - 2');
is($main->get_extraalphadata('knuth:ct:b'), '1', 'YEAR with range needs label differentiating from individual volumes - 3');
is($main->get_extraalphadata('knuth:ct:c'), '2', 'YEAR with range needs label differentiating from individual volumes - 4');

# reset options and regenerate information
Biber::Config->setblxoption('maxalphanames', 2);
Biber::Config->setblxoption('minalphanames', 1);
Biber::Config->setblxoption('maxcitenames', 2);
Biber::Config->setblxoption('mincitenames', 1);

foreach my $k ($section->get_citekeys) {
  $bibentries->entry($k)->del_field('sortlabelalpha');
  $bibentries->entry($k)->del_field('labelalpha');
  $main->set_extraalphadata_for_key($k, undef);
}

$biber->prepare;
$section = $biber->sections->get_section(0);
$main = $biber->sortlists->get_list(0, 'entry', 'MAIN');
$bibentries = $section->bibentries;

is($bibentries->entry('L1')->get_field('sortlabelalpha'), 'Doe95', 'maxalphanames=2 minalphanames=1 entry L1 labelalpha');
ok(is_undef($main->get_extraalphadata('l1')), 'maxalphanames=2 minalphanames=1 entry L1 extraalpha');
is($bibentries->entry('L2')->get_field('sortlabelalpha'), 'DA95', 'maxalphanames=2 minalphanames=1 entry L2 labelalpha');
is($main->get_extraalphadata('L2'), '1', 'maxalphanames=2 minalphanames=1 entry L2 extraalpha');
is($bibentries->entry('L3')->get_field('sortlabelalpha'), 'DA95', 'maxalphanames=2 minalphanames=1 entry L3 labelalpha');
is($main->get_extraalphadata('L3'), '2', 'maxalphanames=2 minalphanames=1 entry L3 extraalpha');
is($bibentries->entry('L4')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=2 minalphanames=1 entry L4 labelalpha');
is($main->get_extraalphadata('L4'), '1', 'maxalphanames=2 minalphanames=1 entry L4 extraalpha');
is($bibentries->entry('L5')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=2 minalphanames=1 entry L5 labelalpha');
is($main->get_extraalphadata('L5'), '2', 'maxalphanames=2 minalphanames=1 entry L5 extraalpha');
is($bibentries->entry('L6')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=2 minalphanames=1 entry L6 labelalpha');
is($main->get_extraalphadata('L6'), '3', 'maxalphanames=2 minalphanames=1 entry L6 extraalpha');
is($bibentries->entry('L7')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=2 minalphanames=1 entry L7 labelalpha');
is($main->get_extraalphadata('L7'), '4', 'maxalphanames=2 minalphanames=1 entry L7 extraalpha');
is($bibentries->entry('L8')->get_field('sortlabelalpha'), 'Sha85', 'maxalphanames=2 minalphanames=1 entry L8 labelalpha');
ok(is_undef($main->get_extraalphadata('L8')), 'maxalphanames=2 minalphanames=1 entry L8 extraalpha');

# reset options and regenerate information
Biber::Config->setblxoption('maxalphanames', 2);
Biber::Config->setblxoption('minalphanames', 2);
Biber::Config->setblxoption('maxcitenames', 2);
Biber::Config->setblxoption('mincitenames', 2);

foreach my $k ($section->get_citekeys) {
  $bibentries->entry($k)->del_field('sortlabelalpha');
  $bibentries->entry($k)->del_field('labelalpha');
  $main->set_extraalphadata_for_key($k, undef);
}

$biber->prepare;
$section = $biber->sections->get_section(0);
$main = $biber->sortlists->get_list(0, 'entry', 'MAIN');
$bibentries = $section->bibentries;

is($bibentries->entry('L1')->get_field('sortlabelalpha'), 'Doe95', 'maxalphanames=2 minalphanames=2 entry L1 labelalpha');
ok(is_undef($main->get_extraalphadata('l1')), 'maxalphanames=2 minalphanames=2 entry L1 extraalpha');
is($bibentries->entry('L2')->get_field('sortlabelalpha'), 'DA95', 'maxalphanames=2 minalphanames=2 entry L2 labelalpha');
is($main->get_extraalphadata('L2'), '1', 'maxalphanames=2 minalphanames=2 entry L2 extraalpha');
is($bibentries->entry('L3')->get_field('sortlabelalpha'), 'DA95', 'maxalphanames=2 minalphanames=2 entry L3 labelalpha');
is($main->get_extraalphadata('L3'), '2', 'maxalphanames=2 minalphanames=2 entry L3 extraalpha');
is($bibentries->entry('L4')->get_field('sortlabelalpha'), 'DA+95', 'maxalphanames=2 minalphanames=2 entry L4 labelalpha');
is($main->get_extraalphadata('L4'), '1', 'maxalphanames=2 minalphanames=2 entry L4 extraalpha');
is($bibentries->entry('L5')->get_field('sortlabelalpha'), 'DA+95', 'maxalphanames=2 minalphanames=2 entry L5 labelalpha');
is($main->get_extraalphadata('L5'), '2', 'maxalphanames=2 minalphanames=2 entry L5 extraalpha');
is($bibentries->entry('L6')->get_field('sortlabelalpha'), 'DS+95', 'maxalphanames=2 minalphanames=2 entry L6 labelalpha');
is($main->get_extraalphadata('L6'), '1', 'maxalphanames=2 minalphanames=2 entry L6 extraalpha');
is($bibentries->entry('L7')->get_field('sortlabelalpha'), 'DS+95', 'maxalphanames=2 minalphanames=2 entry L7 labelalpha');
is($main->get_extraalphadata('L7'), '2', 'maxalphanames=2 minalphanames=2 entry L7 extraalpha');
is($bibentries->entry('L8')->get_field('sortlabelalpha'), 'Sha85', 'maxalphanames=2 minalphanames=2 entry L8 labelalpha');
ok(is_undef($main->get_extraalphadata('L8')), 'maxalphanames=2 minalphanames=2 entry L8 extraalpha');

# reset options and regenerate information
Biber::Config->setblxoption('maxalphanames', 3);
Biber::Config->setblxoption('minalphanames', 1);
Biber::Config->setblxoption('maxcitenames', 3);
Biber::Config->setblxoption('mincitenames', 1);

foreach my $k ($section->get_citekeys) {
  $bibentries->entry($k)->del_field('sortlabelalpha');
  $bibentries->entry($k)->del_field('labelalpha');
  $main->set_extraalphadata_for_key($k, undef);
}

$biber->prepare;
$section = $biber->sections->get_section(0);
$main = $biber->sortlists->get_list(0, 'entry', 'MAIN');
$bibentries = $section->bibentries;

is($bibentries->entry('L1')->get_field('sortlabelalpha'), 'Doe95', 'maxalphanames=3 minalphanames=1 entry L1 labelalpha');
ok(is_undef($main->get_extraalphadata('L1')), 'maxalphanames=3 minalphanames=1 entry L1 extraalpha');
is($bibentries->entry('L2')->get_field('sortlabelalpha'), 'DA95', 'maxalphanames=3 minalphanames=1 entry L2 labelalpha');
is($main->get_extraalphadata('L2'), '1', 'maxalphanames=3 minalphanames=1 entry L2 extraalpha');
is($bibentries->entry('L3')->get_field('sortlabelalpha'), 'DA95', 'maxalphanames=3 minalphanames=1 entry L3 labelalpha');
is($main->get_extraalphadata('L3'), '2', 'maxalphanames=3 minalphanames=1 entry L3 extraalpha');
is($bibentries->entry('L4')->get_field('sortlabelalpha'), 'DAE95', 'maxalphanames=3 minalphanames=1 entry L4 labelalpha');
is($main->get_extraalphadata('L4'), '1', 'maxalphanames=3 minalphanames=1 entry L4 extraalpha');
is($bibentries->entry('L5')->get_field('sortlabelalpha'), 'DAE95', 'maxalphanames=3 minalphanames=1 entry L5 labelalpha');
is($main->get_extraalphadata('L5'), '2', 'maxalphanames=3 minalphanames=1 entry L5 extraalpha');
is($bibentries->entry('L6')->get_field('sortlabelalpha'), 'DSE95', 'maxalphanames=3 minalphanames=1 entry L6 labelalpha');
ok(is_undef($main->get_extraalphadata('L6')), 'maxalphanames=3 minalphanames=1 entry L6 extraalpha');
is($bibentries->entry('L7')->get_field('sortlabelalpha'), 'DSJ95', 'maxalphanames=3 minalphanames=1 entry L7 labelalpha');
ok(is_undef($main->get_extraalphadata('L7')), 'maxalphanames=3 minalphanames=1 entry L7 extraalpha');
is($bibentries->entry('L8')->get_field('sortlabelalpha'), 'Sha85', 'maxalphanames=3 minalphanames=1 entry L8 labelalpha');
ok(is_undef($main->get_extraalphadata('L8')), 'maxalphanames=3 minalphanames=1 entry L8 extraalpha');
is($bibentries->entry('LDN1')->get_field('sortlabelalpha'), 'VUR89', 'Testing compound lastnames 1');
is($bibentries->entry('LDN2')->get_field('sortlabelalpha'), 'VU45', 'Testing compound lastnames 2');

# reset options and regenerate information
Biber::Config->setblxoption('maxalphanames', 4);
Biber::Config->setblxoption('minalphanames', 4);
Biber::Config->setblxoption('maxcitenames', 4);
Biber::Config->setblxoption('mincitenames', 4);
Biber::Config->setblxoption('labelalpha', 1);
Biber::Config->setblxoption('labelyear', 1);

foreach my $k ($section->get_citekeys) {
  $bibentries->entry($k)->del_field('sortlabelalpha');
  $bibentries->entry($k)->del_field('labelalpha');
  $main->set_extraalphadata_for_key($k, undef);
}

$biber->prepare;
my $out = $biber->get_output_obj;
$section = $biber->sections->get_section(0);
$main = $biber->sortlists->get_list(0, 'entry', 'MAIN');
$bibentries = $section->bibentries;

is($bibentries->entry('L11')->get_field('sortlabelalpha'), 'vRan22', 'prefix labelalpha 1');
is($bibentries->entry('L12')->get_field('sortlabelalpha'), 'vRvB2', 'prefix labelalpha 2');
# only the first name in the list is in the label due to namecount=1
is($bibentries->entry('L13')->get_field('sortlabelalpha'), 'vRa+-ksUnV', 'per-type labelalpha 1');
is($bibentries->entry('L14')->get_field('sortlabelalpha'), 'Alabel-ksUnW', 'per-type labelalpha 2');
is($bibentries->entry('L15')->get_field('sortlabelalpha'), 'AccBrClim', 'labelalpha disambiguation 1');
is($bibentries->entry('L16')->get_field('sortlabelalpha'), 'AccBaClim', 'labelalpha disambiguation 2');
is($bibentries->entry('L16a')->get_field('sortlabelalpha'), 'AccBaClim', 'labelalpha disambiguation 2a');
is($main->get_extraalphadata('L16'), '1', 'labelalpha disambiguation 2c');
is($main->get_extraalphadata('L16a'), '2', 'labelalpha disambiguation 2d');
is($bibentries->entry('L17')->get_field('sortlabelalpha'), 'AckBaClim', 'labelalpha disambiguation 3');
is($main->get_extraalphadata('L17a'), '2', 'custom labelalpha extrayear 1');
is($bibentries->entry('L18')->get_field('sortlabelalpha'), 'AgChLa', 'labelalpha disambiguation 4');
is($bibentries->entry('L19')->get_field('sortlabelalpha'), 'AgConLe', 'labelalpha disambiguation 5');
is($bibentries->entry('L20')->get_field('sortlabelalpha'), 'AgCouLa', 'labelalpha disambiguation 6');
is($bibentries->entry('L21')->get_field('sortlabelalpha'), 'BoConEdb', 'labelalpha disambiguation 7');
is($bibentries->entry('L22')->get_field('sortlabelalpha'), 'BoConEm', 'labelalpha disambiguation 8');

# reset options and regenerate information
Biber::Config->setblxoption('labelalphatemplate', {
  labelelement => [
             {
               labelpart => [
                 {
                  content         => "labelname",
                  substring_width => "vf",
                  substring_fixed_threshold => 2,
                  substring_side => "left"
                 },
               ],
               order => 1,
             },
           ],
  type  => "unpublished",
}, 'PER_TYPE', 'unpublished');


foreach my $k ($section->get_citekeys) {
  $bibentries->entry($k)->del_field('sortlabelalpha');
  $bibentries->entry($k)->del_field('labelalpha');
  $main->set_extraalphadata_for_key($k, undef);
}

$biber->prepare;
$section = $biber->sections->get_section(0);
$main = $biber->sortlists->get_list(0, 'entry', 'MAIN');
$bibentries = $section->bibentries;

# "Agas" and not "Aga" because the Schmidt/Schnee below need 4 chars to disambiguate
is($bibentries->entry('L18')->get_field('sortlabelalpha'), 'AgasChaLaver', 'labelalpha disambiguation 4');
is($bibentries->entry('L19')->get_field('sortlabelalpha'), 'AgasConLendl', 'labelalpha disambiguation 5');
is($bibentries->entry('L20')->get_field('sortlabelalpha'), 'AgasCouLaver', 'labelalpha disambiguation 6');

# reset options and regenerate information
Biber::Config->setblxoption('labelalphatemplate', {
  labelelement => [
             {
               labelpart => [
                 {
                  content         => "labelname",
                  substring_width => "l",
                  substring_side => "left"
                 },
               ],
               order => 1,
             },
           ],
  type  => "unpublished",
}, 'PER_TYPE', 'unpublished');

foreach my $k ($section->get_citekeys) {
  $bibentries->entry($k)->del_field('sortlabelalpha');
  $bibentries->entry($k)->del_field('labelalpha');
  $main->set_extraalphadata_for_key($k, undef);
}

$biber->prepare;
$section = $biber->sections->get_section(0);
$main = $biber->sortlists->get_list(0, 'entry', 'MAIN');
$bibentries = $section->bibentries;


is($bibentries->entry('L21')->get_field('sortlabelalpha'), 'BCEd', 'labelalpha disambiguation 7');
is($bibentries->entry('L22')->get_field('sortlabelalpha'), 'BCEm', 'labelalpha disambiguation 8');

# reset options and regenerate information
Biber::Config->setblxoption('maxalphanames', 3);
Biber::Config->setblxoption('minalphanames', 1);
Biber::Config->setblxoption('maxcitenames', 3);
Biber::Config->setblxoption('mincitenames', 1);

Biber::Config->setblxoption('labelalphatemplate', {
  labelelement => [
             {
               labelpart => [
                 { content => "shorthand", final => 1 },
                 { content => "label" },
                 {
                   content         => "labelname",
                   ifnamecount     => 1,
                   substring_side  => "left",
                   substring_width => 3,
                 },
                 { content => "labelname", substring_side => "left", substring_width => 1 },
               ],
               order => 1,
             },
             {
               labelpart => [
                 { content => "year", substring_side => "right", substring_width => 2 },
               ],
               order => 2,
             },
           ],
  type  => "global",
});

foreach my $k ($section->get_citekeys) {
  $bibentries->entry($k)->del_field('sortlabelalpha');
  $bibentries->entry($k)->del_field('labelalpha');
  $main->set_extraalphadata_for_key($k, undef);
}

$biber->prepare;
$section = $biber->sections->get_section(0);
$main = $biber->sortlists->get_list(0, 'entry', 'MAIN');
$bibentries = $section->bibentries;

is($bibentries->entry('Schmidt2007')->get_field('sortlabelalpha'), 'Sch+07', 'extraalpha ne extrayear 1');
is($main->get_extraalphadata('Schmidt2007'), '1', 'extraalpha ne extrayear 2');
is($bibentries->entry('Schmidt2007a')->get_field('sortlabelalpha'), 'Sch07', 'extraalpha ne extrayear 3');
is($main->get_extraalphadata('Schmidt2007a'), '1', 'extraalpha ne extrayear 4');

is($bibentries->entry('Schnee2007')->get_field('sortlabelalpha'), 'Sch+07', 'extraalpha ne extrayear 5');
is($main->get_extraalphadata('Schnee2007'), '2', 'extraalpha ne extrayear 6');
is($bibentries->entry('Schnee2007a')->get_field('sortlabelalpha'), 'Sch07', 'extraalpha ne extrayear 7');
is($main->get_extraalphadata('Schnee2007a'), '2', 'extraalpha ne extrayear 8');



