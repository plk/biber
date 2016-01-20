# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 119;
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
Biber::Config->setoption('fastsort', 1);

# Biblatex options
Biber::Config->setblxoption('maxalphanames', 1);
Biber::Config->setblxoption('maxcitenames', 1);
Biber::Config->setblxoption('labeldate', undef);

# Now generate the information
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $main = $biber->sortlists->get_list(0, 'nty/global', 'entry', 'nty', 'global');
my $bibentries = $section->bibentries;


eq_or_diff($bibentries->entry('prefix1')->get_field('sortlabelalpha'), 'vVaa99', 'Default prefix settings entry prefix1 labelalpha');
eq_or_diff($bibentries->entry('L1')->get_field('sortlabelalpha'), 'Doe95', 'maxalphanames=1 minalphanames=1 entry L1 labelalpha');
ok(is_undef($main->get_extraalphadata('l1')), 'maxalphanames=1 minalphanames=1 entry L1 extraalpha');
eq_or_diff($bibentries->entry('L2')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L2 labelalpha');
eq_or_diff($main->get_extraalphadata('L2'), '1', 'maxalphanames=1 minalphanames=1 entry L2 extraalpha');
eq_or_diff($bibentries->entry('L3')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L3 labelalpha');
eq_or_diff($main->get_extraalphadata('L3'), '2', 'maxalphanames=1 minalphanames=1 entry L3 extraalpha');
eq_or_diff($bibentries->entry('L4')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L4 labelalpha');
eq_or_diff($main->get_extraalphadata('L4'), '3', 'maxalphanames=1 minalphanames=1 entry L4 extraalpha');
eq_or_diff($bibentries->entry('L5')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L5 labelalpha');
eq_or_diff($main->get_extraalphadata('L5'), '4', 'maxalphanames=1 minalphanames=1 entry L5 extraalpha');
eq_or_diff($bibentries->entry('L6')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L6 labelalpha');
eq_or_diff($main->get_extraalphadata('L6'), '5', 'maxalphanames=1 minalphanames=1 entry L6 extraalpha');
eq_or_diff($bibentries->entry('L7')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=1 minalphanames=1 entry L7 labelalpha');
eq_or_diff($main->get_extraalphadata('L7'), '6', 'maxalphanames=1 minalphanames=1 entry L7 extraalpha');
eq_or_diff($bibentries->entry('L8')->get_field('sortlabelalpha'), 'Sha85', 'maxalphanames=1 minalphanames=1 entry L8 labelalpha');
ok(is_undef($main->get_extraalphadata('L8')), 'maxalphanames=1 minalphanames=1 entry L8 extraalpha');
ok(is_undef($main->get_extraalphadata('L9')), 'L9 extraalpha unset due to shorthand');
ok(is_undef($main->get_extraalphadata('L10')), 'L10 extraalpha unset due to shorthand');
eq_or_diff($main->get_extraalphadata('knuth:ct'), '1', 'YEAR with range needs label differentiating from individual volumes - 1');
eq_or_diff($main->get_extraalphadata('knuth:ct:a'), '2', 'YEAR with range needs label differentiating from individual volumes - 2');
eq_or_diff($main->get_extraalphadata('knuth:ct:b'), '1', 'YEAR with range needs label differentiating from individual volumes - 3');
eq_or_diff($main->get_extraalphadata('knuth:ct:c'), '2', 'YEAR with range needs label differentiating from individual volumes - 4');
eq_or_diff($bibentries->entry('ignore1')->get_field('sortlabelalpha'), 'OTo07', 'Default ignore');
eq_or_diff($bibentries->entry('ignore2')->get_field('sortlabelalpha'), 'De 07', 'Default no ignore spaces');

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
$main = $biber->sortlists->get_list(0, 'nty/global', 'entry', 'nty', 'global');
$bibentries = $section->bibentries;

eq_or_diff($bibentries->entry('L1')->get_field('sortlabelalpha'), 'Doe95', 'maxalphanames=2 minalphanames=1 entry L1 labelalpha');
ok(is_undef($main->get_extraalphadata('l1')), 'maxalphanames=2 minalphanames=1 entry L1 extraalpha');
eq_or_diff($bibentries->entry('L2')->get_field('sortlabelalpha'), 'DA95', 'maxalphanames=2 minalphanames=1 entry L2 labelalpha');
eq_or_diff($main->get_extraalphadata('L2'), '1', 'maxalphanames=2 minalphanames=1 entry L2 extraalpha');
eq_or_diff($bibentries->entry('L3')->get_field('sortlabelalpha'), 'DA95', 'maxalphanames=2 minalphanames=1 entry L3 labelalpha');
eq_or_diff($main->get_extraalphadata('L3'), '2', 'maxalphanames=2 minalphanames=1 entry L3 extraalpha');
eq_or_diff($bibentries->entry('L4')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=2 minalphanames=1 entry L4 labelalpha');
eq_or_diff($main->get_extraalphadata('L4'), '1', 'maxalphanames=2 minalphanames=1 entry L4 extraalpha');
eq_or_diff($bibentries->entry('L5')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=2 minalphanames=1 entry L5 labelalpha');
eq_or_diff($main->get_extraalphadata('L5'), '2', 'maxalphanames=2 minalphanames=1 entry L5 extraalpha');
eq_or_diff($bibentries->entry('L6')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=2 minalphanames=1 entry L6 labelalpha');
eq_or_diff($main->get_extraalphadata('L6'), '3', 'maxalphanames=2 minalphanames=1 entry L6 extraalpha');
eq_or_diff($bibentries->entry('L7')->get_field('sortlabelalpha'), 'Doe+95', 'maxalphanames=2 minalphanames=1 entry L7 labelalpha');
eq_or_diff($main->get_extraalphadata('L7'), '4', 'maxalphanames=2 minalphanames=1 entry L7 extraalpha');
eq_or_diff($bibentries->entry('L8')->get_field('sortlabelalpha'), 'Sha85', 'maxalphanames=2 minalphanames=1 entry L8 labelalpha');
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
$main = $biber->sortlists->get_list(0, 'nty/global', 'entry', 'nty', 'global');
$bibentries = $section->bibentries;

eq_or_diff($bibentries->entry('L1')->get_field('sortlabelalpha'), 'Doe95', 'maxalphanames=2 minalphanames=2 entry L1 labelalpha');
ok(is_undef($main->get_extraalphadata('l1')), 'maxalphanames=2 minalphanames=2 entry L1 extraalpha');
eq_or_diff($bibentries->entry('L2')->get_field('sortlabelalpha'), 'DA95', 'maxalphanames=2 minalphanames=2 entry L2 labelalpha');
eq_or_diff($main->get_extraalphadata('L2'), '1', 'maxalphanames=2 minalphanames=2 entry L2 extraalpha');
eq_or_diff($bibentries->entry('L3')->get_field('sortlabelalpha'), 'DA95', 'maxalphanames=2 minalphanames=2 entry L3 labelalpha');
eq_or_diff($main->get_extraalphadata('L3'), '2', 'maxalphanames=2 minalphanames=2 entry L3 extraalpha');
eq_or_diff($bibentries->entry('L4')->get_field('sortlabelalpha'), 'DA+95', 'maxalphanames=2 minalphanames=2 entry L4 labelalpha');
eq_or_diff($main->get_extraalphadata('L4'), '1', 'maxalphanames=2 minalphanames=2 entry L4 extraalpha');
eq_or_diff($bibentries->entry('L5')->get_field('sortlabelalpha'), 'DA+95', 'maxalphanames=2 minalphanames=2 entry L5 labelalpha');
eq_or_diff($main->get_extraalphadata('L5'), '2', 'maxalphanames=2 minalphanames=2 entry L5 extraalpha');
eq_or_diff($bibentries->entry('L6')->get_field('sortlabelalpha'), 'DS+95', 'maxalphanames=2 minalphanames=2 entry L6 labelalpha');
eq_or_diff($main->get_extraalphadata('L6'), '1', 'maxalphanames=2 minalphanames=2 entry L6 extraalpha');
eq_or_diff($bibentries->entry('L7')->get_field('sortlabelalpha'), 'DS+95', 'maxalphanames=2 minalphanames=2 entry L7 labelalpha');
eq_or_diff($main->get_extraalphadata('L7'), '2', 'maxalphanames=2 minalphanames=2 entry L7 extraalpha');
eq_or_diff($bibentries->entry('L8')->get_field('sortlabelalpha'), 'Sha85', 'maxalphanames=2 minalphanames=2 entry L8 labelalpha');
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
$main = $biber->sortlists->get_list(0, 'nty/global', 'entry', 'nty', 'global');
$bibentries = $section->bibentries;

eq_or_diff($bibentries->entry('L1')->get_field('sortlabelalpha'), 'Doe95', 'maxalphanames=3 minalphanames=1 entry L1 labelalpha');
ok(is_undef($main->get_extraalphadata('L1')), 'maxalphanames=3 minalphanames=1 entry L1 extraalpha');
eq_or_diff($bibentries->entry('L2')->get_field('sortlabelalpha'), 'DA95', 'maxalphanames=3 minalphanames=1 entry L2 labelalpha');
eq_or_diff($main->get_extraalphadata('L2'), '1', 'maxalphanames=3 minalphanames=1 entry L2 extraalpha');
eq_or_diff($bibentries->entry('L3')->get_field('sortlabelalpha'), 'DA95', 'maxalphanames=3 minalphanames=1 entry L3 labelalpha');
eq_or_diff($main->get_extraalphadata('L3'), '2', 'maxalphanames=3 minalphanames=1 entry L3 extraalpha');
eq_or_diff($bibentries->entry('L4')->get_field('sortlabelalpha'), 'DAE95', 'maxalphanames=3 minalphanames=1 entry L4 labelalpha');
eq_or_diff($main->get_extraalphadata('L4'), '1', 'maxalphanames=3 minalphanames=1 entry L4 extraalpha');
eq_or_diff($bibentries->entry('L5')->get_field('sortlabelalpha'), 'DAE95', 'maxalphanames=3 minalphanames=1 entry L5 labelalpha');
eq_or_diff($main->get_extraalphadata('L5'), '2', 'maxalphanames=3 minalphanames=1 entry L5 extraalpha');
eq_or_diff($bibentries->entry('L6')->get_field('sortlabelalpha'), 'DSE95', 'maxalphanames=3 minalphanames=1 entry L6 labelalpha');
ok(is_undef($main->get_extraalphadata('L6')), 'maxalphanames=3 minalphanames=1 entry L6 extraalpha');
eq_or_diff($bibentries->entry('L7')->get_field('sortlabelalpha'), 'DSJ95', 'maxalphanames=3 minalphanames=1 entry L7 labelalpha');
ok(is_undef($main->get_extraalphadata('L7')), 'maxalphanames=3 minalphanames=1 entry L7 extraalpha');
eq_or_diff($bibentries->entry('L8')->get_field('sortlabelalpha'), 'Sha85', 'maxalphanames=3 minalphanames=1 entry L8 labelalpha');
ok(is_undef($main->get_extraalphadata('L8')), 'maxalphanames=3 minalphanames=1 entry L8 extraalpha');
eq_or_diff($bibentries->entry('LDN1')->get_field('sortlabelalpha'), 'VUR89', 'Testing compound lastnames 1');
eq_or_diff($bibentries->entry('LDN2')->get_field('sortlabelalpha'), 'VU45', 'Testing compound lastnames 2');

# reset options and regenerate information
Biber::Config->setblxoption('maxalphanames', 4);
Biber::Config->setblxoption('minalphanames', 4);
Biber::Config->setblxoption('maxcitenames', 4);
Biber::Config->setblxoption('mincitenames', 4);
Biber::Config->setblxoption('labelalpha', 1);
Biber::Config->setblxoption('labeldate', 1);

foreach my $k ($section->get_citekeys) {
  $bibentries->entry($k)->del_field('sortlabelalpha');
  $bibentries->entry($k)->del_field('labelalpha');
  $main->set_extraalphadata_for_key($k, undef);
}

$biber->prepare;
my $out = $biber->get_output_obj;
$section = $biber->sections->get_section(0);
$main = $biber->sortlists->get_list(0, 'nty/global', 'entry', 'nty', 'global');
$bibentries = $section->bibentries;

eq_or_diff($bibentries->entry('L11')->get_field('sortlabelalpha'), 'vRan22', 'prefix labelalpha 1');
eq_or_diff($bibentries->entry('L12')->get_field('sortlabelalpha'), 'vRvB2', 'prefix labelalpha 2');
# only the first name in the list is in the label due to namecount=1
eq_or_diff($bibentries->entry('L13')->get_field('sortlabelalpha'), 'vRa+-ksUnV', 'per-type labelalpha 1');
eq_or_diff($bibentries->entry('L14')->get_field('sortlabelalpha'), 'Alabel-ksUnW', 'per-type labelalpha 2');
eq_or_diff($bibentries->entry('L15')->get_field('sortlabelalpha'), 'AccBrClim', 'labelalpha disambiguation 1');
eq_or_diff($bibentries->entry('L16')->get_field('sortlabelalpha'), 'AccBaClim', 'labelalpha disambiguation 2');
eq_or_diff($bibentries->entry('L16a')->get_field('sortlabelalpha'), 'AccBaClim', 'labelalpha disambiguation 2a');
eq_or_diff($main->get_extraalphadata('L16'), '1', 'labelalpha disambiguation 2c');
eq_or_diff($main->get_extraalphadata('L16a'), '2', 'labelalpha disambiguation 2d');
eq_or_diff($bibentries->entry('L17')->get_field('sortlabelalpha'), 'AckBaClim', 'labelalpha disambiguation 3');
eq_or_diff($main->get_extraalphadata('L17a'), '2', 'custom labelalpha extrayear 1');
eq_or_diff($bibentries->entry('L18')->get_field('sortlabelalpha'), 'AgChLa', 'labelalpha disambiguation 4');
eq_or_diff($bibentries->entry('L19')->get_field('sortlabelalpha'), 'AgConLe', 'labelalpha disambiguation 5');
eq_or_diff($bibentries->entry('L20')->get_field('sortlabelalpha'), 'AgCouLa', 'labelalpha disambiguation 6');
eq_or_diff($bibentries->entry('L21')->get_field('sortlabelalpha'), 'BoConEdb', 'labelalpha disambiguation 7');
eq_or_diff($bibentries->entry('L22')->get_field('sortlabelalpha'), 'BoConEm', 'labelalpha disambiguation 8');
eq_or_diff($bibentries->entry('L23')->get_field('sortlabelalpha'), 'Sa', 'labelalpha disambiguation 9');

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
}, 'ENTRYTYPE', 'unpublished');


foreach my $k ($section->get_citekeys) {
  $bibentries->entry($k)->del_field('sortlabelalpha');
  $bibentries->entry($k)->del_field('labelalpha');
  $main->set_extraalphadata_for_key($k, undef);
}

$biber->prepare;
$section = $biber->sections->get_section(0);
$main = $biber->sortlists->get_list(0, 'nty/global', 'entry', 'nty', 'global');
$bibentries = $section->bibentries;

# "Agas" and not "Aga" because the Schmidt/Schnee below need 4 chars to disambiguate
eq_or_diff($bibentries->entry('L18')->get_field('sortlabelalpha'), 'AgasChaLaver', 'labelalpha disambiguation 10');
eq_or_diff($bibentries->entry('L19')->get_field('sortlabelalpha'), 'AgasConLendl', 'labelalpha disambiguation 11');
eq_or_diff($bibentries->entry('L20')->get_field('sortlabelalpha'), 'AgasCouLaver', 'labelalpha disambiguation 12');

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
}, 'ENTRYTYPE', 'unpublished');

foreach my $k ($section->get_citekeys) {
  $bibentries->entry($k)->del_field('sortlabelalpha');
  $bibentries->entry($k)->del_field('labelalpha');
  $main->set_extraalphadata_for_key($k, undef);
}

$biber->prepare;
$section = $biber->sections->get_section(0);
$main = $biber->sortlists->get_list(0, 'nty/global', 'entry', 'nty', 'global');
$bibentries = $section->bibentries;

eq_or_diff($bibentries->entry('L18')->get_field('sortlabelalpha'), 'AChL', 'labelalpha list disambiguation 1');
eq_or_diff($bibentries->entry('L19')->get_field('sortlabelalpha'), 'ACoL', 'labelalpha list disambiguation 2');
eq_or_diff($bibentries->entry('L20')->get_field('sortlabelalpha'), 'ACL', 'labelalpha list disambiguation 3');
eq_or_diff($bibentries->entry('L21')->get_field('sortlabelalpha'), 'BCEd', 'labelalpha list disambiguation 4');
eq_or_diff($bibentries->entry('L22')->get_field('sortlabelalpha'), 'BCE', 'labelalpha list disambiguation 5');
eq_or_diff($bibentries->entry('L24')->get_field('sortlabelalpha'), 'Z', 'labelalpha list disambiguation 6');
eq_or_diff($bibentries->entry('L25')->get_field('sortlabelalpha'), 'ZX', 'labelalpha list disambiguation 7');
eq_or_diff($bibentries->entry('L26')->get_field('sortlabelalpha'), 'ZX', 'labelalpha list disambiguation 8');
eq_or_diff(NFC($bibentries->entry('title1')->get_field('sortlabelalpha')), 'Tït', 'Title in braces with UTF-8 char - 1');

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
$main = $biber->sortlists->get_list(0, 'nty/global', 'entry', 'nty', 'global');
$bibentries = $section->bibentries;

eq_or_diff($bibentries->entry('Schmidt2007')->get_field('sortlabelalpha'), 'Sch+07', 'extraalpha ne extrayear 1');
eq_or_diff($main->get_extraalphadata('Schmidt2007'), '1', 'extraalpha ne extrayear 2');
eq_or_diff($bibentries->entry('Schmidt2007a')->get_field('sortlabelalpha'), 'Sch07', 'extraalpha ne extrayear 3');
eq_or_diff($main->get_extraalphadata('Schmidt2007a'), '1', 'extraalpha ne extrayear 4');

eq_or_diff($bibentries->entry('Schnee2007')->get_field('sortlabelalpha'), 'Sch+07', 'extraalpha ne extrayear 5');
eq_or_diff($main->get_extraalphadata('Schnee2007'), '2', 'extraalpha ne extrayear 6');
eq_or_diff($bibentries->entry('Schnee2007a')->get_field('sortlabelalpha'), 'Sch07', 'extraalpha ne extrayear 7');
eq_or_diff($main->get_extraalphadata('Schnee2007a'), '2', 'extraalpha ne extrayear 8');

Biber::Config->setblxoption('labelalphatemplate', {
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
$main = $biber->sortlists->get_list(0, 'nty/global', 'entry', 'nty', 'global');
$bibentries = $section->bibentries;

eq_or_diff($bibentries->entry('Schmidt2007')->get_field('sortlabelalpha'), 'SCH', 'entrykey label 1');

Biber::Config->setblxoption('labelalphatemplate', {
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
$main = $biber->sortlists->get_list(0, 'nty/global', 'entry', 'nty', 'global');
$bibentries = $section->bibentries;

eq_or_diff($bibentries->entry('labelstest')->get_field('sortlabelalpha'), '20050302', 'labeldate test - 1');
eq_or_diff($bibentries->entry('padtest')->get_field('labelalpha'), '\&Al\_\_{\textasciitilde}{\textasciitilde}T07', 'pad test - 1');
eq_or_diff($bibentries->entry('padtest')->get_field('sortlabelalpha'), '&Al__~~T07', 'pad test - 2');

Biber::Config->setblxoption('labelalphatemplate', {
  labelelement => [
                   {
                    labelpart => [
                                  {
                   content         => "author",
                   ifnamecount     => 1,
                   substring_side  => "left",
                   substring_width => 3,
                   substring_pwidth => 2,
                   substring_pcompound=> 1,
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
$main = $biber->sortlists->get_list(0, 'nty/global', 'entry', 'nty', 'global');
$bibentries = $section->bibentries;

eq_or_diff($bibentries->entry('skipwidthtest1')->get_field('sortlabelalpha'), 'OToolOToole', 'Skip width test - 1');
eq_or_diff($bibentries->entry('prefix1')->get_field('sortlabelalpha'), 'vadeVaaThin', 'compound and string length entry prefix1 labelalpha');


Biber::Config->setblxoption('labelalphatemplate', {
  labelelement => [
                   {
                    labelpart => [
                                  {
                   content         => "author",
                   namerange       => "2-7"
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
                   namerange       => "--3"
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
                   namerange       => "2",
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
                   namerange       => "3--"
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
                   namerange       => "2-+"
                                  },
                   ],
                   order => 9,
                   },
                  ],
  type  => "global",
});
Biber::Config->setblxoption('minalphanames', 2);

foreach my $k ($section->get_citekeys) {
  $bibentries->entry($k)->del_field('sortlabelalpha');
  $bibentries->entry($k)->del_field('labelalpha');
  $main->set_extraalphadata_for_key($k, undef);
}
$biber->prepare;
$section = $biber->sections->get_section(0);
$main = $biber->sortlists->get_list(0, 'nty/global', 'entry', 'nty', 'global');
$bibentries = $section->bibentries;

eq_or_diff($bibentries->entry('rangetest1')->get_field('sortlabelalpha'), 'WAXAYAZA.VEWEXE+.VTWT.XFYFZF.WH+', 'Name range test - 1');


