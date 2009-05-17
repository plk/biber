use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 11;

use Biber;
chdir("t/tdata");

my $bibfile;
my $biber = Biber->new;
$biber->parse_auxfile("50-style-authoryear.aux");
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

# nty
$biber->{config}{biblatex}{global}{sorting} =  [
                                                [
                                                 {'presort'    => []},
                                                 {'mm'         => []},
                                                ],
                                                [
                                                 {'sortkey'    => ['final']}
                                                ],
                                                [
                                                 {'sortname'   => []},
                                                 {'author'     => []},
                                                 {'editor'     => []},
                                                 {'translator' => []},
                                                 {'sorttitle'  => []},
                                                 {'title'      => []}
                                                ],
                                                [
                                                 {'sorttitle'  => []},
                                                 {'title'      => []}
                                                ],
                                                [
                                                 {'sortyear'   => []},
                                                 {'year'       => []}
                                                ],
                                                [
                                                 {'volume'     => []},
                                                 {'0000'       => []}
                                                ]
                                               ];

$biber->prepare;
is($biber->{bib}->{stdmodel}{sortstring}, $nty, 'basic nty sort' );
is($biber->{bib}->{angenendtsk}{sortstring}, $sk1, 'basic sortkey sort' );

# nyt
$biber->{config}{biblatex}{global}{sorting} =  [
                                                [
                                                 {'presort'    => []},
                                                 {'mm'         => []},
                                                ],
                                                [
                                                 {'sortkey'    => ['final']}
                                                ],
                                                [
                                                 {'sortname'   => []},
                                                 {'author'     => []},
                                                 {'editor'     => []},
                                                 {'translator' => []},
                                                 {'sorttitle'  => []},
                                                 {'title'      => []}
                                                ],
                                                [
                                                 {'sortyear'   => []},
                                                 {'year'       => []}
                                                ],
                                                [
                                                 {'sorttitle'  => []},
                                                 {'title'      => []}
                                                ],
                                                [
                                                 {'volume'     => []},
                                                 {'0000'       => []}
                                                ]
                                               ];

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $nyt, 'basic nyt sort' );

# nyvt
$biber->{config}{biblatex}{global}{sorting} =  [
                                                [
                                                 {'presort'    => []},
                                                 {'mm'         => []},
                                                ],
                                                [
                                                 {'sortkey'    => ['final']}
                                                ],
                                                [
                                                 {'sortname'   => []},
                                                 {'author'     => []},
                                                 {'editor'     => []},
                                                 {'translator' => []},
                                                 {'sorttitle'  => []},
                                                 {'title'      => []}
                                                ],
                                                [
                                                 {'sortyear'   => []},
                                                 {'year'       => []}
                                                ],
                                                [
                                                 {'volume'     => []},
                                                 {'0000'       => []}
                                                ],
                                                [
                                                 {'sorttitle'  => []},
                                                 {'title'      => []}
                                                ]
                                               ];

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $nyvt, 'basic nyvt sort' );

# anyt with labelalpha
$biber->{config}{biblatex}{global}{labelalpha} = 1;
$biber->{config}{biblatex}{global}{sorting} =  [
                                                [
                                                 {'presort'    => []},
                                                 {'mm'         => []},
                                                ],
                                                [
                                                 {'labelalpha' => []}
                                                ],
                                                [
                                                 {'sortkey'    => ['final']}
                                                ],
                                                [
                                                 {'sortname'   => []},
                                                 {'author'     => []},
                                                 {'editor'     => []},
                                                 {'translator' => []},
                                                 {'sorttitle'  => []},
                                                 {'title'      => []}
                                                ],
                                                [
                                                 {'sortyear'   => []},
                                                 {'year'       => []}
                                                ],
                                                [
                                                 {'sorttitle'  => []},
                                                 {'title'      => []}
                                                ],
                                                [
                                                 {'sorttitle'  => []},
                                                 {'0000'       => []}
                                                ]
                                               ];

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $anyt_la, 'basic anyt sort (with labelalpha)' );

# anyt without labelalpha
$biber->{config}{biblatex}{global}{labelalpha} = 0;
$biber->{config}{biblatex}{global}{sorting} =  [
                                                [
                                                 {'presort'    => []},
                                                 {'mm'         => []},
                                                ],
                                                [
                                                 {'labelalpha' => []}
                                                ],
                                                [
                                                 {'sortkey'    => ['final']}
                                                ],
                                                [
                                                 {'sortname'   => []},
                                                 {'author'     => []},
                                                 {'editor'     => []},
                                                 {'translator' => []},
                                                 {'sorttitle'  => []},
                                                 {'title'      => []}
                                                ],
                                                [
                                                 {'sortyear'   => []},
                                                 {'year'       => []}
                                                ],
                                                [
                                                 {'sorttitle'  => []},
                                                 {'title'      => []}
                                                ],
                                                [
                                                 {'sorttitle'  => []},
                                                 {'0000'       => []}
                                                ]
                                               ];

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $anyt, 'basic anyt sort (without labelalpha)' );


# anyvt with labelalpha
$biber->{config}{biblatex}{global}{labelalpha} = 1;
$biber->{config}{biblatex}{global}{sorting} =  [
                                                [
                                                 {'presort'    => []},
                                                 {'mm'         => []},
                                                ],
                                                [
                                                 {'labelalpha' => []}
                                                ],
                                                [
                                                 {'sortkey'    => ['final']}
                                                ],
                                                [
                                                 {'sortname'   => []},
                                                 {'author'     => []},
                                                 {'editor'     => []},
                                                 {'translator' => []},
                                                 {'sorttitle'  => []},
                                                 {'title'      => []}
                                                ],
                                                [
                                                 {'sortyear'   => []},
                                                 {'year'       => []}
                                                ],
                                                [
                                                 {'volume'     => []},
                                                 {'0000'       => []}
                                                ],
                                                [
                                                 {'sorttitle'  => []},
                                                 {'title'      => []}
                                                ]
                                               ];

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $anyvt_la, 'basic anyvt sort (with labelalpha)' );

# anyvt without labelalpha
$biber->{config}{biblatex}{global}{labelalpha} = 0;
$biber->{config}{biblatex}{global}{sorting} =  [
                                                [
                                                 {'presort'    => []},
                                                 {'mm'         => []},
                                                ],
                                                [
                                                 {'labelalpha' => []}
                                                ],
                                                [
                                                 {'sortkey'    => ['final']}
                                                ],
                                                [
                                                 {'sortname'   => []},
                                                 {'author'     => []},
                                                 {'editor'     => []},
                                                 {'translator' => []},
                                                 {'sorttitle'  => []},
                                                 {'title'      => []}
                                                ],
                                                [
                                                 {'sortyear'   => []},
                                                 {'year'       => []}
                                                ],
                                                [
                                                 {'volume'     => []},
                                                 {'0000'       => []}
                                                ],
                                                [
                                                 {'sorttitle'  => []},
                                                 {'title'      => []}
                                                ]
                                               ];

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $anyvt, 'basic anyvt sort (without labelalpha)' );

# ynt
$biber->{config}{biblatex}{global}{labelalpha} = 0;
$biber->{config}{biblatex}{global}{sorting} =  [
                                                [
                                                 {'presort'    => []},
                                                 {'mm'         => []},
                                                ],
                                                [
                                                 {'sortkey'    => ['final']}
                                                ],
                                                [
                                                 {'sortyear'   => []},
                                                 {'year'       => []},
                                                 {'9999'       => []}
                                                ],
                                                [
                                                 {'sortname'   => []},
                                                 {'author'     => []},
                                                 {'editor'     => []},
                                                 {'translator' => []},
                                                 {'sorttitle'  => []},
                                                 {'title'      => []}
                                                ],
                                                [
                                                 {'sorttitle'  => []},
                                                 {'title'      => []}
                                                ],
                                               ];

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $ynt, 'basic ynt sort' );

# ydnt
$biber->{config}{biblatex}{global}{labelalpha} = 0;
$biber->{config}{biblatex}{global}{sorting} =  [
                                                [
                                                 {'presort'    => []},
                                                 {'mm'         => []},
                                                ],
                                                [
                                                 {'sortkey'    => ['final']}
                                                ],
                                                [
                                                 {'sortyearD'  => []},
                                                 {'yearD'      => []},
                                                 {'9999'       => []}
                                                ],
                                                [
                                                 {'sortname'   => []},
                                                 {'author'     => []},
                                                 {'editor'     => []},
                                                 {'translator' => []},
                                                 {'sorttitle'  => []},
                                                 {'title'      => []}
                                                ],
                                                [
                                                 {'sorttitle'  => []},
                                                 {'title'      => []}
                                                ],
                                               ];

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $ydnt, 'basic ydnt sort' );

# debug
$biber->{config}{biblatex}{global}{labelalpha} = 0;
$biber->{config}{biblatex}{global}{sorting} =  [
                                                [
                                                 {'debug'    => []},
                                                ],
                                               ];

$biber->prepare;
is($biber->{bib}{stdmodel}{sortstring}, $debug, 'basic debug sort' );
