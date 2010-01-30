package Biber::Internals;
use strict;
use warnings;
use Carp;
use Biber::Constants;
use Biber::Utils;
use Text::Wrap;
$Text::Wrap::columns = 80;
use List::AllUtils qw( :all );
use Log::Log4perl qw(:no_extra_logdie_message);

=encoding utf-8

=head1 NAME

Biber::Internals - Internal methods for processing the bibliographic data

=head1 METHODS


=cut

my $logger = Log::Log4perl::get_logger('main');

sub _getnameinitials {
    my ($self, $citekey, $names) = @_;
    my @names = @{$names};
    my $initstr = "";
    my $bibentries = $self->bib;
    my $be = $bibentries->entry($citekey);
    ## my $nodecodeflag = $self->_decode_or_not($citekey);

    if ( $#names < Biber::Config->getblxoption('maxnames', $be->get_field('entrytype'), $citekey ) ) {    # 1 to maxname names
        foreach my $a (@names) {
            if ( $a->{prefix} and Biber::Config->getblxoption('useprefix', $be->get_field('entrytype'), $citekey ) ) {
                $initstr .= terseinitials( $a->{prefix} )
            }
            $initstr .= terseinitials( $a->{lastname} );

            #FIXME suffix ?
            if ( $a->{firstname} ) {
                $initstr .= terseinitials( $a->{firstname} )
            }
        }
    }
    else
    { # more than maxname names: only take initials of first getblxoption('minnames', $citekey)
        foreach my $i ( 0 .. Biber::Config->getblxoption('minnames', $be->get_field('entrytype'), $citekey ) - 1 ) {
            if ( $names[$i]->{prefix} and Biber::Config->getblxoption('useprefix', $be->get_field('entrytype'), $citekey) ) {
                $initstr .= terseinitials( $names[$i]->{prefix} );
            }
            my $tmp = $names[$i]->{lastname};

            #FIXME suffix ?
            $initstr .= terseinitials($tmp);
            if ( $names[$i]->{firstname} ) {
                $tmp = $names[$i]->{firstname};
                $initstr .= terseinitials($tmp);
            }
            $initstr .= "+";
        }
    }
    return $initstr;
}


sub _getallnameinitials {
    my ($self, $citekey, $names) = @_;
    my $initstr = "";
    my $bibentries = $self->bib;
    my $be = $bibentries->entry($citekey);
    foreach my $a (@{$names}) {
        if ( $a->{prefix} and Biber::Config->getblxoption('useprefix', $be->get_field('entrytype'), $citekey ) ) {
            $initstr .= terseinitials( $a->{prefix} )
        }
        $initstr .= terseinitials( $a->{lastname} );

        #FIXME suffix ?
        if ( $a->{firstname} ) {
            $initstr .= terseinitials( $a->{firstname} );
        }
    }
    return $initstr;
}

sub _getlabel {
  my ($self, $citekey, $namefield) = @_;
  my $bibentries = $self->bib;
  my $be = $bibentries->entry($citekey);
  my $dt = $be->get_field('datatype');
  my @names = @{ $be->get_field($namefield) };
  my $alphaothers = Biber::Config->getblxoption('alphaothers', $be->get_field('entrytype'), $citekey);
  my $sortalphaothers = Biber::Config->getblxoption('sortalphaothers', $be->get_field('entrytype'), $citekey) || $alphaothers;
  my $useprefix = Biber::Config->getblxoption('useprefix', $be->get_field('entrytype'), $citekey);
  my $maxnames = Biber::Config->getblxoption('maxnames', $be->get_field('entrytype'), $citekey);
  my $minnames = Biber::Config->getblxoption('minnames', $be->get_field('entrytype'), $citekey);
  my $label = '';
  my $sortlabel = ''; # This contains sortalphaothers instead of alphaothers, if defined
  # This is needed in cases where alphaothers is something like
  # '\textasteriskcentered' which would mess up sorting.

  my @lastnames = map { normalize_string( $_->{lastname}, $dt ) } @names;
  my @prefixes  = map { $_->{prefix} } @names;
  my $numnames  = scalar @names;

  # If name list was truncated in bib with "and others", this overrides maxnames
  my $morenames = ($names[-1]->{namestring} eq 'others') ? 1 : 0;
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
  # The substring length depends on whether we are using prefixes and also whether
  # we have truncated to one name:
  #   1. If there is only one name
  #      1. label string is first 3 chars of surname if there is no prefix
  #      2. label string is first char of prefix plus first 2 chars of surname if there is a prefix
  #   2. If there is more than one name
  #      1.  label string is first char of each surname (up to minnames) if there is no prefix
  #      2.  label string is first char of prefix plus first char of each surname (up to minnames)
  #          if there is a prefix
  for (my $i=0; $i<$loopnames; $i++) {
    $label .= substr($prefixes[$i] , 0, 1) if ($useprefix and $prefixes[$i]);
    $label .= substr($lastnames[$i], 0, $loopnames == 1 ? (($useprefix and $prefixes[$i]) ? 2 : 3) : 1);
  }

  $sortlabel = $label;

  # Add alphaothers if name list is truncated
  if ($nametrunc) {
    $label .= $alphaothers;
    $sortlabel .= $sortalphaothers;
  }

  return [$label, $sortlabel];
}


#########
# Sorting
#########

our $sorting_sep = '0';

# The keys are defined by BibLaTeX and passed in the control file
# The value is an array pointer, first element is a code pointer, second is
# a pointer to extra arguments to the code. This is to make code re-use possible
# so the sorting can share code for similar things.
our $dispatch_sorting = {
             '0000'          =>  [\&_sort_0000,          []],
             '9999'          =>  [\&_sort_9999,          []],
             'address'       =>  [\&_sort_place,         ['place']],
             'author'        =>  [\&_sort_author,        []],
             'citeorder'     =>  [\&_sort_citeorder,     []],
             'day'           =>  [\&_sort_dm,            ['day']],
             'debug'         =>  [\&_sort_debug,         []],
             'editor'        =>  [\&_sort_editor,        ['editor']],
             'editora'       =>  [\&_sort_editor,        ['editora']],
             'editoraclass'  =>  [\&_sort_editortc,      ['editoraclass']],
             'editoratype'   =>  [\&_sort_editortc,      ['editoratype']],
             'editorb'       =>  [\&_sort_editor,        ['editorb']],
             'editorbclass'  =>  [\&_sort_editortc,      ['editorbclass']],
             'editorbtype'   =>  [\&_sort_editortc,      ['editorbtype']],
             'editorc'       =>  [\&_sort_editor,        ['editorc']],
             'editorcclass'  =>  [\&_sort_editortc,      ['editorcclass']],
             'editorctype'   =>  [\&_sort_editortc,      ['editorctype']],
             'endday'        =>  [\&_sort_dm,            ['endday']],
             'endmonth'      =>  [\&_sort_dm,            ['endmonth']],
             'endyear'       =>  [\&_sort_year,          ['endyear']],
             'eventday'      =>  [\&_sort_dm,            ['eventday']],
             'eventendday'   =>  [\&_sort_dm,            ['eventendday']],
             'eventendmonth' =>  [\&_sort_dm,            ['eventendmonth']],
             'eventendyear'  =>  [\&_sort_year,          ['eventendyear']],
             'eventmonth'    =>  [\&_sort_dm,            ['eventmonth']],
             'eventyear'     =>  [\&_sort_year,          ['eventyear']],
             'extraalpha'    =>  [\&_sort_extraalpha,    []],
             'issuetitle'    =>  [\&_sort_issuetitle,    []],
             'institution'   =>  [\&_sort_place,         ['institution']],
             'journal'       =>  [\&_sort_journal,       []],
             'labelalpha'    =>  [\&_sort_labelalpha,    []],
             'location'      =>  [\&_sort_place,         ['location']],
             'mm'            =>  [\&_sort_mm,            []],
             'month'         =>  [\&_sort_dm,            ['month']],
             'origday'       =>  [\&_sort_dm,            ['origday']],
             'origendday'    =>  [\&_sort_dm,            ['origendday']],
             'origendmonth'  =>  [\&_sort_dm,            ['origendmonth']],
             'origendyear'   =>  [\&_sort_year,          ['origendyear']],
             'origmonth'     =>  [\&_sort_dm,            ['origmonth']],
             'origyear'      =>  [\&_sort_year,          ['origyear']],
             'organization'  =>  [\&_sort_place,         ['organization']],
             'presort'       =>  [\&_sort_presort,       []],
             'publisher'     =>  [\&_sort_publisher,     []],
             'pubstate'      =>  [\&_sort_pubstate,      []],
             'school'        =>  [\&_sort_place,         ['school']],
             'sortkey'       =>  [\&_sort_sortkey,       []],
             'sortname'      =>  [\&_sort_sortname,      []],
             'sorttitle'     =>  [\&_sort_title,         ['sorttitle']],
             'sortyear'      =>  [\&_sort_year,          ['sortyear']],
             'title'         =>  [\&_sort_title,         ['title']],
             'translator'    =>  [\&_sort_translator,    []],
             'urlday'        =>  [\&_sort_dm,            ['urlday']],
             'urlendday'     =>  [\&_sort_dm,            ['urlendday']],
             'urlendmonth'   =>  [\&_sort_dm,            ['urlendmonth']],
             'urlendyear'    =>  [\&_sort_year,          ['urlendyear']],
             'urlmonth'      =>  [\&_sort_dm,            ['urlmonth']],
             'urlyear'       =>  [\&_sort_year,          ['urlyear']],
             'volume'        =>  [\&_sort_volume,        []],
             'year'          =>  [\&_sort_year,          ['year']],
};


# Main sorting dispatch method
sub _dispatch_sorting {
  my ($self, $sortfield, $citekey, $sortelementattributes) = @_;
  my $code_ref = @{$dispatch_sorting->{$sortfield}}[0];
  my $code_args_ref = @{$dispatch_sorting->{$sortfield}}[1];
  return &{$code_ref}($self, $citekey, $sortelementattributes, $code_args_ref);
}

# Conjunctive set of sorting sets
sub _generatesortstring {
  my ($self, $citekey, $sortscheme) = @_;
  my $be = $self->bibentry($citekey);
  my $sortstring;
  foreach my $sortset (@{$sortscheme}) {
    $BIBER_SORT_FINAL = 0; # reset sorting short-circuit
    $sortstring .= $self->_sortset($sortset, $citekey);

    # Only append sorting separator if this isn't a null sort string element
    # Put another way, null elements should be completely ignored and no seperator
    # added
    unless ($BIBER_SORT_NULL) {
      $sortstring .= $sorting_sep;
    }
    # Stop here if this sort element is specified as "final" and it's non-null
    if ($BIBER_SORT_FINAL and not $BIBER_SORT_NULL) {
      last;
    }
  }
  $sortstring =~ s/0\z//xms; # strip off the last '0' added by _sortset()
  $be->set_field('sortstring', lc($sortstring));
  return;
}

# Disjunctive sorting set
sub _sortset {
  my ($self, $sortset, $citekey) = @_;
  foreach my $sortelement (@{$sortset}) {
    my ($sortelementname, $sortelementattributes) = %{$sortelement};
    my $string = $self->_dispatch_sorting($sortelementname, $citekey, $sortelementattributes);
    $BIBER_SORT_NULL  = 0; # reset sorting null flag
    if ($sortelementattributes->{final}) { # set short-circuit flag if specified
      $BIBER_SORT_FINAL = 1;
    }
    if ($string) { # sort returns something for this key
      return $string;
    }
  }
  $BIBER_SORT_NULL = 1; # set null flag - need this to deal with some cases
  return '';
}

##############################################
# Sort dispatch routines
##############################################

sub _sort_0000 {
  return '0000';
}

sub _sort_9999 {
  return '9999';
}

sub _sort_author {
  my ($self, $citekey, $sortelementattributes) = @_;
  my $bibentries = $self->bib;
  my $be = $bibentries->entry($citekey);
  if (Biber::Config->getblxoption('useauthor', $be->get_field('entrytype'), $citekey) and
      $be->get_field('author')) {
    return $self->_namestring($citekey, 'author');
  }
  else {
    return '';
  }
}

sub _sort_citeorder {
  my ($self, $citekey, $sortelementattributes) = @_;
  return (first_index {$_ eq $citekey} @{$self->{orig_order_citekeys}}) + 1; # +1 just to make it easier to debug
}

sub _sort_debug {
  my ($self, $citekey, $sortelementattributes) = @_;
  return $citekey;
}

# This is a meta-sub which uses the optional arguments to the dispatch code
# It's done to avoid having many repetitions of almost identical sorting code
# for the many date sorting options
# It deals with day and month fields
sub _sort_dm {
  my ($self, $citekey, $sortelementattributes, $args) = @_;
  my $dmtype = (@{$args})[0]; # get day/month field type
  my $bibentries = $self->bib;
  my $be = $bibentries->entry($citekey);
  my $default_pad_width = 2;
  my $default_pad_side = 'left';
  my $default_pad_char = '0';
  if ($be->get_field($dmtype)) {
    my $pad_width = ($sortelementattributes->{pad_width} or $default_pad_width);
    my $pad_side = ($sortelementattributes->{pad_side} or $default_pad_side);
    my $pad_char = ($sortelementattributes->{pad_char} or $default_pad_char);
    my $pad_length = $pad_width - length($be->get_field($dmtype));
    if ($pad_side eq 'left') {
      return ($pad_char x $pad_length) . $be->get_field($dmtype);
    }
    elsif ($pad_side eq 'right') {
      return $be->get_field($dmtype) . ($pad_char x $pad_length);
    }
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
  my $ed = (@{$args})[0]; # get editor field
  my $bibentries = $self->bib;
  my $be = $bibentries->entry($citekey);
  if (Biber::Config->getblxoption('useeditor', $be->get_field('entrytype'), $citekey) and
      $be->get_field($ed)) {
    return $self->_namestring($citekey, $ed);
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
  my $edtypeclass = (@{$args})[0]; # get editor type/class field
  my $bibentries = $self->bib;
  my $be = $bibentries->entry($citekey);
  if (Biber::Config->getblxoption('useeditor', $be->get_field('entrytype'), $citekey) and
      $be->get_field($edtypeclass)) {
    return $be->get_field($edtypeclass);
  }
  else {
    return '';
  }
}

sub _sort_extraalpha {
  my ($self, $citekey, $sortelementattributes) = @_;
  my $bibentries = $self->bib;
  my $be = $bibentries->entry($citekey);
  my $default_pad_width = 4;
  my $default_pad_side = 'left';
  my $default_pad_char = '0';
  if (Biber::Config->getblxoption('labelalpha', $be->get_field('entrytype'), $citekey) and
      $be->get_field('extraalpha')) {
    my $pad_width = ($sortelementattributes->{pad_width} or $default_pad_width);
    my $pad_side = ($sortelementattributes->{pad_side} or $default_pad_side);
    my $pad_char = ($sortelementattributes->{pad_char} or $default_pad_char);
    my $pad_length = $pad_width - length($be->get_field('extraalpha'));
    if ($pad_side eq 'left') {
      return ($pad_char x $pad_length) . $be->get_field('extraalpha');
    } elsif ($pad_side eq 'right') {
      return $be->get_field('extraalpha') . ($pad_char x $pad_length);
    }
  }
  else {
    return '';
  }
}

sub _sort_issuetitle {
  my ($self, $citekey, $sortelementattributes) = @_;
  my $bibentries = $self->bib;
  my $be = $bibentries->entry($citekey);
  if ($be->get_field('issuetitle')) {
    return normalize_string( $be->get_field('issuetitle'), $self->_nodecode($citekey) );
  }
  else {
    return '';
  }
}

sub _sort_journal {
  my ($self, $citekey, $sortelementattributes) = @_;
  my $bibentries = $self->bib;
  my $be = $bibentries->entry($citekey);
  if ($be->get_field('journal')) {
    return normalize_string( $be->get_field('journal'), $self->_nodecode($citekey) );
  }
  else {
    return '';
  }
}

sub _sort_mm {
  return 'mm';
}

sub _sort_labelalpha {
  my ($self, $citekey, $sortelementattributes) = @_;
  my $bibentries = $self->bib;
  my $be = $bibentries->entry($citekey);
  if ($be->get_field('sortlabelalpha')) {
    return $be->get_field('sortlabelalpha');
  }
  else {
    return '';
  }
}

# This is a meta-sub which uses the optional arguments to the dispatch code
# It's done to avoid having many repetitions of almost identical sorting code
# for the place (address/location/institution etc.) sorting options
sub _sort_place {
  my ($self, $citekey, $sortelementattributes, $args) = @_;
  my $pltype = (@{$args})[0]; # get place field type
  my $bibentries = $self->bib;
  my $be = $bibentries->entry($citekey);
  if ($be->get_field($pltype)) {
    return $self->_liststring($citekey, $pltype);
  }
  else {
    return '';
  }
}

sub _sort_presort {
  my ($self, $citekey, $sortelementattributes) = @_;
  my $bibentries = $self->bib;
  my $be = $bibentries->entry($citekey);
  return $be->get_field('presort') ? $be->get_field('presort') : '';
}

sub _sort_publisher {
  my ($self, $citekey, $sortelementattributes) = @_;
  my $bibentries = $self->bib;
  my $be = $bibentries->entry($citekey);
  if ($be->get_field('publisher')) {
    return $self->_liststring($citekey, 'publisher');
  }
  else {
    return '';
  }
}

sub _sort_pubstate {
  my ($self, $citekey, $sortelementattributes) = @_;
  my $bibentries = $self->bib;
  my $be = $bibentries->entry($citekey);
  return $be->get_field('pubstate') ? $be->get_field('pubstate') : '';
}

sub _sort_sortkey {
  my ($self, $citekey, $sortelementattributes) = @_;
  my $bibentries = $self->bib;
  my $be = $bibentries->entry($citekey);
  if ($be->get_field('sortkey')) {
    my $sortkey = lc($be->get_field('sortkey'));
    $sortkey = LaTeX::Decode::latex_decode($sortkey) unless $self->_nodecode($citekey);
    return $sortkey;
  }
  else {
    return '';
  }
}

sub _sort_sortname {
  my ($self, $citekey, $sortelementattributes) = @_;
  my $bibentries = $self->bib;
  my $be = $bibentries->entry($citekey);
  # see biblatex manual §3.4 - sortname is ignored if no use<name> option is defined
  if ($be->get_field('sortname') and
      (Biber::Config->getblxoption('useauthor', $be->get_field('entrytype'), $citekey) or
       Biber::Config->getblxoption('useeditor', $be->get_field('entrytype'), $citekey) or
       Biber::Config->getblxoption('useetranslator', $be->get_field('entrytype'), $citekey))) {
    return $self->_namestring($citekey, 'sortname');
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
  my $ttype = (@{$args})[0]; # get year field type
  my $bibentries = $self->bib;
  my $be = $bibentries->entry($citekey);
  if ($be->get_field($ttype)) {
    return normalize_string( $be->get_field($ttype), $self->_nodecode($citekey));
  }
  else {
    return '';
  }
}

sub _sort_translator {
  my ($self, $citekey, $sortelementattributes) = @_;
  my $bibentries = $self->bib;
  my $be = $bibentries->entry($citekey);
  if (Biber::Config->getblxoption('usetranslator', $be->get_field('entrytype'), $citekey) and
                   $be->get_field('translator')) {
    return $self->_namestring($citekey, 'translator');
  }
  else {
    return '';
  }
}

sub _sort_volume {
  my ($self, $citekey, $sortelementattributes) = @_;
  my $bibentries = $self->bib;
  my $be = $bibentries->entry($citekey);
  my $default_pad_width = 4;
  my $default_pad_side = 'left';
  my $default_pad_char = '0';
  if ($be->get_field('volume')) {
    my $pad_width = ($sortelementattributes->{pad_width} or $default_pad_width);
    my $pad_side = ($sortelementattributes->{pad_side} or $default_pad_side);
    my $pad_char = ($sortelementattributes->{pad_char} or $default_pad_char);
    my $pad_length = $pad_width - length($be->get_field('volume'));
    if ($pad_side eq 'left') {
      return ($pad_char x $pad_length) . $be->get_field('volume');
    }
    elsif ($pad_side eq 'right') {
      return $be->get_field('volume') . ($pad_char x $pad_length);
    }
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
  my $ytype = (@{$args})[0]; # get year field type
  my $bibentries = $self->bib;
  my $be = $bibentries->entry($citekey);
  my $default_substring_width = 4;
  my $default_substring_side = 'left';
  my $default_direction = 'ascending';
  my $subs_offset = 0;
  if ($be->get_field($ytype)) {
    my $subs_width = ($sortelementattributes->{substring_width} or $default_substring_width);
    my $subs_side = ($sortelementattributes->{substring_side} or $default_substring_side);
    my $sort_dir = ($sortelementattributes->{sort_direction} or $default_direction);
    if ($subs_side eq 'right') {
      $subs_offset = 0 - $subs_width;
    }
    if ($sort_dir eq 'ascending') { # default, ascending sort
      return substr( $be->get_field($ytype), $subs_offset, $subs_width );
    }
    elsif ($sort_dir eq 'descending') { # descending sort
      return 9999 - substr($be->get_field($ytype), $subs_offset, $subs_width );
    }
  }
  else {
    return '';
  }
}

#========================================================
# Utility subs used elsewhere but relying on sorting code
#========================================================

sub _nodecode {
  my ($self, $citekey) = @_;
  my $be = $self->bibentry($citekey);
  my $no_decode = (Biber::Config->getoption('unicodebib') or
                   Biber::Config->getoption('fastsort') or
                   $be->get_field('datatype') eq 'xml');
  return $no_decode;
}

sub _getyearstring {
  my ($self, $citekey) = @_;
  my $be = $self->bibentry($citekey);
  my $string;
  $string = $self->_dispatch_sorting('sortyear', $citekey);
  return $string if $string;
  $string = $self->_dispatch_sorting('year', $citekey);
  return $string if $string;
  return '';
}

sub _getnamestring {
  my ($self, $citekey) = @_;
  my $be = $self->bibentry($citekey);
  my $string;
  $string = $self->_dispatch_sorting('sortname', $citekey);
  return $string if $string;
  $string = $self->_dispatch_sorting('author', $citekey);
  return $string if $string;
  $string = $self->_dispatch_sorting('editor', $citekey);
  return $string if $string;
  $string = $self->_dispatch_sorting('translator', $citekey);
  return $string if $string;
  return '';
}

sub _namestring {
  my ( $self, $citekey, $field ) = @_;
  my $bibentries = $self->bib;
  my $be = $bibentries->entry($citekey);
  my @names = @{$be->get_field($field)};
  my $str = '';
  my $truncated = 0;

  # perform truncation according to options minnames, maxnames
  if ( $#names + 1 > Biber::Config->getblxoption('maxnames', $be->get_field('entrytype'), $citekey) ) {
    $truncated = 1;
    @names = splice(@names, 0, Biber::Config->getblxoption('minnames', $be->get_field('entrytype'), $citekey) );
  }

  foreach ( @names ) {
    $str .= $_->{prefix} . '2'
      if ( $_->{prefix} and Biber::Config->getblxoption('useprefix', $be->get_field('entrytype'), $citekey ) );
    $str .= strip_nosort($_->{lastname}) . '2';
    $str .= strip_nosort($_->{firstname}) . '2' if $_->{firstname};
    $str .= $_->{suffix} if $_->{suffix};
    $str =~ s/2\z//xms;
    $str .= '1';
  }

  $str =~ s/\s+1/1/gxms;
  $str =~ s/1\z//xms;
  $str = normalize_string($str, $self->_nodecode($citekey));
  $str .= '1zzzz' if $truncated;
  return $str;
}

sub _liststring {
  my ( $self, $citekey, $field ) = @_;
  my $bibentries = $self->bib;
  my $be = $bibentries->entry($citekey);
  my @items = @{$be->get_field($field)};
  my $str = '';
  my $truncated = 0;
  # perform truncation according to options minitems, maxitems
  if ( $#items + 1 > Biber::Config->getblxoption('maxitems', $be->get_field('entrytype'), $citekey) ) {
    $truncated = 1;
    @items = splice(@items, 0, Biber::Config->getblxoption('minitems', $be->get_field('entrytype'), $citekey) );
  }

  # separate the items by a string to give some structure
  $str = join('2', @items);
  $str .= '1';

  $str =~ s/\s+1/1/gxms;
  $str =~ s/1\z//xms;
  $str = normalize_string($str, $self->_nodecode($citekey));
  $str .= '1zzzz' if $truncated;
  return $str;
}


#=====================================================
# OUTPUT SUBS
#=====================================================

# This is to test whether the fields " $be->get_field($field) " are defined and non empty
# (empty fields allow to suppress crossref inheritance)
sub _defined_and_nonempty {
    my $arg = shift;
    if (defined $arg) {
        if (ref \$arg eq 'SCALAR') {
            if ($arg ne '') {
                return 1
            } else {
                return 0
            }
        } elsif (ref $arg eq 'ARRAY') {
            my @arr = @$arg;
            if ( $#arr > -1 ) {
                return 1
            } else {
                return 0
            }
        } elsif (ref $arg eq 'HASH') {
            my @arr = keys %$arg;
            if ($#arr > -1 ) {
                return 1
            } else {
                return 0
            }
        } else {
            return 0
        }
    } else {
        return 0
    }
}

#TODO this could be done earlier as a method and stored in the object
sub _print_name {
  my ($self, $au, $citekey) = @_;
  my $bibentries = $self->bib;
  my $be = $bibentries->entry($citekey);
  my %nh  = %{$au};
  my $ln  = $nh{lastname};
  my $lni = getinitials($ln);
  my $fn  = "";
  $fn = $nh{firstname} if $nh{firstname};
  my $fni = "";
  $fni = getinitials($fn) if $nh{firstname};
  my $pre = "";
  $pre = $nh{prefix} if $nh{prefix};
  my $prei = "";
  $prei = getinitials($pre) if $nh{prefix};
  my $suf = "";
  $suf = $nh{suffix} if $nh{suffix};
  my $sufi = "";
  $sufi = getinitials($suf) if $nh{suffix};
  $fn =~ s/(\p{Lu}\.)\s+/$1~/g;   # J. Frank -> J.~Frank
  $fn =~ s/\s+(\p{Lu}\.)/~$1/g;   # Bernard H. -> Bernard~H.
  $pre =~ s/\s/~/g if $pre;       # van der -> van~der
  $ln =~ s/\s/~/g if $ln;         # Murder Smith -> Murder~Smith
  if ( Biber::Config->getblxoption('terseinits', $be->get_field('entrytype'), $citekey) ) {
    $lni = tersify($lni);
    $fni = tersify($fni);
    $prei = tersify($prei);
    $sufi = tersify($sufi);
  }
  return "    {{$ln}{$lni}{$fn}{$fni}{$pre}{$prei}{$suf}{$sufi}}%\n";
}

sub _printfield {
    my ($self, $field, $str) = @_;
    $str = latexescape($str);

    if (Biber::Config->getoption('wraplines')) {
        ## 12 is the length of '  \field{}{}'
        if ( 12 + length($field) + length($str) > 2*$Text::Wrap::columns ) {
            return "  \\field{$field}{%\n" . wrap('  ', '  ', $str) . "%\n  }\n";
        }
        elsif ( 12 + length($field) + length($str) > $Text::Wrap::columns ) {
            return wrap('  ', '  ', "\\field{$field}{$str}" ) . "\n";
        }
        else {
            return "  \\field{$field}{$str}\n";
        }
    }
     else {
       return "  \\field{$field}{$str}\n";
    }
}

sub _print_biblatex_entry {
    my ($self, $citekey) = @_;
    my $be = $self->bibentry($citekey)
        or $logger->logcroak("Cannot find $citekey");
    my $opts    = '';
    my $origkey = $citekey;
    if ( $be->get_field('origkey') ) {
        $origkey = $be->get_field('origkey');
    }

    if ( _defined_and_nonempty($be->get_field('options')) ) {
        $opts = $be->get_field('options');
    }

    my $str = "";

    $str .= "% sortstring = " . $be->get_field('sortstring') . "\n"
        if (Biber::Config->getoption('debug') || Biber::Config->getblxoption('debug'));

    $str .= "\\entry{$origkey}{" . $be->get_field('entrytype') . "}{$opts}\n";

    if ( $be->get_field('entrytype') eq 'set' ) {
        $str .= "  \\set{" . $be->get_field('entryset') . "}\n";
    }

    if (Biber::Config->getstate('inset_entries', $citekey)) {
      unless (lc(Biber::Config->getstate('inset_entries', $citekey)) eq lc($be->get_field('entryset'))) {
	$logger->warn('Key \"' . lc($citekey) . '\" thinks it is in set ' .
		     Biber::Config->getstate('inset_entries', $citekey) .
		     ' but the set is called "' . lc($be->get_field('entryset')) . '"!');
      }
      $str .= "  \\inset{" . Biber::Config->getstate('inset_entries', $citekey) . "}\n";
    }

    # make labelname a copy of the right thing before output of name lists
    if (_defined_and_nonempty($be->get_field('labelnamename'))) { # avoid unitialised variable warnings
      $be->set_field('labelname', $be->get_field($be->get_field('labelnamename')));
    }

    foreach my $namefield (@NAMEFIELDS) {
        next if $SKIPFIELDS{$namefield};
        if ( _defined_and_nonempty($be->get_field($namefield)) ) {
            my @nf = @{ $be->get_field($namefield) };
            if ( $be->get_field($namefield)->[-1]->{namestring} eq 'others' ) {
                $str .= "  \\true{more$namefield}\n";
                pop @nf; # remove the last element in the array
            };
            my $total = $#nf + 1;
            $str .= "  \\name{$namefield}{$total}{%\n";
            foreach my $n (@nf) {
                $str .= $self->_print_name($n, $citekey);
            }
            $str .= "  }\n";
        }
    }

    foreach my $listfield (@LISTFIELDS) {
        next if $SKIPFIELDS{$listfield};
        if ( _defined_and_nonempty($be->get_field($listfield)) ) {
            my @lf    = @{ $be->get_field($listfield) };
            if ( $be->get_field($listfield)->[-1] eq 'others' ) {
                $str .= "  \\true{more$listfield}\n";
                pop @lf; # remove the last element in the array
            };
            my $total = $#lf + 1;
            $str .= "  \\list{$listfield}{$total}{%\n";
            foreach my $f (@lf) {
                $str .= "    {". latexescape($f) . "}%\n";
            }
            $str .= "  }\n";
        }
    }

    my $namehash = $be->get_field('namehash');
    my $sortinit = substr $namehash, 0, 1;
    $str .= "  \\strng{namehash}{$namehash}\n";
    my $fullhash = $be->get_field('fullhash');
    $str .= "  \\strng{fullhash}{$fullhash}\n";

    if ( Biber::Config->getblxoption('labelalpha', $be->get_field('entrytype'), $citekey) ) {
        my $label = $be->get_field('labelalpha');
        $str .= "  \\field{labelalpha}{$label}\n";
    }
    $str .= "  \\field{sortinit}{$sortinit}\n";

    # The labelyear option determines whether "extrayear" and "labelyear" is output
    if ( Biber::Config->getblxoption('labelyear', $be->get_field('entrytype'), $citekey) ) {
        my $authoryear = $be->get_field('authoryear');
        if ( Biber::Config->getstate('seenauthoryear', $authoryear) > 1) {
            $str .= "  \\field{extrayear}{"
              . $be->get_field('extrayear') . "}\n";
        }

        # Construct labelyear
        if (_defined_and_nonempty($be->get_field('labelyearname'))) {
          $be->set_field('labelyear', $be->get_field($be->get_field('labelyearname')));
          # ignore endyear if it's the same as year
	  my ($ytype) = $be->get_field('labelyearname') =~ /\A(.*)year\z/xms;
          if (_defined_and_nonempty($be->get_field($ytype . 'endyear'))
              and ($be->get_field($be->get_field('labelyearname')) ne $be->get_field($ytype . 'endyear'))) {
            $be->set_field('labelyear',
			   $be->get_field('labelyear') . '\bibdatedash ' . $be->get_field($ytype . 'endyear'));
          }
        $str .= "  \\field{labelyear}{" . $be->get_field('labelyear') . "}\n";
        }
      }

      if ( Biber::Config->getblxoption('labelalpha', $be->get_field('entrytype'), $citekey) ) {
        my $authoryear = $be->get_field('authoryear');
        if ( Biber::Config->getstate('seenauthoryear', $authoryear) > 1) {
            $str .= "  \\field{extraalpha}{"
              . $be->get_field('extraalpha') . "}\n";
        }
    }

    if ( Biber::Config->getblxoption('labelnumber', $be->get_field('entrytype'), $citekey) ) {
        if ($be->get_field('shorthand')) {
            $str .= "  \\field{labelnumber}{"
              . $be->get_field('shorthand') . "}\n";
        }
        elsif ($be->get_field('labelnumber')) {
            $str .= "  \\field{labelnumber}{"
              . $be->get_field('labelnumber') . "}\n";
        }
    }

    if ( $be->get_field('ignoreuniquename') ) {

        $str .= "  \\count{uniquename}{0}\n";

    } else {
        my $lname = $be->get_field('labelnamename');
        my $name;
        my $lastname;
        my $nameinitstr;

        if ($lname) {
          if ($lname =~ m/\Ashort/xms) { # short* fields are just strings, not complex data
            $lastname    = $be->get_field($lname);
            $nameinitstr = $be->get_field($lname);
          } else {
            $name = $be->get_field($lname)->[0];
            $lastname = $name->{lastname};
            $nameinitstr = $name->{nameinitstring};
          }
        }
        if (scalar keys %{ Biber::Config->getstate('uniquenamecount', $lastname) } == 1 ) {
            $str .= "  \\count{uniquename}{0}\n";
        } elsif (scalar keys %{ Biber::Config->getstate('uniquenamecount', $nameinitstr) } == 1 ) {
            $str .= "  \\count{uniquename}{1}\n";
        } else {
            $str .= "  \\count{uniquename}{2}\n";
        }
    }

    if ( Biber::Config->getblxoption('singletitle', $be->get_field('entrytype'), $citekey)
        and Biber::Config->getstate('seennamehash', $be->get_field('fullhash')) < 2 )
    {
        $str .= "  \\true{singletitle}\n";
    }

    foreach my $ifield (@DATECOMPONENTFIELDS) {
        next if $SKIPFIELDS{$ifield};
        if ( _defined_and_nonempty($be->get_field($ifield)) ) {
	        $str .= $self->_printfield( $ifield, $be->get_field($ifield) );
        }
    }

    foreach my $lfield (@LITERALFIELDS) {
        next if $SKIPFIELDS{$lfield};
        if ( _defined_and_nonempty($be->get_field($lfield)) ) {
            next if ( $lfield eq 'crossref' and
                      Biber::Config->getstate('seenkeys', $be->get_field('crossref')) ); # belongs to @auxcitekeys

            my $lfieldprint = $lfield;
            if ($lfield eq 'journal') {
                $lfieldprint = 'journaltitle'
            };

            $str .= $self->_printfield( $lfieldprint, $be->get_field($lfield) );
        }
    }

    # this is currently "pages" only
    foreach my $rfield (@RANGEFIELDS) {
        next if $SKIPFIELDS{$rfield};
        if ( _defined_and_nonempty($be->get_field($rfield)) ) {
            my $rf = $be->get_field($rfield);
            $rf =~ s/[-–]+/\\bibrangedash /g;
            $str .= "  \\field{$rfield}{$rf}\n";
        }
    }

    foreach my $vfield (@VERBATIMFIELDS) {
        next if $SKIPFIELDS{$vfield};
        if ( _defined_and_nonempty($be->get_field($vfield)) ) {
            my $rf = $be->get_field($vfield);
            $str .= "  \\verb{$vfield}\n";
            $str .= "  \\verb $rf\n  \\endverb\n";
        }
    }
    if ( _defined_and_nonempty($be->get_field('keywords')) ) {
        $str .= "  \\keyw{" . $be->get_field('keywords') . "}\n";
    }

    # Append any warnings to the entry, if any
    if ($be->get_field('warnings')) {
      foreach my $warning (@{$be->get_field('warnings')}) {
        $str .= "  \\warn{$warning}\n";
      }
    }

    $str .= "\\endentry\n\n";

    #     $str = encode_utf8($str) if Biber::Config->getoption('unicodebbl');
    return $str;
}

=head1 AUTHOR

François Charette, C<< <firmicus at gmx.net> >>
Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2010 François Charette and Philip Kime, all rights reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

=cut

1;

# vim: set tabstop=4 shiftwidth=4 expandtab:
