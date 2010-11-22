use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 8;

use Biber;
use Biber::Utils;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
chdir("t/tdata");

my $biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('sections.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('fastsort', 1);

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section0 = $biber->sections->get_section(0);
my $section1 = $biber->sections->get_section(1);
my $section2 = $biber->sections->get_section(2);
my $section3 = $biber->sections->get_section(3);

my $preamble = [
                'String for Preamble 1',
                'String for Preamble 2',
                'String for Preamble 3',
                'String for Preamble 4'
               ];

is_deeply($biber->get_preamble, $preamble, 'Preamble for all sections');
is_deeply([$section0->get_citekeys], ['sect1', 'sect2', 'sect3', 'sect8'], 'Section 0 citekeys');
is_deeply([$section0->get_shorthands], ['sect1', 'sect2', 'sect8'], 'Section 0 shorthands');
is_deeply([$section1->get_citekeys], ['sect4', 'sect5'], 'Section 1 citekeys');
is_deeply([$section1->get_shorthands], ['sect4', 'sect5'], 'Section 1 shorthands');
is_deeply([$section2->get_citekeys], ['sect1', 'sect6', 'sect7'], 'Section 2 citekeys');
is_deeply([$section2->get_shorthands], ['sect1', 'sect6', 'sect7'], 'Section 2 shorthands');
is_deeply([$section3->get_orig_order_citekeys], ['sect1', 'sect2', 'sectall1'], 'Section 3 citekeys');

unlink "*.utf8";
