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

my $sa  = 'shortauthor';
my $a   = 'author';
my $ted = 'editor';

$biber->{config}{biblatex}{global}{labelname} = ['shortauthor', 'author', 'shorteditor', 'editor', 'translator'];
$biber->{config}{biblatex}{book}{labelname} = ['editor', 'translator'];

$biber->prepare;
is($biber->{bib}{angenendtsa}{labelnamename}, $sa, 'global shortauthor' );
is($biber->{bib}{stdmodel}{labelnamename}, $a, 'global author' );
is($biber->{bib}{'aristotle:anima'}{labelnamename}, $ted, 'type-specific editor' );



