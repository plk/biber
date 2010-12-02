use strict;
use warnings;
use utf8;
no warnings 'utf8' ;

use Test::More tests => 8;
use Biber;
use Biber::Entry::Name;
use Biber::Entry::Names;
use Biber::Utils;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
my $biber = Biber->new(noconf => 1);

is( normalise_string('"a, b–c: d" ', 1),  'a bc d', 'normalise_string' );

Biber::Config->setoption('bblencoding', 'latin1');
is( normalise_string_underscore('\c Se\x{c}\"ok-\foo{a},  N\`i\~no
    $§+ :-)   ', 1), 'Secoka_Nino', 'normalise_string_underscore 1' );

Biber::Config->setoption('bblencoding', 'UTF-8');
is( normalise_string_underscore('\c Se\x{c}\"ok-\foo{a},  N\`i\~no
    $§+ :-)   ', 0), 'Şecöka_Nìño', 'normalise_string_underscore 2' );

is( normalise_string_underscore('{Foo de Bar, Graf Ludwig}', 1), 'Foo_de_Bar_Graf_Ludwig', 'normalise_string_underscore 2');

my $names = bless {namelist => [
    (bless { namestring => '\"Askdjksdj, Bsadk Cklsjd', nameinitstring => '\"Askdjksdj, BC' }, 'Biber::Entry::Name'),
    (bless { namestring => 'von Üsakdjskd, Vsajd W\`asdjh', nameinitstring => 'v Üsakdjskd, VW'}, 'Biber::Entry::Name'),
    (bless { namestring => 'Xaskldjdd, Yajs\x{d}ajks~Z.', nameinitstring => 'Xaskldjdd, YZ'}, 'Biber::Entry::Name'),
    (bless { namestring => 'Maksjdakj, Nsjahdajsdhj', nameinitstring => 'Maksjdakj, N'  }, 'Biber::Entry::Name')
]}, 'Biber::Entry::Names';

is( makenameid($names), 'Äskdjksdj_Bsadk_Cklsjd_von_Üsakdjskd_Vsajd_Wàsdjh_Xaskldjdd_Yajsdajks_Z_Maksjdakj_Nsjahdajsdhj', 'makenameid' );

my @arrayA = qw/ a b c d e f c /;
my @arrayB = qw/ c e /;
my @AminusB = reduce_array(\@arrayA, \@arrayB);
my @AminusBexpected = qw/ a b d f /;

is_deeply(\@AminusB, \@AminusBexpected, 'reduce_array') ;

is(remove_outer('{Some string}'), 'Some string', 'remove_outer') ;

is( normalise_string_lite('Ä.~{\c{C}}.~{\c S}.'), 'ÄCS', 'normalise_string_lite' ) ;

