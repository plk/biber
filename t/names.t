# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 59;
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
Biber::Config->setoption('fastsort', 1);
Biber::Config->setblxoption('mincitenames', 3);

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $main = $biber->sortlists->get_list(0, 'nty/global/', 'entry', 'nty', 'global', '');
my $bibentries = $section->bibentries;

my $name1 =
    { given          => {string => 'John', initial => ['J']},
      family         => {string => 'Doe', initial => ['D']},
      nameinitstring => 'Doe_J',
      namestring     => 'Doe, John',
      prefix         => {string => undef, initial => undef},
      suffix         => {string => undef, initial => undef},
      strip          => { given => 0, family => 0, prefix => undef, suffix => undef }};

my $name2 =
    { given          => {string => 'John', initial => ['J']},
      family         => {string => 'Doe', initial  => ['D']},
      nameinitstring => 'Doe_J',
      namestring     => 'Doe, John',
      prefix         => {string => undef, initial => undef},
      suffix         => {string => 'Jr', initial => ['J']},
      strip          => { given => 0, family => 0, prefix => undef, suffix => 0 }};

my $name3 =
    { given          => {string => 'Johann~Gottfried', initial => ['J', 'G']},
      family         => {string => 'Berlichingen zu~Hornberg', initial => ['B', 'z', 'H']},
      nameinitstring => 'v_Berlichingen_zu_Hornberg_JG',
      namestring     => 'von Berlichingen zu Hornberg, Johann Gottfried',
      prefix         => {string => 'von', initial => ['v']},
      suffix         => {string => undef, initial => undef},
      strip          => { given => 0, family => 0, prefix => 0, suffix => undef }};

my $name4 =
    { given          => {string => 'Johann~Gottfried', initial => ['J', 'G']},
      family         => {string => 'Berlichingen zu~Hornberg', initial => ['B', 'z', 'H']},
      nameinitstring => 'Berlichingen_zu_Hornberg_JG',
      namestring     => 'von Berlichingen zu Hornberg, Johann Gottfried',
      prefix         => {string => 'von', initial => ['v']},
      suffix         => {string => undef, initial => undef},
      strip          => { given => 0, family => 0, prefix => 0, suffix => undef }};

my $name5 =
   {  given          => {string => undef, initial => undef},
      family         => {string => 'Robert and Sons, Inc.', initial => ['R']},
      nameinitstring => '{Robert_and_Sons,_Inc.}',
      namestring     => 'Robert and Sons, Inc.',
      prefix         => {string => undef, initial => undef},
      suffix         => {string => undef, initial => undef},
      strip          => { given => undef, family => 1, prefix => undef, suffix => undef }};

my $name6 =
   {  given          => {string => 'ʿAbdallāh', initial => ['A']},
      family         => {string => 'al-Ṣāliḥ', initial => ['Ṣ']},
      prefix         => {string => undef, initial => undef},
      suffix         => {string => undef, initial => undef},
      strip          => { given => 0, family => 0, prefix => undef, suffix => undef },
      namestring     => 'al-Ṣāliḥ, ʿAbdallāh',
      nameinitstring => 'al-Ṣāliḥ_A' } ;

my $name7 =
   {  given          => {string => 'Jean Charles~Gabriel', initial => ['J', 'C', 'G']},
      family         => {string => 'Vallée~Poussin', initial => ['V', 'P']},
      prefix         => {string => 'de~la', initial => ['d', 'l']},
      suffix         => {string => undef, initial => undef},
      strip          => { given => 0, family => 0, prefix => 0, suffix => undef },
      namestring     => 'de la Vallée Poussin, Jean Charles Gabriel',
      nameinitstring => 'dl_Vallée_Poussin_JCG' } ;

my $name8 =
   {  given          => {string => 'Jean Charles Gabriel', initial => ['J']},
      family         => {string => 'Vallée~Poussin', initial => ['V', 'P']},
      prefix         => {string => 'de~la', initial => ['d', 'l']},
      suffix         => {string => undef, initial => undef},
      strip          => { given => 1, family => 0, prefix => 0, suffix => undef },
      namestring     => 'de la Vallée Poussin, Jean Charles Gabriel',
      nameinitstring => 'Vallée_Poussin_J' } ;

my $name9 =
   {  given          => {string => 'Jean Charles Gabriel {de la}~Vallée', initial => ['J', 'C', 'G', 'd', 'V']},
      family         => {string => 'Poussin', initial => ['P']},
      prefix         => {string => undef, initial => undef},
      suffix         => {string => undef, initial => undef},
      strip          => { given => 0, family => 0, prefix => undef, suffix => undef },
      namestring     => 'Poussin, Jean Charles Gabriel {de la} Vallée',
      nameinitstring => 'Poussin_JCGdV' } ;

my $name10 =
   {  given          => {string => 'Jean Charles~Gabriel', initial => ['J', 'C', 'G']},
      family         => {string => 'Vallée Poussin', initial => ['V']},
      prefix         => {string => 'de~la', initial => ['d', 'l']},
      suffix         => {string => undef, initial => undef},
      strip          => { given => 0, family => 1, prefix => 0, suffix => undef },
      namestring     => 'de la Vallée Poussin, Jean Charles Gabriel',
      nameinitstring => '{Vallée_Poussin}_JCG' } ;

my $name11 =
   {  given          => {string => 'Jean Charles Gabriel', initial => ['J']},
      family         => {string => 'Vallée Poussin', initial => ['V']},
      prefix         => {string => 'de~la', initial => ['d', 'l']},
      suffix         => {string => undef, initial => undef},
      strip          => { given => 1, family => 1, prefix => 0, suffix => undef },
      namestring     => 'de la Vallée Poussin, Jean Charles Gabriel',
      nameinitstring => '{Vallée_Poussin}_J' } ;

my $name12 =
   {  given          => {string => 'Jean Charles~Gabriel', initial => ['J', 'C', 'G']},
      family         => {string => 'Poussin', initial => ['P']},
      prefix         => {string => undef, initial => undef},
      suffix         => {string => undef, initial => undef},
      strip          => { given => 0, family => 0, prefix => undef, suffix => undef },
      namestring     => 'Poussin, Jean Charles Gabriel',
      nameinitstring => 'Poussin_JCG' } ;

my $name13 =
   {  given          => {string => 'Jean~Charles', initial => ['J', 'C']},
      family         => {string => 'Poussin Lecoq', initial => ['P']},
      prefix         => {string => undef, initial => undef},
      suffix         => {string => undef, initial => undef},
      strip          => { given => 0, family => 1, prefix => undef, suffix => undef },
      namestring     => 'Poussin Lecoq, Jean Charles',
      nameinitstring => '{Poussin_Lecoq}_JC' } ;

my $name14 =
   {  given          => {string => 'J.~C.~G.', initial => ['J', 'C', 'G']},
      family         => {string => 'Vallée~Poussin', initial => ['V', 'P']},
      prefix         => {string => 'de~la', initial => ['d', 'l']},
      suffix         => {string => undef, initial => undef},
      strip          => { given => 0, family => 0, prefix => 0, suffix => undef },
      namestring     => 'de la Vallée Poussin, J. C. G.',
      nameinitstring => 'dl_Vallée_Poussin_JCG' } ;

# Note that the family initials are wrong because the prefix "El-" was not stripped
# This is because the default noinit regexp only strips lower-case prefices to protect
# hyphenated names
my $name15 =
   {  given          => {string => 'E.~S.', initial => ['E', 'S']},
      family         => {string => 'El-{M}allah', initial => ['E-M']},
      prefix         => {string => undef, initial => undef},
      suffix         => {string => undef, initial => undef},
      strip          => { given => 0, family => 0, prefix => undef, suffix => undef },
      namestring     => 'El-{M}allah, E. S.',
      nameinitstring => 'El-{M}allah_ES' } ;

my $name16 =
   {  given          => {string => 'E.~S.', initial => ['E', 'S']},
      family         => {string => '{K}ent-{B}oswell', initial => ['K-B']},
      prefix         => {string => undef, initial => undef},
      suffix         => {string => undef, initial => undef},
      strip          => { given => 0, family => 0, prefix => undef, suffix => undef },
      namestring     => '{K}ent-{B}oswell, E. S.',
      nameinitstring => '{K}ent-{B}oswell_ES' } ;

my $name17 =
   {  given          => {string => 'A.~N.', initial => ['A', 'N']},
      family         => {string => 'Other', initial => ['O']},
      prefix         => {string => undef, initial => undef},
      suffix         => {string => undef, initial => undef},
      strip          => { given => 0, family => 0, prefix => undef, suffix => undef },
      namestring     => 'Other, A. N.',
      nameinitstring => 'Other_AN' } ;

my $name18 =
   {  given          => {string => undef, initial => undef},
      family         => {string => 'British National Corpus', initial => ['B']},
      prefix         => {string => undef, initial => undef},
      suffix         => {string => undef, initial => undef},
      strip          => { given => undef, family => 1, prefix => undef, suffix => undef },
      namestring     => 'British National Corpus',
      nameinitstring => '{British_National_Corpus}' } ;

my $l1 = q|    \entry{L1}{book}{}
      \name{author}{1}{}{%
        {{hash=72287a68c1714cb1b9f4ab9e03a88b96}{%
           family={Adler},
           family_i={A\bibinitperiod},
           given={Alfred},
           given_i={A\bibinitperiod}}}%
      }
      \strng{namehash}{72287a68c1714cb1b9f4ab9e03a88b96}
      \strng{fullhash}{72287a68c1714cb1b9f4ab9e03a88b96}
      \field{sortinit}{A}
      \field{sortinithash}{b685c7856330eaee22789815b49de9bb}
      \field{labelnamesource}{author}
    \endentry
|;

my $l2 = q|    \entry{L2}{book}{}
      \name{author}{1}{}{%
        {{hash=1c867a2b5ceb243bab70afb18702dc04}{%
           family={Bull},
           family_i={B\bibinitperiod},
           given={Bertie\bibnamedelima B.},
           given_i={B\bibinitperiod\bibinitdelim B\bibinitperiod}}}%
      }
      \strng{namehash}{1c867a2b5ceb243bab70afb18702dc04}
      \strng{fullhash}{1c867a2b5ceb243bab70afb18702dc04}
      \field{sortinit}{B}
      \field{sortinithash}{4ecbea03efd0532989d3836d1a048c32}
      \field{labelnamesource}{author}
    \endentry
|;

my $l3 = q|    \entry{L3}{book}{}
      \name{author}{1}{}{%
        {{hash=cecd18116c43ee86e5a136b6e0362948}{%
           family={Crop},
           family_i={C\bibinitperiod},
           given={C.\bibnamedelimi Z.},
           given_i={C\bibinitperiod\bibinitdelim Z\bibinitperiod}}}%
      }
      \strng{namehash}{cecd18116c43ee86e5a136b6e0362948}
      \strng{fullhash}{cecd18116c43ee86e5a136b6e0362948}
      \field{sortinit}{C}
      \field{sortinithash}{59f25d509f3381b07695554a9f35ecb2}
      \field{labelnamesource}{author}
    \endentry
|;

my $l4 = q|    \entry{L4}{book}{}
      \name{author}{1}{}{%
        {{hash=675883f3aca7c6069c0b154d47af4c86}{%
           family={Decket},
           family_i={D\bibinitperiod},
           given={Derek\bibnamedelima D},
           given_i={D\bibinitperiod\bibinitdelim D\bibinitperiod}}}%
      }
      \strng{namehash}{675883f3aca7c6069c0b154d47af4c86}
      \strng{fullhash}{675883f3aca7c6069c0b154d47af4c86}
      \field{sortinit}{D}
      \field{sortinithash}{78f7c4753a2004675f316a80bdb31742}
      \field{labelnamesource}{author}
    \endentry
|;

my $l5 = q|    \entry{L5}{book}{}
      \name{author}{1}{}{%
        {{hash=c2d41bb75b01ec2339c1050981f9c2cc}{%
           prefix={von},
           prefix_i={v\bibinitperiod},
           family={Eel},
           family_i={E\bibinitperiod},
           given={Egbert},
           given_i={E\bibinitperiod}}}%
      }
      \strng{namehash}{c2d41bb75b01ec2339c1050981f9c2cc}
      \strng{fullhash}{c2d41bb75b01ec2339c1050981f9c2cc}
      \field{sortinit}{v}
      \field{sortinithash}{d18f5ce25ce0b5ca7f924e3f6c04870e}
      \field{labelnamesource}{author}
    \endentry
|;

my $l6 = q|    \entry{L6}{book}{}
      \name{author}{1}{}{%
        {{hash=68e9105aa98379a85ef6cd2e7ac29c00}{%
           prefix={van\bibnamedelimb der\bibnamedelima valt},
           prefix_i={v\bibinitperiod\bibinitdelim d\bibinitperiod\bibinitdelim v\bibinitperiod},
           family={Frome},
           family_i={F\bibinitperiod},
           given={Francis},
           given_i={F\bibinitperiod}}}%
      }
      \strng{namehash}{68e9105aa98379a85ef6cd2e7ac29c00}
      \strng{fullhash}{68e9105aa98379a85ef6cd2e7ac29c00}
      \field{sortinit}{v}
      \field{sortinithash}{d18f5ce25ce0b5ca7f924e3f6c04870e}
      \field{labelnamesource}{author}
    \endentry
|;

my $l7 = q|    \entry{L7}{book}{}
      \name{author}{1}{}{%
        {{hash=4dbef3c5464f951b537a49ba93676a9a}{%
           prefix={van},
           prefix_i={v\bibinitperiod},
           family={Gloom},
           family_i={G\bibinitperiod},
           given={Gregory\bibnamedelima R.},
           given_i={G\bibinitperiod\bibinitdelim R\bibinitperiod}}}%
      }
      \strng{namehash}{4dbef3c5464f951b537a49ba93676a9a}
      \strng{fullhash}{4dbef3c5464f951b537a49ba93676a9a}
      \field{sortinit}{v}
      \field{sortinithash}{d18f5ce25ce0b5ca7f924e3f6c04870e}
      \field{labelnamesource}{author}
    \endentry
|;

my $l8 = q|    \entry{L8}{book}{}
      \name{author}{1}{}{%
        {{hash=9fb4d242b62f047e4255282864eedb97}{%
           prefix={van},
           prefix_i={v\bibinitperiod},
           family={Henkel},
           family_i={H\bibinitperiod},
           given={Henry\bibnamedelima F.},
           given_i={H\bibinitperiod\bibinitdelim F\bibinitperiod}}}%
      }
      \strng{namehash}{9fb4d242b62f047e4255282864eedb97}
      \strng{fullhash}{9fb4d242b62f047e4255282864eedb97}
      \field{sortinit}{v}
      \field{sortinithash}{d18f5ce25ce0b5ca7f924e3f6c04870e}
      \field{labelnamesource}{author}
    \endentry
|;

my $l9 = q|    \entry{L9}{book}{}
      \name{author}{1}{}{%
        {{hash=1734924c4c55de5bb18d020c34a5249e}{%
           family={{Iliad Ipswich}},
           family_i={I\bibinitperiod},
           given={Ian},
           given_i={I\bibinitperiod}}}%
      }
      \strng{namehash}{1734924c4c55de5bb18d020c34a5249e}
      \strng{fullhash}{1734924c4c55de5bb18d020c34a5249e}
      \field{sortinit}{I}
      \field{sortinithash}{25e99d37ba90f7c4fb20baf4e310faf3}
      \field{labelnamesource}{author}
    \endentry
|;


my $l10 = q|    \entry{L10}{book}{}
      \name{author}{1}{}{%
        {{hash=758a11cc45860d7635b1f6091b2d95a9}{%
           family={Jolly},
           family_i={J\bibinitperiod},
           suffix={III},
           suffix_i={I\bibinitperiod},
           given={James},
           given_i={J\bibinitperiod}}}%
      }
      \strng{namehash}{758a11cc45860d7635b1f6091b2d95a9}
      \strng{fullhash}{758a11cc45860d7635b1f6091b2d95a9}
      \field{sortinit}{J}
      \field{sortinithash}{ec3950a647c092421b9fcca6d819504a}
      \field{labelnamesource}{author}
    \endentry
|;


my $l10a = q|    \entry{L10a}{book}{}
      \name{author}{1}{}{%
        {{hash=5e60d697e6432558eab7dccf9890eb79}{%
           family={Pimentel},
           family_i={P\bibinitperiod},
           suffix={Jr.},
           suffix_i={J\bibinitperiod},
           given={Joseph\bibnamedelima J.},
           given_i={J\bibinitperiod\bibinitdelim J\bibinitperiod}}}%
      }
      \strng{namehash}{5e60d697e6432558eab7dccf9890eb79}
      \strng{fullhash}{5e60d697e6432558eab7dccf9890eb79}
      \field{sortinit}{P}
      \field{sortinithash}{c0a4896d0e424f9ca4d7f14f2b3428e7}
      \field{labelnamesource}{author}
    \endentry
|;


my $l11 = q|    \entry{L11}{book}{}
      \name{author}{1}{}{%
        {{hash=ef4ab7eba5cd140b54ba4329e1dda90b}{%
           prefix={van},
           prefix_i={v\bibinitperiod},
           family={Kluster},
           family_i={K\bibinitperiod},
           suffix={Jr.},
           suffix_i={J\bibinitperiod},
           given={Kevin},
           given_i={K\bibinitperiod}}}%
      }
      \strng{namehash}{ef4ab7eba5cd140b54ba4329e1dda90b}
      \strng{fullhash}{ef4ab7eba5cd140b54ba4329e1dda90b}
      \field{sortinit}{v}
      \field{sortinithash}{d18f5ce25ce0b5ca7f924e3f6c04870e}
      \field{labelnamesource}{author}
    \endentry
|;

my $l12 = q|    \entry{L12}{book}{}
      \name{author}{1}{}{%
        {{hash=5bb094a9232384acc478f1aa54e8cf3c}{%
           prefix={de\bibnamedelima la},
           prefix_i={d\bibinitperiod\bibinitdelim l\bibinitperiod},
           family={Vallée\bibnamedelima Poussin},
           family_i={V\bibinitperiod\bibinitdelim P\bibinitperiod},
           given={Charles\bibnamedelimb Louis\bibnamedelimb Xavier\bibnamedelima Joseph},
           given_i={C\bibinitperiod\bibinitdelim L\bibinitperiod\bibinitdelim X\bibinitperiod\bibinitdelim J\bibinitperiod}}}%
      }
      \strng{namehash}{5bb094a9232384acc478f1aa54e8cf3c}
      \strng{fullhash}{5bb094a9232384acc478f1aa54e8cf3c}
      \field{sortinit}{d}
      \field{sortinithash}{78f7c4753a2004675f316a80bdb31742}
      \true{uniqueprimaryauthor}
      \field{labelnamesource}{author}
    \endentry
|;

my $l13 = q|    \entry{L13}{book}{}
      \name{author}{1}{}{%
        {{hash=5e79da6869afaf0d38e01285b494d555}{%
           family={Van\bibnamedelimb de\bibnamedelima Graaff},
           family_i={V\bibinitperiod\bibinitdelim d\bibinitperiod\bibinitdelim G\bibinitperiod},
           given={R.\bibnamedelimi J.},
           given_i={R\bibinitperiod\bibinitdelim J\bibinitperiod}}}%
      }
      \strng{namehash}{5e79da6869afaf0d38e01285b494d555}
      \strng{fullhash}{5e79da6869afaf0d38e01285b494d555}
      \field{sortinit}{V}
      \field{sortinithash}{d18f5ce25ce0b5ca7f924e3f6c04870e}
      \field{labelnamesource}{author}
    \endentry
|;

my $l14 = q|    \entry{L14}{book}{}
      \name{author}{1}{}{%
        {{hash=2319907d9a5d5dd46da77879bdb7e609}{%
           family={St\bibnamedelima John-Mollusc},
           family_i={S\bibinitperiod\bibinitdelim J\bibinithyphendelim M\bibinitperiod},
           given={Oliver},
           given_i={O\bibinitperiod}}}%
      }
      \strng{namehash}{2319907d9a5d5dd46da77879bdb7e609}
      \strng{fullhash}{2319907d9a5d5dd46da77879bdb7e609}
      \field{sortinit}{S}
      \field{sortinithash}{fd1e7c5ab79596b13dbbb67f8d70fb5a}
      \field{labelnamesource}{author}
    \endentry
|;

my $l15 = q|    \entry{L15}{book}{}
      \name{author}{1}{}{%
        {{hash=379b415d869a4751678a5eee23b07e48}{%
           prefix={van},
           prefix_i={v\bibinitperiod},
           family={Gompel},
           family_i={G\bibinitperiod},
           given={Roger\bibnamedelima P.{\,}G.},
           given_i={R\bibinitperiod\bibinitdelim P\bibinitperiod}}}%
      }
      \strng{namehash}{379b415d869a4751678a5eee23b07e48}
      \strng{fullhash}{379b415d869a4751678a5eee23b07e48}
      \field{sortinit}{v}
      \field{sortinithash}{d18f5ce25ce0b5ca7f924e3f6c04870e}
      \field{labelnamesource}{author}
    \endentry
|;

my $l16 = q|    \entry{L16}{book}{}
      \name{author}{1}{}{%
        {{hash=0a9532fa161f6305ec403c1c85951bdf}{%
           prefix={van},
           prefix_i={v\bibinitperiod},
           family={Gompel},
           family_i={G\bibinitperiod},
           given={Roger\bibnamedelima {P.\,G.}},
           given_i={R\bibinitperiod\bibinitdelim P\bibinitperiod}}}%
      }
      \strng{namehash}{0a9532fa161f6305ec403c1c85951bdf}
      \strng{fullhash}{0a9532fa161f6305ec403c1c85951bdf}
      \field{sortinit}{v}
      \field{sortinithash}{d18f5ce25ce0b5ca7f924e3f6c04870e}
      \field{labelnamesource}{author}
    \endentry
|;

my $l17 = q|    \entry{L17}{book}{}
      \name{author}{1}{}{%
        {{hash=766d5329cf995fcc7c1cef19de2a2ae8}{%
           family={Lovecraft},
           family_i={L\bibinitperiod},
           given={Bill\bibnamedelima H.{\,}P.},
           given_i={B\bibinitperiod\bibinitdelim H\bibinitperiod}}}%
      }
      \strng{namehash}{766d5329cf995fcc7c1cef19de2a2ae8}
      \strng{fullhash}{766d5329cf995fcc7c1cef19de2a2ae8}
      \field{sortinit}{L}
      \field{sortinithash}{872351f18d0f736066eda0bf18bfa4f7}
      \field{labelnamesource}{author}
    \endentry
|;

my $l18 = q|    \entry{L18}{book}{}
      \name{author}{1}{}{%
        {{hash=58620d2c7d6839bac23306c732c563fb}{%
           family={Lovecraft},
           family_i={L\bibinitperiod},
           given={Bill\bibnamedelima {H.\,P.}},
           given_i={B\bibinitperiod\bibinitdelim H\bibinitperiod}}}%
      }
      \strng{namehash}{58620d2c7d6839bac23306c732c563fb}
      \strng{fullhash}{58620d2c7d6839bac23306c732c563fb}
      \field{sortinit}{L}
      \field{sortinithash}{872351f18d0f736066eda0bf18bfa4f7}
      \field{labelnamesource}{author}
    \endentry
|;

my $l19 = q|    \entry{L19}{book}{}
      \name{author}{1}{}{%
        {{hash=83caa52f21f97e572dd3267bdf62978a}{%
           family={Mustermann},
           family_i={M\bibinitperiod},
           given={Klaus-Peter},
           given_i={K\bibinithyphendelim P\bibinitperiod}}}%
      }
      \strng{namehash}{83caa52f21f97e572dd3267bdf62978a}
      \strng{fullhash}{83caa52f21f97e572dd3267bdf62978a}
      \field{sortinit}{M}
      \field{sortinithash}{2684bec41e9697b92699b46491061da2}
      \field{labelnamesource}{author}
    \endentry
|;

my $l19a = q|    \entry{L19a}{book}{}
      \name{author}{1}{}{%
        {{hash=0963f6904ccfeaac2770c5882a587001}{%
           family={Lam},
           family_i={L\bibinitperiod},
           given={Ho-Pun},
           given_i={H\bibinithyphendelim P\bibinitperiod}}}%
      }
      \strng{namehash}{0963f6904ccfeaac2770c5882a587001}
      \strng{fullhash}{0963f6904ccfeaac2770c5882a587001}
      \field{sortinit}{L}
      \field{sortinithash}{872351f18d0f736066eda0bf18bfa4f7}
      \field{labelnamesource}{author}
    \endentry
|;


my $l20 = q|    \entry{L20}{book}{}
      \name{author}{1}{}{%
        {{hash=fdaa0936724be89ef8bd16cf02e08c74}{%
           family={Ford},
           family_i={F\bibinitperiod},
           given={{John Henry}},
           given_i={J\bibinitperiod}}}%
      }
      \strng{namehash}{fdaa0936724be89ef8bd16cf02e08c74}
      \strng{fullhash}{fdaa0936724be89ef8bd16cf02e08c74}
      \field{sortinit}{F}
      \field{sortinithash}{c6a7d9913bbd7b20ea954441c0460b78}
      \field{labelnamesource}{author}
    \endentry
|;

my $l21 = q|    \entry{L21}{book}{}
      \name{author}{1}{}{%
        {{hash=4389a3c0dc7da74487b50808ba9436ad}{%
           family={Smith},
           family_i={S\bibinitperiod},
           given={\v{S}omeone},
           given_i={\v{S}\bibinitperiod}}}%
      }
      \strng{namehash}{4389a3c0dc7da74487b50808ba9436ad}
      \strng{fullhash}{4389a3c0dc7da74487b50808ba9436ad}
      \field{sortinit}{S}
      \field{sortinithash}{fd1e7c5ab79596b13dbbb67f8d70fb5a}
      \field{labelnamesource}{author}
    \endentry
|;

my $l22u = q|    \entry{L22}{book}{}
      \name{author}{1}{}{%
        {{hash=e58b861545799d0eaf883402a882126e}{%
           family={Šmith},
           family_i={Š\bibinitperiod},
           given={Someone},
           given_i={S\bibinitperiod}}}%
      }
      \strng{namehash}{e58b861545799d0eaf883402a882126e}
      \strng{fullhash}{e58b861545799d0eaf883402a882126e}
      \field{sortinit}{Š}
      \field{sortinithash}{fd1e7c5ab79596b13dbbb67f8d70fb5a}
      \field{labelnamesource}{author}
    \endentry
|;


my $l22 = q|    \entry{L22}{book}{}
      \name{author}{1}{}{%
        {{hash=e58b861545799d0eaf883402a882126e}{%
           family={\v{S}mith},
           family_i={\v{S}\bibinitperiod},
           given={Someone},
           given_i={S\bibinitperiod}}}%
      }
      \strng{namehash}{e58b861545799d0eaf883402a882126e}
      \strng{fullhash}{e58b861545799d0eaf883402a882126e}
      \field{sortinit}{\v{S}}
      \field{sortinithash}{fd1e7c5ab79596b13dbbb67f8d70fb5a}
      \field{labelnamesource}{author}
    \endentry
|;


my $l23 = q|    \entry{L23}{book}{}
      \name{author}{1}{}{%
        {{hash=4389a3c0dc7da74487b50808ba9436ad}{%
           family={Smith},
           family_i={S\bibinitperiod},
           given={Šomeone},
           given_i={Š\bibinitperiod}}}%
      }
      \strng{namehash}{4389a3c0dc7da74487b50808ba9436ad}
      \strng{fullhash}{4389a3c0dc7da74487b50808ba9436ad}
      \field{sortinit}{S}
      \field{sortinithash}{fd1e7c5ab79596b13dbbb67f8d70fb5a}
      \field{labelnamesource}{author}
    \endentry
|;

my $l24 = q|    \entry{L24}{book}{}
      \name{author}{1}{}{%
        {{hash=e58b861545799d0eaf883402a882126e}{%
           family={Šmith},
           family_i={Š\bibinitperiod},
           given={Someone},
           given_i={S\bibinitperiod}}}%
      }
      \strng{namehash}{e58b861545799d0eaf883402a882126e}
      \strng{fullhash}{e58b861545799d0eaf883402a882126e}
      \field{sortinit}{Š}
      \field{sortinithash}{fd1e7c5ab79596b13dbbb67f8d70fb5a}
      \field{labelnamesource}{author}
    \endentry
|;

my $l25 = q|    \entry{L25}{book}{}
      \name{author}{1}{}{%
        {{hash=7069367d4a4f37ffb0377e3830e98ed0}{%
           family={{American Psychological Association, Task Force on the Sexualization of Girls}},
           family_i={A\bibinitperiod}}}%
      }
      \strng{namehash}{7069367d4a4f37ffb0377e3830e98ed0}
      \strng{fullhash}{7069367d4a4f37ffb0377e3830e98ed0}
      \field{sortinit}{A}
      \field{sortinithash}{b685c7856330eaee22789815b49de9bb}
      \field{labelnamesource}{author}
    \endentry
|;

my $l26 = q|    \entry{L26}{book}{}
      \name{author}{1}{}{%
        {{hash=d176a8af5ce1c45cb06875c4433f2fe2}{%
           family={{Sci-Art Publishers}},
           family_i={S\bibinitperiod}}}%
      }
      \strng{namehash}{d176a8af5ce1c45cb06875c4433f2fe2}
      \strng{fullhash}{d176a8af5ce1c45cb06875c4433f2fe2}
      \field{sortinit}{S}
      \field{sortinithash}{fd1e7c5ab79596b13dbbb67f8d70fb5a}
      \field{labelnamesource}{author}
    \endentry
|;

# Malformed anyway but a decent test
my $l28 = q|    \entry{L28}{book}{}
      \field{sortinit}{0}
      \field{sortinithash}{990108227b3316c02842d895999a0165}
      \warn{\item Name "Deux et al.,, O." is malformed (consecutive commas): skipping name}
    \endentry
|;


my $l29 = q|    \entry{L29}{book}{}
      \name{author}{1}{}{%
        {{hash=59a5e43a502767d00e589eb29f863728}{%
           family={{U.S. Department of Health and Human Services, National Institute of Mental Health, National Heart, Lung and Blood Institute}},
           family_i={U\bibinitperiod}}}%
      }
      \strng{namehash}{59a5e43a502767d00e589eb29f863728}
      \strng{fullhash}{59a5e43a502767d00e589eb29f863728}
      \field{sortinit}{U}
      \field{sortinithash}{8145509bd2718876fc77d31fd2cde117}
      \field{labelnamesource}{author}
    \endentry
|;

my $l31 = q|    \entry{L31}{book}{}
      \name{author}{1}{}{%
        {{hash=29c3ff92fff79d09a8b44d2f775de0b1}{%
           family={\~{Z}elly},
           family_i={\~{Z}\\bibinitperiod},
           given={Arthur},
           given_i={A\bibinitperiod}}}%
      }
      \name{editor}{1}{}{%
        {{hash=29c3ff92fff79d09a8b44d2f775de0b1}{%
           family={\~{Z}elly},
           family_i={\~{Z}\\bibinitperiod},
           given={Arthur},
           given_i={A\bibinitperiod}}}%
      }
      \name{translator}{1}{}{%
        {{hash=29c3ff92fff79d09a8b44d2f775de0b1}{%
           family={\~{Z}elly},
           family_i={\~{Z}\\bibinitperiod},
           given={Arthur},
           given_i={A\bibinitperiod}}}%
      }
      \strng{namehash}{29c3ff92fff79d09a8b44d2f775de0b1}
      \strng{fullhash}{29c3ff92fff79d09a8b44d2f775de0b1}
      \field{sortinit}{\~{Z}}
      \field{sortinithash}{fdda4caaa6b5fa63e0c081dcb159543a}
      \true{uniqueprimaryauthor}
      \field{labelnamesource}{author}
    \endentry
|;

is_deeply(Biber::Input::file::bibtex::parsename('John Doe', 'author'), $name1, 'parsename 1');
is_deeply(Biber::Input::file::bibtex::parsename('Doe, Jr, John', 'author'), $name2, 'parsename 2');
is_deeply(Biber::Input::file::bibtex::parsename('von Berlichingen zu Hornberg, Johann Gottfried', 'author', {useprefix => 1}), $name3, 'parsename 3') ;
is_deeply(Biber::Input::file::bibtex::parsename('von Berlichingen zu Hornberg, Johann Gottfried', 'author', {useprefix => 0}), $name4, 'parsename 4') ;
is_deeply(Biber::Input::file::bibtex::parsename('{Robert and Sons, Inc.}', 'author'), $name5, 'parsename 5') ;
is_deeply(Biber::Input::file::bibtex::parsename('al-Ṣāliḥ, ʿAbdallāh', 'author', undef, 1), $name6, 'parsename 6') ;
is_deeply(Biber::Input::file::bibtex::parsename('Jean Charles Gabriel de la Vallée Poussin', 'author', {useprefix => 1}, 1), $name7, 'parsename 7');
is_deeply(Biber::Input::file::bibtex::parsename('{Jean Charles Gabriel} de la Vallée Poussin', 'author', undef, 1), $name8, 'parsename 8');
is_deeply(Biber::Input::file::bibtex::parsename('Jean Charles Gabriel {de la} Vallée Poussin', 'author', undef, 1), $name9, 'parsename 9');
is_deeply(Biber::Input::file::bibtex::parsename('Jean Charles Gabriel de la {Vallée Poussin}', 'author', undef, 1), $name10, 'parsename 10');
is_deeply(Biber::Input::file::bibtex::parsename('{Jean Charles Gabriel} de la {Vallée Poussin}', 'author', undef, 1), $name11, 'parsename 11');
is_deeply(Biber::Input::file::bibtex::parsename('Jean Charles Gabriel Poussin', 'author'), $name12, 'parsename 12');
is_deeply(Biber::Input::file::bibtex::parsename('Jean Charles {Poussin Lecoq}', 'author'), $name13, 'parsename 13');
is_deeply(Biber::Input::file::bibtex::parsename('J. C. G. de la Vallée Poussin', 'author', {useprefix => 1}, 1), $name14, 'parsename 14');
is_deeply(Biber::Input::file::bibtex::parsename('E. S. El-{M}allah', 'author'), $name15, 'parsename 15');
is_deeply(Biber::Input::file::bibtex::parsename('E. S. {K}ent-{B}oswell', 'author'), $name16, 'parsename 16');
is_deeply(Biber::Input::file::bibtex::parsename('Other, A.~N.', 'author'), $name17, 'parsename 17');
is_deeply(Biber::Input::file::bibtex::parsename('{{{British National Corpus}}}', 'author'), $name18, 'parsename 18');

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
# Count does not include the "and others" as this "name" is delete in the output driver
eq_or_diff($bibentries->entry('V1')->get_field($bibentries->entry('V1')->get_labelname_info)->count_names, '2', 'Name count for "and others" - 1');
eq_or_diff($bibentries->entry('V1')->get_field($bibentries->entry('V1')->get_labelname_info)->get_visible_cite, '2', 'Visibility for "and others" - 1');
eq_or_diff($bibentries->entry('V2')->get_field($bibentries->entry('V2')->get_labelname_info)->get_visible_cite, '1', 'Visibility for "and others" - 2');

# A few tests depend set to non UTF-8 output
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
$main = $biber->sortlists->get_list(0, 'nty/global/', 'entry', 'nty', 'global', '');
$bibentries = $section->bibentries;

eq_or_diff(NFC($bibentries->entry('L21')->get_field($bibentries->entry('L21')->get_labelname_info)->nth_name(1)->get_namepart_initial('given')->[0]), 'Š', 'Terseinitials 1'); # Should be in NFD UTF-8
eq_or_diff( encode_utf8($out->get_output_entry('L12', $main)), encode_utf8($l12), 'First First First First prefix prefix Last Last') ;
eq_or_diff( $out->get_output_entry('L21', $main), $l21, 'LaTeX encoded unicode given name');
eq_or_diff( $out->get_output_entry('L22', $main), $l22, 'LaTeX encoded unicode family name - 2');
eq_or_diff( $out->get_output_entry('L31', $main), $l31, 'LaTeX encoded unicode family name with tie char');

# uniqueprimaryauthor tests
eq_or_diff($section->bibentry('upa1')->get_field('uniqueprimaryauthor'), 1, 'Unique primary author - 1');
ok(is_undef($bibentries->entry('upa2')->get_field('uniqueprimaryauthor')), 'Unique primary author - 2');
ok(is_undef($bibentries->entry('upa3')->get_field('uniqueprimaryauthor')), 'Unique primary author - 3');
eq_or_diff($section->bibentry('upa4')->get_field('uniqueprimaryauthor'), 1, 'Unique primary author - 4');

