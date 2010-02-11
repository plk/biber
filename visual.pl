# Module::Build "Build test" invokes this after all test scripts to provide some user
# feedback. See the manual for Module::Build. The name of this script is not arbitrary.
use Biber;

BEGIN {
  push @INC, 'blib/lib/';
}

print "Finished testing Biber $Biber::VERSION using Perl $] at $^X\n";
