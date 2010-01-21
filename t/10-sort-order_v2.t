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
delete $biber->{config}{biblatex}{global}{labelyear};
$biber->prepare;

is_deeply([$biber->citekeys] , ['l2','l1','l4','l3','l5'], 'citeorder');

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

