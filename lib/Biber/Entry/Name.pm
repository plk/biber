package Biber::Entry::Name;

use Regexp::Common qw( balanced );

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
    foreach my $attr (qw/lastname firstname prefix suffix namestring nameinitstring/) {
      if (exists $params{$attr}) {
        $name->{$attr} = $params{$attr}
      }
    }
    return bless $name, $class;
  } else {
    return bless {}, $class;
  }
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
  my $lni = Biber::Utils::getinitials($ln);

  # firstname
  my $fn;
  my $fni;
  if ($fn = $self->get_firstname) {
    $fni = Biber::Utils::getinitials($fn);
  }
  else {
    $fn  = '';
    $fni = '';
  }

  # prefix
  my $pre;
  my $prei;
  if ($pre = $self->get_prefix) {
    $prei = Biber::Utils::getinitials($pre);
  }
  else {
    $pre  = '';
    $prei = '';
  }

  # suffix
  my $suf;
  my $sufi;
  if ($suf = $self->get_suffix) {
    $sufi = Biber::Utils::getinitials($suf);
  }
  else {
    $suf  = '';
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
  $ln =~ s/\s/~/g if $ln;         # Murder Smith -> Murder~Smith
  if ( Biber::Config->getblxoption('terseinits') ) {
    $lni = Biber::Utils::tersify($lni);
    $fni = Biber::Utils::tersify($fni);
    $prei = Biber::Utils::tersify($prei);
    $sufi = Biber::Utils::tersify($sufi);
  }
  return "    {{$ln}{$lni}{$fn}{$fni}{$pre}{$prei}{$suf}{$sufi}}%\n";
}

=head1 AUTHORS

François Charette, C<< <firmicus at gmx.net> >>
Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2010 François Charette and Philip Kime, all rights reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

=cut

1;

# vim: set tabstop=2 shiftwidth=2 expandtab:
