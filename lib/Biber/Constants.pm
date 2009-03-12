package Biber::Constants;
use strict;
use warnings;
use Readonly;

use base 'Exporter';

our @EXPORT = qw{
	@NAMEFIELDS
	@LISTFIELDS
	@LITERALFIELDS_BASE
	@RANGEFIELDS
	@VERBATIMFIELDS
	@KEYFIELDS
	@ENTRIESTOSPLIT
	@LITERALFIELDS
	%CONFIG_DEFAULT
    $BIBLATEX_VERSION
};

Readonly::Scalar our $BIBLATEX_VERSION => '0.8';

## CONFIGURATION DEFAULTS
Readonly::Hash our %CONFIG_DEFAULT => (
    debug       => 0,
    labelalpha  => 0,
    useauthor   => 1,
    useeditor   => 1,
    usetranslator => 0,
    labelyear   => 0,
    labelnumber => 0,     #TODO ?
    singletitle => 0,
    uniquename  => 0,
    useprefix   => 0,
    terseinits  => 0,
    sorting     => 1, # corresponds to 'nty'
    sortlos     => 1,
    maxnames    => 3,
    minnames    => 1,
    maxline     => 79,    # this is currently ignored. TODO ?
	alphaothers => "+",
	# biber options:
	fastsort => 0,
	mincrossrefs =>  2,
	unicodebbl =>  0,
	unicodebib =>  0,
	bibdata =>  undef ,
	allentries =>  0,
	useprd =>  0,
	biberdebug =>  0,
);

### biblatex fields

Readonly::Array our @NAMEFIELDS  =>   qw{
  author editor commentator 
  translator redactor bookauthor 
  afterword introduction holder 
  sortname namea nameb namec 
};

Readonly::Array our @LISTFIELDS  =>   qw{
  publisher location address institution school language origlocation
  origpublisher lista listb listc listd liste listf };

Readonly::Array our @LITERALFIELDS_BASE  =>   qw{
  abstract addendum annotation booksubtitle booktitle booktitleaddon chapter
  day edition eid howpublished indextitle isan isbn ismn isrn issn issue
  issuesubtitle issuetitle iswc journalsubtitle journaltitle journal label
  mainsubtitle maintitle maintitleaddon month nameaddon note number
  origtitle pagetotal part reprinttitle series shorthand shorthandintro
  shortjournal shortseries shorttitle subtitle title titleaddon eprinttype
  urlday urlmonth urlyear venue version volume volumes usera userb userc userd
  usere userf hyphenation crossref entrysubtype execute gender indexsorttitle
  sortkey sorttitle sortyear xref };

# ignored by default: library remarks (more?)
# TODO : Add option to insert them if needed ?? 
# But then it is no longer Readonly…
# => Perhaps take them from config file that is loaded before Biber::Constants?

Readonly::Array our @RANGEFIELDS     =>  qw{ origyear pages year };
Readonly::Array our @VERBATIMFIELDS  =>  qw{ doi eprint file pdf url verba verbb verbc };
Readonly::Array our @KEYFIELDS  =>   qw{ 
  authortype bookpagination editortype origlanguage pagination 
  type nameatype namebtype namectype };

Readonly::Array our @ENTRIESTOSPLIT  =>  ( @NAMEFIELDS, @LISTFIELDS );

# literal and integer fields
# TODO add keys for selecting script, language, translation, transliteration.

# TODO validate the keys in the @keyfields ?

Readonly::Array our @LITERALFIELDS => ( @LITERALFIELDS_BASE, @KEYFIELDS );

1;

__END__

=pod

=head1

Biber::Constants - global readonly arrays for biber

=head2
