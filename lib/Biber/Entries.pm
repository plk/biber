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
  my $citekey = lc(shift);
  return defined($self->{$citekey}) ? 1 : 0;
}

=head2 entry

    Returns a Biber::Entry object for a given
    citekey

=cut

sub entry {
  my $self = shift;
  my $citekey = lc(shift);
  # If entry is already cached, return it
  if ($self->{$citekey}) {
    return $self->{$citekey};
  }
  # Otherwise, we need to fetch data from the datasource and generate it
  # if (my $bibentry = _bibtex_fetch_entry()) {
  #   $self->add_entry($cache_key, $bibentry);
  # }
  # return $bibentry || undef;
}

# sub check_missing {
#   my $self = shift;
#   my $secnum = $self->get_current_section;
#   my $section = $self->sections->get_section($secnum);
#   $logger->debug("Checking for missing citekeys in section $secnum");
#   foreach my $citekey ($section->get_citekeys) {
#     # Either the key refers to a real bib entry or a dynamic set entry
#     unless ( $section->bibentries->entry_exists($citekey) or
#              $section->get_dynamic_set($citekey)) {
#       $logger->warn("I didn't find a database entry for '$citekey' (section $secnum)");
#       $self->{warnings}++;
#       $section->del_citekey($citekey);
#       $section->add_undef_citekey($citekey);
#       next;
#     }
#   }
# }



=head2 sorted_keys

    Returns a sorted array of Biber::Entry object keys

=cut

sub sorted_keys {
  my $self = shift;
  use locale;
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

Copyright 2009-2011 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

1;

# vim: set tabstop=2 shiftwidth=2 expandtab:
