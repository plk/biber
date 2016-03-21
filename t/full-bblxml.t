# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More;

if ($ENV{BIBER_DEV_TESTS}) {
  plan tests => 2;
}
else {
  plan skip_all => 'BIBER_DEV_TESTS not set';
}

use IPC::Run3;
use File::Temp;
use File::Compare;
use File::Which;


my $perl = which('perl');

my $tmpfile = File::Temp->new();
#my $tmpfile = File::Temp->new(UNLINK => 0);
my $bbl = $tmpfile->filename;
#print "File: $bbl\n";
my $stdout;

run3  [ $perl, 'bin/biber', '--noconf', '--nolog', '--output-format=bblxml', "--output-file=$bbl", 't/tdata/full-bblxml.bcf' ], \undef, \$stdout, \undef;

is($? >> 8, 0, 'Full test has zero exit status');
ok(compare($bbl, 't/tdata/full1.bbl') == 0, 'Testing bblxml output');

