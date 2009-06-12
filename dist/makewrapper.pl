#!/usr/bin/perl
use strict;
use warnings;
use IO::File;
my $biber = new IO::File "<../bin/biber" or die "cannot find biber: $!" ;
my $wrapper_snippet = q/
BEGIN {
    if ( $ARGV[0] eq 'bib2biblatexml' ) {
        shift @ARGV ;
        exec 'bib2biblatexml', @ARGV or die "Cannot execute bib2biblatexml"
    } elsif ( $ARGV[0] eq 'latex2utf8') {
        shift @ARGV ;
        exec 'latex2utf8', @ARGV or die "Cannot execute latex2utf8"
    }
}
/;

while (<$biber>) {
    next if /^#Don't remove the next line/ ;
    if ( /^#<wrapper_snippet>/ ) {
        print $wrapper_snippet 
    } else {
        print
    }
}
