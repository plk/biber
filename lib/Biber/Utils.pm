package Biber::Utils;
#use feature 'unicode_strings';

use strict;
use warnings;
use Carp;
use Encode;
use File::Find;
use File::Spec;
use IPC::Cmd qw( can_run run );
use List::Util qw( first );
use Biber::Constants;
use Biber::LaTeX::Recode;
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
  reduce_array remove_outer add_outer ucinit strip_nosort
  is_def is_undef is_def_and_notnull is_def_and_null
  is_undef_or_null is_notnull is_null normalise_utf8 inits join_name};

=head1 FUNCTIONS

=head2 locate_biber_file

  Searches for a file by

  For the exact path if the filename is absolute
  In the output_directory, if defined
  Relative to the current directory
  In the same directory as the control file
  Using kpsewhich, if available

=cut

sub locate_biber_file {
  my $filename = shift;
  my $filenamepath = $filename; # default if nothing else below applies
  my $outfile;
  # If output_directory is set, perhaps the file can be found there so
  # construct a path to test later
  if (my $outdir = Biber::Config->getoption('output_directory')) {
    $outfile = File::Spec->catfile($outdir, $filename);
  }

  # Filename is absolute
  if (File::Spec->file_name_is_absolute($filename) and -e $filename) {
    return $filename;
  }

  # File is output_directory
  if (defined($outfile) and -e $outfile) {
    return $outfile;
  }

  # File is relative to cwd
  if (-e $filename) {
    return $filename;
  }

  # File is where control file lives
  if (my $cfp = Biber::Config->get_ctrlfile_path) {
    my ($ctlvolume, $ctldir, undef) = File::Spec->splitpath($cfp);
    if ($ctlvolume) { # add vol sep for windows if volume is set and there isn't one
      $ctlvolume .= ':' unless $ctlvolume =~ /:\z/;
    }
    if ($ctldir) { # add path sep if there isn't one
      $ctldir .= '/' unless $ctldir =~ /\/\z/;
    }

    my $path = "$ctlvolume$ctldir$filename";

    return $path if -e $path;
  }

  # File is in kpse path
  if (can_run('kpsewhich')) {
    my $found;
    scalar run( command => [ 'kpsewhich', $filename ],
                verbose => 0,
                buffer => \$found );
    if ($found) {
      chomp $found;
      # filename can be UTF-8 and run() isn't clever with UTF-8
      return decode_utf8($found);
    }
  }
  return undef;
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

=head2 latex_recode_output

  Tries to convert UTF-8 to TeX macros in passes string

=cut

sub latex_recode_output {
  my $string = shift;
  $logger->info('Converting UTF-8 to TeX macros on output to .bbl');
  require Biber::LaTeX::Recode;
  return Biber::LaTeX::Recode::latex_encode($string,
                                            scheme => Biber::Config->getoption('bblsafecharsset'));
};

=head2 strip_nosort

Removes elements which are not to be used in sorting a name from a string

=cut

sub strip_nosort {
  my $string = shift;
  my $fieldname = shift;
  return '' unless $string; # Sanitise missing data
  my $nosort = Biber::Config->getoption('nosort');
  # Strip user-defined REs from string
  my $restrings;
  # Specific fieldnames override types
  if (exists($nosort->{$fieldname})) {
    $restrings = $nosort->{$fieldname};
  }
  else { # types
    foreach my $ns (keys %$nosort) {
      next unless $ns =~ /\Atype_/xms;
      if ($NOSORT_TYPES{$ns}{$fieldname}) {
        $restrings = $nosort->{$ns};
      }
    }
  }
  # If no nosort to do, just return string
  return $string unless $restrings;
  # Config::General can't force arrays per option and don't want to set this globally
  $restrings = [ $restrings ] unless ref($restrings) eq 'ARRAY';
  foreach my $re (@$restrings) {
    $re = qr/$re/;
    $string =~ s/$re//gxms;
  }
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
  my $fieldname = shift;
  return '' unless $str; # Sanitise missing data
  # First strip nosort REs
  $str = strip_nosort($str, $fieldname);
  # First replace ties with spaces or they will be lost
  $str =~ s/([^\\])~/$1 /g; # Foo~Bar -> Foo Bar
  # Replace LaTeX chars by Unicode for sorting
  # Don't bother if output is UTF-8 as in this case, we've already decoded everthing
  # before we read the file (see Biber.pm)
  unless (Biber::Config->getoption('bblencoding') eq 'UTF-8') {
    $str = latex_decode($str, strip_outer_braces => 1,
                              scheme => Biber::Config->getoption('decodecharsset'));
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
    $str = latex_decode($str, strip_outer_braces => 1,
                              scheme => Biber::Config->getoption('decodecharsset'));
  }
  return normalise_string_common($str);
}

=head2 normalise_string_common

  Common bit for normalisation

=cut

sub normalise_string_common {
  my $str = shift;
  $str =~ s/\\[A-Za-z]+//g;        # remove latex macros (assuming they have only ASCII letters)
  $str =~ s/[\p{P}\p{S}\p{C}]+//g; # remove punctuation, symbols, separator and control
  $str =~ s/^\s+//;                # Remove leading spaces
  $str =~ s/\s+$//;                # Remove trailing spaces
  $str =~ s/\s+/ /g;               # collapse spaces
  return $str;
}

=head2 normalise_string_lite

  Strip LaTeX macros and other bits

=cut

sub normalise_string_lite {
  my $str = shift;
  return '' unless $str; # Sanitise missing data
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
  return undef unless defined($arg);
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

=head2 inits

   We turn the initials into an array so we can be flexible with them later
   The tie here is used only so we know what to split on. We don't want to make
   any typesetting decisions in Biber, like what to use to join initials so on
   output to the .bbl, we only use BibLaTeX macros.

=cut

sub inits {
  my $istring = shift;
  return [ split(/(?<!\\)~/, $istring) ];
}


=head2 join_name

  Replace all join typsetting elements in a name part (space, ties) with BibLaTeX macros
  so that typesetting decisions are made in BibLaTeX, not hard-coded in biber

=cut

sub join_name {
  my $nstring = shift;
  $nstring =~ s/(?<!\\\S)\s+/\\bibbnamedelim /gxms; # Don't do spaces in char macros
  $nstring =~ s/(?<!\\)~/\\bibnbnamedelim /gxms; # Don't do '\~'
  return $nstring;
}

=head1 AUTHOR

François Charette, C<< <firmicus at gmx.net> >>
Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2011 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

1;

# vim: set tabstop=2 shiftwidth=2 expandtab:
