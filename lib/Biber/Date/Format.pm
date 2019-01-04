package Biber::Date::Format;
use v5.24;

use strict;
use Carp;
use DateTime;
use DateTime::TimeZone;
use DateTime::Format::Builder;
use DateTime::Calendar::Julian;

=encoding utf-8

=head1 NAME

Biber::Date::Format

=head2 Description

  Implements ISO8601-2:2016 Extended Format and also allows detection of
  missing month/year.

=cut


# Needed as a reset of class information between parses as this isn't reset
# by a new parse_datetime
sub init {
  my $self = shift;
  delete $self->{missing};
  delete $self->{approximate};
  delete $self->{uncertain};
  delete $self->{season};
  delete $self->{julian};
  return $self;
}

sub set_julian {
  my $self = shift;
  $self->{julian} = 1;
}

sub julian {
  my $self = shift;
  return $self->{julian};
}

sub missing {
  my $self = shift;
  my $part = shift;
  return $self->{missing}{$part};
}

sub approximate {
  my $self = shift;
  return $self->{approximate};
}

sub uncertain {
  my $self = shift;
  return $self->{uncertain};
}

sub season {
  my $self = shift;
  return $self->{season};
}

DateTime::Format::Builder->create_class(
    parsers => {
        parse_datetime => [
            [ preprocess => \&_pre ],
            {# ISO8601-1 4.2
                #[-]YYYY-MM-DDThh:mm:ss 1985-04-12T10:15:30
                length => [ qw( 19 20 ) ],
                regex  => qr/^ (-?\d{4}) - (\d\d) - (\d\d)
                            T (\d\d) : (\d\d) : (\d\d) $/x,
                params => [ qw( year month day hour minute second ) ],
            },
            {# ISO8601-1 4.1
                #[-]YYYY-MM-DD 1985-04-12
                length => [ qw( 10 11 ) ],
                regex  => qr/^ (-?\d{4}) - (\d\d) - (\d\d) $/x,
                params => [ qw( year month day ) ],
                postprocess => \&_missing_time
            },
            {# ISO8601-1 4.1
                #[-]YYYY-MM 1985-04
                length => [ qw( 7 8 ) ],
                regex  => qr/^ (-?\d{4}) - (\d\d) $/x,
                params => [ qw( year month ) ],
                postprocess => [ \&_missing_day,
                                 \&_missing_time ]
            },
            {# ISO8601-1 4.1
                #[-]YYYY 1985
                length => [ qw( 4 5 ) ],
                regex  => qr/^ (-?\d{4}) $/x,
                params => [ qw( year ) ],
                postprocess => [ \&_missing_month,
                                 \&_missing_day,
                                 \&_missing_time ]
            },
            {# ISO8601-2 4.5.1
                #Y[-]YYYYY... Y17000000002
                regex  => qr/^ Y(-?\d{5,}) $/x,
                params => [ qw( year ) ],
                postprocess => [ \&_missing_month,
                                 \&_missing_day,
                                 \&_missing_time ]
            },
        ],
    }
);


# Parse out timezones and missing/meta information
sub _pre {
  my %p = @_;
  delete $p{self}{missing};
  delete $p{self}{approximate};
  delete $p{self}{uncertain};
  delete $p{self}{season};

  my %seasons = ( 21 => 'spring',
                  22 => 'summer',
                  23 => 'autumn',
                  24 => 'winter' );


  # ISO 8601-2:2016 4.2.1 (uncertain)
  if ($p{input} =~ s/^\s*(.+?)\s*\?\s*$/$1/i) {
    $p{self}{uncertain} = 1;
  }

  # ISO 8601-2:2016 4.2.1 (approximate)
  if ($p{input} =~ s/^\s*(.+?)\s*\~\s*$/$1/i) {
    $p{self}{approximate} = 1;
  }

  # ISO 8601-2:2016 4.2.1 (uncertain+approximate)
  if ($p{input} =~ s/^\s*(.+?)\s*\%\s*$/$1/i) {
    $p{self}{uncertain} = 1;
    $p{self}{approximate} = 1;
  }

  # ISO8601-1 4.2.2 (time zone)
  if ($p{input} =~ s/Z$//) {
    $p{parsed}{time_zone} = 'UTC';
  }
  elsif ($p{input} =~ s/([+-]\d\d:\d\d)$//) {
    $p{parsed}{time_zone} = $1;
  }

  # ISO8601-2:2016 4.7 (season)
  if ($p{input} =~ s/^(-?\d{4})-(2[1234])$/$1/) {
    $p{self}{season} = $seasons{$2};
  }

  return $p{input};
}

sub _missing_month {
  my %p = @_;
  $p{self}{missing}{month} = 1;
  return 1;
}

sub _missing_day {
  my %p = @_;
  $p{self}{missing}{day} = 1;
  return 1;
}

sub _missing_time {
  my %p = @_;
  $p{self}{missing}{time} = 1;
  return 1;
}

1;

__END__

=head1 AUTHORS

Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our Github tracker at
L<https://github.com/plk/biber/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2019 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
