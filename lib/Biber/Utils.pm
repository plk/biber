package Biber::Utils;
use strict;
use warnings;
use Carp;
use LaTeX::Decode ;
use base 'Exporter' ;

=head1 NAME

Biber::Utils - Various utility subs used in Biber

=cut

=head1 VERSION

Version 0.4

=head1 SYNOPSIS

=head1 EXPORT

All functions are exported by default.

=cut

our @EXPORT = qw{ terseinitials makenameid makenameinitid cleanstring
				  normalize_string latexescape print_name array_minus } ;

=head1 FUNCTIONS

=head2 makenameid

=cut

sub makenameid {
    my @names = @_;
    my @namestrings;
    foreach my $n (@names) {
        push @namestrings, $n->{namestring};
    }
    my $tmp = join " ", @namestrings;
    return cleanstring($tmp);
}

=head2 makenameinitid

=cut

sub makenameinitid {
    my @names = @_;
    my @namestrings;
    foreach my $n (@names) {
        push @namestrings, $n->{nameinitstring};
    }
    my $tmp = join " ", @namestrings;
    return cleanstring($tmp);
}

=head2 cleanstring

=cut

sub cleanstring {
    my $str = shift;
    confess "String not defined" unless ($str) ;
    $str =~ s/\\[A-Za-z]+//g;
    $str =~ s/[\p{P}\p{S}\p{C}]+//g ; ### remove punctuation, symbols, separator and control
    $str =~ s/\s+/_/g;
    return $str;
}

=head2 latexescape

=cut

sub latexescape { 
	my $str = shift;
	my @latexspecials = ( '{', '}', '&', '\^', '_', '\$', '%' ); 
	foreach my $char (@latexspecials) {
		$str =~ s/^$char/\\$char/g;
		$str =~ s/([^\\])$char/$1\\$char/g;
	};
	return $str
}

=head2 normalize_string

=cut

sub normalize_string {
    my $str = shift;
    confess "String not defined" unless ($str) ;
    $str =~ s/\\[A-Za-z]+//g;
    $str =~ s/[\p{P}\p{S}\p{C}]+//g ; ### remove punctuation, symbols, separator and control
    return $str;
}

=head2 terseinitials

=cut

sub terseinitials {
    my $str = shift;
    confess "String not defined" unless ($str) ;
	$str =~ s/\\[\p{L}]+\s*//g;  # remove tex macros
    $str =~ s/^{(\p{L}).+}$/$1/g;    # {Aaaa Bbbbb Ccccc} -> A
    $str =~ s/{\s+(\S+)\s+}//g;  # Aaaaa{ de }Bbbb -> AaaaaBbbbb
    # get rid of Punctuation (except DashPunctuation), Symbol and Other characters
    $str =~ s/[\x{2bf}\x{2018}\p{Lm}\p{Po}\p{Pc}\p{Ps}\p{Pe}\p{S}\p{C}]+//g; 
	# remove arabic prefix: al-Khwarizmi -> K / aṣ-Ṣāliḥ -> Ṣ ʿAbd~al-Raḥmān -> A etc
    $str =~ s/\ba\p{Ll}-//; 
    $str =~ s/\B\p{L}//g;
    $str =~ s/\s+//g;
    return $str;
}

=head2 array_minus

=cut

sub array_minus {
    # return @a less all elements that are in @b
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

=head1 AUTHOR

François Charette, C<< <firmicus at gmx.net> >>

=head1 BUGS

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>. 

=head1 COPYRIGHT & LICENSE

Copyright 2009 François Charette, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
# vim: set tabstop=4 shiftwidth=4: 
