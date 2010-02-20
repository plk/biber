package Biber::Entries;

=encoding utf-8

=head1 NAME

Biber::Entries

=head2 new

    Initialize a Biber::Entries object

=cut

sub new {
  my ($class) = @_;
  my $self = bless {}, $class;
  return $self;
}

=head2 notnull

    Test for an empty object

=cut

sub notnull {
  my $self = shift;
  my @arr = keys %$self;
  return $#arr > -1 ? 1 : 0;
}

=head2 entry_exists

    Boolean values sub to tell if there is an entry
    for the passed citation key.

=cut

sub entry_exists {
  my $self = shift;
  my $citekey = shift;
  $citekey = lc($citekey);
  return defined($self->{$citekey}) ? 1 : 0;
}

=head2 entry

    Returns a Biber::Entry object for the passed
    citation key

=cut

sub entry {
  my $self = shift;
  my $citekey = shift;
  $citekey = lc($citekey);
  return $self->{$citekey};
}

=head2 sorted_keys

    Returns a sorted array of Biber::Entry object citekeys

=cut

sub sorted_keys {
  my $self = shift;
  return sort keys %$self;
}

=head2 add_entry

    Adds a Biber::Entry to the Biber::Entries object

=cut

sub add_entry {
  my $self = shift;
  my ($key, $entry) = @_;
  $key = lc($key);
  $self->{$key} = $entry;
  return;
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
