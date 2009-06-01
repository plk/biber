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
        'Readonly' => 0,
        'File::Slurp'  => 0,
        'XML::LibXML'  => 0,
        'XML::Writer'  => 0,
    },
    recommends => {
        'Readonly::XS' => 0,
        'Text::BibTeX' => 0,
    },
    script_files => [ glob( "bin/*" ) ],
    data_files => { 'data/schemata/biblatexml.rnc' => 'lib/Biber/biblatexml.rnc',
                    'data/schemata/biblatexml.rng' => 'lib/Biber/biblatexml.rng',
                    'data/schemata/biblatexml.xsd' => 'lib/Biber/biblatexml.xsd',
                    'data/schemata/bcf.xsd' => 'lib/Biber/bcf.xsd',
                    'data/schemata/bcf.rnc' => 'lib/Biber/bcf.rnc',
                    'data/schemata/bcf.rng' => 'lib/Biber/bcf.rng',
                    'data/latinkeys.txt' => 'lib/Unicode/Collate/latinkeys.txt' }
);

$builder->add_build_element('data');
$builder->create_build_script();
