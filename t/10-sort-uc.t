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
$biber->parse_ctrlfile('sort-uc.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests
Biber::Config->setoption('sortlocale', 'sv_SE');
Biber::Config->setblxoption('sortlos', 1);


my $i = 1;

# This makes sure the the sortorder of the output strings is still correct
# since the sorting and output are far enough apart, codewise, for problems
# to intervene ...
sub check_output_string_order {
  my $out = shift;
  my $test_order = shift;
  is_deeply($out->get_output_entries(0),
            [ map { $out->get_output_entry($_) }  @{$test_order} ], 'U::C Tailoring strings - ' . $i++);
}

# U::C Swedish tailoring
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $out = $biber->get_output_obj;

is_deeply([$section->get_citekeys], ['LS2','LS1','LS3'], 'U::C tailoring - 1');
check_output_string_order($out, ['LS2','LS1','LS3']);
is_deeply([$section->get_shorthands], ['LS3', 'LS2','LS1'], 'U::C tailoring - 2');

Biber::Config->setblxoption('sortlos', 0);
$section->set_shorthands([]);
$biber->prepare;
$section = $biber->sections->get_section(0);
$out = $biber->get_output_obj;
is_deeply([$section->get_shorthands], ['LS2', 'LS1','LS3'], 'U::C tailoring - 3');


# Descending name in Swedish collation
Biber::Config->setblxoption('sorting_label', [
                                                    [
                                                     {},
                                                     {'presort'    => {}}
                                                    ],
                                                    [
                                                     {final        => 1},
                                                     {'sortkey'    => {}}
                                                    ],
                                                    [
                                                     {sort_direction => 'descending'},
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ]
                                                   ]);

Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

$biber->prepare;
$section = $biber->sections->get_section(0);

is_deeply([$section->get_citekeys], ['LS3','LS1','LS2'], 'U::C tailoring descending - 1');


unlink "*.utf8";
