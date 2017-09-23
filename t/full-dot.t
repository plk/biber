# -*- cperl -*-
use v5.24;
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
my $dot = $tmpfile->filename;
my $stdout;
my $stderr;

run3  [ $perl, 'bin/biber', '--noconf', '--nolog', '-dot-include=section,field,xdata,crossref,xref,related', '--output-format=dot', "--output-file=$dot", 't/tdata/full-dot.bcf' ], \undef, \$stdout, \$stderr;
#say $stdout;
#say $stderr;

is($? >> 8, 0, 'Full test has zero exit status');
ok(compare($dot, 't/tdata/full-dot.dot') == 0, 'Testing dot output');

