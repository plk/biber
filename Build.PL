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
        'Text::BibTeX' => 0
    },
    recommends => {
        'Readonly::XS' => 0,
    },
    script_files => [ glob( "bin/*" ) ],
    schema_files => { 'data/schemas/biblatexml.rnc' => 'lib/Biber/biblatexml.rnc', 
                      'data/schemas/biblatexml.rng' => 'lib/Biber/biblatexml.rng',  
                      'data/schemas/biblatexml.xsd' => 'lib/Biber/biblatexml.xsd' }
);

$builder->add_build_element('schema');
$builder->create_build_script();
