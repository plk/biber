package Biber::Internals;
#use feature 'unicode_strings';

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
  my $initstr = '';

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
      if ( $n->get_middlename ) {
        $initstr .= $n->get_middlename_it;
      }
     # without useprefix, prefix is not first in the hash
     if ( $n->get_prefix and not
       Biber::Config->getblxoption('useprefix', $be->get_field('entrytype'), $citekey ) ) {
       $initstr .= $n->get_prefix_it;
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
      if ( $names->nth_element($i)->get_middlename ) {
        $initstr .= $names->nth_element($i)->get_middlename_it;
      }

      # without useprefix, prefix is not first in the hash
      if ( $names->nth_element($i)->get_prefix and not
           Biber::Config->getblxoption('useprefix', $be->get_field('entrytype'), $citekey) ) {
        $initstr .= $names->nth_element($i)->get_prefix_it;
      }
      $initstr .= "+";
    }
  }
  return normalise_string_lite($initstr);
}

sub _getfullhash {
  my ($self, $citekey, $names) = @_;
  my $initstr = '';
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
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

    if ( $n->get_middlename ) {
      $initstr .= $n->get_middlename_it;
    }

    # without useprefix, prefix is not first in the hash
    if ( $n->get_prefix and not
         Biber::Config->getblxoption('useprefix', $be->get_field('entrytype'), $citekey ) ) {
      $initstr .= $n->get_prefix_it;
    }

  }
  return normalise_string_lite($initstr);
}

sub _getlabel {
  my ($self, $citekey, $namefield) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
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
        # warn only on second sorting pass to avoid user confusion
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

sub _namestring {
  my $self = shift;
  my ($citekey, $field) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $be = $section->bibentry($citekey);
  my $names = $be->get_field($field);
  my $str = '';
  my $truncated = 0;
  my $truncnames = dclone($names);

  # These should be symbols which can't appear in names
  # This means, symbols which normalise_string_sort strips out
  my $nsi    = '_';          # name separator, internal
  my $nse    = '+';          # name separator, external
  # Guaranteed to sort after everything else as it's the last legal Unicode code point
  my $trunc = "\x{10FFFD}";  # sort string for "et al" truncated name

  # perform truncation according to options minnames, maxnames
  if ( $names->count_elements > Biber::Config->getblxoption('maxnames') ) {
    $truncated = 1;
    $truncnames = $truncnames->first_n_elements(Biber::Config->getblxoption('minnames'));
  }

  # We strip nosort first otherwise normalise_string_sort damages diacritics
  # We strip each individual component instead of the whole thing so we can use
  # as name separators things which would otherwise be stripped. This way we
  # guarantee that the separators are never in names
  foreach my $n ( @{$truncnames->names} ) {
    # If useprefix is true, use prefix at start of name for sorting
    if ( $n->get_prefix and
         Biber::Config->getblxoption('useprefix', $be->get_field('entrytype'), $citekey ) ) {
      $str .= normalise_string_sort($n->get_prefix, $field) . $nsi;
    }
    $str .= normalise_string_sort($n->get_lastname, $field) . $nsi;
    $str .= normalise_string_sort($n->get_firstname, $field) . $nsi if $n->get_firstname;
    $str .= normalise_string_sort($n->get_middlename, $field) . $nsi if $n->get_middlename;
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
