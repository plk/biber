# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 70;
use Test::Differences;
unified_diff;

use Biber;
use Biber::Utils;
use Biber::Output::bbl;
use Log::Log4perl;
use Unicode::Normalize;
chdir("t/tdata");

# Set up Biber object
my $biber = Biber->new(configfile => 'biber-test.conf');
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

# WARNING - the .bcf has special defs for URLS to test verbatim lists
$biber->parse_ctrlfile('basic-misc.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');
Biber::Config->setblxoption('uniquelist', 1);
Biber::Config->setblxoption('maxcitenames', 3);
Biber::Config->setblxoption('mincitenames', 1);
Biber::Config->setblxoption('maxalphanames', 3);
Biber::Config->setblxoption('minalphanames', 1);
Biber::Config->setblxoption('maxbibnames', 10);
Biber::Config->setblxoption('minbibnames', 7);
Biber::Config->setoption('isbn_normalise', 1);
Biber::Config->setoption('isbn13', 1);

# THERE IS A CONFIG FILE BEING READ TO TEST USER MAPS TOO!

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $main = $biber->sortlists->get_list(0, 'nty/global/', 'entry', 'nty', 'global', '');
my @keys = sort $section->get_citekeys;
my @citedkeys = sort qw{ alias1 alias2 alias5 anon1 anon2 murray t1 kant:ku kant:kpv t2 shore u1 u2 us1 list1 isbn1 isbn2 m1 m2 m3 markey ent1};

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
set:yoon maron coleridge tvonb t2 u1 u2 i1 i2 tmn1 tmn2 tmn3 tmn4 lne1 alias1 alias2 alias5 url1 ol1 pages1 pages2 pages3 pages4 pages5 pages6 pages7 pages8 us1 labelstest list1 sn1 pages9 isbn1 isbn2 snk1 clone-snk1 newtestkey m1 m2 m3 ent1 avona rvonr};

my $u1 = q|    \entry{u1}{misc}{}
      \name{author}{4}{uniquelist=4}{%
        {{uniquename=0,hash=e1faffb3e614e6c2fba74296962386b7}{%
           family={AAA},
           family_i={A\bibinitperiod}}}%
        {{uniquename=0,hash=2bb225f0ba9a58930757a868ed57d9a3}{%
           family={BBB},
           family_i={B\bibinitperiod}}}%
        {{uniquename=0,hash=defb99e69a9f1f6e06f15006b1f166ae}{%
           family={CCC},
           family_i={C\bibinitperiod}}}%
        {{uniquename=0,hash=45054f47ac3305a2a33e9bcceadff712}{%
           family={DDD},
           family_i={D\bibinitperiod}}}%
      }
      \strng{namehash}{b78abdc838d79b6576f2ed0021642766}
      \strng{fullhash}{b78abdc838d79b6576f2ed0021642766}
      \strng{authornamehash}{b78abdc838d79b6576f2ed0021642766}
      \strng{authorfullhash}{b78abdc838d79b6576f2ed0021642766}
      \field{labelalpha}{AAA\textbf{+}00}
      \field{sortinit}{A}
      \field{sortinithash}{b685c7856330eaee22789815b49de9bb}
      \true{singletitle}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{A title}
      \field{year}{2000}
    \endentry
|;

eq_or_diff( $out->get_output_entry('u1', $main), $u1, 'uniquelist 1' ) ;

is_deeply( \@keys, \@citedkeys, 'citekeys 1') ;
is_deeply( [ $biber->sortlists->get_list(0, 'shorthands/global/', 'list', 'shorthands', 'global', '')->get_keys ], [ 'kant:kpv', 'kant:ku' ], 'shorthands' ) ;

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

# Strip out loopkeys because they contain a variable key
@keys = sort grep {$_ !~ m/^loopkey/} map {lc()} $section->get_citekeys;

is_deeply( \@keys, \@allkeys, 'citekeys 2') ;

my $murray1 = q|    \entry{murray}{article}{}
      \name{author}{14}{}{%
        {{uniquename=0,hash=f1bafaf959660d1c3ca82d486ce5a651}{%
           family={Hostetler},
           family_i={H\bibinitperiod},
           given={Michael\bibnamedelima J.},
           given_i={M\bibinitperiod\bibinitdelim J\bibinitperiod}}}%
        {{uniquename=0,hash=de9f774c929dc661b4180b07f5eb62f3}{%
           family={Wingate},
           family_i={W\bibinitperiod},
           given={Julia\bibnamedelima E.},
           given_i={J\bibinitperiod\bibinitdelim E\bibinitperiod}}}%
        {{uniquename=0,hash=76100791c221471771c6bf1dbbc0975d}{%
           family={Zhong},
           family_i={Z\bibinitperiod},
           given={Chuan-Jian},
           given_i={C\bibinithyphendelim J\bibinitperiod}}}%
        {{uniquename=0,hash=34c410f87490dd022093780c69640413}{%
           family={Harris},
           family_i={H\bibinitperiod},
           given={Jay\bibnamedelima E.},
           given_i={J\bibinitperiod\bibinitdelim E\bibinitperiod}}}%
        {{uniquename=0,hash=a803710eddd16b95e91f420c0081985c}{%
           family={Vachet},
           family_i={V\bibinitperiod},
           given={Richard\bibnamedelima W.},
           given_i={R\bibinitperiod\bibinitdelim W\bibinitperiod}}}%
        {{uniquename=0,hash=38d1db37321ac524d14a116e74123685}{%
           family={Clark},
           family_i={C\bibinitperiod},
           given={Michael\bibnamedelima R.},
           given_i={M\bibinitperiod\bibinitdelim R\bibinitperiod}}}%
        {{uniquename=0,hash=969c673c8b05314f89a822ecfbead6af}{%
           family={Londono},
           family_i={L\bibinitperiod},
           given={J.\bibnamedelimi David},
           given_i={J\bibinitperiod\bibinitdelim D\bibinitperiod}}}%
        {{uniquename=0,hash=fc6cda30bdeb421b5b57ef2d1ce6f92b}{%
           family={Green},
           family_i={G\bibinitperiod},
           given={Stephen\bibnamedelima J.},
           given_i={S\bibinitperiod\bibinitdelim J\bibinitperiod}}}%
        {{uniquename=0,hash=69dcde2965d0ce8a53fae463355f36f5}{%
           family={Stokes},
           family_i={S\bibinitperiod},
           given={Jennifer\bibnamedelima J.},
           given_i={J\bibinitperiod\bibinitdelim J\bibinitperiod}}}%
        {{uniquename=0,hash=8cfed260a429843a4846ad8d83f9a09f}{%
           family={Wignall},
           family_i={W\bibinitperiod},
           given={George\bibnamedelima D.},
           given_i={G\bibinitperiod\bibinitdelim D\bibinitperiod}}}%
        {{uniquename=0,hash=71a4aee3f5124c9c94825634735417be}{%
           family={Glish},
           family_i={G\bibinitperiod},
           given={Gary\bibnamedelima L.},
           given_i={G\bibinitperiod\bibinitdelim L\bibinitperiod}}}%
        {{uniquename=0,hash=9406f7f2b15056febb90692ae05e8620}{%
           family={Porter},
           family_i={P\bibinitperiod},
           given={Marc\bibnamedelima D.},
           given_i={M\bibinitperiod\bibinitdelim D\bibinitperiod}}}%
        {{uniquename=0,hash=f8d80918767d0ce7f535453dc016c327}{%
           family={Evans},
           family_i={E\bibinitperiod},
           given={Neal\bibnamedelima D.},
           given_i={N\bibinitperiod\bibinitdelim D\bibinitperiod}}}%
        {{uniquename=0,hash=98688e58f25c10d275f9d15d31ba3396}{%
           family={Murray},
           family_i={M\bibinitperiod},
           given={Royce\bibnamedelima W.},
           given_i={R\bibinitperiod\bibinitdelim W\bibinitperiod}}}%
      }
      \strng{namehash}{7ba00ed438c44a2270c14ba95a7fc011}
      \strng{fullhash}{61836f4684b2615842b68c26479f6ec2}
      \strng{authornamehash}{7ba00ed438c44a2270c14ba95a7fc011}
      \strng{authorfullhash}{61836f4684b2615842b68c26479f6ec2}
      \field{labelalpha}{Hos\textbf{+}98}
      \field{sortinit}{H}
      \field{sortinithash}{82012198d5dfa657b8c4a168793268a6}
      \true{singletitle}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{shorttitle}
      \field{annotation}{An \texttt{article} entry with \arabic{author} authors. By default, long author and editor lists are automatically truncated. This is configurable}
      \field{indextitle}{Alkanethiolate gold cluster molecules}
      \field{journaltitle}{Langmuir}
      \field{langid}{english}
      \field{langidopts}{variant=american}
      \field{number}{1}
      \field{shorttitle}{Alkanethiolate gold cluster molecules}
      \field{subtitle}{Core and monolayer properties as a function of core size}
      \field{title}{Alkanethiolate gold cluster molecules with core diameters from 1.5 to 5.2~nm}
      \field{volume}{14}
      \field{year}{1998}
      \field{pages}{17\bibrangedash 30}
      \range{pages}{14}
      \keyw{keyw1,keyw2}
    \endentry
|;

my $murray2 = q|    \entry{murray}{article}{}
      \name{author}{14}{}{%
        {{uniquename=0,hash=f1bafaf959660d1c3ca82d486ce5a651}{%
           family={Hostetler},
           family_i={H\bibinitperiod},
           given={Michael\bibnamedelima J.},
           given_i={M\bibinitperiod\bibinitdelim J\bibinitperiod}}}%
        {{uniquename=0,hash=de9f774c929dc661b4180b07f5eb62f3}{%
           family={Wingate},
           family_i={W\bibinitperiod},
           given={Julia\bibnamedelima E.},
           given_i={J\bibinitperiod\bibinitdelim E\bibinitperiod}}}%
        {{uniquename=0,hash=76100791c221471771c6bf1dbbc0975d}{%
           family={Zhong},
           family_i={Z\bibinitperiod},
           given={Chuan-Jian},
           given_i={C\bibinithyphendelim J\bibinitperiod}}}%
        {{uniquename=0,hash=34c410f87490dd022093780c69640413}{%
           family={Harris},
           family_i={H\bibinitperiod},
           given={Jay\bibnamedelima E.},
           given_i={J\bibinitperiod\bibinitdelim E\bibinitperiod}}}%
        {{uniquename=0,hash=a803710eddd16b95e91f420c0081985c}{%
           family={Vachet},
           family_i={V\bibinitperiod},
           given={Richard\bibnamedelima W.},
           given_i={R\bibinitperiod\bibinitdelim W\bibinitperiod}}}%
        {{uniquename=0,hash=38d1db37321ac524d14a116e74123685}{%
           family={Clark},
           family_i={C\bibinitperiod},
           given={Michael\bibnamedelima R.},
           given_i={M\bibinitperiod\bibinitdelim R\bibinitperiod}}}%
        {{uniquename=0,hash=969c673c8b05314f89a822ecfbead6af}{%
           family={Londono},
           family_i={L\bibinitperiod},
           given={J.\bibnamedelimi David},
           given_i={J\bibinitperiod\bibinitdelim D\bibinitperiod}}}%
        {{uniquename=0,hash=fc6cda30bdeb421b5b57ef2d1ce6f92b}{%
           family={Green},
           family_i={G\bibinitperiod},
           given={Stephen\bibnamedelima J.},
           given_i={S\bibinitperiod\bibinitdelim J\bibinitperiod}}}%
        {{uniquename=0,hash=69dcde2965d0ce8a53fae463355f36f5}{%
           family={Stokes},
           family_i={S\bibinitperiod},
           given={Jennifer\bibnamedelima J.},
           given_i={J\bibinitperiod\bibinitdelim J\bibinitperiod}}}%
        {{uniquename=0,hash=8cfed260a429843a4846ad8d83f9a09f}{%
           family={Wignall},
           family_i={W\bibinitperiod},
           given={George\bibnamedelima D.},
           given_i={G\bibinitperiod\bibinitdelim D\bibinitperiod}}}%
        {{uniquename=0,hash=71a4aee3f5124c9c94825634735417be}{%
           family={Glish},
           family_i={G\bibinitperiod},
           given={Gary\bibnamedelima L.},
           given_i={G\bibinitperiod\bibinitdelim L\bibinitperiod}}}%
        {{uniquename=0,hash=9406f7f2b15056febb90692ae05e8620}{%
           family={Porter},
           family_i={P\bibinitperiod},
           given={Marc\bibnamedelima D.},
           given_i={M\bibinitperiod\bibinitdelim D\bibinitperiod}}}%
        {{uniquename=0,hash=f8d80918767d0ce7f535453dc016c327}{%
           family={Evans},
           family_i={E\bibinitperiod},
           given={Neal\bibnamedelima D.},
           given_i={N\bibinitperiod\bibinitdelim D\bibinitperiod}}}%
        {{uniquename=0,hash=98688e58f25c10d275f9d15d31ba3396}{%
           family={Murray},
           family_i={M\bibinitperiod},
           given={Royce\bibnamedelima W.},
           given_i={R\bibinitperiod\bibinitdelim W\bibinitperiod}}}%
      }
      \strng{namehash}{7ba00ed438c44a2270c14ba95a7fc011}
      \strng{fullhash}{61836f4684b2615842b68c26479f6ec2}
      \strng{authornamehash}{7ba00ed438c44a2270c14ba95a7fc011}
      \strng{authorfullhash}{61836f4684b2615842b68c26479f6ec2}
      \field{labelalpha}{Hos98}
      \field{sortinit}{H}
      \field{sortinithash}{82012198d5dfa657b8c4a168793268a6}
      \true{singletitle}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{shorttitle}
      \field{annotation}{An \texttt{article} entry with \arabic{author} authors. By default, long author and editor lists are automatically truncated. This is configurable}
      \field{indextitle}{Alkanethiolate gold cluster molecules}
      \field{journaltitle}{Langmuir}
      \field{langid}{english}
      \field{langidopts}{variant=american}
      \field{number}{1}
      \field{shorttitle}{Alkanethiolate gold cluster molecules}
      \field{subtitle}{Core and monolayer properties as a function of core size}
      \field{title}{Alkanethiolate gold cluster molecules with core diameters from 1.5 to 5.2~nm}
      \field{volume}{14}
      \field{year}{1998}
      \field{pages}{17\bibrangedash 30}
      \range{pages}{14}
      \keyw{keyw1,keyw2}
    \endentry
|;

# This example wouldn't compile - it's just to test escaping
my $t1 = q+    \entry{t1}{misc}{}
      \name{author}{1}{}{%
        {{uniquename=0,hash=858fcf9483ec29b7707a7dda2dde7a6f}{%
           family={Brown},
           family_i={B\bibinitperiod},
           given={Bill},
           given_i={B\bibinitperiod}}}%
      }
      \strng{namehash}{858fcf9483ec29b7707a7dda2dde7a6f}
      \strng{fullhash}{858fcf9483ec29b7707a7dda2dde7a6f}
      \strng{authornamehash}{858fcf9483ec29b7707a7dda2dde7a6f}
      \strng{authorfullhash}{858fcf9483ec29b7707a7dda2dde7a6f}
      \field{labelalpha}{Bro92}
      \field{sortinit}{B}
      \field{sortinithash}{4ecbea03efd0532989d3836d1a048c32}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{10\% of [100] and 90% of $Normal_2$ | \& # things {$^{3}$}}
      \field{year}{1992}
      \field{pages}{100\bibrangedash}
      \range{pages}{-1}
      \keyw{primary,something,somethingelse}
    \endentry
+;

my $t2 = q|    \entry{t2}{misc}{}
      \name{author}{1}{}{%
        {{uniquename=0,hash=858fcf9483ec29b7707a7dda2dde7a6f}{%
           family={Brown},
           family_i={B\bibinitperiod},
           given={Bill},
           given_i={B\bibinitperiod}}}%
      }
      \strng{namehash}{858fcf9483ec29b7707a7dda2dde7a6f}
      \strng{fullhash}{858fcf9483ec29b7707a7dda2dde7a6f}
      \strng{authornamehash}{858fcf9483ec29b7707a7dda2dde7a6f}
      \strng{authorfullhash}{858fcf9483ec29b7707a7dda2dde7a6f}
      \field{labelalpha}{Bro94}
      \field{sortinit}{B}
      \field{sortinithash}{4ecbea03efd0532989d3836d1a048c32}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{Signs of W$\frac{o}{a}$nder}
      \field{year}{1994}
      \field{pages}{100\bibrangedash 108}
      \range{pages}{9}
    \endentry
|;

my $anon1 = q|    \entry{anon1}{unpublished}{}
      \name{author}{1}{}{%
        {{hash=a66f357fe2fd356fe49959173522a651}{%
           family={AnonymousX},
           family_i={A\bibinitperiod}}}%
      }
      \name{shortauthor}{1}{}{%
        {{uniquename=0,hash=9873a6cc65c553faa2b21aaad626fe4b}{%
           family={XAnony},
           family_i={X\bibinitperiod}}}%
      }
      \strng{namehash}{9873a6cc65c553faa2b21aaad626fe4b}
      \strng{fullhash}{a66f357fe2fd356fe49959173522a651}
      \strng{authornamehash}{a66f357fe2fd356fe49959173522a651}
      \strng{authorfullhash}{a66f357fe2fd356fe49959173522a651}
      \strng{shortauthornamehash}{9873a6cc65c553faa2b21aaad626fe4b}
      \strng{shortauthorfullhash}{9873a6cc65c553faa2b21aaad626fe4b}
      \field{labelalpha}{XAn35}
      \field{sortinit}{A}
      \field{sortinithash}{b685c7856330eaee22789815b49de9bb}
      \true{singletitle}
      \field{labelnamesource}{shortauthor}
      \field{labeltitlesource}{shorttitle}
      \field{langid}{english}
      \field{langidopts}{variant=american}
      \field{note}{anon1}
      \field{shorttitle}{Shorttitle}
      \field{title}{Title1}
      \field{year}{1835}
      \field{pages}{111\bibrangedash 118}
      \range{pages}{8}
      \keyw{arc}
    \endentry
|;

my $anon2 = q|    \entry{anon2}{unpublished}{}
      \name{author}{1}{}{%
        {{hash=a0bccee4041bc840e14c06e5ba7f083c}{%
           family={AnonymousY},
           family_i={A\bibinitperiod}}}%
      }
      \name{shortauthor}{1}{}{%
        {{uniquename=0,hash=f64c29e89ea49402b997956610b58ef6}{%
           family={YAnony},
           family_i={Y\bibinitperiod}}}%
      }
      \strng{namehash}{f64c29e89ea49402b997956610b58ef6}
      \strng{fullhash}{a0bccee4041bc840e14c06e5ba7f083c}
      \strng{authornamehash}{a0bccee4041bc840e14c06e5ba7f083c}
      \strng{authorfullhash}{a0bccee4041bc840e14c06e5ba7f083c}
      \strng{shortauthornamehash}{f64c29e89ea49402b997956610b58ef6}
      \strng{shortauthorfullhash}{f64c29e89ea49402b997956610b58ef6}
      \field{labelalpha}{YAn39}
      \field{sortinit}{A}
      \field{sortinithash}{b685c7856330eaee22789815b49de9bb}
      \true{singletitle}
      \field{labelnamesource}{shortauthor}
      \field{labeltitlesource}{shorttitle}
      \field{langid}{english}
      \field{langidopts}{variant=american}
      \field{note}{anon2}
      \field{shorttitle}{Shorttitle}
      \field{title}{Title2}
      \field{year}{1839}
      \field{pages}{1176\bibrangedash 1276}
      \range{pages}{101}
      \keyw{arc}
    \endentry
|;

my $url1 = q|    \entry{url1}{misc}{}
      \name{author}{1}{}{%
        {{uniquename=0,hash=b2106a3dda6c5a4879a0cab37e9cca55}{%
           family={Alias},
           family_i={A\bibinitperiod},
           given={Alan},
           given_i={A\bibinitperiod}}}%
      }
      \strng{namehash}{b2106a3dda6c5a4879a0cab37e9cca55}
      \strng{fullhash}{b2106a3dda6c5a4879a0cab37e9cca55}
      \strng{authornamehash}{b2106a3dda6c5a4879a0cab37e9cca55}
      \strng{authorfullhash}{b2106a3dda6c5a4879a0cab37e9cca55}
      \field{labelalpha}{Ali05}
      \field{sortinit}{A}
      \field{sortinithash}{b685c7856330eaee22789815b49de9bb}
      \field{extraalpha}{4}
      \field{labelnamesource}{author}
      \field{year}{2005}
      \verb{url}
      \verb http://www.something.com/q=%C3%A1%C3%A9%C3%A1%C5%A0
      \endverb
      \lverb{urls}{2}
      \lverb http://www.something.com/q=%C3%A1%C3%A9%C3%A1%C5%A0
      \lverb http://www.sun.com
      \endlverb
    \endentry
|;

my $list1 = q|    \entry{list1}{book}{}
      \true{morelocation}
      \list{location}{2}{%
        {AAA}%
        {BBB}%
      }
      \field{sortinit}{}
      \field{sortinithash}{495dc9894017a8b12cafa9c619d10c0c}
    \endentry
|;

my $Worman_N = [ 'WormanN' ] ;
my $Gennep = [ 'vanGennepA', 'vanGennepJ' ] ;

eq_or_diff( $out->get_output_entry('t1', $main), $t1, 'bbl entry with maths in title 1');
eq_or_diff( $bibentries->entry('shore')->get_field('month'), '3', 'default bib month macros');
ok( $bibentries->entry('t1')->has_keyword('primary'), 'Keywords test - 1');
ok( $bibentries->entry('t1')->has_keyword('something'), 'Keywords test - 2');
ok( $bibentries->entry('t1')->has_keyword('somethingelse'), 'Keywords test - 3');
eq_or_diff( $out->get_output_entry('t2', $main), $t2, 'bbl entry with maths in title 2');
is_deeply( Biber::Config->_get_uniquename('WormanN', 'global'), $Worman_N, 'uniquename count 1');
is_deeply( Biber::Config->_get_uniquename('vanGennep', 'global'), $Gennep, 'uniquename count 2');
eq_or_diff( $out->get_output_entry('murray', $main), $murray1, 'bbl with > maxcitenames');
eq_or_diff( $out->get_output_entry('missing1', $main), "  \\missing{missing1}\n", 'missing citekey 1');
eq_or_diff( $out->get_output_entry('missing2', $main), "  \\missing{missing2}\n", 'missing citekey 2');

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
$main = $biber->sortlists->get_list(0, 'nty/global/', 'entry', 'nty', 'global', '');
$out = $biber->get_output_obj;

eq_or_diff($out->get_output_entry('murray', $main), $murray2, 'bbl with > maxcitenames, empty alphaothers');

# Make sure namehash and fullhash are seperately generated
eq_or_diff( $out->get_output_entry('anon1', $main), $anon1, 'namehash/fullhash 1' ) ;
eq_or_diff( $out->get_output_entry('anon2', $main), $anon2, 'namehash/fullhash 2' ) ;

# Testing of user field map ignores
ok(is_undef($bibentries->entry('i1')->get_field('abstract')), 'map 1' );
eq_or_diff($bibentries->entry('i1')->get_field('userd'), 'test', 'map 2' );
ok(is_undef($bibentries->entry('i2')->get_field('userb')), 'map 3' );
eq_or_diff(NFC($bibentries->entry('i2')->get_field('usere')), 'a Štring', 'map 4' );
# Testing ot UTF8 match/replace
eq_or_diff($biber->_liststring('i1', 'listd'), 'abc', 'map 5' );
# Testing of user field map match/replace
eq_or_diff($biber->_liststring('i1', 'listb'), 'REPlacedte!early', 'map 6');
eq_or_diff($biber->_liststring('i1', 'institution'), 'REPlaCEDte!early', 'map 7');
# Testing of pseudo-field "entrykey" handling
eq_or_diff($bibentries->entry('i1')->get_field('note'), 'i1', 'map 8' );
# Checking deletion of alsosets with value BMAP_NULL
ok(is_undef($bibentries->entry('i2')->get_field('userf')), 'map 9' );
# Checking that the "misc" type-specific mapping to null takes precedence over global userb->userc
ok(is_undef($bibentries->entry('i2')->get_field('userc')), 'map 10' );

# Make sure visibility doesn't exceed number of names.
eq_or_diff($bibentries->entry('i2')->get_field($bibentries->entry('i2')->get_labelname_info)->get_visible_bib, '3', 'bib visibility - 1');

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
Biber::Config->setblxoption('maxcitenames', 1, 'ENTRYTYPE', 'misc');
Biber::Config->setblxoption('maxbibnames', 2, 'ENTRYTYPE', 'unpublished');
Biber::Config->setblxoption('minbibnames', 2, 'ENTRYTYPE', 'unpublished');
# maxalphanames is set on tmn2 entry
Biber::Config->setblxoption('minalphanames', 2, 'ENTRYTYPE', 'book');
# minitems is set on tmn3 entry
Biber::Config->setblxoption('maxitems', 2, 'ENTRYTYPE', 'unpublished');

# Have to do a citekey deletion as we are not re-reading the .bcf which would do it for us
# Otherwise, we have citekeys and allkeys which confuses fetch_data()
$section->del_citekeys;
$section->bibentries->del_entries;
$section->del_everykeys;
Biber::Input::file::bibtex->init_cache;
$biber->prepare;
$section = $biber->sections->get_section(0);
$main = $biber->sortlists->get_list(0, 'nty/global/', 'entry', 'nty', 'global', '');

eq_or_diff($bibentries->entry('tmn1')->get_field($bibentries->entry('tmn1')->get_labelname_info)->get_visible_cite, '1', 'per_type maxcitenames - 1');
eq_or_diff($bibentries->entry('tmn2')->get_field($bibentries->entry('tmn2')->get_labelname_info)->get_visible_cite, '3', 'per_type maxcitenames - 2');
eq_or_diff($bibentries->entry('tmn3')->get_field($bibentries->entry('tmn3')->get_labelname_info)->get_visible_bib, '2', 'per_type bibnames - 3');
eq_or_diff($bibentries->entry('tmn4')->get_field($bibentries->entry('tmn4')->get_labelname_info)->get_visible_bib, '3', 'per_type bibnames - 4');
eq_or_diff($bibentries->entry('tmn1')->get_field($bibentries->entry('tmn1')->get_labelname_info)->get_visible_alpha, '3', 'per_type/entry alphanames - 1');
eq_or_diff($bibentries->entry('tmn2')->get_field($bibentries->entry('tmn2')->get_labelname_info)->get_visible_alpha, '2', 'per_type/entry alphanames - 2');
eq_or_diff($biber->_liststring('tmn1', 'institution'), 'A!B!C', 'per_type/entry items - 1');
eq_or_diff($biber->_liststring('tmn3', 'institution'), "A!B\x{10FFFD}", 'per_type/entry items - 2');

# Citekey alias testing
eq_or_diff($section->get_citekey_alias('alias3'), 'alias1', 'Citekey aliases - 1');
ok(is_undef($section->get_citekey_alias('alias2')), 'Citekey aliases - 2');
eq_or_diff($section->get_citekey_alias('alias4'), 'alias2', 'Citekey aliases - 3');
# primary key 'alias5' is not cited but should be added anyway as cited alias 'alias6' needs it
eq_or_diff($section->get_citekey_alias('alias6'), 'alias5', 'Citekey aliases - 4');
ok($bibentries->entry('alias5'), 'Citekey aliases - 5');

# URL encoding testing
eq_or_diff($bibentries->entry('url1')->get_field('url'), 'http://www.something.com/q=%C3%A1%C3%A9%C3%A1%C5%A0', 'URL encoding - 1');
eq_or_diff($out->get_output_entry('url1', $main), $url1, 'URL encoding - 2' ) ;

# map_final testing with map_field_set
eq_or_diff($bibentries->entry('ol1')->get_field('note'), 'A note', 'map_final - 1');
eq_or_diff($bibentries->entry('ol1')->get_field('title'), 'Online1', 'map_final - 2');

# Test for tricky pages field
is_deeply($bibentries->entry('pages1')->get_field('pages'),[[23, 24]], 'pages - 1');
is_deeply($bibentries->entry('pages2')->get_field('pages'),[[23, undef]], 'pages - 2');
is_deeply($bibentries->entry('pages3')->get_field('pages'), [['I-II', 'III-IV']], 'pages - 3');
is_deeply($bibentries->entry('pages4')->get_field('pages'), [[3,5]], 'pages - 4');
is_deeply($bibentries->entry('pages5')->get_field('pages'), [[42, '']], 'pages - 5');
is_deeply($bibentries->entry('pages6')->get_field('pages'), [['\bibstring{number} 42', undef]], 'pages - 6');
is_deeply($bibentries->entry('pages7')->get_field('pages'), [['\bibstring{number} 42', undef], [3,6], ['I-II',5 ]], 'pages - 7');
is_deeply($bibentries->entry('pages8')->get_field('pages'), [[10,15],['ⅥⅠ', 'ⅻ']], 'pages - 8');
is_deeply($bibentries->entry('pages9')->get_field('pages'), [['M-1','M-4']], 'pages - 9');

# Test for map levels, the user map makes this CUSTOMC and then style map makes it CUSTOMA
eq_or_diff($bibentries->entry('us1')->get_field('entrytype'), 'customa', 'Map levels - 1');

# Test for "others" in lists
eq_or_diff( $out->get_output_entry('list1', $main), $list1, 'Entry with others list' ) ;

my $isbn1 = q|    \entry{isbn1}{misc}{}
      \name{author}{1}{}{%
        {{uniquename=0,hash=f6595ccb9db5f634e7bb242a3f78e5f9}{%
           family={Flummox},
           family_i={F\bibinitperiod},
           given={Fred},
           given_i={F\bibinitperiod}}}%
      }
      \strng{namehash}{f6595ccb9db5f634e7bb242a3f78e5f9}
      \strng{fullhash}{f6595ccb9db5f634e7bb242a3f78e5f9}
      \strng{authornamehash}{f6595ccb9db5f634e7bb242a3f78e5f9}
      \strng{authorfullhash}{f6595ccb9db5f634e7bb242a3f78e5f9}
      \field{labelalpha}{Flu}
      \field{sortinit}{F}
      \field{sortinithash}{c6a7d9913bbd7b20ea954441c0460b78}
      \field{extraalpha}{1}
      \field{labelnamesource}{author}
      \field{isbn}{978-0-8165-2066-4}
    \endentry
|;

my $isbn2 = q|    \entry{isbn2}{misc}{}
      \name{author}{1}{}{%
        {{uniquename=0,hash=f6595ccb9db5f634e7bb242a3f78e5f9}{%
           family={Flummox},
           family_i={F\bibinitperiod},
           given={Fred},
           given_i={F\bibinitperiod}}}%
      }
      \strng{namehash}{f6595ccb9db5f634e7bb242a3f78e5f9}
      \strng{fullhash}{f6595ccb9db5f634e7bb242a3f78e5f9}
      \strng{authornamehash}{f6595ccb9db5f634e7bb242a3f78e5f9}
      \strng{authorfullhash}{f6595ccb9db5f634e7bb242a3f78e5f9}
      \field{labelalpha}{Flu}
      \field{sortinit}{F}
      \field{sortinithash}{c6a7d9913bbd7b20ea954441c0460b78}
      \field{extraalpha}{2}
      \field{labelnamesource}{author}
      \field{isbn}{978-0-8165-2066-4}
    \endentry
|;

# ISBN options tests
eq_or_diff($out->get_output_entry('isbn1', $main), $isbn1, 'ISBN options - 1');
eq_or_diff($out->get_output_entry('isbn2', $main), $isbn2, 'ISBN options - 2');

my $new1 = q|    \entry{newtestkey}{book}{}
      \field{sortinit}{}
      \field{sortinithash}{495dc9894017a8b12cafa9c619d10c0c}
      \field{note}{note}
      \field{usera}{RC-6947}
      \field{userb}{RC}
    \endentry
|;

my $clone1 = q|    \entry{snk1}{book}{}
      \name{author}{1}{}{%
        {{uniquename=0,hash=83330b0520b5d4ea57529a23b404d43d}{%
           family={Doe},
           family_i={D\bibinitperiod},
           given={John},
           given_i={J\bibinitperiod},
           prefix={von},
           prefix_i={v\bibinitperiod},
           suffix={Jr},
           suffix_i={J\bibinitperiod}}}%
      }
      \strng{namehash}{83330b0520b5d4ea57529a23b404d43d}
      \strng{fullhash}{83330b0520b5d4ea57529a23b404d43d}
      \strng{authornamehash}{83330b0520b5d4ea57529a23b404d43d}
      \strng{authorfullhash}{83330b0520b5d4ea57529a23b404d43d}
      \field{labelalpha}{vDoe}
      \field{sortinit}{v}
      \field{sortinithash}{d18f5ce25ce0b5ca7f924e3f6c04870e}
      \field{extraalpha}{2}
      \field{labelnamesource}{author}
    \endentry
|;

my $clone2 = q|    \entry{clone-snk1}{book}{}
      \name{author}{1}{}{%
        {{uniquename=0,hash=83330b0520b5d4ea57529a23b404d43d}{%
           family={Doe},
           family_i={D\bibinitperiod},
           given={John},
           given_i={J\bibinitperiod},
           prefix={von},
           prefix_i={v\bibinitperiod},
           suffix={Jr},
           suffix_i={J\bibinitperiod}}}%
      }
      \strng{namehash}{83330b0520b5d4ea57529a23b404d43d}
      \strng{fullhash}{83330b0520b5d4ea57529a23b404d43d}
      \strng{authornamehash}{83330b0520b5d4ea57529a23b404d43d}
      \strng{authorfullhash}{83330b0520b5d4ea57529a23b404d43d}
      \field{labelalpha}{vDoe}
      \field{sortinit}{v}
      \field{sortinithash}{d18f5ce25ce0b5ca7f924e3f6c04870e}
      \field{extraalpha}{1}
      \field{labelnamesource}{author}
      \field{addendum}{add}
    \endentry
|;

my $ent1 = q|    \entry{ent1}{book}{}
      \name{author}{2}{sortnamekeyscheme=snks1}{%
        {{uniquename=1,hash=6b3653417f9aa97391c37cff5dfda7fa}{%
           family={Smith},
           family_i={S\bibinitperiod},
           given={Simon},
           given_i={S\bibinitperiod}}}%
        {{uniquename=0,sortnamekeyscheme=snks2,hash=878a51e6f69e95562d15cb8a3ead5c95}{%
           family={Brown},
           family_i={B\bibinitperiod},
           given={Brian},
           given_i={B\bibinitperiod},
           prefix={de},
           prefix_i={d\bibinitperiod}}}%
      }
      \strng{namehash}{b2536a425d549b46de5f21c4d468050a}
      \strng{fullhash}{b2536a425d549b46de5f21c4d468050a}
      \strng{authornamehash}{b2536a425d549b46de5f21c4d468050a}
      \strng{authorfullhash}{b2536a425d549b46de5f21c4d468050a}
      \field{labelalpha}{SdB}
      \field{sortinit}{S}
      \field{sortinithash}{fd1e7c5ab79596b13dbbb67f8d70fb5a}
      \true{singletitle}
      \field{labelnamesource}{author}
    \endentry
|;

# clone test
eq_or_diff($out->get_output_entry('snk1', $main), $clone1, 'Clone - 1');
eq_or_diff($out->get_output_entry('clone-snk1', $main), $clone2, 'Clone - 2');

# New entry map test
eq_or_diff($out->get_output_entry('newtestkey', $main), $new1, 'New key mapping - 1');

# Should be three new ids in here with random keys
is(3, scalar(grep {$_ =~ m/^loopkey:/} $section->get_citekeys), 'New key loop mapping - 1');
eq_or_diff($bibentries->entry([grep {$_ =~ m/^loopkey:/} $section->get_citekeys]->[0])->get_field('note'), 'NOTEreplaced', 'New key loop mapping - 2');

# uniquetitle test
eq_or_diff($bibentries->entry('m1')->get_field('uniquetitle'), '1', 'uniquetitle test - 1');
ok(is_undef($bibentries->entry('m2')->get_field('uniquetitle')),  'uniquetitle test - 2');
ok(is_undef($bibentries->entry('m3')->get_field('uniquetitle')),  'uniquetitle test - 3');

# notfield test
eq_or_diff($bibentries->entry('markey')->get_field('addendum'), 'NF1', 'notfield - 1');
ok(is_undef($bibentries->entry('markey')->get_field('userb')),  'notfield - 2');

# Extended name format test
eq_or_diff($out->get_output_entry('ent1', $main), $ent1, 'Extended name test - 1');
