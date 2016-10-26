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

  Implements EDTF Levels 0 and 1 and also allows detection of
  missing month/year.

  https://www.loc.gov/standards/datetime/pre-submission.html

=cut


# Needed as a reset of class information between parses as this isn't reset
# by a new parse_datetime
sub init {
  my $self = shift;
  delete $self->{missing};
  delete $self->{circa};
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

sub circa {
  my $self = shift;
  return $self->{circa};
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
            {# EDTF 5.1.2
                #[-]YYYY-MM-DDThh:mm:ss 1985-04-12T10:15:30
                length => [ qw( 19 20 ) ],
                regex  => qr/^ (-?\d{4}) - (\d\d) - (\d\d)
                            T (\d\d) : (\d\d) : (\d\d) $/x,
                params => [ qw( year month day hour minute second ) ],
            },
            {# EDTF 5.1.1
                #[-]YYYY-MM-DD 1985-04-12
                length => [ qw( 10 11 ) ],
                regex  => qr/^ (-?\d{4}) - (\d\d) - (\d\d) $/x,
                params => [ qw( year month day ) ],
                postprocess => \&_missing_time
            },
            {# EDTF 5.1.1
                #[-]YYYY-MM 1985-04
                length => [ qw( 7 8 ) ],
                regex  => qr/^ (-?\d{4}) - (\d\d) $/x,
                params => [ qw( year month ) ],
                postprocess => [ \&_missing_day,
                                 \&_missing_time ]
            },
            {# EDTF 5.1.1
                #[-]YYYY 1985
                length => [ qw( 4 5 ) ],
                regex  => qr/^ (-?\d{4}) $/x,
                params => [ qw( year ) ],
                postprocess => [ \&_missing_month,
                                 \&_missing_day,
                                 \&_missing_time ]
            },
            {# EDTF 5.2.4
                #y[-]YYYYY... y17000000002
                regex  => qr/^ y(-?\d{5,}) $/x,
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
  delete $p{self}{circa};
  delete $p{self}{uncertain};
  delete $p{self}{season};

  my %seasons = ( 21 => 'spring',
                  22 => 'summer',
                  23 => 'autumn',
                  24 => 'winter' );


  # EDTF 5.2.1 (approximate)
  if ($p{input} =~ s/^\s*(.+?)\s*\~\s*$/$1/i) {
    $p{self}{circa} = 1;
  }

  # EDTF 5.2.1 (uncertain)
  if ($p{input} =~ s/^\s*(.+?)\s*\?\s*$/$1/i) {
    $p{self}{uncertain} = 1;
  }

  # EDTF 5.1.2 (time zone)
  if ($p{input} =~ s/Z$//) {
    $p{parsed}{time_zone} = 'UTC';
  }
  elsif ($p{input} =~ s/([+-]\d\d:\d\d)$//) {
    $p{parsed}{time_zone} = $1;
  }

  # EDTF 5.1.5 (season)
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
