package Biber::LaTeX::Recode::Data;
use feature ':5.10';
#use 5.014001;
use strict;
use warnings;
use base qw(Exporter);
use List::AllUtils qw (first);
use XML::LibXML::Simple;

my $data;
# we assume that the data file is in the same dir as the module
(my $vol, my $data_path, undef) = File::Spec->splitpath( $INC{'Biber/LaTeX/Recode/Data.pm'} );

# Deal with the strange world of Par::Packer paths, see similar code in Biber.pm
my $mapdata;
if ($data_path =~ m|/par\-| and $data_path !~ m|/inc|) { # a mangled PAR @INC path
  $mapdata = File::Spec->catpath($vol, "$data_path/inc/lib/Biber/LaTeX/Recode/data.xml");
}
else {
  $mapdata = File::Spec->catpath($vol, $data_path, 'data.xml');
}

# Read driver config file
my $dataxml = XML::LibXML::Simple::XMLin($mapdata, 'ForceContent' => 1);

our @EXPORT    = qw[ %ACCENTS           %ACCENTS_R
                     %WORDMACROS        %WORDMACROS_R
                     %DIACRITICS        %DIACRITICS_R
                     %WORDMACROSEXTRA   %WORDMACROSEXTRA_R
                     %DIACRITICSEXTRA   %DIACRITICSEXTRA_R
                     %PUNCTUATION       %PUNCTUATION_R
                     %NEGATEDSYMBOLS    %NEGATEDSYMBOLS_R
                     %SUPERSCRIPTS      %SUPERSCRIPTS_R
                     %SYMBOLS           %SYMBOLS_R
                     %CMDSUPERSCRIPTS   %CMDSUPERSCRIPTS_R
                     %DINGS             %DINGS_R
                     %GREEK             %GREEK_R
                                        %ENCODE_EXCLUDE_R
                     $ACCENTS_RE        $ACCENTS_RE_R
                     $DIAC_RE_BASE      $DIAC_RE_BASE_R
                     $DIAC_RE_EXTRA     $DIAC_RE_EXTRA_R
                     $NEG_SYMB_RE       $NEG_SYMB_RE_R
                     $SUPER_RE          $SUPER_RE_R
                     $SUPERCMD_RE       $SUPERCMD_RE_R
                                        $DINGS_RE_R
                  ];

our %ACCENTS = map {$_->{from}{content} => $_->{to}{content}} @{$dataxml->{accents}{map}};
our %ACCENTS_R = reverse %ACCENTS;

my $basewordmacros = first {$_->{set} eq 'base'} @{$dataxml->{wordmacros}};
our %WORDMACROS = map {$_->{from}{content} => $_->{to}{content}} @{$basewordmacros->{map}};
our %WORDMACROS_R = reverse %WORDMACROS;
# There are some duplicates in the hash. reverse() doesn't predictably deal with this.
# Force specific prefered reverse mapping to override unpredictable reverse()
# We still use reverse() and just correct it afterwards as it's fast
foreach my $r (@{$basewordmacros->{map}}) {
  next unless exists($r->{from}{preferred});
  $WORDMACROS_R{$r->{to}{content}} = $r->{from}{content};
}

my $extrawordmacros = first {$_->{set} eq 'extra'} @{$dataxml->{wordmacros}};
our %WORDMACROSEXTRA = map {$_->{from}{content} => $_->{to}{content}} @{$extrawordmacros->{map}};
our %WORDMACROSEXTRA_R = reverse %WORDMACROSEXTRA;
# There are some duplicates in the hash. reverse() doesn't predictably deal with this.
# Force specific prefered reverse mapping to override unpredictable reverse()
# We still use reverse() and just correct it afterwards as it's fast
foreach my $r (@{$extrawordmacros->{map}}) {
  next unless exists($r->{from}{preferred});
  $WORDMACROSEXTRA_R{$r->{to}{content}} = $r->{from}{content};
}

my $basediac = first {$_->{set} eq 'base'} @{$dataxml->{diacritics}};
our %DIACRITICS = map {$_->{from}{content} => $_->{to}{content}} @{$basediac->{map}};
our %DIACRITICS_R = reverse %DIACRITICS;
# There are some duplicates in the hash. reverse() doesn't predictably deal with this.
# Force specific prefered reverse mapping to override unpredictable reverse()
# We still use reverse() and just correct it afterwards as it's fast
foreach my $r (@{$basediac->{map}}) {
  next unless exists($r->{from}{preferred});
  $DIACRITICS_R{$r->{to}{content}} = $r->{from}{content};
}

my $extradiac = first {$_->{set} eq 'extra'} @{$dataxml->{diacritics}};
our %DIACRITICSEXTRA = map {$_->{from}{content} => $_->{to}{content}} @{$extradiac->{map}};
our %DIACRITICSEXTRA_R = reverse %DIACRITICSEXTRA;
# There are some duplicates in the hash. reverse() doesn't predictably deal with this.
# Force specific prefered reverse mapping to override unpredictable reverse()
# We still use reverse() and just correct it afterwards as it's fast
foreach my $r (@{$extradiac->{map}}) {
  next unless exists($r->{from}{preferred});
  $DIACRITICSEXTRA_R{$r->{to}{content}} = $r->{from}{content};
}

our %PUNCTUATION = map {$_->{from}{content} => $_->{to}{content}} @{$dataxml->{punctuation}{map}};
our %PUNCTUATION_R = reverse %PUNCTUATION;

our %NEGATEDSYMBOLS = map {$_->{from}{content} => $_->{to}{content}} @{$dataxml->{negatedsymbols}{map}};
our %NEGATEDSYMBOLS_R = reverse %NEGATEDSYMBOLS;

our %SUPERSCRIPTS = map {$_->{from}{content} => $_->{to}{content}} @{$dataxml->{superscripts}{map}};
our %SUPERSCRIPTS_R = reverse %SUPERSCRIPTS;

our %CMDSUPERSCRIPTS = map {$_->{from}{content} => $_->{to}{content}} @{$dataxml->{cmdsuperscripts}{map}};
our %CMDSUPERSCRIPTS_R = reverse %CMDSUPERSCRIPTS;

our %SYMBOLS = map {$_->{from}{content} => $_->{to}{content}} @{$dataxml->{symbols}{map}};
our %SYMBOLS_R = reverse %SYMBOLS;
# There are some duplicates in the hash. reverse() doesn't predictably deal with this.
# Force specific prefered reverse mapping to override unpredictable reverse()
# We still use reverse() and just correct it afterwards as it's fast
foreach my $r (@{$dataxml->{symbols}{map}}) {
  next unless exists($r->{from}{preferred});
  $SYMBOLS_R{$r->{to}{content}} = $r->{from}{content};
}

our %DINGS = map {$_->{from}{content} => $_->{to}{content}} @{$dataxml->{dings}{map}};
our %DINGS_R = reverse %DINGS;

our %GREEK = map {$_->{from}{content} => $_->{to}{content}} @{$dataxml->{greek}{map}};
our %GREEK_R = reverse %GREEK;

# Things we don't want to change when encoding as this would break LaTeX
our %ENCODE_EXCLUDE_R = map {$_->{content} => 1} @{$dataxml->{encode_exclude}{char}};




our $ACCENTS_RE = qr{[\^\.`'"~=]};
our $ACCENTS_RE_R = qr{[\x{300}-\x{304}\x{307}\x{308}]};

our $DIAC_RE_BASE  = join('|', keys %DIACRITICS);
$DIAC_RE_BASE = qr{$DIAC_RE_BASE};
our $DIAC_RE_BASE_R  = join('|', keys %DIACRITICS_R);
$DIAC_RE_BASE_R = qr{$DIAC_RE_BASE_R};

our $DIAC_RE_EXTRA = join('|', sort {length $b <=> length $a} keys %DIACRITICSEXTRA);
$DIAC_RE_EXTRA = qr{$DIAC_RE_EXTRA|$DIAC_RE_BASE};
our $DIAC_RE_EXTRA_R = join('|', sort {length $b <=> length $a} keys %DIACRITICSEXTRA_R);
$DIAC_RE_EXTRA_R = qr{$DIAC_RE_EXTRA_R|$DIAC_RE_BASE_R};

our $NEG_SYMB_RE = join('|', keys %NEGATEDSYMBOLS);
$NEG_SYMB_RE    = qr{$NEG_SYMB_RE};
our $NEG_SYMB_RE_R = join('|', keys %NEGATEDSYMBOLS_R);
$NEG_SYMB_RE_R    = qr{$NEG_SYMB_RE_R};

our $SUPER_RE;
my @_ss   = keys %SUPERSCRIPTS;
$SUPER_RE = join('|', map { /[\+\-\)\(]/ ? '\\' . $_ : $_ } @_ss);
$SUPER_RE = qr{$SUPER_RE};
our $SUPER_RE_R;
my @_ss_r   = keys %SUPERSCRIPTS_R;
$SUPER_RE_R = join('|', map { /[\+\-\)\(]/ ? '\\' . $_ : $_ } @_ss_r);
$SUPER_RE_R = qr{$SUPER_RE_R};

our $SUPERCMD_RE = join('|', keys %CMDSUPERSCRIPTS);
$SUPERCMD_RE    = qr{$SUPERCMD_RE};
our $SUPERCMD_RE_R = join('|', keys %CMDSUPERSCRIPTS_R);
$SUPERCMD_RE_R    = qr{$SUPERCMD_RE_R};

our $DINGS_RE_R = join('|', keys %DINGS_R);
$DINGS_RE_R    = qr{$DINGS_RE_R};

1;

__END__

=head1 AUTHOR

François Charette, C<< <firmicus at gmx.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-latex-decode at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=LaTeX-Decode>.  I will be
notified, and then you'll automatically be notified of progress on your bug as
I make changes.

=head1 NOTICE

This module is currently distributed with biber, but it is not unlikely that it
will eventually make its way to CPAN.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2010 François Charette, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
