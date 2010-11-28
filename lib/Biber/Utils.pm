package Biber::Utils;
use strict;
use warnings;
use Carp;
use Encode;
use File::Find;
use File::Spec;
use IPC::Cmd qw( can_run run );
use List::Util qw( first );
use LaTeX::Decode 0.03;
use Biber::Constants;
use Biber::Entry::Name;
use Regexp::Common qw( balanced );
use re 'eval';
use base 'Exporter';
use Log::Log4perl qw(:no_extra_logdie_message);

my $logger = Log::Log4perl::get_logger('main');

=encoding utf-8

=head1 NAME

Biber::Utils - Various utility subs used in Biber

=cut

=head1 EXPORT

All functions are exported by default.

=cut

our @EXPORT = qw{ locate_biber_file makenameid stringify_hash
  normalise_string normalise_string_lite normalise_string_underscore normalise_string_sort
  latexescape reduce_array remove_outer add_outer ucinit strip_nosort_name
  strip_nosortdiacritics strip_nosortprefix is_def is_undef is_def_and_notnull is_def_and_null
  is_undef_or_null is_notnull is_name_field is_null normalise_utf8};

=head1 FUNCTIONS

=head2 locate_biber_file

  Searches for a file by

  For the exact path if the filename is absolute
  In the output-directory, if defined
  Relative to the current directory
  Using kpsewhich, if available

=cut

sub locate_biber_file {
  my $filename = shift;
  my $filenamepath = $filename; # default if nothing else below applies
  my $outfile;
  # If output-directory is set, perhaps the file can be found there so
  # construct a path to test later
  if (my $outdir = Biber::Config->getoption('output-directory')) {
    $outfile = File::Spec->catfile($outdir, $filename);
  }

  if (File::Spec->file_name_is_absolute($filename)) {
    $filenamepath = $filename;
  }
  elsif (defined($outfile) and -f $outfile) {
    $filenamepath = $outfile;
  }
  elsif (-f $filename) {
    $filenamepath = $filename;
  }
  elsif (can_run('kpsewhich')) {
    my $found;
    scalar run( command => [ 'kpsewhich', $filename ],
                verbose => 0,
                buffer => \$found );
    if ($found) {
      chomp $found;
      # filename can be UTF-8 and run() isn't clever with UTF-8
      $filenamepath = decode_utf8($found);
    }
  }
  $logger->info("Found '$filenamepath'");
  return $filenamepath;
}

=head2 is_name_field

    Returns boolean depending on whether the passed field name
    is a name field or not.

=cut

sub is_name_field {
  my $fieldname = shift;
  my $nfs = Biber::Config->getdata('fields_name');
  return defined(first {$fieldname eq $_} @$nfs) ? 1 : 0;
}

=head2 makenameid

Given a Biber::Names object, return an underscore normalised
concatenation of all of the full name strings.

=cut

sub makenameid {
  my $names = shift;
  my @namestrings;
  foreach my $name (@{$names->names}) {
    push @namestrings, $name->get_namestring;
  }
  my $tmp = join ' ', @namestrings;
  return normalise_string_underscore($tmp);
}

=head2 strip_nosort_name

Removes elements which are not to be used in sorting a name from a string

=cut

sub strip_nosort_name {
  my ($string) = @_;
  return '' unless $string; # Sanitise missing data
  $string = strip_nosortprefix($string); # First remove prefix ...
  $string = strip_nosortdiacritics($string); # ... then diacritics
  return $string;
}

=head2 strip_nosortdiacritics

Removes diacritics from a string

=cut

sub strip_nosortdiacritics {
  my ($string) = @_;
  return '' unless $string; # Sanitise missing data
  my $sds = Biber::Config->getoption('nosortdiacritics');
  $string =~ s/$sds//gxms;
  return $string;
}

=head2 strip_nosortprefix

Removes prefix from a string

=cut

sub strip_nosortprefix {
  my ($string) = @_;
  return '' unless $string; # Sanitise missing data
  my $spr = Biber::Config->getoption('nosortprefix');
  $string =~ s/\A$spr//xms;
  return $string;
}

=head2 normalise_string_sort

Removes LaTeX macros, and all punctuation, symbols, separators and control characters,
as well as leading and trailing whitespace for sorting strings.
It also decodes LaTeX character macros into Unicode as this is always safe when
normalising strings for sorting since they don't appear in the output.

=cut

sub normalise_string_sort {
  my $str = shift;
  return '' unless $str; # Sanitise missing data
  # First replace ties with spaces or they will be lost
  $str =~ s/([^\\])~/$1 /g; # Foo~Bar -> Foo Bar
  # Replace LaTeX chars by Unicode for sorting
  # Don't bother if output is UTF-8 as in this case, we've already decoded everthing
  # before we read the file (see Biber.pm)
  unless (Biber::Config->getoption('bblencoding') eq 'UTF-8') {
    $str = latex_decode($str, strip_outer_braces => 1);
  }
  return normalise_string_common($str);
}

=head2 normalise_string

Removes LaTeX macros, and all punctuation, symbols, separators and control characters,
as well as leading and trailing whitespace for sorting strings.
Only decodes LaTeX character macros into Unicode if output is UTF-8

=cut

sub normalise_string {
  my $str = shift;
  return '' unless $str; # Sanitise missing data
  # First replace ties with spaces or they will be lost
  $str =~ s/([^\\])~/$1 /g; # Foo~Bar -> Foo Bar
  if (Biber::Config->getoption('bblencoding') eq 'UTF-8') {
    $str = latex_decode($str, strip_outer_braces => 1);
  }
  return normalise_string_common($str);
}

=head2 normalise_string_common

  Common bit for normalisation

=cut

sub normalise_string_common {
  my $str = shift;
  $str =~ s/\\[A-Za-z]+//g; # remove latex macros (assuming they have only ASCII letters)
  $str =~ s/[\p{P}\p{S}\p{C}]+//g; # remove punctuation, symbols, separator and control
  $str =~ s/^\s+//;
  $str =~ s/\s+$//;
  $str =~ s/\s+/ /g;
  return $str;
}

=head2 normalise_string_lite

  Removes LaTeX macros

=cut

sub normalise_string_lite {
  my $str = shift;
  return '' unless $str; # Sanitise missing data
  # First replace ties with spaces or they will be lost
  $str =~ s/\\\p{L}+\s*//g; # remove tex macros
  $str =~ s/\\[^\p{L}]+\s*//g; # remove accent macros like \"a
  $str =~ s/[{}]//g; # Remove any brackets left
  $str =~ s/~//g;
  $str =~ s/\.//g;
  $str =~ s/\s+//g;
  return $str;
}

=head2 normalise_string_underscore

Like normalise_string, but also substitutes ~ and whitespace with underscore.

=cut

sub normalise_string_underscore {
  my $str = shift;
  return '' unless $str; # Sanitise missing data
  $str =~ s/([^\\])~/$1 /g; # Foo~Bar -> Foo Bar
  $str = normalise_string($str);
  $str =~ s/\s+/_/g;
  return $str;
}

=head2 latexescape

Escapes the LaTeX special characters & ^ _ $ and % but only when not inside
top-level protecting brace pairs {}

=cut

# Why isn't this a simple regexp? Because it would either need some esoteric perl 5.10
# only tricks or negative zero-width variable width look-behind which perl doesn't do.
# All this is another good reason to move to BibLaTeXML ...
sub latexescape {
 my $str = shift;
 my $latexspecials = qr/(\&|\_|\%|\$|\^)/;
 my $rstr;
 my $protected = 0;
 for (my $i=0;$i<length($str);$i++) {
   my $prea = substr($str,$i-1,1);
   my $a = substr($str,$i,1);
   # Opening brace that isn't escaped
   if ($a eq '{' and $prea ne "\\") {
     $protected += 1;
   }
   # Closing brace that isn't escaped
   elsif ($a eq '}' and $prea ne "\\") {
     $protected -= 1;
   }
   # We escape non-escaped things which aren't in protecting braces
   if ($prea ne "\\" and not $protected) {
     $a =~ s/$latexspecials/\\$1/x;
   }
   $rstr .= $a;
 }
 unless ($protected == 0) {
  $logger->warn("Found unbalanced escape sequence in braces for string \"$str\"");
 }
 return $rstr;
}

=head2 reduce_array

reduce_array(\@a, \@b) returns all elements in @a that are not in @b

=cut

sub reduce_array {
  my ($a, $b) = @_;
  my %countb = ();
  foreach my $elem (@$b) {
    $countb{$elem}++;
  }
  my @result;
  foreach my $elem (@$a) {
    push @result, $elem unless $countb{$elem};
  }
  return @result;
}

=head2 remove_outer

    Remove surrounding curly brackets:
        '{string}' -> 'string'

=cut

sub remove_outer {
  my $str = shift;
  $str =~ s/^{(.+)}$/$1/;
  return $str;
}

=head2 add_outer

    Add surrounding curly brackets:
        'string' -> '{string}'

=cut

sub add_outer {
  my $str = shift;
  return '{' . $str . '}';
}


=head2 ucinit

    upper case of initial letters in a string

=cut

sub ucinit {
  my $str = shift;
  $str = lc($str);
  $str =~ s/\b(\p{Ll})/\u$1/g;
  return $str;
}

=head2 is_undef

    Checks for undefness of arbitrary things, including
    composite method chain calls which don't reliably work
    with defined() (see perldoc for defined())
    This works because we are just testing the value passed
    to this sub. So, for example, this is randomly unreliable
    even if the resulting value of the arg to defined() is "undef":

    defined($thing->method($arg)->method)

    wheras:

    is_undef($thing->method($arg)->method)

    works since we only test the return value of all the methods
    with defined()

=cut

sub is_undef {
  my $val = shift;
  return defined($val) ? 0 : 1;
}

=head2 is_def

    Checks for definedness in the same way as is_undef()

=cut

sub is_def {
  my $val = shift;
  return defined($val) ? 1 : 0;
}

=head2 is_undef_or_null

    Checks for undef or nullness (see is_undef() above)

=cut

sub is_undef_or_null {
  my $val = shift;
  return 1 if is_undef($val);
  return $val ? 0 : 1;
}

=head2 is_def_and_notnull

    Checks for def and unnullness (see is_undef() above)

=cut

sub is_def_and_notnull {
  my $arg = shift;
  if (defined($arg) and is_notnull($arg)) {
    return 1;
  }
  else {
    return 0;
  }
}

=head2 is_def_and_null

    Checks for def and nullness (see is_undef() above)

=cut

sub is_def_and_null {
  my $arg = shift;
  if (defined($arg) and is_null($arg)) {
    return 1;
  }
  else {
    return 0;
  }
}

=head2 is_null

    Checks for nullness

=cut

sub is_null {
  my $arg = shift;
  return is_notnull($arg) ? 0 : 1;
}

=head2 is_notnull

    Checks for notnullness

=cut

sub is_notnull {
  my $arg = shift;
  my $st = is_notnull_scalar($arg);
  if (defined($st) and $st) { return 1; }
  my $at = is_notnull_array($arg);
  if (defined($at) and $at) { return 1; }
  my $ht = is_notnull_hash($arg);
  if (defined($ht) and $ht) { return 1; }
  my $ot = is_notnull_object($arg);
  if (defined($ot) and $ot) { return 1; }
  return 0;
}

=head2 is_notnull_scalar

    Checks for notnullness of a scalar

=cut

sub is_notnull_scalar {
  my $arg = shift;
  unless (ref \$arg eq 'SCALAR') {
    return undef;
  }
  return $arg ne '' ? 1 : 0;
}

=head2 is_notnull_array

    Checks for notnullness of an array (passed by ref)

=cut

sub is_notnull_array {
  my $arg = shift;
  unless (ref $arg eq 'ARRAY') {
    return undef;
  }
  my @arr = @$arg;
  return $#arr > -1 ? 1 : 0;
}

=head2 is_notnull_hash

    Checks for notnullness of an hash (passed by ref)

=cut

sub is_notnull_hash {
  my $arg = shift;
  unless (ref $arg eq 'HASH') {
    return undef;
  }
  my @arr = keys %$arg;
  return $#arr > -1 ? 1 : 0;
}

=head2 is_notnull_object

    Checks for notnullness of an object (passed by ref)

=cut

sub is_notnull_object {
  my $arg = shift;
  unless (ref($arg) =~ m/\ABiber::/xms) {
    return undef;
  }
  return $arg->notnull ? 1 : 0;
}


=head2 stringify_hash

    Turns a hash into a string of keys and values

=cut

sub stringify_hash {
  my $hashref = shift;
  my $string;
  while (my ($k,$v) = each %{$hashref}) {
    $string .= "$k => $v, ";
  }
  # Take off the trailing comma and space
  chop $string;
  chop $string;
  return $string;
}

=head2 normalise_utf8

  Normalise any UTF-8 encoding string immediately to exactly what we want
  We want the strict perl utf8 "UTF-8"

=cut

sub normalise_utf8 {
  if (defined(Biber::Config->getoption('bibencoding')) and
      Biber::Config->getoption('bibencoding') =~ m/\Autf-?8\z/xmsi) {
    Biber::Config->setoption('bibencoding', 'UTF-8');
  }
  if (defined(Biber::Config->getoption('bblencoding')) and
      Biber::Config->getoption('bblencoding') =~ m/\Autf-?8\z/xmsi) {
    Biber::Config->setoption('bblencoding', 'UTF-8');
  }
}

=head1 AUTHOR

François Charette, C<< <firmicus at gmx.net> >>
Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2010 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

1;

# vim: set tabstop=2 shiftwidth=2 expandtab:
