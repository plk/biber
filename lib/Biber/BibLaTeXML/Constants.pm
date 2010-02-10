package Biber::BibLaTeXML::Constants;
use strict;
use warnings;
use Carp;
use Readonly;
use base 'Exporter';

#use Biber::Constants;
use Log::Log4perl qw(:no_extra_logdie_message);
my $logger = Log::Log4perl::get_logger('main');

our @EXPORT = qw{
  $BIBLATEXML_NAMESPACE_URI
  %BIBLATEXML_FORMAT_ELEMENTS
  } ;

Readonly::Scalar our $BIBLATEXML_NAMESPACE_URI => 'http://biblatex-biber.sourceforge.net/biblatexml';

# TODO ask PL to define mkbibsubscript in biblatex ?
Readonly::Hash our %BIBLATEXML_FORMAT_ELEMENTS => (
  'bib:quote'       => 'mkbibquote',
  'bib:subscript'   => 'textsubscript',
  'bib:superscript' => 'mkbibsuperscript',
  'bib:emphasis'    => 'mkbibemph'
  );

## FIXME these are no longer needed: remove?
#Readonly::Array our @BIBLATEXML_FORMATTEXT => qw(
#  abstract
#  addendum
#  annotation
#  booksubtitle
#  booktitleaddon
#  issue
#  issuetitleaddon
#  issuesubtitle
#  journalsubtitle
#  mainsubtitle
#  maintitleaddon
#  note
#  origtitle
#  reprinttitle
#  subtitle
#  titleaddon
#  venue
#  publisher
#  origpublisher
#  publisherinfo
#  item
#  publishername
#  remarks
#  );
#
#Readonly::Array our @BIBLATEXML_FORMATTEXT_B => qw(
#  booktitle
#  eventtitle
#  issuetitle
#  journaltitle
#  maintitle
#  shorttitle
#  title
#  );
#
#our %FIELDS_WITH_CHILDREN = map { $_ => 1 } ( @BIBLATEXML_FORMATTEXT, @BIBLATEXML_FORMATTEXT_B );

1;

=pod

=encoding utf-8

=head1 NAME

Biber::BibLaTeXML::Constants - global constants specific to BibLaTeXML processing

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

# vim: set tabstop=2 shiftwidth=2 expandtab:

