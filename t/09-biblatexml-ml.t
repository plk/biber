use strict;
use warnings;
use utf8;
use Test::More tests => 3;

use Biber;
my $opts = { displaymode => 'romanized' } ;
my $biber = Biber->new($opts);

chdir("t/tdata") ;
$biber->parse_auxfile('examples-ml.aux');
my $bibfile = $biber->config('bibdata')->[0] ;
$biber->parse_biblatexml($bibfile) ;
$biber->prepare ;

is($biber->{bib}->{'Ani:1972'}->{title}, "al-Durr al-multaqaṭ fī tabyīn al-ghalaṭ li-l-Ṣaghānī", "romanized title") ;
is($biber->{bib}->{'Ani:1972'}->{publisher}->[0], "Qism al-lugha al-ʿarabiyya – Kulliyyat al-ādāb – Jāmiʿat Baghdād", "romanized publisher") ;
is($biber->{bib}->{'Ani:1972'}->{year}, "1972", "year") ;
