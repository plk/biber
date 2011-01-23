package Biber::Section;

use Biber::Entries;
use Biber::Utils;
use List::Util qw( first );

=encoding utf-8

=head1 NAME

Biber::Section

=head2 new

    Initialize a Biber::Section object

=cut

sub new {
  my ($class, %params) = @_;
  my $self = bless {%params}, $class;
  $self->{bibentries} = new Biber::Entries;
  $self->{allkeys} = 0;
  $self->{citekeys} = [];
  $self->{dkeys} = {};
  $self->{orig_order_citekeys} = [];
  $self->{undef_citekeys} = [];
  return $self;
}

=head2 allkeys

    Sets flag to say citekey '*' occurred in citekeys

=cut

sub allkeys {
  my $self = shift;
  $self->{allkeys} = 1;
  return;
}

=head2 is_allkeys

    Checks flag which says citekey '*' occurred in citekeys

=cut

sub is_allkeys {
  my $self = shift;
  return $self->{allkeys};
}


=head2 get_shorthands

    Returns the list of all shorthands for a section

=cut

sub get_shorthands {
  my $self = shift;
  if ( $self->{shorthands} ) {
    return @{ $self->{shorthands} }
  } else {
    return;
  }
}

=head2 set_shorthands

    Sets the list of all shorthands for a section

=cut

sub set_shorthands {
  my $self = shift;
  my $shorthands = shift;
  $self->{shorthands} = $shorthands;
  return;
}


=head2 add_shorthand

    Add a shorthand to a section

=cut

sub add_shorthand {
  my ($self, $bee, $key) = @_;
  # Don't add to los if skiplos is set for entry
  if (Biber::Config->getblxoption('skiplos', $bee, $key)) {
    return;
  }
  my @los;
  if ( $self->get_shorthands ) {
    @los = $self->get_shorthands;
  }
  else {
    @los = ();
  }
  push @los, $key;
  $self->{shorthands} = [ @los ];
  return;
}


=head2 bibentry

    Returns a Biber::Entry object for the given citation key

=cut

sub bibentry {
  my $self = shift;
  my $key = shift;
  $key = lc($key);
  return $self->bibentries->entry($key);
}

=head2 bibentries

    Return Biber::Entries object for this section

=cut

sub bibentries {
  my $self = shift;
  return $self->{bibentries};
}

=head2 del_bibentries

    Delete all Biber::Entry objects from the Biber::Section object

=cut

sub del_bibentries {
  my $self = shift;
  $self->{bibentries} = new Biber::Entries;
  return;
}


=head2 set_citekeys

    Sets the citekeys in a Biber::Section object

=cut

sub set_citekeys {
  my $self = shift;
  my $keys = shift;
  $self->{citekeys} = $keys;
  return;
}

=head2 set_orig_order_citekeys

    Sets the original order of citekeys in a Biber::Section object

=cut

sub set_orig_order_citekeys {
  my $self = shift;
  my $keys = shift;
  $self->{orig_order_citekeys} = $keys;
  return;
}


=head2 get_citekeys

    Gets the citekeys of a Biber::Section object
    Returns a normal array

=cut

sub get_citekeys {
  my $self = shift;
  return @{$self->{citekeys}};
}

=head2 get_static_citekeys

    Gets the citekeys of a Biber::Section object
    excluding dynamic set entry keys
    Returns a normal array

=cut

sub get_static_citekeys {
  my $self = shift;
  return reduce_array($self->{citekeys}, $self->dynamic_set_keys);
}


=head2 get_undef_citekeys

    Gets the list of undefined citekeys of a Biber::Section object
    Returns a normal array

=cut

sub get_undef_citekeys {
  my $self = shift;
  return @{$self->{undef_citekeys}};
}

=head2 get_orig_order_citekeys

    Gets the citekeys of a Biber::Section object in their original order
    This is just to ensure we have a method that will return this, just in
    case we mess about with the order at some point. This is needed by
    citeorder sorting.

=cut

sub get_orig_order_citekeys {
  my $self = shift;
  return @{$self->{orig_order_citekeys}};
}

=head2 has_citekey

    Returns true when $key is in the Biber::Section object

=cut

sub has_citekey {
  my $self = shift;
  my $key = shift;
  return defined ( first { lc($_) eq lc($key) } $self->get_citekeys ) ? 1 : 0;
}



=head2 del_citekey

    Deletes a citekey from a Biber::Section object

=cut

sub del_citekey {
  my $self = shift;
  my $key = shift;
  return unless $self->has_citekey($key);
  $self->{citekeys}            = [ grep {$_ ne $key} @{$self->{citekeys}} ];
  $self->{orig_order_citekeys} = [ grep {$_ ne $key} @{$self->{orig_order_citekeys}} ];
  return;
}

=head2 del_citekeys

    Deletes al citekeys from a Biber::Section object

=cut

sub del_citekeys {
  my $self = shift;
  $self->{citekeys}            = [ ];
  $self->{orig_order_citekeys} = [ ];
  return;
}


=head2 set_dynamic_set

    Record a mapping of dynamic key to member keys

=cut

sub set_dynamic_set {
  my $self = shift;
  my $dkey = shift;
  my @members = @_;
  $self->{dkeys}{$dkey} = \@members;
  return;
}

=head2 get_dynamic_set

    Retrieve member keys for a dynamic set key
    Check on has reference returning anything stop spurious warnings
    about empty dereference in return.

=cut

sub get_dynamic_set {
  my $self = shift;
  my $dkey = shift;
  if (my $set_members = $self->{dkeys}{$dkey}) {
    return @$set_members;
  }
  else {
    return ();
  }
}

=head2 dynamic_set_keys

    Retrieve all dynamic set keys

=cut

sub dynamic_set_keys {
  my $self = shift;
  return [keys %{$self->{dkeys}}];
}


=head2 add_citekeys

    Adds citekeys to the Biber::Section object

=cut

sub add_citekeys {
  my $self = shift;
  my @keys = @_;
  foreach my $key (@keys) {
    next if $self->has_citekey($key);
    push @{$self->{citekeys}}, $key;
    push @{$self->{orig_order_citekeys}}, $key;
  }
  return;
}

=head2 add_undef_citekey

    Adds a citekey to the Biber::Section object as an undefined
    key. This allows us to output this information to the .bbl and
    so biblatex can do better reporting to external utils like latexmk

=cut

sub add_undef_citekey {
  my $self = shift;
  my $key = shift;
  push @{$self->{undef_citekeys}}, $key;
  return;
}


=head2 add_datasource

    Adds a data source to a section

=cut

sub add_datasource {
  my $self = shift;
  my $source = shift;
  push @{$self->{datasources}}, $source;
  return;
}

=head2 set_datasources

    Sets the data sources for a section

=cut

sub set_datasources {
  my $self = shift;
  my $sources = shift;
  $self->{datasources} = $sources;
  return;
}


=head2 get_datasources

    Gets an array of data sources for this section

=cut

sub get_datasources {
  my $self = shift;
  if (exists($self->{datasources})) {
    return $self->{datasources};
  }
  else {
    return undef;
  }
}

=head2 add_list

    Adds a section list to this section

=cut

sub add_list {
  my $self = shift;
  my $list = shift;
  push @{$self->{lists}}, $list;
  return;
}

=head2 get_lists

    Returns an array ref of all section lists

=cut

sub get_lists {
  my $self = shift;
  return $self->{lists};
}

=head2 get_list

    Returns a specific list by label

=cut

sub get_list {
  my $self = shift;
  my $label;
  foreach my $list (@{$self->{lists}}) {
    return $list if $list->get_label eq lc($label);
  }
  return undef;
}



=head2 number

    Gets the section number of a Biber::Section object

=cut

sub number {
  my $self = shift;
  return $self->{number};
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
