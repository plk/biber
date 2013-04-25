package Biber;
use v5.16;
use strict;
use warnings;
use base 'Biber::Internals';

use constant {
  EXIT_OK => 0,
  EXIT_ERROR => 2
};

use Carp;
use Encode;
use File::Copy;
use File::Spec;
use File::Temp;
use IO::File;
use POSIX qw( locale_h ); # for sorting with built-in "sort"
use Biber::Config;
use Biber::Constants;
use List::AllUtils qw( first uniq max );
use Biber::DataModel;
use Biber::Internals;
use Biber::Entries;
use Biber::Entry;
use Biber::Entry::Name;
use Biber::Sections;
use Biber::Section;
use Biber::LaTeX::Recode;
use Biber::SortLists;
use Biber::SortList;
use Biber::Utils;
use Log::Log4perl qw( :no_extra_logdie_message );
use Data::Dump;
use Data::Compare;
use Text::BibTeX qw(:macrosubs);

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
  Biber::LaTeX::Recode->init_schemes(Biber::Config->getoption('decodecharsset'),
                                     Biber::Config->getoption('output_safecharsset'));

  $MASTER = $self;

  # Validate if asked to
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
  my $bib_section = new Biber::Section('number' => 0);
  $bib_section->set_datasources([{type => 'file',
                                  name => $ARGV[0],
                                  datatype => Biber::Config->getoption('tool_datatype')}]);
  $bib_section->set_allkeys(1);
  $bib_sections->add_section($bib_section);

  # Add the Biber::Sections object to the Biber object
  $self->add_sections($bib_sections);

  # User maps are set in config file and need some massaging which normally
  # happend in parse_ctrlfile
  if (my $usms = Biber::Config->getoption('sourcemap')) {
    # Force "user" level for the maps
    @$usms = map {$_->{level} = 'user';$_} @$usms;
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

    # Deal with the strange world of Par::Packer paths
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
  my $ctrl = new IO::File "<$ctrl_file_path"
    or biber_error("Cannot open $ctrl_file_path: $!");

  $logger->info("Reading '$ctrl_file_path'");

  # Read control file
  require XML::LibXML::Simple;

  my $bcfxml = XML::LibXML::Simple::XMLin($ctrl,
                                          'ForceContent' => 1,
                                          'ForceArray' => [
                                                           qr/\Acitekey\z/,
                                                           qr/\Aoption\z/,
                                                           qr/\Aoptions\z/,
                                                           qr/\Avalue\z/,
                                                           qr/\Asortitem\z/,
                                                           qr/\Abibdata\z/,
                                                           qr/\Adatasource\z/,
                                                           qr/\Asection\z/,
                                                           qr/\Adtarget\z/,
                                                           qr/\Asortexclusion\z/,
                                                           qr/\Aexclusion\z/,
                                                           qr/\Asort\z/,
                                                           qr/\Amode\z/,
                                                           qr/\Amaps\z/,
                                                           qr/\Amap\z/,
                                                           qr/\Amap_step\z/,
                                                           qr/\Aper_type\z/,
                                                           qr/\Aper_datasource\z/,
                                                           qr/\Anosort\z/,
                                                           qr/\Anoinit\z/,
                                                           qr/\Apresort\z/,
                                                           qr/\Atype_pair\z/,
                                                           qr/\Ainherit\z/,
                                                           qr/\Afieldor\z/,
                                                           qr/\Afieldxor\z/,
                                                           qr/\Afield\z/,
                                                           qr/\Aalias\z/,
                                                           qr/\Aalsoset\z/,
                                                           qr/\Aconstraints\z/,
                                                           qr/\Aconstraint\z/,
                                                           qr/\Aentrytype\z/,
                                                           qr/\Adatetype\z/,
                                                           qr/\Asortlist\z/,
                                                           qr/\Alabel(?:part|element|alphatemplate)\z/,
                                                           qr/\Acondition\z/,
                                                           qr/\A(?:or)?filter\z/,
                                                          ],
                                          'NsStrip' => 1,
                                          'KeyAttr' => []);
#  use Data::Dump;dd($bcfxml);exit 0;
  my $controlversion = $bcfxml->{version};
  Biber::Config->setblxoption('controlversion', $controlversion);
  unless ($controlversion eq $BCF_VERSION) {
    biber_warn("Warning: Found biblatex control file version $controlversion, expected version $BCF_VERSION");
  }

  # Look at control file and populate our main data structure with its information

  # OPTIONS
  foreach my $bcfopts (@{$bcfxml->{options}}) {

    # Biber options
    if ($bcfopts->{component} eq 'biber') {

      # Global options
      if ($bcfopts->{type} eq 'global') {
        foreach my $bcfopt (@{$bcfopts->{option}}) {
          # unless already explicitly set from cmdline/config file
          unless (Biber::Config->isexplicitoption($bcfopt->{key}{content})) {
            if ($bcfopt->{type} eq 'singlevalued') {
              Biber::Config->setoption($bcfopt->{key}{content}, $bcfopt->{value}[0]{content});
            }
            elsif ($bcfopt->{type} eq 'multivalued') {
              Biber::Config->setoption($bcfopt->{key}{content},
                [ map {$_->{content}} sort {$a->{order} <=> $b->{order}} @{$bcfopt->{value}} ]);
            }
          }
        }
      }
    }

    # BibLaTeX options
    if ($bcfopts->{component} eq 'biblatex') {

      # Global options
      if ($bcfopts->{type} eq 'global') {
        foreach my $bcfopt (@{$bcfopts->{option}}) {
          if ($bcfopt->{type} eq 'singlevalued') {
            Biber::Config->setblxoption($bcfopt->{key}{content}, $bcfopt->{value}[0]{content});
          }
          elsif ($bcfopt->{type} eq 'multivalued') {
            # sort on order attribute and then remove it
            Biber::Config->setblxoption($bcfopt->{key}{content},
              [ map {delete($_->{order}); $_} sort {$a->{order} <=> $b->{order}} @{$bcfopt->{value}} ]);
          }
        }
      }

      # Entrytype options
      else {
        my $entrytype = $bcfopts->{type};
        foreach my $bcfopt (@{$bcfopts->{option}}) {
          if ($bcfopt->{type} eq 'singlevalued') {
            Biber::Config->setblxoption($bcfopt->{key}{content}, $bcfopt->{value}[0]{content}, 'PER_TYPE', $entrytype);
          }
          elsif ($bcfopt->{type} eq 'multivalued') {
            # sort on order attribute and then remove it
            Biber::Config->setblxoption($bcfopt->{key}{content},
              [ map {delete($_->{order}); $_} sort {$a->{order} <=> $b->{order}} @{$bcfopt->{value}} ],
              'PER_TYPE',
              $entrytype);
          }
        }
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
      @$usms = map {$_->{level} = 'user';$_} @$usms;

      # Merge any user maps from the document set by \DeclareSourcemap into user
      # maps set in the biber config file. These document user maps take precedence so go
      # at the front of any other user maps
      unshift(@$usms, grep {$_->{level} eq 'user'} @{$bcfxml->{sourcemap}{maps}});

      # Merge the driver/style maps with the user maps from the config file
      if (my @m = grep {$_->{level} eq 'driver' or
                        $_->{level} eq 'style'} @{$bcfxml->{sourcemap}{maps}} ) {
        Biber::Config->setoption('sourcemap', [@$usms, @m]);
      }
      else { # no driver defaults, just override the config file user map settings
        Biber::Config->setoption('sourcemap', $bcfxml->{sourcemap}{maps});
      }
    }
    else { # just write the option as there are no config file settings at all
      Biber::Config->setoption('sourcemap', $bcfxml->{sourcemap}{maps});
    }
  }

  # LABELALPHA TEMPLATE
  foreach my $t (@{$bcfxml->{labelalphatemplate}}) {
    my $latype = $t->{type};
    if ($latype eq 'global') {
      Biber::Config->setblxoption('labelalphatemplate', $t);
    }
    else {
      Biber::Config->setblxoption('labelalphatemplate',
                                  $t,
                                  'PER_TYPE',
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
  foreach my $ni (@{$bcfxml->{noinits}{noinit}}) {
    push @$noinit, { value => $ni->{value}[0]};
  }
  # There is a default so don't set this option if nothing is in the .bcf
  Biber::Config->setoption('noinit', $noinit) if $noinit;

  # NOSORT
  # Make the data structure look like the biber config file structure
  # "field" and "value" are forced to arrays for other elements so we extract
  # the first element here as they will always be only length=1
  my $nosort;
  foreach my $ns (@{$bcfxml->{nosorts}{nosort}}) {
    push @$nosort, { name => $ns->{field}[0], value => $ns->{value}[0]};
  }
  # There is a default so don't set this option if nothing is in the .bcf
  Biber::Config->setoption('nosort', $nosort) if $nosort;

  # SORTING

  # sorting excludes
  foreach my $sex (@{$bcfxml->{sorting}{sortexclusion}}) {
    my $excludes;
    foreach my $ex (@{$sex->{exclusion}}) {
      $excludes->{$ex->{content}} = 1;
    }
    Biber::Config->setblxoption('sortexclusion',
                                $excludes,
                                'PER_TYPE',
                                $sex->{type});
  }

  # presort defaults
  foreach my $presort (@{$bcfxml->{sorting}{presort}}) {
    # Global presort default
    unless (exists($presort->{type})) {
      Biber::Config->setblxoption('presort', $presort->{content});
    }
    # Per-type default
    else {
      Biber::Config->setblxoption('presort',
                                  $presort->{content},
                                  'PER_TYPE',
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
  foreach my $data (@{$bcfxml->{bibdata}}) {
    foreach my $datasource (@{$data->{datasource}}) {
      unless (first {$_->{type} eq $datasource->{type} and
             $_->{datatype} eq $datasource->{datatype} and
               $_->{name} eq $datasource->{content}} @{$bibdatasources{$data->{section}[0]}}) {
        push @{$bibdatasources{$data->{section}[0]}}, { type     => $datasource->{type},
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

SECTION: foreach my $section (@{$bcfxml->{section}}) {
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
    foreach my $keyc (@{$section->{citekey}}) {
      my $key = $keyc->{content};
      # Stop reading citekeys if we encounter "*" as a citation as this means
      # "all keys"
      if ($key eq '*') {
        $bib_section->set_allkeys(1);
        # Normalise - when allkeys is true don't need citekeys - just in case someone
        # lists "*" and also some other citekeys
        $bib_section->del_citekeys;
        $key_flag = 1; # There is at least one key, used for error reporting below
        $logger->info("Using all citekeys in bib section " . $secnum);
        $bib_sections->add_section($bib_section);
        next SECTION;
      }
      elsif (not Biber::Config->get_seenkey($key, $secnum)) {
        # Dynamic set definition
        # Save dynamic key -> member keys mapping for set entry auto creation later
        if (exists($keyc->{type}) and $keyc->{type} eq 'set') {
          $bib_section->set_dynamic_set($key, split /\s*,\s*/, $keyc->{members});
          push @keys, $key;
          $key_flag = 1; # There is at least one key, used for error reporting below
        }
        else {
          # Set order information - there is no order on dynamic key defs above
          # as they are a definition, not a cite
          Biber::Config->set_keyorder($secnum, $key, $keyc->{order});
          push @keys, $key;
          $key_flag = 1; # There is at least one key, used for error reporting below
          Biber::Config->incr_seenkey($key, $secnum);
        }
      }
    }

    unless ($bib_section->is_allkeys) {
      $logger->info('Found ', $#keys+1 , " citekeys in bib section $secnum")
    }

    if (Biber::Config->getoption('debug')) {
      my @debug_keys = sort @keys;
      unless ($bib_section->is_allkeys) {
        $logger->debug("The citekeys for section $secnum are: ", join(', ', @debug_keys), "\n");
      }
    }

    $bib_section->add_citekeys(@keys);
    $bib_sections->add_section($bib_section);
  }

  # Add the Biber::Sections object to the Biber object
  $self->{sections} = $bib_sections;

  # Read sortlists
  my $sortlists = new Biber::SortLists;
  foreach my $list (@{$bcfxml->{sortlist}}) {
    my $ltype  = $list->{type};
    my $llabel = $list->{label};
    my $lsection = $list->{section}[0]; # because "section" needs to be a list elsewhere in XML
    if (my $l = $sortlists->get_list($lsection, $ltype, $llabel)) {
      $logger->debug("Section '$ltype' list '$llabel' is repeated for section $lsection - ignoring");
      next;
    }

    my $seclist = Biber::SortList->new(section => $lsection, label => $llabel);
    $seclist->set_type($ltype || 'entry'); # lists are entry lists by default
    foreach my $filter (@{$list->{filter}}) {
      $seclist->add_filter($filter->{type}, $filter->{content});
    }
    # disjunctive filters
    foreach my $orfilter (@{$list->{orfilter}}) {
      $seclist->add_filter('orfilter', { map {$_->{type} => [$_->{content}]} @{$orfilter->{filter}} });
    }

    if (my $sorting = $list->{sorting}) { # can be undef for fallback to global sorting
      $seclist->set_sortscheme(_parse_sort($sorting));
    }
    else {
      $seclist->set_sortscheme(Biber::Config->getblxoption('sorting'));
    }
    $logger->debug("Adding '$ltype' list '$llabel' for section $lsection");
    $sortlists->add_list($seclist);
  }

  # Check to make sure that each section has an entry sortlist for global sorting
  # We have to make sure in case sortcites is used which uses the global order.
  foreach my $section (@{$bcfxml->{section}}) {
    my $globalss = Biber::Config->getblxoption('sortscheme');
    my $secnum = $section->{number};
    unless ($sortlists->get_list($secnum, 'entry', $globalss)) {
      my $seclist = Biber::SortList->new(section => $secnum, type => 'entry', label => $globalss);
      $seclist->set_sortscheme(Biber::Config->getblxoption('sorting'));
      $sortlists->add_list($seclist);
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
  foreach my $section (@{$self->sections->get_sections}) {
    my $secnum = $section->number;
    unless ($self->sortlists->has_lists_of_type_for_section($secnum, 'entry')) {
      my $dlist = Biber::SortList->new(label => Biber::Config->getblxoption('sortscheme'));
      $dlist->set_sortscheme(Biber::Config->getblxoption('sorting'));
      $dlist->set_type('entry');
      $dlist->set_section($secnum);
      $self->sortlists->add_list($dlist);
    }
  }

  # Break data model information up into more processing-friendly formats
  # for use in verification checks later
  # This has to be here as opposed to in parse_control() so that it can pick
  # up data model defaults in Constants.pm in case there is nothing in the .bcf
  Biber::Config->set_dm(Biber::DataModel->new(Biber::Config->getblxoption('datamodel')));

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

  # Force output_safechars flag if output to ASCII and input_encoding is not ASCII
  if (Biber::Config->getoption('output_encoding') =~ /(?:x-)?ascii/xmsi and
      Biber::Config->getoption('input_encoding') !~ /(?:x-)?ascii/xmsi) {
    Biber::Config->setoption('output_safechars', 1);
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
      my @resolved_keys;
      foreach my $refkey (split /\s*,\s*/, $xdata) {
        $refkey = $section->get_citekey_alias($refkey) // $refkey;
        push @resolved_keys, $refkey;
      }
      $be->set_datafield('xdata', join(',', @resolved_keys));
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
    if ($section->get_citekey_alias($citekey)) {
      $logger->debug("Pruning citekey alias '$citekey' from citekeys");
      $section->del_citekey($citekey);
    }
  }
}

=head2 nullable_check

  Check entries for nullable fields

=cut

sub nullable_check {
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $dm = Biber::Config->get_dm;
  foreach my $citekey ($section->get_citekeys) {
    my $be = $section->bibentry($citekey);
    my $bee = $be->get_field('entrytype');
    foreach my $f ($be->datafields) {
      if (is_null($be->get_datafield($f))) {
        unless ($dm->field_is_nullok($f)) {
          biber_warn("The field '$f' in entry '$citekey' cannot be null, deleting it");
          $be->del_field($f);
        }
      }
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

  $logger->debug("Creating dynamic entries (sets/related) for section $secnum");

  # Instantiate any dynamic set entries before we do anything else
  foreach my $dset (@{$section->dynamic_set_keys}) {
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
    $be->set_field('entryset', join(',', @members));
    $be->set_field('citekey', $dset);
    $be->set_field('datatype', 'dynamic');
    $section->bibentries->add_entry($dset, $be);
    $logger->debug("Created dynamic set entry '$dset' in section $secnum");

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
  $logger->debug("Resolving XDATA entries for section $secnum");

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

  $logger->debug("Adding set members to citekeys for section $secnum");

  foreach my $citekey ($section->get_citekeys) {
    my $be = $section->bibentry($citekey);

    # promote indirectly cited inset set members to fully cited entries
    if ($be->get_field('entrytype') eq 'set' and
        $be->get_field('entryset')) {
      my @inset_keys = split /\s*,\s*/, $be->get_field('entryset');

      my @realmems;
      foreach my $mem (@inset_keys) {
        push @realmems, $section->get_citekey_alias($mem) // $mem;
      }
      @inset_keys = @realmems;
      $be->set_datafield('entryset', join(',', @inset_keys));

      foreach my $inset_key (@inset_keys) {
        $logger->debug("Adding set member '$inset_key' to the citekeys (section $secnum)");
        $section->add_citekeys($inset_key);

        # Save graph information if requested
        if (Biber::Config->getoption('output_format') eq 'dot') {
          Biber::Config->set_graph('set', $citekey, $inset_key);
        }
      }
      # automatically crossref for the first set member using plain set inheritance
      $be->set_inherit_from($section->bibentry($inset_keys[0]), $section);
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
       at least mincrossrefs times are included in the bibliography.

=cut

sub process_interentry {
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);

  $logger->debug("Processing explicit and implicit crossrefs for section $secnum");

  foreach my $citekey ($section->get_citekeys) {
    my $be = $section->bibentry($citekey);
    my $refkey;

    # Record set information
    # It's best to do this in the loop here as every entry needs the information
    # from all other entries in process_sets()
    if ($be->get_field('entrytype') eq 'set') {
      my @entrysetkeys = split /\s*,\s*/, $be->get_field('entryset');
      foreach my $member (@entrysetkeys) {
        Biber::Config->set_set_pc($citekey, $member);
        Biber::Config->set_set_cp($member, $citekey);
      }
    }

    # Loop over cited keys and count the cross/xrefs
    # Can't do this when parsing entries as this would count them
    # for potentially uncited children
    if ($refkey = $be->get_field('xref') or $refkey = $be->get_field('crossref')) {
      $logger->debug("Incrementing cross/xrefkey count for entry '$refkey' via entry '$citekey'");
      Biber::Config->incr_crossrefkey($refkey);
    }

    # Record xref inheritance for graphing if required
    if (Biber::Config->getoption('output_format') eq 'dot' and my $xref = $be->get_field('xref')) {
      Biber::Config->set_graph('xref', $citekey, $xref);
    }

    # Do crossref inheritance
    if (my $cr = $be->get_field('crossref')) {
      # Skip inheritance if we've already done it
      next if Biber::Config->get_inheritance('crossref', $cr, $be->get_field('citekey'));

      my $parent = $section->bibentry($cr);
      $logger->debug("Entry $citekey inheriting fields from parent $cr");
      unless ($parent) {
        biber_warn("Cannot inherit from crossref key '$cr' - does it exist?", $be);
      }
      else {
        $be->inherit_from($parent);
      }
    }
  }

  # We make sure that crossrefs that are directly cited or cross-referenced
  # at least $mincrossrefs times are included in the bibliography.
  foreach my $k ( @{Biber::Config->get_crossrefkeys} ) {
    # If parent has been crossref'ed more than mincrossref times, upgrade it
    # to cited crossref status and add it to the citekeys list
    if (Biber::Config->get_crossrefkey($k) >= Biber::Config->getoption('mincrossrefs')) {
      $logger->debug("cross/xref key '$k' is cross/xref'ed >= mincrossrefs, adding to citekeys");
      $section->add_citekeys($k);
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
    foreach my $citekey ($section->get_citekeys) {
      my $be = $section->bibentry($citekey);
      my $citekey = $be->get_field('citekey');
      my $et = $be->get_field('entrytype');
      my $ds = $section->get_keytods($citekey);

      # default entrytype to MISC type if not a known type
      unless ($dm->is_entrytype($et)) {
        biber_warn("Datamodel: Entry '$citekey' ($ds): Invalid entry type '" . $be->get_field('entrytype') . "' - defaulting to 'misc'", $be);
        $be->set_field('entrytype', 'misc');
        $et = 'misc';           # reset this too
      }

      # Are all fields valid fields?
      # Each field must be:
      # * Valid because it's allowed for "ALL" entrytypes OR
      # * Valid field for the specific entrytype OR
      # * Valid because entrytype allows "ALL" fields
      foreach my $ef ($be->datafields) {
        unless ($dm->is_field_for_entrytype($et, $ef)) {
          biber_warn("Datamodel: Entry '$citekey' ($ds): Invalid field '$ef' for entrytype '$et'", $be);
        }
      }

      # Mandatory constraints
      foreach my $warning ($dm->check_mandatory_constraints($be)) {
        biber_warn($warning, $be);
      }

      # Conditional constraints
      foreach my $warning ($dm->check_conditional_constraints($be)) {
        biber_warn($warning, $be);
      }

      # Data constraints
      foreach my $warning ($dm->check_data_constraints($be)) {
        biber_warn($warning, $be);
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
  foreach my $citekey ( $section->get_citekeys ) {
    $logger->debug("Postprocessing entry '$citekey' from section $secnum (before uniqueness)");

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

  $logger->debug("Finished processing entries in section $secnum (before uniqueness)");

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
  foreach my $citekey ( $section->get_citekeys ) {
    $logger->debug("Postprocessing entry '$citekey' from section $secnum (after uniqueness)");

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

    # generate information for tracking singletitle
    $self->process_singletitle($citekey);

    # generate namehash
    $self->process_namehash($citekey);

    # generate per-name hashes
    $self->process_pername_hashes($citekey);

  }

  $logger->debug("Finished processing entries in section $secnum (after uniqueness)");

  return;
}


=head2 process_singletitle

    Track seen work combination for generation of singletitle

=cut

sub process_singletitle {
  my $self = shift;
  my $citekey = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');
  $logger->trace("Creating singletitle information for '$citekey'");

  # Use labelname to generate this, if there is one ...
  my $identifier;
  if (my $lni = $be->get_labelname_info) {
    $identifier = $self->_getnamehash_u($citekey, $be->get_field($lni->{field},
                                                                 $lni->{form},
                                                                 $lni->{lang}));
  }
  # ... otherwise use labeltitle
  elsif (my $lti = $be->get_labeltitle_info) {
    $identifier = $be->get_field($lti->{field},
                                 $lti->{form},
                                 $lti->{lang});
  }

  # Don't generate this information for entries with no labelname or labeltitle
  # as it would make no sense
  if ($identifier and Biber::Config->getblxoption('singletitle', $bee)) {
    Biber::Config->incr_seenwork($identifier);
    $logger->trace("Setting seenwork for '$citekey' to '$identifier'");
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

  if (Biber::Config->getblxoption('labeldate', $bee)) {
    if (Biber::Config->getblxoption('skiplab', $bee, $citekey)) {
      return;
    }

    $logger->trace("Creating extrayear information for '$citekey'");

    my $name_string = '';
    if (my $lni = $be->get_labelname_info) {
      $name_string = $self->_getnamehash_u($citekey, $be->get_field($lni->{field},
                                                                    $lni->{form},
                                                                    $lni->{lang}));
    }

    # extrayear takes into account the labelyear which can be a range
    my $year_string = $be->get_field('labelyear') || $be->get_field('year') || '';

    my $nameyear_string = "$name_string,$year_string";
    $logger->trace("Setting nameyear to '$nameyear_string' for entry '$citekey'");
    $be->set_field('nameyear', $nameyear_string);
    $logger->trace("Incrementing nameyear for '$name_string'");
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

    $logger->trace("Creating extratitle information for '$citekey'");

    my $name_string = '';
    if (my $lni = $be->get_labelname_info) {
      $name_string = $self->_getnamehash_u($citekey, $be->get_field($lni->{field},
                                                                    $lni->{form},
                                                                    $lni->{lang}));
    }

    my $lti = $be->get_labeltitle_info;
    my $title_string = $be->get_field($lti->{field},
                                      $lti->{form},
                                      $lti->{lang}) // '';

    my $nametitle_string = "$name_string,$title_string";
    $logger->trace("Setting nametitle to '$nametitle_string' for entry '$citekey'");
    $be->set_field('nametitle', $nametitle_string);
    $logger->trace("Incrementing nametitle for '$name_string'");
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

    $logger->trace("Creating extratitleyear information for '$citekey'");

    my $lti = $be->get_labeltitle_info;
    my $title_string = $be->get_field($lti->{field},
                                      $lti->{form},
                                      $lti->{lang}) // '';

    # Takes into account the labelyear which can be a range
    my $year_string = $be->get_field('labelyear') || $be->get_field('year') || '';

    my $titleyear_string = "$title_string,$year_string";
    $logger->trace("Setting titleyear to '$titleyear_string' for entry '$citekey'");
    $be->set_field('titleyear', $titleyear_string);
    $logger->trace("Incrementing titleyear for '$title_string'");
    Biber::Config->incr_seen_titleyear($title_string, $year_string);
  }

  return;
}


=head2 process_sets

    Postprocess set entries

    Checks for common set errors and enforces 'dataonly' for set members

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
      process_entry_options($member, 'skiplab, skiplos, uniquename=0, uniquelist=0');

      my $me = $section->bibentry($member);
      if ($me->get_field('entryset')) {
        biber_warn("Field 'entryset' is no longer needed in set member entries in Biber - ignoring in entry '$member'", $me);
        $me->del_field('entryset');
      }
      # This ends up setting \inset{} in the bbl
      $me->set_field('entryset', $citekey);
    }

    unless (@entrysetkeys) {
      biber_warn("No entryset found for entry $citekey of type 'set'", $be);
    }
  }
  # Also set this here for any non-set keys which are in a set and which haven't
  # had skips set by being seen as a member of that set yet
  else {
    if (Biber::Config->get_set_parents($citekey)) {
      process_entry_options($citekey, 'skiplab, skiplos, uniquename=0, uniquelist=0');
    }
  }
}

=head2 process_labelname

    Generate labelname information.

=cut

sub process_labelname {
  my $self = shift;
  my $citekey = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');
  my $lnamespec = Biber::Config->getblxoption('labelnamespec', $bee);
  my $dm = Biber::Config->get_dm;

  # prepend any per-entry labelname specification to the labelnamespec
  my $tmp_lns;
  if (my $lnfield = Biber::Config->getblxoption('labelnamefield', undef, $citekey)) {
    $tmp_lns->{content} = $lnfield;
  }
  if (my $lnform = Biber::Config->getblxoption('labelnameform', undef, $citekey)) {
    $tmp_lns->{form} = $lnform;
  }
  if (my $lnlang = Biber::Config->getblxoption('labelnamelang', undef, $citekey)) {
    $tmp_lns->{lang} = $lnlang;
  }
  if ($tmp_lns) {
    unshift @$lnamespec, $tmp_lns;
  }

  # First we set the normal labelname name
  foreach my $h_ln ( @$lnamespec ) {
    my $lnameopt;
    my $ln = $h_ln->{content};
    if ( $ln =~ /\Ashort(\X+)\z/xms ) {
      $lnameopt = $1;
    }
    else {
      $lnameopt = $ln;
    }

    unless ($ln ~~ $dm->get_fields_of_type('list', 'name')) {
      biber_warn("Labelname candidate '$ln' is not a name field - skipping");
      next;
    }

    # If there is a biblatex option which controls the use of this labelname info, check it
    if ($CONFIG_SCOPE_BIBLATEX{"use$lnameopt"} and
       not Biber::Config->getblxoption("use$lnameopt", $bee, $citekey)) {
      next;
    }

    if ($be->get_field($ln, $h_ln->{form}, $h_ln->{lang})) {
      $be->set_labelname_info({'field' => $ln,
                               'form'  => $h_ln->{form},
                               'lang'  => $h_ln->{lang}});
      last;
    }
  }

  # Then we loop again to set the labelname name for the fullhash generation code
  # This is because fullhash generation ignores SHORT* fields (section 4.2.4.1, BibLaTeX
  # manual)
  foreach my $h_ln ( @$lnamespec ) {
    my $ln = $h_ln->{content};
    if ( $ln =~ /\Ashort(.+)\z/xms ) {
      next;
    }

    # We have already warned about this above
    unless ($ln ~~ $dm->get_fields_of_type('list', 'name')) {
      next;
    }

    # If there is a biblatex option which controls the use of this labelname info, check it
    if ($CONFIG_SCOPE_BIBLATEX{"use$ln"} and
       not Biber::Config->getblxoption("use$ln", $bee, $citekey)) {
      next;
    }

    if ($be->get_field($ln, $h_ln->{form}, $h_ln->{lang})) {
      $be->set_labelnamefh_info({'field' => $ln,
                                 'form'  => $h_ln->{form},
                                 'lang'  => $h_ln->{lang}});
      last;
    }
  }

  # Set the actual labelname
  # Note this is not set with form and lang, as it is now resolved and the information
  # on what form and lang were used to resolve it are in labelname_info
  if (my $lni = $be->get_labelname_info) {
    $be->set_field('labelname',
                   $be->get_field($lni->{field},
                                  $lni->{form},
                                  $lni->{lang}));
  }
  else {
    $logger->debug("Could not determine the labelname of entry $citekey");
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

  if (Biber::Config->getblxoption('labeldate', $bee)) {
    if (Biber::Config->getblxoption('skiplab', $bee, $citekey)) {
      return;
    }

    my $ldatespec = Biber::Config->getblxoption('labeldatespec', $bee);
    foreach my $h_ly (@$ldatespec) {
      my $ly = $h_ly->{content};
      if ($h_ly->{'type'} eq 'field') { # labeldate field
        my $ldy;
        my $ldm;
        my $ldd;
        if ($dm->field_is_datatype('date', $ly)) { # resolve dates
          my $datetype = $ly =~ s/date\z//xmsr;
          $ldy = $datetype . 'year';
          $ldm = $datetype . 'month';
          $ldd = $datetype . 'day';
        }
        else {
          $ldy = $ly; # labelyear can be a non-date field so make a pseudo-year
        }
        if ($be->get_field($ldy)) { # did we find a labeldate?
          $be->set_labeldate_info({'field' => { 'year'  => $ldy,
                                                'month' => $ldm,
                                                'day'   => $ldd }});
          last;
        }
      }
      elsif ($h_ly->{'type'} eq 'string') { # labelyear fallback string
        $be->set_labeldate_info({'string' => $ly});
        last;
      }
    }

    # Construct labelyear, labelmonth, labelday
    # Might not have been set due to skiplab/dataonly
    if (my $ldi = $be->get_labeldate_info) {
      if (my $df = $ldi->{field}) { # set labelyear to a field value
        $be->set_field('labelyear', $be->get_field($df->{year}));
        $be->set_field('labelmonth', $be->get_field($df->{month})) if $df->{month};
        $be->set_field('labelday', $be->get_field($df->{day})) if $df->{day};
        # ignore endyear if it's the same as year
        my ($ytype) = $df->{year} =~ /\A(\X*)year\z/xms;
        $ytype = $ytype // ''; # Avoid undef warnings since no match above can make it undef
        # endyear can be null
        if (is_def_and_notnull($be->get_field($ytype . 'endyear'))
            and ($be->get_field($df->{year}) ne $be->get_field($ytype . 'endyear'))) {
          $be->set_field('labelyear',
                         $be->get_field('labelyear') . '\bibdatedash ' . $be->get_field($ytype . 'endyear'));
        }
        if ($be->get_field($ytype . 'endmonth')
            and ($be->get_field($df->{month}) ne $be->get_field($ytype . 'endmonth'))) {
          $be->set_field('labelmonth',
                         $be->get_field('labelmonth') . '\bibdatedash ' . $be->get_field($ytype . 'endmonth'));
        }
        if ($be->get_field($ytype . 'endday')
            and ($be->get_field($df->{day}) ne $be->get_field($ytype . 'endday'))) {
          $be->set_field('labelday',
                         $be->get_field('labelday') . '\bibdatedash ' . $be->get_field($ytype . 'endday'));
        }
      }
      elsif (my $ys = $ldi->{string}) { # set labelyear to a fallback string
        $be->set_field('labelyear', $ys);
      }
    }
    else {
      $logger->debug("labeldate information of entry $citekey is unset");
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

  # prepend any per-entry labeltitle specification to the labeltitlespec
  my $tmp_lts;
  if (my $ltfield = Biber::Config->getblxoption('labeltitlefield', undef, $citekey)) {
    $tmp_lts->{content} = $ltfield;
  }
  if (my $ltform = Biber::Config->getblxoption('labeltitleform', undef, $citekey)) {
    $tmp_lts->{form} = $ltform;
  }
  if (my $ltlang = Biber::Config->getblxoption('labeltitlelang', undef, $citekey)) {
    $tmp_lts->{lang} = $ltlang;
  }
  if ($tmp_lts) {
    unshift @$ltitlespec, $tmp_lts;
  }

  foreach my $h_ltn (@$ltitlespec) {
    my $ltn = $h_ltn->{content};
    if (my $lt = $be->get_field($ltn, $h_ltn->{form}, $h_ltn->{lang})) {
      $be->set_labeltitle_info({'field' => $ltn,
                                'form'  => $h_ltn->{form},
                                'lang'  => $h_ltn->{lang}});
      $be->set_field('labeltitle', $lt);
      last;
    }
    $logger->debug("labeltitle information of entry $citekey is unset");
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

  # fullhash is generated from the labelname but ignores SHORT* fields and
  # max/mincitenames settings
  if (my $lnfhi = $be->get_labelnamefh_info) {
    if (my $lnfh = $be->get_field($lnfhi->{field},
                                  $lnfhi->{form},
                                  $lnfhi->{lang})) {
      $be->set_field('fullhash', $self->_getfullhash($citekey, $lnfh));
    }
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

  # namehash is generated from the labelname
  if (my $lni = $be->get_labelname_info) {
    if (my $ln = $be->get_field($lni->{field},
                                $lni->{form},
                                $lni->{lang})) {
      $be->set_field('namehash', $self->_getnamehash($citekey, $ln));
    }
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
  my $dm = Biber::Config->get_dm;

  # Generate hashes for all forms and langs
N:  foreach my $pn (@{$dm->get_fields_of_type('list', 'name')}) {
    foreach my $form ($be->get_field_form_names($pn)) {
      foreach my $lang ($be->get_field_form_lang_names($pn, $form)) {
        my $names = $be->get_field($pn, $form, $lang) or next N;
        foreach my $n (@{$names->names}) {
          $n->set_hash($self->_genpnhash($citekey, $n));
        }
      }
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
  my $dm = Biber::Config->get_dm;

  foreach my $citekey ( $section->get_citekeys ) {
    $logger->debug("Postprocessing visible names for key '$citekey'");
    my $be = $section->bibentry($citekey);
    my $bee = $be->get_field('entrytype');

    my $maxcn = Biber::Config->getblxoption('maxcitenames', $bee, $citekey);
    my $mincn = Biber::Config->getblxoption('mincitenames', $bee, $citekey);
    my $maxbn = Biber::Config->getblxoption('maxbibnames', $bee, $citekey);
    my $minbn = Biber::Config->getblxoption('minbibnames', $bee, $citekey);
    my $maxan = Biber::Config->getblxoption('maxalphanames', $bee, $citekey);
    my $minan = Biber::Config->getblxoption('minalphanames', $bee, $citekey);

    foreach my $n (@{$dm->get_fields_of_type('list', 'name')}) {
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

      $logger->trace("Setting visible names (cite) for key '$citekey' to '$visible_names_cite'");
      $logger->trace("Setting visible names (bib) for key '$citekey' to '$visible_names_bib'");
      $logger->trace("Setting visible names (alpha) for key '$citekey' to '$visible_names_alpha'");
      # Need to set these on all name forms
      foreach my $form ($be->get_field_form_names($n)) {
        my $ns = $be->get_field($n, $form);
        $ns->set_visible_cite($visible_names_cite);
        $ns->set_visible_bib($visible_names_bib);
        $ns->set_visible_alpha($visible_names_alpha);
      }
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
    ( $label, $sortlabel ) = @{ $self->_genlabel($citekey) };
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
    Biber::Config->setblxoption('presort', $ps, 'PER_ENTRY', $citekey);
  }
}

=head2 process_lists

    Sort and filter lists for a section

=cut

sub process_lists {
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  foreach my $list (@{$self->sortlists->get_lists_for_section($secnum)}) {
    my $llabel = $list->get_label;
    my $ltype = $list->get_type;

    # Last-ditch fallback in case we still don't have a sorting spec
    $list->set_sortscheme(Biber::Config->getblxoption('sorting')) unless $list->get_sortscheme;

    $list->set_keys([ $section->get_citekeys ]);
    $logger->debug("Populated '$ltype' list '$llabel' in section $secnum with keys: " . join(', ', $list->get_keys));

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
    $logger->debug("Checking sorting cache for list '$llabel'");
    foreach my $cacheitem (@{$section->get_sort_cache}) {
      if (Compare($list->get_sortscheme, $cacheitem->[0])) {
        $logger->debug("Found sorting cache entry for '$llabel'");
        $logger->trace("Sorting list cache for list '$llabel':\n-------------------\n" . Data::Dump::pp($list->get_sortscheme) . "\n-------------------\n");
        $list->set_keys($cacheitem->[1]);
        $list->set_sortinitdata($cacheitem->[2]);
        $list->set_extrayeardata($cacheitem->[3]);
        $list->set_extraalphadata($cacheitem->[4]);
        $cache_flag = 1;
        last;
      }
    }

    unless ($cache_flag) {
      $logger->debug("No sorting cache entry for '$llabel'");
      # Sorting
      $self->generate_sortinfo($list);       # generate the sort information
      $self->sort_list($list);               # sort the list
      $self->generate_extra($list);          # generate the extra* fields

      # Cache the results
      $logger->debug("Adding sorting cache entry for '$llabel'");
      $section->add_sort_cache($list->get_listdata);
    }

    # Filtering
    # This is not really used - filtering is more efficient to do on the biblatex
    # side since we are filtering afer sorting anyway. It is used to provide
    # a field=shorthand filter for type=shorthand lists though.
    if (my $filters = $list->get_filters) {
      my $flist = [];
KEYLOOP: foreach my $k ($list->get_keys) {
        # Filter out skiplos entries as a special case in 'shorthand' type lists
        if ($list->get_type eq 'shorthand') {
          next if Biber::Config->getblxoption('skiplos', $section->bibentry($k)->get_field('entrytype'), $k);
        }

        $logger->debug("Checking key '$k' in list '$llabel' against list filters");
        my $be = $section->bibentry($k);
        foreach my $t (keys %$filters) {
          my $fs = $filters->{$t};
          # Filter disjunction is ok if any of the checks are ok, hence the grep()
          if ($t eq 'orfilter') {
            next KEYLOOP unless grep {check_list_filter($k, $_, $fs->{$_}, $be)} keys %$fs;
          }
          else {
            next KEYLOOP unless check_list_filter($k, $t, $fs, $be);
          }
        }
        push @$flist, $k;
      }
      $logger->debug("Keys after filtering list '$llabel' in section $secnum: " . join(', ', @$flist));
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
  $logger->debug("Checking key '$k' against filter '$t=" . join(',', @$fs) . "'");
  if ($t eq 'type') {
    return 0 unless grep {$be->get_field('entrytype') eq $_} @$fs;
  }
  elsif ($t eq 'nottype') {
    return 0 if grep {$be->get_field('entrytype') eq $_} @$fs;
  }
  elsif ($t eq 'subtype') {
    return 0 unless grep {$be->field_exists('entrysubtype') and
                                $be->get_field('entrysubtype') eq $_} @$fs;
  }
  elsif ($t eq 'notsubtype') {
    return 0 if grep {$be->field_exists('entrysubtype') and
                            $be->get_field('entrysubtype') eq $_} @$fs;
  }
  elsif ($t eq 'keyword') {
    return 0 unless grep {$be->has_keyword($_)} @$fs;
  }
  elsif ($t eq 'notkeyword') {
    return 0 if grep {$be->has_keyword($_)} @$fs;
  }
  elsif ($t eq 'field') {
    return 0 unless grep {$be->field_exists($_)} @$fs;
  }
  elsif ($t eq 'notfield') {
    return 0 if grep {$be->field_exists($_)} @$fs;
  }
  return 1;
}

=head2 generate_sortinfo

    Generate information for sorting

=cut

sub generate_sortinfo {
  my $self = shift;
  my $list = shift;

  my $sortscheme = $list->get_sortscheme;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  foreach my $key ($list->get_keys) {
    $self->_generatesortinfo($key, $list, $sortscheme);
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
    We are registering the number of occurences of each name, name+init and fullname
    within a specific context. For example, the context is "global" with uniquename < 5
    and "name list" for uniquename=5 or 6. The keys we store to count this are the most specific
    information for the context, so, for uniquename < 5, this is the full name and for
    uniquename=5 or 6, this is the complete list of full names. These keys have values in a hash
    which are ignored. They serve only to accumulate repeated occurences with the context
    and we don't care about this and so the values are a useful sinkhole for such repetition.

    For example, if we find in the global context a lastname "Smith" in two different entries
    under the same form "Alan Smith", the data structure will look like:

    {Smith}->{global}->{Alan Smith} = 2

    We don't care about the value as this means that there are 2 "Alan Smith"s in the global
    context which need disambiguating identically anyway. So, we just count the keys for the
    lastname "Smith" in the global context to see how ambiguous the lastname itself is. This
    would be "1" and so "Alan Smith" would get uniquename=0 because it's unambiguous as just
    "Smith".

    The same goes for "minimal" list context disambiguation for uniquename=5 or 6.
    For example, if we had the lastname "Smith" to disambiguate in two entries with labelname
    "John Smith and Alan Jones", the data structure would look like:

    {Smith}->{Smith+Jones}->{John Smith+Alan Jones} = 2

    Again, counting the keys of the context for the lastname gives us "1" which means we
    have uniquename=0 for "John Smith" in both entries because it's the same list. This also works
    for repeated names in the same list "John Smith and Bert Smith". Disambiguating "Smith" in this:

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

    $logger->trace("Generating uniquename information for '$citekey'");

    if (my $lni = $be->get_labelname_info) {

      # Set the index limit beyond which we don't look for disambiguating information
      my $ul = undef;           # Not set
      if (defined($be->get_field($lni->{field},
                                 $lni->{form},
                                 $lni->{lang})->get_uniquelist)) {
        # If defined, $ul will always be >1, see comment in set_uniquelist() in Names.pm
        $ul = $be->get_field($lni->{field},
                             $lni->{form},
                             $lni->{lang})->get_uniquelist;
      }
      my $maxcn = Biber::Config->getblxoption('maxcitenames', $bee, $citekey);
      my $mincn = Biber::Config->getblxoption('mincitenames', $bee, $citekey);

      # Note that we don't determine if a name is unique here -
      # we can't, were still processing entries at this point.
      # Here we are just recording seen combinations of:
      #
      # lastname and how many name context keys contain this (uniquename = 0)
      # lastnames+initials and how many name context keys contain this (uniquename = 1)
      # Full name and how many name context keys contain this (uniquename = 2)
      #
      # A name context can be either a complete single name or a list of names
      # depending on whether uniquename=min* or not
      #
      # Anything which has more than one combination for both of these would
      # be uniquename = 2 unless even the full name doesn't disambiguate
      # and then it is left at uniquename = 0

      my $nl = $be->get_field($lni->{field},
                              $lni->{form},
                              $lni->{lang});
      my $num_names = $nl->count_names;
      my $names = $nl->names;
      # If name list was truncated in bib with "and others", this overrides maxcitenames
      my $morenames = $nl->get_morenames ? 1 : 0;

      my @truncnames;
      my @lastnames;
      my @fullnames;
      my @initnames;

      foreach my $name (@$names) {
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
            push @lastnames, $name->get_lastname;
            push @fullnames, $name->get_namestring;
            push @initnames, $name->get_nameinitstring;
          }
        }
      }
      # Information for mininit ($un=5) or minfull ($un=6)
      my $lastnames_string;
      my $fullnames_string;
      my $initnames_string;
      if ($un == 5) {
        $lastnames_string = join("\x{10FFFD}", @lastnames);
        $initnames_string = join("\x{10FFFD}", @initnames);
        if ($#lastnames + 1 < $num_names or
            $morenames) {
          $lastnames_string .= "\x{10FFFD}et al"; # if truncated, record this
          $initnames_string .= "\x{10FFFD}et al"; # if truncated, record this
        }
      }
      elsif ($un == 6) {
        $lastnames_string = join("\x{10FFFD}", @lastnames);
        $fullnames_string = join("\x{10FFFD}", @fullnames);
        if ($#lastnames + 1 < $num_names or
            $morenames) {
          $lastnames_string .= "\x{10FFFD}et al"; # if truncated, record this
          $fullnames_string .= "\x{10FFFD}et al"; # if truncated, record this
        }
      }

      foreach my $name (@$names) {
        my $lastname       = $name->get_lastname;
        my $nameinitstring = $name->get_nameinitstring;
        my $namestring     = $name->get_namestring;
        my $namecontext;
        my $key;

        # Context and key depend on the uniquename setting
        given ($un) {
          when ([1,3]) {
            $namecontext = 'global';
            $key = $nameinitstring;
          }
          when ([2,4]) {
            $namecontext = 'global';
            $key = $namestring;
          }
          when (5) {
            $namecontext = $lastnames_string;
            $key = $initnames_string;
            $name->set_minimal_info($lastnames_string);
          }
          when (6) {
            $namecontext = $lastnames_string;
            $key = $fullnames_string;
            $name->set_minimal_info($lastnames_string);
          }
        }
        if (first {Compare($_, $name)} @truncnames) {
          # Record a uniqueness information entry for the lastname showing that
          # this lastname has been seen in this name context
          Biber::Config->add_uniquenamecount($lastname, $namecontext, $key);

          # Record a uniqueness information entry for the lastname+initials showing that
          # this lastname_initials has been seen in this name context
          Biber::Config->add_uniquenamecount($nameinitstring, $namecontext, $key);

          # Record a uniqueness information entry for the fullname
          # showing that this fullname has been seen in this name context
          Biber::Config->add_uniquenamecount($namestring, $namecontext, $key);
        }

        # As above but here we are collecting (separate) information for all
        # names, regardless of visibility (needed to track uniquelist)
        if (Biber::Config->getblxoption('uniquelist', $bee, $citekey)) {
          Biber::Config->add_uniquenamecount_all($lastname, $namecontext, $key);
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

    $logger->trace("Setting uniquename for '$citekey'");

    if (my $lni = $be->get_labelname_info) {
      # Set the index limit beyond which we don't look for disambiguating information

      # If defined, $ul will always be >1, see comment in set_uniquelist() in Names.pm
      my $ul = $be->get_field($lni->{field},
                              $lni->{form},
                              $lni->{lang})->get_uniquelist;

      my $maxcn = Biber::Config->getblxoption('maxcitenames', $bee, $citekey);
      my $mincn = Biber::Config->getblxoption('mincitenames', $bee, $citekey);

      my $nl = $be->get_field($lni->{field},
                              $lni->{form},
                              $lni->{lang});
      my $num_names = $nl->count_names;
      my $names = $nl->names;
      # If name list was truncated in bib with "and others", this overrides maxcitenames
      my $morenames = ($nl->get_morenames) ? 1 : 0;

      my @truncnames;

      foreach my $name (@$names) {
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

      foreach my $name (@$names) {
        my $lastname   = $name->get_lastname;
        my $nameinitstring = $name->get_nameinitstring;
        my $namestring = $name->get_namestring;
        my $namecontext = 'global'; # default
        if ($un == 5 or $un == 6) {
          $namecontext = $name->get_minimal_info; # $un=5 and 6
        }

        if (first {Compare($_, $name)} @truncnames) {

          # If there is one key for the lastname, then it's unique using just lastname
          # because either:
          # * There are no other identical lastnames
          # * All identical lastnames have a lastname+init ($un=5) or fullname ($un=6)
          #   which is identical and therefore can't be disambiguated any further anyway
          if (Biber::Config->get_numofuniquenames($lastname, $namecontext) == 1) {
            $name->set_uniquename(0);
          }
          # Otherwise, if there is one key for the lastname+inits, then it's unique
          # using initials because either:
          # * There are no other identical lastname+inits
          # * All identical lastname+inits have a fullname ($un=6) which is identical
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
            given ($un) {
              when (1) {$run = 1}   # init
              when (2) {$run = 2}   # full
              when (3) {$run = 1}   # allinit
              when (4) {$run = 2}   # allfull
              when (5) {$run = 1}   # mininit
              when (6) {$run = 2}   # minfull
            }
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
          if (Biber::Config->get_numofuniquenames_all($lastname, $namecontext) == 1) {
            $name->set_uniquename_all(0);
          }
          elsif (Biber::Config->get_numofuniquenames_all($nameinitstring, $namecontext) == 1) {
            $name->set_uniquename_all(1);
          }
          elsif (Biber::Config->get_numofuniquenames_all($namestring, $namecontext) == 1) {
            my $run;
            given ($un) {
              when (1) {$run = 1}   # init
              when (2) {$run = 2}   # full
              when (3) {$run = 1}   # allinit
              when (4) {$run = 2}   # allfull
              when (5) {$run = 1}   # mininit
              when (6) {$run = 2}   # minfull
            }
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

    Gather the uniquename information as we look through the names

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

    $logger->trace("Generating uniquelist information for '$citekey'");

    if (my $lni = $be->get_labelname_info) {
      my $nl = $be->get_field($lni->{field},
                              $lni->{form},
                              $lni->{lang});
      my $num_names = $nl->count_names;
      my $namelist = [];
      my $ulminyear_namelist = [];

      foreach my $name (@{$nl->names}) {

        my $lastname   = $name->get_lastname;
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

        # uniquename is not set so generate uniquelist based on just lastname
        if (not defined($name->get_uniquename_all)) {
          push @$namelist, $lastname;
          push @$ulminyear_namelist, $lastname if $ulminyearflag;
        }
        # uniquename indicates unique with just lastname
        elsif ($name->get_uniquename_all == 0) {
          push @$namelist, $lastname;
          push @$ulminyear_namelist, $lastname if $ulminyearflag;
        }
        # uniquename indicates unique with lastname with initials
        elsif ($name->get_uniquename_all == 1) {
          push @$namelist, $nameinitstring;
          push @$ulminyear_namelist, $nameinitstring if $ulminyearflag;
        }
        # uniquename indicates unique with full name
        elsif ($name->get_uniquename_all == 2) {
          push @$namelist, $namestring;
          push @$ulminyear_namelist, $namestring if $ulminyearflag;
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

    $logger->trace("Creating uniquelist for '$citekey'");

    if (my $lni = $be->get_labelname_info) {
      my $nl = $be->get_field($lni->{field},
                              $lni->{form},
                              $lni->{lang});
      my $namelist = [];
      my $num_names = $nl->count_names;

      foreach my $name (@{$nl->names}) {

        my $lastname   = $name->get_lastname;
        my $nameinitstring = $name->get_nameinitstring;
        my $namestring = $name->get_namestring;

        # uniquename is not set so generate uniquelist based on just lastname
        if (not defined($name->get_uniquename_all)) {
          push @$namelist, $lastname;
        }
        # uniquename indicates unique with just lastname
        elsif ($name->get_uniquename_all == 0) {
          push @$namelist, $lastname;
        }
        # uniquename indicates unique with lastname with initials
        elsif ($name->get_uniquename_all == 1) {
          push @$namelist, $nameinitstring;
        }
        # uniquename indicates unique with full name
        elsif ($name->get_uniquename_all == 2) {
          push @$namelist, $namestring;
        }

        # With uniquelist=minyear, uniquelist should not be set at all if there are
        # no other entries with the same max/mincitenames visible list and different years
        # to disambiguate from
        if ($ul == 2 and
            $num_names > $maxcn and
            $name->get_index <= $mincn and
            Biber::Config->get_uniquelistcount_minyear($namelist, $be->get_field('labelyear')) == 1) {
          $logger->trace("Not setting uniquelist=minyear for '$citekey'");
          next LOOP;
        }

        # list is unique after this many names so we set uniquelist to this point
        # Even if uniquelist=minyear, we record normal uniquelist information if
        # we didn't skip this key in the test above
        if (Biber::Config->get_uniquelistcount($namelist) == 1) {
          last;
        }
      }

      $logger->trace("Setting uniquelist for '$citekey' using " . join(',', @$namelist));
      $logger->trace("Uniquelist count for '$citekey' is '" . Biber::Config->get_uniquelistcount_final($namelist) . "'");
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
  my $sortscheme = $list->get_sortscheme;
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
      if (Biber::Config->getblxoption('labeldate', $bee)) {
        my $nameyear = $be->get_field('nameyear');
        if (Biber::Config->get_seen_nameyear($nameyear) > 1) {
          $logger->trace("nameyear for '$nameyear': " . Biber::Config->get_seen_nameyear($nameyear));
          my $v = Biber::Config->incr_seen_extrayear($nameyear);
          $list->set_extrayeardata_for_key($key, $v);
        }
      }
      # extratitle
      if (Biber::Config->getblxoption('labeltitle', $bee)) {
        my $nametitle = $be->get_field('nametitle');
        if (Biber::Config->get_seen_nametitle($nametitle) > 1) {
          $logger->trace("nametitle for '$nametitle': " . Biber::Config->get_seen_nametitle($nametitle));
          my $v = Biber::Config->incr_seen_extratitle($nametitle);
          $list->set_extratitledata_for_key($key, $v);
        }
      }
      # extratitleyear
      if (Biber::Config->getblxoption('labeltitleyear', $bee)) {
        my $titleyear = $be->get_field('titleyear');
        if (Biber::Config->get_seen_titleyear($titleyear) > 1) {
          $logger->trace("titleyear for '$titleyear': " . Biber::Config->get_seen_titleyear($titleyear));
          my $v = Biber::Config->incr_seen_extratitleyear($titleyear);
          $list->set_extratitleyeardata_for_key($key, $v);
        }
      }
      # extraalpha
      if (Biber::Config->getblxoption('labelalpha', $bee)) {
        my $la = $be->get_field('labelalpha');
        if (Biber::Config->get_la_disambiguation($la) > 1) {
          $logger->trace("labelalpha disambiguation for '$la': " . Biber::Config->get_la_disambiguation($la));
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
    this is gathered in process_singletitle()

=cut

sub generate_singletitle {
  my $self = shift;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bibentries;

  foreach my $citekey ( $section->get_citekeys ) {
    my $be = $bibentries->entry($citekey);
    if (Biber::Config->getblxoption('singletitle', $be->get_field('entrytype'))) {
      if ($be->get_field('seenwork') and
          Biber::Config->get_seenwork($be->get_field('seenwork')) < 2 ) {
        $logger->trace("Setting singletitle for '$citekey'");
        $be->set_field('singletitle', 1);
      }
      else {
        $logger->trace("Not setting singletitle for '$citekey'");
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
  my @keys = $list->get_keys;
  my $llabel = $list->get_label;
  my $ltype = $list->get_type;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);

  if (Biber::Config->getoption('sortcase')) {
    $logger->debug("Sorting is by default case-SENSITIVE");
  }
  else {
    $logger->debug("Sorting is by default case-INSENSITIVE");
  }
  $logger->debug("Keys before sort:\n");
  foreach my $k (@keys) {
    $logger->debug("$k => " . $list->get_sortdata($k)->[0] . "\n");
  }

  $logger->trace("Sorting '$ltype' list '$llabel' with scheme\n-------------------\n" . Data::Dump::pp($sortscheme) . "\n-------------------\n");

  # Set up locale. Order of priority is:
  # 1. locale value passed to Unicode::Collate::Locale->new() (Unicode::Collate sorts only)
  # 2. Biber sortlocale option
  # 3. LC_COLLATE env variable
  # 4. LANG env variable
  # 5. LC_ALL env variable
  # 6. Built-in defaults

  my $thislocale = Biber::Config->getoption('sortlocale');
  $logger->debug("Locale for sorting is '$thislocale'");

  if ( Biber::Config->getoption('fastsort') ) {
    use locale;
    $logger->info("Sorting '$ltype' list '$llabel' keys");
    $logger->debug("Sorting with fastsort (locale $thislocale)");
    unless (setlocale(LC_ALL, $thislocale)) {
      biber_warn("Unavailable locale $thislocale");
    }

    # Construct a multi-field Schwartzian Transform with the right number of
    # extractions into a string representing an array ref as we musn't eval this yet
    my $num_sorts = 0;
    my $data_extractor = '[';
    my $sorter;
    my $sort_extractor;
    # Global lowercase setting
    my $glc = Biber::Config->getoption('sortcase') ? '' : 'lc ';

    foreach my $sortset (@{$sortscheme}) {
      $data_extractor .= '$list->get_sortdata($_)->[1][' . $num_sorts . '],';
      $sorter .= ' || ' if $num_sorts; # don't add separator before first field
      my $lc = $glc; # Casing defaults to global default ...
      my $sc = $sortset->[0]{sortcase};
      # but is overriden by field setting if it exists
      if (defined($sc) and $sc != Biber::Config->getoption('sortcase')) {
        unless ($sc) {
          $lc = 'lc ';
        }
        else {
          $lc = '';
        }
      }

      my $sd = $sortset->[0]{sort_direction};
      if (defined($sd) and $sd eq 'descending') {
        # descending field
        $sorter .= $lc
          . '$b->['
            . $num_sorts
              . '] cmp '
                . $lc
                  . '$a->['
                    . $num_sorts
                      . ']';
      }
      else {
        # ascending field
        $sorter .= $lc
          . '$a->['
            . $num_sorts
              . '] cmp '
                . $lc
                  . '$b->['
                    . $num_sorts
                      . ']';
      }
      $num_sorts++;
    }
    $data_extractor .= '$_]';
    # Handily, $num_sorts is now one larger than the number of fields which is the
    # correct index for the actual data in the sort array
    $sort_extractor = '$_->[' . $num_sorts . ']';
    $logger->trace("Sorting structure is: $sorter");

    # Schwartzian transform multi-field sort
    @keys = map  { eval $sort_extractor }
            sort { eval $sorter }
            map  { eval $data_extractor } @keys;
  }
  else {
    require Unicode::Collate::Locale;
    my $collopts = Biber::Config->getoption('collate_options');

    # UCA level 2 if case insensitive sorting is requested
    unless (Biber::Config->getoption('sortcase')) {
      $collopts->{level} = 2;
    }

    # Add upper_before_lower option
    $collopts->{upper_before_lower} = Biber::Config->getoption('sortupper');

    # Add tailoring locale for Unicode::Collate
    if ($thislocale and not $collopts->{locale}) {
      $collopts->{locale} = $thislocale;
      if ($collopts->{table}) {
        my $t = delete $collopts->{table};
        $logger->info("Ignoring collation table '$t' as locale is set ($thislocale)");
      }
    }

    # Remove locale from options as we need this to make the object
    my $coll_locale = delete $collopts->{locale};
    # Now create the collator object
    my $Collator = Unicode::Collate::Locale->new( locale => $coll_locale)
      or $logger->logcarp("Problem creating Unicode::Collate::Locale object: $@");

    # Fix the old "alternate" alias otherwise we have problems as U::C->change() always
    # returns the new "variable" option and we get confused.
    if (my $alt = delete $collopts->{alternate}) {
      $collopts->{variable} = $alt;
    }

    #Show the collation options when debugging
    $logger->debug('Collation options: ' . Data::Dump::pp($collopts));

    # Tailor the collation object and report differences from defaults for locale
    # Have to do this in ->change method as ->new can croak with conflicting tailoring
    # for locales which enforce certain tailorings
    my %coll_changed = $Collator->change( %{$collopts} );
    while (my ($k, $v) = each %coll_changed) {
      # If we changing something that has no override tailoring in the locale, it
      # is undef in this hash and we don't care about such things
      next unless defined($coll_changed{$k});
      if ($coll_changed{$k} ne $collopts->{$k}) {
        $logger->info("Overriding locale '$coll_locale' default tailoring '$k = $v' with '$k = " . $collopts->{$k} . "'");
      }
    }

    my $UCAversion = $Collator->version();
    $logger->info("Sorting '$ltype' list '$llabel' keys");
    $logger->debug("Sorting with Unicode::Collate (" . stringify_hash($collopts) . ", UCA version: $UCAversion, Locale: " . $Collator->getlocale . ")");

    # Log if U::C::L currently has no tailoring for used locale
    if ($Collator->getlocale eq 'default') {
      $logger->info("No sort tailoring available for locale '$thislocale'");
    }

    # Construct a multi-field Schwartzian Transform with the right number of
    # extractions into a string representing an array ref as we musn't eval this yet
    my $num_sorts = 0;
    my $data_extractor = '[';
    my $sorter;
    my $sort_extractor;
    foreach my $sortset (@{$sortscheme}) {
      my $fc = '';
      my @fc;
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

      $data_extractor .= '$list->get_sortdata($_)->[1][' . $num_sorts . '],';
      $sorter .= ' || ' if $num_sorts; # don't add separator before first field

      my $sd = $sortset->[0]{sort_direction};
      if (defined($sd) and $sd eq 'descending') {
        # descending field
        $sorter .= '$Collator'
          . $fc
            . '->cmp($b->['
              . $num_sorts
                . '],$a->['
                  . $num_sorts
                    . '])';
      }
      else {
        # ascending field
        $sorter .= '$Collator'
          . $fc
            . '->cmp($a->['
              . $num_sorts
                . '],$b->['
                  . $num_sorts
                    . '])';
      }
      $num_sorts++;
    }
    $data_extractor .= '$_]';
    # Handily, $num_sorts is now one larger than the number of fields which is the
    # correct index for the actual data in the sort array
    $sort_extractor = '$_->[' . $num_sorts . ']';
    $logger->trace("Sorting structure is: $sorter");

    # Schwartzian transform multi-field sort
    @keys = map  { eval $sort_extractor }
            sort { eval $sorter }
            map  { eval $data_extractor } @keys;
  }

  $logger->debug("Keys after sort:\n");
  foreach my $k (@keys) {
    $logger->debug("$k => " . $list->get_sortdata($k)->[0] . "\n");
  }
  $list->set_keys([ @keys ]);

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

  foreach my $section (@{$self->sections->get_sections}) {
    # shortcut - skip sections that don't have any keys
    next unless $section->get_citekeys or $section->is_allkeys;
    my $secnum = $section->number;

    $logger->info("Processing section $secnum");

    $section->reset_caches;              # Reset the the section caches (sorting, label etc.)
    Biber::Config->_init;                # (re)initialise Config object
    $self->set_current_section($secnum); # Set the section number we are working on
    $self->fetch_data;                   # Fetch cited key and dependent data from sources
    $self->process_citekey_aliases;      # Remove citekey aliases from citekeys
    $self->instantiate_dynamic;          # Instantiate any dynamic entries (sets, related)
    $self->resolve_alias_refs;           # Resolve xref/crossref/xdata aliases to real keys
    $self->resolve_xdata;                # Resolve xdata entries
    $self->cite_setmembers;              # Cite set members
    $self->process_interentry;           # Process crossrefs/sets etc.
    $self->nullable_check;               # Check entries for nullable fields
    $self->validate_datamodel;           # Check against data model
    $self->process_entries_pre;          # Main entry processing loop, part 1
    $self->uniqueness;                   # Here we generate uniqueness information
    $self->process_visible_names;        # Generate visible names information for all entries
    $self->process_entries_post;         # Main entry processing loop, part 2
    $self->process_lists;                # process the output lists (sort and filtering)
    $self->generate_singletitle;         # Generate singletitle field if requested
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

  # tool mode only has a section 0
  my $secnum = 0;
  my $section = $self->sections->get_section($secnum);

  $section->reset_caches; # Reset the the section caches (sorting, label etc.)
  Biber::Config->_init;   # (re)initialise Config object
  $self->set_current_section($secnum); # Set the section number we are working on
  $self->fetch_data;      # Fetch cited key and dependent data from sources

  if (Biber::Config->getoption('tool_resolve')) {
    $self->resolve_alias_refs; # Resolve xref/crossref/xdata aliases to real keys
    $self->resolve_xdata;      # Resolve xdata entries
    $self->process_interentry; # Process crossrefs/sets etc.
  }

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
  # Only looking for static keys, dynamic key entries are not in any datasource ...
  my @citekeys = $section->get_static_citekeys;
  no strict 'refs'; # symbolic references below ...

  # Clear all T::B macro definitions between sections
  # T::B never clears these
  $logger->debug('Clearing Text::BibTeX macros definitions');
  Text::BibTeX::delete_all_macros();

  # (Re-)define the old BibTeX month macros to what biblatex wants unless user stops this
  unless (Biber::Config->getoption('nostdmacros')) {
    my %months = ('jan' => '01',
                  'feb' => '02',
                  'mar' => '03',
                  'apr' => '04',
                  'may' => '05',
                  'jun' => '06',
                  'jul' => '07',
                  'aug' => '08',
                  'sep' => '09',
                  'oct' => '10',
                  'nov' => '11',
                  'dec' => '12');

    foreach my $mon (keys %months) {
      Text::BibTeX::add_macro_text($mon, $months{$mon});
    }
  }

  # First we look for the directly cited keys in each datasource
  my @remaining_keys = @citekeys;
  $logger->debug('Looking for directly cited keys: ' . join(', ', @remaining_keys));
  foreach my $datasource (@{$section->get_datasources}) {
    # shortcut if we have found all the keys now
    last unless (@remaining_keys or $section->is_allkeys);
    my $type = $datasource->{type};
    my $name = $datasource->{name};
    my $datatype = $datasource->{datatype};
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

    @remaining_keys = &{"${package}::extract_entries"}($name, \@remaining_keys);
  }

  # error reporting
  $logger->debug("Directly cited keys not found for section '$secnum': " . join(',', @remaining_keys));
  foreach my $citekey (@remaining_keys) {
    biber_warn("I didn't find a database entry for '$citekey' (section $secnum)");
    $section->del_citekey($citekey);
    $section->add_undef_citekey($citekey);
  }

  # Skip dependents detection if in tool mode
  if (Biber::Config->getoption('tool')) {
    return;
  }

  $logger->debug('Building dependents for keys: ' . join(',', $section->get_citekeys));

  # dependent key list generation - has to be a sub as it's recursive to catch
  # nested crossrefs, xdata etc.
  get_dependents($self, [$section->get_citekeys]);

  $logger->debug("Citekeys for section '$secnum' after fetching data: " . join(', ', $section->get_citekeys));

  return;
}

=head2 get_dependents

  Get dependents of the entries for a given list of citekeys. Is called recursively
  until there are no more dependents to look for.

=cut

sub get_dependents {
  my ($self, $keys) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $dep_map; # Flag to say an entry has some deps so we can shortcut deletions
  my $new_deps;
  no strict 'refs'; # symbolic references below ...

  foreach my $citekey (@$keys) {
    # aliases need resolving here and are treated as dependents
    if (my $real = $section->get_citekey_alias($citekey)) {
      $logger->debug("Alias '$citekey' requires real key '$real'");
      push @$new_deps, $real;
      $dep_map->{$real} = 1;
    }
    # Dynamic sets don't exist yet but their members do
    elsif (my @dmems = $section->get_dynamic_set($citekey)) {
      # skip looking for dependent if it's already there
      foreach my $dm (@dmems) {
        unless ($section->bibentry($dm)) {
          push @$new_deps, $dm;
          $dep_map->{$citekey} = 1;
        }
      }
      $logger->debug("Dynamic set entry '$citekey' has members: " . join(', ', @dmems));
    }
    else {
      # This must exist for all but dynamic sets
      my $be = $section->bibentry($citekey);

      # xdata
      if (my $xdata = $be->get_field('xdata')) {
        foreach my $xdatum (split /\s*,\s*/, $xdata) {
          # skip looking for dependent if it's already there (loop suppression)
          push @$new_deps, $xdatum unless $section->bibentry($xdatum);
          $logger->debug("Entry '$citekey' has xdata '$xdatum'");
          $dep_map->{$citekey} = 1;
        }
      }

      # crossrefs/xrefs
      my $refkey;
      if ($refkey = $be->get_field('xref') or
          $refkey = $be->get_field('crossref')) {
        # skip looking for dependent if it's already there (loop suppression)
        push @$new_deps, $refkey unless $section->bibentry($refkey);
        $logger->debug("Entry '$citekey' has cross/xref '$refkey'");
        $dep_map->{$citekey} = 1;
      }

      # static sets
      if ($be->get_field('entrytype') eq 'set') {
        my @smems = split /\s*,\s*/, $be->get_field('entryset');
        # skip looking for dependent if it's already there (loop suppression)
        foreach my $sm (@smems) {
          unless ($section->has_citekey($sm)) {
            push @$new_deps, $sm;
            $dep_map->{$citekey} = 1;
          }
        }
        $logger->debug("Static set entry '$citekey' has members: " . join(', ', @smems));
      }

      # Related entries
      if (my $relkeys = $be->get_field('related')) {
        my @rmems = split /\s*,\s*/, $relkeys;
        # skip looking for dependent if it's already there (loop suppression)
        foreach my $rm (@rmems) {
          unless ($section->has_citekey($rm) or $section->is_related($rm)) {
            # record that $rm is used as a related entry key
            $section->add_related($rm);
            push @$new_deps, $rm;
            $dep_map->{$citekey} = 1;
          }
        }
        $logger->debug("Entry '$citekey' has related entries: " . join(', ', @rmems));
      }
    }
  }

  # Remove repeated keys which are dependents of more than one entry
  @$new_deps = uniq @$new_deps;
  my @missing;

  if (@$new_deps) {
    # Now look for the dependents of the directly cited keys
    $logger->debug('Looking for dependent keys: ' . join(', ', @$new_deps));

    # No need to go back to the datasource if allkeys, just see if the keys
    # are in section
    if ($section->is_allkeys) {
      foreach my $dk (@$new_deps) {
        push @missing, $dk unless $section->has_citekey($dk);
      }
    }
    else {
      @missing = @$new_deps;
      foreach my $datasource (@{$section->get_datasources}) {
        # shortcut if we have found all the keys now
        last unless @missing;
        my $type = $datasource->{type};
        my $name = $datasource->{name};
        my $datatype = $datasource->{datatype};
        my $package = 'Biber::Input::' . $type . '::' . $datatype;
        eval "require $package" or
          biber_error("Error loading data source package '$package': $@");
        @missing = &{"${package}::extract_entries"}($name, \@missing);
      }
    }

    # error reporting
    $logger->debug("Dependent keys not found for section '$secnum': " . join(', ', @missing));
    foreach my $citekey ($section->get_citekeys) {
      next unless $dep_map->{$citekey}; # only if we have some missing deps to delete
      foreach my $missing_key (@missing) {
        $self->remove_undef_dependent($citekey, $missing_key);
        # Remove the missing key from the list to recurse with
        @$new_deps = grep { $_ ne $missing_key } @$new_deps;
      }
    }
  }

  $logger->trace('Recursing in get_dependents with: ' . join(', ', @$new_deps));
  get_dependents($self, $new_deps) if @$new_deps; # recurse if there are more things to find
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

  # remove from any dynamic keys
  if (my @dmems = $section->get_dynamic_set($citekey)){
    if ($missing_key ~~ @dmems) {
      $section->set_dynamic_set($citekey, grep {$_ ne $missing_key} @dmems);
    }
    else {
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
      biber_warn("I didn't find a database entry for crossref '$missing_key' in entry '$citekey' - ignoring (section $secnum)");
    }

    # remove xdata
    if (my $xdata = $be->get_field('xdata')) {
      my @xdatum = split /\s*,\s*/, $xdata;
      if ($missing_key ~~ @xdatum) {
        $be->set_datafield('xdata', join(',', grep {$_ ne $missing_key} @xdatum));
        biber_warn("I didn't find a database entry for xdata entry '$missing_key' in entry '$citekey' - ignoring (section $secnum)");
      }
    }

    # remove static sets
    if ($be->get_field('entrytype') eq 'set') {
      my @smems = split /\s*,\s*/, $be->get_field('entryset');
      if ($missing_key ~~ @smems) {
        $be->set_datafield('entryset', join(',', grep {$_ ne $missing_key} @smems));
        biber_warn("I didn't find a database entry for static set member '$missing_key' in entry '$citekey' - ignoring (section $secnum)");
      }
    }

    # remove related entries
    if (my $relkeys = $be->get_field('related')) {
      my @rmems = split /\s*,\s*/, $relkeys;
      if ($missing_key ~~ @rmems) {
        $be->set_datafield('related', join(',', grep {$_ ne $missing_key} @rmems));
        # If no more related entries, remove the other related fields
        unless ($be->get_field('related')) {
          $be->del_field('relatedtype');
          $be->del_field('relatedstring');
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

  foreach my $sort (sort {$a->{order} <=> $b->{order}} @{$root_obj->{sort}}) {
    my $sortingitems;

    # Generate sorting pass structures
    foreach my $sortitem (sort {$a->{order} <=> $b->{order}} @{$sort->{sortitem}}) {
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
      if (defined($sortitem->{form})) { # Found script form attribute
        $sortitemattributes->{form} = $sortitem->{form};
      }
      if (defined($sortitem->{lang})) { # Found script lang attribute
        $sortitemattributes->{lang} = $sortitem->{lang};
      }
      push @{$sortingitems}, {$sortitem->{content} => $sortitemattributes};
    }

    # Only push a sortitem if defined. If the item has a conditional "pass"
    # attribute, it may be ommitted in which case we don't want an empty array ref
    # pushing
    # Also, we only push the sort attributes if there are any sortitems otherwise
    # we end up with a blank sort
    my $sopts;
    $sopts->{final}          = $sort->{final}          if defined($sort->{final});
    $sopts->{sort_direction} = $sort->{sort_direction} if defined($sort->{sort_direction});
    $sopts->{sortcase}       = $sort->{sortcase}       if defined($sort->{sortcase});
    $sopts->{sortupper}      = $sort->{sortupper}      if defined($sort->{sortupper});
    if (defined($sortingitems)) {
      unshift @{$sortingitems}, $sopts;
      push @{$sorting}, $sortingitems;
    }
  }
  return $sorting;
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

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2013 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
