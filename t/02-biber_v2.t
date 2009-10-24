use strict;
use warnings;
use utf8;
no warnings 'utf8' ;

use Test::More tests => 6 ;

use Biber;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

my $opts = { fastsort => 1 };
my $biber = Biber->new($opts);

isa_ok($biber, "Biber");

chdir("t/tdata") ;
$biber->parse_auxfile_v2("50-style-authoryear_v2.aux") ;


my @keys = sort $biber->citekeys;
my @citedkeys = sort qw{
stdmodel
knuth:ct
angenendtsk
angenendtsa
stdmodel:glashow
stdmodel:ps_sc
hasan
jaffe
luzzatto
moraux
murray
aristotle:rhetoric
aristotle:anima
augustine
cotton
chiu
};

my @allkeys = sort qw{ stdmodel aristotle:poetics vazques-de-parga shore
gonzalez averroes/bland laufenberg westfahl:frontier knuth:ct:a kastenholz
averroes/hannes iliad luzzatto malinowski sorace knuth:ct:d britannica
nietzsche:historie stdmodel:weinberg knuth:ct:b baez/article knuth:ct:e itzhaki
jaffe padhye cicero stdmodel:salam reese averroes/hercz murray
aristotle:physics massa aristotle:anima gillies set kowalik gaonkar springer
geer hammond wormanx westfahl:space worman set:herrmann augustine gerhardt
piccato hasan hyman stdmodel:glashow stdmodel:ps_sc kant:kpv companion almendro
sigfridsson ctan baez/online aristotle:rhetoric pimentel00 pines knuth:ct:c moraux cms
angenendt angenendtsk loh markey cotton vangennepx kant:ku nussbaum nietzsche:ksa1
vangennep knuth:ct angenendtsa spiegelberg bertram brandt set:aksin chiu nietzsche:ksa
set:yoon maron coleridge } ;

is_deeply( \@keys, \@citedkeys, 'citekeys 1') ;

my $bibfile = $biber->config('bibdata')->[0] . ".bib";
$biber->{config}{allentries} = 1;
$biber->parse_bibtex($bibfile) ;
$biber->prepare ;
@keys = sort $biber->citekeys;

is_deeply( \@keys, \@allkeys, 'citekeys 2') ;

my $stdmodel = {
                'authoryear' => 'Glashow2Sheldon01961',
                'journaltitle' => 'Nucl.~Phys.',
                'entryset' => 'stdmodel:glashow,stdmodel:weinberg,stdmodel:salam',
                'author' => [
                              {
                                'firstname' => 'Sheldon',
                                'suffix' => undef,
                                'lastname' => 'Glashow',
                                'nameinitstring' => 'Glashow_S',
                                'namestring' => 'Glashow, Sheldon',
                                'prefix' => undef
                              }
                            ],
                'fullhash' => 'GS1',
                'namehash' => 'GS1',
                'extrayear' => 1,
                'sortstring' => 'mm00glashow2sheldon019610partial symmetries of weak interactions00022',
                'crossref' => 'stdmodel:glashow',
                'volume' => '22',
                'labelnamename' => 'author',
                'labelyearname' => 'year',
                'entrytype' => 'set',
                'title' => 'Partial Symmetries of Weak Interactions',
                'datatype' => 'bibtex',
                'annotation' => 'A \\texttt{set} entry with three members discussing the standard model of particle physics. Note the \\texttt{entryset} and \\texttt{crossref} fields. The cross-reference must point to the first member of the set',
                'year' => '1961',
                'pages' => '579\\psqq',
                'origkey' => 'stdmodel'
                } ;

is_deeply($biber->{bib}->{stdmodel}, $stdmodel, 'entry stdmodel') ;

my $laufenberg = {
                 'authoryear' => 'Laufenberg2Xaver1zzzz02006',
                 'number' => '1700367',
                 'month' => '09',
                 'holder' => [
                               {
                                 'firstname' => undef,
                                 'suffix' => undef,
                                 'lastname' => 'Robert Bosch GmbH',
                                 'nameinitstring' => 'Robert_Bosch_GmbH',
                                 'namestring' => 'Robert Bosch GmbH',
                                 'prefix' => undef
                               },
                               {
                                 'firstname' => undef,
                                 'suffix' => undef,
                                 'lastname' => 'Daimler Chrysler AG',
                                 'nameinitstring' => 'Daimler_Chrysler_AG',
                                 'namestring' => 'Daimler Chrysler AG',
                                 'prefix' => undef
                               },
                               {
                                 'firstname' => undef,
                                 'suffix' => undef,
                                 'lastname' => 'Bayerische Motoren Werke AG',
                                 'nameinitstring' => 'Bayerische_Motoren_Werke_AG',
                                 'namestring' => 'Bayerische Motoren Werke AG',
                                 'prefix' => undef
                               }
                             ],
                 'date' => '2006-09-13',
                 'file' => 'http://v3.espacenet.com/textdoc?IDX=EP1700367',
                 'author' => [
                               {
                                 'firstname' => 'Xaver',
                                 'suffix' => undef,
                                 'lastname' => 'Laufenberg',
                                 'nameinitstring' => 'Laufenberg_X',
                                 'namestring' => 'Laufenberg, Xaver',
                                 'prefix' => undef
                               },
                               {
                                 'firstname' => 'Dominique',
                                 'suffix' => undef,
                                 'lastname' => 'Eynius',
                                 'nameinitstring' => 'Eynius_D',
                                 'namestring' => 'Eynius, Dominique',
                                 'prefix' => undef
                               },
                               {
                                 'firstname' => 'Helmut',
                                 'suffix' => undef,
                                 'lastname' => 'Suelzle',
                                 'nameinitstring' => 'Suelzle_H',
                                 'namestring' => 'Suelzle, Helmut',
                                 'prefix' => undef
                               },
                               {
                                 'firstname' => 'Stephan',
                                 'suffix' => undef,
                                 'lastname' => 'Usbeck',
                                 'nameinitstring' => 'Usbeck_S',
                                 'namestring' => 'Usbeck, Stephan',
                                 'prefix' => undef
                               },
                               {
                                 'firstname' => 'Matthias',
                                 'suffix' => undef,
                                 'lastname' => 'Spaeth',
                                 'nameinitstring' => 'Spaeth_M',
                                 'namestring' => 'Spaeth, Matthias',
                                 'prefix' => undef
                               },
                               {
                                 'firstname' => 'Miriam',
                                 'suffix' => undef,
                                 'lastname' => 'Neuser-Hoffmann',
                                 'nameinitstring' => 'Neuser-Hoffmann_M',
                                 'namestring' => 'Neuser-Hoffmann, Miriam',
                                 'prefix' => undef
                               },
                               {
                                 'firstname' => 'Christian',
                                 'suffix' => undef,
                                 'lastname' => 'Myrzik',
                                 'nameinitstring' => 'Myrzik_C',
                                 'namestring' => 'Myrzik, Christian',
                                 'prefix' => undef
                               },
                               {
                                 'firstname' => 'Manfred',
                                 'suffix' => undef,
                                 'lastname' => 'Schmid',
                                 'nameinitstring' => 'Schmid_M',
                                 'namestring' => 'Schmid, Manfred',
                                 'prefix' => undef
                               },
                               {
                                 'firstname' => 'Franz',
                                 'suffix' => undef,
                                 'lastname' => 'Nietfeld',
                                 'nameinitstring' => 'Nietfeld_F',
                                 'namestring' => 'Nietfeld, Franz',
                                 'prefix' => undef
                               },
                               {
                                 'firstname' => 'Alexander',
                                 'suffix' => undef,
                                 'lastname' => 'Thiel',
                                 'nameinitstring' => 'Thiel_A',
                                 'namestring' => 'Thiel, Alexander',
                                 'prefix' => undef
                               },
                               {
                                 'firstname' => 'Harald',
                                 'suffix' => undef,
                                 'lastname' => 'Braun',
                                 'nameinitstring' => 'Braun_H',
                                 'namestring' => 'Braun, Harald',
                                 'prefix' => undef
                               },
                               {
                                 'firstname' => 'Norbert',
                                 'suffix' => undef,
                                 'lastname' => 'Ebner',
                                 'nameinitstring' => 'Ebner_N',
                                 'namestring' => 'Ebner, Norbert',
                                 'prefix' => undef
                               }
                             ],
                 'fullhash' => 'LXEDSHUSSMNHMMCSMNFTABHEN1',
                 'hyphenation' => 'german',
                 'day' => '13',
                 'ignoreuniquename' => 1,
                 'namehash' => 'LX+1',
                 'sortstring' => 'mm00laufenberg2xaver1zzzz020060elektrische einrichtung und betriebsverfahren00000',
                 'location' => [
                                 'countryde',
                                 'countrywo'
                               ],
                  'labelnamename' => 'author',
                  'labelyearname' => 'year',
                 'entrytype' => 'patent',
                 'abstract' => 'The invention relates to an electric device comprising a generator, in particular for use in the vehicle electric system of a motor vehicle and a controller for controlling the generator voltage. The device is equipped with a control zone, in which the voltage is controlled and zones, in which the torque is controlled. The invention also relates to methods for operating a device of this type.',
                 'type' => 'patenteu',
                 'title' => 'Elektrische Einrichtung und Betriebsverfahren',
                 'annotation' => 'This is a \\texttt{patent} entry with a \\texttt{holder} field. Note the format of the \\texttt{type} and \\texttt{location} fields in the database file. Compare \\texttt{almendro}, \\texttt{sorace}, and \\texttt{kowalik}',
                 'datatype' => 'bibtex',
                 'year' => '2006',
                'origkey' => 'laufenberg'
                } ;

is_deeply($biber->{bib}->{laufenberg}, $laufenberg, 'entry laufenberg') ;

my $kastenholz = q|\entry{kastenholz}{article}{}
  \name{author}{2}{%
    {{Kastenholz}{K.}{M.~A.}{M.~A.}{}{}{}{}}%
    {{H{\"u}nenberger}{H.}{Philippe~H.}{P.~H.}{}{}{}{}}%
  }
  \strng{namehash}{KMAHPH1}
  \strng{fullhash}{KMAHPH1}
  \field{sortinit}{K}
  \field{labelyear}{2006}
  \count{uniquename}{0}
  \field{year}{2006}
  \field{title}{Computation of methodology\hyphen independent ionic solvation free energies from molecular simulations}
  \field{subtitle}{I. The electrostatic potential in molecular liquids}
  \field{indextitle}{Computation of ionic solvation free energies}
  \field{journaltitle}{J.~Chem. Phys.}
  \field{abstract}{The computation of ionic solvation free energies from atomistic simulations is a surprisingly difficult problem that has found no satisfactory solution for more than 15 years. The reason is that the charging free energies evaluated from such simulations are affected by very large errors. One of these is related to the choice of a specific convention for summing up the contributions of solvent charges to the electrostatic potential in the ionic cavity, namely, on the basis of point charges within entire solvent molecules (M scheme) or on the basis of individual point charges (P scheme). The use of an inappropriate convention may lead to a charge-independent offset in the calculated potential, which depends on the details of the summation scheme, on the quadrupole-moment trace of the solvent molecule, and on the approximate form used to represent electrostatic interactions in the system. However, whether the M or P scheme (if any) represents the appropriate convention is still a matter of on-going debate. The goal of the present article is to settle this long-standing controversy by carefully analyzing (both analytically and numerically) the properties of the electrostatic potential in molecular liquids (and inside cavities within them).}
  \field{annotation}{An \texttt{article} entry with an \texttt{eid} and a \texttt{doi} field. Note that the \textsc{doi} is transformed into a clickable link if \texttt{hyperref} support has been enabled}
  \field{eid}{124106}
  \field{volume}{124}
  \field{hyphenation}{american}
  \verb{doi}
  \verb 10.1063/1.2172593
  \endverb
\endentry

| ;


is( $biber->_print_biblatex_entry('kastenholz'), $kastenholz, 'bbl entry' ) ;
