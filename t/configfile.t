# -*- cperl -*-
use strict;
use warnings;
use utf8;

use Test::More tests => 9;
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

my $collopts = { level => 3,
                 variable => 'non-ignorable',
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
    datatype => "endnotexml",
    level    => "user",
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
    datatype => "zoterordfxml",
    level    => "user",
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
    datatype => "endnotexml",
    level => "driver",
    map => [
      {
        map_step => [
          {
            map_final       => 1,
            map_type_source => "Aggregated Database",
            map_type_target => "misc",
          },
          {
            map_final       => 1,
            map_type_source => "Ancient Text",
            map_type_target => "misc",
          },
          {
            map_final       => 1,
            map_type_source => "Artwork",
            map_type_target => "artwork",
          },
          {
            map_final       => 1,
            map_type_source => "Audiovisual Material",
            map_type_target => "misc",
          },
          {
            map_final       => 1,
            map_type_source => "Bill",
            map_type_target => "jurisdiction",
          },
          { map_final => 1, map_type_source => "Blog", map_type_target => "online" },
          { map_final => 1, map_type_source => "Book", map_type_target => "book" },
          {
            map_final       => 1,
            map_type_source => "Book Section",
            map_type_target => "inbook",
          },
          {
            map_final       => 1,
            map_type_source => "Case",
            map_type_target => "jurisdiction",
          },
          { map_final => 1, map_type_source => "Catalog", map_type_target => "misc" },
          {
            map_final       => 1,
            map_type_source => "Chart or Table",
            map_type_target => "misc",
          },
          {
            map_final       => 1,
            map_type_source => "Classical Work",
            map_type_target => "misc",
          },
          {
            map_final       => 1,
            map_type_source => "Computer Program",
            map_type_target => "software",
          },
          {
            map_final       => 1,
            map_type_source => "Conference Paper",
            map_type_target => "inproceedings",
          },
          {
            map_final       => 1,
            map_type_source => "Conference Proceedings",
            map_type_target => "proceedings",
          },
          {
            map_final       => 1,
            map_type_source => "Dictionary",
            map_type_target => "inreference",
          },
          {
            map_final       => 1,
            map_type_source => "Edited Book",
            map_type_target => "collection",
          },
          {
            map_final       => 1,
            map_type_source => "Electronic Article",
            map_type_target => "article",
          },
          {
            map_final       => 1,
            map_type_source => "Electronic Book",
            map_type_target => "book",
          },
          {
            map_final       => 1,
            map_type_source => "Encyclopedia",
            map_type_target => "reference",
          },
          {
            map_final       => 1,
            map_type_source => "Equation",
            map_type_target => "misc",
          },
          { map_final => 1, map_type_source => "Figure", map_type_target => "misc" },
          {
            map_final       => 1,
            map_type_source => "Film or Broadcast",
            map_type_target => "movie",
          },
          {
            map_final       => 1,
            map_type_source => "Government Document",
            map_type_target => "report",
          },
          { map_final => 1, map_type_source => "Grant", map_type_target => "misc" },
          {
            map_final       => 1,
            map_type_source => "Hearing",
            map_type_target => "jurisdiction",
          },
          {
            map_final       => 1,
            map_type_source => "Journal Article",
            map_type_target => "article",
          },
          {
            map_final       => 1,
            map_type_source => "Legal Rule or Regulation",
            map_type_target => "legislation",
          },
          {
            map_final       => 1,
            map_type_source => "Magazine Article",
            map_type_target => "article",
          },
          {
            map_final       => 1,
            map_type_source => "Manuscript",
            map_type_target => "unpublished",
          },
          { map_final => 1, map_type_source => "Map", map_type_target => "misc" },
          {
            map_final       => 1,
            map_type_source => "Newspaper Article",
            map_type_target => "article",
          },
          {
            map_final       => 1,
            map_type_source => "Online Database",
            map_type_target => "online",
          },
          {
            map_final       => 1,
            map_type_source => "Online Multimedia",
            map_type_target => "online",
          },
          {
            map_final       => 1,
            map_type_source => "Pamphlet",
            map_type_target => "booklet",
          },
          {
            map_final       => 1,
            map_type_source => "Patent",
            map_type_target => "patent",
          },
          {
            map_final       => 1,
            map_type_source => "Personal Communication",
            map_type_target => "letter",
          },
          {
            map_final       => 1,
            map_type_source => "Report",
            map_type_target => "report",
          },
          {
            map_final       => 1,
            map_type_source => "Serial",
            map_type_target => "periodical",
          },
          {
            map_final       => 1,
            map_type_source => "Standard",
            map_type_target => "standard",
          },
          {
            map_final       => 1,
            map_type_source => "Statute",
            map_type_target => "legislation",
          },
          {
            map_final       => 1,
            map_type_source => "Thesis",
            map_type_target => "thesis",
          },
          {
            map_final       => 1,
            map_type_source => "Unpublished Work",
            map_type_target => "unpublished",
          },
          {
            map_final       => 1,
            map_type_source => "Web Page",
            map_type_target => "online",
          },
        ],
      },
      {
        map_step => [
          {
            map_field_source => "electronic-resource-num",
            map_field_target => "eprint",
            map_final => 1,
          },
          {
            map_field_source => "alt-title",
            map_field_target => "shorttitle",
            map_final => 1,
          },
          {
            map_field_source => "meeting-place",
            map_field_target => "venue",
            map_final => 1,
          },
          {
            map_field_source => "pub-location",
            map_field_target => "location",
            map_final => 1,
          },
          {
            map_field_source => "orig-pub",
            map_field_target => "origpublisher",
            map_final => 1,
          },
          {
            map_field_source => "authors",
            map_field_target => "author",
            map_final => 1,
          },
          {
            map_field_source => "secondary-authors",
            map_field_target => "editor",
            map_final => 1,
          },
          {
            map_field_source => "tertiary-authors",
            map_field_target => "commentator",
            map_final => 1,
          },
          {
            map_field_source => "subsidiary-authors",
            map_field_target => "translator",
            map_final => 1,
          },
          { map_field_source => "year", map_field_target => "date", map_final => 1 },
          {
            map_field_source => "pub-dates",
            map_field_target => "date",
            map_final => 1,
          },
          {
            map_field_source => "num-vols",
            map_field_target => "volumes",
            map_final => 1,
          },
          {
            map_field_source => "call-num",
            map_field_target => "library",
            map_final => 1,
          },
          { map_field_source => "notes", map_field_target => "note", map_final => 1 },
          {
            map_field_source => "secondary-title",
            map_field_target => "subtitle",
            map_final => 1,
          },
          {
            map_field_source => "work-type",
            map_field_target => "type",
            map_final => 1,
          },
        ],
      },
      {
        map_step => [
                      { map_field_source => "authors", map_field_target => "editor" },
                    ],
        per_type => [{ content => "Edited Book" }],
      },
      {
        map_step => [{ map_field_source => "isbn", map_field_target => "issn" }],
        per_type => [
                      { content => "Electronic Article" },
                      { content => "Journal Article" },
                      { content => "Magazine Article" },
                      { content => "Newspaper Article" },
                    ],
      },
      {
        map_step => [{ map_field_source => "isbn", map_field_target => "number" }],
        per_type => [
                      { content => "Patent" },
                      { content => "Report" },
                      { content => "Government Document" },
                      { content => "Legal Rule or Regulation" },
                    ],
      },
      {
        map_step => [
                      { map_field_source => "secondary-title", map_field_target => "title" },
                    ],
        per_type => [
                      { content => "Blog" },
                      { content => "Online Database" },
                      { content => "Online Multimedia" },
                      { content => "Web Page" },
                    ],
      },
      {
        map_step => [
                      {
                        map_field_source => "secondary-title",
                        map_field_target => "booktitle",
                      },
                    ],
        per_type => [{ content => "Book Section" }],
      },
      {
        map_step => [
                      { map_field_source => "secondary-title", map_field_target => "series" },
                    ],
        per_type => [
                      { content => "Book" },
                      { content => "Electronic Book" },
                      { content => "Manuscript" },
                      { content => "Unpublished Work" },
                    ],
      },
      {
        map_step => [
                      {
                        map_field_source => "secondary-title",
                        map_field_target => "eventtitle",
                      },
                    ],
        per_type => [
                      { content => "Conference Paper" },
                      { content => "Conference Proceedings" },
                    ],
      },
      {
        map_step => [
                      {
                        map_field_source => "secondary-title",
                        map_field_target => "journaltitle",
                      },
                    ],
        per_type => [
                      { content => "Electronic Article" },
                      { content => "Journal Article" },
                      { content => "Magazine Article" },
                      { content => "Newspaper Article" },
                    ],
      },
      {
        map_step => [
                      {
                        map_field_source => "tertiary-title",
                        map_field_target => "booktitle",
                      },
                    ],
        per_type => [{ content => "Book Section" }],
      },
      {
        map_step => [
                      { map_field_source => "tertiary-title", map_field_target => "series" },
                    ],
        per_type => [
                      { content => "Conference Proceedings" },
                      { content => "periodical" },
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
  {
    datatype => "zoterordfxml",
    level => "driver",
    map => [
      {
        map_step => [
          {
            map_final       => 1,
            map_type_source => "conferencePaper",
            map_type_target => "inproceedings",
          },
          {
            map_final       => 1,
            map_type_source => "bookSection",
            map_type_target => "inbook",
          },
          {
            map_final       => 1,
            map_type_source => "journalArticle",
            map_type_target => "article",
          },
          {
            map_final       => 1,
            map_type_source => "magazineArticle",
            map_type_target => "article",
          },
          {
            map_final       => 1,
            map_type_source => "newspaperArticle",
            map_type_target => "article",
          },
          {
            map_final       => 1,
            map_type_source => "encyclopediaArticle",
            map_type_target => "inreference",
          },
          {
            map_final       => 1,
            map_type_source => "manuscript",
            map_type_target => "unpublished",
          },
          {
            map_final       => 1,
            map_type_source => "document",
            map_type_target => "misc",
          },
          {
            map_final       => 1,
            map_type_source => "dictionaryEntry",
            map_type_target => "inreference",
          },
          {
            map_final       => 1,
            map_type_source => "interview",
            map_type_target => "misc",
          },
          { map_final => 1, map_type_source => "film", map_type_target => "movie" },
          {
            map_final       => 1,
            map_type_source => "webpage",
            map_type_target => "online",
          },
          { map_final => 1, map_type_source => "note", map_type_target => "misc" },
          {
            map_final       => 1,
            map_type_source => "attachment",
            map_type_target => "misc",
          },
          {
            map_final       => 1,
            map_type_source => "bill",
            map_type_target => "legislation",
          },
          {
            map_final       => 1,
            map_type_source => "case",
            map_type_target => "jurisdiction",
          },
          {
            map_final       => 1,
            map_type_source => "hearing",
            map_type_target => "jurisdiction",
          },
          {
            map_final       => 1,
            map_type_source => "statute",
            map_type_target => "legislation",
          },
          { map_final => 1, map_type_source => "email", map_type_target => "letter" },
          { map_final => 1, map_type_source => "map", map_type_target => "image" },
          {
            map_final       => 1,
            map_type_source => "blogPost",
            map_type_target => "online",
          },
          {
            map_final       => 1,
            map_type_source => "instantMessage",
            map_type_target => "letter",
          },
          {
            map_final       => 1,
            map_type_source => "forumPost",
            map_type_target => "online",
          },
          {
            map_final       => 1,
            map_type_source => "audioRecording",
            map_type_target => "audio",
          },
          {
            map_final       => 1,
            map_type_source => "presentation",
            map_type_target => "inproceedings",
          },
          {
            map_final       => 1,
            map_type_source => "videoRecording",
            map_type_target => "video",
          },
          {
            map_final       => 1,
            map_type_source => "tvBroadcast",
            map_type_target => "misc",
          },
          {
            map_final       => 1,
            map_type_source => "radioBroadcast",
            map_type_target => "misc",
          },
          {
            map_final       => 1,
            map_type_source => "podcast",
            map_type_target => "online",
          },
          {
            map_final       => 1,
            map_type_source => "computerProgram",
            map_type_target => "software",
          },
        ],
      },
      {
        map_step => [
          {
            map_field_source => "bib:contributors",
            map_field_target => "author",
          },
          { map_field_source => "bib:authors", map_field_target => "author" },
          { map_field_source => "z:interviewers", map_field_target => "author" },
          { map_field_source => "z:directors", map_field_target => "author" },
          { map_field_source => "z:scriptwriters", map_field_target => "author" },
          { map_field_source => "z:bookAuthor", map_field_target => "author" },
          { map_field_source => "z:inventors", map_field_target => "author" },
          { map_field_source => "z:recipients", map_field_target => "author" },
          { map_field_source => "z:counsels", map_field_target => "author" },
          { map_field_source => "z:artists", map_field_target => "author" },
          { map_field_source => "z:podcasters", map_field_target => "author" },
          { map_field_source => "z:presenters", map_field_target => "author" },
          { map_field_source => "z:commenters", map_field_target => "author" },
          { map_field_source => "z:programers", map_field_target => "author" },
          { map_field_source => "z:composers", map_field_target => "author" },
          { map_field_source => "z:producers", map_field_target => "author" },
          { map_field_source => "z:performers", map_field_target => "author" },
          { map_field_source => "bib:editors", map_field_target => "editor" },
          {
            map_field_source => "z:translators",
            map_field_target => "translator",
          },
          { map_field_source => "z:seriesEditors", map_field_target => "editor" },
          { map_field_source => "dc:date", map_field_target => "date" },
          { map_field_source => "bib:pages", map_field_target => "pages" },
          { map_field_source => "dc:title", map_field_target => "title" },
          {
            map_field_source => "z:proceedingsTitle",
            map_field_target => "title",
          },
          {
            map_field_source => "z:encyclopediaTitle",
            map_field_target => "title",
          },
          {
            map_field_source => "z:dictionaryTitle",
            map_field_target => "title",
          },
          { map_field_source => "z:websiteTitle", map_field_target => "title" },
          { map_field_source => "z:forumTitle", map_field_target => "title" },
          { map_field_source => "z:blogTitle", map_field_target => "title" },
          { map_field_source => "z:nameOfAct", map_field_target => "title" },
          { map_field_source => "z:caseName", map_field_target => "title" },
          {
            map_field_source => "z:meetingName",
            map_field_target => "eventtitle",
          },
          { map_field_source => "prism:volume", map_field_target => "volume" },
          {
            map_field_source => "numberOfVolumes",
            map_field_target => "volumes",
          },
          { map_field_source => "z:numPages", map_field_target => "pagetotal" },
          { map_field_source => "prism:edition", map_field_target => "edition" },
          { map_field_source => "dc:description", map_field_target => "note" },
          {
            map_field_source => "dc:alternative",
            map_field_target => "shortjournal",
          },
          {
            map_field_source => "dcterms:abstract",
            map_field_target => "abstract",
          },
          { map_field_source => "dc:type", map_field_target => "type" },
          {
            map_field_source => "z:shortTitle",
            map_field_target => "shorttitle",
          },
          { map_field_source => "z:bookTitle", map_field_target => "booktitle" },
          { map_field_source => "prism:number", map_field_target => "number" },
          { map_field_source => "z:patentNumber", map_field_target => "number" },
          { map_field_source => "z:codeNumber", map_field_target => "number" },
          { map_field_source => "z:reportNumber", map_field_target => "number" },
          { map_field_source => "z:billNumber", map_field_target => "number" },
          {
            map_field_source => "z:documentNumber",
            map_field_target => "number",
          },
          {
            map_field_source => "z:publicLawNumber",
            map_field_target => "number",
          },
          {
            map_field_source => "z:applicationNumber",
            map_field_target => "number",
          },
          { map_field_source => "z:episodeNumber", map_field_target => "number" },
          { map_field_source => "dc:coverage", map_field_target => "location" },
          {
            map_field_source => "z:university",
            map_field_target => "institution",
          },
          { map_field_source => "z:language", map_field_target => "language" },
          { map_field_source => "z:version", map_field_target => "version" },
          {
            map_field_source => "z:libraryCatalog",
            map_field_target => "library",
          },
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
is_deeply(Biber::Config->getoption('noinit'), $noinit, 'Options 6 - from config file');
is_deeply(Biber::Config->getoption('sortcase'), 0, 'Options 7 - from .bcf');
is(Biber::Config->getoption('decodecharsset'), 'base', 'Options 8 - from defaults');
# Here the result is a merge of the biblatex option from the .bcf and the option from
# the biber config file as sourcemap is a special case
is_deeply(Biber::Config->getoption('sourcemap'), $sourcemap, 'Options 9 - from config file');
