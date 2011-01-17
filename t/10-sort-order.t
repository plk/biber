use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 26;

use Biber;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
chdir("t/tdata") ;
my $S;

# Set up Biber object
my $biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('sort-order.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests
Biber::Config->setoption('fastsort', 1);

my $i = 1;

# This makes sure the the sortorder of the output strings is still correct
# since the sorting and output are far enough apart, codewise, for problems
# to intervene ...
sub check_output_string_order {
  my $out = shift;
  my $test_order = shift;
  is_deeply($out->get_output_entries(0),
            [ map { $out->get_output_entry($_) }  @{$test_order} ], 'sort strings - ' . $i++);
}

# citeorder (sorting=none)
$S =  [
                                                      [
                                                       {},
                                                       {'citeorder'    => {}}
                                                      ]
                                                     ];
Biber::Config->setblxoption('sorting', {default => {label => $S, final => $S, schemes_same => 1}});
Biber::Config->setblxoption('labelyear', undef);

# (re)generate informtion based on option settings
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $out = $biber->get_output_obj;

is_deeply([$section->get_citekeys], ['L2','L1B','L1','L4','L3','L5','L1A','L7','L8','L6','L9'], 'citeorder');
check_output_string_order($out, ['L2','L1B','L1','L4','L3','L5','L1A','L7','L8','L6','L9']);

# nty
$S = [
                                                    [
                                                     {},
                                                     {'presort'    => {}}
                                                    ],
                                                    [
                                                     {final          => 1,
                                                      },
                                                     {'sortkey'    => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}},
                                                     {'0000'       => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'volume'     => {}},
                                                     {'0000'       => {}}
                                                    ]
                                                   ];

Biber::Config->setblxoption('sorting', {default => {label => $S, final => $S, schemes_same => 1}});

$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
$section = $biber->sections->get_section(0);
is_deeply([$section->get_citekeys], ['L5','L1A','L1','L1B','L2','L3','L4','L8','L7','L6','L9'], 'nty');
check_output_string_order($out, ['L5','L1A','L1','L1B','L2','L3','L4','L8','L7','L6','L9']);

# nyt
$S = [
                                                    [
                                                     {},
                                                     {'presort'    => {}}
                                                    ],
                                                    [
                                                     {final          => 1,
                                                      },
                                                     {'sortkey'    => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}},
                                                     {'0000'       => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'volume'     => {}},
                                                     {'0000'       => {}}
                                                    ]
                                                   ];

Biber::Config->setblxoption('sorting', {default => {label => $S, final => $S, schemes_same => 1}});

$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
$section = $biber->sections->get_section(0);
is_deeply([$section->get_citekeys], ['L5','L1A','L1','L1B','L2','L3','L4','L8','L7','L6','L9'], 'nyt');
check_output_string_order($out, ['L5','L1A','L1','L1B','L2','L3','L4','L8','L7','L6','L9']);

# nyvt
$S = [
                                                    [
                                                     {},
                                                     {'presort'    => {}}
                                                    ],
                                                    [
                                                     {final          => 1,
                                                      },
                                                     {'sortkey'    => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}},
                                                     {'0000'       => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'volume'     => {}},
                                                     {'0000'       => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ]
                                                   ];


Biber::Config->setblxoption('sorting', {default => {label => $S, final => $S, schemes_same => 1}});

$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
$section = $biber->sections->get_section(0);
is_deeply([$section->get_citekeys], ['L5','L1','L1A','L1B','L2','L3','L4','L8','L7','L6','L9'], 'nyvt');
check_output_string_order($out, ['L5','L1','L1A','L1B','L2','L3','L4','L8','L7','L6','L9']);

# nyvt with volume padding
$S = [
                                                    [
                                                     {},
                                                     {'presort'    => {}}
                                                    ],
                                                    [
                                                     {final          => 1,
                                                      },
                                                     {'sortkey'    => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}},
                                                     {'0000'       => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'volume'     => {pad_side => 'right'}},
                                                     {'0000'       => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ]
                                                   ];


Biber::Config->setblxoption('sorting', {default => {label => $S, final => $S, schemes_same => 1}});

$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
$section = $biber->sections->get_section(0);
is_deeply([$section->get_citekeys], ['L5','L1A','L1','L1B','L2','L3','L4','L8','L7','L6','L9'], 'nyvt with volume padding');
check_output_string_order($out, ['L5','L1A','L1','L1B','L2','L3','L4','L8','L7','L6','L9']);

# ynt
$S = [
                               						      [
                                                     {},
                                                     {'presort'    => {}}
                                                    ],
                                                    [
                                                     {final          => 1,
                                                      },
                                                     {'sortkey'    => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}},
                                                     {'9999'       => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                   ];

Biber::Config->setblxoption('sorting', {default => {label => $S, final => $S, schemes_same => 1}});

$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
$section = $biber->sections->get_section(0);
is_deeply([$section->get_citekeys], ['L3','L1B','L1A','L1','L4','L2','L8','L7','L6','L9','L5'], 'ynt');
check_output_string_order($out, ['L3','L1B','L1A','L1','L4','L2','L8','L7','L6','L9','L5']);

# ynt with year substring
$S = [
						      [
                                                     {},
                                                     {'presort'    => {}}
                                                    ],
                                                    [
                                                     {final          => 1,
                                                      },
                                                     {'sortkey'    => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sortyear'   => {}},
                                                     {'year'       => {'substring_side' => 'left',
                                                                       'substring_width' => 3}},
                                                     {'9999'       => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                   ];

Biber::Config->setblxoption('sorting', {default => {label => $S, final => $S, schemes_same => 1}});

$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
$section = $biber->sections->get_section(0);
is_deeply([$section->get_citekeys], ['L3','L1B','L1A','L1','L2','L4','L8','L7','L6','L9','L5'], 'ynt with year substring');
check_output_string_order($out, ['L3','L1B','L1A','L1','L2','L4','L8','L7','L6','L9','L5']);

# ydnt
$S = [
                                                    [
                                                     {},
                                                     {'presort'    => {}}
                                                    ],
                                                    [
                                                     {final          => 1,
                                                      },
                                                     {'sortkey'    => {}}
                                                    ],
                                                    [
                                                     {sort_direction => 'descending'},
                                                     {'sortyear'  => {}},
                                                     {'year'      => {}},
                                                     {'9999'       => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                   ];

Biber::Config->setblxoption('sorting', {default => {label => $S, final => $S, schemes_same => 1}});

$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
$section = $biber->sections->get_section(0);
# This is correct as "aaaaaa" sorts before all years when descending
is_deeply([$section->get_citekeys], ['L5','L9','L6','L7','L8','L2','L4','L1A','L1','L1B','L3'], 'ydnt');
check_output_string_order($out, ['L5','L9','L6','L7','L8','L2','L4','L1A','L1','L1B','L3']);

# anyt
$S = [
                                                    [
                                                     {},
                                                     {'presort'    => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'labelalpha' => {}}
                                                    ],
                                                    [
                                                     {final          => 1,
                                                      },
                                                     {'sortkey'    => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}},
                                                     {'0000'       => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sorttitle'  => {}},
                                                     {'0000'       => {}}
                                                    ]
                                                   ];

Biber::Config->setblxoption('sorting', {default => {label => $S, final => $S, schemes_same => 1}});
Biber::Config->setblxoption('labelalpha', 1);

$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
$section = $biber->sections->get_section(0);
is_deeply([$section->get_citekeys], ['L1B','L1A','L1','L2','L3','L4','L5','L8','L7','L6','L9'], 'anyt');
check_output_string_order($out, ['L1B','L1A','L1','L2','L3','L4','L5','L8','L7','L6','L9']);

Biber::Config->setblxoption('labelalpha', 0);

# anyvt
$S = [
                                                    [
                                                     {},
                                                     {'presort'    => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'labelalpha' => {}}
                                                    ],
                                                    [
                                                     {final          => 1,
                                                      },
                                                     {'sortkey'    => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}},
                                                     {'0000'       => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'volume'     => {}},
                                                     {'0000'       => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ]
                                                   ];

Biber::Config->setblxoption('sorting', {default => {label => $S, final => $S, schemes_same => 1}});
Biber::Config->setblxoption('labelalpha', 1);

$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
$section = $biber->sections->get_section(0);
is_deeply([$section->get_citekeys], ['L1B','L1','L1A','L2','L3','L4','L5','L8','L7','L6','L9'], 'anyvt');
check_output_string_order($out, ['L1B','L1','L1A','L2','L3','L4','L5','L8','L7','L6','L9']);


# nty with descending n
$S = [
                                                    [
                                                     {sort_direction => 'descending'},
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {},
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}},
                                                     {'0000'       => {}}
                                                    ],
                                                   ];

Biber::Config->setblxoption('sorting', {default => {label => $S, final => $S, schemes_same => 1}});

$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
$section = $biber->sections->get_section(0);
is_deeply([$section->get_citekeys], ['L9','L6','L7','L8','L5','L4','L3','L2','L1B','L1A','L1'], 'nty with descending n');
check_output_string_order($out, ['L9','L6','L7','L8','L5','L4','L3','L2','L1B','L1A','L1']);


# testing case sensitive with fastsort
# In alphabetic, all uppercase comes before lower so the
# "sortcase => 1" on location means that "edinburgh" sorts at the end after "London"
# Take this out of the location sorting spec and it fails as it should
$S = [
                                                    [
                                                     {sortcase => 1},
                                                     {'location'     => {}}
                                                    ]
                                                   ];

Biber::Config->setblxoption('sorting', {default => {label => $S, final => $S, schemes_same => 1}});

$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
$section = $biber->sections->get_section(0);
is_deeply([$section->get_citekeys], ['L1B','L1A','L1','L2','L3','L4','L7','L8','L5','L9','L6'], 'location - sortcase=1');
check_output_string_order($out, ['L1B','L1A','L1','L2','L3','L4','L7','L8','L5','L9','L6']);

# Test nosort option
$S = [
                                                    [
                                                     {},
                                                     {'title'     => {}}
                                                    ]
                                                   ];

Biber::Config->setblxoption('sorting', {default => {label => $S, final => $S, schemes_same => 1}});
# Set nosort for tests, skipping "The " in titles so L7 should sort before L6
Biber::Config->setoption('nosort', { type_title => q/\AThe\s+/ });

$biber->set_output_obj(Biber::Output::BBL->new());
$biber->prepare;
$out = $biber->get_output_obj;
$section = $biber->sections->get_section(0);
is_deeply([$section->get_citekeys], ['L1A','L1','L1B','L2','L3','L4','L5','L7','L6','L9','L8'], 'nosort 1');
check_output_string_order($out, ['L1A','L1','L1B','L2','L3','L4','L5','L7','L6','L9','L8']);

unlink <*.utf8>;
