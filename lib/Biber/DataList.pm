package Biber::DataList;
use v5.24;
use strict;
use warnings;

use Biber::Utils;
use Biber::Constants;
use Data::Compare;
use Digest::MD5 qw( md5_hex );
use List::Util qw( first );

=encoding utf-8

=head1 NAME

Biber::DataList - Biber::DataList objects

=head2 new

    Initialize a Biber::DataList object

=cut

sub new {
  my ($class, %params) = @_;
  my $self = bless {%params}, $class;
  return $self;
}


=head2 set_section

    Sets the section of a data list

=cut

sub set_section {
  my $self = shift;
  my $section = shift;
  $self->{section} = lc($section);
  return;
}

=head2 get_section

    Gets the section of a data list

=cut

sub get_section {
  my $self = shift;
  return $self->{section};
}

=head2 reset_state

    Resets all state data. Used mainly in tests which call Biber::prepare()
    multiple times without re-creating datalists

=cut

sub reset_state {
  shift->{state} = {};
  return;
}


=head2 incr_seenpa

    Increment the count of occurrences of a primary author base name
    if it has a different non-base part. How many variants of the basename
    are there in the dlist?

=cut

sub incr_seenpa {
  my ($self, $base, $hash) = @_;
  $self->{state}{seenpa}{$base}{$hash} = 1; # increment the number of base variants
  return;
}


=head2 get_seenpa

    Get the count of unique (i.e. with different hash) occurrences of a primary
    author base name

=cut

sub get_seenpa {
  my ($self, $base) = @_;
  return scalar keys %{$self->{state}{seenpa}{$base}};
}

=head2 reset_entryfields

    Resets all entryfield data in a list

=cut

sub reset_entryfields {
  my $self = shift;
  $self->{state}{fields} = {};
  return;
}


=head2 get_entryfield

    Retrieves per-list datafield information for an entry

=cut

sub get_entryfield {
  my ($self, $citekey, $f) = @_;
  return $self->{state}{fields}{$citekey}{$f};
}

=head2 set_entryfield

    Records per-list datafield information for an entry

=cut

sub set_entryfield {
  my ($self, $citekey, $f, $v) = @_;
  $self->{state}{fields}{$citekey}{$f} = $v;
  return;
}

=head2 add_uniquenamecount

    Add a name to the list of name contexts which have the name in it
    (only called for visible names)

=cut

sub add_uniquenamecount {
  my ($self, $name, $namecontext, $key) = @_;
  $self->{state}{uniquenamecount}{$name}{$namecontext}{$key}++;
  return;
}

=head2 add_uniquenamecount_all

    Add a name to the list of name contexts which have the name in it
    (called for all names)

=cut

sub add_uniquenamecount_all {
  my ($self, $name, $namecontext, $key) = @_;
  $self->{state}{uniquenamecount_all}{$name}{$namecontext}{$key}++;
  return;
}


=head2 get_uniquelistcount

    Get the number of uniquelist entries for a (possibly partial) list

=cut

sub get_uniquelistcount {
  my ($self, $namelist) = @_;
  return $self->{state}{uniquelistcount}{global}{join("\x{10FFFD}", $namelist->@*)};
}

=head2 add_uniquelistcount

    Increment the count for a list part to the data for a name

=cut

sub add_uniquelistcount {
  my ($self, $namelist) = @_;
  $self->{state}{uniquelistcount}{global}{join("\x{10FFFD}", $namelist->@*)}++;
  return;
}


=head2 add_uniquelistcount_final

    Increment the count for a complete list to the data for a name

=cut

sub add_uniquelistcount_final {
  my ($self, $namelist, $labelyear) = @_;
  $self->{state}{uniquelistcount}{global}{final}{join("\x{10FFFD}", $namelist->@*)}++;
  if ($labelyear) { # uniquelist=minyear
    $self->{state}{uniquelistcount}{global}{final}{$labelyear}{join("\x{10FFFD}", $namelist->@*)}++;
  }
  return;
}


=head2 add_uniquelistcount_minyear

    Increment the count for a list and year for a name
    Used to track uniquelist = minyear

=cut

sub add_uniquelistcount_minyear {
  my ($self, $minyearnamelist, $year, $namelist) = @_;
  # Allow year a default in case labelyear is undef
  $self->{state}{uniquelistcount}{minyear}{join("\x{10FFFD}", $minyearnamelist->@*)}{$year // '0'}{join("\x{10FFFD}", $namelist->@*)}++;
  return;
}

=head2 get_uniquelistcount_minyear

    Get the count for a list and year for a name
    Used to track uniquelist = minyear

=cut

sub get_uniquelistcount_minyear {
  my ($self, $minyearnamelist, $year) = @_;
  return scalar keys $self->{state}{uniquelistcount}{minyear}{join("\x{10FFFD}", $minyearnamelist->@*)}{$year // '0'}->%*;
}

=head2 get_uniquelistcount_final

    Get the number of uniquelist entries for a full list

=cut

sub get_uniquelistcount_final {
  my ($self, $namelist) = @_;
  my $c = $self->{state}{uniquelistcount}{global}{final}{join("\x{10FFFD}", $namelist->@*)};
  return $c // 0;
}




=head2 reset_uniquelistcount

    Reset the count for list parts and complete lists

=cut

sub reset_uniquelistcount {
  my $self = shift;
  $self->{state}{uniquelistcount} = {};
  return;
}


=head2 reset_uniquenamecount

    Reset the list of names which have the name part in it

=cut

sub reset_uniquenamecount {
  my $self = shift;
  $self->{state}{uniquenamecount} = {};
  $self->{state}{uniquenamecount_all} = {};
  return;
}

=head2 get_basenamestring

  Get a basenamestring for a particular name

=cut

sub get_basenamestring {
  my ($self, $nlid, $nid) = @_;
  return $self->{state}{namelistdata}{$nlid}{$nid}{basenamestring};
}

=head2 get_namestring

  Get a namestring for a particular name

=cut

sub get_namestring {
  my ($self, $nlid, $nid) = @_;
  return $self->{state}{namelistdata}{$nlid}{$nid}{namestring};
}

=head2 get_namestrings

  Get namestrings for a particular name

=cut

sub get_namestrings {
  my ($self, $nlid, $nid) = @_;
  return $self->{state}{namelistdata}{$nlid}{$nid}{namestrings};
}


=head2 set_namedis

  Set name disambiguation metadata

=cut

sub set_namedis {
  my ($self, $nlid, $nid, $ns, $nss, $nds) = @_;
  $self->{state}{namelistdata}{$nlid}{$nid}{namestring} = $ns;
  $self->{state}{namelistdata}{$nlid}{$nid}{namestrings} = $nss;

  for (my $i=0;$i<=$nds->$#*;$i++) {
    my $se = $nds->[$i];
    # make these explicit for faster lookup since they are static
    if ($se->[0] eq 'base') {
      $self->{state}{namelistdata}{$nlid}{$nid}{basenamestring} = $nss->[$i];
      $self->{state}{namelistdata}{$nlid}{$nid}{basenamestringparts} = $se->[1];
      last;
    }
  }

  $self->{state}{namelistdata}{$nlid}{$nid}{namedisschema} = $nds;
  return;
}

=head2 is_unbasepart

  Return boolean to say if a namepart is a base part according to
  template which created the information

=cut

sub is_unbasepart {
  my ($self, $nlid, $nid, $np) = @_;
  if (first {$_ eq $np} $self->{state}{namelistdata}{$nlid}{$nid}{basenamestringparts}->@*) {
    return 1;
  }
  else {
    return 0;
  }
}


=head2 get_namehash

  Get hash for a name

=cut

sub get_namehash {
  my ($self, $nlid, $nid) = @_;
  return $self->{state}{namelistdata}{$nlid}{$nid}{hash};
}

=head2 set_namehash

  Set hash for a name

=cut

sub set_namehash {
  my ($self, $nlid, $nid, $s) = @_;
  $self->{state}{namelistdata}{$nlid}{$nid}{hash} = $s;
  return;
}


=head2 get_unmininfo

  Get uniquename minimalness info for a name

=cut

sub get_unmininfo {
  my ($self, $nlid, $nid) = @_;
  return $self->{state}{namelistdata}{$nlid}{$nid}{unmininfo};
}

=head2 set_unmininfo

  Set uniquename minimalness info for a name

=cut

sub set_unmininfo {
  my ($self, $nlid, $nid, $s) = @_;
  $self->{state}{namelistdata}{$nlid}{$nid}{unmininfo} = $s;
  return;
}


=head2 get_namedisschema

  Get a name disambiguation schema for a name

=cut

sub get_namedisschema {
  my ($self, $nlid, $nid) = @_;
  return $self->{state}{namelistdata}{$nlid}{$nid}{namedisschema};
}


=head2 get_unsummary

  Get legacy uniquename summary for a name

=cut

sub get_unsummary {
  my ($self, $nlid, $nid) = @_;
  my $un = $self->{state}{namelistdata}{$nlid}{$nid}{un};
  return undef unless defined($un);
  if ($un->[1] eq 'none' or $un->[0] eq 'base') {
    return 0;
  }
  elsif ($un->[1] eq 'init') {
    return 1;
  }
  elsif ($un->[1] eq 'full' or $un->[1] eq 'fullonly') {
    return 2;
  }
  return 0;
}

=head2 get_unpart

  Get uniquename summary part for a name

=cut

sub get_unpart {
  my ($self, $nlid, $nid) = @_;
  my $un = $self->{state}{namelistdata}{$nlid}{$nid}{un};
  return undef unless defined($un);
  return $un->[0]
}

=head2 get_unparts

  Get uniquename parts for a name

=cut

sub get_unparts {
  my ($self, $nlid, $nid, $np) = @_;
  return $self->{state}{namelistdata}{$nlid}{$nid}{unparts}{$np};
}

=head2 set_unparts

  Set uniquename parts for a name

=cut

sub set_unparts {
  my ($self, $nlid, $nid, $np, $s) = @_;
  $self->{state}{namelistdata}{$nlid}{$nid}{unparts}{$np} = $s;
  return;
}



=head2 _get_uniquename

    Get the list of name contexts which contain a name
    Mainly for use in tests

=cut

sub _get_uniquename {
  my ($self, $name, $namecontext) = @_;
  my @list = sort keys $self->{state}{uniquenamecount}{$name}{$namecontext}->%*;
  return \@list;
}


=head2 get_uniquename

  Get uniquename for a name

=cut

sub get_uniquename {
  my ($self, $nlid, $nid) = @_;
  return $self->{state}{namelistdata}{$nlid}{$nid}{un};
}

=head2 set_uniquename

  Set uniquename for a name

=cut

sub set_uniquename {
  my ($self, $nlid, $nid, $s) = @_;

  my $currval = $self->{state}{namelistdata}{$nlid}{$nid}{un};
  # Set modified flag to positive if we changed something
  if (not defined($currval) or not Compare($currval, $s)) {
    $self->set_unul_changed(1);
  }
  $self->{state}{namelistdata}{$nlid}{$nid}{un} = $s;
  return;
}

=head2 reset_uniquename

  Reset uniquename for a name

=cut

sub reset_uniquename {
  my ($self, $nlid, $nid) = @_;
  $self->{state}{namelistdata}{$nlid}{$nid}{un} = ['base', $self->{state}{namelistdata}{$nlid}{$nid}{basenamestringparts}];
  return;
}

=head2 get_uniquename_all

  Get uniquename for a name, regardless of visibility

=cut

sub get_uniquename_all {
  my ($self, $nlid, $nid) = @_;
  return $self->{state}{namelistdata}{$nlid}{$nid}{unall};
}

=head2 set_uniquename_all

  Set uniquename for a name, regardless of visibility

=cut

sub set_uniquename_all {
  my ($self, $nlid, $nid, $s) = @_;
  $self->{state}{namelistdata}{$nlid}{$nid}{unall} = $s;
  return;
}




=head2 count_uniquelist

    Count the names in a string used to determine uniquelist.

=cut

sub count_uniquelist {
  my ($self, $namelist) = @_;
  return $namelist->$#* + 1;
}

=head2 get_uniquelist

  Gets a uniquelist setting for a namelist

=cut

sub get_uniquelist {
  my ($self, $nlid) = @_;
  return $self->{state}{namelistdata}{$nlid}{ul};
}

=head2 set_uniquelist

  Sets a uniquelist setting for a namelist

=cut

sub set_uniquelist {
  # $nl is the namelist object
  # $namelist is the extracted string concatenation from $nl which forms the tracking key
  my ($self, $nl, $namelist, $labelyear, $ul, $maxcn, $mincn) = @_;
  my $nlid = $nl->get_id;
  my $uniquelist = $self->count_uniquelist($namelist);
  my $num_names = $nl->count;
  my $currval = $self->{state}{namelistdata}{$nlid}{ul};

  # Set modified flag to positive if we changed something
  if (not defined($currval) or $currval != $uniquelist) {
    $self->set_unul_changed(1);
  }

  # Special case $uniquelist <=1 is meaningless
  return if $uniquelist <= 1;

  # Don't set uniquelist unless the list is longer than maxcitenames as it was therefore
  # never truncated to mincitenames in the first place and uniquelist is a "local mincitenames"
  return unless $num_names > $maxcn;

  # No disambiguation needed if uniquelist is <= mincitenames as this makes no sense
  # since it implies that disambiguation beyond mincitenames was needed.
  # This doesn't apply when the list length is mincitenames as maxmanes therefore
  # (since it can't be less than mincitenames) could also be the same as the list length
  # and this is a special case where we need to preserve uniquelist (see comments in
  # create_uniquelist_info())
  # $uniquelist cannot be undef or 0 either since every list occurs at least once.
  # This guarantees that uniquelist, when set, is >1 because mincitenames cannot
  # be <1
  return if $uniquelist <= $mincn and not $mincn == $num_names;

  # Special case
  # No point disambiguating with uniquelist lists which have the same count
  # for the complete list as this means they are the same list. So, if this
  # is the case, don't set uniquelist at all.
  # BUT, this only applies if there is nothing else which these identical lists
  # need disambiguating from so check if there are any other lists which differ
  # up to any index. If there is such a list, set uniquelist using that index.

  # if final count > 1 (identical lists)
  if ($self->get_uniquelistcount_final($namelist) > 1) {
    # index where this namelist begins to differ from any other
    # Can't be 0 as that means it begins differently in which case $index is undef
    my $index = $self->namelist_differs_index($namelist);
    return unless $index;
    # Now we know that some disambiguation is needed from other similar list(s)
    $uniquelist = $index+1;# convert zero-based index into 1-based uniquelist value
  }
  # this is an elsif because for final count > 1, we are setting uniquelist and don't
  # want to mess about with it any more
  elsif ($num_names > $uniquelist and
         not $self->namelist_differs_nth($namelist, $uniquelist, $ul, $labelyear)) {
    # If there are more names than uniquelist, reduce it by one unless
    # there is another list which differs at uniquelist and is at least as long
    # so we get:
    #
    # AAA and BBB and CCC
    # AAA and BBB and CCC et al
    #
    # instead of
    #
    # AAA and BBB and CCC
    # AAA and BBB and CCC and DDD et al
    #
    # BUT, we also want
    #
    # AAA and BBB and CCC
    # AAA and BBB and CCC and DDD et al
    # AAA and BBB and CCC and EEE et al

    $uniquelist--;
  }

  $self->{state}{namelistdata}{$nlid}{ul} = $uniquelist;
  return;
}

=head2 get_visible_cite

  Gets citation name list visibility

=cut

sub get_visible_cite {
  my ($self, $nlid) = @_;
  return $self->{state}{namelistdata}{$nlid}{viscite};
}

=head2 set_visible_cite

  Gets citation name list visibility

=cut

sub set_visible_cite {
  my ($self, $nlid, $s) = @_;
  $self->{state}{namelistdata}{$nlid}{viscite} = $s;
  return;
}

=head2 get_visible_bib

  Gets bib name list visibility

=cut

sub get_visible_bib {
  my ($self, $nlid) = @_;
  return $self->{state}{namelistdata}{$nlid}{visbib};
}

=head2 set_visible_bib

  Gets bib name list visibility

=cut

sub set_visible_bib {
  my ($self, $nlid, $s) = @_;
  $self->{state}{namelistdata}{$nlid}{visbib} = $s;
  return;
}

=head2 get_visible_sort

  Gets sort name list visibility

=cut

sub get_visible_sort {
  my ($self, $nlid) = @_;
  return $self->{state}{namelistdata}{$nlid}{vissort};
}

=head2 set_visible_sort

  Gets sort name list visibility

=cut

sub set_visible_sort {
  my ($self, $nlid, $s) = @_;
  $self->{state}{namelistdata}{$nlid}{vissort} = $s;
  return;
}

=head2 get_visible_alpha

  Gets alpha name list visibility

=cut

sub get_visible_alpha {
  my ($self, $nlid) = @_;
  return $self->{state}{namelistdata}{$nlid}{visalpha};
}

=head2 set_visible_alpha

  Gets alpha name list visibility

=cut

sub set_visible_alpha {
  my ($self, $nlid, $s) = @_;
  $self->{state}{namelistdata}{$nlid}{visalpha} = $s;
  return;
}

=head2 get_numofuniquenames

    Get the number of uniquenames entries for a visible name

=cut

sub get_numofuniquenames {
  my ($self, $name, $namecontext) = @_;
  return scalar keys $self->{state}{uniquenamecount}{$name}{$namecontext}->%*;
}

=head2 get_numofuniquenames_all

    Get the number of uniquenames entries for a name

=cut

sub get_numofuniquenames_all {
  my ($self, $name, $namecontext) = @_;
  return scalar keys $self->{state}{uniquenamecount_all}{$name}{$namecontext}->%*;
}

=head2 get_unul_done

    Return a boolean saying whether uniquenename+uniquelist processing is finished

=cut

sub get_unul_done {
  my $self = shift;
  return $self->{unulchanged} ? 0 : 1;
}

=head2 set_unul_changed

    Set a boolean saying whether uniquename+uniquelist has changed

=cut

sub set_unul_changed {
  my ($self, $val) = @_;
  $self->{unulchanged} = $val;
  return;
}




=head2 reset_seen_extra

    Reset the counters for extra*

=cut

sub reset_seen_extra {
  my $self = shift;
  $self->{state}{seen_extradate} = {};
  $self->{state}{seen_extraname} = {};
  $self->{state}{seen_extratitle} = {};
  $self->{state}{seen_extratitleyear} = {};
  $self->{state}{seen_extraalpha} = {};
  $self->{state}{seen_nametitledateparts} = {};
  $self->{state}{seen_labelname} = {};
  $self->{state}{seen_nametitle} = {};
  $self->{state}{seen_titleyear} = {};
  return;
}

=head2 incr_seen_extradate

    Increment and return the counter for extradate

=cut

sub incr_seen_extradate {
  my ($self, $ey) = @_;
  return ++$self->{state}{seen_extradate}{$ey};
}

=head2 incr_seen_extraname

    Increment and return the counter for extraname

=cut

sub incr_seen_extraname {
  my ($self, $en) = @_;
  return ++$self->{state}{seen_extraname}{$en};
}

=head2 incr_seen_labelname

    Increment and return a counter used to track extraname

=cut

sub incr_seen_labelname {
  my ($self, $ln) = @_;
  return ++$self->{state}{seen_labelname}{$ln};
}

=head2 incr_seen_extratitle

    Increment and return the counter for extratitle

=cut

sub incr_seen_extratitle {
  my ($self, $et) = @_;
  return ++$self->{state}{seen_extratitle}{$et};
}

=head2 incr_seen_extratitleyear

    Increment and return the counter for extratitleyear

=cut

sub incr_seen_extratitleyear {
  my ($self, $ety) = @_;
  return ++$self->{state}{seen_extratitleyear}{$ety};
}


=head2 incr_seen_extraalpha

    Increment and return the counter for extraalpha

=cut

sub incr_seen_extraalpha {
  my ($self, $ea) = @_;
  return ++$self->{state}{seen_extraalpha}{$ea};
}


=head2 get_seen_nametitledateparts

    Get the count of an labelname/dateparts combination for tracking
    extradate. It uses labelyear plus name as we need to disambiguate
    entries with different labelyear (like differentiating 1984--1986 from
    just 1984)

=cut

sub get_seen_nametitledateparts {
  my ($self, $ny) = @_;
  return $self->{state}{seen_nametitledateparts}{$ny} // 0;
}

=head2 incr_seen_nametitledateparts

    Increment the count of an labelname/labeltitle+dateparts combination for extradate

    We pass in the name/title and date strings separately as we have to
    be careful and only increment this counter beyond 1 if there is
    a name/title component. Otherwise, extradate gets defined for all
    entries with no name/title but the same year etc.

=cut

sub incr_seen_nametitledateparts {
  my ($self, $ns, $ys) = @_;
  my $tmp = "$ns,$ys";
  # We can always increment this to 1
  unless (exists($self->{state}{seen_nametitledateparts}{$tmp})) {
    $self->{state}{seen_nametitledateparts}{$tmp}++;
  }
  # But beyond that only if we have a labelname/labeltitle in the entry since
  # this counter is used to create extradate which doesn't mean anything for
  # entries with no name or title
  # We allow empty year so that we generate extradate for the same name with no year
  # so we can do things like "n.d.-a", "n.d.-b" etc.
  else {
    if ($ns) {
      $self->{state}{seen_nametitledateparts}{$tmp}++;
    }
  }
  return;
}

=head2 get_seen_labelname

    Get the count of a labelname hash for tracking extraname

=cut

sub get_seen_labelname {
  my ($self, $ln) = @_;
  return $self->{state}{seen_labelname}{$ln} // 0;
}

=head2 get_seen_nametitle

    Get the count of an labelname/labeltitle combination for tracking
    extratitle.

=cut

sub get_seen_nametitle {
  my ($self, $nt) = @_;
  return $self->{state}{seen_nametitle}{$nt} // 0;
}

=head2 incr_seen_nametitle

    Increment the count of an labelname/labeltitle combination for extratitle

    We pass in the name and year strings separately as we have to
    be careful and only increment this counter beyond 1 if there is
    a title component. Otherwise, extratitle gets defined for all
    entries with no title.

=cut

sub incr_seen_nametitle {
  my ($self, $ns, $ts) = @_;
  my $tmp = "$ns,$ts";
  # We can always increment this to 1
  unless ($self->{state}{seen_nametitle}{$tmp}) {
    $self->{state}{seen_nametitle}{$tmp}++;
  }
  # But beyond that only if we have a labeltitle in the entry since
  # this counter is used to create extratitle which doesn't mean anything for
  # entries with no title
  else {
    if ($ts) {
      $self->{state}{seen_nametitle}{$tmp}++;
    }
  }
  return;
}

=head2 get_seen_titleyear

    Get the count of an labeltitle/labelyear combination for tracking
    extratitleyear

=cut

sub get_seen_titleyear {
  my ($self, $ty) = @_;
  return $self->{state}{seen_titleyear}{$ty} // 0;
}

=head2 incr_seen_titleyear

    Increment the count of an labeltitle/labelyear combination for extratitleyear

    We pass in the title and year strings separately as we have to
    be careful and only increment this counter beyond 1 if there is
    a title component. Otherwise, extratitleyear gets defined for all
    entries with no title.

=cut

sub incr_seen_titleyear {
  my ($self, $ts, $ys) = @_;
  my $tmp = "$ts,$ys";
  # We can always increment this to 1
  unless ($self->{state}{seen_titleyear}{$tmp}) {
    $self->{state}{seen_titleyear}{$tmp}++;
  }
  # But beyond that only if we have a labeltitle in the entry since
  # this counter is used to create extratitleyear which doesn't mean anything for
  # entries with no title
  else {
    if ($ts) {
      $self->{state}{seen_titleyear}{$tmp}++;
    }
  }
  return;
}


=head2 reset_workuniqueness

  Reset various work uniqueness counters

=cut

sub reset_workuniqueness {
  my $self = shift;
  $self->{state}{seenname} = {};
  $self->{state}{seentitle} = {};
  $self->{state}{seenbaretitle} = {};
  $self->{state}{seenwork} = {};
  return;
}

=head2 get_seenname

    Get the count of occurrences of a labelname or labeltitle

=cut

sub get_seenname {
  my ($self, $identifier) = @_;
  return $self->{state}{seenname}{$identifier};
}

=head2 incr_seenname

    Increment the count of occurrences of a labelname or labeltitle

=cut

sub incr_seenname {
  my ($self, $identifier) = @_;
  $self->{state}{seenname}{$identifier}++;
  return;
}

=head2 get_seentitle

    Get the count of occurrences of a labeltitle

=cut

sub get_seentitle {
  my ($self, $identifier) = @_;
  return $self->{state}{seentitle}{$identifier};
}

=head2 incr_seentitle

    Increment the count of occurrences of a labeltitle

=cut

sub incr_seentitle {
  my ($self, $identifier) = @_;
  $self->{state}{seentitle}{$identifier}++;
  return;
}

=head2 get_seenbaretitle

    Get the count of occurrences of a labeltitle when there is
    no labelname

=cut

sub get_seenbaretitle {
  my ($self, $identifier) = @_;
  return $self->{state}{seenbaretitle}{$identifier};
}

=head2 incr_seenbaretitle

    Increment the count of occurrences of a labeltitle
    when there is no labelname

=cut

sub incr_seenbaretitle {
  my ($self, $identifier) = @_;
  $self->{state}{seenbaretitle}{$identifier}++;
  return;
}

=head2 get_seenwork

    Get the count of occurrences of a labelname and labeltitle

=cut

sub get_seenwork {
  my ($self, $identifier) = @_;
  return $self->{state}{seenwork}{$identifier};
}

=head2 incr_seenwork

    Increment the count of occurrences of a labelname and labeltitle

=cut

sub incr_seenwork {
  my ($self, $identifier) = @_;
  $self->{state}{seenwork}{$identifier}++;
  return;
}


=head2 incr_la_disambiguation

    Increment a counter to say we have seen this labelalpha

=cut

sub incr_la_disambiguation {
  my ($self, $la) = @_;
  $self->{state}{ladisambiguation}{$la}++;
  return;
}


=head2 get_la_disambiguation

    Get the disambiguation counter for this labelalpha.
    Return a 0 for undefs to avoid spurious errors.

=cut

sub get_la_disambiguation {
  my ($self, $la) = @_;
  return $self->{state}{ladisambiguation}{$la} // 0;
}




=head2 set_sortingtemplatename

    Sets the sortingtemplate name of a data list

=cut

sub set_sortingtemplatename {
  my $self = shift;
  my $stn = shift;
  $self->{sortingtemplatename} = lc($stn);
  return;
}

=head2 get_attrs

    Gets the attributes of a data list

=cut

sub get_attrs {
  my $self = shift;
  return join('/', ($self->{sortingtemplatename},
                    $self->{sortingnamekeytemplatename},
                    $self->{labelprefix},
                    $self->{uniquenametemplatename},
                    $self->{labelalphanametemplatename},
                    $self->{namehashtemplatename}));
}

=head2 get_sortingtemplatename

    Gets the sortingtemplatename of a data list

=cut

sub get_sortingtemplatename {
  my $self = shift;
  return $self->{sortingtemplatename};
}

=head2 set_sortingnamekeytemplatename

    Sets the sortingnamekeytemplate name of a data list

=cut

sub set_sortingnamekeytemplatename {
  my $self = shift;
  my $snksn = shift;
  $self->{sortingnamekeytemplatename} = lc($snksn);
  return;
}

=head2 get_sortingnamekeytemplatename

    Gets the sortingnamekeytemplatename of a data list

=cut

sub get_sortingnamekeytemplatename {
  my $self = shift;
  return $self->{sortingnamekeytemplatename};
}

=head2 set_uniquenametemplatename

    Sets the uniquenametemplate name of a data list

=cut

sub set_uniquenametemplatename {
  my $self = shift;
  my $untn = shift;
  $self->{uniquenametemplatename} = lc($untn);
  return;
}

=head2 get_uniquenametemplatename

    Gets the uniquenametemplate name of a data list

=cut

sub get_uniquenametemplatename {
  my $self = shift;
  return $self->{uniquenametemplatename};
}

=head2 set_labelalphanametemplatename

    Sets the labelalphanametemplate name of a data list

=cut

sub set_labelalphanametemplatename {
  my $self = shift;
  my $latn = shift;
  $self->{labelalphanametemplatename} = lc($latn);
  return;
}

=head2 get_labelalphanametemplatename

    Gets the labelalphanametemplate name of a data list

=cut

sub get_labelalphanametemplatename {
  my $self = shift;
  return $self->{labelalphanametemplatename};
}

=head2 set_namehashtemplatename

    Sets the namehashtemplate name of a data list

=cut

sub set_namehashtemplatename {
  my $self = shift;
  my $nhtn = shift;
  $self->{namehashtemplatename} = lc($nhtn);
  return;
}

=head2 get_namehashtemplatename

    Gets the namehashtemplate name of a data list

=cut

sub get_namehashtemplatename {
  my $self = shift;
  return $self->{namehashtemplatename};
}


=head2 set_sortinit_collator

    Sets the sortinit collator for this list

=cut

sub set_sortinit_collator {
  my $self = shift;
  $self->{sortinitcollator} = shift;;
  return;
}

=head2 get_sortinit_collator

    Gets the sortinit collator for this list

=cut

sub get_sortinit_collator {
  my $self = shift;
  return $self->{sortinitcollator};
}

=head2 get_labelprefix

    Gets the labelprefix setting of a data list

=cut

sub get_labelprefix {
  my $self = shift;
  return $self->{labelprefix};
}

=head2 set_labelprefix

    Sets the labelprefix setting of a data list

=cut

sub set_labelprefix {
  my $self = shift;
  my $pn = shift;
  $self->{labelprefix} = $pn;
  return
}

=head2 set_name

    Sets the name of a data list

=cut

sub set_name {
  my $self = shift;
  my $name = shift;
  $self->{name} = $name;
  return;
}

=head2 get_name

    Gets the name of a data list

=cut

sub get_name {
  my $self = shift;
  return $self->{name};
}


=head2 set_type

    Sets the type of a data list

=cut

sub set_type {
  my $self = shift;
  my $type = shift;
  $self->{type} = lc($type);
  return;
}

=head2 get_type

    Gets the type of a section list

=cut

sub get_type {
  my $self = shift;
  return $self->{type};
}

=head2 set_keys

    Sets the keys for the list

=cut

sub set_keys {
  my ($self, $keys) = @_;
  $self->{keys} = $keys;
  return;
}

=head2 get_keys

    Gets the keys for the list

=cut

sub get_keys {
  my $self = shift;
  return $self->{keys};
}

=head2 count_keys

    Count the keys for the list

=cut

sub count_keys {
  my $self = shift;
  return $#{$self->{keys}} + 1;
}

=head2 get_namelistdata

  Gets  name list data

=cut

sub get_namelistdata {
  return shift->{state}{namelistdata};
}

=head2 set_namelistdata

  Saves name list data

=cut

sub set_namelistdata {
  my ($self, $nld) = @_;
  $self->{state}{namelistdata} = $nld;
  return;
}

=head2 get_labelalphadata

  Gets  labelalpha field data

=cut

sub get_labelalphadata {
  return shift->{state}{labelalphadata};
}

=head2 set_labelalphadata

  Saves labelalpha data

=cut

sub set_labelalphadata {
  my ($self, $lad) = @_;
  $self->{state}{labelalphadata} = $lad;
  return;
}

=head2 get_labelalphadata_for_key

  Gets  labelalpha field data for a key

=cut

sub get_labelalphadata_for_key {
  my ($self, $key) = @_;
  return $self->{state}{labelalphadata}{$key};
}

=head2 set_labelalphadata_for_key

  Saves labelalpha field data for a key

=cut

sub set_labelalphadata_for_key {
  my ($self, $key, $la) = @_;
  return unless defined($key);
  $self->{state}{labelalphadata}{$key} = $la;
  return;
}

=head2 set_extradatedata_for_key

  Saves extradate field data for a key

=cut

sub set_extradatedata_for_key {
  my ($self, $key, $ed) = @_;
  return unless defined($key);
  $self->{state}{extradatedata}{$key} = $ed;
  return;
}

=head2 set_extranamedata_for_key

  Saves extraname field data for a key

=cut

sub set_extranamedata_for_key {
  my ($self, $key, $en) = @_;
  return unless defined($key);
  $self->{state}{extranamedata}{$key} = $en;
  return;
}

=head2 get_extranamedata_for_key

    Gets the extraname field data for a key

=cut

sub get_extranamedata_for_key {
  my ($self, $key) = @_;
  return unless defined($key);
  return $self->{state}{extranamedata}{$key};
}

=head2 set_extradatedata

    Saves extradate field data for all keys

=cut

sub set_extradatedata {
  my ($self, $ed) = @_;
  $self->{state}{extradatedata} = $ed;
  return;
}


=head2 get_extradatedata_for_key

    Gets the extradate field data for a key

=cut

sub get_extradatedata_for_key {
  my ($self, $key) = @_;
  return unless defined($key);
  return $self->{state}{extradatedata}{$key};
}

=head2 set_extratitledata_for_key

  Saves extratitle field data for a key

=cut

sub set_extratitledata_for_key {
  my ($self, $key, $ed) = @_;
  return unless defined($key);
  $self->{state}{extratitledata}{$key} = $ed;
  return;
}

=head2 set_extratitledata

    Saves extratitle field data for all keys

=cut

sub set_extratitledata {
  my ($self, $ed) = @_;
  $self->{state}{extratitledata} = $ed;
  return;
}


=head2 get_extratitledata

    Gets the extratitle field data for a key

=cut

sub get_extratitledata_for_key {
  my ($self, $key) = @_;
  return unless defined($key);
  return $self->{state}{extratitledata}{$key};
}


=head2 set_extratitleyeardata_for_key

  Saves extratitleyear field data for a key

=cut

sub set_extratitleyeardata_for_key {
  my ($self, $key, $ed) = @_;
  return unless defined($key);
  $self->{state}{extratitleyeardata}{$key} = $ed;
  return;
}

=head2 set_extratitleyeardata

    Saves extratitleyear field data for all keys

=cut

sub set_extratitleyeardata {
  my ($self, $ed) = @_;
  $self->{state}{extratitleyeardata} = $ed;
  return;
}


=head2 get_extratitleyeardata

    Gets the extratitleyear field data for a key

=cut

sub get_extratitleyeardata_for_key {
  my ($self, $key) = @_;
  return unless defined($key);
  return $self->{state}{extratitleyeardata}{$key};
}


=head2 set_extraalphadata_for_key

    Saves extraalpha field data for a key

=cut

sub set_extraalphadata_for_key {
  my ($self, $key, $ed) = @_;
  return unless defined($key);
  $self->{state}{extraalphadata}{$key} = $ed;
  return;
}

=head2 set_extraalphadata

    Saves extraalpha field data for all keys

=cut

sub set_extraalphadata {
  my ($self, $ed) = @_;
  $self->{state}{extraalphadata} = $ed;
  return;
}

=head2 get_extraalphadata

    Gets the extraalpha field data for a key

=cut

sub get_extraalphadata_for_key {
  my ($self, $key) = @_;
  return unless defined($key);
  return $self->{state}{extraalphadata}{$key};
}

=head2 get_sortdataschema

    Gets the sortdata schema for a sortlist

=cut

sub get_sortdataschema {
  my ($self) = @_;
  return $self->{sortdataschema};
}

=head2 set_sortdataschema

    Saves the sortdata schema for a sortlist

=cut

sub set_sortdataschema {
  my ($self, $ss) = @_;
  $self->{sortdataschema} = $ss;
  return;
}

=head2 set_sortdata

    Saves sorting data in a list for a key

=cut

sub set_sortdata {
  my ($self, $key, $sd) = @_;
  return unless defined($key);
  $self->{sortdata}{$key} = $sd;
  return;
}

=head2 get_sortdata_for_key

    Gets the sorting data in a list for a key

=cut

sub get_sortdata_for_key {
  my ($self, $key) = @_;
  return unless defined($key);
  return $self->{sortdata}{$key};
}


=head2 set_sortinitdata_for_key

 Saves sortinit data for a specific key

=cut

sub set_sortinitdata_for_key {
  my ($self, $key, $init) = @_;
  return unless defined($key);
  $self->{sortinitdata}{$key} = {init => $init};
  return;
}

=head2 set_sortinitdata

 Saves sortinit data for all keys

=cut

sub set_sortinitdata {
  my ($self, $sid) = @_;
  $self->{sortinitdata} = $sid;
  return;
}

=head2 get_sortinit_for_key

    Gets the sortinit in a list for a key

=cut

sub get_sortinit_for_key {
  my ($self, $key) = @_;
  return unless defined($key);
  return $self->{sortinitdata}{$key}{init};
}

=head2 set_sortingtemplate

    Sets the sortingtemplate of a list

=cut

sub set_sortingtemplate {
  my $self = shift;
  my $sortingtemplate = shift;
  $self->{sortingtemplate} = $sortingtemplate;
  return;
}

=head2 get_sortingtemplate

    Gets the sortingtemplate of a list

=cut

sub get_sortingtemplate {
  my $self = shift;
  return $self->{sortingtemplate};
}


=head2 add_filter

    Adds a filter to a list object

=cut

sub add_filter {
  my $self = shift;
  my ($filter) = @_;
  push $self->{filters}->@*, $filter;
  return;
}

=head2 get_filters

    Gets all filters for a list object

=cut

sub get_filters {
  my $self = shift;
  return $self->{filters};
}

=head2 instantiate_entry

  Do any dynamic information replacement for information
  which varies in an entry between lists. This is information which
  needs to be output to the .bbl for an entry but which is a property
  of the reference context and not the entry per se so it cannot be stored
  statically in the entry and must be retrieved from the specific datalist
  when outputting the entry.

=cut

sub instantiate_entry {
  my ($self, $section, $entry, $key, $format) = @_;
  my $be = $section->bibentry($key);
  my $bee = $be->get_field('entrytype');

  return '' unless $entry and $be;

  my $dmh = Biber::Config->get_dm_helpers;

  $format //= 'bbl'; # default

  my $entry_string = $$entry;

  # .bbl output
  if ($format eq 'bbl') {

    # entryset
    if (my $es = $self->get_entryfield($key, 'entryset')) {
      my $str = "\\set{" . join(',', $es->@*) . '}';
      $entry_string =~ s|<BDS>ENTRYSET</BDS>|$str|gxms;
    }

    # uniqueprimaryauthor
    if ($self->get_entryfield($key, 'uniqueprimaryauthor')) {
      my $str = "\\true{uniqueprimaryauthor}";
      $entry_string =~ s|<BDS>UNIQUEPRIMARYAUTHOR</BDS>|$str|gxms;
    }

    # uniquework
    if ($self->get_entryfield($key, 'uniquework')) {
      my $str = "\\true{uniquework}";
      $entry_string =~ s|<BDS>UNIQUEWORK</BDS>|$str|gxms;
    }

    # uniquebaretitle
    if ($self->get_entryfield($key, 'uniquebaretitle')) {
      my $str = "\\true{uniquebaretitle}";
      $entry_string =~ s|<BDS>UNIQUEBARETITLE</BDS>|$str|gxms;
    }

    # uniquetitle
    if ($self->get_entryfield($key, 'uniquetitle')) {
      my $str = "\\true{uniquetitle}";
      $entry_string =~ s|<BDS>UNIQUETITLE</BDS>|$str|gxms;
    }

    # extraalpha
    if (my $e = $self->get_extraalphadata_for_key($key)) {
      my $str = "\\field{extraalpha}{$e}";
      $entry_string =~ s|<BDS>EXTRAALPHA</BDS>|$str|gxms;
    }

    # labelalpha
    if (my $e = $self->get_labelalphadata_for_key($key)) {
      my $str = "\\field{labelalpha}{$e}";
      $entry_string =~ s|<BDS>LABELALPHA</BDS>|$str|gxms;
    }

    # uniquelist
    foreach my $namefield ($dmh->{namelists}->@*) {
      next unless my $nl = $be->get_field($namefield);
      my $nlid = $nl->get_id;
      if (defined($self->get_uniquelist($nlid))) {
        my $str = 'ul=' . $self->get_uniquelist($nlid);
        $entry_string =~ s|<BDS>UL-$nlid</BDS>|$str|gxms;
      }
      else {
        $entry_string =~ s|<BDS>UL-$nlid</BDS>,?||gxms;
      }
    }

    # uniquename
    foreach my $namefield ($dmh->{namelists}->@*) {
      next unless my $nl = $be->get_field($namefield);
      my $nlid = $nl->get_id;
      foreach my $n ($nl->names->@*) {
        my $nid = $n->get_id;
        if (defined($self->get_unsummary($nlid, $nid))) {
          my $str = 'un=' . $self->get_unsummary($nlid, $nid);
          $entry_string =~ s|<BDS>UNS-$nid</BDS>|$str|gxms;
          $str = 'uniquepart=' . $self->get_unpart($nlid, $nid);
          $entry_string =~ s|<BDS>UNP-$nid</BDS>|$str|gxms;
          foreach my $np ($n->get_nameparts) {
            if ($self->is_unbasepart($nlid, $nid, $np)) {
              $entry_string =~ s|\s+<BDS>UNP-$np-$nid</BDS>,?||gxms;
            }
            else {
              $str = "${np}un=" . $self->get_unparts($nlid, $nid, $np);
              $entry_string =~ s|<BDS>UNP-$np-$nid</BDS>|$str|gxms;
            }
          }
        }
        else {
          $entry_string =~ s|<BDS>UN[SP]-$nid</BDS>,?||gxms;
          foreach my $np ($n->get_nameparts) {
            $entry_string =~ s|\s+<BDS>UNP-$np-$nid</BDS>,?||gxms;
          }
        }
      }
    }

    # extratitleyear
    if (my $e = $self->get_extratitleyeardata_for_key($key)) {
      my  $str = "\\field{extratitleyear}{$e}";
      $entry_string =~ s|<BDS>EXTRATITLEYEAR</BDS>|$str|gxms;
    }

    # extratitle
    if (my $e = $self->get_extratitledata_for_key($key)) {
      my $str = "\\field{extratitle}{$e}";
      $entry_string =~ s|<BDS>EXTRATITLE</BDS>|$str|gxms;
    }

    # per-namelist bibnamehash and namehash
    foreach my $namefield ($dmh->{namelists}->@*) {

      # per-namelist bibnamehash
      if (my $e = $self->get_entryfield($key, "${namefield}bibnamehash")) {
        my $str = "\\strng{${namefield}bibnamehash}{$e}";
        $entry_string =~ s|<BDS>${namefield}BIBNAMEHASH</BDS>|$str|gxms;
      }

      # per-namelist namehash
      if (my $e = $self->get_entryfield($key, "${namefield}namehash")) {
        my $str = "\\strng{${namefield}namehash}{$e}";
        $entry_string =~ s|<BDS>${namefield}NAMEHASH</BDS>|$str|gxms;
      }

      # per-namelist fullhash
      if (my $e = $self->get_entryfield($key, "${namefield}fullhash")) {
        my $str = "\\strng{${namefield}fullhash}{$e}";
        $entry_string =~ s|<BDS>${namefield}FULLHASH</BDS>|$str|gxms;
      }

      # per-namelist fullhashraw
      if (my $e = $self->get_entryfield($key, "${namefield}fullhashraw")) {
        my $str = "\\strng{${namefield}fullhashraw}{$e}";
        $entry_string =~ s|<BDS>${namefield}FULLHASHRAW</BDS>|$str|gxms;
      }

    }

    # fullhash
    if (my $e = $self->get_entryfield($key, 'fullhash')) {
      my $str = "\\strng{fullhash}{$e}";
      $entry_string =~ s|<BDS>FULLHASH</BDS>|$str|gxms;
    }

    # fullhashraw
    if (my $e = $self->get_entryfield($key, 'fullhashraw')) {
      my $str = "\\strng{fullhashraw}{$e}";
      $entry_string =~ s|<BDS>FULLHASHRAW</BDS>|$str|gxms;
    }

    # bibnamehash
    if (my $e = $self->get_entryfield($key, 'bibnamehash')) {
      my $str = "\\strng{bibnamehash}{$e}";
      $entry_string =~ s|<BDS>BIBNAMEHASH</BDS>|$str|gxms;
    }

    # namehash
    if (my $e = $self->get_entryfield($key, 'namehash')) {
      my $str = "\\strng{namehash}{$e}";
      $entry_string =~ s|<BDS>NAMEHASH</BDS>|$str|gxms;
    }

    # per-namehash
    foreach my $pn ($dmh->{namelistsall}->@*) {
      next unless my $nl = $be->get_field($pn);
      foreach my $n ($nl->names->@*) {
        my $nid = $n->get_id;
        if (my $e = $self->{state}{namelistdata}{$nl->get_id}{$nid}{hash}) {
          my $str = "hash=$e";
          $entry_string =~ s|<BDS>$nid-PERNAMEHASH</BDS>|$str|gxms;
        }
        else {
          $entry_string =~ s|<BDS>$nid-PERNAMEHASH</BDS>,?||gxms;
        }
      }
    }

    # extraname
    if (my $e = $self->get_extranamedata_for_key($key)) {
      my $str = "\\field{extraname}{$e}";
      $entry_string =~ s|<BDS>EXTRANAME</BDS>|$str|gxms;
    }

    # extradate
    if (my $e = $self->get_extradatedata_for_key($key)) {
      my $str = "\\field{extradate}{$e}";
      $entry_string =~ s|<BDS>EXTRADATE</BDS>|$str|gxms;
    }

    # sortinit + sortinithash
    my $sinit = $self->get_sortinit_for_key($key);
    if (defined($sinit)) {
      my $str = "\\field{sortinit}{$sinit}";
      $entry_string =~ s|<BDS>SORTINIT</BDS>|$str|gxms;
      my $sinithash = md5_hex($self->{sortinitcollator}->viewSortKey($sinit));
      $str = "\\field{sortinithash}{$sinithash}";
      $entry_string =~ s|<BDS>SORTINITHASH</BDS>|$str|gxms;
    }

    # labelprefix
    if (my $pn = $self->get_labelprefix($key)) {
      my $str = "\\field{labelprefix}{$pn}";
      $entry_string =~ s|<BDS>LABELPREFIX</BDS>|$str|gxms;
    }

    # singletitle
    if ($self->get_entryfield($key, 'singletitle')) {
      my $str = "\\true{singletitle}";
      $entry_string =~ s|<BDS>SINGLETITLE</BDS>|$str|gxms;
    }
  }

  # .bblxml output
  if ($format eq 'bblxml') {

    # entryset
    if (my $es = $self->get_entryfield($key, 'entryset')) {
      my $str = "<bbl:set>\n";
      foreach my $m ($es->@*) {
        $str .= "    <bbl:member>$m</bbl:member>\n";
      }
      $str .= "  </bbl:set>";
      $entry_string =~ s|<BDS>ENTRYSET</BDS>|$str|gxms;
    }

    # uniqueprimaryauthor
    if ($self->get_entryfield($key, 'uniqueprimaryauthor')) {
      my $str = 'true';
      $entry_string =~ s|\[BDS\]UNIQUEPRIMARYAUTHOR\[/BDS\]|$str|gxms;
    }
    else {
      $entry_string =~ s|\suniqueprimaryauthor="\[BDS\]UNIQUEPRIMARYAUTHOR\[/BDS\]"||gxms;
    }

    # uniquework
    if ($self->get_entryfield($key, 'uniquework')) {
      my $str = 'true';
      $entry_string =~ s|\[BDS\]UNIQUEWORK\[/BDS\]|$str|gxms;
    }
    else {
      $entry_string =~ s|\suniquework="\[BDS\]UNIQUEWORK\[/BDS\]"||gxms;
    }

    # uniquebaretitle
    if ($self->get_entryfield($key, 'uniquebaretitle')) {
      my $str = 'true';
      $entry_string =~ s|\[BDS\]UNIQUEBARETITLE\[/BDS\]|$str|gxms;
    }
    else {
      $entry_string =~ s|\suniquebaretitle="\[BDS\]UNIQUEBARETITLE\[/BDS\]"||gxms;
    }

    # uniquetitle
    if ($self->get_entryfield($key, 'uniquetitle')) {
      my $str = 'true';
      $entry_string =~ s|\[BDS\]UNIQUETITLE\[/BDS\]|$str|gxms;
    }
    else {
      $entry_string =~ s|\suniquetitle="\[BDS\]UNIQUETITLE\[/BDS\]"||gxms;
    }

    # extraalpha
    if (my $e = $self->get_extraalphadata_for_key($key)) {
      my $str = "<bbl:field name=\"extraalpha\">$e</bbl:field>";
      $entry_string =~ s|<BDS>EXTRAALPHA</BDS>|$str|gxms;
    }

    # labelalpha
    if (my $e = $self->get_labelalphadata_for_key($key)) {
      my $str = "<bbl:field name=\"labelalpha\">$e</bbl:field>";
      $entry_string =~ s|<BDS>LABELALPHA</BDS>|$str|gxms;
    }

    # uniquelist
    foreach my $namefield ($dmh->{namelists}->@*) {
      next unless my $nl = $be->get_field($namefield);
      my $nlid = $nl->get_id;
      if (defined($self->get_uniquelist($nlid))) {
        my $str = $self->get_uniquelist($nlid);
        $entry_string =~ s|\[BDS\]UL-$nlid\[/BDS\]|$str|gxms;
      }
      else {
        $entry_string =~ s|\sul="\[BDS\]UL-$nlid\[/BDS\]"||gxms;
      }
    }

    # uniquename
    foreach my $namefield ($dmh->{namelists}->@*) {
      next unless my $nl = $be->get_field($namefield);
      my $nlid = $nl->get_id;
      foreach my $n ($nl->names->@*) {
        my $nid = $n->get_id;
        if (defined($self->get_unsummary($nlid, $nid))) {
          my $str = $self->get_unsummary($nlid, $nid);
          $entry_string =~ s|\[BDS\]UNS-$nid\[/BDS\]|$str|gxms;
          $str = $self->get_unpart($nlid, $nid);
          $entry_string =~ s|\[BDS\]UNP-$nid\[/BDS\]|$str|gxms;
          foreach my $np ($n->get_nameparts) {
            if ($self->is_unbasepart($nlid, $nid, $np)) {
              $entry_string =~ s|\sun="\[BDS\]UNP-$np-$nid\[/BDS\]",?||gxms;
            }
            else {
              $str = $self->get_unparts($nlid, $nid, $np);
              $entry_string =~ s|\[BDS\]UNP-$np-$nid\[/BDS\]|$str|gxms;
            }
          }
        }
        else {
          $entry_string =~ s#\s(?:un|uniquepart)="\[BDS\]UN[SP]-$nid\[/BDS\]",?##gxms;
          foreach my $np ($n->get_nameparts) {
            $entry_string =~ s|\sun="\[BDS\]UNP-$np-$nid\[/BDS\]",?||gxms;
          }
        }
      }
    }

    # extratitleyear
    if (my $e = $self->get_extratitleyeardata_for_key($key)) {
      my $str = "<bbl:field name=\"extratitleyear\">$e</bbl:field>";
      $entry_string =~ s|<BDS>EXTRATITLEYEAR</BDS>|$str|gxms;
    }

    # extratitle
    if (my $e = $self->get_extratitledata_for_key($key)) {
      my $str = "<bbl:field name=\"extratitle\">$e</bbl:field>";
      $entry_string =~ s|<BDS>EXTRATITLE</BDS>|$str|gxms;
    }

    # per-namelist bibnamehash and namehash
    foreach my $namefield ($dmh->{namelists}->@*) {

      # per-namelist bibnamehash
      if (my $e = $self->get_entryfield($key, "${namefield}bibnamehash")) {
        my $str = "<bbl:field name=\"${namefield}bibnamehash\">$e</bbl:field>";
        $entry_string =~ s|<BDS>${namefield}BIBNAMEHASH</BDS>|$str|gxms;
      }

      # per-namelist namehash
      if (my $e = $self->get_entryfield($key, "${namefield}namehash")) {
        my $str = "<bbl:field name=\"${namefield}namehash\">$e</bbl:field>";
        $entry_string =~ s|<BDS>${namefield}NAMEHASH</BDS>|$str|gxms;
      }
    }

    # bibnamehash
    if (my $e = $self->get_entryfield($key, 'bibnamehash')) {
      my $str = "<bbl:field name=\"bibnamehash\">$e</bbl:field>";
      $entry_string =~ s|<BDS>BIBNAMEHASH</BDS>|$str|gxms;
    }

    # namehash
    if (my $e = $self->get_entryfield($key, 'namehash')) {
      my $str = "<bbl:field name=\"namehash\">$e</bbl:field>";
      $entry_string =~ s|<BDS>NAMEHASH</BDS>|$str|gxms;
    }

    # per-namehash
    foreach my $pn ($dmh->{namelistsall}->@*) {
      next unless my $nl = $be->get_field($pn);
      foreach my $n ($nl->names->@*) {
        my $nid = $n->get_id;
        if (my $e = $self->{state}{namelistdata}{$nl->get_id}{$nid}{hash}) {
          my $str = $e;
          $entry_string =~ s|\[BDS\]$nid-PERNAMEHASH\[/BDS\]|$str|gxms;
        }
        else {
          $entry_string =~ s|hash="\[BDS\]$nid-PERNAMEHASH\[/BDS\]"?,?||gxms;
        }
      }
    }

    # extraname
    if (my $e = $self->get_extranamedata_for_key($key)) {
      my $str = "<bbl:field name=\"extraname\">$e</bbl:field>";
      $entry_string =~ s|<BDS>EXTRANAME</BDS>|$str|gxms;
    }

    # extradate
    if (my $e = $self->get_extradatedata_for_key($key)) {
      my $str = "<bbl:field name=\"extradate\">$e</bbl:field>";
      $entry_string =~ s|<BDS>EXTRADATE</BDS>|$str|gxms;
    }

    # sortinit + sortinithash
    my $sinit = $self->get_sortinit_for_key($key);
    if (defined($sinit)) {
      my $str = "<bbl:field name=\"sortinit\">$sinit</bbl:field>";
      $entry_string =~ s|<BDS>SORTINIT</BDS>|$str|gxms;
      my $sinithash = md5_hex($self->{sortinitcollator}->viewSortKey($sinit));
      $str = "<bbl:field name=\"sortinithash\">$sinithash</bbl:field>";
      $entry_string =~ s|<BDS>SORTINITHASH</BDS>|$str|gxms;
    }

    # labelprefix
    if (my $pn = $self->get_labelprefix($key)) {
      my $str = "<bbl:field name=\"labelprefix\">$pn</bbl:field>";
      $entry_string =~ s|<BDS>LABELPREFIX</BDS>|$str|gxms;
    }

    # singletitle
    if ($self->get_entryfield($key, 'singletitle')) {
      my $str = 'true';
      $entry_string =~ s|\[BDS\]SINGLETITLE\[/BDS\]|$str|gxms;
    }
    else {
      $entry_string =~ s|\ssingletitle="\[BDS\]SINGLETITLE\[/BDS\]"||gxms;
    }
  }

  # Clean up dangling commas
  $entry_string =~ s|,(?:\n\s+)?\}\}|}}|gxms;

  # Clean up generic metadata which was not replaced
  $entry_string =~ s|^\s+<BDS>[^<]+</BDS>\n||gxms;

  return $entry_string;
}

=head2 namelist_differs_index

    Returns the index where the name list begins to differ from any other list

    Assuming these lists

    [a, b]
    [a, b, d, e, f, g, h, i, j]
    [a, b, d, e, f]
    [a, b, e, z, z, y]

    namelist_differs_index([a, b, c, d, e]) -> 2
    namelist_differs_index([a]) -> 1

=cut

sub namelist_differs_index {
  my $self = shift;
  my @list = shift->@*;
  my $index;
  foreach my $l_s (keys $self->{state}{uniquelistcount}{global}{final}->%*) {
    my @l = split("\x{10FFFD}", $l_s);
    next if Compare(\@list, \@l);# Ignore identical lists
    for (my $i=0;$i<=$#list;$i++) {
      if (defined($list[$i]) and defined($l[$i]) and ($list[$i] eq $l[$i])) {
        if (not defined($index) or $i > $index) {
          $index = $i;
        }
      }
      else {
        last;
      }
    }
  }

  if (defined($index)) { # one or more similar lists
    if ($index == $#list) { # There is another list which is a superset, return last index
      return $index;
    }
    else { # Differs with some list, return index of where difference begins
      return $index+1;
    }
  }
  else { # no similar lists
    return undef;
  }
}


=head2 namelist_differs_nth

    Returns true if some other name list differs at passed nth place
    and is at least as long

    namelist_differs_nth([a, b, c, d, e], 3) = 1

    if there is another name list like any of these:

    [a, b, d, e, f]
    [a, b, e, z, z, y]

=cut

sub namelist_differs_nth {
  my $self = shift;
  my ($list, $n, $ul, $labelyear) = @_;
  my @list_one = $list->@*;
  # Loop over all final lists, looking for ones which match:
  # * up to n - 1
  # * differ at $n
  # * are at least as long

  # uniquelist=minyear should only disambiguate from entries with the
  # same labelyear
  my $unames = $self->{state}{uniquelistcount}{global}{final};
  if ($ul eq 'minyear') {
    $unames = $self->{state}{uniquelistcount}{global}{final}{$labelyear};
  }

  foreach my $l_s (keys $unames->%*) {
    my @l = split("\x{10FFFD}", $l_s);
    # If list is shorter than the list we are checking, it's irrelevant
    next if $#l < $list->$#*;
    # If list matches at $n, it's irrelevant
    next if ($list_one[$n-1] eq $l[$n-1]);
    # If list doesn't match up to $n - 1, it's irrelevant
    next unless Compare([@list_one[0 .. $n-2]], [@l[0 .. $n-2]]);
    return 1;
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
