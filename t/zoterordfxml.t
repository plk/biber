use strict;
use warnings;
use utf8;
no warnings 'utf8';

#use Test::More skip_all => 'zotero RDF/XML not working yet';
use Test::More tests => 2;

use Biber;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
chdir("t/tdata");

# Set up Biber object
my $biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('zoterordfxml.bcf');
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

my $l2 = q||;

is( $out->get_output_entry($main, 'http://0-muse.jhu.edu.pugwash.lib.warwick.ac.uk:80/journals/theory_and_event/v005/5.3ranciere.html'), $l1, 'Basic Zoter RDF/XML test - 1') ;
is( $out->get_output_entry($main, 'http://0-muse.jhu.edu.pugwash.lib.warwick.ac.uk:80/journals/theory_and_event/v005/5.3ranciere.html_acdd9e7d346836cf73e47441f0c18607'), $l2, 'Basic Zotero RDF/XML test - 2') ;


unlink <*.utf8>;
