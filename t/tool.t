# -*- cperl -*-
use strict;
use warnings;
use Test::More tests => 19;
use Test::Differences;
unified_diff;

use Encode;
use Biber;
use Biber::Utils;
use Biber::Output::bibtex;
use Log::Log4perl;
use Unicode::Normalize;
use XML::LibXML;
use Cwd 'abs_path';

no warnings 'utf8';
use utf8;

chdir("t/tdata");
my $conf = 'tool-testsort.conf';

# Set up schema
my $CFxmlschema = XML::LibXML::RelaxNG->new(location => '../../data/schemata/config.rng');

# Set up Biber object
my $biber = Biber->new(tool => 1,
                       configtool => abs_path('../../data/biber-tool.conf'),
                       configfile => $conf);
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

$biber->set_output_obj(Biber::Output::bibtex->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('output_align', '1');
Biber::Config->setoption('output_resolve_xdata', 1);
Biber::Config->setoption('output_resolve_crossrefs', 1);
Biber::Config->setoption('output_format', 'bibtex');
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');

# THERE IS A CONFIG FILE BEING READ!

# Now generate the information
$ARGV[0] = 'tool.bib'; # fake this as we are not running through top-level biber program
$biber->tool_mode_setup;
$biber->prepare_tool;
my $main = $biber->datalists->get_lists_by_attrs(section         => 99999,
                                      name                       => 'tool/global//global/global/global',
                                      type                       => 'entry',
                                      sortingtemplatename        => 'tool',
                                      sortingnamekeytemplatename => 'global',
                                      labelprefix                => '',
                                      uniquenametemplatename     => 'global',
                                      labelalphanametemplatename => 'global')->[0];

my $out = $biber->get_output_obj;

my $t1 = q|@UNPUBLISHED{i3Š,
  OPTIONS     = {useprefix=false},
  ABSTRACT    = {Some abstract %50 of which is useless},
  AUTHOR      = {AAA and BBB and CCC and DDD and EEE},
  INSTITUTION = {REPlaCEDte and early},
  LISTA       = {list test},
  LISTB       = {late and early},
  LOCATION    = {one and two},
  DATE        = {2003},
  KEYWORDS    = {keyword,keyword2,keyword3},
  NOTE        = {i3Š},
  TITLE       = {Š title},
  USERB       = {test},
}

|;

my $tx1 = q|@UNPUBLISHED{i3Š,
  OPTIONS     = {useprefix=false},
  ABSTRACT    = {Some abstract %50 of which is useless},
  AUTHOR      = {family:AAA and family:BBB and family:CCC and family:DDD and family:EEE},
  INSTITUTION = {REPlaCEDte and early},
  LISTA       = {list test},
  LISTB       = {late and early},
  LOCATION    = {one and two},
  DATE        = {2003},
  KEYWORDS    = {keyword,keyword2,keyword3},
  NOTE        = {i3Š},
  TITLE       = {Š title},
  USERB       = {test},
}

|;

my $t2 = q|@BOOK{xd1,
  AUTHOR    = {Ellington, Edward Paul},
  LOCATION  = {New York and London},
  PUBLISHER = {Macmillan},
  DATE      = {2001},
  NOTE      = {A Note},
}

|;

my $t3 = q|@BOOK{b1,
  LOCATION            = {London and Edinburgh},
  LOCATION+an:default = {1=ann1;2=ann2},
  DATE                = {1999},
  MAINSUBTITLE        = {Mainsubtitle},
  MAINTITLE           = {Maintitle},
  MAINTITLEADDON      = {Maintitleaddon},
  TITLE               = {Booktitle},
  TITLE+an:default    = {=ann1, ann2},
}

|;

my $t4 = q|@BOOK{dt1,
  DATE      = {2004-04-25T14:34:00/2004-04-05T14:37:06},
  EVENTDATE = {2004-04-25T14:34:00+05:00/2004-04-05T15:34:00+05:00},
  ORIGDATE  = {2004-04-25T14:34:00Z/2004-04-05T14:34:05Z},
  URLDATE   = {2004-04-25T14:34:00/2004-04-05T15:00:00},
}

|;


my $tc1 = ["\@COMMENT{Comment 1}\n",
           "\@COMMENT{Comment 2}\n",
           "\@COMMENT{jabref-meta: groupstree:\n0 AllEntriesGroup:;\n1 ExplicitGroup:Doktorandkurser\\;2\\;;\n2 KeywordGroup:Fra\x{30a}n ko\x{308}nsroll till genus\\;0\\;course\\;UCGS Fra\x{30a}n ko\x{308}nsrolltill genus\\;0\\;0\\;;\n2 KeywordGroup:Historiska och filosofiska perspektiv pa\x{30a} psykologi\\;0\\;course\\;Historiska och filosofiska perspektiv pa\x{30a} psykologi\\;0\\;0\\;;\n2 KeywordGroup:Kurs i introduktion\\;0\\;course\\;Kurs i introduktion\\;0\\;0\\;;\n2 KeywordGroup:Fenomenologi, ko\x{308}n och genus\\;0\\;course\\;UCGS Fenomenologi\\;0\\;0\\;;\n2 KeywordGroup:Quantitative Research Methods\\;0\\;course\\;QMR\\;0\\;0\\;;\n2 KeywordGroup:Multivariate Analysis\\;0\\;course\\;MVA\\;1\\;0\\;;\n}\n"];

# JOURNALTITLE->JOURNAL map in config. JOURNAL won't be output because it's
# not a valid field.
# DATE->YEAR map in config. YEAR won't be output because
# it wasn't in the original datasource.
my $m1 = q|@ARTICLE{m1,
  DATE = {2017},
}

|;

my $badcr1 = q|@BOOK{badcr1,
  AUTHOR = {Foo},
  DATE   = {2019},
  TITLE  = {Foo},
}

|;

my $badcr2 = q|@BOOK{badcr2,
  AUTHOR = {Bar},
  DATE   = {2019},
  TITLE  = {Bar},
}

|;

my $gxd1 = q|@BOOK{gxd1,
  AUTHOR       = {Smith, Simon and Bloom, Brian},
  EDITOR       = {Frill, Frank},
  TRANSLATOR   = {xdata=gxd2-author-3},
  LISTA        = {xdata=gxd3-location-5},
  LOCATION     = {A and B},
  ORGANIZATION = {xdata=gxd2-author-3},
  PUBLISHER    = {xdata=gxd2},
  ADDENDUM     = {xdata=missing},
  NOTE         = {xdata=gxd2-note},
  TITLE        = {Some title},
}

|;

my $gxd2 = q|@BOOK{gxd1,
  AUTHOR       = {family:Smith, given:Simon and xdata:gxd2+author+1},
  EDITOR       = {xdata:gxd2+editor+2},
  TRANSLATOR   = {xdata:gxd2+author+3},
  LISTA        = {xdata:gxd3+location+5},
  LOCATION     = {xdata:gxd3+location+1 and B},
  ORGANIZATION = {xdata:gxd2+author+3},
  PUBLISHER    = {xdata:gxd2},
  ADDENDUM     = {xdata:missing},
  NOTE         = {xdata:gxd2+note},
  TITLE        = {xdata:gxd4+title},
}

|;

my $ld1 = q|@BOOK{ld1,
  AUTHOR    = {AAA and BBB and CCC and DDD and EEE},
  PUBLISHER = P,
  MONTH     = apr,
  TITLE     = {A title},
  YEAR      = {2003},
}

|;

my $ld2 = q|@BOOK{ld1,
  AUTHOR    = {AAA and BBB and CCC and DDD and EEE},
  PUBLISHER = P,
  MONTH     = {4},
  TITLE     = {A title},
  YEAR      = {2003},
}

|;

my $macros1 = ["\@STRING{P = \"Publisher\"}\n"];
my $macros2 = ["\@STRING{N = \"NotUsed\"}\n",
               "\@STRING{P = \"Publisher\"}\n"];

# NFD here because we are testing internals here and all internals expect NFD
eq_or_diff(encode_utf8($out->get_output_entry(NFD('i3Š'))), encode_utf8($t1), 'tool mode - 1');
ok(is_undef($out->get_output_entry('loh')), 'tool mode - 2');
eq_or_diff($out->get_output_entry('xd1',), $t2, 'tool mode - 3');
eq_or_diff($out->get_output_entry('b1',), $t3, 'tool mode - 4');
eq_or_diff($out->get_output_entry('dt1',), $t4, 'tool mode - 5');
is_deeply($main->get_keys, ['b1', 'macmillan', 'dt1', 'm1', 'macmillan:pub', 'macmillan:loc', 'mv1', 'gxd3', 'gxd4', NFD('i3Š'), 'ld1', 'badcr2', 'gxd2', 'xd1', 'badcr1', 'bo1', 'gxd1'], 'tool mode sorting');
eq_or_diff($out->get_output_comments, $tc1, 'tool mode - 6');
eq_or_diff($out->get_output_entry('badcr1',), $badcr1, 'tool mode - 7');
eq_or_diff($out->get_output_entry('badcr2',), $badcr2, 'tool mode - 8');
eq_or_diff($out->get_output_entry('gxd1',), $gxd1, 'tool mode - 9');

Biber::Config->setoption('output_xname', 1);
Biber::Config->setoption('output_xnamesep', ':');
Biber::Config->setoption('output_resolve_xdata', 0);
Biber::Config->setoption('output_xdatasep', '+');

$biber->tool_mode_setup;
$biber->prepare_tool;
$main = $biber->datalists->get_list(section                    => 99999,
                                    name                       => 'tool/global//global/global/global',
                                    type                       => 'entry',
                                    sortingtemplatename        => 'tool',
                                    sortingnamekeytemplatename => 'global',
                                    labelprefix                => '',
                                    uniquenametemplatename     => 'global',
                                    labelalphanametemplatename => 'global');

$out = $biber->get_output_obj;
eq_or_diff(encode_utf8($out->get_output_entry(NFD('i3Š'))), encode_utf8($tx1), 'tool mode - 10');
eq_or_diff($out->get_output_entry('m1',), $m1, 'tool mode - 11');
eq_or_diff($out->get_output_entry('gxd1',), $gxd2, 'tool mode - 12');

my $CFxmlparser = XML::LibXML->new();
 # basic parse and XInclude processing
my $CFxp = $CFxmlparser->parse_file($conf);
# XPath context
my $CFxpc = XML::LibXML::XPathContext->new($CFxp);
# Validate against schema. Dies if it fails.
$CFxmlschema->validate($CFxp);
is($@, '', "Validation of $conf");
# Bad name test
ok(is_undef($out->get_output_entry('badname')), 'Bad name - 1');

Biber::Config->setoption('output_xname', 0);
Biber::Config->setoption('output_legacy_dates', '1');

$biber->tool_mode_setup;
$biber->prepare_tool;
$main = $biber->datalists->get_list(section                    => 99999,
                                    name                       => 'tool/global//global/global/global',
                                    type                       => 'entry',
                                    sortingtemplatename        => 'tool',
                                    sortingnamekeytemplatename => 'global',
                                    labelprefix                => '',
                                    uniquenametemplatename     => 'global',
                                    labelalphanametemplatename => 'global');

$out = $biber->get_output_obj;
eq_or_diff($out->get_output_entry('ld1',), $ld1, 'tool mode - 10');
is_deeply($out->get_output_macros, $macros1, 'tool mode - 11');

Biber::Config->setoption('output_legacy_dates', '1');
Biber::Config->setoption('output_macro_fields', undef);
Biber::Config->setoption('nostdmacros', '1');
Biber::Config->setoption('output_all_macrodefs', '1');

$biber->tool_mode_setup;
$biber->prepare_tool;
$main = $biber->datalists->get_list(section                    => 99999,
                                    name                       => 'tool/global//global/global/global',
                                    type                       => 'entry',
                                    sortingtemplatename        => 'tool',
                                    sortingnamekeytemplatename => 'global',
                                    labelprefix                => '',
                                    uniquenametemplatename     => 'global',
                                    labelalphanametemplatename => 'global');

$out = $biber->get_output_obj;
eq_or_diff($out->get_output_entry('ld1',), $ld2, 'tool mode - 12');
is_deeply($out->get_output_macros, $macros2, 'tool mode - 13');
