use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More skip_all => 'Endnote XML not working yet';
#use Test::More tests => 1;

use Biber;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
chdir("t/tdata");

# Set up Biber object
my $biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('endnotexml.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'C');

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $main = $section->get_list('MAIN');
my $bibentries = $section->bibentries;

my $l1 = q||;

is( $out->get_output_entry($main, 'fpvfswdz9sw5e0edvxix5z26vxadptrzxfwa:42'), $l1, 'Basic Endnote XML test - 1') ;

unlink <*.utf8>;
