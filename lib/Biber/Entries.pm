package Biber::Entries;

=head2 new

    Initialize a Biber::Entries object

=cut

sub new {
    my ($class) = @_;
    my $self = bless {}, $class;
    return $self;
}

=head2 entry_exists

    Boolean values sub to tell if there is an entry
    for the passed citation key.

=cut

sub entry_exists {
  my $self = shift;
  my $citekey = shift;
  return defined($self->{$citekey}) ? 1 : 0;
}

=head2 entry

    Returns a Biber::Entry object for the passesd
    citation key

=cut

sub entry {
  my $self = shift;
  my $citekey = shift;
  return $self->{$citekey};
}

=head2 entries_keys

    Returns a sorted array of Biber::Entry object citekeys

=cut

sub entries_keys {
  my $self = shift;
  return sort keys %$self;
}

=head2 add_entry

    Adds a Biber::Entry to the Biber::Entries object

=cut

sub add_entry {
  my $self = shift;
  my ($key, $entry) = @_;
  $self->{$key} = $entry;
  return;
}

1;
