use strict;
use warnings;
use utf8;
no warnings 'utf8' ;

use Test::More tests => 5 ;

use Biber;

my $biber = Biber->new();
chdir("t/tdata") ;
$biber->parse_ctrlfile_v2("00-options") ;

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

ok($biber->{config}{biblatex}{global}{uniquename} == 1, "Single-valued option") ;
is_deeply($biber->{config}{biblatex}{global}{labelname}, [ 'author' ], "Multi-valued options");
ok($biber->{config}{mincrossrefs} == 88, "Setting Biber options via control file");
ok($biber->{config}{biblatex}{book}{useprefix} == 1 , "Per-type single-valued options");
is_deeply($biber->{config}{biblatex}{book}{labelname}, $bln, "Per-type multi-valued options");




