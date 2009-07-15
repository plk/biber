use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 4;

use Biber;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

my $opts = { unicodebbl => 1, fastsort => 1 };
my $biber = Biber->new($opts);

isa_ok($biber, "Biber");

chdir("t/tdata") ;
$biber->parse_auxfile_v2('60-sort-complex_v2.aux');
$biber->{config}{biblatex}{global}{maxline} = 100000 ;

my $bibfile = $biber->config('bibdata')->[0] . ".bib";
$biber->parse_bibtex($bibfile);
$biber->{config}{biblatex}{global}{labelalpha} = 1;
$biber->{config}{biblatex}{global}{labelyear} = 0;
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
  \field{title}{Some title about sorting}
  \field{year}{1995}
\endentry

|;


is_deeply( $biber->{config}{biblatex}{global}{sorting_label} , $sc1, 'sort - first pass scheme') ;
is_deeply( $biber->{config}{biblatex}{global}{sorting_final} , $sc2, 'sort - second pass scheme') ;

#is( $biber->_print_biblatex_entry('L1'), $t1, '' ) ;
#is( $biber->_print_biblatex_entry('L2'), $t2, '' ) ;
#is( $biber->_print_biblatex_entry('L3'), $t3, '' ) ;

is( $biber->_print_biblatex_entry('l4'), $sc3, '\alphaothers set by "and others"' ) ;


unlink "$bibfile.utf8";

