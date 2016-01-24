# -*- cperl -*-
use strict;
use warnings;
use utf8;

use Test::More tests => 9;
use Test::Differences;
unified_diff;

use Biber;
use Cwd qw(getcwd);
use File::Spec;
use Log::Log4perl;
use Unicode::Normalize;

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

chdir('t/tdata');

my $collopts = { level => 3,
                 variable => 'non-ignorable',
                 normalization => 'prenormalized',
                 table => '/home/user/data/otherkeys.txt' };

my $noinit = [ {value => q/\b\p{Ll}{2}\p{Pd}/}, {value => q/[\x{2bf}\x{2018}]/} ];

my $nosort = [ { name => 'author', value => q/\A\p{L}{2}\p{Pd}/ },
               { name => 'author', value => q/[\x{2bf}\x{2018}]/ },
               { name => 'translator', value => q/[\x{2bf}\x{2018}]/ } ];

my $sourcemap = [
  {
    datatype => "bibtex",
    level    => "user",
    map => [
      {
        map_step => [
          { map_field_source => "TITLE", map_match => "High-Resolution Micromachined Interferometric Accelerometer", map_final => 1, },
          { map_entry_null => 1 },
        ],
      },
      {
        map_step => [
          { map_type_source => "ARTICLE", map_type_target => "CUSTOMB" },
        ],
        per_datasource => [{ content => "doesnotexist.bib" }],
      },
      {
        map_overwrite  => 0,
        map_step       => [
                            { map_field_set => "KEYWORDS", map_field_value => "keyw1, keyw2" },
                            { map_field_set => "TITLE", map_field_value => "Blah" },
                          ],
        per_datasource => [
                            { content => "examples.bib" },
                            { content => "doesnotexist.bib" },
                          ],
        per_type       => [{ content => "ARTICLE" }, { content => "UNPUBLISHED" }],
      },
      {
        map_step => [
          {
            map_final       => 1,
            map_type_source => "CONVERSATION",
            map_type_target => "CUSTOMC",
          },
          { map_field_set => "VERBA", map_origentrytype => 1 },
          { map_field_set => "VERBB", map_field_value => "somevalue" },
          { map_field_set => "VERBC", map_field_value => "somevalue" },
        ],
      },
      {
        map_step => [{ map_type_source => "CHAT", map_type_target => "CUSTOMB" }],
      },
      {
        map_step       => [
                            { map_field_source => "USERB", map_final => 1 },
                            { map_field_set => "USERB", map_null => 1 },
                            { map_field_set => "USERE", map_field_value => NFD("a \x{160}tring") },
                            { map_field_set => "USERF", map_null => 1 },
                          ],
        per_datasource => [{ content => "examples.bib" }],
        per_type       => [{ content => "MISC" }],
      },
      {
        map_step => [
          { map_field_set => "ABSTRACT", map_null => 1 },
          { map_field_source => "CONDUCTOR", map_field_target => "NAMEA" },
          { map_field_source => "GPS", map_field_target => "USERA" },
          { map_field_source => "PARTICIPANT", map_field_target => "NAMEA" },
          { map_field_source => "USERB", map_field_target => "USERD" },
        ],
        per_datasource => [{ content => "examples.bib" }],
      },
      {
        map_step => [
          {
            map_field_source => "PUBMEDID",
            map_field_target => "EPRINT",
            map_final => 1,
          },
          { map_field_set => "EPRINTTYPE", map_origfield => 1 },
          {
            map_field_set   => "USERD",
            map_field_value => "Some string of things",
          },
        ],
      },
      {
        map_step => [
          {
            map_field_source => "LISTB",
            map_match        => "\\A(\\S{2})",
            map_replace      => "REP\$1CED",
          },
          { map_field_source => "LISTB", map_match => "CED", map_replace => "ced" },
        ],
        per_datasource => [{ content => "examples.bib" }],
      },
      {
        map_step => [
        { map_field_source => "TYPE", map_match => "resreport", map_final => "1" },
        { map_field_set => "USERA", map_field_value => "a, b,c" }
        ],
      },
      {
        map_step => [
        { map_field_source => "TYPE", map_match => "resreport", map_final => "1" },
        { map_entry_new => "loopkey:\$MAPLOOP:\$MAPUNIQ", map_entry_newtype => "book" },
        ],
        map_foreach => "USERA",
      },
      {
       map_step => [{ map_field_source => "TYPE", map_match => "resreport", map_final => "1" },
                    { map_entry_new => "newtestkey", map_entry_newtype => "book" },
                    { map_entrytarget => "newtestkey", map_field_set => "NOTE", map_field_value => "note" },
                    { map_field_source => "NUMBER", map_match => "([A-Z]+)" },
                    { map_entrytarget => "newtestkey", map_field_set => "USERA", map_origfieldval => "1" },
                    { map_entrytarget => "newtestkey", map_field_set => "USERB", map_field_value => "\$1" },
                    { map_field_set => "LISTA", map_null => 1 }],
        per_type => [{ content => "REPORT" }],
      },
      {
        map_step => [
                      {
                        map_field_source => "LISTC",
                        map_field_target => "INSTITUTION",
                        map_match        => "\\A(\\S{2})",
                        map_replace      => "REP\$1CED",
                      },
                      {
                        map_field_source => "LISTD",
                        map_match        => NFD("æøå"),
                        map_replace      => "abc",
                      },
                      {
                        map_field_set => "entrykey",
                        map_null         => 1
                      },
                      {
                        map_field_source => "entrykey",
                        map_field_target => "NOTE"
                      },
                      {
                        map_field_set    => "NOTE",
                        map_origfieldval => 1
                      },
                    ],
        per_type => [{ content => "UNPUBLISHED" }],
      },
      {
        map_overwrite  => 0,
        map_step => [{ map_field_set => "NOTE",
                       map_field_value => "Overwrite note",
                       map_final => 1},
                     { map_field_set => "TITLE", map_null => 1 }],
        per_type => [{ content => "ONLINE" }],
      },
    ],
    map_overwrite => 1,
  },
  {
    datatype => "ris",
    level    => "user",
    map => [
      {
        map_step => [{ map_type_source => "JOUR", map_type_target => "RPRT" }],
        per_datasource => [{ content => "ris1.ris" }],
      },
      {
        map_overwrite => 1,
        map_step => [
          { map_final => 1, map_type_source => "BOOK", map_type_target => "CHAP" },
          { map_field_set => "KW", map_field_value => "somevalue" },
        ],
      },
      {
        map_step => [{ map_field_set => "N2", map_null => 1 }],
        per_datasource => [{ content => "ris1.ris" }],
      },
      {
        map_step       => [
                            {
                              map_field_source => "JO",
                              map_match        => "Neurosurg\\.",
                              map_replace      => "Neurosurgery",
                            },
                          ],
        per_datasource => [{ content => "ris1.ris" }],
        per_type       => [{ content => "RPRT" }],
      },
    ],
  },
  {
    datatype => "bibtex",
    level => "driver",
    map => [
      {
        map_step => [
          {
            map_final       => 1,
            map_type_source => "conference",
            map_type_target => "inproceedings",
          },
          {
            map_final       => 1,
            map_type_source => "electronic",
            map_type_target => "online",
          },
          { map_final => 1, map_type_source => "www", map_type_target => "online" },
        ],
      },
      {
        map_step => [
          {
            map_final       => 1,
            map_type_source => "mastersthesis",
            map_type_target => "thesis",
          },
          { map_field_set => "type", map_field_value => "mathesis" },
        ],
      },
      {
        map_step => [
          {
            map_final       => 1,
            map_type_source => "phdthesis",
            map_type_target => "thesis",
          },
          { map_field_set => "type", map_field_value => "phdthesis" },
        ],
      },
      {
        map_step => [
          {
            map_final       => 1,
            map_type_source => "techreport",
            map_type_target => "report",
          },
          { map_field_set => "type", map_field_value => "techreport" },
        ],
      },
      {
        map_step => [
          { map_field_source => "hyphenation", map_field_target => "langid" },
          { map_field_source => "address", map_field_target => "location" },
          { map_field_source => "school", map_field_target => "institution" },
          { map_field_source => "annote", map_field_target => "annotation" },
          {
            map_field_source => "archiveprefix",
            map_field_target => "eprinttype",
          },
          { map_field_source => "journal", map_field_target => "journaltitle" },
          {
            map_field_source => "primaryclass",
            map_field_target => "eprintclass",
          },
          { map_field_source => "key", map_field_target => "sortkey" },
          { map_field_source => "pdf", map_field_target => "file" },
        ],
      },
    ],
  },
  {
    datatype => "ris",
    level => "driver",
    map => [
      {
        map_step => [
          { map_final => 1, map_type_source => "ART", map_type_target => "artwork" },
          {
            map_final       => 1,
            map_type_source => "BILL",
            map_type_target => "jurisdiction",
          },
          { map_final => 1, map_type_source => "BOOK", map_type_target => "book" },
          { map_final => 1, map_type_source => "CHAP", map_type_target => "inbook" },
          {
            map_final       => 1,
            map_type_source => "COMP",
            map_type_target => "software",
          },
          {
            map_final       => 1,
            map_type_source => "CONF",
            map_type_target => "proceedings",
          },
          { map_final => 1, map_type_source => "GEN", map_type_target => "misc" },
          {
            map_final       => 1,
            map_type_source => "JFULL",
            map_type_target => "article",
          },
          { map_final => 1, map_type_source => "JOUR", map_type_target => "article" },
          { map_final => 1, map_type_source => "MGZN", map_type_target => "misc" },
          { map_final => 1, map_type_source => "MPCT", map_type_target => "movie" },
          { map_final => 1, map_type_source => "NEWS", map_type_target => "misc" },
          { map_final => 1, map_type_source => "PAMP", map_type_target => "misc" },
          { map_final => 1, map_type_source => "PAT", map_type_target => "patent" },
          { map_final => 1, map_type_source => "PCOMM", map_type_target => "misc" },
          { map_final => 1, map_type_source => "RPRT", map_type_target => "report" },
          { map_final => 1, map_type_source => "SER", map_type_target => "misc" },
          { map_final => 1, map_type_source => "SLIDE", map_type_target => "misc" },
          { map_final => 1, map_type_source => "SOUND", map_type_target => "audio" },
          { map_final => 1, map_type_source => "STAT", map_type_target => "legal" },
          { map_final => 1, map_type_source => "THES", map_type_target => "thesis" },
          {
            map_final       => 1,
            map_type_source => "UNBILL",
            map_type_target => "jurisdiction",
          },
          {
            map_final       => 1,
            map_type_source => "UNPB",
            map_type_target => "unpublished",
          },
        ],
      },
      {
        map_step => [
          { map_field_source => "Y1", map_field_target => "date" },
          { map_field_source => "PY", map_field_target => "date" },
          { map_field_source => "Y2", map_field_target => "eventdate" },
          { map_field_source => "A1", map_field_target => "author" },
          { map_field_source => "AU", map_field_target => "author" },
          { map_field_source => "A2", map_field_target => "editor" },
          { map_field_source => "A3", map_field_target => "editor" },
          { map_field_source => "ED", map_field_target => "editor" },
          { map_field_source => "SPEP", map_field_target => "pages" },
          { map_field_source => "N1", map_field_target => "note" },
          { map_field_source => "N2", map_field_target => "abstract" },
          { map_field_source => "AB", map_field_target => "abstract" },
          { map_field_source => "JO", map_field_target => "journaltitle" },
          { map_field_source => "JF", map_field_target => "journaltitle" },
          { map_field_source => "JA", map_field_target => "shortjournal" },
          { map_field_source => "VL", map_field_target => "volume" },
          { map_field_source => "IS", map_field_target => "issue" },
          { map_field_source => "CP", map_field_target => "issue" },
          { map_field_source => "CY", map_field_target => "location" },
          { map_field_source => "SN", map_field_target => "isbn" },
          { map_field_source => "PB", map_field_target => "publisher" },
          { map_field_source => "KW", map_field_target => "keywords" },
          { map_field_source => "TI", map_field_target => "title" },
          { map_field_source => "U1", map_field_target => "usera" },
          { map_field_source => "U2", map_field_target => "userb" },
          { map_field_source => "U3", map_field_target => "userc" },
          { map_field_source => "U4", map_field_target => "userd" },
          { map_field_source => "U5", map_field_target => "usere" },
          { map_field_source => "UR", map_field_target => "url" },
          { map_field_source => "L1", map_field_target => "file" },
        ],
      },
    ],
  },
];

# Set up Biber object
my $biber = Biber->new( configfile => 'biber-test.conf', mincrossrefs => 7 );
$biber->parse_ctrlfile('general.bcf');
eq_or_diff(Biber::Config->getoption('mincrossrefs'), 7, 'Options 1 - from cmdline');
eq_or_diff(Biber::Config->getoption('configfile'), File::Spec->catfile('biber-test.conf'), 'Options 2 - from cmdline');
eq_or_diff(Biber::Config->getoption('sortlocale'), 'testlocale', 'Options 3 - from config file');
is_deeply(Biber::Config->getoption('collate_options'), $collopts, 'Options 4 - from config file');
is_deeply(Biber::Config->getoption('nosort'), $nosort, 'Options 5 - from config file');
is_deeply(Biber::Config->getoption('noinit'), $noinit, 'Options 6 - from config file');
is_deeply(Biber::Config->getoption('sortcase'), 0, 'Options 7 - from .bcf');
eq_or_diff(Biber::Config->getoption('decodecharsset'), 'base', 'Options 8 - from defaults');
# Here the result is a merge of the biblatex option from the .bcf and the option from
# the biber config file as sourcemap is a special case
is_deeply(Biber::Config->getoption('sourcemap'), $sourcemap, 'Options 9 - from config file');
