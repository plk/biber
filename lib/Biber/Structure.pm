package Biber::Structure;
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

  # Create internal aliases data format for easy use
  my $aliases;
  my $reverse_aliases;
  foreach my $alias (@{$struc->{aliases}{alias}}) {
    $aliases->{$alias->{type}}{$alias->{name}{content}}
      = {
         realname => $alias->{realname}{content}
        };
    # So we can automatically add aliases to the field definitions
    # without having to maintain them there too.
    $reverse_aliases->{$alias->{realname}{content}} = $alias->{name}{content};

    if (exists($alias->{field})) {
      $aliases->{$alias->{type}}{$alias->{name}{content}}{fields}
        = { map {$_->{name} => $_->{content}} @{$alias->{field}}};
    }
  }
  $self->{aliases} = $aliases;
  $self->{reverse_aliases} = $reverse_aliases;

  # Pull out legal entrytypes, fields and constraints and make lookup hash
  # for quick tests later
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

    # field datatypes
    my ($nullok, $skipout, @name, @list, @literal, @date, @integer, @range, @verbatim, @key);

    # Create data for field types, including any aliases which might be
    # needed when reading the bib data.
    foreach my $f (@{$struc->{fields}{field}}) {
      if ($f->{fieldtype} eq 'list' and $f->{datatype} eq 'name') {
        push @name, $f->{content};
        push @name, $reverse_aliases->{$f->{content}} if exists($reverse_aliases->{$f->{content}});
      }
      elsif ($f->{fieldtype} eq 'list' and $f->{datatype} eq 'literal') {
        push @list, $f->{content};
        push @list, $reverse_aliases->{$f->{content}} if exists($reverse_aliases->{$f->{content}});
      }
      elsif ($f->{fieldtype} eq 'list' and $f->{datatype} eq 'key') {
        push @list, $f->{content};
        push @list, $reverse_aliases->{$f->{content}} if exists($reverse_aliases->{$f->{content}});
      }
      elsif ($f->{fieldtype} eq 'field' and $f->{datatype} eq 'literal') {
        push @literal, $f->{content};
        push @literal, $reverse_aliases->{$f->{content}} if exists($reverse_aliases->{$f->{content}});
      }
      elsif ($f->{fieldtype} eq 'field' and $f->{datatype} eq 'date') {
        push @date, $f->{content};
        push @date, $reverse_aliases->{$f->{content}} if exists($reverse_aliases->{$f->{content}});
      }
      elsif ($f->{fieldtype} eq 'field' and $f->{datatype} eq 'integer') {
        push @integer, $f->{content};
        push @integer, $reverse_aliases->{$f->{content}} if exists($reverse_aliases->{$f->{content}});
      }
      elsif ($f->{fieldtype} eq 'field' and $f->{datatype} eq 'range') {
        push @range, $f->{content};
        push @range, $reverse_aliases->{$f->{content}} if exists($reverse_aliases->{$f->{content}});
      }
      elsif ($f->{fieldtype} eq 'field' and $f->{datatype} eq 'verbatim') {
        push @verbatim, $f->{content};
        push @verbatim, $reverse_aliases->{$f->{content}} if exists($reverse_aliases->{$f->{content}});
      }
      elsif ($f->{fieldtype} eq 'field' and $f->{datatype} eq 'key') {
        push @key, $f->{content};
        push @key, $reverse_aliases->{$f->{content}} if exists($reverse_aliases->{$f->{content}});
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
    $self->{fields}{literal}  = { map {$_ => 1} (@literal, @key, @integer) };
    $self->{fields}{name}     = { map {$_ => 1} @name };
    $self->{fields}{list}     = { map {$_ => 1} @list };
    $self->{fields}{verbatim} = { map {$_ => 1} @verbatim };
    $self->{fields}{range}    = { map {$_ => 1} @range };
    $self->{fields}{date}     = { map {$_ => 1} @date };

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

=head2 resolve_entry_aliases

    Resolve entrytype alias for an entry, if any

=cut

sub resolve_entry_aliases {
  my $self = shift;
  my $be = shift;
  # normalise field name according to alias
  if (my $alias = $self->{aliases}{entrytype}{$be->get_field('entrytype')}) {
    $be->set_field('entrytype', $alias->{realname});
    # Set any other fields which normalising this alias requires if not already set
    foreach my $field (keys %{$alias->{fields}}) {
      unless ($be->field_exists($field)) {
        $be->set_field($field, $alias->{fields}{$field});
      }
    }
  }

  return;
}

=head2 resolve_field_aliases

    Resolve field alias for an entry, if any

=cut

sub resolve_field_aliases {
  my $self = shift;
  my $be = shift;
  my @warnings;
  my $citekey = $be->get_field('dskey');
  while (my ($faliasn, $falias) = each %{$self->{aliases}{field}}) {
    # Field which is an alias and has a value?
    if (my $falias_value = $be->get_field($faliasn)) {
      my $freal = $falias->{realname};
      # If both a field and its alias is set, warn and delete alias field
      if ($be->get_field($freal)) {
        push @warnings, "Field '$faliasn' is an alias for field '$freal' but both are defined in entry with key '$citekey' - skipping field '$faliasn'"; # Warn as that's wrong
        $be->del_field($faliasn);
      }
      else {
        # datafield since aliases only apply to actual data fields from the data file
        $be->set_datafield($freal, $falias_value);
        $be->del_field($faliasn);
      }
    }
  }
  return @warnings;
}

=head2 get_field_type

    Retrieve fields of a certain biblatex type from structure
    Return in sorted order so that bbl order doesn't change when changing
    .bcf. This really messes up tests otherwise.

=cut

sub get_field_type {
  my $self = shift;
  my $type = shift;
  return $self->{fields}{$type} ? [ sort keys %{$self->{fields}{$type}} ] : '';
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
  my $citekey = $be->get_field('dskey');
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
              push @warnings, "Mandatory fields - only one of '" . join(', ', @fs) . "' must be defined in entry '$citekey' ignoring field '$of'";
              $be->del_field($of);
            }
            $flag = 1;
            $xorflag = 1;
          }
        }
        unless ($flag) {
          push @warnings, "Missing mandatory field - one of '" . join(', ', @fs) . "' must be defined in entry '$citekey'";
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
          push @warnings, "Missing mandatory field - one of '" . join(', ', @fs) . "' must be defined in entry '$citekey'";
        }
      }
    }
    # Simple mandatory field
    else {
      unless ($be->field_exists($c)) {
        push @warnings, "Missing mandatory field '$c' in entry '$citekey'";
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
  my $citekey = $be->get_field('dskey');

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
  my $citekey = $be->get_field('dskey');
  foreach my $c ((@{$self->{legal_entrytypes}{ALL}{constraints}{data}},
                  @{$self->{legal_entrytypes}{$et}{constraints}{data}})) {
    if ($c->{datatype} eq 'integer') {
      my $dt = $STRUCTURE_DATATYPES{$c->{datatype}};
      foreach my $f (@{$c->{fields}}) {
        if (my $fv = $be->get_field($f)) {
          unless ( $fv =~ /$dt/ ) {
            push @warnings, "Invalid format (integer) of field '$f' - ignoring field in entry '$citekey'";
            $be->del_field($f);
            next;
          }
          if (my $fmin = $c->{rangemin}) {
            unless ($fv >= $fmin) {
              push @warnings, "Invalid value of field '$f' must be '>=$fmin' - ignoring field in entry '$citekey'";
              $be->del_field($f);
              next;
            }
          }
          if (my $fmax = $c->{rangemax}) {
            unless ($fv <= $fmax) {
              push @warnings, "Invalid value of field '$f' must be '<=$fmax' - ignoring field in entry '$citekey'";
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

     Perform content validation checks on data components by trying to
     instantiate a Date::Simple object.

=cut

sub check_date_components {
  my $self = shift;
  my $be = shift;
  my @warnings;
  my $et = $be->get_field('entrytype');
  my $citekey = $be->get_field('dskey');

  foreach my $c ((@{$self->{legal_entrytypes}{ALL}{constraints}{data}},
                  @{$self->{legal_entrytypes}{$et}{constraints}{data}})) {
    if ($c->{datatype} eq 'datespec') {
      foreach my $f (@{$c->{fields}}) {
        my ($d) = $f =~ m/\A(.*)date\z/xms;

        # The only two data source date fields which aren't called "*date" are
        # YEAR and MONTH. Explicit YEAR doesn't need validating as it can be an
        # arbitrary string by design. Explicit month can be validated so we do. Then
        # we validate pseudo-fields which were derived from "*date" fields.
        if (my $m = $be->get_datafield($d . 'month')) {
          my $int = $STRUCTURE_DATATYPES{integer};
          unless ($m =~ /$int/ and $m <= 12 and $m >= 1) {
            push @warnings, "Invalid value of field 'month' must be and integer between 1 and 12 - ignoring field in entry '$citekey'";
            $be->del_datafield('month');
          }
        }

        # Begin date
        if (my $by = $be->get_pseudodatafield($d . 'year')) {
          my $bm = $be->get_pseudodatafield($d . 'month') || '01';
          my $bd = $be->get_pseudodatafield($d . 'day') || '01';
          my $begin_date = "$by$bm$bd";
          $logger->debug("Checking date value '$by$bm$bd' for key '$citekey'");
          unless (Date::Simple->new($begin_date)) {
            push @warnings, "Invalid value '$begin_date' of date field '$f' - ignoring field in entry '$citekey'";
            $be->del_pseudodatafield($d . 'year');
            $be->del_pseudodatafield($d . 'month');
            $be->del_pseudodatafield($d . 'day');
            next;
          }
        }
        # End date
        # defined and some value - end*year can be empty but defined in which case,
        # we don't need to validate
        if (my $ey = $be->get_pseudodatafield($d . 'endyear')) {
          my $em = $be->get_pseudodatafield($d . 'endmonth') || '01';
          my $ed = $be->get_pseudodatafield($d . 'endday') || '01';
          my $end_date = "$ey$em$ed";
          $logger->debug("Checking date value '$ey$em$ed' for key '$citekey'");
          unless (Date::Simple->new($end_date)) {
            push @warnings, "Invalid value '$end_date' of date field '$f' - ignoring field in entry '$citekey'";
            $be->del_pseudodatafield($d . 'endyear');
            $be->del_pseudodatafield($d . 'endmonth');
            $be->del_pseudodatafield($d . 'endday');
            next;
          }
        }
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

=head1 AUTHORS

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


1;
