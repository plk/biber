package Biber::Config;
use v5.24;

use Biber::Constants;
use Biber::Utils;
use IPC::Cmd qw( can_run );
use IPC::Run3; # This works with PAR::Packer and Windows. IPC::Run doesn't
use Cwd qw( abs_path );
use Data::Compare;
use Data::Dump;
use Encode;
use File::Slurp;
use File::Spec;
use Carp;
use List::AllUtils qw(first max);
use Log::Log4perl qw( :no_extra_logdie_message ); # To keep PAR::Packer happy, explicitly load these
use Log::Log4perl::Appender::Screen;
use Log::Log4perl::Appender::File;
use Log::Log4perl::Layout::SimpleLayout;
use Log::Log4perl::Layout::PatternLayout;
use Unicode::Normalize;
use parent qw(Class::Accessor);
__PACKAGE__->follow_best_practice;

our $VERSION = '2.6';
our $BETA_VERSION = 0; # Is this a beta version?

our $logger  = Log::Log4perl::get_logger('main');
our $screen  = Log::Log4perl::get_logger('screen');
our $logfile = Log::Log4perl::get_logger('logfile');

=encoding utf-8


=head1 NAME

Biber::Config - Configuration items which need to be saved across the
                lifetime of a Biber object

  This class contains a static object and static methods to access
  configuration and state data. There are several classes of data in here
  which have separate accessors:

  * Biber options
  * Biblatex options
  * State information used by Biber as it processes entries
  * displaymode date

=cut


# Static (class) data
our $CONFIG;

# Uniqueness ignore information from inheritance data
$CONFIG->{state}{uniqignore} = {};

$CONFIG->{state}{crossrefkeys} = {};
$CONFIG->{state}{xrefkeys} = {};
$CONFIG->{state}{seenname} = {};
$CONFIG->{state}{seentitle} = {};
$CONFIG->{state}{seenbaretitle} = {};
$CONFIG->{state}{seenwork} = {};

# Set tracking, parent->child and child->parent
$CONFIG->{state}{set}{pc} = {};
$CONFIG->{state}{set}{cp} = {};

# Citekeys which refer to the same entry
$CONFIG->{state}{citkey_aliases} = {};

# Disambiguation data for labelalpha. Used for labelalphatemplate autoinc method
$CONFIG->{state}{ladisambiguation} = {};

# Record of which entries have inherited from other fields. Used for loop detection.
$CONFIG->{state}{crossref} = [];
$CONFIG->{state}{xdata} = [];

# Record of which entries have inherited what from whom, with the fields inherited.
# Used for generating inheritance trees
$CONFIG->{state}{graph} = {};

# For the uniquelist feature. Records the number of times a name list occurs in all entries
$CONFIG->{state}{uniquelistcount} = {};

# Boolean to say whether uniquename/uniquelist information has changed
# Default is true so that uniquename/uniquelist processing starts
$CONFIG->{state}{unulchanged} = 1;

# uniquenamecount holds a hash of familynames and familyname/initials
$CONFIG->{state}{uniquenamecount} = {};
# Same as uniquenamecount but for all names, regardless of visibility. Needed to track
# uniquelist
$CONFIG->{state}{uniquenamecount_all} = {};
# Counter for tracking name/year combinations for extrayear
$CONFIG->{state}{seen_nameyear} = {};
# Counter for the actual extrayear value
$CONFIG->{state}{seen_extrayear} = {};

# Counter for tracking name/title combinations for extratitle
$CONFIG->{state}{seen_nametitle} = {};
# Counter for the actual extratitle value
$CONFIG->{state}{seen_extratitle} = {};

# Counter for tracking title/year combinations for extratitleyear
$CONFIG->{state}{seen_titleyear} = {};
# Counter for the actual extratitleyear value
$CONFIG->{state}{seen_extratitleyear} = {};

# Counter for the actual extraalpha value
$CONFIG->{state}{seen_extraalpha} = {};
$CONFIG->{state}{seenkeys} = {};

# Track the order of keys as cited. Keys cited in the same \cite*{} get the same order
# Used for sorting schemes which use \citeorder
$CONFIG->{state}{keyorder} = {};

# Location of the control file
$CONFIG->{state}{control_file_location} = '';

# Data files per section being used by biber
$CONFIG->{state}{datafiles} = [];

=head2 _init

    Reset internal hashes to defaults.

=cut

sub _init {
  $CONFIG->{state}{uniqignore} = {};
  $CONFIG->{options}{biblatex}{ENTRY} = {};
  $CONFIG->{state}{unulchanged} = 1;
  $CONFIG->{state}{control_file_location} = '';
  $CONFIG->{state}{seenname} = {};
  $CONFIG->{state}{seentitle} = {};
  $CONFIG->{state}{seenbaretitle} = {};
  $CONFIG->{state}{seenwork} = {};
  $CONFIG->{state}{crossrefkeys} = {};
  $CONFIG->{state}{xrefkeys} = {};
  $CONFIG->{state}{ladisambiguation} = {};
  $CONFIG->{state}{uniquenamecount} = {};
  $CONFIG->{state}{uniquenamecount_all} = {};
  $CONFIG->{state}{uniquelistcount} = {};
  $CONFIG->{state}{seen_nameyear} = {};
  $CONFIG->{state}{seen_extrayear} = {};
  $CONFIG->{state}{seen_nametitle} = {};
  $CONFIG->{state}{seen_extratitle} = {};
  $CONFIG->{state}{seen_titleyear} = {};
  $CONFIG->{state}{seen_extratitleyear} = {};
  $CONFIG->{state}{seen_extrayearalpha} = {};
  $CONFIG->{state}{seenkeys} = {};
  $CONFIG->{state}{datafiles} = [];
  $CONFIG->{state}{crossref} = [];
  $CONFIG->{state}{xdata} = [];
  $CONFIG->{state}{set}{pc} = {};
  $CONFIG->{state}{set}{cp} = {};

  return;
}

=head2 _initopts

    Initialise default options, optionally with config file as argument

=cut

sub _initopts {
  shift; # class method so don't care about class name
  my $opts = shift;
  my $userconf;

  # For testing, need to be able to force ignore of conf file in case user
  # already has one which interferes with test settings.
  unless (defined($opts->{noconf})) {
    # if a config file was given as cmd-line arg, it overrides all other
    # config file locations
    unless ( defined($opts->{configfile}) and -f $opts->{configfile} ) {
      $opts->{configfile} = config_file();
    }
  }

  # Set hard-coded biber option defaults
  while (my ($k, $v) = each $CONFIG_DEFAULT_BIBER->%*) {
    if (exists($v->{content})) { # simple option
      Biber::Config->setoption($k, $v->{content});
    }
    # mildly complex options
    elsif (lc($k) eq 'dot_include' or
           lc($k) eq 'collate_options' or
           lc($k) eq 'nosort' or
           lc($k) eq 'nolabel' or
           lc($k) eq 'nolabelwidthcount' or
           lc($k) eq 'noinit' ) {
      Biber::Config->setoption($k, $v->{option});
    }
  }

  # There is a special default config file for tool mode
  # Referring to as yet unprocessed cmd-line tool option as it isn't processed until below
  if ($opts->{tool}) {
    (my $vol, my $dir, undef) = File::Spec->splitpath( $INC{"Biber/Config.pm"} );
    $dir =~ s/\/$//; # splitpath sometimes leaves a trailing '/'
    _config_file_set(File::Spec->catpath($vol, "$dir", 'biber-tool.conf'));
  }

  # Normal user config file - overrides tool mode defaults
  _config_file_set($opts->{configfile});

  # Set hard-coded biblatex option defaults
  # This has to go after _config_file_set() as this is what defines option scope
  # in tool mode (from the .conf file)
  foreach (keys %CONFIG_DEFAULT_BIBLATEX) {
    Biber::Config->setblxoption($_, $CONFIG_DEFAULT_BIBLATEX{$_});
  }

  # Command-line overrides everything else
  foreach my $copt (keys $opts->%*) {
    # This is a tricky option as we need to keep non-overriden defaults
    # If we don't we can get errors when contructing the sorting call to eval() later
    if (lc($copt) eq 'collate_options') {
      my $collopts = Biber::Config->getoption('collate_options');
      my $copt_h = eval "{ $opts->{$copt} }" or croak('Bad command-line collation options');
      # Override defaults with any cmdline settings
      foreach my $co (keys $copt_h->%*) {
        $collopts->{$co} = $copt_h->{$co};
      }
      Biber::Config->setconfigfileoption('collate_options', $collopts);
    }
    else {
      Biber::Config->setcmdlineoption($copt, $opts->{$copt});
    }
  }

  # Record the $ARGV[0] name for future use
  if (Biber::Config->getoption('tool')) {
    # Set datasource file name. In a conditional as @ARGV might not be set in tests
    if (my $dsn = $ARGV[0]) {         # ARGV is ok even in a module
      Biber::Config->setoption('dsn', $dsn);
    }
  }
  else {
    # Set control file name. In a conditional as @ARGV might not be set in tests
    if (my $bcf = $ARGV[0]) {         # ARGV is ok even in a module
      $bcf .= '.bcf' unless $bcf =~ m/\.bcf$/;
      Biber::Config->setoption('bcf', $bcf);
    }
  }

  # Set log file name
  my $biberlog;
  if (my $log = Biber::Config->getoption('logfile')) { # user specified logfile name
    # Sanitise user-specified log name
    $log =~ s/\.blg\z//xms;
    $biberlog = $log . '.blg';
  }
  elsif (not @ARGV) { # default if no .bcf file specified - mainly in tests
    Biber::Config->setoption('nolog', 1);
  }
  else {                        # set log to \jobname.blg
    my $bcf = $ARGV[0];         # ARGV is ok even in a module
    # Sanitise control file name
    $bcf =~ s/\.bcf\z//xms;
    $biberlog = $bcf . '.blg';
  }

  # prepend output directory for log, if specified
  if (my $outdir = Biber::Config->getoption('output_directory')) {
    $biberlog = File::Spec->catfile($outdir, $biberlog);
  }

  # cache meta markers since they are referenced in the oft-called _get_handler
  $CONFIG_META_MARKERS{annotation} = quotemeta(Biber::Config->getoption('annotation_marker'));
  $CONFIG_META_MARKERS{xname} = quotemeta(Biber::Config->getoption('xname_marker'));

  # Setting up Log::Log4perl
  my $LOGLEVEL;
  if (Biber::Config->getoption('trace')) {
    $LOGLEVEL = 'TRACE'
  }
  elsif (Biber::Config->getoption('debug')) {
    $LOGLEVEL = 'DEBUG'
  }
  elsif (Biber::Config->getoption('quiet') == 1) {
    $LOGLEVEL = 'ERROR'
  }
  elsif (Biber::Config->getoption('quiet') > 1) {
    $LOGLEVEL = 'FATAL'
  }
  else {
    $LOGLEVEL = 'INFO'
  }

  my $LOGLEVEL_F;
  my $LOG_MAIN;
  if (Biber::Config->getoption('nolog')) {
    $LOG_MAIN = 'Screen';
    $LOGLEVEL_F = 'OFF'
  }
  else {
    $LOG_MAIN = 'Logfile, Screen';
    $LOGLEVEL_F = $LOGLEVEL
  }

  my $LOGLEVEL_S;
  if (Biber::Config->getoption('onlylog')) {
    $LOGLEVEL_S = 'OFF'
  }
  else {
    # Max screen loglevel is INFO
    if (Biber::Config->getoption('quiet') == 1) {
      $LOGLEVEL_S = 'ERROR';
    }
    elsif (Biber::Config->getoption('quiet') > 1) {
      $LOGLEVEL_S = 'FATAL'
    }
    else {
      $LOGLEVEL_S = 'INFO';
    }
  }

  # configuration "file" for Log::Log4perl
  my $l4pconf = qq|
    log4perl.category.main                             = $LOGLEVEL, $LOG_MAIN
    log4perl.category.screen                           = $LOGLEVEL_S, Screen

    log4perl.appender.Screen                           = Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.utf8                      = 1
    log4perl.appender.Screen.Threshold                 = $LOGLEVEL_S
    log4perl.appender.Screen.stderr                    = 0
    log4perl.appender.Screen.layout                    = Log::Log4perl::Layout::SimpleLayout
|;

  # Only want a logfile appender if --nolog isn't set
  if ($LOGLEVEL_F ne 'OFF') {
    $l4pconf .= qq|
    log4perl.category.logfile                          = $LOGLEVEL_F, Logfile
    log4perl.appender.Logfile                          = Log::Log4perl::Appender::File
    log4perl.appender.Logfile.utf8                     = 1
    log4perl.appender.Logfile.Threshold                = $LOGLEVEL_F
    log4perl.appender.Logfile.filename                 = $biberlog
    log4perl.appender.Logfile.mode                     = clobber
    log4perl.appender.Logfile.layout                   = Log::Log4perl::Layout::PatternLayout
    log4perl.appender.Logfile.layout.ConversionPattern = [%r] %F{1}:%L> %p - %m%n
|;
  }

  Log::Log4perl->init(\$l4pconf);

  my $vn = $VERSION;
  $vn .= ' (beta)' if $BETA_VERSION;
  my $tool = ' running in TOOL mode' if Biber::Config->getoption('tool');

  $logger->info("This is Biber $vn$tool") unless Biber::Config->getoption('nolog');

  $logger->info("Config file is '" . $opts->{configfile} . "'") if $opts->{configfile};
  $logger->info("Logfile is '$biberlog'") unless Biber::Config->getoption('nolog');

  if (Biber::Config->getoption('debug')) {
    $screen->info("DEBUG mode: all messages are logged to '$biberlog'")
  }

  return;
}

# read a config file and set options from it
sub _config_file_set {
  my $conf = shift;
  my $userconf;

  # Can't use logcroak here because logging isn't initialised yet
  if (defined($conf)) {
    require XML::LibXML::Simple;

    my $buf = File::Slurp::read_file($conf);
    $buf = NFD(decode('UTF-8', $buf));# Unicode NFD boundary

    $userconf = XML::LibXML::Simple::XMLin($buf,
                                           'ForceContent' => 1,
                                           'ForceArray' => [
                                                            qr/\Aoption\z/,
                                                            qr/\Amaps\z/,
                                                            qr/\Amap\z/,
                                                            qr/\Amap_step\z/,
                                                            qr/\Aper_type\z/,
                                                            qr/\Aper_datasource\z/,
                                                            qr/\Atype_pair\z/,
                                                            qr/\Ainherit\z/,
                                                            qr/\Afieldor\z/,
                                                            qr/\Afieldxor\z/,
                                                            qr/\Afield\z/,
                                                            qr/\Aalias\z/,
                                                            qr/\Akeypart\z/,
                                                            qr/\Apart\z/,
                                                            qr/\Amember\z/,
                                                            qr/\Anoinit\z/,
                                                            qr/\Anolabel\z/,
                                                            qr/\Aalsoset\z/,
                                                            qr/\Aconstraints\z/,
                                                            qr/\Aconstraint\z/,
                                                            qr/\Aentrytype\z/,
                                                            qr/\Adatetype\z/,
                                                            qr/\Acondition\z/,
                                                            qr/\A(?:or)?filter\z/,
                                                            qr/\Asortexclusion\z/,
                                                            qr/\Aexclusion\z/,
                                                            qr/\Asort\z/,
                                                            qr/\Alabelalpha(?:name)?template\z/,
                                                            qr/\Asortitem\z/,
                                                            qr/\Apresort\z/,
                                                            qr/\Aoptionscope\z/,
                                                            qr/\Asortingnamekey\z/,
                                                           ],
                                           'NsStrip' => 1,
                                           'KeyAttr' => []) or
                                             croak("Failed to read biber config file '$conf'\n $@");
  }
  # Option scope has to be set first
  foreach my $bcfscopeopts ($userconf->{optionscope}->@*) {
    my $scope = $bcfscopeopts->{type};
    foreach my $bcfscopeopt ($bcfscopeopts->{option}->@*) {
      my $opt = $bcfscopeopt->{content};
      $CONFIG_OPTSCOPE_BIBLATEX{$opt}{$scope} = 1;
      $CONFIG_SCOPEOPT_BIBLATEX{$scope}{$opt} = 1;
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

  delete $userconf->{optionscope};

  # DATAFIELD SETS
  # Since we have to use the datamodel to resolve some members, just record the settings
  # here for processing after the datamodel is parsed
  foreach my $s ($userconf->{datafieldset}->@*) {
    my $name = $s->{name};
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
  delete $userconf->{datafieldset};

  # Set options from config file
  while (my ($k, $v) = each $userconf->%*) {
    # Has to be an array ref and so must come before
    # the later options tests which assume hash refs
    if (lc($k) eq 'uniquenametemplate') {
      my $unkt;
      my $bun;
      foreach my $np (sort {$a->{order} <=> $b->{order}} $v->{namepart}->@*) {

        # useful later in uniqueness tests
        if ($np->{base}) {
          push $bun->@*, $np->{content};
        }

        push $unkt->@*, {namepart => $np->{content},
                         use => $np->{use},
                         base => $np->{base}}
      }
      Biber::Config->setblxoption('uniquenametemplate', $unkt);
    }
    # Has to be an array ref and so must come before
    # the later options tests which assume hash refs
    elsif (lc($k) eq 'labelalphatemplate') {
      foreach my $t ($v->@*) {
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
    }
    elsif (lc($k) eq 'labelalphanametemplate') {
      foreach my $t ($v->@*) {
        my $lant;
        my $lantype = $t->{type};
        foreach my $np (sort {$a->{order} <=> $b->{order}} $t->{namepart}->@*) {
          push $lant->@*, {namepart           => $np->{content},
                           use                => $np->{use},
                           pre                => $np->{pre},
                           substring_compound => $np->{substring_compound},
                           substring_side     => $np->{substring_side},
                           substring_width    => $np->{substring_width} };

        }

        if ($lantype eq 'global') {
          Biber::Config->setblxoption('labelalphanametemplate', $lant);
        }
        else {
          Biber::Config->setblxoption('labelalphanametemplate', $lant, 'ENTRYTYPE', $lantype);
        }
      }
    }
    # Has to be an array ref and so must come before
    # the later options tests which assume hash refs
    elsif (lc($k) eq 'sortingnamekey') {
      my $snss;
      foreach my $sns ($v->@*) {
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
    }
    elsif (lc($k) eq 'transliteration') {
      foreach my $tr ($v->@*) {
        if ($tr->{entrytype}[0] eq '*') { # already array forced for another option
          Biber::Config->setblxoption('translit', $tr->{translit});
        }
        else {                  # per_entrytype
          Biber::Config->setblxoption('translit',
                                      $tr->{translit},
                                      'ENTRYTYPE',
                                      $tr->{entrytype}[0]);


        }
      }
    }
    # mildly complex options - nosort/collate_options
    elsif (lc($k) eq 'nosort' or
           lc($k) eq 'noinit' or
           lc($k) eq 'nolabel' ) {
      Biber::Config->setconfigfileoption($k, $v->{option});
    }
    # rather complex options
    elsif (lc($k) eq 'collate_options') {
      my $collopts = Biber::Config->getoption('collate_options');
      # Override defaults with any user settings
      foreach my $co ($v->{option}->@*) {
        $collopts->{$co->{name}} = $co->{value};
      }
      Biber::Config->setconfigfileoption($k, $collopts);
    }
    elsif (lc($k) eq 'sourcemap') {
      my $sms;
      foreach my $sm ($v->{maps}->@*) {
        if (defined($sm->{level}) and $sm->{level} eq 'driver') {
          carp("You can't set driver level sourcemaps via biber - use \\DeclareDriverSourcemap in biblatex. Ignoring map.");
        }
        elsif (defined($sm->{level}) and $sm->{level} eq 'style') {
          carp("You can't set style level sourcemaps via biber - use \\DeclareStyleSourcemap in biblatex. Ignoring map.");
        }
        else {
          push $sms->@*, $sm;
        }
      }
      Biber::Config->setconfigfileoption($k, $sms);
    }
    elsif (lc($k) eq 'inheritance') {# This is a biblatex option
      Biber::Config->setblxoption($k, $v);
    }
    elsif (lc($k) eq 'sorting') {# This is a biblatex option
      # sorting excludes
      foreach my $sex ($v->{sortexclusion}->@*) {
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
      foreach my $presort ($v->{presort}->@*) {
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
      Biber::Config->setblxoption('sorting', Biber::_parse_sort($v));
    }
    elsif (lc($k) eq 'datamodel') {# This is a biblatex option
      Biber::Config->setblxoption('datamodel', $v);
    }
    elsif (exists($v->{content})) { # simple option
      Biber::Config->setconfigfileoption($k, $v->{content});
    }
  }
}

=head2 config_file

Returns the full path of the B<Biber> configuration file.
If returns the first file found among:

=over 4

=item * C<biber.conf> in the current directory

=item * C<$HOME/.biber.conf>

=item * C<$ENV{XDG_CONFIG_HOME}/biber/biber.conf>

=item * C<$HOME/Library/biber/biber.conf> (Mac OSX only)

=item * C<$ENV{APPDATA}/biber.conf> (Windows only)

=item * the output of C<kpsewhich biber.conf> (if available on the system).

=back

If no file is found, it returns C<undef>.

=cut

sub config_file {
  my $biberconf;

  if ( -f $BIBER_CONF_NAME ) {
    $biberconf = abs_path($BIBER_CONF_NAME);
  }
  elsif ( -f File::Spec->catfile($ENV{HOME}, ".$BIBER_CONF_NAME" ) ) {
    $biberconf = File::Spec->catfile($ENV{HOME}, ".$BIBER_CONF_NAME" );
  }
  elsif ( defined $ENV{XDG_CONFIG_HOME} and
    -f File::Spec->catfile($ENV{XDG_CONFIG_HOME}, "biber", $BIBER_CONF_NAME) ) {
    $biberconf = File::Spec->catfile($ENV{XDG_CONFIG_HOME}, "biber", $BIBER_CONF_NAME);
  }
  elsif ( $^O =~ /(?:Mac|darwin)/ and
    -f File::Spec->catfile($ENV{HOME}, "Library", "biber", $BIBER_CONF_NAME) ) {
    $biberconf = File::Spec->catfile($ENV{HOME}, "Library", "biber", $BIBER_CONF_NAME);
  }
  elsif ( $^O =~ /Win/ and
    defined $ENV{APPDATA} and
    -f File::Spec->catfile($ENV{APPDATA}, "biber", $BIBER_CONF_NAME) ) {
    $biberconf = File::Spec->catfile($ENV{APPDATA}, "biber", $BIBER_CONF_NAME);
  }
  elsif ( can_run('kpsewhich') ) {
    my $err;
    run3 [ 'kpsewhich', $BIBER_CONF_NAME ], \undef, \$biberconf, \$err, { return_if_system_error => 1};
    if ($? == -1) {
      biber_error("Error running kpsewhich to look for config file: $err");
    }

    chomp $biberconf;
    $biberconf =~ s/\cM\z//xms; # kpsewhich in cygwin sometimes returns ^M at the end
    $biberconf = undef unless $biberconf; # sanitise just in case it's an empty string
  }
  else {
    $biberconf = undef;
  }

  return $biberconf;
}

##############################
# Biber options static methods
##############################


=head2 get_unul_done

    Return a boolean saying whether uniquenename+uniquelist processing is finished

=cut

sub get_unul_done {
  shift; # class method so don't care about class name
  return $CONFIG->{state}{unulchanged} ? 0 : 1;
}

=head2 set_unul_changed

    Set a boolean saying whether uniquename+uniquelist has changed

=cut

sub set_unul_changed {
  shift; # class method so don't care about class name
  my $val = shift;
  $CONFIG->{state}{unulchanged} = $val;
  return;
}

=head2 add_uniq_ignore

    Track uniqueness ignore settings found in inheritance data

=cut

sub add_uniq_ignore {
  shift; # class method so don't care about class name
  my ($key, $field, $uniqs) = @_;
  return unless $uniqs;
  foreach my $u (split(/\s*,\s*/, $uniqs)) {
    push $CONFIG->{state}{uniqignore}{$key}{$u}->@*, $field;
  }
  return;
}

=head2 get_uniq_ignore

    Retrieve uniqueness ignore settings found in inheritance data

=cut

sub get_uniq_ignore {
  no autovivification;
  shift; # class method so don't care about class name
  my $key = shift;
  return $CONFIG->{state}{uniqignore}{$key};
}

=head2 postprocess_biber_opts

    Place to postprocess biber options when they have been
    gathered from all the possible places that set them

=cut

sub postprocess_biber_opts {
  shift; # class method so don't care about class name
  # Turn sortcase and sortupper into booleans if they are not already
  # They are not booleans on the command-line/config file so that they
  # mirror biblatex option syntax for users, for example

  foreach my $opt ('sortcase', 'sortupper') {
    if (exists($CONFIG->{options}{biber}{$opt})) {
      if ($CONFIG->{options}{biber}{$opt} eq 'true') {
        $CONFIG->{options}{biber}{$opt} = 1;
      }
      elsif ($CONFIG->{options}{biber}{$opt} eq 'false') {
        $CONFIG->{options}{biber}{$opt} = 0;
      }
      unless ($CONFIG->{options}{biber}{$opt} eq '1' or
              $CONFIG->{options}{biber}{$opt} eq '0') {
        Biber::Utils::biber_error("Invalid value for option '$opt'");
      }
    }
  }
}


=head2 set_dm

    Sets the data model information object

=cut

sub set_dm {
  shift;
  my $obj = shift;
  $CONFIG->{dm} = $obj;
  return;
}

=head2 get_dm

    Gets the data model information object

=cut

sub get_dm {
  shift;
  return $CONFIG->{dm};
}

=head2 get_dm_helpers

    Sets the datamodel helper lists

=cut

sub get_dm_helpers {
  shift;
  return $CONFIG->{dm}{helpers};
}

=head2 set_ctrlfile_path

    Stores the path to the control file

=cut

sub set_ctrlfile_path {
  shift;
  $CONFIG->{control_file_location} = shift;
  return;
}

=head2 get_ctrlfile_path

    Retrieved the path to the control file

=cut

sub get_ctrlfile_path {
  shift;
  return $CONFIG->{control_file_location};
}

=head2 setoption

    Store a Biber config option

=cut

sub setoption {
  shift; # class method so don't care about class name
  my ($opt, $val) = @_;
  $CONFIG->{options}{biber}{$opt} = $val;
  return;
}

=head2 getoption

    Get a Biber option

=cut

sub getoption {
  shift; # class method so don't care about class name
  my $opt = shift;
  return $CONFIG->{options}{biber}{$opt};
}

=head2 setcmdlineoption

    Store a Biber command-line option

=cut

sub setcmdlineoption {
  shift; # class method so don't care about class name
  my ($opt, $val) = @_;
  # Command line options are also options ...
  $CONFIG->{options}{biber}{$opt} = $CONFIG->{cmdlineoptions}{$opt} = $val;
  return;
}

=head2 setconfigfileoption

    Store a Biber config-file option

=cut

sub setconfigfileoption {
  shift; # class method so don't care about class name
  my ($opt, $val) = @_;
  # Config file options are also options ...
  $CONFIG->{options}{biber}{$opt} = $CONFIG->{configfileoptions}{$opt} = $val;

  # Config file options can also be global biblatex options
  if ($CONFIG_OPTSCOPE_BIBLATEX{$opt}) {
    $CONFIG->{options}{biblatex}{GLOBAL}{$opt} = $val;
  }

  return;
}


=head2 iscmdlineoption

    Check if an option is explicitly set by user on the command
    line

=cut

sub iscmdlineoption {
  shift; # class method so don't care about class name
  my $opt = shift;
  return 1 if defined($CONFIG->{cmdlineoptions}{$opt});
  return 0;
}

=head2 isconfigfileoption

    Check if an option is explicitly set by user in their
    config file

=cut

sub isconfigfileoption {
  shift; # class method so don't care about class name
  my $opt = shift;
  return 1 if defined($CONFIG->{configfileoptions}{$opt});
  return 0;
}

=head2 isexplicitoption

    Check if an option is explicitly set by user on the command
    line or in the config file

=cut

sub isexplicitoption {
  my $self = shift;
  my $opt = shift;
  return 1 if ($self->iscmdlineoption($opt) || $self->isconfigfileoption($opt));
  return 0;
}


#################################
# BibLaTeX options static methods
#################################


=head2 setblxoption

    Set a biblatex option on the appropriate scope

=cut

sub setblxoption {
  shift; # class method so don't care about class name
  my ($opt, $val, $scope, $scopeval) = @_;
  if (not defined($scope)) { # global is the default
    if ($CONFIG_OPTSCOPE_BIBLATEX{$opt}->{GLOBAL}) {
      $CONFIG->{options}{biblatex}{GLOBAL}{$opt} = $val;
    }
  }
  else { # Per-type/entry options need to specify type/entry too
    if ($CONFIG_OPTSCOPE_BIBLATEX{$opt}->{$scope}) {
      $CONFIG->{options}{biblatex}{$scope}{$scopeval}{$opt} = $val;
    }
  }
  return;
}

=head2 getblxoption

    Get a biblatex option from the global, per-type or per entry scope

    getblxoption('option', ['entrytype'], ['citekey'])

    Returns the value of option. In order of decreasing preference, returns:
    1. Biblatex option defined for entry
    2. Biblatex option defined for entry type
    3. Biblatex option defined globally

=cut

sub getblxoption {
  no autovivification;
  shift; # class method so don't care about class name
  my ($opt, $entrytype, $citekey) = @_;
  if ( defined($citekey) and
       $CONFIG_OPTSCOPE_BIBLATEX{$opt}->{ENTRY} and
       defined $CONFIG->{options}{biblatex}{ENTRY}{$citekey}{$opt}) {
    return $CONFIG->{options}{biblatex}{ENTRY}{$citekey}{$opt};
  }
  elsif (defined($entrytype) and
         $CONFIG_OPTSCOPE_BIBLATEX{$opt}->{ENTRYTYPE} and
         defined $CONFIG->{options}{biblatex}{ENTRYTYPE}{lc($entrytype)}{$opt}) {
    return $CONFIG->{options}{biblatex}{ENTRYTYPE}{lc($entrytype)}{$opt};
  }
  elsif ($CONFIG_OPTSCOPE_BIBLATEX{$opt}->{GLOBAL}) {
    return $CONFIG->{options}{biblatex}{GLOBAL}{$opt};
  }
}


=head2 getblxentryoptions

    Get all per-entry options for an entry

=cut

sub getblxentryoptions {
  no autovivification;
  shift; # class method so don't care about class name
  my $key = shift;
  return keys $CONFIG->{options}{biblatex}{ENTRY}{$key}->%*;
}

##############################
# Inheritance state methods
##############################

=head2 set_graph

   Record node and arc connection types for .dot output

=cut

sub set_graph {
  shift; # class method so don't care about class name
  my $type = shift;
  if ($type eq 'set') {
    my ($source_key, $target_key) = @_;
    if ($logger->is_debug()) {# performance tune
      $logger->debug("Saving DOT graph information type 'set' with SOURCEKEY=$source_key, TARGETKEY=$target_key");
    }
    $CONFIG->{state}{graph}{$type}{settomem}{$source_key}{$target_key} = 1;
    $CONFIG->{state}{graph}{$type}{memtoset}{$target_key} = $source_key;
  }
  elsif ($type eq 'xref') {
    my ($source_key, $target_key) = @_;
    if ($logger->is_debug()) {# performance tune
      $logger->debug("Saving DOT graph information type 'xref' with SOURCEKEY=$source_key, TARGETKEY=$target_key");
    }
    $CONFIG->{state}{graph}{$type}{$source_key} = $target_key;
  }
  elsif ($type eq 'related') {
    my ($clone_key, $related_key, $target_key) = @_;
    if ($logger->is_debug()) {# performance tune
      $logger->debug("Saving DOT graph information type 'related' with CLONEKEY=$clone_key, RELATEDKEY=$related_key, TARGETKEY=$target_key");
    }
    $CONFIG->{state}{graph}{$type}{reltoclone}{$related_key}{$clone_key} = 1;
    $CONFIG->{state}{graph}{$type}{clonetotarget}{$clone_key}{$target_key} = 1;
  }
  else {
    my ($source_key, $target_key, $source_field, $target_field) = @_;
    if ($logger->is_debug()) {# performance tune
      $logger->debug("Saving DOT graph information type '$type' with SOURCEKEY=$source_key, TARGETKEY=$target_key, SOURCEFIELD=$source_field, TARGETFIELD=$target_field");
    }
    # source can go to more than one target (and does in default rules) so need array here
    push $CONFIG->{state}{graph}{$type}{$source_key}{$source_field}{$target_key}->@*, $target_field;
  }
  return;
}

=head2 get_graph

    Return an inheritance graph data structure for an inheritance type

=cut

sub get_graph {
  shift; # class method so don't care about class name
  my $type = shift;
  return $CONFIG->{state}{graph}{$type};
}

=head2 set_set_pc

  Record a parent->child set relationship

=cut

sub set_set_pc {
  shift; # class method so don't care about class name
  my ($parent, $child) = @_;
  $CONFIG->{state}{set}{pc}{$parent}{$child} = 1;
  return;
}

=head2 set_set_cp

  Record a child->parent set relationship

=cut

sub set_set_cp {
  shift; # class method so don't care about class name
  my ($child, $parent) = @_;
  $CONFIG->{state}{set}{cp}{$child}{$parent} = 1;
  return;
}

=head2 get_set_pc

  Return a boolean saying if there is a parent->child set relationship

=cut

sub get_set_pc {
  shift; # class method so don't care about class name
  my ($parent, $child) = @_;
  return exists($CONFIG->{state}{set}{pc}{$parent}{$child}) ? 1 : 0;
}

=head2 get_set_cp

  Return a boolean saying if there is a child->parent set relationship

=cut

sub get_set_cp {
  shift; # class method so don't care about class name
  my ($child, $parent) = @_;
  return exists($CONFIG->{state}{set}{cp}{$child}{$parent}) ? 1 : 0;
}

=head2 get_set_children

  Return a list of children for a parent set

=cut

sub get_set_children {
  shift; # class method so don't care about class name
  my $parent = shift;
  if (exists($CONFIG->{state}{set}{pc}{$parent})) {
    return (keys $CONFIG->{state}{set}{pc}{$parent}->%*);
  }
  else {
    return ();
  }
}

=head2 get_set_parents

  Return a list of parents for a child of a set

=cut

sub get_set_parents {
  shift; # class method so don't care about class name
  my $child = shift;
  if (exists($CONFIG->{state}{set}{cp}{$child})) {
    return (keys $CONFIG->{state}{set}{cp}{$child}->%*);
  }
  else {
    return ();
  }
}


=head2 set_inheritance

    Record that $target inherited information from $source
    Can be used for crossrefs and xdata. This just records that an entry
    inherited from another entry, for loop detection.

=cut

sub set_inheritance {
  shift; # class method so don't care about class name
  my ($type, $source, $target) = @_;
  push $CONFIG->{state}{$type}->@*, {s => $source, t => $target};
  return;
}


=head2 get_inheritance

    Check if $target directly inherited information from $source
    Can be used for crossrefs and xdata

=cut

sub get_inheritance {
  shift; # class method so don't care about class name
  my ($type, $source, $target) = @_;
  return first {$_->{s} eq $source and $_->{t} eq $target} $CONFIG->{state}{$type}->@*;
}

=head2 is_inheritance_path

  Checks for an inheritance path from entry $e1 to $e2
  Can be used for crossrefs and xdata

[
             {s => 'A',
              t => 'B'},
             {s => 'A',
              t => 'E'},
             {s => 'B',
              t => 'C'},
             {s => 'C',
              t => 'D'}
];

=cut

sub is_inheritance_path {
  my ($self, $type, $e1, $e2) = @_;
  foreach my $dps (grep {$_->{s} eq $e1} $CONFIG->{state}{$type}->@*) {
    return 1 if $dps->{t} eq $e2;
    return 1 if is_inheritance_path($self, $type, $dps->{t}, $e2);
  }
  return 0;
}


=head1 labelalpha disambiguation

=head2 incr_la_disambiguation

    Increment a counter to say we have seen this labelalpha

=cut

sub incr_la_disambiguation {
  shift; # class method so don't care about class name
  my $la = shift;
  $CONFIG->{state}{ladisambiguation}{$la}++;
  return;
}


=head2 get_la_disambiguation

    Get the disambiguation counter for this labelalpha.
    Return a 0 for undefs to avoid spurious errors.

=cut

sub get_la_disambiguation {
  shift; # class method so don't care about class name
  my $la = shift;
  return $CONFIG->{state}{ladisambiguation}{$la} // 0;
}

=head1 keyorder

=head2 set_keyorder

  Set some key order information

=cut

sub set_keyorder {
  shift; # class method so don't care about class name
  my ($section, $key, $keyorder) = @_;
  $CONFIG->{state}{keyorder}{$section}{$key} = $keyorder;
  return;
}

=head2 get_keyorder

  Get some key order information

=cut

sub get_keyorder {
  shift; # class method so don't care about class name
  my ($section, $key) = @_;
  return $CONFIG->{state}{keyorder}{$section}{$key};
}


=head2 get_keyorder_max

  Get maximum key order number for a section

=cut

sub get_keyorder_max {
  shift; # class method so don't care about class name
  my $section = shift;
  return (max values $CONFIG->{state}{keyorder}{$section}->%*) || 0;
}

=head2 reset_keyorder

  Reset keyorder - for use in tests where we switch to allkeys

=cut

sub reset_keyorder {
  shift; # class method so don't care about class name
  my $section = shift;
  delete $CONFIG->{state}{keyorder}{$section};
  return;
}


=head1 seenkey

=head2 get_seenkey

    Get the count of a key

=cut

sub get_seenkey {
  shift; # class method so don't care about class name
  my $key = shift;
  my $section = shift; # If passed, return count for just this section
  if (defined($section)) {
    return $CONFIG->{state}{seenkeys}{$section}{$key};
  }
  else {
    my $count;
    foreach my $section (keys $CONFIG->{state}{seenkeys}->%*) {
      $count += $CONFIG->{state}{seenkeys}{$section}{$key};
    }
    return $count;
  }
}


=head2 incr_seenkey

    Increment the seen count of a key

=cut

sub incr_seenkey {
  shift; # class method so don't care about class name
  my $key = shift;
  my $section = shift;
  $CONFIG->{state}{seenkeys}{$section}{$key}++;
  return;
}

=head2 get_seenname

    Get the count of occurrences of a labelname or labeltitle

=cut

sub get_seenname {
  shift; # class method so don't care about class name
  my $identifier = shift;
  return $CONFIG->{state}{seenname}{$identifier};
}

=head2 incr_seenname

    Increment the count of occurrences of a labelname or labeltitle

=cut

sub incr_seenname {
  shift; # class method so don't care about class name
  my $identifier = shift;
  $CONFIG->{state}{seenname}{$identifier}++;
  return;
}

=head2 get_seentitle

    Get the count of occurrences of a labeltitle

=cut

sub get_seentitle {
  shift; # class method so don't care about class name
  my $identifier = shift;
  return $CONFIG->{state}{seentitle}{$identifier};
}

=head2 incr_seentitle

    Increment the count of occurrences of a labeltitle

=cut

sub incr_seentitle {
  shift; # class method so don't care about class name
  my $identifier = shift;
  $CONFIG->{state}{seentitle}{$identifier}++;
  return;
}

=head2 get_seenbaretitle

    Get the count of occurrences of a labeltitle when there is
    no labelname

=cut

sub get_seenbaretitle {
  shift; # class method so don't care about class name
  my $identifier = shift;
  return $CONFIG->{state}{seenbaretitle}{$identifier};
}

=head2 incr_seenbaretitle

    Increment the count of occurrences of a labeltitle
    when there is no labelname

=cut

sub incr_seenbaretitle {
  shift; # class method so don't care about class name
  my $identifier = shift;
  $CONFIG->{state}{seenbaretitle}{$identifier}++;
  return;
}

=head2 get_seenwork

    Get the count of occurrences of a labelname and labeltitle

=cut

sub get_seenwork {
  shift; # class method so don't care about class name
  my $identifier = shift;
  return $CONFIG->{state}{seenwork}{$identifier};
}

=head2 incr_seenwork

    Increment the count of occurrences of a labelname and labeltitle

=cut

sub incr_seenwork {
  shift; # class method so don't care about class name
  my $identifier = shift;
  $CONFIG->{state}{seenwork}{$identifier}++;
  return;
}

=head2 incr_seenpa

    Increment the count of occurrences of a primary author family name

=cut

sub incr_seenpa {
  shift; # class method so don't care about class name
  my $identifier = shift;
  $CONFIG->{state}{seenpa}{$identifier}++;
  return;
}


=head2 get_seenpa

    Get the count of occurrences of a primary author family name

=cut

sub get_seenpa {
  shift; # class method so don't care about class name
  my $identifier = shift;
  return $CONFIG->{state}{seenpa}{$identifier};
}

=head2 reset_seen_extra

    Reset the counters for extra*

=cut

sub reset_seen_extra {
  shift; # class method so don't care about class name
  my $ay = shift;
  $CONFIG->{state}{seen_extrayear} = {};
  $CONFIG->{state}{seen_extratitle} = {};
  $CONFIG->{state}{seen_extratitleyear} = {};
  $CONFIG->{state}{seen_extraalpha} = {};
  return;
}


=head2 incr_seen_extrayear

    Increment and return the counter for extrayear

=cut

sub incr_seen_extrayear {
  shift; # class method so don't care about class name
  my $ey = shift;
  return ++$CONFIG->{state}{seen_extrayear}{$ey};
}

=head2 incr_seen_extratitle

    Increment and return the counter for extratitle

=cut

sub incr_seen_extratitle {
  shift; # class method so don't care about class name
  my $et = shift;
  return ++$CONFIG->{state}{seen_extratitle}{$et};
}

=head2 incr_seen_extratitleyear

    Increment and return the counter for extratitleyear

=cut

sub incr_seen_extratitleyear {
  shift; # class method so don't care about class name
  my $ety = shift;
  return ++$CONFIG->{state}{seen_extratitleyear}{$ety};
}


=head2 incr_seen_extraalpha

    Increment and return the counter for extraalpha

=cut

sub incr_seen_extraalpha {
  shift; # class method so don't care about class name
  my $ea = shift;
  return ++$CONFIG->{state}{seen_extraalpha}{$ea};
}


=head2 get_seen_nameyear

    Get the count of an labelname/labelyear combination for tracking
    extrayear. It uses labelyear plus name as we need to disambiguate
    entries with different labelyear (like differentiating 1984--1986 from
    just 1984)

=cut

sub get_seen_nameyear {
  shift; # class method so don't care about class name
  my $ny = shift;
  return $CONFIG->{state}{seen_nameyear}{$ny};
}

=head2 incr_seen_nameyear

    Increment the count of an labelname/labelyear combination for extrayear

    We pass in the name and year strings separately as we have to
    be careful and only increment this counter beyond 1 if there is
    a name component. Otherwise, extrayear gets defined for all
    entries with no name but the same year etc.

=cut

sub incr_seen_nameyear {
  shift; # class method so don't care about class name
  my ($ns, $ys) = @_;
  my $tmp = "$ns,$ys";
  # We can always increment this to 1
  unless ($CONFIG->{state}{seen_nameyear}{$tmp}) {
    $CONFIG->{state}{seen_nameyear}{$tmp}++;
  }
  # But beyond that only if we have a labelname in the entry since
  # this counter is used to create extrayear which doesn't mean anything for
  # entries with no name
  # We allow empty year so that we generate extrayear for the same name with no year
  # so we can do things like "n.d.-a", "n.d.-b" etc.
  else {
    if ($ns) {
      $CONFIG->{state}{seen_nameyear}{$tmp}++;
    }
  }
  return;
}


=head2 get_seen_nametitle

    Get the count of an labelname/labeltitle combination for tracking
    extratitle.

=cut

sub get_seen_nametitle {
  shift; # class method so don't care about class name
  my $nt = shift;
  return $CONFIG->{state}{seen_nametitle}{$nt};
}

=head2 incr_seen_nametitle

    Increment the count of an labelname/labeltitle combination for extratitle

    We pass in the name and year strings separately as we have to
    be careful and only increment this counter beyond 1 if there is
    a title component. Otherwise, extratitle gets defined for all
    entries with no title.

=cut

sub incr_seen_nametitle {
  shift; # class method so don't care about class name
  my ($ns, $ts) = @_;
  my $tmp = "$ns,$ts";
  # We can always increment this to 1
  unless ($CONFIG->{state}{seen_nametitle}{$tmp}) {
    $CONFIG->{state}{seen_nametitle}{$tmp}++;
  }
  # But beyond that only if we have a labeltitle in the entry since
  # this counter is used to create extratitle which doesn't mean anything for
  # entries with no title
  else {
    if ($ts) {
      $CONFIG->{state}{seen_nametitle}{$tmp}++;
    }
  }
  return;
}


=head2 get_seen_titleyear

    Get the count of an labeltitle/labelyear combination for tracking
    extratitleyear

=cut

sub get_seen_titleyear {
  shift; # class method so don't care about class name
  my $ty = shift;
  return $CONFIG->{state}{seen_titleyear}{$ty};
}

=head2 incr_seen_titleyear

    Increment the count of an labeltitle/labelyear combination for extratitleyear

    We pass in the title and year strings separately as we have to
    be careful and only increment this counter beyond 1 if there is
    a title component. Otherwise, extratitleyear gets defined for all
    entries with no title.

=cut

sub incr_seen_titleyear {
  shift; # class method so don't care about class name
  my ($ts, $ys) = @_;
  my $tmp = "$ts,$ys";
  # We can always increment this to 1
  unless ($CONFIG->{state}{seen_titleyear}{$tmp}) {
    $CONFIG->{state}{seen_titleyear}{$tmp}++;
  }
  # But beyond that only if we have a labeltitle in the entry since
  # this counter is used to create extratitleyear which doesn't mean anything for
  # entries with no title
  else {
    if ($ts) {
      $CONFIG->{state}{seen_titleyear}{$tmp}++;
    }
  }
  return;
}

=head1 uniquelistcount

=head2 get_uniquelistcount

    Get the number of uniquelist entries for a (possibly partial) list

=cut

sub get_uniquelistcount {
  shift; # class method so don't care about class name
  my $namelist = shift;
  return $CONFIG->{state}{uniquelistcount}{global}{join("\x{10FFFD}", $namelist->@*)};
}

=head2 add_uniquelistcount

    Incremenent the count for a list part to the data for a name

=cut

sub add_uniquelistcount {
  shift; # class method so don't care about class name
  my $namelist = shift;
  $CONFIG->{state}{uniquelistcount}{global}{join("\x{10FFFD}", $namelist->@*)}++;
  return;
}

=head2 add_uniquelistcount_final

    Incremenent the count for a complete list to the data for a name

=cut

sub add_uniquelistcount_final {
  shift; # class method so don't care about class name
  my $namelist = shift;
  $CONFIG->{state}{uniquelistcount}{global}{final}{join("\x{10FFFD}", $namelist->@*)}++;
  return;
}


=head2 add_uniquelistcount_minyear

    Incremenent the count for a list and year to the data for a name
    Used to track uniquelist = minyear

=cut

sub add_uniquelistcount_minyear {
  shift; # class method so don't care about class name
  my ($minyearnamelist, $year, $namelist) = @_;
  # Allow year a default in case labelname is undef
  $CONFIG->{state}{uniquelistcount}{minyear}{join("\x{10FFFD}", $minyearnamelist->@*)}{$year // '0'}{join("\x{10FFFD}", $namelist->@*)}++;
  return;
}

=head2 get_uniquelistcount_minyear

    Get the count for a list and year to the data for a name
    Used to track uniquelist = minyear

=cut

sub get_uniquelistcount_minyear {
  shift; # class method so don't care about class name
  my ($minyearnamelist, $year) = @_;
  return scalar keys $CONFIG->{state}{uniquelistcount}{minyear}{join("\x{10FFFD}", $minyearnamelist->@*)}{$year}->%*;
}



=head2 get_uniquelistcount_final

    Get the number of uniquelist entries for a full list

=cut

sub get_uniquelistcount_final {
  shift; # class method so don't care about class name
  my $namelist = shift;
  my $c = $CONFIG->{state}{uniquelistcount}{global}{final}{join("\x{10FFFD}", $namelist->@*)};
  return $c // 0;
}


=head2 reset_uniquelistcount

    Reset the count for list parts and complete lists

=cut

sub reset_uniquelistcount {
  shift; # class method so don't care about class name
  $CONFIG->{state}{uniquelistcount} = {};
  return;
}

=head2 list_differs_nth

    Returns true if some other list differs at passed nth place
    and is at least as long

    list_differs_nth([a, b, c, d, e], 3) = 1

    if there is another list like any of these:

    [a, b, d, e, f]
    [a, b, e, z, z, y]

=cut

sub list_differs_nth {
  shift; # class method so don't care about class name
  my ($list, $n) = @_;
  my @list_one = $list->@*;
  # Loop over all final lists, looking for ones which match:
  # * up to n - 1
  # * differ at $n
  # * are at least as long
  foreach my $l_s (keys $CONFIG->{state}{uniquelistcount}{global}{final}->%*) {
    my @l = split("\x{10FFFD}", $l_s);
    # If list is shorter than the list we are checking, it's irrelevant
    next unless $#l >= $list->$#*;
    # If list matches at $n, it's irrelevant;
    next if ($list_one[$n-1] eq $l[$n-1]);
    # If list doesn't match up to $n - 1, it's irrelevant
    next unless Compare([@list_one[0 .. $n-2]], [@l[0 .. $n-2]]);
    if ($logger->is_trace()) {# performance tune
      $logger->trace("list_differs_nth() returning true: " . join(',', @list_one) . " vs " . join(',', @l));
    }
    return 1;
  }
  return 0;
}



=head2 list_differs_last

    Returns true if some list differs from passed list in its last place

    list_differs_last([a, b, c]) = 1

    if there is another list like any of these:

    [a, b, d]
    [a, b, d, e]

=cut

sub list_differs_last {
  shift; # class method so don't care about class name
  my $list = shift;
  my @list_one = $list->@*;
  my $list_last = pop @list_one;

  # Loop over all final lists, looking for ones which match up to
  # length of list to check minus 1 but which differ in the last place of the
  # list to check.
  foreach my $l_s (keys $CONFIG->{state}{uniquelistcount}{global}{final}->%*) {
    my @l = split("\x{10FFFD}", $l_s);
    # If list is shorter than the list we are checking, it's irrelevant
    next unless $#l >= $list->$#*;
    # get the list elements up to length of the list we are checking
    my @ln = @l[0 .. $list->$#*];
    # pop off the last element which is the potential point of difference
    my $ln_last = pop @ln;
    if (Compare(\@list_one, \@ln) and ($list_last ne $ln_last)) {
      if ($logger->is_trace()) {# performance tune
        $logger->trace("list_differs_last() returning true: (" . join(',', @list_one) . " vs " . join(',', @ln) . " -> $list_last vs $ln_last)");
      }
      return 1;
    }
  }
  return 0;
}

=head2 list_differs_superset

    Returns true if some list differs from passed list by being
    identical to the list up to the end of the list but also
    by having extra elements after this

    list_differs_superset([a, b, c]) = 1

    if there is another list like any of these:

    [a, b, c, d]
    [a, b, c, d, e]

=cut

sub list_differs_superset {
  shift; # class method so don't care about class name
  my $list = shift;
  # Loop over all final lists, looking for ones which match up to
  # length of list to check but which differ after this length
  foreach my $l_s (keys $CONFIG->{state}{uniquelistcount}{global}{final}->%*) {
    my @l = split("\x{10FFFD}", $l_s);
    # If list is not longer than the list we are checking, it's irrelevant
    next unless $#l > $list->$#*;
    # get the list elements up to length of the list we are checking
    my @ln = @l[0 .. $list->$#*];
    if (Compare($list, \@ln)) {
        if ($logger->is_trace()) {# performance tune
          $logger->trace("list_differs_superset() returning true: (" . join(',', $list->@*) . " vs " . join(',', @l) . ")");
        }
      return 1;
    }
  }
  return 0;
}


=head1 uniquenamecount

=head2 get_numofuniquenames

    Get the number of uniquenames entries for a visible name

=cut

sub get_numofuniquenames {
  shift; # class method so don't care about class name
  my ($name, $namecontext) = @_;
  my $return = scalar keys $CONFIG->{state}{uniquenamecount}{$name}{$namecontext}->%*;
  if ($logger->is_trace()) {# performance tune
    $logger->trace("get_numofuniquenames() returning $return for NAME='$name' and NAMECONTEXT='$namecontext'");
  }
  return $return;
}

=head2 get_numofuniquenames_all

    Get the number of uniquenames entries for a name

=cut

sub get_numofuniquenames_all {
  shift; # class method so don't care about class name
  my ($name, $namecontext) = @_;
  my $return = scalar keys $CONFIG->{state}{uniquenamecount_all}{$name}{$namecontext}->%*;
  if ($logger->is_trace()) {# performance tune
    $logger->trace("get_numofuniquenames_all() returning $return for NAME='$name' and NAMECONTEXT='$namecontext'");
  }
  return $return;
}


=head2 add_uniquenamecount

    Add a name to the list of name contexts which have the name in it
    (only called for visible names)

=cut

sub add_uniquenamecount {
  shift; # class method so don't care about class name
  my ($name, $namecontext, $key) = @_;
  $CONFIG->{state}{uniquenamecount}{$name}{$namecontext}{$key}++;
  return;
}

=head2 add_uniquenamecount_all

    Add a name to the list of name contexts which have the name in it
    (called for all names)

=cut

sub add_uniquenamecount_all {
  shift; # class method so don't care about class name
  my ($name, $namecontext, $key) = @_;
  $CONFIG->{state}{uniquenamecount_all}{$name}{$namecontext}{$key}++;
  return;
}

=head2 reset_uniquenamecount

    Reset the list of names which have the name part in it

=cut

sub reset_uniquenamecount {
  shift; # class method so don't care about class name
  $CONFIG->{state}{uniquenamecount} = {};
  $CONFIG->{state}{uniquenamecount_all} = {};
  return;
}

=head2 _get_uniquename

    Get the list of name contexts which contain a name
    Mainly for use in tests

=cut

sub _get_uniquename {
  shift; # class method so don't care about class name
  my ($name, $namecontext) = @_;
  my @list = sort keys $CONFIG->{state}{uniquenamecount}{$name}{$namecontext}->%*;
  return \@list;
}

=head1 crossrefkeys

=head2 get_crossrefkeys

    Return ref to array of keys which are crossref targets

=cut

sub get_crossrefkeys {
  shift; # class method so don't care about class name
  return [ keys $CONFIG->{state}{crossrefkeys}->%* ];
}

=head1 xrefkeys

=head2 get_xrefkeys

    Return ref to array of keys which are xref targets

=cut

sub get_xrefkeys {
  shift; # class method so don't care about class name
  return [ keys $CONFIG->{state}{xrefkeys}->%* ];
}

=head2 get_crossrefkey

    Return an integer representing the number of times a
    crossref target key has been ref'ed

=cut

sub get_crossrefkey {
  shift; # class method so don't care about class name
  my $k = shift;
  return $CONFIG->{state}{crossrefkeys}{$k};
}

=head2 get_xrefkey

    Return an integer representing the number of times a
    xref target key has been ref'ed

=cut

sub get_xrefkey {
  shift; # class method so don't care about class name
  my $k = shift;
  return $CONFIG->{state}{xrefkeys}{$k};
}

=head2 del_crossrefkey

    Remove a crossref target key from the crossrefkeys state

=cut

sub del_crossrefkey {
  shift; # class method so don't care about class name
  my $k = shift;
  if (exists($CONFIG->{state}{crossrefkeys}{$k})) {
    delete $CONFIG->{state}{crossrefkeys}{$k};
  }
  return;
}

=head2 del_xrefkey

    Remove a xref target key from the xrefkeys state

=cut

sub del_xrefkey {
  shift; # class method so don't care about class name
  my $k = shift;
  if (exists($CONFIG->{state}{xrefkeys}{$k})) {
    delete $CONFIG->{state}{xrefkeys}{$k};
  }
  return;
}


=head2 incr_crossrefkey

    Increment the crossreferences count for a target crossref key

=cut

sub incr_crossrefkey {
  shift; # class method so don't care about class name
  my $k = shift;
  $CONFIG->{state}{crossrefkeys}{$k}++;
  return;
}

=head2 incr_xrefkey

    Increment the xreferences count for a target xref key

=cut

sub incr_xrefkey {
  shift; # class method so don't care about class name
  my $k = shift;
  $CONFIG->{state}{xrefkeys}{$k}++;
  return;
}

=head2 dump

    Dump config information (for debugging)

=cut

sub dump {
  shift; # class method so don't care about class name
  dd($CONFIG);
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
