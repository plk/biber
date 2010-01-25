use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 3;

use Biber;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

chdir("t/tdata");

my $bibfile;
my $biber = Biber->new;
$biber->parse_auxfile_v2("50-style-authoryear_v2.aux");
$bibfile = Biber::Config->getoption('bibdata')->[0] . ".bib";
$biber->parse_bibtex($bibfile);

my $sa  = 'shortauthor';
my $a   = 'author';
my $ted = 'editor';

Biber::Config->setblxoption('labelname', ['shortauthor', 'author', 'shorteditor', 'editor', 'translator']);
Biber::Config->setblxoption('labelname', ['editor', 'translator'], 'PER_TYPE', 'book');

$biber->prepare;
is($biber->{bib}{angenendtsa}{labelnamename}, $sa, 'global shortauthor' );
is($biber->{bib}{stdmodel}{labelnamename}, $a, 'global author' );
is($biber->{bib}{'aristotle:anima'}{labelnamename}, $ted, 'type-specific editor' );



