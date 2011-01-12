use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 4;

use Biber;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
chdir("t/tdata") ;
my $i = 1;
my $S;

# Set up Biber object
my $biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('sort-case.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests
Biber::Config->setoption('sortcase', 1);
Biber::Config->setoption('sortupper', 1);

$S =  [
                                                [
                                                 {},
                                                 {'author'     => {}},
                                                ],
                                               ];
Biber::Config->setblxoption('sorting', {default => {label => $S, final => $S, schemes_same => 1}});

$biber->prepare;
my $section = $biber->sections->get_section(0);
my $out = $biber->get_output_obj;

is_deeply([$section->get_citekeys], ['CS1','CS3','CS2'], 'U::C case - 1');
check_output_string_order($out, ['CS1','CS3','CS2']);

$biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('sort-case.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());

# Global here is sortcase=0, sortupper=1
# title is sortcase=1, sortupper=0
# So, all names are the same and it depends on title
$biber->prepare;
$section = $biber->sections->get_section(0);
$out = $biber->get_output_obj;
is_deeply([$section->get_citekeys], ['CS3','CS2','CS1'], 'U::C case - 2');

check_output_string_order($out, ['CS3','CS2','CS1']);


# This makes sure the the sortorder of the output strings is still correct
# since the sorting and output are far enough apart, codewise, for problems
# to intervene ...

sub check_output_string_order {
  my $out = shift;
  my $test_order = shift;
  is_deeply($out->get_output_entries(0),
            [ map { $out->get_output_entry($_) }  @{$test_order} ], 'U::C case strings - ' . $i++);
}


unlink "*.utf8";
