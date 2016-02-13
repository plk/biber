package Biber::Entry::Name;
use v5.16;
use strict;
use warnings;
use parent qw(Class::Accessor);
__PACKAGE__->follow_best_practice;

use Regexp::Common qw( balanced );
use Biber::Config;
use Biber::Constants;
use Biber::Utils;
use Data::Dump qw( pp );
use Log::Log4perl qw( :no_extra_logdie_message );
use List::Util qw( first );
use Unicode::Normalize;
no autovivification;
my $logger = Log::Log4perl::get_logger('main');

# Names of simple package accessor attributes
__PACKAGE__->mk_accessors(qw (
                               hash
                               index
                               namestring
                               nameinitstring
                            ));

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
    foreach my $attr (keys %{$CONFIG_SCOPEOPT_BIBLATEX{NAME}},
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

=head2 name_to_biblatexml {

    Create biblatexml data for a name

=cut

sub name_to_biblatexml {
  my $self = shift;
  my $xml = shift;
  my $out = shift;
  my $xml_prefix = $out->{xml_prefix};
  my @attrs;

  # Add per-name options
  foreach my $pnoname (keys %{$CONFIG_SCOPEOPT_BIBLATEX{NAME}}) {
    if (defined($self->${\"get_$pnoname"})) {
      my $pno = $self->${\"get_$pnoname"};
      if ($CONFIG_OPTTYPE_BIBLATEX{lc($pnoname)} and
          $CONFIG_OPTTYPE_BIBLATEX{lc($pnoname)} eq 'boolean') {
        push @attrs, ($pnoname => Biber::Utils::map_boolean($pno, 'tostring'));
      }
      else {
        push @attrs, ($pnoname => $pno);
      }
    }
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
    my $parts = [split(/[\s~]/, $np)];
    # Compound name part
    if ($#$parts > 0) {
      $xml->startTag([$xml_prefix, 'namepart'], type => $npn);
      for (my $i=0;$i <= $#$parts;$i++) {
        if (my $init = $nip->[$i]) {
          $xml->startTag([$xml_prefix, 'namepart'], initial => $init);
        }
        else {
          $xml->startTag([$xml_prefix, 'namepart']);
        }
        $xml->characters(NFC($parts->[$i]));
        $xml->endTag();         # namepart
      }
      $xml->endTag();           # namepart
    }
    else { # simple name part
      if (my $init = $nip->[0]) {
        $xml->startTag([$xml_prefix, 'namepart'], type => $npn, initial => $init);
      }
      else {
        $xml->startTag([$xml_prefix, 'namepart']);
      }
      $xml->characters(NFC($parts->[0]));
      $xml->endTag();           # namepart
    }
  }
}

=head2 name_to_bbl

    Return bbl data for a name

=cut

sub name_to_bbl {
  my $self = shift;
  my $dm = Biber::Config->get_dm;
  my @pno; # per-name options
  my $pno; # per-name options final string
  my $namestring;
  my @namestrings;

  foreach my $np ($dm->get_constant_value('nameparts')) {# list type so returns list
    my $npc;
    my $npci;
    if ($npc = $self->get_namepart($np)) {
      $npc = Biber::Utils::join_name($npc);
      if ($self->was_stripped($np)) {
        $npc = Biber::Utils::add_outer($npc);
      }
      $npci = join('\bibinitperiod\bibinitdelim ', @{$self->get_namepart_initial($np)}) . '\bibinitperiod';
      $npci =~ s/\p{Pd}/\\bibinithyphendelim /gxms;
    }
    # Some of the subs above can result in these being undef so make sure there is an empty
    # string instead of undef so that interpolation below doesn't produce warnings
    $npc //= '';
    $npci //= '';
    if ($npc) {
      push @namestrings, "           $np={$npc}", "           ${np}_i={$npci}";
    }
  }

  # Generate uniquename if uniquename is requested
  if (defined($self->get_uniquename)) {
    push @pno, 'uniquename=' . $self->get_uniquename;
  }

  # Add per-name options
  foreach my $pnoname (keys %{$CONFIG_SCOPEOPT_BIBLATEX{NAME}}) {
    if (defined($self->${\"get_$pnoname"})) {
      my $pno = $self->${\"get_$pnoname"};
      if ($CONFIG_OPTTYPE_BIBLATEX{lc($pnoname)} and
          $CONFIG_OPTTYPE_BIBLATEX{lc($pnoname)} eq 'boolean') {
        push @pno, "$pnoname=" . Biber::Utils::map_boolean($pno, 'tostring');
      }
      else {
        push @pno, "$pnoname=$pno";
      }
    }
  }

  # Add the name hash to the options
  push @pno, 'hash=' . $self->get_hash;
  $pno = join(',', @pno);

  $namestring = "        {{$pno}{\%\n";
  $namestring .= join(",\n", @namestrings);
  $namestring .= "}}%\n";

  return $namestring;
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
