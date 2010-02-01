package Biber::Config;

use Biber::Constants;
use IPC::Cmd qw( can_run run );
use Cwd qw( abs_path );
use Config::General qw( ParseConfig );
use Data::Dump;
use Carp;

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
$CONFIG->{state}{'crossrefkeys'} = {};
$CONFIG->{state}{'entrieswithcrossref'} = {};
$CONFIG->{state}{'inset_entries'} = {};
$CONFIG->{state}{'seennamehash'} = {};
$CONFIG->{state}{'namehashcount'} = {};
$CONFIG->{state}{'uniquenamecount'} = {};
$CONFIG->{state}{'seenauthoryear'} = {};
$CONFIG->{state}{'seenlabelyear'} = {};
$CONFIG->{state}{'seenkeys'} = {};

=head2 _init

    Reset internal hashes to defaults. This is needed for tests when
    prepare() is used more than once

=cut

sub _init {
  $CONFIG->{state}{'seennamehash'} = {};
  $CONFIG->{state}{'namehashcount'} = {};
  $CONFIG->{state}{'uniquenamecount'} = {};
  $CONFIG->{state}{'seenauthoryear'} = {};
  $CONFIG->{state}{'seenlabelyear'} = {};
  $CONFIG->{state}{'seenkeys'} = {};
  delete $CONFIG->{options}{biblatex}{PER_ENTRY};
  return;
}


=head2 _initopts

    Initialise default options, optionally with config file as argument

=cut

sub _initopts {
  shift; # class method so don't care about class name
  my $conffile = shift;
  my %LOCALCONF = ();

  # if a config file was given as cmd-line arg, it overrides everything else
  unless ( defined $conffile and -f $conffile ) {
    $conffile = config_file();
  }

  if (defined $conffile) {
    %LOCALCONF = ParseConfig(-ConfigFile => $conffile, -UTF8 => 1) or
      $logger->logcarp("Failure to read config file " . $conffile . "\n $@");
  }
  my %CONFIG = (%CONFIG_DEFAULT_BIBER, %LOCALCONF);

  foreach (keys %CONFIG) {
    Biber::Config->setoption($_, $CONFIG{$_});
  }
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

=item * C<$ENV{XDG_HOME_CONFIG}/biber/biber.conf>

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
  } elsif ( defined $ENV{XDG_HOME_CONFIG} and
            -f File::Spec->catfile($ENV{XDG_HOME_CONFIG}, "biber", $BIBER_CONF_NAME) ) {
    $biberconf = File::Spec->catfile($ENV{XDG_HOME_CONFIG}, "biber", $BIBER_CONF_NAME);
  } elsif ( $^O =~ /Mac/ and
            -f File::Spec->catfile($ENV{HOME}, "Library", "biber", $BIBER_CONF_NAME) ) {
    $biberconf = File::Spec->catfile($ENV{HOME}, "Library", "biber", $BIBER_CONF_NAME);

  } elsif ( $^O =~ /Win/ and
            defined $ENV{APPDATA} and
            -f File::Spec->catfile($ENV{APPDATA}, "biber", $BIBER_CONF_NAME) ) {
    $biberconf = File::Spec->catfile($ENV{APPDATA}, $BIBER_CONF_NAME);

  } elsif ( can_run("kpsewhich") ) {
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
    $CONFIG->{options}{biblatex}{GLOBAL}{$opt} = $val;
  }
  else { # Per-type/entry options need to specify type/entry too
    $scopeval = lc($scopeval) if $scope eq 'PER_ENTRY';
    $CONFIG->{options}{biblatex}{$scope}{$scopeval}{$opt} = $val;
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
       defined $CONFIG->{options}{biblatex}{PER_ENTRY}{lc($citekey)} and
       defined $CONFIG->{options}{biblatex}{PER_ENTRY}{lc($citekey)}{$opt}) {
    return $CONFIG->{options}{biblatex}{PER_ENTRY}{lc($citekey)}{$opt};
  }
  elsif (defined($entrytype) and
           defined $CONFIG->{options}{biblatex}{PER_TYPE}{$entrytype} and
           defined $CONFIG->{options}{biblatex}{PER_TYPE}{$entrytype}{$opt}) {
    return $CONFIG->{options}{biblatex}{PER_TYPE}{$entrytype}{$opt};
  }
  else {
    return $CONFIG->{options}{biblatex}{GLOBAL}{$opt};
  }
}

=head2 setblxsection

    Set biblatex bibsections information

=cut


sub setblxsection {
  shift; # class method so don't care about class name
  my ($num, $val) = @_;
  $CONFIG->{options}{biblatex}{GLOBAL}{bibsections}{$num} = @$val;
  return;
}

=head2 getblxsection

    Get biblatex bibsections information

=cut

sub getblxsection {
  shift; # class method so don't care about class name
  my ($num) = @_;
  return $CONFIG->{options}{biblatex}{GLOBAL}{bibsections}{$num};
}


##############################
# Biber state static methods
##############################

=head2 setstate

    Set a Biber internal state value
    setstate(<state_name>, $1, $2, $3 ... $n)

    results in:

    $CONFIG->{state}{$state_name}{$1}{$2}{$3}{...} = $n

=cut

sub setstate {
  shift; # class method so don't care about class name
  my ($statevar, @state_args) = @_;
  my $state = $CONFIG->{state}{$statevar};
  my $state_val = pop @state_args; # save the value to set
  my $state_key = pop @state_args; # save the key to set
  foreach my $state_arg (@state_args) {
    if (defined($state->{$state_arg})) {
      $state = $state->{$state_arg}; # walk down the hash structure if existing
    }
    else {
      $state = $state->{$state_arg} = {}; # otherwise instantiate as we walk
    }
  }
  $state->{$state_key} = $state_val;
  return;
}


=head2 getstate

    Get a complete Biber internal state

    getstate(<state_name>, $1, $2, $3 ... $n)

    returns:

    $CONFIG->{state}{$state_name}{$1}{$2}{$3}{...}{$n}


=cut

sub getstate {
  shift; # class method so don't care about class name
  my ($statevar, @state_args) = @_;
  my $state = $CONFIG->{state}{$statevar};
  return $state unless @state_args;
  my $state_val = pop @state_args; # save the value to get
  foreach my $state_arg (@state_args) {
    $state = $state->{$state_arg}; # walk down the hash structure
  }
  return $state->{$state_val};
}


=head2 delstate

    Delete a Biber internal state value

    delstate(<state_name>, $1, $2, $3 ... $n)

    deletes:

    $CONFIG->{state}{$state_name}{$1}{$2}{$3}{...}{$n}


=cut

sub delstate {
  shift; # class method so don't care about class name
  my ($statevar, @state_args) = @_;
  unless (@state_args) {
    delete $CONFIG->{state}{$statevar};
    return;
  }
  my $state = $CONFIG->{state}{$statevar};
  my $state_val = pop @state_args; # save the value to delete
  foreach my $state_arg (@state_args) {
    $state = $state->{$state_arg}; # walk down the hash structure
  }
  delete $state->{$state_val};
  return;
}


=head2 incrstate

    Increment a state variable counter

    incrstate(<state_name>, $1, $2, $3 ... $n)

    increments the value of

    $CONFIG->{state}{$state_name}{$1}{$2}{$3}{...}{$n}

=cut

sub incrstate {
  shift; # class method so don't care about class name
  my ($statevar, @state_args) = @_;
  my $state = $CONFIG->{state}{$statevar};
  my $state_val = pop @state_args; # save the value to increment
  foreach my $state_arg (@state_args) {
    $state = $state->{$state_arg}; # walk down the hash structure
  }
  $state->{$state_val} += 1;
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

Copyright 2009-2010 François Charette and Philip Kime, all rights reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

=cut

1;
# vim: set tabstop=4 shiftwidth=4 expandtab:
