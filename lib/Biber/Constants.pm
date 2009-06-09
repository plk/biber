package Biber::Constants ;
use strict ;
use warnings ;
use Readonly ;

use base 'Exporter' ;

our @EXPORT = qw{
                  @NAMEFIELDS
                  @LISTFIELDS
                  @LITERALFIELDS_BASE
                  @RANGEFIELDS
                  @VERBATIMFIELDS
                  @TITLEFIELDS
                  @KEYFIELDS
                  @COMMASEP_FIELDS
                  @ENTRIESTOSPLIT
                  @LITERALFIELDS
                  %SKIPFIELDS
                  %CONFIG_DEFAULT
                  $BIBLATEX_VERSION
                  $BIBER_SORT_FINAL
                  %ALIASES
                  %NUMERICALMONTH
              } ;

Readonly::Scalar our $BIBLATEX_VERSION => '0.8' ;
our $BIBER_SORT_FINAL = 0;

## Biber CONFIGURATION DEFAULTS
our %CONFIG_DEFAULT = (
  validate => 0,
  fastsort => 0,
  mincrossrefs =>  2,
  unicodebbl =>  0,
  unicodebib =>  0,
  bibdata =>  undef ,
  allentries =>  0,
  useprd =>  0,
  debug =>  0,
  quiet => 0,
  collate_options => 'level=>2, table=>"latinkeys.txt"',
) ;

### biblatex fields

Readonly::Array our @NAMEFIELDS  =>   qw{
  author editor shortauthor shorteditor commentator translator redactor 
  bookauthor introduction foreword afterword holder sortname 
  namea nameb namec } ;

Readonly::Array our @LISTFIELDS  =>   qw{
  publisher location address institution school language origlocation
  origpublisher lista listb listc listd liste listf } ;

Readonly::Array our @LITERALFIELDS_BASE  =>   qw{
  abstract addendum annotation chapter day edition eid howpublished isan isbn
  ismn isrn issn issue iswc label month nameaddon note number pagetotal part
  series shorthand shorthandintro shortjournal shortseries eprinttype urlday
  urlmonth urlyear urldate venue version volume volumes usera userb userc userd
  usere userf hyphenation crossref entrysubtype execute gender sortkey sortyear
  xref
  } ;

Readonly::Array our @TITLEFIELDS => qw{ title 
  subtitle titleaddon shorttitle sorttitle indextitle indexsorttitle
  origtitle issuetitle issuesubtitle maintitle mainsubtitle maintitleaddon
  booktitle booksubtitle booktitleaddon journal journaltitle journalsubtitle
  reprinttitle };

# Fields that are used internally by biber but are not passed to the bbl output
Readonly::Array our @SKIPFIELDS => qw{ sortname sorttitle presort sortkey sortyear } ;
our %SKIPFIELDS = map { $_ => 1 } @SKIPFIELDS ;

# ignored by default: library remarks (more?)
# TODO : Add option to insert them if needed ?? 
# But then it is no longer Readonly…
# => Perhaps take them from config file that is loaded before Biber::Constants?

Readonly::Array our @RANGEFIELDS     =>  qw{ origyear pages year } ;
Readonly::Array our @VERBATIMFIELDS  =>  qw{ doi eprint file pdf url verba verbb verbc } ;
Readonly::Array our @KEYFIELDS  =>   qw{ 
  authortype bookpagination editortype origlanguage pagination 
  type nameatype namebtype namectype } ;
Readonly::Array our @COMMASEP_FIELDS => qw{ options keywords entryset } ;

Readonly::Array our @ENTRIESTOSPLIT  =>  ( @NAMEFIELDS, @LISTFIELDS ) ;

# literal and integer fields
# TODO add keys for selecting script, language, translation, transliteration.

# TODO validate the keys in the @keyfields ?

Readonly::Array our @LITERALFIELDS => ( @TITLEFIELDS, @LITERALFIELDS_BASE, @KEYFIELDS ) ;

Readonly::Hash our %ALIASES => ( 
  'address' => 'location',
  'school'  => 'institution',
  'annote'  => 'annotation',
  'key'     => 'sortkey'
) ;

Readonly::Hash our %NUMERICALMONTH => (
  'January' => 1,
  'February' => 2,
  'March' => 3,
  'April' => 4,
  'May' => 5,
  'June' => 6,
  'July' => 7,
  'August' => 8,
  'September' => 9,
  'October' => 10,
  'November' => 11,
  'December' => 12,
  'january' => 1,
  'february' => 2,
  'march' => 3,
  'april' => 4,
  'may' => 5,
  'june' => 6,
  'july' => 7,
  'august' => 8,
  'september' => 9,
  'october' => 10,
  'november' => 11,
  'december' => 12,
  'jan' => 1,
  'feb' => 2,
  'mar' => 3,
  'apr' => 4,
  'may' => 5,
  'jun' => 6,
  'jul' => 7,
  'aug' => 8,
  'sep' => 9,
  'oct' => 10,
  'nov' => 11,
  'dec' => 12
  ) ;

1 ;

__END__

=pod

=head1 NAME

Biber::Constants - global constants for biber

=head1 AUTHOR

François Charette, C<< <firmicus at gmx.net> >>

=head1 BUGS

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>. 

=head1 COPYRIGHT & LICENSE

Copyright 2009 François Charette, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# vim: set tabstop=4 shiftwidth=4: 
