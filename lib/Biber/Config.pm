package Biber::Config;
use 5.014000;

use Biber::Constants;
use IPC::Cmd qw( can_run );
use IPC::Run3; # This works with PAR::Packer and Windows. IPC::Run doesn't
use Cwd qw( abs_path );
use Data::Compare;
use Data::Dump;
use Carp;
use List::AllUtils qw(first);
use Log::Log4perl qw( :no_extra_logdie_message ); # To keep PAR::Packer happy, explicitly load these
use Log::Log4perl::Appender::Screen;
use Log::Log4perl::Appender::File;
use Log::Log4perl::Layout::SimpleLayout;
use Log::Log4perl::Layout::PatternLayout;

our $VERSION = '1.0';
our $BETA_VERSION = 1; # Is this a beta version?

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
$CONFIG->{state}{crossrefkeys} = {};
$CONFIG->{state}{seenname} = {};

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

# uniquenamecount holds a hash of lastnames and lastname/initials
$CONFIG->{state}{uniquenamecount} = {};
# Same as uniquenamecount but for all names, regardless of visibility. Needed to track
# uniquelist
$CONFIG->{state}{uniquenamecount_all} = {};
# Counter for tracking name/year combinations for extrayear
$CONFIG->{state}{seen_nameyear} = {};
# Counter for the actual extrayear value
$CONFIG->{state}{seen_extrayear} = {};
# Counter for the actual extraalpha value
$CONFIG->{state}{seen_extraalpha} = {};
$CONFIG->{state}{seenkeys} = {};

# Location of the control file
$CONFIG->{state}{control_file_location} = '';

# Data files per section being used by biber
$CONFIG->{state}{datafiles} = [];

=head2 _init

    Reset internal hashes to defaults.

=cut

sub _init {
  $CONFIG->{options}{biblatex}{PER_ENTRY} = {};
  $CONFIG->{state}{unulchanged} = 1;
  $CONFIG->{state}{control_file_location} = '';
  $CONFIG->{state}{seenname} = {};
  $CONFIG->{state}{crossrefkeys} = {};
  $CONFIG->{state}{ladisambiguation} = {};
  $CONFIG->{state}{uniquenamecount} = {};
  $CONFIG->{state}{uniquenamecount_all} = {};
  $CONFIG->{state}{uniquelistcount} = {};
  $CONFIG->{state}{seen_nameyear} = {};
  $CONFIG->{state}{seen_extrayear} = {};
  $CONFIG->{state}{seen_extrayearalpha} = {};
  $CONFIG->{state}{seenkeys} = {};
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

    # Can't use logcroak here because logging isn't initialised yet
    if (defined($opts->{configfile})) {
      require XML::LibXML::Simple;

      $userconf = XML::LibXML::Simple::XMLin($opts->{configfile},
                                          'ForceContent' => 1,
                                          'ForceArray' => [
                                                           qr/\Aoption\z/,
                                                           qr/\Amaps\z/,
                                                           qr/\Amap\z/,
                                                           qr/\Amap_step\z/,
                                                           qr/\Aper_type\z/,
                                                           qr/\Aper_datasource\z/,
                                                          ],
                                          'NsStrip' => 1,
                                          'KeyAttr' => []) or
           croak("Failed to read biber config file '" . $opts->{configfile} . "'\n $@");
    }
  }

  # Set hard-coded biber option defaults
  while (my ($k, $v) = each %$CONFIG_DEFAULT_BIBER) {
    if (exists($v->{content})) { # simple option
      Biber::Config->setoption($k, $v->{content});
    }
    # mildly complex options - nosort/collate_options
    elsif (lc($k) eq 'collate_options' or
           lc($k) eq 'nosort') {
      Biber::Config->setoption($k, $v->{option});
    }
  }

  # Set hard-coded biblatex option defaults
  foreach (keys %CONFIG_DEFAULT_BIBLATEX) {
    Biber::Config->setblxoption($_, $CONFIG_DEFAULT_BIBLATEX{$_});
  }

  # Set options from config file.
  while (my ($k, $v) = each %$userconf) {
    if (exists($v->{content})) { # simple option
      Biber::Config->setconfigfileoption($k, $v->{content});
    }
    # mildly complex options - nosort/collate_options
    elsif (lc($k) eq 'collate_options' or
           lc($k) eq 'nosort') {
      Biber::Config->setconfigfileoption($k, $v->{option});
    }
    # rather complex options - sourcemap
    elsif (lc($k) eq 'sourcemap') {
      Biber::Config->setconfigfileoption($k, $v->{maps});
    }
  }

  # Command-line overrides everything else
  foreach (keys %$opts) {
    Biber::Config->setcmdlineoption($_, $opts->{$_});
  }

  # Set control file name. In a conditional as @ARGV might not be set in tests
  if (my $bcf = $ARGV[0]) {         # ARGV is ok even in a module
    $bcf .= '.bcf' unless $bcf =~ m/\.bcf$/;
    Biber::Config->setoption('bcf', $bcf); # only referenced in biber program
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

  $logger->info("This is Biber $vn") unless Biber::Config->getoption('nolog');

  $logger->info("Config file is '" . $opts->{configfile} . "'") if $opts->{configfile};
  $logger->info("Logfile is '$biberlog'") unless Biber::Config->getoption('nolog');

  if (Biber::Config->getoption('debug')) {
    $screen->info("DEBUG mode: all messages are logged to '$biberlog'")
  }

  return;
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
    run3  [ 'kpsewhich', $BIBER_CONF_NAME ], \undef, \$biberconf, \$err, { return_if_system_error => 1};
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


=head2 postprocess_biber_opts

    Place to postprocess biber options when they have been
    gathered from all the possible places that set them

=cut

sub postprocess_biber_opts {
  shift; # class method so don't care about class name
  # Turn sortcase, sortupper, sortfirstinits into booleans if they are not already
  # They are not booleans on the command-line/config file so that they
  # mirror biblatex option syntax for users

  # sortfirstinits
  if (exists($CONFIG->{options}{biber}{sortfirstinits})) {
    if ($CONFIG->{options}{biber}{sortfirstinits} eq 'true') {
      $CONFIG->{options}{biber}{sortfirstinits} = 1;
    }
    elsif ($CONFIG->{options}{biber}{sortfirstinits} eq 'false') {
      $CONFIG->{options}{biber}{sortfirstinits} = 0;
    }
    unless ($CONFIG->{options}{biber}{sortfirstinits} eq '1' or
            $CONFIG->{options}{biber}{sortfirstinits} eq '0') {
      biber_error("Invalid value for option 'sortfirstinits'");
    }
  }

  # sortcase
  if (exists($CONFIG->{options}{biber}{sortcase})) {
    if ($CONFIG->{options}{biber}{sortcase} eq 'true') {
      $CONFIG->{options}{biber}{sortcase} = 1;
    }
    elsif ($CONFIG->{options}{biber}{sortcase} eq 'false') {
      $CONFIG->{options}{biber}{sortcase} = 0;
    }
    unless ($CONFIG->{options}{biber}{sortcase} eq '1' or
            $CONFIG->{options}{biber}{sortcase} eq '0') {
      biber_error("Invalid value for option 'sortcase'");
    }
  }

  # sortupper
  if (exists($CONFIG->{options}{biber}{sortupper})) {
    if ($CONFIG->{options}{biber}{sortupper} eq 'true') {
      $CONFIG->{options}{biber}{sortupper} = 1;
    }
    elsif ($CONFIG->{options}{biber}{sortupper} eq 'false') {
      $CONFIG->{options}{biber}{sortupper} = 0;
    }
    unless ($CONFIG->{options}{biber}{sortupper} eq '1' or
            $CONFIG->{options}{biber}{sortupper} eq '0') {
      biber_error("Invalid value for option 'sortupper'");
    }
  }
}

=head2 set_structure

    Sets the structure information object

=cut

sub set_structure {
  shift;
  my $obj = shift;
  $CONFIG->{structure} = $obj;
  return;
}

=head2 get_structure

    Gets the structure information object

=cut

sub get_structure {
  shift;
  return $CONFIG->{structure};
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
    if ($CONFIG_SCOPE_BIBLATEX{$opt}->{GLOBAL}) {
      $CONFIG->{options}{biblatex}{GLOBAL}{$opt} = $val;
    }
  }
  else { # Per-type/entry options need to specify type/entry too
    if ($CONFIG_SCOPE_BIBLATEX{$opt}->{$scope}) {
      $CONFIG->{options}{biblatex}{$scope}{$scopeval}{$opt} = $val;
    }
  }
  return;
}

=head2 getblxoption

    Get a biblatex option from the global or per entry-type scope

    getblxoption('option', ['entrytype'], ['citekey'])

    Returns the value of option. In order of decreasing preference, returns:
    1. Biblatex option defined for entry
    2. Biblatex option defined for entry type
    3. Biblatex option defined globally

=cut

sub getblxoption {
  shift; # class method so don't care about class name
  my ($opt, $entrytype, $citekey) = @_;
  if ( defined($citekey) and
       $CONFIG_SCOPE_BIBLATEX{$opt}->{PER_ENTRY} and
       defined $CONFIG->{options}{biblatex}{PER_ENTRY}{$citekey} and
       defined $CONFIG->{options}{biblatex}{PER_ENTRY}{$citekey}{$opt}) {
    return $CONFIG->{options}{biblatex}{PER_ENTRY}{$citekey}{$opt};
  }
  elsif (defined($entrytype) and
         $CONFIG_SCOPE_BIBLATEX{$opt}->{PER_TYPE} and
         defined $CONFIG->{options}{biblatex}{PER_TYPE}{lc($entrytype)} and
         defined $CONFIG->{options}{biblatex}{PER_TYPE}{lc($entrytype)}{$opt}) {
    return $CONFIG->{options}{biblatex}{PER_TYPE}{lc($entrytype)}{$opt};
  }
  elsif ($CONFIG_SCOPE_BIBLATEX{$opt}->{GLOBAL}) {
    return $CONFIG->{options}{biblatex}{GLOBAL}{$opt};
  }
}



##############################
# Inheritance state methods
##############################

=head2 set_graph

    Record who inherited what fields from whom
    Can be used for crossrefs and xdata. This records the actual fields
    inherited from another entry, for tree generation.

    Biber::Config->set_graph($source_key, $target_key, $source_field, $target_field)

=cut

sub set_graph {
  shift; # class method so don't care about class name
  my $type = shift;
  given ($type) {
    when ('set') {
      my ($source_key, $target_key) = @_;
      $CONFIG->{state}{graph}{$type}{settomem}{$source_key}{$target_key} = 1;
      $CONFIG->{state}{graph}{$type}{memtoset}{$target_key} = $source_key;
    }
    when ('xref') {
      my ($source_key, $target_key) = @_;
      $CONFIG->{state}{graph}{$type}{$source_key} = $target_key;
    }
    when ('related') {
      my ($clone_key, $related_key, $target_key) = @_;
      $CONFIG->{state}{graph}{$type}{reltoclone}{$related_key}{$clone_key} = 1;
      $CONFIG->{state}{graph}{$type}{clonetotarget}{$clone_key}{$target_key} = 1;
    }
    default {
      my ($source_key, $target_key, $source_field, $target_field) = @_;
      $CONFIG->{state}{graph}{$type}{$source_key}{$source_field}{$target_key} = $target_field;
    }
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

    Biber::Config->set_inheritance($source, $target)

=cut

sub set_inheritance {
  shift; # class method so don't care about class name
  my ($type, $source, $target) = @_;
  push @{$CONFIG->{state}{$type}}, {s => $source, t => $target};
  return;
}


=head2 get_inheritance

    Check if $target directly inherited information from $source
    Can be used for crossrefs and xdata

    Biber::Config->get_inheritance($source, $target)

=cut

sub get_inheritance {
  shift; # class method so don't care about class name
  my ($type, $source, $target) = @_;
  return first {$_->{s} eq $source and $_->{t} eq $target} @{$CONFIG->{state}{$type}};
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

  Biber::Config->is_inheritance_path($type, $key1, $key2)

=cut

sub is_inheritance_path {
  my ($self, $type, $e1, $e2) = @_;
  foreach my $dps (grep {$_->{s} eq $e1} @{$CONFIG->{state}{$type}}) {
    return 1 if $dps->{t} eq $e2;
    return 1 if is_inheritance_path($self, $type, $dps->{t}, $e2);
  }
  return 0;
}


##############################
# Biber state static methods
##############################

#============================
#  labelalpha disambiguation
#============================

=head2 incr_la_disambiguation

    Increment a counter to say we have seen this labelalpha

    Biber::Config->incr_la_disambiguation($la);

=cut

sub incr_la_disambiguation {
  shift; # class method so don't care about class name
  my $la = shift;
  $CONFIG->{state}{ladisambiguation}{$la}++;
  return;
}


=head2 get_la_disambiguation

    Get the disambiguation counter for this labelalpha

    Biber::Config->get_la_disambiguation($la);

=cut

sub get_la_disambiguation {
  shift; # class method so don't care about class name
  my $la = shift;
  return $CONFIG->{state}{ladisambiguation}{$la};
}



#============================
#        seenkey
#============================

=head2 get_seenkey

    Get the count of a key

    Biber::Config->get_seenkey($hash);

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
    foreach my $section (keys %{$CONFIG->{state}{seenkeys}}) {
      $count += $CONFIG->{state}{seenkeys}{$section}{$key};
    }
    return $count;
  }
}


=head2 incr_seenkey

    Increment the seen count of a key

    Biber::Config->incr_seenkey($ay);

=cut

sub incr_seenkey {
  shift; # class method so don't care about class name
  my $key = shift;
  my $section = shift;
  $CONFIG->{state}{seenkeys}{$section}{$key}++;
  return;
}

=head2 get_seenname

    Get the count of occurences of a labelname which
    takes into account all of maxcitenames, uniquelist,
    uniquename, useprefix

    Biber::Config->get_seenname($name);

=cut

sub get_seenname {
  shift; # class method so don't care about class name
  my $name = shift;
  return $CONFIG->{state}{seenname}{$name};
}

=head2 incr_seenname

    Increment the count of occurences of a labelname which
    takes into account all of maxcitenames, uniquelist,
    uniquename, useprefix

    Biber::Config->incr_seename($name);

=cut

sub incr_seenname {
  shift; # class method so don't care about class name
  my $name = shift;
  $CONFIG->{state}{seenname}{$name}++;
  return;
}



=head2 reset_seen_extra

    Reset the counters for extra*

    Biber::Config->reset_extra;

=cut

sub reset_seen_extra {
  shift; # class method so don't care about class name
  my $ay = shift;
  $CONFIG->{state}{seen_extrayear} = {};
  $CONFIG->{state}{seen_extraalpha} = {};
  return;
}


=head2 incr_seen_extrayear

    Increment and return the counter for extrayear

    Biber::Config->incr_seen_extrayear($ay);

=cut

sub incr_seen_extrayear {
  shift; # class method so don't care about class name
  my $ey = shift;
  return ++$CONFIG->{state}{seen_extrayear}{$ey};
}


=head2 incr_seen_extraalpha

    Increment and return the counter for extraalpha

    Biber::Config->incr_seen_extraalpha($ay);

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

    Biber::Config->get_seen_nameyear($ny);

=cut

sub get_seen_nameyear {
  shift; # class method so don't care about class name
  my $ny = shift;
  return $CONFIG->{state}{seen_nameyear}{$ny};
}

=head2 incr_seen_nameyear

    Increment the count of an labelname/labelyear combination for extrayear

    Biber::Config->incr_seen_nameyear($ns, $ys);

    We pass in the name and year strings seperately as we have to
    be careful and only increment this counter beyond 1 if there is
    both a name and year component. Otherwise, extrayear gets defined for all
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
  # But beyond that only if we have a labelname and labelyear in the entry since
  # this counter is used to create extrayear which doesn't mean anything for
  # entries with only one of these.
  else {
    if ($ns and $ys) {
      $CONFIG->{state}{seen_nameyear}{$tmp}++;
    }
  }
  return;
}

#============================
#       uniquelistcount
#============================

=head2 get_uniquelistcount

    Get the number of uniquelist entries for a (possibly partial) list

    Biber::Config->get_uniquelistcount($namelist);

=cut

sub get_uniquelistcount {
  shift; # class method so don't care about class name
  my $namelist = shift;
  return $CONFIG->{state}{uniquelistcount}{global}{join("\x{10FFFD}", @$namelist)};
}

=head2 add_uniquelistcount

    Incremenent the count for a list part to the data for a name

    Biber::Config->add_uniquelistcount($liststring);

=cut

sub add_uniquelistcount {
  shift; # class method so don't care about class name
  my $namelist = shift;
  $CONFIG->{state}{uniquelistcount}{global}{join("\x{10FFFD}", @$namelist)}++;
  return;
}

=head2 add_uniquelistcount_final

    Incremenent the count for a complete list to the data for a name

    Biber::Config->add_uniquelistcount_final($liststring);

=cut

sub add_uniquelistcount_final {
  shift; # class method so don't care about class name
  my $namelist = shift;
  $CONFIG->{state}{uniquelistcount}{global}{final}{join("\x{10FFFD}", @$namelist)}++;
  return;
}


=head2 add_uniquelistcount_minyear

    Incremenent the count for a list and year to the data for a name
    Used to track uniquelist = minyear

    Biber::Config->add_uniquelistcount_minyear($minyearliststring, $year, $namelist);

=cut

sub add_uniquelistcount_minyear {
  shift; # class method so don't care about class name
  my ($minyearnamelist, $year, $namelist) = @_;
  # Allow year a default in case labelname is undef
  $CONFIG->{state}{uniquelistcount}{minyear}{join("\x{10FFFD}", @$minyearnamelist)}{$year // '0'}{join("\x{10FFFD}", @$namelist)}++;
  return;
}

=head2 get_uniquelistcount_minyear

    Get the count for a list and year to the data for a name
    Used to track uniquelist = minyear

    Biber::Config->get_uniquelistcount_minyear($minyearliststring, $year);

=cut

sub get_uniquelistcount_minyear {
  shift; # class method so don't care about class name
  my ($minyearnamelist, $year) = @_;
  return scalar keys %{$CONFIG->{state}{uniquelistcount}{minyear}{join("\x{10FFFD}", @$minyearnamelist)}{$year}};
}



=head2 get_uniquelistcount_final

    Get the number of uniquelist entries for a full list

    Biber::Config->get_uniquelistcount_final($namelist);

=cut

sub get_uniquelistcount_final {
  shift; # class method so don't care about class name
  my $namelist = shift;
  my $c = $CONFIG->{state}{uniquelistcount}{global}{final}{join("\x{10FFFD}", @$namelist)};
  return $c // 0;
}


=head2 reset_uniquelistcount

    Reset the count for list parts and complete lists

    Biber::Config->reset_uniquelistcount;

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

    Biber::Config->list_differs_nth($namelist, $n)

=cut

sub list_differs_nth {
  shift; # class method so don't care about class name
  my ($list, $n) = @_;
  my @list_one = @$list;
  # Loop over all final lists, looking for ones which match:
  # * up to n - 1
  # * differ at $n
  # * are at least as long
  foreach my $l_s (keys %{$CONFIG->{state}{uniquelistcount}{global}{final}}) {
    my @l = split("\x{10FFFD}", $l_s);
    # If list is shorter than the list we are checking, it's irrelevant
    next unless $#l >= $#$list;
    # If list matches at $n, it's irrelevant;
    next if ($list_one[$n-1] eq $l[$n-1]);
    # If list doesn't match up to $n - 1, it's irrelevant
    next unless Compare([@list_one[0 .. $n-2]], [@l[0 .. $n-2]]);
    $logger->trace("list_differs_nth() returning true: " . join(',', @list_one) . " vs " . join(',', @l));
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

    Biber::Config->list_differs_last($namelist)

=cut

sub list_differs_last {
  shift; # class method so don't care about class name
  my $list = shift;
  my @list_one = @$list;
  my $list_last = pop @list_one;

  # Loop over all final lists, looking for ones which match up to
  # length of list to check minus 1 but which differ in the last place of the
  # list to check.
  foreach my $l_s (keys %{$CONFIG->{state}{uniquelistcount}{global}{final}}) {
    my @l = split("\x{10FFFD}", $l_s);
    # If list is shorter than the list we are checking, it's irrelevant
    next unless $#l >= $#$list;
    # get the list elements up to length of the list we are checking
    my @ln = @l[0 .. $#$list];
    # pop off the last element which is the potential point of difference
    my $ln_last = pop @ln;
    if (Compare(\@list_one, \@ln) and ($list_last ne $ln_last)) {
      $logger->trace("list_differs_last() returning true: (" . join(',', @list_one) . " vs " . join(',', @ln) . " -> $list_last vs $ln_last)");
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

    Biber::Config->list_differs_superset($namelist)

=cut

sub list_differs_superset {
  shift; # class method so don't care about class name
  my $list = shift;
  # Loop over all final lists, looking for ones which match up to
  # length of list to check but which differ after this length
  foreach my $l_s (keys %{$CONFIG->{state}{uniquelistcount}{global}{final}}) {
    my @l = split("\x{10FFFD}", $l_s);
    # If list is not longer than the list we are checking, it's irrelevant
    next unless $#l > $#$list;
    # get the list elements up to length of the list we are checking
    my @ln = @l[0 .. $#$list];
    if (Compare($list, \@ln)) {
      $logger->trace("list_differs_superset() returning true: (" . join(',', @$list) . " vs " . join(',', @l) . ")");
      return 1;
    }
  }
  return 0;
}


#============================
#       uniquenamecount
#============================

=head2 get_numofuniquenames

    Get the number of uniquenames entries for a visible name

    Biber::Config->get_numofuniquenames($name);

=cut

sub get_numofuniquenames {
  shift; # class method so don't care about class name
  my ($name, $namecontext, $key) = @_;
  $key = '' unless $key; # default for the tracing so we don't get an undef string warning
  my $return = scalar keys %{$CONFIG->{state}{uniquenamecount}{$name}{$namecontext}};
  $logger->trace("get_numofuniquenames() returning $return for NAME='$name' and NAMECONTEXT='$namecontext'");
  return $return;
}

=head2 get_numofuniquenames_all

    Get the number of uniquenames entries for a name

    Biber::Config->get_numofuniquenames_all($name);

=cut

sub get_numofuniquenames_all {
  shift; # class method so don't care about class name
  my ($name, $namecontext, $key) = @_;
  $key = '' unless $key; # default for the tracing so we don't get an undef string warning
  my $return = scalar keys %{$CONFIG->{state}{uniquenamecount_all}{$name}{$namecontext}};
  $logger->trace("get_numofuniquenames_all() returning $return for NAME='$name' and NAMECONTEXT='$namecontext'");
  return $return;
}


=head2 add_uniquenamecount

    Add a name to the list of name contexts which have the name in it
    (only called for visible names)

    Biber::Config->add_uniquenamecount($name, $namecontext);

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

    Biber::Config->add_uniquenamecount_all($name, $namecontext);

=cut

sub add_uniquenamecount_all {
  shift; # class method so don't care about class name
  my ($name, $namecontext, $key) = @_;
  $CONFIG->{state}{uniquenamecount_all}{$name}{$namecontext}{$key}++;
  return;
}

=head2 reset_uniquenamecount

    Reset the list of names which have the name part in it

    Biber::Config->reset_uniquenamecount;

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

    Biber::Config->get_uniquename($name);

=cut

sub _get_uniquename {
  shift; # class method so don't care about class name
  my ($name, $namecontext) = @_;
  my @list = sort keys %{$CONFIG->{state}{uniquenamecount}{$name}{$namecontext}};
  return \@list;
}


#============================
#       crossrefkeys
#============================


=head2 get_crossrefkeys

    Return ref to array of keys which are crossref targets

    Biber::Config->get_crossrefkeys();

=cut

sub get_crossrefkeys {
  shift; # class method so don't care about class name
  return [ keys %{$CONFIG->{state}{crossrefkeys}} ];
}

=head2 get_crossrefkey

    Return an integer representing the number of times a
    crossref target key has been ref'ed

    Biber::Config->get_crossrefkey($key);

=cut

sub get_crossrefkey {
  shift; # class method so don't care about class name
  my $k = shift;
  return $CONFIG->{state}{crossrefkeys}{$k};
}

=head2 del_crossrefkey

    Remove a crossref target key from the crossrefkeys state

    Biber::Config->del_crossrefkey($key);

=cut

sub del_crossrefkey {
  shift; # class method so don't care about class name
  my $k = shift;
  if (exists($CONFIG->{state}{crossrefkeys}{$k})) {
    delete $CONFIG->{state}{crossrefkeys}{$k};
  }
  return;
}

=head2 incr_crossrefkey

    Increment the crossreferences count for a target crossref key

    Biber::Config->incr_crossrefkey($key);

=cut

sub incr_crossrefkey {
  shift; # class method so don't care about class name
  my $k = shift;
  $CONFIG->{state}{crossrefkeys}{$k}++;
  return;
}


############################
# Displaymode static methods
############################

=head2 set_displaymode

    Set the display mode for a field.
    setdisplaymode(['entrytype'], ['field'], ['citekey'], $value)

    This sets the desired displaymode to use for some data in the bib.
    Of course, this is entirey seperate semantically from the
    displaymodes *defined* in the bib which just tell you what to return
    for a particular displaymode request for some data.

=cut

sub set_displaymode {
  shift; # class method so don't care about class name
  my ($val, $entrytype, $fieldtype, $citekey) = @_;
  if ($citekey) {
    if ($fieldtype) {
      $CONFIG->{displaymodes}{PER_FIELD}{$citekey}{$fieldtype} = $val;
    }
    else {
      $CONFIG->{displaymodes}{PER_ENTRY}{$citekey} = $val;
    }
  }
  elsif ($fieldtype) {
    $CONFIG->{displaymodes}{PER_FIELDTYPE}{$fieldtype} = $val;
  }
  elsif ($entrytype) {
    $CONFIG->{displaymodes}{PER_ENTRYTYPE}{$entrytype} = $val;
  }
  else {
    $CONFIG->{displaymodes}{GLOBAL} = $val ;
  }
}

=head2 get_displaymode

    Get the display mode for a field.
    getdisplaymode(['entrytype'], ['field'], ['citekey'])

    Returns the displaymode. In order of decreasing preference, returns:
    1. Mode defined for a specific field in a specific citekey
    2. Mode defined for a citekey
    3. Mode defined for a fieldtype (any citekey)
    4. Mode defined for an entrytype (any citekey)
    5. Mode defined globally (any citekey)

=cut

sub get_displaymode {
  shift; # class method so don't care about class name
  my ($entrytype, $fieldtype, $citekey) = @_;
  my $dm;
  if ($citekey) {
    if ($fieldtype and
      defined($CONFIG->{displaymodes}{PER_FIELD}) and
      defined($CONFIG->{displaymodes}{PER_FIELD}{$citekey}) and
      defined($CONFIG->{displaymodes}{PER_FIELD}{$citekey}{$fieldtype})) {
      $dm = $CONFIG->{displaymodes}{PER_FIELD}{$citekey}{$fieldtype};
    }
    elsif (defined($CONFIG->{displaymodes}{PER_ENTRY}) and
      defined($CONFIG->{displaymodes}{PER_ENTRY}{$citekey})) {
      $dm = $CONFIG->{displaymodes}{PER_ENTRY}{$citekey};
    }
  }
  elsif ($fieldtype and
    defined($CONFIG->{displaymodes}{PER_FIELDTYPE}) and
    defined($CONFIG->{displaymodes}{PER_FIELDTYPE}{$fieldtype})) {
    $dm = $CONFIG->{displaymodes}{PER_FIELDTYPE}{$fieldtype};
  }
  elsif ($entrytype and
    defined($CONFIG->{displaymodes}{PER_ENTRYTYPE}) and
    defined($CONFIG->{displaymodes}{PER_ENTRYTYPE}{$entrytype})) {
    $dm = $CONFIG->{displaymodes}{PER_ENTRYTYPE}{$entrytype};
  }
  $dm = $CONFIG->{displaymodes}{'*'} unless $dm; # Global if nothing else;
  return $dm;
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

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2012 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
