use strict;
use warnings;

use Test::More tests => 3;
use Biber;
use Cwd qw(getcwd);
use File::Spec;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

chdir("t/tdata");
my $biber = Biber->new();
my $cwd = getcwd();
is($biber->config_file, File::Spec->catfile($cwd, "biber.conf"));
is($biber->config('mincrossrefs'),3);
my %collopts = ( level => 1, table => "/home/user/data/mykeys.txt" );
is_deeply($biber->config('collate_options'),\%collopts);

