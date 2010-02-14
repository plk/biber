use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    dist_name           => 'biblatex-biber',
    license             => 'perl',
    dist_author         => 'François Charette <firmicus@gmx.net>',
    dist_version_from   => 'lib/Biber.pm',
    build_recommends => {
       'Test::More'   => 0,
    },
    create_makefile_pl  => 'passthrough',
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
