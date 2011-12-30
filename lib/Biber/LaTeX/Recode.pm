package Biber::LaTeX::Recode;
use 5.014000;
use strict;
use warnings;
use base qw(Exporter);
use Biber::Config;
use Unicode::Normalize;
use List::AllUtils qw (first);
use XML::LibXML::Simple;
use Carp;

our @EXPORT  = qw(latex_encode latex_decode);

=encoding utf-8

=head1 NAME

Biber::LaTeX::Recode - Encode/Decode chars to/from UTF-8/lacros in LaTeX

=head1 SYNOPSIS

    use Biber::LaTeX:Recode

    my $string       = 'Muḥammad ibn Mūsā al-Khwārizmī';
    my $latex_string = latex_encode($string);
        # => 'Mu\d{h}ammad ibn M\=us\=a al-Khw\=arizm\={\i}'

    my $string = 'Mu\d{h}ammad ibn M\=us\=a al-Khw\=arizm\={\i}';
    my $utf8_string   = latex_decode($string);
        # => 'Muḥammad ibn Mūsā al-Khwārizmī'

=head1 DESCRIPTION

Allows conversion between Unicode chars and LaTeX macros.

=head1 GLOBAL OPTIONS

Possible values for the encoding/decoding scheme to use are 'base' and 'full'; default
value is 'base'.

base  => Most common macros and diacritics (sufficient for Western languages
         and common symbols)

full  => Also converts punctuation, larger range of diacritics and macros
         (e.g. for IPA, Latin Extended Additional, etc.), symbols, Greek letters,
         dingbats, negated symbols, and superscript characters and symbols ...

=cut

use vars qw(
$scheme_d
$scheme_e
%ACCENTS         %ACCENTS_R
%WORDMACROS      %WORDMACROS_R
%DIAC            %DIAC_R
%PUNCTUATION     %PUNCTUATION_R
%NEGATEDSYMBOLS  %NEGATEDSYMBOLS_R
%SUPERSCRIPTS    %SUPERSCRIPTS_R
%SYMBOLS         %SYMBOLS_R
%CMDSUPERSCRIPTS %CMDSUPERSCRIPTS_R
%DINGS           %DINGS_R
%GREEK           %GREEK_R
$ACCENTS_RE      $ACCENTS_RE_R
$DIAC_RE         $DIAC_RE_R
$NEG_SYMB_RE     $NEG_SYMB_RE_R
$SUPER_RE        $SUPER_RE_R
$SUPERCMD_RE     $SUPERCMD_RE_R
$DINGS_RE_R
);


# we assume that the data file is in the same dir as the module
(my $vol, my $data_path, undef) = File::Spec->splitpath( $INC{'Biber/LaTeX/Recode.pm'} );

# Deal with the strange world of Par::Packer paths, see similar code in Biber.pm
my $mapdata;
if ($data_path =~ m|/par\-| and $data_path !~ m|/inc|) { # a mangled PAR @INC path
  $mapdata = File::Spec->catpath($vol, "$data_path/inc/lib/Biber/LaTeX/recode_data.xml");
}
else {
  $mapdata = File::Spec->catpath($vol, $data_path, 'recode_data.xml');
}

# Read driver config file
my $dataxml = XML::LibXML::Simple::XMLin($mapdata, 'ForceContent' => 1);




%ACCENTS = map {$_->{from}{content} => $_->{to}{content}} @{$dataxml->{accents}{map}};
%ACCENTS_R = reverse %ACCENTS;

%WORDMACROS = map {$_->{from}{content} => $_->{to}{content}} @{$dataxml->{wordmacros}{map}};
%WORDMACROS_R = reverse %WORDMACROS;
# There are some duplicates in the hash. reverse() doesn't predictably deal with this.
# Force specific prefered reverse mapping to override unpredictable reverse()
# We still use reverse() and just correct it afterwards as it's fast
foreach my $r (@{$dataxml->{wordmacros}{map}}) {
  next unless exists($r->{from}{preferred});
  $WORDMACROS_R{$r->{to}{content}} = $r->{from}{content};
}

# Things we don't want to change when encoding as this would break LaTeX
foreach my $e (map {$_->{content}} @{$dataxml->{encode_exclude}{char}}) {
  delete($WORDMACROS_R{$e});
}

%DIAC = map {$_->{from}{content} => $_->{to}{content}} @{$dataxml->{diacritics}{map}};
%DIAC_R = reverse %DIAC;
# There are some duplicates in the hash. reverse() doesn't predictably deal with this.
# Force specific prefered reverse mapping to override unpredictable reverse()
# We still use reverse() and just correct it afterwards as it's fast
foreach my $r (@{$dataxml->{diacritics}{map}}) {
  next unless exists($r->{from}{preferred});
  $DIAC_R{$r->{to}{content}} = $r->{from}{content};
}

$ACCENTS_RE = qr{[\^\.`'"~=]};
$ACCENTS_RE_R = qr{[\x{300}-\x{304}\x{307}\x{308}]};
$DIAC_RE  = join('|', keys %DIAC);
$DIAC_RE = qr{$DIAC_RE};
$DIAC_RE_R  = join('|', keys %DIAC_R);
$DIAC_RE_R = qr{$DIAC_RE_R};


=head2 init_schemes(<decode scheme>, <encode_scheme>)

  Initialise schemes. We can't do this on loading the module as we don't have the config
  information to do this yet

=cut

sub init_schemes {
  shift; # class method
  ($scheme_d, $scheme_e) = @_;

  # Only in full scheme
  if ( $scheme_d eq 'full' or $scheme_e eq 'full') {
    %PUNCTUATION = map {$_->{from}{content} => $_->{to}{content}} @{$dataxml->{punctuation}{map}};
    %PUNCTUATION_R = reverse %PUNCTUATION;

    %SYMBOLS = map {$_->{from}{content} => $_->{to}{content}} @{$dataxml->{symbols}{map}};
    %SYMBOLS_R = reverse %SYMBOLS;
    # There are some duplicates in the hash. reverse() doesn't predictably deal with this.
    # Force specific prefered reverse mapping to override unpredictable reverse()
    # We still use reverse() and just correct it afterwards as it's fast
    foreach my $r (@{$dataxml->{symbols}{map}}) {
      next unless exists($r->{from}{preferred});
      $SYMBOLS_R{$r->{to}{content}} = $r->{from}{content};
    }

    %DINGS = map {$_->{from}{content} => $_->{to}{content}} @{$dataxml->{dings}{map}};
    %DINGS_R = reverse %DINGS;
    %NEGATEDSYMBOLS = map {$_->{from}{content} => $_->{to}{content}} @{$dataxml->{negatedsymbols}{map}};
    %NEGATEDSYMBOLS_R = reverse %NEGATEDSYMBOLS;

    %SUPERSCRIPTS = map {$_->{from}{content} => $_->{to}{content}} @{$dataxml->{superscripts}{map}};
    %SUPERSCRIPTS_R = reverse %SUPERSCRIPTS;

    %CMDSUPERSCRIPTS = map {$_->{from}{content} => $_->{to}{content}} @{$dataxml->{cmdsuperscripts}{map}};
    %CMDSUPERSCRIPTS_R = reverse %CMDSUPERSCRIPTS;

    %GREEK = map {$_->{from}{content} => $_->{to}{content}} @{$dataxml->{greek}{map}};
    %GREEK_R = reverse %GREEK;

    $NEG_SYMB_RE = join('|', keys %NEGATEDSYMBOLS);
    $NEG_SYMB_RE    = qr{$NEG_SYMB_RE};
    $NEG_SYMB_RE_R = join('|', keys %NEGATEDSYMBOLS_R);
    $NEG_SYMB_RE_R    = qr{$NEG_SYMB_RE_R};

    $SUPER_RE = join('|', map { /[\+\-\)\(]/ ? '\\' . $_ : $_ } keys %SUPERSCRIPTS);
    $SUPER_RE = qr{$SUPER_RE};

    $SUPER_RE_R = join('|', map { /[\+\-\)\(]/ ? '\\' . $_ : $_ } keys %SUPERSCRIPTS_R);
    $SUPER_RE_R = qr{$SUPER_RE_R};

    $SUPERCMD_RE = join('|', keys %CMDSUPERSCRIPTS);
    $SUPERCMD_RE    = qr{$SUPERCMD_RE};
    $SUPERCMD_RE_R = join('|', keys %CMDSUPERSCRIPTS_R);
    $SUPERCMD_RE_R    = qr{$SUPERCMD_RE_R};

    $DINGS_RE_R = join('|', keys %DINGS_R);
    $DINGS_RE_R = qr{$DINGS_RE_R};
  }
}

=head2 latex_decode($text, @options)

Converts LaTeX macros in the $text to Unicode characters.

The function accepts a number of options:

    * normalize => $bool (default 1)
        whether the output string should be normalized with Unicode::Normalize

    * normalization => <normalization form> (default 'NFC')
        and if yes, the normalization form to use (see the Unicode::Normalize documentation)

    * strip_outer_braces => $bool (default 0)
        whether the outer curly braces around letters+combining marks should be
        stripped off. By default "fut{\\'e}" becomes fut{é}, to prevent something
        like '\\textuppercase{\\'e}' from becoming '\\textuppercaseé'. Setting this option to
        TRUE can be useful for instance when converting BibTeX files.

=cut

sub latex_decode {
    my $text      = shift;
    # Optimisation - if there are no macros, no point doing anything
    return $text unless $text =~ m/\\/;

    my %opts      = @_;
    my $norm      = exists $opts{normalize} ? $opts{normalize} : 1;
    my $norm_form = exists $opts{normalization} ? $opts{normalization} : 'NFC';
    my $strip_outer_braces =
      exists $opts{strip_outer_braces} ? $opts{strip_outer_braces} : 0;

    my %WORDMAC;

    if ( $scheme_d eq 'base' ) {
      %WORDMAC = (%WORDMACROS, %PUNCTUATION);
    }
    elsif ( $scheme_d eq 'full' ) {
      %WORDMAC = ( %WORDMACROS, %PUNCTUATION, %SYMBOLS, %GREEK );
      $text =~ s/\\not\\($NEG_SYMB_RE)/$NEGATEDSYMBOLS{$1}/ge;
      $text =~ s/\\textsuperscript{($SUPER_RE)}/$SUPERSCRIPTS{$1}/ge;
      $text =~ s/\\textsuperscript{\\($SUPERCMD_RE)}/$CMDSUPERSCRIPTS{$1}/ge;
      $text =~ s/\\ding{([2-9AF][0-9A-F])}/$DINGS{$1}/ge;
    }

    my $WORDMAC_RE = join( '|', keys %WORDMAC );

    $text =~ s/(\\[a-zA-Z]+)\\(\s+)/$1\{\}$2/g;    # \foo\ bar -> \foo{} bar
    $text =~ s/([^{]\\\w)([;,.:%])/$1\{\}$2/g;     #} Aaaa\o, -> Aaaa\o{},
    $text =~ s/(\\(?:$DIAC_RE|$ACCENTS_RE)){\\i}/$1\{i\}/g;
           # special cases such as '\={\i}' -> '\={i}' -> "i\x{304}"

    ## remove {} around macros that print one character
    ## by default we skip that, as it would break constructions like \foo{\i}
    if ($strip_outer_braces) {
        $text =~ s/ \{\\($WORDMAC_RE)\} / $WORDMAC{$1} /gxe;
    }
    $text =~ s/ \\($WORDMAC_RE)(?: \{\} | \s+ | \b) / $WORDMAC{$1} /gxe;

    $text =~ s/\\($ACCENTS_RE)\{(\p{L}\p{M}*)\}/$2 . $ACCENTS{$1}/ge;

    $text =~ s/\\($ACCENTS_RE)(\p{L}\p{M}*)/$2 . $ACCENTS{$1}/ge;

    $text =~ s/\\($DIAC_RE)\s*\{(\p{L}\p{M}*)\}/$2 . $DIAC{$1}/ge;

    $text =~ s/\\($DIAC_RE)\s+(\p{L}\p{M}*)/$2 . $DIAC{$1}/ge;

    $text =~ s/\\($ACCENTS_RE)\{(\p{L}\p{M}*)\}/$2 . $ACCENTS{$1}/ge;

    $text =~ s/\\($ACCENTS_RE)(\p{L}\p{M}*)/$2 . $ACCENTS{$1}/ge;

    $text =~ s/\\($DIAC_RE)\s*\{(\p{L}\p{M}*)\}/$2 . $DIAC{$1}/ge;

    $text =~ s/\\($DIAC_RE)\s+(\p{L}\p{M}*)/$2 . $DIAC{$1}/ge;

    ## remove {} around letter+combining mark(s)
    ## by default we skip that, as it would destroy constructions like \foo{\`e}
    if ($strip_outer_braces) {
        $text =~ s/{(\PM\pM+)}/$1/g;
    }

    if ($norm) {
        return Unicode::Normalize::normalize( $norm_form, $text );
    }
    else {
        return $text;
    }
}

=head2 latex_encode($text, @options)

Converts LaTeX character macros to UTF-8

=cut

sub latex_encode {
  my $text = shift;

  my $WORDMAC_RE_R = join( '|', keys %WORDMACROS_R );

  if ( $scheme_e eq 'full' ) {
    $text =~ s/($NEG_SYMB_RE_R)/"{\$\\not\\" . $NEGATEDSYMBOLS_R{$1} . '$}'/ge;
    $text =~ s/($SUPER_RE_R)/"\\textsuperscript{" . $SUPERSCRIPTS_R{$1} . "}"/ge;
    $text =~ s/($SUPERCMD_RE_R)/"\\textsuperscript{\\" . $CMDSUPERSCRIPTS_R{$1} . "}"/ge;
    $text =~ s/($DINGS_RE_R)/"\\ding{" . $DINGS_R{$1} . "}"/ge;
  }

  # Switch to NFD form for accents and diacritics. We need to be able to look for diacritics
  # etc. as separate characters which is impossible in NFC form.
  $text = NFD($text);

  # Accents
  # special case such as "i\x{304}" -> '\={\i}' - "i" needs the dot removing for accents
  $text =~ s/i($ACCENTS_RE_R)/"\\" . $ACCENTS_R{$1} . "{\\i}"/ge;

  $text =~ s/\{(\p{L}\p{M}*)\}($ACCENTS_RE_R)/"\\" . $ACCENTS_R{$2} . "{$1}"/ge;
  $text =~ s/(\p{L}\p{M}*)($ACCENTS_RE_R)/"\\" . $ACCENTS_R{$2} . "{$1}"/ge;

  # Diacritics
  $text =~ s{
              (\P{M})($DIAC_RE_R)($DIAC_RE_R)($DIAC_RE_R)
          }{
            "\\" . $DIAC_R{$4} . "{\\" . $DIAC_R{$3} . "{\\" . $DIAC_R{$2} . _get_diac_last_r($1,$2) . '}}'
          }gex;
  $text =~ s{
              (\P{M})($DIAC_RE_R)($DIAC_RE_R)
          }{
            "\\" . $DIAC_R{$3} . "{\\" . $DIAC_R{$2} . _get_diac_last_r($1,$2) . '}'
          }gex;
  $text =~ s{
              (\P{M})($DIAC_RE_R)
          }{
            "\\" . $DIAC_R{$2} . _get_diac_last_r($1,$2)
          }gex;

  # Switch back to NFC form for symbols
  $text = NFC($text);

  # General macros (excluding special encoding excludes)
  $text =~ s/($WORDMAC_RE_R)/"{\\" . $WORDMACROS_R{$1} . '}'/ge;

  # Only replace these if using "full" scheme
  if ($scheme_e eq 'full') {
    my %WORDMATHMAC_R = ( %PUNCTUATION_R, %SYMBOLS_R, %GREEK_R );
    my $WORDMATHMAC_RE_R = join( '|', keys %WORDMATHMAC_R );
    # Math mode macros (excluding special encoding excludes)
    $text =~ s/($WORDMATHMAC_RE_R)/"{\$\\" . $WORDMATHMAC_R{$1} . '$}'/ge;
  }

  return $text;
}


# Helper subroutines

sub _get_diac_last_r {
    my ($a,$b) = @_;
    if ( $b =~ /$ACCENTS_RE_R/) {
        return $a eq 'i' ? '{\\i}' : $a
    }
    else {
        return "{$a}"
    }
}

1;

__END__

=head1 AUTHOR

François Charette, C<< <firmicus at ankabut.net> >>
Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2012 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
