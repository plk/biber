use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 32;

use Biber;
use Biber::Output::BBL;
use Biber::Utils;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
chdir("t/tdata");

# Set up Biber object
my $biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('dateformats.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'C');

# Biblatex options
Biber::Config->setblxoption('labelyear', [ 'year' ]);

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $bibentries = $biber->sections->get_section('0')->bib;
my $section = $biber->sections->get_section('0');

my $l1 = [ "Invalid format of field 'origdate' - ignoring field in entry 'L1'",
           "Invalid format of field 'urldate' - ignoring field in entry 'L1'",
           "Value out of bounds for field/date component 'month' - ignoring in entry 'L1'" ];
my $l2 = [ "Invalid format of field 'origdate' - ignoring field in entry 'L2'" ];
my $l3 = [ "Invalid format of field 'urldate' - ignoring field in entry 'L3'" ];
my $l4 = [ "Invalid format of field 'date' - ignoring field in entry 'L4'" ];
my $l5 = [ "Invalid format of field 'date' - ignoring field in entry 'L5'" ];
my $l6 = [ "Value out of bounds for field/date component 'month' - ignoring in entry 'L6'" ];
my $l7 = [ "Value out of bounds for field/date component 'eventday' - ignoring in entry 'L7'" ];
my $l8 = [ "Invalid format of field 'month' - ignoring field in entry 'L8'" ];
my $l11 = [ "Field conflict - both 'date' and 'year' used - ignoring field 'year' in entry 'L11'" ];
my $l12 = [ "Field conflict - both 'date' and 'month' used - ignoring field 'month' in entry 'L12'" ];



is_deeply($bibentries->entry('l1')->get_field('warnings'), $l1, 'Date format test 1' ) ;
ok(is_undef($bibentries->entry('l1')->get_field('origyear')), 'Date format test 1a - ORIGYEAR undef since ORIGDATE is bad' ) ;
ok(is_undef($bibentries->entry('l1')->get_field('urlyear')), 'Date format test 1b - URLYEAR undef since URLDATE is bad' ) ;
ok(is_undef($bibentries->entry('l1')->get_field('month')), 'Date format test 1c - MONTH undef since not integer' ) ;
is_deeply($bibentries->entry('l2')->get_field('warnings'), $l2, 'Date format test 2' ) ;
is_deeply($bibentries->entry('l3')->get_field('warnings'), $l3, 'Date format test 3' ) ;
is_deeply($bibentries->entry('l4')->get_field('warnings'), $l4, 'Date format test 4' ) ;
is_deeply($bibentries->entry('l5')->get_field('warnings'), $l5, 'Date format test 5' ) ;
is_deeply($bibentries->entry('l6')->get_field('warnings'), $l6, 'Date format test 6' ) ;
is_deeply($bibentries->entry('l7')->get_field('warnings'), $l7, 'Date format test 7' ) ;
is_deeply($bibentries->entry('l8')->get_field('warnings'), $l8, 'Date format test 8' ) ;
ok(is_undef($bibentries->entry('l8')->get_field('month')), 'Date format test 8b - MONTH undef since not integer' ) ;
ok(is_undef($bibentries->entry('l9')->get_field('warnings')), 'Date format test 9' ) ;
ok(is_undef($bibentries->entry('l10')->get_field('warnings')), 'Date format test 10' ) ;
is_deeply($bibentries->entry('l11')->get_field('warnings'), $l11, 'Date format test 11' );
is($bibentries->entry('l11')->get_field('year'), '1996', 'Date format test 11a - DATE overrides YEAR' ) ;
is_deeply($bibentries->entry('l12')->get_field('warnings'), $l12, 'Date format test 12' );
is($bibentries->entry('l12')->get_field('month'), '01', 'Date format test 12a - DATE overrides MONTH' ) ;
# it means something if endyear is defined but null ("1935-")
ok(is_def_and_null($bibentries->entry('l13')->get_field('endyear')), 'Date format test 13 - range with no end' ) ;
ok(is_undef($bibentries->entry('l13')->get_field('endmonth')), 'Date format test 13a - ENDMONTH undef for open-ended range' ) ;
ok(is_undef($bibentries->entry('l13')->get_field('endday')), 'Date format test 13b - ENDDAY undef for open-ended range' ) ;
is($bibentries->entry('l13')->get_field('endyear'), '', 'Date format test 13c - labelyear open-ended range');

my $l14e = $bibentries->entry('l14');
ok((($l14e->get_field('endyear') eq $l14e->get_field('year')) and
   ($l14e->get_field($l14e->get_field('labelyearname')) eq $l14e->get_field('year'))), 'Date format test 14 - labelyear same as YEAR when ENDYEAR == YEAR');


ok(is_undef($bibentries->entry('l15')->get_field('labelyearname')), 'Date format test 15 - labelyear should be undef, no DATE or YEAR');

# reset options and regenerate information
Biber::Config->setblxoption('labelyear', [ 'year', 'eventyear', 'origyear' ]);
$bibentries->entry('l17')->del_field('year');
$bibentries->entry('l17')->del_field('month');
$biber->prepare;
$out = $biber->get_output_obj;

is($bibentries->entry('l16')->get_field('labelyearname'), 'eventyear', 'Date format test 16 - labelyearname = eventyear' ) ;

my $l16e = $bibentries->entry('l16');
ok(($l16e->get_field($l16e->get_field('labelyearname')) eq $l16e->get_field('eventyear')), 'Date format test 16a - labelyear = eventyear value' );

is($bibentries->entry('l17')->get_field('labelyearname'), 'year', 'Date format test 17 - labelyearname = YEAR' ) ;

my $l17e = $bibentries->entry('l17');
ok((is_def($l17e->get_field('origyear')) and
    ($l17e->get_field('endyear') eq $l17e->get_field('year')) and
    ($l17e->get_field($l17e->get_field('labelyearname')) eq $l17e->get_field('year'))), 'Date format test 17a - labelyear = YEAR value when ENDYEAR is the same and ORIGYEAR is also present' );


# reset options and regenerate information
Biber::Config->setblxoption('labelyear', [ 'origyear', 'year', 'eventyear' ]);
$bibentries->entry('l17')->del_field('year');
$bibentries->entry('l17')->del_field('month');
$biber->prepare;
$out = $biber->get_output_obj;

is($bibentries->entry('l17')->get_field('labelyearname'), 'origyear', 'Date format test 17b - labelyearname = ORIGYEAR' ) ;


ok((is_def($l17e->get_field('year')) and
    ($l17e->get_field('origendyear') eq $l17e->get_field('origyear')) and
    ($l17e->get_field($l17e->get_field('labelyearname')) eq $l17e->get_field('origyear'))), 'Date format test 17c - labelyear = ORIGYEAR value when ENDORIGYEAR is the same and YEAR is also present' );

# reset options and regenerate information
Biber::Config->setblxoption('labelyear', [ 'eventyear', 'year', 'origyear' ], 'PER_TYPE', 'book');
$bibentries->entry('l17')->del_field('year');
$bibentries->entry('l17')->del_field('month');
$biber->prepare;
$out = $biber->get_output_obj;

is($bibentries->entry('l17')->get_field('labelyearname'), 'eventyear', 'Date format test 17d - labelyearname = EVENTYEAR' ) ;

my $l17bbl = $out->get_output_entry('l17');
my $l17ly = qr/\\field\{labelyear\}\{1998\\bibdatedash 2004\}/ms;
ok(($l17bbl =~ m/$l17ly/), 'Date format test 17e - labelyear = EVENTYEAR-EVENTENDYEAR');

unlink "*.utf8";
