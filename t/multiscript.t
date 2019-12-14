# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';
use Text::Diff::Config;
$Text::Diff::Config::Output_Unicode = 1;

use Test::More tests => 20;
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

# Now generate the information
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $bibentries = $section->bibentries;
my $main = $biber->datalists->get_list('nty/global//global/global');
my $out = $biber->get_output_obj;

eq_or_diff($bibentries->entry('ms1')->get_field('title'), 'Title', 'multiscript - 1');
eq_or_diff($bibentries->entry('ms1')->get_field('title', 'translation', 'fr'), 'Titre', 'multiscript - 2');
eq_or_diff($bibentries->entry('ms1')->get_field('author', 'transliteration', 'ru-latn')->nth_mslang(2), 'ru-latn', 'multiscript - 3');
eq_or_diff($bibentries->entry('ms1')->get_field('author', 'transliteration', 'ru-latn')->nth_mslang(3), 'zh-latn', 'multiscript - 4');
eq_or_diff($bibentries->entry('ms1')->get_field('author', 'transliteration', 'ru-grek')->nth_mslang(2), 'ru-grek', 'multiscript - 5');
eq_or_diff($bibentries->entry('ms1')->get_field('author', 'transliteration', 'ru-grek')->nth_mslang(3), 'zh-grek', 'multiscript - 6');
eq_or_diff($bibentries->entry('ms1')->get_field('author')->nth_mslang(2), 'ru-cyrl', 'multiscript - 7');
eq_or_diff($bibentries->entry('ms1')->get_field('author')->nth_mslang(3), 'zh-hant', 'multiscript - 8');
eq_or_diff($bibentries->entry('ms1')->get_field('author')->nth_mslang(1), 'en-us', 'multiscript - 9');
eq_or_diff($bibentries->entry('ms1')->get_field('author', 'transliteration', 'ru-latn')->nth_mslang(1), 'en-us', 'multiscript - 10');
eq_or_diff($bibentries->entry('ms1')->get_field('author', 'transliteration', 'ru-grek')->nth_mslang(1), 'en-us', 'multiscript - 11');
eq_or_diff($bibentries->entry('ms1')->get_field('location')->nth_mslang(1), 'en-us', 'multiscript - 12');
eq_or_diff($bibentries->entry('ms1')->get_field('location')->nth_mslang(2), 'de', 'multiscript - 13');
eq_or_diff($bibentries->entry('ms1')->get_field('location', 'translation', 'fr')->nth_mslang(1), 'fr', 'multiscript - 14');
eq_or_diff($bibentries->entry('ms1')->get_field('location', 'translation', 'fr')->nth_mslang(2), 'de', 'multiscript - 15');

# biblatex source
eq_or_diff($bibentries->entry('bltx1')->get_field('author')->nth_mslang(1), 'ru-cyrl', 'multiscript - 16');
eq_or_diff($bibentries->entry('bltx1')->get_field('author')->nth_mslang(2), 'en-us', 'multiscript - 17');
eq_or_diff($bibentries->entry('bltx1')->get_field('author', 'transliteration', 'ru-Grek')->nth_mslang(1), 'ru-grek', 'multiscript - 18');
eq_or_diff($bibentries->entry('bltx1')->get_field('author', 'transliteration', 'ru-grek')->nth_mslang(2), 'en-us', 'multiscript - 19');

# BBL output tests
my $ms1 = q|    \entry{ms1}{article}{}
      \name[msform=default,mslang=en-us]{author}{3}{}{%
        {{mslang=en-us,hash=c221fa2d0fd5443df81b6bc63acf958a}{%
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
      \name[msform=transliteration,mslang=ru-grek]{author}{3}{}{%
        {{mslang=en-us,hash=c221fa2d0fd5443df81b6bc63acf958a}{%
           family={Smith},
           familyi={S\bibinitperiod},
           given={Bill},
           giveni={B\bibinitperiod}}}%
        {{mslang=ru-grek,hash=23836992c4d5c0bdf6f16c3d9feacbce}{%
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
      \name[msform=transliteration,mslang=ru-latn]{author}{3}{}{%
        {{mslang=en-us,hash=c221fa2d0fd5443df81b6bc63acf958a}{%
           family={Smith},
           familyi={S\bibinitperiod},
           given={Bill},
           giveni={B\bibinitperiod}}}%
        {{mslang=ru-latn,hash=0c7edadf6ef1ef60f583b09b35993f86}{%
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
      \list[msform=default,mslang=en-us]{location}{2}{%
        {locationa}%
        {Standortb}%
      }
      \list[msform=translation,mslang=fr]{location}{2}{%
        {emplacementa}%
        {Standortb}%
      }
      \strng{namehash}{6506017dedcafd386988f8f975fedd0d}
      \strng{fullhash}{6506017dedcafd386988f8f975fedd0d}
      \strng{bibnamehash}{6506017dedcafd386988f8f975fedd0d}
      \strng{authorbibnamehash}{c8e70e2e1328616e34339e681de514c7}
      \strng{authornamehash}{c8e70e2e1328616e34339e681de514c7}
      \strng{authorfullhash}{c8e70e2e1328616e34339e681de514c7}
      \field{sortinit}{S}
      \strng{sortinithash}{c319cff79d99c853d775f88277d4e45f}
      \field{labelnamesource}{author}{transliteration}{ru-latn}
      \field{labeltitlesource}{title}{translation}{fr}
      \field[msform=default,mslang=en-us]{title}{Title}
      \field[msform=translation,mslang=fr]{title}{Titre}
      \field{year}{1995}
      \field{dateera}{ce}
      \annotation{item}{author}{default}{en-us}{langtags}{2}{}{0}{ru-Cyrl}
      \annotation{item}{author}{default}{en-us}{langtags}{3}{}{0}{zh-Hant}
      \annotation{item}{author}{transliteration}{ru-grek}{langtags}{1}{}{0}{en-US}
      \annotation{item}{author}{transliteration}{ru-grek}{langtags}{3}{}{0}{zh-Grek}
      \annotation{item}{author}{transliteration}{ru-latn}{langtags}{1}{}{0}{en-US}
      \annotation{item}{author}{transliteration}{ru-latn}{langtags}{3}{}{0}{zh-Latn}
      \annotation{item}{location}{default}{en-us}{langtags}{2}{}{0}{de}
      \annotation{item}{location}{translation}{fr}{langtags}{2}{}{0}{de}
    \endentry
|;

#print $out->get_output_entry('ms1', $main);

eq_or_diff($out->get_output_entry('ms1', $main), $ms1, 'BBL 1');
