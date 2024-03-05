package Biber::Entry;
use v5.24;
use strict;
use warnings;

use Biber::Utils;
use Biber::Internals;
use Biber::Constants;
use Data::Dump qw( pp );
use Digest::MD5 qw( md5_hex );
use Encode;
use Log::Log4perl qw( :no_extra_logdie_message );
use List::Util qw( first );

my $logger = Log::Log4perl::get_logger('main');

=encoding utf-8

=head1 NAME

Biber::Entry - Biber::Entry objects

=head2 new

    Initialize a Biber::Entry object

    There are three types of field possible in an entry:

    * data    - These are fields which derive directly from or are themselves fields in the
                data source. Things like YEAR, MONTH, DAY etc. are such fields which are
                derived from, for example, the DATE field. They are part of the original
                data implicitly, derived from a field.
    * derived - These are fields, often meta-information like labelname, labelalpha etc.
                which are more removed from the data fields.

    The reason for this division is largely the entry cloning required for the related entry and
    inheritance features. When we clone an entry or copy some fields from one entry to another
    we generally don't want the "derived" category as such derived meta-fields will often need
    to be re-created or ignored so we need to know which are the actual "data" fields to
    copy/clone.

=cut

sub new {
  my $class = shift;
  my $obj = shift;
  my $self;
  if (defined($obj) and ref($obj) eq 'HASH') {
    $self = bless $obj, $class;
  }
  else {
    $self = bless {}, $class;
  }
  return $self;
}

=head2 relclone

    Recursively create related entry clones starting with an entry

=cut

sub relclone {
  my $self = shift;
  my $citekey = $self->get_field('citekey');
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $dmh = Biber::Config->get_dm_helpers;
  if (my $relkeys = $self->get_field('related')) {
    if ($logger->is_debug()) {# performance tune
      $logger->debug("Found RELATED field in '$citekey' with contents " . join(',', @$relkeys));
    }
    my @clonekeys;
    foreach my $relkey (@$relkeys) {
      # Resolve any alias
      my $nrelkey = $section->get_citekey_alias($relkey) // $relkey;
      if ($logger->is_debug()) {# performance tune
        $logger->debug("Resolved RELATED key alias '$relkey' to '$nrelkey'") if $relkey ne $nrelkey;
        $logger->debug("Looking at RELATED key '$relkey'");
      }
      $relkey = $nrelkey;

      # Loop avoidance, in case we are back in an entry again in the guise of a clone
      # We can record the related clone but don't create it again
      if (my $ck = $section->get_keytorelclone($relkey)) {
        if ($logger->is_debug()) {# performance tune
          $logger->debug("Found RELATED key '$relkey' already has clone '$ck'");
        }
        push @clonekeys, $ck;

        # Save graph information if requested
        if (Biber::Config->getoption('output_format') eq 'dot') {
          Biber::Config->set_graph('related', $ck, $relkey, $citekey);
        }
      }
      else {
        my $relentry = $section->bibentry($relkey);
        # Digest::MD5 can't deal with straight UTF8 so encode it first (via NFC as this is "output")
        my $clonekey = md5_hex(encode_utf8($relkey));
        push @clonekeys, $clonekey;
        my $relclone = $relentry->clone($clonekey);
        if ($logger->is_debug()) {# performance tune
          $logger->debug("Created new related clone for '$relkey' with clone key '$clonekey'");
        }

        # Set related clone options
        if (my $relopts = $self->get_field('relatedoptions')) {
          # Check if this clone was also directly cited. If so, set skipbib/skipbiblist
          # if they are unset as otherwise this entry would appear twice in bibliographies
          # but with different keys.
          if ($section->has_citekey($relkey)) {
            $relopts = merge_entry_options($relopts, ['skipbib', 'skipbiblist']);
          }

          process_entry_options($clonekey, $relopts, $secnum);
          $relclone->set_datafield('options', $relopts);
        }
        else {
          # related clone needs its own options plus all the dataonly opts, any conflicts and
          # explicit options win

          my $relopts = merge_entry_options(['skipbib', 'skiplab','skipbiblist','uniquename=false','uniquelist=false'], $relentry->get_field('options'));

          # Preserve options already in the clone but add 'dataonly' options
          process_entry_options($clonekey, $relopts, $secnum);
          $relclone->set_datafield('options', $relopts);
        }

        $section->bibentries->add_entry($clonekey, $relclone);
        $section->keytorelclone($relkey, $clonekey);

        # Save graph information if requested
        if (Biber::Config->getoption('output_format') eq 'dot') {
          Biber::Config->set_graph('related', $clonekey, $relkey, $citekey);
        }

        # recurse so we can do cascading related entries
        if ($logger->is_debug()) {# performance tune
          $logger->debug("Recursing into RELATED entry '$clonekey'");
        }
        $relclone->relclone;
      }
    }
    # point to clone keys and add to citekeys
    # We have to add the citekeys as we need these clones in the .bbl
    # but the dataonly will cause biblatex not to print them in the bib
    $section->add_citekeys(@clonekeys);
    $self->set_datafield('related', [ @clonekeys ]);
  }
}

=head2 clone

    Clone a Biber::Entry object and return a copy
    Accepts optionally a key for the copy

=cut

sub clone {
  my ($self, $newkey) = @_;
  my $new = new Biber::Entry;
  my $dmh = Biber::Config->get_dm_helpers;

  while (my ($k, $v) = each(%{$self->{datafields}})) {
    $new->{datafields}{$k} = $v;
  }
  while (my ($k, $v) = each(%{$self->{origfields}})) {
    $new->{origfields}{$k} = $v;
  }

  # Clone xdata information
  $new->{xdatarefs} = $self->{xdatarefs};

  # clone derived date fields
  foreach my $df ($dmh->{datefields}->@*) {
    $df =~ s/date$//;
    foreach my $dsf ('dateunspecified', 'datesplit', 'datejulian',
                     'enddatejulian', 'dateapproximate', 'enddateapproximate',
                     'dateuncertain', 'enddateuncertain', 'yeardivision', 'yeardivision',
                     'era', 'endera') {
      if (my $ds = $self->{derivedfields}{"$df$dsf"}) {
        $new->{derivedfields}{"$df$dsf"} = $ds;
      }
    }
  }

  # Clone annotations
  Biber::Annotation->copy_annotations($self->get_field('citekey'), $newkey);

  # Need to add entrytype and datatype
  $new->{derivedfields}{entrytype} = $self->{derivedfields}{entrytype};
  $new->{derivedfields}{datatype} = $self->{derivedfields}{datatype};

  # put in key if specified
  if ($newkey) {
    $new->{derivedfields}{citekey} = $newkey;
  }
  # Record the key of the source of the clone in the clone. Useful for loop detection etc.
  # in biblatex
  $new->{derivedfields}{clonesourcekey} = $self->get_field('citekey');
  return $new;
}

=head2 notnull

    Test for an empty object

=cut

sub notnull {
  my $self = shift;
  my @arr = keys %$self;
  return $#arr > -1 ? 1 : 0;
}

=head2 add_xdata_ref

  Add an XDATA reference to the entry
  Reference can be simply to an entire XDATA entry or a particular field+position in field
  Record reference and target positions so that the XDATA marker can be removed as otherwise
  it would break further parsing

=cut

sub add_xdata_ref {
  my ($self, $reffield, $value, $reffieldposition) = @_;
  if ($reffield eq 'xdata') { # whole XDATA fields are a simple case
    push $self->{xdatarefs}->@*, {# field pointing to XDATA
                                  reffield => 'xdata',
                                  refposition => 0,
                                  xdataentries => $value,
                                  xdatafield => undef,
                                  xdataposition => 0};
    return 1;
  }
  else { # Granular XDATA reference
    my $xnamesep = Biber::Config->getoption('xnamesep');
    my $xdatamarker = Biber::Config->getoption('xdatamarker');
    if (my ($xdataref) = $value =~ m/^$xdatamarker$xnamesep(\S+)$/xi) {
      my $xdatasep = Biber::Config->getoption('xdatasep');
      my ($xe, $xf, $xfp) = $xdataref =~ m/^([^$xdatasep]+)$xdatasep([^$xdatasep]+)(?:$xdatasep(\d+))?$/x;
      unless ($xf) { # There must be a field in a granular XDATA ref
        my $entry_key = $self->get_field('citekey');
        my $bee = $self->get_field('entrytype');
        my $secnum = $Biber::MASTER->get_current_section;
        biber_warn("$bee entry '$entry_key' has XDATA reference from field '$reffield' that contains no source field (section $secnum)", $self);
        return 0;
      }
      push $self->{xdatarefs}->@*, {# field pointing to XDATA
                                    reffield => $reffield,
                                    # field position pointing to XDATA, 1-based
                                    refposition => defined($reffieldposition) ? $reffieldposition+1 : 1,
                                    # XDATA entry
                                    xdataentries => [$xe],
                                    # XDATA field
                                    xdatafield => $xf,
                                    # XDATA field position, 1-based
                                    xdataposition => $xfp//'*'};
      return 1;
    }
    else {
      return 0;
    }
  }
}

=head2 get_xdata_refs

  Get the XDATA references

=cut

sub get_xdata_refs {
  my $self = shift;
  return $self->{xdatarefs};
}

=head2 get_xdata_ref

  Get a specific XDATA reference

=cut

sub get_xdata_ref {
  my ($self, $field, $pos) = @_;
  foreach my $xdatum ($self->{xdatarefs}->@*) {
    if ($xdatum->{reffield} eq $field) {
      if ($pos) {
        if ($xdatum->{refposition} == $pos) {
          return $xdatum;
        }
      }
      else {
        return $xdatum;
      }
    }
  }
  return undef;
}

=head2 is_xdata_resolved

  Checks if an XDATA reference was resolved. Returns false also for
  "no such reference".

=cut

sub is_xdata_resolved {
  my ($self, $field, $pos) = @_;
  foreach my $xdatum ($self->{xdatarefs}->@*) {
    if ($xdatum->{reffield} eq $field) {
      if ($pos) {
        if ($xdatum->{refposition} == $pos) {
          return $xdatum->{resolved};
        }
      }
      else {
        return $xdatum->{resolved};
      }
    }
  }
  return 0;
}


=head2 set_labelname_info

  Record the labelname information. This is special
  meta-information so we have a separate method for this
  Takes a hash ref with the information.

=cut

sub set_labelname_info {
  my ($self, $data) = @_;
  $self->{labelnameinfo} = $data;
  return;
}

=head2 get_labelname_info

  Retrieve the labelname information. This is special
  meta-information so we have a separate method for this
  Returns a hash ref with the information.

=cut

sub get_labelname_info {
  my $self = shift;
  return $self->{labelnameinfo};
}

=head2 set_labelnamefh_info

  Record the fullhash labelname information. This is special
  meta-information so we have a separate method for this
  Takes a hash ref with the information.

=cut

sub set_labelnamefh_info {
  my ($self, $data) = @_;
  $self->{labelnamefhinfo} = $data;
  return;
}

=head2 get_labelnamefh_info

  Retrieve the fullhash labelname information. This is special
  meta-information so we have a separate method for this
  Returns a hash ref with the information.

=cut

sub get_labelnamefh_info {
  my $self = shift;
  return $self->{labelnamefhinfo};
}

=head2 set_labeltitle_info

  Record the labeltitle information. This is special
  meta-information so we have a separate method for this
  Takes a hash ref with the information.

=cut

sub set_labeltitle_info {
  my ($self, $data) = @_;
  $self->{labeltitleinfo} = $data;
  return;
}

=head2 get_labeltitle_info

  Retrieve the labeltitle information. This is special
  meta-information so we have a separate method for this
  Returns a hash ref with the information.

=cut

sub get_labeltitle_info {
  my $self = shift;
  return $self->{labeltitleinfo};
}


=head2 set_labeldate_info

  Record the labeldate information. This is special
  meta-information so we have a separate method for this
  Takes a hash ref with the information.

=cut

sub set_labeldate_info {
  my ($self, $data) = @_;
  $self->{labeldateinfo} = $data;
  return;
}

=head2 get_labeldate_info

  Retrieve the labeldate information. This is special
  meta-information so we have a separate method for this
  Returns a hash ref with the information.

=cut

sub get_labeldate_info {
  my $self = shift;
  return $self->{labeldateinfo};
}


=head2 set_field

  Set a derived field for a Biber::Entry object, that is, a field
  which was not an actual bibliography field

=cut

sub set_field {
  my ($self, $key, $val) = @_;
  # All derived fields can be null
  $self->{derivedfields}{$key} = $val;
  return;
}


=head2 get_field

    Get a field for a Biber::Entry object
    Uses // as fields can be null (end dates etc).

=cut

sub get_field {
  my ($self, $key) = @_;
  return undef unless $key;
  return $self->{datafields}{$key} //
         $self->{derivedfields}{$key};
}

=head2 set_datafield

    Set a field which is in the .bib data file

=cut

sub set_datafield {
  my ($self, $key, $val) = @_;
  $self->{datafields}{$key} = $val;
  return;
}

=head2 get_datafield

    Get a field that was in the original data file

=cut

sub get_datafield {
  my ($self, $key) = @_;
  return $self->{datafields}{$key};
}


=head2 del_field

    Delete a field in a Biber::Entry object

=cut

sub del_field {
  my ($self, $key) = @_;
  delete $self->{datafields}{$key};
  delete $self->{derivedfields}{$key};
  return;
}

=head2 del_datafield

    Delete an original data source data field in a Biber::Entry object

=cut

sub del_datafield {
  my ($self, $key) = @_;
  delete $self->{datafields}{$key};
  return;
}


=head2 field_exists

    Check whether a field exists (even if null)

=cut

sub field_exists {
  my ($self, $key) = @_;
  return (exists($self->{datafields}{$key}) ||
          exists($self->{derivedfields}{$key})) ? 1 : 0;
}

=head2 date_fields_exist

    Check whether any parts of a date field exist when passed a datepart field name

=cut

sub date_fields_exist {
  my ($self, $field) = @_;
  my $t = $field =~ s/(?:end)?(?:year|month|day|hour|minute|second|yeardivision|timezone)$//r;
  foreach my $dp ('year', 'month', 'day', 'hour', 'minute', 'second', 'yeardivision', 'timezone') {
    if (exists($self->{datafields}{"$t$dp"}) or exists($self->{datafields}{"${t}end$dp"})) {
      return 1;
    }
  }
  return 0;
}

=head2 delete_date_fields

    Delete all parts of a date field when passed any datepart field name

=cut

sub delete_date_fields {
  my ($self, $field) = @_;
  my $t = $field =~ s/(?:end)?(?:year|month|day|hour|minute|second|yeardivision|timezone)$//r;
  foreach my $dp ('year', 'month', 'day', 'hour', 'minute', 'second', 'yeardivision', 'timezone') {
    delete($self->{datafields}{"$t$dp"});
    delete($self->{datafields}{"${t}end$dp"});
  }
  return 1;
}

=head2 datafields

    Returns a sorted array of the fields which came from the data source

=cut

sub datafields {
  my $self = shift;
  use locale;
  return sort keys %{$self->{datafields}};
}

=head2 count_datafields

    Returns the number of datafields

=cut

sub count_datafields {
  my $self = shift;
  return keys %{$self->{datafields}};
}

=head2 derivedfields

    Returns a sorted array of the fields which were added during processing

=cut

sub derivedfields {
  my $self = shift;
  use locale;
  return sort keys %{$self->{derivedfields}};
}

=head2 fields

    Returns a sorted array of all field names, including ones
    added during processing which are not necessarily fields
    which came from the data file

=cut

sub fields {
  my $self = shift;
  use locale;
  my %keys = (%{$self->{derivedfields}}, %{$self->{datafields}});
  return sort keys %keys;
}

=head2 count_fields

    Returns the number of fields

=cut

sub count_fields {
  my $self = shift;
  my %keys = (%{$self->{derivedfields}}, %{$self->{datafields}});
  return keys %keys;
}


=head2 has_keyword

    Check if a Biber::Entry object has a particular keyword in
    in the KEYWORDS field.

=cut

sub has_keyword {
  no autovivification;
  my $self = shift;
  my $keyword = shift;
  if (my $keywords = $self->{datafields}{keywords}) {
    return (first {$_ eq $keyword} @$keywords) ? 1 : 0;
  }
  else {
    return 0;
  }
  return undef; # shouldn't get here
}



=head2 add_warning

    Append a warning to a Biber::Entry object

=cut

sub add_warning {
  my ($self, $warning) = @_;
  push $self->{derivedfields}{warnings}->@*, $warning;
  return;
}


=head2 set_inherit_from

    Inherit fields from first child entry

    $entry->set_inherit_from($firstchild);

    Takes a second Biber::Entry object as argument

    The purpose here is to inherit fields so that sorting/labelling defaults
    can be generated for set parents from the first child set member data, unless
    the set parent itself already has some fields set that will do this. Set
    parents only have certain fields output in the .bbl and those that output but
    are not used in sorting/labelling data generation should not be inherited.

=cut

sub set_inherit_from {
  my ($self, $parent) = @_;
  my $dmh = Biber::Config->get_dm_helpers;

  # Data source fields
  foreach my $field ($parent->datafields) {
    next if $self->field_exists($field); # Don't overwrite existing fields

    # Annotations are allowed for set parents themselves so never inherit these.
    # This can't be suppressed at .bbl writing as it is impossible to know there
    # whether the field came from the parent or first child because inheritance
    # is a low-level operation on datafields
    next if fc($field) eq fc('annotation');

    # sets can have their own shorthands and it's not useful to inherit this anyway
    next if fc($field) eq fc('shorthand');

    $self->set_datafield($field, $parent->get_field($field));
  }

  # Datesplit is a special non datafield and needs to be inherited for any
  # validation checks which may occur later
  foreach my $df ($dmh->{datefields}->@*) {
    $df =~ s/date$//;
    if (my $ds = $parent->get_field("${df}datesplit")) {
      $self->set_field("${df}datesplit", $ds);
    }
  }
  return;
}

=head2 resolve_xdata

    Recursively resolve XDATA in an entry. Sets a flag in the XDATA metadata to
    say if the reference was successfully resolved.

    $entry->resolve_xdata($xdata);

=cut

sub resolve_xdata {
  my ($self, $xdata) = @_;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $entry_key = $self->get_field('citekey');
  my $bee = $self->get_field('entrytype');
  my $dm = Biber::Config->get_dm;

  # $xdata =
  # [
  #  { # xdata info for an actual XDATA field (XDATA = {key, key})
  #    reffield      => 'xdata',
  #    refposition   => 0,
  #    xdataentries  => # array ref of XDATA entry keys
  #    xdatafield    => undef,
  #    xdataposition => 0,
  #    resolved      => 1 or 0
  #  },
  #  { # xdata info for an granular XDATA ref in another field
  #    reffield      => # field pointing to XDATA
  #    refposition   => # field position pointing to XDATA (or 1), 1-based
  #    xdataentries  => # array ref containing single XDATA entry key
  #    xdatafield    => # field within XDATA entry
  #    xdataposition => # position in list field within XDATA entry (or 1), 1-based
  #    resolved      => 1 or 0
  #  }
  #  {
  #    .
  #    .
  #    .
  #  }
  # ]

  foreach my $xdatum ($xdata->@*) {
    foreach my $xdref ($xdatum->{xdataentries}->@*) {
      unless (my $xdataentry = $section->bibentry($xdref)) {
        biber_warn("$bee entry '$entry_key' references XDATA entry '$xdref' which does not exist, not resolving (section $secnum)", $self);
        $xdatum->{resolved} = 0;
        next;
      }
      else {
        unless ($xdataentry->get_field('entrytype') eq 'xdata') {
          biber_warn("$bee entry '$entry_key' references XDATA entry '$xdref' which is not an XDATA entry, not resolving (section $secnum)", $self);
          $xdatum->{resolved} = 0;
          next;
        }

        # record the XDATA resolve between these entries to prevent loops
        Biber::Config->set_inheritance('xdata', $xdref, $entry_key);
        # Detect XDATA loops
        unless (Biber::Config->is_inheritance_path('xdata', $entry_key, $xdref)) {
          if (my $recurse_xdata = $xdataentry->get_xdata_refs) { # recurse
            $xdataentry->resolve_xdata($recurse_xdata);
          }

          # Whole entry XDATA reference so inherit all fields
          if (not defined($xdatum->{xdatafield})) {
            foreach my $field ($xdataentry->datafields()) { # set fields
              next if $field eq 'ids'; # Never inherit aliases
              $self->set_datafield($field, $xdataentry->get_field($field));
              # Inherit field annotations too
              Biber::Annotation->inherit_annotations($xdataentry->get_field('citekey'),
                                                     $self->get_field('citekey'),
                                                     $field,
                                                     $field);

              # Record graphing information if required
              if (Biber::Config->getoption('output_format') eq 'dot') {
                Biber::Config->set_graph('xdata', $xdataentry->get_field('citekey'), $entry_key, $field, $field);
              }
              if ($logger->is_debug()) { # performance tune
                $logger->debug("Setting field '$field' in entry '$entry_key' via XDATA");
              }
            }
          }
          else { # Granular XDATA inheritance
            my $xdatafield = $xdatum->{xdatafield};
            my $xdataposition = $xdatum->{xdataposition};
            my $reffield = $xdatum->{reffield};
            my $refposition = $xdatum->{refposition};
            my $reffielddm = $dm->get_dm_for_field($reffield);
            my $xdatafielddm = $dm->get_dm_for_field($xdatafield);

            unless ($reffielddm->{fieldtype} eq $xdatafielddm->{fieldtype} and
                    $reffielddm->{datatype} eq $xdatafielddm->{datatype}) {
              biber_warn("Field '$reffield' in $bee entry '$entry_key' which xdata references field '$xdatafield' in entry '$xdref' are not the same types, not resolving (section $secnum)", $self);
              $xdatum->{resolved} = 0;
              next;
            }

            unless ($xdataentry->get_field($xdatafield)) {
              biber_warn("Field '$reffield' in $bee entry '$entry_key' references XDATA field '$xdatafield' in entry '$xdref' and this field does not exist, not resolving (section $secnum)", $self);
              $xdatum->{resolved} = 0;
              next;
            }

            # Name lists
            if ($dm->field_is_type('list', 'name', $reffield)) {
              if ($xdatum->{xdataposition} eq '*') { # insert all positions from XDATA field
                $self->get_field($reffield)->splice($xdataentry->get_field($xdatafield), $refposition);
                # Inherit annotations for the field and remap indices to new positions in target
                for (my $i=1; $i<=$xdataentry->get_field($xdatafield)->count; $i++) {
                  Biber::Annotation->inherit_annotations($xdataentry->get_field('citekey'),
                                                         $self->get_field('citekey'),
                                                         $xdatafield,
                                                         $reffield,
                                                         $i,
                                                         $refposition+($i-1));
                }

                if ($logger->is_debug()) { # performance tune
                  $logger->debug("Inserting at position $refposition in name field '$reffield' in entry '$entry_key' via XDATA");
                }
              }
              else {
                unless ($xdataentry->get_field($xdatafield)->is_nth_name($xdataposition)) {
                  biber_warn("Field '$reffield' in $bee entry '$entry_key' references field '$xdatafield' position $xdataposition in entry '$xdref' and this position does not exist, not resolving (section $secnum)", $self);
                  $xdatum->{resolved} = 0;
                  next;
                }
                $self->get_field($reffield)->
                  replace_name($xdataentry->get_field($xdatafield)->nth_name($xdataposition), $refposition);
                # Inherit annotations for the field and remap indices to new positions in target
                Biber::Annotation->inherit_annotations($xdataentry->get_field('citekey'),
                                                       $self->get_field('citekey'),
                                                       $xdatafield,
                                                       $reffield,
                                                       $xdataposition,
                                                       $refposition);

                if ($logger->is_debug()) { # performance tune
                  $logger->debug("Setting position $refposition in name field '$reffield' in entry '$entry_key' via XDATA");
                }
              }
            }
            # Non-name lists
            elsif ($dm->field_is_fieldtype('list', $reffield)) {
              if ($xdatum->{xdataposition} eq '*') { # insert all positions from XDATA field
                my $bibentries = $section->bibentries;
                my $be = $bibentries->entry($xdatum->{xdataentries}[0]);
                splice($self->get_field($reffield)->@*,
                       $refposition-1,
                       1,
                       $be->get_field($xdatafield)->@*);
                # Inherit annotations for the field and remap indices to new positions in target
                for (my $i=1; $i<=scalar($xdataentry->get_field($xdatafield)->@*);$i++) {
                  Biber::Annotation->inherit_annotations($xdataentry->get_field('citekey'),
                                                              $self->get_field('citekey'),
                                                              $xdatafield,
                                                              $reffield,
                                                              $i,
                                                              $refposition+($i-1));
                }

                if ($logger->is_debug()) { # performance tune
                  $logger->debug("Inserting at position $refposition in list field '$reffield' in entry '$entry_key' via XDATA");
                }
              }
              else {
                unless ($xdataentry->get_field($xdatafield)->[$xdataposition-1]) {
                  biber_warn("Field '$reffield' in $bee entry '$entry_key' references field '$xdatafield' position $xdataposition in entry '$xdref' and this position does not exist, not resolving (section $secnum)", $self);
                  $xdatum->{resolved} = 0;
                  next;
                }
                $self->get_field($reffield)->[$refposition-1] =
                  $xdataentry->get_field($xdatafield)->[$xdataposition-1];

                # Inherit annotations for the field and remap indices to new positions in target
                Biber::Annotation->inherit_annotations($xdataentry->get_field('citekey'),
                                                       $self->get_field('citekey'),
                                                       $xdatafield,
                                                       $reffield,
                                                       $xdataposition,
                                                       $refposition);

                if ($logger->is_debug()) { # performance tune
                  $logger->debug("Setting position $refposition in list field '$reffield' in entry '$entry_key' via XDATA");
                }
              }
            }
            # Non-list
            else {

              $self->set_datafield($reffield, $xdataentry->get_field($xdatafield));

              # Inherit annotations for the field and remap indices to new positions in target
              Biber::Annotation->inherit_annotations($xdataentry->get_field('citekey'),
                                                     $self->get_field('citekey'),
                                                     $xdatafield,
                                                     $reffield);

              if ($logger->is_debug()) { # performance tune
                $logger->debug("Setting field '$reffield' in entry '$entry_key' via XDATA");
              }
            }
          }
          $xdatum->{resolved} = 1;
        }
        else {
          biber_error("Circular XDATA inheritance between '$xdref'<->'$entry_key'");
        }
      }
    }
  }
}

=head2 inherit_from

    Inherit fields from parent entry (as indicated by the crossref field)

    $entry->inherit_from($parententry);

    Takes a second Biber::Entry object as argument
    Uses the crossref inheritance specifications from the .bcf

=cut

sub inherit_from {
  my ($self, $parent) = @_;
  my $dmh = Biber::Config->get_dm_helpers;

  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);

  my $target_key = $self->get_field('citekey'); # target/child key
  my $source_key = $parent->get_field('citekey'); # source/parent key

  # record the inheritance between these entries to prevent loops and repeats.
  Biber::Config->set_inheritance('crossref', $source_key, $target_key);

  # Detect crossref loops
  unless (Biber::Config->is_inheritance_path('crossref', $target_key, $source_key)) {
    # cascading crossrefs
    if (my $ppkey = $parent->get_field('crossref')) {
      $parent->inherit_from($section->bibentry($ppkey));
    }
  }
  else {
    biber_error("Circular inheritance between '$source_key'<->'$target_key'");
  }

  my $bee         = $self->get_field('entrytype');
  my $tbee         = $self->get_field('entrytype');
  my $parenttype  = $parent->get_field('entrytype');
  my $inheritance = Biber::Config->getblxoption(undef, 'inheritance');
  my %processed;
  # get defaults
  my $defaults = $inheritance->{defaults};
  # global defaults ...
  my $inherit_all = $defaults->{inherit_all};
  my $override_target = $defaults->{override_target};
  my $dignore = $defaults->{ignore};

  # override with type_pair specific defaults if they exist ...
  foreach my $type_pair ($defaults->{type_pair}->@*) {
    if (($type_pair->{source} eq '*' or $type_pair->{source} eq $parenttype) and
        ($type_pair->{target} eq '*' or $type_pair->{target} eq $bee)) {
      $inherit_all = $type_pair->{inherit_all} if $type_pair->{inherit_all};
      $override_target = $type_pair->{override_target} if $type_pair->{override_target};
      $dignore = $type_pair->{ignore} if defined($type_pair->{ignore});
    }
  }

  # First process any fields that have special treatment
  foreach my $inherit ($inheritance->{inherit}->@*) {
    # Match for this combination of entry and crossref parent?
    foreach my $type_pair ($inherit->{type_pair}->@*) {
      if (($type_pair->{source} eq '*' or $type_pair->{source} eq $parenttype) and
          ($type_pair->{target} eq '*' or $type_pair->{target} eq $bee)) {
        foreach my $field ($inherit->{field}->@*) {
          # Skip for fields in the per-entry noinerit datafield set
          if (my $niset = Biber::Config->getblxoption($secnum, 'noinherit', undef, $target_key) and
             exists($field->{target})) {
            if (first {$field->{target} eq $_} $DATAFIELD_SETS{$niset}->@*) {
              next;
            }
          }
          next unless $parent->field_exists($field->{source});
          $processed{$field->{source}} = 1;
          # localise defaults according to field, if specified
          my $field_override_target = $field->{override_target} // 'false';
          # Skip this field if requested
          if ($field->{skip}) {
            $processed{$field->{source}} = 1;
          }
          # Set the field if it doesn't exist or override is requested
          elsif (not $self->field_exists($field->{target}) or
                 $field_override_target eq 'true') {
            if ($logger->is_debug()) {# performance tune
              $logger->debug("$bee entry '$target_key' is inheriting field '" .
                             $field->{source}.
                             "' as '" .
                             $field->{target} .
                             "' from entry '$source_key'");
            }

            $self->set_datafield($field->{target}, $parent->get_field($field->{source}));
            Biber::Annotation->inherit_annotations($source_key,
                                                   $target_key,
                                                   $field->{source},
                                                   $field->{target});

            # Ignore uniqueness information tracking for this inheritance?
            my $ignore = $inherit->{ignore} || $dignore;
            Biber::Config->add_uniq_ignore($target_key, $field->{target}, $ignore);

            # Record graphing information if required
            if (Biber::Config->getoption('output_format') eq 'dot') {
              Biber::Config->set_graph('crossref', $source_key, $target_key, $field->{source}, $field->{target});
            }
          }
        }
      }
    }
  }

  # Now process the rest of the (original data only) fields, if necessary
  if ($inherit_all eq 'true') {
    my @fields = $parent->datafields;

    # Special case: WITH NO override: If the child has any Xdate datepart,
    # don't inherit any Xdateparts from parent otherwise you can end up
    # with rather broken dates in the child. Remove such fields before we
    # start since it can't be done in the loop because as soon as one
    # Xdatepart field has been inherited, no more will be. Save removed
    # fields as this is needed when copying derived special date fields
    # below as these also need skipping if we have skipped the *date field
    # from which they were derived
    # WITH override: Remove all related dateparts so that there is no conflict
    # with inherited
    # ONLY DO THIS FOR ENTRIES WITH xDATE FIELDS - LEGACY YEAR/MONTH MESS THINGS UP
    # AND WE JUST IGNORE THEM FOR THIS PRE-PROCESSING STEP
    my @filtered_fields;
    my @removed_fields;
    foreach my $field (@fields) {
      if (first {$_ eq $field} $dmh->{dateparts}->@*) {
        if ($parent->get_field('datesplit') and $self->get_field('datesplit')) {
          if ($self->date_fields_exist($field)) {
            if ($override_target eq 'true') {
              $self->delete_date_fields($field); # clear out all date field parts in target
            }
            else {
              push @removed_fields, $field;
              next;
            }
          }
        }
      }
      push @filtered_fields, $field;
    }
    @fields = @filtered_fields;

    # copy derived date fields as these are technically data
    foreach my $datefield ($dmh->{datefields}->@*) {
      my $df = $datefield =~ s/date$//r;
      # Ignore derived date special fields from date fields which we have skipped
      # because they already exist in the child.
      next if first {$_ eq $datefield} @removed_fields;
      foreach my $dsf ('dateunspecified', 'datesplit', 'datejulian',
                       'enddatejulian', 'dateapproximate', 'enddateapproximate',
                       'dateuncertain', 'enddateuncertain', 'yeardivision', 'endyeardivision',
                       'era', 'endera') {
        if (my $ds = $parent->{derivedfields}{"$df$dsf"}) {
          # Set unless the child has the *date datepart, otherwise you can
          # end up with rather broken dates in the child.
          $self->{derivedfields}{"$df$dsf"} = $ds;
        }
      }
    }

    foreach my $field (@fields) {
      # Skip for fields in the per-entry noinherit datafield set
      if (my $niset = Biber::Config->getblxoption($secnum, 'noinherit', undef, $target_key)) {
        if (first {$field eq $_} $DATAFIELD_SETS{$niset}->@*) {
          next;
        }
      }
      next if $processed{$field}; # Skip if we have already dealt with this field above

      # Set the field if it doesn't exist or override is requested
      if (not $self->field_exists($field) or $override_target eq 'true') {
        if ($logger->is_debug()) { # performance tune
          $logger->debug("$tbee entry '$target_key' is inheriting field '$field' from $bee entry '$source_key'");
        }

        $self->set_datafield($field, $parent->get_field($field));
        Biber::Annotation->inherit_annotations($source_key,
                                               $target_key,
                                               $field,
                                               $field);

        # Ignore uniqueness information tracking for this inheritance?
        Biber::Config->add_uniq_ignore($target_key, $field, $dignore);

        # Record graphing information if required
        if (Biber::Config->getoption('output_format') eq 'dot') {
          Biber::Config->set_graph('crossref', $source_key, $target_key, $field, $field);
        }
      }
    }
  }
  # Datesplit is a special non datafield and needs to be inherited for any
  # validation checks which may occur later
  foreach my $df ($dmh->{datefields}->@*) {
    $df =~ s/date$//;
    if (my $ds = $parent->get_field("${df}datesplit")) {
      $self->set_field("${df}datesplit", $ds);
    }
  }

  return;
}

=head2 dump

    Dump Biber::Entry object

=cut

sub dump {
  my $self = shift;
  return pp($self);
}

1;

__END__

=head1 AUTHORS

Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our Github tracker at
L<https://github.com/plk/biber/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2012 François Charette and Philip Kime, all rights reserved.
Copyright 2012-2024 Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
