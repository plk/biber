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
use Biber::DataModel;
use Biber::Constants;
use Biber::Internals;
use Biber::Entries;
use Biber::Entry;
use Biber::Entry::Names;
use Biber::Entry::Name;
use Biber::Sections;
use Biber::Section;
use Biber::LaTeX::Recode;
use Biber::SortLists;
use Biber::SortList;
use Biber::UCollate;
use Biber::Utils;
use Carp;
use Data::Dump;
use Data::Compare;
use Encode;
use File::Copy;
use File::Spec;
use File::Temp;
use IO::File;
use List::AllUtils qw( first uniq max );
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

  # Add a reference to a global temp dir we might use for various things
  $self->{TEMPDIR} = File::Temp->newdir();

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

  return $self;
}


=head2 display_problems

   Output summary of warnings/errors before exit

=cut

sub display_problems {
  my $self = shift;
  if ($self->{warnings}) {
    $logger->info('WARNINGS: ' . $self->{warnings});
  }
  if ($self->{errors}) {
    $logger->info('ERRORS: ' . $self->{errors});
    exit EXIT_ERROR;
  }
}

=head2 biber_tempdir

    my $sections= $biber->biber_tempdir

    Returns a File::Temp directory object for use in various things

=cut

sub biber_tempdir {
  my $self = shift;
  return $self->{TEMPDIR};
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

=head2 sortlists

    my $sortlists= $biber->sortlists

    Returns a Biber::SortLists object describing the bibliography sorting lists

=cut

sub sortlists {
  my $self = shift;
  return $self->{sortlists};
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
  $bib_section->set_datasources([{type => 'file',
                                  name => $ARGV[0],
                                  datatype => Biber::Config->getoption('input_format')}]);
  $bib_section->set_allkeys(1);
  $bib_sections->add_section($bib_section);

  # Always resolve date meta-information in tool mode
  Biber::Config->setblxoption('datecirca', 1);
  Biber::Config->setblxoption('dateera', 1);
  Biber::Config->setblxoption('dateuncertain', 1);

  # Add the Biber::Sections object to the Biber object
  $self->add_sections($bib_sections);

  my $sortlists = new Biber::SortLists;
  my $seclist = Biber::SortList->new(section => 99999,
                                     sortschemename => Biber::Config->getblxoption('sortscheme'),
                                     sortnamekeyschemename => 'global',
                                     labelprefix => '',
                                     name => Biber::Config->getblxoption('sortscheme') . '/global/');
  $seclist->set_type('entry');
  $seclist->set_sortscheme(Biber::Config->getblxoption('sorting'));
  # Locale just needs a default here - there is no biblatex option to take it from
  Biber::Config->setblxoption('sortlocale', 'en_US');
  if ($logger->is_debug()) {# performance tune
    $logger->debug("Adding 'entry' list 'tool' for pseudo-section 99999");
  }
  $sortlists->add_list($seclist);
  $self->{sortlists} = $sortlists;

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

  my $ctrl_file_path = locate_biber_file($ctrl_file);
  Biber::Config->set_ctrlfile_path($ctrl_file_path);

  biber_error("Cannot find control file '$ctrl_file'! - did you pass the \"backend=biber\" option to BibLaTeX?") unless ($ctrl_file_path and -e $ctrl_file_path);

  # Early check to make sure .bcf is well-formed. If not, this means that the last biblatex run
  # exited prematurely while writing the .bcf. This results is problems for latexmk. So, if the
  # .bcf is broken, just stop here, remove the .bcf and exit with error so that we don't write
  # a bad .bbl
  my $checkbuf = File::Slurp::read_file($ctrl_file_path) or biber_error("Cannot open $ctrl_file_path: $!");
  $checkbuf = NFD(decode('UTF-8', $checkbuf));# Unicode NFD boundary
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

    if (-e $bcf_xsl) {
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
  my $buf = File::Slurp::read_file($ctrl_file_path) or biber_error("Cannot open $ctrl_file_path: $!");
  $buf = NFD(decode('UTF-8', $buf));# Unicode NFD boundary

  # Read control file
  require XML::LibXML::Simple;

  my $bcfxml = XML::LibXML::Simple::XMLin($buf,
                                          'ForceContent' => 1,
                                          'ForceArray' => [
                                                           qr/\Acitekey\z/,
                                                           qr/\Aoption\z/,
                                                           qr/\Aoptions\z/,
                                                           qr/\Avalue\z/,
                                                           qr/\Asortitem\z/,
                                                           qr/\Abibdata\z/,
                                                           qr/\Adatasource\z/,
                                                           qr/\Aconstant\z/,
                                                           qr/\Asection\z/,
                                                           qr/\Asortexclusion\z/,
                                                           qr/\Aexclusion\z/,
                                                           qr/\Asort\z/,
                                                           qr/\Amode\z/,
                                                           qr/\Amaps\z/,
                                                           qr/\Amap\z/,
                                                           qr/\Amap_step\z/,
                                                           qr/\Aper_type\z/,
                                                           qr/\Aper_nottype\z/,
                                                           qr/\Akeypart\z/,
                                                           qr/\Apart\z/,
                                                           qr/\Asortingnamekey\z/,
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
                                                           qr/\Atransliteration\z/,
                                                           qr/\Atranslit\z/,
                                                           qr/\Aalias\z/,
                                                           qr/\Aalsoset\z/,
                                                           qr/\Aconstraints\z/,
                                                           qr/\Aconstraint\z/,
                                                           qr/\Aentrytype\z/,
                                                           qr/\Adatetype\z/,
                                                           qr/\Asortlist\z/,
                                                           qr/\Alabel(?:part|element|alpha(?:name)?template)\z/,
                                                           qr/\Acondition\z/,
                                                           qr/\Afilter(?:or)?\z/,
                                                           qr/\Aoptionscope\z/,
                                                          ],
                                          'NsStrip' => 1,
                                          'KeyAttr' => []);
#  use Data::Dump;dd($bcfxml);exit 0;
  my $controlversion = $bcfxml->{version};
  my $bltxversion = $bcfxml->{bltxversion};
  Biber::Config->setblxoption('controlversion', $controlversion);
  unless ($controlversion eq $BCF_VERSION) {
    biber_error("Error: Found biblatex control file version $controlversion, expected version $BCF_VERSION.\nThis means that your biber ($Biber::Config::VERSION) and biblatex ($bltxversion) versions are incompatible.\nSee compat matrix in biblatex or biber PDF documentation.");
  }

  # Option scope
  foreach my $bcfscopeopts ($bcfxml->{optionscope}->@*) {
    my $scope = $bcfscopeopts->{type};
    foreach my $bcfscopeopt ($bcfscopeopts->{option}->@*) {
      my $opt = $bcfscopeopt->{content};
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
            Biber::Config->setblxoption($bcfopt->{key}{content}, $bcfopt->{value}[0]{content});
          }
          elsif ($bcfopt->{type} eq 'multivalued') {
            # sort on order attribute and then remove it
            Biber::Config->setblxoption($bcfopt->{key}{content},
              [ map {delete($_->{order}); $_} sort {$a->{order} <=> $b->{order}} $bcfopt->{value}->@* ]);
          }
        }
      }

      # Entrytype options
      else {
        my $entrytype = $bcfopts->{type};
        foreach my $bcfopt ($bcfopts->{option}->@*) {
          if ($bcfopt->{type} eq 'singlevalued') {
            Biber::Config->setblxoption($bcfopt->{key}{content}, $bcfopt->{value}[0]{content}, 'ENTRYTYPE', $entrytype);
          }
          elsif ($bcfopt->{type} eq 'multivalued') {
            # sort on order attribute and then remove it
            Biber::Config->setblxoption($bcfopt->{key}{content},
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
  foreach my $t ($bcfxml->{labelalphanametemplate}->@*) {
    my $lant;
    my $lantype = $t->{type};
    foreach my $np (sort {$a->{order} <=> $b->{order}} $t->{namepart}->@*) {
      push $lant->@*, {namepart           => $np->{content},
                       use                => $np->{use},
                       pre                => $np->{pre},
                       substring_compound => $np->{substring_compound},
                       substring_side     => $np->{substring_side},
                       substring_width    => $np->{substring_width}};
    }

    if ($lantype eq 'global') {
      Biber::Config->setblxoption('labelalphanametemplate', $lant);
    }
    else {
      Biber::Config->setblxoption('labelalphanametemplate', $lant, 'ENTRYTYPE', $lantype);
    }
  }

  # LABELALPHA TEMPLATE
  foreach my $t ($bcfxml->{labelalphatemplate}->@*) {
    my $latype = $t->{type};
    if ($latype eq 'global') {
      Biber::Config->setblxoption('labelalphatemplate', $t);
    }
    else {
      Biber::Config->setblxoption('labelalphatemplate',
                                  $t,
                                  'ENTRYTYPE',
                                  $latype);
    }
  }

  # INHERITANCE schemes for crossreferences (always global)
  Biber::Config->setblxoption('inheritance', $bcfxml->{inheritance});

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
    push $nosort->@*, { name => $ns->{field}[0], value => $ns->{value}[0]};
  }
  # There is a default so don't set this option if nothing is in the .bcf
  Biber::Config->setoption('nosort', $nosort) if $nosort;

  # UNIQUENAME TEMPLATE
  my $unkt;
  my $bun;
  foreach my $np (sort {$a->{order} <=> $b->{order}} $bcfxml->{uniquenametemplate}{namepart}->@*) {
    # useful later in uniqueness tests
    if ($np->{base}) {
      push $bun->@*, $np->{content};
    }

    push $unkt->@*, {namepart => $np->{content},
                     use      => $np->{use},
                     base     => $np->{base}};
  }
  Biber::Config->setblxoption('uniquenametemplate', $unkt);

  # SORTING NAME KEY
  # Use the order attributes to make sure things are in right order and create a data structure
  # we can use later
  my $snss;
  foreach my $sns ($bcfxml->{sortingnamekey}->@*) {
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
    $snss->{$sns->{keyscheme}} = $snkps;
  }
  Biber::Config->setblxoption('sortingnamekey', $snss);

  # SORTING

  # transliterations
  foreach my $tr ($bcfxml->{transliteration}->@*) {
    if ($tr->{entrytype}[0] eq '*') { # already array forced for another option
      Biber::Config->setblxoption('translit', $tr->{translit});
    }
    else { # per_entrytype
      Biber::Config->setblxoption('translit',
                                  $tr->{translit},
                                  'ENTRYTYPE',
                                  $tr->{entrytype}[0]);
    }
  }

  # sorting excludes
  foreach my $sex ($bcfxml->{sorting}{sortexclusion}->@*) {
    my $excludes;
    foreach my $ex ($sex->{exclusion}->@*) {
      $excludes->{$ex->{content}} = 1;
    }
    Biber::Config->setblxoption('sortexclusion',
                                $excludes,
                                'ENTRYTYPE',
                                $sex->{type});
  }

  # presort defaults
  foreach my $presort ($bcfxml->{sorting}{presort}->@*) {
    # Global presort default
    unless (exists($presort->{type})) {
      Biber::Config->setblxoption('presort', $presort->{content});
    }
    # Per-type default
    else {
      Biber::Config->setblxoption('presort',
                                  $presort->{content},
                                  'ENTRYTYPE',
                                  $presort->{type});
    }
  }

  my $sorting = _parse_sort($bcfxml->{sorting});

  Biber::Config->setblxoption('sorting', $sorting);

  # DATAMODEL schema (always global)
  Biber::Config->setblxoption('datamodel', $bcfxml->{datamodel});

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
                                                         datatype => $datasource->{datatype} };
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

    my @keys = ();
    foreach my $keyc ($section->{citekey}->@*) {
      my $key = NFD($keyc->{content});# Key is already UTF-8 - it comes from UTF-8 XML
      # Stop reading citekeys if we encounter "*" as a citation as this means
      # "all keys"
      if ($key eq '*') {
        $bib_section->set_allkeys(1);
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
          next if $bib_section->is_allkeys; # Skip if we have already encountered '*'
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

  # Read sortlists
  my $sortlists = new Biber::SortLists;

  foreach my $list ($bcfxml->{sortlist}->@*) {
    my $ltype  = $list->{type};
    my $lssn = $list->{sortscheme};
    my $lsnksn = $list->{sortnamekeyscheme};
    my $lpn = $list->{labelprefix};
    my $lname = $list->{name};

    my $lsection = $list->{section}[0]; # because "section" needs to be a list elsewhere in XML
    if ($sortlists->get_list($lsection, $lname, $ltype, $lssn, $lsnksn, $lpn)) {
      if ($logger->is_debug()) {# performance tune
        $logger->debug("Section sortlist '$lname' of type '$ltype' with sortscheme '$lssn', sortnamekeyscheme '$lsnksn' and labelprefix '$lpn' is repeated for section $lsection - ignoring");
      }
      next;
    }

    my $sortlist = Biber::SortList->new(section => $lsection,
                                        sortschemename => $lssn,
                                        sortnamekeyschemename => $lsnksn,
                                        labelprefix => $lpn,
                                        name => $lname);
    $sortlist->set_type($ltype || 'entry'); # lists are entry lists by default
    $sortlist->set_name($lname || "$lssn/$lsnksn/$lpn"); # default to ss+snkss+pn
    foreach my $filter ($list->{filter}->@*) {
      $sortlist->add_filter({'type'  => $filter->{type},
                            'value' => $filter->{content}});
    }
    # disjunctive filters are an array ref of filter hashes
    foreach my $orfilter ($list->{filteror}->@*) {
      my $orfilts = [];
      foreach my $filter ($orfilter->{filter}->@*) {
        push $orfilts->@*, {type  => $filter->{type},
                            value => $filter->{content}};
      }
      $sortlist->add_filter($orfilts) if $orfilts;
    }

    if (my $sorting = $list->{sorting}) { # can be undef for fallback to global sorting
      $sortlist->set_sortscheme(_parse_sort($sorting));
    }
    else {
      $sortlist->set_sortscheme(Biber::Config->getblxoption('sorting'));
    }

    # Collator for determining primary weight hash for sortinit
    # Here as it varies only with the locale and that doesn't vary between entries in a list
    # Potentially, the locale could be different for the first field in the sort spec in which
    # case that might give wrong results but this is highly unlikely as it is only used to
    # determine sortinithash in SortList.pm and that only changes \bibinitsep in biblatex.
    $sortlist->set_sortinit_collator(Unicode::Collate::Locale->new(locale => $sortlist->get_sortscheme->{locale}, level => 1));

    if ($logger->is_debug()) {# performance tune
      $logger->debug("Adding sortlist of type '$ltype' with sortscheme '$lssn', sortnamekeyscheme '$lsnksn', labelprefix '$lpn' and name '$lname' for section $lsection");
    }
    $sortlists->add_list($sortlist);
  }

  # Check to make sure that each section has an entry sortlist for global sorting
  # We have to make sure in case sortcites is used which uses the global order.
  foreach my $section ($bcfxml->{section}->@*) {
    my $globalss = Biber::Config->getblxoption('sortscheme');
    my $secnum = $section->{number};
    unless ($sortlists->get_list($secnum, "$globalss/global/", 'entry', $globalss, 'global', '')) {
      my $sortlist = Biber::SortList->new(section => $secnum,
                                          type => 'entry',
                                          sortschemename => $globalss,
                                          sortnamekeyschemename => 'global',
                                          labelprefix => '',
                                          name => "$globalss/global/");
      $sortlist->set_sortscheme(Biber::Config->getblxoption('sorting'));
      $sortlists->add_list($sortlist);
      # See comment above
      $sortlist->set_sortinit_collator(Unicode::Collate::Locale->new(locale => $sortlist->get_sortscheme->{locale}, level => 1));
    }
  }

  # Add the Biber::SortLists object to the Biber object
  $self->{sortlists} = $sortlists;

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
  if (Biber::Config->getoption('output_format') eq 'bibtex') {
    Biber::Config->setoption('tool' ,1);
    Biber::Config->setoption('pseudo_tool' ,1);

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

    # Global sorting in non tool mode bibtex output is citeorder so override the .bcf here
    Biber::Config->setblxoption('sortscheme', 'none');
    # Global locale in non tool mode bibtex output is default
    Biber::Config->setblxoption('sortlocale', 'english');

    my $sortlist = Biber::SortList->new(section => 99999,
                                        sortschemename => Biber::Config->getblxoption('sortscheme'),
                                        sortnamekeyschemename => 'global',
                                        labelprefix => '',
                                        name => Biber::Config->getblxoption('sortscheme') . '/global/');
    $sortlist->set_type('entry');
    # bibtex output in non-tool mode is just citeorder
    $sortlist->set_sortscheme({locale => locale2bcp47(Biber::Config->getblxoption('sortlocale')),
                              spec   =>
                             [
                              [
                               {},
                               {'citeorder'    => {}}
                              ]
                             ]});
    if ($logger->is_debug()) {# performance tune
      $logger->debug("Adding 'entry' list 'none' for pseudo-section 99999");
    }
    $self->{sortlists}->add_list($sortlist);
  }

  return;
}


=head2 process_setup

   Place to put misc pre-processing things needed later

=cut

sub process_setup {
  my $self = shift;

  # Make sure there is a default entry list with global sorting for each refsection
  # Needed in case someone cites entries which are included in no
  # bibliography as this results in no entry list in the .bcf
  foreach my $section ($self->sections->get_sections->@*) {
    my $secnum = $section->number;
    unless ($self->sortlists->has_lists_of_type_for_section($secnum, 'entry')) {
      my $sortlist = Biber::SortList->new(sortschemename => Biber::Config->getblxoption('sortscheme'),
                                       sortnamekeyschemename => 'global',
                                       labelprefix => '',
                                       name => Biber::Config->getblxoption('sortscheme') . '/global/');
      $sortlist->set_sortscheme(Biber::Config->getblxoption('sorting'));
      $sortlist->set_type('entry');
      $sortlist->set_section($secnum);
      $self->sortlists->add_list($sortlist);
      # See comment for same call in .bcf instantiation of sortlists
      $sortlist->set_sortinit_collator(Unicode::Collate::Locale->new(locale => $sortlist->get_sortscheme->{locale}, level => 1));
    }
  }

  # Break data model information up into more processing-friendly formats
  # for use in verification checks later
  # This has to be here as opposed to in parse_ctrlfile() so that it can pick
  # up user config dm settings
  Biber::Config->set_dm(Biber::DataModel->new(Biber::Config->getblxoption('datamodel')));

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

  Biber::Config->set_dm(Biber::DataModel->new(Biber::Config->getblxoption('datamodel')));

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
    if (my $xdata = $be->get_field('xdata')) {
      my $resolved_keys;
      foreach my $refkey ($xdata->@*) {
        $refkey = $section->get_citekey_alias($refkey) // $refkey;
        push $resolved_keys->@*, $refkey;
      }
      $be->set_datafield('xdata', $resolved_keys);
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

    # Save graph information if requested
    if (Biber::Config->getoption('output_format') eq 'dot') {
      foreach my $m (@members) {
        Biber::Config->set_graph('set', $dset, $m);
      }
    }
    # Setting dataonly for members is handled by process_sets()
  }

  # Instantiate any related entry clones we need
  foreach my $citekey ($section->get_citekeys) {
    my $be = $section->bibentry($citekey);
    $be->relclone;
  }
  return;
}

=head2 resolve_xdata

    Resolve xdata entries

=cut

sub resolve_xdata {
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  if ($logger->is_debug()) {# performance tune
    $logger->debug("Resolving XDATA entries for section $secnum");
  }

  # We are not looping over citekeys here as XDATA entries are not cited.
  # They may have been added to the section as entries, however.
  foreach my $be ($section->bibentries->entries) {
    # Don't directly resolve XDATA entrytypes - this is done recursively in the Entry method
    # Otherwise, we will die on loops etc. for XDATA entries which are never referenced from
    # any cited entry
    next if $be->get_field('entrytype') eq 'xdata';
    next unless my $xdata = $be->get_field('xdata');
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
      # automatically crossref for the first set member using plain set inheritance
      $be->set_inherit_from($section->bibentry($inset_keys->[0]), $section);
      # warning for the old pre-Biber way of doing things
      if ($be->get_field('crossref')) {
        biber_warn("Field 'crossref' is no longer needed in set entries in Biber - ignoring in entry '$citekey'", $be);
        $be->del_field('crossref');
      }
    }
  }
}

=head2 process_interentry

    $biber->process_interentry

    This does several things:
    1. Records the set information for use later
    2. Ensures proper inheritance of data from cross-references.
    3. Ensures that crossrefs/xrefs that are directly cited or cross-referenced
       at least mincrossrefs/minxrefs times are included in the bibliography.

=cut

sub process_interentry {
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);

  if ($logger->is_debug()) {# performance tune
    $logger->debug("Processing explicit and implicit xref/crossrefs for section $secnum");
  }

  foreach my $citekey ($section->get_citekeys) {
    my $be = $section->bibentry($citekey);

    # Record set information
    # It's best to do this in the loop here as every entry needs the information
    # from all other entries in process_sets()
    if ($be->get_field('entrytype') eq 'set') {
      my $entrysetkeys = $be->get_field('entryset');
      foreach my $member ($entrysetkeys->@*) {
        Biber::Config->set_set_pc($citekey, $member);
        Biber::Config->set_set_cp($member, $citekey);
      }
    }

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
      unless ($et eq 'xdata') { # XDATA are generic containers for any field
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
  }
}

=head2 process_entries_pre

    Main processing operations, to generate metadata and entry information
    This method is automatically called by C<prepare>.
    Here we generate the "namehash" and the strings for
    "labelname", "labelyear", "labelalpha", "sortstrings", etc.
    Runs prior to uniqueness processing

=cut

sub process_entries_pre {
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  if ($logger->is_debug()) {# performance tune
    $logger->debug("Postprocessing entries in section $secnum (before uniqueness)");
  }
  foreach my $citekey ( $section->get_citekeys ) {

    # process set entries
    $self->process_sets($citekey);

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
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  if ($logger->is_debug()) {# performance tune
    $logger->debug("Postprocessing entries in section $secnum (after uniqueness)");
  }
  foreach my $citekey ( $section->get_citekeys ) {

    # generate labelalpha information
    $self->process_labelalpha($citekey);

    # generate information for tracking extraalpha
    $self->process_extraalpha($citekey);

    # generate information for tracking extrayear
    $self->process_extrayear($citekey);

    # generate information for tracking extratitle
    $self->process_extratitle($citekey);

    # generate information for tracking extratitleyear
    $self->process_extratitleyear($citekey);

    # generate information for tracking singletitle, uniquetitle, uniquebaretitle and uniquework
    $self->process_workuniqueness($citekey);

    # generate information for tracking uniqueprimaryauthor
    $self ->process_uniqueprimaryauthor($citekey);

    # generate namehash
    $self->process_namehash($citekey);

    # generate per-name hashes
    $self->process_pername_hashes($citekey);

  }

  if ($logger->is_debug()) {# performance tune
    $logger->debug("Finished processing entries in section $secnum (after uniqueness)");
  }

  return;
}

=head2 process_uniqueprimaryauthor

    Track seen primary author base names for generation of uniqueprimaryauthor

=cut

sub process_uniqueprimaryauthor {
  my $self = shift;
  my $citekey = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);

  if (my $lni = $be->get_labelname_info) {
    if (Biber::Config->getblxoption('uniqueprimaryauthor')) {
      my $nl = $be->get_field($lni);
      if ($logger->is_trace()) {# performance tune
        $logger->trace("Creating uniqueprimaryauthor information for '$citekey'");
      }
      my $paf = $nl->nth_name(1)->get_basenamestring;
      $be->set_field('seenprimaryauthor', $paf);
      Biber::Config->incr_seenpa($paf);
    }
  }
}

=head2 process_workuniqueness

    Track seen work combination for generation of singletitle, uniquetitle, uniquebaretitle and
    uniquework

=cut

sub process_workuniqueness {
  my $self = shift;
  my $citekey = shift;
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
  if ($lni and Biber::Config->getblxoption('singletitle', $bee)) {
    $identifier = $self->_getfullhash($citekey, $be->get_field($lni));

    # Skip due to ignore settings?
    # Don't count towards singletitle being false if both labelname and labeltitle
    # were inherited
    # Put another way, if both labelname and labeltitle were inherited, singletitle
    # can still be true (in a mvbook for example, which is just a single "work")
    unless (($lni and first {fc($lni) eq fc($_)} $ignore->{singletitle}->@*) and
            ($lti and first {fc($lti) eq fc($_)} $ignore->{singletitle}->@*)) {
      Biber::Config->incr_seenname($identifier);
      if ($logger->is_trace()) {# performance tune
        $logger->trace("Setting seenname for '$citekey' to '$identifier'");
      }
    }
    $be->set_field('seenname', $identifier);
  }

  # uniquetitle
  # Don't generate information for entries with no labeltitle
  if ($lti and Biber::Config->getblxoption('uniquetitle', $bee)) {
    $identifier = $be->get_field($lti);

    # Skip due to ignore settings?
    unless (first {fc($lti) eq fc($_)} $ignore->{uniquetitle}->@*) {
      Biber::Config->incr_seentitle($identifier);
      if ($logger->is_trace()) {  # performance tune
        $logger->trace("Setting seentitle for '$citekey' to '$identifier'");
      }
    }
    $be->set_field('seentitle', $identifier);
  }

  # uniquebaretitle
  # Don't generate information for entries with no labeltitle and with labelname
  if ($lti and not $lni and Biber::Config->getblxoption('uniquebaretitle', $bee)) {
    $identifier = $be->get_field($lti);

    # Skip due to ignore settings?
    unless (first {fc($lti) eq fc($_)} $ignore->{uniquebaretitle}->@*) {
      Biber::Config->incr_seenbaretitle($identifier);
      if ($logger->is_trace()) {  # performance tune
        $logger->trace("Setting seenbaretitle for '$citekey' to '$identifier'");
      }
    }
    $be->set_field('seenbaretitle', $identifier);
  }

  # uniquework
  # Don't generate information for entries with no labelname and labeltitle
  # Should use fullhash this is not a test of uniqueness of only visible information
  if ($lni and $lti and Biber::Config->getblxoption('uniquework', $bee)) {
    $identifier = $self->_getfullhash($citekey, $be->get_field($lni)) . $be->get_field($lti);

    # Skip due to ignore settings?
    unless (first {fc($lni) eq fc($_)} $ignore->{uniquework}->@* and
            first {fc($lti) eq fc($_)} $ignore->{uniquework}->@*) {
      Biber::Config->incr_seenwork($identifier);
      if ($logger->is_trace()) {  # performance tune
        $logger->trace("Setting seenwork for '$citekey' to '$identifier'");
      }
    }
    $be->set_field('seenwork', $identifier);
  }

  return;
}

=head2 process_extrayear

    Track labelname/year combination for generation of extrayear

=cut

sub process_extrayear {
  my $self = shift;
  my $citekey = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');

  # Generate labelname/year combination for tracking extrayear
  # * If there is no labelname to use, use empty string
  # * If there is no labelyear to use:
  #   * If there is no pubstate to use, use empty string otherwise use pubstate key
  # * Don't increment the seen_nameyear count if either name or year string is empty
  #   (see code in incr_seen_nameyear method).
  # * Don't increment if skiplab is set

  if (Biber::Config->getblxoption('labeldateparts', $bee)) {
    if (Biber::Config->getblxoption('skiplab', $bee, $citekey)) {
      return;
    }

    if ($logger->is_trace()) {# performance tune
      $logger->trace("Creating extrayear information for '$citekey'");
    }

    my $name_string = '';
    if (my $lni = $be->get_labelname_info) {
      $name_string = $self->_getnamehash_u($citekey, $be->get_field($lni));
    }

    # extrayear takes into account the labelyear which can be a range
    my $year_string = $be->get_field('labelyear') || $be->get_field('year') || '';

    my $nameyear_string = "$name_string,$year_string";
    if ($logger->is_trace()) {# performance tune
      $logger->trace("Setting nameyear to '$nameyear_string' for entry '$citekey'");
    }
    $be->set_field('nameyear', $nameyear_string);
    if ($logger->is_trace()) {# performance tune
      $logger->trace("Incrementing nameyear for '$name_string'");
    }
    Biber::Config->incr_seen_nameyear($name_string, $year_string);
  }

  return;
}

=head2 process_extratitle

    Track labelname/labeltitle combination for generation of extratitle

=cut

sub process_extratitle {
  my $self = shift;
  my $citekey = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');

  # Generate labelname/labeltitle combination for tracking extratitle
  # * If there is no labelname to use, use empty string
  # * If there is no labeltitle to use, use empty string
  # * Don't increment if skiplab is set

  # This is different from extrayear in that we do track the information
  # if the labelname is empty as titles are much more unique than years

  if (Biber::Config->getblxoption('labeltitle', $bee)) {
    if (Biber::Config->getblxoption('skiplab', $bee, $citekey)) {
      return;
    }

    if ($logger->is_trace()) {# performance tune
      $logger->trace("Creating extratitle information for '$citekey'");
    }

    my $name_string = '';
    if (my $lni = $be->get_labelname_info) {
      $name_string = $self->_getnamehash_u($citekey, $be->get_field($lni));
    }

    my $lti = $be->get_labeltitle_info;
    my $title_string = $be->get_field($lti) // '';

    my $nametitle_string = "$name_string,$title_string";
    if ($logger->is_trace()) {# performance tune
      $logger->trace("Setting nametitle to '$nametitle_string' for entry '$citekey'");
    }
    $be->set_field('nametitle', $nametitle_string);
    if ($logger->is_trace()) {# performance tune
      $logger->trace("Incrementing nametitle for '$name_string'");
    }
    Biber::Config->incr_seen_nametitle($name_string, $title_string);
  }

  return;
}

=head2 process_extratitleyear

    Track labeltitle/labelyear combination for generation of extratitleyear

=cut

sub process_extratitleyear {
  my $self = shift;
  my $citekey = shift;
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

  if (Biber::Config->getblxoption('labeltitleyear', $bee)) {
    if (Biber::Config->getblxoption('skiplab', $bee, $citekey)) {
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
    $be->set_field('titleyear', $titleyear_string);
    if ($logger->is_trace()) {# performance tune
      $logger->trace("Incrementing titleyear for '$title_string'");
    }
    Biber::Config->incr_seen_titleyear($title_string, $year_string);
  }

  return;
}


=head2 process_sets

    Postprocess set entries

    Checks for common set errors and enforces 'dataonly' for set members.
    It's not necessary to set skipbib, skipbiblist in the OPTIONS field for
    the set members as these are automatically set by biblatex due to the \inset

=cut

sub process_sets {
  my $self = shift;
  my $citekey = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  if (my @entrysetkeys = Biber::Config->get_set_children($citekey)) {
    # Enforce Biber parts of virtual "dataonly" for set members
    # Also automatically create an "entryset" field for the members
    foreach my $member (@entrysetkeys) {
      my $me = $section->bibentry($member);
      process_entry_options($member, [ 'skiplab', 'skipbiblist', 'uniquename=0', 'uniquelist=0' ]);

      if ($me->get_field('entryset')) {
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
    if (Biber::Config->get_set_parents($citekey)) {
      my $me = $section->bibentry($citekey);
      process_entry_options($citekey, [ 'skiplab', 'skipbiblist', 'uniquename=0', 'uniquelist=0' ]);
    }
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
  my $lnamespec = Biber::Config->getblxoption('labelnamespec', $bee);
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
       not Biber::Config->getblxoption("use$lnameopt", $bee, $citekey)) {
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
    unless (first {$ln eq $_} $dmh->{namelistsall}->@*) {
      next;
    }

    # If there is a biblatex option which controls the use of this labelname info, check it
    if ($CONFIG_OPTSCOPE_BIBLATEX{"use$ln"} and
       not Biber::Config->getblxoption("use$ln", $bee, $citekey)) {
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

    Generate labeldate information

=cut

sub process_labeldate {
  my $self = shift;
  my $citekey = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');
  my $dm = Biber::Config->get_dm;

  if (Biber::Config->getblxoption('labeldateparts', $bee)) {
    my $ldatespec = Biber::Config->getblxoption('labeldatespec', $bee);
    foreach my $lds ($ldatespec->@*) {
      my $pseudodate;
      my $ld = $lds->{content};
      if ($lds->{'type'} eq 'field') { # labeldate field
        my $ldy;
        my $ldm;
        my $ldd;
        my $datetype;

        # resolve dates
        $datetype = $ld =~ s/date\z//xmsr;
        if ($dm->field_is_datatype('date', $ld) and
            $be->get_field("${datetype}datesplit")) { # real EDTF dates
          $ldy = $datetype . 'year';
          $ldm = $datetype . 'month';
          $ldd = $datetype . 'day';
        }
        else { # non-EDTF split date field so make a pseudo-year
          $ldy = $ld;
          $pseudodate = 1;
        }

        # Did we find a labeldate?
        if ($be->get_field($ldy)) {
          # set source to field or date field prefix for a real date field
          $be->set_labeldate_info({'field' => {year       => $ldy,
                                               month      => $ldm,
                                               day        => $ldd,
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

    # Construct labelyear, labelmonth, labelday
    # Might not have been set due to skiplab/dataonly
    if (my $ldi = $be->get_labeldate_info) {
      if (my $df = $ldi->{field}) { # set labelyear to a field value
        my $pseudodate = $df->{pseudodate};
        my $yearstring = $be->get_field($df->{year});
        $be->set_field('labelyear', $yearstring);

        $be->set_field('labelmonth', $be->get_field($df->{month})) if $df->{month};
        $be->set_field('labelday', $be->get_field($df->{day})) if $df->{day};
        $be->set_field('labeldatesource', $df->{source});

        # ignore endyear if it's the same as year
        my ($ytype) = $df->{year} =~ /\A(\X*)year\z/xms;
        $ytype = $ytype // ''; # Avoid undef warnings since no match above can make it undef

        # endyear can be null which makes labelyear different to plain year
        if ($be->field_exists($ytype . 'endyear')
            and ($be->get_field($df->{year}) ne $be->get_field($ytype . 'endyear'))) {
          $be->set_field('labelyear',
                         $be->get_field('labelyear') . '\bibdatedash ' . $be->get_field($ytype . 'endyear'));
        }
        # pseudodates (fields which are not really dates per se) are just years
        if (not $pseudodate and
            $be->get_field($ytype . 'endmonth')
            and ($be->get_field($df->{month}) ne $be->get_field($ytype . 'endmonth'))) {
          $be->set_field('labelmonth',
                         $be->get_field('labelmonth') . '\bibdatedash ' . $be->get_field($ytype . 'endmonth'));
        }
        # pseudodates (fields which are not really dates per se) are just years
        if (not $pseudodate and
            $be->get_field($ytype . 'endday')
            and ($be->get_field($df->{day}) ne $be->get_field($ytype . 'endday'))) {
          $be->set_field('labelday',
                         $be->get_field('labelday') . '\bibdatedash ' . $be->get_field($ytype . 'endday'));
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

  my $ltitlespec = Biber::Config->getblxoption('labeltitlespec', $bee);

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
  my $self = shift;
  my $citekey = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $dmh = Biber::Config->get_dm_helpers;

  # namehash is generated from the labelname
  # This can't be resolved nicely by biblatex because it depends on use* options
  # and also SHORT* fields etc.
  if (my $lni = $be->get_labelname_info) {
    if (my $ln = $be->get_field($lni)) {
      $be->set_field('namehash', $self->_getnamehash($citekey, $ln));
    }
  }

  # Generate namehash for all other name fields
  foreach my $n ($dmh->{namelistsall}->@*) {
    next unless my $nv = $be->get_field($n);
    $be->set_field("${n}namehash", $self->_getnamehash($citekey, $nv));
  }

  return;
}


=head2 process_pername_hashes

    Generate per_name_hashes

=cut

sub process_pername_hashes {
  my $self = shift;
  my $citekey = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');
  my $dmh = Biber::Config->get_dm_helpers;

  foreach my $pn ($dmh->{namelistsall}->@*) {
    next unless my $names = $be->get_field($pn);
    foreach my $n ($names->names->@*) {
      $n->set_hash($self->_genpnhash($citekey, $n));
    }
  }
  return;
}


=head2 process_visible_names

    Generate the visible name information.
    This is used in various places and it is useful to have it generated in one place.

=cut

sub process_visible_names {
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $dmh = Biber::Config->get_dm_helpers;

  if ($logger->is_debug()) {# performance tune
    $logger->debug("Postprocessing visible names for section $secnum");
  }
  foreach my $citekey ($section->get_citekeys) {
    my $be = $section->bibentry($citekey);
    my $bee = $be->get_field('entrytype');

    my $maxcn = Biber::Config->getblxoption('maxcitenames', $bee, $citekey);
    my $mincn = Biber::Config->getblxoption('mincitenames', $bee, $citekey);
    my $maxbn = Biber::Config->getblxoption('maxbibnames', $bee, $citekey);
    my $minbn = Biber::Config->getblxoption('minbibnames', $bee, $citekey);
    my $maxan = Biber::Config->getblxoption('maxalphanames', $bee, $citekey);
    my $minan = Biber::Config->getblxoption('minalphanames', $bee, $citekey);

    foreach my $n ($dmh->{namelistsall}->@*) {
      next unless my $names = $be->get_field($n);

      my $count = $names->count_names;
      my $visible_names_cite;
      my $visible_names_bib;
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
      my $l_minan = $count < $minan ? $count : $minan;

      # If name list was truncated in bib with "and others", this overrides maxcitenames
      my $morenames = $names->get_morenames ? 1 : 0;

      # max/minalphanames doesn't care about uniquelist - labels are just labels
      if ( $morenames or $count > $maxan ) {
        $visible_names_alpha = $l_minan;
      }
      else {
        $visible_names_alpha = $count;
      }

      # max/mincitenames
      if ( $morenames or $count > $maxcn ) {
        # Visibiliy to the uniquelist point if uniquelist is requested
        # We know at this stage that if uniquelist is set, there are more than maxcitenames
        # names. We also know that uniquelist > mincitenames because it is a further disambiguation
        # on top of mincitenames so can't be less as you can't disambiguate by losing information
        $visible_names_cite = $names->get_uniquelist // $l_mincn;
      }
      else { # visibility is simply the full list
        $visible_names_cite = $count;
      }

      # max/minbibnames
      if ( $morenames or $count > $maxbn ) {
        # Visibiliy to the uniquelist point if uniquelist is requested
        # We know at this stage that if uniquelist is set, there are more than maxbibnames
        # names. We also know that uniquelist > mincitenames because it is a further disambiguation
        # on top of mincitenames so can't be less as you can't disambiguate by losing information
        $visible_names_bib = $names->get_uniquelist // $l_minbn;
      }
      else { # visibility is simply the full list
        $visible_names_bib = $count;
      }

      if ($logger->is_trace()) { # performance shortcut
        if ($logger->is_trace()) {# performance tune
          $logger->trace("Setting visible names (cite) for key '$citekey' to '$visible_names_cite'");
          $logger->trace("Setting visible names (bib) for key '$citekey' to '$visible_names_bib'");
          $logger->trace("Setting visible names (alpha) for key '$citekey' to '$visible_names_alpha'");
        }
      }

      # Need to set these on all name forms
      my $ns = $be->get_field($n);
      $ns->set_visible_cite($visible_names_cite);
      $ns->set_visible_bib($visible_names_bib);
      $ns->set_visible_alpha($visible_names_alpha);
    }
  }
}


=head2 process_labelalpha

    Generate the labelalpha and also the variant for sorting

=cut

sub process_labelalpha {
  my $self = shift;
  my $citekey = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');
  # Don't add a label if skiplab is set for entry
  if (Biber::Config->getblxoption('skiplab', $bee, $citekey)) {
    return;
  }
  if ( my $la = Biber::Config->getblxoption('labelalpha', $be->get_field('entrytype')) ) {
    my $label;
    my $sortlabel;
    ( $label, $sortlabel ) = $self->_genlabel($citekey)->@*;
    $be->set_field('labelalpha', $label);
    $be->set_field('sortlabelalpha', $sortlabel);
  }
}

=head2 process_extraalpha

    Generate the extraalpha information

=cut

sub process_extraalpha {
  my $self = shift;
  my $citekey = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');
  if (Biber::Config->getblxoption('labelalpha', $be->get_field('entrytype'))) {
    if (my $la = $be->get_field('labelalpha')) {
      Biber::Config->incr_la_disambiguation($la);
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
    Biber::Config->setblxoption('presort', $ps, 'ENTRY', $citekey);
  }
}

=head2 process_lists

    Sort and filter lists for a section

=cut

sub process_lists {
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  foreach my $list ($self->sortlists->get_lists_for_section($secnum)->@*) {
    my $lssn = $list->get_sortschemename;
    my $lsnksn = $list->get_sortnamekeyschemename;
    my $ltype = $list->get_type;
    my $lname = $list->get_name;
    # Last-ditch fallback in case we still don't have a sorting spec
    $list->set_sortscheme(Biber::Config->getblxoption('sorting')) unless $list->get_sortscheme;
    $list->set_sortnamekeyschemename('global') unless $list->get_sortnamekeyschemename;

    $list->set_keys([ $section->get_citekeys ]);
    if ($logger->is_debug()) {# performance tune
      $logger->debug("Populated sortlist '$lname' of type '$ltype' with sortscheme '$lssn' and sorting name key scheme '$lsnksn' in section $secnum with keys: " . join(', ', $list->get_keys));
    }

    # Now we check the sorting cache to see if we already have results
    # for this scheme since sorting is computationally expensive.
    # We know the keys are the same as we just set them
    # to a copy of the section citekeys above. If the scheme is the same
    # as a previous sort then the results have to also be the same so inherit
    # the results which are normally set by sorting:
    #
    # * sorted keys
    # * sortinit data
    # * extra* data

    my $cache_flag = 0;
    if ($logger->is_debug()) {# performance tune
      $logger->debug("Checking sorting cache for scheme '$lssn' with sorting name key scheme '$lsnksn'");
    }
    foreach my $cacheitem ($section->get_sort_cache->@*) {
      # This conditional checks for identity of the data elements which constitute
      # a biblatex refcontext since a sortlist is conceptually part of a refcontext
      if (Compare($list->get_sortscheme, $cacheitem->[0]) and
          $list->get_sortnamekeyschemename eq $cacheitem->[1] and
          $list->get_labelprefix eq $cacheitem->[2]) {
        if ($logger->is_debug()) {# performance tune
          $logger->debug("Found sorting cache entry for scheme '$lssn' with sorting name key scheme '$lsnksn'");
        }
        if ($logger->is_trace()) {# performance tune
          $logger->trace("Sorting list cache for scheme '$lssn' with sorting name key scheme '$lsnksn':\n-------------------\n" . Data::Dump::pp($list->get_sortscheme) . "\n-------------------\n");
        }
        $list->set_sortnamekeyschemename($cacheitem->[1]);
        $list->set_labelprefix($cacheitem->[2]);
        $list->set_keys($cacheitem->[3]);
        $list->set_sortinitdata($cacheitem->[4]);
        $list->set_extrayeardata($cacheitem->[5]);
        $list->set_extraalphadata($cacheitem->[6]);
        $list->set_extratitledata($cacheitem->[7]);
        $list->set_extratitleyeardata($cacheitem->[8]);
        $list->set_sortdataschema($cacheitem->[9]);
        $cache_flag = 1;
        last;
      }
    }

    unless ($cache_flag) {
      if ($logger->is_debug()) {# performance tune
        $logger->debug("No sorting cache entry for scheme '$lssn' with sorting name key scheme '$lsnksn'");
      }
      # Sorting
      $self->generate_sortdataschema($list); # generate the sort information
      $self->generate_sortinfo($list);       # generate the sort information
      $self->sort_list($list);               # sort the list
      $self->generate_extra($list) unless Biber::Config->getoption('tool'); # generate the extra* fields

      # Cache the results
      if ($logger->is_debug()) {# performance tune
        $logger->debug("Adding sorting cache entry for scheme '$lssn' with sorting name key scheme '$lsnksn'");
      }
      $section->add_sort_cache($list->get_listdata);
    }

    # Filtering
    if (my $filters = $list->get_filters) {
      my $flist = [];
KEYLOOP: foreach my $k ($list->get_keys) {

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
      if ($logger->is_debug()) {# performance tune
        $logger->debug("Keys after filtering list '$lname' in section $secnum: " . join(', ', $flist->@*));
      }
      $list->set_keys($flist); # Now save the sorted list in the list object
    }
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
  foreach my $sort ($list->get_sortscheme->{spec}->@*) {
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
  my ($self, $list) = @_;

  foreach my $key ($list->get_keys) {
    $self->_generatesortinfo($key, $list);
  }
  return;
}

=head2 uniqueness

    Generate the uniqueness information needed when creating .bbl

=cut

sub uniqueness {
  my $self = shift;
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
    unless (Biber::Config->get_unul_done) {
      Biber::Config->set_unul_changed(0); # reset state for global unul changed flag
      $self->create_uniquename_info;
      $self->generate_uniquename;
    }
    else {
      last; # uniquename/uniquelist disambiguation is finished as nothing changed
    }
    # Generate uniquelist information, if requested
    # Always run uniquelist at least once, if requested
    if ($first_ul_pass or not Biber::Config->get_unul_done) {
      Biber::Config->set_unul_changed(0); # reset state for global unul changed flag
      $first_ul_pass = 0; # Ignore special case when uniquelist has run once
      $self->create_uniquelist_info;
      $self->generate_uniquelist;
    }
    else {
      last; # uniquename/uniquelist disambiguation is finished as nothing changed
    }
  }
  return;
}


=head2 create_uniquename_info

    Gather the uniquename information as we look through the names

    What is happening in here is the following:
    We are registering the number of occurrences of each name, name+init and fullname
    within a specific context. For example, the context is "global" with uniquename < 5
    and "name list" for uniquename=5 or 6. The keys we store to count this are the most specific
    information for the context, so, for uniquename < 5, this is the full name and for
    uniquename=5 or 6, this is the complete list of full names. These keys have values in a hash
    which are ignored. They serve only to accumulate repeated occurrences with the context
    and we don't care about this and so the values are a useful sinkhole for such repetition.

    For example, if we find in the global context a base name "Smith" in two different entries
    under the same form "Alan Smith", the data structure will look like:

    {Smith}->{global}->{Alan Smith} = 2

    We don't care about the value as this means that there are 2 "Alan Smith"s in the global
    context which need disambiguating identically anyway. So, we just count the keys for the
    base name "Smith" in the global context to see how ambiguous the base name itself is. This
    would be "1" and so "Alan Smith" would get uniquename=0 because it's unambiguous as just
    "Smith".

    The same goes for "minimal" list context disambiguation for uniquename=5 or 6.
    For example, if we had the base name "Smith" to disambiguate in two entries with labelname
    "John Smith and Alan Jones", the data structure would look like:

    {Smith}->{Smith+Jones}->{John Smith+Alan Jones} = 2

    Again, counting the keys of the context for the base name gives us "1" which means we
    have uniquename=0 for "John Smith" in both entries because it's the same list. This also
    works for repeated names in the same list "John Smith and Bert Smith". Disambiguating
    "Smith" in this:

    {Smith}->{Smith+Smith}->{John Smith+Bert Smith} = 2

    So both "John Smith" and "Bert Smith" in this entry get uniquename=0 (of course, as long as
    there are no other "X Smith and Y Smith" entries where X != "John" or Y != "Bert").

=cut

sub create_uniquename_info {
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bibentries;

  # Reset uniquename information as we have to generate it
  # again because uniquelist information might have changed
  Biber::Config->reset_uniquenamecount;

  foreach my $citekey ( $section->get_citekeys ) {
    my $be = $bibentries->entry($citekey);
    my $bee = $be->get_field('entrytype');

    next unless my $un = Biber::Config->getblxoption('uniquename', $bee, $citekey);

    if ($logger->is_trace()) {# performance tune
      $logger->trace("Generating uniquename information for '$citekey'");
    }

    if (my $lni = $be->get_labelname_info) {

      # Set the index limit beyond which we don't look for disambiguating information
      my $ul = undef;           # Not set
      if (defined($be->get_field($lni)->get_uniquelist)) {
        # If defined, $ul will always be >1, see comment in set_uniquelist() in Names.pm
        $ul = $be->get_field($lni)->get_uniquelist;
      }
      my $maxcn = Biber::Config->getblxoption('maxcitenames', $bee, $citekey);
      my $mincn = Biber::Config->getblxoption('mincitenames', $bee, $citekey);

      # Note that we don't determine if a name is unique here -
      # we can't, were still processing entries at this point.
      # Here we are just recording seen combinations of:
      #
      # base name and how many name context keys contain this (uniquename = 0)
      # basenames+initials and how many name context keys contain this (uniquename = 1)
      # Full name and how many name context keys contain this (uniquename = 2)
      #
      # A name context can be either a complete single name or a list of names
      # depending on whether uniquename=min* or not
      #
      # Anything which has more than one combination for both of these would
      # be uniquename = 2 unless even the full name doesn't disambiguate
      # and then it is left at uniquename = 0

      my $nl = $be->get_field($lni);
      my $num_names = $nl->count_names;
      my $names = $nl->names;
      # If name list was truncated in bib with "and others", this overrides maxcitenames
      my $morenames = $nl->get_morenames ? 1 : 0;

      my @truncnames;
      my @basenames;
      my @fullnames;
      my @initnames;

      foreach my $name ($names->@*) {
        # We need to track two types of uniquename disambiguation here:
        #
        # 1. Information to disambiguate visible names from visible names
        #    where "visibility" is governed by uniquelist/max/mincitenames.
        #    This is the actual "uniquename" feature information.
        # 2. Information to disambiguate all names, regardless of visibility
        #    This is needed for uniquelist because it needs to construct
        #    hypothetical ambiguity information for every list position.

        # We want to record disambiguation information for visible names when:
        # uniquename = 3 (allinit) or 4 (allfull)
        # Uniquelist is set and a name appears before the uniquelist truncation
        # Uniquelist is not set and the entry has an explicit "and others" at the end
        #   since this means that every name is less than maxcitenames by definition
        # Uniquelist is not set and a name list is shorter than the maxcitenames truncation
        # Uniquelist is not set, a name list is longer than the maxcitenames truncation
        #   and the name appears before the mincitenames truncation
        if ($un == 3 or $un == 4 or
            ($ul and $name->get_index <= $ul) or
            $morenames or
            $num_names <= $maxcn or
            $name->get_index <= $mincn) { # implicitly, $num_names > $maxcn here

          push @truncnames, $name;
          if ($un == 5 or $un == 6) {
            push @basenames, $name->get_basenamestring;
            push @fullnames, $name->get_namestring;
            push @initnames, $name->get_nameinitstring;
          }
        }
      }
      # Information for mininit ($un=5) or minfull ($un=6)
      my $basenames_string;
      my $fullnames_string;
      my $initnames_string;
      if ($un == 5) {
        $basenames_string = join("\x{10FFFD}", @basenames);
        $initnames_string = join("\x{10FFFD}", @initnames);
        if ($#basenames + 1 < $num_names or
            $morenames) {
          $basenames_string .= "\x{10FFFD}et al"; # if truncated, record this
          $initnames_string .= "\x{10FFFD}et al"; # if truncated, record this
        }
      }
      elsif ($un == 6) {
        $basenames_string = join("\x{10FFFD}", @basenames);
        $fullnames_string = join("\x{10FFFD}", @fullnames);
        if ($#basenames + 1 < $num_names or
            $morenames) {
          $basenames_string .= "\x{10FFFD}et al"; # if truncated, record this
          $fullnames_string .= "\x{10FFFD}et al"; # if truncated, record this
        }
      }

      foreach my $name ($names->@*) {
        my $basename = $name->get_basenamestring;
        my $nameinitstring = $name->get_nameinitstring;
        my $namestring     = $name->get_namestring;
        my $namecontext;
        my $key;

        # Context and key depend on the uniquename setting
        if ($un == 1 or $un == 3) {
          $namecontext = 'global';
          $key = $nameinitstring;
        }
        elsif ($un == 2 or $un == 4) {
          $namecontext = 'global';
          $key = $namestring;
        }
        elsif ($un == 5) {
          $namecontext = $basenames_string;
          $key = $initnames_string;
          $name->set_minimal_info($basenames_string);
        }
        elsif ($un == 6) {
          $namecontext = $basenames_string;
          $key = $fullnames_string;
          $name->set_minimal_info($basenames_string);
        }
        if (first {Compare($_, $name)} @truncnames) {
          # Record a uniqueness information entry for the base name showing that
          # this base name has been seen in this name context
          Biber::Config->add_uniquenamecount($basename, $namecontext, $key);

          # Record a uniqueness information entry for the basename+initials showing that
          # this basename_initials has been seen in this name context
          Biber::Config->add_uniquenamecount($nameinitstring, $namecontext, $key);

          # Record a uniqueness information entry for the fullname
          # showing that this fullname has been seen in this name context
          Biber::Config->add_uniquenamecount($namestring, $namecontext, $key);
        }

        # As above but here we are collecting (separate) information for all
        # names, regardless of visibility (needed to track uniquelist)
        if (Biber::Config->getblxoption('uniquelist', $bee, $citekey)) {
          Biber::Config->add_uniquenamecount_all($basename, $namecontext, $key);
          Biber::Config->add_uniquenamecount_all($nameinitstring, $namecontext, $key);
          Biber::Config->add_uniquenamecount_all($namestring, $namecontext, $key);
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
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bibentries;

  # Now use the information to set the actual uniquename information
  foreach my $citekey ( $section->get_citekeys ) {
    my $be = $bibentries->entry($citekey);
    my $bee = $be->get_field('entrytype');

    next unless my $un = Biber::Config->getblxoption('uniquename', $bee, $citekey);

    if ($logger->is_trace()) {# performance tune
      $logger->trace("Setting uniquename for '$citekey'");
    }

    if (my $lni = $be->get_labelname_info) {
      # Set the index limit beyond which we don't look for disambiguating information

      # If defined, $ul will always be >1, see comment in set_uniquelist() in Names.pm
      my $ul = $be->get_field($lni)->get_uniquelist;

      my $maxcn = Biber::Config->getblxoption('maxcitenames', $bee, $citekey);
      my $mincn = Biber::Config->getblxoption('mincitenames', $bee, $citekey);

      my $nl = $be->get_field($lni);
      my $num_names = $nl->count_names;
      my $names = $nl->names;
      # If name list was truncated in bib with "and others", this overrides maxcitenames
      my $morenames = ($nl->get_morenames) ? 1 : 0;

      my @truncnames;

      foreach my $name ($names->@*) {
        if ($un == 3 or $un == 4 or
            ($ul and $name->get_index <= $ul) or
            $morenames or
            $num_names <= $maxcn or
            $name->get_index <= $mincn) { # implicitly, $num_names > $maxcn here
          push @truncnames, $name;
        }
        else {
          # Set anything now not visible due to uniquelist back to 0
          $name->reset_uniquename;
        }
      }

      foreach my $name ($names->@*) {
        my $basename = $name->get_basenamestring;
        my $nameinitstring = $name->get_nameinitstring;
        my $namestring = $name->get_namestring;
        my $namecontext = 'global'; # default
        if ($un == 5 or $un == 6) {
          $namecontext = $name->get_minimal_info; # $un=5 and 6
        }

        if (first {Compare($_, $name)} @truncnames) {

          # If there is one key for the base name, then it's unique using just base name
          # because either:
          # * There are no other identical base names
          # * All identical base names have a basename+init ($un=5) or fullname ($un=6)
          #   which is identical and therefore can't be disambiguated any further anyway
          if (Biber::Config->get_numofuniquenames($basename, $namecontext) == 1) {
            $name->set_uniquename(0);
          }
          # Otherwise, if there is one key for the base name+inits, then it's unique
          # using initials because either:
          # * There are no other identical  basename+inits
          # * All identical basename+inits have a fullname ($un=6) which is identical
          #   and therefore can't be disambiguated any further anyway
          elsif (Biber::Config->get_numofuniquenames($nameinitstring, $namecontext) == 1) {
            $name->set_uniquename(1);
          }
          # Otherwise if there is one key for the fullname, then it's unique using
          # the fullname because:
          # * There are no other identical full names
          #
          # But restrict to uniquename biblatex option maximum
          elsif (Biber::Config->get_numofuniquenames($namestring, $namecontext) == 1) {
            my $run;
            if ($un == 1)    {$run = 1}   # init
            elsif ($un == 2) {$run = 2}   # full
            elsif ($un == 3) {$run = 1}   # allinit
            elsif ($un == 4) {$run = 2}   # allfull
            elsif ($un == 5) {$run = 1}   # mininit
            elsif ($un == 6) {$run = 2}   # minfull
            $name->set_uniquename($run)
          }
          # Otherwise, there must be more than one key for the full name,
          # so set to 0 since nothing will uniqueify this name and it's just
          # misleading to expand it
          else {
            $name->set_uniquename(0);
          }
        }

        # As above but not just for visible names (needed for uniquelist)
        if (Biber::Config->getblxoption('uniquelist', $bee, $citekey)) {
          if (Biber::Config->get_numofuniquenames_all($basename, $namecontext) == 1) {
            $name->set_uniquename_all(0);
          }
          elsif (Biber::Config->get_numofuniquenames_all($nameinitstring, $namecontext) == 1) {
            $name->set_uniquename_all(1);
          }
          elsif (Biber::Config->get_numofuniquenames_all($namestring, $namecontext) == 1) {
            my $run;
            if ($un == 1) {$run = 1}   # init
            elsif ($un == 2) {$run = 2}   # full
            elsif ($un == 3) {$run = 1}   # allinit
            elsif ($un == 4) {$run = 2}   # allfull
            elsif ($un == 5) {$run = 1}   # mininit
            elsif ($un == 6) {$run = 2}   # minfull
            $name->set_uniquename_all($run)
          }
          else {
            $name->set_uniquename_all(0);
          }
        }
      }
    }
  }
  return;
}

=head2 create_uniquelist_info

    Gather the uniquelist information as we look through the names

=cut

sub create_uniquelist_info {
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bibentries;

  # Reset uniquelist information as we have to generate it again because uniquename
  # information might have changed
  Biber::Config->reset_uniquelistcount;

  foreach my $citekey ( $section->get_citekeys ) {
    my $be = $bibentries->entry($citekey);
    my $bee = $be->get_field('entrytype');
    my $maxcn = Biber::Config->getblxoption('maxcitenames', $bee, $citekey);
    my $mincn = Biber::Config->getblxoption('mincitenames', $bee, $citekey);

    next unless my $ul = Biber::Config->getblxoption('uniquelist', $bee, $citekey);

    if ($logger->is_trace()) {# performance tune
      $logger->trace("Generating uniquelist information for '$citekey'");
    }

    if (my $lni = $be->get_labelname_info) {
      my $nl = $be->get_field($lni);
      my $num_names = $nl->count_names;
      my $namelist = [];
      my $ulminyear_namelist = [];

      foreach my $name ($nl->names->@*) {

        my $basename = $name->get_basenamestring;
        my $nameinitstring = $name->get_nameinitstring;
        my $namestring = $name->get_namestring;
        my $ulminyearflag = 0;

        # uniquelist = minyear
        if ($ul == 2) {
          # minyear uniquename, we set based on the max/mincitenames list
          if ($num_names > $maxcn and
              $name->get_index <= $mincn) {
            $ulminyearflag = 1;
          }
        }

        # uniquename is not set so generate uniquelist based on just base name
        if (not defined($name->get_uniquename_all)) {
          push $namelist->@*, $basename;
          push $ulminyear_namelist->@*, $basename if $ulminyearflag;
        }
        # uniquename indicates unique with just base name
        elsif ($name->get_uniquename_all == 0) {
          push $namelist->@*, $basename;
          push $ulminyear_namelist->@*, $basename if $ulminyearflag;
        }
        # uniquename indicates unique with base name with initials
        elsif ($name->get_uniquename_all == 1) {
          push $namelist->@*, $nameinitstring;
          push $ulminyear_namelist->@*, $nameinitstring if $ulminyearflag;
        }
        # uniquename indicates unique with full name
        elsif ($name->get_uniquename_all == 2) {
          push $namelist->@*, $namestring;
          push $ulminyear_namelist->@*, $namestring if $ulminyearflag;
        }

        Biber::Config->add_uniquelistcount($namelist);
      }
      # We need to know the list uniqueness counts for the whole list seperately otherwise
      # we will falsely "disambiguate" identical name lists from each other by setting
      # uniquelist to the full list because every part of each list will have more than
      # one count. We therefore need to distinguish counts which are of the final, complete
      # list of names. If there is more than one count for these, (meaning that there are
      # two or more identical name lists), we don't expand them at all as there is no point.
      Biber::Config->add_uniquelistcount_final($namelist);

      # Add count for uniquelist=minyear
      unless (Compare($ulminyear_namelist, [])) {
        Biber::Config->add_uniquelistcount_minyear($ulminyear_namelist, $be->get_field('labelyear'), $namelist);
      }
    }
  }
  return;
}


=head2 generate_uniquelist

   Generate the per-namelist uniquelist values using the information
   harvested by create_uniquelist_info()

=cut

sub generate_uniquelist {
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bibentries;

LOOP: foreach my $citekey ( $section->get_citekeys ) {
    my $be = $bibentries->entry($citekey);
    my $bee = $be->get_field('entrytype');
    my $maxcn = Biber::Config->getblxoption('maxcitenames', $bee, $citekey);
    my $mincn = Biber::Config->getblxoption('mincitenames', $bee, $citekey);

    next unless my $ul = Biber::Config->getblxoption('uniquelist', $bee, $citekey);

    if ($logger->is_trace()) {# performance tune
      $logger->trace("Creating uniquelist for '$citekey'");
    }

    if (my $lni = $be->get_labelname_info) {
      my $nl = $be->get_field($lni);
      my $namelist = [];
      my $num_names = $nl->count_names;

      foreach my $name ($nl->names->@*) {

        my $basename = $name->get_basenamestring;
        my $nameinitstring = $name->get_nameinitstring;
        my $namestring = $name->get_namestring;

        # uniquename is not set so generate uniquelist based on just base name
        if (not defined($name->get_uniquename_all)) {
          push $namelist->@*, $basename;
        }
        # uniquename indicates unique with just base name
        elsif ($name->get_uniquename_all == 0) {
          push $namelist->@*, $basename;
        }
        # uniquename indicates unique with base name with initials
        elsif ($name->get_uniquename_all == 1) {
          push $namelist->@*, $nameinitstring;
        }
        # uniquename indicates unique with full name
        elsif ($name->get_uniquename_all == 2) {
          push $namelist->@*, $namestring;
        }

        # With uniquelist=minyear, uniquelist should not be set at all if there are
        # no other entries with the same max/mincitenames visible list and different years
        # to disambiguate from
        if ($ul == 2 and
            $num_names > $maxcn and
            $name->get_index <= $mincn and
            Biber::Config->get_uniquelistcount_minyear($namelist, $be->get_field('labelyear')) == 1) {
          if ($logger->is_trace()) {# performance tune
            $logger->trace("Not setting uniquelist=minyear for '$citekey'");
          }
          next LOOP;
        }

        # list is unique after this many names so we set uniquelist to this point
        # Even if uniquelist=minyear, we record normal uniquelist information if
        # we didn't skip this key in the test above
        if (Biber::Config->get_uniquelistcount($namelist) == 1) {
          last;
        }
      }

      if ($logger->is_trace()) {# performance tune
        $logger->trace("Setting uniquelist for '$citekey' using " . join(',', $namelist->@*));
        $logger->trace("Uniquelist count for '$citekey' is '" . Biber::Config->get_uniquelistcount_final($namelist) . "'");
      }
      $nl->set_uniquelist($namelist, $maxcn, $mincn);
    }
  }
  return;
}


=head2 generate_extra

    Generate information for:

      * extraalpha
      * extrayear
      * extratitle
      * extratitleyear

=cut

sub generate_extra {
  my $self = shift;
  my $list = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);

  Biber::Config->reset_seen_extra(); # Since this sub is per-list, have to reset the
                                     # extra* counters per list
  # This loop critically depends on the order of the citekeys which
  # is why we have to do sorting before this
  foreach my $key ($list->get_keys) {
    my $be = $section->bibentry($key);
    my $bee = $be->get_field('entrytype');
    # Only generate extra* information if skiplab is not set.
    # Don't forget that skiplab is implied for set members
    unless (Biber::Config->getblxoption('skiplab', $bee, $key)) {
      # extrayear
      if (Biber::Config->getblxoption('labeldateparts', $bee)) {
        my $nameyear = $be->get_field('nameyear');
        if (Biber::Config->get_seen_nameyear($nameyear) > 1) {
          if ($logger->is_trace()) {# performance tune
            $logger->trace("nameyear for '$nameyear': " . Biber::Config->get_seen_nameyear($nameyear));
          }
          my $v = Biber::Config->incr_seen_extrayear($nameyear);
          $list->set_extrayeardata_for_key($key, $v);
        }
      }
      # extratitle
      if (Biber::Config->getblxoption('labeltitle', $bee)) {
        my $nametitle = $be->get_field('nametitle');
        if (Biber::Config->get_seen_nametitle($nametitle) > 1) {
          if ($logger->is_trace()) {# performance tune
            $logger->trace("nametitle for '$nametitle': " . Biber::Config->get_seen_nametitle($nametitle));
          }
          my $v = Biber::Config->incr_seen_extratitle($nametitle);
          $list->set_extratitledata_for_key($key, $v);
        }
      }
      # extratitleyear
      if (Biber::Config->getblxoption('labeltitleyear', $bee)) {
        my $titleyear = $be->get_field('titleyear');
        if (Biber::Config->get_seen_titleyear($titleyear) > 1) {
          if ($logger->is_trace()) {# performance tune
            $logger->trace("titleyear for '$titleyear': " . Biber::Config->get_seen_titleyear($titleyear));
          }
          my $v = Biber::Config->incr_seen_extratitleyear($titleyear);
          $list->set_extratitleyeardata_for_key($key, $v);
        }
      }
      # extraalpha
      if (Biber::Config->getblxoption('labelalpha', $bee)) {
        my $la = $be->get_field('labelalpha');
        if (Biber::Config->get_la_disambiguation($la) > 1) {
          if ($logger->is_trace()) {# performance tune
            $logger->trace("labelalpha disambiguation for '$la': " . Biber::Config->get_la_disambiguation($la));
          }
          my $v = Biber::Config->incr_seen_extraalpha($la);
          $list->set_extraalphadata_for_key($key, $v);
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
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bibentries;

  foreach my $citekey ( $section->get_citekeys ) {
    my $be = $bibentries->entry($citekey);
    if (Biber::Config->getblxoption('singletitle', $be->get_field('entrytype'))) {
      if ($be->get_field('seenname') and
          Biber::Config->get_seenname($be->get_field('seenname')) < 2 ) {
        if ($logger->is_trace()) {# performance tune
          $logger->trace("Setting singletitle for '$citekey'");
        }
        $be->set_field('singletitle', 1);
      }
      else {
        if ($logger->is_trace()) {# performance tune
          $logger->trace("Not setting singletitle for '$citekey'");
        }
      }
    }
  }
  return;
}

=head2 generate_uniquetitle

    Generate the uniquetitle field, if requested. The information for generating
    this is gathered in process_workuniqueness()

=cut

sub generate_uniquetitle {
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bibentries;

  foreach my $citekey ( $section->get_citekeys ) {
    my $be = $bibentries->entry($citekey);
    if (Biber::Config->getblxoption('uniquetitle', $be->get_field('entrytype'))) {
      if ($be->get_field('seentitle') and
          Biber::Config->get_seentitle($be->get_field('seentitle')) < 2 ) {
        if ($logger->is_trace()) {# performance tune
          $logger->trace("Setting uniquetitle for '$citekey'");
        }
        $be->set_field('uniquetitle', 1);
      }
      else {
        if ($logger->is_trace()) {# performance tune
          $logger->trace("Not setting uniquetitle for '$citekey'");
        }
      }
    }
  }
  return;
}

=head2 generate_uniquebaretitle

    Generate the uniquebaretitle field, if requested. The information for generating
    this is gathered in process_workuniqueness()

=cut

sub generate_uniquebaretitle {
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bibentries;

  foreach my $citekey ( $section->get_citekeys ) {
    my $be = $bibentries->entry($citekey);
    if (Biber::Config->getblxoption('uniquebaretitle', $be->get_field('entrytype'))) {
      if ($be->get_field('seenbaretitle') and
          Biber::Config->get_seenbaretitle($be->get_field('seenbaretitle')) < 2 ) {
        if ($logger->is_trace()) {# performance tune
          $logger->trace("Setting uniquebaretitle for '$citekey'");
        }
        $be->set_field('uniquebaretitle', 1);
      }
      else {
        if ($logger->is_trace()) {# performance tune
          $logger->trace("Not setting uniquebaretitle for '$citekey'");
        }
      }
    }
  }
  return;
}

=head2 generate_uniquework

    Generate the uniquework field, if requested. The information for generating
    this is gathered in process_workuniqueness()

=cut

sub generate_uniquework {
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bibentries;

  foreach my $citekey ( $section->get_citekeys ) {
    my $be = $bibentries->entry($citekey);
    if (Biber::Config->getblxoption('uniquework', $be->get_field('entrytype'))) {
      if ($be->get_field('seenwork') and
          Biber::Config->get_seenwork($be->get_field('seenwork')) < 2 ) {
        if ($logger->is_trace()) {# performance tune
          $logger->trace("Setting uniquework for '$citekey'");
        }
        $be->set_field('uniquework', 1);
      }
      else {
        if ($logger->is_trace()) {# performance tune
          $logger->trace("Not setting uniquework for '$citekey'");
        }
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
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bibentries;

  foreach my $citekey ( $section->get_citekeys ) {
    my $be = $bibentries->entry($citekey);
    if (Biber::Config->getblxoption('uniqueprimaryauthor')) {
      if ($be->get_field('seenprimaryauthor') and
          Biber::Config->get_seenpa($be->get_field('seenprimaryauthor')) < 2 ) {
        if ($logger->is_trace()) {# performance tune
          $logger->trace("Setting uniqueprimaryauthor for '$citekey'");
        }
        $be->set_field('uniqueprimaryauthor', 1);
      }
      else {
        if ($logger->is_trace()) {# performance tune
          $logger->trace("Not setting uniqueprimaryauthor for '$citekey'");
        }
      }
    }
  }
  return;
}

=head2 sort_list

    Sort a list using information in entries according to a certain sorting scheme.
    Use a flag to skip info messages on first pass

=cut

sub sort_list {
  my $self = shift;
  my $list = shift;
  my $sortscheme = $list->get_sortscheme;
  my $lsds  = $list->get_sortdataschema;
  my @keys = $list->get_keys;
  my $lssn = $list->get_sortschemename;
  my $ltype = $list->get_type;
  my $lname = $list->get_name;
  my $llocale = locale2bcp47($sortscheme->{locale} || Biber::Config->getblxoption('sortlocale'));
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
      $logger->debug("$k => " . $list->get_sortdata($k)->[0]);
    }
  }

  if ($logger->is_trace()) { # performance shortcut
    $logger->trace("Sorting sortlist '$lname' of type '$ltype' with sortscheme '$lssn'. Scheme is\n-------------------\n" . Data::Dump::pp($sortscheme) . "\n-------------------\n");
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
  $logger->info("Sorting list '$lname' of type '$ltype' with scheme '$lssn' and locale '$thislocale'");
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
  foreach my $sortset ($sortscheme->{spec}->@*) {
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
    for (my $i=0; $i<=$#{$list->get_sortdata($key)->[1]}; $i++) {
      my $sortfield = $list->get_sortdata($key)->[1][$i];
      # Resolve real zeros back again
      if ($lsds->[$i]{int}) {
        # There is special cases to be careful of here in that "final" elements
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
        my $a = $collateobjs[$i] . "->getSortKey('$sortfield')";
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
      $logger->debug("$k => " . $list->get_sortdata($k)->[0]);
    }
  }

  $list->set_keys([ @keys ]);

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

    $section->reset_caches;              # Reset the the section caches (sorting, label etc.)
    Biber::Config->_init;                # (re)initialise Config object
    $self->set_current_section($secnum); # Set the section number we are working on
    $self->preprocess_options;           # Preprocess any options
    $self->fetch_data;                   # Fetch cited key and dependent data from sources
    $self->process_citekey_aliases;      # Remove citekey aliases from citekeys
    $self->instantiate_dynamic;          # Instantiate any dynamic entries (sets, related)
    $self->resolve_alias_refs;           # Resolve xref/crossref/xdata aliases to real keys
    $self->resolve_xdata;                # Resolve xdata entries
    $self->cite_setmembers;              # Cite set members
    $self->process_interentry;           # Process crossrefs/sets etc.
    $self->validate_datamodel;           # Check against data model
    $self->process_entries_pre;          # Main entry processing loop, part 1
    $self->uniqueness;                   # Here we generate uniqueness information
    $self->process_visible_names;        # Generate visible names information for all entries
    $self->process_entries_post;         # Main entry processing loop, part 2
    $self->process_lists;                # process the output lists (sort and filtering)
    $self->generate_singletitle;         # Generate singletitle field if requested
    $self->generate_uniquetitle;         # Generate uniquetitle field if requested
    $self->generate_uniquebaretitle;     # Generate uniquebaretitle field if requested
    $self->generate_uniquework;          # Generate uniquework field if requested
    $self->generate_uniquepa;            # Generate uniqueprimaryauthor if requested
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

  $self->process_visible_names;# Generate visible names information for all entries

  if (Biber::Config->getoption('output_resolve')) {
    $self->resolve_alias_refs; # Resolve xref/crossref/xdata aliases to real keys
    $self->resolve_xdata;      # Resolve xdata entries
    $self->process_interentry; # Process crossrefs/sets etc.
  }

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
    my %months = ('jan' => '1',
                  'feb' => '2',
                  'mar' => '3',
                  'apr' => '4',
                  'may' => '5',
                  'jun' => '6',
                  'jul' => '7',
                  'aug' => '8',
                  'sep' => '9',
                  'oct' => '10',
                  'nov' => '11',
                  'dec' => '12');

    foreach my $mon (keys %months) {
      Text::BibTeX::delete_macro($mon);
      Text::BibTeX::add_macro_text($mon, $months{$mon});
    }
  }

  # First we look for the directly cited keys in each datasource
  my @remaining_keys = @citekeys;
  if ($logger->is_debug()) {# performance tune
    $logger->debug('Looking for directly cited keys: ' . join(', ', @remaining_keys));
  }

  foreach my $datasource ($section->get_datasources->@*) {
    # shortcut if we have found all the keys now
    last unless (@remaining_keys or $section->is_allkeys);
    my $type = $datasource->{type};
    my $name = $datasource->{name};
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
    eval "require $package" or
      biber_error("Error loading data source package '$package': $@");

    # Slightly different message for tool mode
    if (Biber::Config->getoption('tool')) {
      $logger->info("Looking for $datatype format $type '$name'");
    }
    else {
      $logger->info("Looking for $datatype format $type '$name' for section $secnum");
    }

    @remaining_keys = "${package}::extract_entries"->($name, \@remaining_keys);
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

  # Don't need to do dependent detection if running in (real) tool mode since this is always
  # allkeys=1 and we don't care about missing dependents which get_dependents() might prune.
  # pseudo_tool mode is bibtex output when not in tool mode. Internally, it's essentially
  # the same but without allkeys.
  if (Biber::Config->getoption('tool') and not
      Biber::Config->getoption('pseudo_tool')) {
    return;
  }

  if ($logger->is_debug()) {# performance tune
    $logger->debug('Building dependents for keys: ' . join(',', $section->get_citekeys));
  }

  # dependent key list generation - has to be a sub as it's recursive to catch
  # nested crossrefs, xdata etc.
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
      if (my $xdata = $be->get_field('xdata')) {
        foreach my $xdatum ($xdata->@*) {
          # skip looking for dependent if it's already there (loop suppression)
          push $new_deps->@*, $xdatum unless $section->bibentry($xdatum);
          if ($logger->is_debug()) {# performance tune
            $logger->debug("Entry '$citekey' has xdata '$xdatum'");
          }
          push $keyswithdeps->@*, $citekey unless first {$citekey eq $_} $keyswithdeps->@*;
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
        my $datatype = $datasource->{datatype};
        my $package = 'Biber::Input::' . $type . '::' . $datatype;
        eval "require $package" or
          biber_error("Error loading data source package '$package': $@");
        $missing->@* = "${package}::extract_entries"->($name, $missing);
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
      $be->del_field('xref');
      biber_warn("I didn't find a database entry for xref '$missing_key' in entry '$citekey' - ignoring (section $secnum)");
    }

    # remove any crossrefs
    if ($be->get_field('crossref') and ($be->get_field('crossref') eq $missing_key)) {
      $be->del_field('crossref');
      if ($logger->is_trace()) {# performance tune
        $logger->trace("Removed crossref dependency for missing key '$missing_key' from '$citekey' in section '$secnum'");
      }
      biber_warn("I didn't find a database entry for crossref '$missing_key' in entry '$citekey' - ignoring (section $secnum)");
    }

    # remove xdata
    if (my $xdata = $be->get_field('xdata')) {
      if (first {$missing_key eq $_} $xdata->@*) {
        $be->set_datafield('xdata', [ grep {$_ ne $missing_key} $xdata->@* ]) ;
        if ($logger->is_trace()) {# performance tune
          $logger->trace("Removed xdata dependency for missing key '$missing_key' from '$citekey' in section '$secnum'");
        }
        biber_warn("I didn't find a database entry for xdata entry '$missing_key' in entry '$citekey' - ignoring (section $secnum)");
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

  return {locale => locale2bcp47($root_obj->{locale} || Biber::Config->getblxoption('sortlocale')),
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

François Charette, C<< <firmicus at ankabut.net> >>
Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our Github tracker at
L<https://github.com/plk/biber/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2016 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
