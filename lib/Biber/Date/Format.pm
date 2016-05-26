package Biber::Date::Format;
use v5.16;

use strict;
use Carp;
use parent qw(DateTime::Format::ISO8601);

=encoding utf-8

=head1 NAME

Biber::Date::Format

=head2 Description

  Subclass of DateTime::Format::ISO8601 which allows detection of missing month/year and
  with time parsers removed as they are not needed.
  Also added a ->missing() method to detect when month/year are missing.

  Does not support the "truncated" formats from ISO8601v2000, section 5.2.1.3 as these are
  not in the later ISO8601v2004 and are not really suited to bibliographies.

  Supports ISO8601v2004 negative date specifications

=cut

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

DateTime::Format::Builder->create_class(
    parsers => {
        parse_datetime => [
            [ preprocess => \&_pre ],
            {
                #YYYYMMDD 19850412
                length => 8,
                regex  => qr/^ (\d{4}) (\d\d) (\d\d) $/x,
                params => [ qw( year month day ) ],
            },
            {
                # uncombined with above because
                #regex => qr/^ (\d{4}) -??  (\d\d) -?? (\d\d) $/x,
                # was matching 152746-05

                #YYYY-MM-DD 1985-04-12
                length => 10,
                regex  => qr/^ (\d{4}) - (\d\d) - (\d\d) $/x,
                params => [ qw( year month day ) ],
            },
            {
                #YYYY-MM 1985-04
                length => 7,
                regex  => qr/^ (\d{4}) - (\d\d) $/x,
                params => [ qw( year month ) ],
                postprocess => \&_missing_day,
            },
            {
                #YYYY 1985
                length => 4,
                regex  => qr/^ (\d{4}) $/x,
                params => [ qw( year ) ],
                postprocess => [ \&_missing_month,
                                 \&_missing_day ],
            },
            {
                #YYY 758
                length => 3,
                regex  => qr/^ (\d{3}) $/x,
                params => [ qw( year ) ],
                postprocess => [ \&_missing_month,
                                 \&_missing_day ],
            },
            {
                #YY 19 (century)
                length => 2,
                regex  => qr/^ (\d\d) $/x,
                params => [ qw( year ) ],
                postprocess => [ \&DateTime::Format::ISO8601::_normalize_century,
                                 \&_missing_month,
                                 \&_missing_day ],
            },
            {
                #-YYYYMMDD -03790201
                #-YYYY-MM-DD -0379-02-01
                length => [ qw( 9 11 ) ],
                regex  => qr/^ (-\d{4}) -?? (\d\d) -?? (\d\d) $/x,
                params => [ qw( year month day) ],
            },
            {
                #-YYYYMM -037902
                #-YYYY-MM -0379-02
                length => [ qw( 7 8 ) ],
                regex  => qr/^ (-\d{4}) -?? (\d\d) $/x,
                params => [ qw( year month) ],
                postprocess => \&_missing_day,
            },
            {
                #-YYYY -0379
                length => 5,
                regex  => qr/^ (-\d{4}) $/x,
                params => [ qw( year ) ],
                postprocess => [ \&_missing_month,
                                 \&_missing_day ],
            },
            {
                #-YYY -379
                length => 4,
                regex  => qr/^ (-\d{3}) $/x,
                params => [ qw( year ) ],
                postprocess => [ \&_missing_month,
                                 \&_missing_day ],
            },
            {
                #-YY -85
                length   => 3,
                regex    => qr/^ - (\d\d) $/x,
                params   => [ qw( year ) ],
                postprocess => [ \&DateTime::Format::ISO8601::_fix_2_digit_year,
                                 \&_missing_month,
                                 \&_missing_day ],
            },
            {
                #+[YY]YYYYMMDD +0019850412
                #+[YY]YYYY-MM-DD +001985-04-12
                length => [ qw( 11 13 ) ],
                regex  => qr/^ \+ (\d{6}) -?? (\d\d) -?? (\d\d)  $/x,
                params => [ qw( year month day ) ],
            },
            {
                #+[YY]YYYY-MM +001985-04
                length => 10,
                regex  => qr/^ \+ (\d{6}) - (\d\d)  $/x,
                params => [ qw( year month ) ],
            },
            {
                #+[YY]YYYY +001985
                length => 7,
                regex  => qr/^ \+ (\d{6}) $/x,
                params => [ qw( year ) ],
            },
            {
                #+[YY]YY +0019 (century)
                length => 5,
                regex  => qr/^ \+ (\d{4}) $/x,
                params => [ qw( year ) ],
                postprocess => \&DateTime::Format::ISO8601::_normalize_century,
            },
            {
                #YYYYDDD 1985102
                #YYYY-DDD 1985-102
                length => [ qw( 7 8 ) ],
                regex  => qr/^ (\d{4}) -?? (\d{3}) $/x,
                params => [ qw( year day_of_year ) ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
            {
                #YYDDD 85102
                #YY-DDD 85-102
                length => [ qw( 5 6 ) ],
                regex  => qr/^ (\d\d) -?? (\d{3}) $/x,
                params => [ qw( year day_of_year ) ],
                postprocess => [ \&DateTime::Format::ISO8601::_fix_2_digit_year ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
            {
                #-DDD -102
                length => 4,
                regex  => qr/^ - (\d{3}) $/x,
                params => [ qw( day_of_year ) ],
                postprocess => [ \&DateTime::Format::ISO8601::_add_year ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
            {
                #+[YY]YYYYDDD +001985102
                #+[YY]YYYY-DDD +001985-102
                length => [ qw( 10 11 ) ],
                regex  => qr/^ \+ (\d{6}) -?? (\d{3}) $/x,
                params => [ qw( year day_of_year ) ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
            {
                #YYYYWwwD 1985W155
                #YYYY-Www-D 1985-W15-5
                length => [ qw( 8 10 ) ],
                regex  => qr/^ (\d{4}) -?? W (\d\d) -?? (\d) $/x,
                params => [ qw( year week day_of_year ) ],
                postprocess => [ \&DateTime::Format::ISO8601::_normalize_week ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
            {
                #YYYYWww 1985W15
                #YYYY-Www 1985-W15
                length => [ qw( 7 8 ) ],
                regex  => qr/^ (\d{4}) -?? W (\d\d) $/x,
                params => [ qw( year week ) ],
                postprocess => [ \&DateTime::Format::ISO8601::_normalize_week ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
            {
                #YYWwwD 85W155
                #YY-Www-D 85-W15-5
                length => [ qw( 6 8 ) ],
                regex  => qr/^ (\d\d) -?? W (\d\d) -?? (\d) $/x,
                params => [ qw( year week day_of_year ) ],
                postprocess => [ \&DateTime::Format::ISO8601::_fix_2_digit_year,
                                 \&DateTime::Format::ISO8601::_normalize_week ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
            {
                #YYWww 85W15
                #YY-Www 85-W15
                length => [ qw( 5 6 ) ],
                regex  => qr/^ (\d\d) -?? W (\d\d) $/x,
                params => [ qw( year week ) ],
                postprocess => [ \&DateTime::Format::ISO8601::_fix_2_digit_year,
                                 \&DateTime::Format::ISO8601::_normalize_week ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
            {
                #-YWwwD -5W155
                #-Y-Www-D -5-W15-5
                length => [ qw( 6 8 ) ],
                regex  => qr/^ - (\d) -?? W (\d\d) -?? (\d) $/x,
                params => [ qw( year week day_of_year ) ],
                postprocess => [ \&DateTime::Format::ISO8601::_fix_1_digit_year,
                                 \&DateTime::Format::ISO8601::_normalize_week ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
            {
                #-YWww -5W15
                #-Y-Www -5-W15
                length => [ qw( 5 6 ) ],
                regex  => qr/^ - (\d) -?? W (\d\d) $/x,
                params => [ qw( year week ) ],
                postprocess => [ \&DateTime::Format::ISO8601::_fix_1_digit_year,
                                 \&DateTime::Format::ISO8601::_normalize_week ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
            {
                #-WwwD -W155
                #-Www-D -W15-5
                length => [ qw( 5 6 ) ],
                regex  => qr/^ - W (\d\d) -?? (\d) $/x,
                params => [ qw( week day_of_year ) ],
                postprocess => [ \&DateTime::Format::ISO8601::_add_year,
                                 \&DateTime::Format::ISO8601::_normalize_week ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
            {
                #-Www -W15
                length => 4,
                regex  => qr/^ - W (\d\d) $/x,
                params => [ qw( week ) ],
                postprocess => [ \&DateTime::Format::ISO8601::_add_year,
                                 \&DateTime::Format::ISO8601::_normalize_week ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
            {
                #-W-D -W-5
                length => 4,
                regex  => qr/^ - W - (\d) $/x,
                params => [ qw( day_of_year ) ],
                postprocess => [
                                \&DateTime::Format::ISO8601::_add_year,
                                \&DateTime::Format::ISO8601::_add_week,
                                \&DateTime::Format::ISO8601::_normalize_week,
                ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
            {
                #+[YY]YYYYWwwD +001985W155
                #+[YY]YYYY-Www-D +001985-W15-5
                length => [ qw( 11 13 ) ],
                regex  => qr/^ \+ (\d{6}) -?? W (\d\d) -?? (\d) $/x,
                params => [ qw( year week day_of_year ) ],
                postprocess => [ \&DateTime::Format::ISO8601::_normalize_week ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
            {
                #+[YY]YYYYWww +001985W15
                #+[YY]YYYY-Www +001985-W15
                length => [ qw( 10 11 ) ],
                regex  => qr/^ \+ (\d{6}) -?? W (\d\d) $/x,
                params => [ qw( year week ) ],
                postprocess => [ \&DateTime::Format::ISO8601::_normalize_week ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
        ],
    }
);


# Convert explicit era to negative ISO8601 format before parsing
sub _pre {
  my %p = @_;
  delete $p{self}{missing};
  delete $p{self}{circa};
  delete $p{self}{uncertain};

  # circa dates - strip circa marker and save flag
  if ($p{input} =~ s/^\s*c(?:irc)?(?:a)?\.?\s*(.+?)\s*$/$1/i) {
    $p{self}{circa} = 1;
  }

  # uncertain dates - strip uncertain marker and save flag
  if ($p{input} =~ s/^\s*(.+?)\s*\?\s*$/$1/i) {
    $p{self}{uncertain} = 1;
  }

  # explicit eras - strip era marker and save flag
  if ($p{input} =~ m/^\s*(\d{1,4})-??(\d\d)?-??(\d\d)?\s*BCE?\s*$/i) {
    return '-' . sprintf('%.4d', $1-1) . "$2$3";
  }
  elsif ($p{input} =~ m/^\s*(\d{1,4})-??(\d\d)?-??(\d\d)?\s*(?:AD|CE)\s*$/i) {
    # YYYYMM is no a valid ISO8601v2004 format
    return sprintf('%.4d', $1) . ($2 ? "-$2" : '') . ($3 ? "-$3" : '');
  }
  else {
    return $p{input};
  }
}

sub _missing_year {
  my %p = @_;
  $p{self}{missing}{year} = 1;
  return 1;
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


1;
