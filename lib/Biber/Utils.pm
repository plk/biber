package Biber::Utils;
use 5.014000;
use strict;
use warnings;
use re 'eval';
use base 'Exporter';

use constant {
  EXIT_OK => 0,
  EXIT_ERROR => 2
};

use Carp;
use Encode;
use File::Find;
use File::Spec;
use IPC::Cmd qw( can_run );
use IPC::Run3; # This works with PAR::Packer and Windows. IPC::Run doesn't
use Biber::Constants;
use Biber::LaTeX::Recode;
use Biber::Entry::Name;
use Regexp::Common qw( balanced );
use Log::Log4perl qw(:no_extra_logdie_message);
my $logger = Log::Log4perl::get_logger('main');

=encoding utf-8

=head1 NAME

Biber::Utils - Various utility subs used in Biber

=cut

=head1 EXPORT

All functions are exported by default.

=cut

our @EXPORT = qw{ locate_biber_file driver_config makenamesid makenameid stringify_hash
  normalise_string normalise_string_hash normalise_string_underscore normalise_string_sort
  normalise_string_label reduce_array remove_outer add_outer ucinit strip_nosort strip_noinit
  is_def is_undef is_def_and_notnull is_def_and_null
  is_undef_or_null is_notnull is_null normalise_utf8 inits join_name latex_recode_output
  filter_entry_options biber_error biber_warn ireplace imatch validate_biber_xml };

=head1 FUNCTIONS

=head2 driver_config

  Returns an XML::LibXML::Simple object for an input driver config file

=cut

sub driver_config {
  my $driver_name = shift;
  # we assume that the driver config file is in the same dir as the driver:
  (my $vol, my $driver_path, undef) = File::Spec->splitpath( $INC{"Biber/Input/file/${driver_name}.pm"} );

  # Deal with the strange world of Par::Packer paths, see similar code in Biber.pm
  my $dcf;
  if ($driver_path =~ m|/par\-| and $driver_path !~ m|/inc|) { # a mangled PAR @INC path
    $dcf = File::Spec->catpath($vol, "$driver_path/inc/lib/Biber/Input/file", "${driver_name}.dcf");
  }
  else {
    $dcf = File::Spec->catpath($vol, $driver_path, "${driver_name}.dcf");
  }

  # Read driver config file
  my $dcfxml = XML::LibXML::Simple::XMLin($dcf,
                                          'ForceContent' => 1,
                                          'ForceArray' => [ qr/\Afield\z/,
                                                            qr/\Aalias\z/,
                                                            qr/\Aalsoset\z/],
                                          'NsStrip' => 1);

  return $dcfxml;
}


=head2 locate_biber_file

  Searches for a file by

  For the exact path if the filename is absolute
  In the output_directory, if defined
  Relative to the current directory
  In the same directory as the control file
  Using kpsewhich, if available

=cut

sub locate_biber_file {
  my $filename = shift;
  my $filenamepath = $filename; # default if nothing else below applies
  my $outfile;
  # If output_directory is set, perhaps the file can be found there so
  # construct a path to test later
  if (my $outdir = Biber::Config->getoption('output_directory')) {
    $outfile = File::Spec->catfile($outdir, $filename);
  }

  # Filename is absolute
  if (File::Spec->file_name_is_absolute($filename) and -e $filename) {
    return $filename;
  }

  # File is output_directory
  if (defined($outfile) and -e $outfile) {
    return $outfile;
  }

  # File is relative to cwd
  if (-e $filename) {
    return $filename;
  }

  # File is where control file lives
  if (my $cfp = Biber::Config->get_ctrlfile_path) {
    my ($ctlvolume, $ctldir, undef) = File::Spec->splitpath($cfp);
    if ($ctlvolume) { # add vol sep for windows if volume is set and there isn't one
      $ctlvolume .= ':' unless $ctlvolume =~ /:\z/;
    }
    if ($ctldir) { # add path sep if there isn't one
      $ctldir .= '/' unless $ctldir =~ /\/\z/;
    }

    my $path = "$ctlvolume$ctldir$filename";

    return $path if -e $path;
  }

  # File is in kpse path
  if (can_run('kpsewhich')) {
    $logger->debug("Looking for file '$filename' via kpsewhich");
    my $found;
    my $err;
    run3  [ 'kpsewhich', $filename ], \undef, \$found, \$err, { return_if_system_error => 1};
    if ($?) {
      $logger->debug("kpsewhich returned error: $err ($!)");
    }
    $logger->trace("kpsewhich returned '$found'");
    if ($found) {
      $logger->debug("Found '$filename' via kpsewhich");
      chomp $found;
      $found =~ s/\cM\z//xms; # kpsewhich in cygwin sometimes returns ^M at the end
      # filename can be UTF-8 and run3() isn't clever with UTF-8
      return decode_utf8($found);
    }
    else {
      $logger->debug("Could not find '$filename' via kpsewhich");
    }
  }
  return undef;
}

=head2 biber_warn

    Wrapper around various warnings bits and pieces
    Logs a warning, add warning to the list of .bbl warnings and optionally
    increments warning count in Biber object, if present

=cut

sub biber_warn {
  my ($warning, $entry) = @_;
  $logger->warn($warning);
  $entry->add_warning($warning) if $entry;
  $Biber::MASTER->{warnings}++;
  return;
}


=head2 biber_error

    Wrapper around error logging
    Forces an exit.

=cut

sub biber_error {
  my $error = shift;
  $logger->error($error);
  $Biber::MASTER->{errors}++;
  # exit unless user requested not to for errors
  unless (Biber::Config->getoption('nodieonerror')) {
    $Biber::MASTER->display_problems;
    exit EXIT_ERROR;
  }
}

=head2 makenamesid

Given a Biber::Names object, return an underscore normalised
concatenation of all of the full name strings.

=cut

sub makenamesid {
  my $names = shift;
  my @namestrings;
  foreach my $name (@{$names->names}) {
    push @namestrings, $name->get_namestring;
  }
  my $tmp = join ' ', @namestrings;
  return normalise_string_underscore($tmp);
}

=head2 makenameid

Given a Biber::Name object, return an underscore normalised
concatenation of the full name strings.

=cut

sub makenameid {
  my $name = shift;
  return normalise_string_underscore($name->get_namestring);
}


=head2 latex_recode_output

  Tries to convert UTF-8 to TeX macros in passed string

=cut

sub latex_recode_output {
  my $string = shift;
  return Biber::LaTeX::Recode::latex_encode($string);
};


=head2 strip_noinit

  Removes elements which are not to be considered during initials generation
  in names

=cut

sub strip_noinit {
  my $string = shift;
  return '' unless $string; # Sanitise missing data
  return $string unless my $noinit = Biber::Config->getoption('noinit');
  foreach my $opt (@$noinit) {
    my $re = $opt->{value};
    $re = qr/$re/;
    $string =~ s/$re//gxms;
  }
  return $string;
}


=head2 strip_nosort

  Removes elements which are not to be used in sorting a name from a string

=cut

sub strip_nosort {
  my $string = shift;
  my $fieldname = shift;
  return '' unless $string; # Sanitise missing data
  return $string unless my $nosort = Biber::Config->getoption('nosort');
  # Strip user-defined REs from string
  my $restrings;
  foreach my $nsopt (@$nosort) {
    # Specific fieldnames override types
    if (lc($nsopt->{name}) eq lc($fieldname)) {
      push @$restrings, $nsopt->{value};
    }
  }

  unless ($restrings) {
    foreach my $nsopt (@$nosort) {
      next unless $nsopt->{name} =~ /\Atype_/xms;
      if ($NOSORT_TYPES{lc($nsopt->{name})}{lc($fieldname)}) {
        push @$restrings, $nsopt->{value};
      }
    }
  }
  # If no nosort to do, just return string
  return $string unless $restrings;
  foreach my $re (@$restrings) {
    $re = qr/$re/;
    $string =~ s/$re//gxms;
  }
  return $string;
}


=head2 normalise_string_label

Remove some things from a string for label generation, like braces.
It also decodes LaTeX character macros into Unicode as this is always safe when
normalising strings for sorting since they don't appear in the output.

=cut

sub normalise_string_label {
  my $str = shift;
  my $fieldname = shift;
  return '' unless $str; # Sanitise missing data
  # Replace LaTeX chars by Unicode for sorting
  # Don't bother if output is UTF-8 as in this case, we've already decoded everthing
  # before we read the file (see Biber.pm)
  unless (Biber::Config->getoption('output_encoding') eq 'UTF-8') {
    $str = latex_decode($str, strip_outer_braces => 1,
                              scheme => Biber::Config->getoption('decodecharsset'));
  }
  return normalise_string_common($str);
}


=head2 normalise_string_sort

Removes LaTeX macros, and all punctuation, symbols, separators and control characters,
as well as leading and trailing whitespace for sorting strings.
It also decodes LaTeX character macros into Unicode as this is always safe when
normalising strings for sorting since they don't appear in the output.

=cut

sub normalise_string_sort {
  my $str = shift;
  my $fieldname = shift;
  return '' unless $str; # Sanitise missing data
  # First strip nosort REs
  $str = strip_nosort($str, $fieldname);
  # Then replace ties with spaces or they will be lost
  $str =~ s/([^\\])~/$1 /g; # Foo~Bar -> Foo Bar
  # Replace LaTeX chars by Unicode for sorting
  # Don't bother if output is UTF-8 as in this case, we've already decoded everthing
  # before we read the file (see Biber.pm)
  unless (Biber::Config->getoption('output_encoding') eq 'UTF-8') {
    $str = latex_decode($str, strip_outer_braces => 1,
                              scheme => Biber::Config->getoption('decodecharsset'));
  }
  return normalise_string_common($str);
}

=head2 normalise_string

Removes LaTeX macros, and all punctuation, symbols, separators and control characters,
as well as leading and trailing whitespace for sorting strings.
Only decodes LaTeX character macros into Unicode if output is UTF-8

=cut

sub normalise_string {
  my $str = shift;
  return '' unless $str; # Sanitise missing data
  # First replace ties with spaces or they will be lost
  $str =~ s/([^\\])~/$1 /g; # Foo~Bar -> Foo Bar
  if (Biber::Config->getoption('output_encoding') eq 'UTF-8') {
    $str = latex_decode($str, strip_outer_braces => 1,
                              scheme => Biber::Config->getoption('decodecharsset'));
  }
  return normalise_string_common($str);
}

=head2 normalise_string_common

  Common bit for normalisation

=cut

sub normalise_string_common {
  my $str = shift;
  $str =~ s/\\[A-Za-z]+//g;        # remove latex macros (assuming they have only ASCII letters)
  $str =~ s/[\p{P}\p{S}\p{C}]+//g; # remove punctuation, symbols, separator and control
  $str =~ s/^\s+//;                # Remove leading spaces
  $str =~ s/\s+$//;                # Remove trailing spaces
  $str =~ s/\s+/ /g;               # collapse spaces
  return $str;
}

=head2 normalise_string_hash

  Normalise strings used for hashes. We collapse LaTeX macros into a vestige
  so that hashes are unique between things like:

  Smith
  {\v S}mith

  we replace macros like this to preserve their vestiges:

  \v S -> v:
  \" -> 34:

=cut

sub normalise_string_hash {
  my $str = shift;
  return '' unless $str; # Sanitise missing data
  $str =~ s/\\(\p{L}+)\s*/$1:/g; # remove tex macros
  $str =~ s/\\([^\p{L}])\s*/ord($1).':'/ge; # remove accent macros like \"a
  $str =~ s/[{}~\.\s]+//g; # Remove brackes, ties, dots, spaces
  return $str;
}

=head2 normalise_string_underscore

Like normalise_string, but also substitutes ~ and whitespace with underscore.

=cut

sub normalise_string_underscore {
  my $str = shift;
  return '' unless $str; # Sanitise missing data
  $str =~ s/([^\\])~/$1 /g; # Foo~Bar -> Foo Bar
  $str = normalise_string($str);
  $str =~ s/\s+/_/g;
  return $str;
}

=head2 reduce_array

reduce_array(\@a, \@b) returns all elements in @a that are not in @b

=cut

sub reduce_array {
  my ($a, $b) = @_;
  my %countb = ();
  foreach my $elem (@$b) {
    $countb{$elem}++;
  }
  my @result;
  foreach my $elem (@$a) {
    push @result, $elem unless $countb{$elem};
  }
  return @result;
}

=head2 remove_outer

    Remove surrounding curly brackets:
        '{string}' -> 'string'

=cut

sub remove_outer {
  my $str = shift;
  $str =~ s/^{(.+)}$/$1/;
  return $str;
}

=head2 add_outer

    Add surrounding curly brackets:
        'string' -> '{string}'

=cut

sub add_outer {
  my $str = shift;
  return '{' . $str . '}';
}


=head2 ucinit

    upper case of initial letters in a string

=cut

sub ucinit {
  my $str = shift;
  $str = lc($str);
  $str =~ s/\b(\p{Ll})/\u$1/g;
  return $str;
}

=head2 is_undef

    Checks for undefness of arbitrary things, including
    composite method chain calls which don't reliably work
    with defined() (see perldoc for defined())
    This works because we are just testing the value passed
    to this sub. So, for example, this is randomly unreliable
    even if the resulting value of the arg to defined() is "undef":

    defined($thing->method($arg)->method)

    wheras:

    is_undef($thing->method($arg)->method)

    works since we only test the return value of all the methods
    with defined()

=cut

sub is_undef {
  my $val = shift;
  return defined($val) ? 0 : 1;
}

=head2 is_def

    Checks for definedness in the same way as is_undef()

=cut

sub is_def {
  my $val = shift;
  return defined($val) ? 1 : 0;
}

=head2 is_undef_or_null

    Checks for undef or nullness (see is_undef() above)

=cut

sub is_undef_or_null {
  my $val = shift;
  return 1 if is_undef($val);
  return $val ? 0 : 1;
}

=head2 is_def_and_notnull

    Checks for def and unnullness (see is_undef() above)

=cut

sub is_def_and_notnull {
  my $arg = shift;
  if (defined($arg) and is_notnull($arg)) {
    return 1;
  }
  else {
    return 0;
  }
}

=head2 is_def_and_null

    Checks for def and nullness (see is_undef() above)

=cut

sub is_def_and_null {
  my $arg = shift;
  if (defined($arg) and is_null($arg)) {
    return 1;
  }
  else {
    return 0;
  }
}

=head2 is_null

    Checks for nullness

=cut

sub is_null {
  my $arg = shift;
  return is_notnull($arg) ? 0 : 1;
}

=head2 is_notnull

    Checks for notnullness

=cut

sub is_notnull {
  my $arg = shift;
  return undef unless defined($arg);
  my $st = is_notnull_scalar($arg);
  if (defined($st) and $st) { return 1; }
  my $at = is_notnull_array($arg);
  if (defined($at) and $at) { return 1; }
  my $ht = is_notnull_hash($arg);
  if (defined($ht) and $ht) { return 1; }
  my $ot = is_notnull_object($arg);
  if (defined($ot) and $ot) { return 1; }
  return 0;
}

=head2 is_notnull_scalar

    Checks for notnullness of a scalar

=cut

sub is_notnull_scalar {
  my $arg = shift;
  unless (ref \$arg eq 'SCALAR') {
    return undef;
  }
  return $arg ne '' ? 1 : 0;
}

=head2 is_notnull_array

    Checks for notnullness of an array (passed by ref)

=cut

sub is_notnull_array {
  my $arg = shift;
  unless (ref $arg eq 'ARRAY') {
    return undef;
  }
  my @arr = @$arg;
  return $#arr > -1 ? 1 : 0;
}

=head2 is_notnull_hash

    Checks for notnullness of an hash (passed by ref)

=cut

sub is_notnull_hash {
  my $arg = shift;
  unless (ref $arg eq 'HASH') {
    return undef;
  }
  my @arr = keys %$arg;
  return $#arr > -1 ? 1 : 0;
}

=head2 is_notnull_object

    Checks for notnullness of an object (passed by ref)

=cut

sub is_notnull_object {
  my $arg = shift;
  unless (ref($arg) =~ m/\ABiber::/xms) {
    return undef;
  }
  return $arg->notnull ? 1 : 0;
}


=head2 stringify_hash

    Turns a hash into a string of keys and values

=cut

sub stringify_hash {
  my $hashref = shift;
  my $string;
  while (my ($k,$v) = each %$hashref) {
    $string .= "$k => $v, ";
  }
  # Take off the trailing comma and space
  chop $string;
  chop $string;
  return $string;
}

=head2 normalise_utf8

  Normalise any UTF-8 encoding string immediately to exactly what we want
  We want the strict perl utf8 "UTF-8"

=cut

sub normalise_utf8 {
  if (defined(Biber::Config->getoption('input_encoding')) and
      Biber::Config->getoption('input_encoding') =~ m/\Autf-?8\z/xmsi) {
    Biber::Config->setoption('input_encoding', 'UTF-8');
  }
  if (defined(Biber::Config->getoption('output_encoding')) and
      Biber::Config->getoption('output_encoding') =~ m/\Autf-?8\z/xmsi) {
    Biber::Config->setoption('output_encoding', 'UTF-8');
  }
}

=head2 inits

   We turn the initials into an array so we can be flexible with them later
   The tie here is used only so we know what to split on. We don't want to make
   any typesetting decisions in Biber, like what to use to join initials so on
   output to the .bbl, we only use BibLaTeX macros.

=cut

sub inits {
  my $istring = shift;
  return [ split(/(?<!\\)~/, $istring) ];
}


=head2 join_name

  Replace all join typsetting elements in a name part (space, ties) with BibLaTeX macros
  so that typesetting decisions are made in BibLaTeX, not hard-coded in Biber

=cut

sub join_name {
  my $nstring = shift;
  $nstring =~ s/(?<!\\\S)\s+/\\bibnamedelimb /gxms; # Don't do spaces in char macros
  $nstring =~ s/(?<!\\)~/\\bibnamedelima /gxms; # Don't do '\~'
  # Special delim after name parts ending in period
  $nstring =~ s/(?<=\.)\\bibnamedelim[ab]/\\bibnamedelimi/gxms;
  return $nstring;
}


=head2 filter_entry_options

    Process any per_entry option transformations which are necessary

=cut

sub filter_entry_options {
  my $options = shift;
  return '' unless $options;
  my @entryoptions = split /\s*,\s*/, $options;
  my @return_options;
  foreach (@entryoptions) {
    m/^([^=]+)=?(.+)?$/;
    given ($CONFIG_BIBLATEX_PER_ENTRY_OPTIONS{lc($1)}{OUTPUT}) {
      # Standard option
      when (not defined($_) or $_ == 1) {
        push @return_options, $1 . ($2 ? "=$2" : '') ;
      }
      # Set all split options to same value as parent
      when (ref($_) eq 'ARRAY') {
        foreach my $map (@$_) {
          push @return_options, "$map=$2";
        }
      }
      # Set all splits to specific values
      when (ref($_) eq 'HASH') {
        foreach my $map (keys %$_) {
          push @return_options, "$map=" . $_->{$map};
        }
      }
    }
  }
  return join(',', @return_options);
}

=head2 imatch

    Do an interpolating match using a match RE and a string passed in as variables

=cut

sub imatch {
  my ($value, $val_match) = @_;
  return 0 unless $val_match;
  $val_match = qr/$val_match/;
  return $value =~ m/$val_match/xms;
}


=head2 ireplace

    Do an interpolating match/replace using a match RE, replacement RE
    and string passed in as variables

=cut

sub ireplace {
  my ($value, $val_match, $val_replace) = @_;
  return $value unless $val_match;
  $val_match = qr/$val_match/;
  # Tricky quoting because of later evals
  $val_replace = '"' . $val_replace . '"';
  $value =~ s/$val_match/$val_replace/eegxms;
  return $value;
}


=head2 validate_biber_xml

  Validate a biber/biblatex XML metadata file against an RNG schema

=cut

sub validate_biber_xml {
  my ($file, $type, $prefix) = @_;
  require XML::LibXML;

  # Set up XML parser
  my $xmlparser = XML::LibXML->new();
  $xmlparser->line_numbers(1); # line numbers for more informative errors

  # Set up schema
  my $xmlschema;

  # we assume that the schema files are in the same dir as Biber.pm:
  (my $vol, my $biber_path, undef) = File::Spec->splitpath( $INC{"Biber.pm"} );
  $biber_path =~ s/\/$//; # splitpath sometimes leaves a trailing '/'

  # Deal with the strange world of Par::Packer paths
  # We might be running inside a PAR executable and @INC is a bit odd in this case
  # Specifically, "Biber.pm" in @INC might resolve to an internal jumbled name
  # nowhere near to these files. You know what I mean if you've dealt with pp
  my $rng;
  if ($biber_path =~ m|/par\-| and $biber_path !~ m|/inc|) { # a mangled PAR @INC path
    $rng = File::Spec->catpath($vol, "$biber_path/inc/lib/Biber", "${type}.rng");
  }
  else {
    $rng = File::Spec->catpath($vol, "$biber_path/Biber", "${type}.rng");
  }

  if (-e $rng) {
    $xmlschema = XML::LibXML::RelaxNG->new( location => $rng )
  }
  else {
    biber_warn("Cannot find XML::LibXML::RelaxNG schema. Skipping validation : $!");
    return;
  }

  # Parse file
  my $xp = $xmlparser->parse_file($file);

  # XPath context
  if ($prefix) {
    my $xpc = XML::LibXML::XPathContext->new($xp);
    $xpc->registerNs($type, $prefix);
  }

  # Validate against schema. Dies if it fails.
  eval { $xmlschema->validate($xp) };
  if (ref($@)) {
    $logger->debug( $@->dump() );
    biber_error("'$file' failed to validate against schema '$rng'");
  }
  elsif ($@) {
    biber_error("'$file' failed to validate against schema '$rng'\n$@");
  }
  else {
    $logger->info("'$file' validates against schema '$rng'");
  }
  undef $xmlparser;
}

1;

__END__

=head1 AUTHOR

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
