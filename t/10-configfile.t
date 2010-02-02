use strict;
use warnings;

use Test::More tests => 7;
use Biber;
use Cwd qw(getcwd);
use File::Spec;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

my $biberA = Biber->new( configfile => "t/tdata/biber2.conf" );
is(Biber::Config->getoption('mincrossrefs'), 5);
my %colloptsA = ( level => 3, table => "/home/user/data/otherkeys.txt" );
is_deeply(Biber::Config->getoption('collate_options'), \%colloptsA);

chdir("t/tdata");
my $biberB = Biber->new();
my $cwdB = getcwd();
is(Biber::Config->config_file, File::Spec->catfile($cwdB, "biber.conf"));
is(Biber::Config->getoption('mincrossrefs'), 3);
my %colloptsB = ( level => 1, table => "/home/user/data/mykeys.txt" );
is_deeply(Biber::Config->getoption('collate_options'), \%colloptsB);

Biber::Config->setstate('inset_entries', 'KeyA', 'keyB');
Biber::Config->incrstate('crossrefkeys', 'SOME_KEY');
is(Biber::Config->getstate('inset_entries', 'KEYA'), 'keyb', 'case-insensitive state methods 1');
is(Biber::Config->getstate('crossrefkeys', 'SoMe_KeY'), 1, 'case-insensitive state methods 2');
