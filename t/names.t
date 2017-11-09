# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 74;
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
Biber::Config->setblxoption('mincitenames', 3);

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $main = $biber->datalists->get_list('custom/global//global/global');
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

my $l1 = q|    \entry{L1}{book}{}
      \name{author}{1}{}{%
        {{hash=72287a68c1714cb1b9f4ab9e03a88b96}{%
           family={Adler},
           familyi={A\bibinitperiod},
           given={Alfred},
           giveni={A\bibinitperiod}}}%
      }
      \strng{namehash}{72287a68c1714cb1b9f4ab9e03a88b96}
      \strng{fullhash}{72287a68c1714cb1b9f4ab9e03a88b96}
      \strng{bibnamehash}{72287a68c1714cb1b9f4ab9e03a88b96}
      \strng{authorbibnamehash}{72287a68c1714cb1b9f4ab9e03a88b96}
      \strng{authornamehash}{72287a68c1714cb1b9f4ab9e03a88b96}
      \strng{authorfullhash}{72287a68c1714cb1b9f4ab9e03a88b96}
      \field{sortinit}{A}
      \field{sortinithash}{d77c7cdd82ff690d4c3ef13216f92f0b}
      \field{labelnamesource}{author}
    \endentry
|;

my $l2 = q|    \entry{L2}{book}{}
      \name{author}{1}{}{%
        {{hash=1c867a2b5ceb243bab70afb18702dc04}{%
           family={Bull},
           familyi={B\bibinitperiod},
           given={Bertie\bibnamedelima B.},
           giveni={B\bibinitperiod\bibinitdelim B\bibinitperiod}}}%
      }
      \strng{namehash}{1c867a2b5ceb243bab70afb18702dc04}
      \strng{fullhash}{1c867a2b5ceb243bab70afb18702dc04}
      \strng{bibnamehash}{1c867a2b5ceb243bab70afb18702dc04}
      \strng{authorbibnamehash}{1c867a2b5ceb243bab70afb18702dc04}
      \strng{authornamehash}{1c867a2b5ceb243bab70afb18702dc04}
      \strng{authorfullhash}{1c867a2b5ceb243bab70afb18702dc04}
      \field{sortinit}{B}
      \field{sortinithash}{276475738cc058478c1677046f857703}
      \field{labelnamesource}{author}
    \endentry
|;

my $l3 = q|    \entry{L3}{book}{}
      \name{author}{1}{}{%
        {{hash=cecd18116c43ee86e5a136b6e0362948}{%
           family={Crop},
           familyi={C\bibinitperiod},
           given={C.\bibnamedelimi Z.},
           giveni={C\bibinitperiod\bibinitdelim Z\bibinitperiod}}}%
      }
      \strng{namehash}{cecd18116c43ee86e5a136b6e0362948}
      \strng{fullhash}{cecd18116c43ee86e5a136b6e0362948}
      \strng{bibnamehash}{cecd18116c43ee86e5a136b6e0362948}
      \strng{authorbibnamehash}{cecd18116c43ee86e5a136b6e0362948}
      \strng{authornamehash}{cecd18116c43ee86e5a136b6e0362948}
      \strng{authorfullhash}{cecd18116c43ee86e5a136b6e0362948}
      \field{sortinit}{C}
      \field{sortinithash}{963e9d84a3da2344e8833203de5aed05}
      \field{labelnamesource}{author}
    \endentry
|;

my $l4 = q|    \entry{L4}{book}{}
      \name{author}{1}{}{%
        {{hash=675883f3aca7c6069c0b154d47af4c86}{%
           family={Decket},
           familyi={D\bibinitperiod},
           given={Derek\bibnamedelima D},
           giveni={D\bibinitperiod\bibinitdelim D\bibinitperiod}}}%
      }
      \strng{namehash}{675883f3aca7c6069c0b154d47af4c86}
      \strng{fullhash}{675883f3aca7c6069c0b154d47af4c86}
      \strng{bibnamehash}{675883f3aca7c6069c0b154d47af4c86}
      \strng{authorbibnamehash}{675883f3aca7c6069c0b154d47af4c86}
      \strng{authornamehash}{675883f3aca7c6069c0b154d47af4c86}
      \strng{authorfullhash}{675883f3aca7c6069c0b154d47af4c86}
      \field{sortinit}{D}
      \field{sortinithash}{2ef1bd9a78cc71eb74d7231c635177b8}
      \field{labelnamesource}{author}
    \endentry
|;

my $l5 = q|    \entry{L5}{book}{}
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
      \strng{bibnamehash}{c6b9d281cc1ff3f35570f76f463d4244}
      \strng{authorbibnamehash}{c6b9d281cc1ff3f35570f76f463d4244}
      \strng{authornamehash}{c6b9d281cc1ff3f35570f76f463d4244}
      \strng{authorfullhash}{c6b9d281cc1ff3f35570f76f463d4244}
      \field{sortinit}{v}
      \field{sortinithash}{75dd7385c90b2252c3ae853a80ca853b}
      \field{labelnamesource}{author}
    \endentry
|;

my $l6 = q|    \entry{L6}{book}{}
      \name{author}{1}{}{%
        {{hash=dd96e3fc645eb4685988366f233403df}{%
           family={Frome},
           familyi={F\\bibinitperiod},
           given={Francis},
           giveni={F\\bibinitperiod},
           prefix={van\\bibnamedelimb der\\bibnamedelima valt},
           prefixi={v\\bibinitperiod\\bibinitdelim d\\bibinitperiod\\bibinitdelim v\\bibinitperiod}}}%
      }
      \strng{namehash}{dd96e3fc645eb4685988366f233403df}
      \strng{fullhash}{dd96e3fc645eb4685988366f233403df}
      \strng{bibnamehash}{dd96e3fc645eb4685988366f233403df}
      \strng{authorbibnamehash}{dd96e3fc645eb4685988366f233403df}
      \strng{authornamehash}{dd96e3fc645eb4685988366f233403df}
      \strng{authorfullhash}{dd96e3fc645eb4685988366f233403df}
      \field{sortinit}{v}
      \field{sortinithash}{75dd7385c90b2252c3ae853a80ca853b}
      \field{labelnamesource}{author}
    \endentry
|;

my $l7 = q|    \entry{L7}{book}{}
      \name{author}{1}{}{%
        {{hash=1e802cc32f10930a9567712b8febdf19}{%
           family={Gloom},
           familyi={G\\bibinitperiod},
           given={Gregory\\bibnamedelima R.},
           giveni={G\\bibinitperiod\\bibinitdelim R\\bibinitperiod},
           prefix={van},
           prefixi={v\\bibinitperiod}}}%
      }
      \strng{namehash}{1e802cc32f10930a9567712b8febdf19}
      \strng{fullhash}{1e802cc32f10930a9567712b8febdf19}
      \strng{bibnamehash}{1e802cc32f10930a9567712b8febdf19}
      \strng{authorbibnamehash}{1e802cc32f10930a9567712b8febdf19}
      \strng{authornamehash}{1e802cc32f10930a9567712b8febdf19}
      \strng{authorfullhash}{1e802cc32f10930a9567712b8febdf19}
      \field{sortinit}{v}
      \field{sortinithash}{75dd7385c90b2252c3ae853a80ca853b}
      \field{labelnamesource}{author}
    \endentry
|;

my $l8 = q|    \entry{L8}{book}{}
      \name{author}{1}{}{%
        {{hash=076a9b62b331eb2cdfba234d9ad7bca9}{%
           family={Henkel},
           familyi={H\\bibinitperiod},
           given={Henry\\bibnamedelima F.},
           giveni={H\\bibinitperiod\\bibinitdelim F\\bibinitperiod},
           prefix={van},
           prefixi={v\\bibinitperiod}}}%
      }
      \strng{namehash}{076a9b62b331eb2cdfba234d9ad7bca9}
      \strng{fullhash}{076a9b62b331eb2cdfba234d9ad7bca9}
      \strng{bibnamehash}{076a9b62b331eb2cdfba234d9ad7bca9}
      \strng{authorbibnamehash}{076a9b62b331eb2cdfba234d9ad7bca9}
      \strng{authornamehash}{076a9b62b331eb2cdfba234d9ad7bca9}
      \strng{authorfullhash}{076a9b62b331eb2cdfba234d9ad7bca9}
      \field{sortinit}{v}
      \field{sortinithash}{75dd7385c90b2252c3ae853a80ca853b}
      \field{labelnamesource}{author}
    \endentry
|;

my $l9 = q|    \entry{L9}{book}{}
      \name{author}{1}{}{%
        {{hash=1734924c4c55de5bb18d020c34a5249e}{%
           family={{Iliad Ipswich}},
           familyi={I\bibinitperiod},
           given={Ian},
           giveni={I\bibinitperiod}}}%
      }
      \strng{namehash}{1734924c4c55de5bb18d020c34a5249e}
      \strng{fullhash}{1734924c4c55de5bb18d020c34a5249e}
      \strng{bibnamehash}{1734924c4c55de5bb18d020c34a5249e}
      \strng{authorbibnamehash}{1734924c4c55de5bb18d020c34a5249e}
      \strng{authornamehash}{1734924c4c55de5bb18d020c34a5249e}
      \strng{authorfullhash}{1734924c4c55de5bb18d020c34a5249e}
      \field{sortinit}{I}
      \field{sortinithash}{320bc8fe8101b9376f9f21cd507de0e8}
      \field{labelnamesource}{author}
    \endentry
|;


my $l10 = q|    \entry{L10}{book}{}
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
      \strng{bibnamehash}{37b4325752e394ddfb2fc810f6c88e27}
      \strng{authorbibnamehash}{37b4325752e394ddfb2fc810f6c88e27}
      \strng{authornamehash}{37b4325752e394ddfb2fc810f6c88e27}
      \strng{authorfullhash}{37b4325752e394ddfb2fc810f6c88e27}
      \field{sortinit}{J}
      \field{sortinithash}{fce5f8d0bd05e8d93f3dbe21c78897ca}
      \field{labelnamesource}{author}
    \endentry
|;


my $l10a = q|    \entry{L10a}{book}{}
      \name{author}{1}{}{%
        {{hash=264cb53d2295644c1c99523e254d9b0e}{%
           family={Pimentel},
           familyi={P\\bibinitperiod},
           given={Joseph\\bibnamedelima J.},
           giveni={J\\bibinitperiod\\bibinitdelim J\\bibinitperiod},
           suffix={Jr.},
           suffixi={J\\bibinitperiod}}}%
      }
      \strng{namehash}{264cb53d2295644c1c99523e254d9b0e}
      \strng{fullhash}{264cb53d2295644c1c99523e254d9b0e}
      \strng{bibnamehash}{264cb53d2295644c1c99523e254d9b0e}
      \strng{authorbibnamehash}{264cb53d2295644c1c99523e254d9b0e}
      \strng{authornamehash}{264cb53d2295644c1c99523e254d9b0e}
      \strng{authorfullhash}{264cb53d2295644c1c99523e254d9b0e}
      \field{sortinit}{P}
      \field{sortinithash}{8d51b3d5b78d75b54308d706b9bbe285}
      \field{labelnamesource}{author}
    \endentry
|;


my $l11 = q|    \entry{L11}{book}{}
      \name{author}{1}{}{%
        {{hash=c536dd808dc9193fda59ba1ff2afb38f}{%
           family={Kluster},
           familyi={K\\bibinitperiod},
           given={Kevin},
           giveni={K\\bibinitperiod},
           prefix={van},
           prefixi={v\\bibinitperiod},
           suffix={Jr.},
           suffixi={J\\bibinitperiod}}}%
      }
      \strng{namehash}{c536dd808dc9193fda59ba1ff2afb38f}
      \strng{fullhash}{c536dd808dc9193fda59ba1ff2afb38f}
      \strng{bibnamehash}{c536dd808dc9193fda59ba1ff2afb38f}
      \strng{authorbibnamehash}{c536dd808dc9193fda59ba1ff2afb38f}
      \strng{authornamehash}{c536dd808dc9193fda59ba1ff2afb38f}
      \strng{authorfullhash}{c536dd808dc9193fda59ba1ff2afb38f}
      \field{sortinit}{v}
      \field{sortinithash}{75dd7385c90b2252c3ae853a80ca853b}
      \field{labelnamesource}{author}
    \endentry
|;

my $l12 = q|    \entry{L12}{book}{}
      \name{author}{1}{}{%
        {{hash=6c883a8c1975ffff06f875bf366b3e47}{%
           family={Vall{é}e\\bibnamedelima Poussin},
           familyi={V\\bibinitperiod\\bibinitdelim P\\bibinitperiod},
           given={Charles\\bibnamedelimb Louis\\bibnamedelimb Xavier\\bibnamedelima Joseph},
           giveni={C\\bibinitperiod\\bibinitdelim L\\bibinitperiod\\bibinitdelim X\\bibinitperiod\\bibinitdelim J\\bibinitperiod},
           prefix={de\\bibnamedelima la},
           prefixi={d\\bibinitperiod\\bibinitdelim l\\bibinitperiod}}}%
      }
      \strng{namehash}{6c883a8c1975ffff06f875bf366b3e47}
      \strng{fullhash}{6c883a8c1975ffff06f875bf366b3e47}
      \strng{bibnamehash}{6c883a8c1975ffff06f875bf366b3e47}
      \strng{authorbibnamehash}{6c883a8c1975ffff06f875bf366b3e47}
      \strng{authornamehash}{6c883a8c1975ffff06f875bf366b3e47}
      \strng{authorfullhash}{6c883a8c1975ffff06f875bf366b3e47}
      \field{sortinit}{d}
      \field{sortinithash}{2ef1bd9a78cc71eb74d7231c635177b8}
      \true{uniqueprimaryauthor}
      \field{labelnamesource}{author}
    \endentry
|;

my $l13 = q|    \entry{L13}{book}{}
      \name{author}{1}{}{%
        {{hash=5e79da6869afaf0d38e01285b494d555}{%
           family={Van\bibnamedelimb de\bibnamedelima Graaff},
           familyi={V\bibinitperiod\bibinitdelim d\bibinitperiod\bibinitdelim G\bibinitperiod},
           given={R.\bibnamedelimi J.},
           giveni={R\bibinitperiod\bibinitdelim J\bibinitperiod}}}%
      }
      \strng{namehash}{5e79da6869afaf0d38e01285b494d555}
      \strng{fullhash}{5e79da6869afaf0d38e01285b494d555}
      \strng{bibnamehash}{5e79da6869afaf0d38e01285b494d555}
      \strng{authorbibnamehash}{5e79da6869afaf0d38e01285b494d555}
      \strng{authornamehash}{5e79da6869afaf0d38e01285b494d555}
      \strng{authorfullhash}{5e79da6869afaf0d38e01285b494d555}
      \field{sortinit}{V}
      \field{sortinithash}{75dd7385c90b2252c3ae853a80ca853b}
      \field{labelnamesource}{author}
    \endentry
|;

my $l14 = q|    \entry{L14}{book}{}
      \name{author}{1}{}{%
        {{hash=2319907d9a5d5dd46da77879bdb7e609}{%
           family={St\bibnamedelima John-Mollusc},
           familyi={S\bibinitperiod\bibinitdelim J\bibinithyphendelim M\bibinitperiod},
           given={Oliver},
           giveni={O\bibinitperiod}}}%
      }
      \strng{namehash}{2319907d9a5d5dd46da77879bdb7e609}
      \strng{fullhash}{2319907d9a5d5dd46da77879bdb7e609}
      \strng{bibnamehash}{2319907d9a5d5dd46da77879bdb7e609}
      \strng{authorbibnamehash}{2319907d9a5d5dd46da77879bdb7e609}
      \strng{authornamehash}{2319907d9a5d5dd46da77879bdb7e609}
      \strng{authorfullhash}{2319907d9a5d5dd46da77879bdb7e609}
      \field{sortinit}{S}
      \field{sortinithash}{322b1d5276f2f6c1bccdcd15920dbee6}
      \field{labelnamesource}{author}
    \endentry
|;

my $l15 = q|    \entry{L15}{book}{}
      \name{author}{1}{}{%
        {{hash=b30b0fc69681fd11ad5d75a880124091}{%
           family={Gompel},
           familyi={G\\bibinitperiod},
           given={Roger\\bibnamedelima P.{\\,}G.},
           giveni={R\\bibinitperiod\\bibinitdelim P\\bibinitperiod},
           prefix={van},
           prefixi={v\\bibinitperiod}}}%
      }
      \strng{namehash}{b30b0fc69681fd11ad5d75a880124091}
      \strng{fullhash}{b30b0fc69681fd11ad5d75a880124091}
      \strng{bibnamehash}{b30b0fc69681fd11ad5d75a880124091}
      \strng{authorbibnamehash}{b30b0fc69681fd11ad5d75a880124091}
      \strng{authornamehash}{b30b0fc69681fd11ad5d75a880124091}
      \strng{authorfullhash}{b30b0fc69681fd11ad5d75a880124091}
      \field{sortinit}{v}
      \field{sortinithash}{75dd7385c90b2252c3ae853a80ca853b}
      \field{labelnamesource}{author}
    \endentry
|;

my $l16 = q|    \entry{L16}{book}{}
      \name{author}{1}{}{%
        {{hash=2b17c50dc666b9cc73d132da9ef08c7b}{%
           family={Gompel},
           familyi={G\\bibinitperiod},
           given={Roger\\bibnamedelima {P.\\,G.}},
           giveni={R\\bibinitperiod\\bibinitdelim P\\bibinitperiod},
           prefix={van},
           prefixi={v\\bibinitperiod}}}%
      }
      \strng{namehash}{2b17c50dc666b9cc73d132da9ef08c7b}
      \strng{fullhash}{2b17c50dc666b9cc73d132da9ef08c7b}
      \strng{bibnamehash}{2b17c50dc666b9cc73d132da9ef08c7b}
      \strng{authorbibnamehash}{2b17c50dc666b9cc73d132da9ef08c7b}
      \strng{authornamehash}{2b17c50dc666b9cc73d132da9ef08c7b}
      \strng{authorfullhash}{2b17c50dc666b9cc73d132da9ef08c7b}
      \field{sortinit}{v}
      \field{sortinithash}{75dd7385c90b2252c3ae853a80ca853b}
      \field{labelnamesource}{author}
    \endentry
|;

my $l17 = q|    \entry{L17}{book}{}
      \name{author}{1}{}{%
        {{hash=766d5329cf995fcc7c1cef19de2a2ae8}{%
           family={Lovecraft},
           familyi={L\bibinitperiod},
           given={Bill\bibnamedelima H.{\,}P.},
           giveni={B\bibinitperiod\bibinitdelim H\bibinitperiod}}}%
      }
      \strng{namehash}{766d5329cf995fcc7c1cef19de2a2ae8}
      \strng{fullhash}{766d5329cf995fcc7c1cef19de2a2ae8}
      \strng{bibnamehash}{766d5329cf995fcc7c1cef19de2a2ae8}
      \strng{authorbibnamehash}{766d5329cf995fcc7c1cef19de2a2ae8}
      \strng{authornamehash}{766d5329cf995fcc7c1cef19de2a2ae8}
      \strng{authorfullhash}{766d5329cf995fcc7c1cef19de2a2ae8}
      \field{sortinit}{L}
      \field{sortinithash}{2c7981aaabc885868aba60f0c09ee20f}
      \field{labelnamesource}{author}
    \endentry
|;

my $l18 = q|    \entry{L18}{book}{}
      \name{author}{1}{}{%
        {{hash=58620d2c7d6839bac23306c732c563fb}{%
           family={Lovecraft},
           familyi={L\bibinitperiod},
           given={Bill\bibnamedelima {H.\,P.}},
           giveni={B\bibinitperiod\bibinitdelim H\bibinitperiod}}}%
      }
      \strng{namehash}{58620d2c7d6839bac23306c732c563fb}
      \strng{fullhash}{58620d2c7d6839bac23306c732c563fb}
      \strng{bibnamehash}{58620d2c7d6839bac23306c732c563fb}
      \strng{authorbibnamehash}{58620d2c7d6839bac23306c732c563fb}
      \strng{authornamehash}{58620d2c7d6839bac23306c732c563fb}
      \strng{authorfullhash}{58620d2c7d6839bac23306c732c563fb}
      \field{sortinit}{L}
      \field{sortinithash}{2c7981aaabc885868aba60f0c09ee20f}
      \field{labelnamesource}{author}
    \endentry
|;

my $l19 = q|    \entry{L19}{book}{}
      \name{author}{1}{}{%
        {{hash=83caa52f21f97e572dd3267bdf62978a}{%
           family={Mustermann},
           familyi={M\bibinitperiod},
           given={Klaus-Peter},
           giveni={K\bibinithyphendelim P\bibinitperiod}}}%
      }
      \strng{namehash}{83caa52f21f97e572dd3267bdf62978a}
      \strng{fullhash}{83caa52f21f97e572dd3267bdf62978a}
      \strng{bibnamehash}{83caa52f21f97e572dd3267bdf62978a}
      \strng{authorbibnamehash}{83caa52f21f97e572dd3267bdf62978a}
      \strng{authornamehash}{83caa52f21f97e572dd3267bdf62978a}
      \strng{authorfullhash}{83caa52f21f97e572dd3267bdf62978a}
      \field{sortinit}{M}
      \field{sortinithash}{cfd219b90152c06204fab207bc6c7cab}
      \field{labelnamesource}{author}
    \endentry
|;

my $l19a = q|    \entry{L19a}{book}{}
      \name{author}{1}{}{%
        {{hash=0963f6904ccfeaac2770c5882a587001}{%
           family={Lam},
           familyi={L\bibinitperiod},
           given={Ho-Pun},
           giveni={H\bibinithyphendelim P\bibinitperiod}}}%
      }
      \strng{namehash}{0963f6904ccfeaac2770c5882a587001}
      \strng{fullhash}{0963f6904ccfeaac2770c5882a587001}
      \strng{bibnamehash}{0963f6904ccfeaac2770c5882a587001}
      \strng{authorbibnamehash}{0963f6904ccfeaac2770c5882a587001}
      \strng{authornamehash}{0963f6904ccfeaac2770c5882a587001}
      \strng{authorfullhash}{0963f6904ccfeaac2770c5882a587001}
      \field{sortinit}{L}
      \field{sortinithash}{2c7981aaabc885868aba60f0c09ee20f}
      \field{labelnamesource}{author}
    \endentry
|;


my $l20 = q|    \entry{L20}{book}{}
      \name{author}{1}{}{%
        {{hash=fdaa0936724be89ef8bd16cf02e08c74}{%
           family={Ford},
           familyi={F\bibinitperiod},
           given={{John Henry}},
           giveni={J\bibinitperiod}}}%
      }
      \strng{namehash}{fdaa0936724be89ef8bd16cf02e08c74}
      \strng{fullhash}{fdaa0936724be89ef8bd16cf02e08c74}
      \strng{bibnamehash}{fdaa0936724be89ef8bd16cf02e08c74}
      \strng{authorbibnamehash}{fdaa0936724be89ef8bd16cf02e08c74}
      \strng{authornamehash}{fdaa0936724be89ef8bd16cf02e08c74}
      \strng{authorfullhash}{fdaa0936724be89ef8bd16cf02e08c74}
      \field{sortinit}{F}
      \field{sortinithash}{669c706c6f1fbf3b5a83d26f1d9e9e72}
      \field{labelnamesource}{author}
    \endentry
|;

my $l21 = q|    \entry{L21}{book}{}
      \name{author}{1}{}{%
        {{hash=b3df6330af0651b93bce079a36dea339}{%
           family={Smith},
           familyi={S\bibinitperiod},
           given={{\v{S}}omeone},
           giveni={\v{S}\bibinitperiod}}}%
      }
      \strng{namehash}{b3df6330af0651b93bce079a36dea339}
      \strng{fullhash}{b3df6330af0651b93bce079a36dea339}
      \strng{bibnamehash}{b3df6330af0651b93bce079a36dea339}
      \strng{authorbibnamehash}{b3df6330af0651b93bce079a36dea339}
      \strng{authornamehash}{b3df6330af0651b93bce079a36dea339}
      \strng{authorfullhash}{b3df6330af0651b93bce079a36dea339}
      \field{sortinit}{S}
      \field{sortinithash}{322b1d5276f2f6c1bccdcd15920dbee6}
      \field{labelnamesource}{author}
    \endentry
|;

my $l22u = q|    \entry{L22}{book}{}
      \name{author}{1}{}{%
        {{hash=2273e0084ca97649d7edced9ce8d0ea3}{%
           family={{Š}mith},
           familyi={Š\bibinitperiod},
           given={Someone},
           giveni={S\bibinitperiod}}}%
      }
      \strng{namehash}{2273e0084ca97649d7edced9ce8d0ea3}
      \strng{fullhash}{2273e0084ca97649d7edced9ce8d0ea3}
      \strng{bibnamehash}{2273e0084ca97649d7edced9ce8d0ea3}
      \strng{authorbibnamehash}{2273e0084ca97649d7edced9ce8d0ea3}
      \strng{authornamehash}{2273e0084ca97649d7edced9ce8d0ea3}
      \strng{authorfullhash}{2273e0084ca97649d7edced9ce8d0ea3}
      \field{sortinit}{Š}
      \field{sortinithash}{322b1d5276f2f6c1bccdcd15920dbee6}
      \field{labelnamesource}{author}
    \endentry
|;


my $l22 = q|    \entry{L22}{book}{}
      \name{author}{1}{}{%
        {{hash=2273e0084ca97649d7edced9ce8d0ea3}{%
           family={{\v{S}}mith},
           familyi={\v{S}\bibinitperiod},
           given={Someone},
           giveni={S\bibinitperiod}}}%
      }
      \strng{namehash}{2273e0084ca97649d7edced9ce8d0ea3}
      \strng{fullhash}{2273e0084ca97649d7edced9ce8d0ea3}
      \strng{bibnamehash}{2273e0084ca97649d7edced9ce8d0ea3}
      \strng{authorbibnamehash}{2273e0084ca97649d7edced9ce8d0ea3}
      \strng{authornamehash}{2273e0084ca97649d7edced9ce8d0ea3}
      \strng{authorfullhash}{2273e0084ca97649d7edced9ce8d0ea3}
      \field{sortinit}{\v{S}}
      \field{sortinithash}{322b1d5276f2f6c1bccdcd15920dbee6}
      \true{uniqueprimaryauthor}
      \field{labelnamesource}{author}
    \endentry
|;


my $l23 = q|    \entry{L23}{book}{}
      \name{author}{1}{}{%
        {{hash=4389a3c0dc7da74487b50808ba9436ad}{%
           family={Smith},
           familyi={S\bibinitperiod},
           given={Šomeone},
           giveni={Š\bibinitperiod}}}%
      }
      \strng{namehash}{4389a3c0dc7da74487b50808ba9436ad}
      \strng{fullhash}{4389a3c0dc7da74487b50808ba9436ad}
      \strng{bibnamehash}{4389a3c0dc7da74487b50808ba9436ad}
      \strng{authorbibnamehash}{4389a3c0dc7da74487b50808ba9436ad}
      \strng{authornamehash}{4389a3c0dc7da74487b50808ba9436ad}
      \strng{authorfullhash}{4389a3c0dc7da74487b50808ba9436ad}
      \field{sortinit}{S}
      \field{sortinithash}{322b1d5276f2f6c1bccdcd15920dbee6}
      \field{labelnamesource}{author}
    \endentry
|;

my $l24 = q|    \entry{L24}{book}{}
      \name{author}{1}{}{%
        {{hash=e58b861545799d0eaf883402a882126e}{%
           family={Šmith},
           familyi={Š\bibinitperiod},
           given={Someone},
           giveni={S\bibinitperiod}}}%
      }
      \strng{namehash}{e58b861545799d0eaf883402a882126e}
      \strng{fullhash}{e58b861545799d0eaf883402a882126e}
      \strng{bibnamehash}{e58b861545799d0eaf883402a882126e}
      \strng{authorbibnamehash}{e58b861545799d0eaf883402a882126e}
      \strng{authornamehash}{e58b861545799d0eaf883402a882126e}
      \strng{authorfullhash}{e58b861545799d0eaf883402a882126e}
      \field{sortinit}{Š}
      \field{sortinithash}{322b1d5276f2f6c1bccdcd15920dbee6}
      \field{labelnamesource}{author}
    \endentry
|;

my $l25 = q|    \entry{L25}{book}{}
      \name{author}{1}{}{%
        {{hash=7069367d4a4f37ffb0377e3830e98ed0}{%
           family={{American Psychological Association, Task Force on the Sexualization of Girls}},
           familyi={A\bibinitperiod}}}%
      }
      \strng{namehash}{7069367d4a4f37ffb0377e3830e98ed0}
      \strng{fullhash}{7069367d4a4f37ffb0377e3830e98ed0}
      \strng{bibnamehash}{7069367d4a4f37ffb0377e3830e98ed0}
      \strng{authorbibnamehash}{7069367d4a4f37ffb0377e3830e98ed0}
      \strng{authornamehash}{7069367d4a4f37ffb0377e3830e98ed0}
      \strng{authorfullhash}{7069367d4a4f37ffb0377e3830e98ed0}
      \field{sortinit}{A}
      \field{sortinithash}{d77c7cdd82ff690d4c3ef13216f92f0b}
      \field{labelnamesource}{author}
    \endentry
|;

my $l26 = q|    \entry{L26}{book}{}
      \name{author}{1}{}{%
        {{hash=d176a8af5ce1c45cb06875c4433f2fe2}{%
           family={{Sci-Art Publishers}},
           familyi={S\bibinitperiod}}}%
      }
      \strng{namehash}{d176a8af5ce1c45cb06875c4433f2fe2}
      \strng{fullhash}{d176a8af5ce1c45cb06875c4433f2fe2}
      \strng{bibnamehash}{d176a8af5ce1c45cb06875c4433f2fe2}
      \strng{authorbibnamehash}{d176a8af5ce1c45cb06875c4433f2fe2}
      \strng{authornamehash}{d176a8af5ce1c45cb06875c4433f2fe2}
      \strng{authorfullhash}{d176a8af5ce1c45cb06875c4433f2fe2}
      \field{sortinit}{S}
      \field{sortinithash}{322b1d5276f2f6c1bccdcd15920dbee6}
      \field{labelnamesource}{author}
    \endentry
|;

# Malformed anyway but a decent test
my $l28 = q|    \entry{L28}{book}{}
      \field{sortinit}{0}
      \field{sortinithash}{168ad0c7c5ed09f1d28c6675717b5b03}
      \warn{\item Name "Deux et al.,, O." is malformed (consecutive commas): skipping name}
    \endentry
|;


my $l29 = q|    \entry{L29}{book}{}
      \name{author}{1}{}{%
        {{hash=59a5e43a502767d00e589eb29f863728}{%
           family={{U.S. Department of Health and Human Services, National Institute of Mental Health, National Heart, Lung and Blood Institute}},
           familyi={U\bibinitperiod}}}%
      }
      \strng{namehash}{59a5e43a502767d00e589eb29f863728}
      \strng{fullhash}{59a5e43a502767d00e589eb29f863728}
      \strng{bibnamehash}{59a5e43a502767d00e589eb29f863728}
      \strng{authorbibnamehash}{59a5e43a502767d00e589eb29f863728}
      \strng{authornamehash}{59a5e43a502767d00e589eb29f863728}
      \strng{authorfullhash}{59a5e43a502767d00e589eb29f863728}
      \field{sortinit}{U}
      \field{sortinithash}{36a2444f5238e0dcf4bb59704df6624d}
      \field{labelnamesource}{author}
    \endentry
|;

my $l31 = q|    \entry{L31}{book}{}
      \name{author}{1}{}{%
        {{hash=b43419361d83c9ab010e98aed1a83e35}{%
           family={{\~{Z}}elly},
           familyi={\~{Z}\\bibinitperiod},
           given={Arthur},
           giveni={A\bibinitperiod}}}%
      }
      \name{editor}{1}{}{%
        {{hash=b43419361d83c9ab010e98aed1a83e35}{%
           family={{\~{Z}}elly},
           familyi={\~{Z}\\bibinitperiod},
           given={Arthur},
           giveni={A\bibinitperiod}}}%
      }
      \name{translator}{1}{}{%
        {{hash=b43419361d83c9ab010e98aed1a83e35}{%
           family={{\~{Z}}elly},
           familyi={\~{Z}\\bibinitperiod},
           given={Arthur},
           giveni={A\bibinitperiod}}}%
      }
      \strng{namehash}{b43419361d83c9ab010e98aed1a83e35}
      \strng{fullhash}{b43419361d83c9ab010e98aed1a83e35}
      \strng{bibnamehash}{b43419361d83c9ab010e98aed1a83e35}
      \strng{authorbibnamehash}{b43419361d83c9ab010e98aed1a83e35}
      \strng{authornamehash}{b43419361d83c9ab010e98aed1a83e35}
      \strng{authorfullhash}{b43419361d83c9ab010e98aed1a83e35}
      \strng{editorbibnamehash}{b43419361d83c9ab010e98aed1a83e35}
      \strng{editornamehash}{b43419361d83c9ab010e98aed1a83e35}
      \strng{editorfullhash}{b43419361d83c9ab010e98aed1a83e35}
      \strng{translatorbibnamehash}{b43419361d83c9ab010e98aed1a83e35}
      \strng{translatornamehash}{b43419361d83c9ab010e98aed1a83e35}
      \strng{translatorfullhash}{b43419361d83c9ab010e98aed1a83e35}
      \field{sortinit}{\~{Z}}
      \field{sortinithash}{156173bd08b075d7295bc3e0f4735a04}
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
is_deeply(tparsename('John Doe', 'author'), $name1, 'parsename 1');
is_deeply(tparsename('Doe, Jr, John', 'author'), $name2, 'parsename 2');
is_deeply(tparsename('von Berlichingen zu Hornberg, Johann Gottfried', 'author'), $name3, 'parsename 3') ;
is_deeply(tparsename('von Berlichingen zu Hornberg, Johann Gottfried', 'author'), $name4, 'parsename 4') ;
is_deeply(tparsename('{Robert and Sons, Inc.}', 'author'), $name5, 'parsename 5') ;
is_deeply(tparsename('al-Ṣāliḥ, ʿAbdallāh', 'author'), $name6, 'parsename 6') ;
is_deeply(tparsename('Jean Charles Gabriel de la Vallée Poussin', 'author'), $name7, 'parsename 7');
is_deeply(tparsename('{Jean Charles Gabriel} de la Vallée Poussin', 'author'), $name8, 'parsename 8');
is_deeply(tparsename('Jean Charles Gabriel {de la} Vallée Poussin', 'author'), $name9, 'parsename 9');
is_deeply(tparsename('Jean Charles Gabriel de la {Vallée Poussin}', 'author'), $name10, 'parsename 10');
is_deeply(tparsename('{Jean Charles Gabriel} de la {Vallée Poussin}', 'author'), $name11, 'parsename 11');
is_deeply(tparsename('Jean Charles Gabriel Poussin', 'author'), $name12, 'parsename 12');
is_deeply(tparsename('Jean Charles {Poussin Lecoq}', 'author'), $name13, 'parsename 13');
is_deeply(tparsename('J. C. G. de la Vallée Poussin', 'author'), $name14, 'parsename 14');
is_deeply(tparsename('E. S. El-{M}allah', 'author'), $name15, 'parsename 15');
is_deeply(tparsename('E. S. {K}ent-{B}oswell', 'author'), $name16, 'parsename 16');
is_deeply(tparsename('Other, A.~N.', 'author'), $name17, 'parsename 17');
is_deeply(tparsename('{{{British National Corpus}}}', 'author'), $name18, 'parsename 18');
is_deeply(Biber::Input::file::bibtex::parsename('{{{British National Corpus}}}', 'author')->{strip}, $name18strip, 'parsename 18a');
is_deeply(tparsename('Vázques{ de }Parga, Luis', 'author'), $name19, 'parsename 19');
is_deeply(tparsename_x('family=Smithers Jones, prefix=van der, given=James, useprefix=true', 'author'), $namex1, 'parsename_x 1');
eq_or_diff(Biber::Input::file::bibtex::parsename_x('family=Smithers Jones, prefix=van der, given=James, useprefix=true', 'author')->{useprefix}, '1', 'parsename_x 2');

# name to bib tests
eq_or_diff(Biber::Input::file::bibtex::parsename('John Doe', 'author')->name_to_bib, 'Doe, John', 'name_to_bib 1');
eq_or_diff(Biber::Input::file::bibtex::parsename('John van der Doe', 'author')->name_to_bib, 'van der Doe, John', 'name_to_bib 2');
eq_or_diff(Biber::Input::file::bibtex::parsename('Doe, Jr, John', 'author')->name_to_bib, 'Doe, Jr, John', 'name_to_bib 3');
eq_or_diff(Biber::Input::file::bibtex::parsename('von Doe, Jr, John', 'author')->name_to_bib, 'von Doe, Jr, John', 'name_to_bib 4');
eq_or_diff(Biber::Input::file::bibtex::parsename('John Alan Doe', 'author')->name_to_bib, 'Doe, John Alan', 'name_to_bib 5');
eq_or_diff(Biber::Input::file::bibtex::parsename('{Robert and Sons, Inc.}', 'author')->name_to_bib, '{Robert and Sons, Inc.}', 'name_to_bib 6');
eq_or_diff(NFC(Biber::Input::file::bibtex::parsename('Jean Charles Gabriel de la {Vallée Poussin}', 'author')->name_to_bib), 'de la {Vallée Poussin}, Jean Charles Gabriel', 'name_to_bib 7');
eq_or_diff(Biber::Input::file::bibtex::parsename('E. S. {K}ent-{B}oswell', 'author')->name_to_bib, '{K}ent-{B}oswell, E. S.', 'name_to_bib 8');
is_deeply(Biber::Input::file::bibtex::parsename_x('family=Smithers Jones, prefix=van der, given=James, useprefix=true', 'author')->name_to_bib, 'van der Smithers Jones, James', 'name_to_bib - 9');

# name to xname tests
is_deeply(Biber::Input::file::bibtex::parsename('van der Smithers Jones, James', 'author')->name_to_xname, 'family=Smithers Jones, given=James, prefix=van der', 'name_to_xname - 1');
is_deeply(Biber::Input::file::bibtex::parsename_x('family=Smithers Jones, prefix=van der, given=James, useprefix=true', 'author')->name_to_xname, 'family=Smithers Jones, given=James, prefix=van der, useprefix=true', 'name_to_xname - 2');

# Full entry tests
eq_or_diff( $out->get_output_entry('L1', $main), $l1, 'First Last') ;
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
eq_or_diff($section->bibentry('L27')->get_field('author')->count_names, 1, 'Bad name with 3 commas');
eq_or_diff( $out->get_output_entry('L28', $main), $l28, 'Bad name with consecutive commas');
eq_or_diff( $out->get_output_entry('L29', $main), $l29, 'Escaped name with 3 commas');

# Checking visibility
# Count does not include the "and others" as this "name" is deleted in the output driver
eq_or_diff($bibentries->entry('V1')->get_field($bibentries->entry('V1')->get_labelname_info)->count_names, '2', 'Name count for "and others" - 1');
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
Biber::Config->setblxoption('uniqueprimaryauthor', 1);
Biber::Config->setoption('namesep', 'and'); # revert custom name sep
Biber::Input::file::bibtex->init_cache;

# Now generate the information
$biber->prepare;
$out = $biber->get_output_obj;
$section = $biber->sections->get_section(0);
$main = $biber->datalists->get_list('custom/global//global/global');
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

