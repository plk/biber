use strict;
use warnings;
use utf8;
no warnings 'utf8' ;

use Test::More tests => 10 ;

use Biber;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

my $biber = Biber->new(noconf => 1);
chdir("t/tdata") ;

my $bibfile;
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('locale', 'C');
$biber->parse_auxfile('options.aux');
$bibfile = Biber::Config->getoption('bibdata')->[0] . '.bib';
$biber->parse_bibtex($bibfile);

Biber::Config->setblxoption('labelyear', [ 'year' ]);
$biber->prepare;
my $bibentries = $biber->bib;

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

my $l1 = q|\entry{L1}{book}{}
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

my $l2 = q|\entry{L2}{book}{usetranslator=true,labelyear=origyear,labelname=translator,labelalpha=true}
  \name{author}{1}{%
    {{Doe}{D.}{John}{J.}{}{}{}{}}%
  }
  \name{translator}{1}{%
    {{Smith}{S.}{Bill}{B.}{}{}{}{}}%
  }
  \list{publisher}{1}{%
    {Oxford}%
  }
  \strng{namehash}{SB1}
  \strng{fullhash}{SB1}
  \field{labelalpha}{Smi98}
  \field{sortinit}{D}
  \field{labelyear}{1985}
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
is( $biber->_print_biblatex_entry('l1'), $l1, 'Global labelyear setting - labelyear should be YEAR') ;
is($biber->{bib}{l2}{labelyearname}, 'origyear', 'Entry-specific labelyear setting' ) ;
is( $biber->_print_biblatex_entry('l2'), $l2, 'Entry-specific labelyear setting - labelyear should be ORIGYEAR') ;
is($bibentries->entry('l2')->get_field('labelnamename'), 'translator', 'Entry-specific labelname setting' ) ;


