package Biber::Input::file::ris;
use v5.16;
use strict;
use warnings;
use base 'Exporter';

use Carp;
use Biber::Constants;
use Biber::DataModel;
use Biber::Entries;
use Biber::Entry;
use Biber::Entry::Names;
use Biber::Entry::Name;
use Biber::Sections;
use Biber::Section;
use Biber::Utils;
use Biber::Config;
use Encode;
use File::Spec;
use File::Temp;
use Log::Log4perl qw(:no_extra_logdie_message);
use List::AllUtils qw( :all );
use XML::LibXML::Simple;
use Readonly;
use Data::Dump qw(dump);
use Unicode::Normalize;
use Unicode::GCString;
use URI;

my $logger = Log::Log4perl::get_logger('main');
my $orig_key_order = {};

# Determine handlers from data model
my $dm = Biber::Config->get_dm;
my $handlers = {
                'field' => {
                            'default' => {
                                          'csv'      => \&_verbatim,
                                          'code'     => \&_literal,
                                          'date'     => \&_date,
                                          'datepart' => \&_verbatim,
                                          'entrykey' => \&_verbatim,
                                          'integer'  => \&_verbatim,
                                          'key'      => \&_verbatim,
                                          'literal'  => \&_verbatim,
                                          'range'    => \&_range,
                                          'verbatim' => \&_verbatim,
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
                                         'entrykey' => \&_list,
                                         'key'      => \&_list,
                                         'literal'  => \&_list,
                                         'name'     => \&_name,
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
  my $tf;

  $logger->trace("Entering extract_entries() in driver 'ris'");

  # Get a reference to the correct sourcemap sections, if they exist
  my $smaps = [];
  # Maps are applied in order USER->STYLE->DRIVER
  if (defined(Biber::Config->getoption('sourcemap'))) {
    # User maps
    if (my $m = first {$_->{datatype} eq 'ris' and $_->{level} eq 'user' } @{Biber::Config->getoption('sourcemap')} ) {
      push @$smaps, $m;
    }
    # Style maps
    if (my $m = first {$_->{datatype} eq 'ris' and $_->{level} eq 'style' } @{Biber::Config->getoption('sourcemap')} ) {
      push @$smaps, $m;
    }
    # Driver default maps
    if (my $m = first {$_->{datatype} eq 'ris' and $_->{level} eq 'driver' } @{Biber::Config->getoption('sourcemap')} ) {
      push @$smaps, $m;
    }
  }

  # If it's a remote data file, fetch it first
  if ($source =~ m/\A(?:http|ftp)(s?):\/\//xms) {
    $logger->info("Data source '$source' is a remote RIS data source - fetching ...");
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
                          SUFFIX => '.ris');
    unless (LWP::Simple::is_success(LWP::Simple::getstore($source, $tf->filename))) {
      biber_error("Could not fetch '$source'");
    }
    $filename = $tf->filename;
  }
  else {
    unless ($filename = locate_biber_file($source)) {
      biber_error("Cannot find '$source'!")
    }
  }

  # Log that we found a data file
  $logger->info("Found RIS data source '$filename'");

  # pre-process into something a little more sensible, dealing with the multi-line
  # fields in RIS
  require IO::File;
  my $ris = new IO::File;
  $ris->open("< $filename");
  my $e;
  my @ris_entries;
  my $last_tag;
  while(<$ris>) {
    if (Biber::Config->getoption('input_encoding') eq 'UTF-8') {
      $_ = NFD($_);# Unicode NFD boundary
    }
    if (m/\A([A-Z][A-Z0-9])\s\s\-\s*(.+)?\n\z/xms) {
      $last_tag = $1;
      if ($1 eq 'TY')     { $e = {'TY' => $2} }
      elsif ($1 eq 'KW')  { push @{$e->{KW}}, $2 } # amalgamate keywords
      elsif ($1 eq 'SP')  { $e->{SPEP}{SP} = $2 }  # amalgamate page range
      elsif ($1 eq 'EP')  { $e->{SPEP}{EP} = $2 }  # amalgamate page range
      elsif ($1 eq 'A1')  { push @{$e->{A1}}, $2 } # amalgamate names
      elsif ($1 eq 'A2')  { push @{$e->{A2}}, $2 } # amalgamate names
      elsif ($1 eq 'A3')  { push @{$e->{A3}}, $2 } # amalgamate names
      elsif ($1 eq 'AU')  { push @{$e->{AU}}, $2 } # amalgamate names
      elsif ($1 eq 'ED')  { push @{$e->{ED}}, $2 } # amalgamate names
      elsif ($1 eq 'ER')  { if (exists($e->{KW})) {$e->{KW} = join(',', @{$e->{KW}})}
                                   push @ris_entries, $e }
      else                { $e->{$1} = $2 }
    }
    elsif (m/\A(.+)\n\z/xms) { # Deal with stupid line continuations
      $e->{$last_tag} .= " $1";
    }
  }
  $ris->close;
  undef $ris;

  if ($section->is_allkeys) {
    $logger->debug("All citekeys will be used for section '$secnum'");
    # Loop over all entries, creating objects
    foreach my $entry (@ris_entries) {
      $logger->debug('Parsing RIS entry object ' . $entry->{ID});

      # If an entry has no key, ignore it and warn
      unless ($entry->{ID}) {
        biber_warn("RIS entry has no ID key in file '$filename', skipping ...");
        next;
      }

      my $ek = $entry->{ID};
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
      $logger->debug("Looking for key '$wanted_key' in RIS file '$filename'");
      if (my @entries = grep { $wanted_key eq $_->{ID} } @ris_entries) {
        if ($#entries > 0) {
          biber_warn("Found more than one entry for key '$wanted_key' in '$filename': " .
                       join(',', map {$_->{ID}} @entries) . ' - skipping duplicates ...');
        }
        my $entry = $entries[0];

        $logger->debug("Found key '$wanted_key' in RIS file '$filename'");
        $logger->debug('Parsing RIS entry object ' . $entry->{ID});

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

   Create a Biber::Entry object from an entry found in a RIS data source

=cut

sub create_entry {
  my ($key, $entry, $source, $smaps) = @_;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $dm = Biber::Config->get_dm;
  my $bibentries = $section->bibentries;
  my $bibentry = new Biber::Entry;

  $bibentry->set_field('citekey', $key);

  # Datasource mapping applied in $smap order (USER->STYLE->DRIVER)
  foreach my $smap (@$smaps) {
    my $level = $smap->{level};

  MAP:    foreach my $map (@{$smap->{map}}) {
      my $last_type = $entry->{TY}; # defaults to the entrytype unless changed below
      my $last_field = undef;
      my $last_fieldval = undef;

      my @imatches; # For persising parenthetical matches over several steps

      # Check pertype restrictions
      unless (not exists($map->{per_type}) or
              first {$_->{content} eq $entry->{TY}} @{$map->{per_type}}) {
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
          unless ($entry->{TY} eq $source) {
            # Skip the rest of the map if this step doesn't match and match is final
            if ($step->{map_final}) {
              $logger->debug("Source mapping (type=$level, key=$key): Entry type is '" . $entry->{TY} . "' but map wants '$source' and step has 'final' set ... skipping rest of map ...");
              next MAP;
            }
            else {
              # just ignore this step
              $logger->debug("Source mapping (type=$level, key=$key): Entry type is '" . $entry->{TY} . "' but map wants '$source' ... skipping step ...");
              next;
            }
          }
          # Change entrytype if requested
          $last_type = $entry->{TY};
          $logger->debug("Source mapping (type=$level, key=$key): Changing entry type from '$last_type' to " . $step->{map_type_target});
          $entry->{TY} = $step->{map_type_target};
        }

        # Field map
        if (my $source = $step->{map_field_source}) {
           # key is a psudo-field. It's guaranteed to exist so
           # just check if that's what's being asked for
           unless (lc($source) eq 'entrykey' or
                   exists($entry->{$source})) {
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
          $last_fieldval = lc($source) eq 'entrykey' ? $entry->{ID} : $entry->{$source};


          # map fields to targets
          if (my $m = $step->{map_match}) {
            if (defined($step->{map_replace})) { # replace can be null

              # Can't modify entrykey
              if (lc($source) eq 'entrykey') {
                $logger->debug("Source mapping (type=$level, key=$key): Field '$source' is 'entrykey'- cannot remap the value of this field, skipping ...");
                next;
              }

              my $r = $step->{map_replace};
              $logger->debug("Source mapping (type=$level, key=$key): Doing match/replace '$m' -> '$r' on field '$source'");
              $entry->{$source} = ireplace($last_fieldval, $m, $r);
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

            # Can't remap entry key pseudo-field
            if (lc($source) eq 'entrykey') {
              $logger->debug("Source mapping (type=$level, key=$key): Field '$source' is 'entrykey'- cannot map this to a new field as you must have an entrykey, skipping ...");
              next;
            }

            if (exists($entry->{$target})) {
              if ($map->{map_overwrite} // $smap->{map_overwrite}) {
                $logger->debug("Source mapping (type=$level, key=$key): Overwriting existing field '$target'");
              }
              else {
                $logger->debug("Source mapping (type=$level, key=$key): Field '$source' is aliased to field '$target' but both are defined, skipping ...");
                next;
              }
            }
            $entry->{$target} = $entry->{$source};
            delete($entry->{$source});
          }
        }

        # field creation
        if (my $field = $step->{map_field_set}) {

          # Deal with special tokens
          if ($step->{map_null}) {
            $logger->debug("Source mapping (type=$level, key=$key): Deleting field '$field'");
            delete($entry->{$field});
          }
          else {
            if (exists($entry->{$field})) {
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
            my $orig = $step->{map_append} ? $entry->{$field} : '';

            if ($step->{map_origentrytype}) {
              next unless $last_type;
              $logger->debug("Source mapping (type=$level, key=$key): Setting field '$field' to '${orig}${last_type}'");
              $entry->{$field} = $orig . $last_type;
            }
            elsif ($step->{map_origfieldval}) {
              next unless $last_fieldval;
              $logger->debug("Source mapping (type=$level, key=$key): Setting field '$field' to '${orig}${last_fieldval}'");
              $entry->{$field} = $orig . $last_fieldval;
            }
            elsif ($step->{map_origfield}) {
              next unless $last_field;
              $logger->debug("Source mapping (type=$level, key=$key): Setting field '$field' to '${orig}${last_field}'");
              $entry->{$field} = $orig . $last_field;
            }
            else {
              my $fv = $step->{map_field_value};
              # Now re-instate any unescaped $1 .. $9 to get round these being
              # dynamically scoped and being null when we get here from any
              # previous map_match
              $fv =~ s/(?<!\\)\$(\d)/$imatches[$1-1]/ge;
              $logger->debug("Source mapping (type=$level, key=$key): Setting field '$field' to '${orig}${fv}'");
              $entry->{$field} = $orig . $fv;
            }
          }
        }
      }
    }
  }

  foreach my $f (keys %$entry) {
    # Now run any defined handler
    if ($dm->is_field($f)) {
      my $handler = _get_handler($f);
      &$handler($bibentry, $entry, $f);
    }
  }

  $bibentry->set_field('entrytype', $entry->{TY});
  $bibentry->set_field('datatype', 'ris');
  $bibentries->add_entry($key, $bibentry);

  return;
}

# HANDLERS
# ========

# List fields
sub _list {
  my ($bibentry, $entry, $f) = @_;
  $bibentry->set_datafield($f, [ $entry->{$f} ]);
  return;
}

# Verbatim fields
sub _verbatim {
  my ($bibentry, $entry, $f) = @_;
  $bibentry->set_datafield($f, $entry->{$f});
  return;
}

# CSV field forms
sub _csv {
  my ($bibentry, $entry, $f) = @_;
  $bibentry->set_datafield($f, [ split(/\s*,\s*/, $entry->{$f}) ]);
  return;
}

# URI fields
sub _uri {
  my ($bibentry, $entry, $f) = @_;
  my $value = $entry->{$f};

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
  if (my $r = _parse_range_list($entry->{$f})) {
    $bibentry->set_datafield($f, $r);
  }
  return;
}

# Date fields
sub _date {
  my ($bibentry, $entry, $f) = @_;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $key = $bibentry->get_field('citekey');
  my $ds = $section->get_keytods($key);
  my $date = $entry->{$f};
  if ($date =~ m|\A([0-9]{4})/([0-9]{2})/([0-9]{2})\s*\z|xms) {
    $bibentry->set_datafield('year', $1);
    $bibentry->set_datafield('month', $2);
    $bibentry->set_datafield('day', $3);
  }
  elsif ($date =~ m|\A([0-9]+)\s*\z|xms) {
    $bibentry->set_datafield('year', $1);
  }
  else {
    biber_warn("Datamodel: Entry '$key' ($ds): Invalid RIS date format: '$date' - ignoring");
  }
  return;
}

# Name fields
sub _name {
  my ($bibentry, $entry, $f) = @_;
  my $names = $entry->{$f};
  my $names_obj = new Biber::Entry::Names;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $key = $bibentry->get_field('citekey');
  my $ds = $section->get_keytods($bibentry->get_field('citekey'));
  foreach my $name (@$names) {
    $logger->debug('Parsing RIS name');
    if ($name =~ m|\A([^,]+)\s*,?\s*([^,]+)?\s*,?\s*([^,]+)?\z|xms) {
      my $lastname = _join_name_parts(split(/\s+/, $1)) if $1;
      my $firstname = _join_name_parts(split(/\s+/, $2)) if $2;
      my $suffix = _join_name_parts(split(/\s+/, $3)) if $3;
      $logger->debug("Found name component 'lastname': $lastname") if $lastname;
      $logger->debug("Found name component 'firstname': $firstname") if $firstname;
      $logger->debug("Found name component 'suffix': $suffix") if $suffix;

      my @lni = _gen_initials(split(/\s/, $1)) if $lastname;
      my @fni = _gen_initials(split(/\s/, $2)) if $firstname;
      my @si = _gen_initials(split(/\s/, $3)) if $suffix;

      my $namestring = '';

      # lastname
      $namestring .= "$lastname, ";

      # suffix
      $namestring .= "$suffix, " if $suffix;

      # firstname
      $namestring .= $firstname if $firstname;

      # Remove any trailing comma and space if, e.g. missing firstname
      # Replace any nbspes
      $namestring =~ s/,\s+\z//xms;
      $namestring =~ s/~/ /gxms;

      # Construct $nameinitstring
      my $nameinitstr = '';
      $nameinitstr .= $lastname if $lastname;
      $nameinitstr .= '_' . join('', @si) if $suffix;
      $nameinitstr .= '_' . join('', @fni) if $firstname;
      $nameinitstr =~ s/\s+/_/g;
      $nameinitstr =~ s/~/_/g;

      my $name_obj = Biber::Entry::Name->new(
        firstname       => $firstname || undef,
        firstname_i     => $firstname ? \@fni : undef,
        lastname        => $lastname,
        lastname_i      => \@lni,
        suffix          => $suffix || undef,
        suffix_i        => $suffix ? \@si : undef,
        namestring      => $namestring,
        nameinitstring  => $nameinitstr
      );
      $names_obj->add_name($name_obj);
      $bibentry->set_datafield($f, $names_obj);

      # Special case
      if ($f eq 'A3') {
        $bibentry->set_datafield('editortype', 'series');
      }
    }
    else {
      biber_warn("Datamodel: Entry '$key' ($ds): Invalid RIS name format: '$name' - ignoring");
    }
  }
  return;

}

# Joins name parts using BibTeX tie algorithm. Ties are added:
#
# 1. After the first part if it is less than three characters long
# 2. Before the last part
sub _join_name_parts {
  my @parts = @_;
  # special case - 1 part
  if ($#parts == 0) {
    return $parts[0];
  }
  # special case - 2 parts
  if ($#parts == 1) {
    return $parts[0] . '~' . $parts[1];
  }
  my $namestring = $parts[0];
  $namestring .= Unicode::GCString->new($parts[0])->length < 3 ? '~' : ' ';
  $namestring .= join(' ', @parts[1 .. ($#parts - 1)]);
  $namestring .= '~' . $parts[$#parts];
  return $namestring;
}

# Passed an array of strings, returns an array of initials for the strings
sub _gen_initials {
  my @strings = @_;
  my @strings_out;
  foreach my $str (@strings) {
    # Deal with hyphenated name parts and normalise to a '-' character for easy
    # replacement with macro later
    if ($str =~ m/\p{Dash}/) {
      push @strings_out, join('-', _gen_initials(split(/\p{Dash}/, $str)));
    }
    elsif ($str =~ m/\s/) { # name parts with spaces
      push @strings_out, _gen_initials(split(/\s+/, $str));
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


# parses a range and returns a ref to an array of start and end values
# Don't return anything if the range is invalid. Deals with RIS files which
# have empty SP or EP fields
sub _parse_range_list {
  my $range = shift;
  my $start = $range->{SP} || '';
  my $end = $range->{EP} || '';
  if ($start) {
    return [[$start, $end]];
  }
  else {
    return undef;
  }
}

sub _get_handler {
  my $field = shift;
  if (my $h = $handlers->{CUSTOM}{$field}) {
    return $h;
  }
  else {
    return $handlers->{$dm->get_fieldtype($field)}{$dm->get_fieldformat($field)}{$dm->get_datatype($field)};
  }
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Biber::Input::file::ris - look in a RIS file for an entry and create it if found

=head1 DESCRIPTION

Provides the extract_entries() method to get entries from a RIS data source
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
