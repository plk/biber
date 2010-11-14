package Biber::Section;

use Biber::Entries;
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
  $self->{orig_order_citekeys} = [];
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

=head2 add_datafile

    Adds a data file to a section

=cut

sub add_datafile {
  my $self = shift;
  my $file = shift;
  push @{$self->{datafiles}}, $file;
  return;
}

=head2 set_datafiles

    Sets the datafiles for a section, passed as arrayref

=cut

sub set_datafiles {
  my $self = shift;
  my $files = shift;
  $self->{datafiles} = $files;
  return;
}


=head2 get_datafiles

    Gets an array of data files for this section

=cut

sub get_datafiles {
  my $self = shift;
  if (exists($self->{datafiles})) {
    return @{$self->{datafiles}};
  }
  else {
    return ();
  }
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

Copyright 2009-2010 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

1;

# vim: set tabstop=2 shiftwidth=2 expandtab:
