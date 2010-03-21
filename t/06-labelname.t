use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 3;

use Biber;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

chdir("t/tdata");

my $bibfile;
my $biber = Biber->new(noconf => 1);

$biber->parse_auxfile("general1.aux");
$biber->parse_ctrlfile("general1.bcf");
$biber->set_output_obj(Biber::Output::BBL->new());
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



