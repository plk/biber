package Biber::LaTeX::Recode;
#use feature 'unicode_strings';
use strict;
use warnings;
no warnings 'utf8';
use Unicode::Normalize;
use Biber::LaTeX::Recode::Data;
use Exporter;
use base qw(Exporter);
use Carp;

our $VERSION = '0.1';
our @EXPORT  = qw(latex_encode latex_decode);

=encoding utf-8

=head1 NAME

Biber::LaTeX::Recode - Encode/Decode chars to/from UTF-8/lacros in LaTeX

=head1 VERSION

Version 0.01

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

The decoding scheme can be set with

    $Biber::LaTeX::Recode::DefaultScheme = '<name>';

Possible values are 'base', 'extra' and 'full'; default value is 'extra'.

base  => Most common macros and diacritics (sufficient for Western languages
         and common symbols)

extra => Also converts punctuation, larger range of diacritics and macros
         (e.g. for IPA, Latin Extended Additional, etc.)

full  => Also converts symbols, Greek letters, dingbats, negated symbols, and
         superscript characters and symbols ...

=cut


our $DefaultScheme_d = 'extra';
our $DefaultScheme_e = 'extra';


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
        like '\\textuppercase{\\'e}' to become '\\textuppercaseé'. Setting this option to
        TRUE can be useful for instance when converting BibTeX files.

=cut

sub latex_decode {
    my $text      = shift;
    my %opts      = @_;
    my $norm      = exists $opts{normalize} ? $opts{normalize} : 1;
    my $norm_form = exists $opts{normalization} ? $opts{normalization} : 'NFC';
    my $scheme    = exists $opts{scheme} ? $opts{scheme} : $DefaultScheme_d;
    croak "invalid scheme name '$scheme'"
        unless ( $scheme eq 'full' or $scheme eq 'base' or $scheme eq 'extra' );
    my $strip_outer_braces =
      exists $opts{strip_outer_braces} ? $opts{strip_outer_braces} : 0;

    my %DIAC    = _get_diac($scheme);
    my ($WORDMAC, $WORDMAC_RE) = _get_mac($scheme);

    my $DIAC_RE;
    if ( $scheme eq 'base' ) {
        $DIAC_RE = $DIAC_RE_BASE;
    }
    else {
        $DIAC_RE = $DIAC_RE_EXTRA;
    }

    if ( $scheme eq 'full' ) {
        $text =~ s/\\not\\($NEG_SYMB_RE)/$NEGATEDSYMBOLS{$1}/ge;
        $text =~ s/\\textsuperscript{($SUPER_RE)}/$SUPERSCRIPTS{$1}/ge;
        $text =~ s/\\textsuperscript{\\($SUPERCMD_RE)}/$CMDSUPERSCRIPTS{$1}/ge;
        $text =~ s/\\dings{([2-9AF][0-9A-F])}/$DINGS{$1}/ge;
    }

    $text =~ s/(\\[a-zA-Z]+)\\(\s+)/$1\{\}$2/g;    # \foo\ bar -> \foo{} bar
    $text =~ s/([^{]\\\w)([;,.:%])/$1\{\}$2/g;     #} Aaaa\o, -> Aaaa\o{},
    $text =~ s/(\\(?:$DIAC_RE_BASE|$ACCENTS_RE)){\\i}/$1\{i\}/g;
           # special cases such as '\={\i}' -> '\={i}' -> "i\x{304}"

    ## remove {} around macros that print one character
    ## by default we skip that, as it would break constructions like \foo{\i}
    if ($strip_outer_braces) {
        $text =~ s/ \{\\($WORDMAC_RE)\} / $WORDMAC->{$1} /gxe;
    }
    $text =~ s/ \\($WORDMAC_RE)(?: \{\} | \s+ | \b) / $WORDMAC->{$1} /gxe;

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
  my $text = NFD(shift);
  my %opts = @_;
  my $scheme    = exists $opts{scheme} ? $opts{scheme} : $DefaultScheme_e;
  croak "invalid scheme name '$scheme'"
    unless ( $scheme eq 'full' or $scheme eq 'base' or $scheme eq 'extra' );
  # choose the diacritics set to use
  my %DIAC_R = _get_diac_r($scheme);
  my $DIAC_RE_R;
  if ( $scheme eq 'base' ) {
    $DIAC_RE_R = $DIAC_RE_BASE_R;
  }
  else {
    $DIAC_RE_R = $DIAC_RE_EXTRA_R;
  }

  # choose the macro set to use
  my ($WORDMAC_R, $WORDMAC_RE_R) = _get_mac_r($scheme);

  if ( $scheme eq 'full' ) {
    $text =~ s/($NEG_SYMB_RE_R)/"\\not\\" . $NEGATEDSYMBOLS_R{$1}/ge;
    $text =~ s/($SUPER_RE_R)/"\\textsuperscript{" . $SUPERSCRIPTS_R{$1} . "}"/ge;
    $text =~ s/($SUPERCMD_RE_R)/"\\textsuperscript{\\" . $CMDSUPERSCRIPTS_R{$1} . "}"/ge;
    $text =~ s/($DINGS_RE_R)/"\\dings{" . $DINGS_R{$1} . "}"/ge;
  }

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

  # General macros (excluding special encoding excludes)
  $text =~ s/($WORDMAC_RE_R)/"{\\" . $WORDMAC_R->{$1} . '}'/ge;

  # Only replace these if using "full" scheme
  if ($scheme eq 'full') {
    my %WORDMATHMAC_R = ( %PUNCTUATION_R, %SYMBOLS_R, %GREEK_R );
    my $WORDMATHMAC_RE_R = join( '|', sort { length $b <=> length $a } keys %WORDMATHMAC_R );
    # Math mode macros (excluding special encoding excludes)
    $text =~ s/($WORDMATHMAC_RE_R)/"{\$\\" . $WORDMATHMAC_R{$1} . '$}'/ge;
  }

  return $text;
}


# Helper subroutines

sub _get_diac {
    my $scheme = shift;
    if ( $scheme eq 'base' ) {
        return %DIACRITICS;
    }
    else {
        return ( %DIACRITICS, %DIACRITICSEXTRA );
    }
}

sub _get_diac_r {
    my $scheme = shift;
    if ( $scheme eq 'base' ) {
        return %DIACRITICS_R;
    }
    else {
        return ( %DIACRITICS_R, %DIACRITICSEXTRA_R);
    }
}


sub _get_mac {
    my $scheme = shift;
    my %macs;
    if ( $scheme eq 'base' ) {
         %macs = %WORDMACROS;
    }
    elsif ( $scheme eq 'full' ) {
        %macs = ( %WORDMACROS, %WORDMACROSEXTRA, %PUNCTUATION, %SYMBOLS,
            %GREEK );
    }
    else {
        %macs = ( %WORDMACROS, %WORDMACROSEXTRA, %PUNCTUATION );
    }
    return (\%macs, join( '|', sort { length $b <=> length $a } keys %macs ));
}

sub _get_mac_r {
    my $scheme = shift;
    my %macs;
    if ( $scheme eq 'base' ) {
         %macs = %WORDMACROS_R;
    }
    elsif ( $scheme eq 'full' ) {
        %macs = ( %WORDMACROS_R, %WORDMACROSEXTRA_R );
    }
    else {
        %macs = ( %WORDMACROS_R, %WORDMACROSEXTRA_R );
    }

    # don't encode things which latex needs like braces etc.
    foreach my $e (keys %ENCODE_EXCLUDE_R) {
      delete($macs{$e});
    }
    return (\%macs, join( '|', sort { length $b <=> length $a } keys %macs ));
}


sub _get_diac_last_r {
    my ($a,$b) = @_;
    if ( $b =~ /$ACCENTS_RE_R/) {
        return $a eq 'i' ? '{\\i}' : $a
    }
    else {
        return "{$a}"
    }
}


=head1 AUTHOR

François Charette, C<< <firmicus@cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-latex-decode at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=LaTeX-Decode>.  I will be
notified, and then you'll automatically be notified of progress on your bug as
I make changes.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2010 François Charette, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

1;

# vim: set tabstop=4 shiftwidth=4 expandtab:

