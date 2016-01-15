package Biber::Entry::Name;
use v5.16;
use strict;
use warnings;

use Regexp::Common qw( balanced );
use Biber::Config;
use Data::Dump qw( pp );
use Log::Log4perl qw( :no_extra_logdie_message );
use List::Util qw( first );
use Unicode::Normalize;
no autovivification;

my $logger = Log::Log4perl::get_logger('main');

=encoding utf-8

=head1 NAME

Biber::Entry::Name

=head2 new

    Initialise a Biber::Entry::Name object, optionally with key=>value arguments.

=cut

sub new {
  my ($class, %params) = @_;
  my $dm = Biber::Config->get_dm;
  if (%params) {
    my $name = {};
    foreach my $attr ('useprefix',
                      'gender',
                      'namestring',
                      'nameinitstring',
                      'strip',
                      $dm->get_constant_value('nameparts')) {
      if (exists $params{$attr}) {
        $name->{$attr} = $params{$attr};
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

=head2 get_useprefix

    Get the useprefix option

=cut

sub get_useprefix {
  my $self = shift;
  return $self->{useprefix};
}

=head2 set_useprefix

    Set the useprefix option

=cut

sub set_useprefix {
  my ($self, $val) = @_;
  $self->{useprefix} = $val;
  return;
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

    Set the string of family names and string of fullnames
    Used to track uniquename=5 or 6

=cut

sub set_minimal_info {
  my ($self, $lns) = @_;
  $self->{familynames_string} = $lns;
  return;
}


=head2 get_minimal_info

    Get the name context used to track uniquename=5 or 6

=cut

sub get_minimal_info {
  my $self = shift;
  return $self->{familynames_string};
}


=head2 get_namepart

    Get a namepart by passed name

=cut

sub get_namepart {
  my ($self, $namepart) = @_;
  return $self->{$namepart}{string};
}

=head2 set_namepart

    Set a namepart by passed name

=cut

sub set_namepart {
  my ($self, $namepart, $val) = @_;
  $self->{$namepart}{string} = $val;
  return;
}

=head2 get_namepart_initial

    Get a namepart initial by passed name

=cut

sub get_namepart_initial {
  my ($self, $namepart) = @_;
  return $self->{$namepart}{initial};
}

=head2 set_namepart_initial

    Set a namepart initial by passed name

=cut

sub set_namepart_initial {
  my ($self, $namepart, $val) = @_;
  $self->{$namepart}{initial} = $val;
  return;
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

=head2 name_to_biblatexml {

    Create biblatexml data for a name

=cut

sub name_to_biblatexml {
  my $self = shift;
  my $xml = shift;
  my $out = shift;
  my $xml_prefix = $out->{xml_prefix};
  my @attrs;

  # name scope useprefix. Use defined() because this can be 0
  if ( defined($self->get_useprefix) ) {
    push @attrs, (useprefix => $self->get_useprefix);
  }

  $xml->startTag([$xml_prefix, 'name'], @attrs);

  # family name
  $self->name_part_to_bltxml($xml, $xml_prefix, 'family');

  # given name
  $self->name_part_to_bltxml($xml, $xml_prefix, 'given');

  # prefix
  $self->name_part_to_bltxml($xml, $xml_prefix, 'prefix');

  # suffix
  $self->name_part_to_bltxml($xml, $xml_prefix, 'suffix');

  $xml->endTag(); # Name
}

=head2 name_part_to_bltxml

    Return BibLaTeXML data for a name

=cut

sub name_part_to_bltxml {
  my ($self, $xml, $xml_prefix, $npn) = @_;
  my $np = $self->get_namepart($npn);
  my $nip = $self->get_namepart_initial($npn);
  if ($np) {
    $xml->startTag([$xml_prefix, 'namepart'], type => $npn);
    my $parts = [split(/[\s~]/, $np)];
    for (my $i=0;$i <= $#$parts;$i++) {
      if (my $init = $nip->[$i]) {
        $xml->startTag([$xml_prefix, 'namepart'], initial => $init);
      }
      else {
        $xml->startTag([$xml_prefix, 'namepart']);
      }
      $xml->characters(NFC($parts->[$i]));
      $xml->endTag();
    }
    $xml->endTag();
  }
}

=head2 name_to_bbl

    Return bbl data for a name

=cut

sub name_to_bbl {
  my $self = shift;

  my @pno; # per-name options
  my $pno; # per-name options final string

  # family name is always defined
  my $lni;
  my $ln  = Biber::Utils::join_name($self->get_namepart('family'));
  if ($self->was_stripped('family')) {
    $ln = Biber::Utils::add_outer($ln);
  }
  $lni = join('\bibinitperiod\bibinitdelim ', @{$self->get_namepart_initial('family')}) . '\bibinitperiod';
  $lni =~ s/\p{Pd}/\\bibinithyphendelim /gxms;

  # given name
  my $fn;
  my $fni;
  if ($fn = $self->get_namepart('given')) {
    $fn = Biber::Utils::join_name($fn);
    if ($self->was_stripped('given')) {
      $fn = Biber::Utils::add_outer($fn);
    }
    $fni = join('\bibinitperiod\bibinitdelim ', @{$self->get_namepart_initial('given')}) . '\bibinitperiod';
    $fni =~ s/\p{Pd}/\\bibinithyphendelim /gxms;
  }
  else {
    $fn = '';
    $fni = '';
  }

  # prefix
  my $pre;
  my $prei;
  if ($pre = $self->get_namepart('prefix')) {
    $pre = Biber::Utils::join_name($pre);
    if ($self->was_stripped('prefix')) {
      $pre = Biber::Utils::add_outer($pre);
    }
    $prei = join('\bibinitperiod\bibinitdelim ', @{$self->get_namepart_initial('prefix')}) . '\bibinitperiod';
    $prei =~ s/\p{Pd}/\\bibinithyphendelim /gxms;
  }
  else {
    $pre = '';
    $prei = '';
  }

  # suffix
  my $suf;
  my $sufi;
  if ($suf = $self->get_namepart('suffix')) {
    $suf = Biber::Utils::join_name($suf);
    if ($self->was_stripped('suffix')) {
      $suf = Biber::Utils::add_outer($suf);
    }
    $sufi = join('\bibinitperiod\bibinitdelim ', @{$self->get_namepart_initial('suffix')}) . '\bibinitperiod';
    $sufi =~ s/\p{Pd}/\\bibinithyphendelim /gxms;
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
  return "        {{$pno}{$ln}{$lni}{$fn}{$fni}{$pre}{$prei}{$suf}{$sufi}}%\n";
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
