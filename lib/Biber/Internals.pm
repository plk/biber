package Biber::Internals;
use v5.24;
use strict;
use warnings;

use Carp;
use Biber::Constants;
use Biber::Utils;
use Biber::DataModel;
use Data::Compare;
use Digest::MD5 qw( md5_hex );
use Encode;
use List::AllUtils qw( :all );
use Log::Log4perl qw(:no_extra_logdie_message);
use POSIX qw( locale_h ); # for lc()
use Scalar::Util qw(looks_like_number);
use Text::Roman qw(isroman roman2int);
use Unicode::GCString;
use Unicode::Collate::Locale;
use Unicode::Normalize;
use Unicode::UCD qw(num);

=encoding utf-8

=head1 NAME

Biber::Internals - Internal methods for processing the bibliographic data

=head1 METHODS



=cut

my $logger = Log::Log4perl::get_logger('main');

# Hashes should not care about use* or sorting name key template etc. We want to generate hashes
# unique to a name, not a particular representation of a name. So, always statically concatenate
# nameparts from the data model list of valid nameparts
sub _getnamehash {
  my ($self, $citekey, $names, $dlist, $bib) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');

  my $hashkey = '';
  my $count = $names->count;
  my $visible = $bib ? $dlist->get_visible_bib($names->get_id) : $dlist->get_visible_cite($names->get_id);
  my $dm = Biber::Config->get_dm;
  my @nps = $dm->get_constant_value('nameparts');

  # refcontext or per-entry namehashtemplate
  my $nhtname = Biber::Config->getblxoption($secnum, 'namehashtemplatename', undef, $citekey) // $dlist->get_namehashtemplatename;

  # Per-namelist namehashtemplate
  if (defined($names->get_namehashtemplatename)) {
    $nhtname = $names->get_namehashtemplatename;
  }

  # namehash obeys list truncations but not uniquename
  foreach my $n ($names->first_n_names($visible)->@*) {

    # use user-defined hashid for hash generation if present
    if (my $hid = $n->get_hashid) {
      $hashkey .= $hid;
      next;
    }

    # Per-name namehashtemplate
    if (defined($n->get_namehashtemplatename)) {
      $nhtname = $n->get_namehashtemplatename;
    }

    my $nht = Biber::Config->getblxoption($secnum, 'namehashtemplate')->{$nhtname};

    unless ($nht) {
      biber_error("No namehash template called '$nhtname'");
    }

    foreach my $nt (@nps) {# list type so returns list
      $hashkey .= $n->get_hash_namepart($nt, $nht);
    }
  }

  my $nho = Biber::Config->getblxoption($secnum, 'nohashothers', $bee, $citekey);

  # Per-namelist nohashothers
  if (defined($names->get_nohashothers)) {
    $nho = $names->get_nohashothers;
  }

  # name list was truncated
  unless ($nho) {
    if ($visible < $count or $names->get_morenames) {
      $hashkey .= '+';
    }
  }

  # Digest::MD5 can't deal with straight UTF8 so encode it first (via NFC as this is "output")
  return md5_hex(encode_utf8(NFC(normalise_string_hash($hashkey))));
}

sub _getfullhash {
  my ($self, $citekey, $names, $dlist) = @_;
  my $hashkey = '';
  my $secnum = $self->get_current_section;
  my $dm = Biber::Config->get_dm;
  my @nps = $dm->get_constant_value('nameparts');

  # refcontext or per-entry namehashtemplate
  my $nhtname = Biber::Config->getblxoption($secnum, 'namehashtemplatename', undef, $citekey) // $dlist->get_namehashtemplatename;

  # Per-namelist namehashtemplate
  if (defined($names->get_namehashtemplatename)) {
    $nhtname = $names->get_namehashtemplatename;
  }

  foreach my $n ($names->names->@*) {

    # use user-defined hashid for hash generation if present
    if (my $hid = $n->get_hashid) {
      $hashkey .= $hid;
      next;
    }

    # Per-name namehashtemplate
    if (defined($n->get_namehashtemplatename)) {
      $nhtname = $n->get_namehashtemplatename;
    }

    my $nht = Biber::Config->getblxoption($secnum, 'namehashtemplate')->{$nhtname};

    unless ($nht) {
      biber_error("No namehash template called '$nhtname'");
    }

    foreach my $nt (@nps) {# list type so returns list
      $hashkey .= strip_nonamestring($n->get_hash_namepart($nt, $nht),  $names->get_type);
    }
  }

  # If we had an "and others"
  if ($names->get_morenames) {
    $hashkey .= '+'
  }

  # Digest::MD5 can't deal with straight UTF8 so encode it first (via NFC as this is "output")
  return md5_hex(encode_utf8(NFC(normalise_string_hash($hashkey))));
}

# fullhash without any namehashtemplate. Basically a hash of all full nameparts present in the .bib,
# after any sourcemaps, naturally
sub _getfullhashraw {
  my ($self, $citekey, $names, $dlist) = @_;
  my $hashkey = '';
  my $secnum = $self->get_current_section;
  my $dm = Biber::Config->get_dm;
  my @nps = $dm->get_constant_value('nameparts');

  foreach my $n ($names->names->@*) {
    foreach my $nt (@nps) {# list type so returns list
      if (my $np = $n->get_namepart($nt)) {
        $hashkey .= strip_nonamestring($np, $names->get_type);
      }
    }
  }

  # If we had an "and others"
  if ($names->get_morenames) {
    $hashkey .= '+'
  }

  # Digest::MD5 can't deal with straight UTF8 so encode it first (via NFC as this is "output")
  return md5_hex(encode_utf8(NFC(normalise_string_hash($hashkey))));
}

# Same as _getnamehash but takes account of uniquename template
# It's used for extra* tracking only
sub _getnamehash_u {
  my ($self, $citekey, $names, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');

  my $hashkey = '';
  my $count = $names->count;
  my $nlid = $names->get_id;
  my $visible = $dlist->get_visible_cite($nlid);
  my $dm = Biber::Config->get_dm;
  my @nps = $dm->get_constant_value('nameparts');

  # refcontext or per-entry uniquenametemplate
  my $untname = Biber::Config->getblxoption($secnum, 'uniquenametemplatename', undef, $citekey) // $dlist->get_uniquenametemplatename;

  # Per-namelist uniquenametemplate
  if (defined($names->get_uniquenametemplatename)) {
    $untname = $names->get_uniquenametemplatename;
  }

  # namehash obeys list truncations
  foreach my $n ($names->first_n_names($visible)->@*) {
    my $nid = $n->get_id;

    # Per-name uniquenametemplate
    if (defined($n->get_uniquenametemplatename)) {
      $untname = $n->get_uniquenametemplatename;
    }

    # Use nameuniqueness template to construct hash
    foreach my $nps (Biber::Config->getblxoption($secnum, 'uniquenametemplate')->{$untname}->@*) {
      # Same as omitting this
      next if defined($nps->{disambiguation}) and ($nps->{disambiguation} eq 'none');
      my $npn = $nps->{namepart};

      if (my $np = $n->get_namepart($npn)) {
        if ($nps->{base}) {
          $hashkey .= $np;
        }
        else {
          my $un = $dlist->get_uniquename($nlid, $nid);
          if (defined($un) and ($un->[0] ne 'base')) {
            if ($un->[1] eq 'full' or $un->[1] eq 'fullonly') {
              $hashkey .= $np;
            }
            # Use initials for non-base parts if uniquename indicates this will disambiguate
            elsif ($un->[1] eq 'init') {
              $hashkey .= join('', $n->get_namepart_initial($npn)->@*);
            }
          }
        }
      }
    }
  }

  my $nho = Biber::Config->getblxoption($secnum, 'nohashothers', $bee, $citekey);

  # Per-namelist nohashothers
  if (defined($names->get_nohashothers)) {
    $nho = $names->get_nohashothers;
  }

  # name list was truncated
  unless ($nho) {
    if ($visible < $count or $names->get_morenames) {
      $hashkey .= '+';
    }
  }

  # Digest::MD5 can't deal with straight UTF8 so encode it first (via NFC as this is "output")
  return md5_hex(encode_utf8(NFC(normalise_string_hash($hashkey))));
}

# Special hash to track per-name information
sub _genpnhash {
  my ($self, $citekey, $names, $n, $dlist) = @_;
  my $hashkey = '';
  my $secnum = $self->get_current_section;
  my $dm = Biber::Config->get_dm;
  my @nps = $dm->get_constant_value('nameparts');

  # use user-defined hashid for hash generation if present
  if (my $hid = $n->get_hashid) {
    return md5_hex(encode_utf8(NFC(normalise_string_hash($hid))));
  }

  # refcontext or per-entry namehashtemplate
  my $nhtname = Biber::Config->getblxoption($secnum, 'namehashtemplatename', undef, $citekey) // $dlist->get_namehashtemplatename;

  # Per-namelist namehashtemplate
  if (defined($names->get_namehashtemplatename)) {
    $nhtname = $names->get_namehashtemplatename;
  }

  # Per-name namehashtemplate
  if (defined($n->get_namehashtemplatename)) {
    $nhtname = $n->get_namehashtemplatename;
  }

  my $nht = Biber::Config->getblxoption($secnum, 'namehashtemplate')->{$nhtname};

  unless ($nht) {
    biber_error("No namehash template called '$nhtname'");
  }

  foreach my $nt (@nps) {# list type so returns list
    $hashkey .= $n->get_hash_namepart($nt, $nht);
  }

  if ($logger->is_trace()) { # performance shortcut
    $logger->trace("Creating MD5 pnhash using '$hashkey'");
  }

  # Digest::MD5 can't deal with straight UTF8 so encode it first (via NFC as this is "output")
  return md5_hex(encode_utf8(NFC(normalise_string_hash($hashkey))));
}


##################
# LABEL GENERATION
##################

# special label routines - either not part of the dm but special fields for biblatex
# or dm fields which need special treatment. Technically users could remove such fields
# from the dm but it would be very strange.
my %internal_dispatch_label = (
                'label'      =>  [\&_label_basic,   ['label', 'nostrip']],
                'shorthand'  =>  [\&_label_basic,   ['shorthand', 'nostrip']],
                'sortkey'    =>  [\&_label_basic,   ['sortkey', 'nostrip']],
                'citekey'    =>  [\&_label_citekey, []],
                'entrykey'   =>  [\&_label_citekey, []],
                'labelname'  =>  [\&_label_name,    ['labelname']],
                'labeltitle' =>  [\&_label_basic,   ['labeltitle']],
                'labelmonth' =>  [\&_label_basic,   ['labelmonth']],
                'labelday'   =>  [\&_label_basic,   ['labelday']],
                'labelyear'  =>  [\&_label_basic,   ['labelyear']]);

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
  my $dmf = $dm->get_dm_for_field($field);
  if ($dmf->{fieldtype} eq 'list' and $dmf->{datatype} eq 'name') {
    return [\&_label_name, [$field]];
  }
  else {
    return [\&_label_basic, [$field]];
  }
}

# Main label loop
sub _genlabel {
  my ($self, $citekey, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $labelalphatemplate = Biber::Config->getblxoption($secnum, 'labelalphatemplate', $be->get_field('entrytype'));
  my $label;
  my $slabel;
  $LABEL_FINAL = 0; # reset final shortcut

  foreach my $labelpart (sort {$a->{order} <=> $b->{order}} $labelalphatemplate->{labelelement}->@*) {
    my $ret = _labelpart($self, $labelpart->{labelpart}, $citekey, $secnum, $section, $be, $dlist);
    $label .= $ret->[0] || '';
    $slabel .= $ret->[1] || '';
    last if $LABEL_FINAL;
  }

  return [ $label, $slabel ];
}

# Disjunctive set of label parts
sub _labelpart {
  my ($self, $labelpart, $citekey, $secnum, $section, $be, $dlist) = @_;
  my $bee = $be->get_field('entrytype');
  my $dm = Biber::Config->get_dm;
  my $maxan = Biber::Config->getblxoption($secnum, 'maxalphanames', $bee, $citekey);
  my $minan = Biber::Config->getblxoption($secnum, 'minalphanames', $bee, $citekey);
  my $lp;
  my $slp;

  foreach my $part ($labelpart->@*) {
    # Implement defaults not set by biblatex itself
    unless (exists($part->{substring_fixed_threshold})) {
      $part->{substring_fixed_threshold} = 1;
    }

    # Deal with various tests
    # ifnames only uses this label template part if the list it is applied to is a certain
    # length
    if (my $inc = $part->{ifnames}) {
      my $f = $part->{content};
      # resolve labelname
      if ($f eq 'labelname') {
        $f = ($be->get_labelname_info || '');
      }
      if ( first {$f eq $_} $dm->get_fields_of_type('list', 'name')->@*) {
        my $name = $be->get_field($f) || next; # just in case there is no labelname etc.
        my $total_names = $name->count;
        my $visible_names;
        if ($total_names > $maxan) {
          $visible_names = $minan;
        }
        else {
          $visible_names = $total_names;
        }

        # Deal with ifnames
        if ($inc =~ m/^\d+$/) {# just a number
          next unless $visible_names == $inc;
        }
        else {# a range
          my $incr = parse_range_alt($inc);
          if (not defined($incr->[0])) {# range -x
            next unless $visible_names <= $incr->[1];
          }
          elsif (not defined($incr->[1])) {# range x-
            next unless $visible_names >= $incr->[0];
          }
          else {# range x-y
            next unless ($visible_names >= $incr->[0] and
                         $visible_names <= $incr->[1]);
          }
        }
      }
    }
    my $ret = _dispatch_label($self, $part, $citekey, $secnum, $section, $be, $dlist);
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
  my ($self, $part, $citekey, $secnum, $section, $be, $dlist) = @_;
  my $code_ref;
  my $code_args_ref;
  my $lp;
  my $slp;
  my $dm = Biber::Config->get_dm;


  # real label field
  if (my $d = _dispatch_table_label($part->{content}, $dm)) {
    $code_ref = $d->[0];
    $code_args_ref = $d->[1];
  }
  else { # if the field is not found in the dispatch table, assume it's a literal string
    $code_ref = \&_label_literal;
    $code_args_ref = [$part->{content}];
  }
  return &{$code_ref}($self, $citekey, $secnum, $section, $be, $code_args_ref, $part, $dlist);
}


#########################
# Label dispatch routines
#########################

sub _label_citekey {
  my ($self, $citekey, $secnum, $section, $be, $args, $labelattrs, $dlist) = @_;
  my $k = _process_label_attributes($self, $citekey, $dlist, [[$citekey, undef]], $labelattrs, $args->[0]);
  return [$k, unescape_label($k)];
}

sub _label_basic {
  my ($self, $citekey, $secnum, $section, $be, $args, $labelattrs, $dlist) = @_;
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
    my $b = _process_label_attributes($self, $citekey, $dlist, [[$f, undef]], $labelattrs, $e);
    return [$b, unescape_label($b)];
  }
  else {
    return ['', ''];
  }
}

# literal string - don't post-process this, there is no point
sub _label_literal {
  my ($self, $citekey, $secnum, $section, $be, $args, $labelattrs) = @_;
  my $string = $args->[0];
  return [escape_label(unescape_label($string)), unescape_label($string)];
}

# names
sub _label_name {
  my ($self, $citekey, $secnum, $section, $be, $args, $labelattrs, $dlist) = @_;
  my $bee = $be->get_field('entrytype');
  my $useprefix = Biber::Config->getblxoption($secnum, 'useprefix', $bee, $citekey);
  my $alphaothers = Biber::Config->getblxoption(undef, 'alphaothers', $bee);
  my $sortalphaothers = Biber::Config->getblxoption(undef, 'sortalphaothers', $bee);

  # Get the labelalphanametemplate name or this list context
  my $lantname = $dlist->get_labelalphanametemplatename;

  # Override with any entry-specific information
  $lantname = Biber::Config->getblxoption($secnum, 'labelalphanametemplatename', undef, $citekey) // $lantname;

  # Shortcut - if there is no labelname, don't do anything
  return ['',''] unless defined($be->get_labelname_info);

  my $namename = $args->[0];
  my $acc = '';# Must initialise to empty string as we need to return a string
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

  my $names = $be->get_field($realname);

  # Account for labelname set to short* when testing use* options
  my $lnameopt;
  if ( $realname =~ /\Ashort(\X+)\z/xms ) {
    $lnameopt = $1;
  }
  else {
    $lnameopt = $realname;
  }

  if (Biber::Config->getblxoption($secnum, "use$lnameopt", $bee, $citekey) and
    $names) {

    # namelist scope labelalphanametemplate
    if (defined($names->get_labelalphanametemplatename)) {
      $lantname = $names->get_labelalphanametemplatename;
    }

    # namelist scope useprefix
    if (defined($names->get_useprefix)) {
      $useprefix = $names->get_useprefix;
    }

    my $numnames  = $names->count;
    my $visibility = $dlist->get_visible_alpha($names->get_id);

    # Use name range override, if any
    my $nr_start;
    my $nr_end;
    if (exists($labelattrs->{names})) {
      my $nr = parse_range($labelattrs->{names});
      $nr_start = $nr->[0];
      $nr_end = $nr->[1];

      if (defined($nr_end) and
          $nr_end eq '+') {# minalphanames cap marker
        $nr_end = $visibility;
      }
      elsif (not defined($nr_end) or
          $nr_end > $numnames) { # cap at numnames, of course
        $nr_end = $numnames;
      }
    }
    else {
      $nr_start = 1;
      $nr_end = $visibility; # Else use bib visibility
    }

    if ($logger->is_trace()) {# performance tune
      $logger->trace("$realname/numnames=$numnames/visibility=$visibility/nr_start=$nr_start/nr_end=$nr_end");
    }

    my $parts;
    my $opts;

    foreach my $name ($names->names->@*) {

      # name scope labelalphanametemplate
      if (defined($name->get_labelalphanametemplatename)) {
        $lantname = $name->get_labelalphanametemplatename;
      }

      # name scope useprefix
      if (defined($name->get_useprefix)) {
        $useprefix = $name->get_useprefix;
      }

      # In future, perhaps there will be a need for more namepart use* options and
      # therefore $opts will come from somewhere else
      $opts->{useprefix} = $useprefix;

      # Now extract the template to use from the global hash of templates
      my $lnat = Biber::Config->getblxoption(undef, 'labelalphanametemplate')->{$lantname};

      my $preacc; # arrayref accumulator for "pre" nameparts
      my $mainacc; # arrayref accumulator for main non "pre" nameparts
      my $mpns; # arrayref accumulator for main non "pre" namepart names
      my $preopts; # arrayref accumulator for "pre" namepart options
      my $mainopts; # arrayref accumulator for main non "pre" namepart options
      foreach my $lnp ($lnat->@*) {
        my $npn = $lnp->{namepart};
        my $np;

        if ($np = $name->get_namepart($npn)) {
          if ($lnp->{use}) { # only ever defined as 1
            next unless $opts->{"use$npn"};
          }

          if ($lnp->{pre}) {
            push $preacc->@*,
              [normalise_string_label($np),
               {substring_width => $lnp->{substring_width},
                substring_side => $lnp->{substring_side},
                substring_compound => $lnp->{substring_compound}}];
          }
          else {
            push $mpns->@*, $npn;
            push $mainacc->@*,
              [normalise_string_label($np),
               {substring_width => $lnp->{substring_width},
                substring_side => $lnp->{substring_side},
                substring_compound => $lnp->{substring_compound}}];
          }
        }
      }

      push $parts->{pre}{strings}->@*, $preacc;
      push $parts->{main}{strings}->@*, $mainacc;
      push $parts->{main}{partnames}->@*, $mpns;
    }

    # Loop over names in range
    for (my $i = $nr_start-1; $i < $nr_end; $i++) {
      # Deal with pre options
      foreach my $fieldinfo ($parts->{pre}{strings}[$i]->@*) {
        my $np = $fieldinfo->[0];
        my $npo = $fieldinfo->[1];
        my $w = $npo->{substring_width} // 1;
        if ($npo->{substring_compound}) {
          my $tmpstring;
          # Splitting on tilde too as libbtparse inserts these into compound prefices
          foreach my $part (split(/[\s\p{Dash}~]+/, $np)) {
            $tmpstring .= Unicode::GCString->new($part)->substr(0, $w)->as_string;
          }
          $acc .= $tmpstring;
        }
        else {
          $acc .= Unicode::GCString->new($np)->substr(0, $w)->as_string;
        }
      }

      $acc .= _process_label_attributes($self,
                                        $citekey,
                                        $dlist,
                                        $parts->{main}{strings}[$i],
                                        $labelattrs,
                                        $realname,
                                        $parts->{main}{partnames}[$i],
                                        $i);

      # put in names sep, if any
      if (my $nsep = $labelattrs->{namessep}) {
        $acc .= $nsep unless ($i == $nr_end-1);
      }
    }

    $sortacc = $acc;

    # Add alphaothers if name list is truncated unless noalphaothers is specified
    unless ($labelattrs->{noalphaothers}) {
      if ($numnames > $nr_end or $names->get_morenames) {
        $acc .= $alphaothers // ''; # alphaothers can be undef
        $sortacc .= $sortalphaothers // ''; # sortalphaothers can be undef
      }
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

# Complicated due to various label disambiguation schemes and also due to dealing with
# name fields
sub _process_label_attributes {
  my ($self, $citekey, $dlist, $fieldstrings, $labelattrs, $field, $nameparts, $index) = @_;

  return join('', map {$_->[0]} $fieldstrings->@*) unless $labelattrs;
  my $rfield_string;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my @citekeys = $section->get_citekeys;
  my $nindex = first_index {$_ eq $citekey} @citekeys;

  foreach my $fieldinfo ($fieldstrings->@*) {
    my $field_string = $fieldinfo->[0];
    my $namepartopts = $fieldinfo->[1];

    if (defined($labelattrs->{substring_width})) {
      # dynamically disambiguated width (individual name disambiguation)
      if ($labelattrs->{substring_width} =~ /v/ and $field) {
        # Use the cache if there is one
        if (my $lcache = $section->get_labelcache_v($field)) {
          if ($logger->is_debug()) { # performance tune
            $logger->debug("Using label disambiguation cache (name) for '$field' in section $secnum");
          }
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
              if ($nameparts) { # name field
                my $nlid = $f->get_id;
                foreach my $n ($f->first_n_names($dlist->get_visible_alpha($nlid))->@*) {
                  # Do strip/nosort here as that's what we also do to the field contents
                  # we will use to look up in this hash later
                  $indices{normalise_string_label(join('',map {$n->get_namepart($_)} $nameparts->@*), $field)} = $n->get_index;
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
              push $lcache->{$map->[0]}{data}->@*, $map->[1];
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
                $lcache->{globalindices}{$s} = max grep {$is->{$ind}{$_} >= $labelattrs->{substring_fixed_threshold} } keys $is->{$ind}->%*;
              }
            }
          }

          # Use the global index override if set (substring_width =~ /f/)
          $field_string = ${$lcache->{$field_string}{data}}[$lcache->{globalindices}{$field_string} || $lcache->{$field_string}{index}];
          if ($logger->is_trace()) { # performance tune
            $logger->trace("Label disambiguation cache for '$field' " .
                           ($nameparts ? '(' . join(',', $nameparts->@*) . ') ' : '') .
                           "in section $secnum:\n " . Data::Dump::pp($lcache));
          }
          $section->set_labelcache_v($field, $lcache);
        }
      }
      # dynamically disambiguated width (list disambiguation)
      elsif ($labelattrs->{substring_width} =~ /l/ and $field) {
        # Use the cache if there is one
        if (my $lcache = $section->get_labelcache_l($field)) {
          if ($logger->is_debug()) { # performance tune
            $logger->debug("Using label disambiguation cache (list) for '$field' in section $secnum");
          }
          $field_string = $lcache->{data}[$nindex][$index];

        }
        else {
          # This retains the structure of the entries for the "l" list disambiguation
          # Have to be careful if field "$f" is not set for all entries
          my $strings = [map {my $f = $section->bibentry($_)->get_field($field);
                              $f ? ($nameparts ? [map {my $n = $_;join('', map {$n->get_namepart($_)} $nameparts->@*)} $f->first_n_names($dlist->get_visible_alpha($f->get_id))->@*] : [$f]) : [''] }
                         @citekeys];
          my $lcache = _label_listdisambiguation($strings);

          $field_string = $lcache->{data}[$nindex][$index];

          if ($logger->is_trace()) { # performance tune
            $logger->trace("Label disambiguation (list) cache for '$field' " .
                           ($nameparts ? '(' . join(',', $nameparts->@*) . ') ' : '') .
                           "in section $secnum:\n " . Data::Dump::pp($lcache));
          }
          $section->set_labelcache_l($field, $lcache);
        }
      }
      # static substring width
      else {
        my $subs_offset = 0;
        my $default_substring_width = 1;
        my $default_substring_side = 'left';
        my $padchar = $labelattrs->{pad_char};
        my $subs_side = ($labelattrs->{substring_side} or $default_substring_side);
        my $subs_width = ($labelattrs->{substring_width} or $default_substring_width);

        # Override subs width with namepart specific setting, if it exists
        if ($nameparts) {
          if (my $w = $namepartopts->{substring_width}) {
            $subs_width = $w;
          }
          if (my $s = $namepartopts->{substring_side}) {
            $subs_side = $s;
          }
        }

        # Set offset depending on subs side
        if ($subs_side eq 'right') {
          $subs_offset = 0 - $subs_width;
        }

        # Get map of regexps to not count against string width and record their place in the
        # string
        my $nolabelwcs = Biber::Config->getoption('nolabelwidthcount');
        my $nolabelwcis;
        if ($nolabelwcs) {
          $nolabelwcis = match_indices([map {$_->{value}} $nolabelwcs->@*], $field_string);
          $logger->trace('Saved indices for nolabelwidthcount: ' . Data::Dump::pp($nolabelwcis));
          # Then remove the nolabelwidthcount chars for now
          foreach my $nolabelwc ($nolabelwcs->@*) {
            my $nlwcopt = $nolabelwc->{value};
            my $re = qr/$nlwcopt/;
            $field_string =~ s/$re//gxms; # remove nolabelwidthcount items
          }
        }

        # If desired, do the substring on all parts of compound names
        # (with internal spaces or hyphens)
        if ($nameparts and $namepartopts->{substring_compound}) {
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
        if ($nolabelwcis) {
          my $gc_string = Unicode::GCString->new($field_string);
          foreach my $nolabelwci ($nolabelwcis->@*) {
            # Don't put back anything at positions which are no longer in the string
            if ($nolabelwci->[1] +1 <= $gc_string->length) {
              $gc_string->substr($nolabelwci->[1], 0, $nolabelwci->[0]);
            }
          }
          $field_string = $gc_string->as_string;
        }
      }
    }
    $rfield_string .= $field_string;
  }

  # Case changes
  if ($labelattrs->{uppercase} and
      $labelattrs->{lowercase}) {
    # do nothing if both are set, for sanity
  }
  elsif ($labelattrs->{uppercase}) {
    $rfield_string = uc($rfield_string);
  }
  elsif ($labelattrs->{lowercase}) {
    $rfield_string = lc($rfield_string);
  }

  return $rfield_string;
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
  my $cache->{substr_map} = [map {[map {1} $_->@*]} $strings->@*];
  my $lcache->{data} = [map {undef} $strings->@*];

  # First flag any duplicates so we can shortcut setting these later
  my @dups;
  for (my $i = 0; $i <= $strings->$#*; $i++) {
    $dups[$i] = join('', $strings->[$i]->@*);
  }

  _do_substr($lcache, $cache, $strings);

  # loop until the entire disambiguation cache is filled.
  while (grep { !defined } $lcache->{data}->@*) {
    _check_counts($lcache, $cache);
    foreach my $ambiguous_indices ($cache->{ambiguity}->@*) {
      my $ambiguous_strings = [$strings->@[$ambiguous_indices->@*]]; # slice
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
      if (all {Compare($ambiguous_strings->[0], $_)} $ambiguous_strings->@*) {
        $lcache->{data}[$ambiguous_indices->[0]] =  [map {Unicode::GCString->new($_)->substr(0,1)->as_string} $ambiguous_strings->[0]->@*];
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
  for (my $i = 0; $i <= $strings->$#*; $i++) {
    next if defined($lcache->{data}[$i]); # ignore names already disambiguated
    my $row = $strings->[$i];
    my @s;
    for (my $j = 0; $j <= $row->$#*; $j++) {
      push @s, Unicode::GCString->new($row->[$j])->substr(0 ,$cache->{substr_map}[$i][$j])->as_string;
    }
    my $js = join('', @s);
    $cache->{keys}{$js}{index} = $i; # index of the last seen $js key - useless for count >1
    push $cache->{keys}{$js}{indices}->@*, $i;
    $cache->{keys}{$js}{count}++;
    $cache->{keys}{$js}{strings} = \@s;
  }
}

# Push finished disambiguation into results and save still ambiguous labels for loop
sub _check_counts {
  my ($lcache, $cache) = @_;
  delete($cache->{ambiguity});
  foreach my $key (keys $cache->{keys}->%*) {
    if ($cache->{keys}{$key}{count} > 1) {
      push $cache->{ambiguity}->@*, $cache->{keys}{$key}{indices};
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
  for (my $i = 0; $i <= $array->$#*; $i++) {
    my @check_array = $array->@*;
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
# extradate
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
                                 'citecount'       =>  [\&_sort_citecount,     []],
                                 'intciteorder'    =>  [\&_sort_intciteorder,  []],
                                 'labelalpha'      =>  [\&_sort_labelalpha,    []],
                                 'labelname'       =>  [\&_sort_labelname,     []],
                                 'labeltitle'      =>  [\&_sort_labeltitle,    []],
                                 'labelyear'       =>  [\&_sort_labeldate,     ['year']],
                                 'labelmonth'      =>  [\&_sort_labeldate,     ['month']],
                                 'labelday'        =>  [\&_sort_labeldate,     ['day']],
                                 'presort'         =>  [\&_sort_presort,       []],
                                 'sortname'        =>  [\&_sort_sortname,      []],
                                 'entrytype'       =>  [\&_sort_entrytype,     []],
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
  my $dmf = $dm->get_dm_for_field($field);
  if ($dmf->{fieldtype} eq 'list' and $dmf->{datatype} eq 'name') {
    return [\&_sort_name, [$field]];
  }
  elsif ($dmf->{datatype} eq 'verbatim' or $dmf->{datatype} eq 'uri') {
    return [\&_sort_verbatim, [$field]];
  }
  elsif ($dmf->{fieldtype} eq 'field' and $dmf->{datatype} eq 'literal' ) {
    return [\&_sort_literal, [$field]];
  }
  elsif ($dmf->{fieldtype} eq 'field' and
         ($dmf->{datatype} eq 'integer' or $dmf->{datatype} eq 'datepart')) {
    return [\&_sort_integer, [$field]];
  }
  elsif ($dmf->{fieldtype} eq 'list' and
         ($dmf->{datatype} eq 'literal' or $dmf->{datatype} eq 'key')) {
    return [\&_sort_list, [$field]];
  }
  elsif ($dmf->{fieldtype} eq 'list' and
         ($dmf->{datatype} eq 'verbatim' or $dmf->{datatype} eq 'uri')) {
    return [\&_sort_list_verbatim, [$field]];
  }
  elsif ($dmf->{fieldtype} eq 'field' and $dmf->{datatype} eq 'key') {
    return [\&_sort_literal, [$field]];
  }
}

# Main sorting dispatch method
sub _dispatch_sorting {
  my ($self, $sortfield, $citekey, $secnum, $section, $be, $dlist, $sortelementattributes) = @_;
  my $code_ref;
  my $code_args_ref;
  my $dm = Biber::Config->get_dm;

  # If this field is excluded from sorting for this entrytype, then skip it and return
  if (my $se = Biber::Config->getblxoption(undef, 'sortexclusion', $be->get_field('entrytype'))) {
    if ($se->{$sortfield}) {
      return '';
    }
  }
  # If this field is excluded from sorting for all entrytypes, then include it if it's
  # explicitly included
  if (my $se = Biber::Config->getblxoption(undef, 'sortexclusion', '*')) {
    if ($se->{$sortfield}) {
      if (my $si = Biber::Config->getblxoption(undef, 'sortinclusion', $be->get_field('entrytype'))) {
        unless ($si->{$sortfield}) {
          return '';
        }
      }
      else {
        return '';
      }
    }
  }

  # if the field is a literal string, use it
  if ($sortelementattributes->{literal}) {
    $code_ref = \&_sort_string;
    $code_args_ref = [$sortfield];
  }
  # real sorting field
  elsif (my $d = _dispatch_table_sorting($sortfield, $dm)) {
    $code_ref = $d->[0];
    $code_args_ref  = $d->[1];
  }
  else { # Unknown field
    biber_warn("Field '$sortfield' in sorting template is not a sortable field");
    return undef;
  }

  return &{$code_ref}($self, $citekey, $secnum, $section, $be, $dlist, $sortelementattributes, $code_args_ref);
}

# Conjunctive set of sorting sets
sub _generatesortinfo {
  my ($self, $citekey, $dlist) = @_;
  my $sortingtemplate = $dlist->get_sortingtemplate;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $sortobj;
  my $szero = 0;

  $BIBER_SORT_NULL = 0;
  $BIBER_SORT_FINAL = '';
  $BIBER_SUPPRESS_FINAL = 1;

  foreach my $sortset ($sortingtemplate->{spec}->@*) {
    my $s = $self->_sortset($sortset, $citekey, $secnum, $section, $be, $dlist);

    # Did we get a real zero? This messes up tests below unless we are careful
    # Don't try and make this more implicit, it is too subtle a problem
    if ($s eq 'BIBERZERO') {
      $szero = 1;
      $s = 0;
    }

    # We have already found a "final" item so if this item returns null,
    # copy in the "final" item string as it's the master key for this entry now
    # (but suppress this when the final item is found so that entries without
    #  the final item don't always sort before entries with the final item)
    # This means that final items are always blank in all sort keys across all entries
    # and so have no impact until later sort items where the final item becomes the
    # sorting key for every subsequent sorting item.
    if (my $f = $BIBER_SORT_FINAL) {
      push $sortobj->@*, ($BIBER_SUPPRESS_FINAL ? '' : $f);
      $BIBER_SUPPRESS_FINAL = 0;
    }
    else {
      push $sortobj->@*, $s;
    }
  }

  # Record the information needed for sorting later
  # sortstring isn't actually used to sort, it's used to generate sortinit and
  # for debugging purposes
  my $ss = join($sorting_sep, $sortobj->@*);
  $dlist->set_sortdata($citekey, [$ss, $sortobj]);
  if ($logger->is_debug()) { # performance shortcut
    $logger->debug("Sorting object for key '$citekey' -> " . Data::Dump::pp($sortobj));
  }

  # Generate sortinit. Skip if there is no sortstring, which is possible in tests
  if ($ss or $szero) {
    # This must ignore the presort characters, naturally
    my $pre = Biber::Config->getblxoption($secnum, 'presort', $be->get_field('entrytype'), $citekey);

    # Strip off the prefix
    $ss =~ s/\A$pre$sorting_sep+//;
    my $init = Unicode::GCString->new(normalise_string($ss))->substr(0, 1)->as_string;
    $dlist->set_sortinitdata_for_key($citekey, $init);
  }
  return;
}

# Process sorting set
sub _sortset {
  my ($self, $sortset, $citekey, $secnum, $section, $be, $dlist) = @_;
  my $dm = Biber::Config->get_dm;
  foreach my $sortelement ($sortset->@[1..$sortset->$#*]) {
    my ($sortelementname, $sortelementattributes) = %$sortelement;
    $BIBER_SORT_NULL = 0; # reset this per sortset
    my $out = $self->_dispatch_sorting($sortelementname, $citekey, $secnum, $section, $be, $dlist, $sortelementattributes);
    if ($out) { # sort returns something for this key
      if ($sortset->[0]{final}) {
        # If we encounter a "final" element, we return an empty sort
        # string and save the string so it can be copied into all further
        # fields as this is now the master sort key. We use an empty string
        # where we found it in order to preserve sort field order and so
        # that we sort correctly against all other entries without a value
        # for this "final" field
        $BIBER_SORT_FINAL = $out;
        last;
      }
      return $out;
    }
  }
  $BIBER_SORT_NULL = 1; # set null flag - need this to deal with some cases
  return '';
}

##############################################
# Sort dispatch routines
##############################################

sub _sort_citeorder {
  my ($self, $citekey, $secnum, $section, $be, $dlist, $sortelementattributes) = @_;
  # Allkeys and sorting=none means use bib order which is in orig_order_citekeys
  # However, someone might do:
  # \cite{b}\cite{a}
  # \nocite{*}
  # in the same section which means we need to use the order attribute for those
  # keys which have one (the \cited keys) and then an orig_order_citekey index based index
  # for the nocite ones.
  my $ko = Biber::Config->get_keyorder($secnum, $citekey);# only for \cited keys
  if ($section->is_allkeys) {
    my $biborder = (Biber::Config->get_keyorder_max($secnum) +
                    (first_index {$_ eq $citekey} $section->get_orig_order_citekeys) + 1);
    my $allkeysorder = Biber::Config->get_keyorder($secnum, '*');
    if (defined($ko) and defined($allkeysorder) and $allkeysorder < $ko) {
      return $biborder;
    }
    else {
      return $ko || $biborder;
    }
  }
  # otherwise, we need to take account of citations with simulataneous order like
  # \cite{key1, key2} so this tied sorting order can be further sorted with other fields
  # Note the fallback of '' - this is for auto-generated entries which are not cited
  # and so never have a keyorder entry
  else {
    return $ko || '';
  }
}

sub _sort_citecount {
  my ($self, $citekey, $secnum, $section, $be, $dlist, $sortelementattributes) = @_;
  return $section->get_citecount($citekey) // '';
}

sub _sort_integer {
  my ($self, $citekey, $secnum, $section, $be, $dlist, $sortelementattributes, $args) = @_;
  my $dmtype = $args->[0]; # get int field type
  my $bee = $be->get_field('entrytype');
  if (my $field = $be->get_field($dmtype)) {

    # Make an attempt to map roman numerals to integers for sorting unless suppressed
    if (isroman(NFKD($field)) and
        not Biber::Config->getblxoption($secnum, 'noroman', $be->get_field('entrytype'), $citekey)) {
      $field = roman2int(NFKD($field));
    }

    # Use Unicode::UCD::num() to map Unicode numbers to integers if possible
    $field = num($field) // $field;

    return _process_sort_attributes($field, $sortelementattributes);
  }
  else {
    return '';
  }
}

sub _sort_editort {
  my ($self, $citekey, $secnum, $section, $be, $dlist, $sortelementattributes, $args) = @_;
  my $edtypeclass = $args->[0]; # get editor type/class field
  if (Biber::Config->getblxoption($secnum, 'useeditor', $be->get_field('entrytype'), $citekey) and
    $be->get_field($edtypeclass)) {
    my $string = $be->get_field($edtypeclass);
    return _translit($edtypeclass, $be, _process_sort_attributes($string, $sortelementattributes));
  }
  else {
    return '';
  }
}

sub _sort_entrykey {
  my ($self, $citekey, $secnum, $section, $be, $dlist, $sortelementattributes) = @_;
  return _process_sort_attributes($citekey, $sortelementattributes);
}

sub _sort_entrytype {
  my ($self, $citekey, $secnum, $section, $be, $dlist, $sortelementattributes) = @_;
  return _process_sort_attributes($be->get_field('entrytype'), $sortelementattributes);
}

sub _sort_intciteorder {
  my ($self, $citekey, $secnum, $section, $be, $dlist, $sortelementattributes) = @_;
  return Biber::Config->get_internal_keyorder($secnum, $citekey);
}

sub _sort_labelalpha {
  my ($self, $citekey, $secnum, $section, $be, $dlist, $sortelementattributes, $args) = @_;
  my $string = $dlist->get_entryfield($citekey, 'sortlabelalpha') // '';
  return _process_sort_attributes($string, $sortelementattributes);
}

sub _sort_labelname {
  my ($self, $citekey, $secnum, $section, $be, $dlist, $sortelementattributes, $args) = @_;
  # re-direct to the right sorting routine for the labelname
  if (my $lni = $be->get_labelname_info) {
    # Don't process attributes as they will be processed in the real sub
    return $self->_dispatch_sorting($lni, $citekey, $secnum, $section, $be, $dlist, $sortelementattributes);
  }
  else {
    return '';
  }
}

sub _sort_labeltitle {
  my ($self, $citekey, $secnum, $section, $be, $dlist, $sortelementattributes, $args) = @_;
  # re-direct to the right sorting routine for the labeltitle
  if (my $lti = $be->get_labeltitle_info) {
    # Don't process attributes as they will be processed in the real sub
    return $self->_dispatch_sorting($lti, $citekey, $secnum, $section, $be, $dlist, $sortelementattributes);
  }
  else {
    return '';
  }
}

sub _sort_labeldate {
  no autovivification;
  my ($self, $citekey, $secnum, $section, $be, $dlist, $sortelementattributes, $args) = @_;
  my $ldc = $args->[0]; # labeldate component
  # re-direct to the right sorting routine for the labeldate component
  if (my $ldi = $be->get_labeldate_info) {
    if (my $ldf = $ldi->{field}{$ldc}) {
      # Don't process attributes as they will be processed in the real sub
      return $self->_dispatch_sorting($ldf, $citekey, $secnum, $section, $be, $dlist, $sortelementattributes);
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
  my ($self, $citekey, $secnum, $section, $be, $dlist, $sortelementattributes, $args) = @_;
  my $list = $args->[0]; # get list field
  if ($be->get_field($list)) {
    my $string = $self->_liststring($citekey, $list);
    return _translit($list, $be, _process_sort_attributes($string, $sortelementattributes));
  }
  else {
    return '';
  }
}

# This is a meta-sub which uses the optional arguments to the dispatch code
# It's done to avoid having many repetitions of almost identical sorting code
sub _sort_list_verbatim {
  my ($self, $citekey, $secnum, $section, $be, $dlist, $sortelementattributes, $args) = @_;
  my $list = $args->[0]; # get list field
  if ($be->get_field($list)) {
    my $string = $self->_liststring($citekey, $list, 1);
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
  my ($self, $citekey, $secnum, $section, $be, $dlist, $sortelementattributes, $args) = @_;
  my $literal = $args->[0]; # get actual field
  if (my $field = $be->get_field($literal)) {
    my $string = normalise_string_sort($field, $literal);
    return _translit($literal, $be, _process_sort_attributes($string, $sortelementattributes));
  }
  else {
    return '';
  }
}

# This is a meta-sub which uses the optional arguments to the dispatch code
# It's done to avoid having many repetitions of almost identical sorting code
# for literal strings which need no normalising/translit. Nosort is still honoured.
sub _sort_verbatim {
  my ($self, $citekey, $secnum, $section, $be, $dlist, $sortelementattributes, $args) = @_;
  my $literal = $args->[0]; # get actual field
  if (my $field = $be->get_field($literal)) {
    my $string = strip_nosort($field, $literal);
    return _process_sort_attributes($field, $sortelementattributes);
  }
  else {
    return '';
  }
}

# This is a meta-sub which uses the optional arguments to the dispatch code
# It's done to avoid having many repetitions of almost identical sorting code
# for the editor roles
sub _sort_name {
  my ($self, $citekey, $secnum, $section, $be, $dlist, $sortelementattributes, $args) = @_;
  my $name = $args->[0]; # get name field name
  # If there is a biblatex option which controls the use of this name, check it
  if ($CONFIG_OPTSCOPE_BIBLATEX{"use$name"} and
      not Biber::Config->getblxoption($secnum, "use$name", $be->get_field('entrytype'), $citekey)) {
    return '';
    }
  if ($be->get_field($name)) {
    my $string = $self->_namestring($citekey, $name, $dlist);
    return _translit($name, $be, _process_sort_attributes($string, $sortelementattributes));
  }
  else {
    return '';
  }
}

sub _sort_presort {
  my ($self, $citekey, $secnum, $section, $be, $dlist, $sortelementattributes) = @_;
  my $string = Biber::Config->getblxoption($secnum, 'presort', $be->get_field('entrytype'), $citekey);
  return _process_sort_attributes($string, $sortelementattributes);
}

sub _sort_sortname {
  my ($self, $citekey, $secnum, $section, $be, $dlist, $sortelementattributes) = @_;
  my $dm = Biber::Config->get_dm;

  # sortname is ignored if no use<name> option is defined - see biblatex manual
  if ($be->get_field('sortname') and
      grep {Biber::Config->getblxoption($secnum, "use$_", $be->get_field('entrytype'), $citekey)} $dm->get_fields_of_type('list', 'name')->@*) {
    my $string = $self->_namestring($citekey, 'sortname', $dlist);
    return _translit('sortname', $be, _process_sort_attributes($string, $sortelementattributes));
  }
  else {
    return '';
  }
}

sub _sort_string {
  my ($self, $citekey, $secnum, $section, $be, $dlist, $sortelementattributes, $args) = @_;
  my $string = $args->[0]; # get literal string
  return _process_sort_attributes($string, $sortelementattributes);
}

#========================================================
# Utility subs used elsewhere but relying on sorting code
#========================================================

sub _process_sort_attributes {
  my ($field_string, $sortelementattributes) = @_;
  return 'BIBERZERO' if $field_string eq '0'; # preserve real zeros
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
  my ($citekey, $field, $dlist) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');
  my $names = $be->get_field($field);
  my $str = '';
  my $count = $names->count;
  my $useprefix = Biber::Config->getblxoption($secnum, 'useprefix', $bee, $citekey);

  # Get the sorting name key template for this list context
  my $snkname = $dlist->get_sortingnamekeytemplatename;

  # Override with any entry-specific sorting name key template option
  $snkname = Biber::Config->getblxoption($secnum, 'sortingnamekeytemplatename', undef, $citekey) // $snkname;

  # Override with any namelist scope sorting name key template option
  $snkname = $names->get_sortingnamekeytemplatename // $snkname;

  # Get the sorting namekey template determined so far now that we are down to the name list
  # scope since we need the visibility type now and this doesn't mean anything below the name list
  # level anyway. We will select the final sorting namekey template below if there is an override
  # at the individual name level
  my $tmpsnk = Biber::Config->getblxoption(undef, 'sortingnamekeytemplate')->{$snkname};
  # Now set visibility of the correct type. By default this is the standard
  # sorting visibility but can be citation visibility as the biblatex
  # "sortcites" option can require a different visibility for citations and
  # so we have to generate a separate sorting list for this case
  my $visible = $dlist->get_visible_sort($names->get_id);
  if (defined($tmpsnk) and $tmpsnk->{visibility} eq 'cite') {
    $visible = $dlist->get_visible_cite($names->get_id);
  }

  # Name list scope useprefix option
  if (defined($names->get_useprefix)) {
    $useprefix = $names->get_useprefix;
  }

  my $trunc = "\x{10FFFD}";  # sort string for "et al" truncated name

  foreach my $n ($names->first_n_names($visible)->@*) {

    # Name scope useprefix option
    if (defined($n->get_useprefix)) {
      $useprefix = $n->get_useprefix;
    }

    # Override with any name scope sorting name key template option
    # This won't override the visibility type selection already taken from higher-level
    # sorting namekey templates since this option only applies at name list level and higher
    # anyway and this is individual name scope
    $snkname = $n->get_sortingnamekeytemplatename // $snkname;

    # Now get the actual sorting name key template
    my $snk = Biber::Config->getblxoption(undef, 'sortingnamekeytemplate')->{$snkname};

    # Get the sorting name key specification and use it to construct a sorting key for each name
    my $kpa = [];
    foreach my $kp ($snk->{template}->@*) {
      my $kps = '';
      for (my $i=0; $i<=$kp->$#*; $i++) {
        my $np = $kp->[$i];
        if ($np->{type} eq 'namepart') {
          my $namepart = $np->{value};
          my $useopt = exists($np->{use}) ? "use$namepart" : undef;
          my $useoptval = Biber::Config->getblxoption($secnum, $useopt, $bee, $citekey);

          # useprefix can be name list or name local
          if ($useopt and $useopt eq 'useprefix') {
            $useoptval = map_boolean('useprefix', $useprefix, 'tonum');
          }

          if (my $npstring = $n->get_namepart($namepart)) {
            # No use attribute conditionals or the attribute is specified and matches the option

            if (not $useopt or
                ($useopt and $useoptval == $np->{use})) {

              my $nps = '';
              # Do we only want initials for sorting?
              if ($np->{inits}) {
                my $npistring = $n->get_namepart_initial($namepart);

                # The namepart is padded to the longest namepart in the ref
                # section as this is the only way to make sorting work
                # properly. The padding is spaces as this sorts before all
                # glyphs but it also of variable weight and ignorable in
                # DUCET so we have to set U::C to variable=>'non-ignorable'
                # as sorting default so that spaces are non-ignorable
                $nps = normalise_string_sort(join('', $npistring->@*), $field);

                # pad all nameparts
                $nps = sprintf("%-*s", $section->get_np_length("${namepart}-i"), $nps);
              }
              else {
                $nps = normalise_string_sort($npstring, $field);

                # pad all nameparts
                $nps = sprintf("%-*s", $section->get_np_length($namepart), $nps);
              }
              $kps .= $nps;
            }
          }
        }
        elsif ($np->{type} eq 'literal') {
          $kps .= $np->{value};
        }
      }
      # Now append the key part string if the string is not empty
      $str .= $kps if $kps;
      push $kpa->@*, $kps;
    }
  }

  my $nso = Biber::Config->getblxoption($secnum, 'nosortothers', $bee, $citekey);

  # Per-namelist nosortothers
  if (defined($names->get_nosortothers)) {
    $nso = $names->get_nosortothers;
  }

  unless ($nso) {
    $str .= $trunc if $visible < $count; # name list was truncated
  }

  return $str;

}

sub _liststring {
  my ($self, $citekey, $field, $verbatim) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $bee = $be->get_field('entrytype');
  my $f = $be->get_field($field); # _liststring is used in tests so there has to be
  return '' unless defined($f);   # more error checking which will never be needed in normal use
  my @items = $f->@*;
  my $str = '';
  my $truncated = 0;

  # These should be symbols which can't appear in lists and which sort before all alphanum
  # so that "Alan Smith" sorts after "Al Smith". This means, symbols which normalise_string_sort()
  # strips out. Unfortuately, this means using punctuation and these are by default variable
  # weight and ignorable in DUCET so we have to redefine these these symbols after loading DUCET
  # when sorting so that they are non-ignorable (see Biber.pm)
  my $lsi    = '!';          # list separator, internal
  # Guaranteed to sort after everything else as it's the last legal Unicode code point
  my $trunc = "\x{10FFFD}";  # sort string for truncated list

  # perform truncation according to options minitems, maxitems
  if ( $#items + 1 > Biber::Config->getblxoption($secnum, 'maxitems', $bee, $citekey) ) {
    $truncated = 1;
    @items = splice(@items, 0, Biber::Config->getblxoption($secnum, 'minitems', $bee, $citekey) );
  }

  # separate the items by a string to give some structure
  # We strip nosort first otherwise normalise_string_sort damages diacritics
  # We strip each individual component instead of the whole thing so we can use
  # as name separators things which would otherwise be stripped. This way we
  # guarantee that the separators are never in names
  if ($verbatim) { # no normalisation for verbatim/uri fields
    $str = join($lsi, map { strip_nosort($_, $field)} @items);
  }
  else {
    $str = join($lsi, map { normalise_string_sort($_, $field)} @items);
  }

  $str =~ s/\s+\z//xms;
  $str .= $trunc if $truncated;
  return $str;
}

# transliterate if requested
sub _translit {
  my ($target, $entry, $string) = @_;
  my $entrytype = $entry->get_field('entrytype');
  if (my $translits = Biber::Config->getblxoption(undef, 'translit', $entrytype)) {
    foreach my $tr ($translits->@*) {
      # Translit is specific to particular langids
      if (defined($tr->{langids})) {
        next unless my $langid = $entry->get_field('langid');
        unless (first {fc($langid) eq fc($_)} split(/\s*,\s*/, $tr->{langids})) {
          next;
        }
      }
      if (lc($tr->{target}) eq '*' or
          $tr->{target} eq $target or
          first {$target eq $_} $DATAFIELD_SETS{$tr->{target}}->@*) {
        return call_transliterator($target, $tr->{from}, $tr->{to}, $string);
      }
    }
  }
  return $string;
}

1;

__END__

=head1 AUTHOR

Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our Github tracker at
L<https://github.com/plk/biber/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2012 François Charette and Philip Kime, all rights reserved.
Copyright 2012-2024 Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
