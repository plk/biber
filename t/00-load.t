#!perl -T

use Test::More tests => 7;

BEGIN {
	use_ok( 'Biber' );
	use_ok( 'Biber::Constants' );
	use_ok( 'Biber::Internals' );
	use_ok( 'Biber::Utils' );
	use_ok( 'Biber::BibTeX' );
	use_ok( 'Biber::BibTeX::PRD' );
	use_ok( 'LaTeX::Decode' );
}

diag( "Testing Biber $Biber::VERSION, Perl $], $^X" );
