package Biber::Input::file::zoterordfxml;
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
use Unicode::Normalize;
use Unicode::GCString;
use URI;

##### This is based on Zotero 2.0.9 #####

my $logger = Log::Log4perl::get_logger('main');
my $orig_key_order = {};

# Determine handlers from data model
my $dm = Biber::Config->get_dm;
my $handlers = {
                'CUSTOM' => {'BIBERCUSTOMpartof'      => \&_partof,
                             'BIBERCUSTOMidentifier'  => \&_identifier,
                             'BIBERCUSTOMpublisher'   => \&_publisher,
                             'BIBERCUSTOMpresentedat' => \&_presentedat,
                             'BIBERCUSTOMsubject'     => \&_subject,
                            },
                'field' => {
                            'default' => {
                                          'code'     => \&_literal,
                                          'date'     => \&_date,
                                          'entrykey' => \&_literal,
                                          'integer'  => \&_literal,
                                          'key'      => \&_literal,
                                          'literal'  => \&_literal,
                                          'range'    => \&_range,
                                          'verbatim' => \&_literal,
                                          'uri'      => \&_uri
                                         },
                            'csv'     => {
                                          'entrykey' => \&_csv,
                                          'keyword'  => \&_csv,
                                          'option'   => \&_csv,
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

my %PREFICES = ('z'       => 'http://www.zotero.org/namespaces/export#',
                'foaf'    => 'http://xmlns.com/foaf/0.1/',
                'rdf'     => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
                'dc'      => 'http://purl.org/dc/elements/1.1/',
                'dcterms' => 'http://purl.org/dc/terms/',
                'bib'     => 'http://purl.org/net/biblio#',
                'prism'   => 'http://prismstandard.org/namespaces/1.2/basic/',
                'vcard'   => 'http://nwalsh.com/rdf/vCard#',
                'vcard2'  => 'http://www.w3.org/2006/vcard/ns#');

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
  $logger->trace("Entering extract_entries()");

  # Get a reference to the correct sourcemap sections, if they exist
  my $smaps = [];
  # Maps are applied in order USER->STYLE->DRIVER
  if (defined(Biber::Config->getoption('sourcemap'))) {
    # User maps
    if (my $m = first {$_->{datatype} eq 'zoterordfxml' and $_->{level} eq 'user' } @{Biber::Config->getoption('sourcemap')} ) {
      push @$smaps, $m;
    }
    # Style maps
    if (my $m = first {$_->{datatype} eq 'zoterordfxml' and $_->{level} eq 'style' } @{Biber::Config->getoption('sourcemap')} ) {
      push @$smaps, $m;
    }
    # Driver default maps
    if (my $m = first {$_->{datatype} eq 'zoterordfxml' and $_->{level} eq 'driver' } @{Biber::Config->getoption('sourcemap')} ) {
      push @$smaps, $m;
    }
  }

  # If it's a remote data file, fetch it first
  if ($source =~ m/\A(?:http|ftp)(s?):\/\//xms) {
    $logger->info("Data source '$source' is a remote Zotero RDF/XML data source - fetching ...");
    if ($1) { # HTTPS
      # use IO::Socket::SSL qw(debug4); # useful for debugging SSL issues
      # We have to explicitly set the cert path because otherwise the https module
      # can't find the .pem when PAR::Packer'ed
      if (not exists($ENV{PERL_LWP_SSL_CA_FILE}) and
          not defined(Biber::Config->getoption('ssl-nointernalca'))) {
        require Mozilla::CA; # Have to explicitly require this here to get it into %INC below
        # we assume that the default CA file is in .../Mozilla/CA/cacert.pem
        (my $vol, my $dir, undef) = File::Spec->splitpath( $INC{"Mozilla/CA.pm"} );
        $dir =~ s/\/$//; # splitpath sometimes leaves a trailing '/'
        $ENV{PERL_LWP_SSL_CA_FILE} = File::Spec->catpath($vol, "$dir/CA", 'cacert.pem');
      }
      if (defined(Biber::Config->getoption('ssl-noverify-host'))) {
          $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
      }
      require LWP::Protocol::https;
    }
    require LWP::Simple;

    $tf = File::Temp->new(TEMPLATE => 'biber_remote_data_source_XXXXX',
                          DIR => $Biber::MASTER->biber_tempdir,
                          SUFFIX => '.rdf');
    unless (LWP::Simple::is_success(LWP::Simple::getstore($source, $tf->filename))) {
      biber_error("Could not fetch '$source'");
    }
    $filename = $tf->filename;
  }
  else {
    # Need to get the filename even if using cache so we increment
    # the filename count for preambles at the bottom of this sub
    unless ($filename = locate_biber_file($source)) {
      biber_error("Cannot find '$source'!")
    }
  }

  # Log that we found a data file
  $logger->info("Found zoterordfxml data source '$filename'");

  # Set up XML parser and namespaces
  my $parser = XML::LibXML->new();
  my $xml = File::Slurp::read_file($filename) or biber_error("Can't read file $filename");
  $xml = NFD(decode('UTF-8', $xml));# Unicode NFD boundary
  my $rdfxml = $parser->parse_string($xml);
  my $xpc = XML::LibXML::XPathContext->new($rdfxml);
  foreach my $ns (keys %PREFICES) {
    $xpc->registerNs($ns, $PREFICES{$ns});
  }

  if ($section->is_allkeys) {
    $logger->debug("All citekeys will be used for section '$secnum'");
    # Loop over all entries, creating objects
    foreach my $entry ($xpc->findnodes("/rdf:RDF/*")) {
      $logger->debug('Parsing Zotero RDF/XML entry object ' . $entry->nodePath);

      # If an entry has no key, ignore it and warn
      unless ($entry->hasAttribute('rdf:about')) {
        biber_warn("Invalid or undefined RDF/XML ID in file '$filename', skipping ...");
        next;
      }

      my $ek = $entry->getAttribute('rdf:about');

      # sanitise the key for LaTeX
      $ek =~ s/\A\#item_/item_/xms;

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

      # We do this as otherwise we have no way of determining the origing .bib entry order
      # We need this in order to do sorting=none + allkeys because in this case, there is no
      # "citeorder" because nothing is explicitly cited and so "citeorder" means .bib order
      push @{$orig_key_order->{$filename}}, $ek;

      # Record a key->datasource name mapping for error reporting
      $section->set_keytods($ek, $filename);

      create_entry($ek, $entry, $source, $smaps);
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
      $logger->debug("Looking for key '$wanted_key' in Zotero RDF/XML file '$filename'");

      # Deal with messy Zotero auto-generated pseudo-keys
      my $temp_key = $wanted_key;
      $temp_key =~ s/\Aitem_/#item_/i;
      if (my @entries = $xpc->findnodes("/rdf:RDF/*[\@rdf:about='$temp_key']")) {
        # Check to see if there is more than one entry with this key and warn if so
        if ($#entries > 0) {
          biber_warn("Found more than one entry for key '$wanted_key' in '$filename': " .
                       join(',', map {$_->getAttribute('rdf:about')} @entries) . ' - skipping duplicates ...');
        }
        my $entry = $entries[0];

        my $key = $entry->getAttribute('rdf:about');
        $key =~ s/\A#item_/item_/i; # reverse of above

        $logger->debug("Found key '$wanted_key' in Zotero RDF/XML file '$filename'");
        $logger->debug('Parsing Zotero RDF/XML entry object ' . $entry->nodePath);
        # See comment above about the importance of the case of the key
        # passed to create_entry()

        # Record a key->datasource name mapping for error reporting
        $section->set_keytods($wanted_key, $filename);

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

   Create a Biber::Entry object from an entry found in a Zotero
   RDF/XML data source

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

      my $itype = $entry->findvalue('./z:itemType') || $entry->nodeName;
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
          $entry->findnodes('./z:itemType/text()')->get_node(1)->setData($step->{map_type_target});
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
              $entry->findnodes($source . '/text()')->get_node(1)->setData($text);
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
              $logger->debug("Source mapping (type=$level, key=$key): Setting field '$field' to '${orig}${last_fieldval}'");
              next unless $last_fieldval;
              $entry->appendTextChild($field, $orig . $last_fieldval);
            }
            elsif ($step->{map_origfield}) {
              $logger->debug("Source mapping (type=$level, key=$key): Setting field '$field' to '${orig}${last_field}'");
              next unless $last_field;
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

  foreach my $f (uniq map {$_->nodeName()} $entry->findnodes('*')) {
    # Now run any defined handler
    # There is no else clause here to warn on invalid fields as there are so many
    # in zoterordfxml
    if ($dm->is_field(_strip_ns($f))) {
      my $handler = _get_handler($f);
      &$handler($bibentry, $entry, $f, $key, $smaps);
    }
  }

  my $itype = $entry->findvalue('./z:itemType') || _strip_ns($entry->nodeName);
  $bibentry->set_field('entrytype', $itype);
  $bibentry->set_field('datatype', 'zoterordfxml');
  $bibentries->add_entry($key, $bibentry);

  return $bibentry; # We need to return the entry here for partof handling below
}

# HANDLERS
# ========

# Handler for partof
sub _partof {
  my ($bibentry, $entry, $f, $key, $smaps) = @_;
  my $partof = $entry->findnodes($f)->get_node(1);
  my $itype = $entry->findvalue('./z:itemType') || $entry->nodeName;
  if ($partof->hasAttribute('rdf:resource')) { # remote ISSN resources aren't much use
    return;
  }
  # For 'webpage' types ('online' biblatex type), Zotero puts in a pointless
  # empty partof z:Website container
  if ($itype eq 'webpage') {
    return;
  }

  # create a dataonly entry for the partOf and add a crossref to it
  my $crkey = $key . '_' . md5_hex($key);
  $logger->debug("Creating a dataonly crossref '$crkey' for key '$key'");
  my $cref = create_entry($crkey, $partof->findnodes('*')->get_node(1), $smaps);
  $cref->set_datafield('options', 'dataonly');
  Biber::Config->setblxoption('skiplab', 1, 'PER_ENTRY', $crkey);
  Biber::Config->setblxoption('skiplos', 1, 'PER_ENTRY', $crkey);
  $bibentry->set_datafield('crossref', $crkey);
  return;
}

# identifier
sub _identifier {
  my ($bibentry, $entry, $f) = @_;
  if (my $url = $entry->findnodes("./$f/dcterms:URI/rdf:value")->get_node(1)) {
    $bibentry->set_datafield('url', $url->textContent());
  }
  else {
    foreach my $id_node ($entry->findnodes($f)) {
      if ($id_node->textContent() =~ m/\A(ISSN|ISBN|DOI)\s(.+)\z/) {
        $bibentry->set_datafield(lc($1), $2);
      }
    }
  }
  return;
}

# Publisher
sub _publisher {
  my ($bibentry, $entry, $f) = @_;
  if (my $org = $entry->findnodes("./$f/foaf:Organization")->get_node(1)) {
    # There is an address, set location.
    # Location is a list field in bibaltex, hence the array ref
    if (my $adr = $org->findnodes('./vcard:adr')->get_node(1)) {
      $bibentry->set_datafield('location', [ $adr->findvalue('./vcard:Address/vcard:locality') ]);
    }
    # set publisher
    # publisher is a list field in bibaltex, hence the array ref
    if (my $adr = $org->findnodes('./foaf:name')->get_node(1)) {
      $bibentry->set_datafield('publisher', [ $adr->textContent() ]);
    }
  }
  return;
}

# presentedAt
sub _presentedat {
  my ($bibentry, $entry, $f) = @_;
  if (my $conf = $entry->findnodes("./$f/bib:Conference")->get_node(1)) {
    $bibentry->set_datafield('eventtitle', $conf->findvalue('./dc:title'));
  }
  return;
}

# subject
sub _subject {
  my ($bibentry, $entry, $f) = @_;
  if (my $lib = $entry->findnodes("./$f/dcterms:LCC/rdf:value")->get_node(1)) {
    # This overrides any z:libraryCatalog node
    $bibentry->set_datafield('library', $lib->textContent());
  }
  elsif (my @s = $entry->findnodes("./$f")) {
    my @kws;
    foreach my $s (@s) {
      push @kws, '{'.$s->textContent().'}';
    }
    $bibentry->set_datafield('keywords', join(',', @kws));
  }
  return;
}


# List fields
sub _list {
  my ($bibentry, $entry, $f) = @_;
  my $value = $entry->findvalue($f);
  $bibentry->set_datafield($f, [ $value ]);
  return;
}

# Literal fields
sub _literal {
  my ($bibentry, $entry, $f, $key) = @_;

  # Special case - libraryCatalog is used only if hasn't already been set
  # by LCC
  if (_strip_ns($f) eq 'library') {
    return if $bibentry->get_field('library');
  }

  my $value = $entry->findvalue($f);
  $bibentry->set_datafield(_strip_ns($f), $value);
  return;
}

# URI fields
sub _uri {
  my ($bibentry, $entry, $f, $key) = @_;
  my $value = $entry->findvalue($f);

  # URL escape if it doesn't look like it already is
  # This is useful if we are generating URLs automatically with maps which may
  # contain UTF-8 from other fields
  unless ($value =~ /\%/) {
   $value = URI->new($value)->as_string;
  }

  $bibentry->set_datafield(_strip_ns($f), $value);
  return;
}


# Range fields
sub _range {
  my ($bibentry, $entry, $f) = @_;
  my $values_ref;
  my $value = $entry->findvalue($f);
  my @values = split(/\s*,\s*/, $value);
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
  $bibentry->set_datafield(_strip_ns($f), $values_ref);
  return;
}

# Date fields
sub _date {
  my ($bibentry, $entry, $f, $key) = @_;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $ds = $section->get_keytods($key);

  my $date = $entry->findvalue($f);
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
    if ($r and $eyear) {        # normal range
      $bibentry->set_datafield('endyear', $eyear);
    }
    elsif ($r and not $eyear) { # open ended range - endyear is defined but empty
      $bibentry->set_datafield('endyear', '');
    }
  }
  else {
    biber_warn("Datamodel: Entry '$key' ($ds): Invalid format '$date' of date field '$f' in entry '$key' - ignoring", $bibentry);
  }
  return;
}

# Name fields
sub _name {
  my ($bibentry, $entry, $f) = @_;
  my $names = new Biber::Entry::Names;
  foreach my $name ($entry->findnodes("./$f/rdf:Seq/rdf:li/foaf:Person")) {
    $names->add_name(parsename($name, $f));
  }
  $bibentry->set_datafield(_strip_ns($f), $names);
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
  my ($node, $fieldname) = @_;
  $logger->debug('Parsing Zotero RDF/XML name object ' . $node->nodePath);

  my %nmap = ('surname'   => 'last',
              'givenname' => 'first');

  my %namec;

  foreach my $n ('surname', 'givenname') {
    if (my $nc = $node->findvalue("./foaf:$n")) {
      my $bn = $nmap{$n}; # convert to biblatex namepart name
      $namec{$bn} = $nc;
      $logger->debug("Found name component '$bn': $nc");
      $namec{"${bn}_i"} = [_gen_initials($nc)];
    }
  }

  # Only warn about lastnames since there should always be one
  biber_warn("Couldn't determine Lastname for name XPath: " . $node->nodePath) unless exists($namec{last});

  my $namestring = '';

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
  $nameinitstr =~ s/\s+/_/g;

  return Biber::Entry::Name->new(
    firstname       => $namec{first} // undef,
    firstname_i     => exists($namec{first}) ? $namec{first_i} : undef,
    lastname        => $namec{last} // undef,
    lastname_i      => exists($namec{last}) ? $namec{last_i} : undef,
    namestring      => $namestring,
    nameinitstring  => $nameinitstr
    );
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
  return $node_path =~ s|\X+/([^/]+$)|$1|r;
}

# Strip interim bltx namespace
sub _strip_ns {
  my $node = shift;
  return $node =~ s|^[^:]+:||r;
}


sub _get_handler {
  my $field = shift;
  if (my $h = $handlers->{CUSTOM}{_strip_ns($field)}) {
    return $h;
  }
  else {
    return $handlers->{$dm->get_fieldtype(_strip_ns($field))}{$dm->get_fieldformat(_strip_ns($field)) || 'default'}{$dm->get_datatype(_strip_ns($field))};
  }
}


1;

__END__

=pod

=encoding utf-8

=head1 NAME

Biber::Input::file::zoterordfxml - look in a Zotero RDF/XML file for an entry and create it if found

=head1 DESCRIPTION

Provides the extract_entries() method to get entries from a Zotero RDF/XML data source
and instantiate Biber::Entry objects for what it finds

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
