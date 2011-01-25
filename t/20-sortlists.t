use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 3;

use Biber;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
chdir("t/tdata") ;
my $S;

# Set up Biber object
my $biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('sortlists.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests
Biber::Config->setoption('fastsort', 1);

# (re)generate informtion based on option settings
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $out = $biber->get_output_obj;

is_deeply([$section->get_list('lname')->get_keys], ['K1', 'K2', 'K4', 'K3'], 'List - name order');
is_deeply([$section->get_list('lyear')->get_keys], ['K4', 'K1', 'K2', 'K3'], 'List - year order');
is_deeply([$section->get_list('ltitle')->get_keys], ['K1', 'K4', 'K2', 'K3'], 'List - title order');

unlink <*.utf8>;
