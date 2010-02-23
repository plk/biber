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
my $cwdB = getcwd();
my $biberB = Biber->new(configfile => "biber3.conf");
is(Biber::Config->getcmdlineoption('configfile'), File::Spec->catfile("biber3.conf"));
is(Biber::Config->getoption('mincrossrefs'), 3);
my %colloptsB = ( level => 1, table => "/home/user/data/mykeys.txt" );
is_deeply(Biber::Config->getoption('collate_options'), \%colloptsB);

Biber::Config->set_setparentkey('KeyA', 'keyB');
Biber::Config->incr_crossrefkey('SOME_KEY');
is(Biber::Config->get_setparentkey('KEYA'), 'keyb', 'case-insensitive state methods 1');
is(Biber::Config->get_crossrefkey('SoMe_KeY'), 1, 'case-insensitive state methods 2');

