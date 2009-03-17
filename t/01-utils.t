use strict;
use warnings;

use Test::More tests => 8;
use utf8;

use Biber::Utils;
is( normalize_string('"a, b–c: d" '),  'a bc d ', 'normalize_string' );

is( cleanstring('\c Se\x{c}\"ok-\foo{a},  N\`i\~no
    $§+ :-)   '), 'Secoka_Nino', 'cleanstring 1' );

is( cleanstring('{Foo de Bar, Graf Ludwig}'), 'Foo_de_Bar_Graf_Ludwig', 'cleanstring 2');

my @names = ( 
    { namestring => '\"Askdjksdj, Bsadk Cklsjd', nameinitstring => '\"Askdjksdj, BC' },
    { namestring => 'von Üsakdjskd, Vsajd W\`asdjh', nameinitstring => 'v Üsakdjskd, VW'  },
    { namestring => 'Xaskldjdd, Yajs\x{d}ajks~Z.', nameinitstring => 'Xaskldjdd, YZ'  },
    { namestring => 'Maksjdakj, Nsjahdajsdhj', nameinitstring => 'Maksjdakj, N'  },
);

is( makenameid(@names), 'Askdjksdj_Bsadk_Cklsjd_von_Üsakdjskd_Vsajd_Wasdjh_Xaskldjdd_Yajsdajks_Z_Maksjdakj_Nsjahdajsdhj', 'makenameid' );

is( makenameinitid(@names), 'Askdjksdj_BC_v_Üsakdjskd_VW_Xaskldjdd_YZ_Maksjdakj_N', 
    'makenameinitid' );

is( latexescape('{5}: Joe & Sons: $3.01 + 5% of some_function()'), 
               '\{5\}: Joe \& Sons: \$3.01 + 5\% of some\_function()',
               'latexescape'); 

is( terseinitials('Goldman-Sachs, Antonio Ludwig '),  'GSAL', 'terseinitials');

my @arrayA = qw/ a b c d e f c /;
my @arrayB = qw/ c e /;
my @AminusB = array_minus(\@arrayA, \@arrayB);
my @AminusBexpected = qw/ a b d f /;

is_deeply(\@AminusB, \@AminusBexpected, 'array_minus') ;


