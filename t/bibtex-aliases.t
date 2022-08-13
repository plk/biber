# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 25;
use Test::Differences;
unified_diff;

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
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');
Biber::Config->setoption('validate_datamodel', 1);

# THERE IS A MAPPING SECTION IN THE .bcf BEING USED TO TEST USER MAPS TOO!

# Now generate the information
$biber->prepare;

my $section = $biber->sections->get_section(0);
my $bibentries = $section->bibentries;

my $w1 = ["Datamodel: thing entry 'alias2' (bibtex-aliases.bib): Field 'school' invalid in data model - ignoring",
          "Datamodel: thing entry 'alias2' (bibtex-aliases.bib): Invalid entry type 'thing' - defaulting to 'misc'",
          "Datamodel: thing entry 'alias2' (bibtex-aliases.bib): Invalid field 'institution' for entrytype 'misc'",
];

my $w2 = ["Datamodel: customa entry 'alias4' (bibtex-aliases.bib): Invalid field 'author' for entrytype 'customa'",
          "Datamodel: customa entry 'alias4' (bibtex-aliases.bib): Invalid field 'title' for entrytype 'customa'",
];

eq_or_diff($bibentries->entry('alias1')->get_field('entrytype'), 'thesis', 'Alias - 1' );
eq_or_diff($bibentries->entry('alias1')->get_field('type'), 'phdthesis', 'Alias - 2' );
is_deeply($bibentries->entry('alias1')->get_field('location'), ['Ivory Towers'], 'Alias - 3' );
eq_or_diff($bibentries->entry('alias1')->get_field('address'), undef, 'Alias - 4' );
eq_or_diff($bibentries->entry('alias2')->get_field('entrytype'), 'misc', 'Alias - 5' );
is_deeply($bibentries->entry('alias2')->get_field('warnings'), $w1, 'Alias - 6' ) ;
eq_or_diff($bibentries->entry('alias2')->get_field('school'), undef, 'Alias - 7' );
eq_or_diff($bibentries->entry('alias3')->get_field('entrytype'), 'customb', 'Alias - 8' );
eq_or_diff($bibentries->entry('alias4')->get_field('entrytype'), 'customa', 'Alias - 9' );
eq_or_diff($bibentries->entry('alias4')->get_field('verba'), 'conversation', 'Alias - 10' );
eq_or_diff($bibentries->entry('alias4')->get_field('verbb'), 'somevalue', 'Alias - 11' );
eq_or_diff($bibentries->entry('alias4')->get_field('eprint'), 'anid', 'Alias - 12' );
eq_or_diff($bibentries->entry('alias4')->get_field('eprinttype'), 'pubmedid', 'Alias - 13' );
eq_or_diff($bibentries->entry('alias4')->get_field('userd'), 'Some string of things', 'Alias - 14' );
eq_or_diff($bibentries->entry('alias4')->get_field('pubmedid'), undef, 'Alias - 15' );
eq_or_diff($bibentries->entry('alias4')->get_field('namea')->nth_name(1)->get_namepart('given'), 'Sam', 'Alias - 16' );
is_deeply($bibentries->entry('alias4')->get_field('warnings'), $w2, 'Alias - 17' ) ;

# Testing of .bcf field map match/replace
ok(is_undef($bibentries->entry('alias5')->get_field('abstract')), 'Alias - 18' );
eq_or_diff($biber->_liststring('alias5', 'listb'), 'REPlaCEDte!early', 'Alias - 19');
eq_or_diff($biber->_liststring('alias5', 'institution'), 'REPlaCEDte!early', 'Alias - 20');

# Testing of no target but just field additions
is_deeply($bibentries->entry('alias6')->get_field('keywords'), ['keyw1', 'keyw2'], 'Alias - 21' );

# Testing of no regexp match for field value
is_deeply($bibentries->entry('alias7')->get_field('lista'), ['listaval'], 'Alias - 22' );

# Testing append overwrites
eq_or_diff($bibentries->entry('alias7')->get_field('verbb'), 'val2val1', 'Alias - 23' );
eq_or_diff($bibentries->entry('alias7')->get_field('verbc'), 'val3val2val1', 'Alias - 24' );

# Testing appendstrict
ok(is_undef($bibentries->entry('alias8')->get_field('verbc')), 'Alias - 25' );
