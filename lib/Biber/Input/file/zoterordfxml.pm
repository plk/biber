package Biber::Input::file::zoterordfxml;
#use feature 'unicode_strings';
use strict;
use warnings;
use Carp;

use Biber::Constants;
use Biber::Entries;
use Biber::Entry;
use Biber::Entry::Names;
use Biber::Entry::Name;
use Biber::Sections;
use Biber::Section;
use Biber::Structure;
use Biber::Utils;
use Biber::Config;
use Digest::MD5 qw( md5_hex );
use File::Spec;
use Log::Log4perl qw(:no_extra_logdie_message);
use base 'Exporter';
use List::AllUtils qw(first uniq);
use XML::LibXML;
use XML::LibXML::Simple;
use Data::Dump qw(dump);
use Switch;

##### This is based on Zotero 2.0.9 #####

my $logger = Log::Log4perl::get_logger('main');

my %PREFICES = ('z'       => 'http://www.zotero.org/namespaces/export#',
                'foaf'    => 'http://xmlns.com/foaf/0.1/',
                'rdf'     => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
                'dc'      => 'http://purl.org/dc/elements/1.1/',
                'dcterms' => 'http://purl.org/dc/terms/',
                'bib'     => 'http://purl.org/net/biblio#',
                'prism'   => 'http://prismstandard.org/namespaces/1.2/basic/',
                'vcard'   => 'http://nwalsh.com/rdf/vCard#',
                'vcard2'  => 'http://www.w3.org/2006/vcard/ns#');

# Handlers for field types
my %handlers = (
                'name'        => \&_name,
                'date'        => \&_date,
                'range'       => \&_range,
                'verbatim'    => \&_verbatim,
                'partof'      => \&_partof,
                'publisher'   => \&_publisher,
                'identifier'  => \&_identifier,
                'presentedat' => \&_presentedat,
                'subject'     => \&_subject
);

# Read driver config file
my $dcfxml = driver_config('zoterordfxml');

=head2 extract_entries

   Main data extraction routine.
   Accepts a data source identifier (filename in this case),
   preprocesses the file and then looks for the passed keys,
   creating entries when it finds them and passes out an
   array of keys it didn't find.

=cut

sub extract_entries {
  my ($biber, $filename, $keys) = @_;
  my $secnum = $biber->get_current_section;
  my $section = $biber->sections->get_section($secnum);
  my $bibentries = $section->bibentries;
  my @rkeys = @$keys;
  my $tf; # Up here so that the temp file has enough scope to survive until we've
          # used it
  $logger->trace("Entering extract_entries()");

  # If it's a remote .bib file, fetch it first
  if ($filename =~ m/\A(?:https?|ftp):\/\//xms) {
    $logger->info("Data source '$filename' is a remote .rdf - fetching ...");
    require LWP::Simple;
    require File::Temp;
    $tf = File::Temp->new(SUFFIX => '.rdf');
    unless (LWP::Simple::is_success(LWP::Simple::getstore($filename, $tf->filename))) {
      $logger->logdie ("Could not fetch file '$filename'");
    }
    $filename = $tf->filename;
  }
  else {
    # Need to get the filename even if using cache so we increment
    # the filename count for preambles at the bottom of this sub
    my $trying_filename = $filename;
    unless ($filename = locate_biber_file($filename)) {
      $logger->logdie("Cannot find file '$trying_filename'!")
    }
  }

  # Set up XML parser and namespaces
  my $parser = XML::LibXML->new();
  my $rdfxml = $parser->parse_file($filename)
    or $logger->logcroak("Can't parse file $filename");
  my $xpc = XML::LibXML::XPathContext->new($rdfxml);
  foreach my $ns (keys %PREFICES) {
    $xpc->registerNs($ns, $PREFICES{$ns});
  }

  if ($section->is_allkeys) {
    $logger->debug("All citekeys will be used for section '$secnum'");
    # Loop over all entries, creating objects
    foreach my $entry ($xpc->findnodes("/rdf:RDF/*")) {
      $logger->debug('Parsing Zotero RDF/XML entry object ' . $entry->nodePath);
      # We have to pass the datasource cased key to
      # create_entry() as this sub needs to know the original case of the
      # citation key so we can do case-insensitive key/entry comparisons
      # later but we need to put the original citation case when we write
      # the .bbl. If we lowercase before this, we lose this information.
      # Of course, with allkeys, "citation case" means "datasource entry case"

      # If an entry has no key, ignore it and warn
      my $key;
      if (my $k = $entry->findvalue('./z:itemID')) {
        $key = $k;
      }
      else {
        unless ($entry->hasAttribute('rdf:about')) {
          $logger->warn("Invalid or undefined RDF/XML ID in file '$filename', skipping ...");
          $biber->{warnings}++;
          next;
        }
        $key = $entry->getAttribute('rdf:about');
      }

      # sanitise the key for LaTeX
      $key =~ s/\A\#//xms;
      create_entry($biber, $key, $entry);
    }

    # if allkeys, push all bibdata keys into citekeys (if they are not already there)
    $section->add_citekeys($section->bibentries->sorted_keys);
    $logger->debug("Added all citekeys to section '$secnum': " . join(', ', $section->get_citekeys));
  }
  else {
    # loop over all keys we're looking for and create objects
    $logger->debug('Wanted keys: ' . join(', ', @$keys));
    foreach my $wanted_key (@$keys) {
      $logger->debug("Looking for key '$wanted_key' in Zotero RDF/XML file '$filename'");
      # Cache index keys are lower-cased. This next line effectively implements
      # case insensitive citekeys
      # This will also get the first match it finds
      if (my @entries = $xpc->findnodes("/rdf:RDF/*/z:itemID[text()='" . lc($wanted_key) ."']|/rdf:RDF/*[\@rdf:about='" . lc($wanted_key) . "']")) {
        my $entry;
        # Check to see if there is more than one entry with this key and warn if so
        if ($#entries > 0) {
          $logger->warn("Found more than one entry for key '$wanted_key' in '$filename': " .
                       join(',', map {$_->getAttribute('rdf:about')} @entries) . ' - using the first one!');
          $biber->{warnings}++;
        }
        $entry = $entries[0];

        $logger->debug("Found key '$wanted_key' in Zotero RDF/XML file '$filename'");
        $logger->debug('Parsing Zotero RDF/XML entry object ' . $entry->nodePath);
        # See comment above about the importance of the case of the key
        # passed to create_entry()
        create_entry($biber, $wanted_key, $entry);
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
  my ($biber, $dskey, $entry) = @_;
  my $secnum = $biber->get_current_section;
  my $section = $biber->sections->get_section($secnum);
  my $struc = Biber::Config->get_structure;
  my $bibentries = $section->bibentries;

  # Want a version of the key that is the same case as any citations which
  # reference it, in case they are different. We use this as the .bbl
  # entry key
  # In case of allkeys, this will just be the datasource key as ->get_citekeys
  # returns an empty list
  my $citekey = first {lc($dskey) eq lc($_)} $section->get_citekeys;
  $citekey = $dskey unless $citekey;
  my $lc_key = lc($dskey);

  my $bibentry = new Biber::Entry;
  # We record the original keys of both the datasource and citation. They may differ in case.
  $bibentry->set_field('dskey', $dskey);
  $bibentry->set_field('citekey', $citekey);

  # Some entries like Series which are created for crossrefs don't have z:itemType
  my $itype = $entry->findvalue('./z:itemType') || $entry->nodeName;

  # Set entrytype taking note of any aliases for this datasource driver
  if (my $ealias = $dcfxml->{'entry-types'}{'entry-type'}{$itype}) {
    $bibentry->set_field('entrytype', $ealias->{aliasof}{content});
    if (my $alsoset = $ealias->{alsoset}) {
      unless ($bibentry->field_exists($alsoset->{target})) {
        $bibentry->set_field($alsoset->{target}, $alsoset->{value});
      }
    }
  }
  else {
    $bibentry->set_field('entrytype', $itype);
  }

  # We put all the fields we find modulo field aliases into the object.
  # Validation happens later and is not datasource dependent
  foreach my $f (uniq map {$_->nodeName()} $entry->findnodes('*')) {

    if (my $fm = $dcfxml->{fields}{field}{$f}) { # ignore fields not in .dcf
      my $to = $f; # By default, field to set internally is the same as data source
      # Redirect any alias
      if (my $alias = $fm->{aliasof}) {
        $logger->debug("Found alias '$alias' of field '$f' in entry '$dskey'");
        $fm = $dcfxml->{fields}{field}{$alias};
        $to = $alias; # Field to set internally is the alias
      }
      &{$handlers{$fm->{handler}}}($biber, $bibentry, $entry, $f, $to, $dskey);
    }
  }

  $bibentry->set_field('datatype', 'zoterordfxml');
  $bibentries->add_entry($lc_key, $bibentry);

  return $bibentry; # We need to return the entry here for _partof() below
}

# Verbatim fields
sub _verbatim {
  my ($biber, $bibentry, $entry, $f, $to, $dskey) = @_;
  # Special case - libraryCatalog is used only if hasn't already been set
  # by LCC
  if ($f eq 'z:libraryCatalog') {
    return if $bibentry->get_field('library');
  }
  $bibentry->set_datafield($to, _norm($entry->findvalue("./$f")));
  return;
}

# Range fields
sub _range {
  my ($biber, $bibentry, $entry, $f, $to, $dskey) = @_;
  my $values_ref;
  my @values = split(/\s*,\s*/, $entry->findvalue("./$f"));
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
  $bibentry->set_datafield($to, $values_ref);
  return;
}

# Date fields
sub _date {
  my ($biber, $bibentry, $entry, $f, $to, $dskey) = @_;
  # We are not validating dates here, just syntax parsing
  my $date_re = qr/(\d{4}) # year
                   (?:-(\d{2}))? # month
                   (?:-(\d{2}))? # day
                  /xms;
  my $d = $entry->findvalue("./$f");
  if (my ($byear, $bmonth, $bday) =
      $d =~ m|\A$date_re\z|xms) {
    $bibentry->set_datafield('year', $byear)      if $byear;
    $bibentry->set_datafield('month', $bmonth)    if $bmonth;
    $bibentry->set_datafield('day', $bday)        if $bday;
  }
  else {
    $biber->biber_warn($bibentry, "Invalid format '$d' of date field '$f' in entry '$dskey' - ignoring");
  }
  return;
}

# Name fields
sub _name {
  my ($biber, $bibentry, $entry, $f, $to, $dskey) = @_;
  my $names = new Biber::Entry::Names;
  foreach my $name ($entry->findnodes("./$f/rdf:Seq/rdf:li/foaf:Person")) {
    $names->add_element(parsename($name, $f));
  }
  $bibentry->set_datafield($to, $names);
  return;
}

# partof container
# This essentially is a bit like biblatex inheritance, but not as fine-grained
sub _partof {
  my ($biber, $bibentry, $entry, $f, $to, $dskey) = @_;
  my $partof = $entry->findnodes("./$f")->get_node(1);
  if ($partof->hasAttribute('rdf:resource')) { # remote ISSN resources aren't much use
    return;
  }
  # create a dataonly entry for the partOf and add a crossref to it
  my $crkey = $dskey . '_' . md5_hex($dskey);
  my $cref = create_entry($biber, $crkey, $partof->findnodes('*')->get_node(1));
  $cref->set_datafield('options', 'dataonly');
  Biber::Config->setblxoption('skiplab', 1, 'PER_ENTRY', $crkey);
  Biber::Config->setblxoption('skiplos', 1, 'PER_ENTRY', $crkey);
  $bibentry->set_datafield('crossref', $crkey);
  # crossrefs are a pain as we have to try to guess the
  # crossref type a bit. This corresponds to the relevant parts of the
  # default inheritance setup
  if ($cref->get_field('entrytype') =~ /\Abib:/) {
    my $ptype = $bibentry->get_field('entrytype');
    switch ($ptype) {
      case 'book'              { $cref->set_datafield('entrytype', 'mvbook') }
      case 'inbook'            { $cref->set_datafield('entrytype', 'book') }
      case 'inproceedings'     { $cref->set_datafield('entrytype', 'proceedings') }
      case 'article'           { $cref->set_datafield('entrytype', 'periodical') }
    }
  }
  return;
}

sub _publisher {
  my ($biber, $bibentry, $entry, $f, $to, $dskey) = @_;
  if (my $org = $entry->findnodes("./$f/foaf:Organization")->get_node(1)) {
    # There is an address, set location
    if (my $adr = $org->findnodes('./vcard:adr')->get_node(1)) {
      $bibentry->set_datafield('location', _norm($adr->findnodes('./vcard:Address/vcard:locality/text()')));
    }
    # set publisher
    if (my $adr = $org->findnodes('./foaf:name')->get_node(1)) {
      $bibentry->set_datafield('publisher', _norm($adr->textContent()));
    }
  }
  return;
}

sub _presentedat {
  my ($biber, $bibentry, $entry, $f, $to, $dskey) = @_;
  if (my $conf = $entry->findnodes("./$f/bib:Conference")->get_node(1)) {
    $bibentry->set_datafield('eventtitle', _norm($conf->findnodes('./dc:title/text()')));
  }
  return;
}

sub _subject {
  my ($biber, $bibentry, $entry, $f, $to, $dskey) = @_;
  if (my $lib = $entry->findnodes("./$f/dcterms:LCC/rdf:value")->get_node(1)) {
    # This overrides any z:libraryCatalog node
    $bibentry->set_datafield('library', _norm($lib->textContent()));
  }
  # otherwise, we ignore the subject tags as they are no use to biblatex
  return;
}

sub _identifier {
  my ($biber, $bibentry, $entry, $f, $to, $dskey) = @_;
  if (my $url = $entry->findnodes("./$f/dcterms:URI/rdf:value")->get_node(1)) {
    $bibentry->set_datafield('url', $url->textContent());
  }
  else {
    foreach my $id_node ($entry->findnodes("./$f")) {
      if ($id_node->textContent() =~ m/\A(ISSN|ISBN|DOI)\s(.+)\z/) {
        $bibentry->set_datafield(lc($1), $2);
      }
    }
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
  $logger->warn("Couldn't determine Lastname for name node: " . $node->nodePath) unless exists($namec{last});

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
      my $chr = substr($str, 0, 1);
      # Keep diacritics with their following characters
      if ($chr =~ m/\p{Dia}/) {
        push @strings_out, substr($str, 0, 2);
      }
      else {
        push @strings_out, $chr;
      }
    }
  }
  return @strings_out;
}

# Do some sanitising on LaTeX special chars since this can't be nicely done by the parser
sub _norm {
  my $s = shift;
  $s =~ s/(?<!\\)\&/\\&/gxms;
  return $s;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Biber::Input::file::zoterordfxml - look in a Zotero RDFXML file for an entry and create it if found

=head1 DESCRIPTION

Provides the extract_entries() method to get entries from a biblatexml data source
and instantiate Biber::Entry objects for what it finds

=head1 AUTHOR

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

# vim: set tabstop=2 shiftwidth=2 expandtab:
