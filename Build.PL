use strict;
use warnings;
use utf8;
my $Bundled_MB = 0.3603;

# Find out what version of Module::Build is installed or fail quietly.
# This should be cross-platform.
my $Installed_MB =
    `$^X -e "eval q{require Module::Build; print Module::Build->VERSION} or exit 1"`;

# some operating systems put a newline at the end of every print.
chomp $Installed_MB;

$Installed_MB = 0 if $?;

# Use our bundled copy of Module::Build if it's newer than the installed.
unshift @INC, "inc/Module-Build/lib/perl5" if $Bundled_MB > $Installed_MB;

require Module::Build;

my $builder = Module::Build->new(
    dist_name           => 'biblatex-biber',
    license             => 'perl',
    dist_author         => 'François Charette <firmicus@gmx.net>',
    dist_version_from   => 'lib/Biber.pm',
    build_recommends => {
       'Test::More'   => 0,
    },
    add_to_cleanup      => [ 'biber-*' ],
    requires => {
        'Data::Dump' => 0,
        'File::Slurp'  => 0,
        'List::AllUtils' => 0,
        'Regexp::Common' => 0,
        'Log::Log4perl' => 0,
        'Readonly' => 0,
        'Text::BibTeX' => 0,
        'XML::LibXML::Simple'  => 0,
    },
    recommends => {
        'Readonly::XS' => 0,
    },
    script_files => [ glob( "bin/*" ) ],
    data_files => { 'data/schemata/bcf.xsd' => 'lib/Biber/bcf.xsd',
                    'data/schemata/bcf.rnc' => 'lib/Biber/bcf.rnc',
                    'data/schemata/bcf.rng' => 'lib/Biber/bcf.rng',
                    'data/latinkeys.txt' => 'lib/Unicode/Collate/latinkeys.txt' }
);

$builder->add_build_element('data');
$builder->create_build_script();
