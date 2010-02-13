use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 7;

use Biber;
use Biber::Utils;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

my $biber = Biber->new( unicodebbl => 1, fastsort => 1 );

chdir("t/tdata") ;
$biber->parse_auxfile_v2('skips.aux');

my $bibfile = Biber::Config->getoption('bibdata')->[0] . ".bib";
$biber->parse_bibtex($bibfile);

$biber->prepare;
my $bibentries = $biber->bib;

is_deeply([$biber->shorthands], ['skip1'], 'skiplos - not in LOS');
is($bibentries->entry('skip2')->get_field('labelalpha'), 'SA', 'Normal labelalpha');
is($bibentries->entry('skip2')->get_field($bibentries->entry('skip2')->get_field('labelyearname')), '1995', 'Normal labelyear');
ok(is_undef($bibentries->entry('skip3')->get_field('labelalpha')), 'skiplab - no labelalpha');
ok(is_undef($bibentries->entry('skip3')->get_field('labelyearname')), 'skiplab - no labelyear');
ok(is_undef($bibentries->entry('skip4')->get_field('labelalpha')), 'dataonly - no labelalpha');
ok(is_undef($bibentries->entry('skip4')->get_field('labelyearname')), 'dataonly - no labelyear');

unlink "$bibfile.utf8";
