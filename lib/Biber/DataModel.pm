package Biber::DataModel;
use 5.014000;
use strict;
use warnings;

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
  if (defined($dm) and ref($dm) eq 'HASH') {
    $self = bless $dm, $class;
  }
  else {
    $self = bless {}, $class;
  }

  # Pull out legal entrytypes, fields and constraints and make lookup hash
  # for quick tests later
  foreach my $f (@{$dm->{fields}{field}}) {

    # In case of conflicts, we need to remove the previous definitions since
    # later overrides earlier
    if (my $previous = $self->{fieldsbyname}{$f->{content}}) {
      @{$self->{fieldsbytype}{$previous->{'fieldtype'}}{$previous->{'datatype'}}} = grep {$_ ne $f->{content}} @{$self->{fieldsbytype}{$previous->{'fieldtype'}}{$previous->{'datatype'}}};
      @{$self->{fieldsbyfieldtype}{$previous->{'fieldtype'}}} = grep {$_ ne $f->{content}} @{$self->{fieldsbyfieldtype}{$previous->{'fieldtype'}}};
      @{$self->{fieldsbydatatype}{$previous->{'datatype'}}} = grep {$_ ne $f->{content}} @{$self->{fieldsbydatatype}{$previous->{'datatype'}}};
      delete $self->{fieldsbyname}{$f->{content}};
    }

    $self->{fieldsbyname}{$f->{content}} = {'fieldtype' => $f->{fieldtype},
                                            'datatype'  => $f->{datatype}};
    push @{$self->{fieldsbytype}{$f->{fieldtype}}{$f->{datatype}}}, $f->{content};
    push @{$self->{fieldsbyfieldtype}{$f->{fieldtype}}}, $f->{content};
    push @{$self->{fieldsbydatatype}{$f->{datatype}}}, $f->{content};

    # check null_ok
    if ($f->{nullok}) {
      $self->{fieldsbyname}{$f->{content}}{nullok} = 1;
    }
    # check skips - fields we don't want to output to BBL
    if ($f->{skip_output}) {
      $self->{fieldsbyname}{$f->{content}}{skipout} = 1;
    }
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
  elsif ($field =~ m/^([^_]+)_(?:original|translated|romanised|uniform)_?.*$/) {
    return $self->{fieldsbyname}{$1} ? 1 : 0;
  }
  else {
    return $self->{fieldsbyname}{$field} ? 1 : 0;
  }
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
  my ($self, $fieldtype, $datatype) = @_;
  my $f = $self->{fieldsbytype}{$fieldtype}{$datatype};
  return $f ? [ sort @$f ] : [];
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

=head2 get_dm_for_field

    Returns the fieldtype and datatype of a field

=cut

sub get_dm_for_field {
  my ($self, $field) = @_;
  return ($self->{fieldsbyname}{$field}{fieldtype}, $self->{fieldsbyname}{$field}{datatype});
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
  my @warnings;
  my $et = $be->get_field('entrytype');
  my $key = $be->get_field('citekey');
  foreach my $c (@{$self->{entrytypesbyname}{$et}{constraints}{mandatory}}) {
    if (ref($c) eq 'ARRAY') {
      # Exactly one of a set is mandatory
      if ($c->[0] eq 'XOR') {
        my @fs = @$c[1,-1]; # Lose the first element which is the 'XOR'
        my $flag = 0;
        my $xorflag = 0;
        foreach my $of (@fs) {
          if ($be->field_exists($of)) {
            if ($xorflag) {
              push @warnings, "Mandatory fields - only one of '" . join(', ', @fs) . "' must be defined in entry '$key' ignoring field '$of'";
              $be->del_field($of);
            }
            $flag = 1;
            $xorflag = 1;
          }
        }
        unless ($flag) {
          push @warnings, "Missing mandatory field - one of '" . join(', ', @fs) . "' must be defined in entry '$key'";
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
          push @warnings, "Missing mandatory field - one of '" . join(', ', @fs) . "' must be defined in entry '$key'";
        }
      }
    }
    # Simple mandatory field
    else {
      unless ($be->field_exists($c)) {
        push @warnings, "Missing mandatory field '$c' in entry '$key'";
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
  my @warnings;
  my $et = $be->get_field('entrytype');
  my $key = $be->get_field('citekey');

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
        push @warnings, "Constraint violation - $cq of fields (" .
          join(', ', @$cfs) .
            ") must exist when $aq of fields (" . join(', ', @$afs). ") exist";
      }
    }
    elsif ($cq eq 'none') {
      if (@actual_cfs) {        # ? -> NONE not satisfied
        push @warnings, "Constraint violation - $cq of fields (" .
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
        push @warnings, "Constraint violation - $cq of fields (" .
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
  my @warnings;
  my $et = $be->get_field('entrytype');
  my $key = $be->get_field('citekey');
  foreach my $c (@{$self->{entrytypesbyname}{$et}{constraints}{data}}) {
    # This is the datatype of the constraint, not the field!
    if ($c->{datatype} eq 'isbn') {
      foreach my $f (@{$c->{fields}}) {
        if (my $fv = $be->get_field($f)) {
          require Business::ISBN;
          my $isbn = Business::ISBN->new($fv);
          if (not $isbn) {
            push @warnings, "Invalid ISBN for value of field '$f' in '$key'";
          }
          # Business::ISBN has an error() method so we might get more information
          elsif (not $isbn->is_valid) {
            push @warnings, "Invalid ISBN for value of field '$f' in '$key' (" . $isbn->error. ')';
          }
        }
      }
    }
    elsif ($c->{datatype} eq 'issn') {
      foreach my $f (@{$c->{fields}}) {
        if (my $fv = $be->get_field($f)) {
          require Business::ISSN;
          my $issn = Business::ISSN->new($fv);
          unless ($issn and $issn->is_valid) {
            push @warnings, "Invalid ISSN for value of field '$f' in '$key'";
          }
        }
      }
    }
    elsif ($c->{datatype} eq 'ismn') {
      foreach my $f (@{$c->{fields}}) {
        if (my $fv = $be->get_field($f)) {
          require Business::ISMN;
          my $ismn = Business::ISMN->new($fv);
          unless ($ismn and $ismn->is_valid) {
            push @warnings, "Invalid ISMN for value of field '$f' in '$key'";
          }
        }
      }
    }
    elsif ($c->{datatype} eq 'integer') {
      my $dt = $DM_DATATYPES{'integer'};
      foreach my $f (@{$c->{fields}}) {
        if (my $fv = $be->get_field($f)) {
          unless ( $fv =~ /$dt/ ) {
            push @warnings, 'Invalid format (' . $c->{datatype}. ") of field '$f' - ignoring field in entry '$key'";
            $be->del_field($f);
            next;
          }
          if (my $fmin = $c->{rangemin}) {
            unless ($fv >= $fmin) {
              push @warnings, "Invalid value of field '$f' must be '>=$fmin' - ignoring field in entry '$key'";
              $be->del_field($f);
              next;
            }
          }
          if (my $fmax = $c->{rangemax}) {
            unless ($fv <= $fmax) {
              push @warnings, "Invalid value of field '$f' must be '<=$fmax' - ignoring field in entry '$key'";
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
        my ($d) = $f =~ m/\A(.*)date\z/xms;
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
            push @warnings, "Invalid date value '" .
              ($byc_d || $byc) .
                "/$bm/$bd' - ignoring its components in entry '$key'";
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
            push @warnings, "Invalid date value '$eyc/$em/$ed' - ignoring its components in entry '$key'";
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
        push @warnings, "Pattern constraint has no pattern!";
      }
      foreach my $f (@{$c->{fields}}) {
        if (my $fv = $be->get_field($f)) {
          unless (imatch($fv, $patt)) {
            push @warnings, "Invalid value (pattern match fails) for field '$f' in entry '$key'";
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

1;

__END__

=head1 AUTHORS

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
