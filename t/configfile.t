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

my %colloptsA = ( level => 3, table => '/home/user/data/otherkeys.txt' );
my %nosort = (author => [ q/\A\p{L}{2}\p{Pd}/, q/[\x{2bf}\x{2018}]/ ],
              translator => q/[\x{2bf}\x{2018}]/ );

my %map = (
   bibtex => {
      bmap_overwrite => 1,
      entrytype => {
        CHAT => { bmap_target => "CUSTOMB" },
        CONVERSATION => {
          alsoset => {
            verba => "BMAP_ORIGENTRYTYPE",
            verbb => "somevalue",
            verbc => "somevalue",
          },
          bmap_target => "CUSTOMA",
        },
        ARTICLE => {
          bmap_persource => ["examples.bib", "examples2.bib"],
          alsoset => {
            keywords => "keyw1, keyw2",
          },
        },
      },
      globalfield => {
        bmap_persource => "examples.bib",
        abstract => "BMAP_NULL",
        conductor => "NAMEA",
        gps => "USERA",
        participant => "NAMEA",
        userb => "USERD",
        PUBMEDID => {
          alsoset => { eprinttype => "BMAP_ORIGFIELD", userd => "some string of things" },
          bmap_target => "EPRINT",
        },
        LISTB => {
          bmap_persource => "examples.bib",
          bmap_match  => "\\A(\\S{2})",
          bmap_replace => "REP\$1CED"
                 }
      },
      field => {
        lista => { bmap_pertype => "REPORT",
                   bmap_target => "BMAP_NULL"},
        title => { bmap_pertype => "ONLINE",
                   bmap_target => "BMAP_NULL"},
        listc => {
          bmap_pertype => "UNPUBLISHED",
          bmap_target => "INSTITUTION",
          bmap_match  => "\\A(\\S{2})",
          bmap_replace => "REP\$1CED"
                 },
        userb => { bmap_pertype => "MISC",
                   bmap_target => "BMAP_NULL",
                   bmap_persource => "examples.bib",
          alsoset => { usere => "a string",
                       userf => "BMAP_NULL"},
                 },
      },
    },
    endnotexml => {
      bmap_overwrite => 1,
      entrytype => {
        "journal Article" => {
          bmap_persource => "endnote.xml",
          alsoset => { usera => "BMAP_ORIGENTRYTYPE" },
          bmap_target => "REPORT",
        },
      },
      globalfield => { abstract => "BMAP_NULL", bmap_persource => "endnote.xml" },
      field => {
        pages => { bmap_pertype => "Journal Article",
                   bmap_persource => "endnote.xml",
                   bmap_match  => "64",
                   bmap_replace => "66"},
               }
    },
    ris => {
      bmap_overwrite => 0,
      entrytype => {
        BOOK => { alsoset => { keywords => "somevalue" }, bmap_target => "MAPBOOK" },
        JOUR => { bmap_target => "REPORT", bmap_persource => "ris1.ris" },
      },
      globalfield => { n2 => "BMAP_NULL", bmap_persource => "ris1.ris" },
      field => {
        JO => { bmap_pertype => "JOUR",
                bmap_persource => "ris1.ris",
                bmap_match  => "Neurosurg\\.",
                bmap_replace => "Neurosurgery"},
               }
    },
    zoterordfxml => {
      bmap_overwrite => 1,
      field => {
        "dc:subject" => {
          bmap_persource => "zotero.rdf",
          bmap_pertype => ["journalArticle", "book", "bookSection"],
          bmap_target  => "BMAP_NULL",
        },
      "dc:title" => { bmap_pertype => "journalArticle",
                      bmap_match  => "(.+)",
                      bmap_replace => "\\L\$1"
                    },
      },
    });

# Set up Biber object
my $biberA = Biber->new( configfile => 'biber-test.conf', mincrossrefs => 7 );
$biberA->parse_ctrlfile('general1.bcf');

is(Biber::Config->getoption('mincrossrefs'), 7, 'Options 1 - from cmdline');
is(Biber::Config->getoption('configfile'), File::Spec->catfile('biber-test.conf'), 'Options 2 - from cmdline');
is(Biber::Config->getoption('sortlocale'), 'testlocale', 'Options 3 - from config file');
is_deeply(Biber::Config->getoption('collate_options'), \%colloptsA, 'Options 4 - from config file');
is_deeply(Biber::Config->getoption('nosort'), \%nosort, 'Options 5 - from config file');
is_deeply(Biber::Config->getoption('sortcase'), 0, 'Options 6 - from .bcf');
is(Biber::Config->getoption('decodecharsset'), 'base', 'Options 7 - from defaults');
is_deeply(Biber::Config->getoption('map'), \%map, 'Options 8 - from config file');
