package Biber::Input::file::endnotexml;
use v5.16;
use strict;
use warnings;
use base 'Exporter';

use Carp;
use Biber::Constants;
use Biber::Entries;
use Biber::Entry;
use Biber::Entry::Names;
use Biber::Entry::Name;
use Biber::Sections;
use Biber::Section;
use Biber::Utils;
use Biber::Config;
use Digest::MD5 qw( md5_hex );
use Encode;
use File::Spec;
use File::Slurp;
use File::Temp;
use Log::Log4perl qw(:no_extra_logdie_message);
use List::AllUtils qw( :all );
use XML::LibXML;
use XML::LibXML::Simple;
use Data::Dump qw(dump);
use Text::BibTeX qw(:nameparts :joinmethods :metatypes);
use Text::BibTeX::Name;
use Text::BibTeX::NameFormat;
use Unicode::Normalize;
use Unicode::GCString;
use URI;

##### This is based on Endnote X4 #####

my $logger = Log::Log4perl::get_logger('main');
my $orig_key_order = {};

# Determine handlers from data model
my $dm = Biber::Config->get_dm;
my $handlers = {
                'field' => {
                            'default' => {
                                          'code'     => \&_literal,
                                          'date'     => \&_date,
                                          'entrykey' => \&_literal,
                                          'integer'  => \&_literal,
                                          'key'      => \&_literal,
                                          'literal'  => \&_literal,
                                          'range'    => \&_range,
                                          'verbatim' => \&_verbatim,
                                          'uri'      => \&_uri
                                         },
                            'xsv'     => {
                                          'entrykey' => \&_xsv,
                                          'keyword'  => \&_xsv,
                                          'option'   => \&_xsv,
                                         }
                           },
                'list' => {
                           'default' => {
                                         'entrykey' => \&_literal,
                                         'key'      => \&_list,
                                         'literal'  => \&_list,
                                         'name'     => \&_name
                                        }
                          }
};


=head2 extract_entries

   Main data extraction routine.
   Accepts a data source identifier (filename in this case),
   preprocesses the file and then looks for the passed keys,
   creating entries when it finds them and passes out an
   array of keys it didn't find.

=cut

sub extract_entries {
  my ($source, $keys) = @_;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $filename;
  my @rkeys = @$keys;
  my $tf; # Up here so that the temp file has enough scope to survive until we've
          # used it
  $logger->trace("Entering extract_entries() in driver 'endnotexml'");

  # Get a reference to the correct sourcemap sections, if they exist
  my $smaps = [];
  # Maps are applied in order USER->STYLE->DRIVER
  if (defined(Biber::Config->getoption('sourcemap'))) {
    # User maps
    if (my $m = first {$_->{datatype} eq 'endnotexml' and $_->{level} eq 'user' } @{Biber::Config->getoption('sourcemap')} ) {
      push @$smaps, $m;
    }
    # Style maps
    if (my $m = first {$_->{datatype} eq 'endnotexml' and $_->{level} eq 'style' } @{Biber::Config->getoption('sourcemap')} ) {
      push @$smaps, $m;
    }
    # Driver default maps
    if (my $m = first {$_->{datatype} eq 'endnotexml' and $_->{level} eq 'driver'} @{Biber::Config->getoption('sourcemap')} ) {
      push @$smaps, $m;
    }
  }

  # If it's a remote data file, fetch it first
  if ($source =~ m/\A(?:http|ftp)(s?):\/\//xms) {
    $logger->info("Data source '$source' is a remote EndNote XML datasource - fetching ...");
    if ($1) { # HTTPS
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
        $dir =~ s/\/$//; # splitpath sometimes leaves a trailing '/'
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
    require LWP::Simple;
    $tf = File::Temp->new(TEMPLATE => 'biber_remote_data_source_XXXXX',
                          DIR => $Biber::MASTER->biber_tempdir,
                          SUFFIX => '.xml');
    unless (LWP::Simple::is_success(LWP::Simple::getstore($source, $tf->filename))) {
      biber_error("Could not fetch '$source'");
    }
    $filename = $tf->filename;
  }
  else {
    # Need to get the filename so we increment
    # the filename count for preambles at the bottom of this sub
    unless ($filename = locate_biber_file($source)) {
      biber_error("Cannot find '$source'!")
    }
  }

  # Log that we found a data file
  $logger->info("Found EndNote XML data source '$filename'");

  # Set up XML parser and namespaces
  my $parser = XML::LibXML->new();
  my $xml = File::Slurp::read_file($filename) or biber_error("Can't read file $filename");
  $xml = NFD(decode('UTF-8', $xml));# Unicode NFD boundary
  my $enxml = $parser->parse_string($xml);
  my $xpc = XML::LibXML::XPathContext->new($enxml);

  if ($section->is_allkeys) {
    $logger->debug("All citekeys will be used for section '$secnum'");
    # Loop over all entries, creating objects
    foreach my $entry ($xpc->findnodes("/xml/records/record")) {
      $logger->debug('Parsing Endnote XML entry object ' . $entry->nodePath);

      # If an entry has no key, ignore it and warn
      unless ($entry->findvalue('./rec-number')) {
        biber_warn("Invalid or undefined entry ID in file '$filename', skipping ...");
        next;
      }

      my $ek = $entry->findvalue('./rec-number');
      # If we've already seen a case variant, warn
      if (my $okey = $section->has_badcasekey($ek)) {
        biber_warn("Possible typo (case mismatch): '$ek' and '$okey' in file '$filename', skipping '$ek' ...");
      }

      # If we've already seen this key, ignore it and warn
      if ($section->has_everykey($ek)) {
        biber_warn("Duplicate entry key: '$ek' in file '$filename', skipping ...");
        next;
      }
      else {
        $section->add_everykey($ek);
      }

      my $dbdid = $entry->findvalue('./foreign-keys/key/@db-id');
      my $key = $ek;

      # Record a key->datasource name mapping for error reporting
      $section->set_keytods("$dbdid:$key", $filename);

      # We do this as otherwise we have no way of determining the origing .bib entry order
      # We need this in order to do sorting=none + allkeys because in this case, there is no
      # "citeorder" because nothing is explicitly cited and so "citeorder" means .bib order
      push @{$orig_key_order->{$filename}}, "$dbdid:$key";
      create_entry("$dbdid:$key", $entry, $source, $smaps);
    }

    # if allkeys, push all bibdata keys into citekeys (if they are not already there)
    # We are using the special "orig_key_order" array which is used to deal with the
    # situation when sorting=non and allkeys is set. We need an array rather than the
    # keys from the bibentries hash because we need to preserver the original order of
    # the .bib as in this case the sorting sub "citeorder" means "bib order" as there are
    # no explicitly cited keys
    $section->add_citekeys(@{$orig_key_order->{$filename}});
    $logger->debug("Added all citekeys to section '$secnum': " . join(', ', $section->get_citekeys));
  }
  else {
    # loop over all keys we're looking for and create objects
    $logger->debug('Wanted keys: ' . join(', ', @$keys));
    foreach my $wanted_key (@$keys) {
      $logger->debug("Looking for key '$wanted_key' in Endnote XML file '$filename'");
      # Split key into parts
      my ($wdbid, $wnum) = split(/:/, $wanted_key);

      if (my @entries = $xpc->findnodes("/xml/records/record[rec-number[text()='$wnum']][foreign-keys/key[\@db-id='$wdbid']]")) {
        # Check to see if there is more than one entry with this key and warn if so
        if ($#entries > 0) {
          biber_warn("Found more than one entry for key '$wanted_key' in '$wdbid:$wnum' - Skipping duplicates ...");
        }
        my $entry = $entries[0];

        $logger->debug("Found key '$wanted_key' in Endnote XML file '$filename'");
        $logger->debug('Parsing Endnote XML entry object ' . $entry->nodePath);

        # Record a key->datasource name mapping for error reporting
        $section->set_keytods($wanted_key, $filename);

        # See comment above about the importance of the case of the key
        # passed to create_entry()
        create_entry($wanted_key, $entry, $source, $smaps);
        # found a key, remove it from the list of keys we want
        @rkeys = grep {$wanted_key ne $_} @rkeys;
      }
      $logger->debug('Wanted keys now: ' . join(', ', @rkeys));
    }
  }

  return @rkeys;
}


=head2 create_entry

   Create a Biber::Entry object from an entry found in a Endnote
   XML data source

=cut

sub create_entry {
  my ($key, $entry, $source, $smaps) = @_;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $bibentries = $section->bibentries;
  my $bibentry = new Biber::Entry;

  $bibentry->set_field('citekey', $key);

  # Datasource mapping applied in $smap order (USER->STYLE->DRIVER)
  foreach my $smap (@$smaps) {
    my $level = $smap->{level};

    # DATASOURCE MAPPING DEFINED BY USER IN CONFIG FILE OR .bcf
  MAP:    foreach my $map (@{$smap->{map}}) {
      my $last_field = undef;
      my $last_fieldval = undef;

      my @imatches; # For persising parenthetical matches over several steps

      my $itype = $entry->findvalue('./ref-type/@name');
      my $last_type = $itype; # defaults to the entrytype unless changed below

      # Check pertype restrictions
      unless (not exists($map->{per_type}) or
              first {$_->{content} eq $itype} @{$map->{per_type}}) {
        next;
      }

      # Check per_datasource restrictions
      # Don't compare case insensitively - this might not be correct
      unless (not exists($map->{per_datasource}) or
              first {$_->{content} eq $source} @{$map->{per_datasource}}) {
        next;
      }

      # loop over mapping steps
      foreach my $step (@{$map->{map_step}}) {

        # Entrytype map
        if (my $source = $step->{map_type_source}) {

          unless ($itype eq $source) {
            # Skip the rest of the map if this step doesn't match and match is final
            if ($step->{map_final}) {
              $logger->debug("Source mapping (type=$level, key=$key): Entry type is '$itype' but map wants '$source' and step has 'final' set ... skipping rest of map ...");
              next MAP;
            }
            else {
              # just ignore this step
              $logger->debug("Source mapping (type=$level, key=$key): Entry type is '$itype' but map wants '$source' ... skipping step ...");
              next;
            }
          }
          # Change entrytype if requested
          $last_type = $itype;
          $logger->debug("Source mapping (type=$level, key=$key): Changing entry type from '$last_type' to " . $step->{map_type_target});
          $entry->findnodes('./ref-type')->get_node(1)->setAttribute('name', $step->{map_type_target});
        }

        # Field map
        if (my $source = $step->{map_field_source}) {
          unless ($entry->exists($source)) {
            # Skip the rest of the map if this step doesn't match and match is final
            if ($step->{map_final}) {
              $logger->debug("Source mapping (type=$level, key=$key): No field '$source' and step has 'final' set, skipping rest of map ...");
              next MAP;
            }
            else {
              # just ignore this step
              $logger->debug("Source mapping (type=$level, key=$key): No field '$source', skipping step ...");
              next;
            }
          }

          $last_field = $source;
          $last_fieldval = $entry->findvalue($source);

          # map fields to targets
          if (my $m = $step->{map_match}) {
            if (defined($step->{map_replace})) { # replace can be null
              my $r = $step->{map_replace};
              $logger->debug("Source mapping (type=$level, key=$key): Doing match/replace '$m' -> '$r' on field '$source'");
              my $text = ireplace($last_fieldval, $m, $r);
              $entry->findnodes($source . '/style/text()')->get_node(1)->setData($text);
            }
            else {
              unless (@imatches = imatch($last_fieldval, $m)) {
                # Skip the rest of the map if this step doesn't match and match is final
                if ($step->{map_final}) {
                  $logger->debug("Source mapping (type=$level, key=$key): Field '$source' does not match '$m' and step has 'final' set, skipping rest of map ...");
                  next MAP;
                }
                else {
                  # just ignore this step
                  $logger->debug("Source mapping (type=$level, key=$key): Field '$source' does not match '$m', skipping step ...");
                  next;
                }
              }
            }
          }

          # Set to a different target if there is one
          if (my $target = $step->{map_field_target}) {
            if (my @t = $entry->findnodes($target)) {
              if ($map->{map_overwrite} // $smap->{map_overwrite}) {
                $logger->debug("Source mapping (type=$level, key=$key): Overwriting existing field '$target'");
                # Have to do this otherwise XML::LibXML will merge the nodes
                map {$_->unbindNode} @t;
              }
              else {
                $logger->debug("Source mapping (type=$level, key=$key): Field '$source' is aliased to field '$target' but both are defined, skipping ...");
                next;
              }
            }

            map {$_->setNodeName(_leaf_node($target))} $entry->findnodes($source);
          }
        }

        # field creation
        if (my $field = $step->{map_field_set}) {

          # Deal with special tokens
          if ($step->{map_null}) {
            $logger->debug("Source mapping (type=$level, key=$key): Deleting field '$field'");
            map {$_->unbindNode} $entry->findnodes($field);
          }
          else {
            if ($entry->exists($field)) {
              unless ($map->{map_overwrite} // $smap->{map_overwrite}) {
                if ($step->{map_final}) {
                  # map_final is set, ignore and skip rest of step
                  $logger->debug("Source mapping (type=$level, key=$key): Field '$field' exists, overwrite is not set and step has 'final' set, skipping rest of map ...");
                  next MAP;
                }
                else {
                  # just ignore this step
                  $logger->debug("Source mapping (type=$level, key=$key): Field '$field' exists and overwrite is not set, skipping step ...");
                  next;
                }
              }
            }

            # If append is set, keep the original value and append the new
            my $orig = $step->{map_append} ? $entry->findvalue($field) : '';

            if ($step->{map_origentrytype}) {
              next unless $last_type;
              $logger->debug("Source mapping (type=$level, key=$key): Setting field '$field' to '${orig}${last_type}'");
              $entry->appendTextChild($field, $orig . $last_type);
            }
            elsif ($step->{map_origfieldval}) {
              next unless $last_fieldval;
              $logger->debug("Source mapping (type=$level, key=$key): Setting field '$field' to '${orig}${last_fieldval}'");
              $entry->appendTextChild($field, $orig . $last_fieldval);
            }
            elsif ($step->{map_origfield}) {
              next unless $last_field;
              $logger->debug("Source mapping (type=$level, key=$key): Setting field '$field' to '${orig}${last_field}'");
              $entry->appendTextChild($field, $orig . $last_field);
            }
            else {
              my $fv = $step->{map_field_value};
              # Now re-instate any unescaped $1 .. $9 to get round these being
              # dynamically scoped and being null when we get here from any
              # previous map_match
              $fv =~ s/(?<!\\)\$(\d)/$imatches[$1-1]/ge;
              $logger->debug("Source mapping (type=$level, key=$key): Setting field '$field' to '${orig}${fv}'");
              $entry->appendTextChild($field, $orig . $fv);
            }
          }
        }
      }
    }
  }

  my $itype = $entry->findvalue('./ref-type/@name');
  foreach my $f (uniq map {$_->nodeName()} $entry->findnodes('(./*|./titles/*|./contributors/*|./urls/web-urls/*|./dates/*)')) {

    # Now run any defined handler
    # There is no else clause here to warn on invalid fields as there are so many
    # in Endnote
    if ($dm->is_field($f)) {
      my $handler = _get_handler($f);
      &$handler($bibentry, $entry, $f, $key);
    }
  }

  $bibentry->set_field('entrytype', $itype);
  $bibentry->set_field('datatype', 'endnotexml');
  $bibentries->add_entry($key, $bibentry);

  return;
}

# HANDLERS
# ========

# List fields
sub _list {
  my ($bibentry, $entry, $f) = @_;
  my $value = $entry->findvalue("./$f");
  $bibentry->set_datafield($f, [ _norm($value) ]);
  return;
}

# literal fields
sub _literal {
  my ($bibentry, $entry, $f) = @_;
  my $value = $entry->findvalue("(./$f|./titles/$f|./contributors/$f|./urls/web-urls/$f)");
  $bibentry->set_datafield($f, _norm($value));
  return;
}

# Verbatim fields
sub _verbatim {
  my ($bibentry, $entry, $f) = @_;
  my $value = $entry->findvalue("(./$f|./titles/$f|./contributors/$f|./urls/web-urls/$f)");
  $bibentry->set_datafield($f, _norm($value));
  return;
}

# URI fields
sub _uri {
  my ($bibentry, $entry, $f) = @_;
  my $value = _norm($entry->findvalue("(./$f|./titles/$f|./contributors/$f|./urls/web-urls/$f)"));

  # URL escape if it doesn't look like it already is
  # This is useful if we are generating URLs automatically with maps which may
  # contain UTF-8 from other fields
  unless ($value =~ /\%/) {
   $value = URI->new($value)->as_string;
  }

  $bibentry->set_datafield($f, $value);
  return;
}

# Range fields
sub _range {
  my ($bibentry, $entry, $f) = @_;
  my $values_ref;
  my $value = $entry->findvalue("./$f");
  my @values = split(/\s*,\s*/, _norm($value));
  # Here the "-–" contains two different chars even though they might
  # look the same in some fonts ...
  # If there is a range sep, then we set the end of the range even if it's null
  # If no  range sep, then the end of the range is undef
  foreach my $value (@values) {
    $value =~ m/\A\s*([^-–]+)([-–]*)([^-–]*)\s*\z/xms;
    my $end;
    if ($2) {
      $end = $3;
    }
    else {
      $end = undef;
    }
    push @$values_ref, [$1 || '', $end];
  }
  $bibentry->set_datafield($f, $values_ref);
  return;
}

# Date fields
sub _date {
  my ($bibentry, $entry, $f, $key) = @_;
  my $daten = $entry->findnodes("./dates/$f")->get_node(1);
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $ds = $section->get_keytods($key);

  # Use Endnote explicit date attributes, if present
  # It's not clear if Endnote actually uses these attributes
  if ($daten->hasAttribute('year')) {
    $bibentry->set_datafield('year', $daten->getAttribute('year'));
    if ($daten->hasAttribute('month')) {
      $bibentry->set_datafield('month', $daten->getAttribute('month'));
    }
    if ($daten->hasAttribute('day')) {
      $bibentry->set_datafield('day', $daten->getAttribute('day'));
    }
    return;
  }
  else {
    my $date = _norm($entry->findvalue("./dates/$f"));
    # We are not validating dates here, just syntax parsing
    my $date_re = qr/(\d{4}) # year
                     (?:-(\d{2}))? # month
                     (?:-(\d{2}))? # day
                    /xms;
    if (my ($byear, $bmonth, $bday, $r, $eyear, $emonth, $eday) =
        $date =~ m|\A$date_re(/)?(?:$date_re)?\z|xms) {

      $bibentry->set_datafield('year',     $byear)      if $byear;
      $bibentry->set_datafield('month',    $bmonth)     if $bmonth;
      $bibentry->set_datafield('day',      $bday)       if $bday;
      $bibentry->set_datafield('endmonth', $emonth)     if $emonth;
      $bibentry->set_datafield('endday',   $eday)       if $eday;
      if ($r and $eyear) {      # normal range
        $bibentry->set_datafield('endyear', $eyear);
      }
      elsif ($r and not $eyear) { # open ended range - endyear is defined but empty
        $bibentry->set_datafield('endyear', '');
      }
    }
    else {
      biber_warn("Datamodel: Entry '$key' ($ds): Invalid format '$date' of date field '$f' - ignoring", $bibentry);
    }
    return;
  }
}

# Name fields
sub _name {
  my ($bibentry, $entry, $f, $key) = @_;
  my $names = new Biber::Entry::Names;
  my $useprefix = Biber::Config->getblxoption('useprefix', $bibentry->get_field('entrytype'), $key);
  foreach my $name ($entry->findnodes("./contributors/$f/*")) {
    $names->add_name(parsename($name, $f, {useprefix => $useprefix}));
  }
  $bibentry->set_datafield($f, $names);
  return;
}

sub _xsv {
  my ($bibentry, $entry, $f) = @_;
  # Keywords
  if (my @s = $entry->findnodes("./$f/keyword")) {
    my $kws;
    foreach my $s (@s) {
      push @$kws, '{'._norm($s->textContent()).'}';
    }
    $bibentry->set_datafield($f, $kws);
  }
  return;
}

=head2 parsename

    Given a name node, this function returns a Biber::Entry::Name object

    Returns an object which internally looks a bit like this:

    { firstname     => 'John',
      firstname_i   => 'J',
      middlename    => 'Fred',
      middlename_i  => 'F',
      lastname      => 'Doe',
      lastname_i    => 'D',
      prefix        => undef,
      prefix_i      => undef,
      suffix        => undef,
      suffix_i      => undef,
      namestring    => 'Doe, John Fred',
      nameinitstring => 'Doe_JF',

=cut

sub parsename {
  my ($node, $fieldname, $opts) = @_;
  $logger->debug('Parsing Endnote XML name object ' . $node->nodePath);
  my $usepre = $opts->{useprefix};

  my %namec;

  # Assume that we are using the Endnote name attrs if we find a 'last-name' attr
  # It's not clear if Endnote actually ever uses these even though they are in the
  # DTD
  if ($node->hasAttribute('last-name')) {
    foreach my $n ('last-name', 'first-name', 'suffix', 'corp-name', 'initials', 'middle-initial', 'title', 'salutation') {
      # If there is a name attribute for this component ...
      # This is all guessing as I've never seen Endnote export this
      if ($node->hasAttribute($n)) {
        my $np = $node->getAttribute($n);
        if ($n eq 'last-name') {
          $namec{last} = $np;
          $namec{last_i} = [_gen_initials($np)];
        }
        elsif ($n eq 'first-name') {
          $namec{first} = $np;
          $namec{first_i} = [_gen_initials($np)];
        }
        elsif ($n eq 'suffix') {
          $namec{suffix} = $np;
          $namec{suffix_i} = [_gen_initials($np)];
        }
        elsif ($n eq 'corp-name') {
          $namec{last} = $np;
          $namec{last_i} = [_gen_initials($np)];
        }
        elsif ($n eq 'initials') {
          $namec{first_i} = $np;
        }
        elsif ($n eq 'middle-initial') {
          my $mi = $np;
          $mi =~ s/\s*\.//g;
          $namec{middle} = $np;
          $namec{middle_i} = [ $mi ];
        }
        elsif ($n eq 'title' or $n eq 'salutation') {
          $namec{first} = "$np " . $namec{first};
        }
      }
    }
  # Only warn about lastnames since there should always be one
    biber_warn("Couldn't determine Lastname for name XPath: " . $node->nodePath) unless exists($namec{last});

    my $namestring = '';

    # Don't add suffix to namestring or nameinitstring as these are used for uniquename disambiguation
    # which should only care about lastname + any prefix (if useprefix=true). See biblatex github
    # tracker #306.

    # lastname
    if (my $l = $namec{last}) {
      $namestring .= "$l, ";
    }

    # firstname
    if (my $f = $namec{first}) {
      $namestring .= "$f";
    }

    # Remove any trailing comma and space if, e.g. missing firstname
    $namestring =~ s/,\s+\z//xms;

    # Construct $nameinitstring
    my $nameinitstr = '';
    $nameinitstr .= $namec{last} if exists($namec{last});
    $nameinitstr .= '_' . join('', @{$namec{first_i}}) if exists($namec{first});
    $nameinitstr .= '_' . join('', @{$namec{middle_i}}) if exists($namec{middle});
    $nameinitstr =~ s/\s+/_/g;

    return Biber::Entry::Name->new(
      firstname       => $namec{first} // undef,
      firstname_i     => exists($namec{first}) ? $namec{first_i} : undef,
      middlename      => $namec{middle} // undef,
      middlename_i    => exists($namec{middle}) ? $namec{middle_i} : undef,
      lastname        => $namec{last} // undef,
      lastname_i      => exists($namec{last}) ? $namec{last_i} : undef,
      suffix          => $namec{suffix} // undef,
      suffix_i        => exists($namec{suffix}) ? $namec{suffix_i} : undef,
      namestring      => $namestring,
      nameinitstring  => $nameinitstr,
    );
  }
  else { # parse with bibtex library because Endnote XML is rubbish
    my $namestr = $node->textContent();

    # First sanitise the namestring due to Text::BibTeX::Name limitations on whitespace
    $namestr =~ s/\A\s*//xms;   # leading whitespace
    $namestr =~ s/\s*\z//xms;   # trailing whitespace
    $namestr =~ s/\s+/ /g;      # Collapse internal whitespace

    my $tberr = File::Temp->new(TEMPLATE => 'biber_Text_BibTeX_STDERR_XXXXX',
                                DIR => $Biber::MASTER->biber_tempdir);
    my $tberr_name = $tberr->filename;

    open OLDERR, '>&', \*STDERR;
    open STDERR, '>', $tberr_name;
    my $name = new Text::BibTeX::Name($namestr);
    open STDERR, '>&', \*OLDERR;
    close OLDERR;

    # Put any Text::BibTeX errors into the biber warnings/errors collections
    # We are parsing the libbtparse library error/warning strings a little here
    # This is not so bad as they have a clean structure (see error.c in libbtparse)
    open my $tbe, '<', $tberr_name;
    while (<$tbe>) {
      if (/error:/) {
        chomp;
        biber_error("BibTeX subsystem: $_");
      }
      elsif (/warning:/) {
        chomp;
        biber_warn("BibTeX subsystem: $_");
      }
    }
    close($tbe);

    # Formats so we can get BibTeX compatible nbsp inserted
    my $l_f = new Text::BibTeX::NameFormat('l', 0);
    my $f_f = new Text::BibTeX::NameFormat('f', 0);
    my $p_f = new Text::BibTeX::NameFormat('v', 0);
    my $s_f = new Text::BibTeX::NameFormat('j', 0);
    $l_f->set_options(BTN_LAST,  0, BTJ_MAYTIE, BTJ_NOTHING);
    $f_f->set_options(BTN_FIRST, 0, BTJ_MAYTIE, BTJ_NOTHING);
    $p_f->set_options(BTN_VON,   0, BTJ_MAYTIE, BTJ_NOTHING);
    $s_f->set_options(BTN_JR,    0, BTJ_MAYTIE, BTJ_NOTHING);

    # Generate name parts
    my $lastname  = $name->format($l_f);
    my $firstname = $name->format($f_f);
    my $prefix    = $name->format($p_f);
    my $suffix    = $name->format($s_f);

    # Variables to hold the Text::BibTeX::NameFormat generated initials string
    my $gen_lastname_i;
    my $gen_firstname_i;
    my $gen_prefix_i;
    my $gen_suffix_i;

    # Use a copy of $name so that when we generate the
    # initials, we do so without certain things. This is easier than trying
    # hack robust initials code into btparse ...
    my $nd_namestr = strip_noinit($namestr);
    my $nd_name = new Text::BibTeX::Name($nd_namestr, $fieldname);

    # Initials formats
    my $li_f = new Text::BibTeX::NameFormat('l', 1);
    my $fi_f = new Text::BibTeX::NameFormat('f', 1);
    my $pi_f = new Text::BibTeX::NameFormat('v', 1);
    my $si_f = new Text::BibTeX::NameFormat('j', 1);

    # Initials generated with forced tie so we can make an array
    $li_f->set_text(BTN_LAST,  undef, undef, undef, '');
    $fi_f->set_text(BTN_FIRST, undef, undef, undef, '');
    $pi_f->set_text(BTN_VON,   undef, undef, undef, '');
    $si_f->set_text(BTN_JR,    undef, undef, undef, '');
    $li_f->set_options(BTN_LAST,  1, BTJ_FORCETIE, BTJ_NOTHING);
    $fi_f->set_options(BTN_FIRST, 1, BTJ_FORCETIE, BTJ_NOTHING);
    $pi_f->set_options(BTN_VON,   1, BTJ_FORCETIE, BTJ_NOTHING);
    $si_f->set_options(BTN_JR,    1, BTJ_FORCETIE, BTJ_NOTHING);

    $gen_lastname_i    = inits($nd_name->format($li_f));
    $gen_firstname_i   = inits($nd_name->format($fi_f));
    $gen_prefix_i      = inits($nd_name->format($pi_f));
    $gen_suffix_i      = inits($nd_name->format($si_f));

    my $namestring = '';
    # prefix
    my $ps;
    my $prefix_stripped;
    my $prefix_i;
    if ($prefix) {
      $prefix_i = $gen_prefix_i;
      $namestring .= "$prefix ";
    }
    # lastname
    my $ls;
    my $lastname_stripped;
    my $lastname_i;
    if ($lastname) {
      $lastname_i = $gen_lastname_i;
      $namestring .= "$lastname, ";
    }
    # suffix
    my $ss;
    my $suffix_stripped;
    my $suffix_i;
    if ($suffix) {
      $suffix_i = $gen_suffix_i;
      $namestring .= "$suffix, ";
    }
    # firstname
    my $fs;
    my $firstname_stripped;
    my $firstname_i;
    if ($firstname) {
      $firstname_i = $gen_firstname_i;
      $namestring .= "$firstname";
    }

    # Remove any trailing comma and space if, e.g. missing firstname
    # Replace any nbspes
    $namestring =~ s/,\s+\z//xms;
    $namestring =~ s/~/ /gxms;

    # Construct $nameinitstring
    my $nameinitstr = '';
    $nameinitstr .= join('', @$prefix_i) . '_' if ( $usepre and $prefix );
    $nameinitstr .= $lastname if $lastname;
    $nameinitstr .= '_' . join('', @$suffix_i) if $suffix;
    $nameinitstr .= '_' . join('', @$firstname_i) if $firstname;
    $nameinitstr =~ s/\s+/_/g;
    $nameinitstr =~ s/~/_/g;

    # The "strip" entry tells us which of the name parts had outer braces
    # stripped during processing so we can add them back when printing the
    # .bbl so as to maintain maximum BibTeX compatibility
    return Biber::Entry::Name->new(
      firstname       => $firstname      eq '' ? undef : $firstname,
      firstname_i     => $firstname      eq '' ? undef : $firstname_i,
      lastname        => $lastname       eq '' ? undef : $lastname,
      lastname_i      => $lastname       eq '' ? undef : $lastname_i,
      prefix          => $prefix         eq '' ? undef : $prefix,
      prefix_i        => $prefix         eq '' ? undef : $prefix_i,
      suffix          => $suffix         eq '' ? undef : $suffix,
      suffix_i        => $suffix         eq '' ? undef : $suffix_i,
      namestring      => $namestring,
      nameinitstring  => $nameinitstr
    );
  }
}

# Passed an array ref of strings, returns an array ref of initials
sub _gen_initials {
  my @strings = @_;
  my @strings_out;
  foreach my $str (@strings) {
    # Deal with hyphenated name parts and normalise to a '-' character for easy
    # replacement with macro later
    if ($str =~ m/\p{Dash}/) {
      push @strings_out, join('-', _gen_initials(split(/\p{Dash}/, $str)));
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


# Syntactically get the leaf node of a node path
sub _leaf_node {
  my $node_path = shift;
  return $node_path =~ s|.+/([^/]+$)|$1|r;
}


# Do some sanitising since this can't be nicely done by the parser
sub _norm {
  my $t = shift;
  return undef unless $t;
  $t =~ s/\A[\n\s]+//xms;
  $t =~ s/[\n\s]+\z//xms;
  return $t;
}

sub _get_handler {
  my $field = shift;
  if (my $h = $handlers->{CUSTOM}{$field}) {
    return $h;
  }
  else {
    return $handlers->{$dm->get_fieldtype($field)}{$dm->get_fieldformat($field) || 'default'}{$dm->get_datatype($field)};
  }
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Biber::Input::file::endnotexml - look in a Zotero RDFXML file for an entry and create it if found

=head1 DESCRIPTION

Provides the extract_entries() method to get entries from a biblatexml data source
and instantiate Biber::Entry objects for what it finds

=head1 AUTHOR

François Charette, C<< <firmicus at ankabut.net> >>
Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our Github tracker at
L<https://github.com/plk/biber/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2015 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
