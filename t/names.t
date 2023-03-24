# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 75;
use Test::Differences;
unified_diff;

use Biber;
use Biber::Utils;
use Biber::Output::bbl;
use Log::Log4perl;
use Unicode::Normalize;
use Encode;
chdir("t/tdata");

# Set up Biber object
my $biber = Biber->new(noconf => 1);
my $LEVEL = 'ERROR';
my $l4pconf = qq|
    log4perl.category.main                             = $LEVEL, Screen
    log4perl.category.screen                           = $LEVEL, Screen
    log4perl.appender.Screen                           = Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.utf8                      = 1
    log4perl.appender.Screen.Threshold                 = $LEVEL
    log4perl.appender.Screen.stderr                    = 0
    log4perl.appender.Screen.layout                    = Log::Log4perl::Layout::SimpleLayout
|;
Log::Log4perl->init(\$l4pconf);

$biber->parse_ctrlfile('names.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('namesep', 'und'); # Testing custom name splitting string
Biber::Config->setoption('others_string', 'andere'); # Testing custom implied "et al"
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');
Biber::Config->setblxoption(undef,'mincitenames', 3);

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $main = $biber->datalists->get_list('custom/global//global/global/global');
my $nhtest = $biber->datalists->get_list('custom/global//global/global/test');
my $bibentries = $section->bibentries;

my $name1 =
    { given               => {string => 'John', initial => ['J']},
      family              => {string => 'Doe', initial => ['D']},
      prefix              => {string => undef, initial => undef},
      suffix              => {string => undef, initial => undef}};

my $name2 =
    { given               => {string => 'John', initial => ['J']},
      family              => {string => 'Doe', initial  => ['D']},
      prefix              => {string => undef, initial => undef},
      suffix              => {string => 'Jr', initial => ['J']}};

my $name3 =
    { given               => {string => 'Johann~Gottfried', initial => ['J', 'G']},
      family              => {string => 'Berlichingen zu~Hornberg', initial => ['B', 'z', 'H']},
      prefix              => {string => 'von', initial => ['v']},
      suffix              => {string => undef, initial => undef}};

my $name4 =
    { given               => {string => 'Johann~Gottfried', initial => ['J', 'G']},
      family              => {string => 'Berlichingen zu~Hornberg', initial => ['B', 'z', 'H']},
      prefix              => {string => 'von', initial => ['v']},
      suffix              => {string => undef, initial => undef}};

my $name5 =
   {  given               => {string => undef, initial => undef},
      family              => {string => 'Robert and Sons, Inc.', initial => ['R']},
      prefix              => {string => undef, initial => undef},
      suffix              => {string => undef, initial => undef}};

my $name6 =
   {  given               => {string => 'ʿAbdallāh', initial => ['A']},
      family              => {string => 'al-Ṣāliḥ', initial => ['Ṣ']},
      prefix              => {string => undef, initial => undef},
      suffix              => {string => undef, initial => undef}};

my $name7 =
   {  given               => {string => 'Jean Charles~Gabriel', initial => ['J', 'C', 'G']},
      family              => {string => 'Vallée~Poussin', initial => ['V', 'P']},
      prefix              => {string => 'de~la', initial => ['d', 'l']},
      suffix              => {string => undef, initial => undef}};

my $name8 =
   {  given               => {string => 'Jean Charles Gabriel', initial => ['J']},
      family              => {string => 'Vallée~Poussin', initial => ['V', 'P']},
      prefix              => {string => 'de~la', initial => ['d', 'l']},
      suffix              => {string => undef, initial => undef}};

my $name9 =
   {  given               => {string => 'Jean Charles Gabriel {de la}~Vallée', initial => ['J', 'C', 'G', 'd', 'V']},
      family              => {string => 'Poussin', initial => ['P']},
      prefix              => {string => undef, initial => undef},
      suffix              => {string => undef, initial => undef}};

my $name10 =
   {  given               => {string => 'Jean Charles~Gabriel', initial => ['J', 'C', 'G']},
      family              => {string => 'Vallée Poussin', initial => ['V']},
      prefix              => {string => 'de~la', initial => ['d', 'l']},
      suffix              => {string => undef, initial => undef}};

my $name11 =
   {  given               => {string => 'Jean Charles Gabriel', initial => ['J']},
      family              => {string => 'Vallée Poussin', initial => ['V']},
      prefix              => {string => 'de~la', initial => ['d', 'l']},
      suffix              => {string => undef, initial => undef}};

my $name12 =
   {  given               => {string => 'Jean Charles~Gabriel', initial => ['J', 'C', 'G']},
      family              => {string => 'Poussin', initial => ['P']},
      prefix              => {string => undef, initial => undef},
      suffix              => {string => undef, initial => undef}};

my $name13 =
   {  given               => {string => 'Jean~Charles', initial => ['J', 'C']},
      family              => {string => 'Poussin Lecoq', initial => ['P']},
      prefix              => {string => undef, initial => undef},
      suffix              => {string => undef, initial => undef}};

my $name14 =
   {  given               => {string => 'J.~C.~G.', initial => ['J', 'C', 'G']},
      family              => {string => 'Vallée~Poussin', initial => ['V', 'P']},
      prefix              => {string => 'de~la', initial => ['d', 'l']},
      suffix              => {string => undef, initial => undef}};

my $namepre1 =
   {  given               => {string => 'Tawfik', initial => ['T']},
      family              => {string => 'Hakim', initial => ['H']},
      prefix              => {string => 'al-', initial => ['a']},
      suffix              => {string => undef, initial => undef}};

# Note that the family initials are wrong because the prefix "El-" was not stripped
# This is because the default noinit regexp only strips lower-case prefices to protect
# hyphenated names
my $name15 =
   {  given               => {string => 'E.~S.', initial => ['E', 'S']},
      family              => {string => 'El-{M}allah', initial => ['E-M']},
      prefix              => {string => undef, initial => undef},
      suffix              => {string => undef, initial => undef}};

my $name16 =
   {  given               => {string => 'E.~S.', initial => ['E', 'S']},
      family              => {string => '{K}ent-{B}oswell', initial => ['K-B']},
      prefix              => {string => undef, initial => undef},
      suffix              => {string => undef, initial => undef}};

my $name17 =
   {  given               => {string => 'A.~N.', initial => ['A', 'N']},
      family              => {string => 'Other', initial => ['O']},
      prefix              => {string => undef, initial => undef},
      suffix              => {string => undef, initial => undef}};

my $name18 =
   {  given               => {string => undef, initial => undef},
      family              => {string => 'British National Corpus', initial => ['B']},
      prefix              => {string => undef, initial => undef},
      suffix              => {string => undef, initial => undef}};
my $name18strip = { given => undef, family => 1, prefix => undef, suffix => undef };

my $name19 =
   {  given               => {string => 'Luis', initial => ['L']},
      family              => {string => 'Vázques{ de }Parga', initial => ['V']},
      prefix              => {string => undef, initial => undef},
      suffix              => {string => undef, initial => undef}};

my $namex1 =
   {  given               => {string => 'James', initial => ['J']},
      family              => {string => 'Smithers~Jones', initial => ['S','J']},
      prefix              => {string => 'van~der', initial => ['v','d']},
      suffix              => {string => undef, initial => undef}};

my $l1 = q|    \entry{L1}{book}{}{}
      \name{author}{1}{}{%
        {{hash=72287a68c1714cb1b9f4ab9e03a88b96}{%
           family={Adler},
           familyi={A\bibinitperiod},
           given={Alfred},
           giveni={A\bibinitperiod}}}%
      }
      \strng{namehash}{72287a68c1714cb1b9f4ab9e03a88b96}
      \strng{fullhash}{72287a68c1714cb1b9f4ab9e03a88b96}
      \strng{fullhashraw}{72287a68c1714cb1b9f4ab9e03a88b96}
      \strng{bibnamehash}{72287a68c1714cb1b9f4ab9e03a88b96}
      \strng{authorbibnamehash}{72287a68c1714cb1b9f4ab9e03a88b96}
      \strng{authornamehash}{72287a68c1714cb1b9f4ab9e03a88b96}
      \strng{authorfullhash}{72287a68c1714cb1b9f4ab9e03a88b96}
      \strng{authorfullhashraw}{72287a68c1714cb1b9f4ab9e03a88b96}
      \field{extraname}{1}
      \field{sortinit}{A}
      \field{sortinithash}{2f401846e2029bad6b3ecc16d50031e2}
      \field{labelnamesource}{author}
    \endentry
|;

my $l1id = q|    \entry{L1id}{book}{}{}
      \name{author}{1}{}{%
        {{hash=88354d4ba914f2ded2574386a2493996}{%
           family={Adler},
           familyi={A\bibinitperiod},
           given={Alfred},
           giveni={A\bibinitperiod}}}%
      }
      \strng{namehash}{88354d4ba914f2ded2574386a2493996}
      \strng{fullhash}{88354d4ba914f2ded2574386a2493996}
      \strng{fullhashraw}{72287a68c1714cb1b9f4ab9e03a88b96}
      \strng{bibnamehash}{88354d4ba914f2ded2574386a2493996}
      \strng{authorbibnamehash}{88354d4ba914f2ded2574386a2493996}
      \strng{authornamehash}{88354d4ba914f2ded2574386a2493996}
      \strng{authorfullhash}{88354d4ba914f2ded2574386a2493996}
      \strng{authorfullhashraw}{72287a68c1714cb1b9f4ab9e03a88b96}
      \field{extraname}{2}
      \field{sortinit}{A}
      \field{sortinithash}{2f401846e2029bad6b3ecc16d50031e2}
      \field{labelnamesource}{author}
    \endentry
|;

my $l1h = q|    \entry{L1}{book}{}{}
      \name{author}{1}{}{%
        {{hash=a4e132fab651ba62e051557227672cda}{%
           family={Adler},
           familyi={A\bibinitperiod},
           given={Alfred},
           giveni={A\bibinitperiod}}}%
      }
      \strng{namehash}{a4e132fab651ba62e051557227672cda}
      \strng{fullhash}{a4e132fab651ba62e051557227672cda}
      \strng{fullhashraw}{72287a68c1714cb1b9f4ab9e03a88b96}
      \strng{bibnamehash}{a4e132fab651ba62e051557227672cda}
      \strng{authorbibnamehash}{a4e132fab651ba62e051557227672cda}
      \strng{authornamehash}{a4e132fab651ba62e051557227672cda}
      \strng{authorfullhash}{a4e132fab651ba62e051557227672cda}
      \strng{authorfullhashraw}{72287a68c1714cb1b9f4ab9e03a88b96}
      \field{extraname}{1}
      \field{sortinit}{A}
      \field{sortinithash}{2f401846e2029bad6b3ecc16d50031e2}
      \field{labelnamesource}{author}
    \endentry
|;

my $l2 = q|    \entry{L2}{book}{}{}
      \name{author}{1}{}{%
        {{hash=2098d59d0f19a2e003ee06c1aa750d57}{%
           family={Bull},
           familyi={B\bibinitperiod},
           given={Bertie\bibnamedelima B.},
           giveni={B\bibinitperiod\bibinitdelim B\bibinitperiod}}}%
      }
      \strng{namehash}{2098d59d0f19a2e003ee06c1aa750d57}
      \strng{fullhash}{2098d59d0f19a2e003ee06c1aa750d57}
      \strng{fullhashraw}{2098d59d0f19a2e003ee06c1aa750d57}
      \strng{bibnamehash}{2098d59d0f19a2e003ee06c1aa750d57}
      \strng{authorbibnamehash}{2098d59d0f19a2e003ee06c1aa750d57}
      \strng{authornamehash}{2098d59d0f19a2e003ee06c1aa750d57}
      \strng{authorfullhash}{2098d59d0f19a2e003ee06c1aa750d57}
      \strng{authorfullhashraw}{2098d59d0f19a2e003ee06c1aa750d57}
      \field{sortinit}{B}
      \field{sortinithash}{d7095fff47cda75ca2589920aae98399}
      \field{labelnamesource}{author}
    \endentry
|;

my $l3 = q|    \entry{L3}{book}{}{}
      \name{author}{1}{}{%
        {{hash=c8b06fe88bde128b25eb0b3b1cc5837c}{%
           family={Crop},
           familyi={C\bibinitperiod},
           given={C.\bibnamedelimi Z.},
           giveni={C\bibinitperiod\bibinitdelim Z\bibinitperiod}}}%
      }
      \strng{namehash}{c8b06fe88bde128b25eb0b3b1cc5837c}
      \strng{fullhash}{c8b06fe88bde128b25eb0b3b1cc5837c}
      \strng{fullhashraw}{c8b06fe88bde128b25eb0b3b1cc5837c}
      \strng{bibnamehash}{c8b06fe88bde128b25eb0b3b1cc5837c}
      \strng{authorbibnamehash}{c8b06fe88bde128b25eb0b3b1cc5837c}
      \strng{authornamehash}{c8b06fe88bde128b25eb0b3b1cc5837c}
      \strng{authorfullhash}{c8b06fe88bde128b25eb0b3b1cc5837c}
      \strng{authorfullhashraw}{c8b06fe88bde128b25eb0b3b1cc5837c}
      \field{sortinit}{C}
      \field{sortinithash}{4d103a86280481745c9c897c925753c0}
      \field{labelnamesource}{author}
    \endentry
|;

my $l4 = q|    \entry{L4}{book}{}{}
      \name{author}{1}{}{%
        {{hash=5ec958b850c0c2de7de7c42c84b9c419}{%
           family={Decket},
           familyi={D\bibinitperiod},
           given={Derek\bibnamedelima D},
           giveni={D\bibinitperiod\bibinitdelim D\bibinitperiod}}}%
      }
      \strng{namehash}{5ec958b850c0c2de7de7c42c84b9c419}
      \strng{fullhash}{5ec958b850c0c2de7de7c42c84b9c419}
      \strng{fullhashraw}{5ec958b850c0c2de7de7c42c84b9c419}
      \strng{bibnamehash}{5ec958b850c0c2de7de7c42c84b9c419}
      \strng{authorbibnamehash}{5ec958b850c0c2de7de7c42c84b9c419}
      \strng{authornamehash}{5ec958b850c0c2de7de7c42c84b9c419}
      \strng{authorfullhash}{5ec958b850c0c2de7de7c42c84b9c419}
      \strng{authorfullhashraw}{5ec958b850c0c2de7de7c42c84b9c419}
      \field{sortinit}{D}
      \field{sortinithash}{6f385f66841fb5e82009dc833c761848}
      \field{labelnamesource}{author}
    \endentry
|;

my $l5 = q|    \entry{L5}{book}{}{}
      \name{author}{1}{}{%
        {{hash=c6b9d281cc1ff3f35570f76f463d4244}{%
           family={Eel},
           familyi={E\\bibinitperiod},
           given={Egbert},
           giveni={E\\bibinitperiod},
           prefix={von},
           prefixi={v\\bibinitperiod}}}%
      }
      \strng{namehash}{c6b9d281cc1ff3f35570f76f463d4244}
      \strng{fullhash}{c6b9d281cc1ff3f35570f76f463d4244}
      \strng{fullhashraw}{c6b9d281cc1ff3f35570f76f463d4244}
      \strng{bibnamehash}{c6b9d281cc1ff3f35570f76f463d4244}
      \strng{authorbibnamehash}{c6b9d281cc1ff3f35570f76f463d4244}
      \strng{authornamehash}{c6b9d281cc1ff3f35570f76f463d4244}
      \strng{authorfullhash}{c6b9d281cc1ff3f35570f76f463d4244}
      \strng{authorfullhashraw}{c6b9d281cc1ff3f35570f76f463d4244}
      \field{sortinit}{v}
      \field{sortinithash}{afb52128e5b4dc4b843768c0113d673b}
      \field{labelnamesource}{author}
    \endentry
|;

my $l6 = q|    \entry{L6}{book}{}{}
      \name{author}{1}{}{%
        {{hash=5fd24d3d1608a310ec205a6b201a5495}{%
           family={Frome},
           familyi={F\\bibinitperiod},
           given={Francis},
           giveni={F\\bibinitperiod},
           prefix={van\\bibnamedelimb der\\bibnamedelima valt},
           prefixi={v\\bibinitperiod\\bibinitdelim d\\bibinitperiod\\bibinitdelim v\\bibinitperiod}}}%
      }
      \strng{namehash}{5fd24d3d1608a310ec205a6b201a5495}
      \strng{fullhash}{5fd24d3d1608a310ec205a6b201a5495}
      \strng{fullhashraw}{5fd24d3d1608a310ec205a6b201a5495}
      \strng{bibnamehash}{5fd24d3d1608a310ec205a6b201a5495}
      \strng{authorbibnamehash}{5fd24d3d1608a310ec205a6b201a5495}
      \strng{authornamehash}{5fd24d3d1608a310ec205a6b201a5495}
      \strng{authorfullhash}{5fd24d3d1608a310ec205a6b201a5495}
      \strng{authorfullhashraw}{5fd24d3d1608a310ec205a6b201a5495}
      \field{sortinit}{v}
      \field{sortinithash}{afb52128e5b4dc4b843768c0113d673b}
      \field{labelnamesource}{author}
    \endentry
|;

my $l7 = q|    \entry{L7}{book}{}{}
      \name{author}{1}{}{%
        {{hash=98edb0b90251df22b74328d9227eceb7}{%
           family={Gloom},
           familyi={G\\bibinitperiod},
           given={Gregory\\bibnamedelima R.},
           giveni={G\\bibinitperiod\\bibinitdelim R\\bibinitperiod},
           prefix={van},
           prefixi={v\\bibinitperiod}}}%
      }
      \strng{namehash}{98edb0b90251df22b74328d9227eceb7}
      \strng{fullhash}{98edb0b90251df22b74328d9227eceb7}
      \strng{fullhashraw}{98edb0b90251df22b74328d9227eceb7}
      \strng{bibnamehash}{98edb0b90251df22b74328d9227eceb7}
      \strng{authorbibnamehash}{98edb0b90251df22b74328d9227eceb7}
      \strng{authornamehash}{98edb0b90251df22b74328d9227eceb7}
      \strng{authorfullhash}{98edb0b90251df22b74328d9227eceb7}
      \strng{authorfullhashraw}{98edb0b90251df22b74328d9227eceb7}
      \field{sortinit}{v}
      \field{sortinithash}{afb52128e5b4dc4b843768c0113d673b}
      \field{labelnamesource}{author}
    \endentry
|;

my $l8 = q|    \entry{L8}{book}{}{}
      \name{author}{1}{}{%
        {{hash=1211dc8dbbc191cbcab4da3c3c1fc48a}{%
           family={Henkel},
           familyi={H\\bibinitperiod},
           given={Henry\\bibnamedelima F.},
           giveni={H\\bibinitperiod\\bibinitdelim F\\bibinitperiod},
           prefix={van},
           prefixi={v\\bibinitperiod}}}%
      }
      \strng{namehash}{1211dc8dbbc191cbcab4da3c3c1fc48a}
      \strng{fullhash}{1211dc8dbbc191cbcab4da3c3c1fc48a}
      \strng{fullhashraw}{1211dc8dbbc191cbcab4da3c3c1fc48a}
      \strng{bibnamehash}{1211dc8dbbc191cbcab4da3c3c1fc48a}
      \strng{authorbibnamehash}{1211dc8dbbc191cbcab4da3c3c1fc48a}
      \strng{authornamehash}{1211dc8dbbc191cbcab4da3c3c1fc48a}
      \strng{authorfullhash}{1211dc8dbbc191cbcab4da3c3c1fc48a}
      \strng{authorfullhashraw}{1211dc8dbbc191cbcab4da3c3c1fc48a}
      \field{sortinit}{v}
      \field{sortinithash}{afb52128e5b4dc4b843768c0113d673b}
      \field{labelnamesource}{author}
    \endentry
|;

my $l9 = q|    \entry{L9}{book}{}{}
      \name{author}{1}{}{%
        {{hash=bae61a889ab149a6deafe45333204cf0}{%
           family={{Iliad Ipswich}},
           familyi={I\bibinitperiod},
           given={Ian},
           giveni={I\bibinitperiod}}}%
      }
      \strng{namehash}{bae61a889ab149a6deafe45333204cf0}
      \strng{fullhash}{bae61a889ab149a6deafe45333204cf0}
      \strng{fullhashraw}{bae61a889ab149a6deafe45333204cf0}
      \strng{bibnamehash}{bae61a889ab149a6deafe45333204cf0}
      \strng{authorbibnamehash}{bae61a889ab149a6deafe45333204cf0}
      \strng{authornamehash}{bae61a889ab149a6deafe45333204cf0}
      \strng{authorfullhash}{bae61a889ab149a6deafe45333204cf0}
      \strng{authorfullhashraw}{bae61a889ab149a6deafe45333204cf0}
      \field{sortinit}{I}
      \field{sortinithash}{8d291c51ee89b6cd86bf5379f0b151d8}
      \field{labelnamesource}{author}
    \endentry
|;


my $l10 = q|    \entry{L10}{book}{}{}
      \name{author}{1}{}{%
        {{hash=37b4325752e394ddfb2fc810f6c88e27}{%
           family={Jolly},
           familyi={J\\bibinitperiod},
           given={James},
           giveni={J\\bibinitperiod},
           suffix={III},
           suffixi={I\\bibinitperiod}}}%
      }
      \strng{namehash}{37b4325752e394ddfb2fc810f6c88e27}
      \strng{fullhash}{37b4325752e394ddfb2fc810f6c88e27}
      \strng{fullhashraw}{37b4325752e394ddfb2fc810f6c88e27}
      \strng{bibnamehash}{37b4325752e394ddfb2fc810f6c88e27}
      \strng{authorbibnamehash}{37b4325752e394ddfb2fc810f6c88e27}
      \strng{authornamehash}{37b4325752e394ddfb2fc810f6c88e27}
      \strng{authorfullhash}{37b4325752e394ddfb2fc810f6c88e27}
      \strng{authorfullhashraw}{37b4325752e394ddfb2fc810f6c88e27}
      \field{sortinit}{J}
      \field{sortinithash}{b2f54a9081ace9966a7cb9413811edb4}
      \field{labelnamesource}{author}
    \endentry
|;


my $l10a = q|    \entry{L10a}{book}{}{}
      \name{author}{1}{}{%
        {{hash=7bf2c9d8b89a1930ee91bfddcaf20c9c}{%
           family={Pimentel},
           familyi={P\\bibinitperiod},
           given={Joseph\\bibnamedelima J.},
           giveni={J\\bibinitperiod\\bibinitdelim J\\bibinitperiod},
           suffix={Jr.},
           suffixi={J\\bibinitperiod}}}%
      }
      \strng{namehash}{7bf2c9d8b89a1930ee91bfddcaf20c9c}
      \strng{fullhash}{7bf2c9d8b89a1930ee91bfddcaf20c9c}
      \strng{fullhashraw}{7bf2c9d8b89a1930ee91bfddcaf20c9c}
      \strng{bibnamehash}{7bf2c9d8b89a1930ee91bfddcaf20c9c}
      \strng{authorbibnamehash}{7bf2c9d8b89a1930ee91bfddcaf20c9c}
      \strng{authornamehash}{7bf2c9d8b89a1930ee91bfddcaf20c9c}
      \strng{authorfullhash}{7bf2c9d8b89a1930ee91bfddcaf20c9c}
      \strng{authorfullhashraw}{7bf2c9d8b89a1930ee91bfddcaf20c9c}
      \field{sortinit}{P}
      \field{sortinithash}{ff3bcf24f47321b42cb156c2cc8a8422}
      \field{labelnamesource}{author}
    \endentry
|;


my $l11 = q|    \entry{L11}{book}{}{}
      \name{author}{1}{}{%
        {{hash=9f48d231be68c9435fab4faca55a5caf}{%
           family={Kluster},
           familyi={K\\bibinitperiod},
           given={Kevin},
           giveni={K\\bibinitperiod},
           prefix={van},
           prefixi={v\\bibinitperiod},
           suffix={Jr.},
           suffixi={J\\bibinitperiod}}}%
      }
      \strng{namehash}{9f48d231be68c9435fab4faca55a5caf}
      \strng{fullhash}{9f48d231be68c9435fab4faca55a5caf}
      \strng{fullhashraw}{9f48d231be68c9435fab4faca55a5caf}
      \strng{bibnamehash}{9f48d231be68c9435fab4faca55a5caf}
      \strng{authorbibnamehash}{9f48d231be68c9435fab4faca55a5caf}
      \strng{authornamehash}{9f48d231be68c9435fab4faca55a5caf}
      \strng{authorfullhash}{9f48d231be68c9435fab4faca55a5caf}
      \strng{authorfullhashraw}{9f48d231be68c9435fab4faca55a5caf}
      \field{sortinit}{v}
      \field{sortinithash}{afb52128e5b4dc4b843768c0113d673b}
      \field{labelnamesource}{author}
    \endentry
|;

my $l12 = q|    \entry{L12}{book}{}{}
      \name{author}{1}{}{%
        {{hash=d7ca88c13a8f7ce1c23e920010a31f83}{%
           family={Vallée\\bibnamedelima Poussin},
           familyi={V\\bibinitperiod\\bibinitdelim P\\bibinitperiod},
           given={Charles\\bibnamedelimb Louis\\bibnamedelimb Xavier\\bibnamedelima Joseph},
           giveni={C\\bibinitperiod\\bibinitdelim L\\bibinitperiod\\bibinitdelim X\\bibinitperiod\\bibinitdelim J\\bibinitperiod},
           prefix={de\\bibnamedelima la},
           prefixi={d\\bibinitperiod\\bibinitdelim l\\bibinitperiod}}}%
      }
      \strng{namehash}{d7ca88c13a8f7ce1c23e920010a31f83}
      \strng{fullhash}{d7ca88c13a8f7ce1c23e920010a31f83}
      \strng{fullhashraw}{d7ca88c13a8f7ce1c23e920010a31f83}
      \strng{bibnamehash}{d7ca88c13a8f7ce1c23e920010a31f83}
      \strng{authorbibnamehash}{d7ca88c13a8f7ce1c23e920010a31f83}
      \strng{authornamehash}{d7ca88c13a8f7ce1c23e920010a31f83}
      \strng{authorfullhash}{d7ca88c13a8f7ce1c23e920010a31f83}
      \strng{authorfullhashraw}{d7ca88c13a8f7ce1c23e920010a31f83}
      \field{sortinit}{d}
      \field{sortinithash}{6f385f66841fb5e82009dc833c761848}
      \true{uniqueprimaryauthor}
      \field{labelnamesource}{author}
    \endentry
|;

my $l13 = q|    \entry{L13}{book}{}{}
      \name{author}{1}{}{%
        {{hash=227ac48bb788a658cfaa4eefc71ff0cc}{%
           family={Van\bibnamedelimb de\bibnamedelima Graaff},
           familyi={V\bibinitperiod\bibinitdelim d\bibinitperiod\bibinitdelim G\bibinitperiod},
           given={R.\bibnamedelimi J.},
           giveni={R\bibinitperiod\bibinitdelim J\bibinitperiod}}}%
      }
      \strng{namehash}{227ac48bb788a658cfaa4eefc71ff0cc}
      \strng{fullhash}{227ac48bb788a658cfaa4eefc71ff0cc}
      \strng{fullhashraw}{227ac48bb788a658cfaa4eefc71ff0cc}
      \strng{bibnamehash}{227ac48bb788a658cfaa4eefc71ff0cc}
      \strng{authorbibnamehash}{227ac48bb788a658cfaa4eefc71ff0cc}
      \strng{authornamehash}{227ac48bb788a658cfaa4eefc71ff0cc}
      \strng{authorfullhash}{227ac48bb788a658cfaa4eefc71ff0cc}
      \strng{authorfullhashraw}{227ac48bb788a658cfaa4eefc71ff0cc}
      \field{sortinit}{V}
      \field{sortinithash}{afb52128e5b4dc4b843768c0113d673b}
      \field{labelnamesource}{author}
    \endentry
|;

my $l14 = q|    \entry{L14}{book}{}{}
      \name{author}{1}{}{%
        {{hash=779475052c17ed56dc3be900d0dfdf87}{%
           family={St\bibnamedelima John-Mollusc},
           familyi={S\bibinitperiod\bibinitdelim J\bibinithyphendelim M\bibinitperiod},
           given={Oliver},
           giveni={O\bibinitperiod}}}%
      }
      \strng{namehash}{779475052c17ed56dc3be900d0dfdf87}
      \strng{fullhash}{779475052c17ed56dc3be900d0dfdf87}
      \strng{fullhashraw}{779475052c17ed56dc3be900d0dfdf87}
      \strng{bibnamehash}{779475052c17ed56dc3be900d0dfdf87}
      \strng{authorbibnamehash}{779475052c17ed56dc3be900d0dfdf87}
      \strng{authornamehash}{779475052c17ed56dc3be900d0dfdf87}
      \strng{authorfullhash}{779475052c17ed56dc3be900d0dfdf87}
      \strng{authorfullhashraw}{779475052c17ed56dc3be900d0dfdf87}
      \field{sortinit}{S}
      \field{sortinithash}{b164b07b29984b41daf1e85279fbc5ab}
      \field{labelnamesource}{author}
    \endentry
|;

my $l15 = q|    \entry{L15}{book}{}{}
      \name{author}{1}{}{%
        {{hash=783c636e853e47a854ae034ebe9dde62}{%
           family={Gompel},
           familyi={G\\bibinitperiod},
           given={Roger\\bibnamedelima P.{\\,}G.},
           giveni={R\\bibinitperiod\\bibinitdelim P\\bibinitperiod},
           prefix={van},
           prefixi={v\\bibinitperiod}}}%
      }
      \strng{namehash}{783c636e853e47a854ae034ebe9dde62}
      \strng{fullhash}{783c636e853e47a854ae034ebe9dde62}
      \strng{fullhashraw}{783c636e853e47a854ae034ebe9dde62}
      \strng{bibnamehash}{783c636e853e47a854ae034ebe9dde62}
      \strng{authorbibnamehash}{783c636e853e47a854ae034ebe9dde62}
      \strng{authornamehash}{783c636e853e47a854ae034ebe9dde62}
      \strng{authorfullhash}{783c636e853e47a854ae034ebe9dde62}
      \strng{authorfullhashraw}{783c636e853e47a854ae034ebe9dde62}
      \field{extraname}{1}
      \field{sortinit}{v}
      \field{sortinithash}{afb52128e5b4dc4b843768c0113d673b}
      \field{labelnamesource}{author}
    \endentry
|;

my $l16 = q|    \entry{L16}{book}{}{}
      \name{author}{1}{}{%
        {{hash=783c636e853e47a854ae034ebe9dde62}{%
           family={Gompel},
           familyi={G\\bibinitperiod},
           given={Roger\\bibnamedelima {P.\\,G.}},
           giveni={R\\bibinitperiod\\bibinitdelim P\\bibinitperiod},
           prefix={van},
           prefixi={v\\bibinitperiod}}}%
      }
      \strng{namehash}{783c636e853e47a854ae034ebe9dde62}
      \strng{fullhash}{783c636e853e47a854ae034ebe9dde62}
      \strng{fullhashraw}{783c636e853e47a854ae034ebe9dde62}
      \strng{bibnamehash}{783c636e853e47a854ae034ebe9dde62}
      \strng{authorbibnamehash}{783c636e853e47a854ae034ebe9dde62}
      \strng{authornamehash}{783c636e853e47a854ae034ebe9dde62}
      \strng{authorfullhash}{783c636e853e47a854ae034ebe9dde62}
      \strng{authorfullhashraw}{783c636e853e47a854ae034ebe9dde62}
      \field{extraname}{2}
      \field{sortinit}{v}
      \field{sortinithash}{afb52128e5b4dc4b843768c0113d673b}
      \field{labelnamesource}{author}
    \endentry
|;

my $l17 = q|    \entry{L17}{book}{}{}
      \name{author}{1}{}{%
        {{hash=b51f667a3384d92ea5458ba80716bff7}{%
           family={Lovecraft},
           familyi={L\bibinitperiod},
           given={Bill\bibnamedelima H.{\,}P.},
           giveni={B\bibinitperiod\bibinitdelim H\bibinitperiod}}}%
      }
      \strng{namehash}{b51f667a3384d92ea5458ba80716bff7}
      \strng{fullhash}{b51f667a3384d92ea5458ba80716bff7}
      \strng{fullhashraw}{b51f667a3384d92ea5458ba80716bff7}
      \strng{bibnamehash}{b51f667a3384d92ea5458ba80716bff7}
      \strng{authorbibnamehash}{b51f667a3384d92ea5458ba80716bff7}
      \strng{authornamehash}{b51f667a3384d92ea5458ba80716bff7}
      \strng{authorfullhash}{b51f667a3384d92ea5458ba80716bff7}
      \strng{authorfullhashraw}{b51f667a3384d92ea5458ba80716bff7}
      \field{extraname}{1}
      \field{sortinit}{L}
      \field{sortinithash}{7c47d417cecb1f4bd38d1825c427a61a}
      \field{labelnamesource}{author}
    \endentry
|;

my $l18 = q|    \entry{L18}{book}{}{}
      \name{author}{1}{}{%
        {{hash=b51f667a3384d92ea5458ba80716bff7}{%
           family={Lovecraft},
           familyi={L\bibinitperiod},
           given={Bill\bibnamedelima {H.\,P.}},
           giveni={B\bibinitperiod\bibinitdelim H\bibinitperiod}}}%
      }
      \strng{namehash}{b51f667a3384d92ea5458ba80716bff7}
      \strng{fullhash}{b51f667a3384d92ea5458ba80716bff7}
      \strng{fullhashraw}{b51f667a3384d92ea5458ba80716bff7}
      \strng{bibnamehash}{b51f667a3384d92ea5458ba80716bff7}
      \strng{authorbibnamehash}{b51f667a3384d92ea5458ba80716bff7}
      \strng{authornamehash}{b51f667a3384d92ea5458ba80716bff7}
      \strng{authorfullhash}{b51f667a3384d92ea5458ba80716bff7}
      \strng{authorfullhashraw}{b51f667a3384d92ea5458ba80716bff7}
      \field{extraname}{2}
      \field{sortinit}{L}
      \field{sortinithash}{7c47d417cecb1f4bd38d1825c427a61a}
      \field{labelnamesource}{author}
    \endentry
|;

my $l19 = q|    \entry{L19}{book}{}{}
      \name{author}{1}{}{%
        {{hash=83caa52f21f97e572dd3267bdf62978a}{%
           family={Mustermann},
           familyi={M\bibinitperiod},
           given={Klaus-Peter},
           giveni={K\bibinithyphendelim P\bibinitperiod}}}%
      }
      \strng{namehash}{83caa52f21f97e572dd3267bdf62978a}
      \strng{fullhash}{83caa52f21f97e572dd3267bdf62978a}
      \strng{fullhashraw}{83caa52f21f97e572dd3267bdf62978a}
      \strng{bibnamehash}{83caa52f21f97e572dd3267bdf62978a}
      \strng{authorbibnamehash}{83caa52f21f97e572dd3267bdf62978a}
      \strng{authornamehash}{83caa52f21f97e572dd3267bdf62978a}
      \strng{authorfullhash}{83caa52f21f97e572dd3267bdf62978a}
      \strng{authorfullhashraw}{83caa52f21f97e572dd3267bdf62978a}
      \field{sortinit}{M}
      \field{sortinithash}{4625c616857f13d17ce56f7d4f97d451}
      \field{labelnamesource}{author}
    \endentry
|;

my $l19a = q|    \entry{L19a}{book}{}{}
      \name{author}{1}{}{%
        {{hash=0963f6904ccfeaac2770c5882a587001}{%
           family={Lam},
           familyi={L\bibinitperiod},
           given={Ho-Pun},
           giveni={H\bibinithyphendelim P\bibinitperiod}}}%
      }
      \strng{namehash}{0963f6904ccfeaac2770c5882a587001}
      \strng{fullhash}{0963f6904ccfeaac2770c5882a587001}
      \strng{fullhashraw}{0963f6904ccfeaac2770c5882a587001}
      \strng{bibnamehash}{0963f6904ccfeaac2770c5882a587001}
      \strng{authorbibnamehash}{0963f6904ccfeaac2770c5882a587001}
      \strng{authornamehash}{0963f6904ccfeaac2770c5882a587001}
      \strng{authorfullhash}{0963f6904ccfeaac2770c5882a587001}
      \strng{authorfullhashraw}{0963f6904ccfeaac2770c5882a587001}
      \field{sortinit}{L}
      \field{sortinithash}{7c47d417cecb1f4bd38d1825c427a61a}
      \field{labelnamesource}{author}
    \endentry
|;


my $l20 = q|    \entry{L20}{book}{}{}
      \name{author}{1}{}{%
        {{hash=5f26c2f3b33095d5b005714893f4d698}{%
           family={Ford},
           familyi={F\bibinitperiod},
           given={{John Henry}},
           giveni={J\bibinitperiod}}}%
      }
      \strng{namehash}{5f26c2f3b33095d5b005714893f4d698}
      \strng{fullhash}{5f26c2f3b33095d5b005714893f4d698}
      \strng{fullhashraw}{5f26c2f3b33095d5b005714893f4d698}
      \strng{bibnamehash}{5f26c2f3b33095d5b005714893f4d698}
      \strng{authorbibnamehash}{5f26c2f3b33095d5b005714893f4d698}
      \strng{authornamehash}{5f26c2f3b33095d5b005714893f4d698}
      \strng{authorfullhash}{5f26c2f3b33095d5b005714893f4d698}
      \strng{authorfullhashraw}{5f26c2f3b33095d5b005714893f4d698}
      \field{sortinit}{F}
      \field{sortinithash}{2638baaa20439f1b5a8f80c6c08a13b4}
      \field{labelnamesource}{author}
    \endentry
|;

my $l21 = q|    \entry{L21}{book}{}{}
      \name{author}{1}{}{%
        {{hash=4389a3c0dc7da74487b50808ba9436ad}{%
           family={Smith},
           familyi={S\bibinitperiod},
           given={\v{S}omeone},
           giveni={\v{S}\bibinitperiod}}}%
      }
      \strng{namehash}{4389a3c0dc7da74487b50808ba9436ad}
      \strng{fullhash}{4389a3c0dc7da74487b50808ba9436ad}
      \strng{fullhashraw}{4389a3c0dc7da74487b50808ba9436ad}
      \strng{bibnamehash}{4389a3c0dc7da74487b50808ba9436ad}
      \strng{authorbibnamehash}{4389a3c0dc7da74487b50808ba9436ad}
      \strng{authornamehash}{4389a3c0dc7da74487b50808ba9436ad}
      \strng{authorfullhash}{4389a3c0dc7da74487b50808ba9436ad}
      \strng{authorfullhashraw}{4389a3c0dc7da74487b50808ba9436ad}
      \field{extraname}{1}
      \field{sortinit}{S}
      \field{sortinithash}{b164b07b29984b41daf1e85279fbc5ab}
      \true{uniqueprimaryauthor}
      \field{labelnamesource}{author}
    \endentry
|;

my $l22u = q|    \entry{L22}{book}{}{}
      \name{author}{1}{}{%
        {{hash=e58b861545799d0eaf883402a882126e}{%
           family={Šmith},
           familyi={Š\bibinitperiod},
           given={Someone},
           giveni={S\bibinitperiod}}}%
      }
      \strng{namehash}{e58b861545799d0eaf883402a882126e}
      \strng{fullhash}{e58b861545799d0eaf883402a882126e}
      \strng{fullhashraw}{e58b861545799d0eaf883402a882126e}
      \strng{bibnamehash}{e58b861545799d0eaf883402a882126e}
      \strng{authorbibnamehash}{e58b861545799d0eaf883402a882126e}
      \strng{authornamehash}{e58b861545799d0eaf883402a882126e}
      \strng{authorfullhash}{e58b861545799d0eaf883402a882126e}
      \strng{authorfullhashraw}{e58b861545799d0eaf883402a882126e}
      \field{extraname}{1}
      \field{sortinit}{Š}
      \field{sortinithash}{b164b07b29984b41daf1e85279fbc5ab}
      \field{labelnamesource}{author}
    \endentry
|;


my $l22 = q|    \entry{L22}{book}{}{}
      \name{author}{1}{}{%
        {{hash=e58b861545799d0eaf883402a882126e}{%
           family={\v{S}mith},
           familyi={\v{S}\bibinitperiod},
           given={Someone},
           giveni={S\bibinitperiod}}}%
      }
      \strng{namehash}{e58b861545799d0eaf883402a882126e}
      \strng{fullhash}{e58b861545799d0eaf883402a882126e}
      \strng{fullhashraw}{e58b861545799d0eaf883402a882126e}
      \strng{bibnamehash}{e58b861545799d0eaf883402a882126e}
      \strng{authorbibnamehash}{e58b861545799d0eaf883402a882126e}
      \strng{authornamehash}{e58b861545799d0eaf883402a882126e}
      \strng{authorfullhash}{e58b861545799d0eaf883402a882126e}
      \strng{authorfullhashraw}{e58b861545799d0eaf883402a882126e}
      \field{extraname}{1}
      \field{sortinit}{\v{S}}
      \field{sortinithash}{b164b07b29984b41daf1e85279fbc5ab}
      \true{uniqueprimaryauthor}
      \field{labelnamesource}{author}
    \endentry
|;


my $l23 = q|    \entry{L23}{book}{}{}
      \name{author}{1}{}{%
        {{hash=4389a3c0dc7da74487b50808ba9436ad}{%
           family={Smith},
           familyi={S\bibinitperiod},
           given={Šomeone},
           giveni={Š\bibinitperiod}}}%
      }
      \strng{namehash}{4389a3c0dc7da74487b50808ba9436ad}
      \strng{fullhash}{4389a3c0dc7da74487b50808ba9436ad}
      \strng{fullhashraw}{4389a3c0dc7da74487b50808ba9436ad}
      \strng{bibnamehash}{4389a3c0dc7da74487b50808ba9436ad}
      \strng{authorbibnamehash}{4389a3c0dc7da74487b50808ba9436ad}
      \strng{authornamehash}{4389a3c0dc7da74487b50808ba9436ad}
      \strng{authorfullhash}{4389a3c0dc7da74487b50808ba9436ad}
      \strng{authorfullhashraw}{4389a3c0dc7da74487b50808ba9436ad}
      \field{extraname}{2}
      \field{sortinit}{S}
      \field{sortinithash}{b164b07b29984b41daf1e85279fbc5ab}
      \field{labelnamesource}{author}
    \endentry
|;

my $l24 = q|    \entry{L24}{book}{}{}
      \name{author}{1}{}{%
        {{hash=e58b861545799d0eaf883402a882126e}{%
           family={Šmith},
           familyi={Š\bibinitperiod},
           given={Someone},
           giveni={S\bibinitperiod}}}%
      }
      \strng{namehash}{e58b861545799d0eaf883402a882126e}
      \strng{fullhash}{e58b861545799d0eaf883402a882126e}
      \strng{fullhashraw}{e58b861545799d0eaf883402a882126e}
      \strng{bibnamehash}{e58b861545799d0eaf883402a882126e}
      \strng{authorbibnamehash}{e58b861545799d0eaf883402a882126e}
      \strng{authornamehash}{e58b861545799d0eaf883402a882126e}
      \strng{authorfullhash}{e58b861545799d0eaf883402a882126e}
      \strng{authorfullhashraw}{e58b861545799d0eaf883402a882126e}
      \field{extraname}{2}
      \field{sortinit}{Š}
      \field{sortinithash}{b164b07b29984b41daf1e85279fbc5ab}
      \field{labelnamesource}{author}
    \endentry
|;

my $l25 = q|    \entry{L25}{book}{}{}
      \name{author}{1}{}{%
        {{hash=d7cd2c5ea0848abc3e90609558b84a45}{%
           family={{American Psychological Association, Task Force on the Sexualization of Girls}},
           familyi={A\bibinitperiod}}}%
      }
      \strng{namehash}{d7cd2c5ea0848abc3e90609558b84a45}
      \strng{fullhash}{d7cd2c5ea0848abc3e90609558b84a45}
      \strng{fullhashraw}{d7cd2c5ea0848abc3e90609558b84a45}
      \strng{bibnamehash}{d7cd2c5ea0848abc3e90609558b84a45}
      \strng{authorbibnamehash}{d7cd2c5ea0848abc3e90609558b84a45}
      \strng{authornamehash}{d7cd2c5ea0848abc3e90609558b84a45}
      \strng{authorfullhash}{d7cd2c5ea0848abc3e90609558b84a45}
      \strng{authorfullhashraw}{d7cd2c5ea0848abc3e90609558b84a45}
      \field{sortinit}{A}
      \field{sortinithash}{2f401846e2029bad6b3ecc16d50031e2}
      \field{labelnamesource}{author}
    \endentry
|;

my $l26 = q|    \entry{L26}{book}{}{}
      \name{author}{1}{}{%
        {{hash=8eee1dbafdbd0a4b73157e60f18b4784}{%
           family={{Sci-Art Publishers}},
           familyi={S\bibinitperiod}}}%
      }
      \strng{namehash}{8eee1dbafdbd0a4b73157e60f18b4784}
      \strng{fullhash}{8eee1dbafdbd0a4b73157e60f18b4784}
      \strng{fullhashraw}{8eee1dbafdbd0a4b73157e60f18b4784}
      \strng{bibnamehash}{8eee1dbafdbd0a4b73157e60f18b4784}
      \strng{authorbibnamehash}{8eee1dbafdbd0a4b73157e60f18b4784}
      \strng{authornamehash}{8eee1dbafdbd0a4b73157e60f18b4784}
      \strng{authorfullhash}{8eee1dbafdbd0a4b73157e60f18b4784}
      \strng{authorfullhashraw}{8eee1dbafdbd0a4b73157e60f18b4784}
      \field{sortinit}{S}
      \field{sortinithash}{b164b07b29984b41daf1e85279fbc5ab}
      \field{labelnamesource}{author}
    \endentry
|;

my $l29 = q|    \entry{L29}{book}{}{}
      \name{author}{1}{}{%
        {{hash=27ad192a3a715aa89152b2a4ee392e8c}{%
           family={{U.S. Department of Health and Human Services, National Institute of Mental Health, National Heart, Lung and Blood Institute}},
           familyi={U\bibinitperiod}}}%
      }
      \strng{namehash}{27ad192a3a715aa89152b2a4ee392e8c}
      \strng{fullhash}{27ad192a3a715aa89152b2a4ee392e8c}
      \strng{fullhashraw}{27ad192a3a715aa89152b2a4ee392e8c}
      \strng{bibnamehash}{27ad192a3a715aa89152b2a4ee392e8c}
      \strng{authorbibnamehash}{27ad192a3a715aa89152b2a4ee392e8c}
      \strng{authornamehash}{27ad192a3a715aa89152b2a4ee392e8c}
      \strng{authorfullhash}{27ad192a3a715aa89152b2a4ee392e8c}
      \strng{authorfullhashraw}{27ad192a3a715aa89152b2a4ee392e8c}
      \field{sortinit}{U}
      \field{sortinithash}{6901a00e45705986ee5e7ca9fd39adca}
      \field{labelnamesource}{author}
    \endentry
|;

my $l31 = q|    \entry{L31}{book}{}{}
      \name{author}{1}{}{%
        {{hash=29c3ff92fff79d09a8b44d2f775de0b1}{%
           family={\~{Z}elly},
           familyi={\~{Z}\\bibinitperiod},
           given={Arthur},
           giveni={A\bibinitperiod}}}%
      }
      \name{editor}{1}{}{%
        {{hash=29c3ff92fff79d09a8b44d2f775de0b1}{%
           family={\~{Z}elly},
           familyi={\~{Z}\\bibinitperiod},
           given={Arthur},
           giveni={A\bibinitperiod}}}%
      }
      \name{translator}{1}{}{%
        {{hash=29c3ff92fff79d09a8b44d2f775de0b1}{%
           family={\~{Z}elly},
           familyi={\~{Z}\\bibinitperiod},
           given={Arthur},
           giveni={A\bibinitperiod}}}%
      }
      \strng{namehash}{29c3ff92fff79d09a8b44d2f775de0b1}
      \strng{fullhash}{29c3ff92fff79d09a8b44d2f775de0b1}
      \strng{fullhashraw}{29c3ff92fff79d09a8b44d2f775de0b1}
      \strng{bibnamehash}{29c3ff92fff79d09a8b44d2f775de0b1}
      \strng{authorbibnamehash}{29c3ff92fff79d09a8b44d2f775de0b1}
      \strng{authornamehash}{29c3ff92fff79d09a8b44d2f775de0b1}
      \strng{authorfullhash}{29c3ff92fff79d09a8b44d2f775de0b1}
      \strng{authorfullhashraw}{29c3ff92fff79d09a8b44d2f775de0b1}
      \strng{editorbibnamehash}{29c3ff92fff79d09a8b44d2f775de0b1}
      \strng{editornamehash}{29c3ff92fff79d09a8b44d2f775de0b1}
      \strng{editorfullhash}{29c3ff92fff79d09a8b44d2f775de0b1}
      \strng{editorfullhashraw}{29c3ff92fff79d09a8b44d2f775de0b1}
      \strng{translatorbibnamehash}{29c3ff92fff79d09a8b44d2f775de0b1}
      \strng{translatornamehash}{29c3ff92fff79d09a8b44d2f775de0b1}
      \strng{translatorfullhash}{29c3ff92fff79d09a8b44d2f775de0b1}
      \strng{translatorfullhashraw}{29c3ff92fff79d09a8b44d2f775de0b1}
      \field{sortinit}{\~{Z}}
      \field{sortinithash}{96892c0b0a36bb8557c40c49813d48b3}
      \true{uniqueprimaryauthor}
      \field{labelnamesource}{author}
    \endentry
|;

# Convert to NFC for testing
sub tparsename {
  my $nps = Biber::Input::file::bibtex::parsename(@_)->{nameparts};
  foreach my $np (keys $nps->%*) {
    next unless defined($nps->{$np}{string});
    $nps->{$np}{string} = NFC($nps->{$np}{string});
    my $npis;
    foreach my $npi ($nps->{$np}{initial}->@*) {
      push $npis->@*, NFC($npi);
    }
    $nps->{$np}{initial} = $npis;
  }
  return $nps;
}

sub tparsename_x {
  my $nps = Biber::Input::file::bibtex::parsename_x(@_)->{nameparts};
  foreach my $np (keys $nps->%*) {
    next unless defined($nps->{$np}{string});
    $nps->{$np}{string} = NFC($nps->{$np}{string}) || undef;
    my $npis;
    foreach my $npi ($nps->{$np}{initial}->@*) {
      push $npis->@*, NFC($npi);
    }
    $nps->{$np}{initial} = $npis;
  }
  return $nps;
}

# name parsing tests
is_deeply(tparsename($section,'John Doe', 'author'), $name1, 'parsename 1');
is_deeply(tparsename($section,'Doe, Jr, John', 'author'), $name2, 'parsename 2');
is_deeply(tparsename($section,'von Berlichingen zu Hornberg, Johann Gottfried', 'author'), $name3, 'parsename 3') ;
is_deeply(tparsename($section,'von Berlichingen zu Hornberg, Johann Gottfried', 'author'), $name4, 'parsename 4') ;
is_deeply(tparsename($section,'{Robert and Sons, Inc.}', 'author'), $name5, 'parsename 5') ;
is_deeply(tparsename($section,'al-Ṣāliḥ, ʿAbdallāh', 'author'), $name6, 'parsename 6') ;
is_deeply(tparsename($section,'al- Hakim, Tawfik', 'author'), $namepre1, 'parsename 6a') ;
is_deeply(tparsename($section,'Jean Charles Gabriel de la Vallée Poussin', 'author'), $name7, 'parsename 7');
is_deeply(tparsename($section,'{Jean Charles Gabriel} de la Vallée Poussin', 'author'), $name8, 'parsename 8');
is_deeply(tparsename($section,'Jean Charles Gabriel {de la} Vallée Poussin', 'author'), $name9, 'parsename 9');
is_deeply(tparsename($section,'Jean Charles Gabriel de la {Vallée Poussin}', 'author'), $name10, 'parsename 10');
is_deeply(tparsename($section,'{Jean Charles Gabriel} de la {Vallée Poussin}', 'author'), $name11, 'parsename 11');
is_deeply(tparsename($section,'Jean Charles Gabriel Poussin', 'author'), $name12, 'parsename 12');
is_deeply(tparsename($section,'Jean Charles {Poussin Lecoq}', 'author'), $name13, 'parsename 13');
is_deeply(tparsename($section,'J. C. G. de la Vallée Poussin', 'author'), $name14, 'parsename 14');
is_deeply(tparsename($section,'E. S. El-{M}allah', 'author'), $name15, 'parsename 15');
is_deeply(tparsename($section,'E. S. {K}ent-{B}oswell', 'author'), $name16, 'parsename 16');
is_deeply(tparsename($section,'Other, A.~N.', 'author'), $name17, 'parsename 17');
is_deeply(tparsename($section,'{{{British National Corpus}}}', 'author'), $name18, 'parsename 18');
is_deeply(Biber::Input::file::bibtex::parsename($section,'{{{British National Corpus}}}', 'author')->{strip}, $name18strip, 'parsename 18a');
is_deeply(tparsename($section,'Vázques{ de }Parga, Luis', 'author'), $name19, 'parsename 19');
is_deeply(tparsename_x($section,'family=Smithers Jones, prefix=van der, given=James, useprefix=true', 'author'), $namex1, 'parsename_x 1');
eq_or_diff(Biber::Input::file::bibtex::parsename_x($section,'family=Smithers Jones, prefix=van der, given=James, useprefix=true', 'author')->{useprefix}, '1', 'parsename_x 2');

# name to bib tests
eq_or_diff(Biber::Input::file::bibtex::parsename($section,'John Doe', 'author')->name_to_bibtex, 'Doe, John', 'name_to_bibtex 1');
eq_or_diff(Biber::Input::file::bibtex::parsename($section,'John van der Doe', 'author')->name_to_bibtex, 'van der Doe, John', 'name_to_bibtex 2');
eq_or_diff(Biber::Input::file::bibtex::parsename($section,'Doe, Jr, John', 'author')->name_to_bibtex, 'Doe, Jr, John', 'name_to_bibtex 3');
eq_or_diff(Biber::Input::file::bibtex::parsename($section,'von Doe, Jr, John', 'author')->name_to_bibtex, 'von Doe, Jr, John', 'name_to_bibtex 4');
eq_or_diff(Biber::Input::file::bibtex::parsename($section,'John Alan Doe', 'author')->name_to_bibtex, 'Doe, John Alan', 'name_to_bibtex 5');
eq_or_diff(Biber::Input::file::bibtex::parsename($section,'{Robert and Sons, Inc.}', 'author')->name_to_bibtex, '{Robert and Sons, Inc.}', 'name_to_bibtex 6');
eq_or_diff(NFC(Biber::Input::file::bibtex::parsename($section,'Jean Charles Gabriel de la {Vallée Poussin}', 'author')->name_to_bibtex), 'de la {Vallée Poussin}, Jean Charles Gabriel', 'name_to_bibtex 7');
eq_or_diff(Biber::Input::file::bibtex::parsename($section,'E. S. {K}ent-{B}oswell', 'author')->name_to_bibtex, '{K}ent-{B}oswell, E. S.', 'name_to_bibtex 8');
is_deeply(Biber::Input::file::bibtex::parsename_x($section,'family=Smithers Jones, prefix=van der, given=James, useprefix=true', 'author')->name_to_bibtex, 'van der Smithers Jones, James', 'name_to_bibtex - 9');

# name to xname tests
is_deeply(Biber::Input::file::bibtex::parsename($section,'van der Smithers Jones, James', 'author')->name_to_xname, 'family=Smithers Jones, given=James, prefix=van der', 'name_to_xname - 1');
is_deeply(Biber::Input::file::bibtex::parsename_x($section,'family=Smithers Jones, prefix=van der, given=James, useprefix=true', 'author')->name_to_xname, 'family=Smithers Jones, given=James, prefix=van der, useprefix=true', 'name_to_xname - 2');

# Full entry tests
eq_or_diff( $out->get_output_entry('L1', $main), $l1, 'First Last') ;
eq_or_diff( $out->get_output_entry('L1', $nhtest), $l1h, 'Name hashing - given initials'); # testing custom name hash templates
eq_or_diff( $out->get_output_entry('L1id', $main), $l1id, 'Name hashing - custom hashid'); # testing custom hashid
eq_or_diff( $out->get_output_entry('L2', $main), $l2, 'First Initial. Last') ;
eq_or_diff( $out->get_output_entry('L3', $main), $l3, 'Initial. Initial. Last') ;
eq_or_diff( $out->get_output_entry('L4', $main), $l4, 'First Initial Last') ;
eq_or_diff( $out->get_output_entry('L5', $main), $l5, 'First prefix Last') ;
eq_or_diff( $out->get_output_entry('L6', $main), $l6, 'First prefix prefix Last') ;
eq_or_diff( $out->get_output_entry('L7', $main), $l7, 'First Initial. prefix Last') ;
eq_or_diff( $out->get_output_entry('L8', $main), $l8, 'First Initial prefix Last') ;
eq_or_diff( $out->get_output_entry('L9', $main), $l9, 'First {Last Last}') ;
eq_or_diff( $out->get_output_entry('L10', $main), $l10, 'Last, Suffix, First') ;
eq_or_diff( $out->get_output_entry('L10a', $main), $l10a, 'Last, Suffix, First Initial.') ;
eq_or_diff( $out->get_output_entry('L11', $main), $l11, 'prefix Last, Suffix, First') ;
eq_or_diff( $out->get_output_entry('L13', $main), $l13, 'Last Last Last, Initial. Initial.');
eq_or_diff( $out->get_output_entry('L14', $main), $l14, 'Last Last-Last, First');
eq_or_diff( $out->get_output_entry('L15', $main), $l15, 'First F.{\bibinitdelim }F. Last');
eq_or_diff( $out->get_output_entry('L16', $main), $l16, 'First {F.\bibinitdelim F.} Last');
eq_or_diff( $out->get_output_entry('L17', $main), $l17, 'Last, First {F.\bibinitdelim F.}');
eq_or_diff( $out->get_output_entry('L18', $main), $l18, 'Last, First F.{\bibinitdelim }F.');
eq_or_diff( $out->get_output_entry('L19', $main), $l19, 'Firstname with hyphen');
eq_or_diff( $out->get_output_entry('L19a', $main), $l19a, 'Short given name with hyphen');
eq_or_diff( $out->get_output_entry('L20', $main), $l20, 'Protected dual given name');
eq_or_diff( encode_utf8(NFC($out->get_output_entry('L22', $main))), encode_utf8($l22u), 'LaTeX encoded unicode family - 1');
eq_or_diff( NFC($out->get_output_entry('L23', $main)), $l23, 'Unicode given name');
eq_or_diff( NFC($out->get_output_entry('L24', $main)), $l24, 'Unicode family name');
eq_or_diff( $out->get_output_entry('L25', $main), $l25, 'Single string name');
eq_or_diff( $out->get_output_entry('L26', $main), $l26, 'Hyphen at brace level <> 0');
eq_or_diff( $out->get_output_entry('L29', $main), $l29, 'Escaped name with 3 commas');

# Checking visibility
# Count does not include the "and others" as this "name" is deleted in the output driver
eq_or_diff($bibentries->entry('V1')->get_field($bibentries->entry('V1')->get_labelname_info)->count, '2', 'Name count for "and others" - 1');
eq_or_diff($main->get_visible_cite($bibentries->entry('V1')->get_field($bibentries->entry('V1')->get_labelname_info)->get_id), '2', 'Visibility for "and others" - 1');
eq_or_diff($main->get_visible_cite($bibentries->entry('V2')->get_field($bibentries->entry('V2')->get_labelname_info)->get_id), '1', 'Visibility for "and others" - 2');
# A few tests depend on non UTF-8 output
# Have to use a new biber object when trying to change encoding as this isn't
# dealt with in ->prepare
$biber->parse_ctrlfile('names.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Biber options
Biber::Config->setoption('output_encoding', 'latin1');
# If you change the encoding options, you have to re-read the T::B data from the datasource
# This won't happen unless you invalidate the T::B cache.
Biber::Config->setblxoption(undef,'uniqueprimaryauthor', 1);
Biber::Config->setoption('namesep', 'and'); # revert custom name sep
Biber::Input::file::bibtex->init_cache;

# Now generate the information
$biber->prepare;
$out = $biber->get_output_obj;
$section = $biber->sections->get_section(0);
$main = $biber->datalists->get_list('custom/global//global/global/global');
$bibentries = $section->bibentries;

eq_or_diff(NFC($bibentries->entry('L21')->get_field($bibentries->entry('L21')->get_labelname_info)->nth_name(1)->get_namepart_initial('given')->[0]), 'Š', 'Terseinitials 1'); # Should be in NFD UTF-8
eq_or_diff( encode_utf8($out->get_output_entry('L12', $main)), encode_utf8($l12), 'First First First First prefix prefix Last Last') ;
eq_or_diff( $out->get_output_entry('L21', $main), $l21, 'LaTeX encoded unicode given name');
eq_or_diff( $out->get_output_entry('L22', $main), $l22, 'LaTeX encoded unicode family name - 2');
eq_or_diff( $out->get_output_entry('L31', $main), $l31, 'LaTeX encoded unicode family name with tie char');

# uniqueprimaryauthor tests
eq_or_diff($main->get_entryfield('upa1', 'uniqueprimaryauthor'), 1, 'Unique primary author - 1');
ok(is_undef($main->get_entryfield('upa2', 'uniqueprimaryauthor')), 'Unique primary author - 2');
ok(is_undef($main->get_entryfield('upa3', 'uniqueprimaryauthor')), 'Unique primary author - 3');
eq_or_diff($main->get_entryfield('upa4', 'uniqueprimaryauthor'), 1, 'Unique primary author - 4');
