#!/opt/local/bin/perl
use v5.16;
use strict;
use warnings;

# First get the latest DUCET allkeys.txt and pass it as the first argument

# Modify the ranges as per the Unicode standard you are using. Currently Unicode 7.0

# NOT USED ANY MORE - because allkeys.txt in U::C is precompiled ans is faster than using
# an uncompiled latinkeys.txt a tenth of the size anyway.

my $latin_ranges = [
                    ['0000', '007F'], # ASCII
                    ['0080', '00FF'], # Latin-1 Supplement
                    ['0100', '017F'], # Latin Extended-A
                    ['0180', '024F'], # Latin Extended-B
                    ['0250', '02AF'], # IPA Extensions
                    ['1D00', '1D7F'], # Phonetic Extensions
                    ['1D80', '1DBF'], # Phonetic Extensions Supplement
                    ['1E00', '1EFF'], # Latin Extended Additional
                    ['2070', '209F'], # Superscripts and Subscripts
                    ['2100', '214F'], # Letterlike Symbols
                    ['2460', '24FF'], # Enclosed Alphanumerics
                    ['2C60', '2C7F'], # Latin Extended-C
                    ['A720', 'A7FF'], # Latin Extended-D
                    ['FB00', 'FB4F'], # Latin Ligatures
                    ['1D400', '1D7FF'], # Mathematical Alphanumeric Symbols
                    ['1F100', '1F1FF'], # Enclosed Alphanumeric Supplement
                   ];


while (<>) {
  # match header lines
  print if m/^$/;
  print if m/^[\#\@]/;
  # match only single byte lines as no latin chars are double-byte anyway
  if (m/^([A-F0-9]+)\s+\;/) {
    print if check_range($1);
  }
}


# Convert to decimal to do the range checks
sub check_range {
  my $c = shift;
  foreach my $range (@$latin_ranges) {
    if (hex($c) >= hex($range->[0]) and
        hex($c) <= hex($range->[1])) {
      return 1;
    }
  }
  return 0;
}
