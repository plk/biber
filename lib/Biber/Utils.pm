package Biber::Utils;
use v5.16;
use strict;
use warnings;
use parent qw(Exporter);

use constant {
  EXIT_OK => 0,
  EXIT_ERROR => 2
};

use utf8;
use Carp;
use Encode;
use File::Find;
use File::Spec;
use IPC::Cmd qw( can_run );
use IPC::Run3; # This works with PAR::Packer and Windows. IPC::Run doesn't
use Biber::Constants;
use Biber::LaTeX::Recode;
use Biber::Entry::Name;
use Data::Uniqid qw ( suniqid );
use Regexp::Common qw( balanced );
use List::AllUtils qw( first );
use Log::Log4perl qw(:no_extra_logdie_message);
use Scalar::Util qw(looks_like_number);
use Text::CSV;
use Text::Roman qw(isroman roman2int);
use Unicode::Normalize;
use Unicode::GCString;
my $logger = Log::Log4perl::get_logger('main');

=encoding utf-8

=head1 NAME

Biber::Utils - Various utility subs used in Biber

=cut

=head1 EXPORT

All functions are exported by default.

=cut

our @EXPORT = qw{ locate_biber_file makenamesid makenameid stringify_hash
  normalise_string normalise_string_hash normalise_string_underscore
  normalise_string_sort normalise_string_label reduce_array remove_outer
  has_outer add_outer ucinit strip_nosort strip_noinit is_def is_undef
  is_def_and_notnull is_def_and_null is_undef_or_null is_notnull is_null
  normalise_utf8 inits join_name latex_recode_output filter_entry_options
  biber_error biber_warn ireplace imatch validate_biber_xml
  process_entry_options remove_entry_options escape_label unescape_label
  biber_decode_utf8 out parse_date_start parse_date_end parse_date_range locale2bcp47
  bcp472locale rangelen match_indices process_comment map_boolean
  parse_range parse_range_alt maploopreplace get_transliterator
  call_transliterator normalise_string_bblxml gen_initials join_name_parts
  split_xsv edtf_monthday};

=head1 FUNCTIONS

=head2 locate_biber_file

  Searches for a file by

  The exact path if the filename is absolute
  In the input_directory, if defined
  In the output_directory, if defined
  Relative to the current directory
  In the same directory as the control file
  Using kpsewhich, if available

=cut

sub locate_biber_file {
  my $filename = shift;
  my $filenamepath = $filename; # default if nothing else below applies
  my $foundfile;
  # If input_directory is set, perhaps the file can be found there so
  # construct a path to test later
  if (my $indir = Biber::Config->getoption('input_directory')) {
    $foundfile = File::Spec->catfile($indir, $filename);
  }
  # If output_directory is set, perhaps the file can be found there so
  # construct a path to test later
  elsif (my $outdir = Biber::Config->getoption('output_directory')) {
    $foundfile = File::Spec->catfile($outdir, $filename);
  }

  # Filename is absolute
  if (File::Spec->file_name_is_absolute($filename) and -e $filename) {
    return $filename;
  }

  # File is input_directory or output_directory
  if (defined($foundfile) and -e $foundfile) {
    return $foundfile;
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
    if ($logger->is_debug()) {# performance tune
      $logger->debug("Looking for file '$filename' via kpsewhich");
    }
    my $found;
    my $err;
    run3  [ 'kpsewhich', $filename ], \undef, \$found, \$err, { return_if_system_error => 1};
    if ($?) {
      if ($logger->is_debug()) {# performance tune
        $logger->debug("kpsewhich returned error: $err ($!)");
      }
    }
    if ($logger->is_trace()) {# performance tune
      $logger->trace("kpsewhich returned '$found'");
    }
    if ($found) {
      if ($logger->is_debug()) {# performance tune
        $logger->debug("Found '$filename' via kpsewhich");
      }
      chomp $found;
      $found =~ s/\cM\z//xms; # kpsewhich in cygwin sometimes returns ^M at the end
      # filename can be UTF-8 and run3() isn't clever with UTF-8
      return decode_utf8($found);
    }
    else {
      if ($logger->is_debug()) {# performance tune
        $logger->debug("Could not find '$filename' via kpsewhich");
      }
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
    $string =~ s/$re//gxms;
  }
  return $string;
}


=head2 strip_nosort

  Removes elements which are not to be used in sorting a name from a string

=cut

sub strip_nosort {
  no autovivification;
  my ($string, $fieldname) = @_;
  return '' unless $string; # Sanitise missing data
  return $string unless my $nosort = Biber::Config->getoption('nosort');

  my $restrings;

  foreach my $nsopt (@$nosort) {
    # Specific fieldnames override sets
    if (fc($nsopt->{name}) eq fc($fieldname)) {
      push @$restrings, $nsopt->{value};
    }
    elsif (my $set = $DATAFIELD_SETS{lc($nsopt->{name})} ) {
      if (first {fc($_) eq fc($fieldname)} @$set) {
        push @$restrings, $nsopt->{value};
      }
    }
  }

  # If no nosort to do, just return string
  return $string unless $restrings;

  foreach my $re (@$restrings) {
    $string =~ s/$re//gxms;
  }
  return $string;
}

=head2 normalise_string_label

Remove some things from a string for label generation.

=cut

sub normalise_string_label {
  my $str = shift;
  return '' unless $str; # Sanitise missing data
  my $nolabels = Biber::Config->getoption('nolabel');
  $str =~ s/\\[A-Za-z]+//g;    # remove latex macros (assuming they have only ASCII letters)
  # Replace ties with spaces or they will be lost
  $str =~ s/([^\\])~/$1 /g; # Foo~Bar -> Foo Bar
  foreach my $nolabel (@$nolabels) {
    my $re = $nolabel->{value};
    $str =~ s/$re//gxms;           # remove nolabel items
  }
  $str =~ s/(?:^\s+|\s+$)//g;      # Remove leading and trailing spaces
  $str =~ s/\s+/ /g;               # collapse spaces
  return $str;
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
  return normalise_string_common($str);
}

=head2 normalise_string_bblxml

Some string normalisation for bblxml output

=cut

sub normalise_string_bblxml {
  my $str = shift;
  return '' unless $str; # Sanitise missing data
  $str =~ s/\\[A-Za-z]+//g; # remove latex macros (assuming they have only ASCII letters)
  $str =~ s/\{([^{}]+)\}/$1/g; # remove pointless braces
  $str =~ s/~/ /g; # replace ties with spaces
  return $str;
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
  return normalise_string_common($str);
}

=head2 normalise_string_common

  Common bit for normalisation

=cut

sub normalise_string_common {
  my $str = shift;
  $str =~ s/\\[A-Za-z]+//g;        # remove latex macros (assuming they have only ASCII letters)
  $str =~ s/[\p{P}\p{S}\p{C}]+//g; # remove punctuation, symbols, separator and control
  $str =~ s/^\s+|\s+$//g;          # Remove leading and trailing spaces
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

=head2 escape_label

  Escapes a few special character which might be used in labels

=cut

sub escape_label {
  my $str = shift;
  return '' unless $str; # Sanitise missing data
  $str =~ s/([_\^\$\#\%\&])/\\$1/g;
  $str =~ s/~/{\\textasciitilde}/g;
  $str =~ s/>/{\\textgreater}/g;
  $str =~ s/</{\\textless}/g;
  return $str;
}

=head2 unescape_label

  Unscapes a few special character which might be used in label but which need
  sorting without escapes

=cut

sub unescape_label {
  my $str = shift;
  return '' unless $str; # Sanitise missing data
  $str =~ s/\\([_\^\$\~\#\%\&])/$1/g;
  $str =~ s/\{\\textasciitilde\}/~/g;
  $str =~ s/\{\\textgreater\}/>/g;
  $str =~ s/\{\\textless\}/</g;
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
    but not
        '{string} {string}' -> 'string} {string'

    Return (boolean if stripped, string)

=cut

sub remove_outer {
  my $str = shift;
  return (0, $str) if $str =~ m/}\s*{/;
  my $r = $str =~ s/^{(\X+)}$/$1/;
  return (($r ? 1 : 0), $str);
}

=head2 has_outer

    Return (boolean if surrounded in braces

=cut

sub has_outer {
  my $str = shift;
  return 0 if $str =~ m/}\s*{/;
  return $str =~ m/^{\X+}$/;
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
  return [] unless $options;
  my $roptions = [];
  foreach (@$options) {
    m/^([^=\s]+)\s*=?\s*([^\s]+)?$/;
    my $cfopt = $CONFIG_BIBLATEX_ENTRY_OPTIONS{lc($1)}{OUTPUT};
    # convert booleans
    my $val = $2;
    if ($val and
        $CONFIG_OPTTYPE_BIBLATEX{lc($1)} and
        $CONFIG_OPTTYPE_BIBLATEX{lc($1)} eq 'boolean') {
      $val = map_boolean($val, 'tostring');
    }
    # Standard option
    if (not defined($cfopt) or $cfopt == 1) {
      push @$roptions, $1 . ($val ? "=$val" : '') ;
    }
    # Set all split options to same value as parent
    elsif (ref($cfopt) eq 'ARRAY') {
      foreach my $map (@$cfopt) {
        push @$roptions, "$map=$val";
      }
    }
    # Set all splits to specific values
    elsif (ref($cfopt) eq 'HASH') {
      foreach my $map (keys %$cfopt) {
        push @$roptions, "$map=" . $_->{$map};
      }
    }
  }
  return $roptions;
}

=head2 imatch

    Do an interpolating (neg)match using a match RE and a string passed in as variables
    Using /g on matches so that $1,$2 etc. can be populated from repeated matches of
    same capture group as well as different groups

=cut

sub imatch {
  my ($value, $val_match, $negmatch) = @_;
  return 0 unless $val_match;
  $val_match = qr/$val_match/;
  if ($negmatch) {# "!~" doesn't work here as we need an array returned
    return $value =~ m/$val_match/xmsg ? () : (1);
  }
  else {
    return $value =~ m/$val_match/xmsg;
  }
}


=head2 ireplace

    Do an interpolating match/replace using a match RE, replacement RE
    and string passed in as variables

=cut

sub ireplace {
  my ($value, $val_match, $val_replace) = map { NFC($_) } @_;
  return $value unless $val_match;
  $val_match = qr/$val_match/;
  # Tricky quoting because of later evals
  $val_replace = '"' . $val_replace . '"';
  $value =~ s/$val_match/$val_replace/eegxms;
  return $value;
}


=head2 validate_biber_xml

  Validate a biber/biblatex XML metadata file against an RNG XML schema

=cut

sub validate_biber_xml {
  my ($file, $type, $prefix, $schema) = @_;
  require XML::LibXML;

  # Set up XML parser
  my $xmlparser = XML::LibXML->new();
  $xmlparser->line_numbers(1); # line numbers for more informative errors

  # Set up schema
  my $xmlschema;

  # Deal with the strange world of Par::Packer paths
  # We might be running inside a PAR executable and @INC is a bit odd in this case
  # Specifically, "Biber.pm" in @INC might resolve to an internal jumbled name
  # nowhere near to these files. You know what I mean if you've dealt with pp
  unless ($schema) {
    # we assume that unspecified schema files are in the same dir as Biber.pm:
    (my $vol, my $biber_path, undef) = File::Spec->splitpath( $INC{"Biber.pm"} );
    $biber_path =~ s/\/$//; # splitpath sometimes leaves a trailing '/'

    if ($biber_path =~ m|/par\-| and $biber_path !~ m|/inc|) { # a mangled PAR @INC path
      $schema = File::Spec->catpath($vol, "$biber_path/inc/lib/Biber", "${type}.rng");
    }
    else {
      $schema = File::Spec->catpath($vol, "$biber_path/Biber", "${type}.rng");
    }
  }

  if (-e $schema) {
    $xmlschema = XML::LibXML::RelaxNG->new( location => $schema )
  }
  else {
    biber_warn("Cannot find XML::LibXML::RelaxNG schema '$schema'. Skipping validation : $!");
    return;
  }

  # Parse file
  my $doc = $xmlparser->load_xml(location => $file);

  # XPath context
  if ($prefix) {
    my $xpc = XML::LibXML::XPathContext->new($doc);
    $xpc->registerNs($type, $prefix);
  }

  # Validate against schema. Dies if it fails.
  eval { $xmlschema->validate($doc) };
  if (ref($@)) {
    if ($logger->is_debug()) {# performance tune
      $logger->debug( $@->dump() );
    }
    biber_error("'$file' failed to validate against schema '$schema'");
  }
  elsif ($@) {
    biber_error("'$file' failed to validate against schema '$schema'\n$@");
  }
  else {
    $logger->info("'$file' validates against schema '$schema'");
  }
  undef $xmlparser;
}

=head2 map_boolean

    Convert booleans between strings and numbers. Because standard XML "boolean"
    datatype considers "true" and "1" the same etc.

=cut

sub map_boolean {
  my $b = lc(shift);
  my $dir = shift;
  my %map = (true  => 1,
             false => 0,
            );
  if ($dir eq 'tonum') {
    return $b if looks_like_number($b);
    return $map{$b};
  }
  elsif ($dir eq 'tostring') {
    return $b if not looks_like_number($b);
    %map = reverse %map;
    return $map{$b};
  }
}

=head2 remove_entry_options

    Remove per-entry options

=cut

sub remove_entry_options {
  my $options = shift;
  my $mods = shift;
  my $changed_opts;
  foreach (@$options) {
    s/\s+=\s+/=/g; # get rid of spaces around any "="
    m/^([^=]+)(=?)(.+)?$/;
    unless ($mods->{$1}) {
      push @$changed_opts, ($1 . ($2 // '') . ($3 // ''));
    }
  }
  return $changed_opts;
}

=head2 process_entry_options

    Set per-entry options

=cut

sub process_entry_options {
  my $citekey = shift;
  my $options = shift;
  return unless $options;       # Just in case it's null
  foreach (@$options) {
    s/\s+=\s+/=/g; # get rid of spaces around any "="
    m/^([^=]+)(=?)(.+)?$/;
    if ($2) {
      if ($CONFIG_OPTTYPE_BIBLATEX{lc($1)} and
          $CONFIG_OPTTYPE_BIBLATEX{lc($1)} eq 'boolean') {
        _expand_option($1, map_boolean($3, 'tonum'), $citekey);
      }
      else {
        _expand_option($1, $3, $citekey);
      }
    }
    else {
      _expand_option($1, 1, $citekey);
    }
  }
  return;
}

sub _expand_option {
  my ($opt, $val, $citekey) = @_;
  my $cfopt = $CONFIG_BIBLATEX_ENTRY_OPTIONS{lc($opt)}{INPUT};
  # Standard option
  if (not defined($cfopt)) {
    Biber::Config->setblxoption($opt, $val, 'ENTRY', $citekey);
  }
  # Set all split options to same value as parent
  elsif (ref($cfopt) eq 'ARRAY') {
    foreach my $k (@$cfopt) {
      Biber::Config->setblxoption($k, $val, 'ENTRY', $citekey);
    }
  }
  # Specify values per all splits
  elsif (ref($cfopt) eq 'HASH') {
    foreach my $k (keys %$cfopt) {
      Biber::Config->setblxoption($k, $cfopt->{$k}, 'ENTRY', $citekey);
    }
  }
  return;
}

=head2 parse_date_range

  Parse of EDTF date range
  Returns two-element array ref: [start DT object, end DT object]

=cut

sub parse_date_range {
  my ($sd, $sep, $ed) = shift =~ m|^([^/]+)(/)?([^/]+)?$|;
  my $unspec;
  if ($sd =~ /u/) {# EDTF 5.2.2 Unspecified format
    ($sd, $sep, $ed, $unspec) = parse_date_edtf_unspecified($sd);
  }
  return (parse_date_start($sd), parse_date_end($ed), $sep, $unspec);
}

=head2 parse_date_edtf_unspecified

  Parse of EDTF 5.2.2 Unspecified format into date range
  Returns range plus specification of granularity of unspecified

=cut

sub parse_date_edtf_unspecified {
  my $d = shift;

  # 199u -> 1990/1999
  if ($d =~ m/^(\d{3})u$/) {
    return ("${1}0", '/', "${1}9", 'yearindecade');
  }
  # 19uu -> 1900/1999
  elsif ($d =~ m/^(\d{2})uu$/) {
    return ("${1}00", '/', "${1}99", 'yearincentury');
  }
  # 1999-uu -> 1999-01/1999-12
  elsif ($d =~ m/^(\d{4})\p{Dash}uu$/) {
    return ("${1}-01", '/', "${1}-12", 'monthinyear');
  }
  # 1999-01-uu -> 1999-01-01/1999-01-31
  # (understands different months and leap years)
  elsif ($d =~ m/^(\d{4})\p{Dash}(\d{2})\p{Dash}uu$/) {

    sub leapyear {
      my $year = shift;
      if ((($year % 4 == 0) and ($year % 100 != 0))
          or ($year % 400 == 0)) {
        return 1;
      }
      else {
        return 0;
      }
    }

    my %monthdays;
    @monthdays{map {sprintf('%.2d', $_)} 1..12} = ('31') x 12;
    @monthdays{'09', '04', '06', '11'} = ('30') x 4;
    $monthdays{'02'} = leapyear($1) ? 29 : 28;

    return ("${1}-${2}-01", '/', "${1}-${2}-" . $monthdays{$2}, 'dayinmonth');
  }
  # 1999-uu-uu -> 1999-01-01/1999-12-31
  elsif ($d =~ m/^(\d{4})\p{Dash}uu\p{Dash}uu$/) {
    return ("${1}-01-01", '/', "${1}-12-31", 'dayinyear');
  }
}


=head2 parse_date_start

  Convenience wrapper

=cut

sub parse_date_start {
  return parse_date($CONFIG_DATE_PARSERS{start}, shift);
}

=head2 parse_date_end

  Convenience wrapper

=cut

sub parse_date_end {
  return parse_date($CONFIG_DATE_PARSERS{end}, shift);
}

=head2 parse_date

  Parse of EDTF dates

=cut

sub parse_date {
  my ($obj, $string) = @_;
  # Must do this to make sure meta-information from sub-class Biber::Date::Format is reset
  $obj->init();
  return 0 unless $string;
  return 0 if $string eq 'unknown'; # EDTF 5.2.3
  return 0 if $string eq 'open';    # EDTF 5.2.3
  return eval {$obj->parse_datetime($string)};
}

=head2 edtf_monthday

  Force month/day to EDTF format with leading zero

=cut

sub edtf_monthday {
  my $md = shift;
  return $md ? sprintf('%.2d', $md) : undef;
}

=head2 biber_decode_utf8

    Perform NFD form conversion as well as UTF-8 conversion. Used to normalize
    bibtex input as the T::B interface doesn't allow a neat whole file slurping.

=cut

sub biber_decode_utf8 {
  return shift;
  #return NFD(decode_utf8(shift));# Unicode NFD boundary
}

=head2 out

  Output to target. Outputs NFC UTF-8 if output is UTF-8

=cut

sub out {
  my ($fh, $string) = @_;
  print $fh NFC($string);# Unicode NFC boundary
}

=head2 process_comment

  Fix up some problems with comments after being processed by btparse

=cut

sub process_comment {
  my $comment = shift;
  # Fix up structured Jabref comments by re-instating line breaks. Hack.
  if ($comment =~ m/jabref-meta:/) {
    $comment =~ s/([:;])\s(\d)/$1\n$2/xmsg;
    $comment =~ s/\z/\n/xms;
  }
  return $comment;
}


=head2 locale2bcp47

  Map babel/polyglossia language options to a sensible CLDR (bcp47) locale default
  Return input string if there is no mapping

=cut

sub locale2bcp47 {
  my $localestr = shift;
  return $localestr unless $localestr;
  return $LOCALE_MAP{$localestr} || $localestr;
}

=head2 bcp472locale

  Map CLDR (bcp47) locale to a babel/polyglossia locale
  Return input string if there is no mapping

=cut

sub bcp472locale {
  my $localestr = shift;
  return $localestr unless $localestr;
  return $LOCALE_MAP_R{$localestr} || $localestr;
}

=head2 rangelen

  Calculate the length of a range field
  Range fields are an array ref of two-element array refs [range_start, range_end]
  range_end can be be empty for open-ended range or undef
  Deals with Unicode and ASCII roman numerals via the magic of Unicode NFKD form

  m-n -> [m, n]
  m   -> [m, undef]
  m-  -> [m, '']
  -n  -> ['', n]
  -   -> ['', undef]

=cut

sub rangelen {
  my $rf = shift;
  my $rl = 0;
  foreach my $f (@$rf) {
    my $m = $f->[0];
    my $n = $f->[1];
    # m is something that's just numerals (decimal Unicode roman or ASCII roman)
    if ($m and $m =~ /^[\p{Nd}\p{Nl}iIvVxXlLcCdDmM]+$/) {
      # This magically decomposes Unicode roman chars into ASCII compat
      $m = NFKD($m);
      # n is something that's just numerals (decimal Unicode roman or ASCII roman)
      if ($n and $n =~ /^[\p{Nd}\p{Nl}iIvVxXlLcCdDmM]+$/) {
        # This magically decomposes Unicode roman chars into ASCII compat
        $n = NFKD($n);
        $m = isroman($m) ? roman2int($m) : $m;
        $n = isroman($n) ? roman2int($n) : $n;
        # If still not an int at this point, it's probably some non-int page number that
        # isn't a roman numeral so give up
        unless (looks_like_number($n) and looks_like_number($m)) {
          return -1;
        }
        # Deal with not so explicit ranges like 22-4 or 135-38
        # Done by turning numbers into string arrays, reversing and then filling in blanks
        if ($n < $m) {
          my @m = reverse split(//,$m);
          my @n = reverse split(//,$n);
          for (my $i=0;$i<=$#m;$i++) {
            next if $n[$i];
            $n[$i] = $m[$i];
          }
          $n = join('', reverse @n);
        }
        $rl += (($n - $m) + 1);
      }
      # n is ''
      elsif (defined($n)) {
        # open-ended range can't be calculated, just return -1
        return -1;
      }
      # n is undef, single item
      else {
        $rl += 1;
      }
    }
    else {
      # open-ended range can't be calculated, just return -1
      return -1;
    }
  }
  return $rl;
}


=head2 match_indices

  Return array ref of array refs of matches and start indices of matches
  for provided array of compiled regexps into string

=cut

sub match_indices {
  my ($regexes, $string) = @_;
  my @ret;
  my $relen = 0;
  foreach my $regex (@$regexes) {
    my $len = 0;
    while ($string =~ /$regex/g) {
      my $gcs = Unicode::GCString->new($string)->substr($-[0], $+[0]-$-[0]);
      push @ret, [ $gcs->as_string, $-[0] - $relen ];
      $len = $gcs->length;
    }
    $relen += $len;
  }
  # Return last index first so replacements can be done without recalculating
  # indices changed by earlier index replacements
  return scalar(@ret) ? [reverse @ret] : undef;
}

=head2 parse_range

  Parses a range of values into a two-value array ref.
  Ranges with no starting value default to "1"
  Ranges can be open-ended and it's up to surrounding code to interpret this
  Ranges can be single figures which is shorthand for 1-x

=cut

sub parse_range {
  my $rs = shift;
  $rs =~ m/\A\s*(\P{Pd}+)?\s*(\p{Pd})*\s*(\P{Pd}+)?\s*\z/xms;
  if ($2) {
    return [$1 // 1, $3];
  }
  else {
    return [1, $1];
  }
}

=head2 parse_range_alt

  Parses a range of values into a two-value array ref.
  Either start or end can be undef and it's up to surrounding code to interpret this

=cut

sub parse_range_alt {
  my $rs = shift;
  $rs =~ m/\A\s*(\P{Pd}+)?\s*(\p{Pd})*\s*(\P{Pd}+)?\s*\z/xms;
  if ($2) {
    return [$1, $3];
  }
  else {
    return undef;
  }
}


=head2 maploopreplace

  Replace loop markers with values.

=cut

sub maploopreplace {
  # $MAPUNIQVAL is lexical here
  no strict 'vars';
  my ($string, $maploop) = @_;
  return undef unless defined($string);
  return $string unless $maploop;
  $string =~ s/\$MAPLOOP/$maploop/g;
  $string =~ s/\$MAPUNIQVAL/$MAPUNIQVAL/g;
  if ($string =~ m/\$MAPUNIQ/) {
    my $MAPUNIQ = suniqid;
    $string =~ s/\$MAPUNIQ/$MAPUNIQ/g;
    $MAPUNIQVAL = $MAPUNIQ;
  }
  return $string;
}

=head2 get_transliterator

  Get a ref to a transliterator for the given from/to
  We are abstracting this in this way because it is not clear what the future
  of the transliteration library is. We want to be able to switch.

=cut

sub get_transliterator {
  my ($target, $from, $to) = map {lc} @_;
  my @valid_from = ('iast');
  my @valid_to   = ('devanagari');
  unless (first {$from eq $_} @valid_from and
          first {$to eq $_} @valid_to) {
    biber_warn("Invalid transliteration from/to pair ($from/$to)");
  }
  require Lingua::Translit;
  # List pairs explicitly as we don't expect there to be to many of these ever
  if ($from eq 'iast' and $to eq 'devanagari') {
    if ($logger->is_debug()) {# performance tune
      $logger->debug("Using 'iast -> devanagari' transliteration for sorting '$target'");
    }
    return new Lingua::Translit('IAST Devanagari');
  }
  return undef;
}

=head2 call_transliterator

  Run a transliterator on passed text. Hides call semantics of transliterator
  so we can switch engine in the future.

=cut

sub call_transliterator {
  my ($target, $from, $to, $text) = @_;
  if (my $tr = get_transliterator($target, $from, $to)) {
    # using Lingua::Translit
    return $tr->translit($text);
  }
  else {
    return $text;
  }
}

# Passed an array of strings, returns an array of initials
sub gen_initials {
  my @strings = @_;
  my @strings_out;
  foreach my $str (@strings) {
    # Deal with hyphenated name parts and normalise to a '-' character for easy
    # replacement with macro later
    if ($str =~ m/\p{Dash}/) {
      push @strings_out, join('-', gen_initials(split(/\p{Dash}/, $str)));
    }
    else {
      my $chr = Unicode::GCString->new($str)->substr(0, 1)->as_string;
      # Keep diacritics with their following characters
      if ($chr =~ m/\p{Dia}/) {
        push @strings_out, Unicode::GCString->new($str)->substr(0, 2)->as_string;
      }
      else {
        push @strings_out, $chr;
      }
    }
  }
  return @strings_out;
}

# Joins name parts using BibTeX tie algorithm. Ties are added:
#
# 1. After the first part if it is less than three characters long
# 2. Before the family part
sub join_name_parts {
  my $parts = shift;
  # special case - 1 part
  if ($#{$parts} == 0) {
    return $parts->[0];
  }
  # special case - 2 parts
  if ($#{$parts} == 1) {
    return $parts->[0] . '~' . $parts->[1];
  }
  my $namestring = $parts->[0];
  $namestring .= Unicode::GCString->new($parts->[0])->length < 3 ? '~' : ' ';
  $namestring .= join(' ', @$parts[1 .. ($#{$parts} - 1)]);
  $namestring .= '~' . $parts->[$#{$parts}];
  return $namestring;
}

# Split an xsv using Text::CSV because it is fast and can handle quoting
sub split_xsv {
  my ($string, $sep) = @_;
  if ($sep) {
    $CONFIG_CSV_PARSER->sep_char($sep);
  }
  $CONFIG_CSV_PARSER->parse($string);
  return $CONFIG_CSV_PARSER->fields();
}

1;

__END__

=head1 AUTHOR

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
