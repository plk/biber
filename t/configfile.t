# -*- cperl -*-
use strict;
use warnings;
use utf8;

use Test::More tests => 8;
use Biber;
use Cwd qw(getcwd);
use File::Spec;
use Log::Log4perl;
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

my $collopts = [ { name => 'level', value => 3 },
                  { name => 'table', value => '/home/user/data/otherkeys.txt' } ];

my $nosort = [ { name => 'author', value => q/\A\p{L}{2}\p{Pd}/ },
               { name => 'author', value => q/[\x{2bf}\x{2018}]/ },
               { name => 'translator', value => q/[\x{2bf}\x{2018}]/ } ];

my $sourcemap = [
  {
    datatype => "bibtex",
    map => [
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
            map_type_target => "CUSTOMA",
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
                            { map_field_set => "USERE", map_field_value => "a \x{160}tring" },
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
        map_step => [{ map_field_set => "LISTA", map_null => 1 }],
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
                    ],
        per_type => [{ content => "UNPUBLISHED" }],
      },
      {
        map_step => [{ map_field_set => "TITLE", map_null => 1 }],
        per_type => [{ content => "ONLINE" }],
      },
    ],
    map_overwrite => 1,
  },
  {
    datatype => "endnotexml",
    map => [
      {
        map_step => [
          {
            map_final       => 1,
            map_type_source => "Journal Article",
            map_type_target => "Report",
          },
          { map_field_set => "label", map_origentrytype => 1 },
        ],
        per_datasource => [{ content => "endnote.xml" }],
      },
      {
        map_step       => [
                            { map_field_source => "pages", map_match => 64, map_replace => 66 },
                          ],
        per_datasource => [{ content => "endnote.xml" }],
        per_type       => [{ content => "Report" }],
      },
      {
        map_step => [{ map_field_set => "abstract", map_null => 1 }],
        per_datasource => [{ content => "endnote.xml" }],
      },
    ],
    map_overwrite => 1,
  },
  {
    datatype => "ris",
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
    datatype => "zoterordfxml",
    map => [
      {
        map_step => [
                      {
                        map_field_source => "dc:title",
                        map_match        => "(.+)",
                        map_replace      => "\\L\$1",
                      },
                    ],
        per_type => [{ content => "journalArticle" }],
      },
      {
        map_step       => [{ map_field_set => "dc:subject", map_null => 1 }],
        per_datasource => [{ content => "zotero.rdf" }],
        per_type       => [
                            { content => "journalArticle" },
                            { content => "book" },
                            { content => "bookSection" },
                          ],
      },
    ],
    map_overwrite => 1,
  },
];

# Set up Biber object
my $biber = Biber->new( configfile => 'biber-test.conf', mincrossrefs => 7 );
$biber->parse_ctrlfile('general1.bcf');
is(Biber::Config->getoption('mincrossrefs'), 7, 'Options 1 - from cmdline');
is(Biber::Config->getoption('configfile'), File::Spec->catfile('biber-test.conf'), 'Options 2 - from cmdline');
is(Biber::Config->getoption('sortlocale'), 'testlocale', 'Options 3 - from config file');
is_deeply(Biber::Config->getoption('collate_options'), $collopts, 'Options 4 - from config file');
is_deeply(Biber::Config->getoption('nosort'), $nosort, 'Options 5 - from config file');
is_deeply(Biber::Config->getoption('sortcase'), 0, 'Options 6 - from .bcf');
is(Biber::Config->getoption('decodecharsset'), 'base', 'Options 7 - from defaults');
is_deeply(Biber::Config->getoption('sourcemap'), $sourcemap, 'Options 8 - from config file');
