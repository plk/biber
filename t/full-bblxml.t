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
my $bblxml = $tmpfile->filename;
my $stdout;
my $stderr;

run3  [ $perl, 'bin/biber', '--noconf', '--nolog', '--output-format=bblxml', "--output-file=$bblxml", '--validate-bblxml', 't/tdata/full-bblxml.bcf' ], \undef, \$stdout, \$stderr;
# say $stdout;
# say $stderr;

is($? >> 8, 0, 'Full test has zero exit status');

# Now replace the model ref for comparison with the static test file
run3  [ $perl, '-pi.bak', '-e', 's/(<\?xml-model href=")([^"]+)/$1full-bblxml.rng/', $bblxml ], \undef, \$stdout, \undef;
ok(compare($bblxml, 't/tdata/full-bblxml.bblxml') == 0, 'Testing bblxml output');

