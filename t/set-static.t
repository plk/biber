use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 5;

use Biber;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
chdir("t/tdata") ;

# Set up Biber object
my $biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('set-static.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('fastsort', 1);

# Now generate the information
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $main = $section->get_list('MAIN');
my $out = $biber->get_output_obj;

my $string1 = q|  \entry{Static1}{set}{}
    \set{Static2,Static3,Static4}
    \name{labelname}{1}{}{%
      {{}{Bumble}{B\bibinitperiod}{Brian}{B\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{}{Bumble}{B\bibinitperiod}{Brian}{B\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{BB1}
    \strng{fullhash}{BB1}
    \field{sortinit}{0}
    \field{labelyear}{2001}
    \field{annotation}{Some notes}
    \field{title}{Blessed Brains}
    \field{year}{2001}
  \endentry

|;

my $string2 = q|  \entry{Static2}{book}{}
    \inset{Static1}
    \name{labelname}{1}{}{%
      {{}{Bumble}{B\bibinitperiod}{Brian}{B\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{}{Bumble}{B\bibinitperiod}{Brian}{B\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{BB1}
    \strng{fullhash}{BB1}
    \field{sortinit}{0}
    \field{annotation}{Some Blessed Note}
    \field{title}{Blessed Brains}
    \field{year}{2001}
  \endentry

|;

my $string3 = q|  \entry{Static3}{book}{}
    \inset{Static1}
    \name{labelname}{1}{}{%
      {{}{Crenellation}{C\bibinitperiod}{Clive}{C\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{}{Crenellation}{C\bibinitperiod}{Clive}{C\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{CC1}
    \strng{fullhash}{CC1}
    \field{sortinit}{0}
    \field{title}{Castles and Crime}
    \field{year}{2002}
  \endentry

|;

my $string4 = q|  \entry{Static4}{book}{}
    \inset{Static1}
    \name{labelname}{1}{}{%
      {{}{Dingle}{D\bibinitperiod}{Derek}{D\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{}{Dingle}{D\bibinitperiod}{Derek}{D\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{DD1}
    \strng{fullhash}{DD1}
    \field{sortinit}{0}
    \field{title}{Dungeons, Dark and Dangerous}
    \field{year}{2005}
  \endentry

|;

# Labelyear is now here as skiplab is not set for this entry when cited in section
# without citation of a set it is a member of
my $string5 = q|  \entry{Static2}{book}{}
    \name{labelname}{1}{}{%
      {{}{Bumble}{B\bibinitperiod}{Brian}{B\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{}{Bumble}{B\bibinitperiod}{Brian}{B\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{BB1}
    \strng{fullhash}{BB1}
    \field{sortinit}{0}
    \field{labelyear}{2001}
    \field{annotation}{Some Blessed Note}
    \field{title}{Blessed Brains}
    \field{year}{2001}
  \endentry

|;


is($out->get_output_entry($main,'Static1'), $string1, 'Static set test 1');
is($out->get_output_entry($main,'Static2'), $string2, 'Static set test 2');
is($out->get_output_entry($main,'Static3'), $string3, 'Static set test 3');
is($out->get_output_entry($main,'Static4'), $string4, 'Static set test 4');
is($out->get_output_entry($main,'Static2', 1), $string5, 'Static set test 5');

