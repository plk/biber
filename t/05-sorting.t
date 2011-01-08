use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 40;

use Biber;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
chdir("t/tdata");

# Set up Biber object
my $biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile("general1.bcf");
$biber->set_output_obj(Biber::Output::BBL->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'C');
Biber::Config->setoption('quiet', 1);

my $yearoff1    = 'mm,,Knuth_Donald E,Computers Typesetting,1984,0000';
my $yearoff2    = 'mm,,Knuth_Donald E,Computers Typesetting,198,0000';
my $yearoff3    = 'mm,,Knuth_Donald E,Computers Typesetting,1984,0000';
my $yearoff4    = 'mm,,Knuth_Donald E,Computers Typesetting,984,0000';
my $yearoff5    = 'mm,,Knuth_Donald E,Computers Typesetting,1984,0000';
my $yearoff6    = 'mm,,Knuth_Donald E,Computers Typesetting,1984,0000';
my $yearoff7    = 'mm,,Knuth_Donald E,Computers Typesetting,198,0000';
my $yearoff8    = 'mm,,Knuth_Donald E,Computers Typesetting,1984,0000';
my $yearoff9    = 'mm,,Knuth_Donald E,Computers Typesetting,984,0000';
my $vol1        = 'mm,,Glashow_Sheldon,Partial Symmetries of Weak Interactions,1961,2200';
my $vol2        = 'mm,,Glashow_Sheldon,Partial Symmetries of Weak Interactions,1961,2200000';
my $vol3        = 'mm,,Glashow_Sheldon,Partial Symmetries of Weak Interactions,1961,ĐĐĐ22';
my $nty         = 'mm,,Glashow_Sheldon,Partial Symmetries of Weak Interactions,1961,22';
my $nyt         = 'mm,,Glashow_Sheldon,1961,Partial Symmetries of Weak Interactions,22';
my $nyvt        = 'mm,,Glashow_Sheldon,1961,22,Partial Symmetries of Weak Interactions';
my $anyt_la     = 'mm,Gla61,,Glashow_Sheldon,1961,Partial Symmetries of Weak Interactions,0000';
my $anyt        = 'mm,,,Glashow_Sheldon,1961,Partial Symmetries of Weak Interactions,0000';
my $anyvt_la    = 'mm,Gla61,,Glashow_Sheldon,1961,0022,Partial Symmetries of Weak Interactions';
my $anyvt_la2   = "mm,Hos+98,,Hostetler_Michael J+\x{10FFFD},1998,0014,Alkanethiolate gold cluster molecules with core diameters from 15 to 52 nm";
my $anyvt_la3   = "mm,HW98,,Hostetler_Michael J+Wingate_Julia E+\x{10FFFD},1998,0014,Alkanethiolate gold cluster molecules with core diameters from 15 to 52 nm";
my $anyvt_la4   = "mm,HW+98,,Hostetler_Michael J+Wingate_Julia E+\x{10FFFD},1998,0014,Alkanethiolate gold cluster molecules with core diameters from 15 to 52 nm";
my $anyvt       = 'mm,,,Glashow_Sheldon,1961,0022,Partial Symmetries of Weak Interactions';
my $ynt         = 'mm,,1961,Glashow_Sheldon,Partial Symmetries of Weak Interactions';
my $ydnt        = 'mm,,1961,Glashow_Sheldon,Partial Symmetries of Weak Interactions';
my $debug       = 'stdmodel';
my $sk1         = 'mm,,AATESTKEY,AATESTKEY,AATESTKEY,AATESTKEY';
my $ps_sc       = 'zs,,Glashow_Sheldon,,Partial Symmetries of Weak Interactions,Partial Symmetries of Weak Interactions';
my $noname      = 'mm,,Partial Symmetries of Weak Interactions,Partial Symmetries of Weak Interactions,1961,22';
my $citeorder   = '0000001';
my $lists1      = 'Marcel Dekker';
my $lists2      = 'Chichester';
my $lists3      = "IBM+\x{10FFFD}";
my $lists4      = "IBM_HP+\x{10FFFD}";
my $lists5      = 'IBM_HP_Sun_Sony';
my $dates1      = '1979,01,0200000,1980,04,08,1924,06,07,1924,07,09,1924,0002,05,192,02,03,1979,03,04,79,03,03';
my $edtypeclass1 = 'redactor,Jaffé_Philipp,Loewenfeld_Samuel+Kaltenbrunner_Ferdinand+Ewald_Paul';
my $prefix1     = 'mm,,Luzzatto_Moshe Ḥayyim,,,haLashon laRamḥal uvo sheloshah ḥiburim,2000,0000';
my $diacritic1  = 'mm,,Hasan_Alī,alHasan_ʿAlī,Hasan_Alī,Some title,2000,0000';

# These have custom presort and also an exclusion on year and title set
my $useprefix1  = 'ww,,von_Bobble_Terrence,,,0000';
my $useprefix2  = 'ww,,Bobble_Terrence_von,,,0000';

my $bibentries;

Biber::Config->setblxoption('useprefix', 1);

# regenerate information
$biber->prepare;

$bibentries = $biber->sections->get_section(0)->bibentries;
is($bibentries->entry('tvonb')->get_field('sortstring'), $useprefix1, 'von with type-specific presort, exclusions and useprefix=true' );

Biber::Config->setblxoption('useprefix', 0);

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;
is($bibentries->entry('tvonb')->get_field('sortstring'), $useprefix2, 'von with type-specific presort, exclusions and useprefix=false' );



# Testing nosort
Biber::Config->setblxoption('sorting_label', [
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
                                                 {'editor'   => {}},
                                                ],
                                                [
                                                 {},
                                                 {'translator'   => {}},
                                                ],
                                                [
                                                 {},
                                                 {'sorttitle'  => {}},
                                                 {'title'      => {}}
                                                ],
                                                [
                                                 {},
                                                 {'labelyear'       => {}}
                                                ],
                                                [
                                                 {},
                                                 {'volume'     => {}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setoption('nosort', { author => [ q/\A\p{L}{2}\p{Pd}/, q/[\x{2bf}\x{2018}]/ ],
                                     translator => [ q/\A\p{L}{2}\p{Pd}/, q/[\x{2bf}\x{2018}]/ ]});

Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));
Biber::Config->setoption('sortcase', '1');

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('luzzatto')->get_field('sortstring'), $prefix1, 'Title with nosort' );
is($bibentries->entry('hasan')->get_field('sortstring'), $diacritic1, 'Name with nosort' );

# Testing editor roles
Biber::Config->setblxoption('sorting_label', [
                                                [
                                                 {},
                                                 {'editoratype'     => {}},
                                                ],
                                                [
                                                 {},
                                                 {'editor'     => {}},
                                                ],
                                                [
                                                 {},
                                                 {'editora'     => {}},
                                                ],
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));
Biber::Config->setoption('sortcase', 0);

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('jaffe')->get_field('sortstring'), $edtypeclass1, 'Editor type/class' );


# Testing sorting using various date fields
Biber::Config->setblxoption('sorting_label', [
                                                [
                                                 {},
                                                 {'year'       => {}},
                                                ],
                                                [
                                                 {},
                                                 {'month'       => {}},
                                                ],
                                                [
                                                 {},
                                                 {'day'       => {pad_side => 'right',
                                                                  pad_width => 7}},
                                                ],
                                                [
                                                 {},
                                                 {'endyear'       => {}},
                                                ],
                                                [
                                                 {},
                                                 {'endmonth'       => {}},
                                                ],
                                                [
                                                 {},
                                                 {'endday'       => {}},
                                                ],
                                                [
                                                 {},
                                                 {'origyear'   => {'sort_direction'  => 'descending'}}
                                                ],
                                                [
                                                 {},
                                                 {'origmonth'   => {}}
                                                ],
                                                [
                                                 {},
                                                 {'origday'   => {}}
                                                ],
                                                [
                                                 {},
                                                 {'origendyear'   => {}}
                                                ],
                                                [
                                                 {},
                                                 {'origendmonth'   => {}}
                                                ],
                                                [
                                                 {},
                                                 {'origendday'   => {}}
                                                ],
                                                [
                                                 {},
                                                 {'eventendyear'   => {}}
                                                ],
                                                [
                                                 {},
                                                 {'eventendmonth'   => {pad_side => 'left',
                                                                  pad_width => 4}}
                                                ],
                                                [
                                                 {},
                                                 {'eventendday'   => {}}
                                                ],
                                                [
                                                 {},
                                                 {'eventyear'   => {'substring_side' => 'left',
                                                                   'substring_width' => 3}}
                                                ],
                                                [
                                                 {},
                                                 {'eventmonth'   => {}}
                                                ],
                                                [
                                                 {},
                                                 {'eventday'   => {}}
                                                ],
                                                [
                                                 {sort_direction => 'descending'},
                                                 {'urlendyear'   => {}}
                                                ],
                                                [
                                                 {},
                                                 {'urlendmonth'   => {}}
                                                ],
                                                [
                                                 {},
                                                 {'urlendday'   => {}}
                                                ],
                                                [
                                                 {},
                                                 {'urlyear'   => {'substring_side' => 'right',
                                                                   'substring_width' => 2}}
                                                ],
                                                [
                                                 {},
                                                 {'urlmonth'   => {}}
                                                ],
                                                [
                                                 {},
                                                 {'urlday'   => {}}
                                                ],
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('moraux')->get_field('sortstring'), $dates1, 'Very contrived but thorough test of date sorting' );

# Testing max/minITEMS with sorting using list fields
# publisher
Biber::Config->setblxoption('sorting_label', [
                                                [
                                                 {},
                                                 {'publisher'    => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('augustine')->get_field('sortstring'), $lists1, 'max/minitems test 1 (publisher)' );

# location
Biber::Config->setblxoption('sorting_label', [
                                                [
                                                 {},
                                                 {'location'    => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('cotton')->get_field('sortstring'), $lists2, 'max/minitems test 2 (location)' );


# institution
Biber::Config->setblxoption('sorting_label', [
                                                [
                                                 {},
                                                 {'institution'    => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('chiu')->get_field('sortstring'), $lists3, 'max/minitems test 3 (institution)' );

# institution with minitems=2
Biber::Config->setblxoption('minitems', 2);
Biber::Config->setblxoption('sorting_label', [
                                                [
                                                 {},
                                                 {'institution'    => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('chiu')->get_field('sortstring'), $lists4, 'max/minitems test 4 (institution - minitems=2)' );

# institution with maxitems=4, minitems=3
Biber::Config->setblxoption('maxitems', 4);
Biber::Config->setblxoption('minitems', 3);
Biber::Config->setblxoption('sorting_label', [
                                                [
                                                 {},
                                                 {'institution'    => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('chiu')->get_field('sortstring'), $lists5, 'max/minitems test 5 (institution - maxitems=4/minitems=3)' );



# nty with implicit default left, 4-digit year sort
Biber::Config->setblxoption('sorting_label', [
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
                                                 {'year'       => {}}
                                                ],
                                                [
                                                 {},
                                                 {'volume'     => {}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('knuth:ct')->get_field('sortstring'), $yearoff1, 'nty with default left offset, 4 digit year' );

# nty with left, 3-digit year sort, case sensitive
Biber::Config->setblxoption('sorting_label', [
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
                                                 {'year'       => {'substring_side' => 'left',
                                                                   'substring_width' => 3}}
                                                ],
                                                [
                                                 {},
                                                 {'volume'     => {}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));
Biber::Config->setoption('sortcase', 1);
# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('knuth:ct')->get_field('sortstring'), $yearoff2, 'nty with left offset, 3 digit year, case sensitive' );


# nty with left, 4-digit year sort, case sensitive
Biber::Config->setblxoption('sorting_label', [
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
                                                 {'year'       => {'substring_side' => 'left',
                                                                   'substring_width' => 4}}
                                                ],
                                                [
                                                 {},
                                                 {'volume'     => {}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('knuth:ct')->get_field('sortstring'), $yearoff3, 'nty with left offset, 4 digit year, case sensitive' );

# nty with right, 3-digit year sort
Biber::Config->setblxoption('sorting_label', [
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
                                                 {'year'       => {'substring_side' => 'right',
                                                                   'substring_width' => 3}}
                                                ],
                                                [
                                                 {},
                                                 {'volume'     => {}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));
Biber::Config->setoption('sortcase', 0);
# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('knuth:ct')->get_field('sortstring'), $yearoff4, 'nty with right offset, 3 digit year' );

# nty with right, 4-digit year sort
Biber::Config->setblxoption('sorting_label', [
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
                                                 {'year'       => {'substring_side' => 'right',
                                                                   'substring_width' => 4}}
                                                ],
                                                [
                                                 {},
                                                 {'volume'     => {}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('knuth:ct')->get_field('sortstring'), $yearoff5, 'nty with right offset, 4 digit year' );

# ntyd with left, 4-digit year sort
Biber::Config->setblxoption('sorting_label', [
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
                                                 {'year'       => {'substring_side'  => 'left',
                                                                   'substring_width' => 4,
                                                                   'sort_direction'  => 'descending'}}
                                                ],
                                                [
                                                 {},
                                                 {'volume'     => {}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('knuth:ct')->get_field('sortstring'), $yearoff6, 'ntyd with left offset, 4 digit year' );

# ntyd with left, 3-digit year sort
Biber::Config->setblxoption('sorting_label', [
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
                                                 {'year'       => {'substring_side'  => 'left',
                                                                   'substring_width' => 3,
                                                                   'sort_direction'  => 'descending'}}
                                                ],
                                                [
                                                 {},
                                                 {'volume'     => {}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('knuth:ct')->get_field('sortstring'), $yearoff7, 'ntyd with left offset, 3 digit year' );

# ntyd with right, 4-digit year sort
Biber::Config->setblxoption('sorting_label', [
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
                                                 {'year'       => {'substring_side'  => 'right',
                                                                   'substring_width' => 4,
                                                                   'sort_direction'  => 'descending'}}
                                                ],
                                                [
                                                 {},
                                                 {'volume'     => {}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('knuth:ct')->get_field('sortstring'), $yearoff8, 'ntyd with right offset, 4 digit year' );

# ntyd with right, 3-digit year sort
Biber::Config->setblxoption('sorting_label', [
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
                                                 {'year'       => {'substring_side' => 'right',
                                                                   'substring_width' => 3,
                                                                   'sort_direction'  => 'descending'}}
                                                ],
                                                [
                                                 {},
                                                 {'volume'     => {}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('knuth:ct')->get_field('sortstring'), $yearoff9, 'ntyd with right offset, 3 digit year' );

# nty with right-padded vol
Biber::Config->setblxoption('sorting_label', [
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
                                                 {'year'       => {}}
                                                ],
                                                [
                                                 {},
                                                 {'volume'     => {pad_side => 'right'}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $vol1, 'nty with right-padded vol' );

# nty with right-padded 7-char vol
Biber::Config->setblxoption('sorting_label', [
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
                                                 {'year'       => {}}
                                                ],
                                                [
                                                 {},
                                                 {'volume'     => {pad_side => 'right',
                                                                  pad_width => 7}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $vol2, 'nty with right-padded 7-char vol' );

# nty with left-padded 5-char using Unicode "Đ" as pad_char vol
# Unicode char will be lowercase "đ" in sortstring
Biber::Config->setblxoption('sorting_label', [
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
                                                 {'year'       => {}}
                                                ],
                                                [
                                                 {},
                                                 {'volume'     => {pad_side => 'left',
                                                                  pad_width => 5,
                                                                  pad_char => 'Đ'}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $vol3, 'nty with left-padded 5-char "a" pad char vol' );


# nty
Biber::Config->setblxoption('sorting_label', [
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
                                                 {'year'       => {}}
                                                ],
                                                [
                                                 {},
                                                 {'volume'     => {}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $nty, 'basic nty sort' );
is($bibentries->entry('angenendtsk')->get_field('sortstring'), $sk1, 'basic sortkey sort' );

# nyt
Biber::Config->setblxoption('sorting_label', [
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
                                                 {'labelname'  => {}},
                                                 {'author'     => {}},
                                                 {'editor'     => {}},
                                                 {'translator' => {}},
                                                 {'sorttitle'  => {}},
                                                 {'title'      => {}}
                                                ],
                                                [
                                                 {},
                                                 {'sortyear'   => {}},
                                                 {'year'       => {}}
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
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $nyt, 'basic nyt sort' );

# nyvt
Biber::Config->setblxoption('sorting_label', [
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
                                                 {'year'       => {}}
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
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $nyvt, 'basic nyvt sort' );

# anyt with labelalpha
Biber::Config->setblxoption('labelalpha', 1);
Biber::Config->setblxoption('sorting_label', [
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
                                                 {'year'       => {}}
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
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $anyt_la, 'anyt sort (with labelalpha)' );
Biber::Config->setblxoption('labelalpha', 0);
$bibentries->entry('stdmodel')->del_field('labelalpha');
$bibentries->entry('stdmodel')->del_field('sortlabelalpha');
$bibentries->entry('stdmodel:glashow')->del_field('labelalpha'); # it's a crossref so have to clear it here too
$bibentries->entry('stdmodel:glashow')->del_field('sortlabelalpha');

# anyt without labelalpha
# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $anyt, 'anyt sort (without labelalpha)' );

# anyvt with labelalpha
Biber::Config->setblxoption('labelalpha',1);
Biber::Config->setblxoption('sorting_label', [
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
                                                 {'year'       => {}}
                                                ],
                                                [
                                                 {},
                                                 {'volume'     => {pad_width => 4}},
                                                 {'0000'       => {}}
                                                ],
                                                [
                                                 {},
                                                 {'sorttitle'  => {}},
                                                 {'title'      => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $anyvt_la, 'anyvt sort (with labelalpha)' );
is($bibentries->entry('murray')->get_field('sortstring'), $anyvt_la2, 'anyvt sort (> maxnames=3 minnames=1, with labelalpha and alphaothers)' );

Biber::Config->setblxoption('maxnames', 2);
Biber::Config->setblxoption('minnames', 2);

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('murray')->get_field('sortstring'), $anyvt_la4, 'anyvt sort (> maxnames=2 minnames=2, with labelalpha and alphaothers)' );

Biber::Config->setblxoption('alphaothers', '');
Biber::Config->setblxoption('sortalphaothers', '');

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('murray')->get_field('sortstring'), $anyvt_la3, 'anyvt sort (> maxnames=2 minnames=2,with labelalpha and without alphaothers)' );

Biber::Config->setblxoption('labelalpha', 0);
$bibentries->entry('stdmodel')->del_field('labelalpha');
$bibentries->entry('stdmodel')->del_field('sortlabelalpha');
$bibentries->entry('stdmodel:glashow')->del_field('labelalpha'); # it's a crossref so have to clear it here too
$bibentries->entry('stdmodel:glashow')->del_field('sortlabelalpha');
$bibentries->entry('murray')->del_field('labelalpha');
$bibentries->entry('murray')->del_field('sortlabelalpha');

# anyvt without labelalpha

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $anyvt, 'anyvt sort (without labelalpha)' );

# ynt
Biber::Config->setblxoption('sorting_label', [
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
                                                 {'labelyear'  => {}},
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
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $ynt, 'basic ynt sort' );

# ydnt
Biber::Config->setblxoption('sorting_label', [
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
                                                 {'sortyear'   => {}},
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
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $ydnt, 'basic ydnt sort' );
Biber::Config->setblxoption('labelalpha', 0);

# debug
Biber::Config->setblxoption('sorting_label', [
                                                [
                                                 {},
                                                 {'entrykey'    => {}},
                                                ],
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $debug, 'basic debug sort' );

# nty with modified presort and short_circuit at title
Biber::Config->setblxoption('sorting_label', [
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
                                                 {final          => 1,
                                                  },
                                                 {'sorttitle'  => {}},
                                                 {'title'      => {}}
                                                ],
                                                [
                                                 {},
                                                 {'sortyear'   => {}},
                                                 {'year'       => {}}
                                                ],
                                                [
                                                 {},
                                                 {'volume'     => {}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;
is($bibentries->entry('stdmodel:ps_sc')->get_field('sortstring'), $ps_sc, 'nty with modified presort and short-circuit title' );

# nty with use* all off
Biber::Config->setblxoption('useauthor', 0);
Biber::Config->setblxoption('useeditor', 0);
Biber::Config->setblxoption('usetranslator', 0);
Biber::Config->setblxoption('sorting_label', [
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
                                                 {'year'       => {}}
                                                ],
                                                [
                                                 {},
                                                 {'volume'     => {}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $noname, 'nty with use* all off' );

# citeorder sort

Biber::Config->setblxoption('sorting_label', [
                                                [
                                                 {},
                                                 {'citeorder'    => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section(0)->bibentries;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $citeorder, 'citeorder' );


unlink "*.utf8";
