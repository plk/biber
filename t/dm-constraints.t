# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 16;

use Biber;
use Biber::Output::bbl;
use Biber::Utils;
use Log::Log4perl;
chdir("t/tdata");

use IPC::Run3;
use File::Spec;
use File::Which;
my $perl = which('perl');
my $stdout;

# This test will complain on the test linux servers as /usr/local/perl/bin/perl will not be
# returned by "which perl" and so the following workaround will fail to find the ISBN messaged file.
# Doesn't matter much but just in case when running "Build test" on the current test VMs, worth
# remembering.

# This is needed so that this env var is set to the runtime location of the message file and not
# the test runtime as this is altered by Module::Build which sets up $INC{} differently
run3  [ $perl, '-MBusiness::ISBN', '-e', 'print $INC{"Business/ISBN.pm"}' ], \undef, \$stdout, \undef;
my ($vol, $dir, undef) = File::Spec->splitpath($stdout);
$ENV{ISBN_RANGE_MESSAGE} = File::Spec->catpath($vol, "$dir/ISBN/", 'RangeMessage.xml');

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

$biber->parse_ctrlfile('dm-constraints.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');
Biber::Config->setoption('validate_datamodel', 1);

# Now generate the information
$biber->prepare;

my $section = $biber->sections->get_section(0);
my $bibentries = $section->bibentries;

my $c1 = [ "Datamodel: badtype entry 'c1' (dm-constraints.bib): Invalid entry type 'badtype' - defaulting to 'misc'" ];
my $c2 = [ "Datamodel: eta entry 'c2' (dm-constraints.bib): Field 'badfield' invalid in data model - ignoring",
           "Datamodel: eta entry 'c2' (dm-constraints.bib): Invalid field 'journaltitle' for entrytype 'eta'",
           "Datamodel: eta entry 'c2' (dm-constraints.bib): Missing mandatory field 'author'" ];
my $c3 = [ "Datamodel: etb entry 'c3' (dm-constraints.bib): Invalid value of field 'month' must be datatype 'datepart' - ignoring field",
           "Datamodel: etb entry 'c3' (dm-constraints.bib): Invalid value (pattern match fails) for field 'gender'" ];
my $c4 = [ "Datamodel: etb entry 'c4' (dm-constraints.bib): Invalid value of field 'month' must be '<=12' - ignoring field",
           "Datamodel: etb entry 'c4' (dm-constraints.bib): Invalid value of field 'field1' must be '>=5' - ignoring field" ];
# There would also have been a date+year constraint violation in the next test if
# it weren't for the fact that the date processing in bibtex.pm already deals with this
# and removed the year field
my $c5 = [ "Overwriting field 'year' with year value from field 'date' for entry 'c5'",
           "Datamodel: etb entry 'c5' (dm-constraints.bib): Constraint violation - none of fields (field5, field6) must exist when all of fields (field2, field3, field4) exist. Ignoring them." ];
my $c6 = [ "Datamodel: etb entry 'c6' (dm-constraints.bib): Constraint violation - one of fields (field7, field8) must exist when all of fields (field1, field2) exist",
           "Datamodel: etb entry 'c6' (dm-constraints.bib): Constraint violation - all of fields (field9, field10) must exist when all of fields (field5, field6) exist" ];
my $c7 = [ "Datamodel: etc entry 'c7' (dm-constraints.bib): Missing mandatory field - one of 'fielda, fieldb' must be defined",
           "Datamodel: etc entry 'c7' (dm-constraints.bib): Constraint violation - none of fields (field7) must exist when one of fields (field5, field6) exist. Ignoring them."];
my $c8 = [ "Datamodel: etd entry 'c8' (dm-constraints.bib): Constraint violation - none of fields (field4) must exist when none of fields (field2, field3) exist. Ignoring them.",
           "Datamodel: etd entry 'c8' (dm-constraints.bib): Constraint violation - one of fields (field10, field11) must exist when none of fields (field8, field9) exist",
           "Datamodel: etd entry 'c8' (dm-constraints.bib): Constraint violation - all of fields (field12, field13) must exist when none of fields (field6) exist" ];

my $c10 = [ "Datamodel: misc entry 'c10' (dm-constraints.bib): Invalid ISBN in value of field 'isbn'",
            "Datamodel: misc entry 'c10' (dm-constraints.bib): Invalid ISSN in value of field 'issn'" ];

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
ok(is_undef($bibentries->entry('c9')->get_field('warnings')), 'Constraints test 9' );
is_deeply($bibentries->entry('c10')->get_field('warnings'), $c10, 'Constraints test 10' );
