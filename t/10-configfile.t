use strict;
use warnings;

use Test::More tests => 5;
use Biber;
use Cwd qw(getcwd);
use File::Spec;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

my $biberA = Biber->new( {configfile => "t/tdata/biber2.conf"} );
is($biberA->config('mincrossrefs'),5);
my %colloptsA = ( level => 3, table => "/home/user/data/otherkeys.txt" );
is_deeply($biberA->config('collate_options'),\%colloptsA);

chdir("t/tdata");
my $biberB = Biber->new();
my $cwdB = getcwd();
is($biberB->config_file, File::Spec->catfile($cwdB, "biber.conf"));
is($biberB->config('mincrossrefs'),3);
my %colloptsB = ( level => 1, table => "/home/user/data/mykeys.txt" );
is_deeply($biberB->config('collate_options'),\%colloptsB);

