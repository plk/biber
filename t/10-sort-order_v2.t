use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 2;
use Storable qw (dclone);

use Biber;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

my $opts = { unicodebbl => 1, fastsort => 1 };
my $biber = Biber->new($opts);

isa_ok($biber, "Biber");
my $ctrlver = $biber->getblxoption('controlversion');
chdir("t/tdata") ;
$biber->parse_auxfile_v2('70-sort-order_v2.aux');

my $bibfile = $biber->config('bibdata')->[0] . ".bib";
$biber->parse_bibtex($bibfile);

$biber->{config}{biblatex}{global}{sorting_label} =  [
                                                      [
                                                       {'citeorder'    => {}}
                                                      ]
                                                     ];
$biber->{config}{biblatex}{global}{sorting_final} = dclone($biber->{config}{biblatex}{global}{sorting_label});
$biber->prepare;

my $sc1 = q|\entry{L2}{article}{}
  \name{author}{1}{%
    {{Britherthwaite}{B.}{Brian}{B.}{}{}{}{}}%
  }
  \list{publisher}{1}{%
    {British Bulldog Press}%
  }
  \list{location}{1}{%
    {Bridlington}%
  }
  \strng{namehash}{BB1}
  \strng{fullhash}{BB1}
  \field{sortinit}{B}
  \count{uniquename}{0}
  \field{title}{Best Barnacled Boat Bottoms}
  \field{year}{2004}
\endentry

\entry{L1}{article}{}
  \name{author}{1}{%
    {{Adamson}{A.}{Aaron}{A.}{}{}{}{}}%
  }
  \list{publisher}{1}{%
    {Aardvark Press}%
  }
  \list{location}{1}{%
    {Arlington Press}%
  }
  \strng{namehash}{AA1}
  \strng{fullhash}{AA1}
  \field{sortinit}{A}
  \count{uniquename}{0}
  \field{title}{Anarchic Ambidexstrous Anomalies}
  \field{year}{1995}
\endentry

\entry{L4}{book}{}
  \name{author}{2}{%
    {{Ditherington}{D.}{Derek}{D.}{}{}{}{}}%
    {{Dumpton}{D.}{David}{D.}{}{}{}{}}%
  }
  \list{publisher}{2}{%
    {Dright}%
    {Drought Press}%
  }
  \list{location}{1}{%
    {Dunbar}%
  }
  \strng{namehash}{DDDD1}
  \strng{fullhash}{DDDD1}
  \field{sortinit}{D}
  \count{uniquename}{0}
  \field{title}{Dangerous Dames}
  \field{subtitle}{Don't Dally Dude!}
  \field{year}{2003}
\endentry

\entry{L3}{article}{}
  \name{author}{1}{%
    {{Clumberton}{C.}{Clive}{C.}{}{}{}{}}%
  }
  \list{publisher}{2}{%
    {Clapp}%
    {Clopp Press}%
  }
  \list{location}{1}{%
    {Cambridge}%
  }
  \strng{namehash}{CC1}
  \strng{fullhash}{CC1}
  \field{sortinit}{C}
  \count{uniquename}{0}
  \field{title}{Clumsy Cultural Caveats}
  \field{subtitle}{Counter-cultural Concepts}
  \field{year}{1914}
\endentry

\entry{L5}{book}{}
  \name{author}{1}{%
    {{Ethoxon}{E.}{Edward~E.}{E.~E.}{}{}{}{}}%
  }
  \list{publisher}{1}{%
    {Ethical Encouragement Press}%
  }
  \list{location}{1}{%
    {Edinburgh}%
  }
  \strng{namehash}{EEE1}
  \strng{fullhash}{EEE1}
  \field{sortinit}{E}
  \count{uniquename}{0}
  \field{title}{Eating Evil Enemies}
  \field{year}{2007}
\endentry

\endinput

|;

is(${$biber->create_bbl_string_body} , $sc1, 'citeorder');


my $so1 = [
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




# is( $biber->_print_biblatex_entry('l4'), $sc3, '\alphaothers set by "and others"');
# is( $biber->_print_biblatex_entry('l1'), $sc4, '2-pass - labelalpha after title');
# is( $biber->_print_biblatex_entry('l2'), $sc5, '2-pass - labelalpha after title');
# is( $biber->_print_biblatex_entry('l3'), $sc6, '2-pass - labelalpha after title');


unlink "$bibfile.utf8";

