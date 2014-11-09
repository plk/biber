package Biber::Entry;
use v5.16;
use strict;
use warnings;

use Biber::Utils;
use Biber::Internals;
use Biber::Constants;
use Data::Dump qw( pp );
use Digest::MD5 qw( md5_hex );
use Log::Log4perl qw( :no_extra_logdie_message );
use List::Util qw( first );
use Storable qw( dclone );

my $logger = Log::Log4perl::get_logger('main');

=encoding utf-8

=head1 NAME

Biber::Entry

=head2 new

    Initialize a Biber::Entry object

    There are three types of field possible in an entry:

    * raw  - These are direct copies of input fields with no processing performed on them.
             Such fields are used for tool mode where we don't want to alter the fields as they
             need to go back into the output as they are
    * data - These are fields which derive directly from or are themselves fields in the
             data souce. Things like YEAR, MONTH, DAY etc. are such fields which are derived from,
             for example, the DATE field (which is itself a "raw" field). They are part of the
             original data implicitly, derived from a "raw" field.
    * other - These are fields, often meta-information like labelname, labelalpha etc. which are
              more removed from the data fields.

    The reason for this division is largely the entry cloning required for the related entry and
    inheritance features. When we clone an entry or copy some fields from one entry to another
    we generally don't want the "other" category as such derived meta-fields will often need
    to be re-created or ignored so we need to know which are the actual "data" fields to copy/clone.
    "raw" fields are important when we are writing bibtex format output (in tool mode for example)
    since in such cases, we don't want to derive implicit fields like YEAR/MONTH from DATE.

=cut

sub new {
  my $class = shift;
  my $obj = shift;
  my $self;
  if (defined($obj) and ref($obj) eq 'HASH') {
    $self = bless $obj, $class;
  }
  else {
    $self = bless { datafields    => {variant => {}, nonvariant => {} },
                    derivedfields => {variant => {}, nonvariant => {} },
                    rawfields     => {variant => {}, nonvariant => {} } }, $class;
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
  if (my $relkeys = $self->get_field('related')) {
    $logger->debug("Found RELATED field in '$citekey' with contents " . join(',', @$relkeys));
    my @clonekeys;
    foreach my $relkey (@$relkeys) {
      # Resolve any alias
      my $nrelkey = $section->get_citekey_alias($relkey) // $relkey;
      $logger->debug("Resolved RELATED key alias '$relkey' to '$nrelkey'") if $relkey ne $nrelkey;
      $relkey = $nrelkey;
      $logger->debug("Looking at RELATED key '$relkey'");

      # Loop avoidance, in case we are back in an entry again in the guise of a clone
      # We can record the related clone but don't create it again
      if (my $ck = $section->get_keytorelclone($relkey)) {
        $logger->debug("Found RELATED key '$relkey' already has clone '$ck'");
        push @clonekeys, $ck;

        # Save graph information if requested
        if (Biber::Config->getoption('output_format') eq 'dot') {
          Biber::Config->set_graph('related', $ck, $relkey, $citekey);
        }
      }
      else {
        my $relentry = $section->bibentry($relkey);
        my $clonekey = md5_hex($relkey);
        push @clonekeys, $clonekey;
        my $relclone = $relentry->clone($clonekey);
        $logger->debug("Created new related clone for '$relkey' with clone key '$clonekey'");

        # Set related clone options
        if (my $relopts = $self->get_field('relatedoptions')) {
          process_entry_options($clonekey, $relopts);
          $relclone->set_datafield('options', $relopts);
        }
        else {
          process_entry_options($clonekey, [ 'skiplab', 'skipbiblist', 'uniquename=0', 'uniquelist=0' ]);
          # Set options field as this is passed through to biblatex
          $relclone->set_datafield('options', [ 'dataonly' ]);
        }

        # vlang is a special option that should be copied to related clones and made
        # visible in the options list for biblatex
        if (my $lid = $relclone->get_field('langid')) {
          my $opts = $relclone->get_field('options');
          push @$opts, "vlang=$lid";
          $relclone->set_datafield('options', $opts);
          Biber::Config->setblxoption('vlang', $lid, 'PER_ENTRY', $clonekey);
        }

        $section->bibentries->add_entry($clonekey, $relclone);
        $section->keytorelclone($relkey, $clonekey);

        # Save graph information if requested
        if (Biber::Config->getoption('output_format') eq 'dot') {
          Biber::Config->set_graph('related', $clonekey, $relkey, $citekey);
        }

        # recurse so we can do cascading related entries
        $logger->debug("Recursing into RELATED entry '$clonekey'");
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
  my $self = shift;
  my $newkey = shift;
  my $key = $self->get_field('citekey');
  my $new = new Biber::Entry;
  while (my ($k, $v) = each(%{$self->{datafields}{variant}})) {
    $new->{datafields}{variant}{$k} = dclone($v);
  }
  while (my ($k, $v) = each(%{$self->{rawfields}{variant}})) {
    $new->{rawfields}{variant}{$k} = dclone($v);
  }
  while (my ($k, $v) = each(%{$self->{datafields}{nonvariant}})) {
    $new->{datafields}{nonvariant}{$k} = $v;
  }
  while (my ($k, $v) = each(%{$self->{rawfields}{nonvariant}})) {
    $new->{rawfields}{nonvariant}{$k} = $v;
  }
  # Need to add entrytype and datatype
  $new->{derivedfields}{nonvariant}{entrytype} = $self->{derivedfields}{nonvariant}{entrytype};
  $new->{derivedfields}{nonvariant}{datatype} = $self->{derivedfields}{nonvariant}{datatype};
  # put in key if specified
  if ($newkey) {
    $new->{derivedfields}{nonvariant}{citekey} = $newkey;
  }
  # Record the key of the source of the clone in the clone. Useful for loop detection etc.
  # in biblatex
  $new->{derivedfields}{nonvariant}{clonesourcekey} = $key;
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

=head2 set_labelname_info

  Record the labelname information. This is special
  meta-information so we have a seperate method for this
  Takes a hash ref with the information.

=cut

sub set_labelname_info {
  my $self = shift;
  my $data = shift;
  my $key = $self->get_field('citekey');
  $data->{form} = $data->{form} || Biber::Config->getblxoption('vform', undef, $key);
  my $langfield = (($data->{form} eq 'translated') ? 'vtranslang' : 'vlang');
  $data->{lang} = $data->{lang} || Biber::Config->getblxoption($langfield, undef, $key);
  $self->{labelnameinfo} = $data;
  $logger->trace("Set labelname for '$key' to " . $data->{field} . '/' . $data->{form} . '/' . $data->{lang});
  return;
}

=head2 get_labelname_info

  Retrieve the labelname information. This is special
  meta-information so we have a seperate method for this
  Returns a hash ref with the information.

=cut

sub get_labelname_info {
  my $self = shift;
  return $self->{labelnameinfo};
}

=head2 set_labelnamefh_info

  Record the fullhash labelname information. This is special
  meta-information so we have a seperate method for this
  Takes a hash ref with the information.

=cut

sub set_labelnamefh_info {
  my $self = shift;
  my $data = shift;
  my $key = $self->get_field('citekey');
  $data->{form} = $data->{form} || Biber::Config->getblxoption('vform', undef, $key);
  my $langfield = (($data->{form} eq 'translated') ? 'vtranslang' : 'vlang');
  $data->{lang} = $data->{lang} || Biber::Config->getblxoption($langfield, undef, $key);
  $self->{labelnamefhinfo} = $data;
  return;
}

=head2 get_labelnamefh_info

  Retrieve the fullhash labelname information. This is special
  meta-information so we have a seperate method for this
  Returns a hash ref with the information.

=cut

sub get_labelnamefh_info {
  my $self = shift;
  return $self->{labelnamefhinfo};
}

=head2 set_labeltitle_info

  Record the labeltitle information. This is special
  meta-information so we have a seperate method for this
  Takes a hash ref with the information.

=cut

sub set_labeltitle_info {
  my $self = shift;
  my $data = shift;
  my $key = $self->get_field('citekey');
  $data->{form} = $data->{form} || Biber::Config->getblxoption('vform', undef, $key);
  my $langfield = (($data->{form} eq 'translated') ? 'vtranslang' : 'vlang');
  $data->{lang} = $data->{lang} || Biber::Config->getblxoption($langfield, undef, $key);
  $self->{labeltitleinfo} = $data;
  $logger->trace("Set labeltitle for '$key' to " . $data->{field} . '/' . $data->{form} . '/' . $data->{lang});
  return;
}

=head2 get_labeltitle_info

  Retrieve the labeltitle information. This is special
  meta-information so we have a seperate method for this
  Returns a hash ref with the information.

=cut

sub get_labeltitle_info {
  my $self = shift;
  return $self->{labeltitleinfo};
}


=head2 set_labeldate_info

  Record the labeldate information. This is special
  meta-information so we have a seperate method for this
  Takes a hash ref with the information.

=cut

sub set_labeldate_info {
  my $self = shift;
  my $data = shift;
  my $key = $self->get_field('citekey');
  $data->{form} = $data->{form} || Biber::Config->getblxoption('vform', undef, $key);
  my $langfield = (($data->{form} eq 'translated') ? 'vtranslang' : 'vlang');
  $data->{lang} = $data->{lang} || Biber::Config->getblxoption($langfield, undef, $key);
  $self->{labeldateinfo} = $data;
  return;
}

=head2 get_labeldate_info

  Retrieve the labeldate information. This is special
  meta-information so we have a seperate method for this
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
  my $self = shift;
  my ($field, $val, $form, $lang) = @_;
  my $dm = Biber::Config->get_dm;
  my $key = ($field eq 'citekey' ) ? $val : $self->{derivedfields}{nonvariant}{citekey};
  if ($dm->field_is_variant_enabled($field)) {
    $form = $form || 'original';
    my $langfield = (($form eq 'translated') ? 'vtranslang' : 'vlang');
    $lang = $lang || Biber::Config->getblxoption($langfield, undef, $key);
    $logger->trace("Setting variant enabled field in '$key': $field/$form/$lang=$val");
    # All derived fields can be null
    $self->{derivedfields}{variant}{$field}{$form}{$lang} = $val;
  }
  else {
    $self->{derivedfields}{nonvariant}{$field} = $val;
    $logger->trace("Setting field in '$key': $field=" . ($val || ''));
  }
  return;
}


=head2 get_field

    Get a specific field variant for a Biber::Entry object,
    Uses // as fields can be null (end dates etc).

    If no field is found using vform/vlang/vtranslang when no variant specified,
    try some fallbacks to support sorting/label/inheritance processing.

=cut

sub get_field {
  no autovivification;
  my $self = shift;
  my ($field, $form, $lang) = @_;
  return undef unless $field;
  return undef unless $self->field_exists($field);
  my $dm = Biber::Config->get_dm;
  my $fbs = Biber::Config->getblxoption('variantfallbacks');
  my $key = $self->{derivedfields}{nonvariant}{citekey};# can't use get_field due to recursion ...

  if ($dm->field_is_variant_enabled($field)) {
    my $f = $self->_get_field($field, $form, $lang);

    # If vform/v*lang form not found, look into fallbacks
    unless ($f) {
      foreach my $fb (@$fbs) {
        $logger->trace("Looking for variant fallback '$field/" . ($fb->{form} || '') . '/' . ($fb->{lang} || '') . "' in '$key'");
        if (my $rf = $self->_get_field($field, $fb->{form}, $fb->{lang})) {
          $logger->trace("Found variant fallback '$field/" . ($fb->{form} || '') . '/' . ($fb->{lang}|| '') . "' in '$key'");
          return $rf;
        }
      }
      return undef;
    }
    else {
      return $f;
    }
  }
  else {
    return $self->_get_field($field);
  }
}

# Pure get_field with no fallbacks
sub _get_field {
  no autovivification;
  my $self = shift;
  my ($field, $form, $lang) = @_;
  my $dm = Biber::Config->get_dm;
  my $key = $self->{derivedfields}{nonvariant}{citekey};# can't use get_field due to recursion ...
  my $bee = $self->{derivedfields}{nonvariant}{entrytype};# can't use get_field due to recursion ...
  if ($dm->field_is_variant_enabled($field)) {
    $form = $form || Biber::Config->getblxoption('vform', undef, $key);
    my $langfield = (($form eq 'translated') ? 'vtranslang' : 'vlang');

    # Wildcard lang
    if (Biber::Config->getblxoption('autovlang', $bee, $key)) {
      my @langs = $self->get_field_form_lang_names($field, $form);
      $lang = $langs[0] || Biber::Config->getblxoption($langfield, undef, $key);
    }
    else {
      $lang = $lang || Biber::Config->getblxoption($langfield, undef, $key);
    }

    $logger->trace("Looking for variant enabled field in '$key': $field/$form/$lang");
    my $r = $self->{datafields}{variant}{$field}{$form}{$lang} //
            $self->{derivedfields}{variant}{$field}{$form}{$lang} //
              $self->{rawfields}{variant}{$field};
    if ($r) {
      $logger->trace("Found variant enabled field in '$key': $field/$form/$lang");
    }
    else {
      $logger->trace("Did NOT find variant enabled field in '$key': $field/$form/$lang");
    }
    return $r;
  }
  else {
    $logger->trace("Looking for field in '$key': $field") if $key;
    my $r = $self->{datafields}{nonvariant}{$field} //
            $self->{derivedfields}{nonvariant}{$field} //
            $self->{rawfields}{nonvariant}{$field};
    if ($r) {
      $logger->trace("Found variant enabled field in '$key': $field");
    }
    else {
      $logger->trace("Did NOT find variant enabled field in '$key': $field");
    }
    return $r;
  }
}

=head2 field_has_variants

    Return boolean if field has any variants (other than defaults)

=cut

sub field_has_variants {
  my $self = shift;
  my $field = shift;
  return undef unless $field;
  my $dm = Biber::Config->get_dm;
  return undef unless $dm->field_is_variant_enabled($field);
  my $key = $self->get_field('citekey');
  foreach my $form ($self->get_field_form_names($field)) {
    my $langfield = (($form eq 'translated') ? 'vtranslang' : 'vlang');
    foreach my $lang ($self->get_field_form_lang_names($field, $form)) {
      return 1 unless ($form eq 'original' and
                       $lang eq Biber::Config->getblxoption($langfield, undef, $key));
    }
  }
  return 0;
}


=head2 get_field_variants

    Get all field variants for a Biber::Entry object field

=cut

sub get_field_variants {
  my $self = shift;
  my $field = shift;
  return undef unless $field;
  my @nfs;
  my $dm = Biber::Config->get_dm;
  return undef unless $dm->field_is_variant_enabled($field);
  foreach my $form ($self->get_field_form_names($field)) {
    foreach my $lang ($self->get_field_form_lang_names($field, $form)) {
      push @nfs, $self->get_field($field, $form, $lang);
    }
  }
  return @nfs;
}


=head2 get_field_forms

    Get all field forms for a Biber::Entry object field

=cut

sub get_field_forms {
  no autovivification;
  my $self = shift;
  my $field = shift;
  return undef unless $field;
  return $self->{datafields}{variant}{$field} ||
         $self->{derivedfields}{variant}{$field};
}

=head2 get_field_form_names

    Get all field form names for a Biber::Entry object field

=cut

sub get_field_form_names {
  no autovivification;
  my $self = shift;
  my $field = shift;
  return undef unless $field;
  my $dm = Biber::Config->get_dm;
  return undef unless $dm->field_is_variant_enabled($field);
  return sort keys %{$self->{datafields}{variant}{$field} ||
                $self->{derivedfields}{variant}{$field} ||
                {}};
}

=head2 get_field_form_lang_names

    Get all field lang names for a Biber::Entry object field and form

=cut

sub get_field_form_lang_names {
  no autovivification;
  my $self = shift;
  my ($field, $form) = @_;
  return undef unless $field;
  return undef unless $form;
  my $dm = Biber::Config->get_dm;
  return undef unless $dm->field_is_variant_enabled($field);
  return sort keys %{$self->{datafields}{variant}{$field}{$form} ||
                $self->{derivedfields}{variant}{$field}{$form} ||
                {}};
}

=head2 set_datafield

    Set a field which is in the .bib data file

=cut

sub set_datafield {
  no autovivification;
  my $self = shift;
  my ($field, $val, $form, $lang) = @_;
  my $key = $self->get_field('citekey');
  my $bee = $self->get_field('entrytype');
  my $dm = Biber::Config->get_dm;
  if ($dm->field_is_variant_enabled($field)) {
    $form = $form || 'original';
    my $langfield = (($form eq 'translated') ? 'vtranslang' : 'vlang');
    $lang = $lang || Biber::Config->getblxoption($langfield, undef, $key);
    $logger->trace("Setting variant enabled datafield in '$key': $field/$form/$lang=$val");

    # Can happen in cases where "x_y" and "x" are in the same entry with vform=y
    if ($self->{datafields}{variant}{$field}{$form}{$lang}) {
      $logger->debug("Variant enabled datafield $field/$form/$lang in key '$key' already has a value - overwriting");
    }
    $self->{datafields}{variant}{$field}{$form}{$lang} = $val;
  }
  else {
    if (exists($self->{datafields}{nonvariant}{$field})) {
      $logger->debug("Non-variant enabled datafield '$field' in key '$key' already has a value - overwriting");
    }
    $self->{datafields}{nonvariant}{$field} = $val;
    $logger->trace("Setting datafield in '$key': $field=$val");
  }
  return;
}

=head2 set_datafield_forms

    Set all forms of a field which is in the bib data file

=cut

sub set_datafield_forms {
  my $self = shift;
  my ($field, $val) = @_;
  my $dm = Biber::Config->get_dm;
  return undef unless $dm->field_is_variant_enabled($field);
  $self->{datafields}{variant}{$field} = $val;
  return;
}


=head2 set_rawfield

    Save a copy of the raw field from the datasource

=cut

sub set_rawfield {
  my $self = shift;
  my ($field, $val) = @_;
  my $dm = Biber::Config->get_dm;
  if ($dm->field_is_variant_enabled($field)) {
    $self->{rawfields}{variant}{$field} = $val;
  }
  else {
    $self->{rawfields}{nonvariant}{$field} = $val;
  }
  return;
}

=head2 get_rawfield

    Get a raw field

=cut

sub get_rawfield {
  no autovivification;
  my $self = shift;
  my $field = shift;
  my $dm = Biber::Config->get_dm;
  if ($dm->field_is_variant_enabled($field)) {
    return $self->{rawfields}{variant}{$field};
  }
  else {
    return $self->{rawfields}{nonvariant}{$field};
  }
}


=head2 get_datafield

    Get a field that was in the original data file
    Only ever used on non-variant fields

=cut

sub get_datafield {
  no autovivification;
  my $self = shift;
  my ($field) = @_;
  return $self->{datafields}{nonvariant}{$field};
}


=head2 del_field

    Delete a field in a Biber::Entry object

=cut

sub del_field {
  my $self = shift;
  my $field = shift;
  my $dm = Biber::Config->get_dm;
  my $type = $dm->field_is_variant_enabled($field) ? 'variant' : 'nonvariant';
  delete $self->{datafields}{$type}{$field};
  delete $self->{derivedfields}{$type}{$field};
  delete $self->{rawfields}{$type}{$field};
  return;
}

=head2 del_datafield

    Delete an original data source data field in a Biber::Entry object

=cut

sub del_datafield {
  my $self = shift;
  my $field = shift;
  my $dm = Biber::Config->get_dm;
  if ($dm->field_is_variant_enabled($field)) {
    delete $self->{datafields}{variant}{$field};
  }
  else {
    delete $self->{datafields}{nonvariant}{$field};
  }
  return;
}


=head2 field_exists

    Check whether a field exists (even if null)

=cut

sub field_exists {
  no autovivification;
  my $self = shift;
  my $field = shift;
  my $dm = Biber::Config->get_dm;
  my $type = $dm->field_is_variant_enabled($field) ? 'variant' : 'nonvariant';
  return (defined($self->{datafields}{$type}{$field}) ||
          defined($self->{derivedfields}{$type}{$field}) ||
          defined($self->{rawfields}{$type}{$field})) ? 1 : 0;
}

=head2 field_form_exists

    Check whether a representation form for a field exists (even if null)

=cut

sub field_form_exists {
  no autovivification;
  my $self = shift;
  my ($field, $form) = @_;
  my $dm = Biber::Config->get_dm;
  return undef unless $dm->field_is_variant_enabled($field);
  my $key = $self->get_field('citekey');
  $form = $form || 'original';
  return (defined($self->{datafields}{variant}{$field}{$form}) ||
          defined($self->{derivedfields}{variant}{$field}{$form})) ? 1 : 0;
}

=head2 field_variant_exists

    Check whether a specific variant of a field exists (even if default)

=cut

sub field_variant_exists {
  no autovivification;
  my $self = shift;
  my ($field, $form, $lang) = @_;
  my $key = $self->get_field('citekey');
  my $dm = Biber::Config->get_dm;
  my $type = $dm->field_is_variant_enabled($field) ? 'variant' : 'nonvariant';
  $form = $form || 'original';
  my $langfield = (($form eq 'translated') ? 'vtranslang' : 'vlang');
  $lang = $lang || Biber::Config->getblxoption($langfield, undef, $key);
  return (defined($self->{datafields}{$type}{$field}{$form}{$lang}) ||
          defined($self->{derivedfields}{$type}{$field}{$form}{$lang})) ? 1 : 0;
}

=head2 datafields

    Returns a sorted array of the fields which came from the data source

=cut

sub datafields {
  my $self = shift;
  use locale;
  return sort keys %{$self->{datafields}{variant}}, keys %{$self->{datafields}{nonvariant}};
}

=head2 rawfields

    Returns a sorted array of the raw fields and contents

=cut

sub rawfields {
  my $self = shift;
  use locale;
  return sort keys %{$self->{rawfields}{variant}}, keys %{$self->{rawfields}{nonvariant}};
}

=head2 count_datafields

    Returns the number of datafields

=cut

sub count_datafields {
  my $self = shift;
  return keys %{$self->{datafields}{variant}}, keys %{$self->{datafields}{nonvariant}};
}


=head2 fields

    Returns a sorted array of all field names, including ones
    added during processing which are not necessarily fields
    which came from the data file

=cut

sub fields {
  my $self = shift;
  use locale;
  my %keys = (%{$self->{derivedfields}{variant}},
              %{$self->{datafields}{variant}},
              %{$self->{derivedfields}{nonvariant}},
              %{$self->{datafields}{nonvariant}});
  return sort keys %keys;
}

=head2 count_fields

    Returns the number of fields

=cut

sub count_fields {
  my $self = shift;
  my %keys = (%{$self->{derivedfields}{variant}},
              %{$self->{datafields}{variant}},
              %{$self->{derivedfields}{nonvariant}},
              %{$self->{datafields}{nonvariant}});
  return keys %keys;
}


=head2 has_keyword

    Check if a Biber::Entry object has a particular keyword in
    in the KEYWORDS field.

=cut

sub has_keyword {
  my ($self, $keyword) = @_;
  if (my $keywords = $self->{datafields}{nonvariant}{keywords}) {
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
  my $self = shift;
  my $warning = shift;
  my $key = $self->get_field('citekey');
  push @{$self->{derivedfields}{nonvariant}{warnings}}, $warning;
  return;
}


=head2 set_inherit_from

    Inherit fields from parent entry

    $entry->set_inherit_from($parententry);

    Takes a second Biber::Entry object as argument
    Tailored for set inheritance which is a straight 1:1 inheritance,
    excluding certain fields for backwards compatibility

=cut

sub set_inherit_from {
  my $self = shift;
  my $parent = shift;
  my $dm = Biber::Config->get_dm;

  # Data source fields
  foreach my $field ($parent->datafields) {
    next if $self->field_exists($field); # Don't overwrite existing fields
    if ($dm->field_is_variant_enabled($field)) {
      $self->set_datafield_forms($field, dclone($parent->get_field_forms($field)));
    }
    else {
      $self->set_datafield($field, $parent->get_field($field));
    }
  }
  # Datesplit is a special non datafield and needs to be inherited for any
  # validation checks which may occur later
  if (my $ds = $parent->get_field('datesplit')) {
    $self->set_field('datesplit', $ds);
  }
  return;
}

=head2 resolve_xdata

    Recursively resolve XDATA fields in an entry

    $entry->resolve_xdata($xdata_entry);

=cut

sub resolve_xdata {
  my ($self, $xdata) = @_;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my $entry_key = $self->get_field('citekey');
  my $dm = Biber::Config->get_dm;

  foreach my $xdatum (@$xdata) {
    unless (my $xdatum_entry = $section->bibentry($xdatum)) {
      biber_warn("Entry '$entry_key' references XDATA entry '$xdatum' which does not exist in section $secnum");
      next;
    }
    else {
      # Skip xdata inheritance if we've already done it
      # This will only ever be between two XDATA entrytypes since we
      # always start at a non-XDATA entrytype, which we'll not look at again
      # and recursion is always between XDATA entrytypes.
      next if Biber::Config->get_inheritance('xdata', $xdatum, $entry_key);

      # record the XDATA resolve between these entries to prevent loops
      Biber::Config->set_inheritance('xdata', $xdatum, $entry_key);

      # Detect XDATA loops
      unless (Biber::Config->is_inheritance_path('xdata', $entry_key, $xdatum)) {
        if (my $recurse_xdata = $xdatum_entry->get_field('xdata')) { # recurse
          $xdatum_entry->resolve_xdata($recurse_xdata);
        }
        # For tool mode with bibtex output we need to copy the raw fields
        if (Biber::Config->getoption('tool') and
            Biber::Config->getoption('output_format') eq 'bibtex') {
          foreach my $field ($xdatum_entry->rawfields()) { # set raw fields
            next if $field eq 'ids'; # Never inherit aliases
            $self->set_rawfield($field, $xdatum_entry->get_rawfield($field));
            $logger->debug("Setting field '$field' in entry '$entry_key' via XDATA");
          }
        }
        else {
          foreach my $field ($xdatum_entry->datafields()) { # set fields
            next if $field eq 'ids'; # Never inherit aliases
            if ($dm->field_is_variant_enabled($field)) {
              $self->set_datafield_forms($field, $xdatum_entry->get_field_forms($field));
            }
            else {
              $self->set_datafield($field, $xdatum_entry->get_field($field));
            }
            # Record graphing information if required
            if (Biber::Config->getoption('output_format') eq 'dot') {
              Biber::Config->set_graph('xdata', $xdatum_entry->get_field('citekey'), $entry_key, $field, $field);
            }
            $logger->debug("Setting field '$field' in entry '$entry_key' via XDATA");
          }
        }
      }
      else {
        biber_error("Circular XDATA inheritance between '$xdatum'<->'$entry_key'");
      }
    }
  }
}

=head2 inherit_from

    Inherit fields from parent entry (as indicated by the crossref field)

    $entry->inherit_from($parententry);

    Takes a second Biber::Entry object as argument
    Uses the crossref inheritance specifications from the .bcf

    Rather verbose because we have to deal with all combinations of variant/non-variant
    fields. It could be more parameterised but it would be horrible to debug.
    At least this is relatively clear and the conditional branches are mutally
    exclusive.

=cut

sub inherit_from {
  my ($self, $parent) = @_;

  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);

  my $target_key = $self->get_field('citekey'); # target/child key
  my $source_key = $parent->get_field('citekey'); # source/parent key
  my $dm = Biber::Config->get_dm;
  my $vlang_s = Biber::Config->getblxoption('vlang', undef, $source_key);
  my $vlang_t = Biber::Config->getblxoption('vlang', undef, $target_key);

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
  my $inheritance = Biber::Config->getblxoption('inheritance');
  my $vsplit     = Biber::Config->getoption('vsplit');
  my $processed;
  # get defaults
  my $defaults = $inheritance->{defaults};
  # global defaults ...
  my $inherit_all = $defaults->{inherit_all};
  my $override_target = $defaults->{override_target};
  # override with type_pair specific defaults if they exist ...
  foreach my $type_pair (@{$defaults->{type_pair}}) {
    if (($type_pair->{source} eq '*' or $type_pair->{source} eq $parenttype) and
        ($type_pair->{target} eq '*' or $type_pair->{target} eq $type)) {
      $inherit_all = $type_pair->{inherit_all} if $type_pair->{inherit_all};
      $override_target = $type_pair->{override_target} if $type_pair->{override_target};
    }
  }

  # First process any fields that have special treatment
  foreach my $inherit (@{$inheritance->{inherit}}) {
    # Match for this combination of entry and crossref parent?
    foreach my $type_pair (@{$inherit->{type_pair}}) {
      if (($type_pair->{source} eq '*' or $type_pair->{source} eq $parenttype) and
          ($type_pair->{target} eq '*' or $type_pair->{target} eq $type)) {
        foreach my $field (@{$inherit->{field}}) {
          # Skip this field if requested
          if ($field->{skip}) {
            if ($dm->field_is_variant_enabled($field->{source})) {
              $processed->{$field->{source}}
                          {$field->{form} || 'original'}
                          {$field->{lang} || $vlang_s} = 1;
            }
            else {
              $processed->{$field->{source}} = 1;
            }
            next;
          }

          # Ignore inheritance for fields which don't exist in the source
          if ($dm->field_is_variant_enabled($field->{source})) {
            next unless $parent->field_variant_exists($field->{source},
                                                      $field->{source_form},
                                                      $field->{source_lang});
            $processed->{$field->{source}}
                        {$field->{source_form} || 'original'}
                        {$field->{source_lang} || $vlang_s} = 1;
          }
          else {
            if ($field->{source_form} or $field->{source_lang}) {
              $logger->warn("Inheritance - variant specified for non-variant enabled field '" .
                            $field->{source} . "'");
            }
            next unless $parent->field_exists($field->{source});
            $processed->{$field->{source}} = 1;
          }

          # localise defaults according to field, if specified
          my $field_override_target = $field->{override_target} // 'false';

          # For tool mode with bibtex output we need to copy the raw fields
          if (Biber::Config->getoption('tool') and
              Biber::Config->getoption('output_format') eq 'bibtex') {
            $self->set_rawfield($field->{target}, $parent->get_rawfield($field->{source}));
            next;
          }

          # Target is variant
          if ($dm->field_is_variant_enabled($field->{target})) {
            # Target and source are variant
            if ($dm->field_is_variant_enabled($field->{source})) {
              # If no specific variants of a the variant fields specified, inherit all
              if (not $field->{source_form} and
                  not $field->{target_form} and
                  not $field->{source_lang} and
                  not $field->{target_lang} and
                  (not $self->field_variant_exists($field->{target},
                                                   $field->{target_form},
                                                   $field->{target_lang}) or
                   $field_override_target eq 'true')) {
                $logger->debug("Entry '$target_key' is inheriting field '" .
                               $field->{source} .
                               ' (all variants) ' .
                               "' as '" .
                               $field->{target} .
                               ' (all variants) ' .
                               "' from entry '$source_key'");
                $self->set_datafield_forms($field->{target}, $parent->get_field_forms($field->{source}));
                # Record graphing information if required
                if (Biber::Config->getoption('output_format') eq 'dot') {
                  Biber::Config->set_graph('crossref',
                                           $source_key,
                                           $target_key,
                                           $field->{source},
                                           $field->{target});
                }
              }
              # Set the field if it doesn't exist or override is requested
              elsif (not $self->field_variant_exists($field->{target},
                                                     $field->{target_form},
                                                     $field->{target_lang}) or
                     $field_override_target eq 'true') {
                $logger->debug("Entry '$target_key' is inheriting field '" .
                               $field->{source} .
                               ' (form=' .
                               ($field->{source_form} || 'original') .
                               ',' .
                               'lang=' .
                               ($field->{source_lang} || $vlang_s) .
                               ') ' .
                               "' as '" .
                               $field->{target} .
                               ' (form=' .
                               ($field->{target_form} || 'original') .
                               ',' .
                               'lang=' .
                               ($field->{target_lang} || $vlang_t) .
                               ') ' .
                               "' from entry '$source_key'");
                $self->set_datafield($field->{target},
                                     $parent->get_field($field->{source},
                                                        $field->{source_form},
                                                        $field->{source_lang}),
                                     $field->{target_form},
                                     $field->{target_lang});
                # Record graphing information if required
                if (Biber::Config->getoption('output_format') eq 'dot') {
                  Biber::Config->set_graph('crossref',
                                           $source_key,
                                           $target_key,
                                           $field->{source} . $vsplit . ($field->{source_form} || 'original') . $vsplit . ($field->{source_lang} || $vlang_s),
                                           $field->{target} . $vsplit . ($field->{target_form} || 'original') . $vsplit . ($field->{target_lang} || $vlang_t));
                }
              }
            }
            # Target is variant, source is not variant
            else {
              # Set the field if it doesn't exist or override is requested
              if (not $self->field_variant_exists($field->{target},
                                                  $field->{target_form},
                                                  $field->{target_lang}) or
                  $field_override_target eq 'true') {
                $logger->debug("Entry '$target_key' is inheriting field '" .
                               $field->{source} . "' as '" .
                               $field->{target} .
                               ' (form=' . ($field->{target_form} || 'original') . ',' .
                               'lang=' . ($field->{target_lang} || $vlang_t) . ') ' .
                               "' from entry '$source_key'");
                $self->set_datafield($field->{target},
                                     $parent->get_field($field->{source}),
                                     $field->{target_form},
                                     $field->{target_lang});

                # Record graphing information if required
                if (Biber::Config->getoption('output_format') eq 'dot') {
                  Biber::Config->set_graph('crossref',
                                           $source_key,
                                           $target_key,
                                           $field->{source},
                                           $field->{target} . $vsplit . ($field->{target_form} || 'original') . $vsplit . ($field->{target_lang} || $vlang_t));
                }
              }
            }
          }
          # Target is not variant
          else {
            # Target is not variant, source is variant
            if ($dm->field_is_variant_enabled($field->{source})) {
              # Set the field if it doesn't exist or override is requested
              if (not $self->field_exists($field->{target}) or
                  $field_override_target eq 'true') {
                $logger->debug("Entry '$target_key' is inheriting field '" .
                               $field->{source} .
                               ' (form=' . ($field->{source_form} || 'original') . ',' .
                               'lang=' . ($field->{source_lang} || $vlang_s) . ') ' .
                               "' as '" .
                               $field->{target} .
                               "' from entry '$source_key'");
                $self->set_datafield($field->{target},
                                     $parent->get_field($field->{source},
                                                        $field->{source_form},
                                                        $field->{source_lang}));

                # Record graphing information if required
                if (Biber::Config->getoption('output_format') eq 'dot') {
                  Biber::Config->set_graph('crossref',
                                           $source_key,
                                           $target_key,
                                           $field->{source} . $vsplit . ($field->{source_form} || 'original') . $vsplit . ($field->{source_lang} || $vlang_s),
                                           $field->{target});
                }
              }
            }
            # Target is not variant, source is not variant
            else {
              # Set the field if it doesn't exist or override is requested
              if (not $self->field_exists($field->{target}) or
                  $field_override_target eq 'true') {
                $logger->debug("Entry '$target_key' is inheriting field '" .
                               $field->{source} .
                               "' as '" .
                               $field->{target} .
                               "' from entry '$source_key'");
                $self->set_datafield($field->{target}, $parent->get_field($field->{source}));
                # Record graphing information if required
                if (Biber::Config->getoption('output_format') eq 'dot') {
                  Biber::Config->set_graph('crossref',
                                           $source_key,
                                           $target_key,
                                           $field->{source},
                                           $field->{target});
                }
              }
            }
          }
        }
      }
    }
  }

  # Now process the rest of the (original data only) fields, if necessary
  if ($inherit_all eq 'true') {
    my @fields;
    if (Biber::Config->getoption('tool')) {
      @fields = $parent->rawfields;
    }
    else {
      @fields = $parent->datafields;
    }
    foreach my $field (@fields) {
    # variant
      if ($dm->field_is_variant_enabled($field)) {
        foreach my $field ($parent->datafields) {
          if ($dm->field_is_variant_enabled($field)) {
            foreach my $form ($parent->get_field_form_names($field)) {
              foreach my $lang ($parent->get_field_form_lang_names($field, $form)) {
                # Skip if we have already dealt with this field above
                next if $processed->{$field}{$form}{$lang};

                # Set the field if it doesn't exist or override is requested
                if (not $self->field_variant_exists($field, $form, $lang) or
                    $override_target eq 'true') {
                  $logger->debug("Entry '$target_key' is inheriting field '$field " .
                                 "(form=$form, lang=$lang)" . "' from entry '$source_key'");
                  # For tool mode with bibtex output we need to copy the raw fields
                  if (Biber::Config->getoption('tool') and
                      Biber::Config->getoption('output_format') eq 'bibtex') {
                    $self->set_rawfield($field, $parent->get_rawfield($field));
                  }
                  else {
                    $self->set_datafield($field,
                                         $parent->get_field($field, $form, $lang),
                                         $form,
                                         $lang);
                  }
                  # Record graphing information if required
                  if (Biber::Config->getoption('output_format') eq 'dot') {
                    Biber::Config->set_graph('crossref',
                                             $source_key,
                                             $target_key,
                                             "$field$vsplit$form$vsplit$lang",
                                             "$field$vsplit$form$vsplit$lang");
                  }
                }
              }
            }
          }
        }
      }
      else { # non-variant
        # Skip if we have already dealt with this field above
        next if $processed->{$field};

        # Set the field if it doesn't exist or override is requested
        if (not $self->field_exists($field) or $override_target eq 'true') {
          $logger->debug("Entry '$target_key' is inheriting field '$field' from entry '$source_key'");
          # For tool mode with bibtex output we need to copy the raw fields
          if (Biber::Config->getoption('tool') and
              Biber::Config->getoption('output_format') eq 'bibtex') {
            $self->set_rawfield($field, $parent->get_rawfield($field));
          }
          else {
            $self->set_datafield($field, $parent->get_field($field));
          }
        }
        # Record graphing information if required
        if (Biber::Config->getoption('output_format') eq 'dot') {
          Biber::Config->set_graph('crossref', $source_key, $target_key, $field, $field);
        }
      }
    }
  }
  # Datesplit is a special non datafield and needs to be inherited for any
  # validation checks which may occur later
  if (my $ds = $parent->get_field('datesplit')) {
    $self->set_field('datesplit', $ds);
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

François Charette, C<< <firmicus at ankabut.net> >>
Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our Github tracker at
L<https://github.com/plk/biber/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2014 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
