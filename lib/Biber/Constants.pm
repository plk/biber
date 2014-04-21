package Biber::Constants;
use v5.16;
use strict;
use warnings;

use Encode::Alias;

use parent 'Exporter';

our @EXPORT = qw{
                  $CONFIG_DEFAULT_BIBER
                  %CONFIG_DEFAULT_BIBLATEX
                  %CONFIG_SCOPE_BIBLATEX
                  %CONFIG_BIBLATEX_PER_ENTRY_OPTIONS
                  %NOSORT_TYPES
                  %DM_DATATYPES
                  %LOCALE_MAP
                  %LOCALE_MAP_R
                  $BIBER_CONF_NAME
                  $BCF_VERSION
                  $BBL_VERSION
                  $BIBER_SORT_FINAL
                  $BIBER_SORT_NULL
                  $LABEL_FINAL
              };

# Version of biblatex control file which this release expects. Matched against version
# passed in control file. Used when checking the .bcf
our $BCF_VERSION = '3.0';
# Format version of the .bbl. Used when writing the .bbl
our $BBL_VERSION = '3.0';

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
  vsplit              => { content => '_' },
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
                   'acadian'         => {locale => 'fr_CA'},
                   'american'        => {locale => 'en_US'},
                   'australian'      => {locale => 'en_AU'},
                   'afrikaans'       => {locale => 'af_ZA'},
                   'albanian'        => {locale => 'sq_AL'},
                   'amharic'         => {locale => 'am_ET'},
                   'arabic'          => {locale => 'ar_001'},
                   'armenian'        => {locale => 'hy_AM'},
                   'asturian'        => {locale => 'ast_ES'},
                   'austrian'        => {locale => 'de_AT'},
                   'bahasa'          => {locale => 'id_ID'},
                   'bahasai'         => {locale => 'id_ID'},
                   'bahasam'         => {locale => 'id_ID'},
                   'basque'          => {locale => 'eu_ES'},
                   'bengali'         => {locale => 'bn_BD'},
                   'bgreek'          => {locale => 'el_GR'},
                   'brazil'          => {locale => 'pt_BR'},
                   'brazilian'       => {locale => 'pt_BR', preferred => 1},
                   'breton'          => {locale => 'br_FR'},
                   'british'         => {locale => 'en_GB'},
                   'bulgarian'       => {locale => 'bg_BG'},
                   'canadian'        => {locale => 'en_US'},
                   'canadien'        => {locale => 'fr_CA'},
                   'catalan'         => {locale => 'ca_ES'},
                   'coptic'          => {locale => 'cop'},
                   'croatian'        => {locale => 'hr_HR'},
                   'czech'           => {locale => 'cs_CZ'},
                   'danish'          => {locale => 'da_DK'},
                   'divehi'          => {locale => 'dv_MV'},
                   'dutch'           => {locale => 'nl_NL'},
                   'english'         => {locale => 'en_US'},
                   'esperanto'       => {locale => 'eo_001'},
                   'estonian'        => {locale => 'et_EE'},
                   'ethiopia'        => {locale => 'am_ET'},
                   'farsi'           => {locale => 'fa_IR'},
                   'finnish'         => {locale => 'fi_FI'},
                   'francais'        => {locale => 'fr_FR'},
                   'french'          => {locale => 'fr_FR', preferred => 1},
                   'frenchle'        => {locale => 'fr_FR'},
                   'friulan'         => {locale => 'fur_IT'},
                   'galician'        => {locale => 'gl_ES'},
                   'german'          => {locale => 'de_DE', preferred => 1},
                   'germanb'         => {locale => 'de_DE'},
                   'greek'           => {locale => 'el_GR'},
                   'hebrew'          => {locale => 'he_IL'},
                   'hindi'           => {locale => 'hi_IN'},
                   'ibygreek'        => {locale => 'el_CY'},
                   'icelandic'       => {locale => 'is_IS'},
                   'indon'           => {locale => 'id_ID'},
                   'indonesia'       => {locale => 'id_ID', preferred => 1},
                   'interlingua'     => {locale => 'ia_FR'},
                   'irish'           => {locale => 'ga_IE'},
                   'italian'         => {locale => 'it_IT'},
                   'japanese'        => {locale => 'ja_JP'},
                   'kannada'         => {locale => 'kn_IN'},
                   'lao'             => {locale => 'lo_LA'},
                   'latin'           => {locale => 'sr_Latn'},
                   'latvian'         => {locale => 'lv_LV'},
                   'lithuanian'      => {locale => 'lt_LT'},
                   'lowersorbian'    => {locale => 'dsb_DE', preferred => 1},
                   'lsorbian'        => {locale => 'dsb_DE'},
                   'magyar'          => {locale => 'hu_HU'},
                   'malay'           => {locale => 'id_ID'},
                   'malayalam'       => {locale => 'ml_IN'},
                   'marathi'         => {locale => 'mr_IN'},
                   'meyalu'          => {locale => 'id_ID'},
                   'mongolian'       => {locale => 'mn_Cyrl'},
                   'naustrian'       => {locale => 'de_AT'},
                   'newzealand'      => {locale => 'en_US'},
                   'ngerman'         => {locale => 'de_DE'},
                   'nko'             => {locale => 'ha_NG'},
                   'norsk'           => {locale => 'nb_NO'},
                   'nynorsk'         => {locale => 'nn_NO'},
                   'occitan'         => {locale => 'oc_FR'},
                   'piedmontese'     => {locale => 'pms_IT'},
                   'pinyin'          => {locale => 'pny'},
                   'polish'          => {locale => 'pl_PL'},
                   'polutonikogreek' => {locale => 'el_GR'},
                   'portuges'        => {locale => 'pt_PT'},
                   'portuguese'      => {locale => 'pt_PT'},
                   'romanian'        => {locale => 'ro_RO'},
                   'romansh'         => {locale => 'rm_CH'},
                   'russian'         => {locale => 'ru_RU'},
                   'samin'           => {locale => 'se_NO'},
                   'sanskrit'        => {locale => 'sa_IN'},
                   'scottish'        => {locale => 'gd_GB'},
                   'serbian'         => {locale => 'sr_Cyrl', preferred => 1},
                   'serbianc'        => {locale => 'sr_Cyrl'},
                   'slovak'          => {locale => 'sk_SK'},
                   'slovene'         => {locale => 'sl_SI'},
                   'slovenian'       => {locale => 'sl_SI', preferred => 1},
                   'spanish'         => {locale => 'es_ES'},
                   'swedish'         => {locale => 'sv_SE'},
                   'syriac'          => {locale => 'syc'},
                   'tamil'           => {locale => 'ta_IN'},
                   'telugu'          => {locale => 'te_IN'},
                   'thai'            => {locale => 'th_TH', preferred => 1},
                   'thaicjk'         => {locale => 'th_TH'},
                   'tibetan'         => {locale => 'bo_CN'},
                   'turkish'         => {locale => 'tr_TR'},
                   'turkmen'         => {locale => 'tk_TM'},
                   'ukrainian'       => {locale => 'uk_UA'},
                   'urdu'            => {locale => 'ur_IN'},
                   'UKenglish'       => {locale => 'en_GB'},
                   'uppersorbian'    => {locale => 'hsb_DE'},
                   'USenglish'       => {locale => 'en_US'},
                   'usorbian'        => {locale => 'hsb_DE'},
                   'vietnamese'      => {locale => 'vi_VN'},
                   'welsh'           => {locale => 'cy_GB'},
                  );
# Create reverse map for biblatexml xml:lang mapping and put in preferred overrides
our %LOCALE_MAP_R;
while (my ($k,$v) = each %LOCALE_MAP) {
  if (defined($LOCALE_MAP_R{$v->{locale}})) {
    if ($v->{preferred}) {
      $LOCALE_MAP_R{$v->{locale}} = $k;
    }
  }
  else {
    $LOCALE_MAP_R{$v->{locale}} = $k;
  }
}

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
  labeldate          => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 0},
  labeldatespec      => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 0},
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
  variantforms       => {GLOBAL => 1, PER_TYPE => 0, PER_ENTRY => 0},
  vform              => {GLOBAL => 1, PER_TYPE => 0, PER_ENTRY => 1},
  vlang              => {GLOBAL => 1, PER_TYPE => 0, PER_ENTRY => 1},
  vtranslang         => {GLOBAL => 1, PER_TYPE => 0, PER_ENTRY => 1},
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
  maxitems        => {OUTPUT => 1},
  minitems        => {OUTPUT => 1},
  maxbibnames     => {OUTPUT => 1},
  minbibnames     => {OUTPUT => 1},
  maxcitenames    => {OUTPUT => 1},
  mincitenames    => {OUTPUT => 1},
  maxalphanames   => {OUTPUT => 0},
  minalphanames   => {OUTPUT => 0},
  maxnames        => {OUTPUT => ['maxcitenames', 'maxbibnames'], INPUT  => ['maxcitenames', 'maxbibnames']},
  minnames        => {OUTPUT => ['mincitenames', 'minbibnames'], INPUT  => ['mincitenames', 'minbibnames']},
  presort         => {OUTPUT => 0},
  skipbib         => {OUTPUT => 1},
  skiplab         => {OUTPUT => 1},
  skipbiblist     => {OUTPUT => 1},
  uniquelist      => {OUTPUT => 0},
  useauthor       => {OUTPUT => 1},
  useeditor       => {OUTPUT => 1},
  useprefix       => {OUTPUT => 1},
  usetranslator   => {OUTPUT => 1},
  vform           => {OUTPUT => 1},
  vlang           => {OUTPUT => 1},
  vtranslang      => {OUTPUT => 1},
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

Copyright 2009-2013 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
