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
use File::Slurper;
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

our $VERSION = '2.20';
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

# Citekeys which refer to the same entry
$CONFIG->{state}{citkey_aliases} = {};

# Record of which entries have inherited from other fields. Used for loop detection.
$CONFIG->{state}{crossref} = [];
$CONFIG->{state}{xdata} = [];

# Record of which entries have inherited what from whom, with the fields inherited.
# Used for generating inheritance trees
$CONFIG->{state}{graph} = {};

# Track the order of keys as cited. Keys cited in the same \cite*{} get the same order
# Used for sorting schemes which use \citeorder
$CONFIG->{state}{keyorder} = {};
$CONFIG->{state}{internalkeyorder} = {};

# Location of the control file
$CONFIG->{state}{control_file_location} = '';

# Data files per section being used by biber
$CONFIG->{state}{datafiles} = [];

=head2 _init

    Reset internal hashes to defaults.

=cut

sub _init {
  $CONFIG->{state}{uniqignore} = {};
  $CONFIG->{state}{control_file_location} = '';
  $CONFIG->{state}{crossrefkeys} = {};
  $CONFIG->{state}{xrefkeys} = {};
  $CONFIG->{state}{datafiles} = [];
  $CONFIG->{state}{crossref} = [];
  $CONFIG->{state}{xdata} = [];

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
    if (my $bc = $opts->{configtool}) { # Only used in tests to use source-tree biber-tool.conf
      _config_file_set($bc);
    }
    else {
      (my $vol, my $dir, undef) = File::Spec->splitpath( $INC{"Biber/Config.pm"} );
      $dir =~ s/\/$//; # splitpath sometimes leaves a trailing '/'
      _config_file_set(File::Spec->catpath($vol, "$dir", 'biber-tool.conf'));
    }
  }

  # Normal user config file - overrides tool mode defaults
  _config_file_set($opts->{configfile});

  # Set hard-coded biblatex option defaults
  # This has to go after _config_file_set() as this is what defines option scope
  # in tool mode (from the .conf file)
  foreach (keys %CONFIG_DEFAULT_BIBLATEX) {
    Biber::Config->setblxoption(0, $_, $CONFIG_DEFAULT_BIBLATEX{$_});
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
    if (defined($ARGV[0])) {         # ARGV is ok even in a module
      my $bcf = $ARGV[0];
      $bcf .= '.bcf' unless $bcf =~ m/\.bcf$/;
      Biber::Config->setoption('bcf', $bcf);
    }
  }

  # Set log file name
  my $biberlog;
  if (my $log = Biber::Config->getoption('logfile')) { # user specified logfile name
    $log = Biber::Utils::biber_decode_utf8($log);
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
    $biberlog = Biber::Utils::biber_decode_utf8($bcf . '.blg');
  }

  # prepend output directory for log, if specified
  if (my $outdir = Biber::Config->getoption('output_directory')) {
    my (undef, undef, $biberlogfile) = File::Spec->splitpath($biberlog);
    $biberlog = File::Spec->catfile($outdir, $biberlogfile);
  }

  # Parse output-field-replace into something easier to use
  if (my $ofrs = Biber::Config->getoption('output_field_replace')) {
    foreach my $ofr (split(/\s*,\s*/, $ofrs)) {
      my ($f, $fr) = $ofr =~ m/^([^:]+):([^:]+)$/;
      $CONFIG_OUTPUT_FIELDREPLACE{$f} = $fr;
    }
  }

  # cache meta markers since they are referenced in the oft-called _get_handler
  $CONFIG_META_MARKERS{annotation} = quotemeta(Biber::Config->getoption('annotation_marker'));
  $CONFIG_META_MARKERS{namedannotation} = quotemeta(Biber::Config->getoption('named_annotation_marker'));

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
  my $tool = Biber::Config->getoption('tool') ? ' running in TOOL mode' : '';

  $logger->info("This is Biber $vn$tool") unless Biber::Config->getoption('nolog');

  $logger->info("Config file is '" . NFC($opts->{configfile}) . "'") if $opts->{configfile};
  $logger->info("Logfile is '" . NFC($biberlog) . "'") unless Biber::Config->getoption('nolog');

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

    my $buf = NFD(Biber::Utils::slurp_switchr($conf)->$*);# Unicode NFD boundary

    $userconf = XML::LibXML::Simple::XMLin($buf,
                                           'ForceContent' => 1,
                                           'ForceArray' => [
                                                            qr/\Aoption\z/,
                                                            qr/\Amaps\z/,
                                                            qr/\Amap\z/,
                                                            qr/\Amap_step\z/,
                                                            qr/\Aper_type\z/,
                                                            qr/\Aper_nottype\z/,
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
                                                            qr/\Aentryfields\z/,
                                                            qr/\Adatetype\z/,
                                                            qr/\Adatafieldset\z/,
                                                            qr/\Acondition\z/,
                                                            qr/\A(?:or)?filter\z/,
                                                            qr/\Asortexclusion\z/,
                                                            qr/\Aexclusion\z/,
                                                            qr/\Asortingtemplate\z/,
                                                            qr/\Aconstant\z/,
                                                            qr/\Asort\z/,
                                                            qr/\Alabelalpha(?:name)?template\z/,
                                                            qr/\Asortitem\z/,
                                                            qr/\Auniquenametemplate\z/,
                                                            qr/\Anamehashtemplate\z/,
                                                            qr/\Apresort\z/,
                                                            qr/\Aoptionscope\z/,
                                                            qr/\Asortingnamekeytemplate\z/,
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
      $CONFIG_BIBLATEX_OPTIONS{$scope}{$opt}{OUTPUT} = $bcfscopeopt->{backendout} || 0;
      if (my $bin = Biber::Utils::process_backendin($bcfscopeopt->{backendin})) {
        $CONFIG_BIBLATEX_OPTIONS{$scope}{$opt}{INPUT} = $bin;
      }
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
    if (lc($k) eq 'labelalphatemplate') {
      foreach my $t ($v->@*) {
        my $latype = $t->{type};
        if ($latype eq 'global') {
          Biber::Config->setblxoption(0, 'labelalphatemplate', $t);
        }
        else {
          Biber::Config->setblxoption(0, 'labelalphatemplate',
                                      $t,
                                      'ENTRYTYPE',
                                      $latype);
        }
      }
    }
    elsif (lc($k) eq 'labelalphanametemplate') {
      foreach my $t ($v->@*) {
        my $lants;
        my $lant;
        foreach my $np (sort {$a->{order} <=> $b->{order}} $t->{namepart}->@*) {
          push $lant->@*, {namepart           => $np->{content},
                           use                => $np->{use},
                           pre                => $np->{pre},
                           substring_compound => $np->{substring_compound},
                           substring_side     => $np->{substring_side},
                           substring_width    => $np->{substring_width} };

        }
        $lants->{$t->{name}} = $lant;
        Biber::Config->setblxoption(0, 'labelalphanametemplate', $lants);
      }
    }
    elsif (lc($k) eq 'uniquenametemplate') {
      my $unts;
      foreach my $unt ($v->@*) {
        my $untval = [];
        foreach my $np (sort {$a->{order} <=> $b->{order}} $unt->{namepart}->@*) {
          push $untval->@*, {namepart        => $np->{content},
                             use             => $np->{use},
                             disambiguation  => $np->{disambiguation},
                             base            => $np->{base}};
        }
        $unts->{$unt->{name}} = $untval;
      }
      Biber::Config->setblxoption(0, 'uniquenametemplate', $unts);
    }
    elsif (lc($k) eq 'namehashtemplate') {
      my $nhts;
      foreach my $nht ($v->@*) {
        my $nhtval = [];
        foreach my $np (sort {$a->{order} <=> $b->{order}} $nht->{namepart}->@*) {
          push $nhtval->@*, {namepart        => $np->{content},
                             hashscope       => $np->{hashscope}};
        }
        $nhts->{$nht->{name}} = $nhtval;
      }
      Biber::Config->setblxoption(0, 'namehashtemplate', $nhts);
    }
    elsif (lc($k) eq 'sortingnamekeytemplate') {
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
        $snss->{$sns->{name}}{visibility} = $sns->{visibility};
        $snss->{$sns->{name}}{template} = $snkps;
      }
      Biber::Config->setblxoption(0, 'sortingnamekeytemplate', $snss);
    }
    elsif (lc($k) eq 'transliteration') {
      foreach my $tr ($v->@*) {
        if ($tr->{entrytype}[0] eq '*') { # already array forced for another option
          Biber::Config->setblxoption(0, 'translit', $tr->{translit});
        }
        else {                  # per_entrytype
          Biber::Config->setblxoption(0, 'translit',
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
      Biber::Config->setblxoption(0, $k, $v);
    }
    elsif (lc($k) eq 'sortexclusion') {# This is a biblatex option
      foreach my $sex ($v->@*) {
        my $excludes;
        foreach my $ex ($sex->{exclusion}->@*) {
          $excludes->{$ex->{content}} = 1;
        }
        Biber::Config->setblxoption(0, 'sortexclusion',
                                    $excludes,
                                    'ENTRYTYPE',
                                    $sex->{type});
      }
    }
    elsif (lc($k) eq 'sortinclusion') {# This is a biblatex option
      foreach my $sin ($v->@*) {
        my $includes;
        foreach my $in ($sin->{inclusion}->@*) {
          $includes->{$in->{content}} = 1;
        }
        Biber::Config->setblxoption(0, 'sortinclusion',
                                    $includes,
                                    'ENTRYTYPE',
                                    $sin->{type});
      }
    }
    elsif (lc($k) eq 'presort') {# This is a biblatex option
      # presort defaults
      foreach my $presort ($v->@*) {
        # Global presort default
        unless (exists($presort->{type})) {
          Biber::Config->setblxoption(0, 'presort', $presort->{content});
        }
        # Per-type default
        else {
          Biber::Config->setblxoption(0, 'presort',
                                      $presort->{content},
                                      'ENTRYTYPE',
                                      $presort->{type});
        }
      }
    }
    elsif (lc($k) eq 'sortingtemplate') {# This is a biblatex option
      my $sorttemplates;
      foreach my $ss ($v->@*) {
        $sorttemplates->{$ss->{name}} = Biber::_parse_sort($ss);
      }
      Biber::Config->setblxoption(0, 'sortingtemplate', $sorttemplates);
    }
    elsif (lc($k) eq 'datamodel') {# This is a biblatex option
      Biber::Config->addtoblxoption(0, 'datamodel', $v);
    }
    elsif (exists($v->{content})) { # simple option
      Biber::Config->setconfigfileoption($k, $v->{content});
    }
  }
}

=head2 config_file

Returns the full path of the B<Biber> configuration file.
It returns the first file found among:

=over 4

=item * C<biber.conf> or C<.biber.conf> in the current directory

=item * C<$HOME/.biber.conf>

=item * C<$ENV{XDG_CONFIG_HOME}/biber/biber.conf>

=item * C<$HOME/.config/biber/biber.conf>

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
  elsif ( -f ".$BIBER_CONF_NAME" ) {
    $biberconf = abs_path(".$BIBER_CONF_NAME");
  }
  elsif ( -f File::Spec->catfile($ENV{HOME}, ".$BIBER_CONF_NAME" ) ) {
    $biberconf = File::Spec->catfile($ENV{HOME}, ".$BIBER_CONF_NAME" );
  }
  elsif ( defined $ENV{XDG_CONFIG_HOME} and
    -f File::Spec->catfile($ENV{XDG_CONFIG_HOME}, "biber", $BIBER_CONF_NAME) ) {
    $biberconf = File::Spec->catfile($ENV{XDG_CONFIG_HOME}, "biber", $BIBER_CONF_NAME);
  }
 # See https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
  elsif ( -f File::Spec->catfile($ENV{HOME}, ".config", "biber", $BIBER_CONF_NAME) ) {
    $biberconf = File::Spec->catfile($ENV{HOME}, ".config", "biber", $BIBER_CONF_NAME);
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


=head2 addtoblxoption

    Add to an array global biblatex option

=cut

sub addtoblxoption {
  shift; # class method so don't care about class name
  my ($secnum, $opt, $val) = @_;
  if ($CONFIG_OPTSCOPE_BIBLATEX{$opt}{GLOBAL}) {
    push $CONFIG->{options}{biblatex}{GLOBAL}{$opt}->@*, $val;
  }
  return;
}

=head2 setblxoption

    Set a biblatex option on the appropriate scope

=cut

sub setblxoption {
  shift; # class method so don't care about class name
  my ($secnum, $opt, $val, $scope, $scopeval) = @_;

  # Map booleans to 1 and 0 for consistent testing
  $val = Biber::Utils::map_boolean($opt, $val, 'tonum');

  if (not defined($scope)) { # global is the default
    if ($CONFIG_OPTSCOPE_BIBLATEX{$opt}{GLOBAL}) {
      $CONFIG->{options}{biblatex}{GLOBAL}{$opt} = $val;
    }
  }
  elsif ($scope eq 'ENTRY') {
    if ($CONFIG_OPTSCOPE_BIBLATEX{$opt}{$scope}) {
      $CONFIG->{options}{biblatex}{$scope}{$scopeval}{$secnum}{$opt} = $val;
    }
  }
  else {
    if ($CONFIG_OPTSCOPE_BIBLATEX{$opt}{$scope}) {
      $CONFIG->{options}{biblatex}{$scope}{$scopeval}{$opt} = $val;
    }
  }
  return;
}

=head2 getblxoption

    Get a biblatex option from the global, per-type or per entry scope

    getblxoption('secnum', 'option', ['entrytype'], ['citekey'])

    Returns the value of option. In order of decreasing preference, returns:
    1. Biblatex option defined for entry
    2. Biblatex option defined for entry type
    3. Biblatex option defined globally

    section number needs to be present only for per-entry options as these might
    differ between sections

=cut

sub getblxoption {
  no autovivification;
  shift; # class method so don't care about class name
  my ($secnum, $opt, $entrytype, $citekey) = @_;
  # Set impossible defaults
  $secnum //= "\x{10FFFD}";
  $opt //= "\x{10FFFD}";
  $entrytype //= "\x{10FFFD}";
  $citekey //= "\x{10FFFD}";
  if ( defined($citekey) and
       $CONFIG_OPTSCOPE_BIBLATEX{$opt}{ENTRY} and
       defined $CONFIG->{options}{biblatex}{ENTRY}{$citekey}{$secnum}{$opt}) {
    return $CONFIG->{options}{biblatex}{ENTRY}{$citekey}{$secnum}{$opt};
  }
  elsif (defined($entrytype) and
         $CONFIG_OPTSCOPE_BIBLATEX{$opt}{ENTRYTYPE} and
         defined $CONFIG->{options}{biblatex}{ENTRYTYPE}{lc($entrytype)}{$opt}) {
    return $CONFIG->{options}{biblatex}{ENTRYTYPE}{lc($entrytype)}{$opt};
  }
  elsif ($CONFIG_OPTSCOPE_BIBLATEX{$opt}{GLOBAL}) {
    return $CONFIG->{options}{biblatex}{GLOBAL}{$opt};
  }
}


=head2 getblxentryoptions

    Get all per-entry options for an entry

=cut

sub getblxentryoptions {
  no autovivification;
  shift; # class method so don't care about class name
  my ($secnum, $key) = @_;
  return keys $CONFIG->{options}{biblatex}{ENTRY}{$key}{$secnum}->%*;
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

=head1 keyorder

=head2 set_keyorder

  Set key order information

=cut

sub set_keyorder {
  shift; # class method so don't care about class name
  my ($section, $key, $keyorder) = @_;
  $CONFIG->{state}{keyorder}{$section}{$key} = $keyorder;
  return;
}

=head2 set_internal_keyorder

  Set key order information for keys with the same order

=cut

sub set_internal_keyorder {
  shift; # class method so don't care about class name
  my ($section, $key, $intkeyorder) = @_;
  $CONFIG->{state}{internalkeyorder}{$section}{$key} = $intkeyorder;
  return;
}

=head2 get_keyorder

  Get key order information

=cut

sub get_keyorder {
  shift; # class method so don't care about class name
  my ($section, $key) = @_;
  return $CONFIG->{state}{keyorder}{$section}{$key};
}

=head2 get_internal_keyorder

  Get key order information for keys with the same order

=cut

sub get_internal_keyorder {
  shift; # class method so don't care about class name
  my ($section, $key) = @_;
  return $CONFIG->{state}{internalkeyorder}{$section}{$key};
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

Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our Github tracker at
L<https://github.com/plk/biber/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2012-2024 Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
