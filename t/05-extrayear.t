use strict;
use warnings;
use utf8;
use Storable qw (dclone);
no warnings 'utf8';

use Test::More tests => 15;

use Biber;
use Biber::Utils;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

chdir("t/tdata");

my $bibfile;
my $biber = Biber->new(noconf => 1);


Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('locale', 'C');
$biber->parse_auxfile('extrayear.aux');
$biber->parse_ctrlfile('extrayear.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());
$bibfile = Biber::Config->getoption('bibdata')->[0] . '.bib';
$biber->parse_bibtex($bibfile);

Biber::Config->setblxoption('labelyear', [ 'year' ]);
Biber::Config->setblxoption('maxnames', 1);
$biber->prepare;
my $bibentries = $biber->bib;

is($bibentries->entry('l1')->get_field('extrayear'), '1', 'Entry L1 - one name, first in 1995');
is($bibentries->entry('l2')->get_field('extrayear'), '2', 'Entry L2 - one name, second in 1995');
is($bibentries->entry('l3')->get_field('extrayear'), '3', 'Entry L3 - one name, third in 1995');
is($bibentries->entry('l4')->get_field('extrayear'), '1', 'Entry L4 - two names, first in 1995');
is($bibentries->entry('l5')->get_field('extrayear'), '2', 'Entry L5 - two names, second in 1995');
is($bibentries->entry('l6')->get_field('extrayear'), '1', 'Entry L6 - two names, first in 1996');
is($bibentries->entry('l7')->get_field('extrayear'), '2', 'Entry L7 - two names, second in 1996');
ok(is_undef($bibentries->entry('l8')->get_field('extrayear')), 'Entry L8 - one name, only in year');
ok(is_undef($bibentries->entry('l9')->get_field('extrayear')), 'Entry L9 - No name, same year as another with no name');
ok(is_undef($bibentries->entry('l10')->get_field('extrayear')), 'Entry L10 - No name, same year as another with no name');
is($bibentries->entry('companion1')->get_field('extrayear'), '1', 'Entry companion1 - names truncated to same as another entry in same year');
is($bibentries->entry('companion2')->get_field('extrayear'), '2', 'Entry companion2 - names truncated to same as another entry in same year');
ok(is_undef($bibentries->entry('companion3')->get_field('extrayear')), 'Entry companion3 - one name, same year as truncated names');
ok(is_undef($bibentries->entry('vangennep')->get_field('extrayear')), 'Entry vangennep - prefix makes it different');
ok(is_undef($bibentries->entry('gennep')->get_field('extrayear')), 'Entry gennep - different from prefix name');


unlink "$bibfile.utf8";
