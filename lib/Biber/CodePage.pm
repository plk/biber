package Biber::CodePage;
use v5.24;
use strict;
use warnings;
use parent qw(Exporter);
our @EXPORT = qw( decode_CS_system encode_CS_system get_CS_system
                  set_CP_Win_console set_CS_defaults  set_STD_encodings );
our @EXPORT_OK = qw( analyze_string );

# Handling of code page issues, especially on Windows.
# John Collins 2024-09-25

use Encode qw( encode decode );
use Unicode::Normalize qw( checkNFC checkNFD );
use feature qw( say );


# My default CS for system (filenames for subroutine, @ARGV): UTF-8.
# Then update according to system settings (if any).
our $CS_system = 'UTF-8';
our $CS_console = 'UTF-8';

# Win32 specific CP **numbers**.  Initialize to 65001 (utf-8), and change
# to correspond to results from system calls.
# Corresponding CS name: Prefix by 'CP'.
# Preserve intial values for console/terminal to allow restore on exit.
# Declarations
our ($CP_Win_system, $CP_init_Win_console_in, $CP_init_Win_console_out);

# Initial defaults
$CP_Win_system = $CP_init_Win_console_in = $CP_init_Win_console_out = '65001';




# ==========================================
# Externally usable subroutines.

#--------------------------

sub decode_CS_system($) {
    my $s = $_[0];
    return decode( $CS_system, $s );
}

#--------------------------

sub encode_CS_system($) {
    my $s = $_[0];
    return encode( $CS_system, $s );
}

#--------------------------

sub get_CS_console() {
    return $CS_console;
}

#--------------------------

sub get_CS_system() {
    return $CS_system;
}

#--------------------------

sub set_STD_encodings($) {
    # Set coding scheme for STDOUT, STDERR & STDIN.
    my $CS = shift;
    my $CS_string = ":encoding($CS)";
    binmode( STDOUT, $CS_string );
    binmode( STDERR, $CS_string );
    binmode( STDIN,  $CS_string );
}

#--------------------------

sub set_CP_Win_console($) {
    # Set code page for console i/o on Windows 
    my $CP = shift;
    if ($^O eq "MSWin32") {
        say "Setting Windows Console CPs to $CP, and matching encoding for STDOUT, etc.";
        if ( ! Win32::SetConsoleOutputCP($CP) ) {
            warn "Cannot set Windows Console Output CP to $CP.\n";
        }
        if ( ! Win32::SetConsoleCP($CP) ) {
            warn "Cannot set Windows Console Input CP to $CP.\n";
        }
        $CS_console = "CP$CP";
        set_STD_encodings( $CS_console );
    }
    else {
        warn "I don't set console CP on non-Windows systems\n";
    }
}

#--------------------------

sub set_CS_defaults() {
    # Set console to use UTF-8
    if ($^O eq "MSWin32") {
        say "Setting console, STDOUT etc to use UTF-8";
        set_CP_Win_console( 65001 );
    }
    else {
        set_STD_encodings( 'UTF-8' );
    }    
}

#--------------------------

sub show_CPs() {
    if ($^O eq "MSWin32") {
        my $CP_in  = Win32::GetConsoleCP();
        my $CP_out = Win32::GetConsoleOutputCP();
        my $CP_sys = Win32::GetACP();
        say "Windows CPs: (in, out, system) = ($CP_in, $CP_out, $CP_sys)";
    }
    else {
        say "CSs are UTF-8";
    }    
}

#==================

# Useful for debugging

sub analyze_string {
    # JCC's utility for showing properties of strings
    my ($m, $s, $bytes) = @_;
    # The string in $s has character semantics unless the third argument is set.
    my $unicode_string = utf8::is_utf8($s);
    my $s1 = $s;
    if (! $bytes ) { $s1 = encode( 'UTF-8', $s ); }
    say "=== $m\nGiven string is '$s'.";
    say(
        'Perl flag = ',
        ($unicode_string ? 'utf8' : 'NOT utf8'),
          ", len = ", length($s)
        );
    my $isNFC = checkNFC($s);
    my $isNFD = checkNFD($s);
    if ($isNFC && $isNFD) { say "Reported to be NFC and NFD, i.e., no relevantaccented characers"; }
    elsif ($isNFC) { say "Reported to be NFC"; }
    elsif ($isNFD) { say "Reported to be NFD"; }
    else { say "Reported to be neither NFC nor NFD"; }
    if ($bytes) { say "Bytes:"; }
    elsif ($s1 eq $s) { say "ASCII string, code points = UTF-8 bytes"; }
    else { say "Code points:"; }
    my @code = unpack( 'U*', $s );
    @code = map { sprintf('%4X', $_) }  @code;
    say join( ' ', @code );
    if($s1 ne $s) {
        say "UTF-8:";
        my @code1 = unpack( 'U*', $s1 );
        @code1 = map { sprintf('%4X', $_) }  @code1;
        say join( ' ', @code1 );
    }
}

#=============================================

# Override by obtaining code pages for Windows

if ($^O eq "MSWin32") {
    eval {  require Win32;
            $CP_Win_system = Win32::GetACP();
            $CS_system = 'CP' . $CP_Win_system;
            $CP_init_Win_console_in = Win32::GetConsoleCP();
            $CP_init_Win_console_out = Win32::GetConsoleOutputCP();
    };
    if ($@) { warn "Trouble finding and setting code pages used by Windows:\n",
              "  $@",
              "  I'LL CONTINUE WITH UTF-8.\n"; 
    }
    else {
        print
        "Initial Win CP for (console input, console output, system): ",
            "(CP$CP_init_Win_console_in, CP$CP_init_Win_console_out, CP$CP_Win_system)\n";
        Win32::SetConsoleCP( 1252 );
    }
}

# Set a sensible default for STD i/o
set_CS_defaults();

# Ensure that on ctrl/C interruption, etc, the END block is obeyed, and Windows console CPs are restored:
use sigtrap qw(die untrapped normal-signals);
END {
    # Restore initial state of console
    if ($^O eq "MSWin32") {
        warn "Reverting Windows console CPs to ",
             "(in,out) = ($CP_init_Win_console_in,$CP_init_Win_console_out)\n";
        Win32::SetConsoleCP($CP_init_Win_console_in);
        Win32::SetConsoleOutputCP($CP_init_Win_console_out);
    }
    # Don't worry about what to do with STDOUT, etc; it should be unimportant from here.
}




1;
