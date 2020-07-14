package Biber::Entry;
use v5.24;
use strict;
use warnings;
use parent qw(Class::Accessor);
__PACKAGE__->follow_best_practice;

use Biber::Utils;
use Biber::Internals;
use Biber::Constants;
use Biber::Entry::FieldValue;
use Data::Dump qw( pp );
use Digest::MD5 qw( md5_hex );
use Encode;
use Log::Log4perl qw( :no_extra_logdie_message );
use List::Util qw( first );

my $logger = Log::Log4perl::get_logger('main');

# Names of simple package accessor attributes for those not created automatically
# by the option scope in the .bcf
__PACKAGE__->mk_accessors(qw (
                               msform
                               mslang
                            ));

=encoding utf-8

=head1 NAME

Biber::Entry

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
  my ($class, $key) = @_;
  my $self;
  if ($key) {
    $self->{derivedfields}{citekey} = $key;
    $self = bless $self, $class;
  }
  else {
    $self = bless {}, $class;
  }
  $self->{dm} = Biber::Config->get_dm;
  $self->{dmh} = Biber::Config->get_dm_helpers;

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
  if (my $relkeys = $self->get_field('related')) {
    if ($logger->is_debug()) {# performance tune
      $logger->debug("Found RELATED field in '$citekey' with contents " . join(',', $relkeys->get_items->@*));
    }
    my @clonekeys;
    foreach my $relkey ($relkeys->get_items->@*) {
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
            $relopts->set_items(merge_entry_options($relopts->get_items, ['skipbib', 'skipbiblist']));
          }

          process_entry_options($clonekey, $relopts, $secnum);
          $relclone->set_datafield('options', $relopts);
        }
        else {
          # related clone needs its own options plus all the dataonly opts, any conflicts and
          # explicit options win

          my $relopts = merge_entry_options(['skipbib',
                                             'skiplab',
                                             'skipbiblist',
                                             'uniquename=false',
                                             'uniquelist=false'],
                                            defined($relentry->get_field('options')) ? $relentry->get_field('options')->get_items : undef);

          $relopts = Biber::Entry::List->new($relopts);

          # Preserve options already in the clone but add 'dataonly' options
          process_entry_options($clonekey, $relopts, $secnum);
          $relclone->set_datafield('options', $relopts);
        }

        $section->bibentries->add_entry($clonekey, $relclone);
        $section->keytorelclone($relkey, $clonekey);

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
    $self->{datafields}{related} = Biber::Entry::List->new([ @clonekeys ]);
  }
}

=head2 clone

    Clone a Biber::Entry object and return a copy
    Accepts optionally a key for the copy

=cut

sub clone {
  my ($self, $newkey) = @_;
  my $new = Biber::Entry->new($newkey);

  while (my ($k, $v) = each(%{$self->{datafields}})) {
    $new->{datafields}{$k} = $v;
  }

  # Clone xdata information
  $new->{xdatarefs} = $self->{xdatarefs};

  # clone derived date fields
  foreach my $df ($self->{dmh}->{datefields}->@*) {
    $df =~ s/date$//;
    foreach my $dsf ('dateunspecified', 'datesplit', 'datejulian',
                     'enddatejulian', 'dateapproximate', 'enddateapproximate',
                     'dateuncertain', 'enddateuncertain', 'season', 'endseason',
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
  my ($self, $reffield, $refform, $reflang, $value, $reffieldposition) = @_;

  # form/lang have already been defaulted at this point

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
        my $secnum = $Biber::MASTER->get_current_section;
        biber_warn("Entry '$entry_key' has XDATA reference from field '$reffield/$refform/$reflang' that contains no source field (section $secnum)", $self);
        return 0;
      }
      my ($xdf, $xdfo, $xdl) = mssplit($xf, $self->{derivedfields}{citekey});
      push $self->{xdatarefs}->@*, {# field pointing to XDATA
                                    reffield => $reffield,
                                    # form for field pointing to XDATA
                                    refform => $refform,
                                    # lang for field pointing to XDATA
                                    reflang => $reflang,
                                    # field position pointing to XDATA, 1-based
                                    refposition => defined($reffieldposition) ? $reffieldposition+1 : 1,
                                    # XDATA entry
                                    xdataentries => [$xe],
                                    # XDATA field
                                    xdatafield => $xdf,
                                    # XDATA field form
                                    xdataform => $xdfo,
                                    # XDATA field lang
                                    xdatalang => $xdl,
                                    # XDATA field position, 1-based
                                    xdataposition => $xfp//1};
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
  my ($self, $field, $form, $lang, $pos) = @_;
  $form = $form // 'default';
  $lang = $lang // Biber::Config->get_mslang($self->{derivedfields}{citekey});

  foreach my $xdatum ($self->{xdatarefs}->@*) {
    if ($xdatum->{reffield} eq $field and
        $xdatum->{refform} eq $form and
        $xdatum->{reflang} eq $lang) {
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
  my ($self, $field, $form, $lang, $pos) = @_;
  $form = $form // 'default';
  $lang = $lang // Biber::Config->get_mslang($self->{derivedfields}{citekey});

  foreach my $xdatum ($self->{xdatarefs}->@*) {
    if ($xdatum->{reffield} eq $field and
        # form/lang won't exist for whole xdata fields
        (not $xdatum->{refform} or $xdatum->{refform} eq $form) and
        (not $xdatum->{reflang} or $xdatum->{reflang} eq $lang)) {
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

=cut

sub set_labelname_info {
  my ($self, $field, $form, $lang) = @_;
  $form = fc($form // 'default');
  $lang = fc($lang // Biber::Config->get_mslang($self->{derivedfields}{citekey}));
  $self->{labelnameinfo} = [$field, $form, $lang];
  return;
}

=head2 get_labelname_info

  Retrieve the labelname information. This is special
  meta-information so we have a separate method for this

=cut

sub get_labelname_info {
  my $self = shift;
  return $self->{labelnameinfo} // [];
}

=head2 set_labelnamefh_info

  Record the fullhash labelname information. This is special
  meta-information so we have a separate method for this

=cut

sub set_labelnamefh_info {
  my ($self, $field, $form, $lang) = @_;
  $form = fc($form // 'default');
  $lang = fc($lang // Biber::Config->get_mslang($self->{derivedfields}{citekey}));
  $self->{labelnamefhinfo} = [$field, $form, $lang];
  return;
}

=head2 get_labelnamefh_info

  Retrieve the fullhash labelname information. This is special
  meta-information so we have a separate method for this

=cut

sub get_labelnamefh_info {
  my $self = shift;
  return $self->{labelnamefhinfo} // [];
}

=head2 set_labeltitle_info

  Record the labeltitle information. This is special
  meta-information so we have a separate method for this

=cut

sub set_labeltitle_info {
  my ($self, $field, $form, $lang) = @_;
  $form = fc($form // 'default');
  $lang = fc($lang // Biber::Config->get_mslang($self->{derivedfields}{citekey}));
  $self->{labeltitleinfo} = [$field, $form, $lang];
  return;
}

=head2 get_labeltitle_info

  Retrieve the labeltitle information. This is special
  meta-information so we have a separate method for this

=cut

sub get_labeltitle_info {
  my $self = shift;
  return $self->{labeltitleinfo} // [];
}


=head2 set_labeldate_info

  Record the labeldate information. This is special
  meta-information so we have a separate method for this

=cut

sub set_labeldate_info {
  my ($self, $field) = @_;
  $self->{labeldateinfo} = $field;
  return;
}

=head2 get_labeldate_info

  Retrieve the labeldate information. This is special
  meta-information so we have a separate method for this

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
  my ($self, $field, $val, $form, $lang) = @_;
  no autovivification;

  if ($self->{dm}->is_multiscript($field)) {
    $lang = fc($lang) if $lang;

    if (defined($self->{derivedfields}{$field})) {
      $self->{derivedfields}{$field}->set_value($val, $form, $lang);
    }
    else {
      $self->{derivedfields}{$field} = Biber::Entry::FieldValue->new($self->{derivedfields}{citekey}, $val, $form, $lang);
    }
  }
  else {
    $self->{derivedfields}{$field} = $val;
  }

  return;
}

=head2 set_datafield

    Set a field which is in the datasource

=cut

sub set_datafield {
  my ($self, $field, $val, $form, $lang) = @_;
  no autovivification;

  if ($self->{dm}->is_multiscript($field)) {
    $lang = fc($lang) if $lang;

    if (defined($self->{datafields}{$field})) {
      $self->{datafields}{$field}->set_value($val, $form, $lang);
    }
    else {
      $self->{datafields}{$field} = Biber::Entry::FieldValue->new($self->{derivedfields}{citekey}, $val, $form, $lang);
    }
  }
  else {
    $self->{datafields}{$field} = $val;
  }

  return;
}

=head2 get_alternates_for_field

    Get an sorted array ref of valid {form=>$form, lang=>$lang,
    val=>$value} triplets for a field

=cut

sub get_alternates_for_field {
  my ($self, $field) = @_;

  if ($self->{dm}->is_multiscript($field)) {
    if (defined($self->{datafields}{$field})) {
      return $self->{datafields}{$field}->get_alternates;
    }
    elsif (defined($self->{derivedfields}{$field})) {
      return $self->{derivedfields}{$field}->get_alternates;
    }
  }
  else {
    if (defined($self->{datafields}{$field})) {
      return [{val => $self->{datafields}{$field}}];
    }
    elsif (defined($self->{derivedfields}{$field})) {
      return [{val => $self->{derivedfields}{$field}}];
    }
  }
  return [];
}

=head2 get_field

    Get a field for a Biber::Entry object

=cut

sub get_field {
  my ($self, $field, $form, $lang) = @_;
  return undef unless $field;
  no autovivification;

  if ($self->{dm}->is_multiscript($field)) {
    $lang = fc($lang) if $lang;

    # Override lang if langid overrode global mslang
    if ($lang) {
      $lang = fc($lang);
    }
    else {
      if ($self->field_exists('langid')) {
        $lang = Biber::Config->get_mslang($self->{derivedfields}{citekey});
      }
    }

    my $v;
    if (defined($self->{datafields}{$field})) {
      $v = $self->{datafields}{$field}->get_value($form, $lang);
    }
    elsif (defined($self->{derivedfields}{$field})) {
      $v = $self->{derivedfields}{$field}->get_value($form, $lang);
    }
    return $v;
  }
  else {
    return $self->{datafields}{$field} if defined($self->{datafields}{$field});
    return $self->{derivedfields}{$field} if defined($self->{derivedfields}{$field});
  }
  return undef;
}

=head2 get_datafield

    Get a field that was in the original data file

=cut

sub get_datafield {
  my ($self, $field, $form, $lang) = @_;
  return undef unless $field;
  no autovivification;

  if ($self->{dm}->is_multiscript($field)) {
    $lang = fc($lang) if $lang;

    my $v;
    if (defined($self->{datafields}{$field})) {
      return  $self->{datafields}{$field}->get_value($form, $lang);
    }
  }
  else {
    return  $self->{datafields}{$field};
  }
}

=head2 get_fieldraw

    Get a raw FieldValue - mostly used for debugging

=cut

sub get_fieldraw {
  my ($self, $field) = @_;
  return undef unless $field;
  return $self->{datafields}{$field} // $self->{derivedfields}{$field};
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
  my ($self, $field, $form, $lang) = @_;
  no autovivification;

  if ($self->{dm}->is_multiscript($field)) {
    my $f = $self->{datafields}{$field} || $self->{derivedfields}{$field};
    return 0 unless $f;
    $lang = fc($lang) if $lang;
    return defined($f->get_value($form, $lang)) ? 1 : 0;
  }
  else {
    my $f = $self->{datafields}{$field} // $self->{derivedfields}{$field};
    return defined($f) ? 1 : 0;
  }
}

=head2 date_fields_exist

    Check whether any parts of a date field exist when passed a datepart field name

=cut

sub date_fields_exist {
  my ($self, $field) = @_;
  my $t = $field =~ s/(?:end)?(?:year|month|day|hour|minute|second|season|timezone)$//r;
  foreach my $dp ('year', 'month', 'day', 'hour', 'minute', 'second', 'season', 'timezone') {
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
  my $t = $field =~ s/(?:end)?(?:year|month|day|hour|minute|second|season|timezone)$//r;
  foreach my $dp ('year', 'month', 'day', 'hour', 'minute', 'second', 'season', 'timezone') {
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
  my ($self, $keyword) = @_;
  if (my $kws = $self->{datafields}{keywords}) {
    return (first {$_ eq $keyword} $kws->get_items->@*) ? 1 : 0;
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
  push $self->{warnings}->@*, $warning;
  return;
}

=head2 get_warnings

    Retrieve warnings for an entry

=cut

sub get_warnings {
  my $self = shift;
  return $self->{warnings};
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

  # Data source fields
  foreach my $field ($parent->datafields) {
    foreach my $alts ($parent->get_alternates_for_field($field)->@*) {
      my $val = $alts->{val};
      my $form = $alts->{form} // '';
      my $lang = $alts->{lang} // '';

      next if $self->field_exists($field, $form, $lang); # Don't overwrite existing fields

      # Annotations are allowed for set parents themselves so never inherit these.
      # This can't be suppressed at .bbl writing as it is impossible to know there
      # whether the field came from the parent or first child because inheritance
      # is a low-level operation on datafields
      next if fc($field) eq fc('annotation');

      $self->set_datafield($field, $parent->get_field($field, $form, $lang), $form, $lang);
    }
  }

  # Datesplit is a special non datafield and needs to be inherited for any
  # validation checks which may occur later
  foreach my $df ($self->{dmh}->{datefields}->@*) {
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
  #    refform       => 'default',
  #    reflang       => 'en-us',
  #    refposition   => # field position pointing to XDATA (or 1), 1-based
  #    xdataentries  => # array ref containing single XDATA entry key
  #    xdatafield    => # field within XDATA entry
  #    xdataform     => 'default',
  #    xdatalang     => 'en-us',
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
        biber_warn("Entry '$entry_key' references XDATA entry '$xdref' which does not exist, not resolving (section $secnum)", $self);
        $xdatum->{resolved} = 0;
        next;
      }
      else {
        unless ($xdataentry->get_field('entrytype') eq 'xdata') {
          biber_warn("Entry '$entry_key' references XDATA entry '$xdref' which is not an XDATA entry, not resolving (section $secnum)", $self);
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
              foreach my $alts ($xdataentry->get_alternates_for_field($field)->@*) {
                my $val = $alts->{val};
                my $form = $alts->{form} // '';
                my $lang = $alts->{lang} // '';

                next if $field eq 'ids'; # Never inherit aliases
                $self->set_datafield($field, $xdataentry->get_field($field, $form, $lang), $form, $lang);

                if ($logger->is_debug()) { # performance tune
                  $logger->debug("Setting field '$field' in entry '$entry_key' via XDATA");
                }
              }
            }
          }
          else { # Granular XDATA inheritance
            my $xdatafield = $xdatum->{xdatafield};
            my $xdataform = $xdatum->{xdataform};
            my $xdatalang = $xdatum->{xdatalang};
            my $xdataposition = $xdatum->{xdataposition};
            my $reffield = $xdatum->{reffield};
            my $refform = $xdatum->{refform};
            my $reflang = $xdatum->{reflang};
            my $refposition = $xdatum->{refposition};
            my $reffielddm = $dm->get_dm_for_field($reffield);
            my $xdatafielddm = $dm->get_dm_for_field($xdatafield);

            unless ($reffielddm->{fieldtype} eq $xdatafielddm->{fieldtype} and
                    $reffielddm->{datatype} eq $xdatafielddm->{datatype}) {
              biber_warn("Field '$reffield/$refform/$reflang' in entry '$entry_key' which xdata references field '$xdatafield/$xdataform/$xdatalang' in entry '$xdref' are not the same types, not resolving (section $secnum)", $self);
              $xdatum->{resolved} = 0;
              next;
            }

            unless ($xdataentry->get_field($xdatafield, $xdataform, $xdatalang)) {
              biber_warn("Field '$reffield/$refform/$reflang' in entry '$entry_key' references XDATA field '$xdatafield/$xdataform/$xdatalang' in entry '$xdref' and this field does not exist, not resolving (section $secnum)", $self);
              $xdatum->{resolved} = 0;
              next;
            }

            # Name lists
            if ($dm->field_is_type('list', 'name', $reffield)){
              unless ($xdataentry->get_field($xdatafield, $xdataform, $xdatalang)->is_nth_name($xdataposition)) {
                biber_warn("Field '$reffield/$refform/$reflang' in entry '$entry_key' references field '$xdatafield/$xdataform/$xdatalang' position $xdataposition in entry '$xdref' and this position does not exist, not resolving (section $secnum)", $self);
                $xdatum->{resolved} = 0;
                next;
              }
              $self->get_field($reffield, $refform, $reflang)->replace_name($xdataentry->get_field($xdatafield, $xdataform, $xdatalang)->nth_name($xdataposition), $refposition);
              if ($logger->is_debug()) { # performance tune
                $logger->debug("Setting position $refposition in name field '$reffield/$refform/$reflang' in entry '$entry_key' via XDATA");
              }
            }
            # Non-name lists
            elsif ($dm->field_is_fieldtype('list', $reffield)) {
              unless ($xdataentry->get_field($xdatafield, $xdataform, $xdatalang)->nth_item($xdataposition)) {
                biber_warn("Field '$reffield/$refform/$reflang' in entry '$entry_key' references field '$xdatafield/$xdataform/$xdatalang' position $xdataposition in entry '$xdref' and this position does not exist, not resolving (section $secnum)", $self);
                $xdatum->{resolved} = 0;
                next;
              }

              $self->get_field($reffield, $refform, $reflang)->replace_item($xdataentry->get_field($xdatafield, $xdataform, $xdatalang)->nth_item($refposition), $refposition);
              if ($logger->is_debug()) { # performance tune
                $logger->debug("Setting position $refposition in list field '$reffield/$refform/$reflang' in entry '$entry_key' via XDATA");
              }
            }
            # Non-list
            else {
              $self->set_datafield($reffield, $xdataentry->get_field($xdatafield, $xdataform, $xdatalang), $refform, $reflang);
              if ($logger->is_debug()) { # performance tune
                $logger->debug("Setting field '$reffield/$refform/$reflang' in entry '$entry_key' via XDATA");
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

  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);

  my $target_key = $self->get_field('citekey'); # target/child key
  my $source_key = $parent->get_field('citekey'); # source/parent key
  my $dm = Biber::Config->get_dm;

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

  my $type        = $self->get_field('entrytype');
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
        ($type_pair->{target} eq '*' or $type_pair->{target} eq $type)) {
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
          ($type_pair->{target} eq '*' or $type_pair->{target} eq $type)) {
        foreach my $field ($inherit->{field}->@*) {
          # Skip for fields in the per-entry noinerit datafield set
          if (my $niset = Biber::Config->getblxoption($secnum, 'noinherit', undef, $target_key) and
             exists($field->{target})) {
            if (first {$field->{target} eq $_} $DATAFIELD_SETS{$niset}->@*) {
              next;
            }
          }
          foreach my $alts ($parent->get_alternates_for_field($field->{source})->@*) {
            my $val = $alts->{val};
            my $form = $alts->{form} // '';
            my $lang = $alts->{lang} // '';

            $processed{$field->{source}} = 1;
            # localise defaults according to field, if specified
            my $field_override_target = $field->{override_target} // 'false';
            # Skip this field if requested
            if ($field->{skip}) {
              $processed{$field->{source}} = 1;
            }
            # Set the field if it doesn't exist or override is requested
            elsif (not $self->field_exists($field->{target}, $form, $lang) or
                   $field_override_target eq 'true') {
              if ($logger->is_debug()) { # performance tune
                $logger->debug("Entry '$target_key' is inheriting field '" .
                               $field->{source} . "/$form/$lang" .
                               "' as '" .
                               $field->{target} . "/$form/$lang" .
                               "' from entry '$source_key'");
              }

              # Force inherited fields to be langid of entry if it exists and override
              # with annotation
              my $tlang = $lang;
              my $llid = $LOCALE_MAP{$self->get_field('langid')} if $self->get_field('langid');
              if ($dm->is_multiscript($field->{target}) and
                  $llid and
                  $llid ne fc($lang)) {
                $tlang = $llid;
                Biber::Annotation->set_annotation('field', $target_key, $field->{target}, $form, $tlang, 'mslang', $lang, 1);
              }

              $self->set_datafield($field->{target}, $parent->get_field($field->{source}, $form, $lang), $form, $tlang);

              # Ignore uniqueness information tracking for this inheritance?
              my $ignore = $inherit->{ignore} || $dignore;
              Biber::Config->add_uniq_ignore($target_key, $field->{target}, $ignore);

            }
          }
        }
      }
    }
  }

  # Now process the rest of the (original data only) fields, if necessary
  if ($inherit_all eq 'true') {
    my @fields = $parent->datafields;

    my @filtered_fields;
    my @removed_fields;

    # Special case:
    # WITH NO override: If the child has any Xdate datepart, don't inherit any Xdateparts
    # from parent otherwise you can end up with rather broken dates in the child.
    # Remove such fields before we start since it can't be done in the loop because
    # as soon as one Xdatepart field has been inherited, no more will be.
    # Save removed fields as this is needed when copying derived special date fields below
    # as these also need skipping if have skipped the *date field from which they were derived
    # WITH override: Remove all related dateparts so that there is no conflict with inherited
    foreach my $field (@fields) {
      if (first {$_ eq $field} $self->{dmh}->{dateparts}->@*) {
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
      push @filtered_fields, $field;
    }
    @fields = @filtered_fields;

    # copy derived date fields as these are technically data
    foreach my $datefield ($self->{dmh}->{datefields}->@*) {
      my $df = $datefield =~ s/date$//r;
      # Ignore derived date special fields from date fields which we have skipped
      # because they already exist in the child.
      next if first {$_ eq $datefield} @removed_fields;
      foreach my $dsf ('dateunspecified', 'datesplit', 'datejulian',
                       'enddatejulian', 'dateapproximate', 'enddateapproximate',
                       'dateuncertain', 'enddateuncertain', 'season', 'endseason',
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

      foreach my $alts ($parent->get_alternates_for_field($field)->@*) {
        my $val = $alts->{val};
        my $form = $alts->{form} // '';
        my $lang = $alts->{lang} // '';

        # Set the field if it doesn't exist or override is requested
        if (not $self->field_exists($field, $form, $lang) or $override_target eq 'true') {
          if ($logger->is_debug()) { # performance tune
            $logger->debug("Entry '$target_key' is inheriting field '$field/$form/$lang' from entry '$source_key'");
          }

          # Force inherited fields to be langid of entry if it exists and override
          # with annotation
          my $tlang = $lang;
          my $llid = $LOCALE_MAP{$self->get_field('langid')} if $self->get_field('langid');
          if ($dm->is_multiscript($field) and
              $llid and
              $llid ne fc($lang)) {
            $tlang = $llid;
            Biber::Annotation->set_annotation('field', $target_key, $field, $form, $tlang, 'mslang', $lang, 1);
          }

          $self->set_datafield($field, $parent->get_field($field, $form, $lang), $form, $tlang);

          # Ignore uniqueness information tracking for this inheritance?
          Biber::Config->add_uniq_ignore($target_key, $field, $dignore);

        }
      }
    }
  }
  # Datesplit is a special non datafield and needs to be inherited for any
  # validation checks which may occur later
  foreach my $df ($self->{dmh}->{datefields}->@*) {
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
Copyright 2012-2020 Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
