# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 193;
use Test::Differences;
unified_diff;

use Biber;
use Biber::Utils;
use Biber::Output::bbl;
use Log::Log4perl;
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

$biber->parse_ctrlfile('uniqueness1.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');

# Biblatex options
Biber::Config->setblxoption('maxcitenames', 1);
Biber::Config->setblxoption('mincitenames', 1);
Biber::Config->setblxoption('uniquename', 2);
Biber::Config->setblxoption('uniquelist', 1);

# Now generate the information
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $bibentries = $section->bibentries;
my $main = $biber->sortlists->get_list(0, 'nty/global', 'entry', 'nty', 'global');

# Basic uniquename and hash testing
eq_or_diff($bibentries->entry('un1')->get_field($bibentries->entry('un1')->get_labelname_info)->nth_name(1)->get_uniquename, '2', 'Uniquename requiring full name expansion - 1');
eq_or_diff($bibentries->entry('un2')->get_field($bibentries->entry('un2')->get_labelname_info)->nth_name(1)->get_uniquename, '2', 'Uniquename requiring full name expansion - 2');
eq_or_diff($bibentries->entry('un5')->get_field($bibentries->entry('un5')->get_labelname_info)->nth_name(1)->get_uniquename, '2', 'Uniquename requiring full name expansion - 3');
eq_or_diff($bibentries->entry('un3')->get_field($bibentries->entry('un2')->get_labelname_info)->nth_name(1)->get_uniquename, '1', 'Uniquename requiring initials name expansion - 1');
eq_or_diff($bibentries->entry('un4')->get_field($bibentries->entry('un4')->get_labelname_info)->nth_name(1)->get_uniquename, '1', 'Uniquename requiring initials name expansion - 2');
ok(is_undef($bibentries->entry('un4a')->get_field($bibentries->entry('un4a')->get_labelname_info)->nth_name(1)->get_uniquename), 'per-entry uniquename');
eq_or_diff($bibentries->entry('un6')->get_field('namehash'), 'f8169a157f8d9209961157b8d23902db', 'Namehash and fullhash - 1');
eq_or_diff($bibentries->entry('un6')->get_field('fullhash'), 'f8169a157f8d9209961157b8d23902db', 'Namehash and fullhash - 2');
eq_or_diff($bibentries->entry('un7')->get_field('namehash'), 'b33fbd3f3349d1536dbcc14664f2cbbd', 'Fullnamshash ignores SHORT* names - 1');
eq_or_diff($bibentries->entry('un7')->get_field('fullhash'), 'f8169a157f8d9209961157b8d23902db', 'Fullnamshash ignores SHORT* names - 2');
eq_or_diff($bibentries->entry('test1')->get_field('namehash'), '07df5c892ba1452776abee0a867591f2', 'Namehash and fullhash - 3');
eq_or_diff($bibentries->entry('test1')->get_field('fullhash'), '637292dd2997a74c91847f1ec5081a46', 'Namehash and fullhash - 4');
eq_or_diff($bibentries->entry('untf1')->get_field($bibentries->entry('untf1')->get_labelname_info)->nth_name(2)->get_uniquename, '2', 'Uniquename with full and repeat - 1');
eq_or_diff($bibentries->entry('untf2')->get_field($bibentries->entry('untf2')->get_labelname_info)->nth_name(2)->get_uniquename, '2', 'Uniquename with full and repeat - 2');
eq_or_diff($bibentries->entry('untf3')->get_field($bibentries->entry('untf3')->get_labelname_info)->nth_name(2)->get_uniquename, '2', 'Uniquename with full and repeat - 3');
# Prefix/suffix
eq_or_diff($bibentries->entry('sp1')->get_field($bibentries->entry('sp1')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Prefix/Suffix - 1');
eq_or_diff($bibentries->entry('sp2')->get_field($bibentries->entry('sp2')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Prefix/Suffix - 2');
eq_or_diff($bibentries->entry('sp3')->get_field($bibentries->entry('sp3')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Prefix/Suffix - 3');
eq_or_diff($bibentries->entry('sp4')->get_field($bibentries->entry('sp4')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Prefix/Suffix - 4');
eq_or_diff($bibentries->entry('sp5')->get_field($bibentries->entry('sp5')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Prefix/Suffix - 5');
eq_or_diff($bibentries->entry('sp6')->get_field($bibentries->entry('sp6')->get_labelname_info)->nth_name(1)->get_uniquename, '2', 'Prefix/Suffix - 6');
eq_or_diff($bibentries->entry('sp7')->get_field($bibentries->entry('sp7')->get_labelname_info)->nth_name(1)->get_uniquename, '2', 'Prefix/Suffix - 7');
eq_or_diff($bibentries->entry('sp8')->get_field($bibentries->entry('sp8')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Prefix/Suffix - 8');
eq_or_diff($bibentries->entry('sp9')->get_field($bibentries->entry('sp9')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Prefix/Suffix - 9');

#############################################################################

$biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('uniqueness1.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());
# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');

# Biblatex options
Biber::Config->setblxoption('maxcitenames', 1);
Biber::Config->setblxoption('mincitenames', 1);
Biber::Config->setblxoption('uniquename', 1);
Biber::Config->setblxoption('uniquelist', 1);

# Now generate the information
$biber->prepare;
$section = $biber->sections->get_section(0);
$bibentries = $section->bibentries;
$main = $biber->sortlists->get_list(0, 'nty/global', 'entry', 'nty', 'global');

eq_or_diff($bibentries->entry('unt1')->get_field($bibentries->entry('unt1')->get_labelname_info)->nth_name(2)->get_uniquename, '1', 'Uniquename with inits and repeat - 1');
eq_or_diff($bibentries->entry('unt2')->get_field($bibentries->entry('unt2')->get_labelname_info)->nth_name(2)->get_uniquename, '1', 'Uniquename with inits and repeat - 2');
eq_or_diff($bibentries->entry('unt3')->get_field($bibentries->entry('unt3')->get_labelname_info)->nth_name(2)->get_uniquename, '1', 'Uniquename with inits and repeat - 3');
eq_or_diff($bibentries->entry('unt4')->get_field($bibentries->entry('unt4')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Uniquename with inits and repeat - 4');
eq_or_diff($bibentries->entry('unt5')->get_field($bibentries->entry('unt5')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Uniquename with inits and repeat - 5');

#############################################################################

$biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('uniqueness2.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());
# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');

# Biblatex options
Biber::Config->setblxoption('maxcitenames', 5);
Biber::Config->setblxoption('mincitenames', 1);
Biber::Config->setblxoption('uniquename', 2);
Biber::Config->setblxoption('uniquelist', 1);

# Now generate the information
$biber->prepare;
$section = $biber->sections->get_section(0);
$bibentries = $section->bibentries;
$main = $biber->sortlists->get_list(0, 'nty/global', 'entry', 'nty', 'global');

# Hashes the same as uniquelist expansion expands to the whole list
eq_or_diff($bibentries->entry('unall3')->get_field('namehash'), 'f1c5973adbc2e674fa4d98164c9ba5d5', 'Namehash and fullhash - 5');
eq_or_diff($bibentries->entry('unall3')->get_field('fullhash'), 'f1c5973adbc2e674fa4d98164c9ba5d5', 'Namehash and fullhash - 6');
ok(is_undef($bibentries->entry('unall3')->get_field($bibentries->entry('unall3')->get_labelname_info)->get_uniquelist), 'Uniquelist edgecase - 1');
eq_or_diff($bibentries->entry('unall4')->get_field($bibentries->entry('unall4')->get_labelname_info)->get_uniquelist, '6', 'Uniquelist edgecase - 2');

#############################################################################

$biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('uniqueness1.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());
# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');
# Biblatex options
Biber::Config->setblxoption('maxcitenames', 2);
Biber::Config->setblxoption('mincitenames', 1);
Biber::Config->setblxoption('uniquename', 1);
Biber::Config->setblxoption('uniquelist', 0);
# Now generate the information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bibentries;

eq_or_diff($bibentries->entry('test2')->get_field($bibentries->entry('test2')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Uniquename 0 due to mincitenames truncation');

#############################################################################

$biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('uniqueness2.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());
# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');
# Biblatex options
Biber::Config->setblxoption('uniquename', 1);
Biber::Config->setblxoption('uniquelist', 1);
Biber::Config->setblxoption('maxcitenames', 1);
Biber::Config->setblxoption('mincitenames', 1);
# Now generate the information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bibentries;

eq_or_diff($bibentries->entry('un8')->get_field($bibentries->entry('un8')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Uniquename - 1');
eq_or_diff($bibentries->entry('un8')->get_field($bibentries->entry('un8')->get_labelname_info)->nth_name(2)->get_uniquename, '0', 'Uniquename - 2');
eq_or_diff($bibentries->entry('un8')->get_field($bibentries->entry('un8')->get_labelname_info)->nth_name(3)->get_uniquename, '1', 'Uniquename - 3');
eq_or_diff($bibentries->entry('un9')->get_field($bibentries->entry('un9')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Uniquename - 4');
eq_or_diff($bibentries->entry('un9')->get_field($bibentries->entry('un9')->get_labelname_info)->nth_name(2)->get_uniquename, '0', 'Uniquename - 5');
eq_or_diff($bibentries->entry('un9')->get_field($bibentries->entry('un9')->get_labelname_info)->nth_name(3)->get_uniquename, '1', 'Uniquename - 6');
eq_or_diff($bibentries->entry('un9')->get_field($bibentries->entry('un9')->get_labelname_info)->nth_name(4)->get_uniquename, '0', 'Uniquename - 7');
eq_or_diff($bibentries->entry('un10')->get_field($bibentries->entry('un10')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Uniquename - 8');

eq_or_diff($bibentries->entry('un8')->get_field($bibentries->entry('un8')->get_labelname_info)->get_uniquelist, '3', 'Uniquelist - 1');
eq_or_diff($bibentries->entry('un9')->get_field($bibentries->entry('un9')->get_labelname_info)->get_uniquelist, '3', 'Uniquelist - 2');
ok(is_undef($bibentries->entry('un10')->get_field($bibentries->entry('un10')->get_labelname_info)->get_uniquelist), 'Uniquelist - 3');
eq_or_diff($bibentries->entry('unapa1')->get_field($bibentries->entry('unapa1')->get_labelname_info)->get_uniquelist, '3', 'Uniquelist - 4');
eq_or_diff($bibentries->entry('unapa2')->get_field($bibentries->entry('unapa2')->get_labelname_info)->get_uniquelist, '3', 'Uniquelist - 5');
ok(is_undef($bibentries->entry('others1')->get_field($bibentries->entry('others1')->get_labelname_info)->get_uniquelist), 'Uniquelist - 6');

# These next two should have uniquelist undef as they are identical author lists and so
# can't be disambiguated (and shouldn't be).
ok(is_undef($bibentries->entry('unall1')->get_field($bibentries->entry('unall1')->get_labelname_info)->get_uniquelist), 'Uniquelist - 7');
ok(is_undef($bibentries->entry('unall2')->get_field($bibentries->entry('unall2')->get_labelname_info)->get_uniquelist), 'Uniquelist - 8');

# These all should have uniquelist=5 as even though two are identical, they still both
# need disambiguating from the other one which differs in fifth place
eq_or_diff($bibentries->entry('unall5')->get_field($bibentries->entry('unall5')->get_labelname_info)->get_uniquelist, '5', 'Uniquelist - 9');
eq_or_diff($bibentries->entry('unall6')->get_field($bibentries->entry('unall6')->get_labelname_info)->get_uniquelist, '5', 'Uniquelist - 10');
eq_or_diff($bibentries->entry('unall7')->get_field($bibentries->entry('unall7')->get_labelname_info)->get_uniquelist, '5', 'Uniquelist - 11');
# unall8/unall9 are the same (ul=5) and unall10 is superset of them (ul=6)
# unall9a  is ul=undef due to per-entry settings (would otherwise be ul=5)
eq_or_diff($bibentries->entry('unall8')->get_field($bibentries->entry('unall8')->get_labelname_info)->get_uniquelist, '5', 'Uniquelist - 12');
eq_or_diff($bibentries->entry('unall9')->get_field($bibentries->entry('unall9')->get_labelname_info)->get_uniquelist, '5', 'Uniquelist - 13');
ok(is_undef($bibentries->entry('unall9a')->get_field($bibentries->entry('unall9a')->get_labelname_info)->get_uniquelist), 'Per-entry Uniquelist - 1');
eq_or_diff($bibentries->entry('unall10')->get_field($bibentries->entry('unall10')->get_labelname_info)->get_uniquelist, '6', 'Uniquelist - 14');

# These next two should have uniquelist 5/6 as they need disambiguating in place 5
eq_or_diff($bibentries->entry('unall3')->get_field($bibentries->entry('unall3')->get_labelname_info)->get_uniquelist, '5', 'Uniquelist - 15');
eq_or_diff($bibentries->entry('unall4')->get_field($bibentries->entry('unall4')->get_labelname_info)->get_uniquelist, '6', 'Uniquelist - 16');

# Testing "et al" counting as a uniquelist position
# ul01 = 3
# ul02 = 3 (because it will be "XXX and YYY and ZZZ et al" which disambiguated the list from
# "XXX and YYY and ZZZ"
eq_or_diff($bibentries->entry('ul01')->get_field($bibentries->entry('ul01')->get_labelname_info)->get_uniquelist, '3', 'Uniquelist - 17');
eq_or_diff($bibentries->entry('ul02')->get_field($bibentries->entry('ul02')->get_labelname_info)->get_uniquelist, '3', 'Uniquelist - 18');

#############################################################################

$biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('uniqueness1.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());
# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');
# Biblatex options
Biber::Config->setblxoption('maxcitenames', 1);
Biber::Config->setblxoption('mincitenames', 1);
Biber::Config->setblxoption('uniquename', 2);
Biber::Config->setblxoption('uniquelist', 1);
# Now generate the information
$biber->prepare;
$bibentries = $biber->sections->get_section('0')->bibentries;

eq_or_diff($bibentries->entry('test3')->get_field($bibentries->entry('test3')->get_labelname_info)->get_uniquelist, '2', 'Uniquelist - 19');
eq_or_diff($bibentries->entry('test3')->get_field($bibentries->entry('test3')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Uniquename - 9');
eq_or_diff($bibentries->entry('test3')->get_field($bibentries->entry('test3')->get_labelname_info)->nth_name(2)->get_uniquename, '2', 'Uniquename - 10');

eq_or_diff($bibentries->entry('test4')->get_field($bibentries->entry('test4')->get_labelname_info)->get_uniquelist, '2', 'Uniquelist - 20');
eq_or_diff($bibentries->entry('test4')->get_field($bibentries->entry('test4')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Uniquename - 11');
eq_or_diff($bibentries->entry('test4')->get_field($bibentries->entry('test4')->get_labelname_info)->nth_name(2)->get_uniquename, '2', 'Uniquename - 12');

eq_or_diff($bibentries->entry('test5')->get_field($bibentries->entry('test5')->get_labelname_info)->get_uniquelist, '2', 'Uniquelist - 21');
eq_or_diff($bibentries->entry('test5')->get_field($bibentries->entry('test5')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Uniquename - 13');
eq_or_diff($bibentries->entry('test5')->get_field($bibentries->entry('test5')->get_labelname_info)->nth_name(2)->get_uniquename, '1', 'Uniquename - 14');

#############################################################################

$biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('uniqueness4.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());
# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');
# Biblatex options
Biber::Config->setblxoption('maxcitenames', 3);
Biber::Config->setblxoption('mincitenames', 3);
Biber::Config->setblxoption('uniquename', 6);
Biber::Config->setblxoption('uniquelist', 1);
Biber::Config->setblxoption('singletitle', 0);
Biber::Config->setblxoption('labeldatespec', [ {content => 'date', type => 'field'} ]);
# Now generate the information
$biber->prepare;
$section = $biber->sections->get_section(0);
$bibentries = $section->bibentries;
$main = $biber->sortlists->get_list(0, 'nty/global', 'entry', 'nty', 'global');

eq_or_diff($bibentries->entry('us1')->get_field($bibentries->entry('us1')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Uniquename sparse - 1');
eq_or_diff($bibentries->entry('us1')->get_field($bibentries->entry('us1')->get_labelname_info)->nth_name(2)->get_uniquename, '0', 'Uniquename sparse - 2');
eq_or_diff($bibentries->entry('us2')->get_field($bibentries->entry('us2')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Uniquename sparse - 3');
eq_or_diff($bibentries->entry('us2')->get_field($bibentries->entry('us2')->get_labelname_info)->nth_name(2)->get_uniquename, '0', 'Uniquename sparse - 4');
eq_or_diff($bibentries->entry('us3')->get_field($bibentries->entry('us3')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Uniquename sparse - 5');
eq_or_diff($bibentries->entry('us3')->get_field($bibentries->entry('us3')->get_labelname_info)->nth_name(2)->get_uniquename, '0', 'Uniquename sparse - 6');
eq_or_diff($bibentries->entry('us4')->get_field($bibentries->entry('us4')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Uniquename sparse - 7');
eq_or_diff($bibentries->entry('us4')->get_field($bibentries->entry('us4')->get_labelname_info)->nth_name(2)->get_uniquename, '0', 'Uniquename sparse - 8');
eq_or_diff($bibentries->entry('us5')->get_field($bibentries->entry('us5')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Uniquename sparse - 9');
eq_or_diff($bibentries->entry('us6')->get_field($bibentries->entry('us6')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Uniquename sparse - 10');
eq_or_diff($bibentries->entry('us6')->get_field($bibentries->entry('us6')->get_labelname_info)->nth_name(2)->get_uniquename, '0', 'Uniquename sparse - 11');
eq_or_diff($bibentries->entry('us6')->get_field($bibentries->entry('us6')->get_labelname_info)->nth_name(3)->get_uniquename, '0', 'Uniquename sparse - 12');
eq_or_diff($bibentries->entry('us7')->get_field($bibentries->entry('us7')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Uniquename sparse - 13');
eq_or_diff($bibentries->entry('us7')->get_field($bibentries->entry('us7')->get_labelname_info)->nth_name(2)->get_uniquename, '0', 'Uniquename sparse - 14');
eq_or_diff($bibentries->entry('us8')->get_field($bibentries->entry('us8')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Uniquename sparse - 15');
eq_or_diff($bibentries->entry('us8')->get_field($bibentries->entry('us8')->get_labelname_info)->nth_name(2)->get_uniquename, '0', 'Uniquename sparse - 16');
eq_or_diff($bibentries->entry('us9')->get_field($bibentries->entry('us9')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Uniquename sparse - 17');
eq_or_diff($bibentries->entry('us9')->get_field($bibentries->entry('us9')->get_labelname_info)->nth_name(2)->get_uniquename, '0', 'Uniquename sparse - 18');
eq_or_diff($bibentries->entry('us10')->get_field($bibentries->entry('us10')->get_labelname_info)->nth_name(1)->get_uniquename, '1', 'Uniquename sparse - 19');
eq_or_diff($bibentries->entry('us10')->get_field($bibentries->entry('us10')->get_labelname_info)->nth_name(2)->get_uniquename, '1', 'Uniquename sparse - 20');
eq_or_diff($bibentries->entry('us11')->get_field($bibentries->entry('us11')->get_labelname_info)->nth_name(1)->get_uniquename, '1', 'Uniquename sparse - 21');
eq_or_diff($bibentries->entry('us11')->get_field($bibentries->entry('us11')->get_labelname_info)->nth_name(2)->get_uniquename, '1', 'Uniquename sparse - 22');
eq_or_diff($bibentries->entry('us12')->get_field($bibentries->entry('us12')->get_labelname_info)->nth_name(1)->get_uniquename, '2', 'Uniquename sparse - 23');
eq_or_diff($bibentries->entry('us12')->get_field($bibentries->entry('us12')->get_labelname_info)->nth_name(2)->get_uniquename, '0', 'Uniquename sparse - 24');
eq_or_diff($bibentries->entry('us13')->get_field($bibentries->entry('us13')->get_labelname_info)->nth_name(1)->get_uniquename, '2', 'Uniquename sparse - 25');
eq_or_diff($bibentries->entry('us13')->get_field($bibentries->entry('us13')->get_labelname_info)->nth_name(2)->get_uniquename, '0', 'Uniquename sparse - 26');

# maxcitenames/mincitenames is 3 in but us14 is still "et al" so it's a "different list
eq_or_diff($bibentries->entry('us14')->get_field($bibentries->entry('us14')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Uniquename sparse - 27');
eq_or_diff($bibentries->entry('us14')->get_field($bibentries->entry('us14')->get_labelname_info)->nth_name(2)->get_uniquename, '0', 'Uniquename sparse - 28');
eq_or_diff($bibentries->entry('us14')->get_field($bibentries->entry('us14')->get_labelname_info)->nth_name(3)->get_uniquename, '0', 'Uniquename sparse - 29');
eq_or_diff($bibentries->entry('us15')->get_field($bibentries->entry('us15')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Uniquename sparse - 30');
eq_or_diff($bibentries->entry('us15')->get_field($bibentries->entry('us15')->get_labelname_info)->nth_name(2)->get_uniquename, '0', 'Uniquename sparse - 31');
eq_or_diff($bibentries->entry('us15')->get_field($bibentries->entry('us15')->get_labelname_info)->nth_name(3)->get_uniquename, '0', 'Uniquename sparse - 32');

eq_or_diff($bibentries->entry('us16')->get_field($bibentries->entry('us16')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Uniquename sparse - 33');
eq_or_diff($bibentries->entry('us16')->get_field($bibentries->entry('us16')->get_labelname_info)->nth_name(2)->get_uniquename, '0', 'Uniquename sparse - 34');
eq_or_diff($bibentries->entry('us16')->get_field($bibentries->entry('us16')->get_labelname_info)->nth_name(3)->get_uniquename, '0', 'Uniquename sparse - 35');
ok(is_undef($bibentries->entry('us16')->get_field($bibentries->entry('us16')->get_labelname_info)->get_uniquelist), 'Uniquename sparse - 36');
eq_or_diff($bibentries->entry('us17')->get_field($bibentries->entry('us17')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Uniquename sparse - 37');
eq_or_diff($bibentries->entry('us17')->get_field($bibentries->entry('us17')->get_labelname_info)->nth_name(2)->get_uniquename, '0', 'Uniquename sparse - 38');
eq_or_diff($bibentries->entry('us17')->get_field($bibentries->entry('us17')->get_labelname_info)->nth_name(3)->get_uniquename, '0', 'Uniquename sparse - 39');
eq_or_diff($bibentries->entry('us17')->get_field($bibentries->entry('us17')->get_labelname_info)->nth_name(4)->get_uniquename, '0', 'Uniquename sparse - 40');
eq_or_diff($bibentries->entry('us17')->get_field($bibentries->entry('us17')->get_labelname_info)->get_uniquelist, '4', 'Uniquename sparse - 41');
eq_or_diff($bibentries->entry('us18')->get_field($bibentries->entry('us18')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Uniquename sparse - 42');
eq_or_diff($bibentries->entry('us19')->get_field($bibentries->entry('us19')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Uniquename sparse - 43');
ok(is_undef($bibentries->entry('us18')->get_field($bibentries->entry('us18')->get_labelname_info)->get_uniquelist), 'Uniquename sparse - 44');
eq_or_diff($bibentries->entry('us19')->get_field($bibentries->entry('us19')->get_labelname_info)->get_uniquelist, '4', 'Uniquename sparse - 45');

#############################################################################

$biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('uniqueness4.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());
# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');
# Biblatex options
Biber::Config->setblxoption('maxcitenames', 3);
Biber::Config->setblxoption('mincitenames', 1);
Biber::Config->setblxoption('uniquename', 6);
Biber::Config->setblxoption('uniquelist', 1);
Biber::Config->setblxoption('singletitle', 0);
Biber::Config->setblxoption('labeldatespec', [ {content => 'date', type => 'field'} ]);
# Now generate the information
$biber->prepare;
$section = $biber->sections->get_section(0);
$bibentries = $section->bibentries;
$main = $biber->sortlists->get_list(0, 'nty/global', 'entry', 'nty', 'global');


# maxcitenames/mincitenames = 3/1 so these will not truncate to the same list (since
# us15 would not be truncated at all) and they therefore would not need disambiguating with
# uniquename = 5 or 6
eq_or_diff($bibentries->entry('us14')->get_field($bibentries->entry('us14')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Uniquename sparse - 46');
eq_or_diff($bibentries->entry('us14')->get_field($bibentries->entry('us14')->get_labelname_info)->nth_name(2)->get_uniquename, '0', 'Uniquename sparse - 47');
eq_or_diff($bibentries->entry('us14')->get_field($bibentries->entry('us14')->get_labelname_info)->nth_name(3)->get_uniquename, '0', 'Uniquename sparse - 48');
eq_or_diff($bibentries->entry('us15')->get_field($bibentries->entry('us15')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Uniquename sparse - 49');
eq_or_diff($bibentries->entry('us15')->get_field($bibentries->entry('us15')->get_labelname_info)->nth_name(2)->get_uniquename, '0', 'Uniquename sparse - 50');
eq_or_diff($bibentries->entry('us15')->get_field($bibentries->entry('us15')->get_labelname_info)->nth_name(3)->get_uniquename, '0', 'Uniquename sparse - 51');

#
eq_or_diff($bibentries->entry('us20')->get_field($bibentries->entry('us20')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Uniquename sparse - 52');
eq_or_diff($bibentries->entry('us21')->get_field($bibentries->entry('us21')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Uniquename sparse - 53');
eq_or_diff($bibentries->entry('us22')->get_field($bibentries->entry('us22')->get_labelname_info)->nth_name(2)->get_uniquename, '0', 'Uniquename sparse - 54');
eq_or_diff($bibentries->entry('us23')->get_field($bibentries->entry('us23')->get_labelname_info)->nth_name(1)->get_uniquename, '2', 'Uniquename sparse - 55');
eq_or_diff($bibentries->entry('us24')->get_field($bibentries->entry('us24')->get_labelname_info)->nth_name(1)->get_uniquename, '2', 'Uniquename sparse - 56');
eq_or_diff($bibentries->entry('us25')->get_field($bibentries->entry('us25')->get_labelname_info)->nth_name(2)->get_uniquename, '0', 'Uniquename sparse - 57');

#############################################################################

$biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('uniqueness4.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());
# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');
# Biblatex options
Biber::Config->setblxoption('maxcitenames', 2);
Biber::Config->setblxoption('mincitenames', 1);
Biber::Config->setblxoption('uniquename', 6);
Biber::Config->setblxoption('uniquelist', 1);
Biber::Config->setblxoption('singletitle', 0);
Biber::Config->setblxoption('labeldatespec', [ {content => 'date', type => 'field'} ]);
# Now generate the information
$biber->prepare;
$section = $biber->sections->get_section(0);
$bibentries = $section->bibentries;
$main = $biber->sortlists->get_list(0, 'nty/global', 'entry', 'nty', 'global');

# maxcitenames/mincitenames = 2/1 so list are the same and need disambiguating but only in the first
# name as the others are not visible

eq_or_diff($bibentries->entry('us14')->get_field($bibentries->entry('us14')->get_labelname_info)->nth_name(1)->get_uniquename, '1', 'Uniquename sparse - 58');
eq_or_diff($bibentries->entry('us14')->get_field($bibentries->entry('us14')->get_labelname_info)->nth_name(2)->get_uniquename, '0', 'Uniquename sparse - 59');
eq_or_diff($bibentries->entry('us14')->get_field($bibentries->entry('us14')->get_labelname_info)->nth_name(3)->get_uniquename, '0', 'Uniquename sparse - 60');
eq_or_diff($bibentries->entry('us15')->get_field($bibentries->entry('us15')->get_labelname_info)->nth_name(1)->get_uniquename, '1', 'Uniquename sparse - 61');
eq_or_diff($bibentries->entry('us15')->get_field($bibentries->entry('us15')->get_labelname_info)->nth_name(2)->get_uniquename, '0', 'Uniquename sparse - 62');
eq_or_diff($bibentries->entry('us15')->get_field($bibentries->entry('us15')->get_labelname_info)->nth_name(3)->get_uniquename, '0', 'Uniquename sparse - 63');
eq_or_diff($bibentries->entry('us26')->get_field($bibentries->entry('us26')->get_labelname_info)->nth_name(1)->get_uniquename, '1', 'Uniquename sparse - 64');
eq_or_diff($bibentries->entry('us27')->get_field($bibentries->entry('us27')->get_labelname_info)->nth_name(1)->get_uniquename, '2', 'Uniquename sparse - 65');
eq_or_diff($bibentries->entry('us28')->get_field($bibentries->entry('us28')->get_labelname_info)->nth_name(1)->get_uniquename, '2', 'Uniquename sparse - 66');
eq_or_diff($bibentries->entry('us29')->get_field($bibentries->entry('us29')->get_labelname_info)->nth_name(1)->get_uniquename, '1', 'Uniquename sparse - 67');
eq_or_diff($bibentries->entry('us30')->get_field($bibentries->entry('us30')->get_labelname_info)->nth_name(1)->get_uniquename, '1', 'Uniquename sparse - 68');

#############################################################################

$biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('uniqueness5.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());
# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');
# Biblatex options
Biber::Config->setblxoption('maxcitenames', 1);
Biber::Config->setblxoption('mincitenames', 1);
Biber::Config->setblxoption('uniquename', 2);
Biber::Config->setblxoption('uniquelist', 2);
Biber::Config->setblxoption('singletitle', 0);
Biber::Config->setblxoption('labeldatespec', [ {content => 'date', type => 'field'} ]);
# Now generate the information
$biber->prepare;
$section = $biber->sections->get_section(0);
$bibentries = $section->bibentries;
$main = $biber->sortlists->get_list(0, 'nty/global', 'entry', 'nty', 'global');

ok(is_undef($bibentries->entry('uls1')->get_field($bibentries->entry('uls1')->get_labelname_info)->get_uniquelist), 'Uniquelist strict - 1');
ok(is_undef($bibentries->entry('uls2')->get_field($bibentries->entry('uls2')->get_labelname_info)->get_uniquelist), 'Uniquelist strict - 2');
eq_or_diff($bibentries->entry('uls3')->get_field($bibentries->entry('uls3')->get_labelname_info)->get_uniquelist, '2', 'Uniquelist strict - 3');
eq_or_diff($bibentries->entry('uls4')->get_field($bibentries->entry('uls4')->get_labelname_info)->get_uniquelist, '2', 'Uniquelist strict - 4');
eq_or_diff($bibentries->entry('uls5')->get_field($bibentries->entry('uls5')->get_labelname_info)->get_uniquelist, '2', 'Uniquelist strict - 5');
eq_or_diff($bibentries->entry('uls6')->get_field($bibentries->entry('uls6')->get_labelname_info)->get_uniquelist, '2', 'Uniquelist strict - 6');
ok(is_undef($bibentries->entry('uls7')->get_field($bibentries->entry('uls7')->get_labelname_info)->get_uniquelist), 'Uniquelist strict - 7');

#############################################################################

$biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('uniqueness5.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());
# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');
# Biblatex options
Biber::Config->setblxoption('maxcitenames', 3);
Biber::Config->setblxoption('mincitenames', 2);
Biber::Config->setblxoption('uniquename', 2);
Biber::Config->setblxoption('uniquelist', 2);
Biber::Config->setblxoption('singletitle', 0);
Biber::Config->setblxoption('labeldatespec', [ {content => 'date', type => 'field'} ]);
# Now generate the information
$biber->prepare;
$section = $biber->sections->get_section(0);
$bibentries = $section->bibentries;
$main = $biber->sortlists->get_list(0, 'nty/global', 'entry', 'nty', 'global');

ok(is_undef($bibentries->entry('uls8')->get_field($bibentries->entry('uls8')->get_labelname_info)->get_uniquelist), 'Uniquelist strict - 8');
ok(is_undef($bibentries->entry('uls9')->get_field($bibentries->entry('uls9')->get_labelname_info)->get_uniquelist),'Uniquelist strict - 9');
ok(is_undef($bibentries->entry('uls1')->get_field($bibentries->entry('uls1')->get_labelname_info)->get_uniquelist),'Uniquelist strict - 10');
eq_or_diff($bibentries->entry('uls10')->get_field($bibentries->entry('uls10')->get_labelname_info)->get_uniquelist, '3', 'Uniquelist strict - 11');
eq_or_diff($bibentries->entry('uls11')->get_field($bibentries->entry('uls11')->get_labelname_info)->get_uniquelist, '3', 'Uniquelist strict - 12');
ok(is_undef($bibentries->entry('uls12')->get_field($bibentries->entry('uls12')->get_labelname_info)->get_uniquelist), 'Uniquelist strict - 13');


#############################################################################

$biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('uniqueness3.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());
# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');
# Biblatex options
Biber::Config->setblxoption('uniquename', 1);
Biber::Config->setblxoption('uniquelist', 0);
Biber::Config->setblxoption('singletitle', 1);
Biber::Config->setblxoption('labeldatespec', [ {content => 'date', type => 'field'} ]);
# Now generate the information
$biber->prepare;
$section = $biber->sections->get_section(0);
$bibentries = $section->bibentries;
$main = $biber->sortlists->get_list(0, 'nty/global', 'entry', 'nty', 'global');

eq_or_diff($main->get_extrayeardata('ey1'), '1', 'Extrayear - 1');
eq_or_diff($main->get_extrayeardata('ey2'), '2', 'Extrayear - 2');
eq_or_diff($main->get_extrayeardata('ey3'), '1', 'Extrayear - 3');
eq_or_diff($main->get_extrayeardata('ey4'), '2', 'Extrayear - 4');
eq_or_diff($main->get_extrayeardata('ey5'), '1', 'Extrayear - 5');
eq_or_diff($main->get_extrayeardata('ey6'), '2', 'Extrayear - 6');
ok(is_undef($bibentries->entry('ey1')->get_field('singletitle')), 'Singletitle - 1');
ok(is_undef($bibentries->entry('ey2')->get_field('singletitle')), 'Singletitle - 2');
ok(is_undef($bibentries->entry('ey5')->get_field('singletitle')), 'Singletitle - 3');

#############################################################################

$biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('uniqueness3.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());
# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');
# Biblatex options
Biber::Config->setblxoption('uniquename', 2);
Biber::Config->setblxoption('uniquelist', 1);
Biber::Config->setblxoption('singletitle', 1);
Biber::Config->setblxoption('labeldatespec', [ {content => 'date', type => 'field'} ]);
# Now generate the information
$biber->prepare;
$section = $biber->sections->get_section(0);
$bibentries = $section->bibentries;
$main = $biber->sortlists->get_list(0, 'nty/global', 'entry', 'nty', 'global');

ok(is_undef($main->get_extrayeardata('ey1')), 'Extrayear - 7');
ok(is_undef($main->get_extrayeardata('ey2')), 'Extrayear - 8');
eq_or_diff($main->get_extrayeardata('ey3'), '1', 'Extrayear - 9');
eq_or_diff($main->get_extrayeardata('ey4'), '2', 'Extrayear - 10');
ok(is_undef($main->get_extrayeardata('ey5')), 'Extrayear - 11');
ok(is_undef($main->get_extrayeardata('ey6')), 'Extrayear - 12');
eq_or_diff($bibentries->entry('ey1')->get_field('singletitle'), '1', 'Singletitle - 4');
eq_or_diff($bibentries->entry('ey2')->get_field('singletitle'), '1', 'Singletitle - 5');
eq_or_diff($bibentries->entry('ey5')->get_field('singletitle'), '1', 'Singletitle - 6');

#############################################################################

$biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('uniqueness3.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());
# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');
# Biblatex options
Biber::Config->setblxoption('uniquename', 0);
Biber::Config->setblxoption('uniquelist', 0);
Biber::Config->setblxoption('singletitle', 1);
Biber::Config->setblxoption('labeldatespec', [ {content => 'date', type => 'field'} ]);
# Now generate the information
$biber->prepare;
$section = $biber->sections->get_section(0);
$bibentries = $section->bibentries;
$main = $biber->sortlists->get_list(0, 'nty/global', 'entry', 'nty', 'global');

eq_or_diff($main->get_extrayeardata('ey1'), '1', 'Extrayear - 13');
eq_or_diff($main->get_extrayeardata('ey2'), '2', 'Extrayear - 14');
eq_or_diff($main->get_extrayeardata('ey3'), '1', 'Extrayear - 15');
eq_or_diff($main->get_extrayeardata('ey4'), '2', 'Extrayear - 16');
eq_or_diff($main->get_extrayeardata('ey5'), '1', 'Extrayear - 17');
eq_or_diff($main->get_extrayeardata('ey6'), '2', 'Extrayear - 18');
ok(is_undef($bibentries->entry('ey1')->get_field('singletitle')), 'Singletitle - 7');
ok(is_undef($bibentries->entry('ey2')->get_field('singletitle')), 'Singletitle - 8');

#############################################################################

# Testing uniquename = 3
$biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('uniqueness2.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());
# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');
# Biblatex options
Biber::Config->setblxoption('uniquename', 3);
Biber::Config->setblxoption('uniquelist', 1);
# Now generate the information
$biber->prepare;
$section = $biber->sections->get_section(0);
$bibentries = $section->bibentries;
$main = $biber->sortlists->get_list(0, 'nty/global', 'entry', 'nty', 'global');

eq_or_diff($bibentries->entry('un8')->get_field($bibentries->entry('un8')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Forced init expansion - 1');
eq_or_diff($bibentries->entry('un8')->get_field($bibentries->entry('un8')->get_labelname_info)->nth_name(2)->get_uniquename, '0', 'Forced init expansion - 2');
eq_or_diff($bibentries->entry('un8')->get_field($bibentries->entry('un8')->get_labelname_info)->nth_name(3)->get_uniquename, '1', 'Forced init expansion - 3');
eq_or_diff($bibentries->entry('un9')->get_field($bibentries->entry('un9')->get_labelname_info)->nth_name(1)->get_uniquename, '0', 'Forced init expansion - 4');
eq_or_diff($bibentries->entry('un9')->get_field($bibentries->entry('un9')->get_labelname_info)->nth_name(2)->get_uniquename, '0', 'Forced init expansion - 5');
eq_or_diff($bibentries->entry('un9')->get_field($bibentries->entry('un9')->get_labelname_info)->nth_name(3)->get_uniquename, '1', 'Forced init expansion - 6');
eq_or_diff($bibentries->entry('un9')->get_field($bibentries->entry('un9')->get_labelname_info)->nth_name(4)->get_uniquename, '1', 'Forced init expansion - 7');
eq_or_diff($bibentries->entry('un10')->get_field($bibentries->entry('un10')->get_labelname_info)->nth_name(1)->get_uniquename, '1', 'Forced init expansion - 8');

#############################################################################

# Testing uniquename = 4
$biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('uniqueness2.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());
# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');
# Biblatex options
Biber::Config->setblxoption('uniquename', 4);
Biber::Config->setblxoption('uniquelist', 1);
# Now generate the information
$biber->prepare;
$section = $biber->sections->get_section(0);
$bibentries = $section->bibentries;
$main = $biber->sortlists->get_list(0, 'nty/global', 'entry', 'nty', 'global');

eq_or_diff($bibentries->entry('un8')->get_field($bibentries->entry('un8')->get_labelname_info)->nth_name(1)->get_uniquename, '2', 'Forced name expansion - 1');
eq_or_diff($bibentries->entry('un8')->get_field($bibentries->entry('un8')->get_labelname_info)->nth_name(2)->get_uniquename, '0', 'Forced name expansion - 2');
eq_or_diff($bibentries->entry('un8')->get_field($bibentries->entry('un8')->get_labelname_info)->nth_name(3)->get_uniquename, '1', 'Forced name expansion - 3');
eq_or_diff($bibentries->entry('un9')->get_field($bibentries->entry('un9')->get_labelname_info)->nth_name(1)->get_uniquename, '2', 'Forced name expansion - 4');
eq_or_diff($bibentries->entry('un9')->get_field($bibentries->entry('un9')->get_labelname_info)->nth_name(2)->get_uniquename, '0', 'Forced name expansion - 5');
eq_or_diff($bibentries->entry('un9')->get_field($bibentries->entry('un9')->get_labelname_info)->nth_name(3)->get_uniquename, '1', 'Forced name expansion - 6');
eq_or_diff($bibentries->entry('un9')->get_field($bibentries->entry('un9')->get_labelname_info)->nth_name(4)->get_uniquename, '1', 'Forced name expansion - 7');
eq_or_diff($bibentries->entry('un10')->get_field($bibentries->entry('un10')->get_labelname_info)->nth_name(1)->get_uniquename, '1', 'Forced name expansion - 8');

