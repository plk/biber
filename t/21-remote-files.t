use strict;
use warnings;
use utf8;
no warnings 'utf8' ;

use Test::More tests => 1;

use Biber;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
chdir("t/tdata") ;

# Set up Biber object
my $biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('remote-files.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'C');

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $main = $section->get_list('MAIN');
my $bibentries = $section->bibentries;

my $cu1 = q|  \entry{seuss}{inproceedings}{}
    \name{labelname}{2}{%
      {{McNatt}{M.}{W.~B.}{W.~B.}{}{}{}{}}%
      {{Bieman}{B.}{J.~M.}{J.~M.}{}{}{}{}}%
    }
    \name{author}{2}{%
      {{McNatt}{M.}{W.~B.}{W.~B.}{}{}{}{}}%
      {{Bieman}{B.}{J.~M.}{J.~M.}{}{}{}{}}%
    }
    \list{location}{1}{%
      {Chicago, IL, USA}%
    }
    \strng{namehash}{MWBBJM1}
    \strng{fullhash}{MWBBJM1}
    \field{sortinit}{M}
    \field{labelyear}{2001}
    \count{uniquename}{0}
    \field{abstract}{{Object-oriented (OO) design patterns define collections of interconnected classes that serve a particular purpose. A design pattern is a structural unit in a system built out of patterns, not unlike the way a function is a structural unit in a procedural program or a class is a structural unit in an OO system designed without patterns. When designers treat patterns as structural units, they become concerned with issues such as coupling and cohesion at a new level of abstraction. We examine the notion of pattern coupling to classify how designs may include coupled patterns. We find many examples of coupled patterns; this coupling may be "tight" or "loose", and provides both benefits and costs. We qualitatively assess the goodness of pattern coupling in terms of effects on maintainability, factorability, and reusability when patterns are coupled in various ways}}
    \field{booktitle}{Computer Software and Applications Conference, 2001. COMPSAC 2001. 25th Annual International}
    \field{journaltitle}{Computer Software and Applications Conference, 2001. COMPSAC 2001. 25th Annual International}
    \field{title}{{Coupling of design patterns: common practices and their benefits}}
    \field{year}{2001}
    \field{pages}{574\bibrangedash 579}
    \verb{doi}
    \verb 10.1109/CMPSAC.2001.960670
    \endverb
    \verb{url}
    \verb http://dx.doi.org/10.1109/CMPSAC.2001.960670
    \endverb
  \endentry

|;

is( $out->get_output_entry($main,'seuss'), $cu1, 'Fetch from citeulike - 1') ;


