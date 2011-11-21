# -*- cperl -*-
use strict;
use warnings;

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
    bmap_overwrite => 1,
    datatype => "bibtex",
    map => [
      {
        map_pair => [{ map_source => "*", map_target => "CUSTOMB" }],
        maptype => "entrytype",
        per_datasource => [{ content => "doesnotexist.bib" }],
      },
      {
        bmap_overwrite => 0,
        also_set       => [{ map_field => "KEYWORDS", map_value => "keyw1, keyw2" },
                           { map_field => "TITLE", map_value => "Blah" }],
        map_pair       => [{ map_source => "ARTICLE" }],
        maptype        => "entrytype",
        per_datasource => [
                            { content => "examples.bib" },
                            { content => "doesnotexist.bib" },
                          ],
      },
      {
        also_set => [
                      { bmap_origentrytype => 1, map_field => "VERBA" },
                      { map_field => "VERBB", map_value => "somevalue" },
                      { map_field => "VERBC", map_value => "somevalue" },
                    ],
        map_pair => [{ map_source => "CONVERSATION", map_target => "CUSTOMA" }],
        maptype  => "entrytype",
      },
      {
        map_pair => [{ map_source => "CHAT", map_target => "CUSTOMB" }],
        maptype  => "entrytype",
      },
      {
        also_set       => [
                            { map_field => "USERE", map_value => "a string" },
                            { bmap_null => 1, map_field => "USERF" },
                          ],
        map_pair       => [{ bmap_null => 1, map_source => "USERB" }],
        maptype        => "field",
        per_datasource => [{ content => "examples.bib" }],
        per_type       => [{ content => "MISC" }],
      },
      {
        map_pair => [
          { bmap_null => 1, map_source => "ABSTRACT" },
          { map_source => "CONDUCTOR", map_target => "NAMEA" },
          { map_source => "GPS", map_target => "USERA" },
          { map_source => "PARTICIPANT", map_target => "NAMEA" },
          { map_source => "USERB", map_target => "USERD" },
        ],
        maptype => "field",
        per_datasource => [{ content => "examples.bib" }],
      },
      {
        also_set => [
                      { bmap_origfield => 1, map_field => "EPRINTTYPE" },
                      { map_field => "USERD", map_value => "Some string of things" },
                    ],
        map_pair => [{ map_source => "PUBMEDID", map_target => "EPRINT" }],
        maptype  => "field",
      },
      {
        map_pair => [
          {
            map_match   => "\\A(\\S{2})",
            map_replace => "REP\$1CED",
            map_source  => "LISTB",
          },
        ],
        maptype => "field",
        per_datasource => [{ content => "examples.bib" }],
      },
      {
        map_pair => [{ bmap_null => 1, map_source => "LISTA" }],
        maptype  => "field",
        per_type => [{ content => "REPORT" }],
      },
      {
        map_pair => [
                      {
                        map_match   => "\\A(\\S{2})",
                        map_replace => "REP\$1CED",
                        map_source  => "LISTC",
                        map_target  => "INSTITUTION",
                      },
                    ],
        maptype  => "field",
        per_type => [{ content => "UNPUBLISHED" }],
      },
      {
        map_pair => [{ bmap_null => 1, map_source => "TITLE" }],
        maptype  => "field",
        per_type => [{ content => "ONLINE" }],
      },
    ],
  },
  {
    bmap_overwrite => 1,
    datatype => "endnotexml",
    map => [
      {
        also_set       => [{ bmap_origentrytype => 1, map_field => "USERA" }],
        map_pair       => [{ map_source => "journal Article", map_target => "REPORT" }],
        maptype        => "entrytype",
        per_datasource => [{ content => "endnote.xml" }],
      },
      {
        map_pair       => [
                            { map_match => 64, map_replace => 66, map_source => "PAGES" },
                          ],
        maptype        => "field",
        per_datasource => [{ content => "endnote.xml" }],
        per_type       => [{ content => "Journal Article" }],
      },
      {
        map_pair => [{ bmap_null => 1, map_source => "ABSTRACT" }],
        maptype => "field",
        per_datasource => [{ content => "endnote.xml" }],
      },
    ],
  },
  {
    bmap_overwrite => 0,
    datatype => "ris",
    map => [
      {
        map_pair => [{ map_source => "JOUR", map_target => "REPORT" }],
        maptype => "entrytype",
        per_datasource => [{ content => "ris1.ris" }],
      },
      {
        bmap_overwrite => 1,
        also_set => [{ map_field => "KEYWORDS", map_value => "somevalue" }],
        map_pair => [{ map_source => "BOOK", map_target => "MAPBOOK" }],
        maptype  => "entrytype",
      },
      {
        map_pair => [{ bmap_null => 1, map_source => "N2" }],
        maptype => "field",
        per_datasource => [{ content => "ris1.ris" }],
      },
      {
        map_pair       => [
                            {
                              map_match   => "Neurosurg\\.",
                              map_replace => "Neurosurgery",
                              map_source  => "JO",
                            },
                          ],
        maptype        => "field",
        per_datasource => [{ content => "ris1.ris" }],
        per_type       => [{ content => "JOUR" }],
      },
    ],
  },
  {
    bmap_overwrite => 1,
    datatype => "zoterordfxml",
    map => [
      {
        map_pair => [
                      { map_match => "(.+)", map_replace => "\\L\$1", map_source => "dc:title" },
                    ],
        maptype  => "field",
        per_type => [{ content => "journalArticle" }],
      },
      {
        map_pair       => [{ bmap_null => 1, map_source => "dc:subject" }],
        maptype        => "field",
        per_datasource => [{ content => "zotero.rdf" }],
        per_type       => [
                            { content => "journalArticle" },
                            { content => "book" },
                            { content => "bookSection" },
                          ],
      },
    ],
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
