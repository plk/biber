package Biber::BibLaTeXML::Node;
use strict;
use warnings;
use Carp;
use Biber::Constants;
use Biber::Utils;
use Log::Log4perl qw(:no_extra_logdie_message);
my $logger = Log::Log4perl::get_logger('main');
##use Data::Dump;

## this returns the title, sorttitle, indextitle and indexsorttitle
## as a hash ref
sub XML::LibXML::NodeList::_biblatex_title_values {
  my $nodelist = shift;
  my $node = $nodelist->get_node(1);
  my $fstring = '';
  my $sortstring = '';
  my $nosortprefix;
  my $count = 0;

  foreach my $child ($node->childNodes) {
    my $type  = $child->nodeType;

    if ( $type == 3 ) {
      my $value = $child->string_value;
      $value =~ s/\s+/ /gms;
      next if $value eq ' ';
      $fstring .= $value;
      $sortstring .= $value;
    } elsif ( $type == 1 ) {

      $fstring .= $child->_biblatex_fstring_value;

      $sortstring .= $child->_biblatex_sortstring_value
        unless $child->nodeName eq 'bib:nosort';

      if (! $count && $child->nodeName eq 'bib:nosort') {
        $nosortprefix = $child->string_value;
      }
    }
    $count++
  };
  my $sorttitle = $sortstring;
  $sorttitle =~ s/^\s+//;
  my $indextitle = $fstring;
  $indextitle =~ s/^$nosortprefix\s*(.+)$/$1, $nosortprefix/ if $nosortprefix;
  $indextitle =~ s/\s+$//;
  my $indexsorttitle = $sorttitle;
  $indexsorttitle .= ", $nosortprefix" if $nosortprefix;
  $indexsorttitle =~ s/\s+$//;

  return {
    title          => $fstring,
    sorttitle      => $sorttitle,
    indextitle     => $indextitle,
    indexsorttitle => $indexsorttitle
    }
}

sub XML::LibXML::NodeList::_biblatex_value {
  my $nodelist = shift;
  my $node = $nodelist->get_node(1);
  return $node->_biblatex_fstring_value
}

sub XML::LibXML::Node::_biblatex_value {
  my $node = shift ;
  return $node->_biblatex_fstring_value
}

sub XML::LibXML::Node::_biblatex_fstring_value {
  my $node = shift;
  my $childname = $node->nodeName;
  my $str = '';
  my $innerstr = '';

  foreach my $child ($node->childNodes) {
    my $type  = $child->nodeType;
    if ( $type == 1 ) {
      $innerstr .= $child->_biblatex_fstring_value;
    } elsif ( $type == 3 ) {
      my $value = $child->string_value;
      $value =~ s/\s+/ /gms;
      next if $value eq ' ';
      $innerstr .= $value;
    }
  }

  if ($BIBLATEXML_FORMAT_ELEMENTS{$childname}) {
    $str =  '\\' . $BIBLATEXML_FORMAT_ELEMENTS{$childname} . '{' . $innerstr . '}';
  }
  else {
    $str = $innerstr
  }

  return $str
}

sub XML::LibXML::Node::_biblatex_sortstring_value {
  my $node = shift;
  my $str = '';
  foreach my $child ($node->childNodes) {
    next if ( $child->nodeName eq 'bib:nosort' );
    my $value;
    if ( $child->hasChildNodes ) {
      $value = $child->_biblatex_sortstring_value
    } else {
      $value = $child->string_value;
      $value =~ s/\s+/ /gms;
    }
    $str .= $value
  }

  return $str;
}

## returns an array of xpaths in order of priority
## given an entry field, display mode, locale and subfield as args
sub _get_xpath_array {
  my ($field, $dm, $locale, $subfield) = @_ ;

  # $dm and $subfield can be undef

  my $xpath_field = "bib:$field";
  my $xpath_dm;
  my $xpath_locale;
  my $xpath_localeb;
  my @xpath_array = ();

  $locale =~ s/\..+$//; # remove encoding suffix
  my $localeb = $locale ;
  $localeb =~ s/_.+$//; # base locale
  if ( ! defined $dm or $dm eq 'uniform' or $dm eq 'translated' ) {
    $xpath_locale  = "\@xml:lang=\"$locale\"";
    $xpath_localeb = "\@xml:lang=\"$localeb\"";
  }

  if ( defined $dm and $dm ne 'original' ) {
    $xpath_dm = "\@mode=\"$dm\""
  }
  else {
    $xpath_dm = 'not(@mode)'
  }

  if ( defined $xpath_locale ) {
    push @xpath_array,
      $xpath_field.'['.$xpath_dm.' and '.$xpath_locale.']';
    push @xpath_array,
      $xpath_field.'['.$xpath_dm.' and '.$xpath_localeb.']'
      unless ( $xpath_locale eq $xpath_localeb );
  }

  push @xpath_array, $xpath_field.'['.$xpath_dm.']';

  if (defined $subfield) {
    map { $_ .= "/bib:$subfield" } @xpath_array
  }

  return @xpath_array
}

sub XML::LibXML::Element::_find_biblatex_nodes {
  my ($node, $biber, $field, $dma, $subfield) = @_ ;
  ## $dma is an arrayref with list of displaymodes, in order of preference
  ## Ex: [ 'original', 'romanized', 'uniform', 'translated' ]

  my $locale = Biber::Config->getoption('locale') or $logger->logcroak("No locale defined");

  unless ($node->exists("bib:$field\[\@mode\]")) {
    foreach my $xpath ( _get_xpath_array($field, undef, $locale, $subfield) ) {
      return $node->findnodes($xpath) if $node->exists($xpath);
    }
  }

  foreach my $dm (@{$dma}) {
    foreach my $xpath ( _get_xpath_array($field, $dm, $locale, $subfield) ) {
      ##ddx "Checking $xpath ...";
      $logger->trace("Checking for node $xpath");
      if ($node->exists($xpath)) {
        $logger->debug("Found node $xpath");
        return $node->findnodes($xpath)
      }
    }
  }
}

sub XML::LibXML::NodeList::_normalize_string_value {
  my $nodelist = shift ;
  my $node = $nodelist->get_node(1) || croak "Can't get node : $@";
  return $node->findvalue("normalize-space()")
}

sub XML::LibXML::Element::_normalize_string_value {
  my $node = shift ;
  return $node->findvalue("normalize-space()")
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Biber::BibLaTeXML::Node - internal methods to extract and reformat data from BibLaTeXML fields

=head1 AUTHOR

François Charette, C<< <firmicus at gmx.net> >>

=head1 BUGS

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2010 François Charette, all rights reserved.

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

