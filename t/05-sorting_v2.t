use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 14;

use Biber;
chdir("t/tdata");

my $bibfile;
my $biber = Biber->new;
$biber->parse_auxfile_v2("50-style-authoryear_v2.aux");
$biber->{config}{biblatex}{global}{maxline} = 100000;
$bibfile = $biber->config('bibdata')->[0] . ".bib";
$biber->parse_bibtex($bibfile);

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

