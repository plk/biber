package Biber::Entry::Name;
use v5.24;
use strict;
use warnings;
use parent qw(Class::Accessor);
__PACKAGE__->follow_best_practice;

use Regexp::Common qw( balanced );
use Biber::Annotation;
use Biber::Config;
use Biber::Constants;
use Biber::Utils;
use Data::Dump qw( pp );
use Data::Uniqid qw (suniqid);
use Log::Log4perl qw( :no_extra_logdie_message );
use List::Util qw( first );
use Unicode::Normalize;
no autovivification;
my $logger = Log::Log4perl::get_logger('main');

# Names of simple package accessor attributes for those not created automatically
# by the option scope in the .bcf
__PACKAGE__->mk_accessors(qw (
                               gender
                               hash
                               index
                               id
                               rawstring
                            ));

=encoding utf-8

=head1 NAME

Biber::Entry::Name - Biber::Entry::Name objects

=head2 new

    Initialise a Biber::Entry::Name object, optionally with key=>value arguments.

=cut

sub new {
  my ($class, %params) = @_;
  my $dm = Biber::Config->get_dm;
  if (%params) {
    my $name = {};

    # Name is an XDATA reference
    if (my $xdata = $params{xdata}) {
      $name->{xdata} = $xdata;
      $name->{id} = suniqid;
      return bless $name, $class;
    }

    foreach my $attr (keys $CONFIG_SCOPEOPT_BIBLATEX{NAME}->%*,
                      'gender',
                      'useprefix',
                      'strip') {
      if (exists $params{$attr}) {
        $name->{$attr} = $params{$attr};
      }
    }
    foreach my $np ($dm->get_constant_value('nameparts')) {
      if (exists $params{$np}) {
        $name->{nameparts}{$np} = $params{$np};
      }
    }

    # Add any user-defined hashid
    if (my $hid = $params{hashid}) {
      $name->{hashid} = $hid;
    }

    $name->{rawstring} = join('',
                              map {$name->{nameparts}{$_}{string} // ''} keys $name->{nameparts}->%*);
    $name->{id} = suniqid;
    return bless $name, $class;
  }
  else {
    return bless {id => suniqid}, $class;
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

=head2 get_xdata

    Get any xdata reference information for a name

=cut

sub get_xdata {
  my $self = shift;
  return $self->{xdata} || '';
}

=head2 get_nameparts

    Get nameparts for a name

=cut

sub get_nameparts {
  my $self = shift;
  return keys $self->{nameparts}->%*;
}

=head2 get_hash_namepart

    Get a namepart determined by a namehashtemplate

=cut

sub get_hash_namepart {
  my ($self, $namepart, $nhtemplate) = @_;
  foreach my $np ($nhtemplate->@*) {
    if (fc($np->{namepart}) eq fc($namepart)) {
      if (fc($np->{hashscope}) eq 'init') {
        if ($self->{nameparts}{$namepart}{initial}) {
          return join('', $self->{nameparts}{$namepart}{initial}->@*);
        }
        else {
          return '';
        }
      }
      elsif (fc($np->{hashscope}) eq 'full') {
        return $self->{nameparts}{$namepart}{string} || '';
      }
    }
  }
  return '';
}

=head2 get_hashid

    Get a hashid by passed name

=cut

sub get_hashid {
  my ($self, $namepart) = @_;
  return $self->{hashid};
}

=head2 get_namepart

    Get a namepart by passed name

=cut

sub get_namepart {
  my ($self, $namepart) = @_;
  # prevent warnings when concating arbitrary nameparts
  return $self->{nameparts}{$namepart}{string} || '';
}

=head2 set_namepart

    Set a namepart by passed name

=cut

sub set_namepart {
  my ($self, $namepart, $val) = @_;
  $self->{nameparts}{$namepart}{string} = $val;
  return;
}

=head2 get_namepart_initial

    Get a namepart initial by passed name

=cut

sub get_namepart_initial {
  my ($self, $namepart) = @_;
  return $self->{nameparts}{$namepart}{initial} || '';
}

=head2 set_namepart_initial

    Set a namepart initial by passed name

=cut

sub set_namepart_initial {
  my ($self, $namepart, $val) = @_;
  $self->{nameparts}{$namepart}{initial} = $val;
  return;
}

=head2 name_to_biblatexml {

    Create biblatexml data for a name

=cut

sub name_to_biblatexml {
  my ($self, $out, $xml, $key, $namefield, $count) = @_;
  my $xml_prefix = $out->{xml_prefix};
  my $dm = Biber::Config->get_dm;
  my @attrs;


  # Add per-name options
  foreach my $no (keys $CONFIG_SCOPEOPT_BIBLATEX{NAME}->%*) {
    if (defined($self->${\"get_$no"})) {
      my $nov = $self->${\"get_$no"};

      if ($CONFIG_BIBLATEX_OPTIONS{NAME}{$no}{OUTPUT}) {
        push @attrs, ($no => Biber::Utils::map_boolean($no, $nov, 'tostring'));
      }
    }
  }

  # gender
  if (my $g = $self->get_gender) {
    push @attrs, ('gender' => $g);
  }

  # name scope annotation
  if (my $ann = Biber::Annotation->get_annotation('item', $key, $namefield, $count)) {
    push @attrs, ('annotation' => $ann);
  }

  $xml->startTag([$xml_prefix, 'name'], @attrs);

  foreach my $np ($dm->get_constant_value('nameparts')) {# list type so returns list
    $self->name_part_to_bltxml($xml, $xml_prefix, $key, $namefield, $np, $count);
  }

  $xml->endTag(); # Name
}

=head2 name_part_to_bltxml

    Return BibLaTeXML data for a name

=cut

sub name_part_to_bltxml {
  my ($self, $xml, $xml_prefix, $key, $namefield, $npn, $count) = @_;
  my $np = $self->get_namepart($npn);
  my $nip = $self->get_namepart_initial($npn);
  if ($np) {
    my $parts = [split(/[\s~]/, $np)];
    my @attrs;

    # namepart scope annotation
    if (my $ann = Biber::Annotation->get_annotation('part', $key, $namefield, $count, $npn)) {
      push @attrs, ('annotation' => $ann);
    }

    # Compound name part
    if ($parts->$#* > 0) {
      $xml->startTag([$xml_prefix, 'namepart'], type => $npn, @attrs);
      for (my $i=0;$i <= $parts->$#*;$i++) {
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
        $xml->startTag([$xml_prefix, 'namepart'], type => $npn, initial => $init, @attrs);
      }
      else {
        $xml->startTag([$xml_prefix, 'namepart']);
      }
      $xml->characters(NFC($parts->[0]));
      $xml->endTag();           # namepart
    }
  }
}


=head2 name_to_bibjson {

    Create bibjson data for a name

=cut

sub name_to_bibjson {
  my ($self, $out, $json, $key, $namefield, $count) = @_;
  my $dm = Biber::Config->get_dm;
  my %attrs;


  # Add per-name options
  foreach my $no (keys $CONFIG_SCOPEOPT_BIBLATEX{NAME}->%*) {
    if (defined($self->${\"get_$no"})) {
      my $nov = $self->${\"get_$no"};

      if ($CONFIG_BIBLATEX_OPTIONS{NAME}{$no}{OUTPUT}) {
        $attrs{$no} = Biber::Utils::map_boolean($no, $nov, 'tostring');
      }
    }
  }

  # gender
  if (my $g = $self->get_gender) {
    $attrs{gender} = $g;
  }

  # name scope annotation
  if (my $ann = Biber::Annotation->get_annotation('item', $key, $namefield, $count)) {
    $attrs{annotation} = $ann;
  }

  while (my ($option, $val) = each %attrs) {
    $json->add_property($option => NFC($val));
  }

  foreach my $np ($dm->get_constant_value('nameparts')) {# list type so returns list
    $self->name_part_to_bibjson($json, $key, $namefield, $np, $count);
  }
}

=head2 name_part_to_bibjson

    Return bibjson data for a name

=cut

sub name_part_to_bibjson {
  my ($self, $json, $key, $namefield, $npn, $count) = @_;
  my $np = $self->get_namepart($npn);
  my $nip = $self->get_namepart_initial($npn);
  if ($np) {
    my $parts = [split(/[\s~]/, $np)];
    my %attrs;

    # namepart scope annotation
    if (my $ann = Biber::Annotation->get_annotation('part', $key, $namefield, $count, $npn)) {
      $attrs{annotation} = $ann;
    }

    $json->start_property('namepart');
    $json->start_object();
    $json->add_property('type' => $npn);

    # Compound name part
    if ($parts->$#* > 0) {

      while (my ($option, $val) = each %attrs) {
        $json->add_property($option => NFC($val));
      }

      for (my $i=0;$i <= $parts->$#*;$i++) {
        $json->start_property('namepart');
        $json->start_object();
        if (my $init = $nip->[$i]) {
          $json->add_property('initial' => $init);
        }
        $json->add_property('value' => NFC($parts->[$i]));
        $json->end_object(); # namepart
        $json->end_property();
      }
    }
    else { # simple name part
      if (my $init = $nip->[0]) {

        $json->start_property('namepart');
        $json->start_object();
        $json->add_property('initial' => $init);

        while (my ($option, $val) = each %attrs) {
          $json->add_property($option => NFC($val));
        }
      }
      else {
        $json->start_property('namepart');
        $json->start_object();
      }

      $json->add_property('value' => NFC($parts->[0]));
      $json->end_object(); # namepart
      $json->end_property(); # namepart
    }

    $json->end_object();
    $json->end_property();
  }
}

=head2 name_to_bbl

    Return bbl data for a name

=cut

sub name_to_bbl {
  my ($self, $un) = @_;
  my $dm = Biber::Config->get_dm;
  my @pno; # per-name options
  my $pno; # per-name options final string
  my $namestring;
  my @namestrings;
  my $nid = $self->{id};

  foreach my $np ($dm->get_constant_value('nameparts')) {# list type so returns list
    my $npc;
    my $npci;
    if ($npc = $self->get_namepart($np)) {

      if ($self->was_stripped($np)) {
        $npc = Biber::Utils::add_outer($npc);
      }
      else {
        # Don't insert name seps in protected names
        $npc = Biber::Utils::join_name($npc);
      }

      $npci = join('\bibinitperiod\bibinitdelim ', @{$self->get_namepart_initial($np)}) . '\bibinitperiod';
      $npci =~ s/\p{Pd}/\\bibinithyphendelim /gxms;
    }
    # Some of the subs above can result in these being undef so make sure there is an empty
    # string instead of undef so that interpolation below doesn't produce warnings
    $npc //= '';
    $npci //= '';

    if ($npc) {
      push @namestrings, "           $np={$npc}",
                         "           ${np}i={$npci}";
      # Only if uniquename is true
      if ($un ne 'false') {
        push @namestrings, "           <BDS>UNP-${np}-${nid}</BDS>";
      }
    }
  }

  # Generate uniquename if uniquename is requested
  if ($un ne 'false') {
    push @pno, "<BDS>UNS-${nid}</BDS>";
    push @pno, "<BDS>UNP-${nid}</BDS>";
  }

  # Add per-name options
  foreach my $no (keys $CONFIG_SCOPEOPT_BIBLATEX{NAME}->%*) {
    if (defined($self->${\"get_$no"})) {
      my $nov = $self->${\"get_$no"};

      if ($CONFIG_BIBLATEX_OPTIONS{NAME}{$no}{OUTPUT}) {
        push @pno, $no . '=' . Biber::Utils::map_boolean($no, $nov, 'tostring');
      }
    }
  }

  # Add the name hash to the options
  push @pno, "<BDS>${nid}-PERNAMEHASH</BDS>";
  $pno = join(',', @pno);

  $namestring = "        {{$pno}{\%\n";
  $namestring .= join(",\n", @namestrings);
  $namestring .= "}}%\n";

  return $namestring;
}

=head2 name_to_bblxml

    Return bblxml data for a name

=cut

sub name_to_bblxml {
  my ($self, $xml, $xml_prefix, $un) = @_;
  my $dm = Biber::Config->get_dm;
  my %pno; # per-name options
  my %names;
  my $nid = $self->{id};

  foreach my $np ($dm->get_constant_value('nameparts')) {# list type so returns list
    my $npc;
    my $npci;

    if ($npc = $self->get_namepart($np)) {
      $npci = join('. ', @{$self->get_namepart_initial($np)});
    }
    # Some of the subs above can result in these being undef so make sure there is an empty
    # string instead of undef so that interpolation below doesn't produce warnings
    $npc //= '';
    $npci //= '';
    if ($npc) {
      $names{$np} = [$npc, $npci];
      if ($un ne 'false') {
        push $names{$np}->@*, "[BDS]UNP-${np}-${nid}[/BDS]";
      }
    }
  }

  # Generate uniquename if uniquename is requested
  if ($un ne 'false') {
    $pno{un} = "[BDS]UNS-${nid}[/BDS]";
    $pno{uniquepart} = "[BDS]UNP-${nid}[/BDS]";
  }

  # Add per-name options
  foreach my $no (keys $CONFIG_SCOPEOPT_BIBLATEX{NAME}->%*) {
    if (defined($self->${\"get_$no"})) {
      my $nov = $self->${\"get_$no"};

      if ($CONFIG_BIBLATEX_OPTIONS{NAME}{$no}{OUTPUT}) {
        $pno{$no} = Biber::Utils::map_boolean($no, $nov, 'tostring');
      }
    }
  }

  # Add the name hash to the options
  $pno{hash} = "[BDS]${nid}-PERNAMEHASH[/BDS]";

  $xml->startTag([$xml_prefix, 'name'], map {$_ => $pno{$_}} sort keys %pno);
  foreach my $key (sort keys %names) {
    my $value = $names{$key};
    my %un;
    if ($un ne 'false') {
      %un = (un => $value->[2]);
    }
    $xml->startTag([$xml_prefix, 'namepart'],
                   type => $key,
                   %un,
                   initials => NFC(Biber::Utils::normalise_string_bblxml($value->[1])));
    $xml->characters(NFC(Biber::Utils::normalise_string_bblxml($value->[0])));
    $xml->endTag();# namepart
  }
  $xml->endTag();# names

  return;
}

=head2 name_to_bibtex

    Return standard bibtex data format for name

=cut

sub name_to_bibtex {
  my $self = shift;
  my $parts;
  my $namestring = '';

  if (my $xdata = $self->get_xdata) {
    return $xdata;
  }

  foreach my $np ('prefix', 'family', 'suffix', 'given') {
    if ($parts->{$np} = $self->get_namepart($np)) {
      $parts->{$np} =~ s/~/ /g;
      if ($self->was_stripped($np)) {
        $parts->{$np} = Biber::Utils::add_outer($parts->{$np});
      }
    }
  }

  if (my $p = $parts->{prefix}) {$namestring .= "$p "};
  if (my $f = $parts->{family}) {$namestring .= $f};
  if (my $s= $parts->{suffix}) {$namestring .= ", $s"};
  if (my $g= $parts->{given}) {$namestring .= ", $g"};

  return $namestring;
}

=head2 name_to_xname

    Return extended bibtex data format for name

=cut

sub name_to_xname {
  my $self = shift;
  my $dm = Biber::Config->get_dm;
  my $parts;
  my @namestring;
  my $xns = Biber::Config->getoption('output_xnamesep');

  foreach my $np (sort $dm->get_constant_value('nameparts')) {# list type so returns list
    if ($parts->{$np} = $self->get_namepart($np)) {
      $parts->{$np} =~ s/~/ /g;
      push @namestring, "$np$xns" . $parts->{$np};
    }
  }

  # Name scope useprefix
  if (defined($self->get_useprefix)) {# could be 0
    push @namestring, "useprefix$xns" . Biber::Utils::map_boolean('useprefix', $self->get_useprefix, 'tostring');
  }

  # Name scope sortingnamekeytemplatename
  if (my $snks = $self->get_sortingnamekeytemplatename) {
    push @namestring, "sortingnamekeytemplatename$xns$snks";
  }

  return join(', ', @namestring);
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

Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our Github tracker at
L<https://github.com/plk/biber/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2012 François Charette and Philip Kime, all rights reserved.
Copyright 2012-2024 Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
