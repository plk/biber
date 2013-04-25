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

       sub ACTION_docs {
         my $self = shift;
         $self->depends_on('code');
         $self->depends_on('manpages'); # skip html on perls where it's enabled
      }

     }
  );

my $builder = $class->new(
    dist_name           => 'biblatex-biber',
    license             => 'perl',
    dist_author         => 'Philip Kime <Philip@kime.org.uk>',
    dist_abstract       => 'Biber is a much-augmented bibtex replacement for biblatex users',
    dist_version_from   => 'lib/Biber/Config.pm',
    build_recommends => {
       'Test::More'   => 0,
       'File::Which'  => 0,
    },
    add_to_cleanup      => [ 'biber-*' ],
    configure_requires => { 'Module::Build' => 0.38 },
    build_requires => {
        'Config::AutoConf' => '0.15',
        'ExtUtils::LibBuilder' => '0.02'
    },
    requires => {
        'Data::Dump' => 0,
        'Data::Compare' => 0,
        'Data::Diver' => 0,
        'Date::Simple' => 0,
        'File::Slurp::Unicode'  => 0,
        'IPC::Cmd' => 0,
        'IPC::Run3' => 0,
        'List::AllUtils' => 0,
        'List::MoreUtils' => 0,
        'Regexp::Common' => 0,
        'Log::Log4perl' => 0,
        'Unicode::Collate' => '0.97',
        'Unicode::GCString' => 0,
        'Encode::EUCJPASCII' => 0,
        'Encode::JIS2K' => 0,
        'Encode::HanExtra' => 0,
        'XML::LibXML::Simple' => 0,
        'XML::LibXSLT' => 0,
        'URI' => 0,
        'Text::BibTeX' => '0.66',
        'LWP::Simple' => 0,
        'LWP::Protocol::https' => 0,
        'Business::ISBN' => 0,
        'Business::ISSN' => 0,
        'Business::ISMN' => 0,
        'Mozilla::CA' => 0,
        'perl' => '5.16.0'
    },
    recommends => {
        'Readonly::XS' => 0
    },
    script_files => [ glob( "bin/*" ) ],
    data_files => {'data/schemata/config.rnc' => 'lib/Biber/config.rnc',
                   'data/schemata/config.rng' => 'lib/Biber/config.rng',
                   'data/schemata/bcf.rnc' => 'lib/Biber/bcf.rnc',
                   'data/schemata/bcf.rng' => 'lib/Biber/bcf.rng',
                   'data/biber-tool.conf' => 'lib/Biber/biber-tool.conf',
                   'lib/Biber/LaTeX/recode_data.xml' => 'lib/Biber/LaTeX/recode_data.xml',
                   'data/schemata/biblatexml.rnc' => 'lib/Biber/biblatexml.rnc',
                   'data/schemata/biblatexml.rng' => 'lib/Biber/biblatexml.rng',
                   'data/bcf.xsl' => 'lib/Biber/bcf.xsl',
                   'data/latinkeys.txt' => 'lib/Unicode/Collate/latinkeys.txt' }
);

$builder->add_build_element('data');
$builder->create_build_script();
