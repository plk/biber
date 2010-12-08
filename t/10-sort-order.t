use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 22;

use Biber;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
chdir("t/tdata") ;

# Set up Biber object
my $biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('sort-order.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'C.UTF-8');

my $i = 1;

# This makes sure the the sortorder of the output strings is still correct
# since the sorting and output are far enough apart, codewise, for problems
# to intervene ...
sub check_output_string_order {
  my $out = shift;
  my $test_order = shift;
  is_deeply($out->get_output_entries(0),
            [ map { $out->get_output_entry($_) }  @{$test_order} ], 'citeorder strings - ' . $i++);
}



# citeorder (sorting=none)
Biber::Config->setblxoption('sorting_label', [
                                                      [
                                                       {final          => undef,
                                                        sort_direction => undef},
                                                       {'citeorder'    => {}}
                                                      ]
                                                     ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));
Biber::Config->setblxoption('labelyear', undef);

# (re)generate informtion based on option settings
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $out = $biber->get_output_obj;

is_deeply([$section->get_citekeys], ['L2','L1B','L1','L4','L3','L5','L1A','L7','L8','L6','L9'], 'citeorder');
check_output_string_order($out, ['L2','L1B','L1','L4','L3','L5','L1A','L7','L8','L6','L9']);

# nty
Biber::Config->setblxoption('sorting_label', [
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'presort'    => {}},
                                                     {'mm'         => {}},
                                                    ],
                                                    [
                                                     {final          => 1,
                                                      sort_direction => undef},
                                                     {'sortkey'    => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}},
                                                     {'0000'       => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'volume'     => {}},
                                                     {'0000'       => {}}
                                                    ]
                                                   ]);

Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
$section = $biber->sections->get_section(0);
is_deeply([$section->get_citekeys], ['L5','L1A','L1','L1B','L2','L3','L4','L8','L7','L6','L9'], 'nty');
check_output_string_order($out, ['L5','L1A','L1','L1B','L2','L3','L4','L8','L7','L6','L9']);

# nyt
Biber::Config->setblxoption('sorting_label', [
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'presort'    => {}},
                                                     {'mm'         => {}},
                                                    ],
                                                    [
                                                     {final          => 1,
                                                      sort_direction => undef},
                                                     {'sortkey'    => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}},
                                                     {'0000'       => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'volume'     => {}},
                                                     {'0000'       => {}}
                                                    ]
                                                   ]);

Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
$section = $biber->sections->get_section(0);
is_deeply([$section->get_citekeys], ['L5','L1A','L1','L1B','L2','L3','L4','L8','L7','L6','L9'], 'nyt');
check_output_string_order($out, ['L5','L1A','L1','L1B','L2','L3','L4','L8','L7','L6','L9']);

# nyvt
Biber::Config->setblxoption('sorting_label', [
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'presort'    => {}},
                                                     {'mm'         => {}},
                                                    ],
                                                    [
                                                     {final          => 1,
                                                      sort_direction => undef},
                                                     {'sortkey'    => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}},
                                                     {'0000'       => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'volume'     => {}},
                                                     {'0000'       => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ]
                                                   ]);


Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
$section = $biber->sections->get_section(0);
is_deeply([$section->get_citekeys], ['L5','L1','L1A','L1B','L2','L3','L4','L8','L7','L6','L9'], 'nyvt');
check_output_string_order($out, ['L5','L1','L1A','L1B','L2','L3','L4','L8','L7','L6','L9']);

# nyvt with volume padding
Biber::Config->setblxoption('sorting_label', [
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'presort'    => {}},
                                                     {'mm'         => {}},
                                                    ],
                                                    [
                                                     {final          => 1,
                                                      sort_direction => undef},
                                                     {'sortkey'    => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}},
                                                     {'0000'       => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'volume'     => {pad_side => 'right'}},
                                                     {'0000'       => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ]
                                                   ]);


Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
$section = $biber->sections->get_section(0);
is_deeply([$section->get_citekeys], ['L5','L1A','L1','L1B','L2','L3','L4','L8','L7','L6','L9'], 'nyvt with volume padding');
check_output_string_order($out, ['L5','L1A','L1','L1B','L2','L3','L4','L8','L7','L6','L9']);

# ynt
Biber::Config->setblxoption('sorting_label', [
                               						      [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'presort'    => {}},
                                                     {'mm'         => {}},
                                                    ],
                                                    [
                                                     {final          => 1,
                                                      sort_direction => undef},
                                                     {'sortkey'    => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}},
                                                     {'9999'       => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                   ]);

Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
$section = $biber->sections->get_section(0);
is_deeply([$section->get_citekeys], ['L3','L1B','L1A','L1','L4','L2','L8','L7','L6','L9','L5'], 'ynt');
check_output_string_order($out, ['L3','L1B','L1A','L1','L4','L2','L8','L7','L6','L9','L5']);

# ynt with year substring
Biber::Config->setblxoption('sorting_label', [
						      [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'presort'    => {}},
                                                     {'mm'         => {}},
                                                    ],
                                                    [
                                                     {final          => 1,
                                                      sort_direction => undef},
                                                     {'sortkey'    => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sortyear'   => {}},
                                                     {'year'       => {'substring_side' => 'left',
                                                                       'substring_width' => 3}},
                                                     {'9999'       => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                   ]);

Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
$section = $biber->sections->get_section(0);
is_deeply([$section->get_citekeys], ['L3','L1B','L1A','L1','L2','L4','L8','L7','L6','L9','L5'], 'ynt with year substring');
check_output_string_order($out, ['L3','L1B','L1A','L1','L2','L4','L8','L7','L6','L9','L5']);

# ydnt
Biber::Config->setblxoption('sorting_label', [
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'presort'    => {}},
                                                     {'mm'         => {}},
                                                    ],
                                                    [
                                                     {final          => 1,
                                                      sort_direction => undef},
                                                     {'sortkey'    => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => 'descending'},
                                                     {'sortyear'  => {}},
                                                     {'year'      => {}},
                                                     {'9999'       => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                   ]);

Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
$section = $biber->sections->get_section(0);
# This is correct as "aaaaaa" sorts before all years when descending
is_deeply([$section->get_citekeys], ['L5','L9','L6','L7','L8','L2','L4','L1A','L1','L1B','L3'], 'ydnt');
check_output_string_order($out, ['L5','L9','L6','L7','L8','L2','L4','L1A','L1','L1B','L3']);

# anyt
Biber::Config->setblxoption('sorting_label', [
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'presort'    => {}},
                                                     {'mm'         => {}},
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'labelalpha' => {}}
                                                    ],
                                                    [
                                                     {final          => 1,
                                                      sort_direction => undef},
                                                     {'sortkey'    => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}},
                                                     {'0000'       => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sorttitle'  => {}},
                                                     {'0000'       => {}}
                                                    ]
                                                   ]);

Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));
Biber::Config->setblxoption('labelalpha', 1);

$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
$section = $biber->sections->get_section(0);
is_deeply([$section->get_citekeys], ['L1B','L1A','L1','L2','L3','L4','L5','L8','L7','L6','L9'], 'anyt');
check_output_string_order($out, ['L1B','L1A','L1','L2','L3','L4','L5','L8','L7','L6','L9']);

Biber::Config->setblxoption('labelalpha', 0);

# anyvt
Biber::Config->setblxoption('sorting_label', [
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'presort'    => {}},
                                                     {'mm'         => {}},
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'labelalpha' => {}}
                                                    ],
                                                    [
                                                     {final          => 1,
                                                      sort_direction => undef},
                                                     {'sortkey'    => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}},
                                                     {'0000'       => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'volume'     => {}},
                                                     {'0000'       => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ]
                                                   ]);

Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));
Biber::Config->setblxoption('labelalpha', 1);

$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
$section = $biber->sections->get_section(0);
is_deeply([$section->get_citekeys], ['L1B','L1','L1A','L2','L3','L4','L5','L8','L7','L6','L9'], 'anyvt');
check_output_string_order($out, ['L1B','L1','L1A','L2','L3','L4','L5','L8','L7','L6','L9']);


# nty with descending n
Biber::Config->setblxoption('sorting_label', [
                                                    [
                                                     {final          => undef,
                                                      sort_direction => 'descending'},
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {final          => undef,
                                                      sort_direction => undef},
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}},
                                                     {'0000'       => {}}
                                                    ],
                                                   ]);

Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
$section = $biber->sections->get_section(0);
is_deeply([$section->get_citekeys], ['L9','L6','L7','L8','L5','L4','L3','L2','L1B','L1A','L1'], 'nty with descending n');
check_output_string_order($out, ['L9','L6','L7','L8','L5','L4','L3','L2','L1B','L1A','L1']);


unlink "*.utf8";
