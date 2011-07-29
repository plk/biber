use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 3;

use Biber;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
chdir("t/tdata");

# Set up Biber object
my $biber = Biber->new(noconf => 1);
#Log::Log4perl->easy_init($TRACE);
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'C');
$biber->parse_ctrlfile("general1.bcf");
$biber->set_output_obj(Biber::Output::BBL->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biblatex options
Biber::Config->setblxoption('labelnamespec', ['shortauthor', 'author', 'shorteditor', 'editor', 'translator']);
Biber::Config->setblxoption('labelnamespec', ['editor', 'translator'], 'PER_TYPE', 'book');

# Now generate the information
$biber->prepare;
my $bibentries = $biber->sections->get_section(0)->bibentries;

my $sa  = 'shortauthor';
my $a   = 'author';
my $ted = 'editor';


is($bibentries->entry('angenendtsa')->get_field('labelnamename'), $sa, 'global shortauthor' );
is($bibentries->entry('stdmodel')->get_field('labelnamename'), $a, 'global author' );
is($bibentries->entry('aristotle:anima')->get_field('labelnamename'), $ted, 'type-specific editor' );
