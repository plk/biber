package Biber::Utils;
use strict;
use warnings;
use Carp;
use File::Find; 
use IPC::Cmd qw( can_run run );
use LaTeX::Decode;
use Biber::Constants;
use base 'Exporter';
use Log::Log4perl;

my $logger = Log::Log4perl::get_logger;

=head1 NAME

Biber::Utils - Various utility subs used in Biber

=cut

=head1 VERSION

Version 0.4

=head1 SYNOPSIS

=head1 EXPORT

All functions are exported by default.

=cut

our @EXPORT = qw{ bibfind parsename terseinitials makenameid makenameinitid 
    normalize_string normalize_string_underscore latexescape array_minus
    remove_outer getinitials tersify ucinit };


######
# These are used in the functions parsename and getinitials :
# 
# TODO move to Biber::Constants ?
#
# Semitic (or eventually other) last names could begin with NONSORTDIACRITICS like ʿ or ‘ (e.g. ʿAlī)
my $NONSORTDIACRITICS = qr/[\x{2bf}\x{2018}]/; # more?

# Semitic (or eventually other) names may be prefixed with an article (e.g. al-Hasan, as-Saleh)
my $NONSORTPREFIX = qr/\p{Ll}{2}-/; # etc

#
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
            $logger->debug("Found bib file $File::Find::name");
        } 

        if (@_found) {
            return shift @_found 
        } else {
            return $_filename
        }

    } else {
        return $_filename
    }
}


=head2 parsename

    Given a name string, this function returns a hash with all parts of the name
    resolved according to the BibTeX conventions.

    parsename('John Doe') 
    returns: 
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
    $namestr =~ s/\\,\s*|{\\,\s*}/~/g; # necessary to get rid of LaTeX small spaces \,
    $logger->debug("Parsing namestring $namestr");
    my $usepre = $opts->{useprefix};

    my $lastname;
    my $firstname;
    my $prefix;
    my $suffix;
    my $nameinitstr;
    
    if ( $namestr =~ /^{.+}$/ ) 
    { 
        $namestr = remove_outer($namestr);
        $lastname = $namestr;
    } 
    elsif ( $namestr =~ /[^\\],.+[^\\],/ )    # pre? Lastname, suffix, Firstname
    {
        ( $prefix, $lastname, $suffix, $firstname ) = $namestr =~
            m/^(
                \p{Ll}
                (?:\p{Ll}|\s)+
               )?
               \s*
               (
                [^,]+
               |
                {[^,]+}
               )
               ,
               \s+
               (
                [^,]+
               | 
                {[^,]+}
               )
               ,
               \s+
               (
                [^,]+
               | 
                {[^,]+}
               )
             $/x;

        #$lastname =~ s/^{(.+)}$/$1/g;
        #$firstname =~ s/^{(.+)}$/$1/g;
        $prefix =~ s/\s+$// if $prefix;
        $suffix =~ s/\s+$//;
    }
    elsif ( $namestr =~ /[^\\],/ )   # <pre> Lastname, Firstname
    {
        ( $prefix, $lastname, $firstname ) = $namestr =~
            m/^(
                \p{Ll} # prefix starts with lowercase
                (?:\p{Ll}|\s)+ # e.g. van der
                \s+
               )?
               (
                $NONSORTPREFIX?$NONSORTDIACRITICS?
                [^,]+
                |
                {[^,]+}
               ),
               \s+
               (
                $NONSORTPREFIX?$NONSORTDIACRITICS?
                [^,]+
                |
                {.+}
               )
               $/x;

        #$lastname =~ s/^{(.+)}$/$1/g;
        #$firstname =~ s/^{(.+)}$/$1/g;
        $namestr =~ s/^$prefix// if ( $prefix && ! $usepre);
        $prefix =~ s/\s+$// if $prefix;
    }
    elsif ( $namestr =~ /\s/ ) # Firstname pre? Lastname
    {
        ( $firstname, $prefix, $lastname ) =
          $namestr =~ /^(
                         {.+}
                        |
                         (?:\S+[\s~]*?)+
                        )
                        \s+
                        (
                         (?:\p{Ll}+\.?[\s~]*)+
                        )?
                        (\S+)
                        $/x;

        #$lastname =~ s/^{(.+)}$/$1/;
        $firstname =~ s/\s+$// if $firstname;

        #$firstname =~ s/^{(.+)}$/$1/ if $firstname;
        $prefix =~ s/\s+$// if $prefix;
        $namestr = "";
        $namestr = $prefix if $prefix;
        $namestr .= $lastname if $lastname;
        $namestr .= ", " . $firstname if $firstname;
    }
    else 
    {    # Name alone
        $lastname = $namestr;
    }

    #TODO? $namestr =~ s/[\p{P}\p{S}\p{C}]+//g;
    ## remove punctuation, symbols, separator and control 

    $namestr =~ s/\b$NONSORTPREFIX//;
    $namestr =~ s/\b$NONSORTDIACRITICS//;

    $nameinitstr = "";
    $nameinitstr .= substr( $prefix, 0, 1 ) . " " if ( $usepre and $prefix );
    $nameinitstr .= $lastname;
    $nameinitstr =~ s/\b$NONSORTPREFIX//;
    $nameinitstr =~ s/\b$NONSORTDIACRITICS//;
    $nameinitstr .= " " . terseinitials($suffix) 
        if $suffix;
    $nameinitstr .= " " . terseinitials($firstname) 
        if $firstname;
    $nameinitstr =~ s/\s+/_/g;

    return {
            namestring     => $namestr,
            nameinitstring => $nameinitstr,
            lastname       => $lastname,
            firstname      => $firstname,
            prefix         => $prefix,
            suffix         => $suffix
           }
}

=head2 makenameid

Given an array of names (as hashes), this internal sub returns a long string
with the concatenation of all names.

=cut

sub makenameid {
    my @names = @_;
    my @namestrings;
    foreach my $n (@names) {
        push @namestrings, $n->{namestring};
    }
    my $tmp = join " ", @namestrings;
    return normalize_string_underscore($tmp, 1);
}

=head2 makenameinitid

Similar to makenameid, with the first names converted to initials.

=cut

sub makenameinitid {
    my @names = @_;
    my @namestrings;
    foreach my $n (@names) {
        push @namestrings, $n->{nameinitstring};
    }
    my $tmp = join " ", @namestrings;
    return normalize_string_underscore($tmp, 1);
}

=head2 normalize_string

Removes LaTeX macros, and all punctuation, symbols, separators and control characters,
as well as leading and trailing whitespace.

=cut

sub normalize_string {
    my ($str, $no_decode) = @_;
    $str = latex_decode($str) unless $no_decode;
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
    $str =~ s/([^\\])~/$1 /g; # Foo~Bar -> Foo Bar
    $str = normalize_string($str, $no_decode);
    $str =~ s/\s+/_/g;
    return $str;
}

=head2 latexescape

Escapes the LaTeX special characters { } & ^ _ $ and %

=cut

sub latexescape { 
  my $str = shift;
  my @latexspecials = qw| { } & _ % |;
  foreach my $char (@latexspecials) {
    $str =~ s/^$char/\\$char/g;
    $str =~ s/([^\\])$char/$1\\$char/g;
  };
    $str =~ s/\$/\\\$/g;
    $str =~ s/\^/\\\^/g;
  return $str
}

=head2 terseinitials

terseinitials($str) returns the contatenated initials of all the words in $str.
    terseinitials('Louis Pierre de la Ramée') => 'LPdlR'

=cut

sub terseinitials {
    my $str = shift;
    $str =~ s/^$NONSORTPREFIX//;
    $str =~ s/^$NONSORTDIACRITICS//;
    $str =~ s/\\[\p{L}]+\s*//g; # remove tex macros
    $str =~ s/^{(\p{L}).+}$/$1/g; # {Aaaa Bbbbb Ccccc} -> A
    $str =~ s/{\s+(\S+)\s+}//g; # Aaaaa{ de }Bbbb -> AaaaaBbbbb
    # get rid of Punctuation (except DashPunctuation), Symbol and Other characters
    $str =~ s/[\x{2bf}\x{2018}\p{Lm}\p{Po}\p{Pc}\p{Ps}\p{Pe}\p{S}\p{C}]+//g;
    $str =~ s/\B\p{L}//g;
    $str =~ s/[\s\p{Pd}]+//g;
    return $str;
}

=head2 array_minus

array_minus(\@a, \@b) returns all elements in @a that are not in @b

=cut

sub array_minus {
  my ($a, $b) = @_;
  my %countb = ();
    foreach my $elem (@$b) { 
    $countb{$elem}++ 
  };
    my @result;
    foreach my $elem (@$a) {
        push @result, $elem unless $countb{$elem}
    };
    return @result
}

=head2 remove_outer
    
    Remove surrounding curly brackets:  
        '{string}' -> 'string'

=cut

sub remove_outer {
    my $str = shift;
    $str =~ s/^{(.+)}$/$1/;
    return $str
}

=head2 getinitials
    
    Returns the initials of a name, preserving LaTeX code.

=cut

sub getinitials {
    my $str = shift;
    $str =~ s/{\s+(\S+)\s+}//g; # Aaaaa{ de }Bbbb -> AaaaaBbbbb
    # remove pseudo-space after macros
    $str =~ s/{? ( \\ [^\p{Ps}\{\}]+ ) \s+ (\p{L}) }?/\{$1\{$2\}\}/gx; # {\\x y} -> {\x{y}}
    $str =~ s/( \\ [^\p{Ps}\{\}]+ ) \s+ { /$1\{/gx; # \\macro { -> \macro{
    my @words = split /\s+/, remove_outer($str);
    $str = join ".~", ( map { _firstatom($_) } @words );
    return $str . "."
}

sub _firstatom {
    my $str = shift;
    $str =~ s/^$NONSORTPREFIX//;
    $str =~ s/^$NONSORTDIACRITICS//;
    if ($str =~ /^({ 
                   \\ [^\p{Ps}\p{L}] \p{L}+ # {\\.x}
                   }
                   | {?
                    \\[^\p{Ps}\{\}]+        # \\macro{x}
                     { \p{L} }
                     }?
                   | { \\\p{L}+ }           # {\\macro}
                   )/x ) {
        return $1
    } else {
        return substr($str, 0, 1)
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
    return $str
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

=head1 AUTHOR

François Charette, C<< <firmicus at gmx.net> >>
Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>. 

=head1 COPYRIGHT & LICENSE

Copyright 2009 François Charette and Philip Kime, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;

# vim: set tabstop=4 shiftwidth=4 expandtab: 
