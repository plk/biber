package Biber::Internals;
use 5.014000;
use strict;
use warnings;

use Carp;
use Biber::Constants;
use Biber::Utils;
use Data::Compare;
use Text::Wrap;
$Text::Wrap::columns = 80;
use List::AllUtils qw( :all );
use Log::Log4perl qw(:no_extra_logdie_message);
use Digest::MD5 qw( md5_hex );
use POSIX qw( locale_h ); # for lc()
use Encode;

=encoding utf-8

=head1 NAME

Biber::Internals - Internal methods for processing the bibliographic data

=head1 METHODS


=cut

my $logger = Log::Log4perl::get_logger('main');


sub _getnamehash {
  my ($self, $citekey, $names) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');
  my $hashkey = '';
  my $count = $names->count_names;
  my $visible = $names->get_visible_cite;

  # namehash obeys list truncations but not uniquename
  foreach my $n (@{$names->first_n_names($visible)}) {
    if ( $n->get_prefix and
         Biber::Config->getblxoption('useprefix', $bee, $citekey)) {
      $hashkey .= $n->get_prefix;
    }
    $hashkey .= $n->get_lastname;

    if ( $n->get_suffix ) {
      $hashkey .= $n->get_suffix;
    }

    if ( $n->get_firstname ) {
      $hashkey .= $n->get_firstname;
    }

    if ( $n->get_middlename ) {
      $hashkey .= $n->get_middlename;
    }

    # without useprefix, prefix is not first in the hash
    if ( $n->get_prefix and not
         Biber::Config->getblxoption('useprefix', $bee, $citekey)) {
      $hashkey .= $n->get_prefix;
    }

  }

  # name list was truncated
  if ($visible < $count or $names->get_morenames) {
    $hashkey .= '+';
  }

  $logger->trace("Creating MD5 namehash using '$hashkey'");
  # Digest::MD5 can't deal with straight UTF8 so encode it first
  return md5_hex(encode_utf8($hashkey));
}

# Same as _getnamehash but takes account of uniquename setting for firstname
# It's used for extra* tracking only
sub _getnamehash_u {
  my ($self, $citekey, $names) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');
  my $hashkey = '';
  my $count = $names->count_names;
  my $visible = $names->get_visible_cite;

  # namehash obeys list truncations but not uniquename
  foreach my $n (@{$names->first_n_names($visible)}) {
    if ( $n->get_prefix and
         Biber::Config->getblxoption('useprefix', $bee, $citekey)) {
      $hashkey .= $n->get_prefix;
    }
    $hashkey .= $n->get_lastname;

    if ( $n->get_suffix ) {
      $hashkey .= $n->get_suffix;
    }

    if ( $n->get_firstname ) {
      given ($n->get_uniquename) {
        when (2) {
          $hashkey .= $n->get_firstname;
        }
        when (1) {
          $hashkey .= join('', @{$n->get_firstname_i});
        }
      }
    }

    if ( $n->get_middlename ) {
      $hashkey .= $n->get_middlename;
    }

    # without useprefix, prefix is not first in the hash
    if ( $n->get_prefix and not
         Biber::Config->getblxoption('useprefix', $bee, $citekey)) {
      $hashkey .= $n->get_prefix;
    }

  }

  # name list was truncated
  if ($visible < $count or $names->get_morenames) {
    $hashkey .= '+';
  }

  $logger->trace("Creating MD5 namehash_u using '$hashkey'");
  # Digest::MD5 can't deal with straight UTF8 so encode it first
  return md5_hex(encode_utf8($hashkey));
}


sub _getfullhash {
  my ($self, $citekey, $names) = @_;
  my $hashkey = '';
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  foreach my $n (@{$names->names}) {
    if ( my $p = $n->get_prefix and
      Biber::Config->getblxoption('useprefix', $be->get_field('entrytype'), $citekey ) ) {
      $hashkey .= $p;
    }
    $hashkey .= $n->get_lastname;

    if ( $n->get_suffix ) {
      $hashkey .= $n->get_suffix;
    }

    if ( $n->get_firstname ) {
      $hashkey .= $n->get_firstname;
    }

    if ( $n->get_middlename ) {
      $hashkey .= $n->get_middlename;
    }

    # without useprefix, prefix is not first in the hash
    if ( my $p = $n->get_prefix and not
         Biber::Config->getblxoption('useprefix', $be->get_field('entrytype'), $citekey ) ) {
      $hashkey .= $p;
    }

  }

  # If we had an "and others"
  if ($names->get_morenames) {
    $hashkey .= '+'
  }

  $logger->trace("Creating MD5 fullhash using '$hashkey'");
  # Digest::MD5 can't deal with straight UTF8 so encode it first
  return md5_hex(encode_utf8($hashkey));
}


sub _getpnhash {
  my ($self, $citekey, $n) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $hashkey = '';

  if ( my $p = $n->get_prefix and
       Biber::Config->getblxoption('useprefix', $be->get_field('entrytype'), $citekey ) ) {
    $hashkey .= $p;
  }
  $hashkey .= $n->get_lastname;

  if ( $n->get_suffix ) {
    $hashkey .= $n->get_suffix;
  }

  if ( $n->get_firstname ) {
    $hashkey .= $n->get_firstname;
  }

  if ( $n->get_middlename ) {
    $hashkey .= $n->get_middlename;
  }

  # without useprefix, prefix is not first in the hash
  if ( $n->get_prefix and not
       Biber::Config->getblxoption('useprefix', $be->get_field('entrytype'), $citekey ) ) {
    $hashkey .= $n->get_prefix;
  }

  $logger->trace("Creating MD5 pnhash using '$hashkey'");
  # Digest::MD5 can't deal with straight UTF8 so encode it first
  return md5_hex(encode_utf8($hashkey));
}


#########################
# custom label generation (labelalpha = 2)
#########################

our $dispatch_label = {
  'afterword'         =>  [\&_label_name,             ['afterword']],
  'annotator'         =>  [\&_label_name,             ['annotator']],
  'author'            =>  [\&_label_name,             ['author']],
  'bookauthor'        =>  [\&_label_name,             ['bookauthor']],
  'booktitle'         =>  [\&_label_title,            ['booktitle']],
  'commentator'       =>  [\&_label_name,             ['commentator']],
  'editor'            =>  [\&_label_name,             ['editor']],
  'editora'           =>  [\&_label_name,             ['editora']],
  'editorb'           =>  [\&_label_name,             ['editorb']],
  'editorc'           =>  [\&_label_name,             ['editorc']],
  'eventday'          =>  [\&_label_day,              ['eventday']],
  'eventmonth'        =>  [\&_label_month,            ['eventmonth']],
  'eventyear'         =>  [\&_label_year,             ['eventyear']],
  'day'               =>  [\&_label_day,              ['day']],
  'foreword'          =>  [\&_label_name,             ['foreword']],
  'holder'            =>  [\&_label_name,             ['holder']],
  'introduction'      =>  [\&_label_name,             ['introduction']],
  'journaltitle'      =>  [\&_label_title,            ['journaltitle']],
  'label'             =>  [\&_label_label,            []],
  'labelname'         =>  [\&_label_labelname,        []],
  'labelyear'         =>  [\&_label_labelyear,        []],
  'maintitle'         =>  [\&_label_title,            ['maintitle']],
  'month'             =>  [\&_label_month,            ['month']],
  'namea'             =>  [\&_label_name,             ['namea']],
  'nameb'             =>  [\&_label_name,             ['nameb']],
  'namec'             =>  [\&_label_name,             ['namec']],
  'origday'           =>  [\&_label_day,              ['origday']],
  'origmonth'         =>  [\&_label_month,            ['origmonth']],
  'origyear'          =>  [\&_label_year,             ['origyear']],
  'origtitle'         =>  [\&_label_title,            ['origtitle']],
  'shorthand'         =>  [\&_label_shorthand,        []],
  'title'             =>  [\&_label_title,            ['title']],
  'translator'        =>  [\&_label_name,             ['translator']],
  'urlday'            =>  [\&_label_day,              ['urlday']],
  'urlmonth'          =>  [\&_label_month,            ['urlmonth']],
  'urlyear'           =>  [\&_label_year,             ['urlyear']],
  'year'              =>  [\&_label_year,             ['year']],
};

# Main label loop
sub _genlabel {
  my ($self, $citekey) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $labelalphatemplate = Biber::Config->getblxoption('labelalphatemplate', $be->get_field('entrytype'));
  my $label;
  my $slabel;
  $LABEL_FINAL = 0; # reset final shortcut

  foreach my $labelpart (sort {$a->{order} <=> $b->{order}} @{$labelalphatemplate->{labelelement}}) {
    my $ret = _labelpart($self, $labelpart->{labelpart}, $citekey);
    $label .= $ret->[0];
    $slabel .= $ret->[1];
    last if $LABEL_FINAL;
  }

  return [ $label, $slabel ];
}

# Disjunctive set of label parts
sub _labelpart {
  my ($self, $labelpart, $citekey) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');
  my $struc = Biber::Config->get_structure;
  my $maxan = Biber::Config->getblxoption('maxalphanames', $bee, $citekey);
  my $minan = Biber::Config->getblxoption('minalphanames', $bee, $citekey);
  my $lp;
  my $slp;

  foreach my $part (@$labelpart) {
    # Deal with various tests
    # ifnamecount only uses this label template part if the list it is applied to is a certain
    # length
    if (my $ic = $part->{ifnamecount}) {
      my $f = $part->{content};
      if (first {$_ eq $f} @{$struc->get_field_type('name')} or
          $f eq 'labelname') {
        my $name = $be->get_field($f) || next; # just in case there is no labelname etc.
        my $total_names = $name->count_names;
        my $visible_names;
        if ($total_names > $maxan) {
          $visible_names = $minan;
        }
        else {
          $visible_names = $total_names;
        }

        next unless $visible_names == $ic;
      }
    }
    my $ret = _dispatch_label($self, $part, $citekey);
    $lp .= $ret->[0];
    $slp .= $ret->[1];

    # We use the first one to return something
    if ($ret->[0]) {
      $LABEL_FINAL = 1 if $part->{final};
      last;
    }
  }

  return [ $lp, $slp ];
}


# Main label dispatch method
sub _dispatch_label {
  my ($self, $part, $citekey) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $struc = Biber::Config->get_structure;
  my $code_ref;
  my $code_args_ref;
  my $lp;
  my $slp;

  # if the field is not found in the dispatch table, assume it's a literal string
  unless (exists($dispatch_label->{$part->{content}})) {
    $code_ref = \&_label_literal;
    $code_args_ref = [$part->{content}];
  }
  else { # real label field
    $code_ref = ${$dispatch_label->{$part->{content}}}[0];
    $code_args_ref = ${$dispatch_label->{$part->{content}}}[1];
  }
  return &{$code_ref}($self, $citekey, $code_args_ref, $part);
}


#########################
# Label dispatch routines
#########################

sub _label_day {
  my ($self, $citekey, $args, $labelattrs) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $day = $args->[0];
  if (my $f = $be->get_field($day)) {
    my $y = _process_label_attributes($self, $citekey, $f, $labelattrs, $day);
    return [$y, $y];
  }
  else {
    return ['', ''];
  }
}

sub _label_label {
  my ($self, $citekey, $args, $labelattrs) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  if (my $f = $be->get_field('label')) {
    my $l = _process_label_attributes($self, $citekey, $f, $labelattrs, 'label');
    return [$l, $l];
  }
  else {
    return ['', ''];
  }
}

sub _label_labelyear {
  my ($self, $citekey, $args, $labelattrs) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  # re-direct to the right label routine for the labelyear
  if (my $lyn = $be->get_field('labelyearname')) {
    $args->[0] = $lyn;
    return $self->_label_year($citekey, $args, $labelattrs);
  }
  else {
    return ['', ''];
  }
}

sub _label_labelname {
  my ($self, $citekey, $args, $labelattrs) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  # re-direct to the right label routine for the labelname
  if (my $lnn = $be->get_field('labelnamename')) {
    $args->[0] = $lnn;
    return $self->_label_name($citekey, $args, $labelattrs);
  }
  else {
    return ['', ''];
  }
}

# literal string - don't post-process this, there is no point
sub _label_literal {
  my ($self, $citekey, $args, $labelattrs) = @_;
  my $string = $args->[0];
  return [$string, $string];
}

sub _label_month {
  my ($self, $citekey, $args, $labelattrs) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $month = $args->[0];
  if (my $f = $be->get_field($month)) {
    my $y = _process_label_attributes($self, $citekey, $f, $labelattrs, $month);
    return [$y, $y];
  }
  else {
    return ['', ''];
  }
}

sub _label_name {
  my ($self, $citekey, $args, $labelattrs) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $useprefix = Biber::Config->getblxoption('useprefix', $be->get_field('entrytype'), $citekey);
  my $alphaothers = Biber::Config->getblxoption('alphaothers', $be->get_field('entrytype'));
  my $sortalphaothers = Biber::Config->getblxoption('sortalphaothers', $be->get_field('entrytype'));
  my $namename = $args->[0];
  my $acc;
  # This contains sortalphaothers instead of alphaothers, if defined
  # This is needed in cases where alphaothers is something like
  # '\textasteriskcentered' which would mess up sorting.
  my $sortacc;

  # Account for labelname set to short* when testing use* options
  my $lnameopt;
  if ( $namename =~ /\Ashort(.+)\z/ ) {
    $lnameopt = $1;
  }
  else {
    $lnameopt = $namename;
  }

  if (Biber::Config->getblxoption("use$lnameopt", $be->get_field('entrytype'), $citekey) and
    $be->get_field($namename)) {
    my $names = $be->get_field($namename);
    my $numnames  = $names->count_names;
    my $visibility = $names->get_visible_alpha;

    my @lastnames = map { strip_nosort(normalise_string($_->get_lastname), $namename) } @{$names->names};
    my @prefices  = map { $_->get_prefix } @{$names->names};
    my $loopnames;

    # loopnames is the number of names to loop over in the name list when constructing the label
    if (my $lc = $labelattrs->{namecount}) {
      if ($lc > $numnames) { # cap at numnames, of course
        $lc = $numnames;
      }
      $loopnames = $lc; # Only look as many names as specified
    }
    else {
      $loopnames = $visibility; # Else use bib visibility
    }

    for (my $i = 0; $i < $loopnames; $i++) {
      $acc .= substr($prefices[$i] , 0, 1) if ($useprefix and $prefices[$i]);
      $acc .= _process_label_attributes($self, $citekey, $lastnames[$i], $labelattrs, $namename, 'lastname', $i);
    }

    $sortacc = $acc;

    # Add alphaothers if name list is truncated
    if ($numnames > $loopnames or $names->get_morenames) {
      $acc .= $alphaothers // ''; # alphaothers can be undef
      $sortacc .= $sortalphaothers // ''; # sortalphaothers can be undef
    }

    return [$acc, $sortacc];
  }
  else {
    return ['', ''];
  }
}

sub _label_shorthand {
  my ($self, $citekey, $args, $labelattrs) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  if (my $f = $be->get_field('shorthand')) {
    my $s = _process_label_attributes($self, $citekey, $f, $labelattrs, 'shorthand');
    return [$s, $s];
  }
  else {
    return ['', ''];
  }
}

sub _label_title {
  my ($self, $citekey, $args, $labelattrs) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $title = $args->[0];
  my $be = $section->bibentry($citekey);
  if (my $f = $be->get_field($title)) {
    my $t = _process_label_attributes($self, $citekey, $f, $labelattrs, $title);
    return [$t, $t];
  }
  else {
    return ['', ''];
  }
}


sub _label_year {
  my ($self, $citekey, $args, $labelattrs) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $year = $args->[0];
  if (my $f = $be->get_field($year)) {
    my $y = _process_label_attributes($self, $citekey, $f, $labelattrs, $year);

    # Make "in press" years look nice in alpha styles
    if ($f =~ m/\A\s*in\s*press\s*\z/ixms) {
      $y = 'ip';
    }
    return [$y, $y];
  }
  else {
    return ['', ''];
  }
}


# Label generation utilities

# Modify label string according to some attributes
# We use different caches for the "v" and "l" schemes because they have a different format
# internally and interfere with each other between resets in prepare() otherwise
sub _process_label_attributes {
  my ($self, $citekey, $field_string, $labelattrs, $field, $namepart, $index) = @_;
  return $field_string unless $labelattrs;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my @citekeys = $section->get_citekeys;
  my $nindex = first_index {$_ eq $citekey} @citekeys;

  if (defined($labelattrs->{substring_width})) {
    # dynamically disambiguated width (individual name disambiguation)
    if ($labelattrs->{substring_width} =~ /v/ and $field) {
      # Use the cache if there is one
      if (my $lcache = $section->get_labelcache_v($field)) {
        $logger->debug("Using label disambiguation cache (name) for '$field' in section $secnum");
        # Use the global index override if set (substring_width =~ /f/)
        $field_string = ${$lcache->{$field_string}{data}}[$lcache->{globalindices}{$field_string} || $lcache->{$field_string}{index}];
      }
      else {
        # This contains a mapping of strings to substrings of increasing lengths
        my %substr_cache = ();
        my $lcache = {};

        # Get the indices of each field (or namepart) we are dealing with
        my %indices;
        foreach my $key (@citekeys) {
          if (my $f = $section->bibentry($key)->get_field($field)) {
            if ($namepart) {
              foreach my $n (@{$f->first_n_names($f->get_visible_alpha)}) {
               $indices{$n->get_namepart($namepart)} = $n->get_index;
              }
            }
            else {
              $indices{$f} = 0;
            }
          }
        }

        # This ends up as a flat list due to array interpolation
        my @strings = uniq keys %indices;

        # Look to the index of the longest string or the explicit max width if set
        my $maxlen = $labelattrs->{substring_width_max} || max map {length($_)} @strings;
        for (my $i = 1; $i <= $maxlen; $i++) {
          foreach my $map (map { my $s = substr($_, 0, $i); $substr_cache{$s}++; [$_, $s] } @strings) {
            # We construct a list of all substrings, up to the length of the longest string
            # or substring_width_max. Then we save the index of the list element which is
            # the minimal disambiguation if it's not yet defined
            push @{$lcache->{$map->[0]}{data}}, $map->[1];
            $lcache->{$map->[0]}{nameindex} = $indices{$map->[0]};
            if (not exists($lcache->{$map->[0]}{index}) and
                ($substr_cache{$map->[1]} == 1 or $i == $maxlen)) {
              # -1 to make it into a clean array index
              $lcache->{$map->[0]}{index} = length($map->[1]) - 1;
            }
          }
        }

        # We want to use a string width for all strings equal to the longest one needed
        # to disambiguate this list. We do this by saving an override for the minimal
        # disambiguation length per index
        if ($labelattrs->{substring_width} =~ /f/) {
          # Get the uniqueness indices of all of the strings and strip out those
          # which don't occur at least substring_fixed_threshold times

          my $is;
          foreach my $v (values %$lcache) {
            $is->{$v->{nameindex}}{$v->{index}}++;
          }

          # Now set a new global index for the name part index which is the maximum of those
          # occuring above a certain threshold
          foreach my $s (keys %$lcache) {
            foreach my $ind (keys %$is) {
              next unless $indices{$s} == $ind;
              $lcache->{globalindices}{$s} = max grep {$is->{$ind}{$_} >= $labelattrs->{substring_fixed_threshold} } keys %{$is->{$ind}};
            }
          }
        }

        # Use the global index override if set (substring_width =~ /f/)
        $field_string = ${$lcache->{$field_string}{data}}[$lcache->{globalindices}{$field_string} || $lcache->{$field_string}{index}];
        $logger->debug("Creating label disambiguation cache for '$field' " .
                       ($namepart ? "($namepart) " : '') .
                       "in section $secnum");
        $logger->trace("Label disambiguation cache for '$field' " .
                       ($namepart ? "($namepart) " : '') .
                       "in section $secnum:\n " . Data::Dump::pp($lcache));
        $section->set_labelcache_v($field, $lcache);
      }
    }
    # dynamically disambiguated width (list disambiguation)
    elsif ($labelattrs->{substring_width} =~ /l/ and $field) {
      # Use the cache if there is one
      if (my $lcache = $section->get_labelcache_l($field)) {
        $logger->debug("Using label disambiguation cache (list) for '$field' in section $secnum");
        $field_string = $lcache->{data}[$nindex][$index];
      }
      else {
        # This retains the structure of the entries for the "l" list disambiguation
        my $strings = [map {my $f = $section->bibentry($_)->get_field($field);
                            $namepart ? [map {$_->get_namepart($namepart)} @{$f->first_n_names($f->get_visible_alpha)}] : [$f]
                          } @citekeys];
        my $lcache = _label_listdisambiguation($strings);

        $field_string = $lcache->{data}[$nindex][$index];
        $logger->debug("Creating label disambiguation (list) cache for '$field' " .
                       ($namepart ? "($namepart) " : '') .
                       "in section $secnum");
        $logger->trace("Label disambiguation (list) cache for '$field' " .
                       ($namepart ? "($namepart) " : '') .
                       "in section $secnum:\n " . Data::Dump::pp($lcache));
        $section->set_labelcache_l($field, $lcache);
      }
    }
    # static substring width
    else {
      my $subs_offset = 0;
      my $default_substring_width = 1;
      my $default_substring_side = 'left';
      my $subs_width = ($labelattrs->{substring_width} or $default_substring_width);
      my $subs_side = ($labelattrs->{substring_side} or $default_substring_side);
      if ($subs_side eq 'right') {
        $subs_offset = 0 - $subs_width;
      }

      # If desired, do the substring on all part of compound strings (strings with internal spaces)
      if ($labelattrs->{substring_compound}) {
        my $tmpstring;
        foreach my $part (split(/\s+/, $field_string)) {
          $tmpstring .= substr( $part, $subs_offset, $subs_width );
        }
        $field_string = $tmpstring;
      }
      else {
        $field_string = substr( $field_string, $subs_offset, $subs_width );
      }
    }
  }
  return $field_string;
}

# This turns a list of label strings:
# (
#  ['Agassi', 'Chang',   'Laver', 'bob'],
#  ['Agassi', 'Connors', 'Lendl'],
#  ['Agassi', 'Courier', 'Laver'],
#  ['Borg',   'Connors', 'Edberg'],
#  ['Borg',   'Connors', 'Emerson']
# )
#
# firstly into the equivalence context:
# (
#   ["", "Agassi", "AgassiChang", "AgassiChangLaver"],
#   ["", "Agassi", "AgassiConnors"],
#   ["", "Agassi", "AgassiCourier"],
#   ["", "Borg", "BorgConnors"],
#   ["", "Borg", "BorgConnors"],
# )
#
# and finally, using this, into a disambiguated list of the same
# strings.
#
# { data => [
#            ['A', 'Ch',  'L',  'b'],
#            ['A', 'Con', 'L',  ''],
#            ['A', 'Cou', 'L',  ''],
#            ['B', 'C',   'Ed', ''],
#            ['B', 'C',   'Em', '']
#           ],
# }
#

sub _label_listdisambiguation {
  my $strings = shift;
  # normalise to the same length
  my $ml = max map {$#$_} @$strings;
  foreach my $row (@$strings) {
    for (my $i = 0; $i <= $ml; $i++) {
      $row->[$i] = $row->[$i] // '';
    }
  }

  my @equiv_class = map {my $acc; [map {$acc .= $_} ('', @$_[0 .. $#$_ - 1])]} @$strings;
  my $lcache = {};
  for (my $i = 0; $i <= $ml; $i++) {
    # This contains a mapping of equivalance classes to strings to substrings of
    # increasing lengths
    my %substr_cache = ();
    my @col = map {$_->[$i]} @$strings;
    my %seen = ();
    my $maxlen = max map {length} @col;
    for (my $k = 0; $k <= $#col; $k++) {
      for (my $j = 1; $j <= $maxlen; $j++) {
        my $s = substr($col[$k], 0, $j);
        $substr_cache{$equiv_class[$k]->[$i]}{$s}++;
      }
    }

    for (my $j = 1; $j <= $maxlen; $j++) {
      for (my $k = 0; $k <= $#col; $k++) {
        my $s = substr($col[$k], 0, $j);
        # We need the items from @col which are in the same equivalance class as the current
        # @col item
        my @col_eq = @col[indexes {$equiv_class[$k]->[$i] eq $_} map {$_->[$i]} @equiv_class];
        # Then we count the items in this slice of @col to see if it's the same size
        # as the substring cache count for this substring. If it is, we can stop here.
        # It would be more obvious to look for the first substring with count == 1 but
        # we can't do that because this requires using uniq to trim @col and we can do that
        # because we need to keep the indexes into $strings the same dimensions as @equiv_class
        if (not $lcache->{data}[$k][$i] and
            ($substr_cache{$equiv_class[$k]->[$i]}{$s} == scalar(grep {$_ eq $col[$k] } @col_eq) or
             $j == $maxlen)) {
          $lcache->{data}[$k][$i] = $s;
        }
      }
    }
  }
  return $lcache;
}


#########
# Sorting
#########

our $sorting_sep = ',';

# The keys are defined by BibLaTeX and passed in the control file
# The value is an array pointer, first element is a code pointer, second is
# a pointer to extra arguments to the code. This is to make code re-use possible
# so the sorting can share code for similar things.
our $dispatch_sorting = {
  'addendum'        =>  [\&_sort_literaln,      ['addendum']],
  'annotator'       =>  [\&_sort_name,          ['annotator']],
  'author'          =>  [\&_sort_name,          ['author']],
  'bookauthor'      =>  [\&_sort_name,          ['bookauthor']],
  'booksubtitle'    =>  [\&_sort_literaln,      ['booksubtitle']],
  'booktitle'       =>  [\&_sort_literaln,      ['booktitle']],
  'booktitleaddon'  =>  [\&_sort_literaln,      ['booktitleaddon']],
  'chapter'         =>  [\&_sort_literal,       ['chapter']],
  'citeorder'       =>  [\&_sort_citeorder,     []],
  'commentator'     =>  [\&_sort_name,          ['commentator']],
  'day'             =>  [\&_sort_dm,            ['day']],
  'edition'         =>  [\&_sort_literal,       ['edition']],
  'editor'          =>  [\&_sort_name,          ['editor']],
  'editora'         =>  [\&_sort_name,          ['editora']],
  'editoratype'     =>  [\&_sort_editortc,      ['editoratype']],
  'editorb'         =>  [\&_sort_name,          ['editorb']],
  'editorbtype'     =>  [\&_sort_editortc,      ['editorbtype']],
  'editorc'         =>  [\&_sort_name,          ['editorc']],
  'editorctype'     =>  [\&_sort_editortc,      ['editorctype']],
  'endday'          =>  [\&_sort_dm,            ['endday']],
  'endmonth'        =>  [\&_sort_dm,            ['endmonth']],
  'endyear'         =>  [\&_sort_literal,       ['endyear']],
  'entrykey'        =>  [\&_sort_entrykey,      []],
  'eventday'        =>  [\&_sort_dm,            ['eventday']],
  'eventendday'     =>  [\&_sort_dm,            ['eventendday']],
  'eventendmonth'   =>  [\&_sort_dm,            ['eventendmonth']],
  'eventendyear'    =>  [\&_sort_literal,       ['eventendyear']],
  'eventmonth'      =>  [\&_sort_dm,            ['eventmonth']],
  'eventtitle'      =>  [\&_sort_literaln,      ['eventtitle']],
  'eventyear'       =>  [\&_sort_literal,       ['eventyear']],
  'foreword'        =>  [\&_sort_name,          ['foreword']],
  'holder'          =>  [\&_sort_name,          ['holder']],
  'issue'           =>  [\&_sort_literal,       ['issue']],
  'issuesubtitle'   =>  [\&_sort_literaln,      ['issuesubtitle']],
  'issuetitle'      =>  [\&_sort_literaln,      ['issuetitle']],
  'institution'     =>  [\&_sort_list,          ['institution']],
  'introduction'    =>  [\&_sort_name,          ['introduction']],
  'journalsubtitle' =>  [\&_sort_literaln,      ['journalsubtitle']],
  'journaltitle'    =>  [\&_sort_literaln,      ['journaltitle']],
  'labelalpha'      =>  [\&_sort_literal,       ['sortlabelalpha']],
  'labelname'       =>  [\&_sort_labelname,     []],
  'labelyear'       =>  [\&_sort_labelyear,     []],
  'language'        =>  [\&_sort_list,          ['language']],
  'library'         =>  [\&_sort_literal,       ['library']],
  'lista'           =>  [\&_sort_list,          ['lista']],
  'listb'           =>  [\&_sort_list,          ['listb']],
  'listc'           =>  [\&_sort_list,          ['listc']],
  'listd'           =>  [\&_sort_list,          ['listd']],
  'liste'           =>  [\&_sort_list,          ['liste']],
  'listf'           =>  [\&_sort_list,          ['listf']],
  'location'        =>  [\&_sort_list,          ['location']],
  'mainsubtitle'    =>  [\&_sort_literaln,      ['mainsubtitle']],
  'maintitle'       =>  [\&_sort_literaln,      ['maintitle']],
  'maintitleaddon'  =>  [\&_sort_literaln,      ['maintitleaddon']],
  'month'           =>  [\&_sort_dm,            ['month']],
  'namea'           =>  [\&_sort_name,          ['namea']],
  'nameb'           =>  [\&_sort_name,          ['nameb']],
  'namec'           =>  [\&_sort_name,          ['namec']],
  'note'            =>  [\&_sort_literal,       ['note']],
  'number'          =>  [\&_sort_literal,       ['number']],
  'origday'         =>  [\&_sort_dm,            ['origday']],
  'origendday'      =>  [\&_sort_dm,            ['origendday']],
  'origendmonth'    =>  [\&_sort_dm,            ['origendmonth']],
  'origendyear'     =>  [\&_sort_literal,       ['origendyear']],
  'origlocation'    =>  [\&_sort_list,          ['origlocation']],
  'origmonth'       =>  [\&_sort_dm,            ['origmonth']],
  'origpublisher'   =>  [\&_sort_list,          ['origpublisher']],
  'origtitle'       =>  [\&_sort_literaln,      ['origtitle']],
  'origyear'        =>  [\&_sort_literal,       ['origyear']],
  'organization'    =>  [\&_sort_list,          ['organization']],
  'part'            =>  [\&_sort_literal,       ['part']],
  'presort'         =>  [\&_sort_presort,       []],
  'publisher'       =>  [\&_sort_list,          ['publisher']],
  'pubstate'        =>  [\&_sort_literal,       ['pubstate']],
  'school'          =>  [\&_sort_list,          ['school']],
  'series'          =>  [\&_sort_literal,       ['series']],
  'shortauthor'     =>  [\&_sort_literaln,      ['shortauthor']],
  'shorteditor'     =>  [\&_sort_literaln,      ['shorteditor']],
  'shorthand'       =>  [\&_sort_literal,       ['shorthand']],
  'shortjournal'    =>  [\&_sort_literaln,      ['shortjournal']],
  'shortseries'     =>  [\&_sort_literaln,      ['shortseries']],
  'shorttitle'      =>  [\&_sort_literaln,      ['shorttitle']],
  'sortkey'         =>  [\&_sort_literal,       ['sortkey']],
  'sortname'        =>  [\&_sort_sortname,      []],
  'sortshorthand'   =>  [\&_sort_literal,       ['sortshorthand']],
  'sorttitle'       =>  [\&_sort_literaln,      ['sorttitle']],
  'sortyear'        =>  [\&_sort_literal,       ['sortyear']],
  'subtitle'        =>  [\&_sort_literaln,      ['subtitle']],
  'title'           =>  [\&_sort_literaln,      ['title']],
  'titleaddon'      =>  [\&_sort_literaln,      ['titleaddon']],
  'translator'      =>  [\&_sort_name,          ['translator']],
  'type'            =>  [\&_sort_literal,       ['type']],
  'urlday'          =>  [\&_sort_dm,            ['urlday']],
  'urlendday'       =>  [\&_sort_dm,            ['urlendday']],
  'urlendmonth'     =>  [\&_sort_dm,            ['urlendmonth']],
  'urlendyear'      =>  [\&_sort_literal,       ['urlendyear']],
  'urlmonth'        =>  [\&_sort_dm,            ['urlmonth']],
  'urlyear'         =>  [\&_sort_literal,       ['urlyear']],
  'usera'           =>  [\&_sort_literal,       ['usera']],
  'userb'           =>  [\&_sort_literal,       ['userb']],
  'userc'           =>  [\&_sort_literal,       ['userc']],
  'userd'           =>  [\&_sort_literal,       ['userd']],
  'usere'           =>  [\&_sort_literal,       ['usere']],
  'userf'           =>  [\&_sort_literal,       ['userf']],
  'venue'           =>  [\&_sort_literal,       ['venue']],
  'verba'           =>  [\&_sort_literal,       ['verba']],
  'verbb'           =>  [\&_sort_literal,       ['verbb']],
  'verbc'           =>  [\&_sort_literal,       ['verbc']],
  'version'         =>  [\&_sort_literal,       ['version']],
  'volume'          =>  [\&_sort_literal,       ['volume']],
  'year'            =>  [\&_sort_literal,       ['year']],
  };

# Main sorting dispatch method
sub _dispatch_sorting {
  my ($self, $sortfield, $citekey, $sortelementattributes) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $code_ref;
  my $code_args_ref;

  # If this field is excluded from sorting for this entrytype, then skip it and return
  if (my $se = Biber::Config->getblxoption('sortexclusion', $be->get_field('entrytype'))) {
    if ($se->{$sortfield}) {
      return '';
    }
  }

  # if the field is not found in the dispatch table, assume it's a literal string
  unless (exists($dispatch_sorting->{$sortfield})) {
    $code_ref = \&_sort_string;
    $code_args_ref = [$sortfield];
  }
  else { # real sorting field
    $code_ref = ${$dispatch_sorting->{$sortfield}}[0];
    $code_args_ref  = ${$dispatch_sorting->{$sortfield}}[1];
  }
  return &{$code_ref}($self, $citekey, $sortelementattributes, $code_args_ref);
}

# Conjunctive set of sorting sets
sub _generatesortinfo {
  my ($self, $citekey, $list, $sortscheme) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $sortobj;
  $BIBER_SORT_FINAL = 0;
  $BIBER_SORT_FINAL = '';
  foreach my $sortset (@{$sortscheme}) {
    my $s = $self->_sortset($sortset, $citekey);
    # We have already found a "final" item so if this item returns null,
    # copy in the "final" item string as it's the master key for this entry now
    if ($BIBER_SORT_FINAL and not $BIBER_SORT_NULL) {
      push @$sortobj, $BIBER_SORT_FINAL;
    }
    else {
      push @$sortobj, $s;
    }
  }

  # Record the information needed for sorting later
  # sortstring isn't actually used to sort, it's used to generate sortinit and
  # for debugging purposes
  my $ss = join($sorting_sep, @$sortobj);
  $list->set_sortdata($citekey, [$ss, $sortobj]);

  # Generate sortinit - the initial letter of the sortstring. Skip
  # if there is no sortstring, which is possible in tests
  if ($ss) {
  # This must ignore the presort characters, naturally
    my $pre = Biber::Config->getblxoption('presort', $be->get_field('entrytype'), $citekey);

    # Strip off the prefix
    $ss =~ s/\A$pre$sorting_sep+//;
    my $init = substr normalise_string($ss), 0, 1;

    # Now check if this sortinit is valid in the bblencoding. If not, warn
    # and replace with a suitable value
    my $bblenc = Biber::Config->getoption('bblencoding');
    if ($bblenc ne 'UTF-8') {
      # Can this init be represented in the BBL encoding?
      if (encode($bblenc, $init) eq '?') { # Malformed data encoding char
        # So convert to macro
        my $initd = Biber::LaTeX::Recode::latex_encode($init);
        # Don't warn if output is ascii as it's fairly pointless since this warning may be
        # true of a lot of data and drawing attention to just sortinit might be confusing
        unless ($bblenc =~ /(?:x-)?ascii/xmsi) {
          biber_warn("The character '$init' cannot be encoded in '$bblenc'. sortinit will be set to macro '$initd' for entry '$citekey'", $be);
        }
        $init = $initd;
      }
    }
    $list->set_sortinitdata_for_key($citekey, $init);
  }
  return;
}

# Process sorting set
sub _sortset {
  my ($self, $sortset, $citekey) = @_;
  foreach my $sortelement (@$sortset[1..$#$sortset]) {
    my ($sortelementname, $sortelementattributes) = %$sortelement;
    $BIBER_SORT_NULL = 0; # reset this per sortset
    my $string = $self->_dispatch_sorting($sortelementname, $citekey, $sortelementattributes);
    if ($string) { # sort returns something for this key
      if ($sortset->[0]{final}) {
        # If we encounter a "final" element, we return an empty sort
        # string and save the string so it can be copied into all further
        # fields as this is now the master sort key. We use an empty string
        # where we found it in order to preserve sort field order and so
        # that we sort correctly against all other entries without a value
        # for this "final" field
        $BIBER_SORT_FINAL = $string;
        last;
      }
      return $string;
    }
  }
  $BIBER_SORT_NULL = 1; # set null flag - need this to deal with some cases
  return '';
}

##############################################
# Sort dispatch routines
##############################################

sub _sort_citeorder {
  my ($self, $citekey, $sortelementattributes) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  # Pad the numbers so that they sort with "cmp" properly. Assume here max of
  # a million bib entries. Probably enough ...
  return sprintf('%.7d', (first_index {$_ eq $citekey} $section->get_orig_order_citekeys) + 1);
}

# This is a meta-sub which uses the optional arguments to the dispatch code
# It's done to avoid having many repetitions of almost identical sorting code
# for the many date sorting options
# It deals with day and month fields
sub _sort_dm {
  my ($self, $citekey, $sortelementattributes, $args) = @_;
  my $dmtype = $args->[0]; # get day/month field type
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  if (my $field = $be->get_field($dmtype)) {
    return _process_sort_attributes($field, $sortelementattributes);
  }
  else {
    return '';
  }
}

# This is a meta-sub which uses the optional arguments to the dispatch code
# It's done to avoid having many repetitions of almost identical sorting code
# for the editor type/class roles
sub _sort_editortc {
  my ($self, $citekey, $sortelementattributes, $args) = @_;
  my $edtypeclass = $args->[0]; # get editor type/class field
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  if (Biber::Config->getblxoption('useeditor', $be->get_field('entrytype'), $citekey) and
    $be->get_field($edtypeclass)) {
    my $string = $be->get_field($edtypeclass);
    return _process_sort_attributes($string, $sortelementattributes);
  }
  else {
    return '';
  }
}

# debug sorting
sub _sort_entrykey {
  my ($self, $citekey, $sortelementattributes) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  return $citekey;
}

sub _sort_labelname {
  my ($self, $citekey, $sortelementattributes, $args) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  # re-direct to the right sorting routine for the labelname
  if (my $ln = $be->get_field('labelnamename')) {
    # Don't process attributes as they will be processed in the real sub
    return $self->_dispatch_sorting($ln, $citekey, $sortelementattributes);
  }
  else {
    return '';
  }
}

sub _sort_labelyear {
  my ($self, $citekey, $sortelementattributes, $args) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  # re-direct to the right sorting routine for the labelyear
  if (my $ly = $be->get_field('labelyearname')) {
    # Don't process attributes as they will be processed in the real sub
    return $self->_dispatch_sorting($ly, $citekey, $sortelementattributes);
  }
  else {
    return '';
  }
}

# This is a meta-sub which uses the optional arguments to the dispatch code
# It's done to avoid having many repetitions of almost identical sorting code
sub _sort_list {
  my ($self, $citekey, $sortelementattributes, $args) = @_;
  my $list = $args->[0]; # get list field
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  if ($be->get_field($list)) {
    my $string = $self->_liststring($citekey, $list);
    return _process_sort_attributes($string, $sortelementattributes);
  }
  else {
    return '';
  }
}

# This is a meta-sub which uses the optional arguments to the dispatch code
# It's done to avoid having many repetitions of almost identical sorting code
# for literal strings which need no normalising
sub _sort_literal {
  my ($self, $citekey, $sortelementattributes, $args) = @_;
  my $literal = $args->[0]; # get actual field
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $string = $be->get_field($literal) // '';
  return _process_sort_attributes($string, $sortelementattributes);
}

# This is a meta-sub which uses the optional arguments to the dispatch code
# It's done to avoid having many repetitions of almost identical sorting code
# for literal strings which need normalising
sub _sort_literaln {
  my ($self, $citekey, $sortelementattributes, $args) = @_;
  my $literal = $args->[0]; # get actual field
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  if (my $field = $be->get_field($literal)) {
    my $string = normalise_string_sort($field, $literal);
    return _process_sort_attributes($string, $sortelementattributes);
  }
  else {
    return '';
  }
}

# This is a meta-sub which uses the optional arguments to the dispatch code
# It's done to avoid having many repetitions of almost identical sorting code
# for the editor roles
sub _sort_name {
  my ($self, $citekey, $sortelementattributes, $args) = @_;
  my $name = $args->[0]; # get name field name
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  # If there is a biblatex option which controls the use of this name, check it
  if ($CONFIG_SCOPE_BIBLATEX{"use$name"} and
      not Biber::Config->getblxoption("use$name", $be->get_field('entrytype'), $citekey)) {
    return '';
    }
  if ($be->get_field($name)) {
    my $string = $self->_namestring($citekey, $name);
    return _process_sort_attributes($string, $sortelementattributes);
  }
  else {
    return '';
  }
}

sub _sort_presort {
  my ($self, $citekey, $sortelementattributes) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $string = Biber::Config->getblxoption('presort', $be->get_field('entrytype'), $citekey);
  return _process_sort_attributes($string, $sortelementattributes);
}

sub _sort_sortname {
  my ($self, $citekey, $sortelementattributes) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);

  # see biblatex manual §3.4 - sortname is ignored if no use<name> option is defined
  if ($be->get_field('sortname') and
    (Biber::Config->getblxoption('useauthor', $be->get_field('entrytype'), $citekey) or
      Biber::Config->getblxoption('useeditor', $be->get_field('entrytype'), $citekey) or
      Biber::Config->getblxoption('useetranslator', $be->get_field('entrytype'), $citekey))) {
    my $string = $self->_namestring($citekey, 'sortname');
    return _process_sort_attributes($string, $sortelementattributes);
  }
  else {
    return '';
  }
}

sub _sort_string {
  my ($self, $citekey, $sortelementattributes, $args) = @_;
  my $string = $args->[0]; # get literal string
  return _process_sort_attributes($string, $sortelementattributes);
}

#========================================================
# Utility subs used elsewhere but relying on sorting code
#========================================================

sub _process_sort_attributes {
  my ($field_string, $sortelementattributes) = @_;
  return $field_string unless $sortelementattributes;
  return $field_string unless $field_string;
  # process substring
  if ($sortelementattributes->{substring_width} or
      $sortelementattributes->{substring_side}) {
    my $subs_offset = 0;
    my $default_substring_width = 4;
    my $default_substring_side = 'left';
    my $subs_width = ($sortelementattributes->{substring_width} or $default_substring_width);
    my $subs_side = ($sortelementattributes->{substring_side} or $default_substring_side);
    if ($subs_side eq 'right') {
      $subs_offset = 0 - $subs_width;
    }
    $field_string = substr( $field_string, $subs_offset, $subs_width );
  }
  # Process padding
  if ($sortelementattributes->{pad_side} or
      $sortelementattributes->{pad_width} or
      $sortelementattributes->{pad_char}) {
    my $default_pad_width = 4;
    my $default_pad_side = 'left';
    my $default_pad_char = '0';
    my $pad_width = ($sortelementattributes->{pad_width} or $default_pad_width);
    my $pad_side = ($sortelementattributes->{pad_side} or $default_pad_side);
    my $pad_char = ($sortelementattributes->{pad_char} or $default_pad_char);
    my $pad_length = $pad_width - length($field_string);
    if ($pad_side eq 'left') {
      $field_string = ($pad_char x $pad_length) . $field_string;
    }
    elsif ($pad_side eq 'right') {
      $field_string = $field_string . ($pad_char x $pad_length);
    }
  }
  return $field_string;
}

# This is used to generate sorting strings for names
sub _namestring {
  my $self = shift;
  my ($citekey, $field) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');
  my $names = $be->get_field($field);
  my $str = '';
  my $count = $names->count_names;
  my $visible = $names->get_visible_bib; # get visibility for bib - can be different to cite

  # These should be symbols which can't appear in names
  # This means, symbols which normalise_string_sort strips out
  my $nsi    = '_';          # name separator, internal
  my $nse    = '+';          # name separator, external
  # Guaranteed to sort after everything else as it's the last legal Unicode code point
  my $trunc = "\x{10FFFD}";  # sort string for "et al" truncated name

  # We strip nosort first otherwise normalise_string_sort damages diacritics
  # We strip each individual component instead of the whole thing so we can use
  # as name separators things which would otherwise be stripped. This way we
  # guarantee that the separators are never in names
  foreach my $n (@{$names->first_n_names($visible)}) {
    # If useprefix is true, use prefix at start of name for sorting
    if ( $n->get_prefix and
         Biber::Config->getblxoption('useprefix', $bee, $citekey ) ) {
      $str .= normalise_string_sort($n->get_prefix, $field) . $nsi;
    }
    # Append last name
    $str .= normalise_string_sort($n->get_lastname, $field) . $nsi;

    # Append last name
    $str .= normalise_string_sort($n->get_firstname, $field) . $nsi if $n->get_firstname;

    # Append suffix
    $str .= normalise_string_sort($n->get_suffix, $field) . $nsi if $n->get_suffix;

    # If useprefix is false, use prefix at end of name
    if ( $n->get_prefix and not
         Biber::Config->getblxoption('useprefix', $be->get_field('entrytype'), $citekey ) ) {
      $str .= normalise_string_sort($n->get_prefix, $field) . $nsi;
    }

    $str =~ s/\Q$nsi\E\z//xms;       # Remove any trailing internal separator
    $str .= $nse;                    # Add separator in between names
  }

  $str =~ s/\s+\Q$nse\E/$nse/gxms;   # Remove any whitespace before external separator
  $str =~ s/\Q$nse\E\z//xms;         # strip final external separator as we are finished

  $str .= $trunc if $visible < $count; # name list was truncated
  return $str;
}

sub _liststring {
  my ( $self, $citekey, $field ) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');
  my $f = $be->get_field($field); # _liststring is used in tests so there has to be
  return '' unless defined($f);   # more error checking which will never be needed in normal use
  my @items = @$f;
  my $str = '';
  my $truncated = 0;

  # These should be symbols which can't appear in lists
  # This means, symbols which normalise_string_sort strips out
  my $lsi    = '_';          # list separator, internal
  # Guaranteed to sort after everything else as it's the last legal Unicode code point
  my $trunc = "\x{10FFFD}";  # sort string for truncated list

  # perform truncation according to options minitems, maxitems
  if ( $#items + 1 > Biber::Config->getblxoption('maxitems', $bee, $citekey) ) {
    $truncated = 1;
    @items = splice(@items, 0, Biber::Config->getblxoption('minitems', $bee, $citekey) );
  }

  # separate the items by a string to give some structure
  $str = join($lsi, map { normalise_string_sort($_, $field)} @items);

  $str =~ s/\s+\z//xms;
  $str .= $trunc if $truncated;
  return $str;
}

=head2 process_entry_options

    Set per-entry options

=cut

sub process_entry_options {
  my $self = shift;
  my $citekey = shift;
  my $options = shift;
  return unless $options;       # Just in case it's null
  my @entryoptions = split /\s*,\s*/, $options;
  foreach (@entryoptions) {
    m/^([^=]+)(=?)(.+)?$/;
    my $val;
    if ($2) {
      given ($3) {
        when ('true') {
          $val = 1;
        }
        when ('false') {
          $val = 0;
        }
        default {
          $val = $3;
        }
      }
      _expand_option($1, $val, $citekey);
    }
    else {
      _expand_option($1, 1, $citekey);
    }
  }
  return;
}

sub _expand_option {
  my ($opt, $val, $citekey) = @_;
  if(my $map = $CONFIG_BIBLATEX_PER_ENTRY_OPTIONS{lc($opt)}{INPUT}) {
    foreach my $m (@$map) {
      Biber::Config->setblxoption($m, $val, 'PER_ENTRY', $citekey);
    }
  }
  else {
    Biber::Config->setblxoption($opt, $val, 'PER_ENTRY', $citekey);
  }
  return;
}

1;

__END__

=head1 AUTHOR

François Charette, C<< <firmicus at ankabut.net> >>
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
