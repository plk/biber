use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 23;

use Biber;
chdir("t/tdata");

my $bibfile;
my $biber = Biber->new;
$biber->{config}{fastsort} = 1;
$biber->{config}{locale} = "C";
$biber->parse_auxfile_v2("50-style-authoryear_v2.aux");
$biber->{config}{biblatex}{global}{maxline} = 100000;
$bibfile = $biber->config('bibdata')->[0] . ".bib";
$biber->parse_bibtex($bibfile);

my $yearoff1    = 'mm00knuth2donald e0computers typesetting0198400000';
my $yearoff2    = 'mm00knuth2donald e0computers typesetting019800000';
my $yearoff3    = 'mm00knuth2donald e0computers typesetting0198400000';
my $yearoff4    = 'mm00knuth2donald e0computers typesetting098600000';
my $yearoff5    = 'mm00knuth2donald e0computers typesetting0198600000';
my $yearoff6    = 'mm00knuth2donald e0computers typesetting0801500000';
my $yearoff7    = 'mm00knuth2donald e0computers typesetting0980100000';
my $yearoff8    = 'mm00knuth2donald e0computers typesetting0801300000';
my $yearoff9    = 'mm00knuth2donald e0computers typesetting0901300000';
my $nty         = 'mm00glashow2sheldon0partial symmetries of weak interactions0196100022';
my $nyt         = 'mm00glashow2sheldon019610partial symmetries of weak interactions00022';
my $nyvt        = 'mm00glashow2sheldon01961000220partial symmetries of weak interactions';
my $anyt_la     = 'mm0gla6100glashow2sheldon019610partial symmetries of weak interactions00000';
my $anyt        = 'mm000glashow2sheldon019610partial symmetries of weak interactions00000';
my $anyvt_la    = 'mm0gla6100glashow2sheldon01961000220partial symmetries of weak interactions';
my $anyvt       = 'mm000glashow2sheldon01961000220partial symmetries of weak interactions';
my $ynt         = 'mm0019610glashow2sheldon0partial symmetries of weak interactions';
my $ydnt        = 'mm0080380glashow2sheldon0partial symmetries of weak interactions';
my $debug       = 'stdmodel';
my $sk1         = 'mm0aatestkey';
my $pt1         = 'mm0081220aristotle0rhetoric of aristotle';
my $ps_sc       = 'zs00glashow2sheldon0partial symmetries of weak interactions';
my $noname      = 'mm00partial symmetries of weak interactions0partial symmetries of weak interactions0196100022';

# nty with implicit default left, 4-digit year sort
$biber->{config}{biblatex}{global}{sorting} =  [
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

$biber->prepare;
is($biber->{bib}{'knuth:ct'}{sortstring}, $yearoff1, 'nty with default left offset, 4 digit year' );

# nty with left, 3-digit year sort
$biber->{config}{biblatex}{global}{sorting} =  [
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

$biber->prepare;
is($biber->{bib}{'knuth:ct'}{sortstring}, $yearoff2, 'nty with left offset, 3 digit year' );


# nty with left, 4-digit year sort
$biber->{config}{biblatex}{global}{sorting} =  [
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

$biber->prepare;
is($biber->{bib}{'knuth:ct'}{sortstring}, $yearoff3, 'nty with left offset, 4 digit year' );

# nty with right, 3-digit year sort
$biber->{config}{biblatex}{global}{sorting} =  [
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

$biber->prepare;
is($biber->{bib}{'knuth:ct'}{sortstring}, $yearoff4, 'nty with right offset, 3 digit year' );

# nty with right, 4-digit year sort
$biber->{config}{biblatex}{global}{sorting} =  [
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

$biber->prepare;
is($biber->{bib}{'knuth:ct'}{sortstring}, $yearoff5, 'nty with right offset, 4 digit year' );

# ntyd with left, 4-digit year sort
$biber->{config}{biblatex}{global}{sorting} =  [
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
                                                 {'yearD'       => {'substring_side' => 'left',
                                                                   'substring_width' => 4}}
                                                ],
                                                [
                                                 {'volume'     => {}},
                                                 {'0000'       => {}}
                                                ]
                                               ];

$biber->prepare;
is($biber->{bib}{'knuth:ct'}{sortstring}, $yearoff6, 'ntyd with left offset, 4 digit year' );

# ntyd with left, 3-digit year sort
$biber->{config}{biblatex}{global}{sorting} =  [
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
                                                 {'yearD'       => {'substring_side' => 'left',
                                                                   'substring_width' => 3}}
                                                ],
                                                [
                                                 {'volume'     => {}},
                                                 {'0000'       => {}}
                                                ]
                                               ];

$biber->prepare;
is($biber->{bib}{'knuth:ct'}{sortstring}, $yearoff7, 'ntyd with left offset, 3 digit year' );

# ntyd with right, 4-digit year sort
$biber->{config}{biblatex}{global}{sorting} =  [
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
                                                 {'yearD'       => {'substring_side' => 'right',
                                                                   'substring_width' => 4}}
                                                ],
                                                [
                                                 {'volume'     => {}},
                                                 {'0000'       => {}}
                                                ]
                                               ];

$biber->prepare;
is($biber->{bib}{'knuth:ct'}{sortstring}, $yearoff8, 'ntyd with right offset, 4 digit year' );

# ntyd with right, 3-digit year sort
$biber->{config}{biblatex}{global}{sorting} =  [
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
                                                 {'yearD'       => {'substring_side' => 'right',
                                                                   'substring_width' => 3}}
                                                ],
                                                [
                                                 {'volume'     => {}},
                                                 {'0000'       => {}}
                                                ]
                                               ];

$biber->prepare;
is($biber->{bib}{'knuth:ct'}{sortstring}, $yearoff9, 'ntyd with right offset, 3 digit year' );


# nty
$biber->{config}{biblatex}{global}{sorting} =  [
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

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $nty, 'basic nty sort' );
is($biber->{bib}{angenendtsk}{sortstring}, $sk1, 'basic sortkey sort' );

# nyt
$biber->{config}{biblatex}{global}{sorting} =  [
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

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $nyt, 'basic nyt sort' );

# nyvt
$biber->{config}{biblatex}{global}{sorting} =  [
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

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $nyvt, 'basic nyvt sort' );

# anyt with labelalpha
$biber->{config}{biblatex}{global}{labelalpha} = 1;
$biber->{config}{biblatex}{global}{sorting} =  [
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

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $anyt_la, 'basic anyt sort (with labelalpha)' );
$biber->{config}{biblatex}{global}{labelalpha} = 0;
delete $biber->{bib}{stdmodel}{labelalpha};
delete $biber->{bib}{'stdmodel:glashow'}{labelalpha}; # it's a crossref so have to clear it here too

# anyt without labelalpha
$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $anyt, 'basic anyt sort (without labelalpha)' );

# anyvt with labelalpha
$biber->{config}{biblatex}{global}{labelalpha} = 1;
$biber->{config}{biblatex}{global}{sorting} =  [
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

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $anyvt_la, 'basic anyvt sort (with labelalpha)' );
$biber->{config}{biblatex}{global}{labelalpha} = 0;
delete $biber->{bib}{stdmodel}{labelalpha};
delete $biber->{bib}{'stdmodel:glashow'}{labelalpha}; # it's a crossref so have to clear it here too

# anyvt without labelalpha
$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $anyvt, 'basic anyvt sort (without labelalpha)' );

# ynt
$biber->{config}{biblatex}{global}{sorting} =  [
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

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $ynt, 'basic ynt sort' );

# ydnt
$biber->{config}{biblatex}{global}{sorting} =  [
                                                [
                                                 {'presort'    => {}},
                                                 {'mm'         => {}},
                                                ],
                                                [
                                                 {'sortkey'    => {'final' => 1}}
                                                ],
                                                [
                                                 {'sortyearD'  => {}},
                                                 {'yearD'      => {}},
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

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $ydnt, 'basic ydnt sort' );
$biber->{config}{biblatex}{global}{labelalpha} = 0;

# debug
$biber->{config}{biblatex}{global}{sorting} =  [
                                                [
                                                 {'debug'    => {}},
                                                ],
                                               ];

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $debug, 'basic debug sort' );

# per-type (book, ydnt)
$biber->{config}{biblatex}{book}{sorting} =  [
                                                [
                                                 {'presort'    => {}},
                                                 {'mm'         => {}},
                                                ],
                                                [
                                                 {'sortkey'    => {'final' => 1}}
                                                ],
                                                [
                                                 {'sortyearD'  => {}},
                                                 {'yearD'      => {}},
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

$biber->prepare;
is($biber->{bib}{'aristotle:rhetoric'}{sortstring}, $pt1, 'book type ydnt sort' );

# nty with modified presort and short_circuit at title
$biber->{config}{biblatex}{global}{sorting} =  [
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

$biber->prepare;
is($biber->{bib}{'stdmodel:ps_sc'}{sortstring}, $ps_sc, 'nty with modified presort and short-circuit title' );

# nty with use* all off
$biber->{config}{biblatex}{global}{useauthor} = 0;
$biber->{config}{biblatex}{global}{useeditor} = 0;
$biber->{config}{biblatex}{global}{usetranslator} = 0;
$biber->{config}{biblatex}{global}{sorting} =  [
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

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $noname, 'nty with use* all off' );

