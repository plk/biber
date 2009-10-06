use strict;
use warnings;
use utf8;
use Storable qw (dclone);
no warnings 'utf8';

use Test::More tests => 8;

use Biber;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

chdir("t/tdata");

my $bibfile;
my $biber = Biber->new;
$biber->{config}{fastsort} = 1;
$biber->{config}{locale} = 'C';
$biber->parse_auxfile_v2('60-extrayear_v2.aux');
$bibfile = $biber->config('bibdata')->[0] . '.bib';
$biber->parse_bibtex($bibfile);

$biber->{config}{biblatex}{global}{labelyear} = 1;
$biber->prepare;

is($biber->{bib}{l1}{extrayear}, '1', 'Entry L1 - one name, first in 1995');
is($biber->{bib}{l2}{extrayear}, '2', 'Entry L2 - one name, second in 1995');
is($biber->{bib}{l3}{extrayear}, '3', 'Entry L3 - one name, third in 1995');
is($biber->{bib}{l4}{extrayear}, '1', 'Entry L4 - two names, first in 1995');
is($biber->{bib}{l5}{extrayear}, '2', 'Entry L5 - two names, second in 1995');
is($biber->{bib}{l6}{extrayear}, '1', 'Entry L6 - two names, first in 1996');
is($biber->{bib}{l7}{extrayear}, '2', 'Entry L7 - two names, second in 1996');
ok(! defined($biber->{bib}{l8}{extrayear}), 'Entry L8 - one name, only in year');

unlink "$bibfile.utf8";
