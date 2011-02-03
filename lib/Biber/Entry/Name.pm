package Biber::Entry::Name;
#use feature 'unicode_strings';

use Regexp::Common qw( balanced );
use Data::Dump qw( pp );

=encoding utf-8

=head1 NAME

Biber::Entry::Name

=head2 new

    Initialize a Biber::Entry::Name object, optionally with key=>value arguments.

    Ex: Biber::Entry::Name->new( lastname="Bolzmann" firstname=>"Anna Maria" prefix => "von" )

=cut

sub new {
  my ($class, %params) = @_;
  if (%params) {
    my $name = {};
    foreach my $attr (qw/gender
                         lastname
                         lastname_i
                         lastname_it
                         firstname
                         firstname_i
                         firstname_it
                         middlename
                         middlename_i
                         middlename_it
                         prefix
                         prefix_i
                         prefix_it
                         suffix
                         suffix_i
                         suffix_it
                         namestring
                         nameinitstring
                         strip/) {
      if (exists $params{$attr}) {
        $name->{$attr} = $params{$attr}
      }
    }
    return bless $name, $class;
  } else {
    return bless {}, $class;
  }
}

=head2 notnull

    Test for an empty object

=cut

sub notnull {
  my $self = shift;
  my @arr = keys %$self;
  return $#arr > -1 ? 1 : 0;
}


=head2 was_stripped

    Return boolean to tell if the passed field had braces stripped from the original

=cut

sub was_stripped {
  my ($self, $part) = @_;
  return exists($self->{strip}) ? $self->{strip}{$part} : undef;
}


=head2 set_firstname

    Set firstname for a Biber::Entry::Name object

=cut

sub set_firstname {
  my ($self, $val) = @_;
  $self->{firstname} = $val;
  return;
}

=head2 get_firstname

    Get firstname for a Biber::Entry::Name object

=cut

sub get_firstname {
  my $self = shift;
  return $self->{firstname};
}

=head2 get_firstname_i

    Get firstname initials for a Biber::Entry::Name object

=cut

sub get_firstname_i {
  my $self = shift;
  return $self->{firstname_i};
}

=head2 get_firstname_it

    Get firstname terse initials for a Biber::Entry::Name object

=cut

sub get_firstname_it {
  my $self = shift;
  return $self->{firstname_it};
}


=head2 set_middlename

    Set middlename for a Biber::Entry::Name object

=cut

sub set_middlename {
  my ($self, $val) = @_;
  $self->{middlename} = $val;
  return;
}

=head2 get_middlename

    Get middlename for a Biber::Entry::Name object

=cut

sub get_middlename {
  my $self = shift;
  return $self->{middlename};
}

=head2 get_middlename_i

    Get middlename initials for a Biber::Entry::Name object

=cut

sub get_middlename_i {
  my $self = shift;
  return $self->{middlename_i};
}

=head2 get_middlename_it

    Get middlename terse initials for a Biber::Entry::Name object

=cut

sub get_middlename_it {
  my $self = shift;
  return $self->{middlename_it};
}


=head2 set_lastname

    Set lastname for a Biber::Entry::Name object

=cut

sub set_lastname {
  my ($self, $val) = @_;
  $self->{lastname} = $val;
  return;
}

=head2 get_lastname

    Get lastname for a Biber::Entry::Name object

=cut

sub get_lastname {
  my $self = shift;
  return $self->{lastname};
}

=head2 get_lastname_i

    Get lastname initials for a Biber::Entry::Name object

=cut

sub get_lastname_i {
  my $self = shift;
  return $self->{lastname_i};
}

=head2 get_lastname_it

    Get lastname terse initials for a Biber::Entry::Name object

=cut

sub get_lastname_it {
  my $self = shift;
  return $self->{lastname_it};
}


=head2 set_suffix

    Set suffix for a Biber::Entry::Name object

=cut

sub set_suffix {
  my ($self, $val) = @_;
  $self->{suffix} = $val;
  return;
}

=head2 get_suffix

    Get suffix for a Biber::Entry::Name object

=cut

sub get_suffix {
  my $self = shift;
  return $self->{suffix};
}

=head2 get_suffix_i

    Get suffix initials for a Biber::Entry::Name object

=cut

sub get_suffix_i {
  my $self = shift;
  return $self->{suffix_i};
}

=head2 get_suffix_it

    Get suffix terse initials for a Biber::Entry::Name object

=cut

sub get_suffix_it {
  my $self = shift;
  return $self->{suffix_it};
}


=head2 set_prefix

    Set prefix for a Biber::Entry::Name object

=cut

sub set_prefix {
  my ($self, $val) = @_;
  $self->{prefix} = $val;
  return;
}

=head2 get_prefix

    Get prefix for a Biber::Entry::Name object

=cut

sub get_prefix {
  my $self = shift;
  return $self->{prefix};
}

=head2 get_prefix_i

    Get prefix initials for a Biber::Entry::Name object

=cut

sub get_prefix_i {
  my $self = shift;
  return $self->{prefix_i};
}

=head2 get_prefix_it

    Get prefix terse initials for a Biber::Entry::Name object

=cut

sub get_prefix_it {
  my $self = shift;
  return $self->{prefix_it};
}


=head2 set_gender

    Set gender for a Biber::Entry::Name object

=cut

sub set_gender {
  my ($self, $val) = @_;
  $self->{gender} = $val;
  return;
}

=head2 get_gender

    Get gender for a Biber::Entry::Name object

=cut

sub get_gender {
  my $self = shift;
  return $self->{gender};
}



=head2 set_namestring

    Set namestring for a Biber::Entry::Name object

=cut

sub set_namestring {
  my ($self, $val) = @_;
  $self->{namestring} = $val;
  return;
}

=head2 get_namestring

    Get namestring for a Biber::Entry::Name object

=cut

sub get_namestring {
  my $self = shift;
  return $self->{namestring};
}

=head2 set_nameinitstring

    Set nameinitstring for a Biber::Entry::Name object

=cut

sub set_nameinitstring {
  my ($self, $val) = @_;
  $self->{nameinitstring} = $val;
  return;
}

=head2 get_nameinitstring

    Get nameinitstring for a Biber::Entry::Name object

=cut

sub get_nameinitstring {
  my $self = shift;
  return $self->{nameinitstring};
}

=head2 name_to_bbl {

    Return bbl data for a name

=cut

sub name_to_bbl {
  my $self = shift;

  # lastname is always defined
  my $ln  = $self->get_lastname;
  if ($self->was_stripped('lastname')) {
    $ln = Biber::Utils::add_outer($ln);
  }
    my $lni = Biber::Config->getblxoption('terseinits') ? $self->get_lastname_it : $self->get_lastname_i;

  # firstname
  my $fn;
  my $fni;
  if ($fn = $self->get_firstname) {
    if ($self->was_stripped('firstname')) {
      $fn = Biber::Utils::add_outer($fn);
    }
    $fni = Biber::Config->getblxoption('terseinits') ? $self->get_firstname_it : $self->get_firstname_i;
  }
  else {
    $fn = '';
    $fni = '';
  }

  # middlename
  my $mn;
  my $mni;
  if ($mn = $self->get_middlename) {
    $mni = Biber::Config->getblxoption('terseinits') ? $self->get_middlename_it : $self->get_middlename_i;
  }
  else {
    $mn = '';
    $mni = '';
  }

  # prefix
  my $pre;
  my $prei;
  if ($pre = $self->get_prefix) {
    if ($self->was_stripped('prefix')) {
      $pre = Biber::Utils::add_outer($pre);
    }
    $prei = Biber::Config->getblxoption('terseinits') ? $self->get_prefix_it : $self->get_prefix_i;
  }
  else {
    $pre = '';
    $prei = '';
  }

  # suffix
  my $suf;
  my $sufi;
  if ($suf = $self->get_suffix) {
    if ($self->was_stripped('suffix')) {
      $suf = Biber::Utils::add_outer($suf);
    }
    $sufi = Biber::Config->getblxoption('terseinits') ? $self->get_suffix_it : $self->get_suffix_i;
  }
  else {
    $suf = '';
    $sufi = '';
  }

  # Can't just replace all spaces in first names with "~" as this could
  # potentially be too long and would do nasty line-break things in LaTeX
  # So, be a bit picky and only attach initials/protected things
  # J. Frank -> J.~Frank
  # {J.\,P.} Frank -> {J.\,P.}~Frank
  $fn =~ s/(\p{Lu}\.|$RE{balanced}{-parens=>'{}'})\s+/$1~/g;
  # Bernard H. -> Bernard~H.
  # Bernard {H.\,P.} -> Bernard~{H.\,P.}
  $fn =~ s/\s+(\p{Lu}\.|$RE{balanced}{-parens=>'{}'})/~$1/g;
  $pre =~ s/\s/~/g if $pre;       # van der -> van~der
  # BIBLATEXML supports middle names
  if ($self->get_middlename) {
    return "      {{$ln}{$lni}{$fn}{$fni}{$mn}{$mni}{$pre}{$prei}{$suf}{$sufi}}%\n";
  }
  else {
    return "      {{$ln}{$lni}{$fn}{$fni}{$pre}{$prei}{$suf}{$sufi}}%\n";
  }
}


=head2 dump

    Dump Biber::Entry::Name object

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

# vim: set tabstop=2 shiftwidth=2 expandtab:
