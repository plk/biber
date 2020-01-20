# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';
use Text::Diff::Config;
$Text::Diff::Config::Output_Unicode = 1;

use Test::More tests => 23;
use Test::Differences;
unified_diff;

use Biber;
use Biber::Utils;
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

$biber->parse_ctrlfile('multiscript.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('bcf', 'multiscript.bcf');
Biber::Config->setoption('msstrict', 1);

# Now generate the information
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $bibentries = $section->bibentries;
my $main = $biber->datalists->get_list('nty/global//global/global');
my $out = $biber->get_output_obj;

eq_or_diff($bibentries->entry('ms1')->get_field('title'), 'Title', 'multiscript - 1');
eq_or_diff($bibentries->entry('ms1')->get_field('title', 'translation', 'fr'), 'Titre', 'multiscript - 2');
ok(is_undef($bibentries->entry('ms1')->get_field('author', 'transliteration', 'ru-latn')->nth_mslang(2)), 'multiscript - 3');
eq_or_diff($bibentries->entry('ms1')->get_field('author', 'transliteration', 'ru-latn')->nth_mslang(3), 'zh-latn', 'multiscript - 4');
ok(is_undef($bibentries->entry('ms1')->get_field('author', 'transliteration', 'ru-grek')->nth_mslang(2)), 'multiscript - 5');
eq_or_diff($bibentries->entry('ms1')->get_field('author', 'transliteration', 'ru-grek')->nth_mslang(3), 'zh-grek', 'multiscript - 6');
eq_or_diff($bibentries->entry('ms1')->get_field('author')->nth_mslang(2), 'ru-cyrl', 'multiscript - 7');
eq_or_diff($bibentries->entry('ms1')->get_field('author')->nth_mslang(3), 'zh-hant', 'multiscript - 8');
ok(is_undef($bibentries->entry('ms1')->get_field('author')->nth_mslang(1)), 'multiscript - 9');
eq_or_diff($bibentries->entry('ms1')->get_field('author', 'transliteration', 'ru-latn')->nth_mslang(1), 'en-us', 'multiscript - 10');
eq_or_diff($bibentries->entry('ms1')->get_field('author', 'transliteration', 'ru-grek')->nth_mslang(1), 'en-us', 'multiscript - 11');
ok(is_undef($bibentries->entry('ms1')->get_field('location')->nth_mslang(1)), 'multiscript - 12');
eq_or_diff($bibentries->entry('ms1')->get_field('location')->nth_mslang(2), 'de', 'multiscript - 13');
ok(is_undef($bibentries->entry('ms1')->get_field('location', 'translation', 'fr')->nth_mslang(1)), 'multiscript - 14');
eq_or_diff($bibentries->entry('ms1')->get_field('location', 'translation', 'fr')->nth_mslang(2), 'de', 'multiscript - 15');

# biblatex source
eq_or_diff($bibentries->entry('bltx1')->get_field('author')->nth_mslang(1), 'ru-cyrl', 'multiscript - 16');
ok(is_undef($bibentries->entry('bltx1')->get_field('author')->nth_mslang(2)), 'multiscript - 17');
ok(is_undef($bibentries->entry('bltx1')->get_field('author', 'transliteration', 'ru-Grek')->nth_mslang(1)), 'multiscript - 18');
eq_or_diff($bibentries->entry('bltx1')->get_field('author', 'transliteration', 'ru-grek')->nth_mslang(2), 'en-us', 'multiscript - 19');

# BBL output tests
my $ms1 = q|    \entry{ms1}{article}{}
      \name[default][en-us]{author}{3}{}{%
        {{hash=c221fa2d0fd5443df81b6bc63acf958a}{%
           family={Smith},
           familyi={S\bibinitperiod},
           given={Bill},
           giveni={B\bibinitperiod}}}%
        {{mslang=ru-cyrl,hash=4f73a0f18329ab1288633835f7b04724}{%
           family={Пушкин},
           familyi={П\bibinitperiod},
           given={Александр},
           giveni={А\bibinitperiod}}}%
        {{mslang=zh-hant,hash=2f26b14cfb672c6b954bbf761450c065}{%
           family={徐冰},
           familyi={徐\bibinitperiod}}}%
      }
      \name[transliteration][ru-grek]{author}{3}{}{%
        {{mslang=en-us,hash=c221fa2d0fd5443df81b6bc63acf958a}{%
           family={Smith},
           familyi={S\bibinitperiod},
           given={Bill},
           giveni={B\bibinitperiod}}}%
        {{hash=23836992c4d5c0bdf6f16c3d9feacbce}{%
           family={Πούσκιν},
           familyi={Π\bibinitperiod},
           given={Ἀλεξάντρ},
           giveni={Ἀ\bibinitperiod}}}%
        {{mslang=zh-grek,hash=c8d42acf200a5d5dc4c71a634f807d66}{%
           family={Ξού},
           familyi={Ξ\bibinitperiod},
           given={Μπίνγκ},
           giveni={Μ\bibinitperiod}}}%
      }
      \name[transliteration][ru-latn]{author}{3}{}{%
        {{mslang=en-us,hash=c221fa2d0fd5443df81b6bc63acf958a}{%
           family={Smith},
           familyi={S\bibinitperiod},
           given={Bill},
           giveni={B\bibinitperiod}}}%
        {{hash=0c7edadf6ef1ef60f583b09b35993f86}{%
           family={Pushkin},
           familyi={P\bibinitperiod},
           given={Aleksandr},
           giveni={A\bibinitperiod}}}%
        {{mslang=zh-latn,hash=743dd6cdaa6639320289d219d351d7b7}{%
           family={Xu},
           familyi={X\bibinitperiod},
           given={Bing},
           giveni={B\bibinitperiod}}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Smith},
          familydefaulten-usi={S\bibinitperiod},
          givendefaulten-us={Bill},
          givendefaulten-usi={B\bibinitperiod},
          familytransliterationen-us={Smith},
          familytransliterationen-usi={S\bibinitperiod},
          giventransliterationen-us={Bill},
          giventransliterationen-usi={B\bibinitperiod}
      }
      \namepartms{author}{2}{%
          familydefaultru-cyrl={Пушкин},
          familydefaultru-cyrli={П\bibinitperiod},
          givendefaultru-cyrl={Александр},
          givendefaultru-cyrli={А\bibinitperiod},
          familytransliterationru-grek={Πούσκιν},
          familytransliterationru-greki={Π\bibinitperiod},
          giventransliterationru-grek={Ἀλεξάντρ},
          giventransliterationru-greki={Ἀ\bibinitperiod},
          familytransliterationru-latn={Pushkin},
          familytransliterationru-latni={P\bibinitperiod},
          giventransliterationru-latn={Aleksandr},
          giventransliterationru-latni={A\bibinitperiod}
      }
      \namepartms{author}{3}{%
          familydefaultzh-hant={徐冰},
          familydefaultzh-hanti={徐\bibinitperiod},
          familytransliterationzh-grek={Ξού},
          familytransliterationzh-greki={Ξ\bibinitperiod},
          giventransliterationzh-grek={Μπίνγκ},
          giventransliterationzh-greki={Μ\bibinitperiod},
          familytransliterationzh-latn={Xu},
          familytransliterationzh-latni={X\bibinitperiod},
          giventransliterationzh-latn={Bing},
          giventransliterationzh-latni={B\bibinitperiod}
      }
      \list[default][en-us]{location}{2}{%
        {locationa}%
        {Standortb}%
      }
      \list[translation][fr]{location}{2}{%
        {emplacementa}%
        {Standortb}%
      }
      \listitemms{location}{1}{%
        defaulten-us={locationa},
        translationfr={emplacementa}
      }
      \listitemms{location}{2}{%
        defaultde={Standortb},
        translationde={Standortb}
      }
      \strng{namehash}{6506017dedcafd386988f8f975fedd0d}
      \strng{fullhash}{6506017dedcafd386988f8f975fedd0d}
      \strng{bibnamehash}{6506017dedcafd386988f8f975fedd0d}
      \strng{authordefaulten-usbibnamehash}{c8e70e2e1328616e34339e681de514c7}
      \strng{authordefaulten-usnamehash}{c8e70e2e1328616e34339e681de514c7}
      \strng{authordefaulten-usfullhash}{c8e70e2e1328616e34339e681de514c7}
      \strng{authortransliterationru-grekbibnamehash}{d4dcf56a391b21aec2131b22a251c6b5}
      \strng{authortransliterationru-greknamehash}{d4dcf56a391b21aec2131b22a251c6b5}
      \strng{authortransliterationru-grekfullhash}{d4dcf56a391b21aec2131b22a251c6b5}
      \strng{authortransliterationru-latnbibnamehash}{6506017dedcafd386988f8f975fedd0d}
      \strng{authortransliterationru-latnnamehash}{6506017dedcafd386988f8f975fedd0d}
      \strng{authortransliterationru-latnfullhash}{6506017dedcafd386988f8f975fedd0d}
      \field{labelalpha}{SPXeS95}
      \field{sortinit}{S}
      \strng{sortinithash}{c319cff79d99c853d775f88277d4e45f}
      \fieldmssource{labelname}{author}{transliteration}{ru-latn}
      \fieldmssource{labeltitle}{title}{translation}{fr}
      \field[default][en-us]{title}{Title}
      \field[translation][fr]{title}{Titre}
      \field{year}{1995}
      \field{dateera}{ce}
      \annotation[default][en-us]{item}{author}{mslang}{2}{}{1}{ru-cyrl}
      \annotation[default][en-us]{item}{author}{mslang}{3}{}{1}{zh-hant}
      \annotation[transliteration][ru-grek]{item}{author}{mslang}{1}{}{1}{en-us}
      \annotation[transliteration][ru-grek]{item}{author}{mslang}{3}{}{1}{zh-grek}
      \annotation[transliteration][ru-latn]{item}{author}{mslang}{1}{}{1}{en-us}
      \annotation[transliteration][ru-latn]{item}{author}{mslang}{3}{}{1}{zh-latn}
      \annotation[default][en-us]{item}{location}{mslang}{2}{}{1}{de}
      \annotation[translation][fr]{item}{location}{mslang}{2}{}{1}{de}
    \endentry
|;

my $ms2 = q|    \entry{ms2}{inbook}{}
      \name[default][en-us]{author}{1}{}{%
        {{hash=02c5906bf7d6156a9695735b750c744b}{%
           family={Treacle},
           familyi={T\bibinitperiod},
           given={Alan},
           giveni={A\bibinitperiod}}}%
      }
      \name[transliteration][ru-latn]{author}{1}{}{%
        {{hash=cb8bc4824dfe756730d5837418bf5b53}{%
           family={Clever},
           familyi={C\bibinitperiod},
           given={Clive},
           giveni={C\bibinitperiod}}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Treacle},
          familydefaulten-usi={T\bibinitperiod},
          givendefaulten-us={Alan},
          givendefaulten-usi={A\bibinitperiod},
          familytransliterationru-latn={Clever},
          familytransliterationru-latni={C\bibinitperiod},
          giventransliterationru-latn={Clive},
          giventransliterationru-latni={C\bibinitperiod}
      }
      \name[default][de]{editor}{1}{}{%
        {{hash=da4e9104ade84cb0fcd815add03dd1fd}{%
           family={Gimble},
           familyi={G\bibinitperiod},
           given={Billy},
           giveni={B\bibinitperiod}}}%
      }
      \namepartms{editor}{1}{%
          familydefaultde={Gimble},
          familydefaultdei={G\bibinitperiod},
          givendefaultde={Billy},
          givendefaultdei={B\bibinitperiod}
      }
      \strng{namehash}{cb8bc4824dfe756730d5837418bf5b53}
      \strng{fullhash}{cb8bc4824dfe756730d5837418bf5b53}
      \strng{bibnamehash}{cb8bc4824dfe756730d5837418bf5b53}
      \strng{authordefaulten-usbibnamehash}{02c5906bf7d6156a9695735b750c744b}
      \strng{authordefaulten-usnamehash}{02c5906bf7d6156a9695735b750c744b}
      \strng{authordefaulten-usfullhash}{02c5906bf7d6156a9695735b750c744b}
      \strng{authortransliterationru-latnbibnamehash}{cb8bc4824dfe756730d5837418bf5b53}
      \strng{authortransliterationru-latnnamehash}{cb8bc4824dfe756730d5837418bf5b53}
      \strng{authortransliterationru-latnfullhash}{cb8bc4824dfe756730d5837418bf5b53}
      \strng{editordefaultdebibnamehash}{da4e9104ade84cb0fcd815add03dd1fd}
      \strng{editordefaultdenamehash}{da4e9104ade84cb0fcd815add03dd1fd}
      \strng{editordefaultdefullhash}{da4e9104ade84cb0fcd815add03dd1fd}
      \field{labelalpha}{Cle96}
      \field{sortinit}{C}
      \strng{sortinithash}{4c244ceae61406cdc0cc2ce1cb1ff703}
      \fieldmssource{labelname}{author}{transliteration}{ru-latn}
      \field[default][de]{booktitle}{Book Title}
      \field[translated][fr]{booktitle}{Livre Titre}
      \field[default][en-us]{title}{Title}
      \field{year}{1996}
      \field{dateera}{ce}
    \endentry
|;

# print $out->get_output_entry('ms1', $main);

eq_or_diff($out->get_output_entry('ms1', $main), $ms1, 'BBL 1');
eq_or_diff($out->get_output_entry('ms2', $main), $ms2, 'BBL 2');
is_deeply($main->get_keys, ['ms2', 'ms1', 'bltx1'], 'sorting - 1');
eq_or_diff(Biber::Config->get_langs(), 'de,en-us,fr,ru-cyrl,ru-grek,ru-latn,zh-grek,zh-hant,zh-latn', 'mslangs 1');
