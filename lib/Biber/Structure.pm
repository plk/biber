package Biber::Structure;
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

Biber::Structure


=cut

my $logger = Log::Log4perl::get_logger('main');


=head2 new

    Initialize a Biber::Structure object

=cut

sub new {
  my $class = shift;
  my $struc = shift;
  my $self;
  if (defined($struc) and ref($struc) eq 'HASH') {
    $self = bless $struc, $class;
  }
  else {
    $self = bless {}, $class;
  }

  # Pull out legal entrytypes, fields and constraints and make lookup hash
  # for quick tests later

  # field datatypes
  my ($nullok, $skipout, @name, @list, @literal, @date, @integer, @range, @verbatim, @key, @entrykey, @datepart);

  # Create data for field types, including any aliases which might be
  # needed when reading the bib data.
  foreach my $f (@{$struc->{fields}{field}}) {
    if ($f->{fieldtype} eq 'list' and $f->{datatype} eq 'name') {
      push @name, $f->{content};
    }
    elsif ($f->{fieldtype} eq 'list' and $f->{datatype} eq 'literal') {
      push @list, $f->{content};
    }
    elsif ($f->{fieldtype} eq 'list' and $f->{datatype} eq 'key') {
      push @list, $f->{content};
    }
    elsif ($f->{fieldtype} eq 'list' and $f->{datatype} eq 'entrykey') {
      push @list, $f->{content};
    }
    elsif ($f->{fieldtype} eq 'field' and $f->{datatype} eq 'literal') {
      push @literal, $f->{content};
    }
    elsif ($f->{fieldtype} eq 'field' and $f->{datatype} eq 'datepart') {
      push @datepart, $f->{content};
    }
    elsif ($f->{fieldtype} eq 'field' and $f->{datatype} eq 'date') {
      push @date, $f->{content};
    }
    elsif ($f->{fieldtype} eq 'field' and $f->{datatype} eq 'integer') {
      push @integer, $f->{content};
    }
    elsif ($f->{fieldtype} eq 'field' and $f->{datatype} eq 'range') {
      push @range, $f->{content};
    }
    elsif ($f->{fieldtype} eq 'field' and $f->{datatype} eq 'verbatim') {
      push @verbatim, $f->{content};
    }
    elsif ($f->{fieldtype} eq 'field' and $f->{datatype} eq 'key') {
      push @key, $f->{content};
    }
    elsif ($f->{fieldtype} eq 'field' and $f->{datatype} eq 'entrykey') {
      push @entrykey, $f->{content};
    }

    # check null_ok
    if ($f->{nullok}) {
      $nullok->{$f->{content}} = 1;
    }
    # check skips - fields we dont' want to output to BBL
    if ($f->{skip_output}) {
      $skipout->{$f->{content}} = 1;
    }
  }

  # Store as lookup tables for speed and multiple re-use
  $self->{fields}{nullok}   = $nullok;
  $self->{fields}{skipout}  = $skipout;
  $self->{fields}{complex}  = { map {$_ => 1} (@name, @list, @range, @date) };
  $self->{fields}{literal}  = { map {$_ => 1} (@literal, @key, @integer, @entrykey) };
  $self->{fields}{datepart} = { map {$_ => 1} @datepart };
  $self->{fields}{name}     = { map {$_ => 1} @name };
  $self->{fields}{list}     = { map {$_ => 1} @list };
  $self->{fields}{verbatim} = { map {$_ => 1} @verbatim };
  $self->{fields}{range}    = { map {$_ => 1} @range };
  $self->{fields}{date}     = { map {$_ => 1} @date };

  my $leg_ents;
  my $ets = [ sort map {$_->{content}} @{$struc->{entrytypes}{entrytype}} ];

  foreach my $es (@$ets) {

    # fields for entrytypes
    my $lfs;
    foreach my $ef (@{$struc->{entryfields}}) {
      # Found a section describing legal fields for entrytype
      if (grep {($_->{content} eq $es) or ($_->{content} eq 'ALL')} @{$ef->{entrytype}}) {
        foreach my $f (@{$ef->{field}}) {
          $lfs->{$f->{content}} = 1;
        }
      }
    }

    # constraints
    my $constraints;
    foreach my $cd (@{$struc->{constraints}}) {
      # Found a section describing constraints for entrytype
      if (grep {($_->{content} eq $es) or ($_->{content} eq 'ALL')} @{$cd->{entrytype}}) {
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
                if ($f->{coerce}) {
                  # put the default override element at the front and flag it
                  unshift @$xorset, $f->{content};
                }
                else {
                  push @$xorset, $f->{content};
                }
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
            push @{$constraints->{data}}, $data;
          }
        }
      }
    }
    $leg_ents->{$es}{legal_fields} = $lfs;
    $leg_ents->{$es}{constraints} = $constraints;
  }
  $self->{legal_entrytypes} = $leg_ents;

  # date types
  my $dts;
  foreach my $dt (@{$struc->{datetypes}{datetype}}) {
    push @$dts, $dt->{content};
  }

  $self->{legal_datetypes} = $dts;

  return $self;
}


=head2 is_entrytype

    Returns boolean to say if an entrytype is a legal entrytype

=cut

sub is_entrytype {
  my $self = shift;
  my $type = shift;
  return $self->{legal_entrytypes}{$type} ? 1 : 0;
}

=head2 is_field_for_entrytype

    Returns boolean to say if a field is legal for an entrytype

=cut

sub is_field_for_entrytype {
  my $self = shift;
  my ($type, $field) = @_;
  if ($self->{legal_entrytypes}{ALL}{legal_fields}{$field} or
      $self->{legal_entrytypes}{$type}{legal_fields}{$field} or
      $self->{legal_entrytypes}{$type}{legal_fields}{ALL}) {
    return 1;
  }
  else {
    return 0;
  }
}


=head2 get_field_type

    Retrieve fields of a certain biblatex type from structure
    Return in sorted order so that bbl order doesn't change when changing
    .bcf. This really messes up tests otherwise.

=cut

sub get_field_type {
  my $self = shift;
  my $type = shift;
  return $self->{fields}{$type} ? [ sort keys %{$self->{fields}{$type}} ] : [];
}

=head2 is_field_type

    Returns boolean depending on whether a field is a certain biblatex type

=cut

sub is_field_type {
  my $self = shift;
  my ($type, $field) = @_;
  return $self->{fields}{$type}{$field} // 0;
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
  foreach my $c ((@{$self->{legal_entrytypes}{ALL}{constraints}{mandatory}},
                  @{$self->{legal_entrytypes}{$et}{constraints}{mandatory}})) {
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

  foreach my $c ((@{$self->{legal_entrytypes}{ALL}{constraints}{conditional}},
                  @{$self->{legal_entrytypes}{$et}{constraints}{conditional}})) {
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
    returns an arry of warnings, if any

=cut

sub check_data_constraints {
  my $self = shift;
  my $be = shift;
  my @warnings;
  my $et = $be->get_field('entrytype');
  my $key = $be->get_field('citekey');
  foreach my $c ((@{$self->{legal_entrytypes}{ALL}{constraints}{data}},
                  @{$self->{legal_entrytypes}{$et}{constraints}{data}})) {
    # This is the datatype of the constraint, not the field!
    if ($c->{datatype} eq 'integer') {
      my $dt = $STRUCTURE_DATATYPES{$c->{datatype}};
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
  }
  return @warnings;
}

=head2 check_date_components

     Perform content validation checks on date components by trying to
     instantiate a Date::Simple object.

=cut

sub check_date_components {
  my $self = shift;
  my $be = shift;
  my @warnings;
  my $et = $be->get_field('entrytype');
  my $key = $be->get_field('citekey');

  foreach my $f (@{$self->{legal_datetypes}}) {
    my ($d) = $f =~ m/\A(.*)date\z/xms;
    # Don't bother unless this type of date is defined (has a year)
    next unless $be->get_datafield($d . 'year');

    # When checking date components not split from date fields, have ignore the value
    # of an explicit YEAR field as it is allowed to be an arbitrary string
    # so we just set it to any valid value for the test
    my $byc;
    my $byc_d; # Display value for errors so as not to confuse people
    if ($d eq '' and not $be->get_field('datesplit')) {
      $byc = '1900'; # Any valid value is fine
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
  return @warnings;
}

=head2 dump

    Dump Biber::Structure object

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

Copyright 2009-2012 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
