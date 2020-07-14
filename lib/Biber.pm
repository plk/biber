package Biber;
use v5.24;
use strict;
use warnings;
use parent qw(Class::Accessor Biber::Internals);

use constant {
  EXIT_OK => 0,
  EXIT_ERROR => 2
};

use Biber::Config;
use Biber::DataLists;
use Biber::DataList;
use Biber::DataModel;
use Biber::Constants;
use Biber::Internals;
use Biber::Entries;
use Biber::Entry;
use Biber::Entry::Names;
use Biber::Entry::Name;
use Biber::LangTags;
use Biber::Sections;
use Biber::Section;
use Biber::LaTeX::Recode;
use Biber::UCollate;
use Biber::Utils;
use Carp;
use Data::Dump;
use Data::Compare;
use Encode;
use File::Copy;
use File::Slurper;
use File::Spec;
use File::Temp;
use IO::File;
use List::AllUtils qw( first uniq max first_index );
use Log::Log4perl qw( :no_extra_logdie_message );
use POSIX qw( locale_h ); # for lc()
use Scalar::Util qw(looks_like_number);
use Sort::Key qw ( multikeysorter );
use Text::BibTeX qw(:macrosubs);
use Unicode::Normalize;

=encoding utf-8

=head1 NAME

Biber - main module for biber, a bibtex replacement for users of biblatex

=cut

my $logger = Log::Log4perl::get_logger('main');


=head1 SYNOPSIS

    use Biber;
    my $biber = Biber->new();
    $biber->parse_ctrlfile("example.bcf");
    $biber->prepare;

=cut

our $MASTER; # reference to biber object. Needed all over the place

=head1 METHODS

=head2 new

    Initialize the Biber object, optionally passing named options as arguments.

=cut

sub new {
  my ($class, %opts) = @_;
  my $self = bless {}, $class;

  Biber::Config->_initopts(\%opts);

  # Add a reference to a global temp dir used for various things
  $self->{TEMPDIR} = File::Temp->newdir("biber_tmp_XXXX",
                                        TMPDIR => 1,
                                        CLEANUP => (Biber::Config->getoption('noremove_tmp_dir') ? 0 : 1));
  $self->{TEMPDIRNAME} = $self->{TEMPDIR}->dirname;

  # Initialise recoding schemes
  Biber::LaTeX::Recode->init_sets(Biber::Config->getoption('decodecharsset'),
                                  Biber::Config->getoption('output_safecharsset'));

  $MASTER = $self;

  # Validate if asked to.
  # This has to be here, after config file is read and options
  # are parsed. It seems strange to validate the config file after it's been
  # read but there is no choice and it's useful anyway as this will catch some semantic
  # errors. Uses biber_error() and so $MASTER has to be defined before we call this
  if (Biber::Config->getoption('validate_config') and $opts{configfile}) {
    validate_biber_xml($opts{configfile}, 'config', '');
  }

  # Set up LangTag parser
  $self->{langtags} = Biber::LangTags->new();

  return $self;
}


=head2 display_end

   Output summary of warnings/errors/misc before exit

=cut

sub display_end {
  my $self = shift;

  # Show location of temporary directory
  if (Biber::Config->getoption('show_tmp_dir')) {
    if (Biber::Config->getoption('noremove_tmp_dir')) {
      $logger->info("TEMP DIR: " . $self->biber_tempdir_name);
    }
    else {
      biber_warn("--noremove-tmp-dir was not set, no temporary directory to show");
    }
  }

  if ($self->{warnings}) {
    $logger->info('WARNINGS: ' . $self->{warnings});
  }
  if ($self->{errors}) {
    $logger->info('ERRORS: ' . $self->{errors});
    exit EXIT_ERROR;
  }
}

=head2 biber_tempdir

    Returns a File::Temp directory object for use in various things

=cut

sub biber_tempdir {
  my $self = shift;
  return $self->{TEMPDIR};
}

=head2 biber_tempdir_name

    Returns the directory name of the File::Temp directory object

=cut

sub biber_tempdir_name {
  my $self = shift;
  return $self->{TEMPDIRNAME};
}

=head2 sections

    my $sections= $biber->sections

    Returns a Biber::Sections object describing the bibliography sections

=cut

sub sections {
  my $self = shift;
  return $self->{sections};
}

=head2 add_sections

    Adds a Biber::Sections object. Used externally from, e.g. biber

=cut

sub add_sections {
  my ($self, $sections) = @_;
  $self->{sections} = $sections;
  return;
}

=head2 datalists

    my $datalists = $biber->datalists

    Returns a Biber::DataLists object describing the bibliography sorting lists

=cut

sub datalists {
  my $self = shift;
  return $self->{datalists};
}

=head2 langtags

    Returns a Biber::LangTags object containing a parser for BCP47 tags

=cut

sub langtags {
  my $self = shift;
  return $self->{langtags};
}

=head2 set_output_obj

    Sets the object used to output final results
    Must be a subclass of Biber::Output::base

=cut

sub set_output_obj {
  my $self = shift;
  my $obj = shift;
  croak('Output object must be subclass of Biber::Output::base!') unless $obj->isa('Biber::Output::base');
  $self->{output_obj} = $obj;
  return;
}


=head2 get_preamble

    Returns the current preamble as an array ref

=cut

sub get_preamble {
  my $self = shift;
  return $self->{preamble};
}


=head2 get_output_obj

    Returns the object used to output final results

=cut

sub get_output_obj {
  my $self = shift;
  return $self->{output_obj};
}

=head2 set_current_section

    Sets the current section number that we are working on to a section number

=cut

sub set_current_section {
  my $self = shift;
  my $secnum = shift;
  $self->{current_section} = $secnum;
  return;
}

=head2 get_current_section

    Gets the current section number that we are working on

=cut

sub get_current_section {
  my $self = shift;
  return $self->{current_section};
}

=head2 tool_mode_setup

  Fakes parts of the control file for tool mode

=cut

sub tool_mode_setup {
  my $self = shift;
  my $bib_sections = new Biber::Sections;
  # There are no sections in tool mode so create a pseudo-section
  my $bib_section = new Biber::Section('number' => 99999);
  my $ifs = [];
  foreach my $if (@ARGV) {
    push $ifs->@*, {type => 'file',
                    name => $if,
                    datatype => Biber::Config->getoption('input_format'),
                    encoding => Biber::Config->getoption('input_encoding')};
  }
  $bib_section->set_datasources($ifs);

  $bib_section->set_allkeys(1);
  $bib_sections->add_section($bib_section);

  # Always resolve date meta-information in tool mode
  Biber::Config->setblxoption(undef, 'dateapproximate', 1);
  Biber::Config->setblxoption(undef, 'dateera', 1);
  Biber::Config->setblxoption(undef, 'dateuncertain', 1);

  # No need to worry about this in tool mode but it needs to be set
  Biber::Config->setblxoption(undef, 'namestrunchandling', 0);

  # Add the Biber::Sections object to the Biber object
  $self->add_sections($bib_sections);

  my $datalists = new Biber::DataLists;
  my $seclist = Biber::DataList->new(section => 99999,
                                     sortingtemplatename => 'tool',
                                     sortingnamekeytemplatename => 'global',
                                     uniquenametemplatename => 'global',
                                     labelalphanametemplatename => 'global',
                                     labelprefix => '',
                                     name => 'tool/global//global/global');
  $seclist->set_type('entry');
  # Locale just needs a default here - there is no biblatex option to take it from
  Biber::Config->setblxoption(undef, 'sortlocale', 'en_US');
  if ($logger->is_debug()) {# performance tune
    $logger->debug("Adding 'entry' list 'tool' for pseudo-section 99999");
  }
  $datalists->add_list($seclist);
  $self->{datalists} = $datalists;

  # User maps are set in config file and need some massaging which normally
  # happens in parse_ctrlfile
  if (my $usms = Biber::Config->getoption('sourcemap')) {
    # Force "user" level for the maps
    $usms->@* = map {$_->{level} = 'user';$_} $usms->@*;
  }
  return;
}

=head2 parse_ctrlfile

    This method reads the control file
    generated by biblatex to work out the various biblatex options.
    See Constants.pm for defaults and example of the data structure being built here.

=cut

sub parse_ctrlfile {
  my ($self, $ctrl_file) = @_;

  my $ctrl_file_path = locate_data_file($ctrl_file);
  Biber::Config->set_ctrlfile_path($ctrl_file_path);

  biber_error("Cannot find control file '$ctrl_file'! - Did latex run successfully on your .tex file before you ran biber?") unless ($ctrl_file_path and check_exists($ctrl_file_path));

  # Early check to make sure .bcf is well-formed. If not, this means that the last biblatex run
  # exited prematurely while writing the .bcf. This results is problems for latexmk. So, if the
  # .bcf is broken, just stop here, remove the .bcf and exit with error so that we don't write
  # a bad .bbl
  my $checkbuf;
  unless ($checkbuf = eval {slurp_switchr($ctrl_file_path)->$*}) {
    # Reading ctrl-file as UTF-8 failed. Probably it was written by fontenc as latin1
    # with some latin1 char in it (probably a sourcemap), so try that as a last resort
    unless (eval {$checkbuf = slurp_switchr($ctrl_file_path, 'latin1')->$*}) {
      biber_error("$ctrl_file_path is not UTF-8 or even latin1, please delete it and run latex again or check that biblatex is writing a valid .bcf file.");
    }
    # Write ctrl file as UTF-8
    slurp_switchw($ctrl_file_path, $checkbuf);# Unicode NFC boundary
  }

  $checkbuf = NFD($checkbuf);# Unicode NFD boundary
  unless (eval "XML::LibXML->load_xml(string => \$checkbuf)") {
    my $output = $self->get_output_obj->get_output_target_file;
    unlink($output) unless $output eq '-';# ignore deletion of STDOUT marker
    biber_error("$ctrl_file_path is malformed, last biblatex run probably failed. Deleted $output");
  }

  # Validate if asked to
  if (Biber::Config->getoption('validate_control')) {
    validate_biber_xml($ctrl_file_path, 'bcf', 'https://sourceforge.net/projects/biblatex');
  }

  # Convert .bcf to .html using XSLT transform if asked to
  if (Biber::Config->getoption('convert_control')) {

    require XML::LibXSLT;
    require XML::LibXML;

    my $xslt = XML::LibXSLT->new();
    my $CFstyle;

    # we assume that the schema files are in the same dir as Biber.pm:
    (my $vol, my $biber_path, undef) = File::Spec->splitpath( $INC{"Biber.pm"} );

    # Deal with the strange world of PAR::Packer paths
    # We might be running inside a PAR executable and @INC is a bit odd in this case
    # Specifically, "Biber.pm" in @INC might resolve to an internal jumbled name
    # nowhere near to these files. You know what I mean if you've dealt with pp
    my $bcf_xsl;
    if ($biber_path =~ m|/par\-| and $biber_path !~ m|/inc|) { # a mangled PAR @INC path
      $bcf_xsl = File::Spec->catpath($vol, "$biber_path/inc/lib/Biber", 'bcf.xsl');
    }
    else {
      $bcf_xsl = File::Spec->catpath($vol, "$biber_path/Biber", 'bcf.xsl');
    }

    if (check_exists($bcf_xsl)) {
      $CFstyle = XML::LibXML->load_xml( location => $bcf_xsl, no_cdata=>1 )
    }
    else {
      biber_warn("Cannot find XML::LibXSLT stylesheet. Skipping conversion : $!");
      goto LOADCF;
    }

    my $CF = XML::LibXML->load_xml(location => $ctrl_file_path);
    my $stylesheet = $xslt->parse_stylesheet($CFstyle);
    my $CFhtml = $stylesheet->transform($CF);
    $stylesheet->output_file($CFhtml, $ctrl_file_path . '.html');
    $logger->info("Converted BibLaTeX control file '$ctrl_file_path' to '$ctrl_file_path.html'");
  }

  # Open control file
 LOADCF:
  $logger->info("Reading '$ctrl_file_path'");
  my $buf = slurp_switchr($ctrl_file_path)->$*;
  $buf = NFD($buf);# Unicode NFD boundary

  # Read control file
  require XML::LibXML::Simple;

  my $bcfxml = XML::LibXML::Simple::XMLin($buf,
                                          'ForceContent' => 1,
                                          'ForceArray' => [
                                                           qr/\A(?:no)*citekey\z/,
                                                           qr/\Aoption\z/,
                                                           qr/\Aoptions\z/,
                                                           qr/\Avalue\z/,
                                                           qr/\Asortitem\z/,
                                                           qr/\Abibdata\z/,
                                                           qr/\Adatasource\z/,
                                                           qr/\Aconstant\z/,
                                                           qr/\Asection\z/,
                                                           qr/\Asort(?:ex|in)clusion\z/,
                                                           qr/\A(?:ex|in)clusion\z/,
                                                           qr/\Asort\z/,
                                                           qr/\Amode\z/,
                                                           qr/\Amaps\z/,
                                                           qr/\Amap\z/,
                                                           qr/\Amap_step\z/,
                                                           qr/\Aper_type\z/,
                                                           qr/\Aper_nottype\z/,
                                                           qr/\Akeypart\z/,
                                                           qr/\Apart\z/,
                                                           qr/\Asortingnamekeytemplate\z/,
                                                           qr/\Asortingtemplate\z/,
                                                           qr/\Aper_datasource\z/,
                                                           qr/\Anosort\z/,
                                                           qr/\Amember\z/,
                                                           qr/\Anoinit\z/,
                                                           qr/\Anolabel\z/,
                                                           qr/\Anolabelwidthcount\z/,
                                                           qr/\Apresort\z/,
                                                           qr/\Atype_pair\z/,
                                                           qr/\Ainherit\z/,
                                                           qr/\Anamepart\z/,
                                                           qr/\Afieldor\z/,
                                                           qr/\Afieldxor\z/,
                                                           qr/\Afield\z/,
                                                           qr/\Ascope\z/,
                                                           qr/\Atransliteration\z/,
                                                           qr/\Atranslit\z/,
                                                           qr/\Aalias\z/,
                                                           qr/\Aalsoset\z/,
                                                           qr/\Aconstraints\z/,
                                                           qr/\Aconstraint\z/,
                                                           qr/\Aentryfields\z/,
                                                           qr/\Aentrytype\z/,
                                                           qr/\Adatetype\z/,
                                                           qr/\Adatalist\z/,
                                                           qr/\Alabel(?:part|element|alpha(?:name)?template)\z/,
                                                           qr/\Auniquenametemplate\z/,
                                                           qr/\Acondition\z/,
                                                           qr/\Afilter(?:or)?\z/,
                                                           qr/\Aoptionscope\z/,
                                                          ],
                                          'NsStrip' => 1,
                                          'KeyAttr' => []);
#  use Data::Dump;dd($bcfxml);exit 0;
  my $controlversion = $bcfxml->{version};
  my $bltxversion = $bcfxml->{bltxversion};
  Biber::Config->setblxoption(undef, 'controlversion', $controlversion);
  unless ($controlversion eq $BCF_VERSION) {
    biber_error("Error: Found biblatex control file version $controlversion, expected version $BCF_VERSION.\nThis means that your biber ($Biber::Config::VERSION) and biblatex ($bltxversion) versions are incompatible.\nSee compat matrix in biblatex or biber PDF documentation.");
  }

  # Option scope
  foreach my $bcfscopeopts ($bcfxml->{optionscope}->@*) {
    my $scope = $bcfscopeopts->{type};
    foreach my $bcfscopeopt ($bcfscopeopts->{option}->@*) {
      my $opt = $bcfscopeopt->{content};
      $CONFIG_BIBLATEX_OPTIONS{$scope}{$opt}{OUTPUT} = $bcfscopeopt->{backendout} || 0;
      if (my $bin = process_backendin($bcfscopeopt->{backendin})) {
        $CONFIG_BIBLATEX_OPTIONS{$scope}{$opt}{INPUT} = $bin;
      }
      $CONFIG_OPTSCOPE_BIBLATEX{$opt}{$scope} = 1;
      $CONFIG_SCOPEOPT_BIBLATEX{$scope}{$opt} = 1;
      if (defined($CONFIG_OPTTYPE_BIBLATEX{$opt}) and
          lc($CONFIG_OPTTYPE_BIBLATEX{$opt}) ne lc($bcfscopeopt->{datatype})) {
        biber_warn("Warning: Datatype for biblatex option '$opt' has conflicting values, probably at different scopes. This is not supported.");
      }
      else {
        $CONFIG_OPTTYPE_BIBLATEX{$opt} = lc($bcfscopeopt->{datatype});
      }
    }
  }
  # Now we have the per-namelist options, make the accessors for them in the Names package
  foreach my $nso (keys $CONFIG_SCOPEOPT_BIBLATEX{NAMELIST}->%*) {
    Biber::Entry::Names->follow_best_practice;
    Biber::Entry::Names->mk_accessors($nso);
  }
  # Now we have the per-name options, make the accessors for them in the Name package
  foreach my $no (keys $CONFIG_SCOPEOPT_BIBLATEX{NAME}->%*) {
    Biber::Entry::Name->follow_best_practice;
    Biber::Entry::Name->mk_accessors($no);
  }

  # OPTIONS
  foreach my $bcfopts ($bcfxml->{options}->@*) {

    # Biber options
    if ($bcfopts->{component} eq 'biber') {

      # Global options
      if ($bcfopts->{type} eq 'global') {
        foreach my $bcfopt ($bcfopts->{option}->@*) {
          # unless already explicitly set from cmdline/config file
          unless (Biber::Config->isexplicitoption($bcfopt->{key}{content})) {
            if ($bcfopt->{type} eq 'singlevalued') {
              Biber::Config->setoption($bcfopt->{key}{content}, $bcfopt->{value}[0]{content});
            }
            elsif ($bcfopt->{type} eq 'multivalued') {
              Biber::Config->setoption($bcfopt->{key}{content},
                [ map {$_->{content}} sort {$a->{order} <=> $b->{order}} $bcfopt->{value}->@* ]);
            }
          }
        }
      }
    }

    # BibLaTeX options
    if ($bcfopts->{component} eq 'biblatex') {

      # Global options
      if ($bcfopts->{type} eq 'global') {
        foreach my $bcfopt ($bcfopts->{option}->@*) {
          if ($bcfopt->{type} eq 'singlevalued') {
            Biber::Config->setblxoption(undef, $bcfopt->{key}{content}, $bcfopt->{value}[0]{content});
          }
          elsif ($bcfopt->{type} eq 'multivalued') {
            # sort on order attribute and then remove it
            Biber::Config->setblxoption(undef, $bcfopt->{key}{content},
              [ map {delete($_->{order}); $_} sort {$a->{order} <=> $b->{order}} $bcfopt->{value}->@* ]);
          }
        }
      }

      # Entrytype options
      else {
        my $entrytype = $bcfopts->{type};
        foreach my $bcfopt ($bcfopts->{option}->@*) {
          if ($bcfopt->{type} eq 'singlevalued') {
            Biber::Config->setblxoption(undef, $bcfopt->{key}{content}, $bcfopt->{value}[0]{content}, 'ENTRYTYPE', $entrytype);
          }
          elsif ($bcfopt->{type} eq 'multivalued') {
            # sort on order attribute and then remove it
            Biber::Config->setblxoption(undef, $bcfopt->{key}{content},
              [ map {delete($_->{order}); $_} sort {$a->{order} <=> $b->{order}} $bcfopt->{value}->@* ],
              'ENTRYTYPE',
              $entrytype);
          }
        }
      }
    }
  }

  # DATAFIELD SETS
  # Since we have to use the datamodel to resolve some members, just record the settings
  # here for processing after the datamodel is parsed
  foreach my $s ($bcfxml->{datafieldset}->@*) {
    my $name = lc($s->{name});
    foreach my $m ($s->{member}->@*) {
      if (my $field = $m->{field}[0]) {# 'field' has forcearray for other things
        push $DATAFIELD_SETS{$name}->@*, $field;
      }
      else {
          push $DATAFIELD_SETS{$name}->@*, {fieldtype => $m->{fieldtype},
                                            datatype  => $m->{datatype}};
      }
    }
  }

  # DATASOURCE MAPPING
  # This is special as it's both a biblatex option and a biber option
  # We merge into the biber option
  # In biblatex you can set driver mappings but not in biber
  # Order of application of maps is decided by the level and within 'user' level,
  # which can come from two places (biber.conf and \DeclareSourcemap), order is
  # \DeclareSourcemap, then biber.conf
  if (exists($bcfxml->{sourcemap})) {
    # User maps are set in config file
    if (my $usms = Biber::Config->getoption('sourcemap')) {
      # Force "user" level for the maps
      $usms->@* = map {$_->{level} = 'user';$_} $usms->@*;

      # Merge any user maps from the document set by \DeclareSourcemap into user
      # maps set in the biber config file. These document user maps take precedence so go
      # at the front of any other user maps
      # Are there any doc maps to merge?
      if (my @docmaps = grep {$_->{level} eq 'user'} $bcfxml->{sourcemap}{maps}->@*) {
        # If so, get a reference to the maps in the config map and prepend all
        # of the doc maps to it. Must also deref the doc maps map element to make
        # sure that they collapse nicely
        my $configmaps = first {$_->{level} eq 'user'} $usms->@*;
        unshift($configmaps->{map}->@*, map {$_->{map}->@*} @docmaps);
      }

      # Merge the driver/style maps with the user maps from the config file
      if (my @m = grep {$_->{level} eq 'driver' or
                        $_->{level} eq 'style'} $bcfxml->{sourcemap}{maps}->@* ) {
        Biber::Config->setoption('sourcemap', [$usms->@*, @m]);
      }
      else { # no driver defaults, just override the config file user map settings
        Biber::Config->setoption('sourcemap', $bcfxml->{sourcemap}{maps});
      }
    }
    else { # just write the option as there are no config file settings at all
      Biber::Config->setoption('sourcemap', $bcfxml->{sourcemap}{maps});
    }
  }

  # LABELALPHA NAME TEMPLATE
  my $lants;
  foreach my $t ($bcfxml->{labelalphanametemplate}->@*) {
    my $lant;
    foreach my $np (sort {$a->{order} <=> $b->{order}} $t->{namepart}->@*) {
      push $lant->@*, {namepart           => $np->{content},
                       use                => $np->{use},
                       pre                => $np->{pre},
                       substring_compound => $np->{substring_compound},
                       substring_side     => $np->{substring_side},
                       substring_width    => $np->{substring_width}};
    }
    $lants->{$t->{name}} = $lant;
  }
  Biber::Config->setblxoption(undef, 'labelalphanametemplate', $lants);

  # LABELALPHA TEMPLATE
  foreach my $t ($bcfxml->{labelalphatemplate}->@*) {
    my $latype = $t->{type};
    if ($latype eq 'global') {
      Biber::Config->setblxoption(undef, 'labelalphatemplate', $t);
    }
    else {
      Biber::Config->setblxoption(undef, 'labelalphatemplate',
                                  $t,
                                  'ENTRYTYPE',
                                  $latype);
    }
  }

  # EXTRADATE specification
  my $ed;
  foreach my $scope ($bcfxml->{extradatespec}->{scope}->@*) {
    my $fields;
    foreach my $field (sort {$a->{order} <=> $b->{order}} $scope->{field}->@*) {
      push $fields->@*, $field->{content};
    }
    push $ed->@*, $fields;
  }
  Biber::Config->setblxoption(undef, 'extradatespec', $ed);

  # INHERITANCE schemes for crossreferences (always global)
  Biber::Config->setblxoption(undef, 'inheritance', $bcfxml->{inheritance});

  # NOINIT
  # Make the data structure look like the biber config file structure
  # "value" is forced to arrays for other elements so we extract
  # the first element here as they will always be only length=1
  my $noinit;
  foreach my $ni ($bcfxml->{noinits}{noinit}->@*) {
    push $noinit->@*, { value => $ni->{value}[0]};
  }
  # There is a default so don't set this option if nothing is in the .bcf
  Biber::Config->setoption('noinit', $noinit) if $noinit;

  # NOLABEL
  # Make the data structure look like the biber config file structure
  # "value" is forced to arrays for other elements so we extract
  # the first element here as they will always be only length=1
  my $nolabel;
  foreach my $nl ($bcfxml->{nolabels}{nolabel}->@*) {
    push $nolabel->@*, { value => $nl->{value}[0]};
  }
  # There is a default so don't set this option if nothing is in the .bcf
  Biber::Config->setoption('nolabel', $nolabel) if $nolabel;

  # NOLABELWIDTHCOUNT
  # Make the data structure look like the biber config file structure
  # "value" is forced to arrays for other elements so we extract
  # the first element here as they will always be only length=1
  my $nolabelwidthcount;
  foreach my $nlwc ($bcfxml->{nolabelwidthcounts}{nolabelwidthcount}->@*) {
    push $nolabelwidthcount->@*, { value => $nlwc->{value}[0]};
  }
  # There is a default so don't set this option if nothing is in the .bcf
  Biber::Config->setoption('nolabelwidthcount', $nolabelwidthcount) if $nolabelwidthcount;

  # NOSORT
  # Make the data structure look like the biber config file structure
  # "field" and "value" are forced to arrays for other elements so we extract
  # the first element here as they will always be only length=1
  my $nosort;
  foreach my $ns ($bcfxml->{nosorts}{nosort}->@*) {
    push $nosort->@*, {name => $ns->{field}[0], value => $ns->{value}[0]};
  }
  # There is a default so don't set this option if nothing is in the .bcf
  Biber::Config->setoption('nosort', $nosort) if $nosort;

  # UNIQUENAME TEMPLATE
  my $unts;
  my $checkbase = 0;
  foreach my $unt ($bcfxml->{uniquenametemplate}->@*) {
    my $untval = [];
    foreach my $np (sort {$a->{order} <=> $b->{order}} $unt->{namepart}->@*) {
      $checkbase = 1 if $np->{base};
      push $untval->@*, {namepart        => $np->{content},
                         use             => $np->{use},
                         disambiguation  => $np->{disambiguation},
                         base            => $np->{base}};
    }
    $unts->{$unt->{name}} = $untval;
  }

  # Check to make sure we have a base to disambiguate from. If not, we can get infinite loops
  # in the disambiguation code
  biber_error("The uniquenametemplate must contain at least one 'base' part otherwise name disambiguation is impossible") unless $checkbase;

  Biber::Config->setblxoption(undef, 'uniquenametemplate', $unts);

  # SORTING NAME KEY
  # Use the order attributes to make sure things are in right order and create a data structure
  # we can use later
  my $snss;
  foreach my $sns ($bcfxml->{sortingnamekeytemplate}->@*) {
    my $snkps;
    foreach my $snkp (sort {$a->{order} <=> $b->{order}} $sns->{keypart}->@*) {
      my $snps;
      foreach my $snp (sort {$a->{order} <=> $b->{order}} $snkp->{part}->@*) {
        my $np;
        if ($snp->{type} eq 'namepart') {
          $np = { type => 'namepart', value => $snp->{content} };
          if (exists($snp->{use})) {
            $np->{use} = $snp->{use};
          }
          if (exists($snp->{inits})) {
            $np->{inits} = $snp->{inits};
          }
        }
        elsif ($snp->{type} eq 'literal') {
          $np = { type => 'literal', value => $snp->{content} };
        }
        push $snps->@*, $np;
      }
      push $snkps->@*, $snps;
    }
    $snss->{$sns->{name}} = $snkps;
  }
  Biber::Config->setblxoption(undef, 'sortingnamekeytemplate', $snss);

  # SORTING

  # transliterations
  foreach my $tr ($bcfxml->{transliteration}->@*) {
    if ($tr->{entrytype}[0] eq '*') { # already array forced for another option
      Biber::Config->setblxoption(undef, 'translit', $tr->{translit});
    }
    else { # per_entrytype
      Biber::Config->setblxoption(undef, 'translit',
                                  $tr->{translit},
                                  'ENTRYTYPE',
                                  $tr->{entrytype}[0]);
    }
  }

  # sorting excludes
  foreach my $sex ($bcfxml->{sortexclusion}->@*) {
    my $excludes;
    foreach my $ex ($sex->{exclusion}->@*) {
      $excludes->{$ex->{content}} = 1;
    }
    Biber::Config->setblxoption(undef, 'sortexclusion',
                                $excludes,
                                'ENTRYTYPE',
                                $sex->{type});
  }

  # sorting includes
  foreach my $sin ($bcfxml->{sortinclusion}->@*) {
    my $includes;
    foreach my $in ($sin->{inclusion}->@*) {
      $includes->{$in->{content}} = 1;
    }
    Biber::Config->setblxoption(undef, 'sortinclusion',
                                $includes,
                                'ENTRYTYPE',
                                $sin->{type});
  }

  # presort defaults
  foreach my $presort ($bcfxml->{presort}->@*) {
    # Global presort default
    unless (exists($presort->{type})) {
      Biber::Config->setblxoption(undef, 'presort', $presort->{content});
    }
    # Per-type default
    else {
      Biber::Config->setblxoption(undef, 'presort',
                                  $presort->{content},
                                  'ENTRYTYPE',
                                  $presort->{type});
    }
  }

  my $sortingtemplates;
  foreach my $ss ($bcfxml->{sortingtemplate}->@*) {
    $sortingtemplates->{$ss->{name}} = _parse_sort($ss);
  }
  Biber::Config->setblxoption(undef, 'sortingtemplate', $sortingtemplates);

  # DATAMODEL schema (always global and is an array to accomodate multiple
  # datamodels in tool mode)

  # Because in tests, parse_ctrlfile() is called several times so we need to sanitise this here
  Biber::Config->setblxoption(undef, 'datamodel', []);
  Biber::Config->addtoblxoption(undef, 'datamodel', $bcfxml->{datamodel});

  # SECTIONS
  # This is also where we set data files as these are associated with a bib section

  # Data sources
  my %bibdatasources = ();
  foreach my $data ($bcfxml->{bibdata}->@*) {
    foreach my $datasource ($data->{datasource}->@*) {
      unless (first {$_->{type} eq $datasource->{type} and
             $_->{datatype} eq $datasource->{datatype} and
               $_->{name} eq $datasource->{content}} $bibdatasources{$data->{section}[0]}->@*) {
        push $bibdatasources{$data->{section}[0]}->@*, { type     => $datasource->{type},
                                                         name     => $datasource->{content},
                                                         datatype => $datasource->{datatype},
                                                         encoding => $datasource->{encoding} // Biber::Config->getoption('input_encoding'),
                                                         glob     => $datasource->{glob} // Biber::Config->getoption('glob_datasources')};
      }
    }
  }

  # Be friendly to latexmk etc.
  unless (%bibdatasources) {
    biber_warn("No data sources defined!");
    exit EXIT_OK;
  }

  my $key_flag = 0;
  my $bib_sections = new Biber::Sections;

SECTION: foreach my $section ($bcfxml->{section}->@*) {
    my $bib_section;
    my $secnum = $section->{number};
    # Can be multiple section 0 entries and so re-use that section object if it exists
    if (my $existing_section = $bib_sections->get_section($secnum)) {
      $bib_section = $existing_section;
    }
    else {
      $bib_section = new Biber::Section('number' => $secnum);
    }

    # Set the data files for the section unless we've already done so
    # (for example, for multiple section 0 entries)
    $bib_section->set_datasources($bibdatasources{$secnum}) unless
      $bib_section->get_datasources;

    my @prekeys = ();
    my @keys = ();
    # Pre-process to deal with situation where key is both \nocite'd and \cited
    # \cite'd takes priority
    foreach my $keyc ($section->{citekey}->@*) {
      my $key = NFD($keyc->{content}); # Key is already UTF-8 - it comes from UTF-8 XML

      if ($keyc->{nocite}) {# \nocite'd
        # Don't add if there is an identical key without nocite since \cite takes precedence
        unless (first {$key eq NFD($_->{content})} @prekeys) {
          push @prekeys, $keyc;
        }
      }
      else {# \cite'd
        # If there is already a nocite of this key, remove the nocite attribute and don't add
        if (first {($key eq NFD($_->{content})) and $_->{nocite}} @prekeys) {
          @prekeys = map {delete($_->{nocite}) if $key eq NFD($_->{content});$_} @prekeys;
        }
        else {
          push @prekeys, $keyc;
        }
      }
    }

    # Loop over all section keys
    foreach my $keyc (@prekeys) {
      my $key = NFD($keyc->{content}); # Key is already UTF-8 - it comes from UTF-8 XML
      # Stop reading citekeys if we encounter "*" as a citation as this means
      # "all keys"
      if ($key eq '*') {
        $bib_section->set_allkeys(1);
        if ($keyc->{nocite}) {
          $bib_section->set_allkeys_nocite(1);
        }
        $key_flag = 1; # There is at least one key, used for error reporting below
      }
      elsif (not Biber::Config->get_seenkey($key, $secnum)) {
        # Dynamic set definition
        # Save dynamic key -> member keys mapping for set entry auto creation later
        # We still need to find these even if allkeys is set
        if (exists($keyc->{type}) and $keyc->{type} eq 'set') {
          $bib_section->set_dynamic_set($key, split /\s*,\s*/, $keyc->{members});
          push @keys, $key;
          $key_flag = 1; # There is at least one key, used for error reporting below
        }
        else {
          # Track cite/nocite - needed for sourcemapping logic
          if ($keyc->{nocite}) {
            $bib_section->add_nocite($key);
          }
          else {
            $bib_section->add_cite($key);
          }
          # Set order information - there is no order on dynamic key defs above
          # as they are a definition, not a cite
          Biber::Config->set_keyorder($secnum, $key, $keyc->{order});
          push @keys, $key;
          $key_flag = 1; # There is at least one key, used for error reporting below
          Biber::Config->incr_seenkey($key, $secnum);
        }
      }
    }

    if ($bib_section->is_allkeys) {
      # Normalise - when allkeys is true don't need citekeys - just in case someone
      # lists "*" and also some other citekeys
      $bib_section->del_citekeys;
      $logger->info("Using all citekeys in bib section " . $secnum);
    }
    else {
      $logger->info('Found ', $#keys+1 , " citekeys in bib section $secnum");
    }

    unless ($bib_section->is_allkeys) {
      if ($logger->is_debug()) { # performance shortcut
        $logger->debug("The citekeys for section $secnum are: ", join(', ', sort @keys), "\n");
      }
    }

    $bib_section->add_citekeys(@keys) unless $bib_section->is_allkeys;
    $bib_sections->add_section($bib_section);
  }

  # Add the Biber::Sections object to the Biber object
  $self->{sections} = $bib_sections;

  # Read datalists
  my $datalists = new Biber::DataLists;

  foreach my $list ($bcfxml->{datalist}->@*) {
    my $ltype  = $list->{type};
    my $lstn = $list->{sortingtemplatename};
    my $lsnksn = $list->{sortingnamekeytemplatename};
    my $luntn = $list->{uniquenametemplatename};
    my $llantn = $list->{labelalphanametemplatename};
    my $lpn = $list->{labelprefix};
    my $lname = $list->{name};

    my $lsection = $list->{section}[0]; # because "section" needs to be a list elsewhere in XML
    if ($datalists->get_list(section                    => $lsection,
                             name                       => $lname,
                             type                       => $ltype,
                             sortingtemplatename        => $lstn,
                             sortingnamekeytemplatename    => $lsnksn,
                             labelprefix                => $lpn,
                             uniquenametemplatename     => $luntn,
                             labelalphanametemplatename => $llantn)) {
      if ($logger->is_debug()) {# performance tune
        $logger->debug("Section datalist '$lname' of type '$ltype' with sortingtemplate '$lstn', sortingnamekeytemplatename '$lsnksn', labelprefix '$lpn', uniquenametemplate '$luntn' and labelalphanametemplate '$llantn' is repeated for section $lsection - ignoring");
      }
      next;
    }

    my $datalist = Biber::DataList->new(section                    => $lsection,
                                        sortingtemplatename        => $lstn,
                                        sortingnamekeytemplatename    => $lsnksn,
                                        uniquenametemplatename     => $luntn,
                                        labelalphanametemplatename => $llantn,
                                        labelprefix                => $lpn,
                                        name                       => $lname);
    $datalist->set_type($ltype || 'entry'); # lists are entry lists by default
    $datalist->set_name($lname || "$lstn/$lsnksn/$lpn/$luntn/$llantn"); # default to ss+snkss+pn+untn+lantn
    foreach my $filter ($list->{filter}->@*) {
      $datalist->add_filter({'type'  => $filter->{type},
                            'value' => $filter->{content}});
    }
    # disjunctive filters are an array ref of filter hashes
    foreach my $orfilter ($list->{filteror}->@*) {
      my $orfilts = [];
      foreach my $filter ($orfilter->{filter}->@*) {
        push $orfilts->@*, {type  => $filter->{type},
                            value => $filter->{content}};
      }
      $datalist->add_filter($orfilts) if $orfilts;
    }

    # Collator for determining primary weight hash for sortinit
    # Here as it varies only with the locale and that doesn't vary between entries in a list
    # Potentially, the locale could be different for the first field in the sort spec in which
    # case that might give wrong results but this is highly unlikely as it is only used to
    # determine sortinithash in DataList.pm and that only changes \bibinitsep in biblatex.
    $datalist->set_sortinit_collator(Unicode::Collate::Locale->new(locale => Biber::Config->getblxoption(undef, 'sortingtemplate')->{$datalist->get_sortingtemplatename}->{locale}, level => 1));

    if ($logger->is_debug()) {# performance tune
      $logger->debug("Adding datalist of type '$ltype' with sortingtemplate '$lstn', sortingnamekeytemplatename '$lsnksn', labelprefix '$lpn', uniquenametemplate '$luntn', labelalphanametemplate '$llantn' and name '$lname' for section $lsection");
    }
    $datalists->add_list($datalist);
  }

  # Check to make sure that each section has an entry datalist for global sorting
  # We have to make sure in case sortcites is used which uses the global order.
  foreach my $section ($bcfxml->{section}->@*) {
    my $globalss = Biber::Config->getblxoption(undef, 'sortingtemplatename');
    my $secnum = $section->{number};

    unless ($datalists->get_lists_by_attrs(section                    => $secnum,
                                           type                       => 'entry',
                                           sortingtemplatename        => $globalss,
                                           sortingnamekeytemplatename    => 'global',
                                           uniquenametemplatename     => 'global',
                                           labelalphanametemplatename => 'global',
                                           labelprefix                => '',
                                           name                       => "$globalss/global//global/global")) {
      my $datalist = Biber::DataList->new(section                    => $secnum,
                                          type                       => 'entry',
                                          sortingtemplatename        => $globalss,
                                          sortingnamekeytemplatename    => 'global',
                                          uniquenametemplatename     => 'global',
                                          labelalphanametemplatename => 'global',
                                          labelprefix                => '',
                                          name                       => "$globalss/global//global/global");
      $datalists->add_list($datalist);
      # See comment above

      $datalist->set_sortinit_collator(Unicode::Collate::Locale->new(locale => Biber::Config->getblxoption(undef, 'sortingtemplate')->{$datalist->get_sortingtemplatename}->{locale}, level => 1));
    }
  }

  # Add the Biber::DataLists object to the Biber object
  $self->{datalists} = $datalists;

  # Warn if there are no citations in any section
  unless ($key_flag) {
    biber_warn("The file '$ctrl_file_path' does not contain any citations!");
  }

  # Normalise any UTF-8 encoding string immediately to exactly what we want
  # We want the strict perl utf8 "UTF-8"
  normalise_utf8();

  # bibtex output when not in tool mode, is essentially entering tool mode but
  # without allkeys. We are not in tool mode if we are here. We fake tool mode
  # and then add a special section which contains all cited keys from all sections
  # No reference resolution for bibtex output and always include all cross/xrefs
  # otherwise the output won't be a standalone .bib file
  if (Biber::Config->getoption('output_format') eq 'bibtex') {
    Biber::Config->setoption('tool', 1);
    Biber::Config->setoption('mincrossrefs', 1);
    Biber::Config->setoption('minxrefs', 1);

    my $bib_section = new Biber::Section('number' => 99999);

    foreach my $section ($self->sections->get_sections->@*) {
      if ($section->is_allkeys) {
        $bib_section->set_allkeys(1);
      }
      else {
        $bib_section->add_citekeys($section->get_citekeys);
      }
      foreach my $ds ($section->get_datasources->@*) {
        $bib_section->add_datasource($ds);
      }
    }

    $self->sections->add_section($bib_section);

    my $datalist = Biber::DataList->new(section => 99999,
                                        sortingtemplatename => Biber::Config->getblxoption(undef, 'sortingtemplatename'),
                                        sortingnamekeytemplatename => 'global',
                                        uniquenametemplatename => 'global',
                                        labelalphanametemplatename => 'global',
                                        labelprefix => '',
                                        name => Biber::Config->getblxoption(undef, 'sortingtemplatename') . '/global//global/global');
    $datalist->set_type('entry');
    if ($logger->is_debug()) {# performance tune
      $logger->debug("Adding 'entry' list 'none' for pseudo-section 99999");
    }
    $self->{datalists}->add_list($datalist);
  }

  return;
}


=head2 process_setup

   Place to put misc pre-processing things needed later

=cut

sub process_setup {
  my $self = shift;

  # If this is tool mode and therefore there is a 99999 section, delete all other sections
  # This is because bibtex output not in real tool mode retains sections from the .bcf
  # which are not needed and cause unnecessary dual-processing of entries since everything
  # is already in the 99999 section anyway
  foreach my $section ($self->sections->get_sections->@*) {
    if (Biber::Config->getoption('output_format') eq 'bibtex') {
      if ($section->number != 99999) {
        $self->sections->delete_section($section);
      }
    }
  }

  # Make sure there is a default entry list with global sorting for each refsection
  # Needed in case someone cites entries which are included in no
  # bibliography as this results in no entry list in the .bcf
  foreach my $section ($self->sections->get_sections->@*) {
    my $secnum = $section->number;

    unless ($self->datalists->has_lists_of_type_for_section($secnum, 'entry')) {
      my $datalist = Biber::DataList->new(sortingtemplatename => Biber::Config->getblxoption(undef, 'sortingtemplatename'),
                                          sortingnamekeytemplatename => 'global',
                                          uniquenametemplatename => 'global',
                                          labelalphanametemplatename => 'global',
                                          labelprefix => '',
                                          name => Biber::Config->getblxoption(undef, 'sortingtemplatename') . '/global//global/global');
      $datalist->set_type('entry');
      $datalist->set_section($secnum);
      $self->datalists->add_list($datalist);
      # See comment for same call in .bcf instantiation of datalists
      $datalist->set_sortinit_collator(Unicode::Collate::Locale->new(locale => Biber::Config->getblxoption(undef, 'sortingtemplate')->{$datalist->get_sortingtemplatename}->{locale}, level => 1));
    }
  }

  # Break data model information up into more processing-friendly formats
  # for use in verification checks later
  # This has to be here as opposed to in parse_ctrlfile() so that it can pick
  # up user config dm settings
  Biber::Config->set_dm(Biber::DataModel->new(Biber::Config->getblxoption(undef, 'datamodel')));

  # Now resolve any datafield sets from the .bcf
  _resolve_datafieldsets();

  # Force output_safechars flag if output to ASCII and input_encoding is not ASCII
  if (Biber::Config->getoption('output_encoding') =~ /(?:x-)?ascii/xmsi and
      Biber::Config->getoption('input_encoding') !~ /(?:x-)?ascii/xmsi) {
    Biber::Config->setoption('output_safechars', 1);
  }
}

=head2 process_setup_tool

   Place to put misc pre-processing things needed later for tool mode

=cut

sub process_setup_tool {
  my $self = shift;

  Biber::Config->set_dm(Biber::DataModel->new(Biber::Config->getblxoption(undef, 'datamodel')));

  # Now resolve any datafield sets from the .bcf
  _resolve_datafieldsets();

  # Force output_safechars flag if output to ASCII and input_encoding is not ASCII
  if (Biber::Config->getoption('output_encoding') =~ /(?:x-)?ascii/xmsi and
      Biber::Config->getoption('input_encoding') !~ /(?:x-)?ascii/xmsi) {
    Biber::Config->setoption('output_safechars', 1);
  }
}

# datafield sets need to be resolved after the datamodel is parsed
sub _resolve_datafieldsets {
  my $dm = Biber::Config->get_dm;
  while (my ($key, $value) = each %DATAFIELD_SETS) {
    my $fs;
    foreach my $m ($value->@*) {
      if (ref $m eq 'HASH') {
        if ($m->{fieldtype} and $m->{datatype}) {
          push $fs->@*, $dm->get_fields_of_type($m->{fieldtype}, $m->{datatype})->@*;
        }
        elsif ($m->{fieldtype}) {
          push $fs->@*, $dm->get_fields_of_fieldtype($m->{fieldtype})->@*;
        }
        elsif ($m->{datatype}) {
          push $fs->@*, $dm->get_fields_of_datatype($m->{datatype})->@*;
        }
      }
      else {
        push $fs->@*, $m;
      }
    }
    $DATAFIELD_SETS{$key} = $fs;
  }
}


=head2 resolve_alias_refs

  Resolve aliases in xref/crossref/xdata which take keys as values to their real keys

  We use set_datafield as we are overriding the alias in the datasource

=cut

sub resolve_alias_refs {
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $dm = Biber::Config->get_dm;


  # Don't resolve alias refs in tool mode unless told to
  if (Biber::Config->getoption('tool') and
      not (Biber::Config->getoption('output_resolve_crossrefs') or
           Biber::Config->getoption('output_resolve_xdata'))) {
    return;
  }

  foreach my $citekey ($section->get_citekeys) {
    my $be = $section->bibentry($citekey);

    # XREF
    if (my $refkey = $be->get_field('xref')) {
      if (my $realkey = $section->get_citekey_alias($refkey)) {
        $be->set_datafield('xref', $realkey);
      }
    }
    # CROSSREF
    if (my $refkey = $be->get_field('crossref')) {
      if (my $realkey = $section->get_citekey_alias($refkey)) {
        $be->set_datafield('crossref', $realkey);
      }
    }
    # XDATA
    if (my $xdata = $be->get_xdata_refs) {
      my $resolved_keys;
      foreach my $xdataref ($xdata->@*) {
        if (not defined($xdataref->{xdatafield})) { # XDATA ref to whole entry
          foreach my $refkey ($xdataref->{xdataentries}->@*) { # whole entry XDATA can be xsv
            $refkey = $section->get_citekey_alias($refkey) // $refkey;
            push $resolved_keys->@*, $refkey;
          }
          $xdataref->{xdataentries} = $resolved_keys;
        }
        else { # granular XDATA ref - only one entry key
          my $refkey = $xdataref->{xdataentries}->[0];
          $refkey = $section->get_citekey_alias($refkey) // $refkey;
          $xdataref->{xdataentries} = [$refkey];
        }
      }
    }
  }
}


=head2 process_citekey_aliases

 Remove citekey aliases from citekeys as they don't point to real
 entries.

=cut

sub process_citekey_aliases {
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  foreach my $citekey ($section->get_citekeys) {
    if (my $a = $section->get_citekey_alias($citekey)) {
      if ($logger->is_debug()) {# performance tune
        $logger->debug("Pruning citekey alias '$citekey' from citekeys");
      }
      $section->del_citekey($citekey);
    }
  }
}

=head2 instantiate_dynamic

    This instantiates any dynamic entries so that they are available
    for processing later on. This has to be done before most all other
    processing so that when we call $section->bibentry($key), as we
    do many times in the code, we don't die because there is a key but
    no Entry object.

=cut

sub instantiate_dynamic {
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);

  if ($logger->is_debug()) {# performance tune
    $logger->debug("Creating dynamic entries (sets/related) for section $secnum");
  }

  # Instantiate any dynamic set entries before we do anything else
  foreach my $dset ($section->dynamic_set_keys->@*) {
    my @members = $section->get_dynamic_set($dset);

    # Resolve any aliases in the members
    my @realmems;
    foreach my $mem (@members) {
      push @realmems, $section->get_citekey_alias($mem) // $mem;
    }
    @members = @realmems;
    $section->set_dynamic_set($dset, @realmems);

    my $be = new Biber::Entry;
    $be->set_field('entrytype', 'set');
    $be->set_field('entryset', [ @members ]);
    $be->set_field('citekey', $dset);
    $be->set_field('datatype', 'dynamic');
    $section->bibentries->add_entry($dset, $be);
    if ($logger->is_debug()) {# performance tune
      $logger->debug("Created dynamic set entry '$dset' in section $secnum");
    }

    foreach my $m (@members) {
    # Save graph information if requested
      if (Biber::Config->getoption('output_format') eq 'dot') {
        Biber::Config->set_graph('set', $dset, $m);
      }
      # Instantiate any related entry clones we need from dynamic set members
      $section->bibentry($m)->relclone;
    }
    # Setting dataonly options for members is handled by process_sets()
  }

  # Instantiate any related entry clones we need from regular entries
  foreach my $citekey ($section->get_citekeys) {
    $section->bibentry($citekey)->relclone;
  }

  return;
}

=head2 resolve_xdata

    Resolve xdata

=cut

sub resolve_xdata {
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);

  # Don't resolve xdata in tool mode unless told to
  if (Biber::Config->getoption('tool') and
      not Biber::Config->getoption('output_resolve_xdata')) {
    return;
  }

  if ($logger->is_debug()) {# performance tune
    $logger->debug("Resolving XDATA for section $secnum");
  }

  # We are not looping over citekeys here as XDATA entries are not cited.
  # They may have been added to the section as entries, however.
  foreach my $be ($section->bibentries->entries) {
    # Don't directly resolve XDATA entrytypes - this is done recursively in the Entry method
    # Otherwise, we will die on loops etc. for XDATA entries which are never referenced from
    # any cited entry
    next if $be->get_field('entrytype') eq 'xdata';
    next unless my $xdata = $be->get_xdata_refs;
    $be->resolve_xdata($xdata);
  }
}


=head2 cite_setmembers

    Promotes set member to cited status

=cut

sub cite_setmembers {
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);

  if ($logger->is_debug()) {# performance tune
    $logger->debug("Adding set members to citekeys for section $secnum");
  }

  foreach my $citekey ($section->get_citekeys) {
    my $be = $section->bibentry($citekey);

    # promote indirectly cited inset set members to fully cited entries
    if ($be->get_field('entrytype') eq 'set' and
        $be->get_field('entryset')) {
      my $inset_keys = $be->get_field('entryset');

      # Ignore empty sets (likely this means that they contained only
      # non-existent keys that were removed)
      next unless $inset_keys->@*;

      my $realmems;
      foreach my $mem ($inset_keys->@*) {
        push $realmems->@*, $section->get_citekey_alias($mem) // $mem;
      }
      $inset_keys = $realmems;
      $be->set_datafield('entryset', $inset_keys);

      foreach my $inset_key ($inset_keys->@*) {
        if ($logger->is_debug()) {# performance tune
          $logger->debug("Adding set member '$inset_key' to the citekeys (section $secnum)");
        }
        $section->add_citekeys($inset_key);

        # Save graph information if requested
        if (Biber::Config->getoption('output_format') eq 'dot') {
          Biber::Config->set_graph('set', $citekey, $inset_key);
        }
      }

      # Set parents inherit first child member data so that they get sensible
      # sorting/labelling defaults. Most of these inherited fields will not be output
      # in the .bbl
      $be->set_inherit_from($section->bibentry($inset_keys->[0]), $section);

      # warning for the old pre-Biber way of doing things
      if ($be->get_field('crossref')) {
        biber_warn("Field 'crossref' is no longer needed in set entries in Biber - ignoring in entry '$citekey'", $be);
        $be->del_field('crossref');
      }
    }
  }
}

=head2 preprocess_sets

    $biber->preprocess_sets

    This records the set information for use later

=cut

sub preprocess_sets {
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);

  # Don't preprocess sets in tool mode unless told to
  if (Biber::Config->getoption('tool') and
      not Biber::Config->getoption('output_resolve_sets')) {
    return;
  }

  if ($logger->is_debug()) {# performance tune
    $logger->debug("Recording set information");
  }

  foreach my $citekey ($section->get_citekeys) {
    my $be = $section->bibentry($citekey);

    # Record set information
    # It's best to do this in the loop here as every entry needs the information
    # from all other entries in process_sets()
    if ($be->get_field('entrytype') eq 'set') {
      my $entrysetkeys = $be->get_field('entryset');
      unless ($entrysetkeys) {
        biber_warn("Set entry '$citekey' has no entryset field, ignoring", $be);
        next;
      }
      foreach my $member ($entrysetkeys->@*) {
        $section->set_set_pc($citekey, $member);
        $section->set_set_cp($member, $citekey);

        # Instantiate any related entry clones we need from static set members
        $section->bibentry($member)->relclone;
      }
    }
  }
}


=head2 calculate_interentry

    $biber->calculate_interentry

    Ensures that crossrefs/xrefs that are directly cited or cross-referenced
    at least mincrossrefs/minxrefs times are included in the bibliography.

=cut

sub calculate_interentry {
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);

  if ($logger->is_debug()) {# performance tune
    $logger->debug("Calculating explicit and implicit xref/crossrefs for section $secnum");
  }

  foreach my $citekey ($section->get_citekeys) {
    my $be = $section->bibentry($citekey);

    # Loop over cited keys and count the cross/xrefs
    # Can't do this when parsing entries as this would count them
    # for potentially uncited children
    if (my $refkey = $be->get_field('crossref')) {
      if ($logger->is_debug()) {# performance tune
        $logger->debug("Incrementing crossrefkey count for entry '$refkey' via entry '$citekey'");
      }
      Biber::Config->incr_crossrefkey($refkey);
    }

    if (my $refkey = $be->get_field('xref')) {
      if ($logger->is_debug()) {# performance tune
        $logger->debug("Incrementing xrefkey count for entry '$refkey' via entry '$citekey'");
      }
      Biber::Config->incr_xrefkey($refkey);
    }

    # Record xref inheritance for graphing if required
    if (Biber::Config->getoption('output_format') eq 'dot' and
        my $xref = $be->get_field('xref')) {
      Biber::Config->set_graph('xref', $citekey, $xref);
    }
  }

  # We make sure that crossrefs that are directly cited or cross-referenced
  # at least mincrossrefs times are included in the bibliography.
  foreach my $k ( Biber::Config->get_crossrefkeys->@* ) {
    # If parent has been crossref'ed more than mincrossref times, upgrade it
    # to cited crossref status and add it to the citekeys list
    if (Biber::Config->get_crossrefkey($k) >= Biber::Config->getoption('mincrossrefs')) {
      if ($logger->is_debug()) {# performance tune
        $logger->debug("cross key '$k' is crossref'ed >= mincrossrefs, adding to citekeys");
      }
      # Don't add this flag if the entry is also cited directly
      $section->bibentry($k)->set_field('crossrefsource', 1) unless $section->has_citekey($k);
      $section->add_citekeys($k);
    }
  }

  # We make sure that xrefs that are directly cited or x-referenced
  # at least minxrefs times are included in the bibliography.
  foreach my $k ( Biber::Config->get_xrefkeys->@* ) {
    # If parent has been xref'ed more than minxref times, upgrade it
    # to cited xref status and add it to the citekeys list
    if (Biber::Config->get_xrefkey($k) >= Biber::Config->getoption('minxrefs')) {
      if ($logger->is_debug()) {# performance tune
        $logger->debug("xref key '$k' is xref'ed >= minxrefs, adding to citekeys");
      }
      # Don't add this flag if the entry is also cited directly
      $section->bibentry($k)->set_field('xrefsource', 1) unless $section->has_citekey($k);
      $section->add_citekeys($k);
    }
  }
}

=head2 process_interentry

    $biber->process_interentry

    Ensures proper inheritance of data from cross-references.

=cut

sub process_interentry {
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);

  # Don't resolve crossrefs in tool mode unless told to
  if (Biber::Config->getoption('tool') and
      not Biber::Config->getoption('output_resolve_crossrefs')) {
    return;
  }

  if ($logger->is_debug()) {# performance tune
    $logger->debug("Processing explicit and implicit xref/crossrefs for section $secnum");
  }

  # This must come after doing implicit inclusion based on minref/mincrossref
  # otherwise cascading xref->crossref wont' work
  foreach my $citekey ($section->get_citekeys) {
    my $be = $section->bibentry($citekey);

    # Do crossref inheritance
    if (my $cr = $be->get_field('crossref')) {
      # Skip inheritance if we've already done it
      next if Biber::Config->get_inheritance('crossref', $cr, $be->get_field('citekey'));
      my $parent = $section->bibentry($cr);
      if ($logger->is_debug()) {# performance tune
        $logger->debug("Entry $citekey inheriting fields from parent $cr");
      }
      unless ($parent) {
        biber_warn("Cannot inherit from crossref key '$cr' - does it exist?", $be);
      }
      else {
        $be->inherit_from($parent);
      }
    }
  }
}

=head2 validate_datamodel

  Validate bib data according to a datamodel
  Note that we are validating the internal Biber::Entries
  after they have been created from the datasources so this is
  datasource neutral, as it should be. It is here to enforce
  adherence to what biblatex expects.

=cut

sub validate_datamodel {
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $dm = Biber::Config->get_dm;

  if (Biber::Config->getoption('validate_datamodel')) {
    $logger->info("Datamodel validation starting");
    my $dmwe = Biber::Config->getoption('dieondatamodel') ? \&biber_error : \&biber_warn;
    foreach my $citekey ($section->get_citekeys) {
      my $be = $section->bibentry($citekey);
      my $citekey = $be->get_field('citekey');
      my $et = $be->get_field('entrytype');
      my $ds = $section->get_keytods($citekey);

      # default entrytype to MISC type if not a known type
      unless ($dm->is_entrytype($et)) {
        $dmwe->("Datamodel: Entry '$citekey' ($ds): Invalid entry type '" . $be->get_field('entrytype') . "' - defaulting to 'misc'", $be);
        $be->set_field('entrytype', 'misc');
        $et = 'misc';           # reset this too
      }

      # Are all fields valid fields?
      # Each field must be:
      # * Valid because it's allowed for "ALL" entrytypes OR
      # * Valid field for the specific entrytype OR
      # * Valid because entrytype allows "ALL" fields
      unless ($et eq 'xdata' or $et eq 'set') { # XDATA/SET are generic containers for any field
        foreach my $ef ($be->datafields) {
          unless ($dm->is_field_for_entrytype($et, $ef)) {
            $dmwe->("Datamodel: Entry '$citekey' ($ds): Invalid field '$ef' for entrytype '$et'", $be);
          }
        }
      }

      # Mandatory constraints
      foreach my $warning ($dm->check_mandatory_constraints($be)) {
        $dmwe->($warning, $be);
      }

      # Conditional constraints
      foreach my $warning ($dm->check_conditional_constraints($be)) {
        $dmwe->($warning, $be);
      }

      # Data constraints
      foreach my $warning ($dm->check_data_constraints($be)) {
        $dmwe->($warning, $be);
      }
    }
    $logger->info("Datamodel validation complete");
  }
}

=head2 process_namedis

    Generate name strings and disambiguation schema. Has to be in the context
    of a data list (reference context) because uniquenametemplate can be specified
    per-list/context

=cut

sub process_namedis {
  my ($self, $citekey, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $dmh = Biber::Config->get_dm_helpers;
  if ($logger->is_debug()) {    # performance tune
    $logger->debug("Processing names in entries in section $secnum to generate disambiguation data");
  }
  # Use nameuniqueness template to construct uniqueness strings
  my $untname = $dlist->get_uniquenametemplatename;

  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');

  my $un = Biber::Config->getblxoption($secnum, 'uniquename', $bee, $citekey);
  my $ul = Biber::Config->getblxoption($secnum, 'uniquelist', $bee, $citekey);

  # Can be per-entry
  $untname = Biber::Config->getblxoption($secnum, 'uniquenametemplatename', undef, $citekey) // $untname;

  # Instead of setting this directly in here, we save the data and pass it out as we need
  # to use this method to get data without setting it in the list object (in uniqueprimaryauthor())
  my $namedis;

MAIN:  foreach my $pn ($dmh->{namelistsall}->@*) {
    next unless my $nl = $be->get_field($pn);
    my $nlid = $nl->get_id;

    # per-namelist uniquenametemplatename
    if (defined($nl->get_uniquenametemplatename)) {
      $untname = $nl->get_uniquenametemplatename;
    }

    # per-namelist uniquelist
    if (defined($nl->get_uniquelist)) {
      $ul = $nl->get_uniquelist;
    }

    # per-namelist uniquename
    if (defined($nl->get_uniquename)) {
      $un = $nl->get_uniquename;
    }

    foreach my $n ($nl->names->@*) {
      my $nid = $n->get_id;

      my $namestring = '';
      my $namestrings = [];
      my $namedisschema = [];

      # per-name uniquenametemplatename
      if (defined($n->get_uniquenametemplatename)) {
        $untname = $n->get_uniquenametemplatename;
      }

      # per-name uniquename
      if (defined($n->get_uniquename)) {
        $un = $n->get_uniquename;
      }

      my $nameun = $un;

      # First construct base part ...
      my $base = ''; # Might not be any base parts at all so make sure it's not undefined
      my $baseparts;

      foreach my $np (Biber::Config->getblxoption(undef, 'uniquenametemplate')->{$untname}->@*) {
        next unless $np->{base};
        my $npn = $np->{namepart};

        if (my $p = $n->get_namepart($npn)) {
          if ($np->{use}) {     # only ever defined as 1
            my $method = "get_use$npn";
            my $useok = Biber::Config->getblxoption($secnum, "use$npn",
                                                    $bee,
                                                    $citekey);
            # Override with per-namelist setting - only for extended name format
            if (defined($nl->$method)) {
              $useok = $nl->$method;
            }
            # Override with per-name setting - only for extended name format
            if (defined($n->$method)) {
              $useok = $n->$method;
            }
            next unless $useok;
          }
          $base .= $p;
          push $baseparts->@*, $npn;
        }
      }

      $namestring .= $base;
      push $namestrings->@*, $base;
      push $namedisschema->@*, ['base' => $baseparts] if defined($baseparts);

      # ... then add non-base parts by incrementally adding to the last disambiguation level
      foreach my $np (Biber::Config->getblxoption(undef, 'uniquenametemplate')->{$untname}->@*) {
        next if $np->{base};
        next if defined($np->{disambiguation}) and ($np->{disambiguation} eq 'none');

        my $npn = $np->{namepart};

        my $level = $np->{disambiguation} // $UNIQUENAME_CONTEXTS{$un // 'false'};
        my $lastns = $namestrings->[$namestrings->$#*];

        if (my $p = $n->get_namepart($npn)) {
          my $pi = $n->get_namepart_initial($npn);
          if ($np->{use}) {     # only ever defined as 1
            my $method = "get_use$npn";
            my $useok = Biber::Config->getblxoption($secnum, "use$npn",
                                                    $bee,
                                                    $citekey);
            # Override with per-namelist setting - only for extended name format
            if (defined($nl->$method)) {
              $useok = $nl->$method;
            }
            # Override with per-name setting - only for extended name format
            if (defined($n->$method)) {
              $useok = $n->$method;
            }
            next unless $useok;
          }

          $namestring .= $p;

          # per-namepart disambiguation level
          # Here we incrementally add disambiguation possibilities to an array and simultaneously
          # record a schema of what each incremental disambiguation is
          if (fc($level) eq fc('full')) { # only full disambiguation
            push $namestrings->@*, $lastns . $p;
            push $namedisschema->@*, [$npn => 'fullonly'];
          }
          if (fc($level) eq fc('initorfull')) { # initials or full disambiguation
            push $namestrings->@*, $lastns . join('', $pi->@*);
            push $namedisschema->@*, [$npn => 'init'];
            push $namestrings->@*, $lastns . $p;
            push $namedisschema->@*, [$npn => 'full'];
          }
          elsif (fc($level) eq fc('init')) { # inits only
            push $namestrings->@*, $lastns . join('', $pi->@*);
            push $namedisschema->@*, [$npn => 'init'];
          }
        }
      }

      if ($logger->is_trace()) { # performance tune
        $logger->trace("namestrings in '$citekey': " . join (',', $namestrings->@*));
      }

      # namelistul is the option value of the effective uniquelist option at the level
      # of the list in which the name occurs. It's useful to know this where the results
      # of the sub are used
      $namedis->{$nlid}{$nid} = {nameun        => $nameun,
                                 namelistul    => $ul,
                                 namestring    => $namestring,
                                 namestrings   => $namestrings,
                                 namedisschema => $namedisschema};
    }
  }

  return $namedis;
}

=head2 postprocess_sets

  Adds required per-entry options etc. to sets

=cut

sub postprocess_sets {
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  foreach my $citekey ( $section->get_citekeys ) {

    # process set entries
    $self->process_sets($citekey);
  }

  return;
}

=head2 process_entries_static

  Processing of entries which is not list-specific and which can therefore
  insert data directly into entries

=cut

sub process_entries_static {
  my ($self) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  if ($logger->is_debug()) {# performance tune
    $logger->debug("Processing static entry information in section $secnum");
  }
  foreach my $citekey ( $section->get_citekeys ) {

    # generate nocite information
    $self->process_nocite($citekey);

    # generate labelname name
    $self->process_labelname($citekey);

    # generate labeldate name
    $self->process_labeldate($citekey);

    # generate labeltitle name
    $self->process_labeltitle($citekey);

    # generate fullhash
    $self->process_fullhash($citekey);

    # push entry-specific presort fields into the presort state
    $self->process_presort($citekey);
  }
}

=head2 process_entries_pre

    Main processing operations, to generate metadata and entry information
    This method is automatically called by C<prepare>.
    Runs prior to uniqueness processing

=cut

sub process_entries_pre {
  my ($self, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  if ($logger->is_debug()) {# performance tune
    $logger->debug("Processing entries in section $secnum (before uniqueness)");
  }
  foreach my $citekey ( $section->get_citekeys ) {

    my $be = $section->bibentry($citekey);

    # process name disambiguation schemata
    my $namedis = $self->process_namedis($citekey, $dlist);

    foreach my $nlid (keys $namedis->%*) {
      foreach my $nid (keys $namedis->{$nlid}->%*) {
        # process_namedis() has to record uniquelist/uniquename as it has access to
        # namelist-scope and name-scope uniquelist/uniquename and makes this visible
        # here so that they can be checked
        # We only don't set name disambiguation data if both uniquelist/uniquename
        # effective options are 'false'. If either are not false, we need the information
        if ($namedis->{$nlid}{$nid}{nameun} eq 'false' and
            $namedis->{$nlid}{$nid}{namelistul} eq 'false') {
          next;
        }
        $dlist->set_namedis($nlid,
                            $nid,
                            $namedis->{$nlid}{$nid}{namestring},
                            $namedis->{$nlid}{$nid}{namestrings},
                            $namedis->{$nlid}{$nid}{namedisschema});
      }
    }
  }

  if ($logger->is_debug()) {# performance tune
    $logger->debug("Finished processing entries in section $secnum (before uniqueness)");
  }

  return;
}

=head2 process_entries_post

    More processing operations, to generate things which require uniqueness
    information like namehash
    Runs after uniqueness processing

=cut

sub process_entries_post {
  my ($self, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  if ($logger->is_debug()) {# performance tune
    $logger->debug("Postprocessing entries in section $secnum (after uniqueness)");
  }
  foreach my $citekey ( $section->get_citekeys ) {

    # generate labelalpha information
    $self->process_labelalpha($citekey, $dlist);

    # generate information for tracking extraalpha
    $self->process_extraalpha($citekey, $dlist);

    # generate information for tracking extradate
    $self->process_extradate($citekey, $dlist);

    # generate information for tracking extraname
    $self->process_extraname($citekey, $dlist);

    # generate information for tracking extratitle
    $self->process_extratitle($citekey, $dlist);

    # generate information for tracking extratitleyear
    $self->process_extratitleyear($citekey, $dlist);

    # generate information for tracking singletitle, uniquetitle, uniquebaretitle and uniquework
    $self->process_workuniqueness($citekey, $dlist);

    # generate namehash
    $self->process_namehash($citekey, $dlist);

    # generate per-name hashes
    $self->process_pername_hashes($citekey, $dlist);

    # generate information for tracking uniqueprimaryauthor
    $self ->process_uniqueprimaryauthor($citekey, $dlist);

  }

  if ($logger->is_debug()) {# performance tune
    $logger->debug("Finished processing entries in section $secnum (after uniqueness)");
  }

  return;
}


=head2 process_entries_final

    Final processing operations which depend on all previous processing

=cut

sub process_entries_final {
  my ($self, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  if ($logger->is_debug()) {# performance tune
    $logger->debug("Final processing for entries in section $secnum");
  }
  foreach my $citekey ( $section->get_citekeys ) {

    # Generate singletitle field if requested
    $self->generate_singletitle($citekey, $dlist);

    # Generate uniquetitle field if requested
    $self->generate_uniquetitle($citekey, $dlist);

    # Generate uniquebaretitle field if requested
    $self->generate_uniquebaretitle($citekey, $dlist);

    # Generate uniquework field if requested
    $self->generate_uniquework($citekey, $dlist);

    # Generate uniqueprimaryauthor if requested
    $self->generate_uniquepa($citekey, $dlist);
  }
}


=head2 process_uniqueprimaryauthor

    Track seen primary author base names for generation of uniqueprimaryauthor

=cut

sub process_uniqueprimaryauthor {
  my ($self, $citekey, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');

  if (my $lni = $be->get_labelname_info) {
    if (Biber::Config->getblxoption(undef, 'uniqueprimaryauthor', $bee, $citekey)) {
      my $nl = $be->get_field($lni);
      if ($logger->is_trace()) {# performance tune
        $logger->trace("Creating uniqueprimaryauthor information for '$citekey'");
      }

      my $namedis = $self->process_namedis($citekey, $dlist);

      my $nds = $namedis->{$nl->get_id}{$nl->nth_name(1)->get_id}{namedisschema};
      my $nss = $namedis->{$nl->get_id}{$nl->nth_name(1)->get_id}{namestrings};
      my $pabase;

      for (my $i=0;$i<=$nds->$#*;$i++) {
        my $se = $nds->[$i];
        if ($se->[0] eq 'base') {
          $pabase = $nss->[$i];
        }
      }

      $dlist->set_entryfield($citekey, 'seenprimaryauthor', $pabase);
      $dlist->incr_seenpa($pabase, $nl->nth_name(1)->get_hash);
    }
  }
}

=head2 process_workuniqueness

    Track seen work combination for generation of singletitle, uniquetitle, uniquebaretitle and
    uniquework

=cut

sub process_workuniqueness {
  my ($self, $citekey, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');

  my $identifier;
  my $lni = $be->get_labelname_info;
  my $lti = $be->get_labeltitle_info;

  # ignore settings from inheritance data?
  my $ignore = Biber::Config->get_uniq_ignore($citekey);

  # singletitle
  # Don't generate information for entries with no labelname or labeltitle
  # Use fullhash as this is not a test of uniqueness of only visible information
  if ($lni and Biber::Config->getblxoption(undef, 'singletitle', $bee, $citekey)) {
    $identifier = $self->_getfullhash($citekey, $be->get_field($lni));

    # Skip due to ignore settings?
    # Don't count towards singletitle being false if both labelname and labeltitle
    # were inherited
    # Put another way, if both labelname and labeltitle were inherited, singletitle
    # can still be true (in a mvbook for example, which is just a single "work")
    unless (($lni and first {fc($lni) eq fc($_)} $ignore->{singletitle}->@*) and
            ($lti and first {fc($lti) eq fc($_)} $ignore->{singletitle}->@*)) {
      $dlist->incr_seenname($identifier);
    }
    $dlist->set_entryfield($citekey, 'seenname', $identifier);
  }

  # uniquetitle
  # Don't generate information for entries with no labeltitle
  if ($lti and Biber::Config->getblxoption(undef, 'uniquetitle', $bee, $citekey)) {
    $identifier = $be->get_field($lti);

    # Skip due to ignore settings?
    unless (first {fc($lti) eq fc($_)} $ignore->{uniquetitle}->@*) {
      $dlist->incr_seentitle($identifier);
    }
    $dlist->set_entryfield($citekey, 'seentitle', $identifier);
  }

  # uniquebaretitle
  # Don't generate information for entries with no labeltitle and with labelname
  if ($lti and not $lni and Biber::Config->getblxoption(undef, 'uniquebaretitle', $bee, $citekey)) {
    $identifier = $be->get_field($lti);

    # Skip due to ignore settings?
    unless (first {fc($lti) eq fc($_)} $ignore->{uniquebaretitle}->@*) {
      $dlist->incr_seenbaretitle($identifier);
    }
    $dlist->set_entryfield($citekey, 'seenbaretitle', $identifier);
  }

  # uniquework
  # Don't generate information for entries with no labelname and labeltitle
  # Should use fullhash this is not a test of uniqueness of only visible information
  if ($lni and $lti and Biber::Config->getblxoption(undef, 'uniquework', $bee, $citekey)) {
    $identifier = $self->_getfullhash($citekey, $be->get_field($lni)) . $be->get_field($lti);

    # Skip due to ignore settings?
    unless (first {fc($lni) eq fc($_)} $ignore->{uniquework}->@* and
            first {fc($lti) eq fc($_)} $ignore->{uniquework}->@*) {
      $dlist->incr_seenwork($identifier);
    }
    $dlist->set_entryfield($citekey, 'seenwork', $identifier);
  }

  return;
}

=head2 process_extradate

    Track labelname/date parts combination for generation of extradate

=cut

sub process_extradate {
  my ($self, $citekey, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');

  # Generate labelname/year combination for tracking extradate
  # * If there is no labelname to use, use empty string
  # * If there is no date information to use, try year
  # * Don't increment the seen_namedateparts count if the name string is empty
  #   (see code in incr_seen_namedateparts method).
  # * Don't increment if skiplab is set

  if (Biber::Config->getblxoption(undef, 'labeldateparts', $bee, $citekey)) {
    if (Biber::Config->getblxoption($secnum, 'skiplab', $bee, $citekey)) {
      return;
    }

    if ($logger->is_trace()) {# performance tune
      $logger->trace("Creating extradate information for '$citekey'");
    }

    my $namehash = '';
    if (my $lni = $be->get_labelname_info) {
      $namehash = $self->_getnamehash_u($citekey, $be->get_field($lni), $dlist);
    }

    my $datestring = ''; # Need a default empty string
    my $edspec = Biber::Config->getblxoption(undef, 'extradatespec');
    my $edscope;
    # Look in each scope
    foreach my $scope ($edspec->@*) {
      # Use the first field in the scope which we find and ignore the rest
      foreach my $field ($scope->@*) {
        if (defined($be->get_field($field))) {
          $datestring .= $be->get_field($field);
          $edscope = $field;
          last;
        }
      }
    }

    my $tracking_string = "$namehash,$datestring";

    $be->set_field('extradatescope', $edscope);
    $dlist->set_entryfield($citekey, 'namedateparts', $tracking_string);
    $dlist->incr_seen_namedateparts($namehash, $datestring);
  }

  return;
}

=head2 process_extraname

    Track labelname only for generation of extraname

=cut

sub process_extraname {
  my ($self, $citekey, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');

  if (Biber::Config->getblxoption($secnum, 'skiplab', $bee, $citekey)) {
    return;
  }

  if ($logger->is_trace()) {# performance tune
    $logger->trace("Creating extraname information for '$citekey'");
  }

  my $namehash;
  if (my $lni = $be->get_labelname_info) {
    $namehash = $self->_getnamehash_u($citekey, $be->get_field($lni), $dlist);
  }

  # Don't bother with extraname when there is no labelname
  if (defined($namehash)) {
    $dlist->set_entryfield($citekey, 'labelnamehash', $namehash);
    $dlist->incr_seen_labelname($namehash);
  }

  return;
}

=head2 process_extratitle

    Track labelname/labeltitle combination for generation of extratitle

=cut

sub process_extratitle {
  my ($self, $citekey, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');

  # Generate labelname/labeltitle combination for tracking extratitle
  # * If there is no labelname to use, use empty string
  # * If there is no labeltitle to use, use empty string
  # * Don't increment if skiplab is set

  # This is different from extradate in that we do track the information
  # if the labelname is empty as titles are much more unique than years

  if (Biber::Config->getblxoption(undef, 'labeltitle', $bee)) {
    if (Biber::Config->getblxoption($secnum, 'skiplab', $bee, $citekey)) {
      return;
    }

    if ($logger->is_trace()) {# performance tune
      $logger->trace("Creating extratitle information for '$citekey'");
    }

    my $namehash = '';
    if (my $lni = $be->get_labelname_info) {
      $namehash = $self->_getnamehash_u($citekey, $be->get_field($lni), $dlist);
    }

    my $lti = $be->get_labeltitle_info;
    my $title_string = $be->get_field($lti) // '';

    my $nametitle_string = "$namehash,$title_string";
    if ($logger->is_trace()) {# performance tune
      $logger->trace("Setting nametitle to '$nametitle_string' for entry '$citekey'");
    }

    $dlist->set_entryfield($citekey, 'nametitle', $nametitle_string);

    if ($logger->is_trace()) {# performance tune
      $logger->trace("Incrementing nametitle for '$namehash'");
    }
    $dlist->incr_seen_nametitle($namehash, $title_string);
  }

  return;
}

=head2 process_extratitleyear

    Track labeltitle/labelyear combination for generation of extratitleyear

=cut

sub process_extratitleyear {
  my ($self, $citekey, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');

  # Generate labeltitle/labelyear combination for tracking extratitleyear
  # * If there is no labeltitle to use, use empty string
  # * If there is no labelyear to use, use empty string
  # * Don't increment the seen_titleyear count if the labeltitle field is empty
  #   (see code in incr_seen_titleyear method).
  # * Don't increment if skiplab is set

  if (Biber::Config->getblxoption(undef, 'labeltitleyear', $bee, $citekey)) {
    if (Biber::Config->getblxoption($secnum, 'skiplab', $bee, $citekey)) {
      return;
    }

    if ($logger->is_trace()) {# performance tune
      $logger->trace("Creating extratitleyear information for '$citekey'");
    }

    my $lti = $be->get_labeltitle_info;
    my $title_string = $be->get_field($lti) // '';

    # Takes into account the labelyear which can be a range
    my $year_string = $be->get_field('labelyear') || $be->get_field('year') || '';

    my $titleyear_string = "$title_string,$year_string";
    if ($logger->is_trace()) {# performance tune
      $logger->trace("Setting titleyear to '$titleyear_string' for entry '$citekey'");
    }

    $dlist->set_entryfield($citekey, 'titleyear', $titleyear_string);

    if ($logger->is_trace()) {# performance tune
      $logger->trace("Incrementing titleyear for '$title_string'");
    }
    $dlist->incr_seen_titleyear($title_string, $year_string);
  }

  return;
}


=head2 process_sets

    Postprocess set entries

    Checks for common set errors and enforces "dataonly" options for set members.
    It's not necessary to set skipbib, skipbiblist in the OPTIONS field for
    the set members as these are automatically set by biblatex due to the \inset

=cut

sub process_sets {
  my $self = shift;
  my $citekey = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  if (my @entrysetkeys = $section->get_set_children($citekey)) {
    # Enforce Biber parts of virtual "dataonly" options for set members
    # Also automatically create an "entryset" field for the members
    foreach my $member (@entrysetkeys) {
      my $me = $section->bibentry($member);
      process_entry_options($member, [ 'skipbib', 'skiplab', 'skipbiblist', 'uniquename=false', 'uniquelist=false' ], $secnum);

      # Use get_datafield() instead of get_field() because we add 'entryset' below
      # and if the same entry is used in more than one set, it will pass this test
      # and generate an error if we use get_field()
      if ($me->get_datafield('entryset')) {
        biber_warn("Field 'entryset' is no longer needed in set member entries in Biber - ignoring in entry '$member'", $me);
        $me->del_field('entryset');
      }
      # This ends up setting \inset{} in the bbl
      $me->set_field('entryset', [ $citekey ]);
    }

    unless (@entrysetkeys) {
      biber_warn("No entryset found for entry $citekey of type 'set'", $be);
    }
  }
  # Also set this here for any non-set keys which are in a set and which haven't
  # had skips set by being seen as a member of that set yet
  else {
    if ($section->get_set_parents($citekey)) {
      process_entry_options($citekey, [ 'skipbib', 'skiplab', 'skipbiblist', 'uniquename=false', 'uniquelist=false' ], $secnum);
    }
  }
}


=head2 process_nocite

    Generate nocite information

=cut

sub process_nocite {
  my ($self, $citekey) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  # Either specifically nocited or \nocite{*} and not specifically cited without nocite
  if ($section->is_nocite($citekey) or
      ($section->is_allkeys_nocite and not $section->is_specificcitekey($citekey))) {
    $be->set_field('nocite', '1');
  }
}

=head2 process_labelname

    Generate labelname information.

=cut

sub process_labelname {
  my ($self, $citekey) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');
  my $lnamespec = Biber::Config->getblxoption(undef, 'labelnamespec', $bee);
  my $dm = Biber::Config->get_dm;
  my $dmh = Biber::Config->get_dm_helpers;

  # First we set the normal labelname name
  foreach my $h_ln ($lnamespec->@*) {
    my $lnameopt;
    my $ln = $h_ln->{content};
    if ( $ln =~ /\Ashort(\X+)\z/xms ) {
      $lnameopt = $1;
    }
    else {
      $lnameopt = $ln;
    }

    unless (first {$ln eq $_} $dmh->{namelistsall}->@*) {
      biber_warn("Labelname candidate '$ln' is not a name field - skipping");
      next;
    }

    # If there is a biblatex option which controls the use of this labelname info, check it
    if ($CONFIG_OPTSCOPE_BIBLATEX{"use$lnameopt"} and
       not Biber::Config->getblxoption($secnum, "use$lnameopt", $bee, $citekey)) {
      next;
    }

    if ($be->get_field($ln)) {
      $be->set_labelname_info($ln);
      last;
    }
  }

  # Then we loop again to set the labelname name for the fullhash generation code
  # This is because fullhash generation ignores SHORT* fields (section 4.2.4.1, BibLaTeX
  # manual)
  foreach my $h_ln ($lnamespec->@*) {
    my $ln = $h_ln->{content};
    if ( $ln =~ /\Ashort(.+)\z/xms ) {
      next;
    }

    # We have already warned about this above
    next unless (first {$ln eq $_} $dmh->{namelistsall}->@*);

    # If there is a biblatex option which controls the use of this labelname info, check it
    if ($CONFIG_OPTSCOPE_BIBLATEX{"use$ln"} and
       not Biber::Config->getblxoption($secnum, "use$ln", $bee, $citekey)) {
      next;
    }

    if ($be->get_field($ln)) {
      $be->set_labelnamefh_info($ln);
      last;
    }
  }

  unless ($be->get_labelname_info) {
    if ($logger->is_debug()) {# performance tune
      $logger->debug("Could not determine the labelname source of entry $citekey");
    }
  }
}

=head2 process_labeldate

    Generate labeldate information, including times

=cut

sub process_labeldate {
  my $self = shift;
  my $citekey = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');
  my $dm = Biber::Config->get_dm;

  if (Biber::Config->getblxoption(undef, 'labeldateparts', $bee, $citekey)) {
    my $ldatespec = Biber::Config->getblxoption(undef, 'labeldatespec', $bee);
    foreach my $lds ($ldatespec->@*) {
      my $pseudodate;
      my $ld = $lds->{content};
      if ($lds->{'type'} eq 'field') { # labeldate field

        my $ldy;
        my $ldey;
        my $ldm;
        my $ldd;
        my $ldhour;
        my $ldmin;
        my $ldsec;
        my $ldtz;
        my $datetype;

        # resolve dates
        $datetype = $ld =~ s/date\z//xmsr;
        if ($dm->field_is_datatype('date', $ld) and
            $be->get_field("${datetype}datesplit")) { # real EDTF dates
          $ldy    = $datetype . 'year';
          $ldey   = $datetype . 'endyear';
          $ldm    = $datetype . 'month';
          $ldd    = $datetype . 'day';
          $ldhour = $datetype . 'hour';
          $ldmin  = $datetype . 'minute';
          $ldsec  = $datetype . 'second';
          $ldtz   = $datetype . 'timezone';
        }
        else { # non-EDTF split date field so make a pseudo-year
          $ldy = $ld;
          $pseudodate = 1;
        }

        # Did we find a labeldate - this is equivalent to checking for a year/endyear
        # as that is always present if there is a labeldate
        if (defined($be->get_field($ldy)) or defined($be->get_field($ldey))) {
          # set source to field or date field prefix for a real date field
          $be->set_labeldate_info({'field' => {year       => $ldy,
                                               month      => $ldm,
                                               day        => $ldd,
                                               hour       => $ldhour,
                                               minute     => $ldmin,
                                               second     => $ldsec,
                                               timezone   => $ldtz,
                                               pseudodate => $pseudodate,
                                               source     => $pseudodate ? $ldy : $datetype }});
          last;
        }
      }
      elsif ($lds->{'type'} eq 'string') { # labelyear fallback string
        $be->set_labeldate_info({'string' => $ld});
        last;
      }
    }

    # Construct label*
    # Might not have been set due to skiplab
    if (my $ldi = $be->get_labeldate_info) {
      if (my $df = $ldi->{field}) { # set labelyear to a field value
        my $pseudodate = $df->{pseudodate};
        $be->set_field('labelyear', $be->get_field($df->{year}));
        $be->set_field('labelmonth', $be->get_field($df->{month})) if $df->{month};
        $be->set_field('labelday', $be->get_field($df->{day})) if $df->{day};
        $be->set_field('labelhour', $be->get_field($df->{hour})) if $df->{hour};
        $be->set_field('labelminute', $be->get_field($df->{minute})) if $df->{minute};
        $be->set_field('labelsecond', $be->get_field($df->{second})) if $df->{second};
        $be->set_field('labeltimezone', $be->get_field($df->{timezone})) if $df->{timezone};
        $be->set_field('labeldatesource', $df->{source});

        # ignore endyear if it's the same as year
        my ($ytype) = $df->{year} =~ /\A(\X*)year\z/xms;
        $ytype = $ytype // ''; # Avoid undef warnings since no match above can make it undef

        # construct labelyear from start/end year field
        if ($be->field_exists($ytype . 'endyear')
            and (($be->get_field($df->{year}) // '') ne $be->get_field($ytype . 'endyear'))) {
          $be->set_field('labelyear',
                         ($be->get_field('labelyear') // ''). '\bibdatedash ' . $be->get_field($ytype . 'endyear'));
        }
        # construct labelmonth from start/end month field
        if (not $pseudodate and
            $be->get_field($ytype . 'endmonth')
            and (($be->get_field($df->{month}) // '') ne $be->get_field($ytype . 'endmonth'))) {
          $be->set_field('labelmonth',
                         ($be->get_field('labelmonth') // '') . '\bibdatedash ' . $be->get_field($ytype . 'endmonth'));
        }
        # construct labelday from start/end month field
        if (not $pseudodate and
            $be->get_field($ytype . 'endday')
            and (($be->get_field($df->{day}) // '') ne $be->get_field($ytype . 'endday'))) {
          $be->set_field('labelday',
                         ($be->get_field('labelday') // '') . '\bibdatedash ' . $be->get_field($ytype . 'endday'));
        }
        # construct labelhour from start/end hour field
        if (not $pseudodate and
            $be->get_field($ytype . 'endhour')
            and (($be->get_field($df->{hour}) // '') ne $be->get_field($ytype . 'endhour'))) {
          $be->set_field('labelhour',
                         ($be->get_field('labelhour') // '') . '\bibdatedash ' . $be->get_field($ytype . 'endhour'));
        }
        # construct labelminute from start/end minute field
        if (not $pseudodate and
            $be->get_field($ytype . 'endminute')
            and (($be->get_field($df->{minute}) // '') ne $be->get_field($ytype . 'endminute'))) {
          $be->set_field('labelminute',
                         ($be->get_field('labelminute') // '') . '\bibdatedash ' . $be->get_field($ytype . 'endminute'));
        }
        # construct labelsecond from start/end second field
        if (not $pseudodate and
            $be->get_field($ytype . 'endsecond')
            and (($be->get_field($df->{second}) // '') ne $be->get_field($ytype . 'endsecond'))) {
          $be->set_field('labelsecond',
                         ($be->get_field('labelsecond') // '') . '\bibdatedash ' . $be->get_field($ytype . 'endsecond'));
        }
      }
      elsif (my $ys = $ldi->{string}) { # set labeldatesource to a fallback string
        $be->set_field('labeldatesource', $ys);
      }
    }
    else {
      if ($logger->is_debug()) {# performance tune
        $logger->debug("labeldate information of entry $citekey is unset");
      }
    }
  }
}

=head2 process_labeltitle

  Generate labeltitle

  Note that this is not conditionalised on the biblatex "labeltitle"
  as labeltitle should always be output since all standard styles need it.
  Only extratitle is conditionalised on the biblatex "labeltitle" option.

=cut


sub process_labeltitle {
  my $self = shift;
  my $citekey = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');

  my $ltitlespec = Biber::Config->getblxoption(undef, 'labeltitlespec', $bee);

  foreach my $h_ltn ($ltitlespec->@*) {
    my $ltn = $h_ltn->{content};
    if (my $lt = $be->get_field($ltn)) {
      $be->set_labeltitle_info($ltn);
      $be->set_field('labeltitle', $lt);
      last;
    }
    if ($logger->is_debug()) {# performance tune
      $logger->debug("labeltitle information of entry $citekey is unset");
    }
  }
}

=head2 process_fullhash

    Generate fullhash

=cut

sub process_fullhash {
  my $self = shift;
  my $citekey = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $dmh = Biber::Config->get_dm_helpers;

  # fullhash is generated from the labelname but ignores SHORT* fields and
  # max/mincitenames settings
  # This can't be resolved nicely by biblatex because it depends on use* options
  # and also SHORT* fields etc.
  if (my $lnfhi = $be->get_labelnamefh_info) {
    if (my $lnfh = $be->get_field($lnfhi)) {
      $be->set_field('fullhash', $self->_getfullhash($citekey, $lnfh));
    }
  }

  # Generate fullhash for all other name fields
  foreach my $n ($dmh->{namelistsall}->@*) {
    next unless my $nv = $be->get_field($n);
    $be->set_field("${n}fullhash", $self->_getfullhash($citekey, $nv));
  }

  return;
}

=head2 process_namehash

    Generate namehash

=cut

sub process_namehash {
  my ($self, $citekey, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $dmh = Biber::Config->get_dm_helpers;

  # namehash is generated from the labelname
  # This can't be resolved nicely by biblatex because it depends on use* options
  # and also SHORT* fields etc.
  if (my $lni = $be->get_labelname_info) {
    if (my $ln = $be->get_field($lni)) {
      $dlist->set_entryfield($citekey, 'namehash', $self->_getnamehash($citekey, $ln, $dlist));
      $dlist->set_entryfield($citekey, 'bibnamehash', $self->_getnamehash($citekey, $ln, $dlist, 1));
    }
  }

  # Generate namehash for all other name fields
  foreach my $n ($dmh->{namelistsall}->@*) {
    next unless my $nv = $be->get_field($n);
    $dlist->set_entryfield($citekey, "${n}namehash", $self->_getnamehash($citekey, $nv, $dlist));
    $dlist->set_entryfield($citekey, "${n}bibnamehash", $self->_getnamehash($citekey, $nv, $dlist, 1));
  }

  return;
}

=head2 process_pername_hashes

    Generate per_name_hashes

=cut

sub process_pername_hashes {
  my ($self, $citekey, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $dmh = Biber::Config->get_dm_helpers;

  foreach my $pn ($dmh->{namelistsall}->@*) {
    next unless my $nl = $be->get_field($pn);
    foreach my $n ($nl->names->@*) {
      my $pnhash = $self->_genpnhash($citekey, $n);
      $n->set_hash($pnhash);
      $dlist->set_namehash($nl->get_id, $n->get_id, $pnhash);
    }
  }
  return;
}

=head2 process_visible_names

    Generate the visible name information.
    This is used in various places and it is useful to have it generated in one place.

=cut

sub process_visible_names {
  my ($self, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $dmh = Biber::Config->get_dm_helpers;

  if ($logger->is_debug()) {# performance tune
    $logger->debug("Postprocessing visible names for section $secnum");
  }
  foreach my $citekey ($section->get_citekeys) {
    my $be = $section->bibentry($citekey);
    my $bee = $be->get_field('entrytype');

    my $maxcn = Biber::Config->getblxoption($secnum, 'maxcitenames', $bee, $citekey);
    my $mincn = Biber::Config->getblxoption($secnum, 'mincitenames', $bee, $citekey);
    my $maxbn = Biber::Config->getblxoption($secnum, 'maxbibnames', $bee, $citekey);
    my $minbn = Biber::Config->getblxoption($secnum, 'minbibnames', $bee, $citekey);
    my $maxsn = Biber::Config->getblxoption($secnum, 'maxsortnames', $bee, $citekey);
    my $minsn = Biber::Config->getblxoption($secnum, 'minsortnames', $bee, $citekey);
    my $maxan = Biber::Config->getblxoption($secnum, 'maxalphanames', $bee, $citekey);
    my $minan = Biber::Config->getblxoption($secnum, 'minalphanames', $bee, $citekey);

    foreach my $n ($dmh->{namelistsall}->@*) {
      next unless my $nl = $be->get_field($n);

      my $count = $nl->count_names;
      my $visible_names_cite;
      my $visible_names_bib;
      my $visible_names_sort;
      my $visible_names_alpha;

      # Cap min*names for this entry at $count. Why? Because imagine we have this:
      #
      # John Smith and Bill Jones
      #
      # and mincitenames=3. Then visibility will be set to 3 but there aren't 3 names to
      # get information from so looping over the visibility count would cause name methods
      # to operate on undef at index 3 and die
      my $l_mincn = $count < $mincn ? $count : $mincn;
      my $l_minbn = $count < $minbn ? $count : $minbn;
      my $l_minsn = $count < $minsn ? $count : $minsn;
      my $l_minan = $count < $minan ? $count : $minan;

      # If name list was truncated in bib with "and others", this means that the
      # name list has already been manually truncated to the correct visibility
      # and so the visibility is just the count of the explicit names

      # max/minalphanames doesn't care about uniquelist - labels are just labels
      if ($count > $maxan) {
        $visible_names_alpha = $l_minan;
      }
      else {
        $visible_names_alpha = $count;
      }

      # max/mincitenames
      if ($count > $maxcn) {
        # Visibility to the uniquelist point if uniquelist is requested
        # We know at this stage that if uniquelist is set, there are more than maxcitenames
        # names. We also know that uniquelist > mincitenames because it is a further
        # disambiguation on top of mincitenames so can't be less as you can't disambiguate
        # by losing information
        $visible_names_cite = $dlist->get_uniquelist($nl->get_id) // $l_mincn;
      }
      else { # visibility is simply the full list
        $visible_names_cite = $count;
      }

      # max/minbibnames
      if ($count > $maxbn) {
        # Visibility to the uniquelist point if uniquelist is requested
        # We know at this stage that if uniquelist is set, there are more than maxbibnames
        # names. We also know that uniquelist > minbibnames because it is a further
        # disambiguation on top of minbibnames so can't be less as you can't disambiguate
        # by losing information
        $visible_names_bib = $dlist->get_uniquelist($nl->get_id) // $l_minbn;
      }
      else { # visibility is simply the full list
        $visible_names_bib = $count;
      }

      # max/minsortnames
      if ($count > $maxsn) {
        # Visibility to the uniquelist point if uniquelist is requested
        # We know at this stage that if uniquelist is set, there are more than maxsortnames
        # names. We also know that uniquelist > minsortnames because it is a further
        # disambiguation on top of minsortnames so can't be less as you can't disambiguate
        # by losing information
        $visible_names_sort = $dlist->get_uniquelist($nl->get_id) // $l_minsn;
      }
      else { # visibility is simply the full list
        $visible_names_sort = $count;
      }

      if ($logger->is_trace()) { # performance shortcut
        $logger->trace("Setting visible names (cite) for key '$citekey' to '$visible_names_cite'");
        $logger->trace("Setting visible names (bib) for key '$citekey' to '$visible_names_bib'");
        $logger->trace("Setting visible names (alpha) for key '$citekey' to '$visible_names_alpha'");
      }

      # Need to set these on all name forms
      my $nlid = $be->get_field($n)->get_id;
      $dlist->set_visible_cite($nlid, $visible_names_cite);
      $dlist->set_visible_bib($nlid, $visible_names_bib);
      $dlist->set_visible_sort($nlid, $visible_names_sort);
      $dlist->set_visible_alpha($nlid, $visible_names_alpha);
    }
  }
}


=head2 process_labelalpha

    Generate the labelalpha and also the variant for sorting

=cut

sub process_labelalpha {
  my ($self, $citekey, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');
  # Don't add a label if skiplab is set for entry
  if (Biber::Config->getblxoption($secnum, 'skiplab', $bee, $citekey)) {
    return;
  }
  if ( my $la = Biber::Config->getblxoption(undef, 'labelalpha', $bee, $citekey) ) {
    my ($label, $sortlabel) = $self->_genlabel($citekey, $dlist)->@*;
    $dlist->set_entryfield($citekey, 'labelalpha', $label);
    $dlist->set_entryfield($citekey, 'sortlabelalpha', $sortlabel);
  }
}

=head2 process_extraalpha

    Generate the extraalpha information

=cut

sub process_extraalpha {
  my ($self, $citekey, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');
  if (Biber::Config->getblxoption(undef, 'labelalpha', $bee, $citekey)) {
    if (my $la = $dlist->get_entryfield($citekey, 'labelalpha')) {
      $dlist->incr_la_disambiguation($la);
    }
  }
}



=head2 process_presort

    Put presort fields for an entry into the main Biber bltx state
    so that it is all available in the same place since this can be
    set per-type and globally too.

=cut

sub process_presort {
  my $self = shift;
  my $citekey = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  # We are treating presort as an option as it can be set per-type and globally too
  if (my $ps = $be->get_field('presort')) {
    Biber::Config->setblxoption($secnum, 'presort', $ps, 'ENTRY', $citekey);
  }
}


=head2 process_lists

    Process a bibliography list

=cut

sub process_lists {
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);

  foreach my $list ($self->datalists->get_lists_for_section($secnum)->@*) {
    my $lattrs = $list->get_attrs;
    my $ltype = $list->get_type;
    my $lname = $list->get_name;

    # sanitise state - essential in tests which call Biber::prepare() multiple times
    $list->reset_state;

    # Last-ditch fallback in case we still don't have a sorting spec
    $list->set_sortingnamekeytemplatename('global') unless $list->get_sortingnamekeytemplatename;
    $list->set_uniquenametemplatename('global') unless $list->get_uniquenametemplatename;
    $list->set_labelalphanametemplatename('global') unless $list->get_labelalphanametemplatename;
    $list->set_keys([ $section->get_citekeys ]);
    if ($logger->is_debug()) {  # performance tune
      $logger->debug("Populated datalist '$lname' of type '$ltype' with attributes '$lattrs' in section $secnum with keys: " . join(', ', $list->get_keys->@*));
    }

    # A datalist represents a biblatex refcontext
    # and many things are refcontext specific and so we need to use the right data. For
    # example labelalphanametemplate and uniquenametemplate can be set per-list and much
    # processing uses these

    unless (Biber::Config->getoption('tool')) {

      # Set this so that uniqueness processing starts
      $list->set_unul_changed(1);

      # Main processing loop, part 1
      $self->process_entries_pre($list);

      # Generate uniqueness information
      $self->uniqueness($list);
    }

    # Generate visible names information for all entries
    $self->process_visible_names($list);

    unless (Biber::Config->getoption('tool')) {
      # Main processing loop, part 2
      $self->process_entries_post($list);

      # Final processing loop
      $self->process_entries_final($list);
    }

    # Filtering - must come before sorting/labelling so that there are no gaps in e.g. extradate
    if (my $filters = $list->get_filters) {
      my $flist = [];
    KEYLOOP: foreach my $k ($list->get_keys->@*) {

        my $be = $section->bibentry($k);
        foreach my $f ($filters->@*) {
          # Filter disjunction is ok if any of the checks are ok, hence the grep()
          if (ref $f eq 'ARRAY') {
            next KEYLOOP unless grep {check_list_filter($k, $_->{type}, $_->{value}, $be)} $f->@*;
          }
          else {
            next KEYLOOP unless check_list_filter($k, $f->{type}, $f->{value}, $be);
          }
        }
        push $flist->@*, $k;
      }
      if ($logger->is_debug()) { # performance tune
        $logger->debug("Keys after filtering list '$lname' in section $secnum: " . join(', ', $flist->@*));
      }
      $list->set_keys($flist); # Now save the sorted list in the list object
    }

    # Sorting
    $self->generate_sortdataschema($list); # generate the sort schema information
    $self->generate_sortinfo($list);       # generate the sort information
    $self->sort_list($list);               # sort the list
    $self->generate_contextdata($list) unless Biber::Config->getoption('tool');

  }
  return;
}


=head2 check_list_filter

    Run an entry through a list filter. Returns a boolean.

=cut

sub check_list_filter {
  my ($k, $t, $fs, $be) = @_;
  if ($logger->is_debug()) {# performance tune
    $logger->debug("Checking key '$k' against filter '$t=$fs'");
  }
  if ($t eq 'type') {
    if ($be->get_field('entrytype') eq lc($fs)) {
      if ($logger->is_trace()) {# performance tune
        $logger->trace("Key '$k' passes against filter '$t=$fs'");
      }
    }
    else {
      return 0;
    }
  }
  elsif ($t eq 'nottype') {
    if ($be->get_field('entrytype') eq lc($fs)) {
      return 0;
    }
    else {
      if ($logger->is_trace()) {# performance tune
        $logger->trace("Key '$k' passes against filter '$t=$fs'");
      }
    }
  }
  elsif ($t eq 'subtype') {
    if ($be->field_exists('entrysubtype') and
        $be->get_field('entrysubtype') eq lc($fs)) {
      if ($logger->is_trace()) {# performance tune
        $logger->trace("Key '$k' passes against filter '$t=$fs'");
      }
    }
    else {
      return 0;
    }
  }
  elsif ($t eq 'notsubtype') {
    if ($be->field_exists('entrysubtype') and
        $be->get_field('entrysubtype') eq lc($fs)) {
      return 0;
    }
    else {
      if ($logger->is_trace()) {# performance tune
        $logger->trace("Key '$k' passes against filter '$t=$fs'");
      }
    }
  }
  elsif ($t eq 'keyword') {
    if ($be->has_keyword($fs)) {
      if ($logger->is_trace()) {# performance tune
        $logger->trace("Key '$k' passes against filter '$t=$fs'");
      }
    }
    else {
      return 0;
    }
  }
  elsif ($t eq 'notkeyword') {
    if ($be->has_keyword($fs)) {
      return 0;
    }
    else {
      if ($logger->is_trace()) {# performance tune
        $logger->trace("Key '$k' passes against filter '$t=$fs'");
      }
    }
  }
  elsif ($t eq 'field') {
    if ($be->field_exists($fs)) {
      if ($logger->is_trace()) {# performance tune
        $logger->trace("Key '$k' passes against filter '$t=$fs'");
      }
    }
    else {
      return 0;
    }
  }
  elsif ($t eq 'notfield') {
    if ($be->field_exists($fs)) {
      return 0;
    }
    else {
      if ($logger->is_trace()) {# performance tune
        $logger->trace("Key '$k' passes against filter '$t=$fs'");
      }
    }
  }
  return 1;
}

=head2 generate_sortdataschema

    Generate sort data schema for Sort::Key from sort spec like this:

  spec   => [
              [undef, { presort => {} }],
              [{ final => 1 }, { sortkey => {} }],
              [
                {'sort_direction'  => 'descending'},
                { sortname => {} },
                { author => {} },
                { editor => {} },
                { translator => {} },
                { sorttitle => {} },
                { title => {} },
              ],
              [undef, { sortyear => {} }, { year => {} }],
              [undef, { sorttitle => {} }, { title => {} }],
              [undef, { volume => {} }, { "0000" => {} }],
            ],


=cut

sub generate_sortdataschema {
  my ($self, $list) = @_;
  my $dm = Biber::Config->get_dm;
  my $ds;
  my $schema;

  # Check if sorting templatename for the list contains anything ...
  if (keys Biber::Config->getblxoption(undef, 'sortingtemplate')->{$list->get_sortingtemplatename}->%*) {
    $schema = Biber::Config->getblxoption(undef, 'sortingtemplate')->{$list->get_sortingtemplatename};
  }
  else {
    # ... fall back to global default if named template does not exist
    $schema = Biber::Config->getblxoption(undef, 'sortingtemplate')->{Biber::Config->getblxoption(undef, 'sortingtemplatename')};
  }

  $list->set_sortingtemplate($schema); # link the sort schema into the list

  foreach my $sort ($schema->{spec}->@*) {
    # Assume here that every item in a sorting spec section is the same datatype
    # See header for data structure
    my $direction = '';
    while (my ($sopt, $val) = each $sort->[0]->%*) {
      if ($sopt eq 'sort_direction') {
        if ($val eq 'descending') {
          $direction = '-';
        }
      }
    }
    my $spec = $dm->{sortdataschema}->([keys $sort->[1]->%*]->[0]);
    push $ds->@*, {spec  => "$direction$spec",
                   $spec => 1}; # Speed shortcut for sortkey extraction sub

  }
  $list->set_sortdataschema($ds);
  return;
}

=head2 generate_sortinfo

    Generate information for sorting

=cut

sub generate_sortinfo {
  my ($self, $dlist) = @_;

  foreach my $key ($dlist->get_keys->@*) {
    $self->_generatesortinfo($key, $dlist);
  }
  return;
}

=head2 uniqueness

    Generate the uniqueness information needed when creating .bbl

=cut

sub uniqueness {
  my ($self, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  # Generate uniqueness information according to this algorithm:
  # 1. Generate uniquename if uniquename option is set
  # 2. if (uniquelist has never run before OR step 1 changed any uniquename values) {
  #      goto step 3
  #    } else { return }
  # 3. Completely regenerate uniquelist if uniquelist option is set
  # 4. if (step 3 changed any uniquelist values) {
  #      goto step 1
  #    } else { return }

  # uniquelist can never shorten to a list shorter than maxcitenames because:
  # * Shortening a list can't make it unique
  # * You can't lengthen it if the list is shorter than maxcitenames because there
  #   is no more information to add that you don't already have.
  # uniquelist cannot be less than mincitenames as the list is either unambiguous
  # at mincitenames or it isn't and uniquelist needs more information by adding items

  # Set a flag for first uniquelist pass. This is a special case as we always want to run
  # at least one uniquelist pass if requested, regardless of unul_done global flag.
  my $first_ul_pass = 1;

  # Generate uniquename information, if requested
  while ('true') {
    unless ($dlist->get_unul_done) {
      if ($logger->is_debug()) {# performance tune
        $logger->debug("Entering uniquename processing");
      }
      $dlist->set_unul_changed(0); # reset state for global unul changed flag
      $self->create_uniquename_info($dlist);
      $self->generate_uniquename($dlist);
    }
    else {
      last; # uniquename/uniquelist disambiguation is finished as nothing changed
    }
    # Generate uniquelist information, if requested
    # Always run uniquelist at least once, if requested
    if ($first_ul_pass or not $dlist->get_unul_done) {
      if ($logger->is_debug()) {# performance tune
        $logger->debug("Entering uniquelist processing");
      }
      $dlist->set_unul_changed(0); # reset state for global unul changed flag
      $first_ul_pass = 0; # Ignore special case when uniquelist has run once
      $self->create_uniquelist_info($dlist);
      $self->generate_uniquelist($dlist);
    }
    else {
      last; # uniquename/uniquelist disambiguation is finished as nothing changed
    }
  }
  return;
}


=head2 create_uniquename_info

    Gather the uniquename information as we look through the names

    What is happening in here is the following: We are registering the
    number of occurrences of each name, name+init and fullname within a
    specific context. For example, the context is "global" with uniquename
    < mininit and "name list" for uniquename=mininit or minfull. The keys
    we store to count this are the most specific information for the
    context, so, for uniquename < mininit, this is the full name and for
    uniquename=mininit or minfull, this is the complete list of full names.
    These keys have values in a hash which are ignored. They serve only to
    accumulate repeated occurrences with the context and we don't care
    about this and so the values are a useful sinkhole for such repetition.

    For example, if we find in the global context a base name "Smith" in two different entries
    under the same form "Alan Smith", the data structure will look like:

    {Smith}->{global}->{Alan Smith} = 2

    We don't care about the value as this means that there are 2 "Alan Smith"s in the global
    context which need disambiguating identically anyway. So, we just count the keys for the
    base name "Smith" in the global context to see how ambiguous the base name itself is. This
    would be "1" and so "Alan Smith" would get uniquename=false because it's unambiguous as just
    "Smith".

    The same goes for "minimal" list context disambiguation for uniquename=mininit or minfull.
    For example, if we had the base name "Smith" to disambiguate in two entries with labelname
    "John Smith and Alan Jones", the data structure would look like:

    {Smith}->{Smith+Jones}->{John Smith+Alan Jones} = 2

    Again, counting the keys of the context for the base name gives us "1" which means we
    have uniquename=false for "John Smith" in both entries because it's the same list. This also
    works for repeated names in the same list "John Smith and Bert Smith". Disambiguating
    "Smith" in this:

    {Smith}->{Smith+Smith}->{John Smith+Bert Smith} = 2

    So both "John Smith" and "Bert Smith" in this entry get
    uniquename=false (of course, as long as there are no other "X Smith and
    Y Smith" entries where X != "John" or Y != "Bert").

    The values from biblatex.sty:

    false   = 0
    init    = 1
    true    = 2
    full    = 2
    allinit = 3
    allfull = 4
    mininit = 5
    minfull = 6

=cut

sub create_uniquename_info {
  my ($self, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bibentries;

  # Reset uniquename information as we have to generate it
  # again because uniquelist information might have changed
  $dlist->reset_uniquenamecount;

  MAIN: foreach my $citekey ( $section->get_citekeys ) {
    my $be = $bibentries->entry($citekey);
    my $bee = $be->get_field('entrytype');
    my $lni = $be->get_labelname_info;

    next unless defined($lni); # only care about labelname

    my $nl = $be->get_field($lni);
    my $nlid = $nl->get_id;

    my $un = Biber::Config->getblxoption($secnum, 'uniquename', $bee, $citekey);

    # Per-namelist uniquename
    if (defined($nl->get_uniquename)) {
      $un = $nl->get_uniquename;
    }

    if ($logger->is_trace()) {# performance tune
      $logger->trace("Generating uniquename information for '$citekey'");
    }

    # Set the index limit beyond which we don't look for disambiguating information
    my $ul = undef;             # Not set
    if (defined($dlist->get_uniquelist($nlid))) {
      # If defined, $ul will always be >1, see comment in set_uniquelist() in Names.pm
      $ul = $dlist->get_uniquelist($nlid);
    }
    my $maxcn = Biber::Config->getblxoption($secnum, 'maxcitenames', $bee, $citekey);
    my $mincn = Biber::Config->getblxoption($secnum, 'mincitenames', $bee, $citekey);

    # Note that we don't determine if a name is unique here -
    # we can't, were still processing entries at this point.
    # Here we are just recording seen combinations of the basename plus
    # non-basename parts in both initial and full formats.
    #
    # A name scope can be either a complete single name or a list of names
    # depending on whether uniquename=min* or not
    #
    # Anything which has more than one combination for a given basename+non-basenameparts
    # would be uniquename = 2 unless even the full name doesn't disambiguate
    # and then it is left at uniquename = 0

    my $num_names = $nl->count_names;
    my $names = $nl->names;

    # If name list was truncated in bib with "and others", this overrides maxcitenames
    my $morenames = $nl->get_morenames ? 1 : 0;

    my %truncnames;
    my @basenames;
    my @allnames;

    foreach my $n ($names->@*) {
      my $nid = $n->get_id;

      # Per-name uniquename
      if (defined($n->get_uniquename)) {
        $un = $n->get_uniquename;
      }

      next MAIN if $un eq 'false';

      # We need to track two types of uniquename disambiguation here:
      #
      # 1. Information to disambiguate visible names from visible names
      #    where "visibility" is governed by uniquelist/max/mincitenames.
      #    This is the actual "uniquename" feature information.
      # 2. Information to disambiguate all names, regardless of visibility
      #    This is needed for uniquelist because it needs to construct
      #    hypothetical ambiguity information for every list position.

      # We want to record disambiguation information for visible names when:
      # uniquename = allinit or allfull
      # Uniquelist is set and a name appears before the uniquelist truncation
      # Uniquelist is not set and the entry has an explicit "and others" at the end
      #   since this means that every name is less than maxcitenames by definition
      # Uniquelist is not set and a name list is shorter than the maxcitenames truncation
      # Uniquelist is not set, a name list is longer than the maxcitenames truncation
      #   and the name appears before the mincitenames truncation

      if ($un eq 'allinit' or $un eq 'allfull' or
          ($ul and $n->get_index <= $ul) or
          $morenames or
          $num_names <= $maxcn or
          $n->get_index <= $mincn) { # implicitly, $num_names > $maxcn here

        $truncnames{$nid} = 1;
        if ($un eq 'mininit' or $un eq 'minfull') {
          push @basenames, $dlist->get_basenamestring($nlid, $nid);
          push @allnames, $dlist->get_namestring($nlid, $nid);
        }
      }
    }
    # Information for mininit or minfull, here the basename
    # and non-basename is all names in the namelist, not just the current name
    my $min_basename;
    my $min_namestring;
    if ($un eq 'mininit' or $un eq 'minfull') {
      $min_basename = join("\x{10FFFD}", @basenames);
      $min_namestring = join("\x{10FFFD}", @allnames);
      if ($#basenames + 1 < $num_names or $morenames) {
        $min_basename .= "\x{10FFFD}et al";     # if truncated, record this
        $min_namestring .= "\x{10FFFD}et al";   # if truncated, record this
      }
    }

    foreach my $n ($names->@*) {
      my $nid = $n->get_id;
      my $basename    = $dlist->get_basenamestring($nlid, $nid);
      my $namestring  = $dlist->get_namestring($nlid, $nid);
      my $namestrings = $dlist->get_namestrings($nlid, $nid);
      my $namedisamiguationscope;
      my $nskey;

      # Disambiguation scope and key depend on the uniquename setting
      if ($un eq 'init' or $un eq 'full' or $un eq 'allinit' or $un eq 'allfull') {
        $namedisamiguationscope = 'global';
        $nskey = join("\x{10FFFD}", $namestrings->@*);
      }
      elsif ($un eq 'mininit' or $un eq 'minfull') {
        $namedisamiguationscope = $min_basename;
        $nskey = $min_namestring;
        $dlist->set_unmininfo($nlid, $nid, $min_basename);
      }

      if ($truncnames{$nid}) {
        # Record uniqueness information entry for all name contexts
        # showing that they have been seen for this name key in this name scope
        foreach my $ns ($namestrings->@*) {
          $dlist->add_uniquenamecount($ns, $namedisamiguationscope, $nskey);
        }
      }

      # As above but here we are collecting (separate) information for all
      # names, regardless of visibility (needed to track uniquelist)
      my $eul = Biber::Config->getblxoption($secnum, 'uniquelist', $bee, $citekey);

      # Per-namelist uniquelist
      my $nl = $be->get_field($lni);
      if (defined($lni) and $nl->get_uniquelist) {
        $eul = $nl->get_uniquelist;
      }

      if ($eul ne 'false') {
        foreach my $ns ($namestrings->@*) {
          $dlist->add_uniquenamecount_all($ns, $namedisamiguationscope, $nskey);
        }
      }
    }
  }

  return;
}

=head2 generate_uniquename

   Generate the per-name uniquename values using the information
   harvested by create_uniquename_info()

=cut

sub generate_uniquename {
  my ($self, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bibentries;

  # Now use the information to set the actual uniquename information
MAIN:  foreach my $citekey ( $section->get_citekeys ) {
    my $be = $bibentries->entry($citekey);
    my $bee = $be->get_field('entrytype');
    my $lni = $be->get_labelname_info;
    next unless defined($lni); # only care about labelname

    my $nl = $be->get_field($lni);
    my $nlid = $nl->get_id;

    my $un = Biber::Config->getblxoption($secnum, 'uniquename', $bee, $citekey);

    # Per-namelist uniquename
    if (defined($nl->get_uniquename)) {
      $un = $nl->get_uniquename;
    }

    if ($logger->is_trace()) {# performance tune
      $logger->trace("Setting uniquename for '$citekey'");
    }

    # Set the index limit beyond which we don't look for disambiguating information
    # If defined, $ul will always be >1, see comment in set_uniquelist() in Names.pm
    my $ul = $dlist->get_uniquelist($nlid);

    my $maxcn = Biber::Config->getblxoption($secnum, 'maxcitenames', $bee, $citekey);
    my $mincn = Biber::Config->getblxoption($secnum, 'mincitenames', $bee, $citekey);

    my $num_names = $nl->count_names;
    my $names = $nl->names;
    # If name list was truncated in bib with "and others", this overrides maxcitenames
    my $morenames = ($nl->get_morenames) ? 1 : 0;

    my %truncnames;

    foreach my $n ($names->@*) {
      my $nid = $n->get_id;

      # Per-name uniquename
      if (defined($n->get_uniquename)) {
        $un = $n->get_uniquename;
      }

      next MAIN if $un eq 'false';

      if ($un eq 'allinit' or $un eq 'allfull' or
          ($ul and $n->get_index <= $ul) or
          $morenames or
          $num_names <= $maxcn or
          $n->get_index <= $mincn) { # implicitly, $num_names > $maxcn here
        $truncnames{$nid} = 1;
      }
      else {
        # Set anything now not visible due to uniquelist back to 0
        $dlist->reset_uniquename($nlid, $nid);
      }
    }

    foreach my $n ($names->@*) {
      my $nid = $n->get_id;
      my $basename = $dlist->get_basenamestring($nlid, $nid);
      my $namestrings = $dlist->get_namestrings($nlid, $nid);
      my $namedisschema = $dlist->get_namedisschema($nlid, $nid);
      my $namescope = 'global'; # default

      if ($un eq 'mininit' or $un eq 'minfull') {
        $namescope = $dlist->get_unmininfo($nlid, $nid);
      }

      if ($truncnames{$nid}) {
        for (my $i=0; $i<=$namestrings->$#*; $i++) {
          my $ns = $namestrings->[$i];
          my $nss = $namedisschema->[$i];
          if ($dlist->get_numofuniquenames($ns, $namescope) == 1) {
            $dlist->set_uniquename($nlid, $nid, $nss);
            # We have found the most general disambiguation schema which disambiguates,
            # skip the rest since the schema array goes from most general to least general
            last;
          }
        }
        # Nothing disambiguates, set to just base of schema
        $dlist->set_uniquename($nlid, $nid, $namedisschema->[0])
          unless defined($dlist->get_uniquename($nlid, $nid));
      }

      my $eul = Biber::Config->getblxoption($secnum, 'uniquelist', $bee, $citekey);
      # Per-namelist uniquelist
      my $names = $be->get_field($be->get_labelname_info);
      if (defined($names->get_uniquelist)) {
        $eul = $names->get_uniquelist;
      }

      # As above but not just for visible names (needed for uniquelist)
      if ($eul ne 'false') {
        for (my $i=0; $i<=$namestrings->$#*; $i++) {
          my $ns = $namestrings->[$i];
          my $nss = $namedisschema->[$i];
          if ($dlist->get_numofuniquenames_all($ns, $namescope) == 1) {
            $dlist->set_uniquename_all($nlid, $nid, $nss);
            # We have found the most general disambiguation schema which disambiguates,
            # skip the rest since the schema array goes from most general to least general
            last;
          }
        }
        # Nothing disambiguates, set to just base of schema
        $dlist->set_uniquename_all($nlid, $nid, $namedisschema->[0])
          unless defined($dlist->get_uniquename_all($nlid, $nid));
      }
    }
  }
  return;
}

=head2 create_uniquelist_info

    Gather the uniquelist information as we look through the names

=cut

sub create_uniquelist_info {
  my ($self, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bibentries;

  # Reset uniquelist information as we have to generate it again because uniquename
  # information might have changed
  $dlist->reset_uniquelistcount;

  foreach my $citekey ($section->get_citekeys) {
    my $be = $bibentries->entry($citekey);
    my $bee = $be->get_field('entrytype');
    my $maxcn = Biber::Config->getblxoption($secnum, 'maxcitenames', $bee, $citekey);
    my $mincn = Biber::Config->getblxoption($secnum, 'mincitenames', $bee, $citekey);
    my $lni = $be->get_labelname_info;
    next unless defined($lni); # only care about labelname
    my $nl = $be->get_field($lni);
    my $nlid = $nl->get_id;

    my $ul = Biber::Config->getblxoption($secnum, 'uniquelist', $bee, $citekey);

    # Per-namelist uniquelist
    if (defined($nl->get_uniquelist)) {
      $ul = $nl->get_uniquelist;
    }

    next if $ul eq 'false';

    if ($logger->is_trace()) {# performance tune
      $logger->trace("Generating uniquelist information for '$citekey'");
    }

    my $num_names = $nl->count_names;
    my $namelist = [];
    my $ulminyear_namelist = [];

    foreach my $n ($nl->names->@*) {
      my $nid = $n->get_id;
      my $basename = $dlist->get_basenamestring($nlid, $nid);
      my $namestrings = $dlist->get_namestrings($nlid, $nid);
      my $namedisschema = $dlist->get_namedisschema($nlid, $nid);
      my $ulminyearflag = 0;

      # uniquelist = minyear
      if ($ul eq 'minyear') {
        # minyear uniquename, we set based on the max/mincitenames list
        if ($num_names > $maxcn and
            $n->get_index <= $mincn) {
          $ulminyearflag = 1;
        }
      }

      my $unall = $dlist->get_uniquename_all($nlid, $nid);

      # uniquename is not set so generate uniquelist based on just base name
      if (not defined($unall) or $unall->[0] eq 'base') {
        push $namelist->@*, $basename if defined($basename);
        push $ulminyear_namelist->@*, $basename if $ulminyearflag;
      }
      else {
        for (my $i=0; $i<=$namedisschema->$#*; $i++) {
          my $nss = $namedisschema->[$i];
          if (Compare($nss, $unall)) {
            push $namelist->@*, $namestrings->[$i] if defined($namestrings->[$i]);
            push $ulminyear_namelist->@*, $namestrings->[$i] if $ulminyearflag;
          }
        }
      }

      $dlist->add_uniquelistcount($namelist);
    }
    # We need to know the list uniqueness counts for the whole list seperately otherwise
    # we will falsely "disambiguate" identical name lists from each other by setting
    # uniquelist to the full list because every part of each list will have more than
    # one count. We therefore need to distinguish counts which are of the final, complete
    # list of names. If there is more than one count for these, (meaning that there are
    # two or more identical name lists), we don't expand them at all as there is no point.
    $dlist->add_uniquelistcount_final($namelist);

    # Add count for uniquelist=minyear
    unless (Compare($ulminyear_namelist, [])) {
      $dlist->add_uniquelistcount_minyear($ulminyear_namelist,
                                          $be->get_field('labelyear'),
                                          $namelist);
    }
  }
  return;
}


=head2 generate_uniquelist

   Generate the per-namelist uniquelist values using the information
   harvested by create_uniquelist_info()

=cut

sub generate_uniquelist {
  my ($self, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bibentries;

 MAIN: foreach my $citekey ( $section->get_citekeys ) {
    my $be = $bibentries->entry($citekey);
    my $bee = $be->get_field('entrytype');
    my $maxcn = Biber::Config->getblxoption($secnum, 'maxcitenames', $bee, $citekey);
    my $mincn = Biber::Config->getblxoption($secnum, 'mincitenames', $bee, $citekey);
    my $lni = $be->get_labelname_info;
    next unless defined($lni); # only care about labelname
    my $nl = $be->get_field($lni);
    my $nlid = $nl->get_id;

    my $ul = Biber::Config->getblxoption($secnum, 'uniquelist', $bee, $citekey);
    # Per-namelist uniquelist
    if (defined($nl->get_uniquelist)) {
      $ul = $nl->get_uniquelist;
    }

    next if $ul eq 'false';

    if ($logger->is_trace()) {# performance tune
      $logger->trace("Creating uniquelist for '$citekey'");
    }

    my $namelist = [];
    my $num_names = $nl->count_names;

    foreach my $n ($nl->names->@*) {
      my $nid = $n->get_id;
      my $basename = $dlist->get_basenamestring($nlid, $nid);
      my $namestrings = $dlist->get_namestrings($nlid, $nid);
      my $namedisschema = $dlist->get_namedisschema($nlid, $nid);

      my $unall = $dlist->get_uniquename_all($nlid, $nid);

      # uniquename is not set so generate uniquelist based on just base name
      if (not defined($unall) or $unall->[0] eq 'base') {
        push $namelist->@*, $basename if defined($basename);
      }
      else {
        for (my $i=0; $i<=$namedisschema->$#*; $i++) {
          my $nss = $namedisschema->[$i];
          if (Compare($nss, $unall)) {
            push $namelist->@*, $namestrings->[$i] if defined($namestrings->[$i]);
          }
        }
      }

      # With uniquelist=minyear, uniquelist should not be set at all if there are
      # no other entries with the same max/mincitenames visible list and different years
      # to disambiguate from
      if ($ul eq 'minyear' and
          $num_names > $maxcn and
          $n->get_index <= $mincn and
          $dlist->get_uniquelistcount_minyear($namelist, $be->get_field('labelyear')) == 1) {
        if ($logger->is_trace()) { # performance tune
          $logger->trace("Not setting uniquelist=minyear for '$citekey'");
        }
        next MAIN;
      }

      # list is unique after this many names so we set uniquelist to this point
      # Even if uniquelist=minyear, we record normal uniquelist information if
      # we didn't skip this key in the test above
      if ($dlist->get_uniquelistcount($namelist) == 1) {
        last;
      }
    }

    if ($logger->is_trace()) {  # performance tune
      $logger->trace("Setting uniquelist for '$citekey' using " . join(',', $namelist->@*));
    }
    $dlist->set_uniquelist($nl, $namelist, $maxcn, $mincn);
  }
  return;
}


=head2 generate_contextdata

    Generate information for data which may changes per datalist

=cut

sub generate_contextdata {
  my ($self, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $dmh = Biber::Config->get_dm_helpers;

  # This loop critically depends on the order of the citekeys which
  # is why we have to do sorting before this
  foreach my $key ($dlist->get_keys->@*) {
    my $be = $section->bibentry($key);
    my $bee = $be->get_field('entrytype');
    my $lni = $be->get_labelname_info;

    # Sort any set members according to the list sorting order of the keys.
    # This gets the indices of the set elements in the sorted datalist, sorts
    # them numerically and then extracts the actual citekeys to make a new
    # entryset field value which we store in the list metadata until output time.
    if ($be->get_field('entrytype') eq 'set') {
      my @es;
      if (Biber::Config->getblxoption(undef, 'sortsets')) {
        my $setkeys = $be->get_field('entryset');
        my $keys = $dlist->get_keys;
        my @sorted_setkeys;
        # Generate array of indices of set members in the main sorted datalist
        foreach my $elem ($setkeys->@*) {
          push @sorted_setkeys, first_index {$elem eq $_} $keys->@*;
        }
        # Sort the indices numerically (sorting has already been done so this is fine)
        # then get the actual citekeys using an array slice on the main sorted list
        @es = $keys->@[sort {$a <=> $b} @sorted_setkeys];
      }
      else {
        @es = $be->get_field('entryset')->@* if $be->get_field('entryset');
      }
      $dlist->set_entryfield($key, 'entryset', \@es);
    }

    # Only generate extra* information if skiplab is not set.
    # Don't forget that skiplab is implied for set members
    unless (Biber::Config->getblxoption($secnum, 'skiplab', $bee, $key)) {
      # extraname
      if (my $labelnamehash = $dlist->get_entryfield($key, 'labelnamehash')) {
        if ($dlist->get_seen_labelname($labelnamehash) > 1) {
          my $v = $dlist->incr_seen_extraname($labelnamehash);
          $dlist->set_extranamedata_for_key($key, $v);
        }
      }
      # extradate
      if (Biber::Config->getblxoption(undef, 'labeldateparts', $bee, $key)) {
        my $namedateparts = $dlist->get_entryfield($key, 'namedateparts');
        if ($dlist->get_seen_namedateparts($namedateparts) > 1) {
          if ($logger->is_trace()) {# performance tune
            $logger->trace("namedateparts for '$namedateparts': " . $dlist->get_seen_namedateparts($namedateparts));
          }
          my $v = $dlist->incr_seen_extradate($namedateparts);
          $dlist->set_extradatedata_for_key($key, $v);
        }
      }
      # extratitle
      if (Biber::Config->getblxoption(undef, 'labeltitle', $bee, $key)) {
        my $nametitle = $dlist->get_entryfield($key, 'nametitle');
        if ($dlist->get_seen_nametitle($nametitle) > 1) {
          if ($logger->is_trace()) {# performance tune
            $logger->trace("nametitle for '$nametitle': " . $dlist->get_seen_nametitle($nametitle));
          }
          my $v = $dlist->incr_seen_extratitle($nametitle);
          $dlist->set_extratitledata_for_key($key, $v);
        }
      }
      # extratitleyear
      if (Biber::Config->getblxoption(undef, 'labeltitleyear', $bee, $key)) {
        my $titleyear = $dlist->get_entryfield($key, 'titleyear');
        if ($dlist->get_seen_titleyear($titleyear) > 1) {
          if ($logger->is_trace()) {# performance tune
            $logger->trace("titleyear for '$titleyear': " . $dlist->get_seen_titleyear($titleyear));
          }
          my $v = $dlist->incr_seen_extratitleyear($titleyear);
          $dlist->set_extratitleyeardata_for_key($key, $v);
        }
      }

      # labelalpha
      # This works because labelalpha field is regenerated per-list
      if (Biber::Config->getblxoption(undef, 'labelalpha', $bee, $key)) {
        $dlist->set_labelalphadata_for_key($key, $dlist->get_entryfield($key, 'labelalpha'));
      }
      # extraalpha
      if (Biber::Config->getblxoption(undef, 'labelalpha', $bee, $key)) {
        my $la = $dlist->get_entryfield($key, 'labelalpha');
        if ($dlist->get_la_disambiguation($la) > 1) {
          if ($logger->is_trace()) {# performance tune
            $logger->trace("labelalpha disambiguation for '$la': " . $dlist->get_la_disambiguation($la));
          }
          my $v = $dlist->incr_seen_extraalpha($la);
          $dlist->set_extraalphadata_for_key($key, $v);
        }
      }
    }

    # uniquename
    foreach my $namefield ($dmh->{namelists}->@*) {
      if (my $nl = $be->get_field($namefield)) {
        my $nlid = $nl->get_id;
        next unless (defined($lni) and $lni eq $namefield); # labelname only
        foreach my $n ($nl->names->@*) {
          my $nid = $n->get_id;
          next unless my $uniquename = $dlist->get_uniquename($nlid, $nid);
          my $namedisschema = $dlist->get_namedisschema($nlid, $nid);

          # Construct per-namepart uniquename value
          my %pnun;
          for (my $i=0; $i<=$namedisschema->$#*; $i++) {
            my $nss = $namedisschema->[$i];
            if (Compare($uniquename, $nss)) {
              # Find where uniqueness is established, determine un settings up to this point
              my @dis = grep {$_->[0] ne 'base' and $_->[1] ne 'full'} $namedisschema->@[1..$i-1];
              push @dis, $namedisschema->@[$i];
              # normalise 'fullonly' to 'full' now that we have stripped all non-disambiguating elements
              %pnun = map {$_->[0] => ($_->[1] eq 'fullonly' ? 'full' : $_->[1])} @dis;
              last;
            }
          }
          foreach my $np ($n->get_nameparts) {
            my $npun = $UNIQUENAME_VALUES{$pnun{$np} // 'none'};
            $npun //= 0;
            $dlist->set_unparts($nlid, $nid, $np, $npun);
          }
        }
      }
    }
  }
  return;
}

=head2 generate_singletitle

    Generate the singletitle field, if requested. The information for generating
    this is gathered in process_workuniqueness()

=cut

sub generate_singletitle {
  my ($self, $citekey, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bibentries;
  my $be = $bibentries->entry($citekey);
  my $bee = $be->get_field('entrytype');

  if (Biber::Config->getblxoption(undef, 'singletitle', $bee, $citekey)) {
    my $sn = $dlist->get_entryfield($citekey, 'seenname');
    if (defined($sn) and $dlist->get_seenname($sn) < 2 ) {
      $dlist->set_entryfield($citekey, 'singletitle', 1);
    }
  }
  return;
}

=head2 generate_uniquetitle

    Generate the uniquetitle field, if requested. The information for generating
    this is gathered in process_workuniqueness()

=cut

sub generate_uniquetitle {
  my ($self, $citekey, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bibentries;
  my $be = $bibentries->entry($citekey);
  my $bee = $be->get_field('entrytype');

  if (Biber::Config->getblxoption(undef, 'uniquetitle', $bee, $citekey)) {
    my $ut = $dlist->get_entryfield($citekey, 'seentitle');
    if (defined($ut) and $dlist->get_seentitle($ut) < 2 ) {
      $dlist->set_entryfield($citekey, 'uniquetitle', 1);
    }
  }
  return;
}

=head2 generate_uniquebaretitle

    Generate the uniquebaretitle field, if requested. The information for generating
    this is gathered in process_workuniqueness()

=cut

sub generate_uniquebaretitle {
  my ($self, $citekey, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bibentries;
  my $be = $bibentries->entry($citekey);
  my $bee = $be->get_field('entrytype');

  if (Biber::Config->getblxoption(undef, 'uniquebaretitle', $bee, $citekey)) {
    my $ubt = $dlist->get_entryfield($citekey, 'seenbaretitle');
    if (defined($ubt) and $dlist->get_seenbaretitle($ubt) < 2 ) {
      $dlist->set_entryfield($citekey, 'uniquebaretitle', 1);
    }
  }
  return;
}

=head2 generate_uniquework

    Generate the uniquework field, if requested. The information for generating
    this is gathered in process_workuniqueness()

=cut

sub generate_uniquework {
  my ($self, $citekey, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bibentries;
  my $be = $bibentries->entry($citekey);
  my $bee = $be->get_field('entrytype');

  if (Biber::Config->getblxoption(undef, 'uniquework', $bee, $citekey)) {
    if ($dlist->get_entryfield($citekey, 'seenwork') and
        $dlist->get_seenwork($dlist->get_entryfield($citekey, 'seenwork')) < 2 ) {
      if ($logger->is_trace()) { # performance tune
        $logger->trace("Setting uniquework for '$citekey'");
      }
      $dlist->set_entryfield($citekey, 'uniquework', 1);
    }
    else {
      if ($logger->is_trace()) { # performance tune
        $logger->trace("Not setting uniquework for '$citekey'");
      }
    }
  }
  return;
}

=head2 generate_uniquepa

    Generate the uniqueprimaryauthor field, if requested. The information for generating
    this is gathered in create_uniquename_info()

=cut

sub generate_uniquepa {
  my ($self, $citekey, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bibentries;
  my $be = $bibentries->entry($citekey);
  my $bee = $be->get_field('entrytype');

  if (Biber::Config->getblxoption(undef, 'uniqueprimaryauthor', $bee, $citekey)) {
    if ($dlist->get_entryfield($citekey, 'seenprimaryauthor') and
        $dlist->get_seenpa($dlist->get_entryfield($citekey, 'seenprimaryauthor')) < 2 ) {
      if ($logger->is_trace()) { # performance tune
        $logger->trace("Setting uniqueprimaryauthor for '$citekey'");
      }
      $dlist->set_entryfield($citekey, 'uniqueprimaryauthor', 1);
    }
    else {
      if ($logger->is_trace()) { # performance tune
        $logger->trace("Not setting uniqueprimaryauthor for '$citekey'");
      }
    }
  }
  return;
}

=head2 sort_list

    Sort a list using information in entries according to a certain sorting template.
    Use a flag to skip info messages on first pass

=cut

sub sort_list {
  my ($self, $dlist) = @_;
  my $sortingtemplate = $dlist->get_sortingtemplate;
  my $lsds  = $dlist->get_sortdataschema;
  my @keys = $dlist->get_keys->@*;
  my $lstn = $dlist->get_sortingtemplatename;
  my $ltype = $dlist->get_type;
  my $lname = $dlist->get_name;
  my $llocale = locale2bcp47($sortingtemplate->{locale} || Biber::Config->getblxoption(undef, 'sortlocale'));
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);

  if ($logger->is_debug()) {# performance tune
    if (Biber::Config->getoption('sortcase')) {
      $logger->debug("Sorting is by default case-SENSITIVE");
    }
    else {
      $logger->debug("Sorting is by default case-INSENSITIVE");
    }
    $logger->debug("Keys before sort:\n");
    foreach my $k (@keys) {
      $logger->debug("$k => " . $dlist->get_sortdata_for_key($k)->[0]);
    }
  }

  if ($logger->is_trace()) { # performance shortcut
    $logger->trace("Sorting datalist '$lname' of type '$ltype' with sortingtemplate '$lstn'. Scheme is\n-------------------\n" . Data::Dump::pp($sortingtemplate) . "\n-------------------\n");
  }
  # Set up locale. Order of priority is:
  # 1. locale value passed to Unicode::Collate::Locale->new() (Unicode::Collate sorts only)
  # 2. Biber sortlocale option
  # 3. Sorting 'locale' option
  # 4. Global biblatex 'sortlocale' option

  my $thislocale = Biber::Config->getoption('sortlocale') || $llocale;
  if ($logger->is_debug()) {# performance tune
    $logger->debug("Locale for sorting is '$thislocale'");
  }

  if ( Biber::Config->getoption('fastsort') ) {
    biber_warn("fastsort option no longer required/supported, defaulting to UCA");
  }

  my $collopts = Biber::Config->getoption('collate_options');

  # UCA level 2 if case insensitive sorting is requested
  unless (Biber::Config->getoption('sortcase')) {
    $collopts->{level} = 2;
  }

  # Add upper_before_lower option
  $collopts->{upper_before_lower} = Biber::Config->getoption('sortupper');

  # Create collation object

  my $Collator = Biber::UCollate->new($thislocale, $collopts->%*);

  my $UCAversion = $Collator->version();
  $logger->info("Sorting list '$lname' of type '$ltype' with template '$lstn' and locale '$thislocale'");
  if ($logger->is_debug()) {# performance tune
    $logger->debug("Sorting with Unicode::Collate (" . stringify_hash($collopts) . ", UCA version: $UCAversion, Locale: " . $Collator->getlocale . ")");
  }

  # Log if U::C::L currently has no tailoring for used locale
  if ($Collator->getlocale eq 'default') {
    $logger->info("No sort tailoring available for locale '$thislocale'");
  }

  # For collecting the collation object settings for retrieval in the sort key extractor
  my @collateobjs;

  # Instantiate Sort::Key sorter with correct data schema
  my $sorter = multikeysorter(map {$_->{spec}} $lsds->@*);

  # Sorting cache to shortcut expensive UCA keygen
  my $cache;

  # Construct data needed for sort key extractor
  foreach my $sortset ($sortingtemplate->{spec}->@*) {
    my $fc = '';
    my @fc;

    # Re-instantiate collation object if a different locale is required for this sort item.
    # This can't be done in a ->change() method, has to be a new object.
    my $cobj;
    my $sl = locale2bcp47($sortset->[0]{locale});
    if (defined($sl) and $sl ne $thislocale) {
      $cobj = 'Biber::UCollate->new(' . "'$sl'" . ",'" . join("','", $collopts->%*) . "')";
    }
    else {
      $cobj = '$Collator';
    }

    # If the case or upper option on a field is not the global default
    # set it locally on the $Collator by constructing a change() method call
    my $sc = $sortset->[0]{sortcase};
    if (defined($sc) and $sc != Biber::Config->getoption('sortcase')) {
      push @fc, $sc ? 'level => 4' : 'level => 2';
    }
    my $su = $sortset->[0]{sortupper};
    if (defined($su) and $su != Biber::Config->getoption('sortupper')) {
      push @fc, $su ? 'upper_before_lower => 1' : 'upper_before_lower => 0';
    }

    if (@fc) {
      # This field has custom collation options
      $fc = '->change(' . join(',', @fc) . ')';
    }
    else {
      # Reset collation options to global defaults if there are no field options
      # We have to do this as ->change modifies the Collation object
      $fc = '->change(level => '
        . $collopts->{level}
          . ' ,upper_before_lower => '
            . $collopts->{upper_before_lower}
              . ')';
    }

    push @collateobjs, $cobj . $fc;
  }

  # Sort::Key sort key extractor called on each element of array to be sorted and
  # returns an array of the sorting keys for each sorting field. We have to construct
  # the collator strings and then eval() because passing the collation
  # objects in directly by reference means that the wrong settings are present on some of them
  # since they point to the same object and the ->change() calls in later references
  # therefore change earlier sorting field sorts. So, we have to defer until actual use time.
  my $extract = sub {
    my @d;
    my $key = $keys[$_];
    # Loop over all sorting fields
    for (my $i=0; $i<=$#{$dlist->get_sortdata_for_key($key)->[1]}; $i++) {
      my $sortfield = $dlist->get_sortdata_for_key($key)->[1][$i];
      # Resolve real zeros back again
      if ($lsds->[$i]{int}) {
        # There are special cases to be careful of here in that "final" elements
        # in sorting copy themselves as strings to further sort fields and therefore
        # need coercing to 0 for int tests. Fallback of '0' for int fields should
        # be handled in the sorting spec otherwise this will be the default for missing
        # int fields. This means that entries with missing data for an int sort field will
        # always sort after int fields by default.

        # normalise all strings to a large int so that they sort after real ints
        # as a fallback
        push @d, looks_like_number($sortfield) ? $sortfield : 2000000000;
      }
      else {
        # Don't do '$sortfield' or "$sortfield" because it might contain quotes
        my $a = $collateobjs[$i] . "->getSortKey(q{$sortfield})";
        # Cache index is just the collation object opts and key gen call in string form
        # since this should be unique for a key/collopts combination
        push @d, $cache->{$a} ||= eval $a;
      }
    }
    return @d;
  };

  # We actually sort the indices of the keys array, as we need these in the extractor.
  # Then we extract the real keys with a map. This therefore follows the typical ST sort
  # semantics (plus an OM cache above due to expensive UCA key extraction).
  @keys = map {$keys[$_]} &$sorter($extract, 0..$#keys);

  if ($logger->is_debug()) {# performance tune for large @keys
    $logger->debug("Keys after sort:\n");
    foreach my $k (@keys) {
      $logger->debug("$k => " . $dlist->get_sortdata_for_key($k)->[0]);
    }
  }

  $dlist->set_keys([ @keys ]);

  return;
}

=head2 preprocess_options

   Preprocessing for options. Used primarily to perform process-intensive
   operations which can be done once instead of inside dense loops later.

=cut

sub preprocess_options {

  # nosort - compile regexps
  if (my $nosort = Biber::Config->getoption('nosort')) {
    foreach my $nsopt ($nosort->@*) {
      my $re = $nsopt->{value};
      $nsopt->{value} = qr/$re/;
    }
  }

  # nolabel - compile regexps
  if (my $nolabel = Biber::Config->getoption('nolabel')) {
    foreach my $nsopt ($nolabel->@*) {
      my $re = $nsopt->{value};
      $nsopt->{value} = qr/$re/;
    }
  }

  # noinit - compile regexps
  if (my $noinit = Biber::Config->getoption('noinit')) {
    foreach my $nsopt ($noinit->@*) {
      my $re = $nsopt->{value};
      $nsopt->{value} = qr/$re/;
    }
  }

  return;
}

=head2 prepare

    Do the main work.
    Process and sort all entries before writing the output.

=cut

sub prepare {
  my $self = shift;

  my $out = $self->get_output_obj;          # Biber::Output object

  # Place to put global pre-processing things
  $self->process_setup;

  foreach my $section ($self->sections->get_sections->@*) {
    # shortcut - skip sections that don't have any keys
    next unless $section->get_citekeys or $section->is_allkeys;
    my $secnum = $section->number;

    $logger->info("Processing section $secnum");

    $section->reset_caches;              # Reset the the section caches
    Biber::Config->_init;                # (re)initialise Config object
    $self->set_current_section($secnum); # Set the section number we are working on
    $self->preprocess_options;           # Preprocess any options
    $self->fetch_data;                   # Fetch cited key and dependent data from sources
    $self->process_citekey_aliases;      # Remove citekey aliases from citekeys
    $self->instantiate_dynamic;          # Instantiate any dynamic entries (sets, related)
    $self->resolve_alias_refs;           # Resolve xref/crossref/xdata aliases to real keys
    $self->resolve_xdata;                # Resolve xdata entries
    $self->cite_setmembers;              # Cite set members
    $self->preprocess_sets;              # Record set information
    $self->calculate_interentry;         # Calculate crossrefs/xrefs etc.
    $self->process_interentry;           # Process crossrefs/xrefs etc.
    $self->validate_datamodel;           # Check against data model
    $self->postprocess_sets;             # Add options to set members etc.
    $self->process_entries_static;       # Generate static entry data not dependent on lists
    $self->process_lists;                # Process the output lists
    $out->create_output_section;         # Generate and push the section output into the
                                         # output object ready for writing
  }
  $out->create_output_misc;              # Generate and push the final misc bits of output
                                         # into the output object ready for writing
  return;
}

=head2 prepare_tool

    Do the main work for tool mode

=cut

sub prepare_tool {
  my $self = shift;
  my $out = $self->get_output_obj;          # Biber::Output object

  # Place to put global pre-processing things
  $self->process_setup_tool;

  # tool mode only has a section '99999'
  my $secnum = 99999;
  my $section = $self->sections->get_section($secnum);

  $section->reset_caches; # Reset the the section caches (sorting, label etc.)
  Biber::Config->_init;   # (re)initialise Config object
  $self->set_current_section($secnum); # Set the section number we are working on
  $self->preprocess_options;           # Preprocess any options
  $self->fetch_data;      # Fetch cited key and dependent data from sources

  $self->resolve_alias_refs;   # Resolve xref/crossref/xdata aliases to real keys
  $self->preprocess_sets;      # Record set information
  $self->calculate_interentry; # Calculate crossrefs/xrefs etc.
  $self->process_interentry;   # Process crossrefs/xrefs etc.
  $self->resolve_xdata;        # Resolve xdata entries

  $self->validate_datamodel;   # Check against data model
  $self->process_lists;        # process the output lists (sort and filtering)
  $out->create_output_section; # Generate and push the section output into the
                               # into the output object ready for writing
  return;
}


=head2 fetch_data

    Fetch citekey and dependents data from section datasources
    Expects to find datasource packages named:

    Biber::Input::<type>::<datatype>

    and one defined subroutine called:

    Biber::Input::<type>::<datatype>::extract_entries

    which takes args:

    1: Biber object
    2: Datasource name
    3: Reference to an array of cite keys to look for

    and returns an array of the cite keys it did not find in the datasource

=cut

sub fetch_data {
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $dm = Biber::Config->get_dm;
  # Only looking for static keys, dynamic key entries are not in any datasource ...
  my @citekeys = $section->get_static_citekeys;
  no strict 'refs'; # symbolic references below ...

  # Clear all T::B macro definitions between sections if asked as T::B never clears these
  if (Biber::Config->getoption('clrmacros')) {
    if ($logger->is_debug()) {# performance tune
      $logger->debug('Clearing Text::BibTeX macros definitions');
    }
    Text::BibTeX::delete_all_macros();
  }

  # (Re-)define the old BibTeX month macros to what biblatex wants unless user stops this
  unless (Biber::Config->getoption('nostdmacros')) {
    foreach my $mon (keys %MONTHS) {
      Text::BibTeX::delete_macro($mon);
      Text::BibTeX::add_macro_text($mon, $MONTHS{$mon});
    }
  }

  # First we look for the directly cited keys in each datasource
  my @remaining_keys = @citekeys;
  if ($logger->is_debug()) {# performance tune
    $logger->debug('Looking for directly cited keys: ' . join(', ', @remaining_keys));
  }

  # Process datasource globs
  my $ds;
  foreach my $datasource ($section->get_datasources->@*) {
    unless ($datasource->{type} eq 'file') {
      push $ds->@*, $datasource;
    }
    foreach my $gds (glob_data_file($datasource->{name}, $datasource->{glob})) {
      push $ds->@*, { type     => $datasource->{type},
                      name     => $gds,
                      datatype => $datasource->{datatype},
                      encoding => $datasource->{encoding}};
    }
  }
  $section->set_datasources($ds);

  # Now actually fetch data with expanded list of data sources
  foreach my $datasource ($section->get_datasources->@*) {
    # shortcut if we have found all the keys now
    last unless (@remaining_keys or $section->is_allkeys);
    my $type = $datasource->{type};
    my $name = $datasource->{name};
    my $encoding = $datasource->{encoding};
    my $datatype = $datasource->{datatype};
    if ($datatype eq 'biblatexml') {
      my $outfile;
      if (Biber::Config->getoption('tool')) {
        my $exts = join('|', values %DS_EXTENSIONS);
        $outfile = Biber::Config->getoption('dsn') =~ s/\.(?:$exts)$/.rng/r;
      }
      else {
        $outfile = Biber::Config->getoption('bcf') =~ s/bcf$/rng/r;
      }

      # Generate schema for datasource
      unless (Biber::Config->getoption('no_bltxml_schema')) {
        $dm->generate_bltxml_schema($outfile);
      }

      if (Biber::Config->getoption('validate_bltxml')) {
        validate_biber_xml($name, 'bltx', 'http://biblatex-biber.sourceforge.net/biblatexml', $outfile);
      }
    }
    my $package = 'Biber::Input::' . $type . '::' . $datatype;
    unless(eval "require $package") {

      my ($vol, $dir, undef) = File::Spec->splitpath( $INC{"Biber.pm"} );
      $dir =~ s/\/$//;          # splitpath sometimes leaves a trailing '/'

      # Use Windows style globbing on Windows
      if ($^O =~ /Win/) {
        $logger->debug("Enabling Windows-style globbing");
        require File::DosGlob;
        File::DosGlob->import('glob');
      }

      my @vts;
      foreach my $t (glob("$vol$dir/Biber/Input/*")) {
        my (undef, undef, $tleaf) = File::Spec->splitpath($t);
        foreach my $dt (map {s/\.pm$//r} glob("$vol$dir/Biber/Input/$tleaf/*.pm")) {
          my (undef, undef, $dtleaf) = File::Spec->splitpath($dt);
          push @vts, "$tleaf/$dtleaf";
        }
      }

      biber_error("Error loading data source package '$package' for '$datatype' '$type' datasource. Valid type/datatypes are: " . join(',', @vts));

    }

    # Slightly different message for tool mode
    if (Biber::Config->getoption('tool')) {
      $logger->info("Looking for $datatype format $type '$name'");
    }
    else {
      $logger->info("Looking for $datatype format $type '$name' for section $secnum");
    }

    @remaining_keys = "${package}::extract_entries"->(locate_data_file($name), $encoding, \@remaining_keys);
  }

  # error reporting
  if ($logger->is_debug()) {# performance tune
    $logger->debug("Directly cited keys not found for section '$secnum': " . join(',', @remaining_keys));
  }

  foreach my $citekey (@remaining_keys) {
    biber_warn("I didn't find a database entry for '$citekey' (section $secnum)");
    $section->del_citekey($citekey);
    $section->add_undef_citekey($citekey);
  }

  if ($logger->is_debug()) {# performance tune
    $logger->debug('Building dependents for keys: ' . join(',', $section->get_citekeys));
  }

  # dependent key list generation - has to be a sub as it's recursive to catch
  # nested crossrefs, xdata etc.
  # We still do this even in tool mode which is implicitly allkeys=1 because it
  # prunes things like missing crossrefs etc. which otherwise would cause problems
  # later on
  get_dependents($self, [$section->get_citekeys]);
  if ($logger->is_debug()) {# performance tune
    $logger->debug("Citekeys for section '$secnum' after fetching data: " . join(', ', $section->get_citekeys));
  }
  return;
}

=head2 get_dependents

  Get dependents of the entries for a given list of citekeys. Is called recursively
  until there are no more dependents to look for.

=cut

sub get_dependents {
  my ($self, $keys, $keyswithdeps, $missing) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $new_deps;

  $keyswithdeps = $keyswithdeps // [];
  $missing = $missing // [];

  no strict 'refs'; # symbolic references below ...

  foreach my $citekey ($keys->@*) {
    # aliases need resolving here and are treated as dependents
    if (my $real = $section->get_citekey_alias($citekey)) {
      if ($logger->is_debug()) {# performance tune
        $logger->debug("Alias '$citekey' requires real key '$real'");
      }
      push $new_deps->@*, $real;
      push $keyswithdeps->@*, $real unless first {$real eq $_} $keyswithdeps->@*;
    }
    # Dynamic sets don't exist yet but their members do
    elsif (my @dmems = $section->get_dynamic_set($citekey)) {
      # skip looking for dependent if it's already there
      foreach my $dm (@dmems) {
        unless ($section->bibentry($dm)) {
          push $new_deps->@*, $dm;
          push $keyswithdeps->@*, $citekey unless first {$citekey eq $_} $keyswithdeps->@*;
        }
      }
      if ($logger->is_debug()) {# performance tune
        $logger->debug("Dynamic set entry '$citekey' has members: " . join(', ', @dmems));
      }
    }
    else {
      # This must exist for all but dynamic sets
      my $be = $section->bibentry($citekey);

      # xdata
      if (my $xdata = $be->get_xdata_refs) {
        foreach my $xdatum ($xdata->@*) {
          foreach my $xdref ($xdatum->{xdataentries}->@*) {
            # skip looking for dependent if it's already there (loop suppression)
            push $new_deps->@*, $xdref unless $section->bibentry($xdref);
            if ($logger->is_debug()) { # performance tune
              $logger->debug("Entry '$citekey' has xdata '$xdref'");
            }
            push $keyswithdeps->@*, $citekey unless first {$citekey eq $_} $keyswithdeps->@*;
          }
        }
      }

      # xrefs
      if (my $refkey = $be->get_field('xref')) {
        # skip looking for dependent if it's already there (loop suppression)
        push $new_deps->@*, $refkey unless $section->bibentry($refkey);
        if ($logger->is_debug()) {# performance tune
          $logger->debug("Entry '$citekey' has xref '$refkey'");
        }
        push $keyswithdeps->@*, $citekey unless first {$citekey eq $_} $keyswithdeps->@*;
      }

      # crossrefs
      if (my $refkey = $be->get_field('crossref')) {
        # skip looking for dependent if it's already there (loop suppression)
        push $new_deps->@*, $refkey unless $section->bibentry($refkey);
        if ($logger->is_debug()) {# performance tune
          $logger->debug("Entry '$citekey' has crossref '$refkey'");
        }
        push $keyswithdeps->@*, $citekey unless first {$citekey eq $_} $keyswithdeps->@*;
      }

      # static sets
      if ($be->get_field('entrytype') eq 'set') {
        my $smems = $be->get_field('entryset');
        # skip looking for dependent if it's already there (loop suppression)
        foreach my $sm ($smems->@*) {
          unless ($section->has_citekey($sm)) {
            push $new_deps->@*, $sm;
            push $keyswithdeps->@*, $citekey unless first {$citekey eq $_} $keyswithdeps->@*;
          }
        }
        if ($logger->is_debug()) {# performance tune
          $logger->debug("Static set entry '$citekey' has members: " . join(', ', $smems->@*));
        }
      }

      # Related entries
      if (my $relkeys = $be->get_field('related')) {
        # skip looking for dependent if it's already there (loop suppression)
        foreach my $rm ($relkeys->@*) {
          unless ($section->has_citekey($rm) or $section->is_related($rm)) {
            # record that $rm is used as a related entry key
            $section->add_related($rm);
            push $new_deps->@*, $rm;
            push $keyswithdeps->@*, $citekey unless first {$citekey eq $_} $keyswithdeps->@*;
          }
        }
        if ($logger->is_debug()) {# performance tune
          $logger->debug("Entry '$citekey' has related entries: " . join(', ', $relkeys->@*));
        }
      }
    }
  }

  # Remove repeated keys which are dependents of more than one entry
  $new_deps->@* = uniq $new_deps->@*;

  if ($new_deps->@*) {
    # Now look for the dependents of the directly cited keys
    if ($logger->is_debug()) {# performance tune
      $logger->debug('Looking for dependent keys: ' . join(', ', $new_deps->@*));
    }

    # No need to go back to the datasource if allkeys, just see if the keys
    # are in section
    if ($section->is_allkeys) {
      foreach my $dk ($new_deps->@*) {
        push $missing->@*, $dk unless $section->has_citekey($dk);
      }
    }
    else {
      $missing->@* = $new_deps->@*;
      foreach my $datasource ($section->get_datasources->@*) {
        # shortcut if we have found all the keys now
        last unless $missing->@*;
        my $type = $datasource->{type};
        my $name = $datasource->{name};
        my $encoding = $datasource->{encoding};
        my $datatype = $datasource->{datatype};
        my $package = 'Biber::Input::' . $type . '::' . $datatype;
        eval "require $package" or
          biber_error("Error loading data source package '$package': $@");
        $missing->@* = "${package}::extract_entries"->(locate_data_file($name), $encoding, $missing);
      }
    }

    if ($logger->is_debug()) {# performance tune
      $logger->debug("Dependent keys not found for section '$secnum': " . join(', ', $missing->@*));
    }
    foreach my $missing_key ($missing->@*) {
      # Remove the missing key from the list to recurse with
      $new_deps->@* = grep { $_ ne $missing_key } $new_deps->@*;
    }
  }

  # recurse if there are more things to find
  if ($logger->is_trace()) {# performance tune
    $logger->trace('Recursing in get_dependents with: ' . join(', ', $new_deps->@*));
  }

  get_dependents($self, $new_deps, $keyswithdeps) if $new_deps->@*;

  # Now remove any missing entries from various places in all entries we have flagged
  # as having dependendents. If we don't do this, many things fail later like clone creation
  # for related entries etc.
  foreach my $keywithdeps ($keyswithdeps->@*) {
    foreach my $missing_key ($missing->@*) {
      $self->remove_undef_dependent($keywithdeps, $missing_key);
    }
  }

  return; # bottom of recursion
}


=head2 remove_undef_dependent

    Remove undefined dependent keys from an entry using a map of
    dependent keys to entries

=cut

sub remove_undef_dependent {
  my $self = shift;
  my ($citekey, $missing_key) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  if ($logger->is_debug()) {# performance tune
    $logger->debug("Removing dependency on missing key '$missing_key' from '$citekey' in section '$secnum'");
  }

  # remove from any dynamic keys
  if (my @dmems = $section->get_dynamic_set($citekey)){
    if (first {$missing_key eq $_} @dmems) {
      $section->set_dynamic_set($citekey, grep {$_ ne $missing_key} @dmems);
      if ($logger->is_trace()) {# performance tune
        $logger->trace("Removed dynamic set dependency for missing key '$missing_key' from '$citekey' in section '$secnum'");
      }
      biber_warn("I didn't find a database entry for dynamic set member '$missing_key' - ignoring (section $secnum)");
    }
  }
  else {
    my $be = $section->bibentry($citekey);

    # remove any xrefs
    if ($be->get_field('xref') and ($be->get_field('xref') eq $missing_key)) {
      biber_warn("I didn't find a database entry for xref '$missing_key' in entry '$citekey' - ignoring (section $secnum)");

      if ($logger->is_trace()) { # performance tune
        $logger->trace("Removed xref dependency for missing key '$missing_key' from '$citekey' in section '$secnum'");
      }

      if (not Biber::Config->getoption('tool_noremove_missing_dependants')) {
        $be->del_field('xref');
      }
    }

    # remove any crossrefs
    if ($be->get_field('crossref') and ($be->get_field('crossref') eq $missing_key)) {
      biber_warn("I didn't find a database entry for crossref '$missing_key' in entry '$citekey' - ignoring (section $secnum)");

      if ($logger->is_trace()) { # performance tune
        $logger->trace("Removed crossref dependency for missing key '$missing_key' from '$citekey' in section '$secnum'");
      }

      if (not Biber::Config->getoption('tool_noremove_missing_dependants')) {
        $be->del_field('crossref');
      }
    }

    # remove xdata
    if (my $xdata = $be->get_field('xdata')) {
      if (first {$missing_key eq $_} $xdata->@*) {
        biber_warn("I didn't find a database entry for xdata entry '$missing_key' in entry '$citekey' - ignoring (section $secnum)");
      }

      if ($logger->is_trace()) { # performance tune
        $logger->trace("Removed xdata dependency for missing key '$missing_key' from '$citekey' in section '$secnum'");
      }

      if (not Biber::Config->getoption('tool_noremove_missing_dependants')) {
        $be->set_datafield('xdata', [ grep {$_ ne $missing_key} $xdata->@* ]);
      }
    }

    # remove static sets
    if ($be->get_field('entrytype') eq 'set') {
      my $smems = $be->get_field('entryset');
      if (first {$missing_key eq $_} $smems->@*) {
        $be->set_datafield('entryset', [ grep {$_ ne $missing_key} $smems->@* ]);
        if ($logger->is_trace()) {# performance tune
          $logger->trace("Removed static set dependency for missing key '$missing_key' from '$citekey' in section '$secnum'");
        }
        biber_warn("I didn't find a database entry for static set member '$missing_key' in entry '$citekey' - ignoring (section $secnum)");
      }
    }

    # remove related entries
    if (my $relkeys = $be->get_field('related')) {
      if (first {$missing_key eq $_} $relkeys->@*) {
        $be->set_datafield('related', [ grep {$_ ne $missing_key} $relkeys->@* ]);
        # If no more related entries, remove the other related fields
        unless ($be->get_field('related')) {
          $be->del_field('relatedtype');
          $be->del_field('relatedstring');
          if ($logger->is_trace()) {# performance tune
            $logger->trace("Removed related entry dependency for missing key '$missing_key' from '$citekey' in section '$secnum'");
          }
        }
        biber_warn("I didn't find a database entry for related entry '$missing_key' in entry '$citekey' - ignoring (section $secnum)");
      }
    }
  }
    return;
}

=head2 _parse_sort

   Convenience sub to parse a .bcf sorting section and return nice
   sorting object

=cut

sub _parse_sort {
  my $root_obj = shift;
  my $sorting;

  foreach my $sort (sort {$a->{order} <=> $b->{order}} $root_obj->{sort}->@*) {
    my $sortingitems;

    # Generate sorting pass structures
    foreach my $sortitem (sort {$a->{order} <=> $b->{order}} $sort->{sortitem}->@*) {
      my $sortitemattributes = {};
      if (defined($sortitem->{substring_side})) { # Found sorting substring side attribute
        $sortitemattributes->{substring_side} = $sortitem->{substring_side};
      }
      if (defined($sortitem->{substring_width})) { # Found sorting substring length attribute
        $sortitemattributes->{substring_width} = $sortitem->{substring_width};
      }
      if (defined($sortitem->{pad_width})) { # Found sorting pad length attribute
        $sortitemattributes->{pad_width} = $sortitem->{pad_width};
      }
      if (defined($sortitem->{pad_char})) { # Found sorting pad char attribute
        $sortitemattributes->{pad_char} = $sortitem->{pad_char};
      }
      if (defined($sortitem->{pad_side})) { # Found sorting pad side attribute
        $sortitemattributes->{pad_side} = $sortitem->{pad_side};
      }
      if (defined($sortitem->{literal})) { # Found literal attribute
        $sortitemattributes->{literal} = $sortitem->{literal};
      }
      push $sortingitems->@*, {$sortitem->{content} => $sortitemattributes};
    }

    # Only push a sortitem if defined.
    # Also, we only push the sort attributes if there are any sortitems otherwise
    # we end up with a blank sort
    my $sopts;
    $sopts->{final}          = $sort->{final}          if defined($sort->{final});
    $sopts->{sort_direction} = $sort->{sort_direction} if defined($sort->{sort_direction});
    $sopts->{sortcase}       = $sort->{sortcase}       if defined($sort->{sortcase});
    $sopts->{sortupper}      = $sort->{sortupper}      if defined($sort->{sortupper});
    $sopts->{locale}         = $sort->{locale}         if defined($sort->{locale});
    if (defined($sortingitems)) {
      unshift $sortingitems->@*, $sopts;
      push $sorting->@*, $sortingitems;
    }
  }

  return {locale => locale2bcp47($root_obj->{locale} || Biber::Config->getblxoption(undef, 'sortlocale')),
          spec   => $sorting};
}

=head2 _filedump and _stringdump

    Dump the biber object with Data::Dump for debugging

=cut

sub _filedump {
  my ($self, $file) = @_;
  my $fh = IO::File->new($file, '>') or croak "Can't open file $file for writing";
  print $fh Data::Dump::pp($self);
  close $fh;
  return
}

sub _stringdump {
  my $self = shift ;
  return Data::Dump::pp($self);
}

1;

__END__

=head1 AUTHORS

Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our Github tracker at
L<https://github.com/plk/biber/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2012 François Charette and Philip Kime, all rights reserved.
Copyright 2012-2020 Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
