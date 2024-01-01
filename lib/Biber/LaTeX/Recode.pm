package Biber::LaTeX::Recode;
use v5.24;
use strict;
use warnings;
use parent qw(Exporter);
use Biber::Config;
use Digest::MD5 qw( md5_hex );
use Encode;
use File::Slurper;
use File::Spec;
use IPC::Cmd qw( can_run );
use IPC::Run3; # This works with PAR::Packer and Windows. IPC::Run doesn't
use Unicode::Normalize;
use List::AllUtils qw (first);
use Log::Log4perl qw(:no_extra_logdie_message);
use XML::LibXML::Simple;
use Carp;
use utf8;

our @EXPORT  = qw(latex_encode latex_decode);

my $logger = Log::Log4perl::get_logger('main');

=encoding utf-8

=head1 NAME

Biber::LaTeX::Recode - Encode/Decode chars to/from UTF-8/lacros in LaTeX

=head1 SYNOPSIS

    use Biber::LaTeX:Recode

    my $string = 'Muḥammad ibn Mūsā al-Khwārizmī';
    my $latex_string = latex_encode($string);
        # => 'Mu\d{h}ammad ibn M\=us\=a al-Khw\=arizm\={\i}'

    my $string = 'Mu\d{h}ammad ibn M\=us\=a al-Khw\=arizm\={\i}';
    my $utf8_string   = latex_decode($string);
        # => 'Muḥammad ibn Mūsā al-Khwārizmī'

=head1 DESCRIPTION

Allows conversion between Unicode chars and LaTeX macros.

=head1 GLOBAL OPTIONS

Possible values for the encoding/decoding set to use are 'null', 'base' and 'full'; default
value is 'base'.

null  => No conversion

base  => Most common macros and diacritics (sufficient for Western languages
         and common symbols)

full  => Also converts punctuation, larger range of diacritics and macros
         (e.g. for IPA, Latin Extended Additional, etc.), symbols, Greek letters,
         dingbats, negated symbols, and superscript characters and symbols ...

=cut

use vars qw( $remap_d $remap_e $remap_e_raw $set_d $set_e );

=head2 init_sets(<decode set>, <encode_set>)

  Initialise recoding sets. We can't do this on loading the module as we don't have the config
  information to do this yet

=cut

sub init_sets {
  shift; # class method
  ($set_d, $set_e) = @_;
  no autovivification;

  # Reset these, mostly for tests which call init_sets more than once
  $remap_d = {};
  $remap_e = {};
  $remap_e_raw = {};

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
  my $xml = Biber::Utils::slurp_switchr($mapdata)->$*;
  my $doc = XML::LibXML->load_xml(string => $xml);
  my $xpc = XML::LibXML::XPathContext->new($doc);

  my @types = qw(letters diacritics punctuation symbols negatedsymbols superscripts cmdsuperscripts dings greek);

  # Have to have separate loops for decode/recode or you can't have independent decode/recode
  # sets

  # Construct decode set
  foreach my $type (@types) {
    foreach my $maps ($xpc->findnodes("/texmap/maps[\@type='$type']")) {
      my @set = split(/\s*,\s*/, $maps->getAttribute('set'));
      next unless first {$set_d eq $_} @set;
      foreach my $map ($maps->findnodes('map')) {
        my $from = $map->findnodes('from')->shift();
        my $to = $map->findnodes('to')->shift();
        $remap_d->{$type}{map}{NFD($from->textContent())} = NFD($to->textContent());
      }
    }
    # Things we don't want to change when decoding as this breaks some things
    foreach my $d ($xpc->findnodes('/texmap/decode_exclude/char')) {
      delete($remap_d->{$type}{map}{NFD($d->textContent())});
    }
  }

  # Construct encode set
  foreach my $type (@types) {
    foreach my $maps ($xpc->findnodes("/texmap/maps[\@type='$type']")) {
      my @set = split(/\s*,\s*/, $maps->getAttribute('set'));
      next unless first {$set_e eq $_} @set;
      foreach my $map ($maps->findnodes('map')) {
        my $from = $map->findnodes('from')->shift();
        my $to = $map->findnodes('to')->shift();
        $remap_e->{$type}{map}{NFD($to->textContent())} = NFD($from->textContent());
      }
      # There are some duplicates in the data to handle preferred encodings.
      foreach my $map ($maps->findnodes('map[from[@preferred]]')) {
        my $from = $map->findnodes('from')->shift();
        my $to = $map->findnodes('to')->shift();
        $remap_e->{$type}{map}{NFD($to->textContent())} = NFD($from->textContent());
      }
      # Some things might need to be inserted as is rather than wrapped in some macro/braces
      foreach my $map ($maps->findnodes('map[from[@raw]]')) {
        my $from = $map->findnodes('from')->shift();
        my $to = $map->findnodes('to')->shift();
        $remap_e_raw->{NFD($to->textContent())} = 1;
      }

    }
    # Things we don't want to change when encoding as this would break LaTeX
    foreach my $e ($xpc->findnodes('/texmap/encode_exclude/char')) {
      delete($remap_e->{$type}{map}{NFD($e->textContent())});
    }
  }

  # Populate the decode regexps
  # sort by descending length of macro name to avoid shorter macros which are substrings
  # of longer ones damaging the longer ones
  foreach my $type (@types) {
    next unless exists $remap_d->{$type};
    $remap_d->{$type}{re} = join('|', map { /[\.\^\|\+\-\)\(]/ ? '\\' . $_ : $_ } sort {length($b) <=> length($a)} keys $remap_d->{$type}{map}->%*);
    $remap_d->{$type}{re} = qr|$remap_d->{$type}{re}|;
  }

  # Populate the encode regexps
  foreach my $type (@types) {
    next unless exists $remap_e->{$type};
    $remap_e->{$type}{re} = join('|', map { /[\.\^\|\+\-\)\(]/ ? '\\' . $_ : $_ } sort keys %{$remap_e->{$type}{map}});
    $remap_e->{$type}{re} = qr|$remap_e->{$type}{re}|;
  }
}

=head2 latex_decode($text, @options)

Converts LaTeX macros in the $text to Unicode characters.

The function accepts a number of options:

    * normalize => $bool (default 1)
        whether the output string should be normalized with Unicode::Normalize

    * normalization => <normalization form> (default 'NFD')
        and if yes, the normalization form to use (see the Unicode::Normalize documentation)

=cut
sub latex_decode {
    my $text = shift;

    if ($logger->is_trace()) {# performance tune
      $logger->trace("String before latex_decode() -> '$text'");
    }

    my %opts      = @_;
    my $norm      = exists $opts{normalize} ? $opts{normalize} : 1;
    my $norm_form = exists $opts{normalization} ? $opts{normalization} : 'NFD';

    # Deal with raw TeX \char macros.
    $text =~ s/\\char"(\p{ASCII_Hex_Digit}+)/"chr(0x$1)"/gee; # hex chars
    $text =~ s/\\char'(\d+)/"chr(0$1)"/gee;  # octal chars
    $text =~ s/\\char(\d+)/"chr($1)"/gee;    # decimal chars

    $text =~ s/(\\[a-zA-Z]+)\\(\s+)/$1\{\}$2/g;    # \foo\ bar -> \foo{} bar
    $text =~ s/([^{]\\\w)([;,.:%])/$1\{\}$2/g;     #} Aaaa\o,  -> Aaaa\o{},

    foreach my $type ('greek', 'dings', 'punctuation', 'symbols', 'negatedsymbols', 'superscripts', 'cmdsuperscripts', 'letters', 'diacritics') {
      my $map = $remap_d->{$type}{map};
      my $re = $remap_d->{$type}{re};
      next unless $re; # Might not be present depending on set

      if ($type eq 'negatedsymbols') {
        $text =~ s/\\not\\($re)/$map->{$1}/ge;
      }
      elsif ($type eq 'superscripts') {
        $text =~ s/\\textsuperscript\{($re)\}/$map->{$1}/ge;
      }
      elsif ($type eq 'cmdsuperscripts') {
        $text =~ s/\\textsuperscript\{\\($re)\}/$map->{$1}/ge;
      }
      elsif ($type eq 'dings') {
        $text =~ s/\\ding\{([2-9AF][0-9A-F])\}/$map->{$1}/ge;
      }
      elsif ($type eq 'letters') {
        $text =~ s/\\($re)(?:\{\}|\s+|\b)/$map->{$1}/ge;
      }
      elsif (first {$type eq $_} ('punctuation', 'symbols', 'greek')) {
        $text =~ s/\\($re)(?: \{\}|\s+|\b)/$map->{$1}/ge;
      }
      elsif ($type eq 'diacritics') {

        # Using Unicode INFORMATION SEPARATOR ONE/TWO
        my $bracemap = {'' => '',
                        '{' => "\x{1f}",
                        '}' => "\x{1e}"};

        # Hacky - specially protect {\X} which is a simple protection as in
        # TITLE = {Part {I}}
        # Can't do this using the seperators above as these are stripping around \X
        # later to avoid breaking capitliastion/kerning with spurious introduced/retained
        # braces
        # Using the VLB method from the link below, this is equivalent to:
        # $text =~ s/(?<!\\$re)\{(\X)\}/\x{f}$1\x{e}/g;
        $text =~ s/(?!(?=(?'a'[\s\S]*))(?'b'\\$re(?=\k'a'\z)|(?<=(?=x^|(?&b))[\s\S])))\{(\X)\}/\x{f}$3\x{e}/g;

        # Rename protecting braces so that they are not broken by RE manipulations
        $text =~ s/(\{?)\\($re)\s*\{(\pL\pM*)\}(\}?)/$bracemap->{$1} . $3 . $map->{$2} . $bracemap->{$4}/ge;
        $text =~ s/(\{)(\pL\pM*)(\})/$bracemap->{$1} . $2 . $bracemap->{$3}/ge;

        # Conditional regexp with code-block condition
        # non letter macros for diacritics (e.g. \=) can be followed by any letter
        # but letter diacritic macros (e.g \c) can't (\cS)
        #
        # If the RE for the macro doesn't end with a basic LaTeX macro letter (\=), then
        #   next char can be any letter (\=d)
        # Else if it did end with a normal LaTeX macro letter (\c), then
        #   If this was followed by a space (\c )
        #     Any letter is allowed after the space (\c S)
        #   Else
        #     Only a non basic LaTeX letter is allowed (\c-)
        $text =~ s/\\# slash
                   ($re)# the diacritic
                   (\s*)# optional space
                   (# capture paren
                     (?(?{$1 !~ m:[A-Za-z]$:})# code block condition (is not a letter?)
                       \pL # yes pattern
                     | # no pattern
                       (?(?{$2}) # code block condition (space matched earlier after diacritic?)
                         \pL # yes pattern
                       | # no pattern
                         [^A-Za-z]
                       ) # close conditional
                     ) # close conditional
                     \pM* # optional marks
                   ) # capture paren
                   /$3 . $map->{$1}/gxe;
      }
    }

    if ($logger->is_trace()) {# performance tune
      $logger->trace("String in latex_decode() before brace elimination now -> '$text'");
    }

    # Now remove braces around single letters (which the replace above can
    # result in). Things like '{á}' can break kerning/brace protection. We
    # can't do this in the RE above as we can't determine if the braces are
    # wrapping a phrase because this match is on an entire field string. So
    # we can't in one step tell the difference between:
    #
    # author = {Andr\'e}
    # and
    # author = {Andr\'{e}}
    #
    # when this is part of a (much) larger string
    #
    # We don't want to do this if it would result in a broken macro name like with
    # \textupper{é}
    # or
    # \frac{a}{b}
    #
    # This horrible RE is the very clever variable-look-behind implementation from:
    # http://www.drregex.com/2019/02/variable-length-lookbehinds-actually.html
    # Perl 5.30 has limited (<255 chars) VLB but it doesn't work here as it can't be determined
    # that it's <255 chars by the parser
    $text =~ s/(?!(?=(?'a'[\s\S]*))(?'b'\\\pL+(?:\{[^{]+\})*(?=\k'a'\z)|(?<=(?=x^|(?&b))[\s\S])))[{\x{1f}](\X)[}\x{1e}]/$3/g;

    # Put back any brace markers left after doing the brace elimination as
    # we only want to eliminate braces introduced as part of decoding, not
    # explicit braces in the data
    $text =~ s/\x{1f}/{/g;
    $text =~ s/\x{1e}/}/g;
    $text =~ s/\x{f}/{/g;
    $text =~ s/\x{e}/}/g;

    # SPECIAL CASES
    # These are special cases that people/LaTeX complains about
    # Replace decomposed i+' diacritic with single grapheme as the decomposed form confuses LaTeX sometimes
    # NFC() does not do this as letter+diacritic is often a valid composed form
    $text =~ s/ı́/í/g;

    if ($logger->is_trace()) {# performance tune
      $logger->trace("String in latex_decode() now -> '$text'");
    }

    if ($norm) {
      return Unicode::Normalize::normalize($norm_form, $text);
    }
    else {
      return $text;
    }
}

=head2 latex_encode($text, @options)

Converts UTF-8 to LaTeX

=cut

sub latex_encode {
  my $text = shift;

  # Optimisation - if virtual null set was specified, do nothing
  return $text if $set_e eq 'null';

  foreach my $type ('greek', 'dings', 'negatedsymbols', 'superscripts', 'cmdsuperscripts', 'diacritics', 'letters', 'punctuation', 'symbols') {
    my $map = $remap_e->{$type}{map};
    my $re = $remap_e->{$type}{re};
    next unless $re; # Might not be present depending on set

    if ($type eq 'negatedsymbols') {
      $text =~ s/($re)/"{\$\\not\\" . $map->{$1} . '$}'/ge;
    }
    elsif ($type eq 'superscripts') {
      $text =~ s/($re)/'\textsuperscript{' . $map->{$1} . '}'/ge;
    }
    elsif ($type eq 'cmdsuperscripts') {
      $text =~ s/($re)/"\\textsuperscript{\\" . $map->{$1} . "}"/ge;
    }
    elsif ($type eq 'dings') {
      $text =~ s/($re)/'\ding{' . $map->{$1} . '}'/ge;
    }
    elsif ($type eq 'letters') {
      # General macros (excluding special encoding excludes)
      $text =~ s/($re)/($remap_e_raw->{$1} ? '' : "\\") . $map->{$1} . ($remap_e_raw->{$1} ? '' : '{}')/ge;
    }
    elsif (first {$type eq $_}  ('punctuation', 'symbols', 'greek')) {
      $text =~ s/($re)/_wrap($1,$map,$remap_e_raw)/ge;
    }
    elsif ($type eq 'diacritics') {
      # special case such as "i\x{304}" -> '\={\i}' -> "i" needs the dot removing for accents
      $text =~ s/i($re)/"\\" . $map->{$1} . '{\i}'/ge;

      $text =~ s/\{(\pL\pM*)\}($re)/"\\" . $map->{$2} . "{$1}"/ge;
      $text =~ s/(\pL\pM*)($re)/"\\" . $map->{$2} . "{$1}"/ge;

      $text =~ s{
                  (\PM)($re)($re)($re)
              }{
                "\\" . $map->{$4} . "{\\" . $map->{$3} . "{\\" . $map->{$2} . "{$1}" . '}}'
              }gex;
      $text =~ s{
                  (\PM)($re)($re)
              }{
                "\\" . $map->{$3} . "{\\" . $map->{$2} . "{$1}" . '}'
              }gex;
      $text =~ s{
                  (\PM)($re)
              }{
                "\\" . $map->{$2} . "{$1}"
              }gex;
    }
  }

  sub _wrap {
    my ($s, $map, $remap_e_raw) = @_;
    if ($map->{$s} =~ m/^(?:text|guil)/) {
      "\\"  . $map->{$s} . '{}';
    }
    elsif ($remap_e_raw->{$s}) {
      $map->{$s};
    }
    else {
      "{\$\\" .  $map->{$s} . '$}';
    }
  }

  return $text;
}

1;

__END__

=head1 AUTHOR

Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our Github tracker at
L<https://github.com/plk/biber/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2012 François Charette and Philip Kime, all rights reserved.
Copyright 2012-2024 Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
