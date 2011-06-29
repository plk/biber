package Biber::Internals;
use feature ':5.10';
#use feature 'unicode_strings';

use strict;
use warnings;
use Carp;
use Biber::Constants;
use Biber::Utils;
use Data::Compare;
use Text::Wrap;
$Text::Wrap::columns = 80;
use Storable qw( dclone );
use List::AllUtils qw( :all );
use Log::Log4perl qw(:no_extra_logdie_message);
use Digest::MD5 qw( md5_hex );
use POSIX qw( locale_h ); # for lc()
use Encode;
use charnames ':full';
use Unicode::Normalize;
use utf8;

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
  my $maxn = Biber::Config->getblxoption('maxnames');
  my $minn = Biber::Config->getblxoption('minnames');
  my $truncated = 0;
  my $truncnames = dclone($names);

  # Since namehash is the hash of the visible name,
  # perform truncation according to options minnames, maxnames
  my $ul;
  if (defined($names->get_uniquelist)) {
    $ul = $names->get_uniquelist;
  }

  # If name list was truncated in bib with "and others", this overrides maxnames
  my $morenames = ($names->last_element->get_namestring eq 'others') ? 1 : 0;
  if ( $morenames or $names->count_elements > $maxn ) {

    # truncate to the uniquelist point if uniquelist is requested
    if ($ul) {
      $truncnames = $truncnames->first_n_elements($ul);
      # Since uniquelist can be larger than maxnames, it's only truncated
      # if uniquelist is shorter than the full name list
      $truncated = 1 if $ul < $names->count_elements;
    }
    # otherwise truncate to minnames
    else {
      $truncnames = $truncnames->first_n_elements($minn);
      $truncated = 1;
    }
  }

  # namehash obeys list truncations but not uniquename
  foreach my $n (@{$truncnames->names}) {
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

  $hashkey .= '+' if $truncated;

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
  my $maxn = Biber::Config->getblxoption('maxnames');
  my $minn = Biber::Config->getblxoption('minnames');
  my $truncated = 0;
  my $truncnames = dclone($names);

  # Since namehash is the hash of the visible name,
  # perform truncation according to options minnames, maxnames
  my $ul;
  if (defined($names->get_uniquelist)) {
    $ul = $names->get_uniquelist;
  }

  # If name list was truncated in bib with "and others", this overrides maxnames
  my $morenames = ($names->last_element->get_namestring eq 'others') ? 1 : 0;
  if ( $morenames or $names->count_elements > $maxn ) {

    # truncate to the uniquelist point if uniquelist is requested
    if ($ul) {
      $truncnames = $truncnames->first_n_elements($ul);
      # Since uniquelist can be larger than maxnames, it's only truncated
      # if uniquelist is shorter than the full name list
      $truncated = 1 if $ul < $names->count_elements;
    }
    # otherwise truncate to minnames
    else {
      $truncnames = $truncnames->first_n_elements($minn);
      $truncated = 1;
    }
  }

  # namehash obeys list truncations but not uniquename
  foreach my $n (@{$truncnames->names}) {
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

  $hashkey .= '+' if $truncated;

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

  # Digest::MD5 can't deal with straight UTF8 so encode it first
  return md5_hex(encode_utf8($hashkey));
}


# Default (labelalpha = 1) label generation
sub _genlabel {
  my ($self, $citekey, $namefield) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $names = $be->get_field($namefield);
  my $alphaothers = Biber::Config->getblxoption('alphaothers', $be->get_field('entrytype'));
  my $sortalphaothers = Biber::Config->getblxoption('sortalphaothers', $be->get_field('entrytype'));
  my $useprefix = Biber::Config->getblxoption('useprefix', $be->get_field('entrytype'), $citekey);
  my $maxnames = Biber::Config->getblxoption('maxalphanames');
  my $minnames = Biber::Config->getblxoption('minalphanames');
  my $label = '';
  # This contains sortalphaothers instead of alphaothers, if defined
  # This is needed in cases where alphaothers is something like
  # '\textasteriskcentered' which would mess up sorting.
  my $sortlabel = '';

  my @lastnames = map { strip_nosort(normalise_string($_->get_lastname), $namefield) } @{$names->names};
  my @prefices  = map { $_->get_prefix } @{$names->names};
  my $numnames  = $names->count_elements;

  # If name list was truncated in bib with "and others", this overrides maxnames
  my $morenames = ($names->last_element->get_namestring eq 'others') ? 1 : 0;
  my $nametrunc;
  my $loopnames;

  # loopnames is the number of names to loop over in the name list when constructing the label
  if ($morenames or ($numnames > $maxnames)) {
    $nametrunc = 1;
    $loopnames = $minnames; # Only look at $minnames names if we are truncating ...
  } else {
    $loopnames = $numnames; # ... otherwise look at all names
  }

  # Now loop over the name list, grabbing a substring of each surname
  # The substring length depends on whether we are using prefices and also whether
  # we have truncated to one name:
  #   1. If there is only one name
  #      1. label string is first 3 chars of surname if there is no prefix
  #      2. label string is first char of prefix plus first 2 chars of surname if there is a prefix
  #   2. If there is more than one name
  #      1.  label string is first char of each surname (up to minnames) if there is no prefix
  #      2.  label string is first char of prefix plus first char of each surname (up to minnames)
  #          if there is a prefix
  for (my $i=0; $i<$loopnames; $i++) {
    $label .= substr($prefices[$i] , 0, 1) if ($useprefix and $prefices[$i]);
    $label .= substr($lastnames[$i], 0, $loopnames == 1 ? (($useprefix and $prefices[$i]) ? 2 : 3) : 1);
  }

  $sortlabel = $label;

  # Add alphaothers if name list is truncated
  if ($nametrunc) {
    $label .= $alphaothers;
    $sortlabel .= $sortalphaothers;
  }

  return [$label, $sortlabel];
}

#########################
# custom label generation (labelalpha = 2)
#########################

our $dispatch_label = {
  'afterword'         =>  [\&_label_name,             ['afterword']],
  'annotator'         =>  [\&_label_name,             ['annotator']],
  'author'            =>  [\&_label_name,             ['author']],
  'autoinc'           =>  [\&_label_autoinc,          []],
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
  'extrayear'         =>  [\&_label_extrayear,        []],
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
sub _genlabel_custom {
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
  my $struc = Biber::Config->get_structure;
  my $maxnames = Biber::Config->getblxoption('maxalphanames');
  my $minnames = Biber::Config->getblxoption('minalphanames');
  my $lp;
  my $slp;

  foreach my $part (@$labelpart) {
    # Deal with various tests
    # iflistcount only uses this label template part if the list it is applied to is a certain
    # length
    if (my $ic = $part->{ifnamecount}) {
      my $f = $part->{content};
      if (first {$_ eq $f} @{$struc->get_field_type('name')} or
          $f eq 'labelname') {
        my $name = $be->get_field($f) || next; # just in case there is no labelname etc.
        my $total_names = $name->count_elements;

        # Allow for explicit "and others" for purposes of labels,
        # this is length one less because "and others" is handled by
        # alphaothers. Otherwise for "John Doe and others" you get
        # "D+" instead of "Doe+" etc.
        if ($name->last_element->get_namestring eq 'others') {
          $total_names--;
        }

        my $visible_names;
        if ($total_names > $maxnames) {
          $visible_names = $minnames;
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

sub _label_autoinc {
  my ($self, $citekey, $args, $labelattrs) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $format = $labelattrs->{format} || 'alpha';
  # This can't and shouldn't be generated here, it's done later during list construction
  if ($format eq 'alpha') {
    return ['<BDS>LAAUTOA</BDS>', '<BDS>LAAUTOA</BDS>'];
  }
  elsif ($format eq 'int') {
    return ['<BDS>LAAUTOI</BDS>', '<BDS>LAAUTOI</BDS>'];
  }
  else {
    return ['', ''];
  }
}

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

sub _label_extrayear {
  my ($self, $citekey, $args, $labelattrs) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $format = $labelattrs->{format} || 'alpha';
  if (Biber::Config->getblxoption('labelyear', $be->get_field('entrytype'))) {
    # This can't and shouldn't be generated here, it's done later during list construction
    if ($format eq 'alpha') {
      return ['<BDS>LAEXTRAYEARA</BDS>', '<BDS>LAEXTRAYEARA</BDS>'];
    }
    elsif ($format eq 'int') {
      return ['<BDS>LAEXTRAYEARI</BDS>', '<BDS>LAEXTRAYEARI</BDS>'];
    }
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

sub _label_literal {
  my ($self, $citekey, $args, $labelattrs) = @_;
  my $string = $args->[0]; # get literal string
  my $ps = _process_label_attributes($self, $citekey, $string, $labelattrs);
  return [$ps, $ps];
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
  my $maxnames = Biber::Config->getblxoption('maxalphanames');
  my $minnames = Biber::Config->getblxoption('minalphanames');
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
    my $numnames  = $names->count_elements;
    my @lastnames = map { strip_nosort(normalise_string($_->get_lastname), $namename) } @{$names->names};
    my @prefices  = map { $_->get_prefix } @{$names->names};

    # If name list was truncated in bib with "and others", this overrides maxnames
    my $morenames = ($names->last_element->get_namestring eq 'others') ? 1 : 0;
    my $nametrunc;
    my $loopnames;

    # loopnames is the number of names to loop over in the name list when constructing the label
    if (my $lc = $labelattrs->{namecount}) {
      if ($lc > $numnames) { # cap at numnames, of course
        $lc = $numnames;
      }
      $loopnames = $lc; # Only look as many names as specified
    }
    elsif ($morenames or ($numnames > $maxnames)) {
      $loopnames = $minnames; # Only look at $minnames names if no uniquelist set
      $nametrunc = 1;
    }
    else {
      $loopnames = $numnames; # ... otherwise look at all names
    }

    for (my $i=0; $i<$loopnames; $i++) {
      $acc .= substr($prefices[$i] , 0, 1) if ($useprefix and $prefices[$i]);
      $acc .= _process_label_attributes($self, $citekey, $lastnames[$i], $labelattrs, $namename, 'lastname');
    }

    $sortacc = $acc;

    # Add alphaothers if name list is truncated
    if ($nametrunc) {
      $acc .= $alphaothers;
      $sortacc .= $sortalphaothers;
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
sub _process_label_attributes {
  my ($self, $citekey, $field_string, $labelattrs, $field, $namepart) = @_;
  return $field_string unless $labelattrs;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);

  if ($labelattrs->{substring_width}) {
    # dynamically disambiguated width (individual name disambiguation)
    if ($labelattrs->{substring_width} =~ /n/ and $field) {
      # Use the cache if there is one
      if (my $lcache = $section->get_labelcache($field)) {
        $logger->debug("Using label disambiguation cache (name) for '$field' in section $secnum");
        # Use the global index override if set (substring_width =~ /f/)
        $field_string = ${$lcache->{$field_string}{data}}[$lcache->{globalindex} || $lcache->{$field_string}{index}];
      }
      else {
        # This contains a mapping of strings to substrings of increasing lengths
        my %substr_cache = ();
        my $lcache = {};
        # This ends up as a flat list due to array interpolation
        my @strings = uniq map {my $f = $section->bibentry($_)->get_field($field);
                           $namepart ? map {$_->get_namepart($namepart)} @{$f->names} : $f
                          } $section->get_citekeys;
        # Look to the index of the longest string or the explicit max width if set
        my $maxlen = $labelattrs->{substring_width_max} || max map {length($_)} @strings;
        my $minlen = 1;
        for (my $i = $minlen; $i <= $maxlen; $i++) {
          foreach my $map (map { my $s = substr($_, 0, $i); $substr_cache{$s}++; [$_, $s] } @strings) {
            # We construct a list of all substrings, up to the length of the longest string
            # or substring_width_max. Then we save the index of the list element which is
            # the minimal disambiguation if it's not yet defined
            push @{$lcache->{$map->[0]}{data}}, $map->[1];
            if (not $lcache->{$map->[0]}{index} and
                ($substr_cache{$map->[1]} < 2 or $i == $maxlen)) {
              # -1 to make it into a clean array index
              $lcache->{$map->[0]}{index} = length($map->[1]) - 1;
            }
          }
        }

        # We want to use a string width for all strings equal to the longest one needed
        # to disambiguate this list. We do this by saving an override for the minimal
        # disambiguation length
        if ($labelattrs->{substring_width} =~ /f/) {
          # Get the uniqueness indices of all of the strings and strip out those
          # which don't occur at least substring_fixed_threshold times
          my %is;
          foreach my $i (values %$lcache) {
            $is{$i->{index}}++;
          }
          $lcache->{globalindex} = max grep {$is{$_} >= $labelattrs->{substring_fixed_threshold}} keys %is;
        }

        # Use the global index override if set (substring_width =~ /f/)
        $field_string = ${$lcache->{$field_string}{data}}[$lcache->{globalindex} || $lcache->{$field_string}{index}];
        $logger->debug("Creating label disambiguation cache for '$field' " .
                       ($namepart ? "($namepart) " : '') .
                       "in section $secnum");
        $logger->trace("Label disambiguation cache for '$field' " .
                       ($namepart ? "($namepart) " : '') .
                       "in section $secnum:\n " . Data::Dump::pp($lcache));
        $section->set_labelcache($field, $lcache);
      }
    }
    # dynamically disambiguated width (list disambiguation)
    elsif ($labelattrs->{substring_width} =~ /l/ and $field) {
      # my $f = $section->bibentry($citekey)->get_field($field);
      # my $in = $namepart ? [map {$_->get_namepart($namepart)} @{$f->names}] : [$f];
      # # Use the cache if there is one
      # if (my $lcache = $section->get_labelcache($field)) {
      #   $logger->debug("Using label disambiguation cache (list) for '$field' in section $secnum");
      #   # Use the global index override if set (substring_width =~ /f/)
      #   $field_string = ${$lcache->{$field_string}{data}}[$lcache->{globalindex} || $lcache->{$field_string}{index}];
      # }
      # else {
      #   # This contains a mapping of strings to substrings of increasing lengths
      #   my %substr_cache = ();
      #   my $lcache = {};
      #   # This retains the structure of the entries for the "l" list disambiguation
      #   my @strings = map {my $f = $section->bibentry($_)->get_field($field);
      #                      $namepart ? [map {$_->get_namepart($namepart)} @{$f->names}] : [$f]
      #                     } $section->get_citekeys;
        


      # }
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
      $field_string = substr( $field_string, $subs_offset, $subs_width );
    }
  }
  return $field_string;
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
  'address'         =>  [\&_sort_place,         ['place']],
  'author'          =>  [\&_sort_author,        []],
  'booksubtitle'    =>  [\&_sort_title,         ['booksubtitle']],
  'booktitle'       =>  [\&_sort_title,         ['booktitle']],
  'booktitleaddon'  =>  [\&_sort_title,         ['booktitleaddon']],
  'citeorder'       =>  [\&_sort_citeorder,     []],
  'day'             =>  [\&_sort_dm,            ['day']],
  'editor'          =>  [\&_sort_editor,        ['editor']],
  'editora'         =>  [\&_sort_editor,        ['editora']],
  'editoratype'     =>  [\&_sort_editortc,      ['editoratype']],
  'editorb'         =>  [\&_sort_editor,        ['editorb']],
  'editorbtype'     =>  [\&_sort_editortc,      ['editorbtype']],
  'editorc'         =>  [\&_sort_editor,        ['editorc']],
  'editorctype'     =>  [\&_sort_editortc,      ['editorctype']],
  'endday'          =>  [\&_sort_dm,            ['endday']],
  'endmonth'        =>  [\&_sort_dm,            ['endmonth']],
  'endyear'         =>  [\&_sort_year,          ['endyear']],
  'entrykey'        =>  [\&_sort_entrykey,      []],
  'eventday'        =>  [\&_sort_dm,            ['eventday']],
  'eventendday'     =>  [\&_sort_dm,            ['eventendday']],
  'eventendmonth'   =>  [\&_sort_dm,            ['eventendmonth']],
  'eventendyear'    =>  [\&_sort_year,          ['eventendyear']],
  'eventmonth'      =>  [\&_sort_dm,            ['eventmonth']],
  'eventtitle'      =>  [\&_sort_title,         ['eventtitle']],
  'eventyear'       =>  [\&_sort_year,          ['eventyear']],
  'issuesubtitle'   =>  [\&_sort_title,         ['issuesubtitle']],
  'issuetitle'      =>  [\&_sort_title,         ['issuetitle']],
  'institution'     =>  [\&_sort_place,         ['institution']],
  'journalsubtitle' =>  [\&_sort_title,         ['journalsubtitle']],
  'journaltitle'    =>  [\&_sort_title,         ['journaltitle']],
  'labelalpha'      =>  [\&_sort_labelalpha,    []],
  'labelname'       =>  [\&_sort_labelname,     []],
  'labelyear'       =>  [\&_sort_labelyear,     []],
  'location'        =>  [\&_sort_place,         ['location']],
  'mainsubtitle'    =>  [\&_sort_title,         ['mainsubtitle']],
  'maintitle'       =>  [\&_sort_title,         ['maintitle']],
  'maintitleaddon'  =>  [\&_sort_title,         ['maintitleaddon']],
  'month'           =>  [\&_sort_dm,            ['month']],
  'origday'         =>  [\&_sort_dm,            ['origday']],
  'origendday'      =>  [\&_sort_dm,            ['origendday']],
  'origendmonth'    =>  [\&_sort_dm,            ['origendmonth']],
  'origendyear'     =>  [\&_sort_year,          ['origendyear']],
  'origmonth'       =>  [\&_sort_dm,            ['origmonth']],
  'origtitle'       =>  [\&_sort_title,         ['origtitle']],
  'origyear'        =>  [\&_sort_year,          ['origyear']],
  'organization'    =>  [\&_sort_place,         ['organization']],
  'presort'         =>  [\&_sort_presort,       []],
  'publisher'       =>  [\&_sort_publisher,     []],
  'pubstate'        =>  [\&_sort_pubstate,      []],
  'school'          =>  [\&_sort_place,         ['school']],
  'shorthand'       =>  [\&_sort_shorthand,     []],
  'shorttitle'      =>  [\&_sort_title,         ['shorttitle']],
  'sortkey'         =>  [\&_sort_sortkey,       []],
  'sortname'        =>  [\&_sort_sortname,      []],
  'sorttitle'       =>  [\&_sort_title,         ['sorttitle']],
  'sortyear'        =>  [\&_sort_year,          ['sortyear']],
  'subtitle'        =>  [\&_sort_title,         ['subtitle']],
  'title'           =>  [\&_sort_title,         ['title']],
  'titleaddon'      =>  [\&_sort_title,         ['titleaddon']],
  'translator'      =>  [\&_sort_translator,    []],
  'urlday'          =>  [\&_sort_dm,            ['urlday']],
  'urlendday'       =>  [\&_sort_dm,            ['urlendday']],
  'urlendmonth'     =>  [\&_sort_dm,            ['urlendmonth']],
  'urlendyear'      =>  [\&_sort_year,          ['urlendyear']],
  'urlmonth'        =>  [\&_sort_dm,            ['urlmonth']],
  'urlyear'         =>  [\&_sort_year,          ['urlyear']],
  'volume'          =>  [\&_sort_volume,        []],
  'year'            =>  [\&_sort_year,          ['year']],
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
    $code_ref = \&_sort_literal;
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
    my $init = substr $ss, 0, 1;

    # Now check if this sortinit is valid in the bblencoding. If not, warn
    # and replace with a suitable value
    my $bblenc = Biber::Config->getoption('bblencoding');
    if ($bblenc ne 'UTF-8') {
      # Can this init be represented in the BBL encoding?
      if (encode($bblenc, $init) eq '?') { # Malformed data encoding char
        # So convert to macro
        require Biber::LaTeX::Recode;
        my $initd = Biber::LaTeX::Recode::latex_encode($init,
                                                       scheme => Biber::Config->getoption('bblsafecharsset'));
        $logger->warn("The character '$init' cannot be encoded in '$bblenc'. sortinit will be set to macro '$initd' for entry '$citekey'");
        $self->{warnings}++;
        $init = $initd;
      }
    }
    $list->set_sortinitdata($citekey, $init);
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

sub _sort_author {
  my ($self, $citekey, $sortelementattributes) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  if (Biber::Config->getblxoption('useauthor', $be->get_field('entrytype'), $citekey) and
    $be->get_field('author')) {
    my $string = $self->_namestring($citekey, 'author');
    return _process_sort_attributes($string, $sortelementattributes);
  }
  else {
    return '';
  }
}

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
# for the editor roles
sub _sort_editor {
  my ($self, $citekey, $sortelementattributes, $args) = @_;
  my $ed = $args->[0]; # get editor field
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  if (Biber::Config->getblxoption('useeditor', $be->get_field('entrytype'), $citekey) and
    $be->get_field($ed)) {
    my $string = $self->_namestring($citekey, $ed);
    return _process_sort_attributes($string, $sortelementattributes);
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


sub _sort_labelalpha {
  my ($self, $citekey, $sortelementattributes) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  if ($be->get_field('sortlabelalpha')) {
    my $string = $be->get_field('sortlabelalpha');
    return _process_sort_attributes($string, $sortelementattributes);
  }
  else {
    return '';
  }
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

sub _sort_literal {
  my ($self, $citekey, $sortelementattributes, $args) = @_;
  my $string = $args->[0]; # get literal string
  return _process_sort_attributes($string, $sortelementattributes);
}

# This is a meta-sub which uses the optional arguments to the dispatch code
# It's done to avoid having many repetitions of almost identical sorting code
# for the place (address/location/institution etc.) sorting options
sub _sort_place {
  my ($self, $citekey, $sortelementattributes, $args) = @_;
  my $pltype = $args->[0]; # get place field type
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  if ($be->get_field($pltype)) {
    my $string = $self->_liststring($citekey, $pltype);
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

sub _sort_publisher {
  my ($self, $citekey, $sortelementattributes) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  if ($be->get_field('publisher')) {
    my $string = $self->_liststring($citekey, 'publisher');
    return _process_sort_attributes($string, $sortelementattributes);
  }
  else {
    return '';
  }
}

sub _sort_pubstate {
  my ($self, $citekey, $sortelementattributes) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $string = $be->get_field('pubstate') // '';
  return _process_sort_attributes($string, $sortelementattributes);
}

sub _sort_shorthand {
  my ($self, $citekey, $sortelementattributes) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $string = $be->get_field('shorthand') // '';
  return _process_sort_attributes($string, $sortelementattributes);
}

sub _sort_sortkey {
  my ($self, $citekey, $sortelementattributes) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $string = $be->get_field('sortkey') // '';
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

# This is a meta-sub which uses the optional arguments to the dispatch code
# It's done to avoid having many repetitions of almost identical sorting code
# for the title sorting options
sub _sort_title {
  my ($self, $citekey, $sortelementattributes, $args) = @_;
  my $ttype = $args->[0]; # get year field type
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  if (my $field = $be->get_field($ttype)) {
    my $string = normalise_string_sort($field, $ttype);
    return _process_sort_attributes($string, $sortelementattributes);
  }
  else {
    return '';
  }
}

sub _sort_translator {
  my ($self, $citekey, $sortelementattributes) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  if (Biber::Config->getblxoption('usetranslator', $be->get_field('entrytype'), $citekey) and
    $be->get_field('translator')) {
    my $string = $self->_namestring($citekey, 'translator');
    return _process_sort_attributes($string, $sortelementattributes);
  }
  else {
    return '';
  }
}

sub _sort_volume {
  my ($self, $citekey, $sortelementattributes) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  if (my $field = $be->get_field('volume')) {
    return _process_sort_attributes($field, $sortelementattributes);
  }
  else {
    return '';
  }
}

# This is a meta-sub which uses the optional arguments to the dispatch code
# It's done to avoid having many repetitions of almost identical sorting code
# for the many date sorting options
# It deals with year fields
sub _sort_year {
  my ($self, $citekey, $sortelementattributes, $args) = @_;
  my $ytype = $args->[0]; # get year field type
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  if (my $field = $be->get_field($ytype)) {
    return _process_sort_attributes($field, $sortelementattributes);
  }
  else {
    return '';
  }
}

#========================================================
# Utility subs used elsewhere but relying on sorting code
#========================================================

sub _process_sort_attributes {
  my ($field_string, $sortelementattributes) = @_;
  return $field_string unless $sortelementattributes;
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
  # $extraflag is set if we are calling this to generate strings for extra*
  # processing and therefore need to use uniquename
  my ($citekey, $field) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');
  my $names = $be->get_field($field);
  my $str = '';
  my $truncated = 0;
  my $truncnames = dclone($names);
  my $maxn = Biber::Config->getblxoption('maxbibnames');
  my $minn = Biber::Config->getblxoption('minbibnames');

  # These should be symbols which can't appear in names
  # This means, symbols which normalise_string_sort strips out
  my $nsi    = '_';          # name separator, internal
  my $nse    = '+';          # name separator, external
  # Guaranteed to sort after everything else as it's the last legal Unicode code point
  my $trunc = "\x{10FFFD}";  # sort string for "et al" truncated name

  # Since namehash is the hash of the visible name,
  # perform truncation according to options minnames, maxnames
  my $ul;
  if (defined($names->get_uniquelist)) {
    $ul = $names->get_uniquelist;
  }

  # If name list was truncated in bib with "and others", this overrides maxnames
  my $morenames = ($names->last_element->get_namestring eq 'others') ? 1 : 0;
  if ( $morenames or $names->count_elements > $maxn ) {
    # truncate to the uniquelist point if uniquelist is requested and max/minbibnames
    # is equal to max/minnames because in this case the user can expect that the bibliography
    # is sorted according to the citation truncations.
    # We know at this stage that if uniquelist is set, there are more than maxnames
    # names. We also know that uniquelist > minnames because it is a further disambiguation
    # on top of minnames so can't be less as you can't disambiguate by losing information
    if ($ul and
       $maxn == Biber::Config->getblxoption('maxnames') and
       $minn == Biber::Config->getblxoption('minnames')) {
      $truncnames = $truncnames->first_n_elements($ul);
      # Since uniquelist can be larger than maxnames, it's only truncated
      # if uniquelist is shorter than the full name list
      $truncated = 1 if $ul < $names->count_elements;
    }
    else {
      # otherwise truncate to minnames
      $truncnames = $truncnames->first_n_elements($minn);
      $truncated = 1;
    }
  }

  # We strip nosort first otherwise normalise_string_sort damages diacritics
  # We strip each individual component instead of the whole thing so we can use
  # as name separators things which would otherwise be stripped. This way we
  # guarantee that the separators are never in names
  foreach my $n ( @{$truncnames->names} ) {
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
  $str .= "$nse$trunc" if $truncated;
  return $str;
}

sub _liststring {
  my ( $self, $citekey, $field ) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my @items = @{$be->get_field($field)};
  my $str = '';
  my $truncated = 0;

  # These should be symbols which can't appear in lists
  # This means, symbols which normalise_string_sort strips out
  my $lsi    = '_';          # list separator, internal
  my $lse    = '+';          # list separator, external
  # Guaranteed to sort after everything else as it's the last legal Unicode code point
  my $trunc = "\x{10FFFD}";  # sort string for truncated list

  # perform truncation according to options minitems, maxitems
  if ( $#items + 1 > Biber::Config->getblxoption('maxitems') ) {
    $truncated = 1;
    @items = splice(@items, 0, Biber::Config->getblxoption('minitems') );
  }

  # separate the items by a string to give some structure
  $str = join($lsi, map { normalise_string_sort($_, $field)} @items);
  $str .= $lse;

  $str =~ s/\s+\Q$lse\E/$lse/gxms;
  $str =~ s/\Q$lse\E\z//xms;
  $str .= "$lse$trunc" if $truncated;
  return $str;
}

=head2 process_entry_options

    Set per-entry options

    "dataonly" is a special case and expands to "skiplab,skiplos,skipbib"
    but only "skiplab" and "skiplos" are dealt with in Biber, "skipbib" is
    dealt with in biblatex.

=cut

sub process_entry_options {
  my $self = shift;
  my $citekey = shift;
  my $options = shift;
  if ( $options ) { # Just in case it's null
    my @entryoptions = split /\s*,\s*/, $options;
    foreach (@entryoptions) {
      m/^([^=]+)=?(.+)?$/;
      if ( $2 and $2 eq 'false' ) {
        if (lc($1) eq 'dataonly') {
          Biber::Config->setblxoption('skiplab', 0, 'PER_ENTRY', $citekey);
          Biber::Config->setblxoption('skiplos', 0, 'PER_ENTRY', $citekey);
        }
        else {
          Biber::Config->setblxoption($1, 0, 'PER_ENTRY', $citekey);
        }
      }
      elsif ( ($2 and $2 eq 'true') or not $2) {
        if (lc($1) eq 'dataonly') {
          Biber::Config->setblxoption('skiplab', 1, 'PER_ENTRY', $citekey);
          Biber::Config->setblxoption('skiplos', 1, 'PER_ENTRY', $citekey);
        }
        else {
          Biber::Config->setblxoption($1, 1, 'PER_ENTRY', $citekey);
        }
      }
      elsif ($2) {
        if (lc($1) eq 'dataonly') {
          Biber::Config->setblxoption('skiplab', $2, 'PER_ENTRY', $citekey);
          Biber::Config->setblxoption('skiplos', $2, 'PER_ENTRY', $citekey);
        }
        else {
          Biber::Config->setblxoption($1, $2, 'PER_ENTRY', $citekey);
        }
      }
      else {
        if (lc($1) eq 'dataonly') {
          Biber::Config->setblxoption('skiplab', 1, 'PER_ENTRY', $citekey);
          Biber::Config->setblxoption('skiplos', 1, 'PER_ENTRY', $citekey);
        }
        else {
          Biber::Config->setblxoption($1, 1, 'PER_ENTRY', $citekey);
        }
      }
    }
  }
}


=head1 AUTHOR

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
