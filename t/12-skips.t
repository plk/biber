use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 14;

use Biber;
use Biber::Utils;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
chdir("t/tdata") ;

my $biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('skips.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('fastsort', 1);

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $bibentries = $section->bibentries;

my $set1 = q|  \entry{seta}{set}{}
    \set{set:membera,set:memberb,set:memberc}
    \name{author}{1}{%
      {{Doe}{D.}{John}{J.}{}{}{}{}}%
    }
    \strng{namehash}{DJ1}
    \strng{fullhash}{DJ1}
    \field{labelalpha}{Doe10}
    \field{sortinit}{D}
    \field{extrayear}{1}
    \field{labelyear}{2010}
    \field{extraalpha}{1}
    \field{year}{2010}
    \field{title}{Set Member A}
    \strng{crossref}{set:membera}
  \endentry

|;

my $set2 = q|  \entry{set:membera}{book}{}
    \inset{set}
    \name{author}{1}{%
      {{Doe}{D.}{John}{J.}{}{}{}{}}%
    }
    \strng{namehash}{DJ1}
    \strng{fullhash}{DJ1}
    \field{sortinit}{D}
    \field{year}{2010}
    \field{title}{Set Member A}
  \endentry

|;

my $set3 = q|  \entry{set:memberb}{book}{}
    \inset{set}
    \name{author}{1}{%
      {{Doe}{D.}{John}{J.}{}{}{}{}}%
    }
    \strng{namehash}{DJ1}
    \strng{fullhash}{DJ1}
    \field{sortinit}{D}
    \field{year}{2010}
    \field{title}{Set Member B}
  \endentry

|;

my $set4 = q|  \entry{set:memberc}{book}{}
    \inset{set}
    \name{author}{1}{%
      {{Doe}{D.}{John}{J.}{}{}{}{}}%
    }
    \strng{namehash}{DJ1}
    \strng{fullhash}{DJ1}
    \field{sortinit}{D}
    \field{year}{2010}
    \field{title}{Set Member C}
  \endentry

|;

my $noset1 = q|  \entry{noseta}{book}{}
    \name{author}{1}{%
      {{Doe}{D.}{John}{J.}{}{}{}{}}%
    }
    \strng{namehash}{DJ1}
    \strng{fullhash}{DJ1}
    \field{labelalpha}{Doe10}
    \field{sortinit}{D}
    \field{extrayear}{2}
    \field{labelyear}{2010}
    \field{extraalpha}{2}
    \field{year}{2010}
    \field{title}{Stand-Alone A}
  \endentry

|;

my $noset2 = q|  \entry{nosetb}{book}{}
    \name{author}{1}{%
      {{Doe}{D.}{John}{J.}{}{}{}{}}%
    }
    \strng{namehash}{DJ1}
    \strng{fullhash}{DJ1}
    \field{labelalpha}{Doe10}
    \field{sortinit}{D}
    \field{extrayear}{3}
    \field{labelyear}{2010}
    \field{extraalpha}{3}
    \field{year}{2010}
    \field{title}{Stand-Alone B}
  \endentry

|;

my $noset3 = q|  \entry{nosetc}{book}{}
    \name{author}{1}{%
      {{Doe}{D.}{John}{J.}{}{}{}{}}%
    }
    \strng{namehash}{DJ1}
    \strng{fullhash}{DJ1}
    \field{labelalpha}{Doe10}
    \field{sortinit}{D}
    \field{extrayear}{4}
    \field{labelyear}{2010}
    \field{extraalpha}{4}
    \field{year}{2010}
    \field{title}{Stand-Alone C}
  \endentry

|;


is_deeply([$section->get_shorthands], ['skip1'], 'skiplos - not in LOS');
is($bibentries->entry('skip2')->get_field('labelalpha'), 'SA', 'Normal labelalpha');
is($bibentries->entry('skip2')->get_field($bibentries->entry('skip2')->get_field('labelyearname')), '1995', 'Normal labelyear');
ok(is_undef($bibentries->entry('skip3')->get_field('labelalpha')), 'skiplab - no labelalpha');
ok(is_undef($bibentries->entry('skip3')->get_field('labelyearname')), 'skiplab - no labelyear');
ok(is_undef($bibentries->entry('skip4')->get_field('labelalpha')), 'dataonly - no labelalpha');
ok(is_undef($bibentries->entry('skip4')->get_field('labelyearname')), 'dataonly - no labelyear');
is($out->get_output_entry('seta'), $set1, 'Set parent - with labels');
is($out->get_output_entry('set:membera'), $set2, 'Set member - no labels 1');
is($out->get_output_entry('set:memberb'), $set3, 'Set member - no labels 2');
is($out->get_output_entry('set:memberc'), $set4, 'Set member - no labels 3');
is($out->get_output_entry('noseta'), $noset1, 'Not a set member - extrayear continues from set 1');
is($out->get_output_entry('nosetb'), $noset2, 'Not a set member - extrayear continues from set 2');
is($out->get_output_entry('nosetc'), $noset3, 'Not a set member - extrayear continues from set 3');


unlink "*.utf8";
