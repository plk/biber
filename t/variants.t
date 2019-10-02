# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 19;
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

is_deeply($biber->langtags->parse('de')->dump, {language => 'de'}, 'BCP47 - 1');
is_deeply($biber->langtags->parse('i-enochian')->dump, { grandfathered => "i-enochian" }, 'BCP47 - 2');
is_deeply($biber->langtags->parse('zh-Hant')->dump, { language => 'zh', script => 'Hant' }, 'BCP47 - 3');
is_deeply($biber->langtags->parse('zh-cmn-Hans-CN')->dump, { language => 'zh', extlang => ['cmn'], script => 'Hans', region => 'CN' }, 'BCP47 - 4');
is_deeply($biber->langtags->parse('cmn-Hans-CN')->dump, { language => 'cmn', script => 'Hans', region => 'CN' }, 'BCP47 - 5');
is_deeply($biber->langtags->parse('yue-HK')->dump, { language => 'yue', region => 'HK' }, 'BCP47 - 6');
is_deeply($biber->langtags->parse('sl-rozaj')->dump, { language => 'sl', variant => ['rozaj'] }, 'BCP47 - 7');
is_deeply($biber->langtags->parse('sl-rozaj-biske')->dump, { language => 'sl', variant => ['rozaj', 'biske'] }, 'BCP47 - 8');
is_deeply($biber->langtags->parse('de-CH-1901')->dump, { language => 'de', region => 'CH', variant => ['1901'] }, 'BCP47 - 9');
is_deeply($biber->langtags->parse('hy-Latn-IT-arevela')->dump, { language => 'hy', region => 'IT', script => 'Latn', variant => ['arevela'] }, 'BCP47 - 10');
is_deeply($biber->langtags->parse('de-DE')->dump, { language => 'de', region => 'DE' }, 'BCP47 - 11');
is_deeply($biber->langtags->parse('es-419')->dump, { language => 'es', region => '419' }, 'BCP47 - 12');
is_deeply($biber->langtags->parse('de-CH-x-phonebk')->dump, { language => 'de', region => 'CH', privateuse => ['phonebk'] }, 'BCP47 - 13');
is_deeply($biber->langtags->parse('az-Arab-x-AZE-derbend')->dump, { language => 'az', script => 'Arab', privateuse => ['AZE', 'derbend'] }, 'BCP47 - 14');
is_deeply($biber->langtags->parse('en-US-u-islamcal')->dump, { language => 'en', region => 'US', extension => ['islamcal'] }, 'BCP47 - 15');
is_deeply($biber->langtags->parse('en-a-myext-b-another')->dump, { language => 'en', extension => ['myext', 'another'] }, 'BCP47 - 16');
is_deeply($biber->langtags->parse('zh-CN-a-myext-x-private')->dump, { language => 'zh', region => 'CN', extension => ['myext'], privateuse => ['private'] }, 'BCP47 - 17');
is_deeply($biber->langtags->parse('de-419-DE'), undef, 'BCP47 - 18');
is_deeply($biber->langtags->parse('a-DE'), undef, 'BCP47 - 19');
