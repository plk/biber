use strict;
use warnings;
use utf8;
no warnings 'utf8' ;

use Test::More tests => 7;

use Biber;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
chdir("t/tdata") ;

# Set up Biber object
my $biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('options.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('locale', 'C');

# Biblatex options
Biber::Config->setblxoption('labelyear', [ 'year' ]);

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $bibentries = $biber->sections->get_section('0')->bib;

my $dmv =  [
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
               {'sorttitle'  => {}},
               {'title'      => {}}
              ],
              [
               {'sortyear'   => {}},
               {'year'       => {}}
              ],
              [
               {'volume'     => {}},
               {'0000'       => {}}
              ]
             ];

my $bln = [ 'author', 'editor' ];

my $l1 = q|  \entry{L1}{book}{}
    \name{author}{1}{%
      {{Doe}{D.}{John}{J.}{}{}{}{}}%
    }
    \list{publisher}{1}{%
      {Oxford}%
    }
    \strng{namehash}{DJ1}
    \strng{fullhash}{DJ1}
    \field{sortinit}{D}
    \field{labelyear}{1998}
    \count{uniquename}{0}
    \field{year}{1998}
    \field{origyear}{1985}
    \field{month}{04}
    \field{origmonth}{10}
    \field{day}{05}
    \field{origday}{30}
    \field{title}{Title 1}
  \endentry

|;

ok(Biber::Config->getblxoption('uniquename') == 1, "Single-valued option") ;
is_deeply(Biber::Config->getblxoption('labelname'), [ 'author' ], "Multi-valued options");
ok(Biber::Config->getoption('mincrossrefs') == 88, "Setting Biber options via control file");
ok(Biber::Config->getblxoption('useprefix', 'book') == 1 , "Per-type single-valued options");
is_deeply(Biber::Config->getblxoption('labelname', 'book'), $bln, "Per-type multi-valued options");
is($bibentries->entry('l1')->get_field('labelyearname'), 'year', 'Global labelyear setting' ) ;
is( $out->get_output_entry('l1'), $l1, 'Global labelyear setting - labelyear should be YEAR') ;


