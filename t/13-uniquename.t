use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 5;

use Biber;
use Biber::Output::BBL;
use Biber::Utils;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
chdir("t/tdata") ;

# Set up Biber object
my $biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('uniquename.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('unicodebbl', 1);

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $bibentries = $biber->sections->get_section('0')->bib;

my $un1 = q|  \entry{un1}{article}{}
    \name{author}{1}{%
      {{Doe}{D.}{John}{J.}{}{}{}{}}%
    }
    \list{publisher}{1}{%
      {A press}%
    }
    \list{location}{1}{%
      {Cambridge}%
    }
    \strng{namehash}{DJ1}
    \strng{fullhash}{DJ1}
    \field{labelalpha}{Doe94}
    \field{sortinit}{D}
    \field{labelyear}{1994}
    \count{uniquename}{2}
    \field{year}{1994}
    \field{title}{Unique 1}
  \endentry

|;

my $un2 = q|  \entry{un2}{article}{}
    \name{author}{1}{%
      {{Doe}{D.}{Edward}{E.}{}{}{}{}}%
    }
    \list{publisher}{1}{%
      {A press}%
    }
    \list{location}{1}{%
      {Cambridge}%
    }
    \strng{namehash}{DE1}
    \strng{fullhash}{DE1}
    \field{labelalpha}{Doe34}
    \field{sortinit}{D}
    \field{labelyear}{1934}
    \count{uniquename}{1}
    \field{year}{1934}
    \field{title}{Unique 2}
  \endentry

|;

my $un3 = q|  \entry{un3}{article}{}
    \name{author}{1}{%
      {{Doe}{D.}{Jane}{J.}{}{}{}{}}%
    }
    \list{publisher}{1}{%
      {A press}%
    }
    \list{location}{1}{%
      {Cambridge}%
    }
    \strng{namehash}{DJ2}
    \strng{fullhash}{DJ2}
    \field{labelalpha}{Doe83}
    \field{sortinit}{D}
    \field{labelyear}{1983}
    \count{uniquename}{2}
    \field{year}{1983}
    \field{title}{Unique 3}
  \endentry

|;

my $un4 = q|  \entry{un4}{article}{}
    \name{author}{2}{%
      {{Doe}{D.}{John}{J.}{}{}{}{}}%
      {{Mills}{M.}{Mike}{M.}{}{}{}{}}%
    }
    \list{publisher}{1}{%
      {A press}%
    }
    \list{location}{1}{%
      {Cambridge}%
    }
    \strng{namehash}{DJ+1}
    \strng{fullhash}{DJMM1}
    \field{labelalpha}{Doe\textbf{+}21}
    \field{sortinit}{D}
    \field{labelyear}{1921}
    \count{uniquename}{0}
    \field{year}{1921}
    \field{title}{Unique 4}
  \endentry

|;

my $un5 = q|  \entry{un5}{article}{}
    \name{author}{2}{%
      {{Doe}{D.}{John}{J.}{}{}{}{}}%
      {{Mills}{M.}{Mike}{M.}{}{}{}{}}%
    }
    \name{shortauthor}{1}{%
      {{Chaps}{C.}{}{}{}{}{}{}}%
    }
    \list{publisher}{1}{%
      {A press}%
    }
    \list{location}{1}{%
      {Cambridge}%
    }
    \strng{namehash}{C1}
    \strng{fullhash}{DJMM1}
    \field{labelalpha}{Cha21}
    \field{sortinit}{D}
    \field{labelyear}{1921}
    \count{uniquename}{0}
    \field{year}{1921}
    \field{title}{Unique 5}
  \endentry

|;


is($out->get_output_entry('un1'), $un1, 'Uniquename requiring full name expansion - 1');
is($out->get_output_entry('un3'), $un3, 'Uniquename requiring full name expansion - 2');
is($out->get_output_entry('un2'), $un2, 'Uniquename requiring initials name expansion');
is($out->get_output_entry('un4'), $un4, 'Namehash and fullhash different due to maxnames setting');
is($out->get_output_entry('un5'), $un5, 'Fullnamshash ignores SHORT* names');

unlink "*.utf8";
