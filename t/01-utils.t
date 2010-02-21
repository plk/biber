use strict;
use warnings;
use utf8;
no warnings 'utf8' ;

use Test::More tests => 28;
use Biber;
use Biber::BibTeX;
use Biber::Entry::Name;
use Biber::Entry::Names;
use Biber::Utils;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
my $biber = Biber->new();

is( normalize_string('"a, b–c: d" ', 1),  'a bc d', 'normalize_string' );

is( normalize_string_underscore('\c Se\x{c}\"ok-\foo{a},  N\`i\~no
    $§+ :-)   ', 1), 'Secoka_Nino', 'normalize_string_underscore 1' );

is( normalize_string_underscore('\c Se\x{c}\"ok-\foo{a},  N\`i\~no
    $§+ :-)   ', 0), 'Şecöka_Nìño', 'normalize_string_underscore 1' );

is( normalize_string_underscore('{Foo de Bar, Graf Ludwig}', 1), 'Foo_de_Bar_Graf_Ludwig', 'normalize_string_underscore 2');

my $names = bless [
    (bless { namestring => '\"Askdjksdj, Bsadk Cklsjd', nameinitstring => '\"Askdjksdj, BC' }, 'Biber::Entry::Name'),
    (bless { namestring => 'von Üsakdjskd, Vsajd W\`asdjh', nameinitstring => 'v Üsakdjskd, VW'}, 'Biber::Entry::Name'),
    (bless { namestring => 'Xaskldjdd, Yajs\x{d}ajks~Z.', nameinitstring => 'Xaskldjdd, YZ'}, 'Biber::Entry::Name'),
    (bless { namestring => 'Maksjdakj, Nsjahdajsdhj', nameinitstring => 'Maksjdakj, N'  }, 'Biber::Entry::Name')
], 'Biber::Entry::Names';

is( makenameid($names), 'Askdjksdj_Bsadk_Cklsjd_von_Üsakdjskd_Vsajd_Wasdjh_Xaskldjdd_Yajsdajks_Z_Maksjdakj_Nsjahdajsdhj', 'makenameid' );


is( latexescape('Joe & Sons: $3.01 + 5% of some_function()'),
               'Joe \& Sons: \$3.01 + 5\% of some\_function()',
               'latexescape'); 

is( terseinitials('G.-S.'),  'GS', 'terseinitials');

my @arrayA = qw/ a b c d e f c /;
my @arrayB = qw/ c e /;
my @AminusB = reduce_array(\@arrayA, \@arrayB);
my @AminusBexpected = qw/ a b d f /;

is_deeply(\@AminusB, \@AminusBexpected, 'reduce_array') ;

is(remove_outer('{Some string}'), 'Some string', 'remove_outer') ;

my $nameA =
    { firstname      => "John",
      firstname_i    => "J.",
      firstname_it   => "J",
      lastname       => "Doe",
      lastname_i     => "D.",
      lastname_it    => "D",
      nameinitstring => "Doe_J",
      namestring     => "Doe, John",
      prefix         => undef,
      prefix_i       => undef,
      prefix_it      => undef,
      strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
      suffix         => undef,
      suffix_i       => undef,
      suffix_it      => undef};
my $nameAb =
    { firstname      => "John",
      firstname_i    => "J.",
      firstname_it   => "J",
      lastname       => "Doe",
      lastname_i     => "D.",
      lastname_it    => "D",
      nameinitstring => "Doe_J_J",
      namestring     => "Doe, Jr, John",
      prefix         => undef,
      prefix_i       => undef,
      prefix_it      => undef,
      strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => 0 },
      suffix         => "Jr",
      suffix_i       => "J.",
      suffix_it      => "J" } ;

is_deeply(parsename('John Doe'), $nameA, 'parsename 1a');

is_deeply(parsename('Doe, Jr, John'), $nameAb, 'parsename 1b');

my $nameB =
    { firstname      => "Johann Gottfried",
      firstname_i    => "J.~G.",
      firstname_it   => "JG",
      lastname       => "Berlichingen zu Hornberg",
      lastname_i     => "B.~z.~H.",
      lastname_it    => "BzH",
      nameinitstring => "v_Berlichingen_zu_Hornberg_JG",
      namestring     => "von Berlichingen zu Hornberg, Johann Gottfried",
      prefix         => "von",
      prefix_i       => "v.",
      prefix_it      => "v",
      strip          => { firstname => 0, lastname => 0, prefix => 0, suffix => undef },
      suffix         => undef,
      suffix_i       => undef,
      suffix_it      => undef};

my $nameBb =
    { firstname      => "Johann Gottfried",
      firstname_i    => "J.~G.",
      firstname_it   => "JG",
      lastname       => "Berlichingen zu Hornberg",
      lastname_i     => "B.~z.~H.",
      lastname_it    => "BzH",
      nameinitstring => "Berlichingen_zu_Hornberg_JG",
      namestring     => "Berlichingen zu Hornberg, Johann Gottfried",
      prefix         => undef,
      prefix_i       => undef,
      prefix_it      => undef,
      strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
      suffix         => undef,
      suffix_i       => undef,
      suffix_it      => undef};


is_deeply(parsename('von Berlichingen zu Hornberg, Johann Gottfried', {useprefix => 1}),
                    $nameB, 'parsename 2a') ;

is_deeply(parsename('von Berlichingen zu Hornberg, Johann Gottfried', {useprefix => 0}),
                    $nameBb, 'parsename 2b') ;

my $nameC =
   {  firstname      => undef,
      firstname_i    => undef,
      firstname_it   => undef,
      lastname       => "Robert and Sons, Inc.",
      lastname_i     => "{.",
      lastname_it    => "",
      nameinitstring => "{Robert_and_Sons,_Inc.}",
      namestring     => "Robert and Sons, Inc.",
      prefix         => undef,
      prefix_i       => undef,
      prefix_it      => undef,
      strip          => { firstname => undef, lastname => 1, prefix => undef, suffix => undef },
      suffix         => undef,
      suffix_i       => undef,
      suffix_it      => undef};


is_deeply(parsename('{Robert and Sons, Inc.}'), $nameC, 'parsename 3') ;

my $nameD =
   {  firstname => 'ʿAbdallāh',
      firstname_i => 'A.',
      firstname_it => 'A',
      lastname => 'al-Ṣāliḥ',
      lastname_i => 'Ṣ.',
      lastname_it => 'Ṣ',
      prefix => undef,
      prefix_i => undef,
      prefix_it => undef,
      suffix => undef,
      suffix_i => undef,
      suffix_it => undef,
      strip => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
      namestring => 'al-Ṣāliḥ, ʿAbdallāh',
      nameinitstring => 'al-Ṣāliḥ_A' } ;

is_deeply(parsename('al-Ṣāliḥ, ʿAbdallāh'), $nameD, 'parsename 4') ;

my $nameE =
   {  firstname    => 'Jean Charles Gabriel',
      firstname_i  => 'J.~C.~G.',
      firstname_it => 'JCG',
      lastname_i   => 'V.~P.',
      lastname_it  => 'VP',
      lastname     => 'Vallée Poussin',
      prefix       => 'de la',
      prefix_i     => 'd.~l.',
      prefix_it    => 'dl',
      suffix       => undef,
      suffix_i     => undef,
      suffix_it    => undef,
      strip => { firstname => 0, lastname => 0, prefix => 0, suffix => undef },
      namestring => 'de la Vallée Poussin, Jean Charles Gabriel',
      nameinitstring => 'dl_Vallée_Poussin_JCG' } ;
my $nameE2 =
   {  firstname    => 'Jean Charles Gabriel',
      firstname_i  => 'J.',
      firstname_it => 'J',
      lastname     => 'Vallée Poussin',
      lastname_i   => 'V.~P.',
      lastname_it  => 'VP',
      prefix       => undef,
      prefix_i     => undef,
      prefix_it    => undef,
      suffix       => undef,
      suffix_i     => undef,
      suffix_it    => undef,
      strip => { firstname => 1, lastname => 0, prefix => undef, suffix => undef },
      namestring => 'Vallée Poussin, Jean Charles Gabriel',
      nameinitstring => 'Vallée_Poussin_J' } ;
my $nameE3 =
   {  firstname     => 'Jean Charles Gabriel {de la} Vallée',
      firstname_i   => 'J.~C.~G.~d.~V.',
      firstname_it  => 'JCGdV',
      lastname      => 'Poussin',
      lastname_i    => 'P.',
      lastname_it   => 'P',
      prefix        => undef,
      prefix_i      => undef,
      prefix_it     => undef,
      suffix        => undef,
      suffix_i      => undef,
      suffix_it     => undef,
      strip => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
      namestring => 'Poussin, Jean Charles Gabriel {de la} Vallée',
      nameinitstring => 'Poussin_JCGdV' } ;
my $nameE4 =
   {  firstname    => 'Jean Charles Gabriel',
      firstname_i  => 'J.~C.~G.',
      firstname_it => 'JCG',
      lastname     => 'Vallée Poussin',
      lastname_i   => 'V.',
      lastname_it  => 'V',
      prefix       => undef,
      prefix_i     => undef,
      prefix_it    => undef,
      suffix       => undef,
      suffix_i     => undef,
      suffix_it    => undef,
      strip => { firstname => 0, lastname => 1, prefix => undef, suffix => undef },
      namestring => 'Vallée Poussin, Jean Charles Gabriel',
      nameinitstring => '{Vallée_Poussin}_JCG' } ;
my $nameE5 =
   {  firstname    => 'Jean Charles Gabriel',
      firstname_i  => 'J.',
      firstname_it => 'J',
      lastname     => 'Vallée Poussin',
      lastname_i   => 'V.',
      lastname_it  => 'V',
      prefix       => undef,
      prefix_i     => undef,
      prefix_it    => undef,
      suffix       => undef,
      suffix_i     => undef,
      suffix_it    => undef,
      strip => { firstname => 1, lastname => 1, prefix => undef, suffix => undef },
      namestring => 'Vallée Poussin, Jean Charles Gabriel',
      nameinitstring => '{Vallée_Poussin}_J' } ;

my $nameE6 =
   {  firstname    => 'Jean Charles Gabriel',
      firstname_i  => 'J.~C.~G.',
      firstname_it => 'JCG',
      lastname      => 'Poussin',
      lastname_i    => 'P.',
      lastname_it   => 'P',
      prefix       => undef,
      prefix_i     => undef,
      prefix_it    => undef,
      suffix       => undef,
      suffix_i     => undef,
      suffix_it    => undef,
      strip => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
      namestring => 'Poussin, Jean Charles Gabriel',
      nameinitstring => 'Poussin_JCG' } ;
my $nameE7 =
   {  firstname    => 'Jean Charles',
      firstname_i  => 'J.~C.',
      firstname_it => 'JC',
      lastname     => 'Poussin Lecoq',
      lastname_i   => 'P.',
      lastname_it  => 'P',
      prefix       => undef,
      prefix_i     => undef,
      prefix_it    => undef,
      suffix       => undef,
      suffix_i     => undef,
      suffix_it    => undef,
      strip => { firstname => 0, lastname => 1, prefix => undef, suffix => undef },
      namestring => 'Poussin Lecoq, Jean Charles',
      nameinitstring => '{Poussin_Lecoq}_JC' } ;
my $nameE8 =
   {  firstname    => 'J. C. G.',
      firstname_i  => 'J.~C.~G.',
      firstname_it => 'JCG',
      lastname     => 'Vallée Poussin',
      lastname_i   => 'V.~P.',
      lastname_it  => 'VP',
      prefix       => 'de la',
      prefix_i     => 'd.~l.',
      prefix_it    => 'dl',
      suffix       => undef,
      suffix_i     => undef,
      suffix_it    => undef,
      strip => { firstname => 0, lastname => 0, prefix => 0, suffix => undef },
      namestring => 'de la Vallée Poussin, J. C. G.',
      nameinitstring => 'dl_Vallée_Poussin_JCG' } ;

my $pstring = '{$}Some string & with \% some specials and then {some \{ & % $^{3}$
protected specials} and then some more things % $$ _^';

my $pstring_processed = '{$}Some string \& with \% some specials and then {some \{ & % $^{3}$
protected specials} and then some more things \% \$\$ \_\^';

is( latexescape($pstring), $pstring_processed, 'latexescape test');
is_deeply(parsename('Jean Charles Gabriel de la Vallée Poussin', {useprefix => 1}), $nameE, 'parsename E1');
is_deeply(parsename('{Jean Charles Gabriel} de la Vallée Poussin'), $nameE2, 'parsename E2');
is_deeply(parsename('Jean Charles Gabriel {de la} Vallée Poussin'), $nameE3, 'parsename E3');
is_deeply(parsename('Jean Charles Gabriel de la {Vallée Poussin}'), $nameE4, 'parsename E4');
is_deeply(parsename('{Jean Charles Gabriel} de la {Vallée Poussin}'), $nameE5, 'parsename E5');
is_deeply(parsename('Jean Charles Gabriel Poussin'), $nameE6, 'parsename E6');
is_deeply(parsename('Jean Charles {Poussin Lecoq}'), $nameE7, 'parsename E8');
is_deeply(parsename('J. C. G. de la Vallée Poussin', {useprefix => 1}), $nameE8, 'parsename E8');

is( getinitials('{\"O}zt{\"u}rk'), '{\"O}.', 'getinitials 1' ) ;
is( getinitials('{\c{C}}ok {\OE}illet'), '{\c{C}}.~{\OE}.', 'getinitials 2' ) ;
is( getinitials('Ḥusayn ʿĪsā'), 'Ḥ.~Ī.', 'getinitials 3' ) ;

is( tersify('Ä.~{\c{C}}.~{\c S}.'), 'Ä{\c{C}}{\c S}', 'terseinitials' ) ;

# vim: set tabstop=4 shiftwidth=4: 
