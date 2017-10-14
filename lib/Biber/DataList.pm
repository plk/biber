package Biber::DataList;
use v5.24;
use strict;
use warnings;

use Biber::Utils;
use Biber::Constants;
use Digest::MD5 qw( md5_hex );
use List::Util qw( first );

=encoding utf-8

=head1 NAME

Biber::DataList

=head2 new

    Initialize a Biber::DataList object

=cut

sub new {
  my ($class, %params) = @_;
  my $self = bless {%params}, $class;
  return $self;
}


=head2 set_section

    Sets the section of a data list

=cut

sub set_section {
  my $self = shift;
  my $section = shift;
  $self->{section} = lc($section);
  return;
}

=head2 get_section

    Gets the section of a data list

=cut

sub get_section {
  my $self = shift;
  return $self->{section};
}


=head2 set_sortschemename

    Sets the sortscheme name of a data list

=cut

sub set_sortschemename {
  my $self = shift;
  my $ssn = shift;
  $self->{sortschemename} = lc($ssn);
  return;
}

=head2 get_refcontext

    Gets the refcontext information for a data list

=cut

sub get_refcontext {
  my $self = shift;
  return join('/', ($self->{sortschemename},
                    $self->{sortnamekeyschemename},
                    $self->{labelprefix},
                    $self->{uniquenametemplatename},
                    $self->{labelalphanametemplatename}));
}

=head2 get_sortschemename

    Gets the sortschemename of a data list

=cut

sub get_sortschemename {
  my $self = shift;
  return $self->{sortschemename};
}

=head2 set_sortnamekeyschemename

    Sets the sortnamekeyscheme name of a data list

=cut

sub set_sortnamekeyschemename {
  my $self = shift;
  my $snksn = shift;
  $self->{sortnamekeyschemename} = lc($snksn);
  return;
}

=head2 get_sortnamekeyschemename

    Gets the sortnamekeyschemename of a data list

=cut

sub get_sortnamekeyschemename {
  my $self = shift;
  return $self->{sortnamekeyschemename};
}

=head2 set_uniquenametemplatename

    Sets the uniquenametemplate name of a data list

=cut

sub set_uniquenametemplatename {
  my $self = shift;
  my $untn = shift;
  $self->{uniquenametemplatename} = lc($untn);
  return;
}

=head2 get_uniquenametemplatename

    Gets the uniquenametemplate name of a data list

=cut

sub get_uniquenametemplatename {
  my $self = shift;
  return $self->{uniquenametemplatename};
}

=head2 set_labelalphanametemplatename

    Sets the labelalphanametemplate name of a data list

=cut

sub set_labelalphanametemplatename {
  my $self = shift;
  my $latn = shift;
  $self->{labelalphanametemplatename} = lc($latn);
  return;
}

=head2 get_labelalphanametemplatename

    Gets the labelalphanametemplate name of a data list

=cut

sub get_labelalphanametemplatename {
  my $self = shift;
  return $self->{labelalphanametemplatename};
}

=head2 set_sortinit_collator

    Sets the sortinit collator for this list

=cut

sub set_sortinit_collator {
  my $self = shift;
  $self->{sortinitcollator} = shift;;
  return;
}

=head2 get_sortinit_collator

    Gets the sortinit collator for this list

=cut

sub get_sortinit_collator {
  my $self = shift;
  return $self->{sortinitcollator};
}

=head2 get_labelprefix

    Gets the labelprefix setting of a data list

=cut

sub get_labelprefix {
  my $self = shift;
  return $self->{labelprefix};
}

=head2 set_labelprefix

    Sets the labelprefix setting of a data list

=cut

sub set_labelprefix {
  my $self = shift;
  my $pn = shift;
  $self->{labelprefix} = $pn;
  return
}

=head2 set_name

    Sets the name of a data list

=cut

sub set_name {
  my $self = shift;
  my $name = shift;
  $self->{name} = $name;
  return;
}

=head2 get_name

    Gets the name of a data list

=cut

sub get_name {
  my $self = shift;
  return $self->{name};
}


=head2 set_type

    Sets the type of a data list

=cut

sub set_type {
  my $self = shift;
  my $type = shift;
  $self->{type} = lc($type);
  return;
}

=head2 get_type

    Gets the type of a section list

=cut

sub get_type {
  my $self = shift;
  return $self->{type};
}

=head2 set_keys

    Sets the keys for the list

=cut

sub set_keys {
  my ($self, $keys) = @_;
  $self->{keys} = $keys;
  return;
}

=head2 get_keys

    Gets the keys for the list

=cut

sub get_keys {
  my $self = shift;
  return $self->{keys}->@*;
}

=head2 count_keys

    Count the keys for the list

=cut

sub count_keys {
  my $self = shift;
  return $#{$self->{keys}} + 1;
}


=head2 get_listdata

    Gets all of the list metadata

=cut

sub get_listdata {
  my $self = shift;
  return [ $self->{sortscheme},
           $self->{sortnamekeyschemename},
           $self->{labelprefix},
           $self->{keys},
           $self->{sortinitdata},
           $self->{extrayeardata},
           $self->{extraalphadata},
           $self->{extratitledata},
           $self->{extratitleyeardata},
           $self->{labelalphadata},
           $self->{namelistdata},
           $self->{sortdataschema},
           $self->{namelistdata},
           $self->{labelalphadata}];
}

=head2 get_namelistdata

  Gets  name list data

=cut

sub get_namelistdata {
  return shift->{namelistdata};
}

=head2 reset_namelistdata

  Reset name list data

=cut

sub reset_namelistdata {
  my $self = shift;
  $self->{namelistdata} = {};
  return;
}

=head2 set_namelistdata

  Saves name list data

=cut

sub set_namelistdata {
  my ($self, $nld) = @_;
  $self->{namelistdata} = $nld;
  return;
}

=head2 get_namelistdata_for_key

  Gets  name list data for a key

=cut

sub get_namelistdata_for_key {
  my ($self, $key) = @_;
  return $self->{namelistdata}{$key};
}

=head2 set_namelistdata_for_key

  Saves name list data for a key

=cut

sub set_namelistdata_for_key {
  my ($self, $key, $nld) = @_;
  return unless defined($key);
  $self->{namelistdata}{$key} = $nld;
  return;
}

=head2 get_labelalphadata

  Gets  labelalpha field data

=cut

sub get_labelalphadata {
  return shift->{labelalphadata};
}

=head2 set_labelalphadata

  Saves labelalpha data

=cut

sub set_labelalphadata {
  my ($self, $lad) = @_;
  $self->{labelalphadata} = $lad;
  return;
}

=head2 get_labelalphadata_for_key

  Gets  labelalpha field data for a key

=cut

sub get_labelalphadata_for_key {
  my ($self, $key) = @_;
  return $self->{labelalphadata}{$key};
}

=head2 set_labelalphadata_for_key

  Saves labelalpha field data for a key

=cut

sub set_labelalphadata_for_key {
  my ($self, $key, $la) = @_;
  return unless defined($key);
  $self->{labelalphadata}{$key} = $la;
  return;
}

=head2 set_extrayeardata_for_key

  Saves extrayear field data for a key

=cut

sub set_extrayeardata_for_key {
  my ($self, $key, $ed) = @_;
  return unless defined($key);
  $self->{extrayeardata}{$key} = $ed;
  return;
}

=head2 set_extrayeardata

    Saves extrayear field data for all keys

=cut

sub set_extrayeardata {
  my ($self, $ed) = @_;
  $self->{extrayeardata} = $ed;
  return;
}


=head2 get_extrayeardata

    Gets the extrayear field data for a key

=cut

sub get_extrayeardata_for_key {
  my ($self, $key) = @_;
  return unless defined($key);
  return $self->{extrayeardata}{$key};
}

=head2 set_extratitledata_for_key

  Saves extratitle field data for a key

=cut

sub set_extratitledata_for_key {
  my ($self, $key, $ed) = @_;
  return unless defined($key);
  $self->{extratitledata}{$key} = $ed;
  return;
}

=head2 set_extratitledata

    Saves extratitle field data for all keys

=cut

sub set_extratitledata {
  my ($self, $ed) = @_;
  $self->{extratitledata} = $ed;
  return;
}


=head2 get_extratitledata

    Gets the extratitle field data for a key

=cut

sub get_extratitledata_for_key {
  my ($self, $key) = @_;
  return unless defined($key);
  return $self->{extratitledata}{$key};
}


=head2 set_extratitleyeardata_for_key

  Saves extratitleyear field data for a key

=cut

sub set_extratitleyeardata_for_key {
  my ($self, $key, $ed) = @_;
  return unless defined($key);
  $self->{extratitleyeardata}{$key} = $ed;
  return;
}

=head2 set_extratitleyeardata

    Saves extratitleyear field data for all keys

=cut

sub set_extratitleyeardata {
  my ($self, $ed) = @_;
  $self->{extratitleyeardata} = $ed;
  return;
}


=head2 get_extratitleyeardata

    Gets the extratitleyear field data for a key

=cut

sub get_extratitleyeardata_for_key {
  my ($self, $key) = @_;
  return unless defined($key);
  return $self->{extratitleyeardata}{$key};
}


=head2 set_extraalphadata_for_key

    Saves extraalpha field data for a key

=cut

sub set_extraalphadata_for_key {
  my ($self, $key, $ed) = @_;
  return unless defined($key);
  $self->{extraalphadata}{$key} = $ed;
  return;
}

=head2 set_extraalphadata

    Saves extraalpha field data for all keys

=cut

sub set_extraalphadata {
  my ($self, $ed) = @_;
  $self->{extraalphadata} = $ed;
  return;
}

=head2 get_extraalphadata

    Gets the extraalpha field data for a key

=cut

sub get_extraalphadata_for_key {
  my ($self, $key) = @_;
  return unless defined($key);
  return $self->{extraalphadata}{$key};
}

=head2 get_sortdataschema

    Gets the sortdata schema for a sortlist

=cut

sub get_sortdataschema {
  my ($self) = @_;
  return $self->{sortdataschema};
}

=head2 set_sortdataschema

    Saves the sortdata schema for a sortlist

=cut

sub set_sortdataschema {
  my ($self, $ss) = @_;
  $self->{sortdataschema} = $ss;
  return;
}

=head2 set_sortdata

    Saves sorting data in a list for a key

=cut

sub set_sortdata {
  my ($self, $key, $sd) = @_;
  return unless defined($key);
  $self->{sortdata}{$key} = $sd;
  return;
}

=head2 get_sortdata_for_key

    Gets the sorting data in a list for a key

=cut

sub get_sortdata_for_key {
  my ($self, $key) = @_;
  return unless defined($key);
  return $self->{sortdata}{$key};
}


=head2 set_sortinitdata_for_key

 Saves sortinit data for a specific key

=cut

sub set_sortinitdata_for_key {
  my ($self, $key, $init) = @_;
  return unless defined($key);
  $self->{sortinitdata}{$key} = {init => $init};
  return;
}

=head2 set_sortinitdata

 Saves sortinit data for all keys

=cut

sub set_sortinitdata {
  my ($self, $sid) = @_;
  $self->{sortinitdata} = $sid;
  return;
}

=head2 get_sortinit_for_key

    Gets the sortinit in a list for a key

=cut

sub get_sortinit_for_key {
  my ($self, $key) = @_;
  return unless defined($key);
  return $self->{sortinitdata}{$key}{init};
}

=head2 set_sortscheme

    Sets the sortscheme of a list

=cut

sub set_sortscheme {
  my $self = shift;
  my $sortscheme = shift;
  $self->{sortscheme} = $sortscheme;
  return;
}

=head2 get_sortscheme

    Gets the sortscheme of a list

=cut

sub get_sortscheme {
  my $self = shift;
  return $self->{sortscheme};
}


=head2 add_filter

    Adds a filter to a list object

=cut

sub add_filter {
  my $self = shift;
  my ($filter) = @_;
  push $self->{filters}->@*, $filter;
  return;
}

=head2 get_filters

    Gets all filters for a list object

=cut

sub get_filters {
  my $self = shift;
  return $self->{filters};
}

=head2 instantiate_entry

  Do any dynamic information replacement for information
  which varies in an entry between lists. This is information which
  needs to be output to the .bbl for an entry but which is a property
  of the reference context and not the entry per se so it cannot be stored
  statically in the entry and must be pulled from the specific list
  when outputting the entry.

  Currently this means:

  * sortinit
  * sortinithash
  * labelalpha
  * extrayear
  * extraalpha
  * extratitle
  * extratitleyear
  * labelprefix
  * uniquelist
  * uniquename

=cut

sub instantiate_entry {
  my $self = shift;
  my ($section, $entry, $key, $format) = @_;

  return '' unless $entry;
  my $be = $section->bibentry($key);
  my $dmh = Biber::Config->get_dm_helpers;

  $format //= 'bbl'; # default

  my $entry_string = $$entry;

  # sortinit
  my $sinit = $self->get_sortinit_for_key($key);
  if (defined($sinit)) {
    my $str;
    if ($format eq 'bbl') {
      $str = "\\field{sortinit}{$sinit}";
    }
    elsif ($format eq 'bblxml') {
      $str = "<bbl:field name=\"sortinit\">$sinit</bbl:field>";
    }
    $entry_string =~ s|<BDS>SORTINIT</BDS>|$str|gxms;
  }
  else {# might not be defined if sortscheme returns nothing at all
    $entry_string =~ s|^\s*<BDS>SORTINIT</BDS>\n||gxms;
  }

  # sortinithash
  if (defined($sinit)) {
    my $str;

    # All Unicode::Collate operations are expensive so use a cache when possible
    my $sinithash = md5_hex($self->{sortinitcollator}->viewSortKey($sinit));

    if ($format eq 'bbl') {
      $str = "\\field{sortinithash}{$sinithash}";
    }
    elsif ($format eq 'bblxml') {
      $str = "<bbl:field name=\"sortinithash\">$sinithash</bbl:field>";
    }
    $entry_string =~ s|<BDS>SORTINITHASH</BDS>|$str|gxms;
  }
  else {# might not be defined if sortscheme returns nothing at all
    $entry_string =~ s|^\s*<BDS>SORTINITHASH</BDS>\n||gxms;
  }

  # extrayear
  if (my $e = $self->get_extrayeardata_for_key($key)) {
    my $str;
    if ($format eq 'bbl') {
      $str = "\\field{extrayear}{$e}";
    }
    elsif ($format eq 'bblxml') {
      $str = "<bbl:field name=\"extrayear\">$e</bbl:field>";
    }
    $entry_string =~ s|<BDS>EXTRAYEAR</BDS>|$str|gxms;
  }

  # extratitle
  if (my $e = $self->get_extratitledata_for_key($key)) {
    my $str;
    if ($format eq 'bbl') {
      $str = "\\field{extratitle}{$e}";
    }
    elsif ($format eq 'bblxml') {
      $str = "<bbl:field name=\"extratitle\">$e</bbl:field>";
    }
    $entry_string =~ s|<BDS>EXTRATITLE</BDS>|$str|gxms;
  }

  # extratitle
  if (my $e = $self->get_extratitleyeardata_for_key($key)) {
    my $str;
    if ($format eq 'bbl') {
      $str = "\\field{extratitleyear}{$e}";
    }
    elsif ($format eq 'bblxml') {
      $str = "<bbl:field name=\"extratitleyear\">$e</bbl:field>";
    }
    $entry_string =~ s|<BDS>EXTRATITLEYEAR</BDS>|$str|gxms;
  }

  # uniquename
  # replace pattern is different because this can occur in bblxml attributes
  # and so can't be angles
  if (my $nld = $self->get_namelistdata_for_key($key)) {
    foreach my $namefield ($dmh->{namelists}->@*) {
      if (my $nl = $be->get_field($namefield)) {
        my $nlid = $nl->get_id;
        foreach my $n ($nl->names->@*) {
          my $str = '';
          my $nid = $n->get_id;
          $str = $nld->{$nlid}{un}{$nid}{summary};
          $entry_string =~ s|[<[]BDS[>\]]UNS-$nid[<[]/BDS[>\]]|$str|gxms;
          $str = $nld->{$nlid}{un}{$nid}{part};
          $entry_string =~ s|[<[]BDS[>\]]UNP-$nid[<[]/BDS[>\]]|$str|gxms;
          foreach my $np ($n->get_nameparts) {
            $str = $nld->{$nlid}{un}{$nid}{parts}{$np};
            $entry_string =~ s|[<[]BDS[>\]]UNP-$np-$nid[<[]/BDS[>\]]|$str|gxms;
          }
        }
      }
    }
  }

  # uniquelist
  # replace pattern is different because this can occur in bblxml attributes
  # and so can't be angles
  if (my $nld = $self->get_namelistdata_for_key($key)) {
    foreach my $namefield ($dmh->{namelists}->@*) {
      if (my $nl = $be->get_field($namefield)) {
        my $str = '';
        my $nlid = $nl->get_id;
        $str = $nld->{$nlid}{ul};
        $entry_string =~ s|[<[]BDS[>\]]UL-$nlid[<[]/BDS[>\]]|$str|gxms;
      }
    }
  }

  # labelalpha
  if (my $e = $self->get_labelalphadata_for_key($key)) {
    my $str;
    if ($format eq 'bbl') {
      $str = "\\field{labelalpha}{$e}";
    }
    elsif ($format eq 'bblxml') {
      $str = "<bbl:field name=\"labelalpha\">$e</bbl:field>";
    }
    $entry_string =~ s|<BDS>LABELALPHA</BDS>|$str|gxms;
  }

  # extraalpha
  if (my $e = $self->get_extraalphadata_for_key($key)) {
    my $str;
    if ($format eq 'bbl') {
      $str = "\\field{extraalpha}{$e}";
    }
    elsif ($format eq 'bblxml') {
      $str = "<bbl:field name=\"extraalpha\">$e</bbl:field>";
    }
    $entry_string =~ s|<BDS>EXTRAALPHA</BDS>|$str|gxms;
  }

  # labelprefix
  if (my $pn = $self->get_labelprefix($key)) {
    my $str;
    if ($format eq 'bbl') {
      $str = "\\field{labelprefix}{$pn}";
    }
    elsif ($format eq 'bblxml') {
      $str = "<bbl:field name=\"labelprefix\">$pn</bbl:field>";
    }
    $entry_string =~ s|<BDS>LABELPREFIX</BDS>|$str|gxms;
  }
  else {
    $entry_string =~ s|^\s*<BDS>LABELPREFIX</BDS>\n||gxms;
  }

  return $entry_string;
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

Copyright 2009-2017 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
