use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 8;

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

# Biblatex options
Biber::Config->setblxoption('labelalpha', 1);
Biber::Config->setblxoption('labelyear', undef);

# Now generate the information
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $main = $section->get_list('MAIN');
my $out = $biber->get_output_obj;

isa_ok($biber, "Biber");

my $sc1 = [
           [
            {},
            {'presort'    => {}}
           ],
           [
            {},
            {'labelalpha'    => {}},
           ],
           [
            {final          => 1,
             },
            {'sortkey'    => {}}
           ],
           [
            {},
            {'sortname'   => {}},
            {'author'     => {}},
            {'editor'     => {}},
            {'translator' => {}},
            {'sorttitle'  => {}},
            {'title'      => {}}
           ],
           [
            {},
            {'sortyear'  => {}},
            {'year'      => {}}
           ],
           [
            {},
            {'sorttitle'       => {}},
            {'title'       => {}}
           ],
           [
            {},
            {'volume'     => {pad_char => '0',
                              pad_side => 'left',
                              pad_width => '4'}},
            {'0000'       => {}}
           ],
          ];

my $sc2 = [
           [
            {},
            {'presort'    => {}}
           ],
           [
            {final          => 1,
             },
            {'sortkey'    => {}}
           ],
           [
            {},
            {'labelalpha'    => {}},
           ],
           [
            {},
            {'extraalpha'     => {pad_side => 'left',
                                 pad_width => 4,
                                 pad_char => '0'}},
           ],
           [
            {},
            {'sortname'   => {}},
            {'author'     => {}},
            {'editor'     => {}},
            {'translator' => {}},
            {'sorttitle'  => {}},
            {'title'      => {}}
           ],
           [
            {},
            {'sortyear'  => {}},
            {'year'      => {}}
           ],
           [
            {},
            {'sorttitle'       => {}},
            {'title'       => {}}
           ],
           [
            {},
            {'volume'     => {pad_char => '0',
                              pad_side => 'left',
                              pad_width => '4'}},
            {'0000'       => {}}
           ],
          ];

my $sc3 = q|  \entry{L4}{book}{}
    \true{morelabelname}
    \name{labelname}{1}{%
      {{Doe}{D.}{John}{J.}{}{}{}{}}%
    }
    \true{moreauthor}
    \name{author}{1}{%
      {{Doe}{D.}{John}{J.}{}{}{}{}}%
    }
    \list{location}{1}{%
      {Cambridge}%
    }
    \list{publisher}{1}{%
      {Another press}%
    }
    \strng{namehash}{DJo1}
    \strng{fullhash}{DJo1}
    \field{labelalpha}{Doe\textbf{+}95}
    \field{sortinit}{D}
    \field{extraalpha}{2}
    \field{title}{Some title about sorting}
    \field{year}{1995}
  \endentry

|;

my $sc4 = q|  \entry{L1}{book}{}
    \name{labelname}{1}{%
      {{Doe}{D.}{John}{J.}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Doe}{D.}{John}{J.}{}{}{}{}}%
    }
    \list{location}{1}{%
      {Cambridge}%
    }
    \list{publisher}{1}{%
      {A press}%
    }
    \strng{namehash}{DJ1}
    \strng{fullhash}{DJ1}
    \field{labelalpha}{Doe95}
    \field{sortinit}{D}
    \field{extraalpha}{1}
    \field{title}{Algorithms For Sorting}
    \field{year}{1995}
  \endentry

|;

my $sc5 = q|  \entry{L2}{book}{}
    \name{labelname}{1}{%
      {{Doe}{D.}{John}{J.}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Doe}{D.}{John}{J.}{}{}{}{}}%
    }
    \list{location}{1}{%
      {Cambridge}%
    }
    \list{publisher}{1}{%
      {A press}%
    }
    \strng{namehash}{DJ1}
    \strng{fullhash}{DJ1}
    \field{labelalpha}{Doe95}
    \field{sortinit}{D}
    \field{extraalpha}{3}
    \field{title}{Sorting Algorithms}
    \field{year}{1995}
  \endentry

|;

my $sc6 = q|  \entry{L3}{book}{}
    \name{labelname}{1}{%
      {{Doe}{D.}{John}{J.}{}{}{}{}}%
    }
    \name{author}{1}{%
      {{Doe}{D.}{John}{J.}{}{}{}{}}%
    }
    \list{location}{1}{%
      {Cambridge}%
    }
    \list{publisher}{1}{%
      {A press}%
    }
    \strng{namehash}{DJ1}
    \strng{fullhash}{DJ1}
    \field{labelalpha}{Doe95}
    \field{sortinit}{D}
    \field{extraalpha}{2}
    \field{title}{More and More Algorithms}
    \field{year}{1995}
  \endentry

|;

is_deeply( $main->get_sortspec->{label} , $sc1, 'first pass scheme');
is_deeply( $main->get_sortspec->{final} , $sc2, 'second pass scheme');
is( $out->get_output_entry($main,'l4'), $sc3, '\alphaothers set by "and others"');
is( $out->get_output_entry($main,'l1'), $sc4, '2-pass - labelalpha after title');
is( $out->get_output_entry($main,'l2'), $sc5, '2-pass - labelalpha after title');
is( $out->get_output_entry($main,'l3'), $sc6, '2-pass - labelalpha after title');
is_deeply([ $main->get_keys ], ['L5', 'L4', 'L1', 'L3', 'L2'], 'citeorder - 1');


unlink <*.utf8>;
