#!/usr/bin/env perl

use v5.24;
use strict;
use warnings;
use feature qw( say );
use utf8;
use Encode;

use FindBin;
use lib $FindBin::RealBin;

use Biber::CodePage qw( :DEFAULT string_analysis );
sub analyze_string {
    my ( $m, $s, $bytes ) = @_;
    print "$m\n", string_analysis( 'PREFIX ', $s, $bytes );
}

say "===================\n-----**Demo of package CodePage**";

#----------------------
my $CS_system = get_CS_system();
say "System CS = $CS_system";

#----------------------
my @ARGU = map { decode_CS_system($_) } @ARGV;
say "===CL argument array is '@ARGU'";

#----------------------
my $s = "Açé∫Δτ";
say "\n=== Try some Unicode to STDOUT: $s";
say "=== Same to STDERR: $s";
analyze_string( "Analyze the string used:\n", $s );


#----------------------
my $dir = '.';
say "\n=== Files in '$dir'";
opendir( my $dh, $dir )
    or die "Cannot read directory '$dir'\n";
my @files = sort readdir($dh);
closedir( $dh );
foreach (@files) {
    $_ = decode( $CS_system, $_);
    if ( /^\.[\.]?\s*$/ ) {next; }
    say " '$_'";
}

#----------------------

say "\n=== Read files given on CL:";
my $max_lines = 3;
if (@ARGU) {
    foreach ( @ARGU ) {
        say "  --- File =  '$_'";
        # The files I've created are known to be UTF-8.
        open( my $fh, "<:encoding(UTF-8)", encode_CS_system($_) )
            or die "Cannot read '$_'";
        local $_;
        my $count =0;
        while ( <$fh> ) {
            print "    $_";
            $count++;
            if ($count >= $max_lines) { last; }
        }
        close $fh;
    }
}
else { say "NONE"; }
