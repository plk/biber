use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 20;

use Biber;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
chdir("t/tdata") ;

# Set up Biber object
my $biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('crossrefs.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'C');

# Now generate the information
$biber->prepare;
my $section0 = $biber->sections->get_section(0);
my $main0 = $section0->get_list('MAIN');
my $section1 = $biber->sections->get_section(1);
my $main1 = $section1->get_list('MAIN');
my $out = $biber->get_output_obj;

# crossref field is included as the parent is included by being crossrefed >= mincrossrefs times
my $cr1 = q|  \entry{cr1}{inbook}{}
    \name{labelname}{1}{}{%
      {{hash=G1}{Gullam}{G\bibinitperiod}{Graham}{G\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{hash=G1}{Gullam}{G\bibinitperiod}{Graham}{G\bibinitperiod}{}{}{}{}}%
    }
    \name{editor}{1}{}{%
      {{hash=E1}{Erbriss}{E\bibinitperiod}{Edgar}{E\bibinitperiod}{}{}{}{}}%
    }
    \list{publisher}{1}{%
      {Grimble}%
    }
    \strng{namehash}{GG1}
    \strng{fullhash}{GG1}
    \field{sortinit}{G}
    \field{labelyear}{1974}
    \field{booktitle}{Graphs of the Continent}
    \strng{crossref}{cr_m}
    \field{eprintclass}{SOMECLASS}
    \field{eprinttype}{SomEPrFiX}
    \field{origyear}{1955}
    \field{title}{Great and Good Graphs}
    \field{year}{1974}
  \endentry

|;

# crossref field is included as the parent is included by being crossrefed >= mincrossrefs times
my $cr2 = q|  \entry{cr2}{inbook}{}
    \name{labelname}{1}{}{%
      {{hash=F1}{Fumble}{F\bibinitperiod}{Frederick}{F\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{hash=F1}{Fumble}{F\bibinitperiod}{Frederick}{F\bibinitperiod}{}{}{}{}}%
    }
    \name{editor}{1}{}{%
      {{hash=E1}{Erbriss}{E\bibinitperiod}{Edgar}{E\bibinitperiod}{}{}{}{}}%
    }
    \list{institution}{1}{%
      {Institution}%
    }
    \list{publisher}{1}{%
      {Grimble}%
    }
    \strng{namehash}{FF1}
    \strng{fullhash}{FF1}
    \field{sortinit}{F}
    \field{labelyear}{1974}
    \field{booktitle}{Graphs of the Continent}
    \strng{crossref}{cr_m}
    \field{origyear}{1943}
    \field{title}{Fabulous Fourier Forms}
    \field{year}{1974}
    \warn{\item Field 'school' is aliased to field 'institution' but both are defined in entry with key 'cr2' - skipping field 'school'}
  \endentry

|;

# This is included as it is crossrefed >= mincrossrefs times
# Notice lack of labelname and hashes because the only name is EDITOR and useeditor is false
my $cr_m = q|  \entry{cr_m}{book}{}
    \name{editor}{1}{}{%
      {{hash=E1}{Erbriss}{E\bibinitperiod}{Edgar}{E\bibinitperiod}{}{}{}{}}%
    }
    \list{publisher}{1}{%
      {Grimble}%
    }
    \strng{namehash}{1}
    \strng{fullhash}{1}
    \field{sortinit}{G}
    \field{labelyear}{1974}
    \field{title}{Graphs of the Continent}
    \field{year}{1974}
  \endentry

|;

# crossref field is included as the parent is cited
my $cr3 = q|  \entry{cr3}{inbook}{}
    \name{labelname}{1}{}{%
      {{hash=A1}{Aptitude}{A\bibinitperiod}{Arthur}{A\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{hash=A1}{Aptitude}{A\bibinitperiod}{Arthur}{A\bibinitperiod}{}{}{}{}}%
    }
    \name{editor}{1}{}{%
      {{hash=M1}{Monkley}{M\bibinitperiod}{Mark}{M\bibinitperiod}{}{}{}{}}%
    }
    \list{publisher}{1}{%
      {Rancour}%
    }
    \strng{namehash}{AA1}
    \strng{fullhash}{AA1}
    \field{sortinit}{A}
    \field{labelyear}{1996}
    \field{booktitle}{Beasts of the Burbling Burns}
    \strng{crossref}{crt}
    \field{eprinttype}{sometype}
    \field{origyear}{1934}
    \field{title}{Arrangements of All Articles}
    \field{year}{1996}
    \warn{\item Field 'archiveprefix' is aliased to field 'eprinttype' but both are defined in entry with key 'cr3' - skipping field 'archiveprefix'}
  \endentry

|;

# cited as normal
my $crt = q|  \entry{crt}{book}{}
    \name{editor}{1}{}{%
      {{hash=M1}{Monkley}{M\bibinitperiod}{Mark}{M\bibinitperiod}{}{}{}{}}%
    }
    \list{publisher}{1}{%
      {Rancour}%
    }
    \strng{namehash}{1}
    \strng{fullhash}{1}
    \field{sortinit}{B}
    \field{labelyear}{1996}
    \field{title}{Beasts of the Burbling Burns}
    \field{year}{1996}
  \endentry

|;

# various event fields inherited correctly
my $cr6 = q|  \entry{cr6}{inproceedings}{}
    \name{labelname}{1}{}{%
      {{hash=A2}{Author}{A\bibinitperiod}{Firstname}{F\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{hash=A2}{Author}{A\bibinitperiod}{Firstname}{F\bibinitperiod}{}{}{}{}}%
    }
    \name{editor}{1}{}{%
      {{hash=E2}{Editor}{E\bibinitperiod}{}{}{}{}{}{}}%
    }
    \list{location}{1}{%
      {Address}%
    }
    \strng{namehash}{AF1}
    \strng{fullhash}{AF1}
    \field{sortinit}{A}
    \field{labelyear}{2009}
    \field{booktitle}{Manual booktitle}
    \field{eventday}{21}
    \field{eventendday}{24}
    \field{eventendmonth}{08}
    \field{eventendyear}{2009}
    \field{eventmonth}{08}
    \field{eventtitle}{Title of the event}
    \field{eventyear}{2009}
    \field{title}{Title of inproceeding}
    \field{venue}{Location of event}
    \field{year}{2009}
    \field{pages}{123\bibrangedash}
  \endentry

|;

# Special fields inherited correctly
my $cr7 = q|  \entry{cr7}{inbook}{}
    \name{labelname}{1}{}{%
      {{hash=A2}{Author}{A\bibinitperiod}{Firstname}{F\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{hash=A2}{Author}{A\bibinitperiod}{Firstname}{F\bibinitperiod}{}{}{}{}}%
    }
    \name{bookauthor}{1}{}{%
      {{hash=B1}{Bookauthor}{B\bibinitperiod}{Brian}{B\bibinitperiod}{}{}{}{}}%
    }
    \list{publisher}{1}{%
      {Publisher of proceeding}%
    }
    \strng{namehash}{AF1}
    \strng{fullhash}{AF1}
    \field{sortinit}{A}
    \field{labelyear}{2010}
    \field{booksubtitle}{Book Subtitle}
    \field{booktitle}{Book Title}
    \field{booktitleaddon}{Book Titleaddon}
    \field{title}{Title of Book bit}
    \field{year}{2010}
    \field{pages}{123\bibrangedash 126}
    \verb{verbb}
    \verb String
    \endverb
  \endentry

|;

# Default inheritance supressed except for specified
my $cr8 = q|  \entry{cr8}{incollection}{}
    \name{labelname}{1}{}{%
      {{hash=S1}{Smith}{S\bibinitperiod}{Firstname}{F\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{hash=S1}{Smith}{S\bibinitperiod}{Firstname}{F\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{SF1}
    \strng{fullhash}{SF1}
    \field{sortinit}{S}
    \field{labelyear}{2010}
    \field{booktitle}{Book Title}
    \field{title}{Title of Collection bit}
    \field{year}{2010}
    \field{pages}{1\bibrangedash 12}
  \endentry

|;

# xref field is included as the parent is included by being crossrefed >= mincrossrefs times
my $xr1 = q|  \entry{xr1}{inbook}{}
    \name{labelname}{1}{}{%
      {{hash=Z1}{Zentrum}{Z\bibinitperiod}{Zoe}{Z\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{hash=Z1}{Zentrum}{Z\bibinitperiod}{Zoe}{Z\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{ZZ1}
    \strng{fullhash}{ZZ1}
    \field{sortinit}{Z}
    \field{origyear}{1921}
    \field{title}{Moods Mildly Modified}
    \strng{xref}{xrm}
  \endentry

|;

# xref field is included as the parent is included by being crossrefed >= mincrossrefs times
my $xr2 = q|  \entry{xr2}{inbook}{}
    \name{labelname}{1}{}{%
      {{hash=I1}{Instant}{I\bibinitperiod}{Ian}{I\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{hash=I1}{Instant}{I\bibinitperiod}{Ian}{I\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{II1}
    \strng{fullhash}{II1}
    \field{sortinit}{I}
    \field{origyear}{1926}
    \field{title}{Migraines Multiplying Madly}
    \strng{xref}{xrm}
  \endentry

|;

# This is included as it is crossrefed >= mincrossrefs times
# Notice lack of labelname and hashes because the only name is EDITOR and useeditor is false
my $xrm = q|  \entry{xrm}{book}{}
    \name{editor}{1}{}{%
      {{hash=P1}{Prendergast}{P\bibinitperiod}{Peter}{P\bibinitperiod}{}{}{}{}}%
    }
    \list{publisher}{1}{%
      {Mainstream}%
    }
    \strng{namehash}{1}
    \strng{fullhash}{1}
    \field{sortinit}{C}
    \field{labelyear}{1970}
    \field{title}{Calligraphy, Calisthenics, Culture}
    \field{year}{1970}
  \endentry

|;

# xref field is included as the parent is cited
my $xr3 = q|  \entry{xr3}{inbook}{}
    \name{labelname}{1}{}{%
      {{hash=N1}{Normal}{N\bibinitperiod}{Norman}{N\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{hash=N1}{Normal}{N\bibinitperiod}{Norman}{N\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{NN1}
    \strng{fullhash}{NN1}
    \field{sortinit}{N}
    \field{origyear}{1923}
    \field{title}{Russion Regalia Revisited}
    \strng{xref}{xrt}
  \endentry

|;

# cited as normal
my $xrt = q|  \entry{xrt}{book}{}
    \name{editor}{1}{}{%
      {{hash=L1}{Lunders}{L\bibinitperiod}{Lucy}{L\bibinitperiod}{}{}{}{}}%
    }
    \list{publisher}{1}{%
      {Middling}%
    }
    \strng{namehash}{1}
    \strng{fullhash}{1}
    \field{sortinit}{K}
    \field{labelyear}{1977}
    \field{title}{Kings, Cork and Calculation}
    \field{year}{1977}
  \endentry

|;

# No crossref field as parent is not cited (mincrossrefs < 2)
my $cr4 = q|  \entry{cr4}{inbook}{}
    \name{labelname}{1}{}{%
      {{hash=M2}{Mumble}{M\bibinitperiod}{Morris}{M\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{hash=M2}{Mumble}{M\bibinitperiod}{Morris}{M\bibinitperiod}{}{}{}{}}%
    }
    \name{editor}{1}{}{%
      {{hash=J1}{Jermain}{J\bibinitperiod}{Jeremy}{J\bibinitperiod}{}{}{}{}}%
    }
    \list{publisher}{1}{%
      {Pillsbury}%
    }
    \strng{namehash}{MM1}
    \strng{fullhash}{MM1}
    \field{sortinit}{M}
    \field{labelyear}{1945}
    \field{booktitle}{Vanquished, Victor, Vandal}
    \field{origyear}{1911}
    \field{title}{Enterprising Entities}
    \field{year}{1945}
  \endentry

|;

# No crossref field as parent is not cited (mincrossrefs < 2)
my $xr4 = q|  \entry{xr4}{inbook}{}
    \name{labelname}{1}{}{%
      {{hash=M3}{Mistrel}{M\bibinitperiod}{Megan}{M\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{hash=M3}{Mistrel}{M\bibinitperiod}{Megan}{M\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{MM2}
    \strng{fullhash}{MM2}
    \field{sortinit}{M}
    \field{origyear}{1933}
    \field{title}{Lumbering Lunatics}
  \endentry

|;

# Missing keys in xref/crossref should be deleted during datasource parse
# So these two should have no xref/crossref data in them
my $mxr = q|  \entry{mxr}{inbook}{}
    \name{labelname}{1}{}{%
      {{hash=M3}{Mistrel}{M\bibinitperiod}{Megan}{M\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{hash=M3}{Mistrel}{M\bibinitperiod}{Megan}{M\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{MM2}
    \strng{fullhash}{MM2}
    \field{sortinit}{M}
    \field{origyear}{1933}
    \field{title}{Lumbering Lunatics}
  \endentry

|;

my $mcr = q|  \entry{mcr}{inbook}{}
    \name{labelname}{1}{}{%
      {{hash=M3}{Mistrel}{M\bibinitperiod}{Megan}{M\bibinitperiod}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{hash=M3}{Mistrel}{M\bibinitperiod}{Megan}{M\bibinitperiod}{}{}{}{}}%
    }
    \strng{namehash}{MM2}
    \strng{fullhash}{MM2}
    \field{sortinit}{M}
    \field{origyear}{1933}
    \field{title}{Lumbering Lunatics}
  \endentry

|;


is($out->get_output_entry($main0,'cr1'), $cr1, 'crossref test 1');
is($out->get_output_entry($main0,'cr2'), $cr2, 'crossref test 2');
is($out->get_output_entry($main0,'cr_m'), $cr_m, 'crossref test 3');
is($out->get_output_entry($main0,'cr3'), $cr3, 'crossref test 4');
is($out->get_output_entry($main0,'crt'), $crt, 'crossref test 5');
is($out->get_output_entry($main0,'cr4'), $cr4, 'crossref test 6');
is($section0->has_citekey('crn'), 0,'crossref test 7');
is($out->get_output_entry($main0,'cr6'), $cr6, 'crossref test (inheritance) 8');
is($out->get_output_entry($main0,'cr7'), $cr7, 'crossref test (inheritance) 9');
is($out->get_output_entry($main0,'cr8'), $cr8, 'crossref test (inheritance) 10');
is($out->get_output_entry($main0,'xr1'), $xr1, 'xref test 1');
is($out->get_output_entry($main0,'xr2'), $xr2, 'xref test 2');
is($out->get_output_entry($main0,'xrm'), $xrm, 'xref test 3');
is($out->get_output_entry($main0,'xr3'), $xr3, 'xref test 4');
is($out->get_output_entry($main0,'xrt'), $xrt, 'xref test 5');
is($out->get_output_entry($main0,'xr4'), $xr4, 'xref test 6');
is($section0->has_citekey('xrn'), 0,'xref test 7');
is($out->get_output_entry($main0,'mxr'), $mxr, 'missing xref test');
is($out->get_output_entry($main0,'mcr'), $mcr, 'missing crossef test');
is($section1->has_citekey('crn'), 0,'mincrossrefs reset between sections');

