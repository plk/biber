use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 12;

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

$biber->prepare;

my $l1 = q|\item Invalid format of field 'year'
\item Invalid format of field 'origdate'
\item Invalid format of field 'urldate'
|;
my $l2 = q|\item Invalid format of field 'origdate'
|;
my $l3 = q|\item Invalid format of field 'urldate'
|;
my $l4 = q|\item Invalid format of field 'date'
|;
my $l5 = q|\item Invalid format of field 'date'
|;
my $l6 = q|\item Value out of bounds for field/date component 'month'
|;
my $l7 = q|\item Value out of bounds for field/date component 'eventday'
|;
my $l8 = q|\item Invalid format of field 'year'
|;

my $l11 = q|\item Field conflict - 'date' will potentially overwrite 'year' and/or 'month'. Please use 'date' OR 'year' and 'month'
|;
my $l12 = q|\item Field conflict - 'date' will potentially overwrite 'year' and/or 'month'. Please use 'date' OR 'year' and 'month'
|;

is($biber->{bib}{l1}{warnings}, $l1, 'Format test 1' ) ;
is($biber->{bib}{l2}{warnings}, $l2, 'Format test 2' ) ;
is($biber->{bib}{l3}{warnings}, $l3, 'Format test 3' ) ;
is($biber->{bib}{l4}{warnings}, $l4, 'Format test 4' ) ;
is($biber->{bib}{l5}{warnings}, $l5, 'Format test 5' ) ;
is($biber->{bib}{l6}{warnings}, $l6, 'Format test 6' ) ;
is($biber->{bib}{l7}{warnings}, $l7, 'Format test 7' ) ;
is($biber->{bib}{l8}{warnings}, $l8, 'Format test 8' ) ;
ok(! defined($biber->{bib}{l9}{warnings}), 'Format test 9' ) ;
ok(! defined($biber->{bib}{l10}{warnings}), 'Format test 10' ) ;
is($biber->{bib}{l11}{warnings}, $l11, 'Format test 11' ) ;
is($biber->{bib}{l12}{warnings}, $l12, 'Format test 12' ) ;

unlink "$bibfile.utf8";
