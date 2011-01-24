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

my $i = 1;

# This makes sure the the sortorder of the output strings is still correct
# since the sorting and output are far enough apart, codewise, for problems
# to intervene ...
sub check_output_string_order {
  my $out = shift;
  my $test_order = shift;
  is_deeply($out->get_output_entries(0),
            [ map { $out->get_output_entry($_) }  @{$test_order} ], 'sort strings - ' . $i++);
}

# (re)generate informtion based on option settings
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $out = $biber->get_output_obj;

is_deeply([$section->get_list('lname')->get_keys], ['K1', 'K2', 'K4', 'K3'], 'List - name order');
is_deeply([$section->get_list('lyear')->get_keys], ['K4', 'K1', 'K2', 'K3'], 'List - year order');
is_deeply([$section->get_list('ltitle')->get_keys], ['K1', 'K4', 'K2', 'K3'], 'List - title order');
#check_output_string_order($out, ['L2','L1B','L1','L4','L3','L5','L1A','L7','L8','L6','L9']);

unlink <*.utf8>;
