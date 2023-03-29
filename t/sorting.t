# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 52;
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

my $yearoff1    = 'mm,,Knuth        Donald E.      ,Computers & Typesetting,1984,';
my $yearoff2    = 'mm,,Knuth        Donald E.      ,Computers & Typesetting,198,';
my $yearoff3    = 'mm,,Knuth        Donald E.      ,Computers & Typesetting,1984,';
my $yearoff4    = 'mm,,Knuth        Donald E.      ,Computers & Typesetting,984,';
my $yearoff5    = 'mm,,Knuth        Donald E.      ,Computers & Typesetting,1984,';
my $yearoff6    = 'mm,,Knuth        Donald E.      ,Computers & Typesetting,1984,';
my $yearoff7    = 'mm,,Knuth        Donald E.      ,Computers & Typesetting,198,';
my $yearoff8    = 'mm,,Knuth        Donald E.      ,Computers & Typesetting,1984,';
my $yearoff9    = 'mm,,Knuth        Donald E.      ,Computers & Typesetting,984,';
my $vol1        = 'mm,,Glashow      Sheldon        ,Partial Symmetries of Weak Interactions,1961,2200';
my $vol2        = 'mm,,Glashow      Sheldon        ,Partial Symmetries of Weak Interactions,1961,2200000';
my $vol3        = 'mm,,Glashow      Sheldon        ,Partial Symmetries of Weak Interactions,1961,ĐĐĐ22';
my $nty         = 'mm,,Glashow      Sheldon        ,Partial Symmetries of Weak Interactions,1961,22';
my $nyt         = 'mm,,Glashow      Sheldon        ,1961,Partial Symmetries of Weak Interactions,22';
my $nyvt        = 'mm,,Glashow      Sheldon        ,1961,22,Partial Symmetries of Weak Interactions';
my $anyt_la     = 'mm,Gla61,,Glashow      Sheldon        ,1961,Partial Symmetries of Weak Interactions,';
my $anyt        = 'mm,,,Glashow      Sheldon        ,1961,Partial Symmetries of Weak Interactions,';
my $anyvt_la    = 'mm,Gla61,,Glashow      Sheldon        ,1961,0022,Partial Symmetries of Weak Interactions';
my $anyvt_la2   = "mm,Hos+98,,Hostetler    Michael J.     \x{10fffd},1998,0014,Alkanethiolate gold cluster molecules with core diameters from 1.5 to 5.2 nm";
my $anyvt_la3   = "mm,HW98,,Hostetler    Michael J.     Wingate      Julia E.       \x{10fffd},1998,0014,Alkanethiolate gold cluster molecules with core diameters from 1.5 to 5.2 nm";
my $anyvt_la4   = "mm,HW+98,,Hostetler    Michael J.     Wingate      Julia E.       \x{10fffd},1998,0014,Alkanethiolate gold cluster molecules with core diameters from 1.5 to 5.2 nm";
my $anyvt       = 'mm,,,Glashow      Sheldon        ,1961,0022,Partial Symmetries of Weak Interactions';
my $ynt         = 'mm,,1961,Glashow      Sheldon        ,Partial Symmetries of Weak Interactions';
my $ydnt        = 'mm,,1961,Glashow      Sheldon        ,Partial Symmetries of Weak Interactions';
my $sortinits   = 'mm,,1961,Glashow      S  ,Partial Symmetries of Weak Interactions';
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
my $edtypeclass1 = 'redactor,Jaffé       Philipp        ,Loewenfeld   Samuel         KaltenbrunnerFerdinand      Ewald        Paul           ';
my $prefix1     = 'mm,,Luzzatto     Moshe Ḥayyim  ,,,Lashon la-Ramḥal: u-vo sheloshah ḥiburim,2000,';
my $diacritic1  = 'mm,,Hasan        Alī           ,al-Hasan     ʿAlī          ,Hasan        Alī           ,Some title,2000,';
my $labels      = '2005,3,2';
my $sn1         = '';
my $snk1        = 'mm,,John            John           vonDoe          Jr,,,0';
my $ent1        = 'mm,,Smith        Brian          ,,,0';
my $others1     = 'mm,,Gauck        Joachim        ,,Title A,0';
my $others2     = 'mm,,Gauck        Joachim        ,,Title B,0';
my $final       = 'mm,,zzzz,zzzz,zzzz,zzzz';

my $short1    = 'mm,,Lopez';
my $short2    = 'mm,,Lopeza';

# These have custom presort and also an exclusion on year and title set
my $useprefix1  = 'ww,,vonBobble       Terrence       ,,,0';
my $useprefix4  = 'ww,,Bobble       Terrence       von,,,0';

# These have namelist and name scope useprefix respectively
my $useprefix2  = 'mm,,Animal       Alan           von,1998,Things,0';
my $useprefix3  = 'mm,,vonRabble       Richard        ,1998,Things,0';

# Sorting data schemata
my $ssd1 = [
  { spec => "str", str => 1 },
  { spec => "str", str => 1 },
  { spec => "str", str => 1 },
  { spec => "int", int => 1 },
  { spec => "str", str => 1 },
  { spec => "int", int => 1 },
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

Biber::Config->setblxoption(undef,'useprefix', 1);

# regenerate information
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $bibentries = $section->bibentries;
my $main = $biber->datalists->get_list('nyt/global//global/global/global');

eq_or_diff($main->get_sortdata_for_key('tvonb')->[0], $useprefix1, 'von with type-specific presort, exclusions and useprefix=true' );
eq_or_diff($main->get_sortdata_for_key('avona')->[0], $useprefix2, 'von with name list scope useprefix' );
eq_or_diff($main->get_sortdata_for_key('rvonr')->[0], $useprefix3, 'von with name scope useprefix' );

# Testing sorting data schema generation
is_deeply($main->get_sortdataschema, $ssd1, 'Sorting data schemata - 1' );

# Explicit "and others"
eq_or_diff($main->get_sortdata_for_key('others1')->[0], $others1, 'Explicit "and others" - 1' );
eq_or_diff($main->get_sortdata_for_key('others2')->[0], $others2, 'Explicit "and others" - 2' );

# Final items with no other data
eq_or_diff($main->get_sortdata_for_key('final')->[0], $final, 'Final entries with no other data' );

# Testing custom name sorting key
my $SNK = Biber::Config->getblxoption(undef,'sortingnamekeytemplate');
$SNK->{global} = {visibility => 'sort', template => [
        [{ type => 'namepart', value => 'given' },
         { type => 'literal', value => ' ' },
         { type => 'namepart', value => 'given' }],
        [{ type => 'namepart', value => 'prefix', use => 1}],
        [{ type => 'namepart', value => 'family'}],
        [{ type => 'namepart', value => 'suffix'}],
        [{ type => 'namepart', value => 'prefix', use => 0}]
       ]};
Biber::Config->setblxoption(undef,'sortingnamekeytemplate', $SNK);
$biber->prepare;
eq_or_diff($main->get_sortdata_for_key('snk1')->[0], $snk1, 'Sorting name key - 1' );
eq_or_diff($main->get_sortdata_for_key('ent1')->[0], $ent1, 'Sorting name key - 2' );

# regenerate information
Biber::Config->setblxoption(undef,'useprefix', 0);
# Default name sorting key back again
$SNK->{global} = {visibility => 'sort', template => [
        [{ type => 'namepart', value => 'prefix', use => 1}],
        [{ type => 'namepart', value => 'family'}],
        [{ type => 'namepart', value => 'given' }],
        [{ type => 'namepart', value => 'suffix'}],
        [{ type => 'namepart', value => 'prefix', use => 0}]
       ]};
Biber::Config->setblxoption(undef,'sortingnamekeytemplate', $SNK);
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('tvonb')->[0], $useprefix4, 'von with type-specific presort, exclusions and useprefix=false' );

# Testing nosort
$main->set_sortingtemplatename('custom1');

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

eq_or_diff(NFC($main->get_sortdata_for_key('luzzatto')->[0]), $prefix1, 'Title with nosort' );
eq_or_diff(NFC($main->get_sortdata_for_key('hasan')->[0]), $diacritic1, 'Name with nosort' );

# Testing editor roles
$main->set_sortingtemplatename('er');

Biber::Config->setoption('sortcase', 0);

# regenerate information
$biber->prepare;

eq_or_diff(NFC($main->get_sortdata_for_key('jaffe')->[0]), $edtypeclass1, 'Editor type/class' );


# Testing sorting using various date fields
$main->set_sortingtemplatename('dates1');

# regenerate information
$biber->prepare;

# Testing sorting data schema generation
is_deeply($main->get_sortdataschema, $ssd2, 'Sorting data schemata - 2' );

eq_or_diff($main->get_sortdata_for_key('moraux')->[0], $dates1, 'Very contrived but thorough test of date sorting' );

# Testing max/minITEMS with sorting using list fields
# publisher
$main->set_sortingtemplatename('publisher');

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('augustine')->[0], $lists1, 'max/minitems test 1 (publisher)' );

# location
$main->set_sortingtemplatename('location');

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('cotton')->[0], $lists2, 'max/minitems test 2 (location)' );

# institution

$main->set_sortingtemplatename('institution');

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('chiu')->[0], $lists3, 'max/minitems test 3 (institution)' );

# institution with minitems=2
Biber::Config->setblxoption(undef,'minitems', 2);

$main->set_sortingtemplatename('institution');

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('chiu')->[0], $lists4, 'max/minitems test 4 (institution - minitems=2)' );

# institution with maxitems=4, minitems=3
Biber::Config->setblxoption(undef,'maxitems', 4);
Biber::Config->setblxoption(undef,'minitems', 3);

$main->set_sortingtemplatename('institution');

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('chiu')->[0], $lists5, 'max/minitems test 5 (institution - maxitems=4/minitems=3)' );



# nty with implicit default left, 4-digit year sort
$main->set_sortingtemplatename('nty9');

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('knuth:ct')->[0], $yearoff1, 'nty with default left offset, 4 digit year' );

# nty with left, 3-digit year sort, case sensitive
$main->set_sortingtemplatename('nty1');
Biber::Config->setoption('sortcase', 1);
# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('knuth:ct')->[0], $yearoff2, 'nty with left offset, 3 digit year, case sensitive' );


# nty with left, 4-digit year sort, case sensitive
$main->set_sortingtemplatename('nty2');

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('knuth:ct')->[0], $yearoff3, 'nty with left offset, 4 digit year, case sensitive' );

# nty with right, 3-digit year sort
$main->set_sortingtemplatename('nty3');
Biber::Config->setoption('sortcase', 0);
# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('knuth:ct')->[0], $yearoff4, 'nty with right offset, 3 digit year' );

# nty with right, 4-digit year sort
$main->set_sortingtemplatename('nty4');

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('knuth:ct')->[0], $yearoff5, 'nty with right offset, 4 digit year' );

# ntyd with left, 4-digit year sort
$main->set_sortingtemplatename('ntyd1');

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('knuth:ct')->[0], $yearoff6, 'ntyd with left offset, 4 digit year' );

# ntyd with left, 3-digit year sort
$main->set_sortingtemplatename('ntyd2');

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('knuth:ct')->[0], $yearoff7, 'ntyd with left offset, 3 digit year' );

# ntyd with right, 4-digit year sort
$main->set_sortingtemplatename('ntyd3');

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('knuth:ct')->[0], $yearoff8, 'ntyd with right offset, 4 digit year' );

# ntyd with right, 3-digit year sort
$main->set_sortingtemplatename('ntyd4');

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('knuth:ct')->[0], $yearoff9, 'ntyd with right offset, 3 digit year' );

# nty with right-padded vol
$main->set_sortingtemplatename('nty5');

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('stdmodel')->[0], $vol1, 'nty with right-padded vol' );

# nty with right-padded 7-char vol
$main->set_sortingtemplatename('nty6');

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('stdmodel')->[0], $vol2, 'nty with right-padded 7-char vol' );

# nty with left-padded 5-char using Unicode "Đ" as pad_char vol
# Unicode char will be lowercase "đ" in sortstring
$main->set_sortingtemplatename('nty7');

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('stdmodel')->[0], $vol3, 'nty with left-padded 5-char "a" pad char vol' );


# nty
$main->set_sortingtemplatename('nty');

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('stdmodel')->[0], $nty, 'basic nty sort' );
eq_or_diff($main->get_sortdata_for_key('angenendtsk')->[0], $sk1, 'basic sortkey sort' );

# nyt
$main->set_sortingtemplatename('nyt');

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('stdmodel')->[0], $nyt, 'basic nyt sort' );

# nyvt
$main->set_sortingtemplatename('nyvt');

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('stdmodel')->[0], $nyvt, 'basic nyvt sort' );

# anyt with labelalpha
Biber::Config->setblxoption(undef,'labelalpha', 1);
$main->set_sortingtemplatename('anyt');

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('stdmodel')->[0], $anyt_la, 'anyt sort (with labelalpha)' );
Biber::Config->setblxoption(undef,'labelalpha', 0);
$bibentries->entry('stdmodel')->del_field('labelalpha');
$bibentries->entry('stdmodel')->del_field('sortlabelalpha');
$bibentries->entry('stdmodel:glashow')->del_field('labelalpha'); # it's a crossref so have to clear it here too
$bibentries->entry('stdmodel:glashow')->del_field('sortlabelalpha');

# anyt without labelalpha
# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('stdmodel')->[0], $anyt, 'anyt sort (without labelalpha)' );

# anyvt with labelalpha
Biber::Config->setblxoption(undef,'labelalpha',1);
$main->set_sortingtemplatename('anyvt');

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('stdmodel')->[0], $anyvt_la, 'anyvt sort (with labelalpha)' );
eq_or_diff($main->get_sortdata_for_key('murray')->[0], $anyvt_la2, 'anyvt sort (> maxbibnames=3 minbibnames=1, with labelalpha and alphaothers)' );

Biber::Config->setblxoption(undef,'maxalphanames', 2);
Biber::Config->setblxoption(undef,'minalphanames', 2);
Biber::Config->setblxoption(undef,'maxsortnames', 2);
Biber::Config->setblxoption(undef,'minsortnames', 2);

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('murray')->[0], $anyvt_la4, 'anyvt sort (> maxbibnames=2 minbibnames=2, with labelalpha and alphaothers)' );

Biber::Config->setblxoption(undef,'alphaothers', '');
Biber::Config->setblxoption(undef,'sortalphaothers', '');

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('murray')->[0], $anyvt_la3, 'anyvt sort (> maxbibnames=2 minbibnames=2,with labelalpha and without alphaothers)' );

Biber::Config->setblxoption(undef,'labelalpha', 0);
$bibentries->entry('stdmodel')->del_field('labelalpha');
$bibentries->entry('stdmodel')->del_field('sortlabelalpha');
$bibentries->entry('stdmodel:glashow')->del_field('labelalpha'); # it's a crossref so have to clear it here too
$bibentries->entry('stdmodel:glashow')->del_field('sortlabelalpha');
$bibentries->entry('murray')->del_field('labelalpha');
$bibentries->entry('murray')->del_field('sortlabelalpha');

# anyvt without labelalpha

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('stdmodel')->[0], $anyvt, 'anyvt sort (without labelalpha)' );

# ynt
$main->set_sortingtemplatename('ynt');

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('stdmodel')->[0], $ynt, 'basic ynt sort' );

# ydnt
$main->set_sortingtemplatename('ydnt');

# regenerate information
$biber->prepare;
eq_or_diff($main->get_sortdata_for_key('stdmodel')->[0], $ydnt, 'basic ydnt sort' );


$SNK = Biber::Config->getblxoption(undef,'sortingnamekey');
$SNK->{global} = {visibility => 'sort', template => [
        [{ type => 'namepart', value => 'prefix', use => 1}],
        [{ type => 'namepart', value => 'family'}],
        [{ type => 'namepart', value => 'given', inits => 1}],
        [{ type => 'namepart', value => 'suffix'}],
        [{ type => 'namepart', value => 'prefix', use => 0}]
       ]};
Biber::Config->setblxoption(undef,'sortingnamekeytemplate', $SNK);

$biber->prepare;
eq_or_diff($main->get_sortdata_for_key('stdmodel')->[0], $sortinits, 'sort first name inits only' );

$SNK = Biber::Config->getblxoption(undef,'sortingnamekey');
# Default back again
$SNK->{global} = {visibility => 'sort', template => [
        [{ type => 'namepart', value => 'prefix', use => 1}],
        [{ type => 'namepart', value => 'family'}],
        [{ type => 'namepart', value => 'given'}],
        [{ type => 'namepart', value => 'suffix'}],
        [{ type => 'namepart', value => 'prefix', use => 0}]
       ]};
Biber::Config->setblxoption(undef,'sortingnamekeytemplate', $SNK);

Biber::Config->setblxoption(undef,'labelalpha', 0);

# debug
$main->set_sortingtemplatename('ek');

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('stdmodel')->[0], $debug, 'basic debug sort' );

# nty with use* all off
Biber::Config->setblxoption(undef,'useauthor', 0);
Biber::Config->setblxoption(undef,'useeditor', 0);
Biber::Config->setblxoption(undef,'usetranslator', 0);
$main->set_sortingtemplatename('nty');

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('stdmodel')->[0], $noname, 'nty with use* all off' );


# nty with modified presort and short_circuit at title
$main->set_sortingtemplatename('nty8');

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('stdmodel:ps_sc')->[0], $ps_sc, 'nty with modified presort and short-circuit title' );


# citeorder sort
$main->set_sortingtemplatename('none');

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('stdmodel')->[0], $citeorder, 'citeorder' );

# labels sort
$main->set_sortingtemplatename('label1');

# regenerate information
$biber->prepare;

eq_or_diff($main->get_sortdata_for_key('labelstest')->[0], $labels, 'date labels' );

# sortname sort
$main->set_sortingtemplatename('name1');

Biber::Config->setblxoption(undef,'useauthor', 0);
Biber::Config->setblxoption(undef,'useeditor', 0);
Biber::Config->setblxoption(undef,'usetranslator', 0);
Biber::Config->setblxoption(undef,'usenamea', 0);
Biber::Config->setblxoption(undef,'useeditora', 0);
$biber->prepare;
# Testing that when no use<name> settings are true, sortname is ignored
eq_or_diff($main->get_sortdata_for_key('sn1')->[0], $sn1, 'Sortname - 1' );

