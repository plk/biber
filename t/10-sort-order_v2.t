use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 11;
use Storable qw (dclone);

use Biber;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

my $opts = { unicodebbl => 1, fastsort => 1 };
my $biber = Biber->new($opts);

isa_ok($biber, "Biber");
chdir("t/tdata") ;
$biber->parse_auxfile_v2('70-sort-order_v2.aux');

my $bibfile = Biber::Config->getoption('bibdata')->[0] . ".bib";
$biber->parse_bibtex($bibfile);

# citeorder (sorting=none)
Biber::Config->setblxoption('sorting_label', [
                                                      [
                                                       {'citeorder'    => {}}
                                                      ]
                                                     ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));
Biber::Config->setblxoption('labelyear', undef);
$biber->prepare;
is_deeply([$biber->citekeys] , ['L2','L1B','L1','L4','L3','L5','L1A'], 'citeorder');

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
$biber->prepare;
is_deeply([$biber->citekeys] , ['L5','L1A','L1','L1B','L2','L3','L4'], 'nty');

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
$biber->prepare;
is_deeply([$biber->citekeys] , ['L5','L1A','L1','L1B','L2','L3','L4'], 'nyt');

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
$biber->prepare;
is_deeply([$biber->citekeys] , ['L5','L1','L1A','L1B','L2','L3','L4'], 'nyvt');

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
$biber->prepare;
is_deeply([$biber->citekeys] , ['L5','L1A','L1','L1B','L2','L3','L4'], 'nyvt with volume padding');

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

$biber->prepare;
is_deeply([$biber->citekeys] , ['L3','L1B','L1A','L1','L4','L2','L5'], 'ynt');

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

$biber->prepare;
is_deeply([$biber->citekeys] , ['L3','L1B','L1A','L1','L2','L4','L5'], 'ynt with year substring');

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
$biber->prepare;
is_deeply([$biber->citekeys] , ['L2','L4','L1A','L1','L1B','L3','L5'], 'ydnt');


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
$biber->prepare;
is_deeply([$biber->citekeys] , ['L1B','L1A','L1','L2','L3','L4','L5'], 'anyt');
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
$biber->prepare;
is_deeply([$biber->citekeys] , ['L1B','L1','L1A','L2','L3','L4','L5'], 'anyvt');

unlink "$bibfile.utf8";

