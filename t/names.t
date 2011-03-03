use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 49;

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
my $main = $section->get_list('MAIN');
my $bibentries = $section->bibentries;

my $name1 =
    { firstname      => 'John',
      firstname_i    => ['J'],
      lastname       => 'Doe',
      lastname_i     => ['D'],
      nameinitstring => 'Doe_J',
      namestring     => 'Doe, John',
      prefix         => undef,
      prefix_i       => undef,
      strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
      suffix         => undef,
      suffix_i       => undef};
my $name2 =
    { firstname      => 'John',
      firstname_i    => ['J'],
      lastname       => 'Doe',
      lastname_i     => ['D'],
      nameinitstring => 'Doe_J_J',
      namestring     => 'Doe, Jr, John',
      prefix         => undef,
      prefix_i       => undef,
      strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => 0 },
      suffix         => 'Jr',
      suffix_i       => ['J'] } ;



my $name3 =
    { firstname      => 'Johann~Gottfried',
      firstname_i    => ['J', 'G'],
      lastname       => 'Berlichingen zu~Hornberg',
      lastname_i     => ['B', 'z', 'H'],
      nameinitstring => 'v_Berlichingen_zu_Hornberg_JG',
      namestring     => 'von Berlichingen zu Hornberg, Johann Gottfried',
      prefix         => 'von',
      prefix_i       => ['v'],
      strip          => { firstname => 0, lastname => 0, prefix => 0, suffix => undef },
      suffix         => undef,
      suffix_i       => undef};

my $name4 =
    { firstname      => 'Johann~Gottfried',
      firstname_i    => ['J', 'G'],
      lastname       => 'Berlichingen zu~Hornberg',
      lastname_i     => ['B', 'z', 'H'],
      nameinitstring => 'Berlichingen_zu_Hornberg_JG',
      namestring     => 'von Berlichingen zu Hornberg, Johann Gottfried',
      prefix         => 'von',
      prefix_i       => ['v'],
      strip          => { firstname => 0, lastname => 0, prefix => 0, suffix => undef },
      suffix         => undef,
      suffix_i       => undef};


my $name5 =
   {  firstname      => undef,
      firstname_i    => undef,
      lastname       => 'Robert and Sons, Inc.',
      lastname_i     => ['R'],
      nameinitstring => '{Robert_and_Sons,_Inc.}',
      namestring     => 'Robert and Sons, Inc.',
      prefix         => undef,
      prefix_i       => undef,
      strip          => { firstname => undef, lastname => 1, prefix => undef, suffix => undef },
      suffix         => undef,
      suffix_i       => undef};


my $name6 =
   {  firstname      => 'ʿAbdallāh',
      firstname_i    => ['A'],
      lastname       => 'al-Ṣāliḥ',
      lastname_i     => ['Ṣ'],
      prefix         => undef,
      prefix_i       => undef,
      suffix         => undef,
      suffix_i       => undef,
      strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
      namestring     => 'al-Ṣāliḥ, ʿAbdallāh',
      nameinitstring => 'al-Ṣāliḥ_A' } ;

my $name7 =
   {  firstname      => 'Jean Charles~Gabriel',
      firstname_i    => ['J', 'C', 'G'],
      lastname       => 'Vallée~Poussin',
      lastname_i     => ['V', 'P'],
      prefix         => 'de~la',
      prefix_i       => ['d', 'l'],
      suffix         => undef,
      suffix_i       => undef,
      strip          => { firstname => 0, lastname => 0, prefix => 0, suffix => undef },
      namestring     => 'de la Vallée Poussin, Jean Charles Gabriel',
      nameinitstring => 'dl_Vallée_Poussin_JCG' } ;

my $name8 =
   {  firstname      => 'Jean Charles Gabriel',
      firstname_i    => ['J'],
      lastname       => 'Vallée~Poussin',
      lastname_i     => ['V', 'P'],
      prefix         => 'de~la',
      prefix_i       => ['d', 'l'],
      suffix         => undef,
      suffix_i       => undef,
      strip          => { firstname => 1, lastname => 0, prefix => 0, suffix => undef },
      namestring     => 'de la Vallée Poussin, Jean Charles Gabriel',
      nameinitstring => 'Vallée_Poussin_J' } ;

my $name9 =
   {  firstname      => 'Jean Charles Gabriel {de la}~Vallée',
      firstname_i    => ['J', 'C', 'G', 'd', 'V'],
      lastname       => 'Poussin',
      lastname_i     => ['P'],
      prefix         => undef,
      prefix_i       => undef,
      suffix         => undef,
      suffix_i       => undef,
      strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
      namestring     => 'Poussin, Jean Charles Gabriel {de la} Vallée',
      nameinitstring => 'Poussin_JCGdV' } ;

my $name10 =
   {  firstname      => 'Jean Charles~Gabriel',
      firstname_i    => ['J', 'C', 'G'],
      lastname       => 'Vallée Poussin',
      lastname_i     => ['V'],
      prefix         => 'de~la',
      prefix_i       => ['d', 'l'],
      suffix         => undef,
      suffix_i       => undef,
      strip          => { firstname => 0, lastname => 1, prefix => 0, suffix => undef },
      namestring     => 'de la Vallée Poussin, Jean Charles Gabriel',
      nameinitstring => '{Vallée_Poussin}_JCG' } ;

my $name11 =
   {  firstname      => 'Jean Charles Gabriel',
      firstname_i    => ['J'],
      lastname       => 'Vallée Poussin',
      lastname_i     => ['V'],
      prefix         => 'de~la',
      prefix_i       => ['d', 'l'],
      suffix         => undef,
      suffix_i       => undef,
      strip          => { firstname => 1, lastname => 1, prefix => 0, suffix => undef },
      namestring     => 'de la Vallée Poussin, Jean Charles Gabriel',
      nameinitstring => '{Vallée_Poussin}_J' } ;

my $name12 =
   {  firstname      => 'Jean Charles~Gabriel',
      firstname_i    => ['J', 'C', 'G'],
      lastname       => 'Poussin',
      lastname_i     => ['P'],
      prefix         => undef,
      prefix_i       => undef,
      suffix         => undef,
      suffix_i       => undef,
      strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
      namestring     => 'Poussin, Jean Charles Gabriel',
      nameinitstring => 'Poussin_JCG' } ;

my $name13 =
   {  firstname      => 'Jean~Charles',
      firstname_i    => ['J', 'C'],
      lastname       => 'Poussin Lecoq',
      lastname_i     => ['P'],
      prefix         => undef,
      prefix_i       => undef,
      suffix         => undef,
      suffix_i       => undef,
      strip          => { firstname => 0, lastname => 1, prefix => undef, suffix => undef },
      namestring     => 'Poussin Lecoq, Jean Charles',
      nameinitstring => '{Poussin_Lecoq}_JC' } ;

my $name14 =
   {  firstname      => 'J.~C.~G.',
      firstname_i    => ['J', 'C', 'G'],
      lastname       => 'Vallée~Poussin',
      lastname_i     => ['V', 'P'],
      prefix         => 'de~la',
      prefix_i       => ['d', 'l'],
      suffix         => undef,
      suffix_i       => undef,
      strip          => { firstname => 0, lastname => 0, prefix => 0, suffix => undef },
      namestring     => 'de la Vallée Poussin, J. C. G.',
      nameinitstring => 'dl_Vallée_Poussin_JCG' } ;

my $name15 =
   {  firstname      => 'E.~S.',
      firstname_i    => ['E', 'S'],
      lastname       => 'El-{M}allah',
      lastname_i     => ['M'],
      prefix         => undef,
      prefix_i       => undef,
      suffix         => undef,
      suffix_i       => undef,
      strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
      namestring     => 'El-{M}allah, E. S.',
      nameinitstring => 'El-{M}allah_ES' } ;

my $name16 =
   {  firstname      => 'E.~S.',
      firstname_i    => ['E', 'S'],
      lastname       => '{K}ent-{B}oswell',
      lastname_i     => ['K-B'],
      prefix         => undef,
      prefix_i       => undef,
      suffix         => undef,
      suffix_i       => undef,
      strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
      namestring     => '{K}ent-{B}oswell, E. S.',
      nameinitstring => '{K}ent-{B}oswell_ES' } ;


my $l1 = q|  \entry{L1}{book}{}
    \name{labelname}{1}{%
      {{Adler}{A\bibinitperiod}{Alfred}{A\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Adler}{A\bibinitperiod}{Alfred}{A\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{AA1}
    \strng{fullhash}{AA1}
    \field{sortinit}{A}
  \endentry

|;

my $l2 = q|  \entry{L2}{book}{}
    \name{labelname}{1}{%
      {{Bull}{B\bibinitperiod}{Bertie\bibnamedelima B.}{B\bibinitperiod\bibinitdelim B\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Bull}{B\bibinitperiod}{Bertie\bibnamedelima B.}{B\bibinitperiod\bibinitdelim B\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{BBB1}
    \strng{fullhash}{BBB1}
    \field{sortinit}{B}
  \endentry

|;

my $l3 = q|  \entry{L3}{book}{}
    \name{labelname}{1}{%
      {{Crop}{C\bibinitperiod}{C.\bibnamedelima Z.}{C\bibinitperiod\bibinitdelim Z\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Crop}{C\bibinitperiod}{C.\bibnamedelima Z.}{C\bibinitperiod\bibinitdelim Z\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{CCZ1}
    \strng{fullhash}{CCZ1}
    \field{sortinit}{C}
  \endentry

|;

my $l4 = q|  \entry{L4}{book}{}
    \name{labelname}{1}{%
      {{Decket}{D\bibinitperiod}{Derek\bibnamedelima D}{D\bibinitperiod\bibinitdelim D\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Decket}{D\bibinitperiod}{Derek\bibnamedelima D}{D\bibinitperiod\bibinitdelim D\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{DDD1}
    \strng{fullhash}{DDD1}
    \field{sortinit}{D}
  \endentry

|;

my $l5 = q|  \entry{L5}{book}{}
    \name{labelname}{1}{%
      {{Eel}{E\bibinitperiod}{Egbert}{E\bibinitperiod}{von}{v\bibinitperiod}{}{}}%
    }
    \name{author}{1}{%
      {{Eel}{E\bibinitperiod}{Egbert}{E\bibinitperiod}{von}{v\bibinitperiod}{}{}}%
    }
    \strng{namehash}{vEE1}
    \strng{fullhash}{vEE1}
    \field{sortinit}{v}
  \endentry

|;

my $l6 = q|  \entry{L6}{book}{}
    \name{labelname}{1}{%
      {{Frome}{F\bibinitperiod}{Francis}{F\bibinitperiod}{van\bibnamedelimb der\bibnamedelima valt}{v\bibinitperiod\bibinitdelim d\bibinitperiod\bibinitdelim v\bibinitperiod}{}{}}%
    }
    \name{author}{1}{%
      {{Frome}{F\bibinitperiod}{Francis}{F\bibinitperiod}{van\bibnamedelimb der\bibnamedelima valt}{v\bibinitperiod\bibinitdelim d\bibinitperiod\bibinitdelim v\bibinitperiod}{}{}}%
    }
    \strng{namehash}{vdvFF1}
    \strng{fullhash}{vdvFF1}
    \field{sortinit}{v}
  \endentry

|;

my $l7 = q|  \entry{L7}{book}{}
    \name{labelname}{1}{%
      {{Gloom}{G\bibinitperiod}{Gregory\bibnamedelima R.}{G\bibinitperiod\bibinitdelim R\bibinitperiod}{van}{v\bibinitperiod}{}{}}%
    }
    \name{author}{1}{%
      {{Gloom}{G\bibinitperiod}{Gregory\bibnamedelima R.}{G\bibinitperiod\bibinitdelim R\bibinitperiod}{van}{v\bibinitperiod}{}{}}%
    }
    \strng{namehash}{vGGR1}
    \strng{fullhash}{vGGR1}
    \field{sortinit}{v}
  \endentry

|;

my $l8 = q|  \entry{L8}{book}{}
    \name{labelname}{1}{%
      {{Henkel}{H\bibinitperiod}{Henry\bibnamedelima F.}{H\bibinitperiod\bibinitdelim F\bibinitperiod}{van}{v\bibinitperiod}{}{}}%
    }
    \name{author}{1}{%
      {{Henkel}{H\bibinitperiod}{Henry\bibnamedelima F.}{H\bibinitperiod\bibinitdelim F\bibinitperiod}{van}{v\bibinitperiod}{}{}}%
    }
    \strng{namehash}{vHHF1}
    \strng{fullhash}{vHHF1}
    \field{sortinit}{v}
  \endentry

|;

my $l9 = q|  \entry{L9}{book}{}
    \name{labelname}{1}{%
      {{{Iliad\bibnamedelimb Ipswich}}{I\bibinitperiod}{Ian}{I\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{{Iliad\bibnamedelimb Ipswich}}{I\bibinitperiod}{Ian}{I\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{II1}
    \strng{fullhash}{II1}
    \field{sortinit}{I}
  \endentry

|;


my $l10 = q|  \entry{L10}{book}{}
    \name{labelname}{1}{%
      {{Jolly}{J\bibinitperiod}{James}{J\bibinitperiod}{}{}{III}{I\bibinitperiod}}%
    }
    \name{author}{1}{%
      {{Jolly}{J\bibinitperiod}{James}{J\bibinitperiod}{}{}{III}{I\bibinitperiod}}%
    }
    \strng{namehash}{JIJ1}
    \strng{fullhash}{JIJ1}
    \field{sortinit}{J}
  \endentry

|;


my $l10a = q|  \entry{L10a}{book}{}
    \name{labelname}{1}{%
      {{Pimentel}{P\bibinitperiod}{Joseph\bibnamedelima J.}{J\bibinitperiod\bibinitdelim J\bibinitperiod}{}{}{Jr.}{J\bibinitperiod}}%
    }
    \name{author}{1}{%
      {{Pimentel}{P\bibinitperiod}{Joseph\bibnamedelima J.}{J\bibinitperiod\bibinitdelim J\bibinitperiod}{}{}{Jr.}{J\bibinitperiod}}%
    }
    \strng{namehash}{PJJJ1}
    \strng{fullhash}{PJJJ1}
    \field{sortinit}{P}
  \endentry

|;


my $l11 = q|  \entry{L11}{book}{}
    \name{labelname}{1}{%
      {{Kluster}{K\bibinitperiod}{Kevin}{K\bibinitperiod}{van}{v\bibinitperiod}{Jr.}{J\bibinitperiod}}%
    }
    \name{author}{1}{%
      {{Kluster}{K\bibinitperiod}{Kevin}{K\bibinitperiod}{van}{v\bibinitperiod}{Jr.}{J\bibinitperiod}}%
    }
    \strng{namehash}{vKJK1}
    \strng{fullhash}{vKJK1}
    \field{sortinit}{v}
  \endentry

|;

my $l12 = q|  \entry{L12}{book}{}
    \name{labelname}{1}{%
      {{Vall{\'e}e\bibnamedelima Poussin}{V\bibinitperiod\bibinitdelim P\bibinitperiod}{Charles\bibnamedelimb Louis\bibnamedelimb Xavier\bibnamedelima Joseph}{C\bibinitperiod\bibinitdelim L\bibinitperiod\bibinitdelim X\bibinitperiod\bibinitdelim J\bibinitperiod}{de\bibnamedelima la}{d\bibinitperiod\bibinitdelim l\bibinitperiod}{}{}}%
    }
    \name{author}{1}{%
      {{Vall{\'e}e\bibnamedelima Poussin}{V\bibinitperiod\bibinitdelim P\bibinitperiod}{Charles\bibnamedelimb Louis\bibnamedelimb Xavier\bibnamedelima Joseph}{C\bibinitperiod\bibinitdelim L\bibinitperiod\bibinitdelim X\bibinitperiod\bibinitdelim J\bibinitperiod}{de\bibnamedelima la}{d\bibinitperiod\bibinitdelim l\bibinitperiod}{}{}}%
    }
    \strng{namehash}{dlVPCLXJ1}
    \strng{fullhash}{dlVPCLXJ1}
    \field{sortinit}{d}
  \endentry

|;

my $l13 = q|  \entry{L13}{book}{}
    \name{labelname}{1}{%
      {{Van\bibnamedelimb de\bibnamedelima Graaff}{V\bibinitperiod\bibinitdelim d\bibinitperiod\bibinitdelim G\bibinitperiod}{R.\bibnamedelima J.}{R\bibinitperiod\bibinitdelim J\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Van\bibnamedelimb de\bibnamedelima Graaff}{V\bibinitperiod\bibinitdelim d\bibinitperiod\bibinitdelim G\bibinitperiod}{R.\bibnamedelima J.}{R\bibinitperiod\bibinitdelim J\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{VdGRJ1}
    \strng{fullhash}{VdGRJ1}
    \field{sortinit}{V}
  \endentry

|;

my $l14 = q|  \entry{L14}{book}{}
    \name{labelname}{1}{%
      {{St\bibnamedelima John-Mollusc}{S\bibinitperiod\bibinitdelim J\bibinithyphendelim M\bibinitperiod}{Oliver}{O\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{St\bibnamedelima John-Mollusc}{S\bibinitperiod\bibinitdelim J\bibinithyphendelim M\bibinitperiod}{Oliver}{O\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{SJ-MO1}
    \strng{fullhash}{SJ-MO1}
    \field{sortinit}{S}
  \endentry

|;

my $l15 = q|  \entry{L15}{book}{}
    \name{labelname}{1}{%
      {{Gompel}{G\bibinitperiod}{Roger\bibnamedelima P.{\,}G.}{R\bibinitperiod\bibinitdelim P\bibinitperiod}{van}{v\bibinitperiod}{}{}}%
    }
    \name{author}{1}{%
      {{Gompel}{G\bibinitperiod}{Roger\bibnamedelima P.{\,}G.}{R\bibinitperiod\bibinitdelim P\bibinitperiod}{van}{v\bibinitperiod}{}{}}%
    }
    \strng{namehash}{vGRP1}
    \strng{fullhash}{vGRP1}
    \field{sortinit}{v}
  \endentry

|;

my $l16 = q|  \entry{L16}{book}{}
    \name{labelname}{1}{%
      {{Gompel}{G\bibinitperiod}{Roger\bibnamedelima {P.\,G.}}{R\bibinitperiod\bibinitdelim P\bibinitperiod}{van}{v\bibinitperiod}{}{}}%
    }
    \name{author}{1}{%
      {{Gompel}{G\bibinitperiod}{Roger\bibnamedelima {P.\,G.}}{R\bibinitperiod\bibinitdelim P\bibinitperiod}{van}{v\bibinitperiod}{}{}}%
    }
    \strng{namehash}{vGRP1}
    \strng{fullhash}{vGRP1}
    \field{sortinit}{v}
  \endentry

|;

my $l17 = q|  \entry{L17}{book}{}
    \name{labelname}{1}{%
      {{Lovecraft}{L\bibinitperiod}{Bill\bibnamedelima H.{\,}P.}{B\bibinitperiod\bibinitdelim H\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Lovecraft}{L\bibinitperiod}{Bill\bibnamedelima H.{\,}P.}{B\bibinitperiod\bibinitdelim H\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{LBH1}
    \strng{fullhash}{LBH1}
    \field{sortinit}{L}
  \endentry

|;

my $l18 = q|  \entry{L18}{book}{}
    \name{labelname}{1}{%
      {{Lovecraft}{L\bibinitperiod}{Bill\bibnamedelima {H.\,P.}}{B\bibinitperiod\bibinitdelim H\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Lovecraft}{L\bibinitperiod}{Bill\bibnamedelima {H.\,P.}}{B\bibinitperiod\bibinitdelim H\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{LBH1}
    \strng{fullhash}{LBH1}
    \field{sortinit}{L}
  \endentry

|;

my $l19 = q|  \entry{L19}{book}{}
    \name{labelname}{1}{%
      {{Mustermann}{M\bibinitperiod}{Klaus-Peter}{K\bibinithyphendelim P\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Mustermann}{M\bibinitperiod}{Klaus-Peter}{K\bibinithyphendelim P\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{MK-P1}
    \strng{fullhash}{MK-P1}
    \field{sortinit}{M}
  \endentry

|;

my $l20 = q|  \entry{L20}{book}{}
    \name{labelname}{1}{%
      {{Ford}{F\bibinitperiod}{{John\bibnamedelimb Henry}}{J\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Ford}{F\bibinitperiod}{{John\bibnamedelimb Henry}}{J\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{FJ1}
    \strng{fullhash}{FJ1}
    \field{sortinit}{F}
  \endentry

|;

my $l21 = q|  \entry{L21}{book}{}
    \name{labelname}{1}{%
      {{Smith}{S\bibinitperiod}{{\v S}omeone}{{\v S}\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Smith}{S\bibinitperiod}{{\v S}omeone}{{\v S}\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{Sv:S1}
    \strng{fullhash}{Sv:S1}
    \field{sortinit}{S}
  \endentry

|;

my $l22u = q|  \entry{L22}{book}{}
    \name{labelname}{1}{%
      {{Šmith}{Š\bibinitperiod}{Someone}{S\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Šmith}{Š\bibinitperiod}{Someone}{S\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{ŠS1}
    \strng{fullhash}{ŠS1}
    \field{sortinit}{Š}
  \endentry

|;


my $l22 = q|  \entry{L22}{book}{}
    \name{labelname}{1}{%
      {{{\v S}mith}{{\v S}\bibinitperiod}{Someone}{S\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{{\v S}mith}{{\v S}\bibinitperiod}{Someone}{S\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{v:SS1}
    \strng{fullhash}{v:SS1}
    \field{sortinit}{\v{S}}
  \endentry

|;


my $l23 = q|  \entry{L23}{book}{}
    \name{labelname}{1}{%
      {{Smith}{S\bibinitperiod}{Šomeone}{Š\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Smith}{S\bibinitperiod}{Šomeone}{Š\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{SŠ1}
    \strng{fullhash}{SŠ1}
    \field{sortinit}{S}
  \endentry

|;

my $l24 = q|  \entry{L24}{book}{}
    \name{labelname}{1}{%
      {{Šmith}{Š\bibinitperiod}{Someone}{S\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Šmith}{Š\bibinitperiod}{Someone}{S\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{ŠS1}
    \strng{fullhash}{ŠS1}
    \field{sortinit}{Š}
  \endentry

|;

my $l25 = q|  \entry{L25}{book}{}
    \name{labelname}{1}{%
      {{{American\bibnamedelimb Psychological\bibnamedelimb Association,\bibnamedelimb Task\bibnamedelimb Force\bibnamedelimb on\bibnamedelimb the\bibnamedelimb Sexualization\bibnamedelimb of\bibnamedelimb Girls}}{A\bibinitperiod}{}{}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{{American\bibnamedelimb Psychological\bibnamedelimb Association,\bibnamedelimb Task\bibnamedelimb Force\bibnamedelimb on\bibnamedelimb the\bibnamedelimb Sexualization\bibnamedelimb of\bibnamedelimb Girls}}{A\bibinitperiod}{}{}{}{}{}{}}%
    }
    \strng{namehash}{A1}
    \strng{fullhash}{A1}
    \field{sortinit}{A}
  \endentry

|;

my $l26 = q|  \entry{L26}{book}{}
    \name{labelname}{1}{%
      {{{Sci-Art\bibnamedelimb Publishers}}{S\bibinitperiod}{}{}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{{Sci-Art\bibnamedelimb Publishers}}{S\bibinitperiod}{}{}{}{}{}{}}%
    }
    \strng{namehash}{S1}
    \strng{fullhash}{S1}
    \field{sortinit}{S}
  \endentry

|;

# Malformed anyway but a decent test
my $l28 = q|  \entry{L28}{book}{}
    \strng{namehash}{1}
    \strng{fullhash}{1}
    \field{sortinit}{0}
    \warn{\item Name "Deux et al.,, O." is malformed (consecutive commas): skipping name}
  \endentry

|;


my $l29 = q|  \entry{L29}{book}{}
    \name{labelname}{1}{%
      {{{U.S.\bibnamedelimb Department\bibnamedelimb of\bibnamedelimb Health\bibnamedelimb and\bibnamedelimb Human\bibnamedelimb Services,\bibnamedelimb National\bibnamedelimb Institute\bibnamedelimb of\bibnamedelimb Mental\bibnamedelimb Health,\bibnamedelimb National\bibnamedelimb Heart,\bibnamedelimb Lung\bibnamedelimb and\bibnamedelimb Blood\bibnamedelimb Institute}}{U\bibinitperiod}{}{}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{{U.S.\bibnamedelimb Department\bibnamedelimb of\bibnamedelimb Health\bibnamedelimb and\bibnamedelimb Human\bibnamedelimb Services,\bibnamedelimb National\bibnamedelimb Institute\bibnamedelimb of\bibnamedelimb Mental\bibnamedelimb Health,\bibnamedelimb National\bibnamedelimb Heart,\bibnamedelimb Lung\bibnamedelimb and\bibnamedelimb Blood\bibnamedelimb Institute}}{U\bibinitperiod}{}{}{}{}{}{}}%
    }
    \strng{namehash}{U1}
    \strng{fullhash}{U1}
    \field{sortinit}{U}
  \endentry

|;

my $l31 = q|  \entry{L31}{book}{}
    \name{labelname}{1}{%
      {{{\~ Z}elly}{{\~ Z}\bibinitperiod}{Arthur}{A\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{{\~ Z}elly}{{\~ Z}\bibinitperiod}{Arthur}{A\bibinitperiod}{}{}{}{}}%
    }
    \name{editor}{1}{%
      {{{\~Z}elly}{{\~Z}\bibinitperiod}{Arthur}{A\bibinitperiod}{}{}{}{}}%
    }
    \name{translator}{1}{%
      {{{\~{Z}}elly}{{\~{Z}}\bibinitperiod}{Arthur}{A\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{126:ZA1}
    \strng{fullhash}{126:ZA1}
    \field{sortinit}{Z}
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
is_deeply(Biber::Input::file::bibtex::parsename('E. S. El-{M}allah', 'author'), $name15, 'parsename 15');
is_deeply(Biber::Input::file::bibtex::parsename('E. S. {K}ent-{B}oswell', 'author'), $name16, 'parsename 16');

is( $out->get_output_entry($main,'l1'), $l1, 'First Last') ;
is( $out->get_output_entry($main,'l2'), $l2, 'First Initial. Last') ;
is( $out->get_output_entry($main,'l3'), $l3, 'Initial. Initial. Last') ;
is( $out->get_output_entry($main,'l4'), $l4, 'First Initial Last') ;
is( $out->get_output_entry($main,'l5'), $l5, 'First prefix Last') ;
is( $out->get_output_entry($main,'l6'), $l6, 'First prefix prefix Last') ;
is( $out->get_output_entry($main,'l7'), $l7, 'First Initial. prefix Last') ;
is( $out->get_output_entry($main,'l8'), $l8, 'First Initial prefix Last') ;
is( $out->get_output_entry($main,'l9'), $l9, 'First {Last Last}') ;
is( $out->get_output_entry($main,'l10'), $l10, 'Last, Suffix, First') ;
is( $out->get_output_entry($main,'l10a'), $l10a, 'Last, Suffix, First Initial.') ;
is( $out->get_output_entry($main,'l11'), $l11, 'prefix Last, Suffix, First') ;
is( $out->get_output_entry($main,'l13'), $l13, 'Last Last Last, Initial. Initial.');
is( $out->get_output_entry($main,'l14'), $l14, 'Last Last-Last, First');
is( $out->get_output_entry($main,'l15'), $l15, 'First F.{\bibinitdelim }F. Last');
is( $out->get_output_entry($main,'l16'), $l16, 'First {F.\bibinitdelim F.} Last');
is( $out->get_output_entry($main,'l17'), $l17, 'Last, First {F.\bibinitdelim F.}');
is( $out->get_output_entry($main,'l18'), $l18, 'Last, First F.{\bibinitdelim }F.');
is( $out->get_output_entry($main,'l19'), $l19, 'Firstname with hyphen');
is( $out->get_output_entry($main,'l20'), $l20, 'Protected dual first name');
is( $out->get_output_entry($main,'l22'), $l22u, 'LaTeX encoded unicode lastname');
is( $out->get_output_entry($main,'l23'), $l23, 'Unicode firstname');
is( $out->get_output_entry($main,'l24'), $l24, 'Unicode lastname');
is( $out->get_output_entry($main,'l25'), $l25, 'Single string name');
is( $out->get_output_entry($main,'l26'), $l26, 'Hyphen at brace level <> 0');
is($section->bibentry('l27')->get_field('author')->count_elements, 1, 'Bad name with 3 commas');
is( $out->get_output_entry($main,'l28'), $l28, 'Bad name with consecutive commas');
is( $out->get_output_entry($main,'l29'), $l29, 'Escaped name with 3 commas');

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
$main = $section->get_list('MAIN');
$bibentries = $section->bibentries;

is_deeply($bibentries->entry('l21')->get_field($bibentries->entry('l21')->get_field('labelnamename'))->nth_element(1)->get_firstname_i, ['{\v S}'], 'Terseinitials 1');
is( $out->get_output_entry($main,'l12'), $l12, 'First First First First prefix prefix Last Last') ;
is( $out->get_output_entry($main,'l21'), $l21, 'LaTeX encoded unicode firstname');
is( $out->get_output_entry($main,'l22'), $l22, 'LaTeX encoded unicode lastname');
is( $out->get_output_entry($main,'l31'), $l31, 'LaTeX encoded unicode lastname with tie char');

unlink <*.utf8>;
