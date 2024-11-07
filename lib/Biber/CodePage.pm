package Biber::CodePage;
use v5.24;
use strict;
use warnings;
use parent qw(Exporter);
our @EXPORT = qw( decode_CS_system encode_CS_system get_CS_system
                  is_Unicode_system
                  set_CP_Win_console set_CS_defaults  set_STD_encodings );
our @EXPORT_OK = qw( get_CS_log string_analysis );

# Handling of code page issues, especially on Windows.

use Encode qw( encode decode );
use Unicode::Normalize qw( checkNFC checkNFD );

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

our $init_success;
our $verbose = 0;

# Log of what I did, including warnings in sequence
our $log = '';
# Warnings only
our $warnings = '';

#--------------------------

sub CP_format {
    # Can do extra formatting here
    my $s = join( '', @_ ) . "\n";
}
sub CP_log {
    my $s = CP_format(@_); 
    $log .= $s;
    print( $s ) if $verbose;
}
sub CP_warn {
    my $s = CP_format(@_); 
    $log .= $s;
    $warnings .= $s;
    warn $s;
}
#--------------------------


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

sub get_CS_log() {
    return $log;
}

#--------------------------

sub is_Unicode_system() {
    return (uc($CS_system) eq 'UTF-8') || (uc($CS_system) eq 'CP65001');
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
        CP_log( "Setting Windows Console CPs to $CP, and matching encoding for STDOUT, etc.");
        if ( ! Win32::SetConsoleOutputCP($CP) ) {
            CP_warn( "Cannot set Windows Console Output CP to $CP." );
        }
        if ( ! Win32::SetConsoleCP($CP) ) {
            CP_warn( "Cannot set Windows Console Input CP to $CP." );
        }
        $CS_console = "CP$CP";
        set_STD_encodings( $CS_console );
    }
    else {
        CP_warn( "I don't set console CP on non-Windows systems" );
    }
}

#--------------------------

sub set_CS_defaults() {
    # Set console to use UTF-8
    if ($^O eq "MSWin32") {
        CP_log( "Setting console, STDOUT etc to use UTF-8" );
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
        return "Codepage info: Windows CPs: (in, out, system) = ($CP_in, $CP_out, $CP_sys)";
    }
    else {
        return "Codepage info: CSs are UTF-8";
    }
}

#==================

# Useful for debugging, etc

sub string_analysis {
    # JCC's utility for showing properties of strings
    # Usage: e.g.,
    #     say "Code page info: Showing string details:\n",
    #         string_analysis("Code page info: ", $string);
    my ($prefix, $s, $bytes) = @_;
    # The string in $s has character semantics unless the third argument is set.
    # Prefix lines with $prefix.  (Useful if sending result to a logger.)
    # Returned result is an encoded string.  

    # Accumulate lines of analysis results:
    my @result = ();
    my $unicode_string = utf8::is_utf8($s);
    my $s1 = $s;
    if (! $bytes ) { $s1 = encode( 'UTF-8', $s ); }
    push @result, "Given string is '$s'.";
    push @result, 'Perl flag = ' . ($unicode_string ? 'utf8' : 'NOT utf8')
                  . ", len = " . length($s);
    my $isNFC = checkNFC($s);
    my $isNFD = checkNFD($s);
    if ($isNFC && $isNFD) {
        push @result,
            "Reported to be NFC and NFD, i.e., no relevant accented characers";
    }
    elsif ($isNFC) { push @result, "Reported to be NFC"; }
    elsif ($isNFD) { push @result, "Reported to be NFD"; }
    else { push @result, "Reported to be neither NFC nor NFD"; }
    if ($bytes) { push @result, "Bytes:"; }
    elsif ($s1 eq $s) { push @result, "ASCII string, code points = UTF-8 bytes"; }
    else { push @result, "Code points:"; }
    my @code = unpack( 'U*', $s );
    @code = map { sprintf('%4X', $_) }  @code;
    push @result, join( ' ', @code );
    if($s1 ne $s) {
        push @result, "UTF-8:";
        my @code1 = unpack( 'U*', $s1 );
        @code1 = map { sprintf('%4X', $_) }  @code1;
        push @result, join( ' ', @code1 );
    }
    foreach (@result) { $_ = "$prefix$_"; }
    return join( "\n", @result );
}

#=============================================

# On Windows, obtain current code page values.
# The console code pages will be restored on exit.
# This code is executed in Perl's compile phase for this module, before any
# other code gets a chance to change the console code pages (including me).


$init_success = 1;
if ($^O eq "MSWin32") {
    eval {  require Win32;
            $CP_Win_system = Win32::GetACP();
            $CS_system = 'CP' . $CP_Win_system;
            $CP_init_Win_console_in = Win32::GetConsoleCP();
            $CP_init_Win_console_out = Win32::GetConsoleOutputCP();
    };
    if ($@) { CP_warn( "Trouble finding and setting code pages used by Windows:",
                       "  $@",
                       "  I'LL CONTINUE WITH UTF-8." ); 
              $init_success = 0;
    }
    else {
        CP_log( 
            "Initial Win CP for (console input, console output, system): ".
            "(CP$CP_init_Win_console_in, CP$CP_init_Win_console_out, CP$CP_Win_system)" );
        CP_log( "At program termination will revert Windows console CPs to ",
                "(in,out) = ($CP_init_Win_console_in,$CP_init_Win_console_out)" );
    }
}

# Make the following settings at start of program execution, not at module
# compile time.  Otherwise when there are errors in later parts of
# compilation, the console CPs will be changed, but the END block to restore
# them will not be executed.
INIT {
    # Set a sensible defaults for STD i/o, for consistency of screen output
    # across operating systems.
    set_CS_defaults();
}

# Ensure that on ctrl/C interruption, etc, the END block is obeyed, and Windows console CPs are restored:
use sigtrap qw(die untrapped normal-signals);
END {
    # Restore initial state of console
    if ($^O eq "MSWin32") {
        CP_log( "Resetting console CPs to (in, out) = ",
                "($CP_init_Win_console_in, $CP_init_Win_console_in)" ); 
        Win32::SetConsoleCP($CP_init_Win_console_in);
        Win32::SetConsoleOutputCP($CP_init_Win_console_out);
    }
    # Don't worry about what to do with STDOUT, etc; it should be unimportant from here.
}

1;
