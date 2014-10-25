# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 29;

use Biber;
use Biber::Utils;
use Biber::Output::bbl;
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

is($bibentries->entry('forms1')->get_field('title'), 'Мухаммад ибн муса ал-Хорезми. Около 783 – около 850', 'forms - 1');
is($bibentries->entry('forms1')->get_field('title', 'original'), 'Мухаммад ибн муса ал-Хорезми. Около 783 – около 850', 'forms - 2');
is($bibentries->entry('forms1')->get_field('title', 'romanised'), 'Mukhammad al-Khorezmi. Okolo 783 – okolo 850', 'forms - 3');
is($bibentries->entry('forms1')->get_field('title', 'translated'), 'Mukhammad al-Khorezmi. Ca. 783 – ca. 850', 'forms - 4');
is($bibentries->entry('forms1')->get_field('publisher', 'original')->[0], 'Наука', 'forms - 5');
is($bibentries->entry('forms1')->get_field('author')->nth_name(3)->get_firstname, 'Борис', 'forms - 6');
# global labelname form
is($bibentries->entry('forms1')->get_field('labelname')->nth_name(3)->get_firstname, 'Борис', 'labelname - 1');
# per-type labelname form
is($bibentries->entry('forms2')->get_field('labelname')->nth_name(1)->get_firstname, 'Boris', 'labelname - 2');
# per-entry labelname form
is($bibentries->entry('forms3')->get_field('labelname')->nth_name(1)->get_firstname, 'Борис', 'labelname - 3');
# global labeltitle form
is($bibentries->entry('forms1')->get_field('labeltitle'), 'Мухаммад ибн муса ал-Хорезми. Около 783 – около 850', 'labeltitle - 1');
# per-type labeltitle form
is($bibentries->entry('forms2')->get_field('labeltitle'), 'Mukhammad al-Khorezmi. Okolo 783 – okolo 850', 'labeltitle - 2');
# per-entry labeltitle form
is($bibentries->entry('forms3')->get_field('labeltitle'), 'Mukhammad al-Khorezmi. Ca. 783 – ca. 850', 'labeltitle - 3');
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
is_deeply([$main->get_keys], ['forms13', 'forms14', 'forms15', 'forms5', 'forms8', 'forms4', 'forms12', 'forms9', 'forms10', 'forms11', 'forms6', 'forms3', 'forms2', 'forms1', 'forms16', 'forms7'], 'Forms sorting - 1');
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
      \name{labelname}{3}{}{%
        {{uniquename=0,hash=e7c368e13a02c9c0f0d3629316eb6227}{Булгаков}{Б\bibinitperiod}{Павел}{П\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=24b7be5b577041e83bf3c4fe658111a5}{Smith}{S\bibinitperiod}{Jim}{J\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=f5f90439e5cc9d87b2665d584974a41d}{Розенфельд}{Р\bibinitperiod}{Борис}{Б\bibinitperiod}{}{}{}{}}%
      }
      \name[form=original,lang=russian]{author}{3}{}{%
        {{uniquename=0,hash=e7c368e13a02c9c0f0d3629316eb6227}{Булгаков}{Б\bibinitperiod}{Павел}{П\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=24b7be5b577041e83bf3c4fe658111a5}{Smith}{S\bibinitperiod}{Jim}{J\bibinitperiod}{}{}{}{}}%
        {{uniquename=0,hash=f5f90439e5cc9d87b2665d584974a41d}{Розенфельд}{Р\bibinitperiod}{Борис}{Б\bibinitperiod}{}{}{}{}}%
      }
      \name[form=uniform,lang=russian]{author}{3}{}{%
        {{hash=d3e42eb37529f4d05f9646c333b5fd5f}{Bulgakov}{B\bibinitperiod}{Pavel}{P\bibinitperiod}{}{}{}{}}%
        {{hash=24b7be5b577041e83bf3c4fe658111a5}{Smith}{S\bibinitperiod}{Jim}{J\bibinitperiod}{}{}{}{}}%
        {{hash=87d0ec74cbe7f9e39f5bbc25930f1474}{Rosenfeld}{R\bibinitperiod}{Boris}{B\bibinitperiod}{}{}{}{}}%
      }
      \field{labelnamesourcefield}{author}
      \field{labelnamesourceform}{original}
      \field{labelnamesourcelang}{russian}
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
      \list[form=translated,lang=english]{location}{2}{%
        {Moscow}%
        {London}%
      }
      \list[form=original,lang=russian]{publisher}{1}{%
        {Наука}%
      }
      \list[form=romanised,lang=russian]{publisher}{1}{%
        {Nauka}%
      }
      \list[form=translated,lang=english]{publisher}{1}{%
        {Science}%
      }
      \strng{namehash}{d56c0403019e70d45bafa420d2695fa9}
      \strng{fullhash}{d56c0403019e70d45bafa420d2695fa9}
      \field{labelalpha}{БSР02}
      \field{sortinit}{Б}
      \field{sortinithash}{8f918f8686258589a227d5aaf265a9bb}
      \field{labeltitle}{Мухаммад ибн муса ал-Хорезми. Около 783 – около 850}
      \field{labeltitlesourcefield}{title}
      \field{labeltitlesourceform}{original}
      \field{labeltitlesourcelang}{russian}
      \true{singletitle}
      \field{day}{01}
      \field{langid}{russian}
      \field{month}{10}
      \field[form=original,lang=russian]{title}{Мухаммад ибн муса ал-Хорезми. Около 783 – около 850}
      \field[form=romanised,lang=russian]{title}{Mukhammad al-Khorezmi. Okolo 783 – okolo 850}
      \field[form=translated,lang=english]{title}{Mukhammad al-Khorezmi. Ca. 783 – ca. 850}
      \field{year}{2002}
    \endentry
|;

my $forms9 = q|    \entry{forms9}{book}{vtranslang=german,vlang=french}
      \field{sortinit}{U}
      \field{sortinithash}{311bb924dfb84a64dcdd01c5b07d40b0}
      \field{labeltitle}{Un titel}
      \field{labeltitlesourcefield}{title}
      \field{labeltitlesourceform}{original}
      \field{labeltitlesourcelang}{french}
      \field{langid}{french}
      \field[form=original,lang=french]{title}{Un titel}
    \endentry
|;

my $forms10 = q|    \entry{forms10}{book}{vlang=french}
      \field{sortinit}{U}
      \field{sortinithash}{311bb924dfb84a64dcdd01c5b07d40b0}
      \field{labeltitle}{Un titel}
      \field{labeltitlesourcefield}{title}
      \field{labeltitlesourceform}{original}
      \field{labeltitlesourcelang}{french}
      \field{langid}{french}
      \field[form=original,lang=french]{title}{Un titel}
    \endentry
|;

my $forms11 = q|    \entry{forms11}{book}{vlang=french}
      \field{sortinit}{U}
      \field{sortinithash}{311bb924dfb84a64dcdd01c5b07d40b0}
      \field{labeltitle}{Un titel}
      \field{labeltitlesourcefield}{title}
      \field{labeltitlesourceform}{original}
      \field{labeltitlesourcelang}{french}
      \field[form=original,lang=french]{journaltitle}{FJ}
      \field[form=translated,lang=english]{journaltitle}{TFJ}
      \field{langid}{french}
      \field[form=original,lang=french]{title}{Un titel}
    \endentry
|;

my $forms12 = q|    \entry{forms12}{unpublished}{}
      \field{sortinit}{T}
      \field{sortinithash}{9378dd666f3c24d81538df53aa99e23d}
      \field{labeltitle}{TITLE}
      \field{labeltitlesourcefield}{title}
      \field{labeltitlesourceform}{original}
      \field{labeltitlesourcelang}{english}
      \true{singletitle}
      \field[form=translated,lang=german]{edition}{Gedition}
      \field[form=translated,lang=french]{maintitle}{Maintitle translated FRENCH}
      \field[form=uniform,lang=german]{subtitle}{Subtitle uniform GERMAN}
      \field[form=original,lang=english]{title}{TITLE}
      \field[form=translated,lang=french]{title}{TITLE translated FRENCH}
    \endentry
|;

my $forms13 = q|    \entry{forms13}{unpublished}{}
      \field{sortinit}{0}
      \field{sortinithash}{a08a9549c5c2429f8cec5d1a581b26ca}
      \field[form=translated,lang=german]{edition}{Gedition}
      \field[form=translated,lang=french]{journaltitle}{Jtitle translated french}
      \field[form=uniform,lang=french]{journaltitle}{Jtitle uniform french}
      \field[form=translated,lang=french]{note}{Note translated french}
      \field[form=translated,lang=german]{note}{Note translated german}
    \endentry
|;

my $forms14 = q|    \entry{forms14}{unpublished}{}
      \field{sortinit}{0}
      \field{sortinithash}{a08a9549c5c2429f8cec5d1a581b26ca}
      \field[form=translated,lang=german]{edition}{Gedition}
      \field[form=original,lang=french]{journaltitle}{JTITLE french}
      \field[form=translated,lang=english]{note}{NOTE translated}
    \endentry
|;

my $forms15 = q|    \entry{forms15}{unpublished}{}
      \field{sortinit}{0}
      \field{sortinithash}{a08a9549c5c2429f8cec5d1a581b26ca}
      \field[form=romanised,lang=english]{booktitle}{German title}
      \field[form=translated,lang=german]{edition}{Gedition}
      \field[form=original,lang=english]{series}{B}
      \field[form=translated,lang=english]{series}{A}
    \endentry
|;

is($out->get_output_entry('forms1', $main), $forms1, 'bbl entry - forms 1') ;
is($bibentries->entry('forms8')->get_field('title', 'original', 'lang1'), 'L title', 'lang only');
is($out->get_output_entry('forms9', $main), $forms9, 'bbl entry - langid option');
is($out->get_output_entry('forms10', $main), $forms10, 'bbl entry - vtranslang same as global');
is($out->get_output_entry('forms11', $main), $forms11, 'bbl entry - vlang with unset options');
is($out->get_output_entry('forms12', $main), $forms12, 'bbl entry - mapping with forms/langs - 1');
is($out->get_output_entry('forms13', $main), $forms13, 'bbl entry - mapping with forms/langs - 2');
is($out->get_output_entry('forms14', $main), $forms14, 'bbl entry - mapping with forms/langs - 3');
is($out->get_output_entry('forms15', $main), $forms15, 'bbl entry - mapping with forms/langs - 4');

my $forms16 = q|    \entry{forms16}{book}{msmode=entry,vlang=ngerman}
      \name{labelname}{1}{}{%
        {{uniquename=0,hash=c30a47831df65fee72e918879815be97}{Masen}{M\bibinitperiod}{Frank}{F\bibinitperiod}{}{}{}{}}%
      }
      \name[form=original,lang=ngerman]{author}{1}{}{%
        {{uniquename=0,hash=c30a47831df65fee72e918879815be97}{Masen}{M\bibinitperiod}{Frank}{F\bibinitperiod}{}{}{}{}}%
      }
      \field{labelnamesourcefield}{author}
      \field{labelnamesourceform}{original}
      \field{labelnamesourcelang}{ngerman}
      \list[form=original,lang=ngerman]{publisher}{1}{%
        {Publisher}%
      }
      \strng{namehash}{c30a47831df65fee72e918879815be97}
      \strng{fullhash}{c30a47831df65fee72e918879815be97}
      \field{labelalpha}{Mas00}
      \field{sortinit}{M}
      \field{sortinithash}{4203d16473bc940d4ac780773cb7c5dd}
      \true{singletitle}
      \field{langid}{ngerman}
      \field[form=original,lang=french]{title}{Un titel}
      \field{year}{2000}
    \endentry
|;

is($out->get_output_entry('forms16', $main), $forms16, 'bbl entry - msmode=entry');
