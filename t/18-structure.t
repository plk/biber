use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 5;

use Biber;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
chdir("t/tdata") ;

# Set up Biber object
my $biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('structure.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('fastsort', 1);

# Now generate the information
$biber->prepare;

my $section = $biber->sections->get_section(0);
my $bibentries = $section->bibentries;

is($bibentries->entry('alias1')->get_field('entrytype'), 'thesis', 'Alias - 1' );
is($bibentries->entry('alias1')->get_field('type'), 'phdthesis', 'Alias - 2' );
is_deeply($bibentries->entry('alias1')->get_field('location'), ['Ivory Towers'], 'Alias - 3' );
is($bibentries->entry('alias1')->get_field('address'), undef, 'Alias - 4' );
is($bibentries->entry('alias2')->get_field('entrytype'), 'misc', 'Alias - 5' );


#is($out->get_output_entry('cr1'), $cr1, 'crossref test 1');

unlink "*.utf8";
