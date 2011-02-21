use strict;
use warnings;
use utf8;

require Module::Build;
my $class = Module::Build->subclass
  (
   class => 'My::Builder',
   code => q{
       sub ACTION_test {
         my $self = shift;
         $ENV{'LANG'} = 'C'; # set LANG to something known for tests
         $self->SUPER::ACTION_test;
       }
     },
  );

my $builder = $class->new(
    dist_name           => 'biblatex-biber',
    license             => 'perl',
    dist_author         => 'François Charette <firmicus@gmx.net>',
    dist_version_from   => 'lib/Biber.pm',
    build_recommends => {
       'Test::More'   => 0,
    },
    add_to_cleanup      => [ 'biber-*' ],
    build_requires => {
        'Config::AutoConf' => '0.15',
        'ExtUtils::LibBuilder' => '0.02'
    },
    requires => {
        'Config::General' => 0,
        'Data::Dump' => 0,
        'Data::Compare' => 0,
        'Date::Simple' => 0,
        'File::Slurp::Unicode'  => 0,
        'IPC::Cmd' => 0,
        'IPC::Run' => 0,
        'List::AllUtils' => 0,
        'List::MoreUtils' => 0,
        'Regexp::Common' => 0,
        'Log::Log4perl' => 0,
        'Readonly' => 0,
        'Unicode::Collate' => '0.72',
        'XML::LibXML::Simple' => 0,
        'XML::LibXSLT' => 0,
        'Text::BibTeX' => '0.52',
        'LWP::Simple' => 0,
        'Switch' => 0,
        'perl' => '5.10.0'
    },
    recommends => {
        'Readonly::XS' => 0
    },
    script_files => [ glob( "bin/*" ) ],
    data_files => {'data/schemata/bcf.rnc' => 'lib/Biber/bcf.rnc',
                   'data/schemata/bcf.rng' => 'lib/Biber/bcf.rng',
                   'data/schemata/dcf.rnc' => 'lib/Biber/dcf.rnc',
                   'data/schemata/dcf.rng' => 'lib/Biber/dcf.rng',
                   'lib/Biber/Input/file/bibtex.dcf' => 'lib/Biber/Input/file/bibtex.dcf',
                   'lib/Biber/Input/file/biblatexml.dcf' => 'lib/Biber/Input/file/biblatexml.dcf',
                   'lib/Biber/Input/file/ris.dcf' => 'lib/Biber/Input/file/ris.dcf',
                   'lib/Biber/Input/file/ris.dcf' => 'lib/Biber/Input/file/zoterordfxml.dcf',
                   'data/schemata/biblatexml.rnc' => 'lib/Biber/biblatexml.rnc',
                   'data/schemata/biblatexml.rng' => 'lib/Biber/biblatexml.rng',
                   'data/bcf.xsl' => 'lib/Biber/bcf.xsl',
                   'data/latinkeys.txt' => 'lib/Unicode/Collate/latinkeys.txt' }
);

$builder->add_build_element('data');
$builder->create_build_script();
