use strict;
use warnings;
use utf8;
use Test::More tests => 10;

use Biber;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

my $opts = {locale => 'fr_FR.utf8' } ;
my $biber = Biber->new($opts);
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

is($biber->{bib}->{'ani:1972'}->{title}, "al-Durr al-multaqaṭ fī tabyīn al-ghalaṭ li-l-Ṣaghānī", "title romanized") ;
is($biber->{bib}->{'ani:1972'}->{publisher}->[0], "Qism al-lugha al-ʿarabiyya – Kulliyyat al-ādāb – Jāmiʿat Baghdād", "publisher romanized") ;
is($biber->{bib}->{'ani:1972'}->{date}, "1972", "year (gregorian)") ;
is($biber->{bib}->{'ani:1972'}->{localdate}, "1392", "year (original)") ;
is($biber->{bib}->{'ani:1972'}->{localcalendar}, "islamic", "localcalendar") ;

is($biber->{bib}->{'bulgakovrozenfeld:1983'}->{title}, 'Мухаммад ибн муса ал-Хорезми. Около 783 – около 850', 'title original') ;

is($biber->{bib}->{'kiyosifestschrift'}->{title}, 'Science and Skills in Asia. A Festschrift for the 77-th Birthday of Professor Yabuuti Kiyosi', 'title translated') ;

is($biber->{bib}->{'djebbaraballagh:2001'}->{publisher}->[0], 'Faculté des Lettres et des Sciences Humaines de Rabat', "translated field with xml:lang");
