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
                  $BIBER_SUPPRESS_FINAL
                  $BIBER_SORT_NULL
                  $LABEL_FINAL
                  %CONFIG_DEFAULT_BIBLATEX
                  %CONFIG_OPTSCOPE_BIBLATEX
                  %CONFIG_SCOPEOPT_BIBLATEX
                  %CONFIG_OPTTYPE_BIBLATEX
                  %CONFIG_BIBLATEX_OPTIONS
                  %CONFIG_META_MARKERS
                  %CONFIG_DATE_PARSERS
                  %DATAFIELD_SETS
                  %DM_DATATYPES
                  %LOCALE_MAP
                  %REMOTE_MAP
                  %DS_EXTENSIONS
                  %UNIQUENAME_CONTEXTS
                  %UNIQUENAME_VALUES
                  %MONTHS
              };

# Version of biblatex control file which this release expects. Matched against version
# passed in control file. Used when checking the .bcf
our $BCF_VERSION = '4.0';
# Format version of the .bbl. Used when writing the .bbl
our $BBL_VERSION = '4.0';

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

our %MONTHS = ('jan' => '1',
              'feb' => '2',
              'mar' => '3',
              'apr' => '4',
              'may' => '5',
              'jun' => '6',
              'jul' => '7',
              'aug' => '8',
              'sep' => '9',
              'oct' => '10',
              'nov' => '11',
              'dec' => '12');

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
                      bibtex     => 'bib',
                      biblatexml => 'bltxml'
                      );

# Mapping of biblatex uniquename option to disambiguation level
our %UNIQUENAME_CONTEXTS = ('false' => 'none',
                            'init' => 'init',
                            'full' => 'initorfull',
                            'allinit' => 'init',
                            'allfull' => 'initorfull',
                            'mininit' => 'init',
                            'minfull' => 'initorfull');

# Mapping of strings to numeric uniquename values for easier biblatex processing
our %UNIQUENAME_VALUES = ('none' => 0, 'init' => 1, full => 2);

# Biber option defaults. Mostly not needed outside of tool mode since they are passed by .bcf
our $CONFIG_DEFAULT_BIBER = {
  annotation_marker                           => { content => q/+an/ },
  clrmacros                                   => { content => 0 },
  collate_options                             => { option => {level => 4, variable => 'non-ignorable', normalization => 'prenormalized' }},
  graph                                       => { content => 0 },
  debug                                       => { content => 0 },
  dieondatamodel                              => { content => 0 },
  decodecharsset                              => { content => 'base' },
  fixinits                                    => { content => 0 },
  input_encoding                              => { content => 'UTF-8' },
  input_format                                => { content => 'bibtex' },
  isbn10                                      => { content => 0 },
  isbn13                                      => { content => 0 },
  isbn_normalise                              => { content => 0 },
  listsep                                     => { content => 'and' },
  mincrossrefs                                => { content => 2 },
  minxrefs                                    => { content => 2 },
  mslang                                      => { content => 'en-us' },
  mssep                                       => { content => '_' },
  msstrict                                    => { content => 0 },
  named_annotation_marker                     => { content => q/:/ },
  namesep                                     => { content => 'and' },
  no_bltxml_schema                            => { content => 0 },
  no_default_datamodel                        => { content => 0 },
  nodieonerror                                => { content => 0 },
  noinit                                      => { option => [ {value => q/\b\p{Ll}{2}\p{Pd}(?=\S)/},
                                                               {value => q/[\x{2bf}\x{2018}]/} ] },
  nolabel                                     => { option => [ {value => q/[\p{Pc}\p{Ps}\p{Pe}\p{Pi}\p{Pf}\p{Po}\p{S}\p{C}]+/} ] },
#  nolabelwidthcount                          => { option =>  }, # default is nothing
  nolog                                       => { content => 0 },
  noskipduplicates                            => { content => 0 },
  nostdmacros                                 => { content => 0 },
  nosort                                      => { option => [ { name => 'setnames', value => q/\A\p{L}{2}\p{Pd}(?=\S)/ },
                                                               { name => 'setnames', value => q/[\x{2bf}\x{2018}]/ } ] },
  onlylog                                     => { content => 0 },
  others_string                               => { content => 'others' },
  output_align                                => { content => 0 },
  output_annotation_marker                    => { content => '+an' },
  output_named_annotation_marker              => { content => ':' },
  output_encoding                             => { content => 'UTF-8' },
  output_field_order                          => { content => 'options,abstract,names,lists,dates' },
  output_format                               => { content => 'bbl' },
  output_indent                               => { content => '2' },
  output_fieldcase                            => { content => 'upper' },
  output_listsep                              => { content => 'and' },
  output_mssep                                => { content => '_' },
  output_namesep                              => { content => 'and' },
  output_resolve_xdata                        => { content => 0 },
  output_resolve_crossrefs                    => { content => 0 },
  output_resolve_sets                         => { content => 0 },
  output_safechars                            => { content => 0 },
  output_safecharsset                         => { content => 'base' },
  output_xdatamarker                          => { content => 'xdata' },
  output_xdatasep                             => { content => '-' },
  output_xnamesep                             => { content => '=' },
  quiet                                       => { content => 0 },
  remove_tmp_dir                              => { content => 1 },
  sortdebug                                   => { content => 0 },
  sortcase                                    => { content => 1 },
  sortupper                                   => { content => 1 },
  strip_comments                              => { content => 0 },
  tool                                        => { content => 0 },
  tool_noremove_missing_dependants            => { content => 0 },
  trace                                       => { content => 0 },
  nouri_encode                                => { content => 0 },
  validate_bltxml                             => { content => 0 },
  validate_config                             => { content => 0 },
  validate_control                            => { content => 0 },
  validate_datamodel                          => { content => 0 },
  wraplines                                   => { content => 0 },
  xdatamarker                                 => { content => 'xdata' },
  xdatasep                                    => { content => '-' },
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
                                sortingtemplatename    => 'tool',
                                useauthor     => 1,
                                useeditor     => 1,
                                usetranslator => 1,
                                maxbibnames   => 100,
                                maxitems      => 100,
                                minbibnames   => 100,
                                maxalphanames => 100,
                                maxcitenames  => 100,
                                maxsortnames  => 100,
                                minalphanames => 100,
                                mincitenames  => 100,
                                minsortnames  => 100,
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
                   'acadian'         => 'fr-ca',
                   'american'        => 'en-us',
                   'australian'      => 'en-au',
                   'afrikaans'       => 'af-za',
                   'albanian'        => 'sq-al',
                   'amharic'         => 'am-et',
                   'arabic'          => 'ar-001',
                   'armenian'        => 'hy-am',
                   'asturian'        => 'ast-es',
                   'austrian'        => 'de-at',
                   'bahasa'          => 'id-id',
                   'bahasai'         => 'id-id',
                   'bahasam'         => 'id-id',
                   'basque'          => 'eu-es',
                   'bengali'         => 'bn-bd',
                   'bgreek'          => 'el-gr',
                   'brazil'          => 'pt-br',
                   'brazilian'       => 'pt-br',
                   'breton'          => 'br-fr',
                   'british'         => 'en-gb',
                   'bulgarian'       => 'bg-bg',
                   'canadian'        => 'en-ca',
                   'canadien'        => 'fr-ca',
                   'catalan'         => 'ca-ad',
                   'coptic'          => 'cop',
                   'croatian'        => 'hr-hr',
                   'czech'           => 'cs-cz',
                   'danish'          => 'da-dk',
                   'divehi'          => 'dv-mv',
                   'dutch'           => 'nl-nl',
                   'english'         => 'en-us',
                   'esperanto'       => 'eo-001',
                   'estonian'        => 'et-ee',
                   'ethiopia'        => 'am-et',
                   'farsi'           => 'fa-ir',
                   'finnish'         => 'fi-fi',
                   'francais'        => 'fr-fr',
                   'french'          => 'fr-fr',
                   'frenchle'        => 'fr-fr',
                   'friulan'         => 'fur-it',
                   'galician'        => 'gl-es',
                   'german'          => 'de',
                   'germanb'         => 'de-de',
                   'greek'           => 'el-gr',
                   'hebrew'          => 'he-il',
                   'hindi'           => 'hi-in',
                   'ibygreek'        => 'el-cy',
                   'icelandic'       => 'is-is',
                   'indon'           => 'id-id',
                   'indonesia'       => 'id-id',
                   'interlingua'     => 'ia-fr',
                   'irish'           => 'ga-ie',
                   'italian'         => 'it-it',
                   'japanese'        => 'ja-jp',
                   'kannada'         => 'kn-in',
                   'lao'             => 'lo-la',
                   'latin'           => 'la-latn',
                   'latvian'         => 'lv-lv',
                   'lithuanian'      => 'lt-lt',
                   'lowersorbian'    => 'dsb-de',
                   'lsorbian'        => 'dsb-de',
                   'magyar'          => 'hu-hu',
                   'malay'           => 'id-id',
                   'malayalam'       => 'ml-in',
                   'marathi'         => 'mr-in',
                   'meyalu'          => 'id-id',
                   'mongolian'       => 'mn-cyrl',
                   'naustrian'       => 'de-at',
                   'newzealand'      => 'en-nz',
                   'ngerman'         => 'de-de',
                   'nko'             => 'ha-ng',
                   'norsk'           => 'nb-no',
                   'norwegian'       => 'nn-no',
                   'nynorsk'         => 'nn-no',
                   'occitan'         => 'oc-fr',
                   'piedmontese'     => 'pms-it',
                   'pinyin'          => 'pny',
                   'polish'          => 'pl-pl',
                   'polutonikogreek' => 'el-gr',
                   'portuges'        => 'pt-pt',
                   'portuguese'      => 'pt-pt',
                   'romanian'        => 'ro-ro',
                   'romansh'         => 'rm-ch',
                   'russian'         => 'ru-ru',
                   'samin'           => 'se-no',
                   'sanskrit'        => 'sa-in',
                   'scottish'        => 'gd-gb',
                   'serbian'         => 'sr-latn',
                   'serbianc'        => 'sr-cyrl',
                   'slovak'          => 'sk-sk',
                   'slovene'         => 'sl-si',
                   'slovenian'       => 'sl-si',
                   'spanish'         => 'es-es',
                   'swedish'         => 'sv-se',
                   'swiss'           => 'de-ch',
                   'swissgerman'     => 'de-ch',
                   'nswissgerman'    => 'de-ch',
                   'syriac'          => 'syc',
                   'tamil'           => 'ta-in',
                   'telugu'          => 'te-in',
                   'thai'            => 'th-th',
                   'thaicjk'         => 'th-th',
                   'tibetan'         => 'bo-cn',
                   'turkish'         => 'tr-tr',
                   'turkmen'         => 'tk-tm',
                   'ukrainian'       => 'uk-ua',
                   'urdu'            => 'ur-in',
                   'ukenglish'       => 'en-uk',
                   'uppersorbian'    => 'hsb-de',
                   'usenglish'       => 'en-us',
                   'usorbian'        => 'hsb-de',
                   'vietnamese'      => 'vi-vn',
                   'welsh'           => 'cy-gb',
                  );

# Holds the scope of each of the BibLaTeX configuration options from the .bcf
our %CONFIG_OPTSCOPE_BIBLATEX;
# Holds the options in a particular scope
our %CONFIG_SCOPEOPT_BIBLATEX;
# Holds the datatype of an option at a particular scope
our %CONFIG_OPTTYPE_BIBLATEX;
# For per-entry, per-namelist and per-name options, what should be set when we find them and
# should they be output to the .bbl for biblatex.
our %CONFIG_BIBLATEX_OPTIONS;

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Biber::Constants - global constants for biber

=head1 AUTHOR

Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our Github tracker at
L<https://github.com/plk/biber/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2012 François Charette and Philip Kime, all rights reserved.
Copyright 2012-2020 Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
