# -*- cperl -*-
use strict;
use warnings;
use Test::More tests => 10;
use Test::Differences;
unified_diff;

use Encode;
use Biber;
use Biber::Utils;
use Biber::Output::bibtex;
use Log::Log4perl;
use Unicode::Normalize;
use XML::LibXML;

no warnings 'utf8';
use utf8;

chdir("t/tdata");
my $conf = 'tool-testsort.conf';

# Set up schema
my $CFxmlschema = XML::LibXML::RelaxNG->new(location => '../../data/schemata/config.rng');

# Set up Biber object
my $biber = Biber->new(configfile => $conf);
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
Biber::Config->setoption('tool', 1);
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
my $main = $biber->datalists->get_lists_by_attrs(section                    => 99999,
                                       name                       => 'tool/global//global/global',
                                       type                       => 'entry',
                                       sortingtemplatename             => 'tool',
                                       sortingnamekeytemplatename      => 'global',
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
  LOCATION       = {London and Edinburgh},
  LOCATION+an    = {1=ann1;2=ann2},
  DATE           = {1999},
  MAINSUBTITLE   = {Mainsubtitle},
  MAINTITLE      = {Maintitle},
  MAINTITLEADDON = {Maintitleaddon},
  TITLE          = {Booktitle},
  TITLE+an       = {=ann1, ann2},
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

# NFD here because we are testing internals here and all internals expect NFD
eq_or_diff(encode_utf8($out->get_output_entry(NFD('i3Š'))), encode_utf8($t1), 'tool mode - 1');
ok(is_undef($out->get_output_entry('loh')), 'tool mode - 2');
eq_or_diff($out->get_output_entry('xd1',), $t2, 'tool mode - 3');
eq_or_diff($out->get_output_entry('b1',), $t3, 'tool mode - 4');
eq_or_diff($out->get_output_entry('dt1',), $t4, 'tool mode - 5');
is_deeply($main->get_keys, ['b1', 'macmillan', 'dt1', 'm1', 'macmillan:pub', 'macmillan:loc', 'mv1', NFD('i3Š'), 'xd1'], 'tool mode sorting');
eq_or_diff($out->get_output_comments, $tc1, 'tool mode - 6');

Biber::Config->setoption('output_xname', 1);
Biber::Config->setoption('output_xnamesep', ':');
$biber->tool_mode_setup;
$biber->prepare_tool;
$main = $biber->datalists->get_list(section                    => 99999,
                                    name                       => 'tool/global//global/global',
                                    type                       => 'entry',
                                    sortingtemplatename             => 'tool',
                                    sortingnamekeytemplatename      => 'global',
                                    labelprefix                => '',
                                    uniquenametemplatename     => 'global',
                                    labelalphanametemplatename => 'global');

$out = $biber->get_output_obj;
eq_or_diff(encode_utf8($out->get_output_entry(NFD('i3Š'))), encode_utf8($tx1), 'tool mode - 7');
eq_or_diff($out->get_output_entry('m1',), $m1, 'tool mode - 8');

my $CFxmlparser = XML::LibXML->new();
 # basic parse and XInclude processing
my $CFxp = $CFxmlparser->parse_file($conf);
# XPath context
my $CFxpc = XML::LibXML::XPathContext->new($CFxp);
# Validate against schema. Dies if it fails.
$CFxmlschema->validate($CFxp);
is($@, '', "Validation of $conf");
