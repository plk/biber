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
$biber->parse_auxfile_v2("style-authoryear.aux");
$bibfile = Biber::Config->getoption('bibdata')->[0] . ".bib";
$biber->parse_bibtex($bibfile);

my $sa  = 'shortauthor';
my $a   = 'author';
my $ted = 'editor';

Biber::Config->setblxoption('labelname', ['shortauthor', 'author', 'shorteditor', 'editor', 'translator']);
Biber::Config->setblxoption('labelname', ['editor', 'translator'], 'PER_TYPE', 'book');

$biber->prepare;
my $bibentries = $biber->bib;
is($bibentries->entry('angenendtsa')->get_field('labelnamename'), $sa, 'global shortauthor' );
is($bibentries->entry('stdmodel')->get_field('labelnamename'), $a, 'global author' );
is($bibentries->entry('aristotle:anima')->get_field('labelnamename'), $ted, 'type-specific editor' );



