package Biber::Constants;
use strict;
use warnings;
use Encode::Alias;
use Readonly;

use base 'Exporter';

our @EXPORT = qw{
  @NAMEFIELDS
  @LISTFIELDS
  @LITERALFIELDS_BASE
  @RANGEFIELDS
  @VERBATIMFIELDS
  @TITLEFIELDS
  @KEYFIELDS
  @COMMASEP_FIELDS
  @ENTRIESTOSPLIT
  @LITERALFIELDS
  @DATERANGEFIELDS
  @DATECOMPONENTFIELDS
  @NULL_OK
  %SKIPFIELDS
  %CONFIG_DEFAULT_BIBER
  %CONFIG_DEFAULT_BIBLATEX
  %CONFIG_SCOPE_BIBLATEX
  $BIBER_CONF_NAME
  $BIBLATEX_VERSION
  $BIBER_SORT_FINAL
  $BIBER_SORT_NULL
  $BIBER_SORT_FIRSTPASSDONE
  %BIBER_DATAFILE_REFS
  %NUMERICALMONTH
  %DISPLAYMODES
  $DISPLAYMODE_DEFAULT
  } ;

# Version of biblatex which this release works with. Matched against version
# passed in control file
Readonly::Scalar our $BIBLATEX_VERSION => '1.0';

# Global flags needed for sorting
our $BIBER_SORT_FINAL = 0;
our $BIBER_SORT_NULL  = 0;
our $BIBER_SORT_FIRSTPASSDONE = 0;

# the name of the Biber configuration file, which should be
# either returned by kpsewhich or located at "$HOME/.$BIBER_CONF_NAME"
our $BIBER_CONF_NAME = 'biber.conf';

Readonly::Scalar our $DISPLAYMODE_DEFAULT => 'uniform';

## Biber CONFIGURATION DEFAULTS

# Locale - first try environment ...
my $locale;
if ($ENV{LC_COLLATE}) {
  $locale = $ENV{LC_COLLATE};
}
elsif ($ENV{LANG}) {
  $locale = $ENV{LANG};
}
elsif ($ENV{LC_ALL}) {
  $locale = $ENV{LC_ALL};
}

# ... if nothing, set a default
unless ($locale) {
  if ( $^O =~ /Win/) {
    $locale = 'English_United States.1252';
  }
  else {
    $locale = 'en_US.UTF-8';
  }
}

our %CONFIG_DEFAULT_BIBER = (
  allentries       => 0,
  bblencoding      => 'UTF-8',
  bibdata          =>  undef,
  bibdatatype      => 'bibtex',
  bibencoding      => 'UTF-8',
  collate          => 1,
  collate_options  => { level => 4 },
  debug            => 0,
  displaymode      => $DISPLAYMODE_DEFAULT, # eventually, shall be moved to biblatex options
  mincrossrefs     => 2,
  nolog            => 0,
  nosortdiacritics => qr/[\x{2bf}\x{2018}]/,
  nosortprefix     => qr/\p{L}{2}\p{Pd}/,
  quiet            => 0,
  sortcase         => 1,
  sortlocale       => $locale,
  sortupper        => 1,
  trace            => 0,
  wraplines        => 0,
  validate         => 0
  );

# default global options for biblatex
# in practice these will be obtained from the control file,
# but we need this as a fallback, just in case,
# or when using the command-line options "-a -d <datafile>"
# without a bcf file
our %CONFIG_DEFAULT_BIBLATEX =
  (
   alphaothers     => '\textbf{+}',
   controlversion  => undef,
   debug           => '0',
   labelalpha      => '0',
   labelname       => ['shortauthor', 'author', 'shorteditor', 'editor', 'translator'],
   labelnumber     => '0',
   labelyear       => [ 'year' ],
   maxitems        => '3',
   maxnames        => '3',
   minitems        => '1',
   minnames        => '1',
   singletitle     => '0',
   sortalphaothers => '+',
   sortlos         => '1',
   terseinits      => '0',
   uniquename      => '0',
   useauthor       => '1',
   useeditor       => '1',
   useprefix       => '0',
   usetranslator   => '0',
   # Now the defaults for special .bcf sections information
   inheritance     => {
                   defaults => {
                                inherit_all     => 'yes',
                                override_target => 'no',
                                type_pair => []
                               },
                   inherit => [
                               {
                                type_pair => [
                                               {
                                                source => 'proceedings',
                                                target => 'inproceedings'
                                               },
                                               {
                                                source => 'collection',
                                                target => 'incollection',
                                               },
                                               {
                                                source => 'book',
                                                target => 'inbook',
                                               }
                                              ],
                                field => [
                                           {
                                            source => 'title',
                                            target => 'booktitle',
                                            override_target => 'yes',
                                           },
                                           {
                                            source => 'subtitle',
                                            target => 'booksubtitle',
                                            override_target => 'yes',
                                           },
                                           {
                                            source => 'titleaddon',
                                            target => 'booktitleaddon',
                                            override_target => 'yes',
                                           },
                                          ]
                               },
                               {
                                type_pair => [
                                               {
                                                source => 'book',
                                                target => 'inbook',
                                               }
                                              ],
                                field => [
                                           {
                                            source => 'author',
                                            target => 'bookauthor',
                                            override_target => 'yes',
                                           },
                                          ]
                               },
                              ]
                  },
   sorting_label   =>  [
                [
                 {
                  'presort'    => {}},
                 {
                  'mm'         => {}},
                ],
                [
                 {
                  'sortkey'    => {'final' => 1}}
                ],
                [
                 {
                  'sortname'   => {}},
                 {
                  'author'     => {}},
                 {
                  'editor'     => {}},
                 {
                  'translator' => {}},
                 {
                  'sorttitle'  => {}},
                 {
                  'title'      => {}}
                ],
                [
                 {
                  'sortyear'   => {}},
                 {
                  'year'       => {}}
                ],
                [
                 {
                  'sorttitle'  => {}},
                 {
                  'title'      => {}}
                ],
                [
                 {
                  'volume'     => {}},
                 {
                  '0000'       => {}}
                ]
               ],
   structure => {
  aliases => {
    alias => [
      {
        name => { content => "conference" },
        realname => { content => "inproceedings" },
        type => "entrytype",
      },
      {
        name => { content => "electronic" },
        realname => { content => "online" },
        type => "entrytype",
      },
      {
        field    => [{ content => "mathesis", name => "type" }],
        name     => { content => "mastersthesis" },
        realname => { content => "thesis" },
        type     => "entrytype",
      },
      {
        field    => [{ content => "phdthesis", name => "type" }],
        name     => { content => "phdthesis" },
        realname => { content => "thesis" },
        type     => "entrytype",
      },
      {
        field    => [{ content => "techreport", name => "type" }],
        name     => { content => "techreport" },
        realname => { content => "report" },
        type     => "entrytype",
      },
      {
        name => { content => "www" },
        realname => { content => "online" },
        type => "entrytype",
      },
      {
        name => { content => "address" },
        realname => { content => "location" },
        type => "field",
      },
      {
        name => { content => "archiveprefix" },
        realname => { content => "eprinttype" },
        type => "field",
      },
      {
        name => { content => "primaryclass" },
        realname => { content => "eprintclass" },
        type => "field",
      },
      {
        name => { content => "school" },
        realname => { content => "institution" },
        type => "field",
      },
      {
        name => { content => "annote" },
        realname => { content => "annotation" },
        type => "field",
      },
      {
        name => { content => "key" },
        realname => { content => "sortkey" },
        type => "field",
      },
    ],
  },
  constraints => [
    { entrytypes => { entrytype => [{ content => "artwork" }] } },
    { entrytypes => { entrytype => [{ content => "audio" }] } },
    { entrytypes => { entrytype => [{ content => "commentary" }] } },
    { entrytypes => { entrytype => [{ content => "image" }] } },
    { entrytypes => { entrytype => [{ content => "jurisdiction" }] } },
    { entrytypes => { entrytype => [{ content => "legislation" }] } },
    { entrytypes => { entrytype => [{ content => "legal" }] } },
    { entrytypes => { entrytype => [{ content => "letter" }] } },
    { entrytypes => { entrytype => [{ content => "movie" }] } },
    { entrytypes => { entrytype => [{ content => "music" }] } },
    { entrytypes => { entrytype => [{ content => "performance" }] } },
    { entrytypes => { entrytype => [{ content => "review" }] } },
    { entrytypes => { entrytype => [{ content => "software" }] } },
    { entrytypes => { entrytype => [{ content => "standard" }] } },
    { entrytypes => { entrytype => [{ content => "video" }] } },
    { entrytypes => { entrytype => [{ content => "customa" }] } },
    { entrytypes => { entrytype => [{ content => "customb" }] } },
    { entrytypes => { entrytype => [{ content => "customc" }] } },
    { entrytypes => { entrytype => [{ content => "customd" }] } },
    { entrytypes => { entrytype => [{ content => "custome" }] } },
    { entrytypes => { entrytype => [{ content => "customf" }] } },
    {
      constraint => [
                      { field => [{ content => "entryset" }], type => "mandatory" },
                      { field => [{ content => "crossref" }], type => "mandatory" },
                      {
                        antecedent => { field => [{ content => "date" }], quant => "all" },
                        consequent => {
                          field => [{ conflict => "suppress", content => "month" }],
                          quant => "none",
                        },
                        type => "conditional",
                      },
                    ],
      entrytypes => { entrytype => [{ content => "set" }] },
    },
    {
      constraint => [
                      { field => [{ content => "author" }], type => "mandatory" },
                      { field => [{ content => "journaltitle" }], type => "mandatory" },
                      { field => [{ content => "title" }], type => "mandatory" },
                      {
                        field => [
                                   { conflict => "suppress", content => "year" },
                                   { content => "date" },
                                 ],
                        type  => "mandatory",
                      },
                      {
                        antecedent => { field => [{ content => "date" }], quant => "all" },
                        consequent => {
                          field => [{ conflict => "suppress", content => "month" }],
                          quant => "none",
                        },
                        type => "conditional",
                      },
                      { field => [{ content => "addendum" }], type => "optional" },
                      { field => [{ content => "annotator" }], type => "optional" },
                      { field => [{ content => "commentator" }], type => "optional" },
                      { field => [{ content => "doi" }], type => "optional" },
                      { field => [{ content => "editor" }], type => "optional" },
                      { field => [{ content => "editora" }], type => "optional" },
                      { field => [{ content => "editorb" }], type => "optional" },
                      { field => [{ content => "editorc" }], type => "optional" },
                      { field => [{ content => "eid" }], type => "optional" },
                      { field => [{ content => "eprint" }], type => "optional" },
                      { field => [{ content => "eprintclass" }], type => "optional" },
                      { field => [{ content => "eprinttype" }], type => "optional" },
                      { field => [{ content => "issn" }], type => "optional" },
                      { field => [{ content => "issue" }], type => "optional" },
                      { field => [{ content => "issuetitle" }], type => "optional" },
                      { field => [{ content => "issuesubtitle" }], type => "optional" },
                      { field => [{ content => "journalsubtitle" }], type => "optional" },
                      { field => [{ content => "language" }], type => "optional" },
                      {
                        field => [
                                   { content => "month", datatype => "integer", rangemax => 12, rangemin => 1 },
                                 ],
                        type  => "optional",
                      },
                      { field => [{ content => "note" }], type => "optional" },
                      { field => [{ content => "number" }], type => "optional" },
                      { field => [{ content => "origlanguage" }], type => "optional" },
                      { field => [{ content => "pages" }], type => "optional" },
                      { field => [{ content => "pubstate" }], type => "optional" },
                      { field => [{ content => "series" }], type => "optional" },
                      { field => [{ content => "subtitle" }], type => "optional" },
                      { field => [{ content => "titleaddon" }], type => "optional" },
                      { field => [{ content => "translator" }], type => "optional" },
                      { field => [{ content => "url" }], type => "optional" },
                      { field => [{ content => "urldate" }], type => "optional" },
                      { field => [{ content => "version" }], type => "optional" },
                      { field => [{ content => "volume" }], type => "optional" },
                    ],
      entrytypes => { entrytype => [{ content => "article" }] },
    },
    {
      constraint => [
                      { field => [{ content => "author" }], type => "mandatory" },
                      { field => [{ content => "title" }], type => "mandatory" },
                      {
                        field => [
                                   { conflict => "suppress", content => "year" },
                                   { content => "date" },
                                 ],
                        type  => "mandatory",
                      },
                      {
                        antecedent => { field => [{ content => "date" }], quant => "all" },
                        consequent => {
                          field => [{ conflict => "suppress", content => "month" }],
                          quant => "none",
                        },
                        type => "conditional",
                      },
                      { field => [{ content => "addendum" }], type => "optional" },
                      { field => [{ content => "afterword" }], type => "optional" },
                      { field => [{ content => "annotator" }], type => "optional" },
                      { field => [{ content => "chapter" }], type => "optional" },
                      { field => [{ content => "commentator" }], type => "optional" },
                      { field => [{ content => "doi" }], type => "optional" },
                      { field => [{ content => "edition" }], type => "optional" },
                      { field => [{ content => "editor" }], type => "optional" },
                      { field => [{ content => "editora" }], type => "optional" },
                      { field => [{ content => "editorb" }], type => "optional" },
                      { field => [{ content => "editorc" }], type => "optional" },
                      { field => [{ content => "eprint" }], type => "optional" },
                      { field => [{ content => "eprintclass" }], type => "optional" },
                      { field => [{ content => "eprinttype" }], type => "optional" },
                      { field => [{ content => "foreword" }], type => "optional" },
                      { field => [{ content => "introduction" }], type => "optional" },
                      { field => [{ content => "isbn" }], type => "optional" },
                      { field => [{ content => "language" }], type => "optional" },
                      { field => [{ content => "location" }], type => "optional" },
                      { field => [{ content => "maintitle" }], type => "optional" },
                      { field => [{ content => "maintitleaddon" }], type => "optional" },
                      { field => [{ content => "mainsubtitle" }], type => "optional" },
                      { field => [{ content => "note" }], type => "optional" },
                      { field => [{ content => "number" }], type => "optional" },
                      { field => [{ content => "origlanguage" }], type => "optional" },
                      { field => [{ content => "pages" }], type => "optional" },
                      { field => [{ content => "pagetotal" }], type => "optional" },
                      { field => [{ content => "part" }], type => "optional" },
                      { field => [{ content => "publisher" }], type => "optional" },
                      { field => [{ content => "pubstate" }], type => "optional" },
                      { field => [{ content => "series" }], type => "optional" },
                      { field => [{ content => "subtitle" }], type => "optional" },
                      { field => [{ content => "titleaddon" }], type => "optional" },
                      { field => [{ content => "translator" }], type => "optional" },
                      { field => [{ content => "url" }], type => "optional" },
                      { field => [{ content => "urldate" }], type => "optional" },
                      { field => [{ content => "volume" }], type => "optional" },
                      { field => [{ content => "volumes" }], type => "optional" },
                    ],
      entrytypes => { entrytype => [{ content => "book" }] },
    },
    {
      constraint => [
                      { field => [{ content => "author" }], type => "mandatory" },
                      { field => [{ content => "title" }], type => "mandatory" },
                      { field => [{ content => "booktitle" }], type => "mandatory" },
                      {
                        field => [
                                   { conflict => "suppress", content => "year" },
                                   { content => "date" },
                                 ],
                        type  => "mandatory",
                      },
                      {
                        antecedent => { field => [{ content => "date" }], quant => "all" },
                        consequent => {
                          field => [{ conflict => "suppress", content => "month" }],
                          quant => "none",
                        },
                        type => "conditional",
                      },
                      { field => [{ content => "addendum" }], type => "optional" },
                      { field => [{ content => "afterword" }], type => "optional" },
                      { field => [{ content => "annotator" }], type => "optional" },
                      { field => [{ content => "bookauthor" }], type => "optional" },
                      { field => [{ content => "booksubtitle" }], type => "optional" },
                      { field => [{ content => "booktitleaddon" }], type => "optional" },
                      { field => [{ content => "chapter" }], type => "optional" },
                      { field => [{ content => "commentator" }], type => "optional" },
                      { field => [{ content => "doi" }], type => "optional" },
                      { field => [{ content => "edition" }], type => "optional" },
                      { field => [{ content => "editor" }], type => "optional" },
                      { field => [{ content => "editora" }], type => "optional" },
                      { field => [{ content => "editorb" }], type => "optional" },
                      { field => [{ content => "editorc" }], type => "optional" },
                      { field => [{ content => "eprint" }], type => "optional" },
                      { field => [{ content => "eprintclass" }], type => "optional" },
                      { field => [{ content => "eprinttype" }], type => "optional" },
                      { field => [{ content => "foreword" }], type => "optional" },
                      { field => [{ content => "introduction" }], type => "optional" },
                      { field => [{ content => "isbn" }], type => "optional" },
                      { field => [{ content => "language" }], type => "optional" },
                      { field => [{ content => "location" }], type => "optional" },
                      { field => [{ content => "mainsubtitle" }], type => "optional" },
                      { field => [{ content => "maintitle" }], type => "optional" },
                      { field => [{ content => "maintitleaddon" }], type => "optional" },
                      { field => [{ content => "note" }], type => "optional" },
                      { field => [{ content => "number" }], type => "optional" },
                      { field => [{ content => "origlanguage" }], type => "optional" },
                      { field => [{ content => "part" }], type => "optional" },
                      { field => [{ content => "publisher" }], type => "optional" },
                      { field => [{ content => "pages" }], type => "optional" },
                      { field => [{ content => "pubstate" }], type => "optional" },
                      { field => [{ content => "series" }], type => "optional" },
                      { field => [{ content => "subtitle" }], type => "optional" },
                      { field => [{ content => "titleaddon" }], type => "optional" },
                      { field => [{ content => "translator" }], type => "optional" },
                      { field => [{ content => "url" }], type => "optional" },
                      { field => [{ content => "urldate" }], type => "optional" },
                      { field => [{ content => "volume" }], type => "optional" },
                      { field => [{ content => "volumes" }], type => "optional" },
                    ],
      entrytypes => {
                      entrytype => [
                        { content => "inbook" },
                        { content => "bookinbook" },
                        { content => "suppbook" },
                      ],
                    },
    },
    {
      constraint => [
                      {
                        field => [{ content => "author" }, { content => "editor" }],
                        type  => "mandatory",
                      },
                      { field => [{ content => "title" }], type => "mandatory" },
                      {
                        field => [
                                   { conflict => "suppress", content => "year" },
                                   { content => "date" },
                                 ],
                        type  => "mandatory",
                      },
                      {
                        antecedent => { field => [{ content => "date" }], quant => "all" },
                        consequent => {
                          field => [{ conflict => "suppress", content => "month" }],
                          quant => "none",
                        },
                        type => "conditional",
                      },
                      { field => [{ content => "addendum" }], type => "optional" },
                      { field => [{ content => "chapter" }], type => "optional" },
                      { field => [{ content => "doi" }], type => "optional" },
                      { field => [{ content => "eprint" }], type => "optional" },
                      { field => [{ content => "eprintclass" }], type => "optional" },
                      { field => [{ content => "eprinttype" }], type => "optional" },
                      { field => [{ content => "howpublished" }], type => "optional" },
                      { field => [{ content => "language" }], type => "optional" },
                      { field => [{ content => "location" }], type => "optional" },
                      { field => [{ content => "note" }], type => "optional" },
                      { field => [{ content => "pages" }], type => "optional" },
                      { field => [{ content => "pagetotal" }], type => "optional" },
                      { field => [{ content => "pubstate" }], type => "optional" },
                      { field => [{ content => "subtitle" }], type => "optional" },
                      { field => [{ content => "titleaddon" }], type => "optional" },
                      { field => [{ content => "type" }], type => "optional" },
                      { field => [{ content => "url" }], type => "optional" },
                      { field => [{ content => "urldate" }], type => "optional" },
                    ],
      entrytypes => { entrytype => [{ content => "booklet" }] },
    },
    {
      constraint => [
                      { field => [{ content => "editor" }], type => "mandatory" },
                      { field => [{ content => "title" }], type => "mandatory" },
                      {
                        field => [
                                   { conflict => "suppress", content => "year" },
                                   { content => "date" },
                                 ],
                        type  => "mandatory",
                      },
                      {
                        antecedent => { field => [{ content => "date" }], quant => "all" },
                        consequent => {
                          field => [{ conflict => "suppress", content => "month" }],
                          quant => "none",
                        },
                        type => "conditional",
                      },
                      { field => [{ content => "addendum" }], type => "optional" },
                      { field => [{ content => "afterword" }], type => "optional" },
                      { field => [{ content => "annotator" }], type => "optional" },
                      { field => [{ content => "chapter" }], type => "optional" },
                      { field => [{ content => "commentator" }], type => "optional" },
                      { field => [{ content => "doi" }], type => "optional" },
                      { field => [{ content => "edition" }], type => "optional" },
                      { field => [{ content => "editora" }], type => "optional" },
                      { field => [{ content => "editorb" }], type => "optional" },
                      { field => [{ content => "editorc" }], type => "optional" },
                      { field => [{ content => "eprint" }], type => "optional" },
                      { field => [{ content => "eprintclass" }], type => "optional" },
                      { field => [{ content => "eprinttype" }], type => "optional" },
                      { field => [{ content => "foreword" }], type => "optional" },
                      { field => [{ content => "introduction" }], type => "optional" },
                      { field => [{ content => "isbn" }], type => "optional" },
                      { field => [{ content => "language" }], type => "optional" },
                      { field => [{ content => "location" }], type => "optional" },
                      { field => [{ content => "mainsubtitle" }], type => "optional" },
                      { field => [{ content => "maintitle" }], type => "optional" },
                      { field => [{ content => "maintitleaddon" }], type => "optional" },
                      { field => [{ content => "note" }], type => "optional" },
                      { field => [{ content => "number" }], type => "optional" },
                      { field => [{ content => "origlanguage" }], type => "optional" },
                      { field => [{ content => "pages" }], type => "optional" },
                      { field => [{ content => "pagetotal" }], type => "optional" },
                      { field => [{ content => "part" }], type => "optional" },
                      { field => [{ content => "publisher" }], type => "optional" },
                      { field => [{ content => "pubstate" }], type => "optional" },
                      { field => [{ content => "series" }], type => "optional" },
                      { field => [{ content => "subtitle" }], type => "optional" },
                      { field => [{ content => "titleaddon" }], type => "optional" },
                      { field => [{ content => "translator" }], type => "optional" },
                      { field => [{ content => "url" }], type => "optional" },
                      { field => [{ content => "urldate" }], type => "optional" },
                      { field => [{ content => "volume" }], type => "optional" },
                      { field => [{ content => "volumes" }], type => "optional" },
                    ],
      entrytypes => {
                      entrytype => [{ content => "collection" }, { content => "reference" }],
                    },
    },
    {
      constraint => [
                      { field => [{ content => "author" }], type => "mandatory" },
                      { field => [{ content => "editor" }], type => "mandatory" },
                      { field => [{ content => "title" }], type => "mandatory" },
                      { field => [{ content => "booktitle" }], type => "mandatory" },
                      {
                        field => [
                                   { conflict => "suppress", content => "year" },
                                   { content => "date" },
                                 ],
                        type  => "mandatory",
                      },
                      {
                        antecedent => { field => [{ content => "date" }], quant => "all" },
                        consequent => {
                          field => [{ conflict => "suppress", content => "month" }],
                          quant => "none",
                        },
                        type => "conditional",
                      },
                      { field => [{ content => "addendum" }], type => "optional" },
                      { field => [{ content => "afterword" }], type => "optional" },
                      { field => [{ content => "annotator" }], type => "optional" },
                      { field => [{ content => "booksubtitle" }], type => "optional" },
                      { field => [{ content => "booktitleaddon" }], type => "optional" },
                      { field => [{ content => "chapter" }], type => "optional" },
                      { field => [{ content => "commentator" }], type => "optional" },
                      { field => [{ content => "doi" }], type => "optional" },
                      { field => [{ content => "edition" }], type => "optional" },
                      { field => [{ content => "editora" }], type => "optional" },
                      { field => [{ content => "editorb" }], type => "optional" },
                      { field => [{ content => "editorc" }], type => "optional" },
                      { field => [{ content => "eprint" }], type => "optional" },
                      { field => [{ content => "eprintclass" }], type => "optional" },
                      { field => [{ content => "eprinttype" }], type => "optional" },
                      { field => [{ content => "foreword" }], type => "optional" },
                      { field => [{ content => "introduction" }], type => "optional" },
                      { field => [{ content => "isbn" }], type => "optional" },
                      { field => [{ content => "language" }], type => "optional" },
                      { field => [{ content => "location" }], type => "optional" },
                      { field => [{ content => "mainsubtitle" }], type => "optional" },
                      { field => [{ content => "maintitle" }], type => "optional" },
                      { field => [{ content => "maintitleaddon" }], type => "optional" },
                      { field => [{ content => "note" }], type => "optional" },
                      { field => [{ content => "number" }], type => "optional" },
                      { field => [{ content => "origlanguage" }], type => "optional" },
                      { field => [{ content => "pages" }], type => "optional" },
                      { field => [{ content => "part" }], type => "optional" },
                      { field => [{ content => "publisher" }], type => "optional" },
                      { field => [{ content => "pubstate" }], type => "optional" },
                      { field => [{ content => "series" }], type => "optional" },
                      { field => [{ content => "subtitle" }], type => "optional" },
                      { field => [{ content => "titleaddon" }], type => "optional" },
                      { field => [{ content => "translator" }], type => "optional" },
                      { field => [{ content => "url" }], type => "optional" },
                      { field => [{ content => "urldate" }], type => "optional" },
                      { field => [{ content => "volume" }], type => "optional" },
                      { field => [{ content => "volumes" }], type => "optional" },
                    ],
      entrytypes => {
                      entrytype => [
                        { content => "incollection" },
                        { content => "suppcollection" },
                        { content => "inreference" },
                      ],
                    },
    },
    {
      constraint => [
                      { field => [{ content => "title" }], type => "mandatory" },
                      {
                        field => [
                                   { conflict => "suppress", content => "year" },
                                   { content => "date" },
                                 ],
                        type  => "mandatory",
                      },
                      {
                        antecedent => { field => [{ content => "date" }], quant => "all" },
                        consequent => {
                          field => [{ conflict => "suppress", content => "month" }],
                          quant => "none",
                        },
                        type => "conditional",
                      },
                      { field => [{ content => "addendum" }], type => "optional" },
                      { field => [{ content => "author" }], type => "optional" },
                      { field => [{ content => "chapter" }], type => "optional" },
                      { field => [{ content => "doi" }], type => "optional" },
                      { field => [{ content => "edition" }], type => "optional" },
                      { field => [{ content => "editor" }], type => "optional" },
                      { field => [{ content => "eprint" }], type => "optional" },
                      { field => [{ content => "eprintclass" }], type => "optional" },
                      { field => [{ content => "eprinttype" }], type => "optional" },
                      { field => [{ content => "isbn" }], type => "optional" },
                      { field => [{ content => "language" }], type => "optional" },
                      { field => [{ content => "location" }], type => "optional" },
                      { field => [{ content => "note" }], type => "optional" },
                      { field => [{ content => "number" }], type => "optional" },
                      { field => [{ content => "organization" }], type => "optional" },
                      { field => [{ content => "pages" }], type => "optional" },
                      { field => [{ content => "pagetotal" }], type => "optional" },
                      { field => [{ content => "publisher" }], type => "optional" },
                      { field => [{ content => "pubstate" }], type => "optional" },
                      { field => [{ content => "series" }], type => "optional" },
                      { field => [{ content => "subtitle" }], type => "optional" },
                      { field => [{ content => "titleaddon" }], type => "optional" },
                      { field => [{ content => "type" }], type => "optional" },
                      { field => [{ content => "url" }], type => "optional" },
                      { field => [{ content => "urldate" }], type => "optional" },
                      { field => [{ content => "version" }], type => "optional" },
                    ],
      entrytypes => { entrytype => [{ content => "manual" }] },
    },
    {
      constraint => [
                      { field => [{ content => "title" }], type => "mandatory" },
                      {
                        field => [
                                   { conflict => "suppress", content => "year" },
                                   { content => "date" },
                                 ],
                        type  => "mandatory",
                      },
                      {
                        antecedent => { field => [{ content => "date" }], quant => "all" },
                        consequent => {
                          field => [{ conflict => "suppress", content => "month" }],
                          quant => "none",
                        },
                        type => "conditional",
                      },
                      { field => [{ content => "addendum" }], type => "optional" },
                      { field => [{ content => "author" }], type => "optional" },
                      { field => [{ content => "doi" }], type => "optional" },
                      { field => [{ content => "editor" }], type => "optional" },
                      { field => [{ content => "eprint" }], type => "optional" },
                      { field => [{ content => "eprintclass" }], type => "optional" },
                      { field => [{ content => "eprinttype" }], type => "optional" },
                      { field => [{ content => "howpublished" }], type => "optional" },
                      { field => [{ content => "language" }], type => "optional" },
                      { field => [{ content => "location" }], type => "optional" },
                      {
                        field => [
                                   { content => "month", datatype => "integer", rangemax => 12, rangemin => 1 },
                                 ],
                        type  => "optional",
                      },
                      { field => [{ content => "note" }], type => "optional" },
                      { field => [{ content => "organization" }], type => "optional" },
                      { field => [{ content => "pubstate" }], type => "optional" },
                      { field => [{ content => "subtitle" }], type => "optional" },
                      { field => [{ content => "titleaddon" }], type => "optional" },
                      { field => [{ content => "type" }], type => "optional" },
                      { field => [{ content => "url" }], type => "optional" },
                      { field => [{ content => "urldate" }], type => "optional" },
                      { field => [{ content => "version" }], type => "optional" },
                    ],
      entrytypes => { entrytype => [{ content => "misc" }] },
    },
    {
      constraint => [
                      { field => [{ content => "title" }], type => "mandatory" },
                      { field => [{ content => "url" }], type => "mandatory" },
                      {
                        antecedent => { field => [{ content => "date" }], quant => "all" },
                        consequent => {
                          field => [{ conflict => "suppress", content => "month" }],
                          quant => "none",
                        },
                        type => "conditional",
                      },
                      { field => [{ content => "addendum" }], type => "optional" },
                      { field => [{ content => "author" }], type => "optional" },
                      { field => [{ content => "editor" }], type => "optional" },
                      { field => [{ content => "language" }], type => "optional" },
                      {
                        field => [
                                   { content => "month", datatype => "integer", rangemax => 12, rangemin => 1 },
                                 ],
                        type  => "optional",
                      },
                      { field => [{ content => "note" }], type => "optional" },
                      { field => [{ content => "organization" }], type => "optional" },
                      { field => [{ content => "pubstate" }], type => "optional" },
                      { field => [{ content => "subtitle" }], type => "optional" },
                      { field => [{ content => "titleaddon" }], type => "optional" },
                      { field => [{ content => "urldate" }], type => "optional" },
                      { field => [{ content => "version" }], type => "optional" },
                      {
                        field => [
                                   { conflict => "suppress", content => "year" },
                                   { content => "date" },
                                 ],
                        type  => "optional",
                      },
                    ],
      entrytypes => { entrytype => [{ content => "online" }] },
    },
    {
      constraint => [
                      { field => [{ content => "author" }], type => "mandatory" },
                      { field => [{ content => "title" }], type => "mandatory" },
                      { field => [{ content => "number" }], type => "mandatory" },
                      {
                        field => [
                                   { conflict => "suppress", content => "year" },
                                   { content => "date" },
                                 ],
                        type  => "mandatory",
                      },
                      {
                        antecedent => { field => [{ content => "date" }], quant => "all" },
                        consequent => {
                          field => [{ conflict => "suppress", content => "month" }],
                          quant => "none",
                        },
                        type => "conditional",
                      },
                      { field => [{ content => "addendum" }], type => "optional" },
                      { field => [{ content => "doi" }], type => "optional" },
                      { field => [{ content => "eprint" }], type => "optional" },
                      { field => [{ content => "eprintclass" }], type => "optional" },
                      { field => [{ content => "eprinttype" }], type => "optional" },
                      { field => [{ content => "holder" }], type => "optional" },
                      { field => [{ content => "location" }], type => "optional" },
                      {
                        field => [
                                   { content => "month", datatype => "integer", rangemax => 12, rangemin => 1 },
                                 ],
                        type  => "optional",
                      },
                      { field => [{ content => "note" }], type => "optional" },
                      { field => [{ content => "pubstate" }], type => "optional" },
                      { field => [{ content => "subtitle" }], type => "optional" },
                      { field => [{ content => "titleaddon" }], type => "optional" },
                      { field => [{ content => "type" }], type => "optional" },
                      { field => [{ content => "url" }], type => "optional" },
                      { field => [{ content => "urldate" }], type => "optional" },
                      { field => [{ content => "version" }], type => "optional" },
                    ],
      entrytypes => { entrytype => [{ content => "patent" }] },
    },
    {
      constraint => [
                      { field => [{ content => "editor" }], type => "mandatory" },
                      { field => [{ content => "title" }], type => "mandatory" },
                      {
                        field => [
                                   { conflict => "suppress", content => "year" },
                                   { content => "date" },
                                 ],
                        type  => "mandatory",
                      },
                      {
                        antecedent => { field => [{ content => "date" }], quant => "all" },
                        consequent => {
                          field => [{ conflict => "suppress", content => "month" }],
                          quant => "none",
                        },
                        type => "conditional",
                      },
                      { field => [{ content => "addendum" }], type => "optional" },
                      { field => [{ content => "doi" }], type => "optional" },
                      { field => [{ content => "editora" }], type => "optional" },
                      { field => [{ content => "editorb" }], type => "optional" },
                      { field => [{ content => "editorc" }], type => "optional" },
                      { field => [{ content => "eprint" }], type => "optional" },
                      { field => [{ content => "eprintclass" }], type => "optional" },
                      { field => [{ content => "eprinttype" }], type => "optional" },
                      { field => [{ content => "issn" }], type => "optional" },
                      { field => [{ content => "issue" }], type => "optional" },
                      { field => [{ content => "issuesubtitle" }], type => "optional" },
                      { field => [{ content => "issuetitle" }], type => "optional" },
                      { field => [{ content => "language" }], type => "optional" },
                      {
                        field => [
                                   { content => "month", datatype => "integer", rangemax => 12, rangemin => 1 },
                                 ],
                        type  => "optional",
                      },
                      { field => [{ content => "note" }], type => "optional" },
                      { field => [{ content => "number" }], type => "optional" },
                      { field => [{ content => "pubstate" }], type => "optional" },
                      { field => [{ content => "series" }], type => "optional" },
                      { field => [{ content => "subtitle" }], type => "optional" },
                      { field => [{ content => "url" }], type => "optional" },
                      { field => [{ content => "urldate" }], type => "optional" },
                      { field => [{ content => "volume" }], type => "optional" },
                    ],
      entrytypes => { entrytype => [{ content => "periodical" }] },
    },
    {
      constraint => [
                      { field => [{ content => "editor" }], type => "mandatory" },
                      { field => [{ content => "title" }], type => "mandatory" },
                      {
                        field => [
                                   { conflict => "suppress", content => "year" },
                                   { content => "date" },
                                 ],
                        type  => "mandatory",
                      },
                      {
                        antecedent => { field => [{ content => "date" }], quant => "all" },
                        consequent => {
                          field => [{ conflict => "suppress", content => "month" }],
                          quant => "none",
                        },
                        type => "conditional",
                      },
                      { field => [{ content => "addendum" }], type => "optional" },
                      { field => [{ content => "chapter" }], type => "optional" },
                      { field => [{ content => "doi" }], type => "optional" },
                      { field => [{ content => "eprint" }], type => "optional" },
                      { field => [{ content => "eprintclass" }], type => "optional" },
                      { field => [{ content => "eprinttype" }], type => "optional" },
                      { field => [{ content => "eventdate" }], type => "optional" },
                      { field => [{ content => "eventtitle" }], type => "optional" },
                      { field => [{ content => "isbn" }], type => "optional" },
                      { field => [{ content => "language" }], type => "optional" },
                      { field => [{ content => "location" }], type => "optional" },
                      { field => [{ content => "mainsubtitle" }], type => "optional" },
                      { field => [{ content => "maintitle" }], type => "optional" },
                      { field => [{ content => "maintitleaddon" }], type => "optional" },
                      { field => [{ content => "month" }], type => "optional" },
                      { field => [{ content => "note" }], type => "optional" },
                      { field => [{ content => "number" }], type => "optional" },
                      { field => [{ content => "organization" }], type => "optional" },
                      { field => [{ content => "pages" }], type => "optional" },
                      { field => [{ content => "pagetotal" }], type => "optional" },
                      { field => [{ content => "part" }], type => "optional" },
                      { field => [{ content => "publisher" }], type => "optional" },
                      { field => [{ content => "pubstate" }], type => "optional" },
                      { field => [{ content => "series" }], type => "optional" },
                      { field => [{ content => "subtitle" }], type => "optional" },
                      { field => [{ content => "titleaddon" }], type => "optional" },
                      { field => [{ content => "url" }], type => "optional" },
                      { field => [{ content => "urldate" }], type => "optional" },
                      { field => [{ content => "venue" }], type => "optional" },
                      { field => [{ content => "volume" }], type => "optional" },
                      { field => [{ content => "volumes" }], type => "optional" },
                    ],
      entrytypes => { entrytype => [{ content => "proceedings" }] },
    },
    {
      constraint => [
                      { field => [{ content => "author" }], type => "mandatory" },
                      { field => [{ content => "editor" }], type => "mandatory" },
                      { field => [{ content => "title" }], type => "mandatory" },
                      { field => [{ content => "booktitle" }], type => "mandatory" },
                      {
                        field => [
                                   { conflict => "suppress", content => "year" },
                                   { content => "date" },
                                 ],
                        type  => "mandatory",
                      },
                      {
                        antecedent => { field => [{ content => "date" }], quant => "all" },
                        consequent => {
                          field => [{ conflict => "suppress", content => "month" }],
                          quant => "none",
                        },
                        type => "conditional",
                      },
                      { field => [{ content => "addendum" }], type => "optional" },
                      { field => [{ content => "booksubtitle" }], type => "optional" },
                      { field => [{ content => "booktitleaddon" }], type => "optional" },
                      { field => [{ content => "chapter" }], type => "optional" },
                      { field => [{ content => "doi" }], type => "optional" },
                      { field => [{ content => "eprint" }], type => "optional" },
                      { field => [{ content => "eprintclass" }], type => "optional" },
                      { field => [{ content => "eprinttype" }], type => "optional" },
                      { field => [{ content => "eventdate" }], type => "optional" },
                      { field => [{ content => "eventtitle" }], type => "optional" },
                      { field => [{ content => "isbn" }], type => "optional" },
                      { field => [{ content => "language" }], type => "optional" },
                      { field => [{ content => "location" }], type => "optional" },
                      { field => [{ content => "mainsubtitle" }], type => "optional" },
                      { field => [{ content => "maintitle" }], type => "optional" },
                      { field => [{ content => "maintitleaddon" }], type => "optional" },
                      {
                        field => [
                                   { content => "month", datatype => "integer", rangemax => 12, rangemin => 1 },
                                 ],
                        type  => "optional",
                      },
                      { field => [{ content => "note" }], type => "optional" },
                      { field => [{ content => "number" }], type => "optional" },
                      { field => [{ content => "organization" }], type => "optional" },
                      { field => [{ content => "pages" }], type => "optional" },
                      { field => [{ content => "part" }], type => "optional" },
                      { field => [{ content => "publisher" }], type => "optional" },
                      { field => [{ content => "pubstate" }], type => "optional" },
                      { field => [{ content => "series" }], type => "optional" },
                      { field => [{ content => "subtitle" }], type => "optional" },
                      { field => [{ content => "titleaddon" }], type => "optional" },
                      { field => [{ content => "url" }], type => "optional" },
                      { field => [{ content => "urldate" }], type => "optional" },
                      { field => [{ content => "venue" }], type => "optional" },
                      { field => [{ content => "volume" }], type => "optional" },
                      { field => [{ content => "volumes" }], type => "optional" },
                    ],
      entrytypes => { entrytype => [{ content => "inproceedings" }] },
    },
    {
      constraint => [
                      { field => [{ content => "author" }], type => "mandatory" },
                      { field => [{ content => "title" }], type => "mandatory" },
                      { field => [{ content => "type" }], type => "mandatory" },
                      { field => [{ content => "institution" }], type => "mandatory" },
                      {
                        field => [
                                   { conflict => "suppress", content => "year" },
                                   { content => "date" },
                                 ],
                        type  => "mandatory",
                      },
                      {
                        antecedent => { field => [{ content => "date" }], quant => "all" },
                        consequent => {
                          field => [{ conflict => "suppress", content => "month" }],
                          quant => "none",
                        },
                        type => "conditional",
                      },
                      { field => [{ content => "addendum" }], type => "optional" },
                      { field => [{ content => "chapter" }], type => "optional" },
                      { field => [{ content => "doi" }], type => "optional" },
                      { field => [{ content => "eprint" }], type => "optional" },
                      { field => [{ content => "eprintclass" }], type => "optional" },
                      { field => [{ content => "eprinttype" }], type => "optional" },
                      { field => [{ content => "isrn" }], type => "optional" },
                      { field => [{ content => "language" }], type => "optional" },
                      { field => [{ content => "location" }], type => "optional" },
                      {
                        field => [
                                   { content => "month", datatype => "integer", rangemax => 12, rangemin => 1 },
                                 ],
                        type  => "optional",
                      },
                      { field => [{ content => "note" }], type => "optional" },
                      { field => [{ content => "number" }], type => "optional" },
                      { field => [{ content => "pages" }], type => "optional" },
                      { field => [{ content => "pagetotal" }], type => "optional" },
                      { field => [{ content => "pubstate" }], type => "optional" },
                      { field => [{ content => "subtitle" }], type => "optional" },
                      { field => [{ content => "titleaddon" }], type => "optional" },
                      { field => [{ content => "url" }], type => "optional" },
                      { field => [{ content => "urldate" }], type => "optional" },
                      { field => [{ content => "version" }], type => "optional" },
                    ],
      entrytypes => { entrytype => [{ content => "report" }] },
    },
    {
      constraint => [
                      { field => [{ content => "author" }], type => "mandatory" },
                      { field => [{ content => "title" }], type => "mandatory" },
                      { field => [{ content => "type" }], type => "mandatory" },
                      { field => [{ content => "institution" }], type => "mandatory" },
                      {
                        field => [
                                   { conflict => "suppress", content => "year" },
                                   { content => "date" },
                                 ],
                        type  => "mandatory",
                      },
                      {
                        antecedent => { field => [{ content => "date" }], quant => "all" },
                        consequent => {
                          field => [{ conflict => "suppress", content => "month" }],
                          quant => "none",
                        },
                        type => "conditional",
                      },
                      { field => [{ content => "addendum" }], type => "optional" },
                      { field => [{ content => "chapter" }], type => "optional" },
                      { field => [{ content => "doi" }], type => "optional" },
                      { field => [{ content => "eprint" }], type => "optional" },
                      { field => [{ content => "eprintclass" }], type => "optional" },
                      { field => [{ content => "eprinttype" }], type => "optional" },
                      { field => [{ content => "language" }], type => "optional" },
                      { field => [{ content => "location" }], type => "optional" },
                      {
                        field => [
                                   { content => "month", datatype => "integer", rangemax => 12, rangemin => 1 },
                                 ],
                        type  => "optional",
                      },
                      { field => [{ content => "note" }], type => "optional" },
                      { field => [{ content => "pages" }], type => "optional" },
                      { field => [{ content => "pagetotal" }], type => "optional" },
                      { field => [{ content => "pubstate" }], type => "optional" },
                      { field => [{ content => "subtitle" }], type => "optional" },
                      { field => [{ content => "titleaddon" }], type => "optional" },
                      { field => [{ content => "url" }], type => "optional" },
                      { field => [{ content => "urldate" }], type => "optional" },
                    ],
      entrytypes => { entrytype => [{ content => "thesis" }] },
    },
    {
      constraint => [
                      { field => [{ content => "author" }], type => "mandatory" },
                      { field => [{ content => "title" }], type => "mandatory" },
                      {
                        field => [
                                   { conflict => "suppress", content => "year" },
                                   { content => "date" },
                                 ],
                        type  => "mandatory",
                      },
                      {
                        antecedent => { field => [{ content => "date" }], quant => "all" },
                        consequent => {
                          field => [{ conflict => "suppress", content => "month" }],
                          quant => "none",
                        },
                        type => "conditional",
                      },
                      { field => [{ content => "addendum" }], type => "optional" },
                      { field => [{ content => "howpublished" }], type => "optional" },
                      { field => [{ content => "language" }], type => "optional" },
                      { field => [{ content => "location" }], type => "optional" },
                      {
                        field => [
                                   { content => "month", datatype => "integer", rangemax => 12, rangemin => 1 },
                                 ],
                        type  => "optional",
                      },
                      { field => [{ content => "note" }], type => "optional" },
                      { field => [{ content => "pubstate" }], type => "optional" },
                      { field => [{ content => "subtitle" }], type => "optional" },
                      { field => [{ content => "titleaddon" }], type => "optional" },
                      { field => [{ content => "url" }], type => "optional" },
                      { field => [{ content => "urldate" }], type => "optional" },
                    ],
      entrytypes => { entrytype => [{ content => "unpublished" }] },
    },
  ],
}
  );
$CONFIG_DEFAULT_BIBLATEX{sorting_final} = $CONFIG_DEFAULT_BIBLATEX{sorting_label};

# Set up some encoding aliases to map \inputen{c,x} encoding names to Encode
# It seems that inputen{c,x} has a different idea of nextstep than Encode
# so we push it to MacRoman
define_alias( 'ansinew'        => 'cp1252'); # inputenc alias for cp1252
define_alias( 'applemac'       => 'MacRoman');
define_alias( 'applemacce'     => 'MacCentralEurRoman');
define_alias( 'next'           => 'MacRoman');
define_alias( 'x-mac-roman'    => 'MacRoman');
define_alias( 'x-mac-centeuro' => 'MacCentralEurRoman');
define_alias( 'x-mac-cyrillic' => 'MacCyrillic');
define_alias( 'x-nextstep'     => 'MacRoman');
define_alias( 'lutf8'          => 'UTF-8'); # Luatex
define_alias( 'utf8x'          => 'UTF-8'); # UCS (old)

# Defines the scope of each of the BibLaTeX configuration options
our %CONFIG_SCOPE_BIBLATEX = (
  alphaothers       => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 0},
  controlversion    => {GLOBAL => 1, PER_TYPE => 0, PER_ENTRY => 0},
  debug             => {GLOBAL => 1, PER_TYPE => 0, PER_ENTRY => 0},
  dataonly          => {GLOBAL => 0, PER_TYPE => 0, PER_ENTRY => 1},
  inheritance       => {GLOBAL => 1, PER_TYPE => 0, PER_ENTRY => 0},
  labelalpha        => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 0},
  labelname         => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 0},
  labelnumber       => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 0},
  labelyear         => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 0},
  maxitems          => {GLOBAL => 1, PER_TYPE => 0, PER_ENTRY => 0},
  minitems          => {GLOBAL => 1, PER_TYPE => 0, PER_ENTRY => 0},
  maxnames          => {GLOBAL => 1, PER_TYPE => 0, PER_ENTRY => 0},
  minnames          => {GLOBAL => 1, PER_TYPE => 0, PER_ENTRY => 0},
  singletitle       => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 0},
  skipbib           => {GLOBAL => 0, PER_TYPE => 1, PER_ENTRY => 1},
  skiplab           => {GLOBAL => 0, PER_TYPE => 1, PER_ENTRY => 1},
  skiplos           => {GLOBAL => 0, PER_TYPE => 1, PER_ENTRY => 1},
  sortalphaothers   => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 0},
  sorting           => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 0},
  sorting_label     => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 0},
  sorting_final     => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 0},
  sortlos           => {GLOBAL => 1, PER_TYPE => 0, PER_ENTRY => 0},
  structure         => {GLOBAL => 1, PER_TYPE => 0, PER_ENTRY => 0},
  terseinits        => {GLOBAL => 1, PER_TYPE => 0, PER_ENTRY => 0},
  uniquename        => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 0},
  useauthor         => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 1},
  useeditor         => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 1},
  useprefix         => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 1},
  usetranslator     => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 1},
);

### biblatex fields

Readonly::Array our @NAMEFIELDS  =>   qw{
  author editor editora editorb editorc shortauthor shorteditor commentator
  translator annotator bookauthor introduction foreword afterword
  holder sortname namea nameb namec };

Readonly::Array our @LISTFIELDS  =>   qw{
  publisher address location school institution organization language origlocation
  origpublisher lista listb listc listd liste listf };

Readonly::Array our @LITERALFIELDS_BASE  =>   qw{
  abstract addendum annotation chapter edition eid howpublished isan isbn
  ismn isrn issn issue iswc label labelnameaddon nameaddon note number pagetotal part pubstate
  series shorthand shorthandintro shortjournal shortseries eprinttype eprintclass
  venue version volume volumes usera userb userc userd
  usere userf hyphenation crossref entrysubtype execute gender sortkey sortyear
  xref
  };

Readonly::Array our @DATECOMPONENTFIELDS  =>   qw{
  year  endyear  origyear  origendyear   eventyear   eventendyear  urlyear  urlendyear
  month endmonth origmonth origendmonth  eventmonth  eventendmonth urlmonth urlendmonth
  day   endday   origday   origendday    eventday    eventendday   urlday   urlendday
  };

Readonly::Array our @TITLEFIELDS => qw{
  title subtitle titleaddon shorttitle sorttitle indextitle indexsorttitle
  origtitle issuetitle issuesubtitle maintitle mainsubtitle maintitleaddon
  booktitle booksubtitle booktitleaddon journal journaltitle journalsubtitle
  reprinttitle eventtitle };

# Fields that are used internally by biber but are not passed to the bbl output
Readonly::Array our @SKIPFIELDS => qw{
  sortname sorttitle presort sortkey sortyear library remarks date urldate
  eventdate origdate };
our %SKIPFIELDS = map { $_ => 1 } @SKIPFIELDS;

Readonly::Array our @RANGEFIELDS     =>  qw{ pages };
Readonly::Array our @DATERANGEFIELDS =>  qw{ date origdate eventdate urldate };
Readonly::Array our @VERBATIMFIELDS  =>  qw{ doi eprint file pdf url verba verbb verbc };
Readonly::Array our @KEYFIELDS       =>  qw{
  authortype bookpagination editortype origlanguage pagination
  type nameatype namebtype namectype editoratype editorbtype editorctype editorclass
  editoraclass editorbclass editorcclass };
Readonly::Array our @COMMASEP_FIELDS => qw{ options keywords entryset };

Readonly::Array our @ENTRIESTOSPLIT  =>  ( @NAMEFIELDS, @LISTFIELDS );

# These fields can be present when null. All others are not set if null
Readonly::Array our @NULL_OK  => qw{ endyear origendyear eventendyear urlendyear };

# literal and integer fields

Readonly::Array our @LITERALFIELDS => ( @TITLEFIELDS, @LITERALFIELDS_BASE, @KEYFIELDS );

Readonly::Hash our %NUMERICALMONTH => (
  'January' => 1,
  'February' => 2,
  'March' => 3,
  'April' => 4,
  'May' => 5,
  'June' => 6,
  'July' => 7,
  'August' => 8,
  'September' => 9,
  'October' => 10,
  'November' => 11,
  'December' => 12,
  'january' => 1,
  'february' => 2,
  'march' => 3,
  'april' => 4,
  'may' => 5,
  'june' => 6,
  'july' => 7,
  'august' => 8,
  'september' => 9,
  'october' => 10,
  'november' => 11,
  'december' => 12,
  'jan' => 1,
  'feb' => 2,
  'mar' => 3,
  'apr' => 4,
  'may' => 5,
  'jun' => 6,
  'jul' => 7,
  'aug' => 8,
  'sep' => 9,
  'oct' => 10,
  'nov' => 11,
  'dec' => 12
  );


Readonly::Hash our %DISPLAYMODES => {
  uniform => [ qw/uniform romanized translated original/ ],
  translated => [ qw/translated uniform romanized original/ ],
  romanized => [ qw/romanized uniform translated original/ ],
  original => [ qw/original romanized uniform translated/ ]
  } ;

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Biber::Constants - global constants for biber

=head1 AUTHOR

François Charette, C<< <firmicus at gmx.net> >>
Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2010 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# vim: set tabstop=2 shiftwidth=2 expandtab:
