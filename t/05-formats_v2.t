use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 23;

use Biber;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

chdir("t/tdata");

my $bibfile;
my $biber = Biber->new;
$biber->{config}{fastsort} = 1;
$biber->{config}{locale} = 'C';
$biber->parse_auxfile_v2('50-formats_v2.aux');
$bibfile = $biber->config('bibdata')->[0] . '.bib';
$biber->parse_bibtex($bibfile);

$biber->{config}{biblatex}{global}{labelyear} = 1;
$biber->prepare;

my $l1 = q|\item Invalid format of field 'year' - ignoring field
\item Invalid format of field 'origdate' - ignoring field
\item Invalid format of field 'urldate' - ignoring field
\item Value out of bounds for field/date component 'month' - ignoring
|;
my $l2 = q|\item Invalid format of field 'origdate' - ignoring field
|;
my $l3 = q|\item Invalid format of field 'urldate' - ignoring field
|;
my $l4 = q|\item Invalid format of field 'date' - ignoring field
|;
my $l5 = q|\item Invalid format of field 'date' - ignoring field
|;
my $l6 = q|\item Value out of bounds for field/date component 'month' - ignoring
|;
my $l7 = q|\item Value out of bounds for field/date component 'eventday' - ignoring
|;
my $l8 = q|\item Invalid format of field 'year' - ignoring field
\item Invalid format of field 'month' - ignoring field
|;

my $l11 = q|\item Field conflict - both 'date' and 'year' used - ignoring field 'year'
|;
my $l12 = q|\item Field conflict - both 'date' and 'month' used - ignoring field 'month'
|;

my $l13c = q|\entry{L13}{book}{}
  \name{author}{2}{%
    {{Doe}{D.}{John}{J.}{}{}{}{}}%
    {{Abrahams}{A.}{Albert}{A.}{}{}{}{}}%
  }
  \list{publisher}{1}{%
    {Oxford}%
  }
  \strng{namehash}{DJAA1}
  \strng{fullhash}{DJAA1}
  \field{sortinit}{D}
  \field{extrayear}{4}
  \field{labelyear}{1996}
  \count{uniquename}{0}
  \field{year}{1996}
  \field{day}{01}
  \field{month}{01}
  \field{title}{Title 2}
\endentry

|;

is($biber->{bib}{l1}{warnings}, $l1, 'Format test 1' ) ;
ok(! defined($biber->{bib}{l1}{origyear}), 'Format test 1a - ORIGYEAR undef since ORIGDATE is bad' ) ;
ok(! defined($biber->{bib}{l1}{urlyear}), 'Format test 1b - URLYEAR undef since URLDATE is bad' ) ;
ok(! defined($biber->{bib}{l1}{month}), 'Format test 1c - MONTH undef since not integer' ) ;
is($biber->{bib}{l2}{warnings}, $l2, 'Format test 2' ) ;
is($biber->{bib}{l3}{warnings}, $l3, 'Format test 3' ) ;
is($biber->{bib}{l4}{warnings}, $l4, 'Format test 4' ) ;
is($biber->{bib}{l5}{warnings}, $l5, 'Format test 5' ) ;
is($biber->{bib}{l6}{warnings}, $l6, 'Format test 6' ) ;
is($biber->{bib}{l7}{warnings}, $l7, 'Format test 7' ) ;
is($biber->{bib}{l8}{warnings}, $l8, 'Format test 8' ) ;
ok(! defined($biber->{bib}{l8}{year}), 'Format test 8a - YEAR undef since not integer' ) ;
ok(! defined($biber->{bib}{l8}{month}), 'Format test 8b - MONTH undef since not integer' ) ;
ok(! defined($biber->{bib}{l9}{warnings}), 'Format test 9' ) ;
ok(! defined($biber->{bib}{l10}{warnings}), 'Format test 10' ) ;
is($biber->{bib}{l11}{warnings}, $l11, 'Format test 11' ) ;
is($biber->{bib}{l11}{year}, '1996', 'Format test 11a - DATE overrides YEAR' ) ;
is($biber->{bib}{l12}{warnings}, $l12, 'Format test 12' ) ;
is($biber->{bib}{l12}{month}, '01', 'Format test 12a - DATE overrides MONTH' ) ;
is($biber->{bib}{l13}{endyear}, '', 'Format test 13 - range with no end' ) ;
ok(! defined($biber->{bib}{l13}{endmonth}), 'Format test 13a - ENDMONTH undef for open-ended range' ) ;
ok(! defined($biber->{bib}{l13}{endday}), 'Format test 13b - ENDDAY undef for open-ended range' ) ;
is( $biber->_print_biblatex_entry('l13'), $l13c, 'Format test 13c - labelyeat open-ended range' ) ;

unlink "$bibfile.utf8";
