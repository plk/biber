package Biber::Config;
#use feature 'unicode_strings';
use Biber::Constants;
use IPC::Cmd qw( can_run run );
use Cwd qw( abs_path );
use Config::General qw( ParseConfig );
use Data::Dump;
use Carp;
use List::AllUtils qw(first);
use Log::Log4perl qw( :no_extra_logdie_message );
my $logger = Log::Log4perl::get_logger('main');

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
$CONFIG->{state}{seennamehash} = {};
$CONFIG->{state}{keycase} = {};

# namehashcount holds a hash of namehashes and 
# occurences of unique names that generate the hash. For example:
# {AA => { Adams_A => 1, Allport_A => 2 }}
$CONFIG->{state}{namehashcount} = {};

# uniquenamecount holds a hash of lastnames and lastname/initials which point to a list
# of name(hashes) which contain them
$CONFIG->{state}{uniquenamecount} = {};
# Counter for tracking name/year combinations for extrayear
$CONFIG->{state}{seen_nameyear_extrayear} = {};
# Counter for the actual extrayear value
$CONFIG->{state}{seen_extrayear} = {};
# Counter for tracking name/year combinations for extraalpha
$CONFIG->{state}{seen_nameyear_extraalpha} = {};
# Counter for the actual extraalpha value
$CONFIG->{state}{seen_extraalpha} = {};
$CONFIG->{state}{seenkeys} = {};

# Location of the control file
$CONFIG->{state}{control_file_location} = '';

# Data files per section being used by biber
$CONFIG->{state}{datafiles} = [];

=head2 _init

    Reset internal hashes to defaults. This is needed for tests when
    prepare() is used more than once

=cut

sub _init {
  $CONFIG->{options}{biblatex}{PER_ENTRY} = {};
  $CONFIG->{state}{control_file_location} = '';
  $CONFIG->{state}{seennamehash} = {};
  $CONFIG->{state}{namehashcount} = {};
  $CONFIG->{state}{uniquenamecount} = {};
  $CONFIG->{state}{seen_nameyear_extrayear} = {};
  $CONFIG->{state}{seen_extrayear} = {};
  $CONFIG->{state}{seen_nameyear_extraalpha} = {};
  $CONFIG->{state}{seen_extraalpha} = {};
  $CONFIG->{state}{seenkeys} = {};
  $CONFIG->{state}{keycase} = {};
  $CONFIG->{state}{datafiles} = [];

  return;
}

=head2 _initopts

    Initialise default options, optionally with config file as argument

=cut

sub _initopts {
  shift; # class method so don't care about class name
  my $conffile = shift;
  my $noconf = shift;
  my %LOCALCONF = ();

  # For testing, need to be able to force ignore of conf file in case user
  # already has one which interferes with test settings.
  unless ($noconf) {
    # if a config file was given as cmd-line arg, it overrides all other
    # config file locations
    unless ( defined $conffile and -f $conffile ) {
      $conffile = config_file();
    }

    if (defined $conffile) {
      %LOCALCONF = ParseConfig(-LowerCaseNames => 1,
                               -MergeDuplicateBlocks => 1,
                               -AllowMultiOptions => 1,
                               -ConfigFile => $conffile,
                               -UTF8 => 1) or
        $logger->logcarp("Failure to read config file " . $conffile . "\n $@");
    }
  }

  # Config file overrides defaults for biber
  my %BIBER_CONFIG = (%CONFIG_DEFAULT_BIBER, %LOCALCONF);

  # Set options internally from config for biber options
  foreach (keys %BIBER_CONFIG) {
    Biber::Config->setoption($_, $BIBER_CONFIG{$_});
  }

  # Set options internally from config for biblatex options
  foreach (keys %CONFIG_DEFAULT_BIBLATEX) {
    Biber::Config->setblxoption($_, $CONFIG_DEFAULT_BIBLATEX{$_});
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
  } elsif ( -f File::Spec->catfile($ENV{HOME}, ".$BIBER_CONF_NAME" ) ) {
    $biberconf = File::Spec->catfile($ENV{HOME}, ".$BIBER_CONF_NAME" );
  } elsif ( defined $ENV{XDG_CONFIG_HOME} and
    -f File::Spec->catfile($ENV{XDG_CONFIG_HOME}, "biber", $BIBER_CONF_NAME) ) {
    $biberconf = File::Spec->catfile($ENV{XDG_CONFIG_HOME}, "biber", $BIBER_CONF_NAME);
  } elsif ( $^O =~ /(?:Mac|darwin)/ and
    -f File::Spec->catfile($ENV{HOME}, "Library", "biber", $BIBER_CONF_NAME) ) {
    $biberconf = File::Spec->catfile($ENV{HOME}, "Library", "biber", $BIBER_CONF_NAME);
  } elsif ( $^O =~ /Win/ and
    defined $ENV{APPDATA} and
    -f File::Spec->catfile($ENV{APPDATA}, "biber", $BIBER_CONF_NAME) ) {
    $biberconf = File::Spec->catfile($ENV{APPDATA}, "biber", $BIBER_CONF_NAME);
  } elsif ( can_run('kpsewhich') ) {
    scalar run( command => [ 'kpsewhich', $BIBER_CONF_NAME ],
      verbose => 0,
      buffer => \$biberconf );
  } else {
    $biberconf = undef;
  }
  return $biberconf;
}

##############################
# Biber options static methods
##############################

=head2 postprocess_biber_opts

    Place to postprocess biber options when they have been
    gathered from all the possible places that set them

=cut

sub postprocess_biber_opts {
  shift; # class method so don't care about class name

  # Turn sortcase and sortupper into booleans if they are not already
  # They are not booleans on the command-line/config file so that they
  # mirror biblatex option syntax for users
  if (exists($CONFIG->{options}{biber}{sortcase})) {
    if ($CONFIG->{options}{biber}{sortcase} eq 'true') {
      $CONFIG->{options}{biber}{sortcase} = 1;
    } elsif ($CONFIG->{options}{biber}{sortcase} eq 'false') {
      $CONFIG->{options}{biber}{sortcase} = 0;
    }
    unless ($CONFIG->{options}{biber}{sortcase} eq '1' or
            $CONFIG->{options}{biber}{sortcase} eq '0') {
      $logger->logdie("Invalid value for option 'sortcase'");
    }
  }

  if (exists($CONFIG->{options}{biber}{sortupper})) {
    if ($CONFIG->{options}{biber}{sortupper} eq 'true') {
      $CONFIG->{options}{biber}{sortupper} = 1;
    } elsif ($CONFIG->{options}{biber}{sortupper} eq 'false') {
      $CONFIG->{options}{biber}{sortupper} = 0;
    }
    unless ($CONFIG->{options}{biber}{sortupper} eq '1' or
            $CONFIG->{options}{biber}{sortupper} eq '0') {
      $logger->logdie("Invalid value for option 'sortupper'");
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

=head2 getcmdlineoption

    Get a Biber command lineoption

=cut

sub getcmdlineoption {
  shift; # class method so don't care about class name
  my $opt = shift;
  return $CONFIG->{cmdlineoptions}{$opt};
}

#################################
# BibLaTeX options static methods
#################################


=head2 setblxoption

    Set a biblatex option on the global or per entry-type scope

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
    $scopeval = lc($scopeval) if $scope eq 'PER_ENTRY';
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
       defined $CONFIG->{options}{biblatex}{PER_ENTRY}{lc($citekey)} and
       defined $CONFIG->{options}{biblatex}{PER_ENTRY}{lc($citekey)}{$opt}) {
    return $CONFIG->{options}{biblatex}{PER_ENTRY}{lc($citekey)}{$opt};
  }
  elsif (defined($entrytype) and
         $CONFIG_SCOPE_BIBLATEX{$opt}->{PER_TYPE} and
         defined $CONFIG->{options}{biblatex}{PER_TYPE}{$entrytype} and
         defined $CONFIG->{options}{biblatex}{PER_TYPE}{$entrytype}{$opt}) {
    return $CONFIG->{options}{biblatex}{PER_TYPE}{$entrytype}{$opt};
  }
  elsif ($CONFIG_SCOPE_BIBLATEX{$opt}->{GLOBAL}) {
    return $CONFIG->{options}{biblatex}{GLOBAL}{$opt};
  }
}


##############################
# Biber state static methods
##############################

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
    return $CONFIG->{state}{seenkeys}{$section}{lc($key)};
  }
  else {
    my $count;
    foreach my $section (keys %{$CONFIG->{state}{seenkeys}}) {
      $count += $CONFIG->{state}{seenkeys}{$section}{lc($key)};
    }
    return $count;
  }
}

=head2 get_keycase

    Return a key in the original case it was cited with so we
    can return mismatched cite key errors

    Biber::Config->get_keycase($key);

=cut

sub get_keycase {
  shift; # class method so don't care about class name
  my $key = shift;
  return $CONFIG->{state}{keycase}{lc($key)};
}

=head2 incr_seenkey

    Increment the seen count of a key

    Biber::Config->incr_seenkey($ay);

=cut

sub incr_seenkey {
  shift; # class method so don't care about class name
  my $key = shift;
  my $section = shift;
  $CONFIG->{state}{keycase}{lc($key)} = $key;
  $CONFIG->{state}{seenkeys}{$section}{lc($key)}++;
  return;
}


=head2 reset_seen_extra

    Reset the counters for extrayear and extraalpha

    Biber::Config->reset_extra;

=cut

sub reset_seen_extra {
  shift; # class method so don't care about class name
  my $ay = shift;
  $CONFIG->{state}{seen_extrayear}= {};
  $CONFIG->{state}{seen_extraalpha}= {};
  return;
}

#============================
#        seen_extrayear
#============================

=head2 incr_seen_extrayear

    Increment and return the counter for extrayear

    Biber::Config->incr_seen_extrayear($ay);

=cut

sub incr_seen_extrayear {
  shift; # class method so don't care about class name
  my $ay = shift;
  return ++$CONFIG->{state}{seen_extrayear}{$ay};
}


#============================
#       seen_nameyear_extrayear
#============================

=head2 get_seen_nameyear_extrayear

    Get the count of an labelname/labelyear combination for tracking
    extrayear. It uses labelyear plus name as we need to disambiguate
    entries with different labelyear (like differentiating 1984--1986 from
    just 1984)

    Biber::Config->get_seen_nameyear_extrayear($ny);

=cut

sub get_seen_nameyear_extrayear {
  shift; # class method so don't care about class name
  my $ny = shift;
  return $CONFIG->{state}{seen_nameyear_extrayear}{$ny};
}

=head2 incr_seen_nameyear_extrayear

    Increment the count of an labelname/labelyear combination for extrayear

    Biber::Config->incr_seen_nameyear_extrayear($ns, $ys);

    We pass in the name and year strings seperately as we have to
    be careful and only increment this counter beyond 1 if there is
    both a name and year component. Otherwise, extrayear gets defined for all
    entries with no name but the same year etc.

=cut

sub incr_seen_nameyear_extrayear {
  shift; # class method so don't care about class name
  my ($ns, $ys) = @_;
  $tmp = "$ns,$ys";
  # We can always increment this to 1
  unless ($CONFIG->{state}{seen_nameyear_extrayear}{$tmp}) {
    $CONFIG->{state}{seen_nameyear_extrayear}{$tmp}++;
  }
  # But beyond that only if we have a labelname and labelyear in the entry since
  # this counter is used to create extrayear which doesn't mean anything for
  # entries with only one of these.
  else {
    if ($ns and $ys) {
      $CONFIG->{state}{seen_nameyear_extrayear}{$tmp}++;
    }
  }
  return;
}

#============================
#        seen_extraalpha
#============================

=head2 incr_seen_extraalpha

    Increment and return the counter for extraalpha

    Biber::Config->incr_seen_extraalpha($ay);

=cut

sub incr_seen_extraalpha {
  shift; # class method so don't care about class name
  my $ay = shift;
  return ++$CONFIG->{state}{seen_extraalpha}{$ay};
}


#============================
#       seen_nameyear_extraalpha
#============================

=head2 get_seen_nameyear_extraalpha

    Get the count of an labelname/labelyear combination for tracking
    extraalpha. It uses labelyear plus name as we need to disambiguate
    entries with different labelyear (like differentiating 1984--1986 from
    just 1984)

    Biber::Config->get_seen_nameyear_extraalpha($ny);

=cut

sub get_seen_nameyear_extraalpha {
  shift; # class method so don't care about class name
  my $ny = shift;
  return $CONFIG->{state}{seen_nameyear_extraalpha}{$ny};
}

=head2 incr_seen_nameyear_extraalpha

    Increment the count of an labelname/labelyear combination for extraalpha

    Biber::Config->incr_seen_nameyear_extraalpha($ns, $ys);

    We pass in the name and year strings seperately as we have to
    be careful and only increment this counter beyond 1 if there is
    both a name and year component. Otherwise, extraalpha gets defined for all
    entries with no name but the same year etc.

=cut

sub incr_seen_nameyear_extraalpha {
  shift; # class method so don't care about class name
  my ($ns, $ys) = @_;
  $tmp = "$ns,$ys";
  # We can always increment this to 1
  unless ($CONFIG->{state}{seen_nameyear_extraalpha}{$tmp}) {
    $CONFIG->{state}{seen_nameyear_extraalpha}{$tmp}++;
  }
  # But beyond that only if we have a labelname and labelyear in the entry since
  # this counter is used to create extraalpha which doesn't mean anything for
  # entries with only one of these.
  else {
    if ($ns and $ys) {
      $CONFIG->{state}{seen_nameyear_extraalpha}{$tmp}++;
    }
  }
  return;
}

#============================
#       uniquenamecount
#============================

=head2 get_numofuniquenames

    Get the number of uniquenames entries for a name

    Biber::Config->get_numofuniquenames($name);

=cut

sub get_numofuniquenames {
  shift; # class method so don't care about class name
  my $name = shift;
  return $#{$CONFIG->{state}{uniquenamecount}{$name}} + 1;
}

=head2 add_uniquenamecount

    Add a hash to the list of name(hashes) which have the name part in it

    Biber::Config->add_uniquenamecount($name, $hash);

=cut

sub add_uniquenamecount {
  shift; # class method so don't care about class name
  my $namestring = shift;
  my $hash = shift;
  # name(hash) already recorded as containing namestring
  if (first {$hash eq $_} @{$CONFIG->{state}{uniquenamecount}{$namestring}}) {
    return;
  }
  # Record name(hash) as containing namestring
  else {
    push @{$CONFIG->{state}{uniquenamecount}{$namestring}}, $hash;
  }
  return;
}


=head2 _get_uniquename

    Get the uniquename hash of a lastname/hash combination
    Mainly for use in tests

    Biber::Config->get_uniquename($name);

=cut

sub _get_uniquename {
  shift; # class method so don't care about class name
  my $name = shift;
  my @list = sort @{$CONFIG->{state}{uniquenamecount}{$name}};
  return \@list;
}


#============================
#       namehashcount
#============================


=head2 get_numofnamehashes

    Get the number of name hashes

    Biber::Config->get_numofnamehashes($hash);

=cut

sub get_numofnamehashes {
  shift; # class method so don't care about class name
  my $hash = shift;
  return scalar keys %{$CONFIG->{state}{namehashcount}{$hash}};
}

=head2 namehashexists

    Check if there is an entry for a namehash

    Biber::Config->namehashexists($hash);

=cut

sub namehashexists {
  shift; # class method so don't care about class name
  my $hash = shift;
  return exists($CONFIG->{state}{namehashcount}{$hash}) ? 1 : 0;
}


=head2 get_namehashcount

    Get the count of a name hash and name id

    Biber::Config->get_namehashcount($hash, $id);

=cut

sub get_namehashcount {
  shift; # class method so don't care about class name
  my ($hash, $id) = @_;
  return $CONFIG->{state}{namehashcount}{$hash}{$id};
}

=head2 set_namehashcount

    Set the count of a name hash and name id

    Biber::Config->set_namehashcount($hash, $id, $num);

=cut

sub set_namehashcount {
  shift; # class method so don't care about class name
  my ($hash, $id, $num) = @_;
  $CONFIG->{state}{namehashcount}{$hash}{$id} = $num;
  return;
}


=head2 del_namehash

    Delete the count information for a name hash

    Biber::Config->del_namehashcount($hash);

=cut

sub del_namehash {
  shift; # class method so don't care about class name
  my $hash = shift;
  if (exists($CONFIG->{state}{namehashcount}{$hash})) {
    delete $CONFIG->{state}{namehashcount}{$hash};
  }
  return;
}

#============================
#       seennamehash
#============================


=head2 get_seennamehash

    Get the count of a seen name hash

    Biber::Config->get_seennamehash($hash);

=cut

sub get_seennamehash {
  shift; # class method so don't care about class name
  my $hash = shift;
  return $CONFIG->{state}{seennamehash}{$hash};
}


=head2 incr_seennamehash

    Increment the count of a seen name hash

    Biber::Config->incr_seennamehash($hash);

=cut

sub incr_seennamehash {
  shift; # class method so don't care about class name
  my $hash = shift;
  $CONFIG->{state}{seennamehash}{$hash}++;
  return;
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
  return $CONFIG->{state}{crossrefkeys}{lc($k)};
}

=head2 del_crossrefkey

    Remove a crossref target key from the crossrefkeys state

    Biber::Config->del_crossrefkey($key);

=cut

sub del_crossrefkey {
  shift; # class method so don't care about class name
  my $k = shift;
  if (exists($CONFIG->{state}{crossrefkeys}{lc($k)})) {
    delete $CONFIG->{state}{crossrefkeys}{lc($k)};
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
  $CONFIG->{state}{crossrefkeys}{lc($k)}++;
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
    my $key = lc($citekey);
    if ($fieldtype) {
      $CONFIG->{displaymodes}{PER_FIELD}{$key}{$fieldtype} = $val;
    }
    else {
      $CONFIG->{displaymodes}{PER_ENTRY}{$key} = $val;
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
    my $key = lc($citekey);
    if ($fieldtype and
      defined($CONFIG->{displaymodes}{PER_FIELD}) and
      defined($CONFIG->{displaymodes}{PER_FIELD}{$key}) and
      defined($CONFIG->{displaymodes}{PER_FIELD}{$key}{$fieldtype})) {
      $dm = $CONFIG->{displaymodes}{PER_FIELD}{$key}{$fieldtype};
    }
    elsif (defined($CONFIG->{displaymodes}{PER_ENTRY}) and
      defined($CONFIG->{displaymodes}{PER_ENTRY}{$key})) {
      $dm = $CONFIG->{displaymodes}{PER_ENTRY}{$key};
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
  $dm = $CONFIG->{displaymodes}{GLOBAL} unless $dm; # Global if nothing else;
  $dm = $DISPLAYMODE_DEFAULT unless $dm; # fall back to this constant
  if ( ref $dm eq 'ARRAY') {
    return $dm;
  }
  else {
    return $DISPLAYMODES{$dm};
  }
}

=head2 dump

    Dump config information (for debugging)

=cut

sub dump {
  shift; # class method so don't care about class name
  dd($CONFIG);
}

=head1 AUTHORS

François Charette, C<< <firmicus at gmx.net> >>
Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2011 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

1;

# vim: set tabstop=2 shiftwidth=2 expandtab:
