use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 3;

use Biber;
use Biber::Utils;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
chdir("t/tdata") ;

my $biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('sections.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('unicodebbl', 1);

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $bibentries0 = $biber->sections->get_section('0')->bib;
my $section0 = $biber->sections->get_section('0');
my $section1 = $biber->sections->get_section('1');
my $section2 = $biber->sections->get_section('2');

#is_deeply([$section->get_shorthands], ['skip1'], 'skiplos - not in LOS');
#is($bibentries->entry('skip2')->get_field('labelalpha'), 'SA', 'Normal labelalpha');
is_deeply([$section0->get_citekeys], ['sect1', 'sect2', 'sect3'], 'Section 0 citekeys');
is_deeply([$section1->get_citekeys], ['sect4', 'sect5'], 'Section 1 citekeys');
is_deeply([$section2->get_citekeys], ['sect6', 'sect7'], 'Section 2 citekeys');



unlink "*.utf8";
