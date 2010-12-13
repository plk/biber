use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 11;

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
my $bibentries = $biber->sections->get_section('0')->bibentries;

my $out = $biber->get_output_obj;

isa_ok($biber, "Biber");

my $sc1 = [
           [
            {},
            {'labelalpha'    => {}},
           ],
           [
            {},
            {'presort'    => {}}
           ],
           [
            {'final' => 1},
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
            {sort_direction => 'descending'},
            {'sortyear'  => {}},
            {'year'      => {substring_side => 'right',
                             substring_width => '4'}}
           ],
           [
            {},
            {'volume'     => {pad_char => '0'}},
            {'0000'       => {}}
           ],
           [
            {},
            {'sorttitle'       => {}},
            {'title'       => {}}
           ],
          ];

my $sc2 = [
           [
            {},
            {'presort'    => {}}
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
            {'final' => 1},
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
            {sort_direction => 'descending'},
            {'sortyear'  => {}},
            {'year'      => {substring_side => 'right',
                             substring_width => '4'}}
           ],
           [
            {},
            {'volume'     => {pad_char => '0'}},
            {'0000'       => {}}
           ],
           [
            {},
            {'sorttitle'       => {}},
            {'title'       => {}}
           ],
          ];


my $sc4 = q|  \entry{L4}{book}{}
    \true{morelabelname}
    \name{labelname}{1}{}{%
      {{}{Doe}{D.}{John}{J.}{}{}{}{}}%
    }
    \true{moreauthor}
    \name{author}{1}{}{%
      {{}{Doe}{D.}{John}{J.}{}{}{}{}}%
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

is_deeply( Biber::Config->getblxoption('sorting_label') , $sc1, 'first pass scheme');
is_deeply( Biber::Config->getblxoption('sorting_final') , $sc2, 'second pass scheme');

is( $out->get_output_entry('l4'), $sc4, 'Check more* fields"');
is ($bibentries->entry('l4')->get_field('labelalpha'), 'Doe\textbf{+}95', '\alphaothers set by "and others"');
is ($bibentries->entry('l1')->get_field('labelalpha'), 'Doe95', '2-pass - labelalpha after title - 1');
is ($bibentries->entry('l1')->get_field('extraalpha'), '1', '2-pass - labelalpha after title - 2');
is ($bibentries->entry('l2')->get_field('labelalpha'), 'Doe95', '2-pass - labelalpha after title - 3');
is ($bibentries->entry('l2')->get_field('extraalpha'), '3', '2-pass - labelalpha after title - 4');
is ($bibentries->entry('l3')->get_field('labelalpha'), 'Doe95', '2-pass - labelalpha after title - 5');
is ($bibentries->entry('l3')->get_field('extraalpha'), '2', '2-pass - labelalpha after title - 6');

unlink "*.utf8";

