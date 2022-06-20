
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
    test_requires => {
                      'Test::More'   => 0,
                      'Test::Differences' => 0,
                      'File::Which'  => 0
                        },
    add_to_cleanup      => [ 'biber-*' ],
    configure_requires => { 'Module::Build' => 0.38 },
    build_requires => {
        'Config::AutoConf' => '0.15',
        'ExtUtils::LibBuilder' => '0.02'
    },
    requires => {
                 'autovivification' => 0,
                 'Class::Accessor' => 0,
                 'Data::Dump' => 0,
                 'Data::Compare' => 0,
                 'Data::Uniqid' => 0,
                 'DateTime::Format::Builder' => 0,
                 'DateTime::Calendar::Julian' => 0,
                 'File::Slurper'  => 0,
                 'IPC::Cmd' => 0,
                 'IPC::Run3' => 0,
                 'List::AllUtils' => 0,
                 'List::MoreUtils' => 0,
                 'List::MoreUtils::XS' => 0,
                 'Mozilla::CA' =>  '20160104',
                 'Regexp::Common' => 0,
                 'Log::Log4perl' => 0,
                 'Unicode::Collate' => '1.29',
                 'Unicode::Normalize' => '1.26',
                 'Unicode::LineBreak' => '2019.001',
                 'Unicode::GCString' => 0,
                 'Encode::Locale' => 0,
                 'Encode::EUCJPASCII' => 0,
                 'Encode::JIS2K' => 0,
                 'Encode::HanExtra' => 0,
                 'Parse::RecDescent' => 0,
                 'PerlIO::utf8_strict' => 0,
                 'XML::LibXML' => 1.70,
                 'XML::LibXML::Simple' => 0,
                 'XML::LibXSLT' => 0,
                 'XML::Writer' => 0,
                 'Sort::Key' => 0,
                 'Storable' => 0,
                 'Text::CSV' => 0,
                 'Text::CSV_XS' => 0,
                 'Text::Roman' => 0,
                 'IO::String' => 0,
                 'URI' => 0,
                 'Text::Balanced' => 0,
                 'Text::BibTeX' => '0.88',
                 'LWP::UserAgent' => 0,
                 'LWP::Protocol::https' => 0,
                 'Business::ISBN' => 0,
                 'Business::ISSN' => 0,
                 'Business::ISMN' => 0,
                 'Lingua::Translit' => '0.28',
                 'perl' => '5.32.0'
                },
    script_files => [ glob( "bin/*" ) ],
    data_files => {'data/schemata/config.rnc' => 'lib/Biber/config.rnc',
                   'data/schemata/config.rng' => 'lib/Biber/config.rng',
                   'data/schemata/bcf.rnc' => 'lib/Biber/bcf.rnc',
                   'data/schemata/bcf.rng' => 'lib/Biber/bcf.rng',
                   'data/biber-tool.conf' => 'lib/Biber/biber-tool.conf',
                   'lib/Biber/LaTeX/recode_data.xml' => 'lib/Biber/LaTeX/recode_data.xml',
                   'data/bcf.xsl' => 'lib/Biber/bcf.xsl' }
);

$builder->add_build_element('data');
$builder->create_build_script();
