use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 3;

use Biber;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
chdir("t/tdata") ;

# Set up Biber object
my $biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('set-legacy.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('fastsort', 1);

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;

my $string1 = q|  \entry{Elias1955}{set}{}
    \set{Elias1955a,Elias1955b}
    \name{labelname}{1}{}{%
      {{}{Elias}{E.}{P.}{P.}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{}{Elias}{E.}{P.}{P.}{}{}{}{}}%
    }
    \strng{namehash}{EP1}
    \strng{fullhash}{EP1}
    \field{sortinit}{0}
    \field{labelyear}{1955}
    \field{issn}{0096-1000}
    \field{journaltitle}{IRE Transactions on Information Theory}
    \field{month}{3}
    \field{number}{1}
    \field{title}{Predictive coding--I}
    \field{volume}{1}
    \field{year}{1955}
    \field{pages}{16\bibrangedash 24}
    \verb{doi}
    \verb 10.1109/TIT.1955.1055126
    \endverb
    \warn{\item Field 'crossref' is no longer needed in set entries in Biber - ignoring in entry 'Elias1955'}
  \endentry

|;

my $string2 = q|  \entry{Elias1955a}{article}{}
    \inset{Elias1955}
    \name{labelname}{1}{}{%
      {{}{Elias}{E.}{P.}{P.}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{}{Elias}{E.}{P.}{P.}{}{}{}{}}%
    }
    \strng{namehash}{EP1}
    \strng{fullhash}{EP1}
    \field{sortinit}{0}
    \field{issn}{0096-1000}
    \field{journaltitle}{IRE Transactions on Information Theory}
    \field{month}{3}
    \field{number}{1}
    \field{title}{Predictive coding--I}
    \field{volume}{1}
    \field{year}{1955}
    \field{pages}{16\bibrangedash 24}
    \verb{doi}
    \verb 10.1109/TIT.1955.1055126
    \endverb
    \warn{\item Field 'entryset' is no longer needed in set member entries in Biber - ignoring in entry 'Elias1955a'}
  \endentry

|;

my $string3 = q|  \entry{Elias1955b}{article}{}
    \inset{Elias1955}
    \name{labelname}{1}{}{%
      {{}{Elias}{E.}{P.}{P.}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{}{Elias}{E.}{P.}{P.}{}{}{}{}}%
    }
    \strng{namehash}{EP1}
    \strng{fullhash}{EP1}
    \field{sortinit}{0}
    \field{issn}{0096-1000}
    \field{journaltitle}{IRE Transactions on Information Theory}
    \field{month}{3}
    \field{number}{1}
    \field{title}{Predictive coding--II}
    \field{volume}{1}
    \field{year}{1955}
    \field{pages}{24\bibrangedash 33}
    \verb{doi}
    \verb 10.1109/TIT.1955.1055116
    \endverb
    \warn{\item Field 'entryset' is no longer needed in set member entries in Biber - ignoring in entry 'Elias1955b'}
  \endentry

|;

is($out->get_output_entry('elias1955'), $string1, 'Legacy set test 1');
is($out->get_output_entry('elias1955a'), $string2, 'Legacy set test 2');
is($out->get_output_entry('elias1955b'), $string3, 'Legacy set test 3');

unlink "*.utf8";
