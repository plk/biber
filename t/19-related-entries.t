use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 13;

use Biber;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
chdir("t/tdata") ;

# Set up Biber object
my $biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('related.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('fastsort', 1);

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $bibentries = $section->bibentries;

my $ck1 = 'c2add694bf942dc77b376592d9c862cd';
my $ck2 = '78f825aaa0103319aaa1a30bf4fe3ada';
my $ck3 = '3631578538a2d6ba5879b31a9a42f290';

is($bibentries->entry('key1')->get_field('related'), "$ck2,$ck3", 'Related entry test 1');
is($bibentries->entry('key2')->get_field('related'), $ck1, 'Related entry test 2');
is($bibentries->entry('key3')->get_field('related'), $ck1, 'Related entry test 3');

is($bibentries->entry($ck2)->get_field('origkey'), $ck2, 'Related entry test 4');
is($bibentries->entry($ck2)->get_field('date'), '2009', 'Related entry test 5');
is_deeply($bibentries->entry($ck2)->get_field('publisher'), ['Publisher'], 'Related entry test 6');

is($bibentries->entry($ck1)->get_field('origkey'), $ck1, 'Related entry test 7');
is($bibentries->entry($ck1)->get_field('date'), '1998', 'Related entry test 8');
is($bibentries->entry($ck1)->get_field('number'), '5', 'Related entry test 9');

is($bibentries->entry($ck3)->get_field('origkey'), $ck3, 'Related entry test 10');
is($bibentries->entry($ck3)->get_field('date'), '2010', 'Related entry test 11');
is_deeply($bibentries->entry($ck3)->get_field('publisher'), ['Publisher2'], 'Related entry test 12');

is_deeply([$section->get_shorthands], ['key1', 'key2', 'key3'], 'Related entry test 13');

unlink "*.utf8";
