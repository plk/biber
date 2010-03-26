use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 7;

use Biber;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
chdir("t/tdata") ;

# Set up Biber object
my $biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('sort-complex.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('unicodebbl', 1);

# Biblatex options
Biber::Config->setblxoption('labelalpha', 1);
Biber::Config->setblxoption('labelyear', undef);

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;

isa_ok($biber, "Biber");

my $sc1 = [
           [
            {'labelalpha'    => {}},
           ],
           [
            {'presort'    => {}},
            {'mm'         => {}},
           ],
           [
            {'sortkey'    => {'final' => 1}}
           ],
           [
            {'sortname'   => {}},
            {'author'     => {}},
            {'editor'     => {}},
            {'translator' => {}},
            {'sorttitle'  => {}},
            {'title'      => {}}
           ],
           [
            {'sortyear'  => {sort_direction => 'descending'}},
            {'year'      => {substring_side => 'right',
                             substring_width => '4'}}
           ],
           [
            {'volume'     => {pad_char => '0'}},
            {'0000'       => {}}
           ],
           [
            {'sorttitle'       => {}},
            {'title'       => {}}
           ],
          ];

my $sc2 = [
           [
            {'presort'    => {}},
            {'mm'         => {}},
           ],
           [
            {'labelalpha'    => {}},
           ],
           [
            {'extraalpha'     => {pad_side => 'left',
                                 pad_width => 4,
                                 pad_char => '0'}},
           ],
           [
            {'sortkey'    => {'final' => 1}}
           ],
           [
            {'sortname'   => {}},
            {'author'     => {}},
            {'editor'     => {}},
            {'translator' => {}},
            {'sorttitle'  => {}},
            {'title'      => {}}
           ],
           [
            {'sortyear'  => {sort_direction => 'descending'}},
            {'year'      => {substring_side => 'right',
                             substring_width => '4'}}
           ],
           [
            {'volume'     => {pad_char => '0'}},
            {'0000'       => {}}
           ],
           [
            {'sorttitle'       => {}},
            {'title'       => {}}
           ],
          ];

my $sc3 = q|  \entry{L4}{book}{}
    \true{moreauthor}
    \name{author}{1}{%
      {{Doe}{D.}{John}{J.}{}{}{}{}}%
    }
    \list{publisher}{1}{%
      {Another press}%
    }
    \list{location}{1}{%
      {Cambridge}%
    }
    \strng{namehash}{DJo1}
    \strng{fullhash}{DJo1}
    \field{labelalpha}{Doe\textbf{+}95}
    \field{sortinit}{D}
    \field{extraalpha}{2}
    \field{year}{1995}
    \field{title}{Some title about sorting}
  \endentry

|;

my $sc4 = q|  \entry{L1}{article}{}
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
    \field{labelalpha}{Doe95}
    \field{sortinit}{D}
    \field{extraalpha}{1}
    \field{year}{1995}
    \field{title}{Algorithms For Sorting}
  \endentry

|;

my $sc5 = q|  \entry{L2}{article}{}
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
    \field{labelalpha}{Doe95}
    \field{sortinit}{D}
    \field{extraalpha}{3}
    \field{year}{1995}
    \field{title}{Sorting Algorithms}
  \endentry

|;

my $sc6 = q|  \entry{L3}{article}{}
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
    \field{labelalpha}{Doe95}
    \field{sortinit}{D}
    \field{extraalpha}{2}
    \field{year}{1995}
    \field{title}{More and More Algorithms}
  \endentry

|;

is_deeply( Biber::Config->getblxoption('sorting_label') , $sc1, 'first pass scheme');
is_deeply( Biber::Config->getblxoption('sorting_final') , $sc2, 'second pass scheme');
is( $out->get_output_entry('l4'), $sc3, '\alphaothers set by "and others"');
is( $out->get_output_entry('l1'), $sc4, '2-pass - labelalpha after title');
is( $out->get_output_entry('l2'), $sc5, '2-pass - labelalpha after title');
is( $out->get_output_entry('l3'), $sc6, '2-pass - labelalpha after title');


unlink "*.utf8";

