use strict;
use warnings;
use utf8;
no warnings 'utf8' ;

use Test::More tests => 7 ;

use Biber;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

my $biber = Biber->new( fastsort => 1, noconf => 1 );

my $bibentries = $biber->bib;

isa_ok($biber, "Biber");

chdir("t/tdata") ;
$biber->parse_auxfile("general1.aux") ;
$biber->parse_ctrlfile("general1.bcf") ;
$biber->set_output_obj(Biber::Output::BBL->new());

my @keys = sort $biber->citekeys;
my @citedkeys = sort qw{
t1
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

my @allkeys = sort qw{ stdmodel aristotle:poetics vazques-de-parga shore t1
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

my $bibfile = Biber::Config->getoption('bibdata')->[0] . ".bib";
Biber::Config->setoption('allentries',1);
$biber->parse_bibtex($bibfile) ;
$biber->prepare ;
my $out = $biber->get_output_obj;

@keys = sort $biber->citekeys;

is_deeply( \@keys, \@allkeys, 'citekeys 2') ;

my $stdmodel = {
                'nameyear' => 'Glashow01961',
                'journaltitle' => 'Nucl.~Phys.',
                'entryset' => 'stdmodel:glashow,stdmodel:weinberg,stdmodel:salam',
                'labelyear' => '1961',
                'author' => {namelist =>
                             [
                              {
                               index => 1,
                               uniquename   => 0,
                               firstname    => 'Sheldon',
                               firstname_i  => 'S.',
                               firstname_it => 'S',
                               suffix       => undef,
                               suffix_i     => undef,
                               suffix_it    => undef,
                               lastname     => 'Glashow',
                               lastname_i   => 'G.',
                               lastname_it  => 'G',
                               nameinitstring => 'Glashow_S',
                               namestring   => 'Glashow, Sheldon',
                               prefix       => undef,
                               prefix_i     => undef,
                               prefix_it    => undef,
                               strip        => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
                              }
                            ]},
                'labelname' => {namelist =>
                             [
                              {
                               index => 1,
                               uniquename   => 0,
                               firstname    => 'Sheldon',
                               firstname_i  => 'S.',
                               firstname_it => 'S',
                               suffix       => undef,
                               suffix_i     => undef,
                               suffix_it    => undef,
                               lastname     => 'Glashow',
                               lastname_i   => 'G.',
                               lastname_it  => 'G',
                               nameinitstring => 'Glashow_S',
                               namestring   => 'Glashow, Sheldon',
                               prefix       => undef,
                               prefix_i     => undef,
                               prefix_it    => undef,
                               strip        => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
                              }
                            ]},
                'fullhash' => 'GS1',
                'namehash' => 'GS1',
                'extrayear' => 1,
                'sortstring' => 'mm0glashow2sheldon019610partial symmetries of weak interactions00022',
                'sortinit' => 'G',
                'crossref' => 'stdmodel:glashow',
                'volume' => '22',
                'labelnamename' => 'author',
                'labelnamenamefullhash' => 'author',
                'labelyearname' => 'year',
                'entrytype' => 'set',
                'title' => 'Partial Symmetries of Weak Interactions',
                'datatype' => 'bibtex',
                'annotation' => 'A \\texttt{set} entry with three members discussing the standard model of particle physics. Note the \\texttt{entryset} and \\texttt{crossref} fields. The cross-reference must point to the first member of the set',
                'year' => '1961',
                'pages' => '579\\psqq',
                'origkey' => 'stdmodel',
                'citecasekey' => 'stdmodel'
                } ;

is_deeply($bibentries->entry('stdmodel'), $stdmodel, 'entry stdmodel') ;

my $laufenberg = {
                 'nameyear' => 'Laufenberg1zzzz02006',
                 'number' => '1700367',
                 'month' => '09',
                 'labelyear' => '2006',
                 'holder' => {namelist => [
                              {
                               index => 1,
                               firstname => undef,
                               firstname_i => undef,
                               firstname_it => undef,
                               suffix => undef,
                               suffix_i => undef,
                               suffix_it => undef,
                               prefix => undef,
                               prefix_i => undef,
                               prefix_it => undef,
                               lastname => 'Robert Bosch GmbH',
                               lastname_i => 'R.',
                               lastname_it => 'R',
                               nameinitstring => '{Robert_Bosch_GmbH}',
                               namestring => 'Robert Bosch GmbH',
                               strip => { firstname => undef, lastname => 1, prefix => undef, suffix => undef },
                              },
                              {
                               index => 2,
                               firstname => undef,
                               firstname_i => undef,
                               firstname_it => undef,
                               suffix => undef,
                               suffix_i => undef,
                               suffix_it => undef,
                               prefix => undef,
                               prefix_i => undef,
                               prefix_it => undef,
                               lastname => 'Daimler Chrysler AG',
                               lastname_i => 'D.',
                               lastname_it => 'D',
                               nameinitstring => '{Daimler_Chrysler_AG}',
                               namestring => 'Daimler Chrysler AG',
                               strip => { firstname => undef, lastname => 1, prefix => undef, suffix => undef },
                               },
                               {
                               index => 3,
                               firstname => undef,
                               firstname_i => undef,
                               firstname_it => undef,
                               suffix => undef,
                               suffix_i => undef,
                               suffix_it => undef,
                               prefix => undef,
                               prefix_i => undef,
                               prefix_it => undef,
                               lastname => 'Bayerische Motoren Werke AG',
                               lastname_i => 'B.',
                               lastname_it => 'B',
                               nameinitstring => '{Bayerische_Motoren_Werke_AG}',
                               namestring => 'Bayerische Motoren Werke AG',
                               strip => { firstname => undef, lastname => 1, prefix => undef, suffix => undef },
                               }
                             ]},
                 'date' => '2006-09-13',
                 'file' => 'http://v3.espacenet.com/textdoc?IDX=EP1700367',
                 'author' => {namelist => [
                               {
                                 index => 1,
                                 uniquename   => 0,
                                 firstname      => "Xaver",
                                 firstname_i    => "X.",
                                 firstname_it   => "X",
                                 lastname       => "Laufenberg",
                                 lastname_i     => "L.",
                                 lastname_it    => "L",
                                 nameinitstring => "Laufenberg_X",
                                 namestring     => "Laufenberg, Xaver",
                                 prefix         => undef,
                                 prefix_i       => undef,
                                 prefix_it      => undef,
                                 strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
                                 suffix         => undef,
                                 suffix_i       => undef,
                                 suffix_it      => undef,
                               },
                               {
                                 index => 2,
                                 uniquename   => 0,
                                 firstname      => "Dominique",
                                 firstname_i    => "D.",
                                 firstname_it   => "D",
                                 lastname       => "Eynius",
                                 lastname_i     => "E.",
                                 lastname_it    => "E",
                                 nameinitstring => "Eynius_D",
                                 namestring     => "Eynius, Dominique",
                                 prefix         => undef,
                                 prefix_i       => undef,
                                 prefix_it      => undef,
                                 strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
                                 suffix         => undef,
                                 suffix_i       => undef,
                                 suffix_it      => undef,
                               },
                               {
                                 index => 3,
                                 uniquename   => 0,
                                 firstname      => "Helmut",
                                 firstname_i    => "H.",
                                 firstname_it   => "H",
                                 lastname       => "Suelzle",
                                 lastname_i     => "S.",
                                 lastname_it    => "S",
                                 nameinitstring => "Suelzle_H",
                                 namestring     => "Suelzle, Helmut",
                                 prefix         => undef,
                                 prefix_i       => undef,
                                 prefix_it      => undef,
                                 strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
                                 suffix         => undef,
                                 suffix_i       => undef,
                                 suffix_it      => undef,
                               },
                               {
                                 index => 4,
                                 uniquename   => 0,
                                 firstname      => "Stephan",
                                 firstname_i    => "S.",
                                 firstname_it   => "S",
                                 lastname       => "Usbeck",
                                 lastname_i     => "U.",
                                 lastname_it    => "U",
                                 nameinitstring => "Usbeck_S",
                                 namestring     => "Usbeck, Stephan",
                                 prefix         => undef,
                                 prefix_i       => undef,
                                 prefix_it      => undef,
                                 strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
                                 suffix         => undef,
                                 suffix_i       => undef,
                                 suffix_it      => undef,
                               },
                               {
                                 index => 5,
                                 uniquename   => 0,
                                 firstname      => "Matthias",
                                 firstname_i    => "M.",
                                 firstname_it   => "M",
                                 lastname       => "Spaeth",
                                 lastname_i     => "S.",
                                 lastname_it    => "S",
                                 nameinitstring => "Spaeth_M",
                                 namestring     => "Spaeth, Matthias",
                                 prefix         => undef,
                                 prefix_i       => undef,
                                 prefix_it      => undef,
                                 strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
                                 suffix         => undef,
                                 suffix_i       => undef,
                                 suffix_it      => undef,
                               },
                               {
                                 index => 6,
                                 uniquename   => 0,
                                 firstname      => "Miriam",
                                 firstname_i    => "M.",
                                 firstname_it   => "M",
                                 lastname       => "Neuser-Hoffmann",
                                 lastname_i     => "N.-H.",
                                 lastname_it    => "NH",
                                 nameinitstring => "Neuser-Hoffmann_M",
                                 namestring     => "Neuser-Hoffmann, Miriam",
                                 prefix         => undef,
                                 prefix_i       => undef,
                                 prefix_it      => undef,
                                 strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
                                 suffix         => undef,
                                 suffix_i       => undef,
                                 suffix_it      => undef,
                               },
                               {
                                 index => 7,
                                 uniquename   => 0,
                                 firstname      => "Christian",
                                 firstname_i    => "C.",
                                 firstname_it   => "C",
                                 lastname       => "Myrzik",
                                 lastname_i     => "M.",
                                 lastname_it    => "M",
                                 nameinitstring => "Myrzik_C",
                                 namestring     => "Myrzik, Christian",
                                 prefix         => undef,
                                 prefix_i       => undef,
                                 prefix_it      => undef,
                                 strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
                                 suffix         => undef,
                                 suffix_i       => undef,
                                 suffix_it      => undef,
                               },
                               {
                                 index => 8,
                                 uniquename   => 0,
                                 firstname      => "Manfred",
                                 firstname_i    => "M.",
                                 firstname_it   => "M",
                                 lastname       => "Schmid",
                                 lastname_i     => "S.",
                                 lastname_it    => "S",
                                 nameinitstring => "Schmid_M",
                                 namestring     => "Schmid, Manfred",
                                 prefix         => undef,
                                 prefix_i       => undef,
                                 prefix_it      => undef,
                                 strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
                                 suffix         => undef,
                                 suffix_i       => undef,
                                 suffix_it      => undef,
                               },
                               {
                                 index => 9,
                                 uniquename   => 0,
                                 firstname      => "Franz",
                                 firstname_i    => "F.",
                                 firstname_it   => "F",
                                 lastname       => "Nietfeld",
                                 lastname_i     => "N.",
                                 lastname_it    => "N",
                                 nameinitstring => "Nietfeld_F",
                                 namestring     => "Nietfeld, Franz",
                                 prefix         => undef,
                                 prefix_i       => undef,
                                 prefix_it      => undef,
                                 strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
                                 suffix         => undef,
                                 suffix_i       => undef,
                                 suffix_it      => undef,
                               },
                               {
                                 index => 10,
                                 uniquename   => 0,
                                 firstname      => "Alexander",
                                 firstname_i    => "A.",
                                 firstname_it   => "A",
                                 lastname       => "Thiel",
                                 lastname_i     => "T.",
                                 lastname_it    => "T",
                                 nameinitstring => "Thiel_A",
                                 namestring     => "Thiel, Alexander",
                                 prefix         => undef,
                                 prefix_i       => undef,
                                 prefix_it      => undef,
                                 strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
                                 suffix         => undef,
                                 suffix_i       => undef,
                                 suffix_it      => undef,
                               },
                               {
                                 index => 11,
                                 uniquename   => 0,
                                 firstname      => "Harald",
                                 firstname_i    => "H.",
                                 firstname_it   => "H",
                                 lastname       => "Braun",
                                 lastname_i     => "B.",
                                 lastname_it    => "B",
                                 nameinitstring => "Braun_H",
                                 namestring     => "Braun, Harald",
                                 prefix         => undef,
                                 prefix_i       => undef,
                                 prefix_it      => undef,
                                 strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
                                 suffix         => undef,
                                 suffix_i       => undef,
                                 suffix_it      => undef,
                               },
                               {
                                 index => 12,
                                 uniquename   => 0,
                                 firstname      => "Norbert",
                                 firstname_i    => "N.",
                                 firstname_it   => "N",
                                 lastname       => "Ebner",
                                 lastname_i     => "E.",
                                 lastname_it    => "E",
                                 nameinitstring => "Ebner_N",
                                 namestring     => "Ebner, Norbert",
                                 prefix         => undef,
                                 prefix_i       => undef,
                                 prefix_it      => undef,
                                 strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
                                 suffix         => undef,
                                 suffix_i       => undef,
                                 suffix_it      => undef,
                               }
                             ]},
                 'labelname' => {namelist => [
                               {
                                 index => 1,
                                 uniquename   => 0,
                                 firstname      => "Xaver",
                                 firstname_i    => "X.",
                                 firstname_it   => "X",
                                 lastname       => "Laufenberg",
                                 lastname_i     => "L.",
                                 lastname_it    => "L",
                                 nameinitstring => "Laufenberg_X",
                                 namestring     => "Laufenberg, Xaver",
                                 prefix         => undef,
                                 prefix_i       => undef,
                                 prefix_it      => undef,
                                 strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
                                 suffix         => undef,
                                 suffix_i       => undef,
                                 suffix_it      => undef,
                               },
                               {
                                 index => 2,
                                 uniquename   => 0,
                                 firstname      => "Dominique",
                                 firstname_i    => "D.",
                                 firstname_it   => "D",
                                 lastname       => "Eynius",
                                 lastname_i     => "E.",
                                 lastname_it    => "E",
                                 nameinitstring => "Eynius_D",
                                 namestring     => "Eynius, Dominique",
                                 prefix         => undef,
                                 prefix_i       => undef,
                                 prefix_it      => undef,
                                 strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
                                 suffix         => undef,
                                 suffix_i       => undef,
                                 suffix_it      => undef,
                               },
                               {
                                 index => 3,
                                 uniquename   => 0,
                                 firstname      => "Helmut",
                                 firstname_i    => "H.",
                                 firstname_it   => "H",
                                 lastname       => "Suelzle",
                                 lastname_i     => "S.",
                                 lastname_it    => "S",
                                 nameinitstring => "Suelzle_H",
                                 namestring     => "Suelzle, Helmut",
                                 prefix         => undef,
                                 prefix_i       => undef,
                                 prefix_it      => undef,
                                 strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
                                 suffix         => undef,
                                 suffix_i       => undef,
                                 suffix_it      => undef,
                               },
                               {
                                 index => 4,
                                 uniquename   => 0,
                                 firstname      => "Stephan",
                                 firstname_i    => "S.",
                                 firstname_it   => "S",
                                 lastname       => "Usbeck",
                                 lastname_i     => "U.",
                                 lastname_it    => "U",
                                 nameinitstring => "Usbeck_S",
                                 namestring     => "Usbeck, Stephan",
                                 prefix         => undef,
                                 prefix_i       => undef,
                                 prefix_it      => undef,
                                 strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
                                 suffix         => undef,
                                 suffix_i       => undef,
                                 suffix_it      => undef,
                               },
                               {
                                 index => 5,
                                 uniquename   => 0,
                                 firstname      => "Matthias",
                                 firstname_i    => "M.",
                                 firstname_it   => "M",
                                 lastname       => "Spaeth",
                                 lastname_i     => "S.",
                                 lastname_it    => "S",
                                 nameinitstring => "Spaeth_M",
                                 namestring     => "Spaeth, Matthias",
                                 prefix         => undef,
                                 prefix_i       => undef,
                                 prefix_it      => undef,
                                 strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
                                 suffix         => undef,
                                 suffix_i       => undef,
                                 suffix_it      => undef,
                               },
                               {
                                 index => 6,
                                 uniquename   => 0,
                                 firstname      => "Miriam",
                                 firstname_i    => "M.",
                                 firstname_it   => "M",
                                 lastname       => "Neuser-Hoffmann",
                                 lastname_i     => "N.-H.",
                                 lastname_it    => "NH",
                                 nameinitstring => "Neuser-Hoffmann_M",
                                 namestring     => "Neuser-Hoffmann, Miriam",
                                 prefix         => undef,
                                 prefix_i       => undef,
                                 prefix_it      => undef,
                                 strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
                                 suffix         => undef,
                                 suffix_i       => undef,
                                 suffix_it      => undef,
                               },
                               {
                                 index => 7,
                                 uniquename   => 0,
                                 firstname      => "Christian",
                                 firstname_i    => "C.",
                                 firstname_it   => "C",
                                 lastname       => "Myrzik",
                                 lastname_i     => "M.",
                                 lastname_it    => "M",
                                 nameinitstring => "Myrzik_C",
                                 namestring     => "Myrzik, Christian",
                                 prefix         => undef,
                                 prefix_i       => undef,
                                 prefix_it      => undef,
                                 strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
                                 suffix         => undef,
                                 suffix_i       => undef,
                                 suffix_it      => undef,
                               },
                               {
                                 index => 8,
                                 uniquename   => 0,
                                 firstname      => "Manfred",
                                 firstname_i    => "M.",
                                 firstname_it   => "M",
                                 lastname       => "Schmid",
                                 lastname_i     => "S.",
                                 lastname_it    => "S",
                                 nameinitstring => "Schmid_M",
                                 namestring     => "Schmid, Manfred",
                                 prefix         => undef,
                                 prefix_i       => undef,
                                 prefix_it      => undef,
                                 strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
                                 suffix         => undef,
                                 suffix_i       => undef,
                                 suffix_it      => undef,
                               },
                               {
                                 index => 9,
                                 uniquename   => 0,
                                 firstname      => "Franz",
                                 firstname_i    => "F.",
                                 firstname_it   => "F",
                                 lastname       => "Nietfeld",
                                 lastname_i     => "N.",
                                 lastname_it    => "N",
                                 nameinitstring => "Nietfeld_F",
                                 namestring     => "Nietfeld, Franz",
                                 prefix         => undef,
                                 prefix_i       => undef,
                                 prefix_it      => undef,
                                 strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
                                 suffix         => undef,
                                 suffix_i       => undef,
                                 suffix_it      => undef,
                               },
                               {
                                 index => 10,
                                 uniquename   => 0,
                                 firstname      => "Alexander",
                                 firstname_i    => "A.",
                                 firstname_it   => "A",
                                 lastname       => "Thiel",
                                 lastname_i     => "T.",
                                 lastname_it    => "T",
                                 nameinitstring => "Thiel_A",
                                 namestring     => "Thiel, Alexander",
                                 prefix         => undef,
                                 prefix_i       => undef,
                                 prefix_it      => undef,
                                 strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
                                 suffix         => undef,
                                 suffix_i       => undef,
                                 suffix_it      => undef,
                               },
                               {
                                 index => 11,
                                 uniquename   => 0,
                                 firstname      => "Harald",
                                 firstname_i    => "H.",
                                 firstname_it   => "H",
                                 lastname       => "Braun",
                                 lastname_i     => "B.",
                                 lastname_it    => "B",
                                 nameinitstring => "Braun_H",
                                 namestring     => "Braun, Harald",
                                 prefix         => undef,
                                 prefix_i       => undef,
                                 prefix_it      => undef,
                                 strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
                                 suffix         => undef,
                                 suffix_i       => undef,
                                 suffix_it      => undef,
                               },
                               {
                                 index => 12,
                                 uniquename   => 0,
                                 firstname      => "Norbert",
                                 firstname_i    => "N.",
                                 firstname_it   => "N",
                                 lastname       => "Ebner",
                                 lastname_i     => "E.",
                                 lastname_it    => "E",
                                 nameinitstring => "Ebner_N",
                                 namestring     => "Ebner, Norbert",
                                 prefix         => undef,
                                 prefix_i       => undef,
                                 prefix_it      => undef,
                                 strip          => { firstname => 0, lastname => 0, prefix => undef, suffix => undef },
                                 suffix         => undef,
                                 suffix_i       => undef,
                                 suffix_it      => undef,
                               }
                             ]},
                 'fullhash' => 'LXEDSHUSSMNHMMCSMNFTABHEN1',
                 'hyphenation' => 'german',
                 'day' => '13',
                 'namehash' => 'LX+1',
                 'sortstring' => 'mm0laufenberg2xaver1zzzz020060elektrische einrichtung und betriebsverfahren00000',
                 'sortinit' => 'L',
                 'location' => [
                                 'countryde',
                                 'countrywo'
                               ],
                  'labelnamename' => 'author',
                  'labelnamenamefullhash' => 'author',
                  'labelyearname' => 'year',
                 'entrytype' => 'patent',
                 'abstract' => 'The invention relates to an electric device comprising a generator, in particular for use in the vehicle electric system of a motor vehicle and a controller for controlling the generator voltage. The device is equipped with a control zone, in which the voltage is controlled and zones, in which the torque is controlled. The invention also relates to methods for operating a device of this type.',
                 'type' => 'patenteu',
                 'title' => 'Elektrische Einrichtung und Betriebsverfahren',
                 'annotation' => 'This is a \\texttt{patent} entry with a \\texttt{holder} field. Note the format of the \\texttt{type} and \\texttt{location} fields in the database file. Compare \\texttt{almendro}, \\texttt{sorace}, and \\texttt{kowalik}',
                 'datatype' => 'bibtex',
                 'year' => '2006',
                'origkey' => 'laufenberg',
                'citecasekey' => 'laufenberg'
                } ;

is_deeply($bibentries->entry('laufenberg'), $laufenberg, 'entry laufenberg') ;

my $kastenholz = q|\entry{kastenholz}{article}{}
  \name{labelname}{2}{}{%
    {{uniquename=0}{Kastenholz}{K.}{M.~A.}{M.~A.}{}{}{}{}}%
    {{uniquename=0}{H{\"u}nenberger}{H.}{Philippe~H.}{P.~H.}{}{}{}{}}%
  }
  \name{author}{2}{}{%
    {{}{Kastenholz}{K.}{M.~A.}{M.~A.}{}{}{}{}}%
    {{}{H{\"u}nenberger}{H.}{Philippe~H.}{P.~H.}{}{}{}{}}%
  }
  \strng{namehash}{KMAHPH1}
  \strng{fullhash}{KMAHPH1}
  \field{sortinit}{K}
  \field{labelyear}{2006}
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


is( $out->get_output_entry('kastenholz'), $kastenholz, 'bbl entry' ) ;

my $t1 = q|\entry{t1}{misc}{}
  \name{labelname}{1}{}{%
    {{uniquename=0}{Brown}{B.}{Bill}{B.}{}{}{}{}}%
  }
  \name{author}{1}{}{%
    {{}{Brown}{B.}{Bill}{B.}{}{}{}{}}%
  }
  \strng{namehash}{BB1}
  \strng{fullhash}{BB1}
  \field{sortinit}{B}
  \field{labelyear}{1992}
  \field{year}{1992}
  \field{title}{Normal things {$^{3}$}}
\endentry

|;

is( $out->get_output_entry('t1'), $t1, 'bbl entry with maths in title' ) ;
