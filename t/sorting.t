# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 49;
use Test::Differences;
unified_diff;

use Biber;
use Biber::Output::bbl;
use Log::Log4perl;
use Unicode::Normalize;
chdir("t/tdata");

# Set up Biber object
my $biber = Biber->new(noconf => 1);
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

$biber->parse_ctrlfile("general.bcf");
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');

my $yearoff1    = 'mm,,Knuth!Donald E,Computers Typesetting,1984,';
my $yearoff2    = 'mm,,Knuth!Donald E,Computers Typesetting,198,';
my $yearoff3    = 'mm,,Knuth!Donald E,Computers Typesetting,1984,';
my $yearoff4    = 'mm,,Knuth!Donald E,Computers Typesetting,984,';
my $yearoff5    = 'mm,,Knuth!Donald E,Computers Typesetting,1984,';
my $yearoff6    = 'mm,,Knuth!Donald E,Computers Typesetting,1984,';
my $yearoff7    = 'mm,,Knuth!Donald E,Computers Typesetting,198,';
my $yearoff8    = 'mm,,Knuth!Donald E,Computers Typesetting,1984,';
my $yearoff9    = 'mm,,Knuth!Donald E,Computers Typesetting,984,';
my $vol1        = 'mm,,Glashow!Sheldon,Partial Symmetries of Weak Interactions,1961,2200';
my $vol2        = 'mm,,Glashow!Sheldon,Partial Symmetries of Weak Interactions,1961,2200000';
my $vol3        = 'mm,,Glashow!Sheldon,Partial Symmetries of Weak Interactions,1961,ĐĐĐ22';
my $nty         = 'mm,,Glashow!Sheldon,Partial Symmetries of Weak Interactions,1961,22';
my $nyt         = 'mm,,Glashow!Sheldon,1961,Partial Symmetries of Weak Interactions,22';
my $nyvt        = 'mm,,Glashow!Sheldon,1961,22,Partial Symmetries of Weak Interactions';
my $anyt_la     = 'mm,Gla61,,Glashow!Sheldon,1961,Partial Symmetries of Weak Interactions,';
my $anyt        = 'mm,,,Glashow!Sheldon,1961,Partial Symmetries of Weak Interactions,';
my $anyvt_la    = 'mm,Gla61,,Glashow!Sheldon,1961,0022,Partial Symmetries of Weak Interactions';
my $anyvt_la2   = "mm,Hos+98,,Hostetler!Michael J\x{10FFFD},1998,0014,Alkanethiolate gold cluster molecules with core diameters from 15 to 52 nm";
my $anyvt_la3   = "mm,HW98,,Hostetler!Michael J#Wingate!Julia E\x{10FFFD},1998,0014,Alkanethiolate gold cluster molecules with core diameters from 15 to 52 nm";
my $anyvt_la4   = "mm,HW+98,,Hostetler!Michael J#Wingate!Julia E\x{10FFFD},1998,0014,Alkanethiolate gold cluster molecules with core diameters from 15 to 52 nm";
my $anyvt       = 'mm,,,Glashow!Sheldon,1961,0022,Partial Symmetries of Weak Interactions';
my $ynt         = 'mm,,1961,Glashow!Sheldon,Partial Symmetries of Weak Interactions';
my $ydnt        = 'mm,,1961,Glashow!Sheldon,Partial Symmetries of Weak Interactions';
my $sortinits   = 'mm,,1961,Glashow!S,Partial Symmetries of Weak Interactions';
my $debug       = 'stdmodel';
my $sk1         = 'mm,,AATESTKEY,AATESTKEY,AATESTKEY,AATESTKEY';
my $ps_sc       = 'zs,,Partial Symmetries of Weak Interactions,,Partial Symmetries of Weak Interactions,Partial Symmetries of Weak Interactions';
my $noname      = 'mm,,Partial Symmetries of Weak Interactions,Partial Symmetries of Weak Interactions,1961,22';
my $citeorder   = '1';
my $lists1      = 'Marcel Dekker';
my $lists2      = 'Chichester';
my $lists3      = "IBM\x{10FFFD}";
my $lists4      = "IBM!HP\x{10FFFD}";
my $lists5      = 'IBM!HP!Sun!Sony';
my $dates1      = '1979,1,2000000,1980,4,8,1924,6,7,1924,7,9,1924,0002,5,192,2,3,1979,3,4,79,3,3';
my $edtypeclass1 = 'redactor,Jaffé!Philipp,Loewenfeld!Samuel#Kaltenbrunner!Ferdinand#Ewald!Paul';
my $prefix1     = 'mm,,Luzzatto!Moshe Ḥayyim,,,Lashon laRamḥal uvo sheloshah ḥiburim,2000,';
my $diacritic1  = 'mm,,Hasan!Alī,alHasan!ʿAlī,Hasan!Alī,Some title,2000,';
my $labels      = '2005,3,2';
my $sn1         = '';
my $snk1        = 'mm,,John John!von!Doe!Jr,,,0';
my $ent1        = 'mm,,Smith#Brian,,,0';

# These have custom presort and also an exclusion on year and title set
my $useprefix1  = 'ww,,von!Bobble!Terrence,,,0';
my $useprefix4  = 'ww,,Bobble!Terrence!von,,,0';

# These have namelist and name scope useprefix respectively
my $useprefix2  = 'mm,,Animal!Alan!von,1998,Things,0';
my $useprefix3  = 'mm,,von!Rabble!Richard,1998,Things,0';

# Sorting data schemata
my $ssd1 = [
  { spec => "str", str => 1 },
  { spec => "str", str => 1 },
  { spec => "str", str => 1 },
  { int => 1, spec => "int" },
  { spec => "str", str => 1 },
  { int => 1, spec => "int" },
];
my $ssd2 = [
  { int => 1, spec => "int" },
  { int => 1, spec => "int" },
  { int => 1, spec => "int" },
  { int => 1, spec => "int" },
  { int => 1, spec => "int" },
  { int => 1, spec => "int" },
  { int => 1, spec => "-int" },
  { int => 1, spec => "int" },
  { int => 1, spec => "int" },
  { int => 1, spec => "int" },
  { int => 1, spec => "int" },
  { int => 1, spec => "int" },
  { int => 1, spec => "int" },
  { int => 1, spec => "int" },
  { int => 1, spec => "int" },
  { int => 1, spec => "int" },
  { int => 1, spec => "int" },
  { int => 1, spec => "int" },
  { int => 1, spec => "-int" },
  { int => 1, spec => "int" },
  { int => 1, spec => "int" },
  { int => 1, spec => "int" },
  { int => 1, spec => "int" },
  { int => 1, spec => "int" },
];

Biber::Config->setblxoption('useprefix', 1);

# regenerate information
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $bibentries = $section->bibentries;
my $main = $biber->sortlists->get_list(0, 'nty/global/', 'entry', 'nty', 'global', '');

eq_or_diff($main->get_sortdata('tvonb')->[0], $useprefix1, 'von with type-specific presort, exclusions and useprefix=true' );
eq_or_diff($main->get_sortdata('avona')->[0], $useprefix2, 'von with name list scope useprefix' );
eq_or_diff($main->get_sortdata('rvonr')->[0], $useprefix3, 'von with name scope useprefix' );

# Testing sorting data schema generation
is_deeply($main->get_sortdataschema, $ssd1, 'Sorting data schemata - 1' );

# Testing custom name sorting key
my $SNK = Biber::Config->getblxoption('sortingnamekey');
$SNK->{global} = [
        [{ type => 'namepart', value => 'given' },
         { type => 'literal', value => ' ' },
         { type => 'namepart', value => 'given' }],
        [{ type => 'namepart', value => 'prefix', use => 1}],
        [{ type => 'namepart', value => 'family'}],
        [{ type => 'namepart', value => 'suffix'}],
        [{ type => 'namepart', value => 'prefix', use => 0}]
       ];
Biber::Config->setblxoption('sortingnamekey', $SNK);
$biber->prepare;
eq_or_diff($main->get_sortdata('snk1')->[0], $snk1, 'Sorting name key - 1' );
eq_or_diff($main->get_sortdata('ent1')->[0], $ent1, 'Sorting name key - 2' );

# regenerate information
Biber::Config->setblxoption('useprefix', 0);
# Default name sorting key back again
$SNK->{global} = [
        [{ type => 'namepart', value => 'prefix', use => 1}],
        [{ type => 'namepart', value => 'family'}],
        [{ type => 'namepart', value => 'given' }],
        [{ type => 'namepart', value => 'suffix'}],
        [{ type => 'namepart', value => 'prefix', use => 0}]
       ];
Biber::Config->setblxoption('sortingnamekey', $SNK);
$biber->prepare;

eq_or_diff($main->get_sortdata('tvonb')->[0], $useprefix4, 'von with type-specific presort, exclusions and useprefix=false' );

my $S;

# Testing nosort
$S = {spec => [
      [
       {},
       {'presort'    => {}}
      ],
      [
       {final          => 1,
       },
       {'sortkey'    => {}}
      ],
      [
       {},
       {'sortname'   => {}},
       {'author'     => {}},
       {'editor'     => {}},
       {'translator' => {}},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'editor'   => {}},
      ],
      [
       {},
       {'translator'   => {}},
      ],
      [
       {},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'labelyear'       => {}}
      ],
      [
       {},
       {'volume'     => {}},
      ]
     ]};
$main->set_sortscheme($S);
Biber::Config->setoption('nosort', [ { name => 'author', value => q/\A\p{L}{2}\p{Pd}/ },
                                     { name => 'author', value => q/[\x{2bf}\x{2018}]/ },
                                     { name => 'translator', value => q/\A\p{L}{2}\p{Pd}/ },
                                     { name => 'translator', value => q/[\x{2bf}\x{2018}]/ },
                                     # type_title should be not used as there is an
                                     # explicit title nosort
                                     { name => 'type_title', value => q/\A.*/ },
                                     { name => 'title', value => q/\A\p{L}{2}\p{Pd}/ }
                                   ]);

Biber::Config->setoption('sortcase', '1');

# regenerate information
$biber->prepare;

eq_or_diff(NFC($main->get_sortdata('luzzatto')->[0]), $prefix1, 'Title with nosort' );
eq_or_diff(NFC($main->get_sortdata('hasan')->[0]), $diacritic1, 'Name with nosort' );

# Testing editor roles
$S = {spec => [
      [
       {},
       {'editoratype'     => {}},
      ],
      [
       {},
       {'editor'     => {}},
      ],
      [
       {},
       {'editora'     => {}},
      ],
     ]};
$main->set_sortscheme($S);
Biber::Config->setoption('sortcase', 0);

# regenerate information
$biber->prepare;

eq_or_diff(NFC($main->get_sortdata('jaffe')->[0]), $edtypeclass1, 'Editor type/class' );


# Testing sorting using various date fields
$S = {spec => [
      [
       {},
       {'year'       => {}},
      ],
      [
       {},
       {'month'       => {}},
      ],
      [
       {},
       {'day'       => {pad_side => 'right',
                        pad_width => 7}},
      ],
      [
       {},
       {'endyear'       => {}},
      ],
      [
       {},
       {'endmonth'       => {}},
      ],
      [
       {},
       {'endday'       => {}},
      ],
      [
       {'sort_direction'  => 'descending'},
       {'origyear'   => {}}
      ],
      [
       {},
       {'origmonth'   => {}}
      ],
      [
       {},
       {'origday'   => {}}
      ],
      [
       {},
       {'origendyear'   => {}}
      ],
      [
       {},
       {'origendmonth'   => {}}
      ],
      [
       {},
       {'origendday'   => {}}
      ],
      [
       {},
       {'eventendyear'   => {}}
      ],
      [
       {},
       {'eventendmonth'   => {pad_side => 'left',
                              pad_width => 4}}
      ],
      [
       {},
       {'eventendday'   => {}}
      ],
      [
       {},
       {'eventyear'   => {'substring_side' => 'left',
                          'substring_width' => 3}}
      ],
      [
       {},
       {'eventmonth'   => {}}
      ],
      [
       {},
       {'eventday'   => {}}
      ],
      [
       {sort_direction => 'descending'},
       {'urlendyear'   => {}}
      ],
      [
       {},
       {'urlendmonth'   => {}}
      ],
      [
       {},
       {'urlendday'   => {}}
      ],
      [
       {},
       {'urlyear'   => {'substring_side' => 'right',
                        'substring_width' => 2}}
      ],
      [
       {},
       {'urlmonth'   => {}}
      ],
      [
       {},
       {'urlday'   => {}}
      ],
     ]};
$main->set_sortscheme($S);

# regenerate information
$biber->prepare;

# Testing sorting data schema generation
is_deeply($main->get_sortdataschema, $ssd2, 'Sorting data schemata - 2' );

eq_or_diff($main->get_sortdata('moraux')->[0], $dates1, 'Very contrived but thorough test of date sorting' );

# Testing max/minITEMS with sorting using list fields
# publisher
$S = {spec => [
      [
       {},
       {'publisher'    => {}}
      ]
     ]};
$main->set_sortscheme($S);

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('augustine')->[0], $lists1, 'max/minitems test 1 (publisher)' );

# location
$S = {spec => [
      [
       {},
       {'location'    => {}}
      ]
     ]};
$main->set_sortscheme($S);

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('cotton')->[0], $lists2, 'max/minitems test 2 (location)' );


# institution
$S = {spec => [
      [
       {},
       {'institution'    => {}}
      ]
     ]};
$main->set_sortscheme($S);

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('chiu')->[0], $lists3, 'max/minitems test 3 (institution)' );

# institution with minitems=2
Biber::Config->setblxoption('minitems', 2);
$S = {spec => [
      [
       {},
       {'institution'    => {}}
      ]
     ]};
$main->set_sortscheme($S);

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('chiu')->[0], $lists4, 'max/minitems test 4 (institution - minitems=2)' );

# institution with maxitems=4, minitems=3
Biber::Config->setblxoption('maxitems', 4);
Biber::Config->setblxoption('minitems', 3);
$S = {spec => [
      [
       {},
       {'institution'    => {}}
      ]
     ]};
$main->set_sortscheme($S);

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('chiu')->[0], $lists5, 'max/minitems test 5 (institution - maxitems=4/minitems=3)' );



# nty with implicit default left, 4-digit year sort
$S = {spec => [
      [
       {},
       {'presort'    => {}}
      ],
      [
       {final          => 1,
       },
       {'sortkey'    => {}}
      ],
      [
       {},
       {'sortname'   => {}},
       {'author'     => {}},
       {'editor'     => {}},
       {'translator' => {}},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'year'       => {}}
      ],
      [
       {},
       {'volume'     => {}},
      ]
     ]};
$main->set_sortscheme($S);

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('knuth:ct')->[0], $yearoff1, 'nty with default left offset, 4 digit year' );

# nty with left, 3-digit year sort, case sensitive
$S = {spec => [
      [
       {},
       {'presort'    => {}}
      ],
      [
       {final          => 1,
       },
       {'sortkey'    => {}}
      ],
      [
       {},
       {'sortname'   => {}},
       {'author'     => {}},
       {'editor'     => {}},
       {'translator' => {}},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'year'       => {'substring_side' => 'left',
                         'substring_width' => 3}}
      ],
      [
       {},
       {'volume'     => {}},
      ]
     ]};
$main->set_sortscheme($S);
Biber::Config->setoption('sortcase', 1);
# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('knuth:ct')->[0], $yearoff2, 'nty with left offset, 3 digit year, case sensitive' );


# nty with left, 4-digit year sort, case sensitive
$S = {spec => [
      [
       {},
       {'presort'    => {}}
      ],
      [
       {final          => 1,
       },
       {'sortkey'    => {}}
      ],
      [
       {},
       {'sortname'   => {}},
       {'author'     => {}},
       {'editor'     => {}},
       {'translator' => {}},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'year'       => {'substring_side' => 'left',
                         'substring_width' => 4}}
      ],
      [
       {},
       {'volume'     => {}},
      ]
     ]};
$main->set_sortscheme($S);

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('knuth:ct')->[0], $yearoff3, 'nty with left offset, 4 digit year, case sensitive' );

# nty with right, 3-digit year sort
$S = {spec => [
      [
       {},
       {'presort'    => {}}
      ],
      [
       {final          => 1,
       },
       {'sortkey'    => {}}
      ],
      [
       {},
       {'sortname'   => {}},
       {'author'     => {}},
       {'editor'     => {}},
       {'translator' => {}},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'year'       => {'substring_side' => 'right',
                         'substring_width' => 3}}
      ],
      [
       {},
       {'volume'     => {}},
      ]
     ]};
$main->set_sortscheme($S);
Biber::Config->setoption('sortcase', 0);
# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('knuth:ct')->[0], $yearoff4, 'nty with right offset, 3 digit year' );

# nty with right, 4-digit year sort
$S = {spec => [
      [
       {},
       {'presort'    => {}}
      ],
      [
       {final          => 1,
       },
       {'sortkey'    => {}}
      ],
      [
       {},
       {'sortname'   => {}},
       {'author'     => {}},
       {'editor'     => {}},
       {'translator' => {}},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'year'       => {'substring_side' => 'right',
                         'substring_width' => 4}}
      ],
      [
       {},
       {'volume'     => {}},
      ]
     ]};
$main->set_sortscheme($S);

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('knuth:ct')->[0], $yearoff5, 'nty with right offset, 4 digit year' );

# ntyd with left, 4-digit year sort
$S = {spec => [
      [
       {},
       {'presort'    => {}}
      ],
      [
       {final          => 1,
       },
       {'sortkey'    => {}}
      ],
      [
       {},
       {'sortname'   => {}},
       {'author'     => {}},
       {'editor'     => {}},
       {'translator' => {}},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {'sort_direction'  => 'descending'},
       {'year'       => {'substring_side'  => 'left',
                         'substring_width' => 4}}
      ],
      [
       {},
       {'volume'     => {}},
      ]
     ]};
$main->set_sortscheme($S);

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('knuth:ct')->[0], $yearoff6, 'ntyd with left offset, 4 digit year' );

# ntyd with left, 3-digit year sort
$S = {spec => [
      [
       {},
       {'presort'    => {}}
      ],
      [
       {final          => 1,
       },
       {'sortkey'    => {}}
      ],
      [
       {},
       {'sortname'   => {}},
       {'author'     => {}},
       {'editor'     => {}},
       {'translator' => {}},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {'sort_direction'  => 'descending'},
       {'year'       => {'substring_side'  => 'left',
                         'substring_width' => 3}}
      ],
      [
       {},
       {'volume'     => {}},
      ]
     ]};
$main->set_sortscheme($S);

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('knuth:ct')->[0], $yearoff7, 'ntyd with left offset, 3 digit year' );

# ntyd with right, 4-digit year sort
$S = {spec => [
      [
       {},
       {'presort'    => {}}
      ],
      [
       {final          => 1,
       },
       {'sortkey'    => {}}
      ],
      [
       {},
       {'sortname'   => {}},
       {'author'     => {}},
       {'editor'     => {}},
       {'translator' => {}},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {'sort_direction'  => 'descending'},
       {'year'       => {'substring_side'  => 'right',
                         'substring_width' => 4}}
      ],
      [
       {},
       {'volume'     => {}},
      ]
     ]};
$main->set_sortscheme($S);

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('knuth:ct')->[0], $yearoff8, 'ntyd with right offset, 4 digit year' );

# ntyd with right, 3-digit year sort
$S = {spec => [
      [
       {},
       {'presort'    => {}}
      ],
      [
       {final          => 1,
       },
       {'sortkey'    => {}}
      ],
      [
       {},
       {'sortname'   => {}},
       {'author'     => {}},
       {'editor'     => {}},
       {'translator' => {}},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {'sort_direction'  => 'descending'},
       {'year'       => {'substring_side' => 'right',
                         'substring_width' => 3}}
      ],
      [
       {},
       {'volume'     => {}},
      ]
     ]};
$main->set_sortscheme($S);

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('knuth:ct')->[0], $yearoff9, 'ntyd with right offset, 3 digit year' );

# nty with right-padded vol
$S = {spec => [
      [
       {},
       {'presort'    => {}}
      ],
      [
       {final          => 1,
       },
       {'sortkey'    => {}}
      ],
      [
       {},
       {'sortname'   => {}},
       {'author'     => {}},
       {'editor'     => {}},
       {'translator' => {}},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'sortyear'   => {}},
       {'year'       => {}}
      ],
      [
       {},
       {'volume'     => {pad_side => 'right'}},
       {'0'       => {}}
      ]
     ]};
$main->set_sortscheme($S);

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('stdmodel')->[0], $vol1, 'nty with right-padded vol' );

# nty with right-padded 7-char vol
$S = {spec => [
      [
       {},
       {'presort'    => {}}
      ],
      [
       {final          => 1,
       },
       {'sortkey'    => {}}
      ],
      [
       {},
       {'sortname'   => {}},
       {'author'     => {}},
       {'editor'     => {}},
       {'translator' => {}},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'sortyear'   => {}},
       {'year'       => {}}
      ],
      [
       {},
       {'volume'     => {pad_side => 'right',
                         pad_width => 7}}
      ]
     ]};
$main->set_sortscheme($S);

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('stdmodel')->[0], $vol2, 'nty with right-padded 7-char vol' );

# nty with left-padded 5-char using Unicode "Đ" as pad_char vol
# Unicode char will be lowercase "đ" in sortstring
$S = {spec => [
      [
       {},
       {'presort'    => {}}
      ],
      [
       {final          => 1,
       },
       {'sortkey'    => {}}
      ],
      [
       {},
       {'sortname'   => {}},
       {'author'     => {}},
       {'editor'     => {}},
       {'translator' => {}},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'sortyear'   => {}},
       {'year'       => {}}
      ],
      [
       {},
       {'volume'     => {pad_side => 'left',
                         pad_width => 5,
                         pad_char => 'Đ'}},
      ]
     ]};
$main->set_sortscheme($S);

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('stdmodel')->[0], $vol3, 'nty with left-padded 5-char "a" pad char vol' );


# nty
$S = {spec => [
      [
       {},
       {'presort'    => {}}
      ],
      [
       {final          => 1,
       },
       {'sortkey'    => {}}
      ],
      [
       {},
       {'sortname'   => {}},
       {'author'     => {}},
       {'editor'     => {}},
       {'translator' => {}},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'sortyear'   => {}},
       {'year'       => {}}
      ],
      [
       {},
       {'volume'     => {}},
      ]
     ]};
$main->set_sortscheme($S);

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('stdmodel')->[0], $nty, 'basic nty sort' );
eq_or_diff($main->get_sortdata('angenendtsk')->[0], $sk1, 'basic sortkey sort' );

# nyt
$S = {spec => [
      [
       {},
       {'presort'    => {}}
      ],
      [
       {final          => 1,
       },
       {'sortkey'    => {}}
      ],
      [
       {},
       {'sortname'   => {}},
       {'labelname'  => {}},
       {'author'     => {}},
       {'editor'     => {}},
       {'translator' => {}},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'sortyear'   => {}},
       {'year'       => {}}
      ],
      [
       {},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'volume'     => {}},
      ]
     ]};
$main->set_sortscheme($S);

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('stdmodel')->[0], $nyt, 'basic nyt sort' );

# nyvt
$S = {spec => [
      [
       {},
       {'presort'    => {}}
      ],
      [
       {final          => 1,
       },
       {'sortkey'    => {}}
      ],
      [
       {},
       {'sortname'   => {}},
       {'author'     => {}},
       {'editor'     => {}},
       {'translator' => {}},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'sortyear'   => {}},
       {'year'       => {}}
      ],
      [
       {},
       {'volume'     => {}},
      ],
      [
       {},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ]
     ]};
$main->set_sortscheme($S);

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('stdmodel')->[0], $nyvt, 'basic nyvt sort' );

# anyt with labelalpha
Biber::Config->setblxoption('labelalpha', 1);
$S = {spec => [
      [
       {},
       {'presort'    => {}}
      ],
      [
       {},
       {'labelalpha' => {}}
      ],
      [
       {final          => 1,
       },
       {'sortkey'    => {}}
      ],
      [
       {},
       {'sortname'   => {}},
       {'author'     => {}},
       {'editor'     => {}},
       {'translator' => {}},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'sortyear'   => {}},
       {'year'       => {}}
      ],
      [
       {},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'sorttitle'  => {}},
      ]
     ]};
$main->set_sortscheme($S);

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('stdmodel')->[0], $anyt_la, 'anyt sort (with labelalpha)' );
Biber::Config->setblxoption('labelalpha', 0);
$bibentries->entry('stdmodel')->del_field('labelalpha');
$bibentries->entry('stdmodel')->del_field('sortlabelalpha');
$bibentries->entry('stdmodel:glashow')->del_field('labelalpha'); # it's a crossref so have to clear it here too
$bibentries->entry('stdmodel:glashow')->del_field('sortlabelalpha');

# anyt without labelalpha
# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('stdmodel')->[0], $anyt, 'anyt sort (without labelalpha)' );

# anyvt with labelalpha
Biber::Config->setblxoption('labelalpha',1);
$S = {spec => [
      [
       {},
       {'presort'    => {}}
      ],
      [
       {},
       {'labelalpha' => {}}
      ],
      [
       {final          => 1,
       },
       {'sortkey'    => {}}
      ],
      [
       {},
       {'sortname'   => {}},
       {'author'     => {}},
       {'editor'     => {}},
       {'translator' => {}},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'sortyear'   => {}},
       {'year'       => {}}
      ],
      [
       {},
       {'volume'     => {pad_width => 4}},
      ],
      [
       {},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ]
     ]};
$main->set_sortscheme($S);

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('stdmodel')->[0], $anyvt_la, 'anyvt sort (with labelalpha)' );
eq_or_diff($main->get_sortdata('murray')->[0], $anyvt_la2, 'anyvt sort (> maxbibnames=3 minbibnames=1, with labelalpha and alphaothers)' );

Biber::Config->setblxoption('maxalphanames', 2);
Biber::Config->setblxoption('minalphanames', 2);
Biber::Config->setblxoption('maxbibnames', 2);
Biber::Config->setblxoption('minbibnames', 2);

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('murray')->[0], $anyvt_la4, 'anyvt sort (> maxbibnames=2 minbibnames=2, with labelalpha and alphaothers)' );

Biber::Config->setblxoption('alphaothers', '');
Biber::Config->setblxoption('sortalphaothers', '');

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('murray')->[0], $anyvt_la3, 'anyvt sort (> maxbibnames=2 minbibnames=2,with labelalpha and without alphaothers)' );

Biber::Config->setblxoption('labelalpha', 0);
$bibentries->entry('stdmodel')->del_field('labelalpha');
$bibentries->entry('stdmodel')->del_field('sortlabelalpha');
$bibentries->entry('stdmodel:glashow')->del_field('labelalpha'); # it's a crossref so have to clear it here too
$bibentries->entry('stdmodel:glashow')->del_field('sortlabelalpha');
$bibentries->entry('murray')->del_field('labelalpha');
$bibentries->entry('murray')->del_field('sortlabelalpha');

# anyvt without labelalpha

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('stdmodel')->[0], $anyvt, 'anyvt sort (without labelalpha)' );

# ynt
$S = {spec => [
      [
       {},
       {'presort'    => {}}
      ],
      [
       {final          => 1,
       },
       {'sortkey'    => {}}
      ],
      [
       {},
       {'sortyear'   => {}},
       {'labelyear'  => {}},
       {'9999'       => {}}
      ],
      [
       {},
       {'sortname'   => {}},
       {'author'     => {}},
       {'editor'     => {}},
       {'translator' => {}},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
     ]};
$main->set_sortscheme($S);

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('stdmodel')->[0], $ynt, 'basic ynt sort' );

# ydnt
$S = {spec => [
      [
       {},
       {'presort'    => {}}
      ],
      [
       {final          => 1,
       },
       {'sortkey'    => {}}
      ],
      [
       {sort_direction => 'descending'},
       {'sortyear'   => {}},
       {'year'      => {}},
       {'9999'       => {}}
      ],
      [
       {},
       {'sortname'   => {}},
       {'author'     => {}},
       {'editor'     => {}},
       {'translator' => {}},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
     ]};
$main->set_sortscheme($S);

# regenerate information
$biber->prepare;
eq_or_diff($main->get_sortdata('stdmodel')->[0], $ydnt, 'basic ydnt sort' );


$SNK = Biber::Config->getblxoption('sortingnamekey');
$SNK->{global} = [
        [{ type => 'namepart', value => 'prefix', use => 1}],
        [{ type => 'namepart', value => 'family'}],
        [{ type => 'namepart', value => 'given', inits => 1}],
        [{ type => 'namepart', value => 'suffix'}],
        [{ type => 'namepart', value => 'prefix', use => 0}]
       ];
Biber::Config->setblxoption('sortingnamekey', $SNK);

$biber->prepare;
eq_or_diff($main->get_sortdata('stdmodel')->[0], $sortinits, 'sort first name inits only' );

$SNK = Biber::Config->getblxoption('sortingnamekey');
# Default back again
$SNK->{global} = [
        [{ type => 'namepart', value => 'prefix', use => 1}],
        [{ type => 'namepart', value => 'family'}],
        [{ type => 'namepart', value => 'given'}],
        [{ type => 'namepart', value => 'suffix'}],
        [{ type => 'namepart', value => 'prefix', use => 0}]
       ];
Biber::Config->setblxoption('sortingnamekey', $SNK);

Biber::Config->setblxoption('labelalpha', 0);

# debug
$S = {spec => [
      [
       {},
       {'entrykey'    => {}},
      ],
     ]};
$main->set_sortscheme($S);

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('stdmodel')->[0], $debug, 'basic debug sort' );

# nty with use* all off
Biber::Config->setblxoption('useauthor', 0);
Biber::Config->setblxoption('useeditor', 0);
Biber::Config->setblxoption('usetranslator', 0);
$S = {spec => [
      [
       {},
       {'presort'    => {}}
      ],
      [
       {final          => 1,
       },
       {'sortkey'    => {}}
      ],
      [
       {},
       {'sortname'   => {}},
       {'author'     => {}},
       {'editor'     => {}},
       {'translator' => {}},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'sortyear'   => {}},
       {'year'       => {}}
      ],
      [
       {},
       {'volume'     => {}},
      ]
     ]};
$main->set_sortscheme($S);

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('stdmodel')->[0], $noname, 'nty with use* all off' );


# nty with modified presort and short_circuit at title
$S = {spec => [
      [
       {},
       {'presort'    => {}}
      ],
      [
       {final          => 1,
       },
       {'sortkey'    => {}}
      ],
      [
       {},
       {'sortname'   => {}},
       {'author'     => {}},
       {'editor'     => {}},
       {'translator' => {}},
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {final          => 1,
       },
       {'sorttitle'  => {}},
       {'title'      => {}}
      ],
      [
       {},
       {'sortyear'   => {}},
       {'year'       => {}}
      ],
      [
       {},
       {'volume'     => {}},
      ]
     ]};

$main->set_sortscheme($S);

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('stdmodel:ps_sc')->[0], $ps_sc, 'nty with modified presort and short-circuit title' );


# citeorder sort
$S = {spec => [
      [
       {},
       {'citeorder'    => {}}
      ]
     ]};
$main->set_sortscheme($S);

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('stdmodel')->[0], $citeorder, 'citeorder' );

# citeorder sort
$S = {spec => [
      [
       {},
       {'labelyear'    => {}},
      ],
      [
       {},
       {'labelmonth'    => {}},
      ],
      [
       {},
       {'labelday'    => {}}
      ]
     ]};
$main->set_sortscheme($S);

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata('labelstest')->[0], $labels, 'date labels' );

# sortname sort
$S = {spec => [
      [
       {},
       {'sortname'   => {}},
       {'author'     => {}},
      ]
     ]};

$main->set_sortscheme($S);

Biber::Config->setblxoption('useauthor', 0);
Biber::Config->setblxoption('useeditor', 0);
Biber::Config->setblxoption('usetranslator', 0);
Biber::Config->setblxoption('usenamea', 0);
Biber::Config->setblxoption('useeditora', 0);
$biber->prepare;
# Testing that when no use<name> settings are true, sortname is ignored
eq_or_diff($main->get_sortdata('sn1')->[0], $sn1, 'Sortname - 1' );

