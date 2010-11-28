package Biber::Structure;
use List::Util qw( first );
use Biber::Utils;
use Biber::Constants;
use Data::Dump qw( pp );

=encoding utf-8

=head1 NAME

Biber::Structure

=cut

our $STRUCTURE;
$STRUCTURE = {};

=head2 define_alias

    Define an alias from the format presented in the .bcf

=cut

sub define_alias {
  shift; # class method
  my $type = shift;
  my $name = shift;
  my $rname = shift;
  my $field = shift;
  $STRUCTURE->{aliases}{$type}{$name} = { realname => $rname };
  if ($field) {
    $STRUCTURE->{aliases}{$type}{$name}{fields} = { map {$_->{name} => $_->{content}} @{$alias->{field}}}
  }
  $STRUCTURE->{reversealiases}{$rname} = $name;
  return;
}

=head2 get_alias

    Retrieve an alias for a type

=cut

sub get_alias {
  shift; # class method
  my $type = shift;
  my $name = shift;
  return $STRUCTURE->{aliases}{$type}{$name}{realname} // '';
}

=head2 get_alias_fields

    Retrieve any special fields changes for an alias

=cut

sub get_alias_fields {
  shift; # class method
  my $type = shift;
  my $name = shift;
  my $fs = $STRUCTURE->{aliases}{$type}{$name}{fields};
  return $fs ? keys(%$fs) : '';
}

=head2 get_alias_field_value

    Retrieve a new value for a field which requires special processing
    with an alias

=cut

sub get_alias_field_value {
  shift; # class method
  my $field = shift;
  my $fs = $STRUCTURE->{aliases}{$type}{$name}{fields};
  return $fs ? keys(%$fs) : '';
}



=head2 get_reverse_alias

    Retrieve a reverse alias (realname -> alias) for a type

=cut

sub get_reverse_alias {
  shift; # class method
  my $type = shift;
  my $rname = shift;
  return $STRUCTURE->{reversealiases}{$rname} // '';
}

