package Biber::Constants;
use v5.24;
use strict;
use warnings;

use Encode;
use Encode::Alias;

use parent qw(Exporter);
use Biber::Date::Format;
use Text::CSV;

our @EXPORT = qw{
                  $CONFIG_DEFAULT_BIBER
                  $CONFIG_CSV_PARSER
                  $BIBER_CONF_NAME
                  $BCF_VERSION
                  $BBL_VERSION
                  $BIBER_SORT_FINAL
                  $BIBER_SORT_NULL
                  $LABEL_FINAL
                  %CONFIG_DEFAULT_BIBLATEX
                  %CONFIG_OPTSCOPE_BIBLATEX
                  %CONFIG_SCOPEOPT_BIBLATEX
                  %CONFIG_OPTTYPE_BIBLATEX
                  %CONFIG_BIBLATEX_ENTRY_OPTIONS
                  %CONFIG_META_MARKERS
                  %CONFIG_DATE_PARSERS
                  %DATAFIELD_SETS
                  %DM_DATATYPES
                  %LOCALE_MAP
                  %LOCALE_MAP_R
                  %REMOTE_MAP
                  %DS_EXTENSIONS
              };

# Version of biblatex control file which this release expects. Matched against version
# passed in control file. Used when checking the .bcf
our $BCF_VERSION = '3.4';
# Format version of the .bbl. Used when writing the .bbl
our $BBL_VERSION = '2.8';

# Global flags needed for sorting
our $BIBER_SORT_FINAL;
our $BIBER_SORT_NULL;

# the name of the Biber configuration file, which should be
# either returned by kpsewhich or located at "$HOME/.$BIBER_CONF_NAME"
our $BIBER_CONF_NAME = 'biber.conf';

## Biber CONFIGURATION DEFAULTS

# Locale -  if nothing, set a default
my $locale;
unless ($locale) {
  if ( $^O =~ /Win/) {
    $locale = 'English_United States.1252';
  }
  else {
    $locale = 'en_US.UTF-8';
  }
}


# datafieldsets
our %DATAFIELD_SETS = ();

# datatypes for data model validation
our %DM_DATATYPES = (
                     integer  => qr/\A\d+\z/xms,
                     datepart => qr/\A\d+\z/xms
                    );

# Mapping of data source and output types to extensions
our %DS_EXTENSIONS = (
                      bbl        => 'bbl',
                      bblxml     => 'bblxml',
                      bibtex     => 'bib',
                      biblatexml => 'bltxml',
                      ris        => 'ris'
                      );

# Biber option defaults. Mostly not needed outside of tool mode since they are passed by .bcf
our $CONFIG_DEFAULT_BIBER = {
  annotation_marker                           => { content => q/+an/ },
  clrmacros                                   => { content => 0 },
  collate_options                             => { option => {level => 4, variable => 'non-ignorable', normalization => 'prenormalized' }},
  graph                                       => { content => 0 },
  debug                                       => { content => 0 },
  dieondatamodel                              => { content => 0 },
  decodecharsset                              => { content => 'base' },
  dot_include                                 => { option => {section => 1, xdata => 1, crossref => 1, xref => 1 }},
  fixinits                                    => { content => 0 },
  input_encoding                              => { content => 'UTF-8' },
  input_format                                => { content => 'bibtex' },
  isbn10                                      => { content => 0 },
  isbn13                                      => { content => 0 },
  isbn_normalise                              => { content => 0 },
  listsep                                     => { content => 'and' },
  mincrossrefs                                => { content => 2 },
  minxrefs                                    => { content => 2 },
  namesep                                     => { content => 'and' },
  no_bblxml_schema                            => { content => 0 },
  no_bltxml_schema                            => { content => 0 },
  nodieonerror                                => { content => 0 },
  noinit                                      => { option => [ {value => q/\b\p{Ll}{2}\p{Pd}/},
                                                               {value => q/[\x{2bf}\x{2018}]/} ] },
  nolabel                                     => { option => [ {value => q/[\p{P}\p{S}\p{C}]+/} ] },
#  nolabelwidthcount                          => { option =>  }, # default is nothing
  nolog                                       => { content => 0 },
  nostdmacros                                 => { content => 0 },
  nosort                                      => { option => [ { name => 'setnames', value => q/\A\p{L}{2}\p{Pd}/ },
                                                               { name => 'setnames', value => q/[\x{2bf}\x{2018}]/ } ] },
  onlylog                                     => { content => 0 },
  others_string                               => { content => 'others' },
  output_align                                => { content => 0 },
  output_annotation_marker                    => { content => '+an' },
  output_encoding                             => { content => 'UTF-8' },
  output_field_order                          => { content => 'options,abstract,names,lists,dates' },
  output_format                               => { content => 'bbl' },
  output_indent                               => { content => '2' },
  output_fieldcase                            => { content => 'upper' },
  output_listsep                              => { content => 'and' },
  output_namesep                              => { content => 'and' },
  output_resolve_xdata                        => { content => 0 },
  output_resolve_crossrefs                    => { content => 0 },
  output_resolve_sets                         => { content => 0 },
  output_safechars                            => { content => 0 },
  output_safecharsset                         => { content => 'base' },
  output_xnamesep                             => { content => '=' },
  quiet                                       => { content => 0 },
  noskipduplicates                            => { content => 0 },
  sortdebug                                   => { content => 0 },
  sortcase                                    => { content => 1 },
  sortupper                                   => { content => 1 },
  strip_comments                              => { content => 0 },
  tool                                        => { content => 0 },
  trace                                       => { content => 0 },
  nouri_encode                                => { content => 0 },
  validate_bblxml                             => { content => 0 },
  validate_bltxml                             => { content => 0 },
  validate_config                             => { content => 0 },
  validate_control                            => { content => 0 },
  validate_datamodel                          => { content => 0 },
  wraplines                                   => { content => 0 },
  xnamesep                                    => { content => '=' },
  xsvsep                                      => { content => q/\s*,\s*/ },
};

# Set up some re-usable CSV parsers here for efficiency reasons
our $CONFIG_CSV_PARSER = Text::CSV->new ( { binary           => 1,
                                            allow_whitespace => 1,
                                            always_quote     => 1  } );

# Set up some re-usable Date parsers here for efficiency reasons
# We need two as the missing component data is in these objects, not
# in the DT objects returned by ->parse_datetime() and this data will
# likely be different for start/end
our %CONFIG_DATE_PARSERS = ('start' => Biber::Date::Format->new(),
                            'end'   => Biber::Date::Format->new());

our %CONFIG_META_MARKERS = ();

# default global options for biblatex
# Used to set:
# * Some tool-mode defaults (as there is no .bcf and some biblatex options
#   cannot be set in a biber config file)
our %CONFIG_DEFAULT_BIBLATEX = (
                                sortscheme    => 'none',
                                useauthor     => 1,
                                useeditor     => 1,
                                usetranslator => 1,
                                maxbibnames   => 100,
                                maxitems      => 100,
                                minbibnames   => 100,
                                maxalphanames => 100,
                                maxcitenames  => 100,
                                minalphanames => 100,
                                mincitenames  => 100,
                                minitems      => 100,
                                useprefix     => 0
                               );

# Set up some encoding aliases to map \inputen{c,x} encoding names to Encode
# It seems that inputen{c,x} has a different idea of nextstep than Encode
# so we push it to MacRoman
define_alias('ansinew'        => 'cp1252'); # inputenc alias for cp1252
define_alias('applemac'       => 'MacRoman');
define_alias('applemacce'     => 'MacCentralEurRoman');
define_alias('next'           => 'MacRoman');
define_alias('x-mac-roman'    => 'MacRoman');
define_alias('x-mac-centeuro' => 'MacCentralEurRoman');
define_alias('x-mac-cyrillic' => 'MacCyrillic');
define_alias('x-nextstep'     => 'MacRoman');
define_alias('x-ascii'        => 'ascii'); # Encode doesn't resolve this one by default
define_alias('lutf8'          => 'UTF-8'); # Luatex
define_alias('utf8x'          => 'UTF-8'); # UCS (old)

# maps between bcp47 lang/locales and babel/polyglossia language names
our %LOCALE_MAP = (
                   'acadian'         => 'fr-CA',
                   'american'        => 'en-US',
                   'australian'      => 'en-AU',
                   'afrikaans'       => 'af-ZA',
                   'albanian'        => 'sq-AL',
                   'amharic'         => 'am-ET',
                   'arabic'          => 'ar-001',
                   'armenian'        => 'hy-AM',
                   'asturian'        => 'ast-ES',
                   'austrian'        => 'de-AT',
                   'bahasa'          => 'id-ID',
                   'bahasai'         => 'id-ID',
                   'bahasam'         => 'id-ID',
                   'basque'          => 'eu-ES',
                   'bengali'         => 'bn-BD',
                   'bgreek'          => 'el-GR',
                   'brazil'          => 'pt-BR',
                   'brazilian'       => 'pt-BR',
                   'breton'          => 'br-FR',
                   'british'         => 'en-GB',
                   'bulgarian'       => 'bg-BG',
                   'canadian'        => 'en-CA',
                   'canadien'        => 'fr-CA',
                   'catalan'         => 'ca-AD',
                   'coptic'          => 'cop',
                   'croatian'        => 'hr-HR',
                   'czech'           => 'cs-CZ',
                   'danish'          => 'da-DK',
                   'divehi'          => 'dv-MV',
                   'dutch'           => 'nl-NL',
                   'english'         => 'en-US',
                   'esperanto'       => 'eo-001',
                   'estonian'        => 'et-EE',
                   'ethiopia'        => 'am-ET',
                   'farsi'           => 'fa-IR',
                   'finnish'         => 'fi-FI',
                   'francais'        => 'fr-FR',
                   'french'          => 'fr-FR',
                   'frenchle'        => 'fr-FR',
                   'friulan'         => 'fur-IT',
                   'galician'        => 'gl-ES',
                   'german'          => 'de-DE',
                   'germanb'         => 'de-DE',
                   'greek'           => 'el-GR',
                   'hebrew'          => 'he-IL',
                   'hindi'           => 'hi-IN',
                   'ibygreek'        => 'el-CY',
                   'icelandic'       => 'is-IS',
                   'indon'           => 'id-ID',
                   'indonesia'       => 'id-ID',
                   'interlingua'     => 'ia-FR',
                   'irish'           => 'ga-IE',
                   'italian'         => 'it-IT',
                   'japanese'        => 'ja-JP',
                   'kannada'         => 'kn-IN',
                   'lao'             => 'lo-LA',
                   'latin'           => 'la-Latn',
                   'latvian'         => 'lv-LV',
                   'lithuanian'      => 'lt-LT',
                   'lowersorbian'    => 'dsb-DE',
                   'lsorbian'        => 'dsb-DE',
                   'magyar'          => 'hu-HU',
                   'malay'           => 'id-ID',
                   'malayalam'       => 'ml-IN',
                   'marathi'         => 'mr-IN',
                   'meyalu'          => 'id-ID',
                   'mongolian'       => 'mn-Cyrl',
                   'naustrian'       => 'de-AT',
                   'newzealand'      => 'en-NZ',
                   'ngerman'         => 'de-DE',
                   'nko'             => 'ha-NG',
                   'norsk'           => 'nb-NO',
                   'norwegian'       => 'nn-NO',
                   'nynorsk'         => 'nn-NO',
                   'occitan'         => 'oc-FR',
                   'piedmontese'     => 'pms-IT',
                   'pinyin'          => 'pny',
                   'polish'          => 'pl-PL',
                   'polutonikogreek' => 'el-GR',
                   'portuges'        => 'pt-PT',
                   'portuguese'      => 'pt-PT',
                   'romanian'        => 'ro-RO',
                   'romansh'         => 'rm-CH',
                   'russian'         => 'ru-RU',
                   'samin'           => 'se-NO',
                   'sanskrit'        => 'sa-IN',
                   'scottish'        => 'gd-GB',
                   'serbian'         => 'sr-Latn',
                   'serbianc'        => 'sr-Cyrl',
                   'slovak'          => 'sk-SK',
                   'slovene'         => 'sl-SI',
                   'slovenian'       => 'sl-SI',
                   'spanish'         => 'es-ES',
                   'swedish'         => 'sv-SE',
                   'swiss'           => 'de-CH',
                   'swissgerman'     => 'de-CH',
                   'nswissgerman'    => 'de-CH',
                   'syriac'          => 'syc',
                   'tamil'           => 'ta-IN',
                   'telugu'          => 'te-IN',
                   'thai'            => 'th-TH',
                   'thaicjk'         => 'th-TH',
                   'tibetan'         => 'bo-CN',
                   'turkish'         => 'tr-TR',
                   'turkmen'         => 'tk-TM',
                   'ukrainian'       => 'uk-UA',
                   'urdu'            => 'ur-IN',
                   'UKenglish'       => 'en-UK',
                   'uppersorbian'    => 'hsb-DE',
                   'USenglish'       => 'en-US',
                   'usorbian'        => 'hsb-DE',
                   'vietnamese'      => 'vi-VN',
                   'welsh'           => 'cy-GB',
                  );

our %LOCALE_MAP_R = (
                     'af'         => 'afrikaans',
                     'af-ZA'      => 'afrikaans',
                     'am'         => 'ethiopia',
                     'am-ET'      => 'amharic',
                     'ar'         => 'arabic',
                     'ar-001'     => 'arabic',
                     'ast'        => 'asturian',
                     'ast-ES'     => 'asturian',
                     'bg'         => 'bulgarian',
                     'bg-BG'      => 'bulgarian',
                     'bn'         => 'bengali',
                     'bn-BD'      => 'bengali',
                     'bo'         => 'tibetan',
                     'bo-CN'      => 'tibetan',
                     'br'         => 'breton',
                     'br-FR'      => 'breton',
                     'ca'         => 'catalan',
                     'ca-AD'      => 'catalan',
                     'ca-ES'      => 'catalan',
                     'cop'        => 'coptic',
                     'cs'         => 'czech',
                     'cs-CZ'      => 'czech',
                     'cy'         => 'welsh',
                     'cy-GB'      => 'welsh',
                     'da'         => 'danish',
                     'da-DK'      => 'danish',
                     'de-1996'    => 'ngerman',
                     'de-AT'      => 'austrian',
                     'de-AT-1996' => 'naustrian',
                     'de-CH'      => 'swissgerman',
                     'de-CH-1996' => 'nswissgerman',
                     'de-DE'      => 'german',
                     'de-DE-1996' => 'ngerman',
                     'dsb'        => 'lowersorbian',
                     'dsb-DE'     => 'lowersorbian',
                     'dv'         => 'divehi',
                     'dv-MV'      => 'divehi',
                     'el'         => 'greek',
                     'el-CY'      => 'ibygreek',
                     'el-GR'      => 'greek',
                     'en'         => 'english',
                     'en-AU'      => 'australian',
                     'en-CA'      => 'canadian',
                     'en-UK'      => 'UKenglish',
                     'en-GB'      => 'british',
                     'en-NZ'      => 'newzealand',
                     'en-US'      => 'USenglish',
                     'en-US'      => 'american',
                     'en-US'      => 'english',
                     'eo'         => 'esperanto',
                     'eo-001'     => 'esperanto',
                     'es'         => 'spanish',
                     'es-ES'      => 'spanish',
                     'et'         => 'estonian',
                     'et-EE'      => 'estonian',
                     'eu'         => 'basque',
                     'eu-ES'      => 'basque',
                     'fa'         => 'farsi',
                     'fa-IR'      => 'farsi',
                     'fi'         => 'finnish',
                     'fi-FI'      => 'finnish',
                     'fr'         => 'french',
                     'fr-CA'      => 'acadian',
                     'fr-CA'      => 'canadien',
                     'fr-FR'      => 'french',
                     'fur'        => 'friulan',
                     'fur-IT'     => 'friulan',
                     'ga'         => 'irish',
                     'ga-IE'      => 'irish',
                     'gd'         => 'scottish',
                     'gd-GB'      => 'scottish',
                     'gl'         => 'galician',
                     'gl-ES'      => 'galician',
                     'ha'         => 'nko',
                     'ha-NG'      => 'nko',
                     'he'         => 'hebrew',
                     'he-IL'      => 'hebrew',
                     'hi'         => 'hindi',
                     'hi-IN'      => 'hindi',
                     'hr'         => 'croatian',
                     'hr-HR'      => 'croatian',
                     'hsb'        => 'uppersorbian',
                     'hsb-DE'     => 'uppersorbian',
                     'hu'         => 'magyar',
                     'hu-HU'      => 'magyar',
                     'hy'         => 'armenian',
                     'hy-AM'      => 'armenian',
                     'ia'         => 'interlingua',
                     'ia-FR'      => 'interlingua',
                     'id'         => 'indonesia',
                     'is'         => 'icelandic',
                     'is-IS'      => 'icelandic',
                     'it'         => 'italian',
                     'it-IT'      => 'italian',
                     'ja'         => 'japanese',
                     'ja-JP'      => 'japanese',
                     'kn'         => 'kannada',
                     'kn-IN'      => 'kannada',
                     'lo'         => 'lao',
                     'lo-LA'      => 'lao',
                     'lt'         => 'lithuanian',
                     'lt-LT'      => 'lithuanian',
                     'lv'         => 'latvian',
                     'lv-LV'      => 'latvian',
                     'ml'         => 'malayalam',
                     'ml-IN'      => 'malayalam',
                     'mn'         => 'mongolian',
                     'mn-Cyrl'    => 'mongolian',
                     'mr'         => 'marathi',
                     'mr-IN'      => 'marathi',
                     'nb'         => 'norsk',
                     'nb-NO'      => 'norsk',
                     'nl'         => 'dutch',
                     'nl-NL'      => 'dutch',
                     'nn'         => 'nynorsk',
                     'nn-NO'      => 'nynorsk',
                     'oc'         => 'occitan',
                     'oc-FR'      => 'occitan',
                     'pl'         => 'polish',
                     'pl-PL'      => 'polish',
                     'pms'        => 'piedmontese',
                     'pms-IT'     => 'piedmontese',
                     'pny'        => 'pinyin',
                     'pt'         => 'portuguese',
                     'pt-BR'      => 'brazilian',
                     'pt-PT'      => 'portuguese',
                     'rm'         => 'romansh',
                     'rm-CH'      => 'romansh',
                     'ro'         => 'romanian',
                     'ro-RO'      => 'romanian',
                     'ru'         => 'russian',
                     'ru-RU'      => 'russian',
                     'sa'         => 'sanskrit',
                     'sa-IN'      => 'sanskrit',
                     'se'         => 'samin',
                     'se-NO'      => 'samin',
                     'sk'         => 'slovak',
                     'sk-SK'      => 'slovak',
                     'sl'         => 'slovenian',
                     'sl-SI'      => 'slovenian',
                     'sq'         => 'albanian',
                     'sq-AL'      => 'albanian',
                     'sr'         => 'serbian',
                     'sr-Cyrl'    => 'serbian',
                     'sr-Latn'    => 'latin',
                     'sv'         => 'swedish',
                     'sv-SE'      => 'swedish',
                     'syc'        => 'syriac',
                     'ta'         => 'tamil',
                     'ta-IN'      => 'tamil',
                     'te'         => 'telugu',
                     'te-IN'      => 'telugu',
                     'th'         => 'thai',
                     'th-TH'      => 'thai',
                     'tk'         => 'turkmen',
                     'tk-TM'      => 'turkmen',
                     'tr'         => 'turkish',
                     'tr-TR'      => 'turkish',
                     'uk'         => 'ukrainian',
                     'uk-UA'      => 'ukrainian',
                     'ur'         => 'urdu',
                     'ur-IN'      => 'urdu',
                     'vi'         => 'vietnamese',
                     'vi-VN'      => 'vietnamese',
                    );

# Holds the scope of each of the BibLaTeX configuration options from the .bcf
our %CONFIG_OPTSCOPE_BIBLATEX;
# Holds the options in a particular scope
our %CONFIG_SCOPEOPT_BIBLATEX;
# Holds the datatype of an option at a particular scope
our %CONFIG_OPTTYPE_BIBLATEX;

# For per-entry options, what should be set when we find them and
# what should be output to the .bbl for biblatex.
# Basically, here we have to emulate relevant parts of biblatex's options processing
# for local entry-specific options, note therefore the presence here of some
# options like max/mincitenames which are not passed in the .bcf
our %CONFIG_BIBLATEX_ENTRY_OPTIONS =
  (
   dataonly          => {OUTPUT => 1,
                         INPUT => {skiplab     => 1,
                                   skipbiblist => 1,
                                   uniquename  => 0,
                                   uniquelist  => 0}
                        },
   maxitems          => {OUTPUT => 1},
   minitems          => {OUTPUT => 1},
   maxbibnames       => {OUTPUT => 1},
   minbibnames       => {OUTPUT => 1},
   maxcitenames      => {OUTPUT => 1},
   mincitenames      => {OUTPUT => 1},
   maxalphanames     => {OUTPUT => 0},
   minalphanames     => {OUTPUT => 0},
   maxnames          => {OUTPUT => ['maxcitenames', 'maxbibnames'],
                         INPUT  => ['maxcitenames', 'maxbibnames']},
   minnames          => {OUTPUT => ['mincitenames', 'minbibnames'],
                         INPUT  => ['mincitenames', 'minbibnames']},
   noinherit         => {OUTPUT => 0},
   presort           => {OUTPUT => 0},
   skipbib           => {OUTPUT => 1},
   skipbiblist       => {OUTPUT => 1},
   skiplab           => {OUTPUT => 1},
   sortnamekeyscheme => {OUTPUT => 1},
   uniquelist        => {OUTPUT => 0},
   useauthor         => {OUTPUT => 1},
   useeditor         => {OUTPUT => 1},
   useprefix         => {OUTPUT => 1},
   usetranslator     => {OUTPUT => 1},
  );


1;

__END__

=pod

=encoding utf-8

=head1 NAME

Biber::Constants - global constants for biber

=head1 AUTHOR

François Charette, C<< <firmicus at ankabut.net> >>
Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our Github tracker at
L<https://github.com/plk/biber/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2017 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
