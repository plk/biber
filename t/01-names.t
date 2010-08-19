use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 45;

use Biber;
use Biber::Input::BibTeX;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
chdir("t/tdata");

# Set up Biber object
my $biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('names.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('locale', 'C');

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $bibentries = $biber->sections->get_section('0')->bib;
my $section = $biber->sections->get_section('0');

my $name1 =
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
my $name2 =
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



my $name3 =
    { firstname      => "Johann~Gottfried",
      firstname_i    => "J.~G.",
      firstname_it   => "JG",
      lastname       => "Berlichingen zu~Hornberg",
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

my $name4 =
    { firstname      => "Johann~Gottfried",
      firstname_i    => "J.~G.",
      firstname_it   => "JG",
      lastname       => "Berlichingen zu~Hornberg",
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


my $name5 =
   {  firstname      => undef,
      firstname_i    => undef,
      firstname_it   => undef,
      lastname       => "Robert and Sons, Inc.",
      lastname_i     => "R.",
      lastname_it    => "R",
      nameinitstring => "{Robert_and_Sons,_Inc.}",
      namestring     => "Robert and Sons, Inc.",
      prefix         => undef,
      prefix_i       => undef,
      prefix_it      => undef,
      strip          => { firstname => undef, lastname => 1, prefix => undef, suffix => undef },
      suffix         => undef,
      suffix_i       => undef,
      suffix_it      => undef};


my $name6 =
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


my $name7 =
   {  firstname    => 'Jean Charles~Gabriel',
      firstname_i  => 'J.~C.~G.',
      firstname_it => 'JCG',
      lastname_i   => 'V.~P.',
      lastname_it  => 'VP',
      lastname     => 'Vallée~Poussin',
      prefix       => 'de~la',
      prefix_i     => 'd.~l.',
      prefix_it    => 'dl',
      suffix       => undef,
      suffix_i     => undef,
      suffix_it    => undef,
      strip => { firstname => 0, lastname => 0, prefix => 0, suffix => undef },
      namestring => 'de la Vallée Poussin, Jean Charles Gabriel',
      nameinitstring => 'dl_Vallée_Poussin_JCG' } ;
my $name8 =
   {  firstname    => 'Jean Charles Gabriel',
      firstname_i  => 'J.',
      firstname_it => 'J',
      lastname     => 'Vallée~Poussin',
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
my $name9 =
   {  firstname     => 'Jean Charles Gabriel {de la}~Vallée',
      firstname_i   => 'J.~C. G. d.~V.',
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
my $name10 =
   {  firstname    => 'Jean Charles~Gabriel',
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
my $name11 =
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

my $name12 =
   {  firstname    => 'Jean Charles~Gabriel',
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
my $name13 =
   {  firstname    => 'Jean~Charles',
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
my $name14 =
   {  firstname    => 'J.~C.~G.',
      firstname_i  => 'J.~C.~G.',
      firstname_it => 'JCG',
      lastname     => 'Vallée~Poussin',
      lastname_i   => 'V.~P.',
      lastname_it  => 'VP',
      prefix       => 'de~la',
      prefix_i     => 'd.~l.',
      prefix_it    => 'dl',
      suffix       => undef,
      suffix_i     => undef,
      suffix_it    => undef,
      strip => { firstname => 0, lastname => 0, prefix => 0, suffix => undef },
      namestring => 'de la Vallée Poussin, J. C. G.',
      nameinitstring => 'dl_Vallée_Poussin_JCG' } ;



is_deeply(parsename('John Doe'), $name1, 'parsename 1');
is_deeply(parsename('Doe, Jr, John'), $name2, 'parsename 2');
is_deeply(parsename('von Berlichingen zu Hornberg, Johann Gottfried', {useprefix => 1}),
                    $name3, 'parsename 3') ;
is_deeply(parsename('von Berlichingen zu Hornberg, Johann Gottfried', {useprefix => 0}),
                    $name4, 'parsename 4') ;
is_deeply(parsename('{Robert and Sons, Inc.}'), $name5, 'parsename 5') ;
is_deeply(parsename('al-Ṣāliḥ, ʿAbdallāh'), $name6, 'parsename 6') ;
is_deeply(parsename('Jean Charles Gabriel de la Vallée Poussin', {useprefix => 1}), $name7, 'parsename 7');
is_deeply(parsename('{Jean Charles Gabriel} de la Vallée Poussin'), $name8, 'parsename 8');
is_deeply(parsename('Jean Charles Gabriel {de la} Vallée Poussin'), $name9, 'parsename 9');
is_deeply(parsename('Jean Charles Gabriel de la {Vallée Poussin}'), $name10, 'parsename 10');
is_deeply(parsename('{Jean Charles Gabriel} de la {Vallée Poussin}'), $name11, 'parsename 11');
is_deeply(parsename('Jean Charles Gabriel Poussin'), $name12, 'parsename 12');
is_deeply(parsename('Jean Charles {Poussin Lecoq}'), $name13, 'parsename 13');
is_deeply(parsename('J. C. G. de la Vallée Poussin', {useprefix => 1}), $name14, 'parsename 14');

is($bibentries->entry('l1')->get_field($bibentries->entry('l1')->get_field('labelnamename'))->nth_element(1)->name_to_bbl, '      {{}{Adler}{A.}{Alfred}{A.}{}{}{}{}}%' . "\n", 'First Last');
is($bibentries->entry('l2')->get_field($bibentries->entry('l2')->get_field('labelnamename'))->nth_element(1)->name_to_bbl, '      {{}{Bull}{B.}{Bertie~B.}{B.~B.}{}{}{}{}}%' . "\n", 'First Initial. Last');
is($bibentries->entry('l3')->get_field($bibentries->entry('l3')->get_field('labelnamename'))->nth_element(1)->name_to_bbl, '      {{}{Crop}{C.}{C.~Z.}{C.~Z.}{}{}{}{}}%' . "\n", 'Initial. Initial. Last');
is($bibentries->entry('l4')->get_field($bibentries->entry('l4')->get_field('labelnamename'))->nth_element(1)->name_to_bbl, '      {{}{Decket}{D.}{Derek~D}{D.~D.}{}{}{}{}}%' . "\n", 'First Initial Last');
is($bibentries->entry('l5')->get_field($bibentries->entry('l5')->get_field('labelnamename'))->nth_element(1)->name_to_bbl, '      {{}{Eel}{E.}{Egbert}{E.}{von}{v.}{}{}}%' . "\n", 'First prefix Last');
is($bibentries->entry('l6')->get_field($bibentries->entry('l6')->get_field('labelnamename'))->nth_element(1)->name_to_bbl, '      {{}{Frome}{F.}{Francis}{F.}{van~der~valt}{v.~d.~v.}{}{}}%' . "\n", 'First prefix prefix Last');
is($bibentries->entry('l7')->get_field($bibentries->entry('l7')->get_field('labelnamename'))->nth_element(1)->name_to_bbl, '      {{}{Gloom}{G.}{Gregory~R.}{G.~R.}{van}{v.}{}{}}%' . "\n", 'First Initial. prefix Last');
is($bibentries->entry('l8')->get_field($bibentries->entry('l8')->get_field('labelnamename'))->nth_element(1)->name_to_bbl, '      {{}{Henkel}{H.}{Henry~F.}{H.~F.}{van}{v.}{}{}}%' . "\n", 'First Initial prefix Last');
is($bibentries->entry('l9')->get_field($bibentries->entry('l9')->get_field('labelnamename'))->nth_element(1)->name_to_bbl, '      {{}{{Iliad Ipswich}}{I.}{Ian}{I.}{}{}{}{}}%' . "\n", 'First {Last Last}');
is($bibentries->entry('l10')->get_field($bibentries->entry('l10')->get_field('labelnamename'))->nth_element(1)->name_to_bbl, '      {{}{Jolly}{J.}{James}{J.}{}{}{III}{I.}}%' . "\n", 'Last, Suffix, First') ;
is($bibentries->entry('l11')->get_field($bibentries->entry('l11')->get_field('labelnamename'))->nth_element(1)->name_to_bbl, '      {{}{Kluster}{K.}{Kevin}{K.}{van}{v.}{Jr.}{J.}}%' . "\n", 'prefix Last, Suffix, First');
is($bibentries->entry('l12')->get_field($bibentries->entry('l12')->get_field('labelnamename'))->nth_element(1)->name_to_bbl, "      {{}{Vall{\\'e}e~Poussin}{V.~P.}{Charles Louis Xavier~Joseph}{C.~L. X.~J.}{de~la}{d.~l.}{}{}}%" . "\n", 'First First First First prefix prefix Last Last');
is($bibentries->entry('l13')->get_field($bibentries->entry('l13')->get_field('labelnamename'))->nth_element(1)->name_to_bbl, '      {{}{Van de~Graaff}{V.~d.~G.}{R.~J.}{R.~J.}{}{}{}{}}%' . "\n", 'Last Last Last, Initial. Initial.');
is($bibentries->entry('l14')->get_field($bibentries->entry('l14')->get_field('labelnamename'))->nth_element(1)->name_to_bbl, '      {{}{St~John-Mollusc}{S.~J.-M.}{Oliver}{O.}{}{}{}{}}%' . "\n", 'Last Last-Last, First');
is($bibentries->entry('l15')->get_field($bibentries->entry('l15')->get_field('labelnamename'))->nth_element(1)->name_to_bbl, '      {{}{Gompel}{G.}{Roger~P.{\,}G.}{R.~P.}{van}{v.}{}{}}%' . "\n", 'First F.{\,}F. Last');
is($bibentries->entry('l16')->get_field($bibentries->entry('l16')->get_field('labelnamename'))->nth_element(1)->name_to_bbl, '      {{}{Gompel}{G.}{Roger~{P.\,G.}}{R.~P.}{van}{v.}{}{}}%' . "\n", 'First {F.\,F.} Last');
is($bibentries->entry('l17')->get_field($bibentries->entry('l17')->get_field('labelnamename'))->nth_element(1)->name_to_bbl, '      {{}{Lovecraft}{L.}{Bill~H.{\,}P.}{B.~H.}{}{}{}{}}%' . "\n", 'Last, First {F.\,F.}');
is($bibentries->entry('l18')->get_field($bibentries->entry('l18')->get_field('labelnamename'))->nth_element(1)->name_to_bbl, '      {{}{Lovecraft}{L.}{Bill~{H.\,P.}}{B.~H.}{}{}{}{}}%' . "\n", 'Last, First F.{\,}F.');
is($bibentries->entry('l19')->get_field($bibentries->entry('l19')->get_field('labelnamename'))->nth_element(1)->name_to_bbl, '      {{}{Mustermann}{M.}{Klaus-Peter}{K.-P.}{}{}{}{}}%' . "\n", 'Firstname with hyphen');
is($bibentries->entry('l20')->get_field($bibentries->entry('l20')->get_field('labelnamename'))->nth_element(1)->name_to_bbl, '      {{}{Ford}{F.}{{John Henry}}{J.}{}{}{}{}}%' . "\n", 'Protected dual first name');
is($bibentries->entry('l21')->get_field($bibentries->entry('l21')->get_field('labelnamename'))->nth_element(1)->name_to_bbl, '      {{}{Smith}{S.}{{\v S}omeone}{{\v S}.}{}{}{}{}}%' . "\n", 'LaTeX encoded unicode firstname');
is($bibentries->entry('l22')->get_field($bibentries->entry('l22')->get_field('labelnamename'))->nth_element(1)->name_to_bbl, '      {{}{{\v S}mith}{{\v S}.}{Someone}{S.}{}{}{}{}}%' . "\n", 'LaTeX encoded unicode lastname');
is($bibentries->entry('l23')->get_field($bibentries->entry('l23')->get_field('labelnamename'))->nth_element(1)->name_to_bbl, '      {{}{Smith}{S.}{Šomeone}{Š.}{}{}{}{}}%' . "\n", 'Unicode firstname');
is($bibentries->entry('l24')->get_field($bibentries->entry('l24')->get_field('labelnamename'))->nth_element(1)->name_to_bbl, '      {{}{Šmith}{Š.}{Someone}{S.}{}{}{}{}}%' . "\n", 'Unicode lastname');
is($bibentries->entry('l21')->get_field($bibentries->entry('l21')->get_field('labelnamename'))->nth_element(1)->get_firstname_it, '{\v S}', 'Terseinitials 1');
is($bibentries->entry('l21')->get_field('namehash'), 'SS1', 'Namehash check 1');
is($bibentries->entry('l25')->get_field($bibentries->entry('l25')->get_field('labelnamename'))->nth_element(1)->name_to_bbl, '      {{}{{American Psychological Association, Task Force on the Sexualization of Girls}}{A.}{}{}{}{}{}{}}%' . "\n", 'Single string name');
is($bibentries->entry('l26')->get_field($bibentries->entry('l26')->get_field('labelnamename'))->nth_element(1)->name_to_bbl, '      {{}{{Sci-Art Publishers}}{S.}{}{}{}{}{}{}}%' . "\n", 'Hyphen at brace level <> 0');
is($section->has_citekey('l27'), '0', 'Bad name with 3 commas');
is($section->has_citekey('l28'), '0', 'Bad name with consecutive commas');
SKIP: {
  skip "Text::BibTeX < 0.41", 1, if $Text::BibTeX::VERSION < 0.41;
  is($bibentries->entry('l29')->get_field($bibentries->entry('l29')->get_field('labelnamename'))->nth_element(1)->name_to_bbl, '      {{}{{U.S. Department of Health and Human Services, National Institute of Mental Health, National Heart, Lung and Blood Institute}}{U.}{}{}{}{}{}{}}%' . "\n",  'Escaped name with 3 commas');
}

unlink "*.utf8";
