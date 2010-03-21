use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 21;
use Storable qw (dclone);

use Biber;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

my $biber = Biber->new( unicodebbl => 1, fastsort => 1, noconf => 1 );


isa_ok($biber, "Biber");
chdir("t/tdata") ;
$biber->parse_auxfile('sort-order.aux');
$biber->parse_ctrlfile('sort-order.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());
my $bibfile = Biber::Config->getoption('bibdata')->[0] . ".bib";
$biber->parse_bibtex($bibfile);
my $i= 1;

# This makes sure the the sortorder of the output strings is still correct
# since the sorting and output are far enough apart, codewise, for problems
# to intervene ...
sub check_output_string_order {
  my $out = shift;
  my $test_order = shift;
  is_deeply($out->get_output_entries,
            [ map { $out->get_output_entry($_) }  @{$test_order} ], 'citeorder strings - ' . $i++);
}

# citeorder (sorting=none)
Biber::Config->setblxoption('sorting_label', [
                                                      [
                                                       {'citeorder'    => {}}
                                                      ]
                                                     ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));
Biber::Config->setblxoption('labelyear', undef);
$biber->prepare;
my $out = $biber->get_output_obj;
is_deeply([$biber->citekeys], ['L2','L1B','L1','L4','L3','L5','L1A'], 'citeorder');
check_output_string_order($out, ['L2','L1B','L1','L4','L3','L5','L1A']);

# nty
Biber::Config->setblxoption('sorting_label', [
                                                    [
                                                     {'presort'    => {}},
                                                     {'mm'         => {}},
                                                    ],
                                                    [
                                                     {'sortkey'    => {'final' => 1}}
                                                    ],
                                                    [
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}}
                                                    ],
                                                    [
                                                     {'volume'     => {}},
                                                     {'0000'       => {}}
                                                    ]
                                                   ]);

Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));
$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
is_deeply([$biber->citekeys], ['L5','L1A','L1','L1B','L2','L3','L4'], 'nty');
check_output_string_order($out, ['L5','L1A','L1','L1B','L2','L3','L4']);

# nyt
Biber::Config->setblxoption('sorting_label', [
                                                    [
                                                     {'presort'    => {}},
                                                     {'mm'         => {}},
                                                    ],
                                                    [
                                                     {'sortkey'    => {'final' => 1}}
                                                    ],
                                                    [
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}}
                                                    ],
                                                    [
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {'volume'     => {}},
                                                     {'0000'       => {}}
                                                    ]
                                                   ]);

Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));
$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
is_deeply([$biber->citekeys], ['L5','L1A','L1','L1B','L2','L3','L4'], 'nyt');
check_output_string_order($out, ['L5','L1A','L1','L1B','L2','L3','L4']);

# nyvt
Biber::Config->setblxoption('sorting_label', [
                                                    [
                                                     {'presort'    => {}},
                                                     {'mm'         => {}},
                                                    ],
                                                    [
                                                     {'sortkey'    => {'final' => 1}}
                                                    ],
                                                    [
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}}
                                                    ],
                                                    [
                                                     {'volume'     => {}},
                                                     {'0000'       => {}}
                                                    ],
                                                    [
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ]
                                                   ]);


Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));
$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
is_deeply([$biber->citekeys], ['L5','L1','L1A','L1B','L2','L3','L4'], 'nyvt');
check_output_string_order($out, ['L5','L1','L1A','L1B','L2','L3','L4']);

# nyvt with volume padding
Biber::Config->setblxoption('sorting_label', [
                                                    [
                                                     {'presort'    => {}},
                                                     {'mm'         => {}},
                                                    ],
                                                    [
                                                     {'sortkey'    => {'final' => 1}}
                                                    ],
                                                    [
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}}
                                                    ],
                                                    [
						     {'volume'     => {pad_side => 'right'}},
                                                     {'0000'       => {}}
                                                    ],
                                                    [
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ]
                                                   ]);


Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));
$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
is_deeply([$biber->citekeys], ['L5','L1A','L1','L1B','L2','L3','L4'], 'nyvt with volume padding');
check_output_string_order($out, ['L5','L1A','L1','L1B','L2','L3','L4']);

# ynt
Biber::Config->setblxoption('sorting_label', [
						      [
                                                     {'presort'    => {}},
                                                     {'mm'         => {}},
                                                    ],
                                                    [
                                                     {'sortkey'    => {'final' => 1}}
                                                    ],
                                                    [
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}},
                                                     {'9999'       => {}}
                                                    ],
                                                    [
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                   ]);

Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
is_deeply([$biber->citekeys], ['L3','L1B','L1A','L1','L4','L2','L5'], 'ynt');
check_output_string_order($out, ['L3','L1B','L1A','L1','L4','L2','L5']);

# ynt with year substring
Biber::Config->setblxoption('sorting_label', [
						      [
                                                     {'presort'    => {}},
                                                     {'mm'         => {}},
                                                    ],
                                                    [
                                                     {'sortkey'    => {'final' => 1}}
                                                    ],
                                                    [
                                                     {'sortyear'   => {}},
                                                     {'year'       => {'substring_side' => 'left',
								       'substring_width' => 3}},
                                                     {'9999'       => {}}
                                                    ],
                                                    [
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                   ]);

Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
is_deeply([$biber->citekeys], ['L3','L1B','L1A','L1','L2','L4','L5'], 'ynt with year substring');
check_output_string_order($out, ['L3','L1B','L1A','L1','L2','L4','L5']);

# ydnt
Biber::Config->setblxoption('sorting_label', [
                                                    [
                                                     {'presort'    => {}},
                                                     {'mm'         => {}},
                                                    ],
                                                    [
                                                     {'sortkey'    => {'final' => 1}}
                                                    ],
                                                    [
                                                     {'sortyear'  => {'sort_direction'  => 'descending'}},
                                                     {'year'      => {'sort_direction'  => 'descending'}},
                                                     {'9999'       => {}}
                                                    ],
                                                    [
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                   ]);

Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));
$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
is_deeply([$biber->citekeys], ['L2','L4','L1A','L1','L1B','L3','L5'], 'ydnt');
check_output_string_order($out, ['L2','L4','L1A','L1','L1B','L3','L5']);

# anyt
Biber::Config->setblxoption('sorting_label', [
                                                    [
                                                     {'presort'    => {}},
                                                     {'mm'         => {}},
                                                    ],
                                                    [
                                                     {'labelalpha' => {}}
                                                    ],
                                                    [
                                                     {'sortkey'    => {'final' => 1}}
                                                    ],
                                                    [
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}}
                                                    ],
                                                    [
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {'sorttitle'  => {}},
                                                     {'0000'       => {}}
                                                    ]
                                                   ]);

Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));
Biber::Config->setblxoption('labelalpha', 1);
$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
is_deeply([$biber->citekeys], ['L1B','L1A','L1','L2','L3','L4','L5'], 'anyt');
check_output_string_order($out, ['L1B','L1A','L1','L2','L3','L4','L5']);

Biber::Config->setblxoption('labelalpha', 0);

# anyvt
Biber::Config->setblxoption('sorting_label', [
                                                    [
                                                     {'presort'    => {}},
                                                     {'mm'         => {}},
                                                    ],
                                                    [
                                                     {'labelalpha' => {}}
                                                    ],
                                                    [
                                                     {'sortkey'    => {'final' => 1}}
                                                    ],
                                                    [
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}}
                                                    ],
                                                    [
                                                     {'volume'     => {}},
                                                     {'0000'       => {}}
                                                    ],
                                                    [
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ]
                                                   ]);

Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));
Biber::Config->setblxoption('labelalpha', 1);
$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
is_deeply([$biber->citekeys], ['L1B','L1','L1A','L2','L3','L4','L5'], 'anyvt');
check_output_string_order($out, ['L1B','L1','L1A','L2','L3','L4','L5']);

unlink "$bibfile.utf8";

