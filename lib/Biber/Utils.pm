package Biber::Utils;
use v5.24;
use strict;
use warnings;
use parent qw(Exporter);

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
use Data::Uniqid qw ( suniqid );
use Regexp::Common qw( balanced );
use List::AllUtils qw( first );
use Log::Log4perl qw(:no_extra_logdie_message);
use Scalar::Util qw(looks_like_number);
use Text::Balanced qw(extract_bracketed);
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

our @EXPORT = qw{ check_empty check_exists slurp_switchr slurp_switchw
  glob_data_file locate_data_file makenamesid makenameid stringify_hash
  normalise_string normalise_string_hash normalise_string_underscore
  normalise_string_sort normalise_string_label reduce_array remove_outer
  has_outer add_outer ucinit strip_nosort strip_nonamestring strip_noinit
  is_def is_undef is_def_and_notnull is_def_and_null is_undef_or_null
  is_notnull is_null normalise_utf8 inits join_name latex_recode_output
  filter_entry_options biber_error biber_warn ireplace imatch
  validate_biber_xml process_entry_options escape_label unescape_label
  biber_decode_utf8 out parse_date_start parse_date_end parse_date_range
  locale2bcp47 bcp472locale rangelen match_indices process_comment
  map_boolean parse_range parse_range_alt maploopreplace get_transliterator
  call_transliterator normalise_string_bblxml gen_initials join_name_parts
  split_xsv date_monthday tzformat expand_option_input strip_annotation
  appendstrict_check merge_entry_options process_backendin xdatarefout
  xdatarefcheck};

=head1 FUNCTIONS



=head2 glob_data_file

  Expands a data file glob to a list of filenames

=cut

sub glob_data_file {
  my ($source, $globflag) = @_;
  my @sources;

  # No globbing unless requested. No globbing for remote datasources.
  if ($source =~ m/\A(?:http|ftp)(s?):\/\//xms or
      not _bool_norm($globflag)) {
    push @sources, $source;
    return @sources;
  }

  $logger->info("Globbing data source '$source'");

  if ($^O =~ /Win/) {
    $logger->debug("Enabling Windows-style globbing");
    require Win32;
    require File::DosGlob;
    File::DosGlob->import('glob');
  }

  push @sources, map {biber_decode_utf8($_)} glob NFC(qq("$source"));

  $logger->info("Globbed data source '$source' to '" . join(',', @sources) . "'");
  return @sources;
}

=head2 slurp_switchr

  Use different read encoding/slurp interfaces for Windows due to its
  horrible legacy codepage system

=cut

sub slurp_switchr {
  my ($filename, $encoding) = @_;
  my $slurp;
  $encoding //= 'UTF-8';
  if ($^O =~ /Win/ and not Biber::Config->getoption('winunicode')) {
    require Win32::Unicode::File;
    my $fh = Win32::Unicode::File->new('<', NFC($filename));
    $fh->binmode(":encoding($encoding)");
    # 100MB block size as the loop over the default 1MB block size seems to fail for
    # files > 1Mb
    $slurp = $fh->slurp({blk_size => 1024*1024*100});
    $fh->close;
  }
  else {
    $slurp = File::Slurper::read_text($filename, $encoding);
  }
  return \$slurp;
}

=head2 slurp_switchw

  Use different write encoding/slurp interfaces for Windows due to its
  horrible legacy codepage system

=cut

sub slurp_switchw {
  my ($filename, $string) = @_;
  if ($^O =~ /Win/ and not Biber::Config->getoption('winunicode')) {
    require Win32::Unicode::File;
    my $fh = Win32::Unicode::File->new('>', NFC($filename));
    $fh->binmode(':encoding(UTF-8)');
    $fh->write($string);
    $fh->flush;
    $fh->close;
  }
  else {
    File::Slurper::write_text($filename, NFC($string));
  }
  return;
}

=head2 locate_data_file

  Searches for a data file by

  The exact path if the filename is absolute
  In the input_directory, if defined
  In the output_directory, if defined
  Relative to the current directory
  In the same directory as the control file
  Using kpsewhich, if available

=cut

sub locate_data_file {
  my $source = shift;
  my $sourcepath = $source; # default if nothing else below applies
  my $foundfile;

  if ($source =~ m/\A(?:http|ftp)(s?):\/\//xms) {
    $logger->info("Data source '$source' is a remote BibTeX data source - fetching ...");
    if (my $cf = $REMOTE_MAP{$source}) {
      $logger->info("Found '$source' in remote source cache");
      $sourcepath = $cf;
    }
    else {
      if ($1) { # HTTPS/FTPS
        # use IO::Socket::SSL qw(debug99); # useful for debugging SSL issues
        # We have to explicitly set the cert path because otherwise the https module
        # can't find the .pem when PAR::Packer'ed
        # Have to explicitly try to require Mozilla::CA here to get it into %INC below
        # It may, however, have been removed by some biber unpacked dists
        if (not exists($ENV{PERL_LWP_SSL_CA_FILE}) and
            not exists($ENV{PERL_LWP_SSL_CA_PATH}) and
            not defined(Biber::Config->getoption('ssl-nointernalca')) and
            eval {require Mozilla::CA}) {
          # we assume that the default CA file is in .../Mozilla/CA/cacert.pem
          (my $vol, my $dir, undef) = File::Spec->splitpath( $INC{"Mozilla/CA.pm"} );
          $dir =~ s/\/$//;      # splitpath sometimes leaves a trailing '/'
          $ENV{PERL_LWP_SSL_CA_FILE} = File::Spec->catpath($vol, "$dir/CA", 'cacert.pem');
        }

        # fallbacks for, e.g., linux
        unless (exists($ENV{PERL_LWP_SSL_CA_FILE})) {
          foreach my $ca_bundle (qw{
                                     /etc/ssl/certs/ca-certificates.crt
                                     /etc/pki/tls/certs/ca-bundle.crt
                                     /etc/ssl/ca-bundle.pem
                                 }) {
            next if ! -e $ca_bundle;
            $ENV{PERL_LWP_SSL_CA_FILE} = $ca_bundle;
            last;
          }
          foreach my $ca_path (qw{
                                   /etc/ssl/certs/
                                   /etc/pki/tls/
                               }) {
            next if ! -d $ca_path;
            $ENV{PERL_LWP_SSL_CA_PATH} = $ca_path;
            last;
          }
        }

        if (defined(Biber::Config->getoption('ssl-noverify-host'))) {
          $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
        }

        require LWP::Protocol::https;
      }

      require LWP::UserAgent;
      # no need to unlink file as tempdir will be unlinked. Also, the tempfile
      # will be needed after this sub has finished and so it must not be unlinked
      # by going out of scope
      my $tf = File::Temp->new(TEMPLATE => 'biber_remote_data_source_XXXXX',
                               DIR => $Biber::MASTER->biber_tempdir,
                               SUFFIX => '.bib',
                               UNLINK => 0);

      # Pretend to be a browser otherwise some sites refuse the default LWP UA string
      my $ua = LWP::UserAgent->new;  # we create a global UserAgent object
      $ua->agent('Mozilla/5.0');
      $ua->env_proxy;
      my $request = HTTP::Request->new('GET', $source, ['Zotero-Allowed-Request' => '1']);
      my $response = $ua->request($request, $tf->filename);

      unless ($response->is_success) {
        biber_error("Could not fetch '$source' (HTTP code: " . $response->code. ")");
      }
      $sourcepath = $tf->filename;
      # cache any remote so it persists and so we don't fetch it again
      $REMOTE_MAP{$source} = $sourcepath;
    }
  }

  # If input_directory is set, perhaps the file can be found there so
  # construct a path to test later
  if (my $indir = Biber::Config->getoption('input_directory')) {
    $foundfile = File::Spec->catfile($indir, $sourcepath);
  }
  # If output_directory is set, perhaps the file can be found there so
  # construct a path to test later
  elsif (my $outdir = Biber::Config->getoption('output_directory')) {
    $foundfile = File::Spec->catfile($outdir, $sourcepath);
  }

  # Filename is absolute
  if (File::Spec->file_name_is_absolute($sourcepath) and my $f = file_exist_check($sourcepath)) {
    return $f;
  }

  # File is input_directory or output_directory
  if (defined($foundfile) and my $f = file_exist_check($foundfile)) {
    return $f;
  }

  if (my $f = file_exist_check($sourcepath)) {
    return $f;
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

    my $path = "$ctlvolume$ctldir$sourcepath";

    if (my $f = file_exist_check($path)) {
      return $f;
    }
  }

  # File is in kpse path
  if (can_run('kpsewhich')) {
    if ($logger->is_debug()) {# performance tune
      $logger->debug("Looking for file '$sourcepath' via kpsewhich");
    }
    my $found;
    my $err;
    run3  [ 'kpsewhich', $sourcepath ], \undef, \$found, \$err, { return_if_system_error => 1};
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
        $logger->debug("Found '$sourcepath' via kpsewhich");
      }
      chomp $found;
      $found =~ s/\cM\z//xms; # kpsewhich in cygwin sometimes returns ^M at the end
      # filename can be UTF-8 and run3() isn't clever with UTF-8
      my $f = file_exist_check(decode_utf8($found));
      return $f;
    }
    else {
      if ($logger->is_debug()) {# performance tune
        $logger->debug("Could not find '$sourcepath' via kpsewhich");
      }
    }
  }

  # Not found
  biber_error("Cannot find '$source'!")
}

=head2 

  Check existence of NFC/NFD file variants and return correct one.
  Account for windows file encodings

=cut

sub file_exist_check {
  my $filename = shift;
  if ($^O =~ /Win/ and not Biber::Config->getoption('winunicode')) {
    require Win32::Unicode::File;
    if (Win32::Unicode::File::statW(NFC($filename))) {
      return NFC($filename);
    }
    if (Win32::Unicode::File::statW(NFD($filename))) {
      return NFD($filename);
    }
  }
  else {
    if (-e NFC("$filename")) {
      return NFC("$filename");
    }
    if (-e NFD("$filename")) {
      return NFD("$filename");
    }
  }

  return undef;
}

=head2 check_empty

    Wrapper around empty check to deal with Win32 Unicode filenames

=cut

sub check_empty {
  my $filename = shift;
  if ($^O =~ /Win/ and not Biber::Config->getoption('winunicode')) {
    require Win32::Unicode::File;
    return (Win32::Unicode::File::file_size(NFC($filename))) ? 1 : 0;
  }
  else {
    return (-s $filename) ? 1 : 0;
  }
}

=head2 check_exists

    Wrapper around exists check to deal with Win32 Unicode filenames

=cut

sub check_exists {
  my $filename = shift;
  if ($^O =~ /Win/ and not Biber::Config->getoption('winunicode')) {
    require Win32::Unicode::File;
    return Win32::Unicode::File::statW(NFC($filename)) ? 1 : 0;
  }
  else {
    return (-e $filename) ? 1 : 0;
  }
}

=head2 biber_warn

    Wrapper around various warnings bits and pieces.
    Add warning to the list of .bbl warnings and the master list of warnings

=cut

sub biber_warn {
  my ($warning, $entry) = @_;
  $entry->add_warning($warning) if $entry;
  push $Biber::MASTER->{warnings}->@*, $warning;
  return;
}


=head2 biber_error

    Wrapper around error logging
    Forces an exit.

=cut

sub biber_error {
  my ($error, $nodie) = @_;
  $logger->error($error);
  $Biber::MASTER->{errors}++;
  # exit unless user requested not to for errors
  unless ($nodie or Biber::Config->getoption('nodieonerror')) {
    $Biber::MASTER->display_end;
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
  foreach my $name ($names->names->@*) {
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
  foreach my $opt ($noinit->@*) {
    my $re = $opt->{value};
    $string =~ s/$re//gxms;
  }
  # remove latex macros (assuming they have only ASCII letters)
  $string =~ s{\\[A-Za-z]+\s*(\{([^\}]*)?\})?}{defined($2)?$2:q{}}eg;
  $string =~ s/^\{\}$//; # Special case if only braces are left
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

  foreach my $nsopt ($nosort->@*) {
    # Specific fieldnames override sets
    if (fc($nsopt->{name}) eq fc($fieldname)) {
      push $restrings->@*, $nsopt->{value};
    }
    elsif (my $set = $DATAFIELD_SETS{lc($nsopt->{name})} ) {
      if (first {fc($_) eq fc($fieldname)} $set->@*) {
        push $restrings->@*, $nsopt->{value};
      }
    }
  }

  # If no nosort to do, just return string
  return $string unless $restrings;

  foreach my $re ($restrings->@*) {
    $string =~ s/$re//gxms;
  }
  return $string;
}

=head2 strip_nonamestring

  Removes elements which are not to be used in certain name-related operations like:

  * fullhash generation
  * uniquename generation

 from a name

=cut

sub strip_nonamestring {
  no autovivification;
  my ($string, $fieldname) = @_;
  return '' unless $string; # Sanitise missing data
  return $string unless my $nonamestring = Biber::Config->getoption('nonamestring');

  my $restrings;

  foreach my $nnopt ($nonamestring->@*) {
    # Specific fieldnames override sets
    if (fc($nnopt->{name}) eq fc($fieldname)) {
      push $restrings->@*, $nnopt->{value};
    }
        elsif (my $set = $DATAFIELD_SETS{lc($nnopt->{name})} ) {
      if (first {fc($_) eq fc($fieldname)} $set->@*) {
        push $restrings->@*, $nnopt->{value};
      }
    }
  }

  # If no nonamestring to do, just return string
  return $string unless $restrings;

  foreach my $re ($restrings->@*) {
    $string =~ s/$re//gxms;
  }
  return $string;
}

=head2 normalise_string_label

Remove some things from a string for label generation. Don't strip \p{Dash}
as this is needed to process compound names or label generation.

=cut

sub normalise_string_label {
  my $str = shift;
  return '' unless $str; # Sanitise missing data
  my $nolabels = Biber::Config->getoption('nolabel');
  $str =~ s/\\[A-Za-z]+//g;    # remove latex macros (assuming they have only ASCII letters)
  # Replace ties with spaces or they will be lost
  $str =~ s/([^\\])~/$1 /g; # Foo~Bar -> Foo Bar
  foreach my $nolabel ($nolabels->@*) {
    my $re = $nolabel->{value};
    $str =~ s/$re//gxms;           # remove nolabel items
  }
  $str =~ s/(?:^\s+|\s+$)//g;      # Remove leading and trailing spaces
  $str =~ s/\s+/ /g;               # collapse spaces
  return $str;
}

=head2 normalise_string_sort

Removes LaTeX macros, and all punctuation, symbols, separators
as well as leading and trailing whitespace for sorting strings.
Control chars don't need to be stripped as they are completely ignorable in DUCET

=cut

sub normalise_string_sort {
  my $str = shift;
  my $fieldname = shift;
  return '' unless $str; # Sanitise missing data
  # First strip nosort REs
  $str = strip_nosort($str, $fieldname);
  # Then replace ties with spaces or they will be lost
  $str =~ s/([^\\])~/$1 /g; # Foo~Bar -> Foo Bar
  # Don't use normalise_string_common() as this strips out things needed for sorting
  $str =~ s/\\[A-Za-z]+//g;        # remove latex macros (assuming they have only ASCII letters)
  $str =~ s/[{}]+//g;              # remove embedded braces
  $str =~ s/^\s+|\s+$//g;          # Remove leading and trailing spaces
  $str =~ s/\s+/ /g;               # collapse spaces
  return $str;
}

=head2 normalise_string_bblxml

Some string normalisation for bblxml output

=cut

sub normalise_string_bblxml {
  my $str = shift;
  return '' unless $str; # Sanitise missing data
  $str =~ s/\\[A-Za-z]+//g; # remove latex macros (assuming they have only ASCII letters)
  $str =~ s/\{([^\{\}]+)\}/$1/g; # remove pointless braces
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
  $str =~ s/[\p{P}\p{S}\p{C}]+//g; # remove punctuation, symbols and control
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
  $str =~ s/[\{\}~\.\s]+//g; # Remove braces, ties, dots, spaces
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
  foreach my $elem ($b->@*) {
    $countb{$elem}++;
  }
  my @result;
  foreach my $elem ($a->@*) {
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
  my @check = extract_bracketed($str, '{}');
  if (not defined($check[0]) or $check[0] ne $str) {# Not balanced outer braces, ignore
    return (0, $str);
  }
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

    whereas:

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
  my @arr = $arg->@*;
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
  my @arr = keys $arg->%*;
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
  while (my ($k,$v) = each $hashref->%*) {
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
  $istring =~ s/[{}]//; # Remove any spurious braces left by btparse inits routines
  # The map {} is there to remove broken hyphenated initials returned from btparse
  # For example, in the, admittedly strange 'al- Hassan, John', we want the 'al-'
  # interpreted as a prefix (because of the following space) but because of the
  # hypen, this is intialised as "a-" by btparse. So we correct such edge cases here by
  # removing any trailing dashes in initials
  return [ map {s/\p{Pd}$//r} split(/(?<!\\)~/, $istring) ];
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

    Process any per_entry option transformations which are necessary on output

=cut

sub filter_entry_options {
  my ($secnum, $be) = @_;
  my $bee = $be->get_field('entrytype');
  my $citekey = $be->get_field('citekey');
  my $roptions = [];

  foreach my $opt (sort Biber::Config->getblxentryoptions($secnum, $citekey)) {

    my $val = Biber::Config->getblxoption($secnum, $opt, undef, $citekey);
    my $cfopt = $CONFIG_BIBLATEX_OPTIONS{ENTRY}{$opt}{OUTPUT};
    $val = map_boolean($opt, $val, 'tostring');

    # By this point, all entry meta-options have been expanded by expand_option_input
    if ($cfopt) { # suppress only explicitly ignored output options
      push $roptions->@*, $opt . ($val ? "=$val" : '') ;
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
  my ($value, $val_match, $negmatch, $ci) = @_;
  return 0 unless $val_match;
  if ($ci) {
    $val_match = qr/$val_match/i;
  }
  else {
    $val_match = qr/$val_match/;
  }
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
  my ($value, $val_match, $val_replace, $ci) = @_;
  return $value unless $val_match;
  if ($ci) {
    $val_match = qr/$val_match/i;
  }
  else {
    $val_match = qr/$val_match/;
  }
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

  if (check_exists($schema)) {
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
  my ($bn, $bv, $dir) = @_;
  # Ignore non-booleans
  return $bv unless exists($CONFIG_OPTTYPE_BIBLATEX{$bn});
  return $bv unless $CONFIG_OPTTYPE_BIBLATEX{$bn} eq 'boolean';

  my $b = lc($bv);

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

=head2 process_entry_options

    Set per-entry options

=cut

sub process_entry_options {
  my ($citekey, $options, $secnum) = @_;
  return unless $options;       # Just in case it's null
  foreach ($options->@*) {
    s/\s+=\s+/=/g; # get rid of spaces around any "="
    m/^([^=]+)=?(.+)?$/;
    my $val = $2 // 1; # bare options are just boolean numerals
    my $oo = expand_option_input($1, $val, $CONFIG_BIBLATEX_OPTIONS{ENTRY}{lc($1)}{INPUT});

    foreach my $o ($oo->@*) {
      Biber::Config->setblxoption($secnum, $o->[0], $o->[1], 'ENTRY', $citekey);
    }
  }
  return;
}

=head2 merge_entry_options

    Merge entry options, dealing with conflicts

=cut

sub merge_entry_options {
  my ($opts, $overrideopts) = @_;
  return $opts unless defined($overrideopts);
  return $overrideopts unless defined($opts);
  my $merged = [];
  my $used_overrides = [];

  foreach my $ov ($opts->@*) {
    my $or = 0;
    my ($o, $e, $v) = $ov =~ m/^([^=]+)(=?)(.*)$/;
    foreach my $oov ($overrideopts->@*) {
      my ($oo, $eo, $vo) = $oov =~ m/^([^=]+)(=?)(.*)$/;
      if ($o eq $oo) {
        $or = 1;
        my $oropt = "$oo" . ($eo // '') . ($vo // '');
        push $merged->@*, $oropt;
        push $used_overrides->@*, $oropt;
        last;
      }
    }
    unless ($or) {
      push $merged->@*, ("$o" . ($e // '') .($v // ''));
    }
  }

  # Now push anything in the overrides array which had no conflicts
  foreach my $oov ($overrideopts->@*) {
    unless(first {$_ eq $oov} $used_overrides->@*) {
      push $merged->@*, $oov;
    }
  }

  return $merged;
}

=head2 expand_option_input

    Expand options such as meta-options coming from biblatex

=cut

sub expand_option_input {
  my ($opt, $val, $cfopt) = @_;
  my $outopts;

  # Coerce $val to integer so we know what to test with later
  $val = map_boolean($opt, $val, 'tonum');

  # Standard option
  if (not defined($cfopt)) { # no special input meta-option handling
    push $outopts->@*, [$opt, $val];
  }
  # Set all split options
  elsif (ref($cfopt) eq 'ARRAY') {
    foreach my $k ($cfopt->@*) {
      push $outopts->@*, [$k, $val];
    }
  }
  # ASSUMPTION - only biblatex booleans resolve to hashes (currently, only dataonly)
  # Specify values per all splits
  elsif (ref($cfopt) eq 'HASH') {
    foreach my $k (keys $cfopt->%*) {
      my $subval = map_boolean($k, $cfopt->{$k}, 'tonum');

      # meta-opt $val is 0/false - invert any boolean sub-options and ignore others
      # for example, if datonly=false in a per-entry option:
      # skipbib => false
      # skiplab => false
      # skipbiblist => false
      # uniquename => DON'T SET ANYTHING (picked up from higher scopes)
      # uniquelist => DON'T SET ANYTHING (picked up from higher scopes)
      unless ($val) {
        if (exists($CONFIG_OPTTYPE_BIBLATEX{$k}) and
            $CONFIG_OPTTYPE_BIBLATEX{$k} eq 'boolean') {

          # The defaults for the sub-options are for when $val=true
          # invert booleans when $val=false
          push $outopts->@*, [$k, $subval ? 0 : 1];
        }
      }
      else {
        push $outopts->@*, [$k, $subval];
      }
    }
  }

  return $outopts;
}

=head2 parse_date_range

  Parse of ISO8601 date range

=cut

sub parse_date_range {
  my ($bibentry, $datetype, $datestring) = @_;
  my ($sd, $sep, $ed) = $datestring =~ m|^([^/]+)?(/)?([^/]+)?$|;

  # Very bad date format, something like '2006/05/04' catch early
  unless ($sd or $ed) {
    return (undef, undef, undef, undef);
  }

  my $unspec;
  if ($sd =~ /X/) {# ISO8601-2 4.3 unspecified format
    ($sd, $sep, $ed, $unspec) = parse_date_unspecified($sd);
  }
  # Set start date unknown flag
  if ($sep and not $sd) {
    $bibentry->set_field($datetype . 'dateunknown',1);
  }
  # Set end date unknown flag
  if ($sep and not $ed) {
    $bibentry->set_field($datetype . 'enddateunknown',1);
  }
  return (parse_date_start($sd), parse_date_end($ed), $sep, $unspec);
}

=head2 parse_date_unspecified

  Parse of ISO8601-2:2016 4.3 unspecified format into date range
  Returns range plus specification of granularity of unspecified

=cut

sub parse_date_unspecified {
  my $d = shift;

  # 199X -> 1990/1999
  if ($d =~ m/^(\d{3})X$/) {
    return ("${1}0", '/', "${1}9", 'yearindecade');
  }
  # 19XX -> 1900/1999
  elsif ($d =~ m/^(\d{2})XX$/) {
    return ("${1}00", '/', "${1}99", 'yearincentury');
  }
  # 1999-XX -> 1999-01/1999-12
  elsif ($d =~ m/^(\d{4})\p{Dash}XX$/) {
    return ("${1}-01", '/', "${1}-12", 'monthinyear');
  }
  # 1999-01-XX -> 1999-01-01/1999-01-31
  # (understands different months and leap years)
  elsif ($d =~ m/^(\d{4})\p{Dash}(\d{2})\p{Dash}XX$/) {

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
  # 1999-XX-XX -> 1999-01-01/1999-12-31
  elsif ($d =~ m/^(\d{4})\p{Dash}XX\p{Dash}XX$/) {
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

  Parse of iso8601-2 dates

=cut

sub parse_date {
  my ($obj, $string) = @_;
  # Must do this to make sure meta-information from sub-class Biber::Date::Format is reset
  $obj->init();
  return 0 unless $string;
  return 0 if $string eq '..';    # ISO8601-2 4.4 (open date)

  my $dt = eval {$obj->parse_datetime($string)};
  return $dt unless $dt; # bad parse, don't do anything else

  # Check if this datetime is before the Gregorian start date. If so, return Julian date
  # instead of Gregorian/astronomical
  # This conversion is only done if the date is not missing month or day since the Julian
  # Gregorian difference is usually a matter of only days and therefore a bare year like
  # "1565" could be "1564" or "1565" in Julian, depending on the month/day of the Gregorian date
  # For example, "1565-01-01" (which is what DateTime will default to for bare years), is
  # "1564-12-22" Julian but 1564-01-11" and later is "1565" Julian year.
  if (Biber::Config->getblxoption(undef,'julian') and
      not $obj->missing('month') and
      not $obj->missing('day')) {

    # There is guaranteed to be an end point since biblatex has a default
    my $gs = Biber::Config->getblxoption(undef,'gregorianstart');
    my ($gsyear, $gsmonth, $gsday) = $gs =~ m/^(\d{4})\p{Dash}(\d{2})\p{Dash}(\d{2})$/;
    my $dtgs = DateTime->new( year  => $gsyear,
                              month => $gsmonth,
                              day   => $gsday );

    # Datetime is not before the Gregorian start point
    if (DateTime->compare($dt, $dtgs) == -1) {
      # Override with Julian conversion
      $dt = DateTime::Calendar::Julian->from_object( object => $dt );
      $obj->set_julian;
    }
  }

  return $dt;
}

=head2 date_monthday

  Force month/day to ISO8601-2:2016 format with leading zero

=cut

sub date_monthday {
  my $md = shift;
  return $md ? sprintf('%.2d', $md) : undef;
}

=head2 biber_decode_utf8

    Perform NFD form conversion as well as UTF-8 conversion. Used to normalize
    bibtex input as the T::B interface doesn't allow a neat whole file slurping.

=cut

sub biber_decode_utf8 {
  return NFD(decode_utf8(shift));# Unicode NFD boundary
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
  foreach my $f ($rf->@*) {
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
  foreach my $regex ($regexes->@*) {
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

=head2 strip_annotation

  Removes annotation marker from a field name

=cut

sub strip_annotation {
  my $string = shift;
  my $ann = $CONFIG_META_MARKERS{annotation};
  my $nam = $CONFIG_META_MARKERS{namedannotation};
  return $string =~ s/$ann$nam?.*$//r;
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
  my @valid_from = ('iast', 'russian');
  my @valid_to   = ('devanagari', 'ala-lc', 'bgn/pcgn-standard');
  unless (first {$from eq $_} @valid_from and
          first {$to eq $_} @valid_to) {
    biber_warn("Invalid transliteration from/to pair ($from/$to)");
  }
  require Lingua::Translit;
  if ($logger->is_debug()) {# performance tune
    $logger->debug("Using '$from -> $to' transliteration for sorting '$target'");
  }

  # List pairs explicitly as we don't expect there to be to many of these ever
  if ($from eq 'iast' and $to eq 'devanagari') {
    return new Lingua::Translit('IAST Devanagari');
  }
  elsif ($from eq 'russian' and $to eq 'ala-lc') {
    return new Lingua::Translit('ALA-LC RUS');
  }
  elsif ($from eq 'russian' and $to eq 'bgn/pcgn-standard') {
    return new Lingua::Translit('BGN/PCGN RUS Standard');
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
    # using Lingua::Translit, NFC boundary as we are talking to external module
    return $tr->translit(NFC($text));
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
    # Dont' split a name part if it's brace-wrapped
    # Dont' split a name part if the hyphen in a hyphenated name is protected like:
    # Hans{-}Peter as this is an old BibTeX way of suppressing hyphenated names
    if ($str !~ m/^\{.+\}$/ and $str =~ m/[^{]\p{Dash}[^}]/) {
      push @strings_out, join('-', gen_initials(split(/\p{Dash}/, $str)));
    }
    else {
      # remove any leading braces and backslash from latex decoding or protection
      $str =~ s/^\{+//;
      my $chr = Unicode::GCString->new($str)->substr(0, 1)->as_string;
      # Keep diacritics with their following characters
      if ($chr =~ m/^\p{Dia}/) {
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
  $namestring .= join(' ', $parts->@[1 .. ($#{$parts} - 1)]);
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

# Add a macro sep for minutes in timezones
sub tzformat {
  my $tz = shift;
  if ($tz =~ m/^([+-])(\d{2}):?(\d{2})?/) {
    return "$1$2" . ($3 ? "\\bibtzminsep $3" : '');
  }
  elsif ($tz eq 'UTC') {
    return 'Z';
  }
  else {
    return $tz;
  }
}

# Wrapper to enforce map_appendstrict
sub appendstrict_check {
  my ($step, $orig, $val) = @_;
  # Strict append?
  if ($step->{map_appendstrict}) {
    if ($orig) {
      return $orig . $val;
    }
    else { # orig is empty, don't append
      return '';
    }
  }
  # Normal append, don't care if orig is empty
  else {
    return $orig . $val;
  }
}

# Process backendin attribute from .bcf
sub process_backendin {
  my $bin = shift;
  return undef unless $bin;
  my $opts = [split(/\s*,\s*/, $bin)];
  if (grep {/=/} $opts->@*) {
    my $hopts;
    foreach my $o ($opts->@*) {
      my ($k, $v) = $o =~ m/\s*([^=]+)=(.+)\s*/;
      $hopts->{$k} = $v;
    }
    return $hopts;
  }
  else {
    return $opts;
  }
  return undef;
}

# Replace xnamesep/xdatasep with output variants
# Some datasource formats don't need the marker (biblatexml)
sub xdatarefout {
  my ($xdataref, $implicitmarker) = @_;
  my $xdmi = Biber::Config->getoption('xdatamarker');
  my $xdmo = Biber::Config->getoption('output_xdatamarker');
  my $xnsi = Biber::Config->getoption('xnamesep');
  my $xnso = Biber::Config->getoption('output_xnamesep');
  my $xdsi = Biber::Config->getoption('xdatasep');
  my $xdso = Biber::Config->getoption('output_xdatasep');
  if ($implicitmarker) { # Don't want output marker at all
    $xdataref =~ s/^$xdmi$xnsi//x;
  }
  else {
    $xdataref =~ s/^$xdmi(?=$xnsi)/$xdmo/x; # Should be only one
    $xdataref =~ s/$xnsi/$xnso/xg;
  }
  $xdataref =~ s/$xdsi/$xdso/xg;
  return $xdataref;
}

# Check an output value for an xdata ref and replace output markers if necessary.
sub xdatarefcheck {
  my ($val, $implicitmarker) = @_;
  return undef unless $val;
  my $xdmi = Biber::Config->getoption('xdatamarker');
  my $xnsi = Biber::Config->getoption('xnamesep');
  if ($val =~ m/^\s*$xdmi(?=$xnsi)/) {
    return xdatarefout($val, $implicitmarker);
  }
  return undef;
}

sub _bool_norm {
  my $b = shift;
  return 0 unless $b;
  return 1 if $b =~ m/(?:true|1)/i;
  return 0;
}

1;

__END__

=head1 AUTHOR

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
