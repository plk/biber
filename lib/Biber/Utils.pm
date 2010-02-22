package Biber::Utils;
use strict;
use warnings;
use Carp;
use Encode;
use File::Find;
use IPC::Cmd qw( can_run run );
use List::Util qw( first );
use LaTeX::Decode;
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

=head1 VERSION

Version 0.4

=head1 SYNOPSIS

=head1 EXPORT

All functions are exported by default.

=cut

our @EXPORT = qw{ bibfind tersify terseinitials makenameid stringify_hash
  normalize_string normalize_string_underscore latexescape reduce_array
  remove_outer add_outer getinitials ucinit strip_nosort strip_nosortdiacritics
  strip_nosortprefix is_def is_undef is_def_and_notnull is_def_and_null is_undef_or_null
  is_notnull is_name_field is_null};


######

=head1 FUNCTIONS

=head2 bibfind

    Searches a bib file in the BIBINPUTS paths using kpsepath (which should be
    available on most modern TeX installations). Otherwise it just returns
    the argument.

=cut

sub bibfind {
  ## since these variables are used in the _wanted sub, they need to be made global
  ## FIXME there must be a way to avoid this
  our $_filename = shift;
  our @_found = ();

  $_filename .= '.bib' unless $_filename =~ /\.(bib|xml|dbxml)$/;

  if ( can_run("kpsepath") ) {
    my $kpsepath;
    scalar run( command => [ 'kpsepath', 'bib' ],
      verbose => 0,
      buffer => \$kpsepath );
    my @paths = split ( /:!*/, $kpsepath );
    sub _removetrailingslashes {
      my $str = shift;
      $str =~ s|/+\s*$||;
      return $str
    };

    @paths = map { _removetrailingslashes( $_ ) } @paths;

    no warnings 'File::Find';
    find (\&_wanted, @paths);

    sub _wanted {
      $_ =~ /^$_filename($|\.bib$)/ && push @_found, $File::Find::name;
    }

    if (@_found) {
      my $found = shift @_found;
      $logger->debug("Found bib file $found");
      return $found ;
    } else {
      $logger->debug("Found bib file $_filename");
      return $_filename ;
    }

  } else {
    return $_filename
  }
}


=head2 is_name_field

    Returns boolean depending on whether the passed field name
    is a name field or not.

=cut

sub is_name_field {
  my $fieldname = shift;
  return defined(first {$fieldname eq $_} @NAMEFIELDS) ? 1 : 0;
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
  return normalize_string_underscore($tmp, 1);
}

=head2 strip_nosort

Removes elements which are not to be used in sorting from a string

=cut

sub strip_nosort {
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

=head2 normalize_string

Removes LaTeX macros, and all punctuation, symbols, separators and control characters,
as well as leading and trailing whitespace.

=cut

sub normalize_string {
  my ($str, $no_decode) = @_;
  return '' unless $str; # Sanitise missing data
  # First replace ties with spaces or they will be lost
  $str =~ s/([^\\])~/$1 /g; # Foo~Bar -> Foo Bar
  $str = latex_decode($str) unless $no_decode;
  $str = strip_nosort($str); # strip nosort elements
  $str =~ s/\\[A-Za-z]+//g; # remove latex macros (assuming they have only ASCII letters)
  $str =~ s/[\p{P}\p{S}\p{C}]+//g; ### remove punctuation, symbols, separator and control
  $str =~ s/^\s+//;
  $str =~ s/\s+$//;
  $str =~ s/\s+/ /g;
  return $str;
}

=head2 normalize_string_underscore

Like normalize_string, but also substitutes ~ and whitespace with underscore.

=cut

sub normalize_string_underscore {
  my ($str, $no_decode) = @_;
  return '' unless $str; # Sanitise missing data
  $str =~ s/([^\\])~/$1 /g; # Foo~Bar -> Foo Bar
  $str = normalize_string($str, $no_decode);
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

=head2 terseinitials

terseinitials($str) returns the contatenated initials of the raw initials list
passed in $str. It removes LaTeX formatting. This is used to create hashes.

   terseinitials('L.~P.~D.) => 'LPD'
   terseinitials('{\v S}~P.~D.) => '{\v S}PD'
   terseinitials('J.-M.) => 'J-M'

=cut

sub terseinitials {
  my $str = shift;
  return '' unless $str; # Sanitise missing data
  $str =~ s/\\[\p{L}]+\s*//g; # remove tex macros
  $str =~ s/^{(\p{L}).+}$/$1/g; # {Aaaa Bbbbb Ccccc} -> A
  # get rid of Punctuation, Symbol and Other characters
  $str =~ s/[\p{Lm}\p{Pd}\p{Po}\p{Pc}\p{Ps}\p{Pe}\p{S}\p{C}]+//g;
  $str =~ s/\s+//g;
  $str =~ s/~//g;
  $str =~ s/\.//g;
  return $str;
}

=head2 tersify

tersify($str) sanitises the initials string passed in $str to a format
required by the "terseinits" option of biblatex

   tersify('L.~P.~D.) => 'LPD'
   tersify('{\v S}~P.~D.) => '{\v S}PD'
   tersify('J.-M.) => 'J-M'

=cut

sub tersify {
  my $str = shift;
  return '' unless $str; # Sanitise missing data
  $str =~ s/~//g;
  $str =~ s/\.//g;
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

=head2 getinitials

    Returns the initials of a name, preserving LaTeX code.
    This has to be a token parser as we need to take account of
    brace groupings:

    e.g. getting firstname initials:

    "{John Henry} Ford" -> "J."
    "John Henry Ford" -> "J.H."

=cut

sub getinitials {
  my $str = shift;
  my $rstr;
  return '' unless $str; # Sanitise missing data
  while (my $atom = get_atom(\$str)) {
    # We have to look inside braces to see what we have
    # Just normal protected names:

    # hyphens in names are special atoms
    if ($atom =~ m/\A-\z/xms) {
      $rstr =~ s/~\z//xms; # If we're appending a hypehn, don't want nbsp too
      $rstr .= '-';
    }
    # Initials - P. or {P.\,G.}
    elsif ($atom =~ m/\A{?(\p{L}+)?\./xms) {
      $rstr .= substr($1, 0, 1) . '.~';
    }
    # John
    elsif ($atom =~ m/\A\p{L}+\z/xms) {
      $rstr .= substr($atom, 0, 1) . '.~';
    }
    # {John Henry} or {American Automobile Association, Canada}
    elsif ($atom =~ m/\A{([^\\\{\}]+)}\z/xms) {
      $rstr .= substr($1, 0, 1) . '.~';
    }
    # {\OE}illet
    elsif ($atom =~ m/\A({\\\p{L}+}).+\z/xms) {
      $rstr .= $1 . '.~';
    }
    # {\v S}omeone or {\v Someone}
    elsif ($atom =~ m/\A({\\\S+\s+\p{L}+}).+\z/xms) {
      $rstr .= $1 . '.~';
    }
    # {\v{S}}omeone
    elsif ($atom =~ m/\A({\\\S+{\p{L}}}).+\z/xms) {
      $rstr .= $1 . '.~';
    }
    # \v{S}omeone
    elsif ($atom =~ m/\A(\\\S+{\p{L}}).+\z/xms) {
      $rstr .= $1 . '.~';
    }
    # {\"O}zt{\"u}rk
    elsif ($atom =~ m/\A({\\[^\p{L}]\p{L}}).+\z/xms) {
      $rstr .= $1 . '.~';
    }
    # Default
    else {
      $rstr .= substr($atom, 0, 1) . '.~';
    }
  }
  # remove trailing nbsp
  $rstr =~ s/~\z//xms;
  return $rstr;
}

=head2 get_atom

     Pull an "atom" from a name list. An "atom" is the first chunk
     of a name that will have a separate initial created for it.
     This has to be a token parser with a "brace level 0" concept
     It cannot be done with regexps due to BibTeX's parsing semantics
     which we are emulating.

=cut

sub get_atom {
  my $str = shift;
  unless ($$str) {
    return undef;
  }
  # strip nosort elements as they shouldn't be initials either
  $$str = strip_nosort($$str);
  my $bl = 0;
  my $atom;
  for (my $i=0;$i<length($$str);$i++) {
    my $prea = substr($$str,$i-1,1);
    my $a = substr($$str,$i,1);
    if ($a =~ m/[\s~]/ and $bl == 0)  {
      $$str = substr($$str, $i+1);
      return $atom;
    }
    elsif ($a eq '{' and $prea ne "\\") {
      $bl++;
    }
    # Hyphens are special atoms at brace level zero
    elsif ($a eq '-' and $bl == 0) {
      # If the hyphen is at the beginning of the string, return it as an atom
      # Since we left it there to be so consumed
      if ($i == 0) {
        $$str = substr($$str, $i+1);
        return '-';
      }
      # Leave the hyphen on the string so it can be consumed as a separate atom
      # and return the current token
      else {
        $$str = substr($$str, $i);
        return $atom;
      }
    }
    elsif ($a eq '}') {
      $bl--;
    }
    $atom .= $a;
  }
  $$str = '';
  return $atom;
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
  return $arg ? 1 : 0;
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

=head1 AUTHOR

François Charette, C<< <firmicus at gmx.net> >>
Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2010 François Charette and Philip Kime, all rights reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

=cut

1;

# vim: set tabstop=2 shiftwidth=2 expandtab:
