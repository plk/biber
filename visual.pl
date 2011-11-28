# Module::Build "Build test" invokes this after all test scripts to provide some user
# feedback. See the manual for Module::Build. The name of this script is not arbitrary.
use Biber;

BEGIN {
  push @INC, 'blib/lib/';
}

my $v = $Biber::Config::VERSION;
$v .= ' (beta)' if $Biber::Config::BETA_VERSION;

print "Finished testing biber $v using Perl $] at $^X\n";
