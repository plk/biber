# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 13;
use Test::Differences;
use List::AllUtils qw( first );
unified_diff;

use Biber;
use Biber::Output::bbl;
use Log::Log4perl;
use Capture::Tiny qw(capture);
use Encode;

chdir("t/tdata") ;

# USING CAPTURE - DEBUGGING PRINTS, DUMPS WON'T BE VISIBLE UNLESS YOU PRINT $stderr
# AT THE END!

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

$biber->parse_ctrlfile('xdata.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');
Biber::Config->setoption('nodieonerror', 1); # because there is a cyclic xdata check
Biber::Config->setoption('no_bltxml_schema', 1);

# Now generate the information
my ($stdout, $stderr) = capture { $biber->prepare };
#my ($stdout, $stderr); $biber->prepare; # For debugging
my $section = $biber->sections->get_section(0);
my $bibentries = $section->bibentries;
my $main = $biber->datalists->get_list('nty/global//global/global/global');
my $out = $biber->get_output_obj;

my $xd1 = q|    \entry{xd1}{book}{}{}
      \name{author}{1}{}{%
        {{hash=51db4bfd331cba22959ce2d224c517cd}{%
           family={Ellington},
           familyi={E\bibinitperiod},
           given={Edward},
           giveni={E\bibinitperiod}}}%
      }
      \list{location}{2}{%
        {New York}%
        {London}%
      }
      \list{publisher}{1}{%
        {Macmillan}%
      }
      \strng{namehash}{51db4bfd331cba22959ce2d224c517cd}
      \strng{fullhash}{51db4bfd331cba22959ce2d224c517cd}
      \strng{fullhashraw}{51db4bfd331cba22959ce2d224c517cd}
      \strng{bibnamehash}{51db4bfd331cba22959ce2d224c517cd}
      \strng{authorbibnamehash}{51db4bfd331cba22959ce2d224c517cd}
      \strng{authornamehash}{51db4bfd331cba22959ce2d224c517cd}
      \strng{authorfullhash}{51db4bfd331cba22959ce2d224c517cd}
      \strng{authorfullhashraw}{51db4bfd331cba22959ce2d224c517cd}
      \field{extraname}{2}
      \field{sortinit}{E}
      \field{sortinithash}{8da8a182d344d5b9047633dfc0cc9131}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{note}{A Note}
      \field{year}{2007}
      \field{dateera}{ce}
      \warn{\item book entry 'xd1' references XDATA entry 'missingxd' which does not exist, not resolving (section 0)}
    \endentry
|;

my $xd2 = q|    \entry{xd2}{book}{}{}
      \name{author}{1}{}{%
        {{hash=68539e0ce4922cc4957c6cabf35e6fc8}{%
           family={Pillington},
           familyi={P\bibinitperiod},
           given={Peter},
           giveni={P\bibinitperiod}}}%
      }
      \list{location}{2}{%
        {New York}%
        {London}%
      }
      \list{publisher}{1}{%
        {Routledge}%
      }
      \strng{namehash}{68539e0ce4922cc4957c6cabf35e6fc8}
      \strng{fullhash}{68539e0ce4922cc4957c6cabf35e6fc8}
      \strng{fullhashraw}{68539e0ce4922cc4957c6cabf35e6fc8}
      \strng{bibnamehash}{68539e0ce4922cc4957c6cabf35e6fc8}
      \strng{authorbibnamehash}{68539e0ce4922cc4957c6cabf35e6fc8}
      \strng{authornamehash}{68539e0ce4922cc4957c6cabf35e6fc8}
      \strng{authorfullhash}{68539e0ce4922cc4957c6cabf35e6fc8}
      \strng{authorfullhashraw}{68539e0ce4922cc4957c6cabf35e6fc8}
      \field{sortinit}{P}
      \field{sortinithash}{ff3bcf24f47321b42cb156c2cc8a8422}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{abstract}{An abstract}
      \field{addendum}{Москва}
      \field{note}{A Note}
      \field{venue}{venue}
      \field{year}{2003}
      \field{dateera}{ce}
    \endentry
|;

my $gxd1 = q|    \entry{gxd1}{book}{}{}
      \name{author}{2}{}{%
        {{hash=6b3653417f9aa97391c37cff5dfda7fa}{%
           family={Smith},
           familyi={S\bibinitperiod},
           given={Simon},
           giveni={S\bibinitperiod}}}%
        {{hash=350a836ae63897de6d88baf1d62dc9f2}{%
           family={Bloom},
           familyi={B\bibinitperiod},
           given={Brian},
           giveni={B\bibinitperiod}}}%
      }
      \name{editor}{1}{}{%
        {{hash=6238b302317c6baeba56035f2c4998c9}{%
           family={Frill},
           familyi={F\bibinitperiod},
           given={Frank},
           giveni={F\bibinitperiod}}}%
      }
      \name{namea}{1}{}{%
        {{hash=d41d8cd98f00b204e9800998ecf8427e}{%
}}%
      }
      \name{translator}{1}{}{%
        {{hash=d41d8cd98f00b204e9800998ecf8427e}{%
}}%
      }
      \list{lista}{1}{%
        {xdata=gxd3-location-5}%
      }
      \list{location}{2}{%
        {A}%
        {B}%
      }
      \list{organization}{1}{%
        {xdata=gxd2-author-3}%
      }
      \list{publisher}{1}{%
        {xdata=gxd2}%
      }
      \strng{namehash}{167d3a67f6ee19fe4d131fc34dcd9ede}
      \strng{fullhash}{167d3a67f6ee19fe4d131fc34dcd9ede}
      \strng{fullhashraw}{167d3a67f6ee19fe4d131fc34dcd9ede}
      \strng{bibnamehash}{167d3a67f6ee19fe4d131fc34dcd9ede}
      \strng{authorbibnamehash}{167d3a67f6ee19fe4d131fc34dcd9ede}
      \strng{authornamehash}{167d3a67f6ee19fe4d131fc34dcd9ede}
      \strng{authorfullhash}{167d3a67f6ee19fe4d131fc34dcd9ede}
      \strng{authorfullhashraw}{167d3a67f6ee19fe4d131fc34dcd9ede}
      \strng{editorbibnamehash}{6238b302317c6baeba56035f2c4998c9}
      \strng{editornamehash}{6238b302317c6baeba56035f2c4998c9}
      \strng{editorfullhash}{6238b302317c6baeba56035f2c4998c9}
      \strng{editorfullhashraw}{6238b302317c6baeba56035f2c4998c9}
      \strng{nameabibnamehash}{d41d8cd98f00b204e9800998ecf8427e}
      \strng{nameanamehash}{d41d8cd98f00b204e9800998ecf8427e}
      \strng{nameafullhash}{d41d8cd98f00b204e9800998ecf8427e}
      \strng{nameafullhashraw}{d41d8cd98f00b204e9800998ecf8427e}
      \strng{translatorbibnamehash}{d41d8cd98f00b204e9800998ecf8427e}
      \strng{translatornamehash}{d41d8cd98f00b204e9800998ecf8427e}
      \strng{translatorfullhash}{d41d8cd98f00b204e9800998ecf8427e}
      \strng{translatorfullhashraw}{d41d8cd98f00b204e9800998ecf8427e}
      \field{sortinit}{S}
      \field{sortinithash}{b164b07b29984b41daf1e85279fbc5ab}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{addendum}{xdata=missing}
      \field{note}{xdata=gxd2-note}
      \field{title}{Some title}
      \warn{\item book entry 'gxd1' has XDATA reference from field 'publisher' that contains no source field (section 0)}
      \warn{\\item book entry 'gxd1' has XDATA reference from field 'addendum' that contains no source field (section 0)}
      \warn{\item Field 'note' in book entry 'gxd1' references XDATA field 'note' in entry 'gxd2' and this field does not exist, not resolving (section 0)}
      \warn{\item Field 'translator' in book entry 'gxd1' references field 'author' position 3 in entry 'gxd2' and this position does not exist, not resolving (section 0)}
      \warn{\item Field 'lista' in book entry 'gxd1' references field 'location' position 5 in entry 'gxd3' and this position does not exist, not resolving (section 0)}
      \warn{\item Field 'organization' in book entry 'gxd1' which xdata references field 'author' in entry 'gxd2' are not the same types, not resolving (section 0)}
      \warn{\item book entry 'gxd1' references XDATA entry 'lxd1' which is not an XDATA entry, not resolving (section 0)}
    \endentry
|;

my $gxd1g = q|    \entry{gxd1g}{book}{}{}
      \name{author}{3}{}{%
        {{hash=6b3653417f9aa97391c37cff5dfda7fa}{%
           family={Smith},
           familyi={S\bibinitperiod},
           given={Simon},
           giveni={S\bibinitperiod}}}%
        {{hash=350a836ae63897de6d88baf1d62dc9f2}{%
           family={Bloom},
           familyi={B\bibinitperiod},
           given={Brian},
           giveni={B\bibinitperiod}}}%
        {{hash=7370e41a0804af6d5598ecf557c59841}{%
           family={Anderson},
           familyi={A\bibinitperiod},
           given={Arthur},
           giveni={A\bibinitperiod}}}%
      }
      \name{editor}{1}{}{%
        {{hash=6238b302317c6baeba56035f2c4998c9}{%
           family={Frill},
           familyi={F\bibinitperiod},
           given={Frank},
           giveni={F\bibinitperiod}}}%
      }
      \name{namea}{1}{}{%
        {{hash=d41d8cd98f00b204e9800998ecf8427e}{%
}}%
      }
      \name{translator}{1}{}{%
        {{hash=d41d8cd98f00b204e9800998ecf8427e}{%
}}%
      }
      \list{lista}{1}{%
        {xdata=gxd3-location-5}%
      }
      \list{location}{3}{%
        {A}%
        {C}%
        {B}%
      }
      \list{organization}{1}{%
        {xdata=gxd2-author-3}%
      }
      \list{publisher}{1}{%
        {xdata=gxd2}%
      }
      \strng{namehash}{9fd3d5e0bec66ae3baacf58cf747485a}
      \strng{fullhash}{9fd3d5e0bec66ae3baacf58cf747485a}
      \strng{fullhashraw}{9fd3d5e0bec66ae3baacf58cf747485a}
      \strng{bibnamehash}{9fd3d5e0bec66ae3baacf58cf747485a}
      \strng{authorbibnamehash}{9fd3d5e0bec66ae3baacf58cf747485a}
      \strng{authornamehash}{9fd3d5e0bec66ae3baacf58cf747485a}
      \strng{authorfullhash}{9fd3d5e0bec66ae3baacf58cf747485a}
      \strng{authorfullhashraw}{9fd3d5e0bec66ae3baacf58cf747485a}
      \strng{editorbibnamehash}{6238b302317c6baeba56035f2c4998c9}
      \strng{editornamehash}{6238b302317c6baeba56035f2c4998c9}
      \strng{editorfullhash}{6238b302317c6baeba56035f2c4998c9}
      \strng{editorfullhashraw}{6238b302317c6baeba56035f2c4998c9}
      \strng{nameabibnamehash}{d41d8cd98f00b204e9800998ecf8427e}
      \strng{nameanamehash}{d41d8cd98f00b204e9800998ecf8427e}
      \strng{nameafullhash}{d41d8cd98f00b204e9800998ecf8427e}
      \strng{nameafullhashraw}{d41d8cd98f00b204e9800998ecf8427e}
      \strng{translatorbibnamehash}{d41d8cd98f00b204e9800998ecf8427e}
      \strng{translatornamehash}{d41d8cd98f00b204e9800998ecf8427e}
      \strng{translatorfullhash}{d41d8cd98f00b204e9800998ecf8427e}
      \strng{translatorfullhashraw}{d41d8cd98f00b204e9800998ecf8427e}
      \field{sortinit}{S}
      \field{sortinithash}{b164b07b29984b41daf1e85279fbc5ab}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{addendum}{xdata=missing}
      \field{note}{xdata=gxd2-note}
      \field{title}{Some title}
      \warn{\item book entry 'gxd1g' has XDATA reference from field 'publisher' that contains no source field (section 0)}
      \warn{\item book entry 'gxd1g' has XDATA reference from field 'addendum' that contains no source field (section 0)}
      \warn{\item Field 'note' in book entry 'gxd1g' references XDATA field 'note' in entry 'gxd2' and this field does not exist, not resolving (section 0)}
      \warn{\item Field 'translator' in book entry 'gxd1g' references field 'author' position 3 in entry 'gxd2' and this position does not exist, not resolving (section 0)}
      \warn{\item Field 'lista' in book entry 'gxd1g' references field 'location' position 5 in entry 'gxd3' and this position does not exist, not resolving (section 0)}
      \warn{\item Field 'organization' in book entry 'gxd1g' which xdata references field 'author' in entry 'gxd2' are not the same types, not resolving (section 0)}
      \warn{\item book entry 'gxd1g' references XDATA entry 'lxd1' which is not an XDATA entry, not resolving (section 0)}
    \endentry
|;

my $bltxgxd1 = q|    \entry{bltxgxd1}{book}{}{}
      \name{author}{2}{}{%
        {{hash=ecc4a87e596c582a09b19d4ab187d8c2}{%
           family={Brian},
           familyi={B\bibinitperiod},
           given={Bell},
           giveni={B\bibinitperiod}}}%
        {{hash=aec59e82011f45e1e719b313e70abfdc}{%
           family={Clive},
           familyi={C\bibinitperiod},
           given={Clue},
           giveni={C\bibinitperiod}}}%
      }
      \name{editor}{1}{}{%
        {{hash=c8eb0270ad4e434f36dca28e219e81a8}{%
           family={Lee},
           familyi={L\bibinitperiod},
           given={Lay},
           giveni={L\bibinitperiod}}}%
      }
      \name{translator}{1}{}{%
        {{hash=d41d8cd98f00b204e9800998ecf8427e}{%
}}%
      }
      \list{lista}{1}{%
        {xdata=bltxgxd3-location-5}%
      }
      \list{location}{2}{%
        {A}%
        {B}%
      }
      \list{organization}{1}{%
        {xdata=bltxgxd2-author-3}%
      }
      \list{publisher}{1}{%
        {xdata=bltxgxd2}%
      }
      \strng{namehash}{f3cbd0df6512c5a3653f60e9e9849c69}
      \strng{fullhash}{f3cbd0df6512c5a3653f60e9e9849c69}
      \strng{fullhashraw}{f3cbd0df6512c5a3653f60e9e9849c69}
      \strng{bibnamehash}{f3cbd0df6512c5a3653f60e9e9849c69}
      \strng{authorbibnamehash}{f3cbd0df6512c5a3653f60e9e9849c69}
      \strng{authornamehash}{f3cbd0df6512c5a3653f60e9e9849c69}
      \strng{authorfullhash}{f3cbd0df6512c5a3653f60e9e9849c69}
      \strng{authorfullhashraw}{f3cbd0df6512c5a3653f60e9e9849c69}
      \strng{editorbibnamehash}{c8eb0270ad4e434f36dca28e219e81a8}
      \strng{editornamehash}{c8eb0270ad4e434f36dca28e219e81a8}
      \strng{editorfullhash}{c8eb0270ad4e434f36dca28e219e81a8}
      \strng{editorfullhashraw}{c8eb0270ad4e434f36dca28e219e81a8}
      \strng{translatorbibnamehash}{d41d8cd98f00b204e9800998ecf8427e}
      \strng{translatornamehash}{d41d8cd98f00b204e9800998ecf8427e}
      \strng{translatorfullhash}{d41d8cd98f00b204e9800998ecf8427e}
      \strng{translatorfullhashraw}{d41d8cd98f00b204e9800998ecf8427e}
      \field{sortinit}{B}
      \field{sortinithash}{d7095fff47cda75ca2589920aae98399}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{addendum}{xdata=missing}
      \field{note}{xdata=bltxgxd2-note}
      \field{title}{Some title}
      \warn{\item book entry 'bltxgxd1' has XDATA reference from field 'publisher' that contains no source field (section 0)}
      \warn{\item book entry 'bltxgxd1' has XDATA reference from field 'addendum' that contains no source field (section 0)}
      \warn{\item Field 'translator' in book entry 'bltxgxd1' references field 'author' position 3 in entry 'bltxgxd2' and this position does not exist, not resolving (section 0)}
      \warn{\item Field 'lista' in book entry 'bltxgxd1' references field 'location' position 5 in entry 'bltxgxd3' and this position does not exist, not resolving (section 0)}
      \warn{\item Field 'organization' in book entry 'bltxgxd1' which xdata references field 'author' in entry 'bltxgxd2' are not the same types, not resolving (section 0)}
      \warn{\item Field 'note' in book entry 'bltxgxd1' references XDATA field 'note' in entry 'bltxgxd2' and this field does not exist, not resolving (section 0)}
    \endentry
|;

my $xdann1 = q|    \entry{xdann1}{book}{}{}
      \name{author}{4}{}{%
        {{hash=9c855075c7ab53ad38ec38086eda2029}{%
           family={Smith},
           familyi={S\bibinitperiod},
           given={Arthur},
           giveni={A\bibinitperiod}}}%
        {{hash=0c6731af5e4274be0b0ceef16eccb8f6}{%
           family={Bee},
           familyi={B\bibinitperiod},
           given={May},
           giveni={M\bibinitperiod}}}%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{%
           family={Doe},
           familyi={D\bibinitperiod},
           given={John},
           giveni={J\bibinitperiod}}}%
        {{hash=ccc542396e5b42506590dc7132859c8c}{%
           family={Blogs},
           familyi={B\bibinitperiod},
           given={Bill},
           giveni={B\bibinitperiod}}}%
      }
      \name{editor}{5}{}{%
        {{hash=93f025f0446f3db59decfaf17a19dbbe}{%
           family={Little},
           familyi={L\bibinitperiod},
           given={Raymond},
           giveni={R\bibinitperiod}}}%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{%
           family={Doe},
           familyi={D\bibinitperiod},
           given={John},
           giveni={J\bibinitperiod}}}%
        {{hash=d6cfb2b8c4b3f9440ec4642438129367}{%
           family={Doe},
           familyi={D\bibinitperiod},
           given={Jane},
           giveni={J\bibinitperiod}}}%
        {{hash=0c6731af5e4274be0b0ceef16eccb8f6}{%
           family={Bee},
           familyi={B\bibinitperiod},
           given={May},
           giveni={M\bibinitperiod}}}%
        {{hash=ead97b429847e5d377495ef9e13acb27}{%
           family={Roth},
           familyi={R\bibinitperiod},
           given={Gerald},
           giveni={G\bibinitperiod}}}%
      }
      \list{institution}{3}{%
        {inst1}%
        {inst2}%
        {inst3}%
      }
      \list{location}{3}{%
        {loca}%
        {xloc2}%
        {xloc2}%
      }
      \list{publisher}{1}{%
        {MacMillan}%
      }
      \strng{namehash}{416c234e34c8082fb7acf86c6e7a499a}
      \strng{fullhash}{7d301d11b9579ee16fad350195f2d756}
      \strng{fullhashraw}{7d301d11b9579ee16fad350195f2d756}
      \strng{bibnamehash}{416c234e34c8082fb7acf86c6e7a499a}
      \strng{authorbibnamehash}{416c234e34c8082fb7acf86c6e7a499a}
      \strng{authornamehash}{416c234e34c8082fb7acf86c6e7a499a}
      \strng{authorfullhash}{7d301d11b9579ee16fad350195f2d756}
      \strng{authorfullhashraw}{7d301d11b9579ee16fad350195f2d756}
      \strng{editorbibnamehash}{d1f1309f75dc90b7a1846a2efbd43572}
      \strng{editornamehash}{d1f1309f75dc90b7a1846a2efbd43572}
      \strng{editorfullhash}{519612891addebf4b3e5e61fefc6d52d}
      \strng{editorfullhashraw}{519612891addebf4b3e5e61fefc6d52d}
      \field{sortinit}{S}
      \field{sortinithash}{b164b07b29984b41daf1e85279fbc5ab}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{note}{A note}
      \field{title}{Very Long Title with XDATA}
      \annotation{field}{note}{default}{}{}{0}{bignote}
      \annotation{item}{author}{default}{1}{}{0}{biggerauthor}
      \annotation{item}{author}{default}{2}{}{0}{bigauthor}
      \annotation{item}{author}{default}{3}{}{0}{bigishauthor}
      \annotation{item}{editor}{default}{2}{}{0}{bigishauthor}
      \annotation{item}{editor}{default}{4}{}{0}{bigauthor}
      \annotation{item}{institution}{default}{2}{}{0}{biginst}
      \annotation{item}{location}{default}{2}{}{0}{bigloc}
      \annotation{item}{location}{default}{3}{}{0}{bigloc}
      \annotation{item}{publisher}{default}{1}{}{0}{bigpublisher}
    \endentry
|;

# Test::Differences doesn't like utf8 unless it's encoded here
eq_or_diff($out->get_output_entry('xd1', $main), $xd1, 'xdata test - 1');
eq_or_diff(encode_utf8($out->get_output_entry('xd2', $main)), encode_utf8($xd2), 'xdata test - 2');
# XDATA entries should not be output at all
eq_or_diff($out->get_output_entry('macmillan', $main), undef, 'xdata test - 3');
eq_or_diff($out->get_output_entry('macmillan:pub', $main), undef, 'xdata test - 4');
eq_or_diff($out->get_output_entry('gxd1', $main), $gxd1, 'xdata granular test - 1');
eq_or_diff($out->get_output_entry('gxd1g', $main), $gxd1g, 'xdata granular test - 2');
eq_or_diff($out->get_output_entry('bltxgxd1', $main), $bltxgxd1, 'xdata granular test - 3');
eq_or_diff($out->get_output_entry('xdann1', $main), $xdann1, 'xdata annotation test - 1');
chomp $stderr;
ok((first {$_ eq "ERROR - Circular XDATA inheritance between 'lxd1:loop'<->'lxd2:loop'"} split("\n",$stderr)), 'Cyclic xdata error check - 1');
ok((first {$_ eq "ERROR - Circular XDATA inheritance between 'lxd4:loop'<->'lxd4:loop'"} split("\n",$stderr)), 'Cyclic xdata error check - 2');
ok((first {$_ eq "ERROR - Circular XDATA inheritance between 'loop'<->'loop:3'"} split("\n",$stderr)), 'Cyclic xdata error check - 3');

# granular warnings
my $w1 = [ "book entry 'gxd1' has XDATA reference from field 'publisher' that contains no source field (section 0)",
          "book entry 'gxd1' has XDATA reference from field 'addendum' that contains no source field (section 0)",
          "Field 'note' in book entry 'gxd1' references XDATA field 'note' in entry 'gxd2' and this field does not exist, not resolving (section 0)",
          "Field 'translator' in book entry 'gxd1' references field 'author' position 3 in entry 'gxd2' and this position does not exist, not resolving (section 0)",
          "Field 'lista' in book entry 'gxd1' references field 'location' position 5 in entry 'gxd3' and this position does not exist, not resolving (section 0)",
           "Field 'organization' in book entry 'gxd1' which xdata references field 'author' in entry 'gxd2' are not the same types, not resolving (section 0)",
           "book entry 'gxd1' references XDATA entry 'lxd1' which is not an XDATA entry, not resolving (section 0)"];
is_deeply($bibentries->entry('gxd1')->get_field('warnings'), $w1, 'Granular XDATA resolution warnings - bibtex' );

my $w2 = [ "book entry 'bltxgxd1' has XDATA reference from field 'publisher' that contains no source field (section 0)",
           "book entry 'bltxgxd1' has XDATA reference from field 'addendum' that contains no source field (section 0)",
           "Field 'translator' in book entry 'bltxgxd1' references field 'author' position 3 in entry 'bltxgxd2' and this position does not exist, not resolving (section 0)",
           "Field 'lista' in book entry 'bltxgxd1' references field 'location' position 5 in entry 'bltxgxd3' and this position does not exist, not resolving (section 0)",
           "Field 'organization' in book entry 'bltxgxd1' which xdata references field 'author' in entry 'bltxgxd2' are not the same types, not resolving (section 0)",
           "Field 'note' in book entry 'bltxgxd1' references XDATA field 'note' in entry 'bltxgxd2' and this field does not exist, not resolving (section 0)"];
is_deeply($bibentries->entry('bltxgxd1')->get_field('warnings'), $w2, 'Granular XDATA resolution warnings - biblatexml' );
# print $stdout;
# print $stderr;
