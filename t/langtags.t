# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 36;
use Test::Differences;
unified_diff;

use Biber;
use Biber::Utils;
use Biber::LangTag;
use Log::Log4perl;
chdir("t/tdata");

# Set up Biber object
my $biber = Biber->new();
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

is_deeply($biber->langtags->parse('de')->get_language, 'de', 'BCP47 - 1');
is_deeply($biber->langtags->parse('i-enochian')->dump, { grandfathered => "i-enochian" }, 'BCP47 - 2');
is_deeply($biber->langtags->parse('zh-Hant')->dump, { language => 'zh', script => 'hant' }, 'BCP47 - 3');
is_deeply($biber->langtags->parse('zh-cmn-Hans-CN')->dump, { language => 'zh', extlang => ['cmn'], script => 'hans', region => 'cn' }, 'BCP47 - 4');
is_deeply($biber->langtags->parse('cmn-Hans-CN')->dump, { language => 'cmn', script => 'hans', region => 'cn' }, 'BCP47 - 5');
is_deeply($biber->langtags->parse('yue-HK')->dump, { language => 'yue', region => 'hk' }, 'BCP47 - 6');
is_deeply($biber->langtags->parse('sl-rozaj')->dump, { language => 'sl', variant => ['rozaj'] }, 'BCP47 - 7');
is_deeply($biber->langtags->parse('sl-rozaj-biske')->dump, { language => 'sl', variant => ['rozaj', 'biske'] }, 'BCP47 - 8');
is_deeply($biber->langtags->parse('de-CH-1901')->dump, { language => 'de', region => 'ch', variant => ['1901'] }, 'BCP47 - 9');
is_deeply($biber->langtags->parse('hy-Latn-IT-arevela')->dump, { language => 'hy', region => 'it', script => 'latn', variant => ['arevela'] }, 'BCP47 - 10');
is_deeply($biber->langtags->parse('de-DE')->dump, { language => 'de', region => 'de' }, 'BCP47 - 11');
is_deeply($biber->langtags->parse('es-419')->dump, { language => 'es', region => '419' }, 'BCP47 - 12');
is_deeply($biber->langtags->parse('de-CH-x-phonebk')->dump, { language => 'de', region => 'ch', privateuse => ['phonebk'] }, 'BCP47 - 13');
is_deeply($biber->langtags->parse('az-Arab-x-AZE-derbend')->dump, { language => 'az', script => 'arab', privateuse => ['aze', 'derbend'] }, 'BCP47 - 14');
is_deeply($biber->langtags->parse('en-US-u-islamcal')->dump, { language => 'en', region => 'us', extension => {'u' => 'islamcal'} }, 'BCP47 - 15');
is_deeply($biber->langtags->parse('en-a-myext-b-another')->dump, { language => 'en', extension => {a => 'myext', b => 'another'} }, 'BCP47 - 16');
is_deeply($biber->langtags->parse('zh-CN-a-myext-x-private')->dump, { language => 'zh', region => 'cn', extension => {a => 'myext'}, privateuse => ['private'] }, 'BCP47 - 17');
is_deeply($biber->langtags->parse('de-419-DE')->as_string, 'invalidtag', 'BCP47 - 18');
is_deeply($biber->langtags->parse('a-DE')->as_string, 'invalidtag', 'BCP47 - 19');

# Testing reversability
eq_or_diff($biber->langtags->parse('de')->as_string, 'de', 'BCP47 - 20');
eq_or_diff($biber->langtags->parse('i-enochian')->as_string, 'i-enochian', 'BCP47 - 21');
eq_or_diff($biber->langtags->parse('zh-Hant')->as_string, 'zh-hant', 'BCP47 - 22');
eq_or_diff($biber->langtags->parse('zh-cmn-Hans-CN')->as_string, 'zh-cmn-hans-cn', 'BCP47 - 23');
eq_or_diff($biber->langtags->parse('cmn-Hans-CN')->as_string, 'cmn-hans-cn', 'BCP47 - 24');
eq_or_diff($biber->langtags->parse('yue-HK')->as_string, 'yue-hk', 'BCP47 - 25');
eq_or_diff($biber->langtags->parse('sl-rozaj')->as_string, 'sl-rozaj', 'BCP47 - 26');
eq_or_diff($biber->langtags->parse('sl-rozaj-biske')->as_string, 'sl-rozaj-biske', 'BCP47 - 27');
eq_or_diff($biber->langtags->parse('de-CH-1901')->as_string, 'de-ch-1901', 'BCP47 - 28');
eq_or_diff($biber->langtags->parse('hy-Latn-IT-arevela')->as_string, 'hy-latn-it-arevela', 'BCP47 - 29');
eq_or_diff($biber->langtags->parse('de-DE')->as_string, 'de-de', 'BCP47 - 30');
eq_or_diff($biber->langtags->parse('es-419')->as_string, 'es-419', 'BCP47 - 31');
eq_or_diff($biber->langtags->parse('de-CH-x-phonebk')->as_string, 'de-ch-x-phonebk', 'BCP47 - 32');
eq_or_diff($biber->langtags->parse('az-Arab-x-AZE-derbend')->as_string, 'az-arab-x-aze-derbend', 'BCP47 - 33');
eq_or_diff($biber->langtags->parse('en-US-u-islamcal')->as_string, 'en-us-u-islamcal', 'BCP47 - 34');
eq_or_diff($biber->langtags->parse('en-a-myext-b-another')->as_string, 'en-a-myext-b-another', 'BCP47 - 35');
eq_or_diff($biber->langtags->parse('zh-CN-a-myext-x-private')->as_string, 'zh-cn-a-myext-x-private', 'BCP47 - 36');

