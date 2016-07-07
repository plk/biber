package Biber::DataModel;
use v5.24;
use strict;

use warnings;
no autovivification;

use List::Util qw( first );
use Biber::Config;
use Biber::Utils;
use Biber::Constants;
use Data::Dump qw( pp );
use Log::Log4perl qw( :no_extra_logdie_message );

=encoding utf-8

=head1 NAME

Biber::DataModel


=cut

my $logger = Log::Log4perl::get_logger('main');


=head2 new

    Initialize a Biber::DataModel object

=cut

sub new {
  my $class = shift;
  my $dm = shift;
  my $self;
  $self = bless {}, $class;
#  use Data::Dump;dd($dm);exit 0;

  # Early check for fatal datamodel errors

  # Make sure dates are named *date. A lot of code relies on this.
  foreach my $date (grep {$_->{datatype} eq 'date'} $dm->{fields}{field}->@*) {
    unless ($date->{content} =~ m/date$/) {
      biber_error("Fatal datamodel error: date field '" . $date->{content} . "' must end with string 'date'");
    }
  }

  # Pull out legal entrytypes, fields and constraints and make lookup hash
  # for quick tests later
  foreach my $f ($dm->{fields}{field}->@*) {

    # In case of conflicts, we need to remove the previous definitions since
    # later overrides earlier
    if (my $previous = $self->{fieldsbyname}{$f->{content}}) {

      if ($f->{format}) {
        $self->{fieldsbytype}{$previous->{fieldtype}}{$previous->{datatype}}{$previous->{format}}->@* = grep {$_ ne $f->{content}} $self->{fieldsbytype}{$previous->{fieldtype}}{$previous->{datatype}}{$previous->{format}}->@*;
      }
      $self->{fieldsbytype}{$previous->{fieldtype}}{$previous->{datatype}}{'*'}->@* = grep {$_ ne $f->{content}} $self->{fieldsbytype}{$previous->{fieldtype}}{$previous->{datatype}}{'*'}->@*;
      $self->{fieldsbyfieldtype}{$previous->{fieldtype}}->@* = grep {$_ ne $f->{content}} $self->{fieldsbyfieldtype}{$previous->{fieldtype}}->@*;
      $self->{fieldsbydatatype}{$previous->{datatype}}->@* = grep {$_ ne $f->{content}} $self->{fieldsbydatatype}{$previous->{datatype}}->@*;
      $self->{fieldsbyformat}{$previous->{'format'}}->@* = grep {$_ ne $f->{content}} $self->{fieldsbyformat}{$previous->{format}}->@*;
      delete $self->{fieldsbyname}{$f->{content}};
    }

    $self->{fieldsbyname}{$f->{content}} = {'fieldtype'   => $f->{fieldtype},
                                            'datatype'    => $f->{datatype},
                                            'format'      => $f->{format} || 'default'};
    if ($f->{format}) {
      push $self->{fieldsbytype}{$f->{fieldtype}}{$f->{datatype}}{$f->{format}}->@*, $f->{content};
    }
    push $self->{fieldsbytype}{$f->{fieldtype}}{$f->{datatype}}{'*'}->@*, $f->{content};
    push $self->{fieldsbyfieldtype}{$f->{fieldtype}}->@*, $f->{content};
    push $self->{fieldsbydatatype}{$f->{datatype}}->@*, $f->{content};
    push $self->{fieldsbyformat}{$f->{format} || 'default'}->@*, $f->{content};

    # check null_ok
    if ($f->{nullok}) {
      $self->{fieldsbyname}{$f->{content}}{nullok} = 1;
    }
    # check skips - fields we don't want to output to .bbl
    if ($f->{skip_output}) {
      $self->{fieldsbyname}{$f->{content}}{skipout} = 1;
    }
  }

  my $constants;
  foreach my $constant ($dm->{constants}{constant}->@*) {
    $self->{constants}{$constant->{name}}{type} = $constant->{type};
    $self->{constants}{$constant->{name}}{value} = $constant->{content};
  }

  my $leg_ents;
  foreach my $et ($dm->{entrytypes}{entrytype}->@*) {
    my $es = $et->{content};

    # Skip output flag for certain entrytypes
    if ($et->{skip_output}) {
      $leg_ents->{$es}{skipout} = 1;
    }
    # fields for entrytypes
    my $lfs;
    foreach my $ef ($dm->{entryfields}->@*) {
      # Found a section describing legal fields for entrytype
      if (not exists($ef->{entrytype}) or
          grep {$_->{content} eq $es} $ef->{entrytype}->@*) {
        foreach my $f ($ef->{field}->@*) {
          $lfs->{$f->{content}} = 1;
        }
      }
    }

    # constraints
    my $constraints;
    foreach my $cd ($dm->{constraints}->@*) {
      # Found a section describing constraints for entrytype
      if (not exists($cd->{entrytype}) or
          grep {$_->{content} eq $es} $cd->{entrytype}->@*) {
        foreach my $c ($cd->{constraint}->@*) {
          if ($c->{type} eq 'mandatory') {
            # field
            foreach my $f ($c->{field}->@*) {
              push $constraints->{mandatory}->@*, $f->{content};
            }
            # xor set of fields
            # [ XOR, field1, field2, ... , fieldn ]
            foreach my $fxor ($c->{fieldxor}->@*) {
              my $xorset;
              foreach my $f ($fxor->{field}->@*) {
                push $xorset->@*, $f->{content};
              }
              unshift $xorset->@*, 'XOR';
              push $constraints->{mandatory}->@*, $xorset;
            }
            # or set of fields
            # [ OR, field1, field2, ... , fieldn ]
            foreach my $for ($c->{fieldor}->@*) {
              my $orset;
              foreach my $f ($for->{field}->@*) {
                push $orset->@*, $f->{content};
              }
              unshift $orset->@*, 'OR';
              push $constraints->{mandatory}->@*, $orset;
            }
          }
          # Conditional constraints
          # [ ANTECEDENT_QUANTIFIER
          #   [ ANTECEDENT LIST ]
          #   CONSEQUENT_QUANTIFIER
          #   [ CONSEQUENT LIST ]
          # ]
          elsif ($c->{type} eq 'conditional') {
            my $cond;
            $cond->[0] = $c->{antecedent}{quant};
            $cond->[1] = [ map { $_->{content} } $c->{antecedent}{field}->@* ];
            $cond->[2] = $c->{consequent}{quant};
            $cond->[3] = [ map { $_->{content} } $c->{consequent}{field}->@* ];
            push $constraints->{conditional}->@*, $cond;
          }
          # data constraints
          elsif ($c->{type} eq 'data') {
            my $data;
            $data->{fields} = [ map { $_->{content} } $c->{field}->@* ];
            $data->{datatype} = $c->{datatype};
            $data->{rangemin} = $c->{rangemin};
            $data->{rangemax} = $c->{rangemax};
            $data->{pattern} = $c->{pattern};
            push $constraints->{data}->@*, $data;
          }
        }
      }
    }
    $leg_ents->{$es}{legal_fields} = $lfs;
    $leg_ents->{$es}{constraints} = $constraints;
  }
  $self->{entrytypesbyname} = $leg_ents;

  # Calculate and store some convenient lists of DM fields. This is to save the expense
  # of constructing these in dense loops like entry processing/output.
  # Mostly only used for .bbl output since that's the most commonly used one and so
  # we care about performance there. Other output formats are not often used and so a few
  # seconds difference is irrelevant.
  $self->{helpers} = {namelistsall => [sort $self->get_fields_of_type('list', 'name')->@*],
                      namelists => [sort grep
                                    {not $self->field_is_skipout($_)}
                                    $self->get_fields_of_type('list', 'name')->@*],
                      lists     => [sort grep
                                    {
                                      not $self->field_is_datatype('name', $_) and
                                        not $self->field_is_skipout($_) and
                                          not $self->field_is_datatype('verbatim', $_) and
                                            not $self->field_is_datatype('uri', $_)
                                    }
                                    $self->get_fields_of_fieldtype('list')->@*],
                      fields    => [sort grep
                                    {
                                      not $self->field_is_skipout($_) and
                                        not $self->get_fieldformat($_) eq 'xsv'
                                    }
                                    $self->get_fields_of_type('field',
                                                              ['entrykey',
                                                               'key',
                                                               'integer',
                                                               'datepart',
                                                               'literal',
                                                               'code'])->@*],
                      datefields   => [sort $self->get_fields_of_type('field', 'date')->@*],
                      dateparts    => [sort $self->get_fields_of_type('field', 'datepart')->@*],
                      xsv       => [sort grep
                                    {
                                      not $self->field_is_skipout($_) and
                                        not $self->get_datatype($_) eq 'keyword'
                                    }
                                    $self->get_fields_of_fieldformat('xsv')->@*],
                      ranges    => [sort grep
                                    {
                                      not $self->field_is_skipout($_)
                                    }
                                    $self->get_fields_of_datatype('range')->@*],
                      uris      => [sort grep
                                    {
                                      not $self->field_is_skipout($_);
                                    }
                                    $self->get_fields_of_type('field', 'uri')->@*],
                      urils     => [sort grep
                                    {
                                      not $self->field_is_skipout($_);
                                    }
                                    $self->get_fields_of_type('list', 'uri')->@*],
                      vfields   => [sort grep
                                    {
                                      not $self->field_is_skipout($_);
                                    }
                                    $self->get_fields_of_type('field', ['verbatim', 'uri'])->@*],
                      vlists    => [sort grep
                                    {
                                      not $self->field_is_skipout($_);
                                    }
                                    $self->get_fields_of_type('list', ['verbatim', 'uri'])->@*],
                      integers  => [sort $self->get_fields_of_datatype(['datepart', 'integer'])->@*]
                     };
  # Mapping of sorting fields to Sort::Key sort data types which are not 'str'
  $self->{sortdataschema} = sub {
    my $f = shift;
    if (first {$f eq $_} ('citeorder', $self->{helpers}{integers}->@*)) {
      return 'int';
    }
    else {
      return 'str';
    }
  };

#  use Data::Dump;dd($self);exit 0;
  return $self;
}

=head2 constants

    Returns array ref of constant names

=cut

sub constants {
  my $self = shift;
  return [ keys $self->{constants}->%* ];
}

=head2 get_constant_type

    Returns a constant type

=cut

sub get_constant_type {
  my ($self, $name) = @_;
  return $self->{constants}{$name}{type};
}

=head2 get_constant_value

    Returns a constant value

=cut

sub get_constant_value {
  my ($self, $name) = @_;
  if ($self->{constants}{$name}{type} eq 'list') {
    return split(/\s*,\s*/, $self->{constants}{$name}{value});
  }
  elsif ($self->{constants}{$name}{type} eq 'string') {
    return $self->{constants}{$name}{value};
  }
}


=head2 fieldtypes

    Returns array ref of legal fieldtypes

=cut

sub fieldtypes {
  my $self = shift;
  return [ keys $self->{fieldsbyfieldtype}->%* ];
}

=head2 datatypes

    Returns array ref of legal datatypes

=cut

sub datatypes {
  my $self = shift;
  return [ keys $self->{fieldsbydatatype}->%* ];
}


=head2 is_field

    Returns boolean to say if a field is a legal field.
    Allows for fields with meta markers whose marked field should be in
    the datamodel.

=cut

sub is_field {
  my $self = shift;
  my $field = shift;
  my $ann = $CONFIG_META_MARKERS{annotation};

  if ($field =~ m/^(.+)(?:$ann)$/) {
    return $self->{fieldsbyname}{$1} ? 1 : 0;
  }
  else {
    return $self->{fieldsbyname}{$field} ? 1 : 0;
  }
}

=head2 entrytypes

    Returns array ref of legal entrytypes

=cut

sub entrytypes {
  my $self = shift;
  return [ keys $self->{entrytypesbyname}->%* ];
}


=head2 is_entrytype

    Returns boolean to say if an entrytype is a legal entrytype

=cut

sub is_entrytype {
  my $self = shift;
  my $type = shift;
  return $self->{entrytypesbyname}{$type} ? 1 : 0;
}

=head2 is_field_for_entrytype

    Returns boolean to say if a field is legal for an entrytype

=cut

sub is_field_for_entrytype {
  my $self = shift;
  my ($type, $field) = @_;
  if ($self->{entrytypesbyname}{$type}{legal_fields}{$field}) {
    return 1;
  }
  else {
    return 0;
  }
}

=head2 entrytype_is_skipout

    Returns boolean depending on whether an entrytype is to be skipped on output

=cut

sub entrytype_is_skipout {
  my ($self, $type) = @_;
  return $self->{entrytypesbyname}{$type}{skipout} // 0;
}


=head2 get_fields_of_fieldtype

    Retrieve fields of a certain biblatex fieldtype from data model
    Return in sorted order so that bbl order doesn't change when changing
    .bcf. This really messes up tests otherwise.

=cut

sub get_fields_of_fieldtype {
  my ($self, $fieldtype) = @_;
  my $f = $self->{fieldsbyfieldtype}{$fieldtype};
  return $f ? [ sort $f->@* ] : [];
}

=head2 get_fields_of_fieldformat

    Retrieve fields of a certain format from data model
    Return in sorted order so that bbl order doesn't change when changing
    .bcf. This really messes up tests otherwise.

=cut

sub get_fields_of_fieldformat {
  my ($self, $format) = @_;
  my $f = $self->{fieldsbyformat}{$format};
  return $f ? [ sort $f->@* ] : [];
}


=head2 get_fields_of_datatype

    Retrieve fields of a certain biblatex datatype from data model
    Return in sorted order so that bbl order doesn't change when changing
    .bcf. This really messes up tests otherwise.

=cut

sub get_fields_of_datatype {
  my ($self, $datatype) = @_;
  my @f;
  # datatype can be array ref of datatypes - makes some calls cleaner
  if (ref($datatype) eq 'ARRAY') {
    foreach my $dt ($datatype->@*) {
      if (my $fs = $self->{fieldsbydatatype}{$dt}) {
        push @f, $fs->@*;
      }
    }
  }
  else {
    if (my $fs = $self->{fieldsbydatatype}{$datatype}) {
      push @f, $fs->@*;
    }
  }
  return [ sort @f ];
}


=head2 get_fields_of_type

    Retrieve fields of a certain biblatex type from data model
    Return in sorted order so that bbl order doesn't change when changing
    .bcf. This really messes up tests otherwise.

=cut

sub get_fields_of_type {
  my ($self, $fieldtype, $datatype, $format) = @_;
  my @f;
  $format //= '*';

  # datatype can be array ref of datatypes - makes some calls cleaner
  if (ref($datatype) eq 'ARRAY') {
    foreach my $dt ($datatype->@*) {
      if (my $fs = $self->{fieldsbytype}{$fieldtype}{$dt}{$format}) {
        push @f, $fs->@*;
      }
    }
  }
  else {
    if (my $fs = $self->{fieldsbytype}{$fieldtype}{$datatype}{$format}) {
      push @f, $fs->@*;
    }
  }

  return [ sort @f ];
}

=head2 is_fields_of_type

  Returns boolean to say if the given fieldtype/datatype/format is a valid combination

=cut

sub is_fields_of_type {
  my ($self, $fieldtype, $datatype, $format) = @_;
  my $f;
  if ($format) {
    return exists($self->{fieldsbytype}{$fieldtype}{$datatype}{$format}) ? 1 : 0;
  }
  else {
    return exists($self->{fieldsbytype}{$fieldtype}{$datatype}) ? 1 : 0;
  }
}

=head2 get_fieldtype

    Returns the fieldtype of a field

=cut

sub get_fieldtype {
  my ($self, $field) = @_;
  return $self->{fieldsbyname}{$field}{fieldtype};
}

=head2 get_datatype

    Returns the datatype of a field

=cut

sub get_datatype {
  my ($self, $field) = @_;
  return $self->{fieldsbyname}{$field}{datatype};
}

=head2 get_fieldformat

    Returns the format of a field

=cut

sub get_fieldformat {
  my ($self, $field) = @_;
  return $self->{fieldsbyname}{$field}{format};
}


=head2 get_dm_for_field

    Returns the fieldtype, datatype and format of a field

=cut

sub get_dm_for_field {
  my ($self, $field) = @_;
  return {'fieldtype' =>  $self->{fieldsbyname}{$field}{fieldtype},
          'datatype'  => $self->{fieldsbyname}{$field}{datatype},
          'format'    => $self->{fieldsbyname}{$field}{format}};
}

=head2 field_is_fieldtype

    Returns boolean depending on whether a field is a certain biblatex fieldtype

=cut

sub field_is_fieldtype {
  my ($self, $fieldtype, $field) = @_;
  return $self->{fieldsbyname}{$field}{fieldtype} eq $fieldtype ? 1 : 0;
}

=head2 field_is_datatype

    Returns boolean depending on whether a field is a certain biblatex datatype

=cut

sub field_is_datatype {
  my ($self, $datatype, $field) = @_;
  return $self->{fieldsbyname}{$field}{datatype} eq $datatype ? 1 : 0;
}


=head2 field_is_type

    Returns boolean depending on whether a field is a certain biblatex fieldtype
    and datatype

=cut

sub field_is_type {
  my ($self, $fieldtype, $datatype, $field) = @_;
  if ($self->{fieldsbyname}{$field} and
      $self->{fieldsbyname}{$field}{fieldtype} eq $fieldtype and
      $self->{fieldsbyname}{$field}{datatype} eq $datatype) {
    return 1;
  }
  else {
    return 0;
  }
}

=head2 field_is_nullok

    Returns boolean depending on whether a field is ok to be null

=cut

sub field_is_nullok {
  my ($self, $field) = @_;
  return $self->{fieldsbyname}{$field}{nullok} // 0;
}

=head2 field_is_skipout

    Returns boolean depending on whether a field is to be skipped on output

=cut

sub field_is_skipout {
  my ($self, $field) = @_;
  return $self->{fieldsbyname}{$field}{skipout} // 0;
}

=head2 check_mandatory_constraints

    Checks constraints of type "mandatory" on entry and
    returns an arry of warnings, if any

=cut

sub check_mandatory_constraints {
  my $self = shift;
  my $be = shift;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my @warnings;
  my $et = $be->get_field('entrytype');
  my $key = $be->get_field('citekey');
  my $ds = $section->get_keytods($key);

  foreach my $c ($self->{entrytypesbyname}{$et}{constraints}{mandatory}->@*) {
    if (ref($c) eq 'ARRAY') {
      # Exactly one of a set is mandatory
      if ($c->[0] eq 'XOR') {
        my @fs = $c->@[1,-1]; # Lose the first element which is the 'XOR'
        my $flag = 0;
        my $xorflag = 0;
        foreach my $of (@fs) {
          if ($be->field_exists($of) and
              # ignore date field if it has been split into parts
              not ($of eq 'date' and $be->get_field('datesplit'))) {
            if ($xorflag) {
              push @warnings, "Datamodel: Entry '$key' ($ds): Mandatory fields - only one of '" . join(', ', @fs) . "' must be defined - ignoring field '$of'";
              $be->del_field($of);
            }
            $flag = 1;
            $xorflag = 1;
          }
        }
        unless ($flag) {
          push @warnings, "Datamodel: Entry '$key' ($ds): Missing mandatory field - one of '" . join(', ', @fs) . "' must be defined";
        }
      }
      # One or more of a set is mandatory
      elsif ($c->[0] eq 'OR') {
        my @fs = $c->@[1,-1]; # Lose the first element which is the 'OR'
        my $flag = 0;
        foreach my $of (@fs) {
          if ($be->field_exists($of)) {
            $flag = 1;
            last;
          }
        }
        unless ($flag) {
          push @warnings, "Datamodel: Entry '$key' ($ds): Missing mandatory field - one of '" . join(', ', @fs) . "' must be defined";
        }
      }
    }
    # Simple mandatory field
    else {
      unless ($be->field_exists($c)) {
        push @warnings, "Datamodel: Entry '$key' ($ds): Missing mandatory field '$c'";
      }
    }
  }
  return @warnings;
}

=head2 check_conditional_constraints

    Checks constraints of type "conditional" on entry and
    returns an arry of warnings, if any

=cut

sub check_conditional_constraints {
  my $self = shift;
  my $be = shift;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my @warnings;
  my $et = $be->get_field('entrytype');
  my $key = $be->get_field('citekey');
  my $ds = $section->get_keytods($key);

  foreach my $c ($self->{entrytypesbyname}{$et}{constraints}{conditional}->@*) {
    my $aq  = $c->[0];          # Antecedent quantifier
    my $afs = $c->[1];          # Antecedent fields
    my $cq  = $c->[2];          # Consequent quantifier
    my $cfs = $c->[3];          # Consequent fields
    my @actual_afs = (grep {$be->field_exists($_)} $afs->@*); # antecedent fields in entry
    # check antecedent
    if ($aq eq 'all') {
      next unless $afs->$#* == $#actual_afs; # ALL -> ? not satisfied
    }
    elsif ($aq eq 'none') {
      next if @actual_afs;      # NONE -> ? not satisfied
    }
    elsif ($aq eq 'one') {
      next unless @actual_afs;  # ONE -> ? not satisfied
    }

    # check consequent
    my @actual_cfs = (grep {$be->field_exists($_)} $cfs->@*);
    if ($cq eq 'all') {
      unless ($cfs->$#* == $#actual_cfs) { # ? -> ALL not satisfied
        push @warnings, "Datamodel: Entry '$key' ($ds): Constraint violation - $cq of fields (" .
          join(', ', $cfs->@*) .
            ") must exist when $aq of fields (" . join(', ', $afs->@*). ") exist";
      }
    }
    elsif ($cq eq 'none') {
      if (@actual_cfs) {        # ? -> NONE not satisfied
        push @warnings, "Datamodel: Entry '$key' ($ds): Constraint violation - $cq of fields (" .
          join(', ', @actual_cfs) .
            ") must exist when $aq of fields (" . join(', ', $afs->@*). ") exist. Ignoring them.";
        # delete the offending fields
        foreach my $f (@actual_cfs) {
          $be->del_field($f);
        }
      }
    }
    elsif ($cq eq 'one') {
      unless (@actual_cfs) {    # ? -> ONE not satisfied
        push @warnings, "Datamodel: Entry '$key' ($ds): Constraint violation - $cq of fields (" .
          join(', ', $cfs->@*) .
            ") must exist when $aq of fields (" . join(', ', $afs->@*). ") exist";
      }
    }
  }
  return @warnings;
}

=head2 check_data_constraints

    Checks constraints of type "data" on entry and
    returns an array of warnings, if any

=cut

sub check_data_constraints {
  my $self = shift;
  my $be = shift;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);
  my @warnings;
  my $et = $be->get_field('entrytype');
  my $key = $be->get_field('citekey');
  my $ds = $section->get_keytods($key);

  foreach my $c ($self->{entrytypesbyname}{$et}{constraints}{data}->@*) {
    # This is the datatype of the constraint, not the field!
    if ($c->{datatype} eq 'isbn') {
      foreach my $f ($c->{fields}->@*) {
        if (my $fv = $be->get_field($f)) {
          require Business::ISBN;
          my ($vol, $dir, undef) = File::Spec->splitpath( $INC{"Business/ISBN.pm"} );
          $dir =~ s/\/$//; # splitpath sometimes leaves a trailing '/'
          # Just in case it is already set. We also need to fake this in tests or it will
          # look for it in the blib dir
          unless (exists($ENV{ISBN_RANGE_MESSAGE})) {
            $ENV{ISBN_RANGE_MESSAGE} = File::Spec->catpath($vol, "$dir/ISBN/", 'RangeMessage.xml');
          }
          # Treat as a list field just in case someone has made it so in a custom datamodel
          unless ($self->get_fieldtype($f) eq 'list') {
            $fv = [$fv];
          }
          foreach ($fv->@*) {
            my $isbn = Business::ISBN->new($_);
            if (not $isbn) {
              push @warnings, "Datamodel: Entry '$key' ($ds): Invalid ISBN in value of field '$f'";
            }
            # Business::ISBN has an error() method so we might get more information
            elsif (not $isbn->is_valid) {
              push @warnings, "Datamodel: Entry '$key' ($ds): Invalid ISBN in value of field '$f' (" . $isbn->error. ')';
            }
          }
        }
      }
    }
    elsif ($c->{datatype} eq 'issn') {
      foreach my $f ($c->{fields}->@*) {
        if (my $fv = $be->get_field($f)) {
          require Business::ISSN;
          # Treat as a list field just in case someone has made it so in a custom datamodel
          unless ($self->get_fieldtype($f) eq 'list') {
            $fv = [$fv];
          }
          foreach ($fv->@*) {
            my $issn = Business::ISSN->new($_);
            unless ($issn and $issn->is_valid) {
              push @warnings, "Datamodel: Entry '$key' ($ds): Invalid ISSN in value of field '$f'";
            }
          }
        }
      }
    }
    elsif ($c->{datatype} eq 'ismn') {
      foreach my $f ($c->{fields}->@*) {
        if (my $fv = $be->get_field($f)) {
          require Business::ISMN;
          # Treat as a list field just in case someone has made it so in a custom datamodel
          unless ($self->get_fieldtype($f) eq 'list') {
            $fv = [$fv];
          }
          foreach ($fv->@*) {
            my $ismn = Business::ISMN->new($_);
            unless ($ismn and $ismn->is_valid) {
              push @warnings, "Datamodel: Entry '$key' ($ds): Invalid ISMN in value of field '$f'";
            }
          }
        }
      }
    }
    elsif ($c->{datatype} eq 'integer' or
           $c->{datatype} eq 'datepart') {
      my $dt = $DM_DATATYPES{$c->{datatype}};
      foreach my $f ($c->{fields}->@*) {
        if (my $fv = $be->get_field($f)) {
          unless ( $fv =~ /$dt/ ) {
            push @warnings, "Datamodel: Entry '$key' ($ds): Invalid format (" . $c->{datatype}. ") of field '$f' - ignoring field";
            $be->del_field($f);
            next;
          }
          if (my $fmin = $c->{rangemin}) {
            unless ($fv >= $fmin) {
              push @warnings, "Datamodel: Entry '$key' ($ds): Invalid value of field '$f' must be '>=$fmin' - ignoring field";
              $be->del_field($f);
              next;
            }
          }
          if (my $fmax = $c->{rangemax}) {
            unless ($fv <= $fmax) {
              push @warnings, "Datamodel: Entry '$key' ($ds): Invalid value of field '$f' must be '<=$fmax' - ignoring field";
              $be->del_field($f);
              next;
            }
          }
        }
      }
    }
    elsif ($c->{datatype} eq 'pattern') {
      my $patt;
      unless ($patt = $c->{pattern}) {
        push @warnings, "Datamodel: Pattern constraint has no pattern!";
      }
      foreach my $f ($c->{fields}->@*) {
        if (my $fv = $be->get_field($f)) {
          unless (imatch($fv, $patt)) {
            push @warnings, "Datamodel: Entry '$key' ($ds): Invalid value (pattern match fails) for field '$f'";
          }
        }
      }
    }
  }
  return @warnings;
}

=head2 dump

    Dump Biber::DataModel object

=cut

sub dump {
  my $self = shift;
  return pp($self);
}

=head2 generate_bltxml_schema

    Generate a RelaxNG XML schema from the datamodel for BibLaTeXML datasources

=cut

sub generate_bltxml_schema {
  my ($dm, $outfile) = @_;
  return if $dm->{bltxml_schema_gen_done};

  # Set the .rng path to the output dir, if specified
  if (my $outdir = Biber::Config->getoption('output_directory')) {
    my (undef, undef, $file) = File::Spec->splitpath($outfile);
    $outfile = File::Spec->catfile($outdir, $file)
  }
  my $rng = IO::File->new($outfile, '>:encoding(UTF-8)');
  $rng->autoflush;# Needed for running tests to string refs

  $logger->info("Writing BibLaTeXML RNG schema '$outfile' for datamodel");
  require XML::Writer;
  my $bltx_ns = 'http://biblatex-biber.sourceforge.net/biblatexml';
  my $bltx = 'bltx';
  my $default_ns = 'http://relaxng.org/ns/structure/1.0';
  my $writer = new XML::Writer(NAMESPACES   => 1,
                               ENCODING     => 'UTF-8',
                               DATA_MODE    => 1,
                               DATA_INDENT  => 2,
                               OUTPUT       => $rng,
                               PREFIX_MAP   => {$bltx_ns    => $bltx,
                                                $default_ns => ''});

  $writer->xmlDecl();
  $writer->comment('Auto-generated from .bcf Datamodel');
  $writer->forceNSDecl($default_ns);
  $writer->forceNSDecl($bltx_ns);
  $writer->startTag('grammar',
                    'datatypeLibrary' => 'http://www.w3.org/2001/XMLSchema-datatypes');
  $writer->startTag('start');
  $writer->startTag('element', 'name' => "$bltx:entries");
  $writer->startTag('oneOrMore');
  $writer->startTag('element', 'name' => "$bltx:entry");
  $writer->emptyTag('attribute', 'name' => 'id');
  $writer->startTag('attribute', 'name' => 'entrytype');
  $writer->startTag('choice');
  foreach my $entrytype ($dm->entrytypes->@*) {
    $writer->dataElement('value', $entrytype);
  }
  $writer->endTag();# choice
  $writer->endTag();# attribute
  $writer->startTag('interleave');

  foreach my $ft ($dm->fieldtypes->@*) {
    foreach my $dt ($dm->datatypes->@*) {
      if ($dm->is_fields_of_type($ft, $dt)) {
        next if $dt eq 'datepart'; # not legal in input, only output
        $writer->comment("$dt ${ft}s");
        $writer->emptyTag('ref', 'name' => "$dt$ft");
      }
    }
  }

  $writer->endTag();# interleave
  $writer->endTag();# entry element
  $writer->endTag();# oneOrMore
  $writer->endTag();# entries element
  $writer->endTag();# start

  foreach my $ft ($dm->fieldtypes->@*) {
    foreach my $dt ($dm->datatypes->@*) {
      if ($dm->is_fields_of_type($ft, $dt)) {
        next if $dt eq 'datepart'; # not legal in input, only output
        $writer->comment("$dt ${ft}s definition");
        $writer->startTag('define', 'name' => "$dt$ft");

        # Name lists element definition
        # =============================
        if ($ft eq 'list' and $dt eq 'name') {
          $writer->startTag('zeroOrMore');# for example, XDATA doesn't need a name
          $writer->startTag('element', 'name' => "$bltx:names");

          # useprefix attribute
          $writer->comment('useprefix option');
          $writer->startTag('optional');
          $writer->startTag('attribute', 'name' => 'useprefix');
          $writer->emptyTag('data', 'type' => 'boolean');
          $writer->endTag();    # attribute
          $writer->endTag();    # optional

          # sortnamekeyscheme attribute
          $writer->comment('sortnamekeyscheme option');
          $writer->startTag('optional');
          $writer->startTag('attribute', 'name' => 'sortnamekeyscheme');
          $writer->emptyTag('data', 'type' => 'string');
          $writer->endTag();    # attribute
          $writer->endTag();    # optional

          # type attribute
          $writer->comment('types of names elements');
          $writer->startTag('attribute', 'name' => 'type');
          $writer->startTag('choice');
          foreach my $name ($dm->get_fields_of_type($ft, $dt)->@*) {
            $writer->dataElement('value', $name);
          }
          $writer->endTag();    # choice
          $writer->endTag();    # attribute

          # morenames attribute
          $writer->startTag('optional');
          $writer->startTag('attribute', 'name' => 'morenames');
          $writer->emptyTag('data', 'type' => 'boolean');
          $writer->endTag();    # attribute
          $writer->endTag();    # optional

          # generic annotation attribute
          $writer->emptyTag('ref', 'name' => "annotation");

          $writer->startTag('oneOrMore');

          # Individual name element
          $writer->startTag('element', 'name' => "$bltx:name");

          # useprefix attribute
          $writer->comment('useprefix option');
          $writer->startTag('optional');
          $writer->startTag('attribute', 'name' => 'useprefix');
          $writer->emptyTag('data', 'type' => 'boolean');
          $writer->endTag();    # attribute
          $writer->endTag();    # optional

          # sortnamekeyscheme attribute
          $writer->comment('sortnamekeyscheme option');
          $writer->startTag('optional');
          $writer->startTag('attribute', 'name' => 'sortnamekeyscheme');
          $writer->emptyTag('data', 'type' => 'string');
          $writer->endTag();    # attribute
          $writer->endTag();    # optional

          # gender attribute ref
          $writer->emptyTag('ref', 'name' => 'gender');

          # generic annotation attribute
          $writer->emptyTag('ref', 'name' => "annotation");

          # namepart element
          $writer->startTag('oneOrMore');
          $writer->startTag('element', 'name' => "$bltx:namepart");
          $writer->startTag('attribute', 'name' => 'type');
          $writer->startTag('choice');
          foreach my $np ($dm->get_constant_value('nameparts')) {# list type so returns list
            $writer->dataElement('value', $np);
          }
          $writer->endTag();    # choice
          $writer->endTag();    # attribute
          $writer->startTag('optional');
          $writer->emptyTag('attribute', 'name' => 'initial');
          $writer->endTag();    # optional

          # generic annotation attribute
          $writer->emptyTag('ref', 'name' => "annotation");

          $writer->startTag('choice');
          $writer->emptyTag('text');# text
          $writer->startTag('oneOrMore');
          $writer->startTag('element', 'name' => "$bltx:namepart");
          $writer->startTag('optional');
          $writer->emptyTag('attribute', 'name' => 'initial');
          $writer->endTag();    # optional
          $writer->emptyTag('text');# text
          $writer->endTag();    # (sub)namepart element
          $writer->endTag();    # oneOrMore
          $writer->endTag();    # choice
          $writer->endTag();    # namepart element
          $writer->endTag();    # oneOrMore
          $writer->endTag();    # name element
          $writer->endTag();    # oneOrMore
          $writer->endTag();    # names element
          $writer->endTag();    # zeroOrMore
          # ========================
        }
        elsif ($ft eq 'list') {
          # lists element definition
          # ========================
          $writer->startTag('interleave');
          foreach my $list ($dm->get_fields_of_type($ft, $dt)->@*) {
            $writer->startTag('optional');
            $writer->startTag('element', 'name' => "$bltx:$list");

            # generic annotation attribute
            $writer->emptyTag('ref', 'name' => "annotation");

            $writer->startTag('choice');
            $writer->emptyTag('text');# text
            $writer->startTag('element', 'name' => "$bltx:list");
            $writer->startTag('oneOrMore');
            $writer->startTag('element', 'name' => "$bltx:item");

            # generic annotation attribute
            $writer->emptyTag('ref', 'name' => "annotation");

            $writer->emptyTag('text');# text
            $writer->endTag(); # item element
            $writer->endTag(); # oneOrMore element
            $writer->endTag(); # list element
            $writer->endTag(); # choice
            $writer->endTag(); # $list element
            $writer->endTag(); # optional
          }
          $writer->endTag();# interleave
          # ========================
        }
        elsif ($ft eq 'field' and $dt eq 'uri') {
          # uri field element definition
          # ============================
          $writer->startTag('interleave');
          foreach my $field ($dm->get_fields_of_type($ft, $dt)->@*) {
            $writer->startTag('optional');
            $writer->startTag('element', 'name' => "$bltx:$field");

            # generic annotation attribute
            $writer->emptyTag('ref', 'name' => "annotation");

            $writer->emptyTag('data', 'type' => 'anyURI');
            $writer->endTag();   # $field element
            $writer->endTag();# optional
          }
          $writer->endTag();# interleave
          # ============================
        }
        elsif ($ft eq 'field' and $dt eq 'range') {
          # range field element definition
          # ==============================
          $writer->startTag('interleave');
          foreach my $field ($dm->get_fields_of_type($ft, $dt)->@*) {
            $writer->startTag('optional');
            $writer->startTag('element', 'name' => "$bltx:$field");

            # generic annotation attribute
            $writer->emptyTag('ref', 'name' => "annotation");

            $writer->startTag('element', 'name' => "$bltx:list");
            $writer->startTag('oneOrMore');
            $writer->startTag('element', 'name' => "$bltx:item");
            $writer->startTag('element', 'name' => "$bltx:start");
            $writer->emptyTag('text');
            $writer->endTag();  # start element
            $writer->startTag('element', 'name' => "$bltx:end");
            $writer->startTag('choice');
            $writer->emptyTag('text');
            $writer->emptyTag('empty');
            $writer->endTag();  # choice
            $writer->endTag();  # end element
            $writer->endTag(); # item element
            $writer->endTag();   # oneOrMore element
            $writer->endTag();  # list element
            $writer->endTag();   # $field element
            $writer->endTag();# optional
          }
          $writer->endTag();# interleave
          # ==============================
        }
        elsif ($ft eq 'field' and $dt eq 'entrykey') {
          # entrykey field element definition
          # =================================
          $writer->startTag('interleave');
          foreach my $field ($dm->get_fields_of_type($ft, $dt)->@*) {
            $writer->startTag('optional');
            # related field is special
            if ($field eq 'related') {
              $writer->startTag('element', 'name' => "$bltx:$field");
              $writer->startTag('element', 'name' => "$bltx:list");
              $writer->startTag('oneOrMore');
              $writer->startTag('element', 'name' => "$bltx:item");
              $writer->emptyTag('attribute', 'name' => 'type');
              $writer->emptyTag('attribute', 'name' => 'ids');
              $writer->startTag('optional');
              $writer->emptyTag('attribute', 'name' => 'string');
              $writer->endTag(); # optional
              $writer->startTag('optional');
              $writer->emptyTag('attribute', 'name' => 'options');
              $writer->endTag(); # optional
              $writer->endTag(); # item element
              $writer->endTag(); # oneOrMore
              $writer->endTag(); # list element
              $writer->endTag(); # $field element
            }
            else {
              $writer->startTag('element', 'name' => "$bltx:$field");

              # generic annotation attribute
              $writer->emptyTag('ref', 'name' => "annotation");

              $writer->startTag('choice');
              $writer->startTag('list');
              $writer->startTag('oneOrMore');
              $writer->emptyTag('data', 'type' => 'string');
              $writer->endTag(); # oneOrMore
              $writer->endTag();    # list
              $writer->startTag('oneOrMore');
              $writer->startTag('element', 'name' => "$bltx:key");
              $writer->emptyTag('text');# text
              $writer->endTag(); # key element
              $writer->endTag(); # oneOrMore
              $writer->endTag(); # choice
              $writer->endTag(); # $field element
            }
            $writer->endTag(); # optional
          }
          $writer->endTag();# interleave
        }
        elsif ($ft eq 'field' and $dt eq 'date') {
          # date field element definition
          # =============================
          my @types = map { s/date$//r } $dm->get_fields_of_type($ft, $dt)->@*;
          $writer->startTag('zeroOrMore');
          $writer->startTag('element', 'name' => "$bltx:date");
          $writer->startTag('optional');
          $writer->startTag('attribute', 'name' => 'type');
          $writer->startTag('choice');
          foreach my $datetype(@types) {
            next unless $datetype;
            $writer->dataElement('value', $datetype);
          }
          $writer->endTag(); # choice
          $writer->endTag(); # attribute
          $writer->endTag(); # optional

          # generic annotation attribute
          $writer->emptyTag('ref', 'name' => "annotation");

          $writer->startTag('choice');
          $writer->emptyTag('data', 'type' => 'date');
          $writer->emptyTag('data', 'type' => 'gYear');
          $writer->startTag('group');
          $writer->startTag('element', 'name' => "$bltx:start");
          $writer->startTag('choice');
          $writer->emptyTag('data', 'type' => 'date');
          $writer->emptyTag('data', 'type' => 'gYear');
          $writer->endTag(); # choice
          $writer->endTag(); # start element
          $writer->startTag('element', 'name' => "$bltx:end");
          $writer->startTag('choice');
          $writer->emptyTag('data', 'type' => 'date');
          $writer->emptyTag('data', 'type' => 'gYear');
          $writer->emptyTag('empty');
          $writer->endTag(); # choice
          $writer->endTag(); # end element
          $writer->endTag(); # group
          $writer->endTag(); # choice
          $writer->endTag(); # $field element
          $writer->endTag(); # zeroOrMore
          # =============================
        }
        elsif ($ft eq 'field') {
          # field element definition
          # ========================
          $writer->startTag('interleave');
          foreach my $field ($dm->get_fields_of_type($ft, $dt)->@*) {
            $writer->startTag('optional');
            $writer->startTag('element', 'name' => "$bltx:$field");

            # generic annotation attribute
            $writer->emptyTag('ref', 'name' => "annotation");

            $writer->emptyTag('text');# text
            $writer->endTag(); # $field element
            $writer->endTag();# optional
          }
          $writer->endTag();# interleave
          # ========================
        }
        $writer->endTag(); # define
      }
    }
  }

  # gender attribute definition
  # ===========================
  $writer->comment('gender attribute definition');
  $writer->startTag('define', 'name' => 'gender');
  $writer->startTag('optional');
  $writer->startTag('attribute', 'name' => 'gender');
  $writer->startTag('choice');
  foreach my $gender ($dm->get_constant_value('gender')) {# list type so returns list
    $writer->dataElement('value', $gender);
  }
  $writer->endTag();# choice
  $writer->endTag();# attribute
  $writer->endTag();# optional
  $writer->endTag();# define
  # ===========================

  # generic annotation attribute definition
  # =====================================
  $writer->comment('generic annotation attribute definition');
  $writer->startTag('define', 'name' => 'annotation');
  $writer->startTag('optional');
  $writer->emptyTag('attribute', 'name' => 'annotation');
  $writer->endTag(); # optional
  $writer->endTag();# define
  # ===========================

  $writer->endTag();# grammar
  $writer->end();
  $rng->close();
  # So we only do this one for potentially multiple .bltxml datasources
  $dm->{bltxml_schema_gen_done} = 1;
}


=head2 generate_bblxml_schema

    Generate a RelaxNG XML schema from the datamodel for bblXML output

=cut

sub generate_bblxml_schema {
  my ($dm, $outfile) = @_;
  my $dmh = $dm->{helpers};

  # Set the .rng path to the output dir, if specified
  if (my $outdir = Biber::Config->getoption('output_directory')) {
    my (undef, undef, $file) = File::Spec->splitpath($outfile);
    $outfile = File::Spec->catfile($outdir, $file)
  }
  my $rng = IO::File->new($outfile, '>:encoding(UTF-8)');
  $rng->autoflush;# Needed for running tests to string refs

  $logger->info("Writing bblXML RNG schema '$outfile' for datamodel");
  require XML::Writer;
  my $bbl_ns = 'https://sourceforge.net/projects/biblatex/bblxml';
  my $bbl = 'bbl';
  my $default_ns = 'http://relaxng.org/ns/structure/1.0';
  my $writer = new XML::Writer(NAMESPACES   => 1,
                               ENCODING     => 'UTF-8',
                               DATA_MODE    => 1,
                               DATA_INDENT  => 2,
                               OUTPUT       => $rng,
                               PREFIX_MAP   => {$bbl_ns    => $bbl,
                                                $default_ns => ''});

  $writer->xmlDecl();
  $writer->comment('Auto-generated from .bcf Datamodel');
  $writer->forceNSDecl($default_ns);
  $writer->forceNSDecl($bbl_ns);
  $writer->startTag('grammar',
                    'datatypeLibrary' => 'http://www.w3.org/2001/XMLSchema-datatypes');
  $writer->startTag('start');
  $writer->startTag('element', 'name' => "$bbl:refsections");
  $writer->startTag('oneOrMore');
  $writer->startTag('element', 'name' => "$bbl:refsection");
  $writer->emptyTag('attribute', 'name' => 'id');
  $writer->startTag('oneOrMore');
  $writer->startTag('element', 'name' => "$bbl:sortlist");
  $writer->emptyTag('attribute', 'name' => 'id');
  $writer->startTag('attribute', 'name' => 'type');
  $writer->startTag('choice');
  $writer->dataElement('value', 'entry');
  $writer->dataElement('value', 'list');
  $writer->endTag();    # choice
  $writer->endTag();    # attribute
  $writer->startTag('oneOrMore');
  $writer->startTag('element', 'name' => "$bbl:entry");
  $writer->emptyTag('attribute', 'name' => 'key');
  $writer->startTag('attribute', 'name' => 'type');
  $writer->startTag('choice');
  foreach my $et ($dm->entrytypes->@*) {
    $writer->dataElement('value', $et);
  }
  $writer->endTag();    # choice
  $writer->endTag();    # attribute

  # source
  $writer->startTag('optional');
  $writer->startTag('attribute', 'name' => 'source');
  $writer->startTag('choice');
  $writer->dataElement('value', 'crossref');
  $writer->dataElement('value', 'xref');
  $writer->endTag();    # choice
  $writer->endTag();    # attribute
  $writer->endTag();    # optional

  # singletitle
  $writer->startTag('optional');
  $writer->startTag('attribute', 'name' => 'singletitle');
  $writer->startTag('choice');
  $writer->dataElement('value', 'true');
  $writer->endTag();    # choice
  $writer->endTag();    # attribute
  $writer->endTag();    # optional

  # uniquetitle
  $writer->startTag('optional');
  $writer->startTag('attribute', 'name' => 'uniquetitle');
  $writer->startTag('choice');
  $writer->dataElement('value', 'true');
  $writer->endTag();    # choice
  $writer->endTag();    # attribute
  $writer->endTag();    # optional

  # uniquework
  $writer->startTag('optional');
  $writer->startTag('attribute', 'name' => 'uniquework');
  $writer->startTag('choice');
  $writer->dataElement('value', 'true');
  $writer->endTag();    # choice
  $writer->endTag();    # attribute
  $writer->endTag();    # optional

  # uniqueprimaryauthor
  $writer->startTag('optional');
  $writer->startTag('attribute', 'name' => 'uniqueprimaryauthor');
  $writer->startTag('choice');
  $writer->dataElement('value', 'true');
  $writer->endTag();    # choice
  $writer->endTag();    # attribute
  $writer->endTag();    # optional

  $writer->startTag('interleave');

  # sets
  $writer->startTag('zeroOrMore');
  $writer->startTag('element', 'name' => "$bbl:set");
  $writer->startTag('oneOrMore');
  $writer->startTag('element', 'name' => "$bbl:member");
  $writer->emptyTag('text');# text
  $writer->endTag();    # member
  $writer->endTag();    # oneOrMore
  $writer->endTag();    # set
  $writer->endTag();    # zeroOrMore

  $writer->startTag('zeroOrMore');
  $writer->startTag('element', 'name' => "$bbl:inset");
  $writer->startTag('oneOrMore');
  $writer->startTag('element', 'name' => "$bbl:member");
  $writer->emptyTag('text');# text
  $writer->endTag();    # member
  $writer->endTag();    # oneOrMore
  $writer->endTag();    # inset
  $writer->endTag();    # zeroOrMore

  # names
  my @names = grep {not $dm->field_is_skipout($_)} $dm->get_fields_of_type('list', 'name')->@*;

  $writer->startTag('oneOrMore');
  $writer->startTag('element', 'name' => "$bbl:names");
  $writer->startTag('attribute', 'name' => 'type');
  $writer->startTag('choice');
  foreach my $name (@names) {
    $writer->dataElement('value', $name);
  }
  $writer->endTag();    # choice
  $writer->endTag();    # attribute
  $writer->startTag('attribute', 'name' => 'count');
  $writer->emptyTag('data', 'type' => 'integer');
  $writer->endTag();    # attribute
  $writer->startTag('optional');
  $writer->startTag('attribute', 'name' => 'uniquelist');
  $writer->emptyTag('data', 'type' => 'integer');
  $writer->endTag();    # attribute
  $writer->endTag();    # optional
  $writer->startTag('optional');
  $writer->startTag('attribute', 'name' => 'useprefix');
  $writer->emptyTag('data', 'type' => 'boolean');
  $writer->endTag();    # attribute
  $writer->endTag();    # optional
  $writer->startTag('optional');
  $writer->emptyTag('attribute', 'name' => 'sortnamekeyscheme');
  $writer->endTag();    # optional
  $writer->startTag('optional');
  $writer->startTag('attribute', 'name' => 'more');
  $writer->emptyTag('data', 'type' => 'boolean');
  $writer->endTag();    # attribute
  $writer->endTag();    # optional

  # name
  $writer->startTag('oneOrMore');
  $writer->startTag('element', 'name' => "$bbl:name");
  $writer->startTag('optional');
  $writer->startTag('attribute', 'name' => 'useprefix');
  $writer->emptyTag('data', 'type' => 'boolean');
  $writer->endTag();    # attribute
  $writer->endTag();    # optional
  $writer->startTag('optional');
  $writer->emptyTag('attribute', 'name' => 'sortnamekeyscheme');
  $writer->endTag();    # optional
  $writer->emptyTag('attribute', 'name' => 'hash');
  $writer->startTag('optional');
  $writer->startTag('attribute', 'name' => 'uniquename');
  $writer->emptyTag('data', 'type' => 'integer');
  $writer->endTag();    # attribute
  $writer->endTag();    # optional
  $writer->startTag('oneOrMore');
  $writer->startTag('element', 'name' => "$bbl:namepart");
  $writer->emptyTag('attribute', 'name' => 'type');
  $writer->emptyTag('attribute', 'name' => 'initials');
  $writer->emptyTag('text');# text
  $writer->endTag();# namepart
  $writer->endTag();# oneOrMore
  $writer->endTag();# name
  $writer->endTag();# oneOrMore
  $writer->endTag();# names
  $writer->endTag();# oneOrMore

  # lists
  # verbatim lists don't need special handling in XML, unlike TeX so they are here
  my @lists = grep {
    not $dm->field_is_datatype('name', $_)
        and not $dm->field_is_datatype('uri', $_)
          and not $dm->field_is_skipout($_)
        } $dm->get_fields_of_fieldtype('list')->@*;

  $writer->startTag('zeroOrMore');
  $writer->startTag('element', 'name' => "$bbl:list");
  $writer->startTag('attribute', 'name' => 'name');
  $writer->startTag('choice');
  foreach my $list (@lists) {
    $writer->dataElement('value', $list);
  }
  $writer->endTag();          # choice
  $writer->endTag();          # attribute
  $writer->startTag('attribute', 'name' => 'count');
  $writer->emptyTag('data', 'type' => 'integer');
  $writer->endTag();          # attribute
  $writer->startTag('optional');
  $writer->startTag('attribute', 'name' => 'more');
  $writer->emptyTag('data', 'type' => 'boolean');
  $writer->endTag();    # attribute
  $writer->endTag();    # optional
  $writer->startTag('oneOrMore');
  $writer->startTag('element', 'name' => "$bbl:item");
  $writer->emptyTag('text');# text
  $writer->endTag();          # item
  $writer->endTag();          # oneOrMore
  $writer->endTag();          # list
  $writer->endTag();          # zeroOrMore

  # fields
  my @fs1 = qw/namehash
              fullhash
              labelalpha
              sortinit
              sortinithash
              sortinithash
              extrayear
              labelyear
              labelmonth
              labelday
              labeldatesource
              labelprefix
              extratitle
              extratitleyear
              extraalpha
              labelnamesource
              labeltitlesource
              clonesourcekey/;

  # verbatim fields don't need special handling in XML, unlike TeX so they are here
  my @fs2 = grep {
      not ($dm->get_fieldformat($_) eq 'xsv')
        and not $dm->field_is_skipout($_)
      } $dm->get_fields_of_type('field',
                                  ['entrykey',
                                   'key',
                                   'integer',
                                   'datepart',
                                   'literal',
                                   'code',
                                   'verbatim'])->@*;

  # uri fields
  my @fs3 = $dm->get_fields_of_type('field', 'uri')->@*;

  # <namelist>namehash and <namelist>fullhash
  my @fs4;
  map {push @fs4, "${_}namehash";push @fs4, "${_}fullhash"} $dmh->{namelists}->@*;

  $writer->startTag('oneOrMore');
  $writer->startTag('element', 'name' => "$bbl:field");
  $writer->startTag('choice'); # start choice of normal vs datepart fields
  $writer->startTag('group'); #
  $writer->startTag('attribute', 'name' => 'name');

  $writer->startTag('choice');
  foreach my $f (@fs1, @fs2, @fs3, @fs4) {
    $writer->dataElement('value', $f);
  }
  $writer->endTag();    # choice
  $writer->endTag();    # attribute
  $writer->endTag();    # group
  $writer->startTag('group'); #
  $writer->startTag('attribute', 'name' => 'name');

  $writer->startTag('choice');
  foreach my $dp ($dm->get_fields_of_type('field', 'datepart')->@*) {
    $writer->dataElement('value', $dp);
  }
  $writer->endTag();    # choice
  $writer->endTag();    # attribute
  # dateparts may have an era attributes
  $writer->startTag('optional');
  $writer->startTag('attribute', 'name' => 'startera');
  $writer->startTag('choice');
  $writer->dataElement('value', 'bce');
  $writer->dataElement('value', 'ce');
  $writer->endTag();    # choice
  $writer->endTag();    # attribute
  $writer->endTag();    # optional
  $writer->startTag('optional');
  $writer->startTag('attribute', 'name' => 'endera');
  $writer->startTag('choice');
  $writer->dataElement('value', 'bce');
  $writer->dataElement('value', 'ce');
  $writer->endTag();    # choice
  $writer->endTag();    # attribute
  $writer->endTag();    # optional
  # dateparts may have a julian attributes
  $writer->startTag('optional');
  $writer->startTag('attribute', 'name' => 'startjulian');
  $writer->startTag('choice');
  $writer->dataElement('value', 'true');
  $writer->endTag();    # choice
  $writer->endTag();    # attribute
  $writer->endTag();    # optional
  $writer->startTag('optional');
  $writer->startTag('attribute', 'name' => 'endjulian');
  $writer->startTag('choice');
  $writer->dataElement('value', 'true');
  $writer->endTag();    # choice
  $writer->endTag();    # attribute
  $writer->endTag();    # optional
  # dateparts may have a circa attributes
  $writer->startTag('optional');
  $writer->startTag('attribute', 'name' => 'startcirca');
  $writer->startTag('choice');
  $writer->dataElement('value', 'true');
  $writer->endTag();    # choice
  $writer->endTag();    # attribute
  $writer->endTag();    # optional
  $writer->startTag('optional');
  $writer->startTag('attribute', 'name' => 'endcirca');
  $writer->startTag('choice');
  $writer->dataElement('value', 'true');
  $writer->endTag();    # choice
  $writer->endTag();    # attribute
  $writer->endTag();    # optional
  # dateparts may have an uncertain attributes
  $writer->startTag('optional');
  $writer->startTag('attribute', 'name' => 'startuncertain');
  $writer->startTag('choice');
  $writer->dataElement('value', 'true');
  $writer->endTag();    # choice
  $writer->endTag();    # attribute
  $writer->endTag();    # optional
  $writer->startTag('optional');
  $writer->startTag('attribute', 'name' => 'enduncertain');
  $writer->startTag('choice');
  $writer->dataElement('value', 'true');
  $writer->endTag();    # choice
  $writer->endTag();    # attribute
  $writer->endTag();    # optional
  $writer->endTag();    # group
  $writer->endTag();    # choice (normal vs datepart)
  $writer->emptyTag('text');# text
  $writer->endTag();    # field
  $writer->endTag();    # oneOrMore

  # ranges
  my @ranges = grep {not $dm->field_is_skipout($_)} $dm->get_fields_of_datatype('range')->@*;

  $writer->startTag('zeroOrMore');
  $writer->startTag('element', 'name' => "$bbl:range");
  $writer->startTag('attribute', 'name' => 'name');
  $writer->startTag('choice');
  foreach my $r (@ranges) {
    $writer->dataElement('value', $r);
  }
  $writer->endTag();    # choice
  $writer->endTag();    # attribute
  $writer->startTag('oneOrMore');
  $writer->startTag('element', 'name' => "$bbl:item");
  $writer->startTag('attribute', 'name' => 'length');
  $writer->emptyTag('data', 'type' => 'integer');
  $writer->endTag();    # attribute
  $writer->startTag('element', 'name' => "$bbl:start");
  $writer->emptyTag('text');# text
  $writer->endTag();    # start
  $writer->startTag('optional');
  $writer->startTag('element', 'name' => "$bbl:end");
  $writer->emptyTag('text');# text
  $writer->endTag();    # end
  $writer->endTag();    # optional
  $writer->endTag();    # item
  $writer->endTag();    # oneOrMore
  $writer->endTag();    # range
  $writer->endTag();    # zeroOrMore

  # uri lists - not in default data model
  if (my @uril = $dm->get_fields_of_type('list', 'uri')->@*) {
    $writer->startTag('optional');
    $writer->startTag('element', 'name' => "$bbl:list");
    $writer->startTag('attribute', 'name' => 'name');
    $writer->startTag('choice');
    foreach my $u (@uril) {
      $writer->dataElement('value', $u);
    }
    $writer->endTag();          # choice
    $writer->endTag();          # attribute
    $writer->startTag('attribute', 'name' => 'count');
    $writer->emptyTag('data', 'type' => 'integer');
    $writer->endTag();          # attribute
    $writer->startTag('oneOrMore');
    $writer->startTag('element', 'name' => "$bbl:item");
    $writer->emptyTag('data', 'type' => 'anyURI');
    $writer->endTag();          # item
    $writer->endTag();          # oneOrMore
    $writer->endTag();          # list element
    $writer->endTag();          # optional
  }

  # keywords
  $writer->startTag('optional');
  $writer->startTag('element', 'name' => "$bbl:keywords");
  $writer->startTag('oneOrMore');
  $writer->startTag('element', 'name' => "$bbl:keyword");
  $writer->emptyTag('data', 'type' => 'string');
  $writer->endTag();# item
  $writer->endTag();# oneOrMore
  $writer->endTag();# keywords
  $writer->endTag();# optional

  # annotations
  $writer->startTag('zeroOrMore');
  $writer->startTag('element', 'name' => "$bbl:annotation");
  $writer->startTag('attribute', 'name' => 'scope');
  $writer->startTag('choice');
  foreach my $s ('field', 'list', 'names', 'item', 'name', 'namepart') {
    $writer->dataElement('value', $s);
  }
  $writer->endTag();# choice
  $writer->endTag();# scope attribute
  $writer->emptyTag('attribute', 'name' => 'field');
  $writer->emptyTag('attribute', 'name' => 'value');
  $writer->startTag('optional');
  $writer->emptyTag('attribute', 'name' => 'item');
  $writer->endTag();# optional
  $writer->startTag('optional');
  $writer->emptyTag('attribute', 'name' => 'part');
  $writer->endTag();# optional
  $writer->endTag();# annotation
  $writer->endTag();# zeroOrMore

  # warnings
  $writer->startTag('zeroOrMore');
  $writer->startTag('element', 'name' => "$bbl:warning");
  $writer->emptyTag('data', 'type' => 'string');
  $writer->endTag();# warning
  $writer->endTag();# zeroOrMore

  $writer->endTag();# interleave element
  $writer->endTag();# entry element
  $writer->endTag();# oneOrMore
  $writer->endTag();# sortlist element
  $writer->endTag();# oneOrMore

  # aliases
  $writer->startTag('zeroOrMore');
  $writer->startTag('element', 'name' => "$bbl:keyalias");
  $writer->emptyTag('attribute', 'name' => 'key');
  $writer->emptyTag('text');# text
  $writer->endTag();# keyalias
  $writer->endTag();# zeroOrMore

  # missing keys
  $writer->startTag('zeroOrMore');
  $writer->startTag('element', 'name' => "$bbl:missing");
  $writer->emptyTag('text');# text
  $writer->endTag();# missing
  $writer->endTag();# zeroOrMore

  $writer->endTag();# refsection element
  $writer->endTag();# oneOrMore
  $writer->endTag();# refsections element
  $writer->endTag();# start

  $writer->endTag();# grammar
  $writer->end();
  $rng->close();
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

Copyright 2009-2016 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
