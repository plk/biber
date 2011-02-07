use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 8;

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
is_deeply([$section->get_list('lnamef1')->get_keys], ['K2', 'K4'], 'List - name order (filtered) - 1');
is_deeply([$section->get_list('lnamef2')->get_keys], ['K4'], 'List - name order (filtered) - 2');
is_deeply([$section->get_list('lnamef3')->get_keys], ['K1', 'K2'], 'List - name order (filtered) - 3');
is_deeply([$section->get_list('lnamef4')->get_keys], ['K3'], 'List - name order (filtered) - 4');
is_deeply([$section->get_list('lnamef5')->get_keys], ['K1', 'K3'], 'List - name order (filtered) - 5');

unlink <*.utf8>;
