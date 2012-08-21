# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 24;

use Biber;
use Biber::Utils;
use Biber::Output::bbl;
use Log::Log4perl;
chdir("t/tdata") ;

# Set up Biber object
my $biber = Biber->new( noconf => 1);

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

$biber->parse_ctrlfile('bibtex-aliases.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'C');
Biber::Config->setoption('validate_datamodel', 1);

# THERE IS A MAPPING SECTION IN THE .bcf BEING USED TO TEST USER MAPS TOO!

# Now generate the information
$biber->prepare;

my $section = $biber->sections->get_section(0);
my $bibentries = $section->bibentries;

my $w1 = ["Field 'school' invalid in data model for entry 'alias2' - ignoring",
          "Entry 'alias2' - invalid entry type 'thing' - defaulting to 'misc'",
          "Entry 'alias2' - invalid field 'institution' for entrytype 'misc'",
];

my $w2 = ["Entry 'alias4' - invalid field 'author' for entrytype 'customa'",
          "Entry 'alias4' - invalid field 'eprint' for entrytype 'customa'",
          "Entry 'alias4' - invalid field 'eprinttype' for entrytype 'customa'",
          "Entry 'alias4' - invalid field 'namea' for entrytype 'customa'",
          "Entry 'alias4' - invalid field 'title' for entrytype 'customa'",
];

is($bibentries->entry('alias1')->get_field('entrytype'), 'thesis', 'Alias - 1' );
is($bibentries->entry('alias1')->get_field('type'), 'phdthesis', 'Alias - 2' );
is_deeply($bibentries->entry('alias1')->get_field('location'), ['Ivory Towers'], 'Alias - 3' );
is($bibentries->entry('alias1')->get_field('address'), undef, 'Alias - 4' );
is($bibentries->entry('alias2')->get_field('entrytype'), 'misc', 'Alias - 5' );
is_deeply($bibentries->entry('alias2')->get_field('warnings'), $w1, 'Alias - 6' ) ;
is($bibentries->entry('alias2')->get_field('school'), undef, 'Alias - 7' );
is($bibentries->entry('alias3')->get_field('entrytype'), 'customb', 'Alias - 8' );
is($bibentries->entry('alias4')->get_field('entrytype'), 'customa', 'Alias - 9' );
is($bibentries->entry('alias4')->get_field('verba'), 'conversation', 'Alias - 10' );
is($bibentries->entry('alias4')->get_field('verbb'), 'somevalue', 'Alias - 11' );
is($bibentries->entry('alias4')->get_field('eprint'), 'anid', 'Alias - 12' );
is($bibentries->entry('alias4')->get_field('eprinttype'), 'PUBMEDID', 'Alias - 13' );
is($bibentries->entry('alias4')->get_field('userd'), 'Some string of things', 'Alias - 14' );
is($bibentries->entry('alias4')->get_field('pubmedid'), undef, 'Alias - 15' );
is($bibentries->entry('alias4')->get_field('namea')->nth_name(1)->get_firstname, 'Sam', 'Alias - 16' );
is_deeply($bibentries->entry('alias4')->get_field('warnings'), $w2, 'Alias - 17' ) ;

# Testing of .bcf field map match/replace
ok(is_undef($bibentries->entry('alias5')->get_field('abstract')), 'Alias - 18' );
is($biber->_liststring('alias5', 'listb'), 'REPlaCEDte!early', 'Alias - 19');
is($biber->_liststring('alias5', 'institution'), 'REPlaCEDte!early', 'Alias - 20');

# Testing of no target but just field additions
is($bibentries->entry('alias6')->get_field('keywords'), 'keyw1, keyw2', 'Alias - 21' );

# Testing of no regexp match for field value
is_deeply($bibentries->entry('alias7')->get_field('lista'), ['listaval'], 'Alias - 22' );

# Testing append overwrites
is($bibentries->entry('alias7')->get_field('verbb'), 'val2val1', 'Alias - 23' );
is($bibentries->entry('alias7')->get_field('verbc'), 'val3val2val1', 'Alias - 24' );
