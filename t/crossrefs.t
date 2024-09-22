# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 38;
use Test::Differences;
unified_diff;

use Biber;
use Biber::Constants;
use Biber::Output::bbl;
use Log::Log4perl;
use Capture::Tiny qw(capture);
use Biber::Utils;

chdir("t/tdata");

# Set up Biber object
my $biber = Biber->new(noconf => 1);

# Note stderr is output here so we can capture it and do a cyclic crossref test
my $LEVEL = 'ERROR';
my $l4pconf = qq|
    log4perl.category.main                             = $LEVEL, Screen
    log4perl.category.screen                           = $LEVEL, Screen
    log4perl.appender.Screen                           = Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.utf8                      = 1
    log4perl.appender.Screen.Threshold                 = $LEVEL
    log4perl.appender.Screen.stderr                    = 1
    log4perl.appender.Screen.layout                    = Log::Log4perl::Layout::SimpleLayout
|;

Log::Log4perl->init(\$l4pconf);

$biber->parse_ctrlfile('crossrefs.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

$DATAFIELD_SETS{'nobtitle'} = ['booktitle'];

# Biber options
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');
Biber::Config->setoption('nodieonerror', 1); # because there is a failing cyclic crossref check

# Now generate the information
my ($stdout, $stderr) = capture { $biber->prepare };
my $section0 = $biber->sections->get_section(0);
my $main = $biber->datalists->get_list('nty/global//global/global/global');
my $section1 = $biber->sections->get_section(1);
my $out = $biber->get_output_obj;
print "$stdout"; # needed for usual say(), dd() debugging due to capture() above

# crossref field is included as the parent is included by being crossrefed >= mincrossrefs times
my $cr1 = q|    \entry{cr1}{inbook}{}{}
      \name[default][en-us]{author}{1}{}{%
        {{hash=121b6dc164b5b619c81c670fbd823f12}{%
           family={Gullam},
           familyi={G\bibinitperiod},
           given={Graham},
           giveni={G\bibinitperiod}}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Gullam},
          familydefaulten-usi={G\bibinitperiod},
          givendefaulten-us={Graham},
          givendefaulten-usi={G\bibinitperiod}
      }
      \name[default][en-us]{editor}{1}{}{%
        {{hash=c129df5593fdaa7475548811bfbb227d}{%
           family={Erbriss},
           familyi={E\bibinitperiod},
           given={Edgar},
           giveni={E\bibinitperiod}}}%
      }
      \namepartms{editor}{1}{%
          familydefaulten-us={Erbriss},
          familydefaulten-usi={E\bibinitperiod},
          givendefaulten-us={Edgar},
          givendefaulten-usi={E\bibinitperiod}
      }
      \list[default][en-us]{publisher}{1}{%
        {Grimble}%
      }
      \listitemms{publisher}{1}{%
        defaulten-us={Grimble}
      }
      \strng{namehash}{121b6dc164b5b619c81c670fbd823f12}
      \strng{fullhash}{121b6dc164b5b619c81c670fbd823f12}
      \strng{fullhashraw}{121b6dc164b5b619c81c670fbd823f12}
      \strng{bibnamehash}{121b6dc164b5b619c81c670fbd823f12}
      \strng{authordefaulten-usbibnamehash}{121b6dc164b5b619c81c670fbd823f12}
      \strng{authordefaulten-usnamehash}{121b6dc164b5b619c81c670fbd823f12}
      \strng{authordefaulten-usfullhash}{121b6dc164b5b619c81c670fbd823f12}
      \strng{authordefaulten-usfullhashraw}{121b6dc164b5b619c81c670fbd823f12}
      \strng{editordefaulten-usbibnamehash}{c129df5593fdaa7475548811bfbb227d}
      \strng{editordefaulten-usnamehash}{c129df5593fdaa7475548811bfbb227d}
      \strng{editordefaulten-usfullhash}{c129df5593fdaa7475548811bfbb227d}
      \strng{editordefaulten-usfullhashraw}{c129df5593fdaa7475548811bfbb227d}
      \field{sortinit}{G}
      \strng{sortinithash}{32d67eca0634bf53703493fb1090a2e8}
      \true{singletitle}
      \true{uniquetitle}
      \true{uniquework}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{booktitle}{Graphs of the Continent}
      \strng{crossref}{cr_m}
      \field{eprintclass}{SOMECLASS}
      \field{eprinttype}{SomEPrFiX}
      \field{month}{1}
      \field{origyear}{1955}
      \field[default][en-us]{title}{Great and Good Graphs}
      \field{year}{1974}
      \field{origdateera}{ce}
    \endentry
|;

# crossref field is included as the parent is included by being crossrefed >= mincrossrefs times
my $cr2 = q|    \entry{cr2}{inbook}{}{}
      \name[default][en-us]{author}{1}{}{%
        {{hash=2d51a96bc0a6804995b3a9ff350c3384}{%
           family={Fumble},
           familyi={F\bibinitperiod},
           given={Frederick},
           giveni={F\bibinitperiod}}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Fumble},
          familydefaulten-usi={F\bibinitperiod},
          givendefaulten-us={Frederick},
          givendefaulten-usi={F\bibinitperiod}
      }
      \name[default][en-us]{editor}{1}{}{%
        {{hash=c129df5593fdaa7475548811bfbb227d}{%
           family={Erbriss},
           familyi={E\bibinitperiod},
           given={Edgar},
           giveni={E\bibinitperiod}}}%
      }
      \namepartms{editor}{1}{%
          familydefaulten-us={Erbriss},
          familydefaulten-usi={E\bibinitperiod},
          givendefaulten-us={Edgar},
          givendefaulten-usi={E\bibinitperiod}
      }
      \list[default][en-us]{institution}{1}{%
        {Institution}%
      }
      \listitemms{institution}{1}{%
        defaulten-us={Institution}
      }
      \list[default][en-us]{publisher}{1}{%
        {Grimble}%
      }
      \listitemms{publisher}{1}{%
        defaulten-us={Grimble}
      }
      \strng{namehash}{2d51a96bc0a6804995b3a9ff350c3384}
      \strng{fullhash}{2d51a96bc0a6804995b3a9ff350c3384}
      \strng{fullhashraw}{2d51a96bc0a6804995b3a9ff350c3384}
      \strng{bibnamehash}{2d51a96bc0a6804995b3a9ff350c3384}
      \strng{authordefaulten-usbibnamehash}{2d51a96bc0a6804995b3a9ff350c3384}
      \strng{authordefaulten-usnamehash}{2d51a96bc0a6804995b3a9ff350c3384}
      \strng{authordefaulten-usfullhash}{2d51a96bc0a6804995b3a9ff350c3384}
      \strng{authordefaulten-usfullhashraw}{2d51a96bc0a6804995b3a9ff350c3384}
      \strng{editordefaulten-usbibnamehash}{c129df5593fdaa7475548811bfbb227d}
      \strng{editordefaulten-usnamehash}{c129df5593fdaa7475548811bfbb227d}
      \strng{editordefaulten-usfullhash}{c129df5593fdaa7475548811bfbb227d}
      \strng{editordefaulten-usfullhashraw}{c129df5593fdaa7475548811bfbb227d}
      \field{sortinit}{F}
      \strng{sortinithash}{2638baaa20439f1b5a8f80c6c08a13b4}
      \true{singletitle}
      \true{uniquetitle}
      \true{uniquework}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{booktitle}{Graphs of the Continent}
      \strng{crossref}{cr_m}
      \field{origyear}{1943}
      \field[default][en-us]{title}{Fabulous Fourier Forms}
      \field{year}{1974}
      \field{origdateera}{ce}
    \endentry
|;

# This is included as it is crossrefed >= mincrossrefs times Notice lack of
# singletitle, labelname and labelname hashes because the only name is
# EDITOR and useeditor is false This is also why there is no
# \true{uniquework}
my $cr_m = q|    \entry{cr_m}{book}{}{}
      \name[default][en-us]{editor}{1}{}{%
        {{hash=c129df5593fdaa7475548811bfbb227d}{%
           family={Erbriss},
           familyi={E\bibinitperiod},
           given={Edgar},
           giveni={E\bibinitperiod}}}%
      }
      \namepartms{editor}{1}{%
          familydefaulten-us={Erbriss},
          familydefaulten-usi={E\bibinitperiod},
          givendefaulten-us={Edgar},
          givendefaulten-usi={E\bibinitperiod}
      }
      \list[default][en-us]{publisher}{1}{%
        {Grimble}%
      }
      \listitemms{publisher}{1}{%
        defaulten-us={Grimble}
      }
      \strng{editordefaulten-usbibnamehash}{c129df5593fdaa7475548811bfbb227d}
      \strng{editordefaulten-usnamehash}{c129df5593fdaa7475548811bfbb227d}
      \strng{editordefaulten-usfullhash}{c129df5593fdaa7475548811bfbb227d}
      \strng{editordefaulten-usfullhashraw}{c129df5593fdaa7475548811bfbb227d}
      \field{sortinit}{G}
      \strng{sortinithash}{32d67eca0634bf53703493fb1090a2e8}
      \true{crossrefsource}
      \true{uniquetitle}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{title}{Graphs of the Continent}
      \field{year}{1974}
    \endentry
|;

# crossref field is included as the parent is cited
my $cr3 = q|    \entry{cr3}{inbook}{}{}
      \name[default][en-us]{author}{1}{}{%
        {{hash=2baf676a220704f6914223aefccaaa88}{%
           family={Aptitude},
           familyi={A\bibinitperiod},
           given={Arthur},
           giveni={A\bibinitperiod}}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Aptitude},
          familydefaulten-usi={A\bibinitperiod},
          givendefaulten-us={Arthur},
          givendefaulten-usi={A\bibinitperiod}
      }
      \name[default][en-us]{editor}{1}{}{%
        {{hash=a1f5c22413396d599ec766725b226735}{%
           family={Monkley},
           familyi={M\bibinitperiod},
           given={Mark},
           giveni={M\bibinitperiod}}}%
      }
      \namepartms{editor}{1}{%
          familydefaulten-us={Monkley},
          familydefaulten-usi={M\bibinitperiod},
          givendefaulten-us={Mark},
          givendefaulten-usi={M\bibinitperiod}
      }
      \list[default][en-us]{publisher}{1}{%
        {Rancour}%
      }
      \listitemms{publisher}{1}{%
        defaulten-us={Rancour}
      }
      \strng{namehash}{2baf676a220704f6914223aefccaaa88}
      \strng{fullhash}{2baf676a220704f6914223aefccaaa88}
      \strng{fullhashraw}{2baf676a220704f6914223aefccaaa88}
      \strng{bibnamehash}{2baf676a220704f6914223aefccaaa88}
      \strng{authordefaulten-usbibnamehash}{2baf676a220704f6914223aefccaaa88}
      \strng{authordefaulten-usnamehash}{2baf676a220704f6914223aefccaaa88}
      \strng{authordefaulten-usfullhash}{2baf676a220704f6914223aefccaaa88}
      \strng{authordefaulten-usfullhashraw}{2baf676a220704f6914223aefccaaa88}
      \strng{editordefaulten-usbibnamehash}{a1f5c22413396d599ec766725b226735}
      \strng{editordefaulten-usnamehash}{a1f5c22413396d599ec766725b226735}
      \strng{editordefaulten-usfullhash}{a1f5c22413396d599ec766725b226735}
      \strng{editordefaulten-usfullhashraw}{a1f5c22413396d599ec766725b226735}
      \field{sortinit}{A}
      \strng{sortinithash}{2f401846e2029bad6b3ecc16d50031e2}
      \true{singletitle}
      \true{uniquetitle}
      \true{uniquework}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{booktitle}{Beasts of the Burbling Burns}
      \strng{crossref}{crt}
      \field{eprinttype}{sometype}
      \field{origyear}{1934}
      \field[default][en-us]{title}{Arrangements of All Articles}
      \field{year}{1996}
      \field{origdateera}{ce}
    \endentry
|;

# No crossref field as parent is not cited (mincrossrefs < 2)
my $cr4 = q|    \entry{cr4}{inbook}{}{}
      \name[default][en-us]{author}{1}{}{%
        {{hash=50ef7fd3a1be33bccc5de2768b013836}{%
           family={Mumble},
           familyi={M\bibinitperiod},
           given={Morris},
           giveni={M\bibinitperiod}}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Mumble},
          familydefaulten-usi={M\bibinitperiod},
          givendefaulten-us={Morris},
          givendefaulten-usi={M\bibinitperiod}
      }
      \name[default][en-us]{editor}{1}{}{%
        {{hash=6ea89bd4958743a20b70fe17647d6af5}{%
           family={Jermain},
           familyi={J\bibinitperiod},
           given={Jeremy},
           giveni={J\bibinitperiod}}}%
      }
      \namepartms{editor}{1}{%
          familydefaulten-us={Jermain},
          familydefaulten-usi={J\bibinitperiod},
          givendefaulten-us={Jeremy},
          givendefaulten-usi={J\bibinitperiod}
      }
      \list[default][en-us]{publisher}{1}{%
        {Pillsbury}%
      }
      \listitemms{publisher}{1}{%
        defaulten-us={Pillsbury}
      }
      \strng{namehash}{50ef7fd3a1be33bccc5de2768b013836}
      \strng{fullhash}{50ef7fd3a1be33bccc5de2768b013836}
      \strng{fullhashraw}{50ef7fd3a1be33bccc5de2768b013836}
      \strng{bibnamehash}{50ef7fd3a1be33bccc5de2768b013836}
      \strng{authordefaulten-usbibnamehash}{50ef7fd3a1be33bccc5de2768b013836}
      \strng{authordefaulten-usnamehash}{50ef7fd3a1be33bccc5de2768b013836}
      \strng{authordefaulten-usfullhash}{50ef7fd3a1be33bccc5de2768b013836}
      \strng{authordefaulten-usfullhashraw}{50ef7fd3a1be33bccc5de2768b013836}
      \strng{editordefaulten-usbibnamehash}{6ea89bd4958743a20b70fe17647d6af5}
      \strng{editordefaulten-usnamehash}{6ea89bd4958743a20b70fe17647d6af5}
      \strng{editordefaulten-usfullhash}{6ea89bd4958743a20b70fe17647d6af5}
      \strng{editordefaulten-usfullhashraw}{6ea89bd4958743a20b70fe17647d6af5}
      \field{sortinit}{M}
      \strng{sortinithash}{4625c616857f13d17ce56f7d4f97d451}
      \true{singletitle}
      \true{uniquetitle}
      \true{uniquework}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{booktitle}{Vanquished, Victor, Vandal}
      \field{origyear}{1911}
      \field[default][en-us]{title}{Enterprising Entities}
      \field{year}{1945}
      \field{origdateera}{ce}
    \endentry
|;

# cited as normal
# No singletitle as useeditor is false
my $crt = q|    \entry{crt}{book}{}{}
      \name[default][en-us]{editor}{1}{}{%
        {{hash=a1f5c22413396d599ec766725b226735}{%
           family={Monkley},
           familyi={M\bibinitperiod},
           given={Mark},
           giveni={M\bibinitperiod}}}%
      }
      \namepartms{editor}{1}{%
          familydefaulten-us={Monkley},
          familydefaulten-usi={M\bibinitperiod},
          givendefaulten-us={Mark},
          givendefaulten-usi={M\bibinitperiod}
      }
      \list[default][en-us]{publisher}{1}{%
        {Rancour}%
      }
      \listitemms{publisher}{1}{%
        defaulten-us={Rancour}
      }
      \strng{editordefaulten-usbibnamehash}{a1f5c22413396d599ec766725b226735}
      \strng{editordefaulten-usnamehash}{a1f5c22413396d599ec766725b226735}
      \strng{editordefaulten-usfullhash}{a1f5c22413396d599ec766725b226735}
      \strng{editordefaulten-usfullhashraw}{a1f5c22413396d599ec766725b226735}
      \field{sortinit}{B}
      \strng{sortinithash}{d7095fff47cda75ca2589920aae98399}
      \true{uniquetitle}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{title}{Beasts of the Burbling Burns}
      \field{year}{1996}
    \endentry
|;

# various event fields inherited correctly
my $cr6 = q|    \entry{cr6}{inproceedings}{}{}
      \name[default][en-us]{author}{1}{}{%
        {{hash=8ab39ee68c55046dc1f05d657fcefed9}{%
           family={Author},
           familyi={A\bibinitperiod},
           given={Firstname},
           giveni={F\bibinitperiod}}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Author},
          familydefaulten-usi={A\bibinitperiod},
          givendefaulten-us={Firstname},
          givendefaulten-usi={F\bibinitperiod}
      }
      \name[default][en-us]{editor}{1}{}{%
        {{hash=344a7f427fb765610ef96eb7bce95257}{%
           family={Editor},
           familyi={E\bibinitperiod}}}%
      }
      \namepartms{editor}{1}{%
          familydefaulten-us={Editor},
          familydefaulten-usi={E\bibinitperiod}
      }
      \list[default][en-us]{location}{1}{%
        {Address}%
      }
      \listitemms{location}{1}{%
        defaulten-us={Address}
      }
      \strng{namehash}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{fullhash}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{fullhashraw}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{bibnamehash}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{authordefaulten-usbibnamehash}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{authordefaulten-usnamehash}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{authordefaulten-usfullhash}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{authordefaulten-usfullhashraw}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{editordefaulten-usbibnamehash}{344a7f427fb765610ef96eb7bce95257}
      \strng{editordefaulten-usnamehash}{344a7f427fb765610ef96eb7bce95257}
      \strng{editordefaulten-usfullhash}{344a7f427fb765610ef96eb7bce95257}
      \strng{editordefaulten-usfullhashraw}{344a7f427fb765610ef96eb7bce95257}
      \field{extraname}{2}
      \field{sortinit}{A}
      \strng{sortinithash}{2f401846e2029bad6b3ecc16d50031e2}
      \true{uniquetitle}
      \true{uniquework}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{booktitle}{Manual booktitle}
      \field{eventday}{21}
      \field{eventendday}{24}
      \field{eventendmonth}{8}
      \field{eventendyear}{2009}
      \field{eventmonth}{8}
      \field{eventtitle}{Title of the event}
      \field{eventyear}{2009}
      \field[default][en-us]{title}{Title of inproceeding}
      \field[default][en-us]{venue}{Location of event}
      \field{year}{2009}
      \field{eventenddateera}{ce}
      \field{eventdateera}{ce}
      \field{pages}{123\bibrangedash}
      \range{pages}{-1}
    \endentry
|;

# Special fields inherited correctly
my $cr7 = q|    \entry{cr7}{inbook}{}{}
      \name[default][en-us]{author}{1}{}{%
        {{hash=8ab39ee68c55046dc1f05d657fcefed9}{%
           family={Author},
           familyi={A\bibinitperiod},
           given={Firstname},
           giveni={F\bibinitperiod}}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Author},
          familydefaulten-usi={A\bibinitperiod},
          givendefaulten-us={Firstname},
          givendefaulten-usi={F\bibinitperiod}
      }
      \name[default][en-us]{bookauthor}{1}{}{%
        {{hash=91a1dd4aeed3c4ec29ca74c4e778be5f}{%
           family={Bookauthor},
           familyi={B\bibinitperiod},
           given={Brian},
           giveni={B\bibinitperiod}}}%
      }
      \namepartms{bookauthor}{1}{%
          familydefaulten-us={Bookauthor},
          familydefaulten-usi={B\bibinitperiod},
          givendefaulten-us={Brian},
          givendefaulten-usi={B\bibinitperiod}
      }
      \list[default][en-us]{publisher}{1}{%
        {Publisher of proceeding}%
      }
      \listitemms{publisher}{1}{%
        defaulten-us={Publisher of proceeding}
      }
      \strng{namehash}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{fullhash}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{fullhashraw}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{bibnamehash}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{authordefaulten-usbibnamehash}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{authordefaulten-usnamehash}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{authordefaulten-usfullhash}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{authordefaulten-usfullhashraw}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{bookauthordefaulten-usbibnamehash}{91a1dd4aeed3c4ec29ca74c4e778be5f}
      \strng{bookauthordefaulten-usnamehash}{91a1dd4aeed3c4ec29ca74c4e778be5f}
      \strng{bookauthordefaulten-usfullhash}{91a1dd4aeed3c4ec29ca74c4e778be5f}
      \strng{bookauthordefaulten-usfullhashraw}{91a1dd4aeed3c4ec29ca74c4e778be5f}
      \field{extraname}{1}
      \field{sortinit}{A}
      \strng{sortinithash}{2f401846e2029bad6b3ecc16d50031e2}
      \true{uniquetitle}
      \true{uniquework}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{booksubtitle}{Book Subtitle}
      \field[default][en-us]{booktitle}{Book Title}
      \field[default][en-us]{booktitleaddon}{Book Titleaddon}
      \field[default][en-us]{title}{Title of Book bit}
      \field{year}{2010}
      \field{pages}{123\bibrangedash 126}
      \range{pages}{4}
      \verb{verbb}
      \verb String
      \endverb
    \endentry
|;

# Default inheritance suppressed except for specified
my $cr8 = q|    \entry{cr8}{incollection}{}{}
      \name[default][en-us]{author}{1}{}{%
        {{hash=3d449e56eb3ca1ae80dc99a18d689795}{%
           family={Smith},
           familyi={S\bibinitperiod},
           given={Firstname},
           giveni={F\bibinitperiod}}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Smith},
          familydefaulten-usi={S\bibinitperiod},
          givendefaulten-us={Firstname},
          givendefaulten-usi={F\bibinitperiod}
      }
      \strng{namehash}{3d449e56eb3ca1ae80dc99a18d689795}
      \strng{fullhash}{3d449e56eb3ca1ae80dc99a18d689795}
      \strng{fullhashraw}{3d449e56eb3ca1ae80dc99a18d689795}
      \strng{bibnamehash}{3d449e56eb3ca1ae80dc99a18d689795}
      \strng{authordefaulten-usbibnamehash}{3d449e56eb3ca1ae80dc99a18d689795}
      \strng{authordefaulten-usnamehash}{3d449e56eb3ca1ae80dc99a18d689795}
      \strng{authordefaulten-usfullhash}{3d449e56eb3ca1ae80dc99a18d689795}
      \strng{authordefaulten-usfullhashraw}{3d449e56eb3ca1ae80dc99a18d689795}
      \field{extraname}{4}
      \field{sortinit}{S}
      \strng{sortinithash}{b164b07b29984b41daf1e85279fbc5ab}
      \true{singletitle}
      \true{uniquetitle}
      \true{uniquework}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{booktitle}{Book Title}
      \field[default][en-us]{title}{Title of Collection bit}
      \field{year}{2010}
      \field{pages}{1\bibrangedash 12}
      \range{pages}{12}
    \endentry
|;

# xref field is included as the parent is included by being crossrefed >= mincrossrefs times
my $xr1 = q|    \entry{xr1}{inbook}{}{}
      \name[default][en-us]{author}{1}{}{%
        {{hash=e0ecc4fc668ee499d1afba44e1ac064d}{%
           family={Zentrum},
           familyi={Z\bibinitperiod},
           given={Zoe},
           giveni={Z\bibinitperiod}}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Zentrum},
          familydefaulten-usi={Z\bibinitperiod},
          givendefaulten-us={Zoe},
          givendefaulten-usi={Z\bibinitperiod}
      }
      \strng{namehash}{e0ecc4fc668ee499d1afba44e1ac064d}
      \strng{fullhash}{e0ecc4fc668ee499d1afba44e1ac064d}
      \strng{fullhashraw}{e0ecc4fc668ee499d1afba44e1ac064d}
      \strng{bibnamehash}{e0ecc4fc668ee499d1afba44e1ac064d}
      \strng{authordefaulten-usbibnamehash}{e0ecc4fc668ee499d1afba44e1ac064d}
      \strng{authordefaulten-usnamehash}{e0ecc4fc668ee499d1afba44e1ac064d}
      \strng{authordefaulten-usfullhash}{e0ecc4fc668ee499d1afba44e1ac064d}
      \strng{authordefaulten-usfullhashraw}{e0ecc4fc668ee499d1afba44e1ac064d}
      \field{sortinit}{Z}
      \strng{sortinithash}{96892c0b0a36bb8557c40c49813d48b3}
      \true{singletitle}
      \true{uniquetitle}
      \true{uniquework}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field{origyear}{1921}
      \field[default][en-us]{title}{Moods Mildly Modified}
      \strng{xref}{xrm}
      \field{origdateera}{ce}
    \endentry
|;

# xref field is included as the parent is included by being crossrefed >= mincrossrefs times
my $xr2 = q|    \entry{xr2}{inbook}{}{}
      \name[default][en-us]{author}{1}{}{%
        {{hash=6afa09374ecfd6b394ce714d2d9709c7}{%
           family={Instant},
           familyi={I\bibinitperiod},
           given={Ian},
           giveni={I\bibinitperiod}}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Instant},
          familydefaulten-usi={I\bibinitperiod},
          givendefaulten-us={Ian},
          givendefaulten-usi={I\bibinitperiod}
      }
      \strng{namehash}{6afa09374ecfd6b394ce714d2d9709c7}
      \strng{fullhash}{6afa09374ecfd6b394ce714d2d9709c7}
      \strng{fullhashraw}{6afa09374ecfd6b394ce714d2d9709c7}
      \strng{bibnamehash}{6afa09374ecfd6b394ce714d2d9709c7}
      \strng{authordefaulten-usbibnamehash}{6afa09374ecfd6b394ce714d2d9709c7}
      \strng{authordefaulten-usnamehash}{6afa09374ecfd6b394ce714d2d9709c7}
      \strng{authordefaulten-usfullhash}{6afa09374ecfd6b394ce714d2d9709c7}
      \strng{authordefaulten-usfullhashraw}{6afa09374ecfd6b394ce714d2d9709c7}
      \field{sortinit}{I}
      \strng{sortinithash}{8d291c51ee89b6cd86bf5379f0b151d8}
      \true{singletitle}
      \true{uniquetitle}
      \true{uniquework}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field{origyear}{1926}
      \field[default][en-us]{title}{Migraines Multiplying Madly}
      \strng{xref}{xrm}
      \field{origdateera}{ce}
    \endentry
|;

# This is included as it is xref'd >= minxrefs times Notice lack of singletitle,
# labelname and labelname hashes because the only name is EDITOR and
# useeditor is false
my $xrm = q|    \entry{xrm}{book}{}{}
      \name[default][en-us]{editor}{1}{}{%
        {{hash=809950f9b59ae207092b909a19dcb27b}{%
           family={Prendergast},
           familyi={P\bibinitperiod},
           given={Peter},
           giveni={P\bibinitperiod}}}%
      }
      \namepartms{editor}{1}{%
          familydefaulten-us={Prendergast},
          familydefaulten-usi={P\bibinitperiod},
          givendefaulten-us={Peter},
          givendefaulten-usi={P\bibinitperiod}
      }
      \list[default][en-us]{publisher}{1}{%
        {Mainstream}%
      }
      \listitemms{publisher}{1}{%
        defaulten-us={Mainstream}
      }
      \strng{editordefaulten-usbibnamehash}{809950f9b59ae207092b909a19dcb27b}
      \strng{editordefaulten-usnamehash}{809950f9b59ae207092b909a19dcb27b}
      \strng{editordefaulten-usfullhash}{809950f9b59ae207092b909a19dcb27b}
      \strng{editordefaulten-usfullhashraw}{809950f9b59ae207092b909a19dcb27b}
      \field{sortinit}{C}
      \strng{sortinithash}{4d103a86280481745c9c897c925753c0}
      \true{xrefsource}
      \true{uniquetitle}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{title}{Calligraphy, Calisthenics, Culture}
      \field{year}{1970}
    \endentry
|;

# xref field is included as the parent is cited
my $xr3 = q|    \entry{xr3}{inbook}{}{}
      \name[default][en-us]{author}{1}{}{%
        {{hash=9788055665b9bb4b37c776c3f6b74f16}{%
           family={Normal},
           familyi={N\bibinitperiod},
           given={Norman},
           giveni={N\bibinitperiod}}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Normal},
          familydefaulten-usi={N\bibinitperiod},
          givendefaulten-us={Norman},
          givendefaulten-usi={N\bibinitperiod}
      }
      \strng{namehash}{9788055665b9bb4b37c776c3f6b74f16}
      \strng{fullhash}{9788055665b9bb4b37c776c3f6b74f16}
      \strng{fullhashraw}{9788055665b9bb4b37c776c3f6b74f16}
      \strng{bibnamehash}{9788055665b9bb4b37c776c3f6b74f16}
      \strng{authordefaulten-usbibnamehash}{9788055665b9bb4b37c776c3f6b74f16}
      \strng{authordefaulten-usnamehash}{9788055665b9bb4b37c776c3f6b74f16}
      \strng{authordefaulten-usfullhash}{9788055665b9bb4b37c776c3f6b74f16}
      \strng{authordefaulten-usfullhashraw}{9788055665b9bb4b37c776c3f6b74f16}
      \field{sortinit}{N}
      \strng{sortinithash}{22369a73d5f88983a108b63f07f37084}
      \true{singletitle}
      \true{uniquetitle}
      \true{uniquework}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field{origyear}{1923}
      \field[default][en-us]{title}{Russian Regalia Revisited}
      \strng{xref}{xrt}
      \field{origdateera}{ce}
    \endentry
|;

# cited as normal
# Note no singletitle as useeditor is false
my $xrt = q|    \entry{xrt}{book}{}{}
      \name[default][en-us]{editor}{1}{}{%
        {{hash=bf7d6b02f3e073913e5bfe5059508dd5}{%
           family={Lunders},
           familyi={L\bibinitperiod},
           given={Lucy},
           giveni={L\bibinitperiod}}}%
      }
      \namepartms{editor}{1}{%
          familydefaulten-us={Lunders},
          familydefaulten-usi={L\bibinitperiod},
          givendefaulten-us={Lucy},
          givendefaulten-usi={L\bibinitperiod}
      }
      \list[default][en-us]{publisher}{1}{%
        {Middling}%
      }
      \listitemms{publisher}{1}{%
        defaulten-us={Middling}
      }
      \strng{editordefaulten-usbibnamehash}{bf7d6b02f3e073913e5bfe5059508dd5}
      \strng{editordefaulten-usnamehash}{bf7d6b02f3e073913e5bfe5059508dd5}
      \strng{editordefaulten-usfullhash}{bf7d6b02f3e073913e5bfe5059508dd5}
      \strng{editordefaulten-usfullhashraw}{bf7d6b02f3e073913e5bfe5059508dd5}
      \field{sortinit}{K}
      \strng{sortinithash}{c02bf6bff1c488450c352b40f5d853ab}
      \true{uniquetitle}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{title}{Kings, Cork and Calculation}
      \field{year}{1977}
    \endentry
|;


# No crossref field as parent is not cited (mincrossrefs < 2)
my $xr4 = q|    \entry{xr4}{inbook}{}{}
      \name[default][en-us]{author}{1}{}{%
        {{hash=7804ffef086c0c4686c235807f5cb502}{%
           family={Mistrel},
           familyi={M\bibinitperiod},
           given={Megan},
           giveni={M\bibinitperiod}}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Mistrel},
          familydefaulten-usi={M\bibinitperiod},
          givendefaulten-us={Megan},
          givendefaulten-usi={M\bibinitperiod}
      }
      \strng{namehash}{7804ffef086c0c4686c235807f5cb502}
      \strng{fullhash}{7804ffef086c0c4686c235807f5cb502}
      \strng{fullhashraw}{7804ffef086c0c4686c235807f5cb502}
      \strng{bibnamehash}{7804ffef086c0c4686c235807f5cb502}
      \strng{authordefaulten-usbibnamehash}{7804ffef086c0c4686c235807f5cb502}
      \strng{authordefaulten-usnamehash}{7804ffef086c0c4686c235807f5cb502}
      \strng{authordefaulten-usfullhash}{7804ffef086c0c4686c235807f5cb502}
      \strng{authordefaulten-usfullhashraw}{7804ffef086c0c4686c235807f5cb502}
      \field{extraname}{1}
      \field{sortinit}{M}
      \strng{sortinithash}{4625c616857f13d17ce56f7d4f97d451}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field{origyear}{1933}
      \field[default][en-us]{title}{Lumbering Lunatics}
      \strng{xref}{xrn}
      \field{origdateera}{ce}
    \endentry
|;

# Missing keys in xref/crossref should be deleted during datasource parse
# So these two should have no xref/crossref data in them
my $mxr = q|    \entry{mxr}{inbook}{}{}
      \name[default][en-us]{author}{1}{}{%
        {{hash=7804ffef086c0c4686c235807f5cb502}{%
           family={Mistrel},
           familyi={M\bibinitperiod},
           given={Megan},
           giveni={M\bibinitperiod}}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Mistrel},
          familydefaulten-usi={M\bibinitperiod},
          givendefaulten-us={Megan},
          givendefaulten-usi={M\bibinitperiod}
      }
      \strng{namehash}{7804ffef086c0c4686c235807f5cb502}
      \strng{fullhash}{7804ffef086c0c4686c235807f5cb502}
      \strng{fullhashraw}{7804ffef086c0c4686c235807f5cb502}
      \strng{bibnamehash}{7804ffef086c0c4686c235807f5cb502}
      \strng{authordefaulten-usbibnamehash}{7804ffef086c0c4686c235807f5cb502}
      \strng{authordefaulten-usnamehash}{7804ffef086c0c4686c235807f5cb502}
      \strng{authordefaulten-usfullhash}{7804ffef086c0c4686c235807f5cb502}
      \strng{authordefaulten-usfullhashraw}{7804ffef086c0c4686c235807f5cb502}
      \field{extraname}{2}
      \field{sortinit}{M}
      \strng{sortinithash}{4625c616857f13d17ce56f7d4f97d451}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field{origyear}{1933}
      \field[default][en-us]{title}{Lumbering Lunatics}
      \field{origdateera}{ce}
    \endentry
|;

my $mcr = q|    \entry{mcr}{inbook}{}{}
      \name[default][en-us]{author}{1}{}{%
        {{hash=7804ffef086c0c4686c235807f5cb502}{%
           family={Mistrel},
           familyi={M\bibinitperiod},
           given={Megan},
           giveni={M\bibinitperiod}}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Mistrel},
          familydefaulten-usi={M\bibinitperiod},
          givendefaulten-us={Megan},
          givendefaulten-usi={M\bibinitperiod}
      }
      \strng{namehash}{7804ffef086c0c4686c235807f5cb502}
      \strng{fullhash}{7804ffef086c0c4686c235807f5cb502}
      \strng{fullhashraw}{7804ffef086c0c4686c235807f5cb502}
      \strng{bibnamehash}{7804ffef086c0c4686c235807f5cb502}
      \strng{authordefaulten-usbibnamehash}{7804ffef086c0c4686c235807f5cb502}
      \strng{authordefaulten-usnamehash}{7804ffef086c0c4686c235807f5cb502}
      \strng{authordefaulten-usfullhash}{7804ffef086c0c4686c235807f5cb502}
      \strng{authordefaulten-usfullhashraw}{7804ffef086c0c4686c235807f5cb502}
      \field{extraname}{3}
      \field{sortinit}{M}
      \strng{sortinithash}{4625c616857f13d17ce56f7d4f97d451}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field{origyear}{1933}
      \field[default][en-us]{title}{Lumbering Lunatics}
      \field{origdateera}{ce}
    \endentry
|;

my $ccr1 = q|    \entry{ccr2}{book}{}{}
      \name[default][en-us]{author}{1}{}{%
        {{hash=6268941b408d3263bddb208a54899ea9}{%
           family={Various},
           familyi={V\bibinitperiod},
           given={Vince},
           giveni={V\bibinitperiod}}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Various},
          familydefaulten-usi={V\bibinitperiod},
          givendefaulten-us={Vince},
          givendefaulten-usi={V\bibinitperiod}
      }
      \name[default][en-us]{editor}{1}{}{%
        {{hash=cfee758a1c82df2e26af1985e061bb0a}{%
           family={Editor},
           familyi={E\bibinitperiod},
           given={Edward},
           giveni={E\bibinitperiod}}}%
      }
      \namepartms{editor}{1}{%
          familydefaulten-us={Editor},
          familydefaulten-usi={E\bibinitperiod},
          givendefaulten-us={Edward},
          givendefaulten-usi={E\bibinitperiod}
      }
      \strng{namehash}{6268941b408d3263bddb208a54899ea9}
      \strng{fullhash}{6268941b408d3263bddb208a54899ea9}
      \strng{fullhashraw}{6268941b408d3263bddb208a54899ea9}
      \strng{bibnamehash}{6268941b408d3263bddb208a54899ea9}
      \strng{authordefaulten-usbibnamehash}{6268941b408d3263bddb208a54899ea9}
      \strng{authordefaulten-usnamehash}{6268941b408d3263bddb208a54899ea9}
      \strng{authordefaulten-usfullhash}{6268941b408d3263bddb208a54899ea9}
      \strng{authordefaulten-usfullhashraw}{6268941b408d3263bddb208a54899ea9}
      \strng{editordefaulten-usbibnamehash}{cfee758a1c82df2e26af1985e061bb0a}
      \strng{editordefaulten-usnamehash}{cfee758a1c82df2e26af1985e061bb0a}
      \strng{editordefaulten-usfullhash}{cfee758a1c82df2e26af1985e061bb0a}
      \strng{editordefaulten-usfullhashraw}{cfee758a1c82df2e26af1985e061bb0a}
      \field{extraname}{1}
      \field{sortinit}{V}
      \strng{sortinithash}{afb52128e5b4dc4b843768c0113d673b}
      \true{uniquetitle}
      \true{uniquework}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \strng{crossref}{ccr1}
      \field[default][en-us]{title}{Misc etc.}
      \field{year}{1923}
      \field{dateera}{ce}
    \endentry
|;

my $ccr2 = q|    \entry{ccr3}{inbook}{}{}
      \name[default][en-us]{bookauthor}{1}{}{%
        {{hash=6268941b408d3263bddb208a54899ea9}{%
           family={Various},
           familyi={V\bibinitperiod},
           given={Vince},
           giveni={V\bibinitperiod}}}%
      }
      \namepartms{bookauthor}{1}{%
          familydefaulten-us={Various},
          familydefaulten-usi={V\bibinitperiod},
          givendefaulten-us={Vince},
          givendefaulten-usi={V\bibinitperiod}
      }
      \name[default][en-us]{editor}{1}{}{%
        {{hash=cfee758a1c82df2e26af1985e061bb0a}{%
           family={Editor},
           familyi={E\bibinitperiod},
           given={Edward},
           giveni={E\bibinitperiod}}}%
      }
      \namepartms{editor}{1}{%
          familydefaulten-us={Editor},
          familydefaulten-usi={E\bibinitperiod},
          givendefaulten-us={Edward},
          givendefaulten-usi={E\bibinitperiod}
      }
      \strng{bookauthordefaulten-usbibnamehash}{6268941b408d3263bddb208a54899ea9}
      \strng{bookauthordefaulten-usnamehash}{6268941b408d3263bddb208a54899ea9}
      \strng{bookauthordefaulten-usfullhash}{6268941b408d3263bddb208a54899ea9}
      \strng{bookauthordefaulten-usfullhashraw}{6268941b408d3263bddb208a54899ea9}
      \strng{editordefaulten-usbibnamehash}{cfee758a1c82df2e26af1985e061bb0a}
      \strng{editordefaulten-usnamehash}{cfee758a1c82df2e26af1985e061bb0a}
      \strng{editordefaulten-usfullhash}{cfee758a1c82df2e26af1985e061bb0a}
      \strng{editordefaulten-usfullhashraw}{cfee758a1c82df2e26af1985e061bb0a}
      \field{sortinit}{P}
      \strng{sortinithash}{ff3bcf24f47321b42cb156c2cc8a8422}
      \true{uniquetitle}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{booktitle}{Misc etc.}
      \strng{crossref}{ccr2}
      \field[default][en-us]{title}{Perhaps, Perchance, Possibilities?}
      \field{year}{1911}
      \field{dateera}{ce}
    \endentry
|;

# This is strange in what it gets from where but it shows information being inherited from two
# sources
my $ccr3 = q|    \entry{ccr4}{inbook}{}{}
      \name[default][en-us]{bookauthor}{1}{}{%
        {{hash=6268941b408d3263bddb208a54899ea9}{Various}{V\bibinitperiod}{Vince}{V\bibinitperiod}{}{}{}{}}%
      }
      \name[default][en-us]{editor}{1}{}{%
        {{hash=cfee758a1c82df2e26af1985e061bb0a}{Editor}{E\bibinitperiod}{Edward}{E\bibinitperiod}{}{}{}{}}%
      }
      \field{sortinit}{V}
      \strng{sortinithash}{4125bb4c3a0eb3eaee3ea6da32eb70c8}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{booktitle}{Misc etc.}
      \field[default][en-us]{title}{Stuff Concerning Varia}
      \field{year}{1911}
      \field{dateera}{ce}
    \endentry
|;

my $s1 = q|    \entry{s1}{inbook}{}{}
      \field{sortinit}{S}
      \strng{sortinithash}{b164b07b29984b41daf1e85279fbc5ab}
      \true{uniquetitle}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \strng{crossref}{s2}
      \field[default][en-us]{title}{Subtitle}
    \endentry
|;

my $xc2 = q|    \entry{xc2}{inbook}{}{}
      \name[default][en-us]{author}{1}{}{%
        {{hash=1a0f7d518cccdad859a74412ef956474}{%
           family={Crust},
           familyi={C\bibinitperiod},
           given={Xavier},
           giveni={X\bibinitperiod}}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Crust},
          familydefaulten-usi={C\bibinitperiod},
          givendefaulten-us={Xavier},
          givendefaulten-usi={X\bibinitperiod}
      }
      \name[default][en-us]{bookauthor}{1}{}{%
        {{hash=1a0f7d518cccdad859a74412ef956474}{%
           family={Crust},
           familyi={C\bibinitperiod},
           given={Xavier},
           giveni={X\bibinitperiod}}}%
      }
      \namepartms{bookauthor}{1}{%
          familydefaulten-us={Crust},
          familydefaulten-usi={C\bibinitperiod},
          givendefaulten-us={Xavier},
          givendefaulten-usi={X\bibinitperiod}
      }
      \strng{namehash}{1a0f7d518cccdad859a74412ef956474}
      \strng{fullhash}{1a0f7d518cccdad859a74412ef956474}
      \strng{fullhashraw}{1a0f7d518cccdad859a74412ef956474}
      \strng{bibnamehash}{1a0f7d518cccdad859a74412ef956474}
      \strng{authordefaulten-usbibnamehash}{1a0f7d518cccdad859a74412ef956474}
      \strng{authordefaulten-usnamehash}{1a0f7d518cccdad859a74412ef956474}
      \strng{authordefaulten-usfullhash}{1a0f7d518cccdad859a74412ef956474}
      \strng{authordefaulten-usfullhashraw}{1a0f7d518cccdad859a74412ef956474}
      \strng{bookauthordefaulten-usbibnamehash}{1a0f7d518cccdad859a74412ef956474}
      \strng{bookauthordefaulten-usnamehash}{1a0f7d518cccdad859a74412ef956474}
      \strng{bookauthordefaulten-usfullhash}{1a0f7d518cccdad859a74412ef956474}
      \strng{bookauthordefaulten-usfullhashraw}{1a0f7d518cccdad859a74412ef956474}
      \field{extraname}{2}
      \field{sortinit}{C}
      \strng{sortinithash}{4d103a86280481745c9c897c925753c0}
      \true{xrefsource}
      \fieldmssource{labelname}{author}{default}{en-us}
      \field[default][en-us]{booktitle}{Title}
    \endentry
|;

my $b1 = q|    \entry{b1}{inbook}{}{}
      \field{sortinit}{2}
      \strng{sortinithash}{8b555b3791beccb63322c22f3320aa9a}
      \strng{crossref}{b2}
      \field{day}{3}
      \field{month}{3}
      \field{origmonth}{3}
      \field{origyear}{2004}
      \field{year}{2004}
      \field{dateera}{ce}
      \field{origdateera}{ce}
    \endentry
|;

# sup1 is here because it is crossref'ed twice by sup2 and sup3 which share
# the author as a result. However, note that singletitle is true despite
# the same author for three entries because two instance of the author
# being present are by inheritance and singletitle tracking is suppressed
# in this case because of the "suppress=singletitle" in the inheritance
# definitions in the .bcf
my $sup1 = q|    \entry{sup1}{mvbook}{}{}
      \name[default][en-us]{author}{1}{}{%
        {{hash=556c8dba145b472e6a8598d506f7cbe2}{%
           family={Smith},
           familyi={S\bibinitperiod},
           given={Alan},
           giveni={A\bibinitperiod}}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Smith},
          familydefaulten-usi={S\bibinitperiod},
          givendefaulten-us={Alan},
          givendefaulten-usi={A\bibinitperiod}
      }
      \strng{namehash}{556c8dba145b472e6a8598d506f7cbe2}
      \strng{fullhash}{556c8dba145b472e6a8598d506f7cbe2}
      \strng{fullhashraw}{556c8dba145b472e6a8598d506f7cbe2}
      \strng{bibnamehash}{556c8dba145b472e6a8598d506f7cbe2}
      \strng{authordefaulten-usbibnamehash}{556c8dba145b472e6a8598d506f7cbe2}
      \strng{authordefaulten-usnamehash}{556c8dba145b472e6a8598d506f7cbe2}
      \strng{authordefaulten-usfullhash}{556c8dba145b472e6a8598d506f7cbe2}
      \strng{authordefaulten-usfullhashraw}{556c8dba145b472e6a8598d506f7cbe2}
      \field{extraname}{3}
      \field{sortinit}{S}
      \strng{sortinithash}{b164b07b29984b41daf1e85279fbc5ab}
      \true{crossrefsource}
      \true{singletitle}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{title}{Title1}
    \endentry
|;

my $sup2 = q|    \entry{sup2}{book}{}{}
      \name[default][en-us]{author}{1}{}{%
        {{hash=556c8dba145b472e6a8598d506f7cbe2}{%
           family={Smith},
           familyi={S\bibinitperiod},
           given={Alan},
           giveni={A\bibinitperiod}}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Smith},
          familydefaulten-usi={S\bibinitperiod},
          givendefaulten-us={Alan},
          givendefaulten-usi={A\bibinitperiod}
      }
      \strng{namehash}{556c8dba145b472e6a8598d506f7cbe2}
      \strng{fullhash}{556c8dba145b472e6a8598d506f7cbe2}
      \strng{fullhashraw}{556c8dba145b472e6a8598d506f7cbe2}
      \strng{bibnamehash}{556c8dba145b472e6a8598d506f7cbe2}
      \strng{authordefaulten-usbibnamehash}{556c8dba145b472e6a8598d506f7cbe2}
      \strng{authordefaulten-usnamehash}{556c8dba145b472e6a8598d506f7cbe2}
      \strng{authordefaulten-usfullhash}{556c8dba145b472e6a8598d506f7cbe2}
      \strng{authordefaulten-usfullhashraw}{556c8dba145b472e6a8598d506f7cbe2}
      \field{extraname}{1}
      \field{sortinit}{S}
      \strng{sortinithash}{b164b07b29984b41daf1e85279fbc5ab}
      \true{singletitle}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \strng{crossref}{sup1}
      \field[default][en-us]{note}{Book sup2}
      \field[default][en-us]{title}{Title1}
    \endentry
|;

my $lid2 = q|    \entry{lid2}{incollection}{}{}
      \name[default][en-us]{author}{1}{}{%
        {{hash=efc1032346cdbd27a2678c6a4b6e12d8}{%
           family={Jones},
           familyi={J\bibinitperiod},
           given={John},
           giveni={J\bibinitperiod}}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Jones},
          familydefaulten-usi={J\bibinitperiod},
          givendefaulten-us={John},
          givendefaulten-usi={J\bibinitperiod}
      }
      \strng{namehash}{efc1032346cdbd27a2678c6a4b6e12d8}
      \strng{fullhash}{efc1032346cdbd27a2678c6a4b6e12d8}
      \strng{fullhashraw}{efc1032346cdbd27a2678c6a4b6e12d8}
      \strng{bibnamehash}{efc1032346cdbd27a2678c6a4b6e12d8}
      \strng{authordefaulten-usbibnamehash}{efc1032346cdbd27a2678c6a4b6e12d8}
      \strng{authordefaulten-usnamehash}{efc1032346cdbd27a2678c6a4b6e12d8}
      \strng{authordefaulten-usfullhash}{efc1032346cdbd27a2678c6a4b6e12d8}
      \strng{authordefaulten-usfullhashraw}{efc1032346cdbd27a2678c6a4b6e12d8}
      \field{sortinit}{J}
      \strng{sortinithash}{b2f54a9081ace9966a7cb9413811edb4}
      \true{singletitle}
      \true{uniquetitle}
      \true{uniquework}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{booktitle}{Book title}
      \strng{crossref}{lid1}
      \field{langid}{english}
      \field[default][en-us]{title}{Paper title}
      \annotation[default][en-us]{field}{booktitle}{mslang}{}{}{1}{de}
    \endentry
|;

eq_or_diff($out->get_output_entry('cr1', $main), $cr1, 'crossref test 1');
eq_or_diff($out->get_output_entry('cr2', $main), $cr2, 'crossref test 2');
eq_or_diff($out->get_output_entry('cr_m', $main), $cr_m, 'crossref test 3');
eq_or_diff($out->get_output_entry('cr3', $main), $cr3, 'crossref test 4');
eq_or_diff($out->get_output_entry('crt', $main), $crt, 'crossref test 5');
eq_or_diff($out->get_output_entry('cr4', $main), $cr4, 'crossref test 6');
eq_or_diff($section0->has_citekey('crn'), 0,'crossref test 7');
eq_or_diff($out->get_output_entry('cr6', $main), $cr6, 'crossref test (inheritance) 8');
eq_or_diff($out->get_output_entry('cr7', $main), $cr7, 'crossref test (inheritance) 9');
eq_or_diff($out->get_output_entry('cr8', $main), $cr8, 'crossref test (inheritance) 10');
eq_or_diff($out->get_output_entry('xr1', $main), $xr1, 'xref test 1');
eq_or_diff($out->get_output_entry('xr2', $main), $xr2, 'xref test 2');
eq_or_diff($out->get_output_entry('xrm', $main), $xrm, 'xref test 3');
eq_or_diff($out->get_output_entry('xr3', $main), $xr3, 'xref test 4');
eq_or_diff($out->get_output_entry('xrt', $main), $xrt, 'xref test 5');
eq_or_diff($out->get_output_entry('xr4', $main), $xr4, 'xref test 6');
eq_or_diff($section0->has_citekey('xrn'), 1,'xref test 7');
eq_or_diff($out->get_output_entry('mxr', $main), $mxr, 'missing xref test');
eq_or_diff($out->get_output_entry('mcr', $main), $mcr, 'missing crossef test');
eq_or_diff($section1->has_citekey('crn'), 0,'mincrossrefs reset between sections');
eq_or_diff($out->get_output_entry('ccr2', $main), $ccr1, 'cascading crossref test 1');
eq_or_diff($out->get_output_entry('ccr3', $main), $ccr2, 'cascading crossref test 2');
chomp $stderr;
eq_or_diff($stderr, "ERROR - Circular inheritance between 'circ1'<->'circ2'\nERROR - Circular inheritance between 'circ3'<->'circ1'", 'Cyclic crossref error check');
eq_or_diff($section0->has_citekey('r1'), 1,'Recursive crossref test 1');
ok(defined($section0->bibentry('r1')),'Recursive crossref test 2');
eq_or_diff($section0->has_citekey('r2'), 0,'Recursive crossref test 3');
ok(defined($section0->bibentry('r2')),'Recursive crossref test 4');
eq_or_diff($section0->has_citekey('r3'), 0,'Recursive crossref test 5');
ok(defined($section0->bibentry('r3')),'Recursive crossref test 6');
eq_or_diff($section0->has_citekey('r4'), 0,'Recursive crossref test 7');
ok(defined($section0->bibentry('r4')),'Recursive crossref test 8');
eq_or_diff($out->get_output_entry('s1', $main), $s1, 'per-entry noinherit');
eq_or_diff($out->get_output_entry('xc2', $main), $xc2, 'Cascading xref+crossref');
eq_or_diff($out->get_output_entry('b1', $main), $b1, 'Blocking bad date inheritance');
eq_or_diff($out->get_output_entry('sup1', $main), $sup1, 'Suppressing singletitle tracking - 1');
eq_or_diff($out->get_output_entry('sup2', $main), $sup2, 'Suppressing singletitle tracking - 2');
eq_or_diff($section0->has_citekey('al2'), 0, 'mincrossref via alias');
eq_or_diff($out->get_output_entry('lid2', $main), $lid2, 'langid and annotations - 1');
