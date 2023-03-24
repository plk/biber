# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 37;
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
      \name{author}{1}{}{%
        {{hash=121b6dc164b5b619c81c670fbd823f12}{%
           family={Gullam},
           familyi={G\bibinitperiod},
           given={Graham},
           giveni={G\bibinitperiod}}}%
      }
      \name{editor}{1}{}{%
        {{hash=c129df5593fdaa7475548811bfbb227d}{%
           family={Erbriss},
           familyi={E\bibinitperiod},
           given={Edgar},
           giveni={E\bibinitperiod}}}%
      }
      \list{publisher}{1}{%
        {Grimble}%
      }
      \strng{namehash}{121b6dc164b5b619c81c670fbd823f12}
      \strng{fullhash}{121b6dc164b5b619c81c670fbd823f12}
      \strng{fullhashraw}{121b6dc164b5b619c81c670fbd823f12}
      \strng{bibnamehash}{121b6dc164b5b619c81c670fbd823f12}
      \strng{authorbibnamehash}{121b6dc164b5b619c81c670fbd823f12}
      \strng{authornamehash}{121b6dc164b5b619c81c670fbd823f12}
      \strng{authorfullhash}{121b6dc164b5b619c81c670fbd823f12}
      \strng{authorfullhashraw}{121b6dc164b5b619c81c670fbd823f12}
      \strng{editorbibnamehash}{c129df5593fdaa7475548811bfbb227d}
      \strng{editornamehash}{c129df5593fdaa7475548811bfbb227d}
      \strng{editorfullhash}{c129df5593fdaa7475548811bfbb227d}
      \strng{editorfullhashraw}{c129df5593fdaa7475548811bfbb227d}
      \field{sortinit}{G}
      \field{sortinithash}{32d67eca0634bf53703493fb1090a2e8}
      \true{singletitle}
      \true{uniquetitle}
      \true{uniquework}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{booktitle}{Graphs of the Continent}
      \strng{crossref}{cr_m}
      \field{eprintclass}{SOMECLASS}
      \field{eprinttype}{SomEPrFiX}
      \field{month}{1}
      \field{origyear}{1955}
      \field{title}{Great and Good Graphs}
      \field{year}{1974}
      \field{origdateera}{ce}
    \endentry
|;

# crossref field is included as the parent is included by being crossrefed >= mincrossrefs times
my $cr2 = q|    \entry{cr2}{inbook}{}{}
      \name{author}{1}{}{%
        {{hash=2d51a96bc0a6804995b3a9ff350c3384}{%
           family={Fumble},
           familyi={F\bibinitperiod},
           given={Frederick},
           giveni={F\bibinitperiod}}}%
      }
      \name{editor}{1}{}{%
        {{hash=c129df5593fdaa7475548811bfbb227d}{%
           family={Erbriss},
           familyi={E\bibinitperiod},
           given={Edgar},
           giveni={E\bibinitperiod}}}%
      }
      \list{institution}{1}{%
        {Institution}%
      }
      \list{publisher}{1}{%
        {Grimble}%
      }
      \strng{namehash}{2d51a96bc0a6804995b3a9ff350c3384}
      \strng{fullhash}{2d51a96bc0a6804995b3a9ff350c3384}
      \strng{fullhashraw}{2d51a96bc0a6804995b3a9ff350c3384}
      \strng{bibnamehash}{2d51a96bc0a6804995b3a9ff350c3384}
      \strng{authorbibnamehash}{2d51a96bc0a6804995b3a9ff350c3384}
      \strng{authornamehash}{2d51a96bc0a6804995b3a9ff350c3384}
      \strng{authorfullhash}{2d51a96bc0a6804995b3a9ff350c3384}
      \strng{authorfullhashraw}{2d51a96bc0a6804995b3a9ff350c3384}
      \strng{editorbibnamehash}{c129df5593fdaa7475548811bfbb227d}
      \strng{editornamehash}{c129df5593fdaa7475548811bfbb227d}
      \strng{editorfullhash}{c129df5593fdaa7475548811bfbb227d}
      \strng{editorfullhashraw}{c129df5593fdaa7475548811bfbb227d}
      \field{sortinit}{F}
      \field{sortinithash}{2638baaa20439f1b5a8f80c6c08a13b4}
      \true{singletitle}
      \true{uniquetitle}
      \true{uniquework}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{booktitle}{Graphs of the Continent}
      \strng{crossref}{cr_m}
      \field{origyear}{1943}
      \field{title}{Fabulous Fourier Forms}
      \field{year}{1974}
      \field{origdateera}{ce}
    \endentry
|;

# This is included as it is crossrefed >= mincrossrefs times Notice lack of
# singletitle, labelname and labelname hashes because the only name is
# EDITOR and useeditor is false This is also why there is no
# \true{uniquework}
my $cr_m = q|    \entry{cr_m}{book}{}{}
      \name{editor}{1}{}{%
        {{hash=c129df5593fdaa7475548811bfbb227d}{%
           family={Erbriss},
           familyi={E\bibinitperiod},
           given={Edgar},
           giveni={E\bibinitperiod}}}%
      }
      \list{publisher}{1}{%
        {Grimble}%
      }
      \strng{editorbibnamehash}{c129df5593fdaa7475548811bfbb227d}
      \strng{editornamehash}{c129df5593fdaa7475548811bfbb227d}
      \strng{editorfullhash}{c129df5593fdaa7475548811bfbb227d}
      \strng{editorfullhashraw}{c129df5593fdaa7475548811bfbb227d}
      \field{sortinit}{G}
      \field{sortinithash}{32d67eca0634bf53703493fb1090a2e8}
      \true{crossrefsource}
      \true{uniquetitle}
      \field{labeltitlesource}{title}
      \field{title}{Graphs of the Continent}
      \field{year}{1974}
    \endentry
|;

# crossref field is included as the parent is cited
my $cr3 = q|    \entry{cr3}{inbook}{}{}
      \name{author}{1}{}{%
        {{hash=2baf676a220704f6914223aefccaaa88}{%
           family={Aptitude},
           familyi={A\bibinitperiod},
           given={Arthur},
           giveni={A\bibinitperiod}}}%
      }
      \name{editor}{1}{}{%
        {{hash=a1f5c22413396d599ec766725b226735}{%
           family={Monkley},
           familyi={M\bibinitperiod},
           given={Mark},
           giveni={M\bibinitperiod}}}%
      }
      \list{publisher}{1}{%
        {Rancour}%
      }
      \strng{namehash}{2baf676a220704f6914223aefccaaa88}
      \strng{fullhash}{2baf676a220704f6914223aefccaaa88}
      \strng{fullhashraw}{2baf676a220704f6914223aefccaaa88}
      \strng{bibnamehash}{2baf676a220704f6914223aefccaaa88}
      \strng{authorbibnamehash}{2baf676a220704f6914223aefccaaa88}
      \strng{authornamehash}{2baf676a220704f6914223aefccaaa88}
      \strng{authorfullhash}{2baf676a220704f6914223aefccaaa88}
      \strng{authorfullhashraw}{2baf676a220704f6914223aefccaaa88}
      \strng{editorbibnamehash}{a1f5c22413396d599ec766725b226735}
      \strng{editornamehash}{a1f5c22413396d599ec766725b226735}
      \strng{editorfullhash}{a1f5c22413396d599ec766725b226735}
      \strng{editorfullhashraw}{a1f5c22413396d599ec766725b226735}
      \field{sortinit}{A}
      \field{sortinithash}{2f401846e2029bad6b3ecc16d50031e2}
      \true{singletitle}
      \true{uniquetitle}
      \true{uniquework}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{booktitle}{Beasts of the Burbling Burns}
      \strng{crossref}{crt}
      \field{eprinttype}{sometype}
      \field{origyear}{1934}
      \field{title}{Arrangements of All Articles}
      \field{year}{1996}
      \field{origdateera}{ce}
    \endentry
|;

# No crossref field as parent is not cited (mincrossrefs < 2)
my $cr4 = q|    \entry{cr4}{inbook}{}{}
      \name{author}{1}{}{%
        {{hash=50ef7fd3a1be33bccc5de2768b013836}{%
           family={Mumble},
           familyi={M\bibinitperiod},
           given={Morris},
           giveni={M\bibinitperiod}}}%
      }
      \name{editor}{1}{}{%
        {{hash=6ea89bd4958743a20b70fe17647d6af5}{%
           family={Jermain},
           familyi={J\bibinitperiod},
           given={Jeremy},
           giveni={J\bibinitperiod}}}%
      }
      \list{publisher}{1}{%
        {Pillsbury}%
      }
      \strng{namehash}{50ef7fd3a1be33bccc5de2768b013836}
      \strng{fullhash}{50ef7fd3a1be33bccc5de2768b013836}
      \strng{fullhashraw}{50ef7fd3a1be33bccc5de2768b013836}
      \strng{bibnamehash}{50ef7fd3a1be33bccc5de2768b013836}
      \strng{authorbibnamehash}{50ef7fd3a1be33bccc5de2768b013836}
      \strng{authornamehash}{50ef7fd3a1be33bccc5de2768b013836}
      \strng{authorfullhash}{50ef7fd3a1be33bccc5de2768b013836}
      \strng{authorfullhashraw}{50ef7fd3a1be33bccc5de2768b013836}
      \strng{editorbibnamehash}{6ea89bd4958743a20b70fe17647d6af5}
      \strng{editornamehash}{6ea89bd4958743a20b70fe17647d6af5}
      \strng{editorfullhash}{6ea89bd4958743a20b70fe17647d6af5}
      \strng{editorfullhashraw}{6ea89bd4958743a20b70fe17647d6af5}
      \field{sortinit}{M}
      \field{sortinithash}{4625c616857f13d17ce56f7d4f97d451}
      \true{singletitle}
      \true{uniquetitle}
      \true{uniquework}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{booktitle}{Vanquished, Victor, Vandal}
      \field{origyear}{1911}
      \field{title}{Enterprising Entities}
      \field{year}{1945}
      \field{origdateera}{ce}
    \endentry
|;

# cited as normal
# No singletitle as useeditor is false
my $crt = q|    \entry{crt}{book}{}{}
      \name{editor}{1}{}{%
        {{hash=a1f5c22413396d599ec766725b226735}{%
           family={Monkley},
           familyi={M\bibinitperiod},
           given={Mark},
           giveni={M\bibinitperiod}}}%
      }
      \list{publisher}{1}{%
        {Rancour}%
      }
      \strng{editorbibnamehash}{a1f5c22413396d599ec766725b226735}
      \strng{editornamehash}{a1f5c22413396d599ec766725b226735}
      \strng{editorfullhash}{a1f5c22413396d599ec766725b226735}
      \strng{editorfullhashraw}{a1f5c22413396d599ec766725b226735}
      \field{sortinit}{B}
      \field{sortinithash}{d7095fff47cda75ca2589920aae98399}
      \true{uniquetitle}
      \field{labeltitlesource}{title}
      \field{title}{Beasts of the Burbling Burns}
      \field{year}{1996}
    \endentry
|;

# various event fields inherited correctly
my $cr6 = q|    \entry{cr6}{inproceedings}{}{}
      \name{author}{1}{}{%
        {{hash=8ab39ee68c55046dc1f05d657fcefed9}{%
           family={Author},
           familyi={A\bibinitperiod},
           given={Firstname},
           giveni={F\bibinitperiod}}}%
      }
      \name{editor}{1}{}{%
        {{hash=344a7f427fb765610ef96eb7bce95257}{%
           family={Editor},
           familyi={E\bibinitperiod}}}%
      }
      \list{location}{1}{%
        {Address}%
      }
      \strng{namehash}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{fullhash}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{fullhashraw}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{bibnamehash}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{authorbibnamehash}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{authornamehash}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{authorfullhash}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{authorfullhashraw}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{editorbibnamehash}{344a7f427fb765610ef96eb7bce95257}
      \strng{editornamehash}{344a7f427fb765610ef96eb7bce95257}
      \strng{editorfullhash}{344a7f427fb765610ef96eb7bce95257}
      \strng{editorfullhashraw}{344a7f427fb765610ef96eb7bce95257}
      \field{extraname}{2}
      \field{sortinit}{A}
      \field{sortinithash}{2f401846e2029bad6b3ecc16d50031e2}
      \true{uniquetitle}
      \true{uniquework}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{booktitle}{Manual booktitle}
      \field{eventday}{21}
      \field{eventendday}{24}
      \field{eventendmonth}{8}
      \field{eventendyear}{2009}
      \field{eventmonth}{8}
      \field{eventtitle}{Title of the event}
      \field{eventyear}{2009}
      \field{title}{Title of inproceeding}
      \field{venue}{Location of event}
      \field{year}{2009}
      \field{eventenddateera}{ce}
      \field{eventdateera}{ce}
      \field{pages}{123\bibrangedash}
      \range{pages}{-1}
    \endentry
|;

# Special fields inherited correctly
my $cr7 = q|    \entry{cr7}{inbook}{}{}
      \name{author}{1}{}{%
        {{hash=8ab39ee68c55046dc1f05d657fcefed9}{%
           family={Author},
           familyi={A\bibinitperiod},
           given={Firstname},
           giveni={F\bibinitperiod}}}%
      }
      \name{bookauthor}{1}{}{%
        {{hash=91a1dd4aeed3c4ec29ca74c4e778be5f}{%
           family={Bookauthor},
           familyi={B\bibinitperiod},
           given={Brian},
           giveni={B\bibinitperiod}}}%
      }
      \list{publisher}{1}{%
        {Publisher of proceeding}%
      }
      \strng{namehash}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{fullhash}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{fullhashraw}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{bibnamehash}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{authorbibnamehash}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{authornamehash}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{authorfullhash}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{authorfullhashraw}{8ab39ee68c55046dc1f05d657fcefed9}
      \strng{bookauthorbibnamehash}{91a1dd4aeed3c4ec29ca74c4e778be5f}
      \strng{bookauthornamehash}{91a1dd4aeed3c4ec29ca74c4e778be5f}
      \strng{bookauthorfullhash}{91a1dd4aeed3c4ec29ca74c4e778be5f}
      \strng{bookauthorfullhashraw}{91a1dd4aeed3c4ec29ca74c4e778be5f}
      \field{extraname}{1}
      \field{sortinit}{A}
      \field{sortinithash}{2f401846e2029bad6b3ecc16d50031e2}
      \true{uniquetitle}
      \true{uniquework}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{booksubtitle}{Book Subtitle}
      \field{booktitle}{Book Title}
      \field{booktitleaddon}{Book Titleaddon}
      \field{title}{Title of Book bit}
      \field{year}{2010}
      \field{pages}{123\bibrangedash 126}
      \range{pages}{4}
      \verb{verbb}
      \verb String
      \endverb
    \endentry
|;

# Default inheritance supressed except for specified
my $cr8 = q|    \entry{cr8}{incollection}{}{}
      \name{author}{1}{}{%
        {{hash=3d449e56eb3ca1ae80dc99a18d689795}{%
           family={Smith},
           familyi={S\bibinitperiod},
           given={Firstname},
           giveni={F\bibinitperiod}}}%
      }
      \strng{namehash}{3d449e56eb3ca1ae80dc99a18d689795}
      \strng{fullhash}{3d449e56eb3ca1ae80dc99a18d689795}
      \strng{fullhashraw}{3d449e56eb3ca1ae80dc99a18d689795}
      \strng{bibnamehash}{3d449e56eb3ca1ae80dc99a18d689795}
      \strng{authorbibnamehash}{3d449e56eb3ca1ae80dc99a18d689795}
      \strng{authornamehash}{3d449e56eb3ca1ae80dc99a18d689795}
      \strng{authorfullhash}{3d449e56eb3ca1ae80dc99a18d689795}
      \strng{authorfullhashraw}{3d449e56eb3ca1ae80dc99a18d689795}
      \field{extraname}{4}
      \field{sortinit}{S}
      \field{sortinithash}{b164b07b29984b41daf1e85279fbc5ab}
      \true{singletitle}
      \true{uniquetitle}
      \true{uniquework}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{booktitle}{Book Title}
      \field{title}{Title of Collection bit}
      \field{year}{2010}
      \field{pages}{1\bibrangedash 12}
      \range{pages}{12}
    \endentry
|;

# xref field is included as the parent is included by being crossrefed >= mincrossrefs times
my $xr1 = q|    \entry{xr1}{inbook}{}{}
      \name{author}{1}{}{%
        {{hash=e0ecc4fc668ee499d1afba44e1ac064d}{%
           family={Zentrum},
           familyi={Z\bibinitperiod},
           given={Zoe},
           giveni={Z\bibinitperiod}}}%
      }
      \strng{namehash}{e0ecc4fc668ee499d1afba44e1ac064d}
      \strng{fullhash}{e0ecc4fc668ee499d1afba44e1ac064d}
      \strng{fullhashraw}{e0ecc4fc668ee499d1afba44e1ac064d}
      \strng{bibnamehash}{e0ecc4fc668ee499d1afba44e1ac064d}
      \strng{authorbibnamehash}{e0ecc4fc668ee499d1afba44e1ac064d}
      \strng{authornamehash}{e0ecc4fc668ee499d1afba44e1ac064d}
      \strng{authorfullhash}{e0ecc4fc668ee499d1afba44e1ac064d}
      \strng{authorfullhashraw}{e0ecc4fc668ee499d1afba44e1ac064d}
      \field{sortinit}{Z}
      \field{sortinithash}{96892c0b0a36bb8557c40c49813d48b3}
      \true{singletitle}
      \true{uniquetitle}
      \true{uniquework}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{origyear}{1921}
      \field{title}{Moods Mildly Modified}
      \strng{xref}{xrm}
      \field{origdateera}{ce}
    \endentry
|;

# xref field is included as the parent is included by being crossrefed >= mincrossrefs times
my $xr2 = q|    \entry{xr2}{inbook}{}{}
      \name{author}{1}{}{%
        {{hash=6afa09374ecfd6b394ce714d2d9709c7}{%
           family={Instant},
           familyi={I\bibinitperiod},
           given={Ian},
           giveni={I\bibinitperiod}}}%
      }
      \strng{namehash}{6afa09374ecfd6b394ce714d2d9709c7}
      \strng{fullhash}{6afa09374ecfd6b394ce714d2d9709c7}
      \strng{fullhashraw}{6afa09374ecfd6b394ce714d2d9709c7}
      \strng{bibnamehash}{6afa09374ecfd6b394ce714d2d9709c7}
      \strng{authorbibnamehash}{6afa09374ecfd6b394ce714d2d9709c7}
      \strng{authornamehash}{6afa09374ecfd6b394ce714d2d9709c7}
      \strng{authorfullhash}{6afa09374ecfd6b394ce714d2d9709c7}
      \strng{authorfullhashraw}{6afa09374ecfd6b394ce714d2d9709c7}
      \field{sortinit}{I}
      \field{sortinithash}{8d291c51ee89b6cd86bf5379f0b151d8}
      \true{singletitle}
      \true{uniquetitle}
      \true{uniquework}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{origyear}{1926}
      \field{title}{Migraines Multiplying Madly}
      \strng{xref}{xrm}
      \field{origdateera}{ce}
    \endentry
|;

# This is included as it is xref'd >= minxrefs times Notice lack of singletitle,
# labelname and labelname hashes because the only name is EDITOR and
# useeditor is false
my $xrm = q|    \entry{xrm}{book}{}{}
      \name{editor}{1}{}{%
        {{hash=809950f9b59ae207092b909a19dcb27b}{%
           family={Prendergast},
           familyi={P\bibinitperiod},
           given={Peter},
           giveni={P\bibinitperiod}}}%
      }
      \list{publisher}{1}{%
        {Mainstream}%
      }
      \strng{editorbibnamehash}{809950f9b59ae207092b909a19dcb27b}
      \strng{editornamehash}{809950f9b59ae207092b909a19dcb27b}
      \strng{editorfullhash}{809950f9b59ae207092b909a19dcb27b}
      \strng{editorfullhashraw}{809950f9b59ae207092b909a19dcb27b}
      \field{sortinit}{C}
      \field{sortinithash}{4d103a86280481745c9c897c925753c0}
      \true{xrefsource}
      \true{uniquetitle}
      \field{labeltitlesource}{title}
      \field{title}{Calligraphy, Calisthenics, Culture}
      \field{year}{1970}
    \endentry
|;

# xref field is included as the parent is cited
my $xr3 = q|    \entry{xr3}{inbook}{}{}
      \name{author}{1}{}{%
        {{hash=9788055665b9bb4b37c776c3f6b74f16}{%
           family={Normal},
           familyi={N\bibinitperiod},
           given={Norman},
           giveni={N\bibinitperiod}}}%
      }
      \strng{namehash}{9788055665b9bb4b37c776c3f6b74f16}
      \strng{fullhash}{9788055665b9bb4b37c776c3f6b74f16}
      \strng{fullhashraw}{9788055665b9bb4b37c776c3f6b74f16}
      \strng{bibnamehash}{9788055665b9bb4b37c776c3f6b74f16}
      \strng{authorbibnamehash}{9788055665b9bb4b37c776c3f6b74f16}
      \strng{authornamehash}{9788055665b9bb4b37c776c3f6b74f16}
      \strng{authorfullhash}{9788055665b9bb4b37c776c3f6b74f16}
      \strng{authorfullhashraw}{9788055665b9bb4b37c776c3f6b74f16}
      \field{sortinit}{N}
      \field{sortinithash}{22369a73d5f88983a108b63f07f37084}
      \true{singletitle}
      \true{uniquetitle}
      \true{uniquework}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{origyear}{1923}
      \field{title}{Russian Regalia Revisited}
      \strng{xref}{xrt}
      \field{origdateera}{ce}
    \endentry
|;

# cited as normal
# Note no singletitle as useeditor is false
my $xrt = q|    \entry{xrt}{book}{}{}
      \name{editor}{1}{}{%
        {{hash=bf7d6b02f3e073913e5bfe5059508dd5}{%
           family={Lunders},
           familyi={L\bibinitperiod},
           given={Lucy},
           giveni={L\bibinitperiod}}}%
      }
      \list{publisher}{1}{%
        {Middling}%
      }
      \strng{editorbibnamehash}{bf7d6b02f3e073913e5bfe5059508dd5}
      \strng{editornamehash}{bf7d6b02f3e073913e5bfe5059508dd5}
      \strng{editorfullhash}{bf7d6b02f3e073913e5bfe5059508dd5}
      \strng{editorfullhashraw}{bf7d6b02f3e073913e5bfe5059508dd5}
      \field{sortinit}{K}
      \field{sortinithash}{c02bf6bff1c488450c352b40f5d853ab}
      \true{uniquetitle}
      \field{labeltitlesource}{title}
      \field{title}{Kings, Cork and Calculation}
      \field{year}{1977}
    \endentry
|;


# No crossref field as parent is not cited (mincrossrefs < 2)
my $xr4 = q|    \entry{xr4}{inbook}{}{}
      \name{author}{1}{}{%
        {{hash=7804ffef086c0c4686c235807f5cb502}{%
           family={Mistrel},
           familyi={M\bibinitperiod},
           given={Megan},
           giveni={M\bibinitperiod}}}%
      }
      \strng{namehash}{7804ffef086c0c4686c235807f5cb502}
      \strng{fullhash}{7804ffef086c0c4686c235807f5cb502}
      \strng{fullhashraw}{7804ffef086c0c4686c235807f5cb502}
      \strng{bibnamehash}{7804ffef086c0c4686c235807f5cb502}
      \strng{authorbibnamehash}{7804ffef086c0c4686c235807f5cb502}
      \strng{authornamehash}{7804ffef086c0c4686c235807f5cb502}
      \strng{authorfullhash}{7804ffef086c0c4686c235807f5cb502}
      \strng{authorfullhashraw}{7804ffef086c0c4686c235807f5cb502}
      \field{extraname}{1}
      \field{sortinit}{M}
      \field{sortinithash}{4625c616857f13d17ce56f7d4f97d451}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{origyear}{1933}
      \field{title}{Lumbering Lunatics}
      \strng{xref}{xrn}
      \field{origdateera}{ce}
    \endentry
|;

# Missing keys in xref/crossref should be deleted during datasource parse
# So these two should have no xref/crossref data in them
my $mxr = q|    \entry{mxr}{inbook}{}{}
      \name{author}{1}{}{%
        {{hash=7804ffef086c0c4686c235807f5cb502}{%
           family={Mistrel},
           familyi={M\bibinitperiod},
           given={Megan},
           giveni={M\bibinitperiod}}}%
      }
      \strng{namehash}{7804ffef086c0c4686c235807f5cb502}
      \strng{fullhash}{7804ffef086c0c4686c235807f5cb502}
      \strng{fullhashraw}{7804ffef086c0c4686c235807f5cb502}
      \strng{bibnamehash}{7804ffef086c0c4686c235807f5cb502}
      \strng{authorbibnamehash}{7804ffef086c0c4686c235807f5cb502}
      \strng{authornamehash}{7804ffef086c0c4686c235807f5cb502}
      \strng{authorfullhash}{7804ffef086c0c4686c235807f5cb502}
      \strng{authorfullhashraw}{7804ffef086c0c4686c235807f5cb502}
      \field{extraname}{2}
      \field{sortinit}{M}
      \field{sortinithash}{4625c616857f13d17ce56f7d4f97d451}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{origyear}{1933}
      \field{title}{Lumbering Lunatics}
      \field{origdateera}{ce}
    \endentry
|;

my $mcr = q|    \entry{mcr}{inbook}{}{}
      \name{author}{1}{}{%
        {{hash=7804ffef086c0c4686c235807f5cb502}{%
           family={Mistrel},
           familyi={M\bibinitperiod},
           given={Megan},
           giveni={M\bibinitperiod}}}%
      }
      \strng{namehash}{7804ffef086c0c4686c235807f5cb502}
      \strng{fullhash}{7804ffef086c0c4686c235807f5cb502}
      \strng{fullhashraw}{7804ffef086c0c4686c235807f5cb502}
      \strng{bibnamehash}{7804ffef086c0c4686c235807f5cb502}
      \strng{authorbibnamehash}{7804ffef086c0c4686c235807f5cb502}
      \strng{authornamehash}{7804ffef086c0c4686c235807f5cb502}
      \strng{authorfullhash}{7804ffef086c0c4686c235807f5cb502}
      \strng{authorfullhashraw}{7804ffef086c0c4686c235807f5cb502}
      \field{extraname}{3}
      \field{sortinit}{M}
      \field{sortinithash}{4625c616857f13d17ce56f7d4f97d451}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{origyear}{1933}
      \field{title}{Lumbering Lunatics}
      \field{origdateera}{ce}
    \endentry
|;

my $ccr1 = q|    \entry{ccr2}{book}{}{}
      \name{author}{1}{}{%
        {{hash=6268941b408d3263bddb208a54899ea9}{%
           family={Various},
           familyi={V\bibinitperiod},
           given={Vince},
           giveni={V\bibinitperiod}}}%
      }
      \name{editor}{1}{}{%
        {{hash=cfee758a1c82df2e26af1985e061bb0a}{%
           family={Editor},
           familyi={E\bibinitperiod},
           given={Edward},
           giveni={E\bibinitperiod}}}%
      }
      \strng{namehash}{6268941b408d3263bddb208a54899ea9}
      \strng{fullhash}{6268941b408d3263bddb208a54899ea9}
      \strng{fullhashraw}{6268941b408d3263bddb208a54899ea9}
      \strng{bibnamehash}{6268941b408d3263bddb208a54899ea9}
      \strng{authorbibnamehash}{6268941b408d3263bddb208a54899ea9}
      \strng{authornamehash}{6268941b408d3263bddb208a54899ea9}
      \strng{authorfullhash}{6268941b408d3263bddb208a54899ea9}
      \strng{authorfullhashraw}{6268941b408d3263bddb208a54899ea9}
      \strng{editorbibnamehash}{cfee758a1c82df2e26af1985e061bb0a}
      \strng{editornamehash}{cfee758a1c82df2e26af1985e061bb0a}
      \strng{editorfullhash}{cfee758a1c82df2e26af1985e061bb0a}
      \strng{editorfullhashraw}{cfee758a1c82df2e26af1985e061bb0a}
      \field{extraname}{1}
      \field{sortinit}{V}
      \field{sortinithash}{afb52128e5b4dc4b843768c0113d673b}
      \true{uniquetitle}
      \true{uniquework}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \strng{crossref}{ccr1}
      \field{title}{Misc etc.}
      \field{year}{1923}
      \field{dateera}{ce}
    \endentry
|;

my $ccr2 = q|    \entry{ccr3}{inbook}{}{}
      \name{bookauthor}{1}{}{%
        {{hash=6268941b408d3263bddb208a54899ea9}{%
           family={Various},
           familyi={V\bibinitperiod},
           given={Vince},
           giveni={V\bibinitperiod}}}%
      }
      \name{editor}{1}{}{%
        {{hash=cfee758a1c82df2e26af1985e061bb0a}{%
           family={Editor},
           familyi={E\bibinitperiod},
           given={Edward},
           giveni={E\bibinitperiod}}}%
      }
      \strng{bookauthorbibnamehash}{6268941b408d3263bddb208a54899ea9}
      \strng{bookauthornamehash}{6268941b408d3263bddb208a54899ea9}
      \strng{bookauthorfullhash}{6268941b408d3263bddb208a54899ea9}
      \strng{bookauthorfullhashraw}{6268941b408d3263bddb208a54899ea9}
      \strng{editorbibnamehash}{cfee758a1c82df2e26af1985e061bb0a}
      \strng{editornamehash}{cfee758a1c82df2e26af1985e061bb0a}
      \strng{editorfullhash}{cfee758a1c82df2e26af1985e061bb0a}
      \strng{editorfullhashraw}{cfee758a1c82df2e26af1985e061bb0a}
      \field{sortinit}{P}
      \field{sortinithash}{ff3bcf24f47321b42cb156c2cc8a8422}
      \true{uniquetitle}
      \field{labeltitlesource}{title}
      \field{booktitle}{Misc etc.}
      \strng{crossref}{ccr2}
      \field{title}{Perhaps, Perchance, Possibilities?}
      \field{year}{1911}
      \field{dateera}{ce}
    \endentry
|;

# This is strange in what it gets from where but it shows information being inherited from two
# sources
my $ccr3 = q|    \entry{ccr4}{inbook}{}{}
      \name{bookauthor}{1}{}{%
        {{hash=6268941b408d3263bddb208a54899ea9}{Various}{V\bibinitperiod}{Vince}{V\bibinitperiod}{}{}{}{}}%
      }
      \name{editor}{1}{}{%
        {{hash=cfee758a1c82df2e26af1985e061bb0a}{Editor}{E\bibinitperiod}{Edward}{E\bibinitperiod}{}{}{}{}}%
      }
      \field{sortinit}{V}
      \field{sortinithash}{4125bb4c3a0eb3eaee3ea6da32eb70c8}
      \field{labeltitlesource}{title}
      \field{booktitle}{Misc etc.}
      \field{title}{Stuff Concerning Varia}
      \field{year}{1911}
      \field{dateera}{ce}
    \endentry
|;

my $s1 = q|    \entry{s1}{inbook}{}{}
      \field{sortinit}{S}
      \field{sortinithash}{b164b07b29984b41daf1e85279fbc5ab}
      \true{uniquetitle}
      \field{labeltitlesource}{title}
      \strng{crossref}{s2}
      \field{title}{Subtitle}
    \endentry
|;

my $xc2 = q|    \entry{xc2}{inbook}{}{}
      \name{author}{1}{}{%
        {{hash=1a0f7d518cccdad859a74412ef956474}{%
           family={Crust},
           familyi={C\\bibinitperiod},
           given={Xavier},
           giveni={X\\bibinitperiod}}}%
      }
      \name{bookauthor}{1}{}{%
        {{hash=1a0f7d518cccdad859a74412ef956474}{%
           family={Crust},
           familyi={C\\bibinitperiod},
           given={Xavier},
           giveni={X\\bibinitperiod}}}%
      }
      \strng{namehash}{1a0f7d518cccdad859a74412ef956474}
      \strng{fullhash}{1a0f7d518cccdad859a74412ef956474}
      \strng{fullhashraw}{1a0f7d518cccdad859a74412ef956474}
      \strng{bibnamehash}{1a0f7d518cccdad859a74412ef956474}
      \strng{authorbibnamehash}{1a0f7d518cccdad859a74412ef956474}
      \strng{authornamehash}{1a0f7d518cccdad859a74412ef956474}
      \strng{authorfullhash}{1a0f7d518cccdad859a74412ef956474}
      \strng{authorfullhashraw}{1a0f7d518cccdad859a74412ef956474}
      \strng{bookauthorbibnamehash}{1a0f7d518cccdad859a74412ef956474}
      \strng{bookauthornamehash}{1a0f7d518cccdad859a74412ef956474}
      \strng{bookauthorfullhash}{1a0f7d518cccdad859a74412ef956474}
      \strng{bookauthorfullhashraw}{1a0f7d518cccdad859a74412ef956474}
      \field{extraname}{2}
      \field{sortinit}{C}
      \field{sortinithash}{4d103a86280481745c9c897c925753c0}
      \true{xrefsource}
      \field{labelnamesource}{author}
      \field{booktitle}{Title}
    \endentry
|;

my $b1 = q|    \entry{b1}{inbook}{}{}
      \field{sortinit}{2}
      \field{sortinithash}{8b555b3791beccb63322c22f3320aa9a}
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
      \name{author}{1}{}{%
        {{hash=556c8dba145b472e6a8598d506f7cbe2}{%
           family={Smith},
           familyi={S\\bibinitperiod},
           given={Alan},
           giveni={A\\bibinitperiod}}}%
      }
      \strng{namehash}{556c8dba145b472e6a8598d506f7cbe2}
      \strng{fullhash}{556c8dba145b472e6a8598d506f7cbe2}
      \strng{fullhashraw}{556c8dba145b472e6a8598d506f7cbe2}
      \strng{bibnamehash}{556c8dba145b472e6a8598d506f7cbe2}
      \strng{authorbibnamehash}{556c8dba145b472e6a8598d506f7cbe2}
      \strng{authornamehash}{556c8dba145b472e6a8598d506f7cbe2}
      \strng{authorfullhash}{556c8dba145b472e6a8598d506f7cbe2}
      \strng{authorfullhashraw}{556c8dba145b472e6a8598d506f7cbe2}
      \field{extraname}{3}
      \field{sortinit}{S}
      \field{sortinithash}{b164b07b29984b41daf1e85279fbc5ab}
      \true{crossrefsource}
      \true{singletitle}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{Title1}
    \endentry
|;

my $sup2 = q|    \entry{sup2}{book}{}{}
      \name{author}{1}{}{%
        {{hash=556c8dba145b472e6a8598d506f7cbe2}{%
           family={Smith},
           familyi={S\\bibinitperiod},
           given={Alan},
           giveni={A\\bibinitperiod}}}%
      }
      \strng{namehash}{556c8dba145b472e6a8598d506f7cbe2}
      \strng{fullhash}{556c8dba145b472e6a8598d506f7cbe2}
      \strng{fullhashraw}{556c8dba145b472e6a8598d506f7cbe2}
      \strng{bibnamehash}{556c8dba145b472e6a8598d506f7cbe2}
      \strng{authorbibnamehash}{556c8dba145b472e6a8598d506f7cbe2}
      \strng{authornamehash}{556c8dba145b472e6a8598d506f7cbe2}
      \strng{authorfullhash}{556c8dba145b472e6a8598d506f7cbe2}
      \strng{authorfullhashraw}{556c8dba145b472e6a8598d506f7cbe2}
      \field{extraname}{1}
      \field{sortinit}{S}
      \field{sortinithash}{b164b07b29984b41daf1e85279fbc5ab}
      \true{singletitle}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \strng{crossref}{sup1}
      \field{note}{Book sup2}
      \field{title}{Title1}
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
