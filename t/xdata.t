# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 11;
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
my $main = $biber->datalists->get_list('nty/global//global/global');
my $out = $biber->get_output_obj;

my $xd1 = q|    \entry{xd1}{book}{}
      \name[default][en-us]{author}{1}{}{%
        {{hash=51db4bfd331cba22959ce2d224c517cd}{%
           family={Ellington},
           familyi={E\bibinitperiod},
           given={Edward},
           giveni={E\bibinitperiod}}}%
      }
      \list[default][en-us]{location}{2}{%
        {New York}%
        {London}%
      }
      \list[default][en-us]{publisher}{1}{%
        {Macmillan}%
      }
      \strng{namehash}{51db4bfd331cba22959ce2d224c517cd}
      \strng{fullhash}{51db4bfd331cba22959ce2d224c517cd}
      \strng{bibnamehash}{51db4bfd331cba22959ce2d224c517cd}
      \strng{authordefaulten-usbibnamehash}{51db4bfd331cba22959ce2d224c517cd}
      \strng{authordefaulten-usnamehash}{51db4bfd331cba22959ce2d224c517cd}
      \strng{authordefaulten-usfullhash}{51db4bfd331cba22959ce2d224c517cd}
      \field{extraname}{2}
      \field{sortinit}{E}
      \strng{sortinithash}{c554bd1a0b76ea92b9f105fe36d9c7b0}
      \field{extradatescope}{labelyear}
      \fieldsource{labeldate}{}{}{}
      \fieldsource{labelname}{author}{default}{en-us}
      \field[default][en-us]{note}{A Note}
      \field{year}{2007}
      \field{dateera}{ce}
      \warn{\item Entry 'xd1' references XDATA entry 'missingxd' which does not exist, not resolving (section 0)}
    \endentry
|;

my $xd2 = q|    \entry{xd2}{book}{}
      \name[default][en-us]{author}{1}{}{%
        {{hash=68539e0ce4922cc4957c6cabf35e6fc8}{%
           family={Pillington},
           familyi={P\bibinitperiod},
           given={Peter},
           giveni={P\bibinitperiod}}}%
      }
      \list[default][en-us]{location}{2}{%
        {New York}%
        {London}%
      }
      \list[default][en-us]{publisher}{1}{%
        {Routledge}%
      }
      \strng{namehash}{68539e0ce4922cc4957c6cabf35e6fc8}
      \strng{fullhash}{68539e0ce4922cc4957c6cabf35e6fc8}
      \strng{bibnamehash}{68539e0ce4922cc4957c6cabf35e6fc8}
      \strng{authordefaulten-usbibnamehash}{68539e0ce4922cc4957c6cabf35e6fc8}
      \strng{authordefaulten-usnamehash}{68539e0ce4922cc4957c6cabf35e6fc8}
      \strng{authordefaulten-usfullhash}{68539e0ce4922cc4957c6cabf35e6fc8}
      \field{sortinit}{P}
      \strng{sortinithash}{bb5b15f2db90f7aef79bb9e83defefcb}
      \field{extradatescope}{labelyear}
      \fieldsource{labeldate}{}{}{}
      \fieldsource{labelname}{author}{default}{en-us}
      \field[default][en-us]{abstract}{An abstract}
      \field[default][en-us]{addendum}{Москва}
      \field[default][en-us]{note}{A Note}
      \field[default][en-us]{venue}{venue}
      \field{year}{2003}
      \field{dateera}{ce}
    \endentry
|;

my $gxd1 = q|    \entry{gxd1}{book}{}
      \name[default][en-us]{author}{2}{}{%
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
      \name[default][en-us]{editor}{1}{}{%
        {{hash=6238b302317c6baeba56035f2c4998c9}{%
           family={Frill},
           familyi={F\bibinitperiod},
           given={Frank},
           giveni={F\bibinitperiod}}}%
      }
      \name[default][en-us]{namea}{1}{}{%
        {{hash=d41d8cd98f00b204e9800998ecf8427e}{%
}}%
      }
      \name[default][en-us]{translator}{1}{}{%
        {{hash=d41d8cd98f00b204e9800998ecf8427e}{%
}}%
      }
      \list[default][en-us]{lista}{1}{%
        {xdata=gxd3-location-5}%
      }
      \list[default][en-us]{location}{2}{%
        {A}%
        {B}%
      }
      \list[default][en-us]{organization}{1}{%
        {xdata=gxd2-author-3}%
      }
      \list[default][en-us]{publisher}{1}{%
        {xdata=gxd2}%
      }
      \strng{namehash}{167d3a67f6ee19fe4d131fc34dcd9ede}
      \strng{fullhash}{167d3a67f6ee19fe4d131fc34dcd9ede}
      \strng{bibnamehash}{167d3a67f6ee19fe4d131fc34dcd9ede}
      \strng{authordefaulten-usbibnamehash}{167d3a67f6ee19fe4d131fc34dcd9ede}
      \strng{authordefaulten-usnamehash}{167d3a67f6ee19fe4d131fc34dcd9ede}
      \strng{authordefaulten-usfullhash}{167d3a67f6ee19fe4d131fc34dcd9ede}
      \strng{editordefaulten-usbibnamehash}{6238b302317c6baeba56035f2c4998c9}
      \strng{editordefaulten-usnamehash}{6238b302317c6baeba56035f2c4998c9}
      \strng{editordefaulten-usfullhash}{6238b302317c6baeba56035f2c4998c9}
      \strng{nameadefaulten-usbibnamehash}{d41d8cd98f00b204e9800998ecf8427e}
      \strng{nameadefaulten-usnamehash}{d41d8cd98f00b204e9800998ecf8427e}
      \strng{nameadefaulten-usfullhash}{d41d8cd98f00b204e9800998ecf8427e}
      \strng{translatordefaulten-usbibnamehash}{d41d8cd98f00b204e9800998ecf8427e}
      \strng{translatordefaulten-usnamehash}{d41d8cd98f00b204e9800998ecf8427e}
      \strng{translatordefaulten-usfullhash}{d41d8cd98f00b204e9800998ecf8427e}
      \field{sortinit}{S}
      \strng{sortinithash}{c319cff79d99c853d775f88277d4e45f}
      \fieldsource{labelname}{author}{default}{en-us}
      \fieldsource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{addendum}{xdata=missing}
      \field[default][en-us]{note}{xdata=gxd2-note}
      \field[default][en-us]{title}{Some title}
      \warn{\item Entry 'gxd1' has XDATA reference from field 'publisher/default/en-us' that contains no source field (section 0)}
      \warn{\\item Entry 'gxd1' has XDATA reference from field 'addendum/default/en-us' that contains no source field (section 0)}
      \warn{\item Field 'note/default/en-us' in entry 'gxd1' references XDATA field 'note/default/en-us' in entry 'gxd2' and this field does not exist, not resolving (section 0)}
      \warn{\item Field 'translator/default/en-us' in entry 'gxd1' references field 'author/default/en-us' position 3 in entry 'gxd2' and this position does not exist, not resolving (section 0)}
      \warn{\item Field 'lista/default/en-us' in entry 'gxd1' references field 'location/default/en-us' position 5 in entry 'gxd3' and this position does not exist, not resolving (section 0)}
      \warn{\item Field 'organization/default/en-us' in entry 'gxd1' which xdata references field 'author/default/en-us' in entry 'gxd2' are not the same types, not resolving (section 0)}
      \warn{\item Entry 'gxd1' references XDATA entry 'lxd1' which is not an XDATA entry, not resolving (section 0)}
    \endentry
|;

my $bltxgxd1 = q|    \entry{bltxgxd1}{book}{}
      \name[default][en-us]{author}{2}{}{%
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
      \name[default][en-us]{editor}{1}{}{%
        {{hash=c8eb0270ad4e434f36dca28e219e81a8}{%
           family={Lee},
           familyi={L\bibinitperiod},
           given={Lay},
           giveni={L\bibinitperiod}}}%
      }
      \name[default][en-us]{translator}{1}{}{%
        {{hash=d41d8cd98f00b204e9800998ecf8427e}{%
}}%
      }
      \list[default][en-us]{lista}{1}{%
        {xdata=bltxgxd3-location-5}%
      }
      \list[default][en-us]{location}{2}{%
        {A}%
        {B}%
      }
      \list[default][en-us]{organization}{1}{%
        {xdata=bltxgxd2-author-3}%
      }
      \list[default][en-us]{publisher}{1}{%
        {xdata=bltxgxd2}%
      }
      \strng{namehash}{f3cbd0df6512c5a3653f60e9e9849c69}
      \strng{fullhash}{f3cbd0df6512c5a3653f60e9e9849c69}
      \strng{bibnamehash}{f3cbd0df6512c5a3653f60e9e9849c69}
      \strng{authordefaulten-usbibnamehash}{f3cbd0df6512c5a3653f60e9e9849c69}
      \strng{authordefaulten-usnamehash}{f3cbd0df6512c5a3653f60e9e9849c69}
      \strng{authordefaulten-usfullhash}{f3cbd0df6512c5a3653f60e9e9849c69}
      \strng{editordefaulten-usbibnamehash}{c8eb0270ad4e434f36dca28e219e81a8}
      \strng{editordefaulten-usnamehash}{c8eb0270ad4e434f36dca28e219e81a8}
      \strng{editordefaulten-usfullhash}{c8eb0270ad4e434f36dca28e219e81a8}
      \strng{translatordefaulten-usbibnamehash}{d41d8cd98f00b204e9800998ecf8427e}
      \strng{translatordefaulten-usnamehash}{d41d8cd98f00b204e9800998ecf8427e}
      \strng{translatordefaulten-usfullhash}{d41d8cd98f00b204e9800998ecf8427e}
      \field{sortinit}{B}
      \strng{sortinithash}{8de16967003c7207dae369d874f1456e}
      \fieldsource{labelname}{author}{default}{en-us}
      \fieldsource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{addendum}{xdata=missing}
      \field[default][en-us]{note}{xdata=bltxgxd2-note}
      \field[default][en-us]{title}{Some title}
      \warn{\item Entry 'bltxgxd1' has XDATA reference from field 'publisher/default/en-us' that contains no source field (section 0)}
      \warn{\item Entry 'bltxgxd1' has XDATA reference from field 'addendum/default/en-us' that contains no source field (section 0)}
      \warn{\item Field 'translator/default/en-us' in entry 'bltxgxd1' references field 'author/default/en-us' position 3 in entry 'bltxgxd2' and this position does not exist, not resolving (section 0)}
      \warn{\item Field 'lista/default/en-us' in entry 'bltxgxd1' references field 'location/default/en-us' position 5 in entry 'bltxgxd3' and this position does not exist, not resolving (section 0)}
      \warn{\item Field 'organization/default/en-us' in entry 'bltxgxd1' which xdata references field 'author/default/en-us' in entry 'bltxgxd2' are not the same types, not resolving (section 0)}
      \warn{\item Field 'note/default/en-us' in entry 'bltxgxd1' references XDATA field 'note/default/en-us' in entry 'bltxgxd2' and this field does not exist, not resolving (section 0)}
    \endentry
|;

# Test::Differences doesn't like utf8 unless it's encoded here
eq_or_diff($out->get_output_entry('xd1', $main), $xd1, 'xdata test - 1');
eq_or_diff(encode_utf8($out->get_output_entry('xd2', $main)), encode_utf8($xd2), 'xdata test - 2');
# XDATA entries should not be output at all
eq_or_diff($out->get_output_entry('macmillan', $main), undef, 'xdata test - 3');
eq_or_diff($out->get_output_entry('macmillan:pub', $main), undef, 'xdata test - 4');
eq_or_diff($out->get_output_entry('gxd1', $main), $gxd1, 'xdata granular test - 1');
eq_or_diff($out->get_output_entry('bltxgxd1', $main), $bltxgxd1, 'xdata granular test - 2');
chomp $stderr;
ok((first {$_ eq "ERROR - Circular XDATA inheritance between 'lxd1:loop'<->'lxd2:loop'"} split("\n",$stderr)), 'Cyclic xdata error check - 1');
ok((first {$_ eq "ERROR - Circular XDATA inheritance between 'lxd4:loop'<->'lxd4:loop'"} split("\n",$stderr)), 'Cyclic xdata error check - 2');
ok((first {$_ eq "ERROR - Circular XDATA inheritance between 'loop'<->'loop:3'"} split("\n",$stderr)), 'Cyclic xdata error check - 3');

# granular warnings
my $w1 = [ "Entry 'gxd1' has XDATA reference from field 'publisher/default/en-us' that contains no source field (section 0)",
          "Entry 'gxd1' has XDATA reference from field 'addendum/default/en-us' that contains no source field (section 0)",
          "Field 'note/default/en-us' in entry 'gxd1' references XDATA field 'note/default/en-us' in entry 'gxd2' and this field does not exist, not resolving (section 0)",
          "Field 'translator/default/en-us' in entry 'gxd1' references field 'author/default/en-us' position 3 in entry 'gxd2' and this position does not exist, not resolving (section 0)",
          "Field 'lista/default/en-us' in entry 'gxd1' references field 'location/default/en-us' position 5 in entry 'gxd3' and this position does not exist, not resolving (section 0)",
           "Field 'organization/default/en-us' in entry 'gxd1' which xdata references field 'author/default/en-us' in entry 'gxd2' are not the same types, not resolving (section 0)",
           "Entry 'gxd1' references XDATA entry 'lxd1' which is not an XDATA entry, not resolving (section 0)"];
is_deeply($bibentries->entry('gxd1')->get_warnings, $w1, 'Granular XDATA resolution warnings - bibtex' );

my $w2 = [ "Entry 'bltxgxd1' has XDATA reference from field 'publisher/default/en-us' that contains no source field (section 0)",
           "Entry 'bltxgxd1' has XDATA reference from field 'addendum/default/en-us' that contains no source field (section 0)",
           "Field 'translator/default/en-us' in entry 'bltxgxd1' references field 'author/default/en-us' position 3 in entry 'bltxgxd2' and this position does not exist, not resolving (section 0)",
           "Field 'lista/default/en-us' in entry 'bltxgxd1' references field 'location/default/en-us' position 5 in entry 'bltxgxd3' and this position does not exist, not resolving (section 0)",
           "Field 'organization/default/en-us' in entry 'bltxgxd1' which xdata references field 'author/default/en-us' in entry 'bltxgxd2' are not the same types, not resolving (section 0)",
           "Field 'note/default/en-us' in entry 'bltxgxd1' references XDATA field 'note/default/en-us' in entry 'bltxgxd2' and this field does not exist, not resolving (section 0)"];
is_deeply($bibentries->entry('bltxgxd1')->get_warnings, $w2, 'Granular XDATA resolution warnings - biblatexml' );
# print $stdout;
# print $stderr;
