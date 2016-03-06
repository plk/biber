# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 15;

use Biber;
use Biber::Output::bbl;
use Log::Log4perl;
chdir("t/tdata");
my $S;

# Set up Biber object
my $biber = Biber->new(noconf => 1);
my $LEVEL = 'ERROR';
my $l4pconf = qq|
    log4perl.category.main                             = $LEVEL, Screen
    log4perl.category.screen                           = $LEVEL, Screen
    log4perl.appender.Screen                           = Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.utf8                      = 1
    log4perl.appender.Screen.Threshold                 = $LEVEL
    log4perl.appender.Screen.stderr                    = 0
    log4perl.appender.Screen.layout                    = Log::Log4perl::Layout::SimpleLayout
|;
Log::Log4perl->init(\$l4pconf);

$biber->parse_ctrlfile('sort-order.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');
Biber::Config->setoption('fastsort', 1);
Biber::Config->setblxoption('labelyear', undef);
Biber::Config->setblxoption('labelalpha', 0);

# (re)generate informtion based on option settings
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $main = $biber->sortlists->get_list(0, 'nty/global/', 'entry', 'nty', 'global', '');

is_deeply([ $main->get_keys ], ['L2','L3','L1B','L1','L4','L5','L1A','L7','L8','L6','L9'], 'citeorder');

# nty
$S = { spec => [
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
                                                   ]};

$main->set_sortscheme($S);

$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply([ $main->get_keys ], ['L5','L1A','L1','L1B','L2','L3','L4','L8','L7','L6','L9'], 'nty');

# nyt
$S = { spec => [
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
                                                   ]};

$main->set_sortscheme($S);

$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply([$main->get_keys], ['L5','L1A','L1','L1B','L2','L3','L4','L8','L7','L6','L9'], 'nyt');

# nyvt
$S = { spec => [
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
                                                   ]};


$main->set_sortscheme($S);

$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply([$main->get_keys], ['L5','L1','L1A','L1B','L2','L3','L4','L8','L7','L6','L9'], 'nyvt');

# nyvt with volume padding
$S = { spec => [
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
                                                   ]};


$main->set_sortscheme($S);

$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply([$main->get_keys], ['L5','L1A','L1','L1B','L2','L3','L4','L8','L7','L6','L9'], 'nyvt with volume padding');

# ynt
$S = { spec => [
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
                                                   ]};

$main->set_sortscheme($S);

$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply([$main->get_keys], ['L3','L1B','L1A','L1','L4','L2','L8','L7','L6','L9','L5'], 'ynt');

# ynt with year substring
$S = { spec => [
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
                                                   ]};

$main->set_sortscheme($S);

$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply([$main->get_keys], ['L3','L1B','L1A','L1','L2','L4','L8','L7','L6','L9','L5'], 'ynt with year substring');

# ydnt
$S = { spec => [
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
                                                   ]};

$main->set_sortscheme($S);

$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
# This is correct as "aaaaaa" sorts before all years when descending
is_deeply([$main->get_keys], ['L5','L9','L6','L7','L8','L2','L4','L1A','L1','L1B','L3'], 'ydnt');

# anyt
$S = { spec => [
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
                                                   ]};

$main->set_sortscheme($S);
Biber::Config->setblxoption('labelalpha', 1);

$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply([$main->get_keys], ['L1B','L1A','L1','L2','L3','L4','L5','L8','L7','L6','L9'], 'anyt');

Biber::Config->setblxoption('labelalpha', 0);

# anyvt
$S = { spec => [
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
                                                   ]};

$main->set_sortscheme($S);
Biber::Config->setblxoption('labelalpha', 1);

$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply([$main->get_keys], ['L1B','L1','L1A','L2','L3','L4','L5','L8','L7','L6','L9'], 'anyvt');


# nty with descending n
$S = { spec => [
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
                                                   ]};

$main->set_sortscheme($S);

$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply([$main->get_keys], ['L9','L6','L7','L8','L5','L4','L3','L2','L1B','L1A','L1'], 'nty with descending n');


# testing case sensitive with fastsort
# In alphabetic, all uppercase comes before lower so the
# "sortcase => 1" on location means that "edinburgh" sorts at the end after "London"
# Take this out of the location sorting spec and it fails as it should
$S = { spec => [
                                                    [
                                                     {sortcase => 1},
                                                     {'location'     => {}}
                                                    ]
                                                   ]};

$main->set_sortscheme($S);

$biber->set_output_obj(Biber::Output::bbl->new());
# Have to set locale to something which understands lexical/case differences for this test
# otherwise testing on Windows doesn't work ...
Biber::Config->setoption('sortlocale', 'C.UTF-8');
$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply([$main->get_keys], ['L1B','L1','L1A','L2','L3','L4','L5','L7','L8','L9','L6'], 'location - sortcase=1');

# Test nosort option
$S = { spec => [
                                                    [
                                                     {},
                                                     {'title'     => {}}
                                                    ]
                                                   ]};

$main->set_sortscheme($S);
# Set nosort for tests, skipping "The " in titles so L7 should sort before L6
Biber::Config->setoption('nosort', [{ name => 'settitles', value => q/\AThe\s+/ }]);

$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply([$main->get_keys], ['L1A','L1','L1B','L2','L3','L4','L5','L7','L6','L9','L8'], 'nosort 1');

# Testing sorting keys which have the same order as they were cited in the same \cite*{} cmd.
# In this case, they will be tied on sorting=none and can be further sorted by other fields
$S = { spec => [
                                                      [
                                                       {},
                                                       {'citeorder'    => {}}
                                                      ],
                                                      [
                                                       {},
                                                       {'year'    => {}}
                                                      ],
                                                     ]};
$main->set_sortscheme($S);
# Have to do a citekey deletion as we are not re-reading the .bcf which would do it for us
# Otherwise, we have citekeys and allkeys which confuses fetch_data()
$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply([ $main->get_keys ], ['L3','L2','L1B','L1','L4','L5','L1A','L7','L8','L6','L9'], 'sorting=none + year');

# Testing special case of sorting=none and allkeys because in this case "citeorder" means
# bib order
$S = { spec => [
                                                      [
                                                       {},
                                                       {'citeorder'    => {}}
                                                      ],
                                                     ]};

$main->set_sortscheme($S);
# Have to do a citekey deletion as we are not re-reading the .bcf which would do it for us
# Otherwise, we have citekeys and allkeys which confuses fetch_data()
$section->del_citekeys;
Biber::Config->reset_keyorder(0);
$section->set_allkeys(1);
$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply([$main->get_keys], ['L1','L1A','L1B','L2','L3','L4','L5','L6','L7','L8','L9'], 'sorting=none and allkeys');

