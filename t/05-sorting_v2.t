use strict;
use warnings;
use utf8;
use Storable qw (dclone);
no warnings 'utf8';

use Test::More tests => 39;

use Biber;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

chdir("t/tdata");

my $bibfile;
my $biber = Biber->new;
$biber->{config}{fastsort} = 1;
$biber->{config}{locale} = 'C';
$biber->parse_auxfile_v2("50-style-authoryear_v2.aux");
$bibfile = $biber->config('bibdata')->[0] . '.bib';
$biber->parse_bibtex($bibfile);

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
my $anyvt_la2   = 'mm0hos+980hostetler2michael j1zzzz01998000140alkanethiolate gold cluster molecules with core diameters from 15 to 52nm';
my $anyvt_la3   = 'mm0hw980hostetler2michael j1wingate2julia e1zzzz01998000140alkanethiolate gold cluster molecules with core diameters from 15 to 52nm';
my $anyvt_la4   = 'mm0hw+980hostetler2michael j1wingate2julia e1zzzz01998000140alkanethiolate gold cluster molecules with core diameters from 15 to 52nm';
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
my $prefix1     = 'mm0luzzatto2moshe ḥayyim0lashon laramḥal uvo sheloshah ḥiburim meet mosheh ḥayim lutsaṭo0200000000';
my $diacritic1  = 'mm0hasan2alī0some title0200000000';

# Testing nosortprefix and nosortdiacritics
$biber->{config}{biblatex}{global}{sorting_label} =  [
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
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});
$biber->prepare;
is($biber->{bib}{luzzatto}{sortstring}, $prefix1, 'Title with nosortprefix' );
is($biber->{bib}{hasan}{sortstring}, $diacritic1, 'Title with nosortdiacritic' );

# Testing editor roles
$biber->{config}{biblatex}{global}{sorting_label} =  [
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
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});
$biber->prepare;
is($biber->{bib}{jaffe}{sortstring}, $edtypeclass1, 'Editor type/class' );


# Testing sorting using various date fields
$biber->{config}{biblatex}{global}{sorting_label} =  [
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
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});
$biber->prepare;
is($biber->{bib}{moraux}{sortstring}, $dates1, 'Very contrived but thorough test of date sorting' );

# Testing max/minITEMS with sorting using list fields
# publisher
$biber->{config}{biblatex}{global}{sorting_label} =  [
                                                [
                                                 {'publisher'    => {}}
                                                ]
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});
$biber->prepare;
is($biber->{bib}{augustine}{sortstring}, $lists1, 'max/minitems test 1 (publisher)' );

# location
$biber->{config}{biblatex}{global}{sorting_label} =  [
                                                [
                                                 {'location'    => {}}
                                                ]
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});
$biber->prepare;
is($biber->{bib}{cotton}{sortstring}, $lists2, 'max/minitems test 2 (location)' );


# institution
$biber->{config}{biblatex}{global}{sorting_label} =  [
                                                [
                                                 {'institution'    => {}}
                                                ]
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});
$biber->prepare;
is($biber->{bib}{chiu}{sortstring}, $lists3, 'max/minitems test 3 (institution)' );

# institution with minitems=2
$biber->{config}{biblatex}{global}{minitems} = 2;
$biber->{config}{biblatex}{global}{sorting_label} =  [
                                                [
                                                 {'institution'    => {}}
                                                ]
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});
$biber->prepare;
is($biber->{bib}{chiu}{sortstring}, $lists4, 'max/minitems test 4 (institution - minitems=2)' );

# institution with maxitems=4, minitems=3
$biber->{config}{biblatex}{global}{maxitems} = 4;
$biber->{config}{biblatex}{global}{minitems} = 3;
$biber->{config}{biblatex}{global}{sorting_label} =  [
                                                [
                                                 {'institution'    => {}}
                                                ]
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});
$biber->prepare;
is($biber->{bib}{chiu}{sortstring}, $lists5, 'max/minitems test 5 (institution - maxitems=4/minitems=3)' );



# nty with implicit default left, 4-digit year sort
$biber->{config}{biblatex}{global}{sorting_label} =  [
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
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});
$biber->prepare;
is($biber->{bib}{'knuth:ct'}{sortstring}, $yearoff1, 'nty with default left offset, 4 digit year' );

# nty with left, 3-digit year sort
$biber->{config}{biblatex}{global}{sorting_label} =  [
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
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});

$biber->prepare;
is($biber->{bib}{'knuth:ct'}{sortstring}, $yearoff2, 'nty with left offset, 3 digit year' );


# nty with left, 4-digit year sort
$biber->{config}{biblatex}{global}{sorting_label} =  [
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
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});

$biber->prepare;
is($biber->{bib}{'knuth:ct'}{sortstring}, $yearoff3, 'nty with left offset, 4 digit year' );

# nty with right, 3-digit year sort
$biber->{config}{biblatex}{global}{sorting_label} =  [
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
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});

$biber->prepare;
is($biber->{bib}{'knuth:ct'}{sortstring}, $yearoff4, 'nty with right offset, 3 digit year' );

# nty with right, 4-digit year sort
$biber->{config}{biblatex}{global}{sorting_label} =  [
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
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});

$biber->prepare;
is($biber->{bib}{'knuth:ct'}{sortstring}, $yearoff5, 'nty with right offset, 4 digit year' );

# ntyd with left, 4-digit year sort
$biber->{config}{biblatex}{global}{sorting_label} =  [
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
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});

$biber->prepare;
is($biber->{bib}{'knuth:ct'}{sortstring}, $yearoff6, 'ntyd with left offset, 4 digit year' );

# ntyd with left, 3-digit year sort
$biber->{config}{biblatex}{global}{sorting_label} =  [
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
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});

$biber->prepare;
is($biber->{bib}{'knuth:ct'}{sortstring}, $yearoff7, 'ntyd with left offset, 3 digit year' );

# ntyd with right, 4-digit year sort
$biber->{config}{biblatex}{global}{sorting_label} =  [
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
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});

$biber->prepare;
is($biber->{bib}{'knuth:ct'}{sortstring}, $yearoff8, 'ntyd with right offset, 4 digit year' );

# ntyd with right, 3-digit year sort
$biber->{config}{biblatex}{global}{sorting_label} =  [
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
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});

$biber->prepare;
is($biber->{bib}{'knuth:ct'}{sortstring}, $yearoff9, 'ntyd with right offset, 3 digit year' );

# nty with right-padded vol
$biber->{config}{biblatex}{global}{sorting_label} =  [
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
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $vol1, 'nty with right-padded vol' );

# nty with right-padded 7-char vol
$biber->{config}{biblatex}{global}{sorting_label} =  [
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
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $vol2, 'nty with right-padded 7-char vol' );

# nty with left-padded 5-char using "a" as pad_char vol
$biber->{config}{biblatex}{global}{sorting_label} =  [
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
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $vol3, 'nty with left-padded 5-char "a" pad char vol' );


# nty
$biber->{config}{biblatex}{global}{sorting_label} =  [
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
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $nty, 'basic nty sort' );
is($biber->{bib}{angenendtsk}{sortstring}, $sk1, 'basic sortkey sort' );

# nyt
$biber->{config}{biblatex}{global}{sorting_label} =  [
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
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $nyt, 'basic nyt sort' );

# nyvt
$biber->{config}{biblatex}{global}{sorting_label} =  [
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
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $nyvt, 'basic nyvt sort' );

# anyt with labelalpha
$biber->{config}{biblatex}{global}{labelalpha} = 1;
$biber->{config}{biblatex}{global}{sorting_label} =  [
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
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $anyt_la, 'anyt sort (with labelalpha)' );
$biber->{config}{biblatex}{global}{labelalpha} = 0;
delete $biber->{bib}{stdmodel}{labelalpha};
delete $biber->{bib}{stdmodel}{sortlabelalpha};
delete $biber->{bib}{'stdmodel:glashow'}{labelalpha}; # it's a crossref so have to clear it here too
delete $biber->{bib}{'stdmodel:glashow'}{sortlabelalpha};

# anyt without labelalpha
$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $anyt, 'anyt sort (without labelalpha)' );

# anyvt with labelalpha
$biber->{config}{biblatex}{global}{labelalpha} = 1;
$biber->{config}{biblatex}{global}{sorting_label} =  [
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
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $anyvt_la, 'anyvt sort (with labelalpha)' );
is($biber->{bib}{murray}{sortstring}, $anyvt_la2, 'anyvt sort (> maxnames=3 minnames=1, with labelalpha and alphaothers)' );

$biber->{config}{biblatex}{global}{maxnames} = 2;
$biber->{config}{biblatex}{global}{minnames} = 2;
$biber->prepare;
is($biber->{bib}{murray}{sortstring}, $anyvt_la4, 'anyvt sort (> maxnames=2 minnames=2, with labelalpha and alphaothers)' );

$biber->{config}{biblatex}{global}{alphaothers} = '';
$biber->{config}{biblatex}{global}{sortalphaothers} = '';
$biber->prepare;
is($biber->{bib}{murray}{sortstring}, $anyvt_la3, 'anyvt sort (> maxnames=2 minnames=2,with labelalpha and without alphaothers)' );

$biber->{config}{biblatex}{global}{labelalpha} = 0;
delete $biber->{bib}{stdmodel}{labelalpha};
delete $biber->{bib}{stdmodel}{sortlabelalpha};
delete $biber->{bib}{'stdmodel:glashow'}{labelalpha}; # it's a crossref so have to clear it here too
delete $biber->{bib}{'stdmodel:glashow'}{sortlabelalpha};
delete $biber->{bib}{murray}{labelalpha};
delete $biber->{bib}{murray}{sortlabelalpha};

# anyvt without labelalpha
$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $anyvt, 'anyvt sort (without labelalpha)' );

# ynt
$biber->{config}{biblatex}{global}{sorting_label} =  [
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
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $ynt, 'basic ynt sort' );

# ydnt
$biber->{config}{biblatex}{global}{sorting_label} =  [
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
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $ydnt, 'basic ydnt sort' );
$biber->{config}{biblatex}{global}{labelalpha} = 0;

# debug
$biber->{config}{biblatex}{global}{sorting_label} =  [
                                                [
                                                 {'debug'    => {}},
                                                ],
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $debug, 'basic debug sort' );

# per-type (book, ydnt)
$biber->{config}{biblatex}{book}{sorting_label} =  [
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
                                               ];
$biber->{config}{biblatex}{book}{sorting_final} = dclone($biber->{config}{biblatex}{book}{sorting_label});

$biber->prepare;
is($biber->{bib}{'aristotle:rhetoric'}{sortstring}, $pt1, 'book type ydnt sort' );

# nty with modified presort and short_circuit at title
$biber->{config}{biblatex}{global}{sorting_label} =  [
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
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});

$biber->prepare;
is($biber->{bib}{'stdmodel:ps_sc'}{sortstring}, $ps_sc, 'nty with modified presort and short-circuit title' );

# nty with use* all off
$biber->{config}{biblatex}{global}{useauthor} = 0;
$biber->{config}{biblatex}{global}{useeditor} = 0;
$biber->{config}{biblatex}{global}{usetranslator} = 0;
$biber->{config}{biblatex}{global}{sorting_label} =  [
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
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $noname, 'nty with use* all off' );

# citeorder sort

$biber->{config}{biblatex}{global}{sorting_label} =  [
                                                [
                                                 {'citeorder'    => {}}
                                                ]
                                               ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});
$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $citeorder, 'citeorder' );


