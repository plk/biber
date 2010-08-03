package Biber::Internals;
use strict;
use warnings;
use Carp;
use Biber::Constants;
use Biber::Utils;
use Text::Wrap;
$Text::Wrap::columns = 80;
use Storable qw( dclone );
use List::AllUtils qw( :all );
use Log::Log4perl qw(:no_extra_logdie_message);
use POSIX qw( locale_h ); # for lc() of sorting strings

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
  my $bibentries = $section->bib;
  my $initstr = '';
  my $be = $bibentries->entry($citekey);
  ## my $nodecodeflag = $self->_decode_or_not($citekey);

  if ( $names->count_elements <= Biber::Config->getblxoption('maxnames') ) {    # 1 to maxname names
    foreach my $n (@{$names->names}) {
      if ( $n->get_prefix and
        Biber::Config->getblxoption('useprefix', $be->get_field('entrytype'), $citekey ) ) {
        $initstr .= $n->get_prefix_it;
      }
      $initstr .= $n->get_lastname_it;

      if ( $n->get_suffix ) {
        $initstr .= $n->get_suffix_it;
      }

      if ( $n->get_firstname ) {
        $initstr .= $n->get_firstname_it;
      }
    }
  }
  # > maxname names: only take initials of first getblxoption('minnames', $citekey)
  else {
    foreach my $i ( 1 .. Biber::Config->getblxoption('minnames') ) {
      if ( $names->nth_element($i)->get_prefix and
        Biber::Config->getblxoption('useprefix', $be->get_field('entrytype'), $citekey) ) {
        $initstr .= $names->nth_element($i)->get_prefix_it;
      }

      if ( $names->nth_element($i)->get_suffix ) {
        $initstr .= $names->nth_element($i)->get_suffix_it;
      }

      $initstr .= $names->nth_element($i)->get_lastname_it;
      if ( $names->nth_element($i)->get_firstname ) {
        $initstr .= $names->nth_element($i)->get_firstname_it;
      }
      $initstr .= "+";
    }
  }
  return normalize_string_lite($initstr);
}

sub _getfullhash {
  my ($self, $citekey, $names) = @_;
  my $initstr = '';
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bib;
  my $be = $bibentries->entry($citekey);
  foreach my $n (@{$names->names}) {
    if ( $n->get_prefix and
      Biber::Config->getblxoption('useprefix', $be->get_field('entrytype'), $citekey ) ) {
      $initstr .= $n->get_prefix_it;
    }
    $initstr .= $n->get_lastname_it;

    if ( $n->get_suffix ) {
      $initstr .= $n->get_suffix_it;
    }

    if ( $n->get_firstname ) {
      $initstr .= $n->get_firstname_it;
    }
  }
  return normalize_string_lite($initstr);
}

sub _getlabel {
  my ($self, $citekey, $namefield) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bib;
  my $be = $bibentries->entry($citekey);
  my $dt = $be->get_field('datatype');
  my $names = $be->get_field($namefield);
  my $alphaothers = Biber::Config->getblxoption('alphaothers', $be->get_field('entrytype'));
  my $sortalphaothers = Biber::Config->getblxoption('sortalphaothers', $be->get_field('entrytype'));
  my $useprefix = Biber::Config->getblxoption('useprefix', $be->get_field('entrytype'), $citekey);
  my $maxnames = Biber::Config->getblxoption('maxnames');
  my $minnames = Biber::Config->getblxoption('minnames');
  my $label = '';
  my $sortlabel = ''; # This contains sortalphaothers instead of alphaothers, if defined
  # This is needed in cases where alphaothers is something like
  # '\textasteriskcentered' which would mess up sorting.

  my @lastnames = map { normalize_string( $_->get_lastname, $dt ) } @{$names->names};
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
  my $code_ref = ${$dispatch_sorting->{$sortfield}}[0];
  my $code_args_ref = ${$dispatch_sorting->{$sortfield}}[1];
  return &{$code_ref}($self, $citekey, $sortelementattributes, $code_args_ref);
}

# Conjunctive set of sorting sets
sub _generatesortstring {
  my ($self, $citekey, $sortscheme) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $sortstring;
  foreach my $sortset (@{$sortscheme}) {
    $BIBER_SORT_FINAL = 0; # reset sorting short-circuit
    $sortstring .= $self->_sortset($sortset, $citekey);

  # Only append sorting separator if this isn't a null sort string element
  # Put another way, null elements should be completely ignored and no separator
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

  # Decide if we are doing case-insensitive sorting or not
  # If so, lowercase according to locale
  my $casesort;
  if (Biber::Config->getoption('cssort')) {
    $casesort = $sortstring;
  }
  else {
    if (my $thislocale = Biber::Config->getoption('locale')) {
      use locale;
      setlocale( LC_CTYPE, $thislocale );
    }
    $casesort = lc($sortstring);
  }
  $be->set_field('sortstring', $casesort);

  # Generate sortinit - the initial letter of the sortstring. This must ignore
  # presort characters, naturally
  my $pre;
  my $ss = $sortstring;
  # Prefix is either specified or 'mm' default plus the $sorting_sep
  if ($be->get_field('presort')) {
    $pre = $be->get_field('presort');
    $pre .= $sorting_sep;
  }
  else {
    $pre = 'mm' . $sorting_sep;
  }
  # Strip off the prefix
  $ss =~ s/\A$pre//;
  $be->set_field('sortinit', substr $ss, 0, 1);
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
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bib;
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
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  return (first_index {$_ eq $citekey} $section->get_orig_order_citekeys) + 1; # +1 just to make it easier to debug
}

sub _sort_debug {
  my ($self, $citekey, $sortelementattributes) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  return $citekey;
}

# This is a meta-sub which uses the optional arguments to the dispatch code
# It's done to avoid having many repetitions of almost identical sorting code
# for the many date sorting options
# It deals with day and month fields
sub _sort_dm {
  my ($self, $citekey, $sortelementattributes, $args) = @_;
  my $dmtype = (@{$args})[0]; # get day/month field type
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bib;
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
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bib;
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
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bib;
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
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bib;
  my $be = $bibentries->entry($citekey);
  my $default_pad_width = 4;
  my $default_pad_side = 'left';
  my $default_pad_char = '0';
  if (Biber::Config->getblxoption('labelalpha', $be->get_field('entrytype')) and
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
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bib;
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
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bib;
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
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bib;
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
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bib;
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
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bib;
  my $be = $bibentries->entry($citekey);
  return $be->get_field('presort') ? $be->get_field('presort') : '';
}

sub _sort_publisher {
  my ($self, $citekey, $sortelementattributes) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bib;
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
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bib;
  my $be = $bibentries->entry($citekey);
  return $be->get_field('pubstate') ? $be->get_field('pubstate') : '';
}

sub _sort_sortkey {
  my ($self, $citekey, $sortelementattributes) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bib;
  my $be = $bibentries->entry($citekey);
  if ($be->get_field('sortkey')) {
    my $sortkey = $be->get_field('sortkey');
    $sortkey = LaTeX::Decode::latex_decode($sortkey, strip_outer_braces=>1)
      unless $self->_nodecode($citekey);
    return $sortkey;
  }
  else {
    return '';
  }
}

sub _sort_sortname {
  my ($self, $citekey, $sortelementattributes) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bib;
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
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bib;
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
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bib;
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
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bib;
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
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bib;
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
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $no_decode = (Biber::Config->getoption('unicodebib') or
      Biber::Config->getoption('fastsort') or
      $be->get_field('datatype') eq 'xml');
  return $no_decode;
}

sub _namestring {
  my $self = shift;
  my ($citekey, $field) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bib;
  my $be = $bibentries->entry($citekey);
  my $names = $be->get_field($field);
  my $str = '';
  my $truncated = 0;
  my $truncnames = dclone($names);

  # perform truncation according to options minnames, maxnames
  if ( $names->count_elements > Biber::Config->getblxoption('maxnames') ) {
    $truncated = 1;
    $truncnames = $truncnames->first_n_elements(Biber::Config->getblxoption('minnames'));
  }

  foreach my $n ( @{$truncnames->names} ) {
    $str .= $n->get_prefix . '2'
      if ( $n->get_prefix and
           Biber::Config->getblxoption('useprefix', $be->get_field('entrytype'), $citekey ) );
    $str .= strip_nosort($n->get_lastname) . '2';
    $str .= strip_nosort($n->get_firstname) . '2' if $n->get_firstname;
    $str .= $n->get_suffix if $n->get_suffix;
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
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $bibentries = $section->bib;
  my $be = $bibentries->entry($citekey);
  my @items = @{$be->get_field($field)};
  my $str = '';
  my $truncated = 0;

  # perform truncation according to options minitems, maxitems
  if ( $#items + 1 > Biber::Config->getblxoption('maxitems') ) {
    $truncated = 1;
    @items = splice(@items, 0, Biber::Config->getblxoption('minitems') );
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

=head2 process_entry_options

    Set per-entry options

    "dataonly" is a special case and expands to "skiplab,skiplos,skipbib"
    but only "skiplab" and "skiplos" are dealt with in Biber, "skipbib" is
    dealt with in biblatex.

    The skip* local options are dealt with by not generating at all:

    * labelyear
    * extrayear
    * labelalpha
    * extraalpha

=cut

sub process_entry_options {
  my $self = shift;
  my $be = shift;
  my $citekey = lc($be->get_field('origkey'));
  if ( my $options = $be->get_field('options') ) {
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

# vim: set tabstop=2 shiftwidth=2 expandtab:
