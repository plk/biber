use strict;
use warnings;
use utf8;
use Storable qw (dclone);
no warnings 'utf8';

use Test::More tests => 39;

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
Biber::Config->setoption('locale', 'C');
Biber::Config->setoption('quiet', 1);
Biber::Config->setoption('bibencoding', 'utf8');

my $yearoff1    = 'mm0knuth2donald e0computers typesetting0198400000';
my $yearoff2    = 'mm0knuth2donald e0computers typesetting019800000';
my $yearoff3    = 'mm0knuth2donald e0computers typesetting0198400000';
my $yearoff4    = 'mm0knuth2donald e0computers typesetting098400000';
my $yearoff5    = 'mm0knuth2donald e0computers typesetting0198400000';
my $yearoff6    = 'mm0knuth2donald e0computers typesetting0801500000';
my $yearoff7    = 'mm0knuth2donald e0computers typesetting0980100000';
my $yearoff8    = 'mm0knuth2donald e0computers typesetting0801500000';
my $yearoff9    = 'mm0knuth2donald e0computers typesetting0901500000';
my $vol1        = 'mm0glashow2sheldon0partial symmetries of weak interactions0196102200';
my $vol2        = 'mm0glashow2sheldon0partial symmetries of weak interactions0196102200000';
my $vol3        = 'mm0glashow2sheldon0partial symmetries of weak interactions019610aaa22';
my $nty         = 'mm0glashow2sheldon0partial symmetries of weak interactions0196100022';
my $nyt         = 'mm0glashow2sheldon019610partial symmetries of weak interactions00022';
my $nyvt        = 'mm0glashow2sheldon01961000220partial symmetries of weak interactions';
my $anyt_la     = 'mm0gla610glashow2sheldon019610partial symmetries of weak interactions00000';
my $anyt        = 'mm0glashow2sheldon019610partial symmetries of weak interactions00000';
my $anyvt_la    = 'mm0gla610glashow2sheldon01961000220partial symmetries of weak interactions';
my $anyvt_la2   = 'mm0hos+980hostetler2michael j1zzzz01998000140alkanethiolate gold cluster molecules with core diameters from 15 to 52 nm';
my $anyvt_la3   = 'mm0hw980hostetler2michael j1wingate2julia e1zzzz01998000140alkanethiolate gold cluster molecules with core diameters from 15 to 52 nm';
my $anyvt_la4   = 'mm0hw+980hostetler2michael j1wingate2julia e1zzzz01998000140alkanethiolate gold cluster molecules with core diameters from 15 to 52 nm';
my $anyvt       = 'mm0glashow2sheldon01961000220partial symmetries of weak interactions';
my $ynt         = 'mm019610glashow2sheldon0partial symmetries of weak interactions';
my $ydnt        = 'mm080380glashow2sheldon0partial symmetries of weak interactions';
my $debug       = 'stdmodel';
my $sk1         = 'mm0aatestkey';
my $pt1         = 'mm081220aristotle0rhetoric of aristotle';
my $ps_sc       = 'zs0glashow2sheldon0partial symmetries of weak interactions';
my $noname      = 'mm0partial symmetries of weak interactions0partial symmetries of weak interactions0196100022';
my $citeorder   = '1';
my $lists1      = 'marcel dekker';
my $lists2      = 'chichester';
my $lists3      = 'ibm1zzzz';
my $lists4      = 'ibm2hp1zzzz';
my $lists5      = 'ibm2hp2sun2sony';
my $dates1      = '1979001002000000198000400808075006007019240070090192400002005019200200308020003004079003003';
my $edtypeclass1 = 'vol0redactor0jaffe2philipp0loewenfeld2samuel1kaltenbrunner2ferdinand1ewald2paul';
my $prefix1     = 'mm0Luzzatto2Moshe Ḥayyim0Lashon laRamḥal uvo sheloshah ḥiburim0200000000';
my $diacritic1  = 'mm0Hasan2Alī0Some title0200000000';

# Testing nosortprefix and nosortdiacritics
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
                                                 {'year'       => {}}
                                                ],
                                                [
                                                 {'volume'     => {}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));
Biber::Config->setoption('cssort', '1');

# regenerate information
$biber->prepare;
my $bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('luzzatto')->get_field('sortstring'), $prefix1, 'Title with nosortprefix' );
is($bibentries->entry('hasan')->get_field('sortstring'), $diacritic1, 'Title with nosortdiacritic' );

# Testing editor roles
Biber::Config->setblxoption('sorting_label', [
                                                [
                                                 {'editoraclass'     => {}},
                                                ],
                                                [
                                                 {'editoratype'     => {}},
                                                ],
                                                [
                                                 {'editor'     => {}},
                                                ],
                                                [
                                                 {'editora'     => {}},
                                                ],
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));
Biber::Config->setoption('cssort', '0');

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('jaffe')->get_field('sortstring'), $edtypeclass1, 'Editor type/class' );


# Testing sorting using various date fields
Biber::Config->setblxoption('sorting_label', [
                                                [
                                                 {'year'       => {}},
                                                ],
                                                [
                                                 {'month'       => {}},
                                                ],
                                                [
                                                 {'day'       => {pad_side => 'right',
                                                                  pad_width => 7}},
                                                ],
                                                [
                                                 {'endyear'       => {}},
                                                ],
                                                [
                                                 {'endmonth'       => {}},
                                                ],
                                                [
                                                 {'endday'       => {}},
                                                ],
                                                [
                                                 {'origyear'   => {'sort_direction'  => 'descending'}}
                                                ],
                                                [
                                                 {'origmonth'   => {}}
                                                ],
                                                [
                                                 {'origday'   => {}}
                                                ],
                                                [
                                                 {'origendyear'   => {}}
                                                ],
                                                [
                                                 {'origendmonth'   => {}}
                                                ],
                                                [
                                                 {'origendday'   => {}}
                                                ],
                                                [
                                                 {'eventendyear'   => {}}
                                                ],
                                                [
                                                 {'eventendmonth'   => {pad_side => 'left',
                                                                  pad_width => 4}}
                                                ],
                                                [
                                                 {'eventendday'   => {}}
                                                ],
                                                [
                                                 {'eventyear'   => {'substring_side' => 'left',
                                                                   'substring_width' => 3}}
                                                ],
                                                [
                                                 {'eventmonth'   => {}}
                                                ],
                                                [
                                                 {'eventday'   => {}}
                                                ],
                                                [
                                                 {'urlendyear'   => {'sort_direction'  => 'descending'}}
                                                ],
                                                [
                                                 {'urlendmonth'   => {}}
                                                ],
                                                [
                                                 {'urlendday'   => {}}
                                                ],
                                                [
                                                 {'urlyear'   => {'substring_side' => 'right',
                                                                   'substring_width' => 2}}
                                                ],
                                                [
                                                 {'urlmonth'   => {}}
                                                ],
                                                [
                                                 {'urlday'   => {}}
                                                ],
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('moraux')->get_field('sortstring'), $dates1, 'Very contrived but thorough test of date sorting' );

# Testing max/minITEMS with sorting using list fields
# publisher
Biber::Config->setblxoption('sorting_label', [
                                                [
                                                 {'publisher'    => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('augustine')->get_field('sortstring'), $lists1, 'max/minitems test 1 (publisher)' );

# location
Biber::Config->setblxoption('sorting_label', [
                                                [
                                                 {'location'    => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('cotton')->get_field('sortstring'), $lists2, 'max/minitems test 2 (location)' );


# institution
Biber::Config->setblxoption('sorting_label', [
                                                [
                                                 {'institution'    => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('chiu')->get_field('sortstring'), $lists3, 'max/minitems test 3 (institution)' );

# institution with minitems=2
Biber::Config->setblxoption('minitems', 2);
Biber::Config->setblxoption('sorting_label', [
                                                [
                                                 {'institution'    => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('chiu')->get_field('sortstring'), $lists4, 'max/minitems test 4 (institution - minitems=2)' );

# institution with maxitems=4, minitems=3
Biber::Config->setblxoption('maxitems', 4);
Biber::Config->setblxoption('minitems', 3);
Biber::Config->setblxoption('sorting_label', [
                                                [
                                                 {'institution'    => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('chiu')->get_field('sortstring'), $lists5, 'max/minitems test 5 (institution - maxitems=4/minitems=3)' );



# nty with implicit default left, 4-digit year sort
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
                                                 {'year'       => {}}
                                                ],
                                                [
                                                 {'volume'     => {}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('knuth:ct')->get_field('sortstring'), $yearoff1, 'nty with default left offset, 4 digit year' );

# nty with left, 3-digit year sort
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
                                                 {'year'       => {'substring_side' => 'left',
                                                                   'substring_width' => 3}}
                                                ],
                                                [
                                                 {'volume'     => {}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('knuth:ct')->get_field('sortstring'), $yearoff2, 'nty with left offset, 3 digit year' );


# nty with left, 4-digit year sort
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
                                                 {'year'       => {'substring_side' => 'left',
                                                                   'substring_width' => 4}}
                                                ],
                                                [
                                                 {'volume'     => {}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('knuth:ct')->get_field('sortstring'), $yearoff3, 'nty with left offset, 4 digit year' );

# nty with right, 3-digit year sort
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
                                                 {'year'       => {'substring_side' => 'right',
                                                                   'substring_width' => 3}}
                                                ],
                                                [
                                                 {'volume'     => {}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('knuth:ct')->get_field('sortstring'), $yearoff4, 'nty with right offset, 3 digit year' );

# nty with right, 4-digit year sort
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
                                                 {'year'       => {'substring_side' => 'right',
                                                                   'substring_width' => 4}}
                                                ],
                                                [
                                                 {'volume'     => {}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('knuth:ct')->get_field('sortstring'), $yearoff5, 'nty with right offset, 4 digit year' );

# ntyd with left, 4-digit year sort
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
                                                 {'year'       => {'substring_side'  => 'left',
                                                                   'substring_width' => 4,
                                                                   'sort_direction'  => 'descending'}}
                                                ],
                                                [
                                                 {'volume'     => {}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('knuth:ct')->get_field('sortstring'), $yearoff6, 'ntyd with left offset, 4 digit year' );

# ntyd with left, 3-digit year sort
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
                                                 {'year'       => {'substring_side'  => 'left',
                                                                   'substring_width' => 3,
                                                                   'sort_direction'  => 'descending'}}
                                                ],
                                                [
                                                 {'volume'     => {}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('knuth:ct')->get_field('sortstring'), $yearoff7, 'ntyd with left offset, 3 digit year' );

# ntyd with right, 4-digit year sort
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
                                                 {'year'       => {'substring_side'  => 'right',
                                                                   'substring_width' => 4,
                                                                   'sort_direction'  => 'descending'}}
                                                ],
                                                [
                                                 {'volume'     => {}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('knuth:ct')->get_field('sortstring'), $yearoff8, 'ntyd with right offset, 4 digit year' );

# ntyd with right, 3-digit year sort
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
                                                 {'year'       => {'substring_side' => 'right',
                                                                   'substring_width' => 3,
                                                                   'sort_direction'  => 'descending'}}
                                                ],
                                                [
                                                 {'volume'     => {}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('knuth:ct')->get_field('sortstring'), $yearoff9, 'ntyd with right offset, 3 digit year' );

# nty with right-padded vol
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
                                                 {'volume'     => {pad_side => 'right'}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $vol1, 'nty with right-padded vol' );

# nty with right-padded 7-char vol
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
                                                 {'volume'     => {pad_side => 'right',
                                                                  pad_width => 7}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $vol2, 'nty with right-padded 7-char vol' );

# nty with left-padded 5-char using "a" as pad_char vol
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
                                                 {'volume'     => {pad_side => 'left',
                                                                  pad_width => 5,
                                                                  pad_char => 'a'}},
                                                 {'0000'       => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $vol3, 'nty with left-padded 5-char "a" pad char vol' );


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

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $nty, 'basic nty sort' );
is($bibentries->entry('angenendtsk')->get_field('sortstring'), $sk1, 'basic sortkey sort' );

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

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $nyt, 'basic nyt sort' );

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

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $nyvt, 'basic nyvt sort' );

# anyt with labelalpha
Biber::Config->setblxoption('labelalpha', 1);
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

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $anyt_la, 'anyt sort (with labelalpha)' );
Biber::Config->setblxoption('labelalpha', 0);
$bibentries->entry('stdmodel')->del_field('labelalpha');
$bibentries->entry('stdmodel')->del_field('sortlabelalpha');
$bibentries->entry('stdmodel:glashow')->del_field('labelalpha'); # it's a crossref so have to clear it here too
$bibentries->entry('stdmodel:glashow')->del_field('sortlabelalpha');

# anyt without labelalpha
# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $anyt, 'anyt sort (without labelalpha)' );

# anyvt with labelalpha
Biber::Config->setblxoption('labelalpha',1);
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

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $anyvt_la, 'anyvt sort (with labelalpha)' );
is($bibentries->entry('murray')->get_field('sortstring'), $anyvt_la2, 'anyvt sort (> maxnames=3 minnames=1, with labelalpha and alphaothers)' );

Biber::Config->setblxoption('maxnames', 2);
Biber::Config->setblxoption('minnames', 2);

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('murray')->get_field('sortstring'), $anyvt_la4, 'anyvt sort (> maxnames=2 minnames=2, with labelalpha and alphaothers)' );

Biber::Config->setblxoption('alphaothers', '');
Biber::Config->setblxoption('sortalphaothers', '');

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

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
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $anyvt, 'anyvt sort (without labelalpha)' );

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

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $ynt, 'basic ynt sort' );

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
                                                 {'sortyear'   => {'sort_direction'  => 'descending'}},
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

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $ydnt, 'basic ydnt sort' );
Biber::Config->setblxoption('labelalpha', 0);

# debug
Biber::Config->setblxoption('sorting_label', [
                                                [
                                                 {'debug'    => {}},
                                                ],
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $debug, 'basic debug sort' );

# per-type (book, ydnt)
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
                                               ],
			    'PER_TYPE',
			    'book');
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label', 'book'), 'PER_TYPE', 'book');

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('aristotle:rhetoric')->get_field('sortstring'), $pt1, 'book type ydnt sort' );

# nty with modified presort and short_circuit at title
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
                                                 {'sorttitle'  => {'final' => 1}},
                                                 {'title'      => {'final' => 1}}
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

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('stdmodel:ps_sc')->get_field('sortstring'), $ps_sc, 'nty with modified presort and short-circuit title' );

# nty with use* all off
Biber::Config->setblxoption('useauthor', 0);
Biber::Config->setblxoption('useeditor', 0);
Biber::Config->setblxoption('usetranslator', 0);
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

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $noname, 'nty with use* all off' );

# citeorder sort

Biber::Config->setblxoption('sorting_label', [
                                                [
                                                 {'citeorder'    => {}}
                                                ]
                                               ]);
Biber::Config->setblxoption('sorting_final', Biber::Config->getblxoption('sorting_label'));

# regenerate information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bib;

is($bibentries->entry('stdmodel')->get_field('sortstring'), $citeorder, 'citeorder' );


