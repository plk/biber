# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 55;

use Biber;
use Biber::Utils;
use Biber::Output::bbl;
use Log::Log4perl;
use Unicode::Normalize;
chdir("t/tdata");

# Set up Biber object
my $biber = Biber->new( configfile => 'biber-test.conf');
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

$biber->parse_ctrlfile("general2.bcf");
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('sortlocale', 'C');
Biber::Config->setoption('fastsort', 1);
Biber::Config->setblxoption('uniquelist', 1);
Biber::Config->setblxoption('maxcitenames', 3);
Biber::Config->setblxoption('mincitenames', 1);
Biber::Config->setblxoption('maxalphanames', 3);
Biber::Config->setblxoption('minalphanames', 1);
Biber::Config->setblxoption('maxbibnames', 10);
Biber::Config->setblxoption('minbibnames', 7);

# THERE IS A CONFIG FILE BEING READ TO TEST USER MAPS TOO!

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $main = $biber->sortlists->get_list(0, 'entry', 'nty');
my @keys = sort $section->get_citekeys;
my @citedkeys = sort qw{ alias1 alias2 alias5 anon1 anon2 murray t1 kant:ku kant:kpv t2 shore u1 u2 us1 list1 };

# entry "loh" is missing as the biber.conf map removes it with map_entry_null
my @allkeys = sort map {lc()} qw{ anon1 anon2 stdmodel aristotle:poetics vazques-de-parga t1
gonzalez averroes/bland laufenberg westfahl:frontier knuth:ct:a kastenholz
averroes/hannes iliad luzzatto malinowski sorace knuth:ct:d britannica
nietzsche:historie stdmodel:weinberg knuth:ct:b baez/article knuth:ct:e itzhaki
jaffe padhye cicero stdmodel:salam reese averroes/hercz murray shore
aristotle:physics massa aristotle:anima gillies set kowalik gaonkar springer
geer hammond wormanx westfahl:space worman set:herrmann augustine gerhardt
piccato hasan hyman stdmodel:glashow stdmodel:ps_sc kant:kpv companion almendro
sigfridsson ctan baez/online aristotle:rhetoric pimentel00 pines knuth:ct:c moraux cms
angenendt angenendtsk markey cotton vangennepx kant:ku nussbaum nietzsche:ksa1
vangennep knuth:ct angenendtsa spiegelberg bertram brandt set:aksin chiu nietzsche:ksa
set:yoon maron coleridge tvonb t2 u1 u2 i1 i2 tmn1 tmn2 tmn3 tmn4 lne1 alias1 alias2 alias5 url1 url2 ol1 pages1 pages2 pages3 pages4 pages5 pages6 pages7 us1 labelstest list1 } ;

my $u1 = q|    \entry{u1}{misc}{}
      \name{labelname}{4}{uniquelist=4}{%
        {{uniquename=0,hash=e1faffb3e614e6c2fba74296962386b7}{AAA}{A\bibinitperiod}{}{}{}{}{}{}}%
        {{uniquename=0,hash=2bb225f0ba9a58930757a868ed57d9a3}{BBB}{B\bibinitperiod}{}{}{}{}{}{}}%
        {{uniquename=0,hash=defb99e69a9f1f6e06f15006b1f166ae}{CCC}{C\bibinitperiod}{}{}{}{}{}{}}%
        {{uniquename=0,hash=45054f47ac3305a2a33e9bcceadff712}{DDD}{D\bibinitperiod}{}{}{}{}{}{}}%
      }
      \name{author}{4}{uniquelist=4}{%
        {{uniquename=0,hash=e1faffb3e614e6c2fba74296962386b7}{AAA}{A\bibinitperiod}{}{}{}{}{}{}}%
        {{uniquename=0,hash=2bb225f0ba9a58930757a868ed57d9a3}{BBB}{B\bibinitperiod}{}{}{}{}{}{}}%
        {{uniquename=0,hash=defb99e69a9f1f6e06f15006b1f166ae}{CCC}{C\bibinitperiod}{}{}{}{}{}{}}%
        {{uniquename=0,hash=45054f47ac3305a2a33e9bcceadff712}{DDD}{D\bibinitperiod}{}{}{}{}{}{}}%
      }
      \strng{namehash}{b78abdc838d79b6576f2ed0021642766}
      \strng{fullhash}{b78abdc838d79b6576f2ed0021642766}
      \field{labelalpha}{AAA\textbf{+}00}
      \field{sortinit}{A}
      \field{labeltitle}{A title}
      \true{singletitle}
      \field{title}{A title}
      \field{year}{2000}
    \endentry
|;

is( $out->get_output_entry('u1', $main), $u1, 'uniquelist 1' ) ;

is_deeply( \@keys, \@citedkeys, 'citekeys 1') ;
is_deeply( [ $biber->sortlists->get_list(0, 'shorthand', 'shorthand')->get_keys ], [ 'kant:kpv', 'kant:ku' ], 'shorthands' ) ;

# reset some options and re-generate information

# Have to do a citekey deletion as we are not re-reading the .bcf which would do it for us
# Otherwise, we have citekeys and allkeys which confuses fetch_data()
$section->del_citekeys;
$section->set_allkeys(1);
$section->bibentries->del_entries;
$section->del_everykeys;
Biber::Input::file::bibtex->init_cache;
$biber->prepare;

$section = $biber->sections->get_section(0);
my $bibentries = $section->bibentries;

$out = $biber->get_output_obj;

@keys = sort map {lc()} $section->get_citekeys;

is_deeply( \@keys, \@allkeys, 'citekeys 2') ;

my $murray1 = q|    \entry{murray}{article}{}
      \name{labelname}{14}{}{%
        {{uniquename=0,hash=f1bafaf959660d1c3ca82d486ce5a651}{Hostetler}{H\bibinitperiod}{Michael\bibnamedelima J.}{M\bibinitperiod\bibinitdelim J\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=de9f774c929dc661b4180b07f5eb62f3}{Wingate}{W\bibinitperiod}{Julia\bibnamedelima E.}{J\bibinitperiod\bibinitdelim E\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=76100791c221471771c6bf1dbbc0975d}{Zhong}{Z\bibinitperiod}{Chuan-Jian}{C\bibinithyphendelim J\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=34c410f87490dd022093780c69640413}{Harris}{H\bibinitperiod}{Jay\bibnamedelima E.}{J\bibinitperiod\bibinitdelim E\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=a803710eddd16b95e91f420c0081985c}{Vachet}{V\bibinitperiod}{Richard\bibnamedelima W.}{R\bibinitperiod\bibinitdelim W\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=38d1db37321ac524d14a116e74123685}{Clark}{C\bibinitperiod}{Michael\bibnamedelima R.}{M\bibinitperiod\bibinitdelim R\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=969c673c8b05314f89a822ecfbead6af}{Londono}{L\bibinitperiod}{J.\bibnamedelimi David}{J\bibinitperiod\bibinitdelim D\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=fc6cda30bdeb421b5b57ef2d1ce6f92b}{Green}{G\bibinitperiod}{Stephen\bibnamedelima J.}{S\bibinitperiod\bibinitdelim J\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=69dcde2965d0ce8a53fae463355f36f5}{Stokes}{S\bibinitperiod}{Jennifer\bibnamedelima J.}{J\bibinitperiod\bibinitdelim J\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=8cfed260a429843a4846ad8d83f9a09f}{Wignall}{W\bibinitperiod}{George\bibnamedelima D.}{G\bibinitperiod\bibinitdelim D\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=71a4aee3f5124c9c94825634735417be}{Glish}{G\bibinitperiod}{Gary\bibnamedelima L.}{G\bibinitperiod\bibinitdelim L\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=9406f7f2b15056febb90692ae05e8620}{Porter}{P\bibinitperiod}{Marc\bibnamedelima D.}{M\bibinitperiod\bibinitdelim D\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=f8d80918767d0ce7f535453dc016c327}{Evans}{E\bibinitperiod}{Neal\bibnamedelima D.}{N\bibinitperiod\bibinitdelim D\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=98688e58f25c10d275f9d15d31ba3396}{Murray}{M\bibinitperiod}{Royce\bibnamedelima W.}{R\bibinitperiod\bibinitdelim W\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{14}{}{%
        {{uniquename=0,hash=f1bafaf959660d1c3ca82d486ce5a651}{Hostetler}{H\bibinitperiod}{Michael\bibnamedelima J.}{M\bibinitperiod\bibinitdelim J\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=de9f774c929dc661b4180b07f5eb62f3}{Wingate}{W\bibinitperiod}{Julia\bibnamedelima E.}{J\bibinitperiod\bibinitdelim E\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=76100791c221471771c6bf1dbbc0975d}{Zhong}{Z\bibinitperiod}{Chuan-Jian}{C\bibinithyphendelim J\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=34c410f87490dd022093780c69640413}{Harris}{H\bibinitperiod}{Jay\bibnamedelima E.}{J\bibinitperiod\bibinitdelim E\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=a803710eddd16b95e91f420c0081985c}{Vachet}{V\bibinitperiod}{Richard\bibnamedelima W.}{R\bibinitperiod\bibinitdelim W\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=38d1db37321ac524d14a116e74123685}{Clark}{C\bibinitperiod}{Michael\bibnamedelima R.}{M\bibinitperiod\bibinitdelim R\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=969c673c8b05314f89a822ecfbead6af}{Londono}{L\bibinitperiod}{J.\bibnamedelimi David}{J\bibinitperiod\bibinitdelim D\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=fc6cda30bdeb421b5b57ef2d1ce6f92b}{Green}{G\bibinitperiod}{Stephen\bibnamedelima J.}{S\bibinitperiod\bibinitdelim J\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=69dcde2965d0ce8a53fae463355f36f5}{Stokes}{S\bibinitperiod}{Jennifer\bibnamedelima J.}{J\bibinitperiod\bibinitdelim J\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=8cfed260a429843a4846ad8d83f9a09f}{Wignall}{W\bibinitperiod}{George\bibnamedelima D.}{G\bibinitperiod\bibinitdelim D\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=71a4aee3f5124c9c94825634735417be}{Glish}{G\bibinitperiod}{Gary\bibnamedelima L.}{G\bibinitperiod\bibinitdelim L\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=9406f7f2b15056febb90692ae05e8620}{Porter}{P\bibinitperiod}{Marc\bibnamedelima D.}{M\bibinitperiod\bibinitdelim D\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=f8d80918767d0ce7f535453dc016c327}{Evans}{E\bibinitperiod}{Neal\bibnamedelima D.}{N\bibinitperiod\bibinitdelim D\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=98688e58f25c10d275f9d15d31ba3396}{Murray}{M\bibinitperiod}{Royce\bibnamedelima W.}{R\bibinitperiod\bibinitdelim W\bibinitperiod}{}{}{}{}}%
      }
      \strng{namehash}{7ba00ed438c44a2270c14ba95a7fc011}
      \strng{fullhash}{61836f4684b2615842b68c26479f6ec2}
      \field{labelalpha}{Hos\textbf{+}98}
      \field{sortinit}{H}
      \field{labeltitle}{Alkanethiolate gold cluster molecules}
      \true{singletitle}
      \field{annotation}{An \texttt{article} entry with \arabic{author} authors. By default, long author and editor lists are automatically truncated. This is configurable}
      \field{hyphenation}{american}
      \field{indextitle}{Alkanethiolate gold cluster molecules}
      \field{journaltitle}{Langmuir}
      \field{number}{1}
      \field{shorttitle}{Alkanethiolate gold cluster molecules}
      \field{subtitle}{Core and monolayer properties as a function of core size}
      \field{title}{Alkanethiolate gold cluster molecules with core diameters from 1.5 to 5.2~nm}
      \field{volume}{14}
      \field{year}{1998}
      \field{pages}{17\bibrangedash 30}
      \keyw{keyw1,keyw2}
    \endentry
|;

my $murray2 = q|    \entry{murray}{article}{}
      \name{labelname}{14}{}{%
        {{uniquename=0,hash=f1bafaf959660d1c3ca82d486ce5a651}{Hostetler}{H\bibinitperiod}{Michael\bibnamedelima J.}{M\bibinitperiod\bibinitdelim J\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=de9f774c929dc661b4180b07f5eb62f3}{Wingate}{W\bibinitperiod}{Julia\bibnamedelima E.}{J\bibinitperiod\bibinitdelim E\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=76100791c221471771c6bf1dbbc0975d}{Zhong}{Z\bibinitperiod}{Chuan-Jian}{C\bibinithyphendelim J\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=34c410f87490dd022093780c69640413}{Harris}{H\bibinitperiod}{Jay\bibnamedelima E.}{J\bibinitperiod\bibinitdelim E\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=a803710eddd16b95e91f420c0081985c}{Vachet}{V\bibinitperiod}{Richard\bibnamedelima W.}{R\bibinitperiod\bibinitdelim W\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=38d1db37321ac524d14a116e74123685}{Clark}{C\bibinitperiod}{Michael\bibnamedelima R.}{M\bibinitperiod\bibinitdelim R\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=969c673c8b05314f89a822ecfbead6af}{Londono}{L\bibinitperiod}{J.\bibnamedelimi David}{J\bibinitperiod\bibinitdelim D\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=fc6cda30bdeb421b5b57ef2d1ce6f92b}{Green}{G\bibinitperiod}{Stephen\bibnamedelima J.}{S\bibinitperiod\bibinitdelim J\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=69dcde2965d0ce8a53fae463355f36f5}{Stokes}{S\bibinitperiod}{Jennifer\bibnamedelima J.}{J\bibinitperiod\bibinitdelim J\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=8cfed260a429843a4846ad8d83f9a09f}{Wignall}{W\bibinitperiod}{George\bibnamedelima D.}{G\bibinitperiod\bibinitdelim D\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=71a4aee3f5124c9c94825634735417be}{Glish}{G\bibinitperiod}{Gary\bibnamedelima L.}{G\bibinitperiod\bibinitdelim L\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=9406f7f2b15056febb90692ae05e8620}{Porter}{P\bibinitperiod}{Marc\bibnamedelima D.}{M\bibinitperiod\bibinitdelim D\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=f8d80918767d0ce7f535453dc016c327}{Evans}{E\bibinitperiod}{Neal\bibnamedelima D.}{N\bibinitperiod\bibinitdelim D\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=98688e58f25c10d275f9d15d31ba3396}{Murray}{M\bibinitperiod}{Royce\bibnamedelima W.}{R\bibinitperiod\bibinitdelim W\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{14}{}{%
        {{uniquename=0,hash=f1bafaf959660d1c3ca82d486ce5a651}{Hostetler}{H\bibinitperiod}{Michael\bibnamedelima J.}{M\bibinitperiod\bibinitdelim J\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=de9f774c929dc661b4180b07f5eb62f3}{Wingate}{W\bibinitperiod}{Julia\bibnamedelima E.}{J\bibinitperiod\bibinitdelim E\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=76100791c221471771c6bf1dbbc0975d}{Zhong}{Z\bibinitperiod}{Chuan-Jian}{C\bibinithyphendelim J\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=34c410f87490dd022093780c69640413}{Harris}{H\bibinitperiod}{Jay\bibnamedelima E.}{J\bibinitperiod\bibinitdelim E\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=a803710eddd16b95e91f420c0081985c}{Vachet}{V\bibinitperiod}{Richard\bibnamedelima W.}{R\bibinitperiod\bibinitdelim W\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=38d1db37321ac524d14a116e74123685}{Clark}{C\bibinitperiod}{Michael\bibnamedelima R.}{M\bibinitperiod\bibinitdelim R\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=969c673c8b05314f89a822ecfbead6af}{Londono}{L\bibinitperiod}{J.\bibnamedelimi David}{J\bibinitperiod\bibinitdelim D\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=fc6cda30bdeb421b5b57ef2d1ce6f92b}{Green}{G\bibinitperiod}{Stephen\bibnamedelima J.}{S\bibinitperiod\bibinitdelim J\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=69dcde2965d0ce8a53fae463355f36f5}{Stokes}{S\bibinitperiod}{Jennifer\bibnamedelima J.}{J\bibinitperiod\bibinitdelim J\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=8cfed260a429843a4846ad8d83f9a09f}{Wignall}{W\bibinitperiod}{George\bibnamedelima D.}{G\bibinitperiod\bibinitdelim D\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=71a4aee3f5124c9c94825634735417be}{Glish}{G\bibinitperiod}{Gary\bibnamedelima L.}{G\bibinitperiod\bibinitdelim L\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=9406f7f2b15056febb90692ae05e8620}{Porter}{P\bibinitperiod}{Marc\bibnamedelima D.}{M\bibinitperiod\bibinitdelim D\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=f8d80918767d0ce7f535453dc016c327}{Evans}{E\bibinitperiod}{Neal\bibnamedelima D.}{N\bibinitperiod\bibinitdelim D\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=98688e58f25c10d275f9d15d31ba3396}{Murray}{M\bibinitperiod}{Royce\bibnamedelima W.}{R\bibinitperiod\bibinitdelim W\bibinitperiod}{}{}{}{}}%
      }
      \strng{namehash}{7ba00ed438c44a2270c14ba95a7fc011}
      \strng{fullhash}{61836f4684b2615842b68c26479f6ec2}
      \field{labelalpha}{Hos98}
      \field{sortinit}{H}
      \field{labeltitle}{Alkanethiolate gold cluster molecules}
      \true{singletitle}
      \field{annotation}{An \texttt{article} entry with \arabic{author} authors. By default, long author and editor lists are automatically truncated. This is configurable}
      \field{hyphenation}{american}
      \field{indextitle}{Alkanethiolate gold cluster molecules}
      \field{journaltitle}{Langmuir}
      \field{number}{1}
      \field{shorttitle}{Alkanethiolate gold cluster molecules}
      \field{subtitle}{Core and monolayer properties as a function of core size}
      \field{title}{Alkanethiolate gold cluster molecules with core diameters from 1.5 to 5.2~nm}
      \field{volume}{14}
      \field{year}{1998}
      \field{pages}{17\bibrangedash 30}
      \keyw{keyw1,keyw2}
    \endentry
|;

# This example wouldn't compile - it's just to test escaping
my $t1 = q+    \entry{t1}{misc}{}
      \name{labelname}{1}{}{%
        {{uniquename=0,hash=858fcf9483ec29b7707a7dda2dde7a6f}{Brown}{B\bibinitperiod}{Bill}{B\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{uniquename=0,hash=858fcf9483ec29b7707a7dda2dde7a6f}{Brown}{B\bibinitperiod}{Bill}{B\bibinitperiod}{}{}{}{}}%
      }
      \strng{namehash}{858fcf9483ec29b7707a7dda2dde7a6f}
      \strng{fullhash}{858fcf9483ec29b7707a7dda2dde7a6f}
      \field{labelalpha}{Bro92}
      \field{sortinit}{B}
      \field{labeltitle}{10\% of [100] and 90% of $Normal_2$ | \& # things {$^{3}$}}
      \field{title}{10\% of [100] and 90% of $Normal_2$ | \& # things {$^{3}$}}
      \field{year}{1992}
      \field{pages}{100\bibrangedash}
      \keyw{primary,something,somethingelse}
    \endentry
+;

my $t2 = q|    \entry{t2}{misc}{}
      \name{labelname}{1}{}{%
        {{uniquename=0,hash=858fcf9483ec29b7707a7dda2dde7a6f}{Brown}{B\bibinitperiod}{Bill}{B\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{uniquename=0,hash=858fcf9483ec29b7707a7dda2dde7a6f}{Brown}{B\bibinitperiod}{Bill}{B\bibinitperiod}{}{}{}{}}%
      }
      \strng{namehash}{858fcf9483ec29b7707a7dda2dde7a6f}
      \strng{fullhash}{858fcf9483ec29b7707a7dda2dde7a6f}
      \field{labelalpha}{Bro94}
      \field{sortinit}{B}
      \field{labeltitle}{Signs of W$\frac{o}{a}$nder}
      \field{title}{Signs of W$\frac{o}{a}$nder}
      \field{year}{1994}
      \field{pages}{100\bibrangedash 108}
    \endentry
|;

my $anon1 = q|    \entry{anon1}{unpublished}{}
      \name{labelname}{1}{}{%
        {{uniquename=0,hash=9873a6cc65c553faa2b21aaad626fe4b}{XAnony}{X\bibinitperiod}{}{}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{hash=a66f357fe2fd356fe49959173522a651}{AnonymousX}{A\bibinitperiod}{}{}{}{}{}{}}%
      }
      \name{shortauthor}{1}{}{%
        {{uniquename=0,hash=9873a6cc65c553faa2b21aaad626fe4b}{XAnony}{X\bibinitperiod}{}{}{}{}{}{}}%
      }
      \strng{namehash}{9873a6cc65c553faa2b21aaad626fe4b}
      \strng{fullhash}{a66f357fe2fd356fe49959173522a651}
      \field{labelalpha}{XAn35}
      \field{sortinit}{A}
      \field{labeltitle}{Shorttitle}
      \true{singletitle}
      \field{hyphenation}{USenglish}
      \field{note}{anon1}
      \field{shorttitle}{Shorttitle}
      \field{title}{Title1}
      \field{year}{1835}
      \field{pages}{111\bibrangedash 118}
      \keyw{arc}
    \endentry
|;

my $anon2 = q|    \entry{anon2}{unpublished}{}
      \name{labelname}{1}{}{%
        {{uniquename=0,hash=f64c29e89ea49402b997956610b58ef6}{YAnony}{Y\bibinitperiod}{}{}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{hash=a0bccee4041bc840e14c06e5ba7f083c}{AnonymousY}{A\bibinitperiod}{}{}{}{}{}{}}%
      }
      \name{shortauthor}{1}{}{%
        {{uniquename=0,hash=f64c29e89ea49402b997956610b58ef6}{YAnony}{Y\bibinitperiod}{}{}{}{}{}{}}%
      }
      \strng{namehash}{f64c29e89ea49402b997956610b58ef6}
      \strng{fullhash}{a0bccee4041bc840e14c06e5ba7f083c}
      \field{labelalpha}{YAn39}
      \field{sortinit}{A}
      \field{labeltitle}{Shorttitle}
      \true{singletitle}
      \field{hyphenation}{USenglish}
      \field{note}{anon2}
      \field{shorttitle}{Shorttitle}
      \field{title}{Title2}
      \field{year}{1839}
      \field{pages}{1176\bibrangedash 1276}
      \keyw{arc}
    \endentry
|;

my $url1 = q|    \entry{url1}{misc}{}
      \name{labelname}{1}{}{%
        {{uniquename=0,hash=b2106a3dda6c5a4879a0cab37e9cca55}{Alias}{A\bibinitperiod}{Alan}{A\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{uniquename=0,hash=b2106a3dda6c5a4879a0cab37e9cca55}{Alias}{A\bibinitperiod}{Alan}{A\bibinitperiod}{}{}{}{}}%
      }
      \strng{namehash}{b2106a3dda6c5a4879a0cab37e9cca55}
      \strng{fullhash}{b2106a3dda6c5a4879a0cab37e9cca55}
      \field{labelalpha}{Ali05}
      \field{sortinit}{A}
      \field{extraalpha}{4}
      \field{year}{2005}
      \verb{url}
      \verb http://www.something.com/q=%C3%A1%C3%A9%C3%A1%C5%A0
      \endverb
    \endentry
|;

my $list1 = q|    \entry{list1}{book}{}
      \true{morelocation}
      \list{location}{2}{%
        {AAA}%
        {BBB}%
      }
      \field{sortinit}{0}
    \endentry
|;

my $Worman_N = [ 'Worman_N' ] ;
my $Gennep = [ 'v_Gennep_A', 'v_Gennep_J' ] ;

is( $out->get_output_entry('t1', $main), $t1, 'bbl entry with maths in title 1' ) ;
is( $bibentries->entry('shore')->get_field('month'), '03', 'default bib month macros' ) ;
ok( $bibentries->entry('t1')->has_keyword('primary'), 'Keywords test - 1' ) ;
ok( $bibentries->entry('t1')->has_keyword('something'), 'Keywords test - 2' ) ;
ok( $bibentries->entry('t1')->has_keyword('somethingelse'), 'Keywords test - 3' ) ;
is( $out->get_output_entry('t2', $main), $t2, 'bbl entry with maths in title 2' ) ;
is_deeply( Biber::Config->_get_uniquename('Worman_N', 'global'), $Worman_N, 'uniquename count 1') ;
is_deeply( Biber::Config->_get_uniquename('Gennep', 'global'), $Gennep, 'uniquename count 2') ;
is( $out->get_output_entry('murray', $main), $murray1, 'bbl with > maxcitenames' ) ;
is( $out->get_output_entry('missing1', $main), "  \\missing{missing1}\n", 'missing citekey 1' ) ;
is( $out->get_output_entry('missing2', $main), "  \\missing{missing2}\n", 'missing citekey 2' ) ;


Biber::Config->setblxoption('alphaothers', '');
Biber::Config->setblxoption('sortalphaothers', '');

# Have to do a citekey deletion as we are not re-reading the .bcf which would do it for us
# Otherwise, we have citekeys and allkeys which confuses fetch_data()
$section->del_citekeys;
$section->bibentries->del_entries;
$section->del_everykeys;
Biber::Input::file::bibtex->init_cache;
$biber->prepare ;
$section = $biber->sections->get_section(0);
$main = $biber->sortlists->get_list(0, 'entry', 'nty');
$out = $biber->get_output_obj;

is( $out->get_output_entry('murray', $main), $murray2, 'bbl with > maxcitenames, empty alphaothers' ) ;

# Make sure namehash and fullhash are seperately generated
is( $out->get_output_entry('anon1', $main), $anon1, 'namehash/fullhash 1' ) ;
is( $out->get_output_entry('anon2', $main), $anon2, 'namehash/fullhash 2' ) ;

# Testing of user field map ignores
ok(is_undef($bibentries->entry('i1')->get_field('abstract')), 'map 1' );
is($bibentries->entry('i1')->get_field('userd'), 'test', 'map 2' );
ok(is_undef($bibentries->entry('i2')->get_field('userb')), 'map 3' );
is(NFC($bibentries->entry('i2')->get_field('usere')), 'a Štring', 'map 4' );
# Testing of user field map match/replace
is($biber->_liststring('i1', 'listb'), 'REPlacedte!early', 'map 5');
is($biber->_liststring('i1', 'institution'), 'REPlaCEDte!early', 'map 6');
# Testing of pseudo-field "entrykey" handling
is($bibentries->entry('i1')->get_field('note'), 'i1', 'map 3' );
# Checking deletion of alsosets with value BMAP_NULL
ok(is_undef($bibentries->entry('i2')->get_field('userf')), 'map 7' );
# Checking that the "misc" type-specific mapping to null takes precedence over global userb->userc
ok(is_undef($bibentries->entry('i2')->get_field('userc')), 'map 8' );

# Make sure visibility doesn't exceed number of names.
is($bibentries->entry('i2')->get_field($bibentries->entry('i2')->get_labelname_info->{field})->get_visible_bib, '3', 'bib visibility - 1');

# Testing per_type and per_entry max/min* so reset globals to defaults
Biber::Config->setblxoption('uniquelist', 0);
Biber::Config->setblxoption('maxcitenames', 3);
Biber::Config->setblxoption('mincitenames', 1);
Biber::Config->setblxoption('maxitems', 3);
Biber::Config->setblxoption('minitems', 1);
Biber::Config->setblxoption('maxbibnames', 3);
Biber::Config->setblxoption('minbibnames', 1);
Biber::Config->setblxoption('maxalphanames', 3);
Biber::Config->setblxoption('minalphanames', 1);
Biber::Config->setblxoption('maxcitenames', 1, 'PER_TYPE', 'misc');
Biber::Config->setblxoption('maxbibnames', 2, 'PER_TYPE', 'unpublished');
Biber::Config->setblxoption('minbibnames', 2, 'PER_TYPE', 'unpublished');
# maxalphanames is set on tmn2 entry
Biber::Config->setblxoption('minalphanames', 2, 'PER_TYPE', 'book');
# minitems is set on tmn3 entry
Biber::Config->setblxoption('maxitems', 2, 'PER_TYPE', 'unpublished');

# Have to do a citekey deletion as we are not re-reading the .bcf which would do it for us
# Otherwise, we have citekeys and allkeys which confuses fetch_data()
$section->del_citekeys;
$section->bibentries->del_entries;
$section->del_everykeys;
Biber::Input::file::bibtex->init_cache;
$biber->prepare;
$section = $biber->sections->get_section(0);
$main = $biber->sortlists->get_list(0, 'entry', 'nty');

is($bibentries->entry('tmn1')->get_field($bibentries->entry('tmn1')->get_labelname_info->{field})->get_visible_cite, '1', 'per_type maxcitenames - 1');
is($bibentries->entry('tmn2')->get_field($bibentries->entry('tmn2')->get_labelname_info->{field})->get_visible_cite, '3', 'per_type maxcitenames - 2');
is($bibentries->entry('tmn3')->get_field($bibentries->entry('tmn3')->get_labelname_info->{field})->get_visible_bib, '2', 'per_type bibnames - 3');
is($bibentries->entry('tmn4')->get_field($bibentries->entry('tmn4')->get_labelname_info->{field})->get_visible_bib, '3', 'per_type bibnames - 4');
is($bibentries->entry('tmn1')->get_field($bibentries->entry('tmn1')->get_labelname_info->{field})->get_visible_alpha, '3', 'per_type/entry alphanames - 1');
is($bibentries->entry('tmn2')->get_field($bibentries->entry('tmn2')->get_labelname_info->{field})->get_visible_alpha, '2', 'per_type/entry alphanames - 2');
is($biber->_liststring('tmn1', 'institution'), 'A!B!C', 'per_type/entry items - 1');
is($biber->_liststring('tmn3', 'institution'), "A!B\x{10FFFD}", 'per_type/entry items - 2');

# Citekey alias testing
is($section->get_citekey_alias('alias3'), 'alias1', 'Citekey aliases - 1');
ok(is_undef($section->get_citekey_alias('alias2')), 'Citekey aliases - 2');
is($section->get_citekey_alias('alias4'), 'alias2', 'Citekey aliases - 3');
# primary key 'alias5' is not cited but should be added anyway as cited alias 'alias6' needs it
is($section->get_citekey_alias('alias6'), 'alias5', 'Citekey aliases - 4');
ok($bibentries->entry('alias5'), 'Citekey aliases - 5');

# URL encoding testing
is($bibentries->entry('url1')->get_field('url'), 'http://www.something.com/q=%C3%A1%C3%A9%C3%A1%C5%A0', 'URL encoding - 1');
is($bibentries->entry('url2')->get_field('url'), 'http://www.something.com/q=one%20two', 'URL encoding - 2');
is($out->get_output_entry('url1', $main), $url1, 'URL encoding - 3' ) ;

# map_final testing with map_field_set
is($bibentries->entry('ol1')->get_field('note'), 'A note', 'map_final - 1');
is($bibentries->entry('ol1')->get_field('title'), 'Online1', 'map_final - 2');

# Test for tricky pages field
is_deeply($bibentries->entry('pages1')->get_field('pages'),[[23, 24]], 'pages - 1');
is_deeply($bibentries->entry('pages2')->get_field('pages'),[[23, undef]], 'pages - 2');
is_deeply($bibentries->entry('pages3')->get_field('pages'), [['I-II', 'III-IV']], 'pages - 3');
is_deeply($bibentries->entry('pages4')->get_field('pages'), [[3,5]], 'pages - 4');
is_deeply($bibentries->entry('pages5')->get_field('pages'), [[42, '']], 'pages - 5');
is_deeply($bibentries->entry('pages6')->get_field('pages'), [['\bibstring{number} 42', undef]], 'pages - 6');
is_deeply($bibentries->entry('pages7')->get_field('pages'), [['\bibstring{number} 42', undef], [3,6], ['I-II',5 ]], 'pages - 7');

# Test for map levels, the user map makes this CUSTOMC and then style map makes it CUSTOMA
is($bibentries->entry('us1')->get_field('entrytype'), 'customa', 'Map levels - 1');

# Test for "others" in lists
is( $out->get_output_entry('list1', $main), $list1, 'Entry with others list' ) ;
