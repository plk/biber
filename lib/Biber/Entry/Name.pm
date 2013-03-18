package Biber::Entry::Name;
use v5.16;
use strict;
use warnings;

use Regexp::Common qw( balanced );
use Biber::Config;
use Data::Dump qw( pp );
use Log::Log4perl qw( :no_extra_logdie_message );
use List::Util qw( first );
my $logger = Log::Log4perl::get_logger('main');

=encoding utf-8

=head1 NAME

Biber::Entry::Name

=head2 new

    Initialize a Biber::Entry::Name object, optionally with key=>value arguments.

    Ex: Biber::Entry::Name->new( lastname=>"Bolzmann", firstname=>"Anna Maria", prefix => "von" )

=cut

sub new {
  my ($class, %params) = @_;
  if (%params) {
    my $name = {};
    foreach my $attr (qw/gender
                         lastname
                         lastname_i
                         firstname
                         firstname_i
                         middlename
                         middlename_i
                         prefix
                         prefix_i
                         suffix
                         suffix_i
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

=head2 TO_JSON

   Serialiser for JSON::XS::encode

=cut

sub TO_JSON {
  my $self = shift;
  my $json;
  while (my ($k, $v) = each(%{$self})) {
    $json->{$k} = $v;
  }
  return $json;
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

=head2 set_hash

    Set a hash for the name

=cut

sub set_hash {
  my ($self, $hash) = @_;
  $self->{hash} = $hash;
  return;
}

=head2 get_hash

    Get a hash for the name

=cut

sub get_hash {
  my $self = shift;
  return $self->{hash};
}



=head2 set_index

    Set a field telling what position in the name list the name is

=cut

sub set_index {
  my ($self, $index) = @_;
  $self->{index} = $index;
  return;
}

=head2 get_index

    Get the index of a Biber::Entry::Name object

=cut

sub get_index {
  my $self = shift;
  return $self->{index};
}


=head2 set_uniquename

    Set uniquename for a visible Biber::Entry::Name object
    Sets global flag to say that some uniquename value has changed

=cut

sub set_uniquename {
  my ($self, $uniquename) = @_;
  my $currval = $self->{uniquename};

  # Set modified flag to positive if we change something
  if (not defined($currval) or $currval != $uniquename) {
    Biber::Config->set_unul_changed(1);
  }
  $logger->trace('Setting uniquename for "' . $self->get_namestring . '" to ' . $uniquename);
  $self->{uniquename} = $uniquename;
  return;
}

=head2 set_uniquename_all

    Set uniquename for a Biber::Entry::Name object

=cut

sub set_uniquename_all {
  my ($self, $uniquename) = @_;

  $logger->trace('Setting uniquename_all for "' . $self->get_namestring . '" to ' . $uniquename);
  $self->{uniquename_all} = $uniquename;
  return;
}


=head2 get_uniquename

    Get uniquename for a visible Biber::Entry::Name object

=cut

sub get_uniquename {
  my $self = shift;
  return $self->{uniquename};
}

=head2 get_uniquename_all

    Get uniquename for a Biber::Entry::Name object

=cut

sub get_uniquename_all {
  my $self = shift;
  return $self->{uniquename_all};
}


=head2 reset_uniquename

    Reset uniquename for a Biber::Entry::Name object

=cut

sub reset_uniquename {
  my $self = shift;
  $self->{uniquename} = 0;
  return;
}


=head2 set_minimal_info

    Set the string of lastnames and string of fullnames
    Used to track uniquename=5 or 6

=cut

sub set_minimal_info {
  my ($self, $lns) = @_;
  $self->{lastnames_string} = $lns;
  return;
}


=head2 get_minimal_info

    Get the name context used to track uniquename=5 or 6

=cut

sub get_minimal_info {
  my $self = shift;
  return $self->{lastnames_string};
}


=head2 get_namepart

    Get a namepart by passed name

=cut

sub get_namepart {
  my ($self, $namepart) = @_;
  return $self->{$namepart};
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

  my @pno; # per-name options
  my $pno; # per-name options final string

  # lastname is always defined
  my $lni;
  my $ln  = Biber::Utils::join_name($self->get_lastname);
  if ($self->was_stripped('lastname')) {
    $ln = Biber::Utils::add_outer($ln);
  }
  $lni = join('\bibinitperiod\bibinitdelim ', @{$self->get_lastname_i}) . '\bibinitperiod';
  $lni =~ s/\-/\\bibinithyphendelim /gxms;

  # firstname
  my $fn;
  my $fni;
  if ($fn = $self->get_firstname) {
    $fn = Biber::Utils::join_name($fn);
    if ($self->was_stripped('firstname')) {
      $fn = Biber::Utils::add_outer($fn);
    }
    $fni = join('\bibinitperiod\bibinitdelim ', @{$self->get_firstname_i}) . '\bibinitperiod';
    $fni =~ s/\-/\\bibinithyphendelim /gxms;
  }
  else {
    $fn = '';
    $fni = '';
  }

  # middlename
  my $mn;
  my $mni;
  if ($mn = $self->get_middlename) {
    $mn = Biber::Utils::join_name($mn);
    $mni = join('\bibinitperiod\bibinitdelim ', @{$self->get_middlename_i}) . '\bibinitperiod';
    $mni =~ s/\-/\\bibinithyphendelim /gxms;
  }
  else {
    $mn = '';
    $mni = '';
  }

  # prefix
  my $pre;
  my $prei;
  if ($pre = $self->get_prefix) {
    $pre = Biber::Utils::join_name($pre);
    if ($self->was_stripped('prefix')) {
      $pre = Biber::Utils::add_outer($pre);
    }
    $prei = join('\bibinitperiod\bibinitdelim ', @{$self->get_prefix_i}) . '\bibinitperiod';
    $prei =~ s/\-/\\bibinithyphendelim /gxms;
  }
  else {
    $pre = '';
    $prei = '';
  }

  # suffix
  my $suf;
  my $sufi;
  if ($suf = $self->get_suffix) {
    $suf = Biber::Utils::join_name($suf);
    if ($self->was_stripped('suffix')) {
      $suf = Biber::Utils::add_outer($suf);
    }
    $sufi = join('\bibinitperiod\bibinitdelim ', @{$self->get_suffix_i}) . '\bibinitperiod';
    $sufi =~ s/\-/\\bibinithyphendelim /gxms;
  }
  else {
    $suf = '';
    $sufi = '';
  }

  # Generate uniquename if uniquename is requested
  if (defined($self->get_uniquename)) {
    push @pno, 'uniquename=' . $self->get_uniquename;
  }
  # Add the name hash to the options
  push @pno, 'hash=' . $self->get_hash;
  $pno = join(',', @pno);
  # Some data sources support middle names
  if ($self->get_middlename) {
    return "        {{$pno}{$ln}{$lni}{$fn}{$fni}{$mn}{$mni}{$pre}{$prei}{$suf}{$sufi}}%\n";
  }
  else {
    return "        {{$pno}{$ln}{$lni}{$fn}{$fni}{$pre}{$prei}{$suf}{$sufi}}%\n";
  }
}

=head2 dump

    Dump Biber::Entry::Name object

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
