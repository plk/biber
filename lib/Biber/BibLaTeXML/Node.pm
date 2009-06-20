package Biber::BibLaTeXML::Node ;
use strict;
use warnings;
use Carp ;
use Biber::Constants ;
use Biber::Utils ;
use Data::Dump ;

sub XML::LibXML::NodeList::_biblatex_title_values {
    my $nodelist = shift ;
    my $node = $nodelist->get_node(1) ;
    my $fstring = '';
    my $sortstring = '';
    my $nosortprefix ;
    my $count = 0;

    foreach my $child ($node->childNodes) {
        my $type  = $child->nodeType ;

        if ( $type == 3 ) {
            my $value = $child->string_value ;
            $value =~ s/\s+/ /gms ;
            next if $value eq ' ' ;
            $fstring .= $value ;
            $sortstring .= $value ;
        } elsif ( $type == 1 ) {

            $fstring .= $child->_biblatex_fstring_value;
        
            $sortstring .= $child->_biblatex_sortstring_value 
                unless $child->nodeName eq 'bib:nosort';

            if (! $count && $child->nodeName eq 'bib:nosort') {
                $nosortprefix = $child->string_value ;
            }
        }
        $count++
    } ;
    my $sorttitle = $sortstring;
    $sorttitle =~ s/^\s+// ;
    my $indextitle = $fstring;
    $indextitle =~ s/^$nosortprefix\s*(.+)$/$1, $nosortprefix/ if $nosortprefix ;
    $indextitle =~ s/\s+$// ;
    my $indexsorttitle = $sorttitle ;
    $indexsorttitle .= ", $nosortprefix" if $nosortprefix ;
    $indexsorttitle =~ s/\s+$// ;

    return { 
        title          => $fstring,
        sorttitle      => $sorttitle,
        indextitle     => $indextitle,
        indexsorttitle => $indexsorttitle
    }
}

sub XML::LibXML::NodeList::_biblatex_value {
    my $nodelist = shift ;
    my $node = $nodelist->get_node(1) ;
    return $node->_biblatex_fstring_value
}

sub XML::LibXML::Node::_biblatex_fstring_value {
    my $node = shift ;
    my $childname = $node->nodeName ;
    my $str = '' ;
    my $innerstr = '' ;

    foreach my $child ($node->childNodes) {
       my $type  = $child->nodeType ;
       if ( $type == 1 ) {
           $innerstr .= $child->_biblatex_fstring_value ;
       } elsif ( $type == 3 ) {
           my $value = $child->string_value ;
           $value =~ s/\s+/ /gms ;
           next if $value eq ' ' ;
           $innerstr .= $value ;
       } 
    }

    if ($BIBLATEXML_FORMAT_ELEMENTS{$childname}) {
        $str =  '\\' . $BIBLATEXML_FORMAT_ELEMENTS{$childname} . '{' . $innerstr . '}' ;
    } 
    else {
        $str = $innerstr   
    }

    return $str
}

sub XML::LibXML::Node::_biblatex_sortstring_value {
    my $node = shift ;
    my $str = '' ;
    foreach my $child ($node->childNodes) {
        next if ( $child->nodeName eq 'bib:nosort' ) ;
        my $value ;
        if ( $child->hasChildNodes ) {
            $value = $child->_biblatex_sortstring_value 
        } else {
            $value = $child->string_value ;
            $value =~ s/\s+/ /gms ;
        }
        $str .= $value
    } 

    return $str;
}

sub XML::LibXML::Element::_find_biblatex_nodes {
    my ($self, $field, $dma, $subfield) = @_ ;
    ## $dma is an arrayref with list of displaymodes, in order of preference
    ## Ex: [ 'original', 'transliterated', 'uniform', 'translated' ]
    unless ($self->exists("bib:$field\[\@mode\]")) {
        my $xpath = "bib:$field" ;
        $xpath .= "/bib:$subfield" if defined $subfield ;
        return $self->findnodes($xpath)
    } ;
    foreach my $dm (@{$dma}) {
        my $xpath ;
        if ($dm eq 'original') {
            $xpath = "bib:$field\[not(\@mode)\]"
        } else {
            $xpath = "bib:$field\[\@mode=\"$dm\"\]" 
        } ;
        $xpath .= "/bib:$subfield" if defined $subfield ;
        if ($self->exists($xpath)) {
            return $self->findnodes($xpath) ;
            #last
        }
    }
}

1 ;

__END__

=pod

=head1 NAME

Biber::BibLaTeXML::Node - internal methods to extract and reformat data from BibLaTeXML fields

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

# vim: set tabstop=4 shiftwidth=4 expandtab: 

