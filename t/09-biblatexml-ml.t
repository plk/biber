use strict;
use warnings;
use utf8;
use Test::More tests => 8;

use Biber;
my $opts = { displaymode => 'romanized' } ;
my $biber = Biber->new($opts);

chdir("t/tdata") ;
$biber->parse_auxfile('examples-ml.aux');
my $bibfile = $biber->config('bibdata')->[0] ;
$Biber::localoptions{"BulgakovRozenfeld:1983"}{displaymode} = 'original' ;
$Biber::localoptions{"KiyosiFestschrift"}{displaymode} = 'translated' ;

is($biber->get_displaymode('KiyosiFestschrift')->[0], 'translated', 'getdisplaymode') ;

$biber->parse_biblatexml($bibfile) ;

is($biber->{bib}->{'Ani:1972'}->{title}, "al-Durr al-multaqaṭ fī tabyīn al-ghalaṭ li-l-Ṣaghānī", "title romanized") ;
is($biber->{bib}->{'Ani:1972'}->{publisher}->[0], "Qism al-lugha al-ʿarabiyya – Kulliyyat al-ādāb – Jāmiʿat Baghdād", "publisher romanized") ;
is($biber->{bib}->{'Ani:1972'}->{year}, "1972", "year (gregorian)") ;
is($biber->{bib}->{'Ani:1972'}->{localyear}, "1392", "year (original)") ;
is($biber->{bib}->{'Ani:1972'}->{localyearcalendar}, "islamic", "localyearcalendar") ;

is($biber->{bib}->{'BulgakovRozenfeld:1983'}->{title}, 'Мухаммад ибн муса ал-Хорезми. Около 783 – около 850', 'title original') ;

is($biber->{bib}->{'KiyosiFestschrift'}->{title}, 'Science and Skills in Asia. A Festschrift for the 77-th Birthday of Professor Yabuuti Kiyosi', 'title translated') ;


