use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 14;

use Biber;
use Biber::Utils;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

my $biber = Biber->new( unicodebbl => 1, fastsort => 1, noconf => 1 );

chdir("t/tdata") ;
$biber->parse_auxfile('skips.aux');

my $bibfile = Biber::Config->getoption('bibdata')->[0] . ".bib";
$biber->parse_bibtex($bibfile);

$biber->prepare;
my $bibentries = $biber->bib;

my $set1 = q|\entry{seta}{set}{}
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
  \field{crossref}{set:membera}
\endentry

|;

my $set2 = q|\entry{set:membera}{book}{}
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

my $set3 = q|\entry{set:memberb}{book}{}
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

my $set4 = q|\entry{set:memberc}{book}{}
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

my $noset1 = q|\entry{noseta}{book}{}
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

my $noset2 = q|\entry{nosetb}{book}{}
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

my $noset3 = q|\entry{nosetc}{book}{}
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


is_deeply([$biber->shorthands], ['skip1'], 'skiplos - not in LOS');
is($bibentries->entry('skip2')->get_field('labelalpha'), 'SA', 'Normal labelalpha');
is($bibentries->entry('skip2')->get_field($bibentries->entry('skip2')->get_field('labelyearname')), '1995', 'Normal labelyear');
ok(is_undef($bibentries->entry('skip3')->get_field('labelalpha')), 'skiplab - no labelalpha');
ok(is_undef($bibentries->entry('skip3')->get_field('labelyearname')), 'skiplab - no labelyear');
ok(is_undef($bibentries->entry('skip4')->get_field('labelalpha')), 'dataonly - no labelalpha');
ok(is_undef($bibentries->entry('skip4')->get_field('labelyearname')), 'dataonly - no labelyear');
is($biber->_print_biblatex_entry('seta'), $set1, 'Set parent - with labels');
is($biber->_print_biblatex_entry('set:membera'), $set2, 'Set member - no labels 1');
is($biber->_print_biblatex_entry('set:memberb'), $set3, 'Set member - no labels 2');
is($biber->_print_biblatex_entry('set:memberc'), $set4, 'Set member - no labels 3');
is($biber->_print_biblatex_entry('noseta'), $noset1, 'Not a set member - extrayear continues from set 1');
is($biber->_print_biblatex_entry('nosetb'), $noset2, 'Not a set member - extrayear continues from set 2');
is($biber->_print_biblatex_entry('nosetc'), $noset3, 'Not a set member - extrayear continues from set 3');


unlink "$bibfile.utf8";
