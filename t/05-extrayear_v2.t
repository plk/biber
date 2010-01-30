use strict;
use warnings;
use utf8;
use Storable qw (dclone);
no warnings 'utf8';

use Test::More tests => 8;

use Biber;
use Biber::Utils;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

chdir("t/tdata");

my $bibfile;
my $biber = Biber->new;
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('locale', 'C');
$biber->parse_auxfile_v2('60-extrayear_v2.aux');
$bibfile = Biber::Config->getoption('bibdata')->[0] . '.bib';
$biber->parse_bibtex($bibfile);

Biber::Config->setblxoption('labelyear', [ 'year' ]);
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

unlink "$bibfile.utf8";
