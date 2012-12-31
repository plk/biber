package Biber::LaTeX::Recode;
use 5.014000;
use strict;
use warnings;
use base qw(Exporter);
use Biber::Config;
use IPC::Cmd qw( can_run );
use IPC::Run3; # This works with PAR::Packer and Windows. IPC::Run doesn't
use Unicode::Normalize;
use List::AllUtils qw (first);
use Log::Log4perl qw(:no_extra_logdie_message);
use XML::LibXML::Simple;
use Carp;

our @EXPORT  = qw(latex_encode latex_decode);

my $logger = Log::Log4perl::get_logger('main');

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

use vars qw( $remaps $r_remaps $scheme_d $scheme_e );

=head2 init_schemes(<decode scheme>, <encode_scheme>)

  Initialise schemes. We can't do this on loading the module as we don't have the config
  information to do this yet

=cut

sub init_schemes {
  shift; # class method
  ($scheme_d, $scheme_e) = @_;

  my $mapdata;
  # User-defined recode data file
  if (my $rdata = Biber::Config->getoption('recodedata')) {
    my $err;
    if ( can_run('kpsewhich') ) {
      run3 [ 'kpsewhich', $rdata ], \undef, \$mapdata, \$err, { return_if_system_error => 1};
      if ($? == -1) {
        biber_error("Error running kpsewhich to look for output_safechars data file: $err");
      }

      chomp $mapdata;
      $mapdata =~ s/\cM\z//xms; # kpsewhich in cygwin sometimes returns ^M at the end
      $mapdata = undef unless $mapdata; # sanitise just in case it's an empty string
    }
    else {
      biber_error("Can't run kpsewhich to look for output_safechars data file: $err");
    }
    $logger->info("Using user-defined recode data file '$mapdata'");
  }
  else {
    # we assume that the data file is in the same dir as the module
    (my $vol, my $data_path, undef) = File::Spec->splitpath( $INC{'Biber/LaTeX/Recode.pm'} );

    # Deal with the strange world of Par::Packer paths, see similar code in Biber.pm

    if ($data_path =~ m|/par\-| and $data_path !~ m|/inc|) { # a mangled PAR @INC path
      $mapdata = File::Spec->catpath($vol, "$data_path/inc/lib/Biber/LaTeX/recode_data.xml");
    }
    else {
      $mapdata = File::Spec->catpath($vol, $data_path, 'recode_data.xml');
    }
  }

  # Read driver config file
  my $dataxml = XML::LibXML::Simple::XMLin($mapdata,
                                           'ForceContent' => 1,
                                           'ForceArray' => [
                                                            qr/\Amaps\z/,
                                                            qr/\Amap\z/,
                                                            qr/\Achar\z/,
                                                           ]
                                                           );
  foreach my $map (@{$dataxml->{maps}}) {
    my @set = split(/\s*,\s*/, $map->{set});
    my $type = $map->{type};
    my $map = $map->{map};
    next unless $scheme_d ~~ @set or $scheme_e ~~ @set;
    foreach my $set (@set) {
      $remaps->{$set}{$type}{map} = { map {$_->{from}{content} => $_->{to}{content}} @$map };
      $r_remaps->{$set}{$type}{map} = { reverse %{$remaps->{$set}{$type}{map}} };
      # There are some duplicates in the hash. reverse() doesn't predictably deal with this.
      # Force specific prefered reverse mapping to override unpredictable reverse()
      # We still use reverse() and just correct it afterwards as it's fast
      foreach my $r (@$map) {
        next unless exists($r->{from}{preferred});
        $r_remaps->{$set}{$type}{map}{$r->{to}{content}} = $r->{from}{content};
      }
      # Things we don't want to change when encoding as this would break LaTeX
      foreach my $e (map {$_->{content}} @{$dataxml->{encode_exclude}{char}}) {
        delete($r_remaps->{$set}{$type}{map}->{$e});
      }

      # Now populate the regexps
      if ($type eq 'accents') {
        $remaps->{$set}{$type}{re} = '[' . join('', keys %{$remaps->{$set}{$type}{map}}) . ']';
        $remaps->{$set}{$type}{re} = qr/$remaps->{$set}{$type}{re}/;
        $r_remaps->{$set}{$type}{re} = '[' . join('', keys %{$r_remaps->{$set}{$type}{map}}) . ']';
        $r_remaps->{$set}{$type}{re} = qr/$r_remaps->{$set}{$type}{re}/;
      }
      elsif ($type eq 'superscripts') {
        $remaps->{$set}{$type}{re} = join('|', map { /[\+\-\)\(]/ ? '\\' . $_ : $_ } keys %{$remaps->{$set}{$type}{map}});
        $remaps->{$set}{$type}{re} = qr|$remaps->{$set}{$type}{re}|;
        $r_remaps->{$set}{$type}{re} = join('|', map { /[\+\-\)\(]/ ? '\\' . $_ : $_ } keys %{$r_remaps->{$set}{$type}{map}});
        $r_remaps->{$set}{$type}{re} = qr|$r_remaps->{$set}{$type}{re}|;
      }
      else {
        $remaps->{$set}{$type}{re} = join('|', keys %{$remaps->{$set}{$type}{map}});
        $remaps->{$set}{$type}{re} = qr|$remaps->{$set}{$type}{re}|;
        $r_remaps->{$set}{$type}{re} = join('|', keys %{$r_remaps->{$set}{$type}{map}});
        $r_remaps->{$set}{$type}{re} = qr|$r_remaps->{$set}{$type}{re}|;
      }
    }
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

    $logger->trace("String before latex_decode() -> '$text'");

    my %opts      = @_;
    my $norm      = exists $opts{normalize} ? $opts{normalize} : 1;
    my $norm_form = exists $opts{normalization} ? $opts{normalization} : 'NFC';
    my $strip_outer_braces =
      exists $opts{strip_outer_braces} ? $opts{strip_outer_braces} : 0;

    # Deal with raw TeX \char macros.
    $text =~ s/\{(\\char['"]*[[:xdigit:]]+)\}/$1/g; # strip braces around \char
    $text =~ s/\\char"([[:xdigit:]]+)/"chr(0x$1)"/gee; # hex chars
    $text =~ s/\\char'(\d+)/"chr(0$1)"/gee;  # octal chars
    $text =~ s/\\char(\d+)/"chr($1)"/gee;    # decimal chars

    my $mainmap;

    foreach my $type (keys %{$remaps->{$scheme_d}}) {
      my $map = $remaps->{$scheme_d}{$type}{map};
      my $re = $remaps->{$scheme_d}{$type}{re};
      given ($type) {
        when ('negatedsymbols') {
          $text =~ s/\\not\\($re)/$map->{$1}/ge if $re;
        }
        when ('superscripts') {
          $text =~ s/\\textsuperscript{($re)}/$map->{$1}/ge if $re;
        }
        when ('cmdsuperscripts') {
          $text =~ s/\\textsuperscript{\\($re)}/$map->{$1}/ge if $re;
        }
        when ('dings') {
          $text =~ s/\\ding{([2-9AF][0-9A-F])}/$map->{$1}/ge;
        }
      }
    }

    $text =~ s/(\\[a-zA-Z]+)\\(\s+)/$1\{\}$2/g;    # \foo\ bar -> \foo{} bar
    $text =~ s/([^{]\\\w)([;,.:%])/$1\{\}$2/g;     #} Aaaa\o, -> Aaaa\o{},
    my $d_re = $remaps->{$scheme_d}{diacritics}{re} || '';
    my $a_re = $remaps->{$scheme_d}{accents}{re} || '';

    # special cases such as '\={\i}' -> '\={i}' -> "i\x{304}"
    $text =~ s/(\\(?:$d_re|$a_re)){\\i}/$1\{i\}/g;

    foreach my $type (keys %{$remaps->{$scheme_d}}) {
      my $map = $remaps->{$scheme_d}{$type}{map};
      my $re = $remaps->{$scheme_d}{$type}{re};
      next unless $re;

      if ($type ~~ ['wordmacros', 'punctuation', 'symbols', 'greek']) {
        ## remove {} around macros that print one character
        ## by default we skip that, as it would break constructions like \foo{\i}
        if ($strip_outer_braces) {
          $text =~ s/ \{\\($re)\} / $map->{$1} /gxe;
        }
        $text =~ s/\\($re)(?: \{\} | \s+ | \b) / $map->{$1} /gxe;
      }
      if ($type eq 'accents') {
        $text =~ s/\\($re)\{(\p{L}\p{M}*)\}/$2 . $map->{$1}/ge;
        $text =~ s/\\($re)(\p{L}\p{M}*)/$2 . $map->{$1}/ge;
        $text =~ s/\\($re)\{(\p{L}\p{M}*)\}/$2 . $map->{$1}/ge;
        $text =~ s/\\($re)(\p{L}\p{M}*)/$2 . $map->{$1}/ge;
      }
      if ($type eq 'diacritics') {
        $text =~ s/\\($re)\s*\{(\p{L}\p{M}*)\}/$2 . $map->{$1}/ge;
        $text =~ s/\\($re)\s+(\p{L}\p{M}*)/$2 . $map->{$1}/ge;
        $text =~ s/\\($re)\s*\{(\p{L}\p{M}*)\}/$2 . $map->{$1}/ge;
        $text =~ s/\\($re)\s+(\p{L}\p{M}*)/$2 . $map->{$1}/ge;
      }
    }

    ## remove {} around letter+combining mark(s)
    ## by default we skip that, as it would destroy constructions like \foo{\`e}
    if ($strip_outer_braces) {
        $text =~ s/{(\PM\pM+)}/$1/g;
    }

    $logger->trace("String in latex_decode() now -> '$text'");

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

  foreach my $type (keys %{$r_remaps->{$scheme_e}}) {
    my $map = $r_remaps->{$scheme_e}{$type}{map};
    my $re = $r_remaps->{$scheme_e}{$type}{re};
    given ($type) {
      when ('negatedsymbols') {
        $text =~ s/($re)/"{\$\\not\\" . $map->{$1} . '$}'/ge;
      }
      when ('superscripts') {
        $text =~ s/($re)/"\\textsuperscript{" . $map->{$1} . "}"/ge;
      }
      when ('cmdsuperscripts') {
        $text =~ s/($re)/"\\textsuperscript{\\" . $map->{$1} . "}"/ge;
      }
      when ('dings') {
        $text =~ s/($re)/"\\ding{" . $map->{$1} . "}"/ge;
      }
    }
  }

  # Switch to NFD form for accents and diacritics. We need to be able to look for diacritics
  # etc. as separate characters which is impossible in NFC form.
  $text = NFD($text);

  foreach my $type (keys %{$r_remaps->{$scheme_e}}) {
    my $map = $r_remaps->{$scheme_e}{$type}{map};
    my $re = $r_remaps->{$scheme_e}{$type}{re};
    if ($type eq 'accents') {
      # Accents
      # special case such as "i\x{304}" -> '\={\i}' - "i" needs the dot removing for accents
      $text =~ s/i($re)/"\\" . $map->{$1} . "{\\i}"/ge;

      $text =~ s/\{(\p{L}\p{M}*)\}($re)/"\\" . $map->{$2} . "{$1}"/ge;
      $text =~ s/(\p{L}\p{M}*)($re)/"\\" . $map->{$2} . "{$1}"/ge;

    }
    if ($type eq 'diacritics') {
      # Diacritics
      $text =~ s{
                  (\P{M})($re)($re)($re)
              }{
                "\\" . $map->{$4} . "{\\" . $map->{$3} . "{\\" . $map->{$2} . _get_diac_last_r($1,$2) . '}}'
              }gex;
      $text =~ s{
                  (\P{M})($re)($re)
              }{
                "\\" . $map->{$3} . "{\\" . $map->{$2} . _get_diac_last_r($1,$2) . '}'
              }gex;
      $text =~ s{
                  (\P{M})($re)
              }{
                "\\" . $map->{$2} . _get_diac_last_r($1,$2)
              }gex;
    }
  }

  # Switch back to NFC form for symbols
  $text = NFC($text);

  foreach my $type (keys %{$r_remaps->{$scheme_e}}) {
    my $map = $r_remaps->{$scheme_e}{$type}{map};
    my $re = $r_remaps->{$scheme_e}{$type}{re};
    if ($type eq 'wordmacros') {
      # General macros (excluding special encoding excludes)
      $text =~ s/($re)/"{\\" . $map->{$1} . '}'/ge;
    }
    if ($type ~~ ['punctuation', 'symbols', 'greek']) {
      # Math mode macros (excluding special encoding excludes)
      $text =~ s/($re)/"{\$\\" . $map->{$1} . '$}'/ge;
    }
  }

  return $text;
}


# Helper subroutines

sub _get_diac_last_r {
    my ($a,$b) = @_;
    my $re = $r_remaps->{$scheme_e}{accents}{re};

    if ( $b =~ /$re/) {
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

Copyright 2009-2013 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
