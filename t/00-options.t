use strict;
use warnings;
use utf8;
no warnings 'utf8' ;

use Test::More tests => 10 ;

use Biber;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);




my $biber = Biber->new();
chdir("t/tdata") ;

my $bibfile;
$biber->{config}{fastsort} = 1;
$biber->{config}{locale} = 'C';
$biber->parse_auxfile_v2('00-options_v2.aux');
$bibfile = $biber->config('bibdata')->[0] . '.bib';
$biber->parse_bibtex($bibfile);

$biber->{config}{biblatex}{global}{labelyear} = [ 'year' ];
$biber->prepare;


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

my $l1 = q|\entry{l1}{book}{}
  \name{author}{1}{%
    {{Doe}{D.}{John}{J.}{}{}{}{}}%
  }
  \list{publisher}{1}{%
    {Oxford}%
  }
  \strng{namehash}{T11}
  \strng{fullhash}{T11}
  \field{sortinit}{T}
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

my $l2 = q|\entry{l2}{book}{usetranslator=true,labelyear=origyear,labelname=translator,labelalpha=true}
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
  \field{sortinit}{S}
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

ok($biber->{config}{biblatex}{global}{uniquename} == 1, "Single-valued option") ;
is_deeply($biber->{config}{biblatex}{global}{labelname}, [ 'author' ], "Multi-valued options");
ok($biber->{config}{mincrossrefs} == 88, "Setting Biber options via control file");
ok($biber->{config}{biblatex}{book}{useprefix} == 1 , "Per-type single-valued options");
is_deeply($biber->{config}{biblatex}{book}{labelname}, $bln, "Per-type multi-valued options");
is($biber->{bib}{l1}{labelyearname}, 'year', 'Global labelyear setting' ) ;
is( $biber->_print_biblatex_entry('l1'), $l1, 'Global labelyear setting - labelyear should be YEAR') ;
is($biber->{bib}{l2}{labelyearname}, 'origyear', 'Entry-specific labelyear setting' ) ;
is( $biber->_print_biblatex_entry('l2'), $l2, 'Entry-specific labelyear setting - labelyear should be ORIGYEAR') ;
is($biber->{bib}{l2}{labelnamename}, 'translator', 'Entry-specific labelname setting' ) ;


