use strict;
use warnings;
use utf8;
use Test::More tests => 10;

use Biber;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

my $biber = Biber->new( locale => 'fr_FR.utf8' );
Biber::Config->set_displaymode('romanized');

chdir("t/tdata") ;
$biber->parse_auxfile('examples-ml.aux');
my $bibfile = Biber::Config->getoption('bibdata')->[0] ;
Biber::Config->set_displaymode('original', '', '', 'BulgakovRozenfeld:1983');
Biber::Config->set_displaymode('translated', undef, undef, 'KiyosiFestschrift');
Biber::Config->set_displaymode('translated', undef, undef, 'DjebbarAballagh:2001');
is(Biber::Config->get_displaymode('article', undef, 'Ani:1972')->[0], 'romanized', 'getdisplaymode 1') ;
is(Biber::Config->get_displaymode('collection', undef, 'KiyosiFestschrift')->[0], 'translated', 'getdisplaymode 2') ;

$biber->parse_biblatexml($bibfile) ;
my $bibentries = $biber->bib;
is($bibentries->entry('ani:1972')->get_field('title'), "al-Durr al-multaqaṭ fī tabyīn al-ghalaṭ li-l-Ṣaghānī", "title romanized") ;
is($bibentries->entry('ani:1972')->get_field('publisher')->[0], "Qism al-lugha al-ʿarabiyya – Kulliyyat al-ādāb – Jāmiʿat Baghdād", "publisher romanized") ;
is($bibentries->entry('ani:1972')->get_field('date'), "1972", "year (gregorian)") ;
is($bibentries->entry('ani:1972')->get_field('localdate'), "1392", "year (original)") ;
is($bibentries->entry('ani:1972')->get_field('localcalendar'), "islamic", "localcalendar") ;

is($bibentries->entry('bulgakovrozenfeld:1983')->get_field('title'), 'Мухаммад ибн муса ал-Хорезми. Около 783 – около 850', 'title original') ;

is($bibentries->entry('kiyosifestschrift')->get_field('title'), 'Science and Skills in Asia. A Festschrift for the 77-th Birthday of Professor Yabuuti Kiyosi', 'title translated') ;

is($bibentries->entry('djebbaraballagh:2001')->get_field('publisher')->[0], 'Faculté des Lettres et des Sciences Humaines de Rabat', "translated field with xml:lang");
