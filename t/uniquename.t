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

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $main = $section->get_list('MAIN');
my $bibentries = $section->bibentries;

my $un1 = q|  \entry{un1}{book}{}
    \name{labelname}{1}{%
      {{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
    }
    \list{location}{1}{%
      {Cambridge}%
    }
    \list{publisher}{1}{%
      {A press}%
    }
    \strng{namehash}{DJ1}
    \strng{fullhash}{DJ1}
    \field{labelalpha}{Doe94}
    \field{sortinit}{D}
    \field{labelyear}{1994}
    \count{uniquename}{2}
    \field{title}{Unique 1}
    \field{year}{1994}
  \endentry

|;

my $un2 = q|  \entry{un2}{book}{}
    \name{labelname}{1}{%
      {{Doe}{D\bibinitperiod}{Edward}{E\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Doe}{D\bibinitperiod}{Edward}{E\bibinitperiod}{}{}{}{}}%
    }
    \list{location}{1}{%
      {Cambridge}%
    }
    \list{publisher}{1}{%
      {A press}%
    }
    \strng{namehash}{DE1}
    \strng{fullhash}{DE1}
    \field{labelalpha}{Doe34}
    \field{sortinit}{D}
    \field{labelyear}{1934}
    \count{uniquename}{1}
    \field{title}{Unique 2}
    \field{year}{1934}
  \endentry

|;

my $un3 = q|  \entry{un3}{book}{}
    \name{labelname}{1}{%
      {{Doe}{D\bibinitperiod}{Jane}{J\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Doe}{D\bibinitperiod}{Jane}{J\bibinitperiod}{}{}{}{}}%
    }
    \list{location}{1}{%
      {Cambridge}%
    }
    \list{publisher}{1}{%
      {A press}%
    }
    \strng{namehash}{DJ2}
    \strng{fullhash}{DJ2}
    \field{labelalpha}{Doe83}
    \field{sortinit}{D}
    \field{labelyear}{1983}
    \count{uniquename}{2}
    \field{title}{Unique 3}
    \field{year}{1983}
  \endentry

|;

my $un4 = q|  \entry{un4}{book}{}
    \name{labelname}{2}{%
      {{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
      {{Mills}{M\bibinitperiod}{Mike}{M\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{2}{%
      {{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
      {{Mills}{M\bibinitperiod}{Mike}{M\bibinitperiod}{}{}{}{}}%
    }
    \list{location}{1}{%
      {Cambridge}%
    }
    \list{publisher}{1}{%
      {A press}%
    }
    \strng{namehash}{DJ+1}
    \strng{fullhash}{DJMM1}
    \field{labelalpha}{Doe\textbf{+}21}
    \field{sortinit}{D}
    \field{labelyear}{1921}
    \count{uniquename}{0}
    \field{title}{Unique 4}
    \field{year}{1921}
  \endentry

|;

my $un5 = q|  \entry{un5}{book}{}
    \name{labelname}{1}{%
      {{Chaps}{C\bibinitperiod}{}{}{}{}{}{}}%
    }
    \name{author}{2}{%
      {{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
      {{Mills}{M\bibinitperiod}{Mike}{M\bibinitperiod}{}{}{}{}}%
    }
    \name{shortauthor}{1}{%
      {{Chaps}{C\bibinitperiod}{}{}{}{}{}{}}%
    }
    \list{location}{1}{%
      {Cambridge}%
    }
    \list{publisher}{1}{%
      {A press}%
    }
    \strng{namehash}{C1}
    \strng{fullhash}{DJMM1}
    \field{labelalpha}{Cha21}
    \field{sortinit}{D}
    \field{labelyear}{1921}
    \count{uniquename}{0}
    \field{title}{Unique 5}
    \field{year}{1921}
  \endentry

|;


is($out->get_output_entry($main,'un1'), $un1, 'Uniquename requiring full name expansion - 1');
is($out->get_output_entry($main,'un3'), $un3, 'Uniquename requiring full name expansion - 2');
is($out->get_output_entry($main,'un2'), $un2, 'Uniquename requiring initials name expansion');
is($out->get_output_entry($main,'un4'), $un4, 'Namehash and fullhash different due to maxnames setting');
is($out->get_output_entry($main,'un5'), $un5, 'Fullnamshash ignores SHORT* names');

unlink <*.utf8>;
