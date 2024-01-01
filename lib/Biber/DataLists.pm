package Biber::DataLists;
use v5.24;
use strict;
use warnings;

=encoding utf-8

=head1 NAME

Biber::DataLists - Biber::DataLists objects

=head2 new

    Initialize a Biber::DataLists object

=cut

sub new {
  my ($class) = @_;
  my $self = bless {}, $class;
  return $self;
}

=head2 add_list

    Adds a section list to this section

=cut

sub add_list {
  my $self = shift;
  my $list = shift;
  push $self->{lists}->@*, $list;
  return;
}

=head2 get_lists

    Returns an array ref of all sort lists

=cut

sub get_lists {
  my $self = shift;
  return $self->{lists};
}

=head2 get_lists_for_section

    Returns an array ref of all sort lists for a given section
    Using numeric equals as section identifiers are numbers

=cut

sub get_lists_for_section {
  my $self = shift;
  my $section = shift;
  my $lists = [];
  my $glist;
  foreach my $list ($self->{lists}->@*) {
    if ($list->get_section == $section) {
      push $lists->@*, $list;
    }
  }
  return $lists;
}

=head2 get_lists_by_attrs

    Returns an array ref of data lists with certain
    attributes

=cut

sub get_lists_by_attrs {
  my ($self, %attrs) = @_;
  my $lists;
  LIST: foreach my $list ($self->{lists}->@*) {
      foreach my $attr (keys %attrs) {
        my $method = "get_$attr";
        unless ($attrs{$attr} eq $list->$method) {
          next LIST;
        }
      }
      push $lists->@*, $list;
    }
  return $lists;
}

=head2 get_list

    Returns a specific list by list metadata

=cut

sub get_list {
  my ($self, $name, $section, $type) = @_;
  foreach my $list ($self->{lists}->@*) {
    next if (defined($section) and ($list->get_section ne $section));
    next if ($type and ($list->get_type ne $type));
    return $list if $list->get_name eq $name;
  }
  return undef;
}

=head2 has_lists_of_type_for_section

    Returns boolean saying whether there is a sort list for a section of a
    specified type

=cut

sub has_lists_of_type_for_section {
  my ($self, $section, $type) = @_;
  foreach my $list ($self->{lists}->@*) {
    if ($list->get_type eq $type and
        $list->get_section == $section) {
      return 1;
    }
  }
  return 0;
}


1;

__END__

=head1 AUTHORS

Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our Github tracker at
L<https://github.com/plk/biber/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2012-2024 Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
