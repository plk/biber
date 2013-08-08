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
  $BIBER_CONF_NAME
  $BCF_VERSION
  $BBL_VERSION
  $BIBER_SORT_FINAL
  $BIBER_SORT_NULL
  $LABEL_FINAL
  };

# Version of biblatex control file which this release expects. Matched against version
# passed in control file. Used when checking the .bcf
our $BCF_VERSION = '2.5';
# Format version of the .bbl. Used when writing the .bbl
our $BBL_VERSION = '2.3';

# Global flags needed for sorting
our $BIBER_SORT_FINAL = 0;
our $BIBER_SORT_NULL  = 0;

# the name of the Biber configuration file, which should be
# either returned by kpsewhich or located at "$HOME/.$BIBER_CONF_NAME"
our $BIBER_CONF_NAME = 'biber.conf';

## Biber CONFIGURATION DEFAULTS

# Locale - first try environment ...
my $locale;
if ($ENV{LC_COLLATE}) {
  $locale = $ENV{LC_COLLATE};
}
elsif ($ENV{LANG}) {
  $locale = $ENV{LANG};
}
elsif ($ENV{LC_ALL}) {
  $locale = $ENV{LC_ALL};
}

# ... if nothing, set a default
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
  collate_options     => { option => { level => 4, variable => 'non-ignorable' }},
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
  sortlocale          => { content => $locale },
  sortupper           => { content => 1 },
  tool                => { content => 0 },
  trace               => { content => 0 },
  validate_config     => { content => 0 },
  validate_control    => { content => 0 },
  validate_datamodel  => { content => 0 },
  wraplines           => { content => 0 },
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
  skiplab            => {GLOBAL => 0, PER_TYPE => 1, PER_ENTRY => 1},
  skiplos            => {GLOBAL => 0, PER_TYPE => 1, PER_ENTRY => 1},
  sortalphaothers    => {GLOBAL => 1, PER_TYPE => 1, PER_ENTRY => 0},
  sortexclusion      => {GLOBAL => 0, PER_TYPE => 1, PER_ENTRY => 0},
  sorting            => {GLOBAL => 1, PER_TYPE => 0, PER_ENTRY => 0},
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
                                            'skiplos' => 1,
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
  skiplab        => {OUTPUT => 1},
  skiplos        => {OUTPUT => 1},
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

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2013 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
