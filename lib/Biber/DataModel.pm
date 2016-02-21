package Biber::DataModel;
use v5.16;
use strict;

use warnings;
no autovivification;

use List::Util qw( first );
use Biber::Utils;
use Biber::Constants;
use Data::Dump qw( pp );
use Date::Simple;

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
  # Pull out legal entrytypes, fields and constraints and make lookup hash
  # for quick tests later
  foreach my $f (@{$dm->{fields}{field}}) {

    # In case of conflicts, we need to remove the previous definitions since
    # later overrides earlier
    if (my $previous = $self->{fieldsbyname}{$f->{content}}) {

      if ($f->{format}) {
        @{$self->{fieldsbytype}{$previous->{fieldtype}}{$previous->{datatype}}{$previous->{format}}} = grep {$_ ne $f->{content}} @{$self->{fieldsbytype}{$previous->{fieldtype}}{$previous->{datatype}}{$previous->{format}}};
      }
      @{$self->{fieldsbytype}{$previous->{fieldtype}}{$previous->{datatype}}{'*'}} = grep {$_ ne $f->{content}} @{$self->{fieldsbytype}{$previous->{fieldtype}}{$previous->{datatype}}{'*'}};
      @{$self->{fieldsbyfieldtype}{$previous->{fieldtype}}} = grep {$_ ne $f->{content}} @{$self->{fieldsbyfieldtype}{$previous->{fieldtype}}};
      @{$self->{fieldsbydatatype}{$previous->{datatype}}} = grep {$_ ne $f->{content}} @{$self->{fieldsbydatatype}{$previous->{datatype}}};
      @{$self->{fieldsbyformat}{$previous->{'format'}}} = grep {$_ ne $f->{content}} @{$self->{fieldsbyformat}{$previous->{format}}};
      delete $self->{fieldsbyname}{$f->{content}};
    }

    $self->{fieldsbyname}{$f->{content}} = {'fieldtype'   => $f->{fieldtype},
                                            'datatype'    => $f->{datatype},
                                            'format'      => $f->{format} || 'default'};
    if ($f->{format}) {
      push @{$self->{fieldsbytype}{$f->{fieldtype}}{$f->{datatype}}{$f->{format}}}, $f->{content};
    }
    push @{$self->{fieldsbytype}{$f->{fieldtype}}{$f->{datatype}}{'*'}}, $f->{content};
    push @{$self->{fieldsbyfieldtype}{$f->{fieldtype}}}, $f->{content};
    push @{$self->{fieldsbydatatype}{$f->{datatype}}}, $f->{content};
    push @{$self->{fieldsbyformat}{$f->{format} || 'default'}}, $f->{content};

    # check null_ok
    if ($f->{nullok}) {
      $self->{fieldsbyname}{$f->{content}}{nullok} = 1;
    }
    # check skips - fields we don't want to output to BBL
    if ($f->{skip_output}) {
      $self->{fieldsbyname}{$f->{content}}{skipout} = 1;
    }
  }

  my $constants;
  foreach my $constant (@{$dm->{constants}{constant}}) {
    $self->{constants}{$constant->{name}}{type} = $constant->{type};
    $self->{constants}{$constant->{name}}{value} = $constant->{content};
  }

  my $leg_ents;
  foreach my $et (@{$dm->{entrytypes}{entrytype}}) {
    my $es = $et->{content};

    # Skip output flag for certain entrytypes
    if ($et->{skip_output}) {
      $leg_ents->{$es}{skipout} = 1;
    }
    # fields for entrytypes
    my $lfs;
    foreach my $ef (@{$dm->{entryfields}}) {
      # Found a section describing legal fields for entrytype
      if (not exists($ef->{entrytype}) or
          grep {$_->{content} eq $es} @{$ef->{entrytype}}) {
        foreach my $f (@{$ef->{field}}) {
          $lfs->{$f->{content}} = 1;
        }
      }
    }

    # constraints
    my $constraints;
    foreach my $cd (@{$dm->{constraints}}) {
      # Found a section describing constraints for entrytype
      if (not exists($cd->{entrytype}) or
          grep {$_->{content} eq $es} @{$cd->{entrytype}}) {
        foreach my $c (@{$cd->{constraint}}) {
          if ($c->{type} eq 'mandatory') {
            # field
            foreach my $f (@{$c->{field}}) {
              push @{$constraints->{mandatory}}, $f->{content};
            }
            # xor set of fields
            # [ XOR, field1, field2, ... , fieldn ]
            foreach my $fxor (@{$c->{fieldxor}}) {
              my $xorset;
              foreach my $f (@{$fxor->{field}}) {
                push @$xorset, $f->{content};
              }
              unshift @$xorset, 'XOR';
              push @{$constraints->{mandatory}}, $xorset;
            }
            # or set of fields
            # [ OR, field1, field2, ... , fieldn ]
            foreach my $for (@{$c->{fieldor}}) {
              my $orset;
              foreach my $f (@{$for->{field}}) {
                push @$orset, $f->{content};
              }
              unshift @$orset, 'OR';
              push @{$constraints->{mandatory}}, $orset;
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
            $cond->[1] = [ map { $_->{content} } @{$c->{antecedent}{field}} ];
            $cond->[2] = $c->{consequent}{quant};
            $cond->[3] = [ map { $_->{content} } @{$c->{consequent}{field}} ];
            push @{$constraints->{conditional}}, $cond;
          }
          # data constraints
          elsif ($c->{type} eq 'data') {
            my $data;
            $data->{fields} = [ map { $_->{content} } @{$c->{field}} ];
            $data->{datatype} = $c->{datatype};
            $data->{rangemin} = $c->{rangemin};
            $data->{rangemax} = $c->{rangemax};
            $data->{pattern} = $c->{pattern};
            push @{$constraints->{data}}, $data;
          }
        }
      }
    }
    $leg_ents->{$es}{legal_fields} = $lfs;
    $leg_ents->{$es}{constraints} = $constraints;
  }
  $self->{entrytypesbyname} = $leg_ents;

#  use Data::Dump;dd($self);exit 0;
  return $self;
}

=head2 constants

    Returns array ref of constant names

=cut

sub constants {
  my $self = shift;
  return [ keys %{$self->{constants}} ];
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
  return [ keys %{$self->{fieldsbyfieldtype}} ];
}

=head2 datatypes

    Returns array ref of legal datatypes

=cut

sub datatypes {
  my $self = shift;
  return [ keys %{$self->{fieldsbydatatype}} ];
}


=head2 is_field

    Returns boolean to say if a field is a legal field
    Allows intermediate temp custom fields which are used
    when a driver source field doesn't have an obvious 1:1 mapping
    to a datamodel field. Such intermediates are defined in the target
    field mapping of a sourcemap.

    Also allows for fields with script form and optional lang suffix

=cut

sub is_field {
  my $self = shift;
  my $field = shift;
  if ($field =~ m/^BIBERCUSTOM/o) {
    return 1;
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
  return [ keys %{$self->{entrytypesbyname}} ];
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
  return $f ? [ sort @$f ] : [];
}

=head2 get_fields_of_fieldformat

    Retrieve fields of a certain format from data model
    Return in sorted order so that bbl order doesn't change when changing
    .bcf. This really messes up tests otherwise.

=cut

sub get_fields_of_fieldformat {
  my ($self, $format) = @_;
  my $f = $self->{fieldsbyformat}{$format};
  return $f ? [ sort @$f ] : [];
}


=head2 get_fields_of_datatype

    Retrieve fields of a certain biblatex datatype from data model
    Return in sorted order so that bbl order doesn't change when changing
    .bcf. This really messes up tests otherwise.

=cut

sub get_fields_of_datatype {
  my ($self, $datatype) = @_;
  my $f = $self->{fieldsbydatatype}{$datatype};
  return $f ? [ sort @$f ] : [];
}


=head2 get_fields_of_type

    Retrieve fields of a certain biblatex type from data model
    Return in sorted order so that bbl order doesn't change when changing
    .bcf. This really messes up tests otherwise.

=cut

sub get_fields_of_type {
  my ($self, $fieldtype, $datatype, $format) = @_;
  my $f;
  if ($format) {
    $f = $self->{fieldsbytype}{$fieldtype}{$datatype}{$format};
  }
  else {
    $f = $self->{fieldsbytype}{$fieldtype}{$datatype}{'*'};
  }

  return $f ? [ sort @$f ] : [];
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

  foreach my $c (@{$self->{entrytypesbyname}{$et}{constraints}{mandatory}}) {
    if (ref($c) eq 'ARRAY') {
      # Exactly one of a set is mandatory
      if ($c->[0] eq 'XOR') {
        my @fs = @$c[1,-1]; # Lose the first element which is the 'XOR'
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
        my @fs = @$c[1,-1]; # Lose the first element which is the 'OR'
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

  foreach my $c (@{$self->{entrytypesbyname}{$et}{constraints}{conditional}}) {
    my $aq  = $c->[0];          # Antecedent quantifier
    my $afs = $c->[1];          # Antecedent fields
    my $cq  = $c->[2];          # Consequent quantifier
    my $cfs = $c->[3];          # Consequent fields
    my @actual_afs = (grep {$be->field_exists($_)} @$afs); # antecedent fields in entry
    # check antecedent
    if ($aq eq 'all') {
      next unless $#$afs == $#actual_afs; # ALL -> ? not satisfied
    }
    elsif ($aq eq 'none') {
      next if @actual_afs;      # NONE -> ? not satisfied
    }
    elsif ($aq eq 'one') {
      next unless @actual_afs;  # ONE -> ? not satisfied
    }

    # check consequent
    my @actual_cfs = (grep {$be->field_exists($_)} @$cfs);
    if ($cq eq 'all') {
      unless ($#$cfs == $#actual_cfs) { # ? -> ALL not satisfied
        push @warnings, "Datamodel: Entry '$key' ($ds): Constraint violation - $cq of fields (" .
          join(', ', @$cfs) .
            ") must exist when $aq of fields (" . join(', ', @$afs). ") exist";
      }
    }
    elsif ($cq eq 'none') {
      if (@actual_cfs) {        # ? -> NONE not satisfied
        push @warnings, "Datamodel: Entry '$key' ($ds): Constraint violation - $cq of fields (" .
          join(', ', @actual_cfs) .
            ") must exist when $aq of fields (" . join(', ', @$afs). ") exist. Ignoring them.";
        # delete the offending fields
        foreach my $f (@actual_cfs) {
          $be->del_field($f);
        }
      }
    }
    elsif ($cq eq 'one') {
      unless (@actual_cfs) {    # ? -> ONE not satisfied
        push @warnings, "Datamodel: Entry '$key' ($ds): Constraint violation - $cq of fields (" .
          join(', ', @$cfs) .
            ") must exist when $aq of fields (" . join(', ', @$afs). ") exist";
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

  foreach my $c (@{$self->{entrytypesbyname}{$et}{constraints}{data}}) {
    # This is the datatype of the constraint, not the field!
    if ($c->{datatype} eq 'isbn') {
      foreach my $f (@{$c->{fields}}) {
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
          foreach (@$fv) {
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
      foreach my $f (@{$c->{fields}}) {
        if (my $fv = $be->get_field($f)) {
          require Business::ISSN;
          # Treat as a list field just in case someone has made it so in a custom datamodel
          unless ($self->get_fieldtype($f) eq 'list') {
            $fv = [$fv];
          }
          foreach (@$fv) {
            my $issn = Business::ISSN->new($_);
            unless ($issn and $issn->is_valid) {
              push @warnings, "Datamodel: Entry '$key' ($ds): Invalid ISSN in value of field '$f'";
            }
          }
        }
      }
    }
    elsif ($c->{datatype} eq 'ismn') {
      foreach my $f (@{$c->{fields}}) {
        if (my $fv = $be->get_field($f)) {
          require Business::ISMN;
          # Treat as a list field just in case someone has made it so in a custom datamodel
          unless ($self->get_fieldtype($f) eq 'list') {
            $fv = [$fv];
          }
          foreach (@$fv) {
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
      foreach my $f (@{$c->{fields}}) {
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
    elsif ($c->{datatype} eq 'date') {
      # Perform content validation checks on date components by trying to
      # instantiate a Date::Simple object.
      foreach my $f (@{$self->get_fields_of_type('field', 'date')}) {
        my $d = $f =~ s/date\z//xmsr;
        # Don't bother unless this type of date is defined (has a year)
        next unless $be->get_datafield($d . 'year');

        # When checking date components not split from date fields, have ignore the value
        # of an explicit YEAR field as it is allowed to be an arbitrary string
        # so we just set it to any valid value for the test
        my $byc;
        my $byc_d; # Display value for errors so as not to confuse people
        if ($d eq '' and not $be->get_field('datesplit')) {
          $byc = '1900';        # Any valid value is fine
          $byc_d = 'YYYY';
        }
        else {
          $byc = $be->get_datafield($d . 'year')
        }

        # Begin date
        if ($byc) {
          my $bm = $be->get_datafield($d . 'month') || 'MM';
          my $bmc = $bm  eq 'MM' ? '01' : $bm;
          my $bd = $be->get_datafield($d . 'day') || 'DD';
          my $bdc = $bd  eq 'DD' ? '01' : $bd;
          $logger->debug("Checking '${d}date' date value '$byc/$bmc/$bdc' for key '$key'");
          unless (Date::Simple->new("$byc$bmc$bdc")) {
            push @warnings, "Datamodel: Entry '$key' ($ds): Invalid date value '" .
              ($byc_d || $byc) .
                "/$bm/$bd' - ignoring its components";
            $be->del_datafield($d . 'year');
            $be->del_datafield($d . 'month');
            $be->del_datafield($d . 'day');
            next;
          }
        }
        # End date
        # defined and some value - end*year can be empty but defined in which case,
        # we don't need to validate
        if (my $eyc = $be->get_datafield($d . 'endyear')) {
          my $em = $be->get_datafield($d . 'endmonth') || 'MM';
          my $emc = $em  eq 'MM' ? '01' : $em;
          my $ed = $be->get_datafield($d . 'endday') || 'DD';
          my $edc = $ed  eq 'DD' ? '01' : $ed;
          $logger->debug("Checking '${d}date' date value '$eyc/$emc/$edc' for key '$key'");
          unless (Date::Simple->new("$eyc$emc$edc")) {
            push @warnings, "Datamodel: Entry '$key' ($ds): Invalid date value '$eyc/$em/$ed' - ignoring its components";
            $be->del_datafield($d . 'endyear');
            $be->del_datafield($d . 'endmonth');
            $be->del_datafield($d . 'endday');
            next;
          }
        }
      }
    }
    elsif ($c->{datatype} eq 'pattern') {
      my $patt;
      unless ($patt = $c->{pattern}) {
        push @warnings, "Datamodel: Pattern constraint has no pattern!";
      }
      foreach my $f (@{$c->{fields}}) {
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
  foreach my $entrytype (@{$dm->entrytypes}) {
    $writer->dataElement('value', $entrytype);
  }
  $writer->endTag();# choice
  $writer->endTag();# attribute
  $writer->startTag('interleave');

  foreach my $ft (@{$dm->fieldtypes()}) {
    foreach my $dt (@{$dm->datatypes()}) {
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

  foreach my $ft (@{$dm->fieldtypes()}) {
    foreach my $dt (@{$dm->datatypes()}) {
      if ($dm->is_fields_of_type($ft, $dt)) {
        next if $dt eq 'datepart'; # not legal in input, only output
        $writer->comment("$dt ${ft}s definition");
        $writer->startTag('define', 'name' => "$dt$ft");

        # Name lists element definition
        # =============================
        if ($ft eq 'list' and $dt eq 'name') {
          $writer->startTag('optional');
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
          foreach my $name (@{$dm->get_fields_of_type($ft, $dt)}) {
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
          $writer->endTag();# optional
          # ========================
        }
        elsif ($ft eq 'list') {
          # lists element definition
          # ========================
          $writer->startTag('interleave');
          foreach my $list (@{$dm->get_fields_of_type($ft, $dt)}) {
            $writer->startTag('optional');
            $writer->startTag('element', 'name' => "$bltx:$list");
            $writer->startTag('choice');
            $writer->emptyTag('text');# text
            $writer->startTag('oneOrMore');
            $writer->startTag('element', 'name' => "$bltx:item");
            $writer->emptyTag('text');# text
            $writer->endTag(); # item element
            $writer->endTag(); # oneOrMore element
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
          foreach my $field (@{$dm->get_fields_of_type($ft, $dt)}) {
            $writer->startTag('optional');
            $writer->startTag('element', 'name' => "$bltx:$field");
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
          foreach my $field (@{$dm->get_fields_of_type($ft, $dt)}) {
            $writer->startTag('optional');
            $writer->startTag('element', 'name' => "$bltx:$field");
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
          foreach my $field (@{$dm->get_fields_of_type($ft, $dt)}) {
            $writer->startTag('optional');
            # related field is special
            if ($field eq 'related') {
              $writer->startTag('element', 'name' => "$bltx:$field");
              $writer->startTag('oneOrMore');
              $writer->startTag('element', 'name' => "$bltx:item");
              $writer->emptyTag('attribute', 'name' => 'type');
              $writer->emptyTag('attribute', 'name' => 'ids');
              $writer->startTag('optional');
              $writer->emptyTag('attribute', 'name' => 'options');
              $writer->endTag(); # optional
              $writer->startTag('optional');
              $writer->emptyTag('attribute', 'name' => 'string');
              $writer->endTag(); # optional
              $writer->endTag(); # item element
              $writer->endTag(); # oneOrMore
              $writer->endTag(); # $field element
            }
            else {
              $writer->startTag('element', 'name' => "$bltx:$field");
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
          my @types = map { s/date$//r } @{$dm->get_fields_of_type($ft, $dt)};
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
          $writer->startTag('choice');
          $writer->emptyTag('data', 'type' => 'date');
          $writer->emptyTag('data', 'type' => 'gYear');
          $writer->startTag('group');
          $writer->startTag('element', 'name' => "$bltx:start");
          $writer->emptyTag('data', 'type' => 'date');
          $writer->endTag(); # start element
          $writer->startTag('element', 'name' => "$bltx:end");
          $writer->startTag('choice');
          $writer->emptyTag('data', 'type' => 'date');
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
          foreach my $field (@{$dm->get_fields_of_type($ft, $dt)}) {
            $writer->startTag('optional');
            $writer->startTag('element', 'name' => "$bltx:$field");
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
  $writer->startTag('zeroOrMore');
  $writer->startTag('attribute', 'name' => 'gender');
  $writer->startTag('choice');
  foreach my $gender ($dm->get_constant_value('gender')) {# list type so returns list
    $writer->dataElement('value', $gender);
  }
  $writer->endTag();# choice
  $writer->endTag();# attribute
  $writer->endTag();# zeroOrMore
  $writer->endTag();# define
  # ===========================

  $writer->endTag();# grammar
  $writer->end();
  $rng->close();
  # So we only do this one for potentially multiple .bltxml datasources
  $dm->{bltxml_schema_gen_done} = 1;
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
