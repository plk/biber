use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 7;

use Biber;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

my $biber = Biber->new( unicodebbl => 1, fastsort => 1 );

isa_ok($biber, "Biber");

chdir("t/tdata") ;
$biber->parse_auxfile_v2('sort-complex.aux');

my $bibfile = Biber::Config->getoption('bibdata')->[0] . ".bib";
$biber->parse_bibtex($bibfile);
Biber::Config->setblxoption('labelalpha', 1);
Biber::Config->setblxoption('labelyear', undef);
$biber->prepare;

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

my $sc3 = q|\entry{L4}{book}{}
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
  \count{uniquename}{0}
  \field{year}{1995}
  \field{title}{Some title about sorting}
\endentry

|;

my $sc4 = q|\entry{L1}{article}{}
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
  \count{uniquename}{0}
  \field{year}{1995}
  \field{title}{Algorithms For Sorting}
\endentry

|;

my $sc5 = q|\entry{L2}{article}{}
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
  \count{uniquename}{0}
  \field{year}{1995}
  \field{title}{Sorting Algorithms}
\endentry

|;

my $sc6 = q|\entry{L3}{article}{}
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
  \count{uniquename}{0}
  \field{year}{1995}
  \field{title}{More and More Algorithms}
\endentry

|;




is_deeply( Biber::Config->getblxoption('sorting_label') , $sc1, 'first pass scheme');
is_deeply( Biber::Config->getblxoption('sorting_final') , $sc2, 'second pass scheme');
is( $biber->_print_biblatex_entry('l4'), $sc3, '\alphaothers set by "and others"');
is( $biber->_print_biblatex_entry('l1'), $sc4, '2-pass - labelalpha after title');
is( $biber->_print_biblatex_entry('l2'), $sc5, '2-pass - labelalpha after title');
is( $biber->_print_biblatex_entry('l3'), $sc6, '2-pass - labelalpha after title');


unlink "$bibfile.utf8";

