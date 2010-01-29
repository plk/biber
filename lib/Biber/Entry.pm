package Biber::Entry;




=head2 new

    Initialize a Biber::Entry object

=cut

sub new {
  my $class = shift;
  my ($obj) = @_;
  my $self;
  if (defined($obj) and ref($obj) eq 'HASH') {
    $self = bless $obj, $class;
  }
  else {
    $self = bless {}, $class;
  }
  return $self;
}


=head2 set_field

    Set a field for a Biber::Entry object

=cut

sub set_field {
  my $self = shift;
  my ($key, $val) = @_;
  $self->{$key} = $val;
  return;
}


=head2 get_field

    Get a field for a Biber::Entry object

=cut

sub get_field {
  my $self = shift;
  my $key = shift;
  return defined($self->{$key}) ? $self->{$key} : '';
}

=head2 del_field

    Delete a field in a Biber::Entry object

=cut

sub del_field {
  my $self = shift;
  my $key = shift;
  delete $self->{$key};
  return;
}

=head2 fields

    Returns a sorted array of the Biber::Entry object fields

=cut

sub fields {
  my $self = shift;
  return sort keys %$self;
}


=head2 add_warning

    Append a warning to a Biber::Entry object

=cut

sub add_warning {
  my $self = shift;
  my $warning = shift;
  push @{$self->{'warnings'}}, $warning;
  return;
}

1;
