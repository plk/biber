use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 10;

use Biber;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

my $biber = Biber->new( unicodebbl => 1, fastsort => 1, noconf => 1 );

isa_ok($biber, "Biber");

chdir("t/tdata") ;
$biber->parse_auxfile('sort-complex.aux');
$biber->parse_ctrlfile('sort-complex.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());
my $bibfile = Biber::Config->getoption('bibdata')->[0] . ".bib";
$biber->parse_bibtex($bibfile);
Biber::Config->setblxoption('labelalpha', 1);
Biber::Config->setblxoption('labelyear', undef);
$biber->prepare;
my $bibentries = $biber->bib;

my $out = $biber->get_output_obj;
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



is_deeply( Biber::Config->getblxoption('sorting_label') , $sc1, 'first pass scheme');
is_deeply( Biber::Config->getblxoption('sorting_final') , $sc2, 'second pass scheme');

is ($bibentries->entry('l4')->get_field('labelalpha'), 'Doe\textbf{+}95', '\alphaothers set by "and others"');
is ($bibentries->entry('l1')->get_field('labelalpha'), 'Doe95', '2-pass - labelalpha after title - 1');
is ($bibentries->entry('l1')->get_field('extraalpha'), '1', '2-pass - labelalpha after title - 2');
is ($bibentries->entry('l2')->get_field('labelalpha'), 'Doe95', '2-pass - labelalpha after title - 3');
is ($bibentries->entry('l2')->get_field('extraalpha'), '3', '2-pass - labelalpha after title - 4');
is ($bibentries->entry('l3')->get_field('labelalpha'), 'Doe95', '2-pass - labelalpha after title - 5');
is ($bibentries->entry('l3')->get_field('extraalpha'), '2', '2-pass - labelalpha after title - 6');

unlink "$bibfile.utf8";

