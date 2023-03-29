# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 122;
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

$biber->parse_ctrlfile('labelalpha.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');

# Biblatex options
Biber::Config->setblxoption(undef,'maxalphanames', 1);
Biber::Config->setblxoption(undef,'maxcitenames', 1);
Biber::Config->setblxoption(undef,'labeldateparts', 0);

# Now generate the information, saving per-entry options or they are deleted
$biber->prepare;

my $section = $biber->sections->get_section(0);
my $main = $biber->datalists->get_list('custom/global//global/global/global');
my $bibentries = $section->bibentries;

# Test with useprefix=false
eq_or_diff($main->get_entryfield('prefix1', 'sortlabelalpha'), 'Vaa99', 'useprefix=0 so not in label');

# useprefix=true
Biber::Config->setblxoption(undef,'useprefix', 1);
$biber->prepare;

eq_or_diff($main->get_entryfield('prefix1', 'sortlabelalpha'), 'vdVaa99', 'Default prefix settings entry prefix1 labelalpha');
eq_or_diff($main->get_entryfield('L1', 'sortlabelalpha'), 'Doe95', 'maxalphanames=1 minalphanames=1 entry L1 labelalpha');
ok(is_undef($main->get_extraalphadata_for_key('l1')), 'maxalphanames=1 minalphanames=1 entry L1 extraalpha');
eq_or_diff($main->get_entryfield('L2', 'sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L2 labelalpha');
eq_or_diff($main->get_extraalphadata_for_key('L2'), '1', 'maxalphanames=1 minalphanames=1 entry L2 extraalpha');
eq_or_diff($main->get_entryfield('L3', 'sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L3 labelalpha');
eq_or_diff($main->get_extraalphadata_for_key('L3'), '2', 'maxalphanames=1 minalphanames=1 entry L3 extraalpha');
eq_or_diff($main->get_entryfield('L4', 'sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L4 labelalpha');
eq_or_diff($main->get_extraalphadata_for_key('L4'), '3', 'maxalphanames=1 minalphanames=1 entry L4 extraalpha');
eq_or_diff($main->get_entryfield('L5', 'sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L5 labelalpha');
eq_or_diff($main->get_extraalphadata_for_key('L5'), '4', 'maxalphanames=1 minalphanames=1 entry L5 extraalpha');
eq_or_diff($main->get_entryfield('L6', 'sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L6 labelalpha');
eq_or_diff($main->get_extraalphadata_for_key('L6'), '5', 'maxalphanames=1 minalphanames=1 entry L6 extraalpha');
eq_or_diff($main->get_entryfield('L7', 'sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L7 labelalpha');
eq_or_diff($main->get_extraalphadata_for_key('L7'), '6', 'maxalphanames=1 minalphanames=1 entry L7 extraalpha');
eq_or_diff($main->get_entryfield('L8', 'sortlabelalpha'), 'Sha85', 'maxalphanames=1 minalphanames=1 entry L8 labelalpha');
ok(is_undef($main->get_extraalphadata_for_key('L8')), 'maxalphanames=1 minalphanames=1 entry L8 extraalpha');
ok(is_undef($main->get_extraalphadata_for_key('L9')), 'L9 extraalpha unset due to shorthand');
ok(is_undef($main->get_extraalphadata_for_key('L10')), 'L10 extraalpha unset due to shorthand');
eq_or_diff($main->get_extraalphadata_for_key('knuth:ct'), '1', 'YEAR with range needs label differentiating from individual volumes - 1');
eq_or_diff($main->get_extraalphadata_for_key('knuth:ct:a'), '2', 'YEAR with range needs label differentiating from individual volumes - 2');
eq_or_diff($main->get_extraalphadata_for_key('knuth:ct:b'), '1', 'YEAR with range needs label differentiating from individual volumes - 3');
eq_or_diff($main->get_extraalphadata_for_key('knuth:ct:c'), '2', 'YEAR with range needs label differentiating from individual volumes - 4');
eq_or_diff($main->get_entryfield('ignore1', 'sortlabelalpha'), 'OTo07', 'Default ignore');
eq_or_diff($main->get_entryfield('ignore2', 'sortlabelalpha'), 'De 07', 'Default no ignore spaces');

# reset options and regenerate information
Biber::Config->setblxoption(undef,'maxalphanames', 2);
Biber::Config->setblxoption(undef,'minalphanames', 1);
Biber::Config->setblxoption(undef,'maxcitenames', 2);
Biber::Config->setblxoption(undef,'mincitenames', 1);

foreach my $k ($section->get_citekeys) {
  $bibentries->entry($k)->del_field('sortlabelalpha');
  $bibentries->entry($k)->del_field('labelalpha');
  $main->set_extraalphadata_for_key($k, undef);
}

$biber->prepare;

$section = $biber->sections->get_section(0);
$main = $biber->datalists->get_list('custom/global//global/global/global');
$bibentries = $section->bibentries;

eq_or_diff($main->get_entryfield('L1', 'sortlabelalpha'), 'Doe95', 'maxalphanames=2 minalphanames=1 entry L1 labelalpha');
ok(is_undef($main->get_extraalphadata_for_key('l1')), 'maxalphanames=2 minalphanames=1 entry L1 extraalpha');
eq_or_diff($main->get_entryfield('L2', 'sortlabelalpha'), 'DA95', 'maxalphanames=2 minalphanames=1 entry L2 labelalpha');
eq_or_diff($main->get_extraalphadata_for_key('L2'), '1', 'maxalphanames=2 minalphanames=1 entry L2 extraalpha');
eq_or_diff($main->get_entryfield('L3', 'sortlabelalpha'), 'DA95', 'maxalphanames=2 minalphanames=1 entry L3 labelalpha');
eq_or_diff($main->get_extraalphadata_for_key('L3'), '2', 'maxalphanames=2 minalphanames=1 entry L3 extraalpha');
eq_or_diff($main->get_entryfield('L4', 'sortlabelalpha'), 'Doe+95', 'maxalphanames=2 minalphanames=1 entry L4 labelalpha');
eq_or_diff($main->get_extraalphadata_for_key('L4'), '1', 'maxalphanames=2 minalphanames=1 entry L4 extraalpha');
eq_or_diff($main->get_entryfield('L5', 'sortlabelalpha'), 'Doe+95', 'maxalphanames=2 minalphanames=1 entry L5 labelalpha');
eq_or_diff($main->get_extraalphadata_for_key('L5'), '2', 'maxalphanames=2 minalphanames=1 entry L5 extraalpha');
eq_or_diff($main->get_entryfield('L6', 'sortlabelalpha'), 'Doe+95', 'maxalphanames=2 minalphanames=1 entry L6 labelalpha');
eq_or_diff($main->get_extraalphadata_for_key('L6'), '3', 'maxalphanames=2 minalphanames=1 entry L6 extraalpha');
eq_or_diff($main->get_entryfield('L7', 'sortlabelalpha'), 'Doe+95', 'maxalphanames=2 minalphanames=1 entry L7 labelalpha');
eq_or_diff($main->get_extraalphadata_for_key('L7'), '4', 'maxalphanames=2 minalphanames=1 entry L7 extraalpha');
eq_or_diff($main->get_entryfield('L8', 'sortlabelalpha'), 'Sha85', 'maxalphanames=2 minalphanames=1 entry L8 labelalpha');
ok(is_undef($main->get_extraalphadata_for_key('L8')), 'maxalphanames=2 minalphanames=1 entry L8 extraalpha');

# reset options and regenerate information
Biber::Config->setblxoption(undef,'maxalphanames', 2);
Biber::Config->setblxoption(undef,'minalphanames', 2);
Biber::Config->setblxoption(undef,'maxcitenames', 2);
Biber::Config->setblxoption(undef,'mincitenames', 2);

foreach my $k ($section->get_citekeys) {
  $bibentries->entry($k)->del_field('sortlabelalpha');
  $bibentries->entry($k)->del_field('labelalpha');
  $main->set_extraalphadata_for_key($k, undef);
}

$biber->prepare;

$section = $biber->sections->get_section(0);
$main = $biber->datalists->get_list('custom/global//global/global/global');
$bibentries = $section->bibentries;

eq_or_diff($main->get_entryfield('L1', 'sortlabelalpha'), 'Doe95', 'maxalphanames=2 minalphanames=2 entry L1 labelalpha');
ok(is_undef($main->get_extraalphadata_for_key('l1')), 'maxalphanames=2 minalphanames=2 entry L1 extraalpha');
eq_or_diff($main->get_entryfield('L2', 'sortlabelalpha'), 'DA95', 'maxalphanames=2 minalphanames=2 entry L2 labelalpha');
eq_or_diff($main->get_extraalphadata_for_key('L2'), '1', 'maxalphanames=2 minalphanames=2 entry L2 extraalpha');
eq_or_diff($main->get_entryfield('L3', 'sortlabelalpha'), 'DA95', 'maxalphanames=2 minalphanames=2 entry L3 labelalpha');
eq_or_diff($main->get_extraalphadata_for_key('L3'), '2', 'maxalphanames=2 minalphanames=2 entry L3 extraalpha');
eq_or_diff($main->get_entryfield('L4', 'sortlabelalpha'), 'DA+95', 'maxalphanames=2 minalphanames=2 entry L4 labelalpha');
eq_or_diff($main->get_extraalphadata_for_key('L4'), '1', 'maxalphanames=2 minalphanames=2 entry L4 extraalpha');
eq_or_diff($main->get_entryfield('L5', 'sortlabelalpha'), 'DA+95', 'maxalphanames=2 minalphanames=2 entry L5 labelalpha');
eq_or_diff($main->get_extraalphadata_for_key('L5'), '2', 'maxalphanames=2 minalphanames=2 entry L5 extraalpha');
eq_or_diff($main->get_entryfield('L6', 'sortlabelalpha'), 'DS+95', 'maxalphanames=2 minalphanames=2 entry L6 labelalpha');
eq_or_diff($main->get_extraalphadata_for_key('L6'), '1', 'maxalphanames=2 minalphanames=2 entry L6 extraalpha');
eq_or_diff($main->get_entryfield('L7', 'sortlabelalpha'), 'DS+95', 'maxalphanames=2 minalphanames=2 entry L7 labelalpha');
eq_or_diff($main->get_extraalphadata_for_key('L7'), '2', 'maxalphanames=2 minalphanames=2 entry L7 extraalpha');
eq_or_diff($main->get_entryfield('L8', 'sortlabelalpha'), 'Sha85', 'maxalphanames=2 minalphanames=2 entry L8 labelalpha');
ok(is_undef($main->get_extraalphadata_for_key('L8')), 'maxalphanames=2 minalphanames=2 entry L8 extraalpha');

# reset options and regenerate information
Biber::Config->setblxoption(undef,'maxalphanames', 3);
Biber::Config->setblxoption(undef,'minalphanames', 1);
Biber::Config->setblxoption(undef,'maxcitenames', 3);
Biber::Config->setblxoption(undef,'mincitenames', 1);

foreach my $k ($section->get_citekeys) {
  $bibentries->entry($k)->del_field('sortlabelalpha');
  $bibentries->entry($k)->del_field('labelalpha');
  $main->set_extraalphadata_for_key($k, undef);
}

$biber->prepare;

$section = $biber->sections->get_section(0);
$main = $biber->datalists->get_list('custom/global//global/global/global');
$bibentries = $section->bibentries;

eq_or_diff($main->get_entryfield('L1', 'sortlabelalpha'), 'Doe95', 'maxalphanames=3 minalphanames=1 entry L1 labelalpha');
ok(is_undef($main->get_extraalphadata_for_key('L1')), 'maxalphanames=3 minalphanames=1 entry L1 extraalpha');
eq_or_diff($main->get_entryfield('L2', 'sortlabelalpha'), 'DA95', 'maxalphanames=3 minalphanames=1 entry L2 labelalpha');
eq_or_diff($main->get_extraalphadata_for_key('L2'), '1', 'maxalphanames=3 minalphanames=1 entry L2 extraalpha');
eq_or_diff($main->get_entryfield('L3', 'sortlabelalpha'), 'DA95', 'maxalphanames=3 minalphanames=1 entry L3 labelalpha');
eq_or_diff($main->get_extraalphadata_for_key('L3'), '2', 'maxalphanames=3 minalphanames=1 entry L3 extraalpha');
eq_or_diff($main->get_entryfield('L4', 'sortlabelalpha'), 'DAE95', 'maxalphanames=3 minalphanames=1 entry L4 labelalpha');
eq_or_diff($main->get_extraalphadata_for_key('L4'), '1', 'maxalphanames=3 minalphanames=1 entry L4 extraalpha');
eq_or_diff($main->get_entryfield('L5', 'sortlabelalpha'), 'DAE95', 'maxalphanames=3 minalphanames=1 entry L5 labelalpha');
eq_or_diff($main->get_extraalphadata_for_key('L5'), '2', 'maxalphanames=3 minalphanames=1 entry L5 extraalpha');
eq_or_diff($main->get_entryfield('L6', 'sortlabelalpha'), 'DSE95', 'maxalphanames=3 minalphanames=1 entry L6 labelalpha');
ok(is_undef($main->get_extraalphadata_for_key('L6')), 'maxalphanames=3 minalphanames=1 entry L6 extraalpha');
eq_or_diff($main->get_entryfield('L7', 'sortlabelalpha'), 'DSJ95', 'maxalphanames=3 minalphanames=1 entry L7 labelalpha');
ok(is_undef($main->get_extraalphadata_for_key('L7')), 'maxalphanames=3 minalphanames=1 entry L7 extraalpha');
eq_or_diff($main->get_entryfield('L8', 'sortlabelalpha'), 'Sha85', 'maxalphanames=3 minalphanames=1 entry L8 labelalpha');
ok(is_undef($main->get_extraalphadata_for_key('L8')), 'maxalphanames=3 minalphanames=1 entry L8 extraalpha');
eq_or_diff($main->get_entryfield('LDN1', 'sortlabelalpha'), 'VUR89', 'Testing compound lastnames 1');
eq_or_diff($main->get_entryfield('LDN2', 'sortlabelalpha'), 'VU45', 'Testing compound lastnames 2');
eq_or_diff($main->get_entryfield('LDN3', 'sortlabelalpha'), 'VisvSJRu45', 'Testing with multiple pre and main and width/side override');

# reset options and regenerate information
Biber::Config->setblxoption(undef,'maxalphanames', 4);
Biber::Config->setblxoption(undef,'minalphanames', 4);
Biber::Config->setblxoption(undef,'maxcitenames', 4);
Biber::Config->setblxoption(undef,'mincitenames', 4);
Biber::Config->setblxoption(undef,'labelalpha', 1);
Biber::Config->setblxoption(undef,'labeldateparts', 1);

foreach my $k ($section->get_citekeys) {
  $bibentries->entry($k)->del_field('sortlabelalpha');
  $bibentries->entry($k)->del_field('labelalpha');
  $main->set_extraalphadata_for_key($k, undef);
}

$biber->prepare;

my $out = $biber->get_output_obj;
$section = $biber->sections->get_section(0);
$main = $biber->datalists->get_list('custom/global//global/global/global');
$bibentries = $section->bibentries;

eq_or_diff($main->get_entryfield('L11', 'sortlabelalpha'), 'vRan22', 'prefix labelalpha 1');
eq_or_diff($main->get_entryfield('L12', 'sortlabelalpha'), 'vRvB2', 'prefix labelalpha 2');
# only the first name in the list is in the label due to namecount=1
eq_or_diff($main->get_entryfield('L13', 'sortlabelalpha'), 'vRa+-ksUnV', 'per-type labelalpha 1');
eq_or_diff($main->get_entryfield('L14', 'sortlabelalpha'), 'Alabel-ksUnW', 'per-type labelalpha 2');
eq_or_diff($main->get_entryfield('L15', 'sortlabelalpha'), 'AccBrClim', 'labelalpha disambiguation 1');
eq_or_diff($main->get_entryfield('L16', 'sortlabelalpha'), 'AccBaClim', 'labelalpha disambiguation 2');
eq_or_diff($main->get_entryfield('L16a', 'sortlabelalpha'), 'AccBaClim', 'labelalpha disambiguation 2a');
eq_or_diff($main->get_extraalphadata_for_key('L16'), '1', 'labelalpha disambiguation 2c');
eq_or_diff($main->get_extraalphadata_for_key('L16a'), '2', 'labelalpha disambiguation 2d');
eq_or_diff($main->get_entryfield('L17', 'sortlabelalpha'), 'AckBaClim', 'labelalpha disambiguation 3');
eq_or_diff($main->get_extraalphadata_for_key('L17a'), '2', 'custom labelalpha extradate 1');
eq_or_diff($main->get_entryfield('L18', 'sortlabelalpha'), 'AgChLa', 'labelalpha disambiguation 4');
eq_or_diff($main->get_entryfield('L19', 'sortlabelalpha'), 'AgConLe', 'labelalpha disambiguation 5');
eq_or_diff($main->get_entryfield('L20', 'sortlabelalpha'), 'AgCouLa', 'labelalpha disambiguation 6');
eq_or_diff($main->get_entryfield('L21', 'sortlabelalpha'), 'BoConEdb', 'labelalpha disambiguation 7');
eq_or_diff($main->get_entryfield('L22', 'sortlabelalpha'), 'BoConEm', 'labelalpha disambiguation 8');
eq_or_diff($main->get_entryfield('L23', 'sortlabelalpha'), 'Sa', 'labelalpha disambiguation 9');

# reset options and regenerate information
Biber::Config->setblxoption(undef,'labelalphatemplate', {
  labelelement => [
             {
               labelpart => [
                 {
                  content         => "labelname",
                  substring_width => "vf",
                  namessep => "/",
                  substring_fixed_threshold => 2,
                  substring_side => "left"
                 },
               ],
               order => 1,
             },
           ],
  type  => "unpublished",
}, 'ENTRYTYPE', 'unpublished');


foreach my $k ($section->get_citekeys) {
  $bibentries->entry($k)->del_field('sortlabelalpha');
  $bibentries->entry($k)->del_field('labelalpha');
  $main->set_extraalphadata_for_key($k, undef);
}

$biber->prepare;

$section = $biber->sections->get_section(0);
$main = $biber->datalists->get_list('custom/global//global/global/global');
$bibentries = $section->bibentries;

# "Agas" and not "Aga" because the Schmidt/Schnee below need 4 chars to disambiguate
eq_or_diff($main->get_entryfield('L18', 'sortlabelalpha'), 'Agas/Cha/Laver', 'labelalpha disambiguation 10');
eq_or_diff($main->get_entryfield('L19', 'sortlabelalpha'), 'Agas/Con/Lendl', 'labelalpha disambiguation 11');
eq_or_diff($main->get_entryfield('L20', 'sortlabelalpha'), 'Agas/Cou/Laver', 'labelalpha disambiguation 12');

# reset options and regenerate information
Biber::Config->setblxoption(undef,'labelalphatemplate', {
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
}, 'ENTRYTYPE', 'unpublished');

foreach my $k ($section->get_citekeys) {
  $bibentries->entry($k)->del_field('sortlabelalpha');
  $bibentries->entry($k)->del_field('labelalpha');
  $main->set_extraalphadata_for_key($k, undef);
}

$biber->prepare;

$section = $biber->sections->get_section(0);
$main = $biber->datalists->get_list('custom/global//global/global/global');
$bibentries = $section->bibentries;

eq_or_diff($main->get_entryfield('L18', 'sortlabelalpha'), 'AChL', 'labelalpha list disambiguation 1');
eq_or_diff($main->get_entryfield('L19', 'sortlabelalpha'), 'ACoL', 'labelalpha list disambiguation 2');
eq_or_diff($main->get_entryfield('L20', 'sortlabelalpha'), 'ACL', 'labelalpha list disambiguation 3');
eq_or_diff($main->get_entryfield('L21', 'sortlabelalpha'), 'BCEd', 'labelalpha list disambiguation 4');
eq_or_diff($main->get_entryfield('L22', 'sortlabelalpha'), 'BCE', 'labelalpha list disambiguation 5');
eq_or_diff($main->get_entryfield('L24', 'sortlabelalpha'), 'Z', 'labelalpha list disambiguation 6');
eq_or_diff($main->get_entryfield('L25', 'sortlabelalpha'), 'ZX', 'labelalpha list disambiguation 7');
eq_or_diff($main->get_entryfield('L26', 'sortlabelalpha'), 'ZX', 'labelalpha list disambiguation 8');
eq_or_diff(NFC($main->get_entryfield('title1', 'sortlabelalpha')), 'Tït', 'Title in braces with UTF-8 char - 1');

# reset options and regenerate information
Biber::Config->setblxoption(undef,'maxalphanames', 3);
Biber::Config->setblxoption(undef,'minalphanames', 1);
Biber::Config->setblxoption(undef,'maxcitenames', 3);
Biber::Config->setblxoption(undef,'mincitenames', 1);

Biber::Config->setblxoption(undef,'labelalphatemplate', {
  labelelement => [
             {
               labelpart => [
                 { content => "shorthand", final => 1 },
                 { content => "label" },
                 {
                   content         => "labelname",
                   ifnames     => 1,
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
$main = $biber->datalists->get_list('custom/global//global/global/global');
$bibentries = $section->bibentries;

eq_or_diff($main->get_entryfield('Schmidt2007', 'sortlabelalpha'), 'Sch+07', 'extraalpha ne extradate 1');
eq_or_diff($main->get_extraalphadata_for_key('Schmidt2007'), '1', 'extraalpha ne extradate 2');
eq_or_diff($main->get_entryfield('Schmidt2007a', 'sortlabelalpha'), 'Sch07', 'extraalpha ne extradate 3');
eq_or_diff($main->get_extraalphadata_for_key('Schmidt2007a'), '1', 'extraalpha ne extradate 4');

eq_or_diff($main->get_entryfield('Schnee2007', 'sortlabelalpha'), 'Sch+07', 'extraalpha ne extradate 5');
eq_or_diff($main->get_extraalphadata_for_key('Schnee2007'), '2', 'extraalpha ne extradate 6');
eq_or_diff($main->get_entryfield('Schnee2007a', 'sortlabelalpha'), 'Sch07', 'extraalpha ne extradate 7');
eq_or_diff($main->get_extraalphadata_for_key('Schnee2007a'), '2', 'extraalpha ne extradate 8');

Biber::Config->setblxoption(undef,'labelalphatemplate', {
  labelelement => [
             {
               labelpart => [
                 {
                   content         => "citekey",
                   substring_side  => "left",
                   substring_width => 3,
                   uppercase => 1,
                 },
               ],
               order => 1,
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
$main = $biber->datalists->get_list('custom/global//global/global/global');
$bibentries = $section->bibentries;

eq_or_diff($main->get_entryfield('Schmidt2007', 'sortlabelalpha'), 'SCH', 'entrykey label 1');

Biber::Config->setblxoption(undef,'labelalphatemplate', {
  labelelement => [
             {
               labelpart => [
                 {
                  content         => "labelyear",
                 }
               ],
              order => 1,
             },
             {
               labelpart => [
                 {
                  content         => "labelmonth",
                 }
               ],
              order => 2,
             },
             {
               labelpart => [
                 {
                  content         => "labelday",
                 }
               ],
              order => 3,
             }
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
$main = $biber->datalists->get_list('custom/global//global/global/global');
$bibentries = $section->bibentries;

eq_or_diff($main->get_entryfield('labelstest', 'sortlabelalpha'), '200532', 'labeldate test - 1');
eq_or_diff($main->get_entryfield('padtest', 'labelalpha'), '\&Al\_\_{\textasciitilde}{\textasciitilde}T07', 'pad test - 1');
eq_or_diff($main->get_entryfield('padtest', 'sortlabelalpha'), '&Al__~~T07', 'pad test - 2');

my $lant = Biber::Config->getblxoption(undef,'labelalphanametemplate');
$lant->{global} = [
 {
    namepart => "prefix",
    pre => 1,
    substring_compound => 1,
    substring_width => 2,
    use => 1,
  },
  {
    namepart => "family",
    pre => undef,
    substring_compound => 1,
    substring_width => undef,
    use => undef,
  }];
Biber::Config->setblxoption(undef,'labelalphanametemplate', $lant);

Biber::Config->setblxoption(undef,'labelalphatemplate', {
  labelelement => [
                   {
                    labelpart => [
                                  {
                                   content         => "author",
                                   ifnames         => 1,
                                   substring_side  => "left",
                                   substring_width => 3,
                                  },
                                 ],
                    order => 1,
                   },
                   {
                    labelpart => [
                                  {
                                   content         => "title",
                                   substring_side  => "left",
                                   substring_width => 4,
                                  },
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
# The "o"s are ignored for width substring calculation - take note
Biber::Config->setoption('nolabelwidthcount', [ {value => q/o+/} ] );
$biber->prepare;

$section = $biber->sections->get_section(0);
$main = $biber->datalists->get_list('custom/global//global/global/global');
$bibentries = $section->bibentries;

eq_or_diff($main->get_entryfield('skipwidthtest1', 'sortlabelalpha'), 'OToolOToole', 'Skip width test - 1');
eq_or_diff($main->get_entryfield('prefix1', 'sortlabelalpha'), 'vadeVaaThin', 'compound and string length entry prefix1 labelalpha');

Biber::Config->setblxoption(undef,'labelalphatemplate', {
  labelelement => [
                   {
                    labelpart => [
                                  {
                   content         => "author",
                   names       => "2-7"
                                  },
                   ],
                   order => 1,
                   },
                   {
                    labelpart => [
                                  {
                   content         => ".",
                                  },
                   ],
                   order => 2,
                   },
                   {
                    labelpart => [
                                  {
                   content         => "editor",
                   names       => "--3"
                                  },
                   ],
                   order => 3,
                   },
                   {
                    labelpart => [
                                  {
                   content         => ".",
                                  },
                   ],
                   order => 4,
                   },
                   {
                    labelpart => [
                                  {
                   content         => "translator",
                   names       => "2",
                   noalphaothers   => "1"
                                  },
                   ],
                   order => 5,
                   },
                   {
                    labelpart => [
                                  {
                   content         => ".",
                                  },
                   ],
                   order => 6,
                   },
                   {
                    labelpart => [
                                  {
                   content         => "foreword",
                   names       => "3--"
                                  },
                   ],
                   order => 7,
                   },
                   {
                    labelpart => [
                                  {
                   content         => ".",
                                  },
                   ],
                   order => 8,
                   },
                   {
                    labelpart => [
                                  {
                   content         => "holder",
                   names       => "2-+"
                                  },
                   ],
                   order => 9,
                   },
                  ],
  type  => "global",
});
Biber::Config->setblxoption(undef,'minalphanames', 2);

foreach my $k ($section->get_citekeys) {
  $bibentries->entry($k)->del_field('sortlabelalpha');
  $bibentries->entry($k)->del_field('labelalpha');
  $main->set_extraalphadata_for_key($k, undef);
}
$biber->prepare;

$section = $biber->sections->get_section(0);
$main = $biber->datalists->get_list('custom/global//global/global/global');
$bibentries = $section->bibentries;

eq_or_diff($main->get_entryfield('rangetest1', 'sortlabelalpha'), 'WAXAYAZA.VEWEXE+.VTWT.XFYFZF.WH+', 'Name range test - 1');


Biber::Config->setblxoption(undef,'labelalphatemplate', {
  labelelement => [
                   {
                    labelpart => [
                                  {
                   content         => "author",
                   ifnames     => "3-",
                   substring_side  => "left",
                   substring_width => 1,
                                  },
                   ],
                   order => 1,
                   },
                   {
                    labelpart => [
                                  {
                   content         => ".",
                                  },
                   ],
                   order => 2,
                   },
                   {
                    labelpart => [
                                  {
                   content         => "editor",
                   ifnames     => "-2",
                   substring_side  => "left",
                   substring_width => 1,
                                  },
                   ],
                   order => 3,
                   },
                   {
                    labelpart => [
                                  {
                   content         => ".",
                                  },
                   ],
                   order => 4,
                   },
                   {
                    labelpart => [
                                  {
                   content         => "translator",
                   ifnames     => "4-6",
                   namessep     => "/",
                   substring_side  => "left",
                   substring_width => 1,
                                  },
                   ],
                   order => 5,
                   },

                  ],
  type  => "global",
});

Biber::Config->setblxoption(undef,'maxalphanames', 10);
Biber::Config->setblxoption(undef,'minalphanames', 10);

foreach my $k ($section->get_citekeys) {
  $bibentries->entry($k)->del_field('sortlabelalpha');
  $bibentries->entry($k)->del_field('labelalpha');
  $main->set_extraalphadata_for_key($k, undef);
}
$biber->prepare;

$section = $biber->sections->get_section(0);
$main = $biber->datalists->get_list('custom/global//global/global/global');
$bibentries = $section->bibentries;

eq_or_diff($main->get_entryfield('rangetest1', 'sortlabelalpha'), 'VWXYZ..V/W/X/Y/Z', 'Name range test - 2');

