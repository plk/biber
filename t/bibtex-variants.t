# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 26;
use Test::Differences;
unified_diff;

use Biber;
use Biber::Utils;
use Biber::Output::bbl;
use Encode;
use Log::Log4perl;
use Unicode::Normalize;
chdir("t/tdata");

# Set up Biber object
my $biber = Biber->new(configfile => 'biber-test-variants.conf');
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

$biber->parse_ctrlfile("bibtex-variants.bcf");
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('sortlocale', 'C');
Biber::Config->setoption('fastsort', 1);

# THERE IS A CONFIG FILE BEING READ TO TEST USER MAPS TOO!

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $bibentries = $section->bibentries;
my $main = $biber->sortlists->get_list(0, 'nty', 'entry', 'nty');

my $f7 = [ "The variant enabled name field 'author' in entry 'forms7' has variants with different numbers of items. This will almost certainly cause problems.",
           "The variant enabled list field 'location' in entry 'forms7' has variants with different numbers of items. This will almost certainly cause problems." ];

is($bibentries->entry('forms1')->get_field('title', 'original', 'russian'), 'Мухаммад ибн муса ал-Хорезми. Около 783 – около 850', 'forms - 1');
is($bibentries->entry('forms1')->get_field('title', 'original', 'russian'), 'Мухаммад ибн муса ал-Хорезми. Около 783 – около 850', 'forms - 2');
is($bibentries->entry('forms1')->get_field('title', 'romanised', 'russian'), 'Mukhammad al-Khorezmi. Okolo 783 – okolo 850', 'forms - 3');
is($bibentries->entry('forms1')->get_field('title', 'translated', 'english'), 'Mukhammad al-Khorezmi. Ca. 783 – ca. 850', 'forms - 4');
is($bibentries->entry('forms1')->get_field('publisher', 'original', 'russian')->[0], 'Наука', 'forms - 5');
is($bibentries->entry('forms1')->get_field('author', 'original', 'russian')->nth_name(3)->get_firstname, 'Борис', 'forms - 6');
# global labelname form
is($bibentries->entry('forms1')->get_field($bibentries->entry('forms1')->get_labelname_info, 'original', 'russian')->nth_name(3)->get_firstname, 'Борис', 'labelname - 1');
# per-type labelname form
is($bibentries->entry('forms2')->get_field($bibentries->entry('forms2')->get_labelname_info, 'uniform', 'russian')->nth_name(1)->get_firstname, 'Boris', 'labelname - 2');
# global labeltitle form
is($bibentries->entry('forms1')->get_field($bibentries->entry('forms1')->get_labeltitle_info, 'original', 'russian'), 'Мухаммад ибн муса ал-Хорезми. Около 783 – около 850', 'labeltitle - 1');
# per-type labeltitle form
is($bibentries->entry('forms2')->get_field($bibentries->entry('forms2')->get_labeltitle_info, 'romanised', 'russian'), 'Mukhammad al-Khorezmi. Okolo 783 – okolo 850', 'labeltitle - 2');
is_deeply($bibentries->entry('forms7')->get_field('warnings'), $f7, 'MS warnings - 1') ;

my $S = { spec => [
         [
          {},
          {'author'     => {'form' => 'uniform'}},
          {'author'     => {}},
         ],
         [
          {},
          {'title'      => {'form' => 'translated', 'lang' => 'lang1'}},
          {'title'      => {'form' => 'translated', 'lang' => 'lang2'}},
          {'title'      => {}}
         ],
         [
          {},
          {'location'      => {'form' => 'romanised'}},
         ],
         [
          {},
          {'year'  => {}},
         ],
        ]};

$main->set_sortscheme($S);

$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare(1);
$section = $biber->sections->get_section(0);
# There is complex interaction here between the variant sorting scheme above and the fallback defaults for variants in the .bcf
is_deeply([$main->get_keys], ['forms12', 'forms13', 'forms14', 'forms5', 'forms8', 'forms15', 'forms4', 'forms11', 'forms9', 'forms10', 'forms6', 'forms2', 'forms1', 'forms7'], 'Forms sorting - 1');
# Uses name from generic variant for sorting when a name in the sorting variant is null
is(NFC($main->get_sortdata('forms1')->[0]), 'Bulgakov!Pavel#Smith!Jim#Rosenfeld!Boris,Мухаммад ибн муса алХорезми Около 783 около 850,Moskva!London,2002', 'Null name sortstring');

# reset options and regenerate information
Biber::Config->setblxoption('labelalphatemplate', {
  labelelement => [
             {
               labelpart => [
                 {
                  content                   => "author",
                  form                      => "uniform",
                  substring_width           => "3",
                  substring_side            => "left"
                 },
               ],
               order => 1,
             },
             {
               labelpart => [
                 {
                  content                   => "title",
                  form                      => "translated",
                  lang                      => "lang1",
                  substring_width           => "3",
                  substring_side            => "left"
                 },
                 {
                  content                   => "title",
                  substring_width           => "3",
                  substring_side            => "left"
                 },
               ],
               order => 2,
             },
           ],
  type  => "global",
});


foreach my $k ($section->get_citekeys) {
  $bibentries->entry($k)->del_field('sortlabelalpha');
  $bibentries->entry($k)->del_field('labelalpha');
  $main->set_extraalphadata_for_key($k, undef);
}

$biber->prepare(1);
$section = $biber->sections->get_section(0);
$main = $biber->sortlists->get_list(0, 'nty', 'entry', 'nty');
$bibentries = $section->bibentries;

is($bibentries->entry('forms1')->get_field('sortlabelalpha'), 'BulSmiRosМух', 'labelalpha forms - 1');
is($bibentries->entry('forms4')->get_field('sortlabelalpha'), 'F t', 'labelalpha forms - 2');
is($bibentries->entry('forms5')->get_field('sortlabelalpha'), 'A t', 'labelalpha forms - 3');
is($bibentries->entry('forms6')->get_field('sortlabelalpha'), 'Z t', 'labelalpha forms - 4');

my $forms1 = q|    \entry{forms1}{book}{vlang=russian}
      \name[form=original,lang=russian]{author}{3}{}{%
        {{uniquename=0,hash=e7c368e13a02c9c0f0d3629316eb6227}{Булгаков}{Б\bibinitperiod}{Павел}{П\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=24b7be5b577041e83bf3c4fe658111a5}{Smith}{S\bibinitperiod}{Jim}{J\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=f5f90439e5cc9d87b2665d584974a41d}{Розенфельд}{Р\bibinitperiod}{Борис}{Б\bibinitperiod}{}{}{}{}}%
      }
      \name[form=uniform,lang=russian]{author}{3}{}{%
        {{uniquename=0,hash=d3e42eb37529f4d05f9646c333b5fd5f}{Bulgakov}{B\bibinitperiod}{Pavel}{P\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=24b7be5b577041e83bf3c4fe658111a5}{Smith}{S\bibinitperiod}{Jim}{J\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=87d0ec74cbe7f9e39f5bbc25930f1474}{Rosenfeld}{R\bibinitperiod}{Boris}{B\bibinitperiod}{}{}{}{}}%
      }
      \list[form=original,lang=russian]{institution}{1}{%
        {University of Life}%
      }
      \list[form=original,lang=russian]{location}{2}{%
        {Москва}%
        {London}%
      }
      \list[form=romanised,lang=russian]{location}{2}{%
        {Moskva}%
        {London}%
      }
      \list[form=translated,lang=russian]{location}{2}{%
        {Moscow}%
        {London}%
      }
      \list[form=original,lang=russian]{publisher}{1}{%
        {Наука}%
      }
      \list[form=romanised,lang=russian]{publisher}{1}{%
        {Nauka}%
      }
      \list[form=translated,lang=russian]{publisher}{1}{%
        {Science}%
      }
      \strng{namehash}{899713297eb2d663fbb6a0b41bf66c4c}
      \strng{fullhash}{899713297eb2d663fbb6a0b41bf66c4c}
      \field{labelalpha}{БSР02}
      \field{sortinit}{B}
      \field{sortinithash}{4ecbea03efd0532989d3836d1a048c32}
      \true{singletitle}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{day}{01}
      \field{langid}{russian}
      \field{month}{10}
      \field[form=original,lang=russian]{title}{Мухаммад ибн муса ал-Хорезми. Около 783 – около 850}
      \field[form=romanised,lang=russian]{title}{Mukhammad al-Khorezmi. Okolo 783 – okolo 850}
      \field[form=translated,lang=english]{title}{Mukhammad al-Khorezmi. Ca. 783 – ca. 850}
      \field{year}{2002}
    \endentry
|;

my $forms9 = q|    \entry{forms9}{book}{vlang=french}
      \field{sortinit}{U}
      \field{sortinithash}{8145509bd2718876fc77d31fd2cde117}
      \field{labeltitlesource}{title}
      \field{langid}{french}
      \field[form=original,lang=french]{title}{Un titel}
    \endentry
|;

my $forms10 = q|    \entry{forms10}{book}{vlang=french}
      \field{sortinit}{U}
      \field{sortinithash}{8145509bd2718876fc77d31fd2cde117}
      \field{labeltitlesource}{title}
      \field[form=original,lang=french]{journaltitle}{FJ}
      \field[form=translated,lang=french]{journaltitle}{TFJ}
      \field{langid}{french}
      \field[form=original,lang=french]{title}{Un titel}
    \endentry
|;

my $forms11 = q|    \entry{forms11}{unpublished}{}
      \field{sortinit}{T}
      \field{sortinithash}{423d138a005a533b47e6475e39378bf2}
      \true{singletitle}
      \field{labeltitlesource}{title}
      \field[form=translated,lang=german]{edition}{Gedition}
      \field[form=translated,lang=french]{maintitle}{Maintitle translated FRENCH}
      \field[form=uniform,lang=german]{subtitle}{Subtitle uniform GERMAN}
      \field[form=original,lang=english]{title}{TITLE}
      \field[form=translated,lang=french]{title}{TITLE translated FRENCH}
    \endentry
|;

my $forms12 = q|    \entry{forms12}{unpublished}{}
      \field{sortinit}{0}
      \field{sortinithash}{a08a9549c5c2429f8cec5d1a581b26ca}
      \field[form=translated,lang=german]{edition}{Gedition}
      \field[form=translated,lang=french]{journaltitle}{Jtitle translated french}
      \field[form=uniform,lang=french]{journaltitle}{Jtitle uniform french}
      \field[form=translated,lang=french]{note}{Note translated french}
      \field[form=translated,lang=german]{note}{Note translated german}
    \endentry
|;

my $forms13 = q|    \entry{forms13}{unpublished}{}
      \field{sortinit}{0}
      \field{sortinithash}{a08a9549c5c2429f8cec5d1a581b26ca}
      \field[form=translated,lang=german]{edition}{Gedition}
      \field[form=original,lang=french]{journaltitle}{JTITLE french}
      \field[form=translated,lang=english]{note}{NOTE translated}
    \endentry
|;

my $forms14 = q|    \entry{forms14}{unpublished}{}
      \field{sortinit}{0}
      \field{sortinithash}{a08a9549c5c2429f8cec5d1a581b26ca}
      \field[form=romanised,lang=english]{booktitle}{German title}
      \field[form=translated,lang=german]{edition}{Gedition}
      \field[form=original,lang=english]{series}{B}
      \field[form=translated,lang=english]{series}{A}
    \endentry
|;

my $forms15 = q|    \entry{forms15}{book}{autovlang=true}
      \list[form=original,lang=english]{location}{1}{%
        {Leipzig}%
      }
      \list[form=original,lang=english]{publisher}{1}{%
        {Hermann Mendelssohn}%
      }
      \field{labelalpha}{03}
      \field{sortinit}{Π}
      \field{sortinithash}{9056cb6813a3c373de7ee34a24f2f7ae}
      \true{singletitle}
      \field[form=original,lang=latin]{booktitle}{Acta Apocryphorum Apostolorum}
      \field[form=original,lang=greek]{title}{Περίοδοι καὶ μαρτύριον τοῦ ἁγίου Βαρνάβα τοῦ ἀποστόλου}
      \field[form=translated,lang=french]{title}{Actes de Barnabé}
      \field[form=uniform,lang=latin]{title}{Acta Barnabae}
      \field{volume}{2.2}
      \field{year}{1903}
      \field{pages}{292\bibrangedash 302}
      \range{pages}{11}
    \endentry
|;

eq_or_diff(encode_utf8($out->get_output_entry('forms1', $main)), encode_utf8($forms1), 'bbl entry - forms 1') ;
is($bibentries->entry('forms8')->get_field('title', 'original', 'lang1'), 'L title', 'lang only');
eq_or_diff(encode_utf8($out->get_output_entry('forms9', $main)), encode_utf8($forms9), 'bbl entry - langid option');
eq_or_diff(encode_utf8($out->get_output_entry('forms10', $main)), encode_utf8($forms10), 'bbl entry - vlang with unset options');
eq_or_diff(encode_utf8($out->get_output_entry('forms11', $main)), encode_utf8($forms11), 'bbl entry - mapping with forms/langs - 1');
eq_or_diff(encode_utf8($out->get_output_entry('forms12', $main)), encode_utf8($forms12), 'bbl entry - mapping with forms/langs - 2');
eq_or_diff(encode_utf8($out->get_output_entry('forms13', $main)), encode_utf8($forms13), 'bbl entry - mapping with forms/langs - 3');
eq_or_diff(encode_utf8($out->get_output_entry('forms14', $main)), encode_utf8($forms14), 'bbl entry - mapping with forms/langs - 4');
eq_or_diff(encode_utf8($out->get_output_entry('forms15', $main)), encode_utf8($forms15), 'autovlang=true as entry option');

