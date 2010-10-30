use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 17;

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

# Now generate the information
$biber->prepare;

my $section = $biber->sections->get_section(0);
my $out = $biber->get_output_obj;

# crossref field is included as the parent is included by being crossrefed >= mincrossrefs times
my $cr1 = q|  \entry{cr1}{inbook}{}
    \name{labelname}{1}{}{%
      {{}{Gullam}{G.}{Graham}{G.}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{}{Gullam}{G.}{Graham}{G.}{}{}{}{}}%
    }
    \name{editor}{1}{}{%
      {{}{Erbriss}{E.}{Edgar}{E.}{}{}{}{}}%
    }
    \list{publisher}{1}{%
      {Grimble}%
    }
    \strng{namehash}{GG1}
    \strng{fullhash}{GG1}
    \field{sortinit}{G}
    \field{labelyear}{1974}
    \field{year}{1974}
    \field{origyear}{1955}
    \field{title}{Great and Good Graphs}
    \field{booktitle}{Graphs of the Continent}
    \field{eprinttype}{SomEPrFiX}
    \field{eprintclass}{SOMECLASS}
    \strng{crossref}{crm}
  \endentry

|;

# crossref field is included as the parent is included by being crossrefed >= mincrossrefs times
my $cr2 = q|  \entry{cr2}{inbook}{}
    \name{labelname}{1}{}{%
      {{}{Fumble}{F.}{Frederick}{F.}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{}{Fumble}{F.}{Frederick}{F.}{}{}{}{}}%
    }
    \name{editor}{1}{}{%
      {{}{Erbriss}{E.}{Edgar}{E.}{}{}{}{}}%
    }
    \list{publisher}{1}{%
      {Grimble}%
    }
    \list{institution}{1}{%
      {Institution}%
    }
    \strng{namehash}{FF1}
    \strng{fullhash}{FF1}
    \field{sortinit}{F}
    \field{labelyear}{1974}
    \field{year}{1974}
    \field{origyear}{1943}
    \field{title}{Fabulous Fourier Forms}
    \field{booktitle}{Graphs of the Continent}
    \strng{crossref}{crm}
  \endentry

|;

# This is included as it is crossrefed >= mincrossrefs times
my $crm = q|  \entry{crm}{book}{}
    \name{editor}{1}{}{%
      {{}{Erbriss}{E.}{Edgar}{E.}{}{}{}{}}%
    }
    \list{publisher}{1}{%
      {Grimble}%
    }
    \strng{namehash}{1}
    \strng{fullhash}{1}
    \field{sortinit}{G}
    \field{labelyear}{1974}
    \field{year}{1974}
    \field{title}{Graphs of the Continent}
  \endentry

|;

# crossref field is included as the parent is cited
my $cr3 = q|  \entry{cr3}{inbook}{}
    \name{labelname}{1}{}{%
      {{}{Aptitude}{A.}{Arthur}{A.}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{}{Aptitude}{A.}{Arthur}{A.}{}{}{}{}}%
    }
    \name{editor}{1}{}{%
      {{}{Monkley}{M.}{Mark}{M.}{}{}{}{}}%
    }
    \list{publisher}{1}{%
      {Rancour}%
    }
    \strng{namehash}{AA1}
    \strng{fullhash}{AA1}
    \field{sortinit}{A}
    \field{labelyear}{1996}
    \field{year}{1996}
    \field{origyear}{1934}
    \field{title}{Arrangements of All Articles}
    \field{booktitle}{Beasts of the Burbling Burns}
    \field{eprinttype}{sometype}
    \strng{crossref}{crt}
  \endentry

|;

# cited as normal
my $crt = q|  \entry{crt}{book}{}
    \name{editor}{1}{}{%
      {{}{Monkley}{M.}{Mark}{M.}{}{}{}{}}%
    }
    \list{publisher}{1}{%
      {Rancour}%
    }
    \strng{namehash}{1}
    \strng{fullhash}{1}
    \field{sortinit}{B}
    \field{labelyear}{1996}
    \field{year}{1996}
    \field{title}{Beasts of the Burbling Burns}
  \endentry

|;

# various event fields inherited correctly
my $cr6 = q|  \entry{cr6}{inproceedings}{}
    \name{labelname}{1}{}{%
      {{}{Author}{A.}{Firstname}{F.}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{}{Author}{A.}{Firstname}{F.}{}{}{}{}}%
    }
    \name{editor}{1}{}{%
      {{}{Editor}{E.}{}{}{}{}{}{}}%
    }
    \list{publisher}{1}{%
      {Publisher of proceeding}%
    }
    \list{location}{1}{%
      {Address}%
    }
    \strng{namehash}{AF1}
    \strng{fullhash}{AF1}
    \field{sortinit}{A}
    \field{labelyear}{2009}
    \field{year}{2009}
    \field{eventyear}{2009}
    \field{eventendyear}{2009}
    \field{eventmonth}{08}
    \field{eventendmonth}{08}
    \field{eventday}{21}
    \field{eventendday}{24}
    \field{title}{Title of inproceeding}
    \field{booktitle}{Manual booktitle}
    \field{eventtitle}{Title of the event}
    \field{venue}{Location of event}
    \field{pages}{123\bibrangedash 126}
  \endentry

|;

# Special fields inherited correctly
my $cr7 = q|  \entry{cr7}{inbook}{}
    \name{labelname}{1}{}{%
      {{}{Author}{A.}{Firstname}{F.}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{}{Author}{A.}{Firstname}{F.}{}{}{}{}}%
    }
    \name{bookauthor}{1}{}{%
      {{}{Bookauthor}{B.}{Brian}{B.}{}{}{}{}}%
    }
    \list{publisher}{1}{%
      {Publisher of proceeding}%
    }
    \strng{namehash}{AF1}
    \strng{fullhash}{AF1}
    \field{sortinit}{A}
    \field{labelyear}{2010}
    \field{year}{2010}
    \field{title}{Title of Book bit}
    \field{booktitle}{Book Title}
    \field{booksubtitle}{Book Subtitle}
    \field{booktitleaddon}{Book Titleaddon}
    \field{pages}{123\bibrangedash 126}
  \endentry

|;

# Default inheritance supressed
my $cr8 = q|  \entry{cr8}{incollection}{}
    \name{labelname}{1}{}{%
      {{}{Smith}{S.}{Firstname}{F.}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{}{Smith}{S.}{Firstname}{F.}{}{}{}{}}%
    }
    \strng{namehash}{SF1}
    \strng{fullhash}{SF1}
    \field{sortinit}{S}
    \field{labelyear}{2010}
    \field{year}{2010}
    \field{title}{Title of Collection bit}
    \field{pages}{1\bibrangedash 12}
  \endentry

|;

# xref field is included as the parent is included by being crossrefed >= mincrossrefs times
my $xr1 = q|  \entry{xr1}{inbook}{}
    \name{labelname}{1}{}{%
      {{}{Zentrum}{Z.}{Zoe}{Z.}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{}{Zentrum}{Z.}{Zoe}{Z.}{}{}{}{}}%
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
      {{}{Instant}{I.}{Ian}{I.}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{}{Instant}{I.}{Ian}{I.}{}{}{}{}}%
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
my $xrm = q|  \entry{xrm}{book}{}
    \name{editor}{1}{}{%
      {{}{Prendergast}{P.}{Peter}{P.}{}{}{}{}}%
    }
    \list{publisher}{1}{%
      {Mainstream}%
    }
    \strng{namehash}{1}
    \strng{fullhash}{1}
    \field{sortinit}{C}
    \field{labelyear}{1970}
    \field{year}{1970}
    \field{title}{Calligraphy, Calisthenics, Culture}
  \endentry

|;

# xref field is included as the parent is cited
my $xr3 = q|  \entry{xr3}{inbook}{}
    \name{labelname}{1}{}{%
      {{}{Normal}{N.}{Norman}{N.}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{}{Normal}{N.}{Norman}{N.}{}{}{}{}}%
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
      {{}{Lunders}{L.}{Lucy}{L.}{}{}{}{}}%
    }
    \list{publisher}{1}{%
      {Middling}%
    }
    \strng{namehash}{1}
    \strng{fullhash}{1}
    \field{sortinit}{K}
    \field{labelyear}{1977}
    \field{year}{1977}
    \field{title}{Kings, Cork and Calculation}
  \endentry

|;

# No crossref field as parent is not cited (mincrossrefs < 2)
my $cr4 = q|  \entry{cr4}{inbook}{}
    \name{labelname}{1}{}{%
      {{}{Mumble}{M.}{Morris}{M.}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{}{Mumble}{M.}{Morris}{M.}{}{}{}{}}%
    }
    \name{editor}{1}{}{%
      {{}{Jermain}{J.}{Jeremy}{J.}{}{}{}{}}%
    }
    \list{publisher}{1}{%
      {Pillsbury}%
    }
    \strng{namehash}{MM1}
    \strng{fullhash}{MM1}
    \field{sortinit}{M}
    \field{labelyear}{1945}
    \field{year}{1945}
    \field{origyear}{1911}
    \field{title}{Enterprising Entities}
    \field{booktitle}{Vanquished, Victor, Vandal}
  \endentry

|;

# No crossref field as parent is not cited (mincrossrefs < 2)
my $xr4 = q|  \entry{xr4}{inbook}{}
    \name{labelname}{1}{}{%
      {{}{Mistrel}{M.}{Megan}{M.}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{}{Mistrel}{M.}{Megan}{M.}{}{}{}{}}%
    }
    \strng{namehash}{MM2}
    \strng{fullhash}{MM2}
    \field{sortinit}{M}
    \field{origyear}{1933}
    \field{title}{Lumbering Lunatics}
  \endentry

|;


is($out->get_output_entry('cr1'), $cr1, 'crossref test 1');
is($out->get_output_entry('cr2'), $cr2, 'crossref test 2');
is($out->get_output_entry('crm'), $crm, 'crossref test 3');
is($out->get_output_entry('cr3'), $cr3, 'crossref test 4');
is($out->get_output_entry('crt'), $crt, 'crossref test 5');
is($out->get_output_entry('cr4'), $cr4, 'crossref test 6');
is($section->has_citekey('crn'), 0,'crossref test 7');
is($out->get_output_entry('cr6'), $cr6, 'crossref test (inheritance) 8');
is($out->get_output_entry('cr7'), $cr7, 'crossref test (inheritance) 9');
is($out->get_output_entry('cr8'), $cr8, 'crossref test (inheritance) 10');
is($out->get_output_entry('xr1'), $xr1, 'xref test 1');
is($out->get_output_entry('xr2'), $xr2, 'xref test 2');
is($out->get_output_entry('xrm'), $xrm, 'xref test 3');
is($out->get_output_entry('xr3'), $xr3, 'xref test 4');
is($out->get_output_entry('xrt'), $xrt, 'xref test 5');
is($out->get_output_entry('xr4'), $xr4, 'xref test 6');
is($section->has_citekey('xrn'), 0,'xref test 7');

unlink "*.utf8";
