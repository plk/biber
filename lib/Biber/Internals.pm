package Biber::Internals;
use v5.16;
use strict;
use warnings;

use Carp;
use Biber::Constants;
use Biber::Utils;
use Biber::DataModel;
use Data::Compare;
use List::AllUtils qw( :all );
use Log::Log4perl qw(:no_extra_logdie_message);
use Digest::MD5 qw( md5_hex );
use POSIX qw( locale_h ); # for lc()
use Unicode::GCString;
use Unicode::Collate::Locale;
use Unicode::Normalize;
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
    if ($n->get_prefix and not
        Biber::Config->getblxoption('useprefix', $bee, $citekey)) {
      $hashkey .= $n->get_prefix;
    }
  }

  # name list was truncated
  if ($visible < $count or $names->get_morenames) {
    $hashkey .= '+';
  }

  $logger->trace("Creating MD5 namehash using '$hashkey'");
  # Digest::MD5 can't deal with straight UTF8 so encode it first (via NFC as this is "output")
  return md5_hex(encode_utf8(NFC($hashkey)));
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

    if ( $n->get_firstname and defined($n->get_uniquename)) {
      if ($n->get_uniquename eq '2') {
        $hashkey .= $n->get_firstname;
      }
      elsif ($n->get_uniquename eq '1') {
        $hashkey .= join('', @{$n->get_firstname_i});
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
  # Digest::MD5 can't deal with straight UTF8 so encode it first (via NFC as this is "output")
  return md5_hex(encode_utf8(NFC($hashkey)));
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
  # Digest::MD5 can't deal with straight UTF8 so encode it first (via NFC as this is "output")
  return md5_hex(encode_utf8(NFC($hashkey)));
}


# Special hash to track per-name information
sub _genpnhash {
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
  # Digest::MD5 can't deal with straight UTF8 so encode it first (via NFC as this is "output") 
  return md5_hex(encode_utf8(NFC($hashkey)));
}


##################
# label generation
##################

# special label routines - either not part of the dm but special fields for biblatex
# or dm fields which need special treatment. Technically users could remove such fields
# from the dm but it would be very strange.
my %internal_dispatch_label = (
                'label'             =>  [\&_label_basic,            ['label', 'nostrip']],
                'shorthand'         =>  [\&_label_basic,            ['shorthand', 'nostrip']],
                'sortkey'           =>  [\&_label_basic,            ['sortkey', 'nostrip']],
                'citekey'           =>  [\&_label_citekey,          []],
                'labelname'         =>  [\&_label_name,             ['labelname']],
                'labeltitle'        =>  [\&_label_basic,            ['labeltitle']],
                'labelmonth'        =>  [\&_label_basic,            ['labelmonth']],
                'labelday'          =>  [\&_label_basic,            ['labelday']],
                'labelyear'         =>  [\&_label_basic,            ['labelyear']]);

sub _dispatch_table_label {
  my ($field, $dm) = @_;
  # internal fields not part of the data model
  if (my $id = $internal_dispatch_label{$field}) {
    return $id;
  }
  # Label elements which aren't fields
  unless ($dm->is_field($field)) {
    return undef;
  }
  # Fields which are part of the datamodel
  my ($t, $dt) = $dm->get_dm_for_field($field);
  if ($t eq 'list' and $dt eq 'name') {
    return [\&_label_name, [$field]];
  }
  else {
    return [\&_label_basic, [$field]];
  }
}

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
    $label .= $ret->[0] || '';
    $slabel .= $ret->[1] || '';
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
  my $dm = Biber::Config->get_dm;
  my $maxan = Biber::Config->getblxoption('maxalphanames', $bee, $citekey);
  my $minan = Biber::Config->getblxoption('minalphanames', $bee, $citekey);
  my $lp;
  my $slp;

  foreach my $part (@$labelpart) {
    # Implement defaults not set by biblatex itself
    unless (exists($part->{substring_fixed_threshold})) {
      $part->{substring_fixed_threshold} = 1;
    }

    # Deal with various tests
    # ifnamecount only uses this label template part if the list it is applied to is a certain
    # length
    if (my $ic = $part->{ifnamecount}) {
      my $f = $part->{content};
      # resolve labelname
      if ($f eq 'labelname') {
        $f = ($be->get_labelname_info || '');
      }
      if ( first {$f eq $_} @{$dm->get_fields_of_type('list', 'name')}) {
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
  my $code_ref;
  my $code_args_ref;
  my $lp;
  my $slp;
  my $dm = Biber::Config->get_dm;

  # if the field is not found in the dispatch table, assume it's a literal string
  unless (_dispatch_table_label($part->{content}, $dm)) {
    $code_ref = \&_label_literal;
    $code_args_ref = [$part->{content}];
  }
  else { # real label field
    $code_ref = ${_dispatch_table_label($part->{content}, $dm)}[0];
    $code_args_ref = ${_dispatch_table_label($part->{content}, $dm)}[1];
  }
  return &{$code_ref}($self, $citekey, $code_args_ref, $part);
}


#########################
# Label dispatch routines
#########################

sub _label_citekey {
  my ($self, $citekey, $args, $labelattrs) = @_;
  my $k = _process_label_attributes($self, $citekey, $citekey, $labelattrs, $args->[0]);
  return [$k, unescape_label($k)];
}

sub _label_basic {
  my ($self, $citekey, $args, $labelattrs) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $e = $args->[0];
  my $f;
  if ($args->[1] and
      $args->[1] eq 'nostrip') {
    $f = $be->get_field($e);
  }
  else {
    $f = normalise_string_label($be->get_field($e));
  }
  if ($f) {
    my $b = _process_label_attributes($self, $citekey, $f, $labelattrs, $e);
    return [$b, unescape_label($b)];
  }
  else {
    return ['', ''];
  }
}

# literal string - don't post-process this, there is no point
sub _label_literal {
  my ($self, $citekey, $args, $labelattrs) = @_;
  my $string = $args->[0];
  return [escape_label(unescape_label($string)), unescape_label($string)];
}

# names
sub _label_name {
  my ($self, $citekey, $args, $labelattrs) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $useprefix = Biber::Config->getblxoption('useprefix', $be->get_field('entrytype'), $citekey);
  my $alphaothers = Biber::Config->getblxoption('alphaothers', $be->get_field('entrytype'));
  my $sortalphaothers = Biber::Config->getblxoption('sortalphaothers', $be->get_field('entrytype'));

  # Shortcut - if there is no labelname, don't do anything
  return ['',''] unless defined($be->get_labelname_info);

  my $namename = $args->[0];
  my $acc;
  # This contains sortalphaothers instead of alphaothers, if defined
  # This is needed in cases where alphaothers is something like
  # '\textasteriskcentered' which would mess up sorting.
  my $sortacc;

  # Careful to extract the information we need about the real name behind labelname
  # as we need this to set the use* options below.
  my $realname;
  if ($namename eq 'labelname') {
    $realname = $be->get_labelname_info;
  }
  else {
    $realname = $namename;
  }

  my $nameval  = $be->get_field($realname);

  # Account for labelname set to short* when testing use* options
  my $lnameopt;
  if ( $realname =~ /\Ashort(\X+)\z/xms ) {
    $lnameopt = $1;
  }
  else {
    $lnameopt = $realname;
  }

  if (Biber::Config->getblxoption("use$lnameopt", $be->get_field('entrytype'), $citekey) and
    $nameval) {
    my $numnames  = $nameval->count_names;
    my $visibility = $nameval->get_visible_alpha;

    my @lastnames = map { normalise_string_label($_->get_lastname, $realname) } @{$nameval->names};
    my @prefices  = map { $_->get_prefix } @{$nameval->names};
    my $loopnames;

    # loopnames is the number of names to loop over in the name list when constructing the label
    if (my $lc = $labelattrs->{namecount}) {
      if ($lc > $numnames) { # cap at numnames, of course
        $lc = $numnames;
      }
      $loopnames = $lc; # Only look at as many names as specified
    }
    else {
      $loopnames = $visibility; # Else use bib visibility
    }

    for (my $i = 0; $i < $loopnames; $i++) {
      # Deal with prefix options
      if ($useprefix and $prefices[$i]) {
        my $w = $labelattrs->{substring_pwidth} // 1;
        if ($labelattrs->{substring_pcompound}) {
          my $tmpstring;
          # Splitting on tilde too as libbtparse inserts these into compound prefices
          foreach my $part (split(/[\s\p{Dash}~]+/, $prefices[$i])) {
            $tmpstring .= Unicode::GCString->new($part)->substr(0, $w)->as_string;
          }
          $acc .= $tmpstring;
        }
        else {
          $acc .= Unicode::GCString->new($prefices[$i])->substr(0, $w)->as_string;
        }
      }
      $acc .= _process_label_attributes($self, $citekey, $lastnames[$i], $labelattrs, $realname, 'lastname', $i);
    }

    $sortacc = $acc;

    # Add alphaothers if name list is truncated
    if ($numnames > $loopnames or $nameval->get_morenames) {
      $acc .= $alphaothers // ''; # alphaothers can be undef
      $sortacc .= $sortalphaothers // ''; # sortalphaothers can be undef
    }

    return [$acc, unescape_label($sortacc)];
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
                # Do strip/nosort here as that's what we also do to the field contents
                # we will use to look up in this hash later
                $indices{normalise_string_sort($n->get_namepart($namepart), $field)} = $n->get_index;
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
        my $maxlen = $labelattrs->{substring_width_max} || max map {Unicode::GCString->new($_)->length} @strings;
        for (my $i = 1; $i <= $maxlen; $i++) {
          foreach my $map (map { my $s = Unicode::GCString->new($_)->substr(0, $i)->as_string; $substr_cache{$s}++; [$_, $s] } @strings) {
            # We construct a list of all substrings, up to the length of the longest string
            # or substring_width_max. Then we save the index of the list element which is
            # the minimal disambiguation if it's not yet defined
            push @{$lcache->{$map->[0]}{data}}, $map->[1];
            $lcache->{$map->[0]}{nameindex} = $indices{$map->[0]};
            if (not exists($lcache->{$map->[0]}{index}) and
                ($substr_cache{$map->[1]} == 1 or $i == $maxlen)) {
              # -1 to make it into a clean array index
              $lcache->{$map->[0]}{index} = Unicode::GCString->new($map->[1])->length - 1;
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
        # Have to be careful if field "$f" is not set for all entries
        my $strings = [map {my $f = $section->bibentry($_)->get_field($field);
                            $f ? ($namepart ? [map {$_->get_namepart($namepart)} @{$f->first_n_names($f->get_visible_alpha)}] : [$f]) : ['']
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
      my $padchar = $labelattrs->{pad_char};
      if ($subs_side eq 'right') {
        $subs_offset = 0 - $subs_width;
      }

      # Get map of regexps to not count against stringth width and record their place in the string
      my $nolabelwcs = Biber::Config->getoption('nolabelwidthcount');
      my $nolabelwcis = match_indices([map {$_->{value}} @$nolabelwcs], $field_string);

      $logger->trace('Saved indices for nolabelwidthcount: ' . Data::Dump::pp($nolabelwcis));

      # Then remove the nolabelwidthcount chars for now
      foreach my $nolabelwc (@$nolabelwcs) {
        my $nlwcopt = $nolabelwc->{value};
        my $re = qr/$nlwcopt/;
        $field_string =~ s/$re//gxms;           # remove nolabelwidthcount items
      }

      # If desired, do the substring on all parts of compound strings
      # (strings with internal spaces or hyphens)
      if ($labelattrs->{substring_compound}) {
        my $tmpstring;
        foreach my $part (split(/[\s\p{Dash}]+/, $field_string)) {
          $tmpstring .= Unicode::GCString->new($part)->substr($subs_offset, $subs_width)->as_string;
        }
        $field_string = $tmpstring;
      }
      else {
        $field_string = Unicode::GCString->new($field_string)->substr($subs_offset, $subs_width)->as_string;
      }

      # Padding
      if ($padchar) {
        $padchar = unescape_label($padchar);
        my $pad_side = ($labelattrs->{pad_side} or 'right');
        my $paddiff = $subs_width - Unicode::GCString->new($field_string)->length;
        if ($paddiff > 0) {
          if ($pad_side eq 'right') {
            $field_string .= $padchar x $paddiff;
          }
          elsif ($pad_side eq 'left') {
            $field_string = $padchar x $paddiff . $field_string;
          }
        }
        $field_string = escape_label($field_string);
      }

      # Now reinstate any nolabelwidthcount regexps
      # Unicode::GCString->substr() with 3 args doesn't seem to work
      my $subslength = Unicode::GCString->new($field_string)->length;
      my @gca = Unicode::GCString->new($field_string)->as_array;
      my $splicelen = 0;
      foreach my $nolabelwci (@$nolabelwcis) {
        if (($nolabelwci->[1] + 1) <= $subslength) {
          splice(@gca, $nolabelwci->[1] + $splicelen, 0, $nolabelwci->[0]);
          # - 1 here as we are using a length as a 0-based index calculation later on
          $splicelen += (Unicode::GCString->new($nolabelwci->[0])->length - 1);
        }
      }
      $field_string = join('', @gca);
    }
  }

  # Case changes
  if ($labelattrs->{uppercase} and
      $labelattrs->{lowercase}) {
    # do nothing if both are set, for sanity
  }
  elsif ($labelattrs->{uppercase}) {
    $field_string = uc($field_string);
  }
  elsif ($labelattrs->{lowercase}) {
    $field_string = lc($field_string);
  }

  return $field_string;
}

# This turns a list of label strings:
# [
#  ['Agassi', 'Chang',   'Laver', 'bob'],
#  ['Agassi', 'Chang',   'Laver'],
#  ['Agassi', 'Chang',   'Laver'],
#  ['Agassi', 'Connors', 'Lendl'],
#  ['Agassi', 'Courier', 'Laver'],
#  ['Borg',   'Connors', 'Edberg'],
#  ['Borg',   'Connors', 'Emerson'],
#  ['Becker', 'Connors', 'Emerson'],
#  ['Becker']
#  ['Zoo', 'Xaa'],
#  ['Zoo', 'Xaa'],
#  ['Zaa'],
#  ['Abc', 'Abc', 'Abc'],
#  ['Abc', 'Abc', 'Abc'],
#  ['Abc', 'Abc', 'Abc']
# ]
#
#
# into a disambiguated list of substrings:
#
# { data => [
#            ['A',  'C',  'L',  'b'],
#            ['A',  'Ch', 'L'      ],
#            ['A',  'Ch', 'L'      ],
#            ['A',  'Co', 'L'      ],
#            ['A',  'C',  'L'      ],
#            ['B',  'C',  'Ed'     ],
#            ['Bo', 'C',  'E'      ],
#            ['B',  'C',  'E'      ],
#            ['B'                  ]
#            ['Z'   'X'            ]
#            ['Z'   'X'            ]
#            ['Z'                  ]
#            ['A',  'A',  'A'      ]
#            ['A',  'A',  'A'      ]
#            ['A',  'A',  'A'      ]
#           ],
# }
#

sub _label_listdisambiguation {
  my $strings = shift;

  # Cache map says which index are we substr'ing to for each name.
  # Starting default is first char from each
  my $cache->{substr_map} = [map {[map {1} @$_]} @$strings];
  my $lcache->{data} = [map {undef} @$strings];

  # First flag any duplicates so we can shortcut setting these later
  my @dups;
  for (my $i = 0; $i <= $#$strings; $i++) {
    $dups[$i] = join('', @{$strings->[$i]});
  }

  _do_substr($lcache, $cache, $strings);

  # loop until the entire disambiguation cache is filled.
  while (grep { !defined } @{$lcache->{data}}) {
    _check_counts($lcache, $cache);
    foreach my $ambiguous_indices (@{$cache->{ambiguity}}) {
      my $ambiguous_strings = [@$strings[@$ambiguous_indices]]; # slice
      # We work on the first in an ambiguous set
      # We have to find the first name which is not the same as another name in the
      # same position as we can't disambiguate on the basis of an identical name. For example:
      # [
      #   [ 'Smith', 'Jones' ]
      #   [ 'Smith', 'Janes' ]
      # ]
      #
      # Here there is no point trying more characters in "Smith" as it won't help

      # Special case: If all lists in an ambiguity set are identical, like
      #
      # [
      #  [ 'Smith, 'Jones' ],
      #  [ 'Smith, 'Jones' ],
      # ]
      #
      # Then we can shortcut and take a 1-char substring only
      # if all name lists in the ambiguous list are in fact the same
      if (all {Compare($ambiguous_strings->[0], $_)} @$ambiguous_strings) {
        $lcache->{data}[$ambiguous_indices->[0]] =  [map {Unicode::GCString->new($_)->substr(0,1)->as_string} @{$ambiguous_strings->[0]}];
      }
      else {
        # Get disambiguating list position information
        _gen_first_disambiguating_name_map($cache, $ambiguous_strings, $ambiguous_indices);

        # Then increment appropriate substr map
        $cache->{substr_map}[$ambiguous_indices->[0]][$cache->{name_map}[$ambiguous_indices->[0]]]++;
      }

      # Rebuild the cache and loop
      _do_substr($lcache, $cache, $strings);
    }
  }

  return $lcache;
}

# Take substrings of name lists according to a map and save the results
sub _do_substr {
  my ($lcache, $cache, $strings) = @_;
  delete($cache->{keys});
  for (my $i = 0; $i <= $#$strings; $i++) {
    next if defined($lcache->{data}[$i]); # ignore names already disambiguated
    my $row = $strings->[$i];
    my @s;
    for (my $j = 0; $j <= $#$row; $j++) {
      push @s, Unicode::GCString->new($row->[$j])->substr(0 ,$cache->{substr_map}[$i][$j])->as_string;
    }
    my $js = join('', @s);
    $cache->{keys}{$js}{index} = $i; # index of the last seen $js key - useless for count >1
    push @{$cache->{keys}{$js}{indices}}, $i;
    $cache->{keys}{$js}{count}++;
    $cache->{keys}{$js}{strings} = \@s;
  }
}

# Push finished disambiguation into results and save still ambiguous labels for loop
sub _check_counts {
  my ($lcache, $cache) = @_;
  delete($cache->{ambiguity});
  foreach my $key (keys %{$cache->{keys}}) {
    if ($cache->{keys}{$key}{count} > 1) {
      push @{$cache->{ambiguity}}, $cache->{keys}{$key}{indices};
    }
    else {
      $lcache->{data}[$cache->{keys}{$key}{index}] = $cache->{keys}{$key}{strings};
    }
  }
}

# Find the index of the first name in $array->[0] which doesn't
# occur in any other of $array in the same position. This must be the name
# which disambiguates.

# [
#  ['Agassi', 'Chang',   'Laver'],
#  ['Agassi', 'Chang',   'Laver'],
#  ['Agassi', 'Connors', 'Lendl'],
#  ['Agassi', 'Courier', 'Laver'],
#  ['Agassi', 'Courier', 'Lendl'],
# ]

# results in

# $cache->{name_map} = [ 1, 1, 1, 1, 2 ]
sub _gen_first_disambiguating_name_map {
  my ($cache, $array, $indices) = @_;
  for (my $i = 0; $i <= $#$array; $i++) {
    my @check_array = @$array;
    splice(@check_array, $i, 1);
    # Remove duplicates from the check array otherwise the duplicate makes generating the
    # name disambiguation index fail because there is a same name in every position
    @check_array = grep {not Compare($array->[$i], $_)} @check_array;
    # all ambiguous must be same length (otherwise they wouldn't be ambiguous)
    my $len = $#{$array->[0]};
    for (my $j = 0; $j <= $len; $j++) {
      # if no other name equal to this one in same place, this is the index of the name
      # to use for disambiguation
      unless (grep {$array->[$i][$j] eq $_} map {$_->[$j]} @check_array) {
        $cache->{name_map}[$indices->[$i]] = $j;
        last;
      }
    }
  }
}

#########
# Sorting
#########

# None of these can be used to generate sorting information otherwise there
# would be a circular dependency:

# sortinit
# sortinithash
# extrayear
# extratitle
# extratitleyear
# extraalpha

my $sorting_sep = ',';

# special sorting routines - not part of the dm but special fields for biblatex
my %internal_dispatch_sorting = (
                                 'editoratype'     =>  [\&_sort_editort,       ['editoratype']],
                                 'editorbtype'     =>  [\&_sort_editort,       ['editorbtype']],
                                 'editorctype'     =>  [\&_sort_editort,       ['editorctype']],
                                 'citeorder'       =>  [\&_sort_citeorder,     []],
                                 'labelalpha'      =>  [\&_sort_labelalpha,    []],
                                 'labelname'       =>  [\&_sort_labelname,     []],
                                 'labeltitle'      =>  [\&_sort_labeltitle,    []],
                                 'labelyear'       =>  [\&_sort_labeldate,     ['year']],
                                 'labelmonth'      =>  [\&_sort_labeldate,     ['month']],
                                 'labelday'        =>  [\&_sort_labeldate,     ['day']],
                                 'presort'         =>  [\&_sort_presort,       []],
                                 'sortname'        =>  [\&_sort_sortname,      []],
                                 'entrykey'        =>  [\&_sort_entrykey,      []]);

# The value is an array pointer, first element is a code pointer, second is
# a pointer to extra arguments to the code. This is to make code re-use possible
# so the sorting can share code for similar things.
sub _dispatch_table_sorting {
  my ($field, $dm) = @_;
  # internal fields not part of the data model
  if (my $id = $internal_dispatch_sorting{$field}) {
    return $id;
  }
  # Sorting elements which aren't fields
  unless ($dm->is_field($field)) {
    return undef;
  }
  # Fields which are part of the datamodel
  my ($t, $dt) = $dm->get_dm_for_field($field);
  if ($t eq 'list' and $dt eq 'name') {
    return [\&_sort_name, [$field]];
  }
  elsif ($t eq 'field' and $dt eq 'literal') {
    return [\&_sort_literal, [$field]];
  }
  elsif ($t eq 'field' and
         ($dt eq 'integer' or $dt eq 'datepart')) {
    return [\&_sort_integer, [$field]];
  }
  elsif ($t eq 'list' and
         ($dt eq 'literal' or $dt eq 'key')) {
    return [\&_sort_list, [$field]];
  }
  elsif ($t eq 'field' and $dt eq 'key') {
    return [\&_sort_literal, [$field]];
  }
}

# Main sorting dispatch method
sub _dispatch_sorting {
  my ($self, $sortfield, $citekey, $sortelementattributes) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $code_ref;
  my $code_args_ref;
  my $dm = Biber::Config->get_dm;

  # If this field is excluded from sorting for this entrytype, then skip it and return
  if (my $se = Biber::Config->getblxoption('sortexclusion', $be->get_field('entrytype'))) {
    if ($se->{$sortfield}) {
      return '';
    }
  }

  # if the field is not found in the dispatch table, assume it's a literal string
  unless (_dispatch_table_sorting($sortfield, $dm)) {
    $code_ref = \&_sort_string;
    $code_args_ref = [$sortfield];
  }
  else { # real sorting field
    $code_ref = ${_dispatch_table_sorting($sortfield, $dm)}[0];
    $code_args_ref  = ${_dispatch_table_sorting($sortfield, $dm)}[1];
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
  foreach my $sortset (@{$sortscheme->{spec}}) {
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
  $logger->debug("Sorting object for key '$citekey' -> " . Data::Dump::pp($sortobj));

  # Generate sortinit. Skip if there is no sortstring, which is possible in tests
  if ($ss) {
  # This must ignore the presort characters, naturally
    my $pre = Biber::Config->getblxoption('presort', $be->get_field('entrytype'), $citekey);

    # Strip off the prefix
    $ss =~ s/\A$pre$sorting_sep+//;
    my $init = Unicode::GCString->new(normalise_string($ss))->substr(0, 1)->as_string;

    # Collator for determining primary weight hash for sortinit
    # Using the global sort locale because we only want the sortinit of the first sorting field
    # and if this was locally different to the global sorting, something would be very strange.
    my $Collator = Unicode::Collate::Locale->new(locale => Biber::Config->getoption('sortlocale'), level => 1);
    my $inithash = md5_hex($Collator->viewSortKey($init));
    $list->set_sortinitdata_for_key($citekey, $init, $inithash);
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
  # Allkeys and sorting=none means use bib order which is in orig_order_citekeys
  # However, someone might do:
  # \cite{b,a}
  # \nocite{*}
  # in the same section which means we need to use the order attribute for those
  # keys which have one (the \cited keys) and then an orig_order_citekey index based index
  # for the nocite ones.
  my $ko = Biber::Config->get_keyorder($secnum, $citekey);# only for \cited keys
  if ($section->is_allkeys) {
    return sprintf('%.7d', $ko ||
                   (Biber::Config->get_keyorder_max($secnum) +
                    (first_index {$_ eq $citekey} $section->get_orig_order_citekeys) + 1));
  }
  # otherwise, we need to take account of citations with simulataneous order like
  # \cite{key1, key2} so this tied sorting order can be further sorted with other fields
  # Note the fallback of "0" - this is for auto-generated entries which are not cited
  # and so never have a keyorder entry
  else {
    return sprintf('%.7d', $ko || 0);
  }
}

sub _sort_integer {
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

sub _sort_editort {
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

sub _sort_entrykey {
  my ($self, $citekey, $sortelementattributes) = @_;
  return _process_sort_attributes($citekey, $sortelementattributes);
}

sub _sort_labelalpha {
  my ($self, $citekey, $sortelementattributes, $args) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $string = $be->get_field('sortlabelalpha') // '';
  return _process_sort_attributes($string, $sortelementattributes);
}

sub _sort_labelname {
  my ($self, $citekey, $sortelementattributes, $args) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  # re-direct to the right sorting routine for the labelname
  if (my $lni = $be->get_labelname_info) {
    # Don't process attributes as they will be processed in the real sub
    return $self->_dispatch_sorting($lni, $citekey, $sortelementattributes);
  }
  else {
    return '';
  }
}

sub _sort_labeltitle {
  my ($self, $citekey, $sortelementattributes, $args) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  # re-direct to the right sorting routine for the labeltitle
  if (my $lti = $be->get_labeltitle_info) {
    # Don't process attributes as they will be processed in the real sub
    return $self->_dispatch_sorting($lti, $citekey, $sortelementattributes);
  }
  else {
    return '';
  }
}

sub _sort_labeldate {
  no autovivification;
  my ($self, $citekey, $sortelementattributes, $args) = @_;
  my $ldc = $args->[0]; # labeldate component
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  # re-direct to the right sorting routine for the labeldate component
  if (my $ldi = $be->get_labeldate_info) {
    if (my $ldf = $ldi->{field}{$ldc}) {
      # Don't process attributes as they will be processed in the real sub
      return $self->_dispatch_sorting($ldf, $citekey, $sortelementattributes);
    }
    elsif (exists($ldi->{string})) { # labelyear fallback string
      return '';
    }
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
# for literal strings which need normalising
sub _sort_literal {
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
  my $dm = Biber::Config->get_dm;

  # sortname is ignored if no use<name> option is defined - see biblatex manual
  if ($be->get_field('sortname') and
      grep {Biber::Config->getblxoption("use$_", $be->get_field('entrytype'), $citekey)} @{$dm->get_fields_of_type('list', 'name')}) {
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
    $field_string = Unicode::GCString->new($field_string)->substr($subs_offset, $subs_width)->as_string;
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
    my $pad_length = $pad_width - Unicode::GCString->new($field_string)->length;
    if ($pad_length > 0) {
      if ($pad_side eq 'left') {
        $field_string = ($pad_char x $pad_length) . $field_string;
      }
      elsif ($pad_side eq 'right') {
        $field_string = $field_string . ($pad_char x $pad_length);
      }
    }
  }
  return $field_string;
}

# This is used to generate sorting string for names
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

  # These should be symbols which can't appear in names and which sort before all alphanum
  # so that "Alan Smith" sorts after "Al Smith". This means, symbols which normalise_string_sort()
  # strips out. Unfortuately, this means using punctuation and these are by default variable
  # weight and ignorable in DUCET so we have to set U::C to variable=>'non-ignorable' as
  # sorting default so that they are non-ignorable
  my $nsi    = '!';          # name separator, internal
  my $nse    = '#';          # name separator, external
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

    # Append first name or inits if sortfirstinits is set
    if (Biber::Config->getoption('sortfirstinits')) {
      $str .=  normalise_string_sort(join('', @{$n->get_firstname_i}), $field) . $nsi if $n->get_firstname_i;
    }
    else {
      $str .= normalise_string_sort($n->get_firstname, $field) . $nsi if $n->get_firstname;
    }

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
  $str =~ s/\Q$nse\E\z//xms;         # strip final external separator as we have finished

  $str .= $trunc if $visible < $count; # name list was truncated
  return $str;
}

sub _liststring {
  my ($self, $citekey, $field) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');
  my $f = $be->get_field($field); # _liststring is used in tests so there has to be
  return '' unless defined($f);   # more error checking which will never be needed in normal use
  my @items = @$f;
  my $str = '';
  my $truncated = 0;

  # These should be symbols which can't appear in lists and which sort before all alphanum
  # so that "Alan Smith" sorts after "Al Smth". This means, symbols which normalise_string_sort()
  # strips out. Unfortuately, this means using punctuation and these are by default variable
  # weight and ignorable in DUCET so we have to redefine these these symbols after loading DUCET
  # when sorting so that they are non-ignorable (see Biber.pm)
  my $lsi    = '!';          # list separator, internal
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


1;

__END__

=head1 AUTHOR

François Charette, C<< <firmicus at ankabut.net> >>
Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our Github tracker at
L<https://github.com/plk/biber/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2015 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
