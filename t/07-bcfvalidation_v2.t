use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 1;

use Biber;
chdir("t/tdata");

my $bibfile;
my $biber = Biber->new;
$biber->{config}{validate} = 1;
$biber->parse_auxfile_v2("50-style-authoryear_v2.aux");

ok($biber->{config}{mincrossrefs} == 88, "Validation ok as we set this");



