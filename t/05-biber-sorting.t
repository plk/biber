use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 3;

use Biber;
chdir("t/tdata");

my $bibfile;
my $biber = Biber->new;
$biber->parse_auxfile("50-style-authoryear.aux");
$biber->{config}{biblatex}{global}{maxline} = 100000;
$bibfile = $biber->config('bibdata')->[0] . ".bib";
$biber->parse_bibtex($bibfile);


my $nty  = 'mm0glashow2sheldon0partial symmetries of weak interactions0196100022';
my $nyt  = 'mm0glashow2sheldon019610partial symmetries of weak interactions00022';
my $nyvt = 'mm0glashow2sheldon01961000220partial symmetries of weak interactions';

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
is($biber->{bib}->{stdmodel}{sortstring}, $nyt, 'basic nyt sort' );

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
is($biber->{bib}->{stdmodel}{sortstring}, $nyvt, 'basic nyvt sort' );
