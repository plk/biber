# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8' ;

use Test::More tests => 34;
use Biber;
use Biber::Entry::Name;
use Biber::Entry::Names;
use Biber::Utils;
use Biber::LaTeX::Recode;
use Log::Log4perl;
use IPC::Cmd qw( can_run );
use Cwd;
use Unicode::Normalize;
my $cwd = getcwd;

my $biber = Biber->new(noconf => 1);
my $LEVEL = 'ERROR';
my $l4pconf = qq|
    log4perl.category.main                             = $LEVEL, Screen
    log4perl.category.screen                           = $LEVEL, Screen
    log4perl.appender.Screen                           = Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.utf8                      = 1
    log4perl.appender.Screen.Threshold                 = $LEVEL
    log4perl.appender.Screen.stderr                    = 0
    log4perl.appender.Screen.layout                    = Log::Log4perl::Layout::SimpleLayout
|;
Log::Log4perl->init(\$l4pconf);

# NFD/NFC calls below as we are accessing internal functions which assume NFD and results strings
# which assume NFC.

# File locating
# Using File::Spec->canonpath() to normalise path separators so these tests work
# on Windows/non-Windows
# Absolute path
is(File::Spec->canonpath(locate_biber_file("$cwd/t/tdata/general1.bcf")), File::Spec->canonpath("$cwd/t/tdata/general1.bcf"), 'File location - 1');
# Relative path
is(File::Spec->canonpath(locate_biber_file('t/tdata/general1.bcf')), File::Spec->canonpath('t/tdata/general1.bcf'), 'File location - 2');
# Same place as control file
Biber::Config->set_ctrlfile_path('t/tdata/general1.bcf');
is(File::Spec->canonpath(locate_biber_file('t/tdata/examples.bib')), File::Spec->canonpath('t/tdata/examples.bib'), 'File location - 3');

# The \cM* is there because if cygwin picks up miktex kpsewhich, it will return a path
# with a Ctrl-M on the end
# Testing using a file guaranteed to be installed with any latex install
SKIP: {
  skip "No LaTeX installation", 1 unless can_run('kpsewhich');
  # using kpsewhich
  like(File::Spec->canonpath(locate_biber_file('plain.tex')), qr|plain.tex\cM*\z|, 'File location - 4');
    }

# In output_directory
Biber::Config->setoption('output_directory', 't/tdata');
is(File::Spec->canonpath(locate_biber_file('general1.bcf')), File::Spec->canonpath("t/tdata/general1.bcf"), 'File location - 5');

# String normalising
is( normalise_string('"a, b–c: d" ', 1),  'a bc d', 'normalise_string' );

Biber::Config->setoption('output_encoding', 'UTF-8');
is( NFC(normalise_string_underscore(latex_decode('\c Se\x{c}\"ok-\foo{a},  N\`i\~no
    $§+ :-)   ', strip_outer_braces => 1), 0)), 'Şecöka_Nìño', 'normalise_string_underscore 1' );

is( normalise_string_underscore('{Foo de Bar, Graf Ludwig}', 1), 'Foo_de_Bar_Graf_Ludwig', 'normalise_string_underscore 3');

# LaTeX decoding/encoding
is( NFC(latex_decode('Mu\d{h}ammad ibn M\=us\=a al-Khw\=arizm\={\i} \r{a}')), 'Muḥammad ibn Mūsā al-Khwārizmī å', 'latex decode 1');
is( latex_decode('\alpha'), '\alpha', 'latex decode 2'); # no greek decoding by default
is( latex_decode('\textless\textampersand'), '<&', 'latex decode 3'); # checking XML encoding bits
is( latex_encode(NFD('Muḥammad ibn Mūsā al-Khwārizmī')), 'Mu\d{h}ammad ibn M\={u}s\={a} al-Khw\={a}rizm\={\i}', 'latex encode 1');
is( latex_encode(NFD('α')), 'α', 'latex encode 2'); # no greek encoding by default

Biber::LaTeX::Recode->init_sets('full', 'full'); # Need to do this to reset

is( latex_decode('\alpha'), 'α', 'latex decode 4'); # greek decoding with "full"
is( NFC(latex_decode("\\'\\i")), 'í', 'latex decode 5'); # checking i with accents
is( NFC(latex_decode("\\^{\\j}")), 'ĵ', 'latex decode 6'); # checking j with accents
is( latex_decode('\i'), 'ı', 'latex decode 7'); # checking dotless i
is( latex_decode('\j'), 'ȷ', 'latex decode 8'); # checking dotless j
is( latex_decode('\textdiv'), '÷', 'latex decode 9'); # checking multiple set for types
is( latex_decode('\textbackslash'), "\\", 'latex decode 10'); # checking multiple set for types
is( latex_decode('--'), '--', 'latex decode 11'); # Testing raw
is( latex_encode(NFD('α')), '{$\alpha$}', 'latex encode 3'); # greek encoding with "full"
is( latex_encode(NFD('µ')), '{$\mu$}', 'latex encode 4'); # Testing symbols
is( latex_encode(NFD('≄')), '{$\not\simeq$}', 'latex encode 5'); # Testing negated symbols
is( latex_encode(NFD('Þ')), '{\TH}', 'latex encode 6'); # Testing preferred
is( latex_encode('$'), '$', 'latex encode 7'); # Testing exclude
is( latex_encode(NFD('–')), '--', 'latex encode 8'); # Testing raw


my @arrayA = qw/ a b c d e f c /;
my @arrayB = qw/ c e /;
my @AminusB = reduce_array(\@arrayA, \@arrayB);
my @AminusBexpected = qw/ a b d f /;

is_deeply(\@AminusB, \@AminusBexpected, 'reduce_array') ;

is(remove_outer('{Some string}'), 'Some string', 'remove_outer') ;

is( normalise_string_hash('Ä.~{\c{C}}.~{\c S}.'), 'Äc:Cc:S', 'normalise_string_lite' ) ;

Biber::LaTeX::Recode->init_sets('base', 'full'); # Need to do this to reset
is( latex_decode('\textdiv'), '\textdiv', 'latex different encode/decode sets 1');
is( latex_encode(NFD('÷')), '{$\div$}', 'latex different encode/decode sets 2');

Biber::LaTeX::Recode->init_sets('null', 'full'); # Need to do this to reset
is( latex_decode('\i'), '\i', 'latex null decode 1');
is( latex_encode(NFD('ı')), '{\i}', 'latex null encode 2');

