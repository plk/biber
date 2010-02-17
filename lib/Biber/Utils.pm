package Biber::Utils;
use strict;
use warnings;
use Carp;
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

our @EXPORT = qw{ bibfind parsename terseinitials makenameid stringify_hash
  normalize_string normalize_string_underscore latexescape reduce_array
  remove_outer getinitials tersify ucinit strip_nosort strip_nosortdiacritics
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

=head2 parsename

    Given a name string, this function returns a Biber::Entry:Name object
    with all parts of the name resolved according to the BibTeX conventions.

    parsename('John Doe')
    returns an object which internally looks a bit like this:

    { firstname => 'John',
      lastname => 'Doe',
      prefix => undef,
      suffix => undef,
      namestring => 'Doe, John',
      nameinitstring => 'Doe_J' }

    parsename('von Berlichingen zu Hornberg, Johann G{\"o}tz')
    returns:

    { firstname => 'Johann G{\"o}tz',
      lastname => 'Berlichingen zu Hornberg',
      prefix => 'von',
      suffix => undef,
      namestring => 'Berlichingen zu Hornberg, Johann Gotz',
      nameinitstring => 'Berlichingen_zu_Hornberg_JG' }

=cut

sub parsename {
  my ($namestr, $opts) = @_;
  $logger->debug("   Parsing namestring '$namestr'");
  # Change small spaces to something else temporarily to make parsing easier
  # We rely on looking for commas to parse names and latex small spaces confuse
  # things a lot
  $namestr =~ s/\\,\s*|{\\,\s*}/BSM~~~BSM/g;
  my $usepre = $opts->{useprefix};

  my $lastname;
  my $firstname;
  my $prefix;
  my $suffix;
  my $nameinitstr;

  my $PREFIX_RE = qr/
                {?
                \p{Ll} # prefix starts with lowercase
                [^\p{Lu},]+ # e.g. van der
                }?
                \s+
/x ;
  my $NAME_RE = qr/
                [^,]+
               |
                $RE{balanced}{-parens=>'{}'}
/x;
  my $SUFFIX_RE = $NAME_RE;
  my $NAME_SEQ_RE = qr/ (?:(?:\p{Lu}\S*|{\p{Lu}\S*})[\s~]*)+ /x ;

  if ( $namestr =~ /^$RE{balanced}{-parens => '{}'}$/ )
  {
    $logger->debug("   Caught namestring of type '{Some protected name string}'");
    $namestr = remove_outer($namestr);
    $lastname = $namestr;
  }
  elsif ( $namestr =~ /[^\\],.+[^\\],/ )    # pre? Lastname, suffix, Firstname
  {
    $logger->debug("   Caught namestring of type 'prefix? Lastname, suffix, Firstname'");
    ( $prefix, $lastname, $suffix, $firstname ) = $namestr =~
      m/\A( # prefix?
                $PREFIX_RE
               )?
               ( # last name
                $NAME_RE
               )
               ,
               \s*
               ( # suffix
                $SUFFIX_RE
               )
               ,
               \s*
               ( # first name
                $NAME_RE
               )
\z/xms;

    $logger->warn("Couldn't determine Last Name for name \"$namestr\"") unless $lastname;
    $logger->warn("Couldn't determine First Name for name \"$namestr\"") unless $firstname;
    if ($lastname) {$lastname =~ s/^{(.+)}$/$1/g;}
    if ($firstname) {$firstname =~ s/^{(.+)}$/$1/g;}
    $prefix =~ s/\s+$// if $prefix;
    $prefix =~ s/^{(.+)}$/$1/ if $prefix;
    $suffix =~ s/\s+$//;
    $suffix =~ s/^{(.+)}$/$1/;
    $namestr = "";
    $namestr .= "$prefix " if ($prefix && $usepre);
    $namestr .= "$lastname, $suffix, $firstname";
  }
  elsif ( $namestr =~ /[^\\],/ )   # <pre> Lastname, Firstname
  {
    $logger->debug("   Caught namestring of type 'prefix? Lastname, Firstname'");

    ( $prefix, $lastname, $firstname ) = $namestr =~
      m/^( # prefix?
                $PREFIX_RE
               )?
               ( # last name
                $NAME_RE
               )
               ,
               \s*
               ( # first name
                $NAME_RE
               )
$/x;

    $logger->warn("Couldn't determine Last Name for name \"$namestr\"") unless $lastname;
    $logger->warn("Couldn't determine First Name for name \"$namestr\"") unless $firstname;
    if ($lastname) {$lastname =~ s/^{(.+)}$/$1/g;}
    if ($firstname) {$firstname =~ s/^{(.+)}$/$1/g;}
    $prefix =~ s/\s+$// if $prefix;
    $prefix =~ s/^{(.+)}$/$1/ if $prefix;
    $namestr = "";
    $namestr .= "$prefix " if ($prefix && $usepre);
    $namestr .= "$lastname, $firstname";
  }
  elsif ( $namestr =~ /\s/ ) # Firstname pre? Lastname
  {
    if ( $namestr =~ /^$RE{balanced}{-parens => '{}'}.*\s+$RE{balanced}{-parens => '{}'}$/ )
    {
      $logger->debug("   Caught namestring of type '{Firstname} prefix? {Lastname}'");
      ( $firstname, $prefix, $lastname ) = $namestr =~
        m/^( # first name
                    $RE{balanced}{-parens=>'{}'}
                )
                    \s+
                ( # prefix?
                    $PREFIX_RE
                )?
                ( # last name
                    $RE{balanced}{-parens=>'{}'}
                )
$/x;
    }
    elsif ( $namestr =~ /^.+\s+$RE{balanced}{-parens => '{}'}$/ )
    {
      $logger->debug("   Caught namestring of type 'Firstname prefix? {Lastname}'");
      ( $firstname, $prefix, $lastname ) = $namestr =~
        m/^( # first name
                    $NAME_SEQ_RE
                )
                    \s+
                ( # prefix?
                    $PREFIX_RE
                )?
                ( # last name
                    $RE{balanced}{-parens=>'{}'}
                )
$/x;
    }
    elsif ( $namestr =~ /^$RE{balanced}{-parens => '{}'}.+$/ )
    {
      $logger->debug("   Caught namestring of type '{Firstname} prefix? Lastname'");
      ( $firstname, $prefix, $lastname ) = $namestr =~
        m/^( # first name
                    $RE{balanced}{-parens=>'{}'}
                )
                    \s+
                ( # prefix?
                    $PREFIX_RE
                )?
                ( # last name
                    .+
                )
$/x;
    }
   else {
      $logger->debug("   Caught namestring of type 'Firstname prefix? Lastname'");
      ( $firstname, $prefix, $lastname ) = $namestr =~
        m/^( # first name
                    $NAME_SEQ_RE
                )
                 \s+
                ( # prefix?
                    $PREFIX_RE
                )?
                ( # last name
                    $NAME_SEQ_RE
                )
$/x;
    }

    $logger->warn("Couldn't determine Last Name for name \"$namestr\"") unless $lastname;
    $logger->warn("Couldn't determine First Name for name \"$namestr\"") unless $firstname;
    if ($lastname) {$lastname =~ s/^{(.+)}$/$1/;}
    if ($firstname) {$firstname =~ s/^{(.+)}$/$1/;}
    $firstname =~ s/\s+$// if $firstname;

    $prefix =~ s/\s+$// if $prefix;
    $prefix =~ s/^{(.+)}$/$1/ if $prefix;
    $namestr = "";
    $namestr = "$prefix " if $prefix;
    $namestr .= $lastname if $lastname;
    $namestr .= ", " . $firstname if $firstname;
  }
  else
  {    # Name alone
    $logger->debug("   Caught namestring of type 'Isolated_name_string'");
    $lastname = $namestr;
  }

  #TODO? $namestr =~ s/[\p{P}\p{S}\p{C}]+//g;
  ## remove punctuation, symbols, separator and control

  # Now put the LaTeX small spaces back again since we're finished parsing
  $namestr =~ s/BSM~~~BSM/{\\,}/g if $namestr;
  $firstname =~ s/BSM~~~BSM/{\\,}/g if $firstname;
  $lastname =~ s/BSM~~~BSM/{\\,}/g if $lastname;
  $nameinitstr =~ s/BSM~~~BSM/{\\,}/g if $nameinitstr;
  $prefix =~ s/BSM~~~BSM/{\\,}/g if $prefix;
  $suffix =~ s/BSM~~~BSM/{\\,}/g if $suffix;

  $nameinitstr = "";
  $nameinitstr .= substr( $prefix, 0, 1 ) . " " if ( $usepre and $prefix );
  $nameinitstr .= $lastname if $lastname;
  $nameinitstr .= " " . terseinitials($suffix)
    if $suffix;
  $nameinitstr .= " " . terseinitials($firstname)
    if $firstname;
  $nameinitstr =~ s/\s+/_/g;

  return Biber::Entry::Name->new(
    firstname => $firstname,
    lastname  => $lastname,
    namestring => $namestr,
    nameinitstring => $nameinitstr,
    prefix => $prefix,
    suffix => $suffix
    );
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


# sub latexescape {
#   my $str = shift;
#   my @latexspecials = qw| & _ % |;
#   foreach my $char (@latexspecials) {
#     $str =~ s/^$char/\\$char/g;
#     $str =~ s/([^\\])$char/$1\\$char/g;
#   }
#   $str =~ s/\$/\\\$/g;
#   $str =~ s/\^/\\\^/g;
#   return $str;
# }

=head2 terseinitials

terseinitials($str) returns the contatenated initials of all the words in $str.
    terseinitials('Louis Pierre de la Ramée') => 'LPdlR'

=cut

sub terseinitials {
  my $str = shift;
  return '' unless $str; # Sanitise missing data
  $str = strip_nosort($str); # strip nosort elements
  $str =~ s/\\[\p{L}]+\s*//g; # remove tex macros
  $str =~ s/^{(\p{L}).+}$/$1/g; # {Aaaa Bbbbb Ccccc} -> A
  $str =~ s/{\s+(\S+)\s+}//g; # Aaaaa{ de }Bbbb -> AaaaaBbbbb
  # get rid of Punctuation (except DashPunctuation), Symbol and Other characters
  $str =~ s/[\p{Lm}\p{Po}\p{Pc}\p{Ps}\p{Pe}\p{S}\p{C}]+//g;
  $str =~ s/\B\p{L}//g;
  $str =~ s/[\s\p{Pd}]+//g;
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

=head2 getinitials

    Returns the initials of a name, preserving LaTeX code.

=cut

sub getinitials {
  my $str = shift;
  return '' unless $str; # Sanitise missing data
  $str =~ s/{\s+(\S+)\s+}//g; # Aaaaa{ de }Bbbb -> AaaaaBbbbb
  # remove pseudo-space after macros
  $str =~ s/{? ( \\ [^\p{Ps}\{\}]+ ) \s+ (\p{L}) }?/\{$1\{$2\}\}/gx; # {\\x y} -> {\x{y}}
  $str =~ s/( \\ [^\p{Ps}\{\}]+ ) \s+ { /$1\{/gx; # \\macro { -> \macro{
  # Split first names on space or protected LaTeX small space
  my @words = split /(?:\s+|{\\,})/, remove_outer($str);
  $str = join '.~', ( map { _firstatom($_) } @words );
  # Add a final period if there isn't already one at the "end"
  # where "end" could be inside a brace to the left too
  $str .= '.' unless $str =~ m/\.}?\z/xms;
  return $str;
}

sub _firstatom {
  my $str = shift;
  $str = strip_nosort($str); # strip nosort elements
  if ($str =~ /^({
                   \\ [^\p{Ps}\p{L}] \p{L}+ # {\\.x}
                   }
                   | {?
                    \\[^\p{Ps}\{\}]+        # \\macro{x}
                     { \p{L} }
                     }?
                   | { \\\p{L}+ }           # {\\macro}
                   | {.+}                   # {something protected}
)/x ) {
    return $1;
  } else {
    return substr($str, 0, 1);
  }
}

=head2 tersify

    Removes '.' and '~' from initials.

    tersify('A.~B.~C.') -> 'ABC'

=cut

sub tersify {
  my $str = shift;
  $str =~ s/~//g;
  $str =~ s/\.//g;
  return $str;
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
  my $ht = is_notnull_array($arg);
  if (defined($ht) and $ht) { return 1; }
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
