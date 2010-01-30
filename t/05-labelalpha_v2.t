use strict;
use warnings;
use utf8;
use Storable qw (dclone);
no warnings 'utf8';

use Test::More tests => 64;

use Biber;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

chdir("t/tdata");

my $bibfile;
my $biber = Biber->new;
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('locale', 'C');
$biber->parse_auxfile_v2('60-labelalpha_v2.aux');
$bibfile = Biber::Config->getoption('bibdata')->[0] . '.bib';
$biber->parse_bibtex($bibfile);

Biber::Config->setblxoption('labelalpha', 1);
Biber::Config->setblxoption('labelyear', undef);
Biber::Config->setblxoption('maxnames', 1);
Biber::Config->setblxoption('minnames', 1);
$biber->prepare;
my $bibentries = $biber->bib;

is($bibentries->entry('l1')->get_field('sortlabelalpha'), 'Doe95', 'maxnames=1 minnames=1 entry L1 labelalpha');
is($bibentries->entry('l1')->get_field('extraalpha'), '', 'maxnames=1 minnames=1 entry L1 extraalpha');
is($bibentries->entry('l2')->get_field('sortlabelalpha'), 'Doe+95', 'maxnames=1 minnames=1 entry L2 labelalpha');
is($bibentries->entry('l2')->get_field('extraalpha'), '1', 'maxnames=1 minnames=1 entry L2 extraalpha');
is($bibentries->entry('l3')->get_field('sortlabelalpha'), 'Doe+95', 'maxnames=1 minnames=1 entry L3 labelalpha');
is($bibentries->entry('l3')->get_field('extraalpha'), '2', 'maxnames=1 minnames=1 entry L3 extraalpha');
is($bibentries->entry('l4')->get_field('sortlabelalpha'), 'Doe+95', 'maxnames=1 minnames=1 entry L4 labelalpha');
is($bibentries->entry('l4')->get_field('extraalpha'), '3', 'maxnames=1 minnames=1 entry L4 extraalpha');
is($bibentries->entry('l5')->get_field('sortlabelalpha'), 'Doe+95', 'maxnames=1 minnames=1 entry L5 labelalpha');
is($bibentries->entry('l5')->get_field('extraalpha'), '4', 'maxnames=1 minnames=1 entry L5 extraalpha');
is($bibentries->entry('l6')->get_field('sortlabelalpha'), 'Doe+95', 'maxnames=1 minnames=1 entry L6 labelalpha');
is($bibentries->entry('l6')->get_field('extraalpha'), '5', 'maxnames=1 minnames=1 entry L6 extraalpha');
is($bibentries->entry('l7')->get_field('sortlabelalpha'), 'Doe+95', 'maxnames=1 minnames=1 entry L7 labelalpha');
is($bibentries->entry('l7')->get_field('extraalpha'), '6', 'maxnames=1 minnames=1 entry L7 extraalpha');
is($bibentries->entry('l8')->get_field('sortlabelalpha'), 'Sha85', 'maxnames=1 minnames=1 entry L8 labelalpha');
is($bibentries->entry('l8')->get_field('extraalpha'), '', 'maxnames=1 minnames=1 entry L8 extraalpha');

Biber::Config->setblxoption('maxnames', 2);
Biber::Config->setblxoption('minnames', 1);

for (my $i=1; $i<9; $i++) {
  $bibentries->entry("l$i")->del_field('sortlabelalpha');
  $bibentries->entry("l$i")->del_field('labelalpha');
  $bibentries->entry("l$i")->del_field('extraalpha');
}
$biber->prepare;

is($bibentries->entry('l1')->get_field('sortlabelalpha'), 'Doe95', 'maxnames=2 minnames=1 entry L1 labelalpha');
is($bibentries->entry('l1')->get_field('extraalpha'), '', 'maxnames=2 minnames=1 entry L1 extraalpha');
is($bibentries->entry('l2')->get_field('sortlabelalpha'), 'DA95', 'maxnames=2 minnames=1 entry L2 labelalpha');
is($bibentries->entry('l2')->get_field('extraalpha'), '1', 'maxnames=2 minnames=1 entry L2 extraalpha');
is($bibentries->entry('l3')->get_field('sortlabelalpha'), 'DA95', 'maxnames=2 minnames=1 entry L3 labelalpha');
is($bibentries->entry('l3')->get_field('extraalpha'), '2', 'maxnames=2 minnames=1 entry L3 extraalpha');
is($bibentries->entry('l4')->get_field('sortlabelalpha'), 'Doe+95', 'maxnames=2 minnames=1 entry L4 labelalpha');
is($bibentries->entry('l4')->get_field('extraalpha'), '1', 'maxnames=2 minnames=1 entry L4 extraalpha');
is($bibentries->entry('l5')->get_field('sortlabelalpha'), 'Doe+95', 'maxnames=2 minnames=1 entry L5 labelalpha');
is($bibentries->entry('l5')->get_field('extraalpha'), '2', 'maxnames=2 minnames=1 entry L5 extraalpha');
is($bibentries->entry('l6')->get_field('sortlabelalpha'), 'Doe+95', 'maxnames=2 minnames=1 entry L6 labelalpha');
is($bibentries->entry('l6')->get_field('extraalpha'), '3', 'maxnames=2 minnames=1 entry L6 extraalpha');
is($bibentries->entry('l7')->get_field('sortlabelalpha'), 'Doe+95', 'maxnames=2 minnames=1 entry L7 labelalpha');
is($bibentries->entry('l7')->get_field('extraalpha'), '4', 'maxnames=2 minnames=1 entry L7 extraalpha');
is($bibentries->entry('l8')->get_field('sortlabelalpha'), 'Sha85', 'maxnames=2 minnames=1 entry L8 labelalpha');
is($bibentries->entry('l8')->get_field('extraalpha'), '', 'maxnames=2 minnames=1 entry L8 extraalpha');


Biber::Config->setblxoption('maxnames', 2);
Biber::Config->setblxoption('minnames', 2);

for (my $i=1; $i<9; $i++) {
  $bibentries->entry("l$i")->del_field('sortlabelalpha');
  $bibentries->entry("l$i")->del_field('labelalpha');
  $bibentries->entry("l$i")->del_field('extraalpha');
}
$biber->prepare;

is($bibentries->entry('l1')->get_field('sortlabelalpha'), 'Doe95', 'maxnames=2 minnames=2 entry L1 labelalpha');
is($bibentries->entry('l1')->get_field('extraalpha'), '', 'maxnames=2 minnames=2 entry L1 extraalpha');
is($bibentries->entry('l2')->get_field('sortlabelalpha'), 'DA95', 'maxnames=2 minnames=2 entry L2 labelalpha');
is($bibentries->entry('l2')->get_field('extraalpha'), '1', 'maxnames=2 minnames=2 entry L2 extraalpha');
is($bibentries->entry('l3')->get_field('sortlabelalpha'), 'DA95', 'maxnames=2 minnames=2 entry L3 labelalpha');
is($bibentries->entry('l3')->get_field('extraalpha'), '2', 'maxnames=2 minnames=2 entry L3 extraalpha');
is($bibentries->entry('l4')->get_field('sortlabelalpha'), 'DA+95', 'maxnames=2 minnames=2 entry L4 labelalpha');
is($bibentries->entry('l4')->get_field('extraalpha'), '1', 'maxnames=2 minnames=2 entry L4 extraalpha');
is($bibentries->entry('l5')->get_field('sortlabelalpha'), 'DA+95', 'maxnames=2 minnames=2 entry L5 labelalpha');
is($bibentries->entry('l5')->get_field('extraalpha'), '2', 'maxnames=2 minnames=2 entry L5 extraalpha');
is($bibentries->entry('l6')->get_field('sortlabelalpha'), 'DS+95', 'maxnames=2 minnames=2 entry L6 labelalpha');
is($bibentries->entry('l6')->get_field('extraalpha'), '1', 'maxnames=2 minnames=2 entry L6 extraalpha');
is($bibentries->entry('l7')->get_field('sortlabelalpha'), 'DS+95', 'maxnames=2 minnames=2 entry L7 labelalpha');
is($bibentries->entry('l7')->get_field('extraalpha'), '2', 'maxnames=2 minnames=2 entry L7 extraalpha');
is($bibentries->entry('l8')->get_field('sortlabelalpha'), 'Sha85', 'maxnames=2 minnames=2 entry L8 labelalpha');
is($bibentries->entry('l8')->get_field('extraalpha'), '', 'maxnames=2 minnames=2 entry L8 extraalpha');

Biber::Config->setblxoption('maxnames', 3);
Biber::Config->setblxoption('minnames', 1);

for (my $i=1; $i<9; $i++) {
  $bibentries->entry("l$i")->del_field('sortlabelalpha');
  $bibentries->entry("l$i")->del_field('labelalpha');
  $bibentries->entry("l$i")->del_field('extraalpha');
}
$biber->prepare;

is($bibentries->entry('l1')->get_field('sortlabelalpha'), 'Doe95', 'maxnames=3 minnames=1 entry L1 labelalpha');
is($bibentries->entry('l1')->get_field('extraalpha'), '', 'maxnames=3 minnames=1 entry L1 extraalpha');
is($bibentries->entry('l2')->get_field('sortlabelalpha'), 'DA95', 'maxnames=3 minnames=1 entry L2 labelalpha');
is($bibentries->entry('l2')->get_field('extraalpha'), '1', 'maxnames=3 minnames=1 entry L2 extraalpha');
is($bibentries->entry('l3')->get_field('sortlabelalpha'), 'DA95', 'maxnames=3 minnames=1 entry L3 labelalpha');
is($bibentries->entry('l3')->get_field('extraalpha'), '2', 'maxnames=3 minnames=1 entry L3 extraalpha');
is($bibentries->entry('l4')->get_field('sortlabelalpha'), 'DAE95', 'maxnames=3 minnames=1 entry L4 labelalpha');
is($bibentries->entry('l4')->get_field('extraalpha'), '1', 'maxnames=3 minnames=1 entry L4 extraalpha');
is($bibentries->entry('l5')->get_field('sortlabelalpha'), 'DAE95', 'maxnames=3 minnames=1 entry L5 labelalpha');
is($bibentries->entry('l5')->get_field('extraalpha'), '2', 'maxnames=3 minnames=1 entry L5 extraalpha');
is($bibentries->entry('l6')->get_field('sortlabelalpha'), 'DSE95', 'maxnames=3 minnames=1 entry L6 labelalpha');
is($bibentries->entry('l6')->get_field('extraalpha'), '', 'maxnames=3 minnames=1 entry L6 extraalpha');
is($bibentries->entry('l7')->get_field('sortlabelalpha'), 'DSJ95', 'maxnames=3 minnames=1 entry L7 labelalpha');
is($bibentries->entry('l7')->get_field('extraalpha'), '', 'maxnames=3 minnames=1 entry L7 extraalpha');
is($bibentries->entry('l8')->get_field('sortlabelalpha'), 'Sha85', 'maxnames=3 minnames=1 entry L8 labelalpha');
is($bibentries->entry('l8')->get_field('extraalpha'), '', 'maxnames=3 minnames=1 entry L8 extraalpha');

unlink "$bibfile.utf8";
