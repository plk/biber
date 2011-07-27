use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 12;

use Biber;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
chdir("t/tdata") ;

# Set up Biber object
my $biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('bibtex-aliases.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'C');
Biber::Config->setoption('validate_structure', 1);
Biber::Config->setoption('map',   {
    bibtex => {
      entrytype => {
        CHAT => { bmap_target => "CUSTOMB" },
        CONVERSATION => {
          alsoset => {
            VERBA => { bmap_value => "BMAP_ORIGENTRYTYPE" },
            VERBB => { bmap_value => "somevalue" },
            VERBC => { bmap_value => "somevalue" },
          },
          bmap_target => "CUSTOMA",
        },
      },
    },
  });


# Now generate the information
$biber->prepare;

my $section = $biber->sections->get_section(0);
my $bibentries = $section->bibentries;

my $w1 = ["Field 'school' is aliased to field 'institution' but both are defined in entry with key 'alias2' - skipping field 'school'",
          "Entry 'alias2' - invalid entry type 'thing' - defaulting to 'misc'",
          "Entry 'alias2' - invalid field 'institution' for entrytype 'misc'"
];

my $w2 = ["Overwriting existing field 'VERBC' during aliasing of entrytype 'conversation' to 'customa'",
          "Entry 'alias4' - invalid field 'author' for entrytype 'customa'",
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
is_deeply($bibentries->entry('alias4')->get_field('warnings'), $w2, 'Alias - 12' ) ;
