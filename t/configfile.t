use strict;
use warnings;

use Test::More tests => 6;
use Biber;
use Cwd qw(getcwd);
use File::Spec;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

my $biberA = Biber->new( configfile => "t/tdata/biber2.conf" );
is(Biber::Config->getoption('mincrossrefs'), 5);
my %colloptsA = ( level => 3, table => "/home/user/data/otherkeys.txt" );
my %nosort = (author => [ q/\A\p{L}{2}\p{Pd}/, q/[\x{2bf}\x{2018}]/ ],
              translator => q/[\x{2bf}\x{2018}]/ );
is_deeply(Biber::Config->getoption('collate_options'), \%colloptsA);
is_deeply(Biber::Config->getoption('nosort'), \%nosort);

chdir("t/tdata");
my $cwdB = getcwd();
my $biberB = Biber->new(configfile => "biber3.conf");
is(Biber::Config->getcmdlineoption('configfile'), File::Spec->catfile("biber3.conf"));
is(Biber::Config->getoption('mincrossrefs'), 3);
my %colloptsB = ( level => 1, table => "/home/user/data/mykeys.txt" );
is_deeply(Biber::Config->getoption('collate_options'), \%colloptsB);

