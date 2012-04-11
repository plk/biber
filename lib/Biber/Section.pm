package Biber::Section;
use 5.014000;
use strict;
use warnings;

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
  $self->{citekeys_h} = {}; # For faster hash-based lookup of individual keys
  $self->{labelcache_l} = {};
  $self->{everykey} = {};
  $self->{everykey_lc} = {};
  $self->{bcfkeycache} = {};
  $self->{labelcache_v} = {};
  $self->{sortcache} = [];
  $self->{dkeys} = {};
  $self->{orig_order_citekeys} = [];
  $self->{undef_citekeys} = [];
  $self->{citekey_alias} = {};
  return $self;
}

=head2 reset_caches

    Reset section caches which need it

=cut

sub reset_caches {
  my $self = shift;
  $self->{sortcache} = [];
  $self->{labelcache_l} = {};
  $self->{labelcache_v} = {};
  $self->{bcfkeycache} = {};
  return;
}

=head2 has_badcasekey

    Returns a value to say if we've seen a key differing only in case before
    <previouskey>  - we've seen a differently cased variant of this key so we can warn about this
    undef  - Not seen this key at all in any case variant before

=cut

sub has_badcasekey {
  my ($self, $key) = @_;
  my $ckey = $self->{everykey_lc}{lc($key)};
  return undef unless $ckey;
  return $ckey ne $key ? $ckey : undef;
}


=head2 add_everykey

    Adds a datasource key to the section list of all datasource keys

=cut

sub add_everykey {
  my ($self, $key) = @_;
  $self->{everykey}{$key} = 1;
  $self->{everykey_lc}{lc($key)} = $key;
  return;
}

=head2 del_everykeys

  Delete everykey cache. For use in tests.

=cut

sub del_everykeys {
  my $self = shift;
  $self->{everykey} = undef
  $self->{everykey_lc} = undef;
  return;
}

=head2 has_everykey

    Returns a boolean to say if we've seen a key in any datasource for this section.
    This used to be an array ref which was checked using first() and it
    was twenty times slower.

=cut

sub has_everykey {
  my ($self, $key) = @_;
  return $self->{everykey}{$key} ? 1 : 0;
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


=head2 bibentry

    Returns a Biber::Entry object for the given citation key

=cut

sub bibentry {
  my ($self, $key) = @_;
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
  map { $self->{citekeys_h}{$_} = 1} @$keys;
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
  return $self->{citekeys_h}{$key} ? 1 : 0;
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
  delete $self->{citekeys_h}{$key};
  return;
}

=head2 del_citekeys

    Deletes all citekeys from a Biber::Section object

=cut

sub del_citekeys {
  my $self = shift;
  $self->{citekeys}            = [];
  $self->{citekeys_h}          = {};
  $self->{orig_order_citekeys} = [];
  return;
}

=head2 add_citekeys

    Adds citekeys to the Biber::Section object

=cut

sub add_citekeys {
  my $self = shift;
  my @keys = @_;
  foreach my $key (@keys) {
    next if $self->has_citekey($key);
    $self->{citekeys_h}{$key} = 1;
    push @{$self->{citekeys}}, $key;
    push @{$self->{orig_order_citekeys}}, $key;
  }
  return;
}


=head2 set_citekey_alias

    Set citekey alias information

=cut

sub set_citekey_alias {
  my $self = shift;
  my ($alias, $key) = @_;
  $self->{citekey_alias}{$alias} = $key;
  return;
}

=head2 get_citekey_alias

    Get citekey alias information

=cut

sub get_citekey_alias {
  my $self = shift;
  my $alias = shift;
  return $self->{citekey_alias}{$alias};
}

=head2 del_citekey_alias

    Delete citekey alias

=cut

sub del_citekey_alias {
  my $self = shift;
  my $alias = shift;
  delete($self->{citekey_alias}{$alias});
  return;
}


=head2 get_citekey_aliases

    Get a list of all citekey aliases for the section

=cut

sub get_citekey_aliases {
  my $self = shift;
  return ( keys %{$self->{citekey_alias}} );
}


=head2 set_labelcache_v

    Sets the variable label disambiguation cache for a field

=cut

sub set_labelcache_v {
  my ($self, $field, $cache) = @_;
  $self->{labelcache_v}{$field} = $cache;
  return;
}

=head2 get_labelcache_v

    Gets the variable label disambiguation cache for a field

=cut

sub get_labelcache_v {
  my ($self, $field) = @_;
  return $self->{labelcache_v}{$field};
}

=head2 set_labelcache_l

    Sets the list label disambiguation cache for a field

=cut

sub set_labelcache_l {
  my ($self, $field, $cache) = @_;
  $self->{labelcache_l}{$field} = $cache;
  return;
}

=head2 get_labelcache_l

    Gets the list label disambiguation cache for a field

=cut

sub get_labelcache_l {
  my ($self, $field) = @_;
  return $self->{labelcache_l}{$field};
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


=head2 add_sort_cache

    Adds a scheme/keys pair to the sort cache:
    [$scheme, $keys, $sortinitdata, $extraalphadata, $extrayeardata ]

=cut

sub add_sort_cache {
  my $self = shift;
  my $cacheitem = shift;
  push @{$self->{sortcache}}, $cacheitem;
  return;
}


=head2 get_sort_cache

    Retrieves the sort cache

=cut

sub get_sort_cache {
  my $self = shift;
  return $self->{sortcache};
}



=head2 number

    Gets the section number of a Biber::Section object

=cut

sub number {
  my $self = shift;
  return $self->{number};
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
