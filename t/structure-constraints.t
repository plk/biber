# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 14;

use Biber;
use Biber::Output::bbl;
use Biber::Utils;
use Log::Log4perl;
chdir("t/tdata");

# Set up Biber object
my $biber = Biber->new(noconf => 1);
my $LEVEL = 'ERROR';
my $l4pconf = qq|
    log4perl.category.main                             = $LEVEL, Screen
    log4perl.category.screen                           = $LEVEL, Screen
    log4perl.appender.Screen                           = Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.utf8                      = 1
    log4perl.appender.Screen.Threshold                 = $LEVEL
    log4perl.appender.Screen.stderr                    = 0
    log4perl.appender.Screen.layout                    = Log::Log4perl::Layout::SimpleLayout
|;
Log::Log4perl->init(\$l4pconf);

$biber->parse_ctrlfile('structure-constraints.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('validate_structure', 1);
Biber::Config->setoption('sortlocale', 'C');

# Now generate the information
$biber->prepare;

my $section = $biber->sections->get_section(0);
my $bibentries = $section->bibentries;

my $c1 = [ "Entry 'c1' - invalid entry type 'badtype' - defaulting to 'misc'" ];
my $c2 = [ "Entry 'c2' - invalid field 'badfield' for entrytype 'eta'",
           "Entry 'c2' - invalid field 'journaltitle' for entrytype 'eta'",
           "Missing mandatory field 'author' in entry 'c2'" ];
my $c3 = [ "Invalid format (integer) of field 'month' - ignoring field in entry 'c3'" ];
my $c4 = [ "Invalid value of field 'month' must be '<=12' - ignoring field in entry 'c4'",
           "Invalid value of field 'field1' must be '>=5' - ignoring field in entry 'c4'" ];
# There would also have been a date+year constraint violation in the next test if
# it weren't for the fact that the date processing in bibtex.pm already deals with this
# and removed the year field
my $c5 = [ "Overwriting field 'year' with year value from field 'date' for entry 'c5'",
           "Constraint violation - none of fields (field5, field6) must exist when all of fields (field2, field3, field4) exist. Ignoring them." ];
my $c6 = [ "Constraint violation - one of fields (field7, field8) must exist when all of fields (field1, field2) exist",
           "Constraint violation - all of fields (field9, field10) must exist when all of fields (field5, field6) exist" ];
my $c7 = [ "Missing mandatory field - one of 'fielda, fieldb' must be defined in entry 'c7'",
           "Constraint violation - none of fields (field7) must exist when one of fields (field5, field6) exist. Ignoring them."];
my $c8 = [ "Constraint violation - none of fields (field4) must exist when none of fields (field2, field3) exist. Ignoring them.",
           "Constraint violation - one of fields (field10, field11) must exist when none of fields (field8, field9) exist",
           "Constraint violation - all of fields (field12, field13) must exist when none of fields (field6) exist" ];

is_deeply($bibentries->entry('c1')->get_field('warnings'), $c1, 'Constraints test 1' );
is_deeply($bibentries->entry('c2')->get_field('warnings'), $c2, 'Constraints test 2' );
is_deeply($bibentries->entry('c3')->get_field('warnings'), $c3, 'Constraints test 3a' );
ok(is_undef($bibentries->entry('c3')->get_field('month')), 'Constraints test 3b' );
is_deeply($bibentries->entry('c4')->get_field('warnings'), $c4, 'Constraints test 4a' );
ok(is_undef($bibentries->entry('c4')->get_field('month')), 'Constraints test 4b' );
is_deeply($bibentries->entry('c5')->get_field('warnings'), $c5, 'Constraints test 5a' );
ok(is_undef($bibentries->entry('c5')->get_field('field5')), 'Constraints test 5b' );
ok(is_undef($bibentries->entry('c5')->get_field('field6')), 'Constraints test 5c' );
is_deeply($bibentries->entry('c6')->get_field('warnings'), $c6, 'Constraints test 6' );
is_deeply($bibentries->entry('c7')->get_field('warnings'), $c7, 'Constraints test 7a' );
ok(is_undef($bibentries->entry('c7')->get_field('field7')), 'Constraints test 7b' );
is_deeply($bibentries->entry('c8')->get_field('warnings'), $c8, 'Constraints test 8a' );
ok(is_undef($bibentries->entry('c8')->get_field('field4')), 'Constraints test 8b' );

