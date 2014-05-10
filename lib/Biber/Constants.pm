package Biber::Constants;
use v5.16;
use strict;
use warnings;

use Encode::Alias;

use base 'Exporter';

our @EXPORT = qw{
                  $CONFIG_DEFAULT_BIBER
                  %CONFIG_DEFAULT_BIBLATEX
                  %CONFIG_SCOPE_BIBLATEX
                  %CONFIG_BIBLATEX_PER_ENTRY_OPTIONS
                  %NOSORT_TYPES
                  %DM_DATATYPES
                  %LOCALE_MAP
                  %LOCALE_MAP_R
                  %REMOTE_MAP
                  $BIBER_CONF_NAME
                  $BCF_VERSION
                  $BBL_VERSION
                  $BIBER_SORT_FINAL
                  $BIBER_SORT_NULL
                  $LABEL_FINAL
              };

# Version of biblatex control file which this release expects. Matched against version
# passed in control file. Used when checking the .bcf
our $BCF_VERSION = '2.6';
# Format version of the .bbl. Used when writing the .bbl
our $BBL_VERSION = '2.4';

# Global flags needed for sorting
our $BIBER_SORT_FINAL = 0;
our $BIBER_SORT_NULL  = 0;

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

# nosort type category shortcuts
our %NOSORT_TYPES = (
                     type_name => {
                                   author => 1,
                                   afterword => 1,
                                   annotator => 1,
                                   bookauthor => 1,
                                   commentator => 1,
                                   editor => 1,
                                   editora => 1,
                                   editorb => 1,
                                   editorc => 1,
                                   foreword => 1,
                                   holder => 1,
                                   introduction => 1,
                                   namea => 1,
                                   nameb => 1,
                                   namec => 1,
                                   shortauthor => 1,
                                   shorteditor => 1,
                                   translator => 1
                                  },
                     type_title => {
                                    booktitle => 1,
                                    eventtitle => 1,
                                    issuetitle => 1,
                                    journaltitle => 1,
                                    maintitle => 1,
                                    origtitle => 1,
                                    title => 1
                                   }
);

# datatypes for data model validation
our %DM_DATATYPES = (
                     integer => qr/\A\d+\z/xms,
                     datepart => qr/\A\d+\z/xms
);

# Biber option defaults. Mostly not needed outside of tool mode since they are passed by .bcf

our $CONFIG_DEFAULT_BIBER = {
  clrmacros           => { content => 0 },
  collate             => { content => 1 },
  collate_options     => { option => { level => 4, variable => 'non-ignorable', normalization => 'prenormalized' }},
  graph               => { content => 0 },
  debug               => { content => 0 },
  decodecharsset      => { content => 'base' },
  dot_include         => { option => {section => 1, xdata => 1, crossref => 1, xref => 1 }},
  fastsort            => { content => 0 },
  fixinits            => { content => 0 },
  input_encoding      => { content => 'UTF-8' },
  input_format        => { content => 'bibtex' },
  listsep             => { content => 'and' },
  mincrossrefs        => { content => 2 },
  mssplit             => { content => '_' },
  namesep             => { content => 'and' },
  nodieonerror        => { content => 0 },
  noinit              => { option => [ {value => q/\b\p{Ll}{2}\p{Pd}/},
                                       {value => q/[\x{2bf}\x{2018}]/} ] },
  nolog               => { content => 0 },
  nostdmacros         => { content => 0 },
  nosort              => { option => [ { name => 'type_name', value => q/\A\p{L}{2}\p{Pd}/ },
                                       { name => 'type_name', value => q/[\x{2bf}\x{2018}]/ } ] },
  onlylog             => { content => 0 },
  others_string       => { content => 'others' },
  output_align        => { content => 1 },
  output_encoding     => { content => 'UTF-8' },
  output_format       => { content => 'bbl' },
  output_indent       => { content => '2' },
  output_fieldcase    => { content => 'upper' },
  output_resolve      => { content => 0 },
  output_safechars    => { content => 0 },
  output_safecharsset => { content => 'base' },
  quiet               => { content => 0 },
  sortcase            => { content => 1 },
  sortfirstinits      => { content => 0 },
  sortupper           => { content => 1 },
  tool                => { content => 0 },
  trace               => { content => 0 },
  validate_config     => { content => 0 },
  validate_control    => { content => 0 },
  validate_datamodel  => { content => 0 },
  wraplines           => { content => 0 },
  xsvsep              => { content => q/\s*,\s*/ },
};

# default global options for biblatex
# Used to set:
# * Some tool-mode defaults (as there is no .bcf and some biblatex options
#   cannot be set in a biber config file)
our %CONFIG_DEFAULT_BIBLATEX = (
  sortscheme => 'none',
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

# Defines sensible defaults for setting sort locale (bcp47) from babel/polyglossia language names
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
                   'catalan'         => 'ca-ES',
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
                   'latin'           => 'sr-Latn',
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
                   'serbian'         => 'sr-Cyrl',
                   'serbianc'        => 'sr-Cyrl',
                   'slovak'          => 'sk-SK',
                   'slovene'         => 'sl-SI',
                   'slovenian'       => 'sl-SI',
                   'spanish'         => 'es-ES',
                   'swedish'         => 'sv-SE',
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
                   'UKenglish'       => 'en-GB',
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
                     'en-GB'      => 'UKenglish',
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

# Defines the scope of each of the BibLaTeX configuration options
#
# PRESORT is not a "real" biblatex option passed by biblatex. It is defined
# by the biblatex \DeclarePresort macro and is stored in here as it
# can be global/per-type or per-entry and therefore it's natural to store it here.
our %CONFIG_SCOPE_BIBLATEX = (
  alphaothers        => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 0},
  controlversion     => {GLOBAL => 1, PER_TYPE => 0, PER_ENTRY => 0},
  debug              => {GLOBAL => 1, PER_TYPE => 0, PER_ENTRY => 0},
  datamodel          => {GLOBAL => 1, PER_TYPE => 0, PER_ENTRY => 0},
  dataonly           => {GLOBAL => 0, PER_TYPE => 0, PER_ENTRY => 1},
  inheritance        => {GLOBAL => 1, PER_TYPE => 0, PER_ENTRY => 0},
  labelalpha         => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 0},
  labelalphatemplate => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 0},
  labelnamefield     => {GLOBAL => 0, PER_TYPE => 0, PER_ENTRY => 1},
  labelnameform      => {GLOBAL => 0, PER_TYPE => 0, PER_ENTRY => 1},
  labelnamelang      => {GLOBAL => 0, PER_TYPE => 0, PER_ENTRY => 1},
  labelnamespec      => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 0},
  labelnumber        => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 0},
  labeltitle         => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 0},
  labeltitlefield    => {GLOBAL => 0, PER_TYPE => 0, PER_ENTRY => 1},
  labeltitleform     => {GLOBAL => 0, PER_TYPE => 0, PER_ENTRY => 1},
  labeltitlelang     => {GLOBAL => 0, PER_TYPE => 0, PER_ENTRY => 1},
  labeltitlespec     => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 0},
  labeltitleyear     => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 0},
  labeldate          => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 0},
  labeldatespec      => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 0},
  maxalphanames      => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 1},
  maxbibnames        => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 1},
  maxcitenames       => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 1},
  maxitems           => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 1},
  minalphanames      => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 1},
  minbibnames        => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 1},
  mincitenames       => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 1},
  minitems           => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 1},
  presort            => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 1},
  singletitle        => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 0},
  skipbib            => {GLOBAL => 0, PER_TYPE => 1, PER_ENTRY => 1},
  skipbiblist        => {GLOBAL => 0, PER_TYPE => 1, PER_ENTRY => 1},
  skiplab            => {GLOBAL => 0, PER_TYPE => 1, PER_ENTRY => 1},
  sortalphaothers    => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 0},
  sortexclusion      => {GLOBAL => 0, PER_TYPE => 1, PER_ENTRY => 0},
  sorting            => {GLOBAL => 1, PER_TYPE => 0, PER_ENTRY => 0},
  sortlocale         => {GLOBAL => 1, PER_TYPE => 0, PER_ENTRY => 0},
  sortscheme         => {GLOBAL => 1, PER_TYPE => 0, PER_ENTRY => 0},
  uniquelist         => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 1},
  uniquename         => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 1},
  useauthor          => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 1},
  useeditor          => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 1},
  useprefix          => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 1},
  usetranslator      => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 1},
);

# For per-entry options, what should be set when we find them and
# what should be output to the .bbl for biblatex.
# Basically, here we have to emulate relevant parts of biblatex's options processing
# for local entry-specific options, note therefore the presence here of some
# options like max/mincitenames which are not passed in the .bcf
our %CONFIG_BIBLATEX_PER_ENTRY_OPTIONS =  (
  dataonly       => {OUTPUT => 1, INPUT => {'skiplab' => 1,
                                            'skipbiblist' => 1,
                                            'uniquename' => 0,
                                            'uniquelist' => 0}},
  maxitems       => {OUTPUT => 1},
  minitems       => {OUTPUT => 1},
  maxbibnames    => {OUTPUT => 1},
  minbibnames    => {OUTPUT => 1},
  maxcitenames   => {OUTPUT => 1},
  mincitenames   => {OUTPUT => 1},
  maxalphanames  => {OUTPUT => 0},
  minalphanames  => {OUTPUT => 0},
  maxnames       => {OUTPUT => ['maxcitenames', 'maxbibnames'], INPUT  => ['maxcitenames', 'maxbibnames']},
  minnames       => {OUTPUT => ['mincitenames', 'minbibnames'], INPUT  => ['mincitenames', 'minbibnames']},
  presort        => {OUTPUT => 0},
  skipbib        => {OUTPUT => 1},
  skipbiblist    => {OUTPUT => 1},
  skiplab        => {OUTPUT => 1},
  uniquelist     => {OUTPUT => 0},
  useauthor      => {OUTPUT => 1},
  useeditor      => {OUTPUT => 1},
  useprefix      => {OUTPUT => 1},
  usetranslator  => {OUTPUT => 1},
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

Copyright 2009-2014 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
