use strict;
use warnings;
use utf8;
no warnings 'utf8' ;

use Test::More tests => 10 ;

use Biber;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

my $biber = Biber->new(noconf => 1);
chdir("t/tdata") ;

my $bibfile;
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('locale', 'C');
$biber->parse_auxfile('options.aux');
$bibfile = Biber::Config->getoption('bibdata')->[0] . '.bib';
$biber->parse_bibtex($bibfile);

Biber::Config->setblxoption('labelyear', [ 'year' ]);
$biber->prepare;
my $bibentries = $biber->bib;

ok(Biber::Config->getblxoption('uniquename') == 1, "Single-valued option") ;
is_deeply(Biber::Config->getblxoption('labelname'), [ 'author' ], "Multi-valued options");
ok(Biber::Config->getoption('mincrossrefs') == 88, "Setting Biber options via control file");
ok(Biber::Config->getblxoption('useprefix', 'book') == 1 , "Per-type single-valued options");
is_deeply(Biber::Config->getblxoption('labelname', 'book'), [ 'author', 'editor' ], "Per-type multi-valued options");
is($bibentries->entry('l1')->get_field('labelyearname'), 'year', 'Global labelyear setting' ) ;
ok($bibentries->entry('l1')->get_field($bibentries->entry('l1')->get_field('labelyearname')) eq
   $bibentries->entry('l1')->get_field('year'), 'Global labelyear setting - labelyear should be YEAR') ;
is($bibentries->entry('l2')->get_field('labelyearname'), 'origyear', 'Entry-specific labelyear setting' ) ;
ok($bibentries->entry('l2')->get_field($bibentries->entry('l2')->get_field('labelyearname')) eq
   $bibentries->entry('l2')->get_field('origyear'), 'Entry-specific labelyear setting - labelyear should be ORIGYEAR') ;
is($bibentries->entry('l2')->get_field('labelnamename'), 'translator', 'Entry-specific labelname setting' ) ;

unlink "$bibfile.utf8";
