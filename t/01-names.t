use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 45;

use Biber;
use Biber::Input::file::bibtex;
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
Biber::Config->setoption('sortlocale', 'C');

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $bibentries = $section->bibentries;

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
      namestring     => "von Berlichingen zu Hornberg, Johann Gottfried",
      prefix         => "von",
      prefix_i       => "v.",
      prefix_it      => "v",
      strip          => { firstname => 0, lastname => 0, prefix => 0, suffix => undef },
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
      prefix         => undef,
      prefix_i       => undef,
      prefix_it      => undef,
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
      prefix       => 'de~la',
      prefix_i     => 'd.~l.',
      prefix_it    => 'dl',
      suffix       => undef,
      suffix_i     => undef,
      suffix_it    => undef,
      strip => { firstname => 1, lastname => 0, prefix => 0, suffix => undef },
      namestring => 'de la Vallée Poussin, Jean Charles Gabriel',
      nameinitstring => 'Vallée_Poussin_J' } ;
my $name9 =
   {  firstname     => 'Jean Charles Gabriel {de la}~Vallée',
      firstname_i   => 'J.~C. G. d.~V.',
      firstname_it  => 'JCGdV',
      lastname      => 'Poussin',
      lastname_i    => 'P.',
      lastname_it   => 'P',
      prefix       => undef,
      prefix_i     =>  undef,
      prefix_it    => undef,
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
      prefix       => 'de~la',
      prefix_i     => 'd.~l.',
      prefix_it    => 'dl',
      suffix       => undef,
      suffix_i     => undef,
      suffix_it    => undef,
      strip => { firstname => 0, lastname => 1, prefix => 0, suffix => undef },
      namestring => 'de la Vallée Poussin, Jean Charles Gabriel',
      nameinitstring => '{Vallée_Poussin}_JCG' } ;
my $name11 =
   {  firstname    => 'Jean Charles Gabriel',
      firstname_i  => 'J.',
      firstname_it => 'J',
      lastname     => 'Vallée Poussin',
      lastname_i   => 'V.',
      lastname_it  => 'V',
      prefix       => 'de~la',
      prefix_i     => 'd.~l.',
      prefix_it    => 'dl',
      suffix       => undef,
      suffix_i     => undef,
      suffix_it    => undef,
      strip => { firstname => 1, lastname => 1, prefix => 0, suffix => undef },
      namestring => 'de la Vallée Poussin, Jean Charles Gabriel',
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


my $l1 = q|  \entry{L1}{book}{}
    \name{labelname}{1}{%
      {{Adler}{A.}{Alfred}{A.}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Adler}{A.}{Alfred}{A.}{}{}{}{}}%
    }
    \strng{namehash}{AA1}
    \strng{fullhash}{AA1}
    <BDS>SORTINIT</BDS>
  \endentry

|;

my $l2 = q|  \entry{L2}{book}{}
    \name{labelname}{1}{%
      {{Bull}{B.}{Bertie~B.}{B.~B.}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Bull}{B.}{Bertie~B.}{B.~B.}{}{}{}{}}%
    }
    \strng{namehash}{BBB1}
    \strng{fullhash}{BBB1}
    <BDS>SORTINIT</BDS>
  \endentry

|;

my $l3 = q|  \entry{L3}{book}{}
    \name{labelname}{1}{%
      {{Crop}{C.}{C.~Z.}{C.~Z.}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Crop}{C.}{C.~Z.}{C.~Z.}{}{}{}{}}%
    }
    \strng{namehash}{CCZ1}
    \strng{fullhash}{CCZ1}
    <BDS>SORTINIT</BDS>
  \endentry

|;

my $l4 = q|  \entry{L4}{book}{}
    \name{labelname}{1}{%
      {{Decket}{D.}{Derek~D}{D.~D.}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Decket}{D.}{Derek~D}{D.~D.}{}{}{}{}}%
    }
    \strng{namehash}{DDD1}
    \strng{fullhash}{DDD1}
    <BDS>SORTINIT</BDS>
  \endentry

|;

my $l5 = q|  \entry{L5}{book}{}
    \name{labelname}{1}{%
      {{Eel}{E.}{Egbert}{E.}{von}{v.}{}{}}%
    }
    \name{author}{1}{%
      {{Eel}{E.}{Egbert}{E.}{von}{v.}{}{}}%
    }
    \strng{namehash}{vEE1}
    \strng{fullhash}{vEE1}
    <BDS>SORTINIT</BDS>
  \endentry

|;

my $l6 = q|  \entry{L6}{book}{}
    \name{labelname}{1}{%
      {{Frome}{F.}{Francis}{F.}{van~der~valt}{v.~d.~v.}{}{}}%
    }
    \name{author}{1}{%
      {{Frome}{F.}{Francis}{F.}{van~der~valt}{v.~d.~v.}{}{}}%
    }
    \strng{namehash}{vdvFF1}
    \strng{fullhash}{vdvFF1}
    <BDS>SORTINIT</BDS>
  \endentry

|;

my $l7 = q|  \entry{L7}{book}{}
    \name{labelname}{1}{%
      {{Gloom}{G.}{Gregory~R.}{G.~R.}{van}{v.}{}{}}%
    }
    \name{author}{1}{%
      {{Gloom}{G.}{Gregory~R.}{G.~R.}{van}{v.}{}{}}%
    }
    \strng{namehash}{vGGR1}
    \strng{fullhash}{vGGR1}
    <BDS>SORTINIT</BDS>
  \endentry

|;

my $l8 = q|  \entry{L8}{book}{}
    \name{labelname}{1}{%
      {{Henkel}{H.}{Henry~F.}{H.~F.}{van}{v.}{}{}}%
    }
    \name{author}{1}{%
      {{Henkel}{H.}{Henry~F.}{H.~F.}{van}{v.}{}{}}%
    }
    \strng{namehash}{vHHF1}
    \strng{fullhash}{vHHF1}
    <BDS>SORTINIT</BDS>
  \endentry

|;

my $l9 = q|  \entry{L9}{book}{}
    \name{labelname}{1}{%
      {{{Iliad Ipswich}}{I.}{Ian}{I.}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{{Iliad Ipswich}}{I.}{Ian}{I.}{}{}{}{}}%
    }
    \strng{namehash}{II1}
    \strng{fullhash}{II1}
    <BDS>SORTINIT</BDS>
  \endentry

|;


my $l10 = q|  \entry{L10}{book}{}
    \name{labelname}{1}{%
      {{Jolly}{J.}{James}{J.}{}{}{III}{I.}}%
    }
    \name{author}{1}{%
      {{Jolly}{J.}{James}{J.}{}{}{III}{I.}}%
    }
    \strng{namehash}{JIJ1}
    \strng{fullhash}{JIJ1}
    <BDS>SORTINIT</BDS>
  \endentry

|;


my $l10a = q|  \entry{L10a}{book}{}
    \name{labelname}{1}{%
      {{Pimentel}{P.}{Joseph~J.}{J.~J.}{}{}{Jr.}{J.}}%
    }
    \name{author}{1}{%
      {{Pimentel}{P.}{Joseph~J.}{J.~J.}{}{}{Jr.}{J.}}%
    }
    \strng{namehash}{PJJJ1}
    \strng{fullhash}{PJJJ1}
    <BDS>SORTINIT</BDS>
  \endentry

|;


my $l11 = q|  \entry{L11}{book}{}
    \name{labelname}{1}{%
      {{Kluster}{K.}{Kevin}{K.}{van}{v.}{Jr.}{J.}}%
    }
    \name{author}{1}{%
      {{Kluster}{K.}{Kevin}{K.}{van}{v.}{Jr.}{J.}}%
    }
    \strng{namehash}{vKJK1}
    \strng{fullhash}{vKJK1}
    <BDS>SORTINIT</BDS>
  \endentry

|;

my $l12 = q|  \entry{L12}{book}{}
    \name{labelname}{1}{%
      {{Vall{\'e}e~Poussin}{V.~P.}{Charles Louis Xavier~Joseph}{C.~L. X.~J.}{de~la}{d.~l.}{}{}}%
    }
    \name{author}{1}{%
      {{Vall{\'e}e~Poussin}{V.~P.}{Charles Louis Xavier~Joseph}{C.~L. X.~J.}{de~la}{d.~l.}{}{}}%
    }
    \strng{namehash}{dlVPCLXJ1}
    \strng{fullhash}{dlVPCLXJ1}
    <BDS>SORTINIT</BDS>
  \endentry

|;

my $l13 = q|  \entry{L13}{book}{}
    \name{labelname}{1}{%
      {{Van de~Graaff}{V.~d.~G.}{R.~J.}{R.~J.}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Van de~Graaff}{V.~d.~G.}{R.~J.}{R.~J.}{}{}{}{}}%
    }
    \strng{namehash}{VdGRJ1}
    \strng{fullhash}{VdGRJ1}
    <BDS>SORTINIT</BDS>
  \endentry

|;

my $l14 = q|  \entry{L14}{book}{}
    \name{labelname}{1}{%
      {{St~John-Mollusc}{S.~J.-M.}{Oliver}{O.}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{St~John-Mollusc}{S.~J.-M.}{Oliver}{O.}{}{}{}{}}%
    }
    \strng{namehash}{SJMO1}
    \strng{fullhash}{SJMO1}
    <BDS>SORTINIT</BDS>
  \endentry

|;

my $l15 = q|  \entry{L15}{book}{}
    \name{labelname}{1}{%
      {{Gompel}{G.}{Roger~P.{\,}G.}{R.~P.}{van}{v.}{}{}}%
    }
    \name{author}{1}{%
      {{Gompel}{G.}{Roger~P.{\,}G.}{R.~P.}{van}{v.}{}{}}%
    }
    \strng{namehash}{vGRP1}
    \strng{fullhash}{vGRP1}
    <BDS>SORTINIT</BDS>
  \endentry

|;

my $l16 = q|  \entry{L16}{book}{}
    \name{labelname}{1}{%
      {{Gompel}{G.}{Roger~{P.\,G.}}{R.~P.}{van}{v.}{}{}}%
    }
    \name{author}{1}{%
      {{Gompel}{G.}{Roger~{P.\,G.}}{R.~P.}{van}{v.}{}{}}%
    }
    \strng{namehash}{vGRP1}
    \strng{fullhash}{vGRP1}
    <BDS>SORTINIT</BDS>
  \endentry

|;

my $l17 = q|  \entry{L17}{book}{}
    \name{labelname}{1}{%
      {{Lovecraft}{L.}{Bill~H.{\,}P.}{B.~H.}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Lovecraft}{L.}{Bill~H.{\,}P.}{B.~H.}{}{}{}{}}%
    }
    \strng{namehash}{LBH1}
    \strng{fullhash}{LBH1}
    <BDS>SORTINIT</BDS>
  \endentry

|;

my $l18 = q|  \entry{L18}{book}{}
    \name{labelname}{1}{%
      {{Lovecraft}{L.}{Bill~{H.\,P.}}{B.~H.}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Lovecraft}{L.}{Bill~{H.\,P.}}{B.~H.}{}{}{}{}}%
    }
    \strng{namehash}{LBH1}
    \strng{fullhash}{LBH1}
    <BDS>SORTINIT</BDS>
  \endentry

|;

my $l19 = q|  \entry{L19}{book}{}
    \name{labelname}{1}{%
      {{Mustermann}{M.}{Klaus-Peter}{K.-P.}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Mustermann}{M.}{Klaus-Peter}{K.-P.}{}{}{}{}}%
    }
    \strng{namehash}{MKP1}
    \strng{fullhash}{MKP1}
    <BDS>SORTINIT</BDS>
  \endentry

|;

my $l20 = q|  \entry{L20}{book}{}
    \name{labelname}{1}{%
      {{Ford}{F.}{{John Henry}}{J.}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Ford}{F.}{{John Henry}}{J.}{}{}{}{}}%
    }
    \strng{namehash}{FJ1}
    \strng{fullhash}{FJ1}
    <BDS>SORTINIT</BDS>
  \endentry

|;

my $l21 = q|  \entry{L21}{book}{}
    \name{labelname}{1}{%
      {{Smith}{S.}{{\v S}omeone}{{\v S}.}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Smith}{S.}{{\v S}omeone}{{\v S}.}{}{}{}{}}%
    }
    \strng{namehash}{SS1}
    \strng{fullhash}{SS1}
    <BDS>SORTINIT</BDS>
  \endentry

|;

my $l22 = q|  \entry{L22}{book}{}
    \name{labelname}{1}{%
      {{{\v S}mith}{{\v S}.}{Someone}{S.}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{{\v S}mith}{{\v S}.}{Someone}{S.}{}{}{}{}}%
    }
    \strng{namehash}{SS1}
    \strng{fullhash}{SS1}
    <BDS>SORTINIT</BDS>
  \endentry

|;


my $l23 = q|  \entry{L23}{book}{}
    \name{labelname}{1}{%
      {{Smith}{S.}{Šomeone}{Š.}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Smith}{S.}{Šomeone}{Š.}{}{}{}{}}%
    }
    \strng{namehash}{SŠ1}
    \strng{fullhash}{SŠ1}
    <BDS>SORTINIT</BDS>
  \endentry

|;

my $l24 = q|  \entry{L24}{book}{}
    \name{labelname}{1}{%
      {{Šmith}{Š.}{Someone}{S.}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Šmith}{Š.}{Someone}{S.}{}{}{}{}}%
    }
    \strng{namehash}{ŠS1}
    \strng{fullhash}{ŠS1}
    <BDS>SORTINIT</BDS>
  \endentry

|;

my $l25 = q|  \entry{L25}{book}{}
    \name{labelname}{1}{%
      {{{American Psychological Association, Task Force on the Sexualization of Girls}}{A.}{}{}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{{American Psychological Association, Task Force on the Sexualization of Girls}}{A.}{}{}{}{}{}{}}%
    }
    \strng{namehash}{A1}
    \strng{fullhash}{A1}
    <BDS>SORTINIT</BDS>
  \endentry

|;

my $l26 = q|  \entry{L26}{book}{}
    \name{labelname}{1}{%
      {{{Sci-Art Publishers}}{S.}{}{}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{{Sci-Art Publishers}}{S.}{}{}{}{}{}{}}%
    }
    \strng{namehash}{S1}
    \strng{fullhash}{S1}
    <BDS>SORTINIT</BDS>
  \endentry

|;

# Malformed anyway but a decent test
my $l28 = q|  \entry{L28}{book}{}
    \strng{namehash}{1}
    \strng{fullhash}{1}
    <BDS>SORTINIT</BDS>
    \warn{\item Name "Deux et al.,, O." is malformed (consecutive commas): skipping name}
  \endentry

|;


my $l29 = q|  \entry{L29}{book}{}
    \name{labelname}{1}{%
      {{{U.S. Department of Health and Human Services, National Institute of Mental Health, National Heart, Lung and Blood Institute}}{U.}{}{}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{{U.S. Department of Health and Human Services, National Institute of Mental Health, National Heart, Lung and Blood Institute}}{U.}{}{}{}{}{}{}}%
    }
    \strng{namehash}{U1}
    \strng{fullhash}{U1}
    <BDS>SORTINIT</BDS>
  \endentry

|;


is_deeply(Biber::Input::file::bibtex::parsename('John Doe', 'author'), $name1, 'parsename 1');
is_deeply(Biber::Input::file::bibtex::parsename('Doe, Jr, John', 'author'), $name2, 'parsename 2');
is_deeply(Biber::Input::file::bibtex::parsename('von Berlichingen zu Hornberg, Johann Gottfried', 'author', {useprefix => 1}), $name3, 'parsename 3') ;
is_deeply(Biber::Input::file::bibtex::parsename('von Berlichingen zu Hornberg, Johann Gottfried', 'author', {useprefix => 0}), $name4, 'parsename 4') ;
is_deeply(Biber::Input::file::bibtex::parsename('{Robert and Sons, Inc.}', 'author'), $name5, 'parsename 5') ;
is_deeply(Biber::Input::file::bibtex::parsename('al-Ṣāliḥ, ʿAbdallāh', 'author'), $name6, 'parsename 6') ;
is_deeply(Biber::Input::file::bibtex::parsename('Jean Charles Gabriel de la Vallée Poussin', 'author', {useprefix => 1}), $name7, 'parsename 7');
is_deeply(Biber::Input::file::bibtex::parsename('{Jean Charles Gabriel} de la Vallée Poussin', 'author'), $name8, 'parsename 8');
is_deeply(Biber::Input::file::bibtex::parsename('Jean Charles Gabriel {de la} Vallée Poussin', 'author'), $name9, 'parsename 9');
is_deeply(Biber::Input::file::bibtex::parsename('Jean Charles Gabriel de la {Vallée Poussin}', 'author'), $name10, 'parsename 10');
is_deeply(Biber::Input::file::bibtex::parsename('{Jean Charles Gabriel} de la {Vallée Poussin}', 'author'), $name11, 'parsename 11');
is_deeply(Biber::Input::file::bibtex::parsename('Jean Charles Gabriel Poussin', 'author'), $name12, 'parsename 12');
is_deeply(Biber::Input::file::bibtex::parsename('Jean Charles {Poussin Lecoq}', 'author'), $name13, 'parsename 13');
is_deeply(Biber::Input::file::bibtex::parsename('J. C. G. de la Vallée Poussin', 'author', {useprefix => 1}), $name14, 'parsename 14');

is( $out->get_output_entry('l1'), $l1, 'First Last') ;
is( $out->get_output_entry('l2'), $l2, 'First Initial. Last') ;
is( $out->get_output_entry('l3'), $l3, 'Initial. Initial. Last') ;
is( $out->get_output_entry('l4'), $l4, 'First Initial Last') ;
is( $out->get_output_entry('l5'), $l5, 'First prefix Last') ;
is( $out->get_output_entry('l6'), $l6, 'First prefix prefix Last') ;
is( $out->get_output_entry('l7'), $l7, 'First Initial. prefix Last') ;
is( $out->get_output_entry('l8'), $l8, 'First Initial prefix Last') ;
is( $out->get_output_entry('l9'), $l9, 'First {Last Last}') ;
is( $out->get_output_entry('l10'), $l10, 'Last, Suffix, First') ;
is( $out->get_output_entry('l10a'), $l10a, 'Last, Suffix, First Initial.') ;
is( $out->get_output_entry('l11'), $l11, 'prefix Last, Suffix, First') ;
is( $out->get_output_entry('l13'), $l13, 'Last Last Last, Initial. Initial.');
is( $out->get_output_entry('l14'), $l14, 'Last Last-Last, First');
is( $out->get_output_entry('l15'), $l15, 'First F.{\,}F. Last');
is( $out->get_output_entry('l16'), $l16, 'First {F.\,F.} Last');
is( $out->get_output_entry('l17'), $l17, 'Last, First {F.\,F.}');
is( $out->get_output_entry('l18'), $l18, 'Last, First F.{\,}F.');
is( $out->get_output_entry('l19'), $l19, 'Firstname with hyphen');
is( $out->get_output_entry('l20'), $l20, 'Protected dual first name');
is( $out->get_output_entry('l23'), $l23, 'Unicode firstname');
is( $out->get_output_entry('l24'), $l24, 'Unicode lastname');
is( $out->get_output_entry('l25'), $l25, 'Single string name');
is( $out->get_output_entry('l26'), $l26, 'Hyphen at brace level <> 0');
is($section->bibentry('l27')->get_field('author')->count_elements, 1, 'Bad name with 3 commas');
#is($section->has_citekey('l28'), '0', 'Bad name with consecutive commas');
is( $out->get_output_entry('l28'), $l28, 'Bad name with consecutive commas');
is( $out->get_output_entry('l29'), $l29, 'Escaped name with 3 commas');

# A few tests depend set to non UTF-8 output
# Have to use a new biber object when trying to change encoding as this isn't
# dealt with in ->prepare
$biber->parse_ctrlfile('names.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());

# Biber options
Biber::Config->setoption('bblencoding', 'latin1');

# Now generate the information
$biber->prepare;
$out = $biber->get_output_obj;
$section = $biber->sections->get_section(0);
$bibentries = $section->bibentries;

is($bibentries->entry('l21')->get_field($bibentries->entry('l21')->get_field('labelnamename'))->nth_element(1)->get_firstname_it, '{\v S}', 'Terseinitials 1');
is( $out->get_output_entry('l12'), $l12, 'First First First First prefix prefix Last Last') ;
is( $out->get_output_entry('l21'), $l21, 'LaTeX encoded unicode firstname');
is( $out->get_output_entry('l22'), $l22, 'LaTeX encoded unicode lastname');

unlink <*.utf8>;
