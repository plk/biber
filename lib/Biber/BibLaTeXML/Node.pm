package Biber::BibLaTeXML::Node ;
use strict;
use warnings;
use Carp ;
use Biber::Constants ;
use Biber::Utils ;

sub XML::LibXML::NodeList::_biblatex_title_values {
    my $nodelist = shift ;
    my $node = $nodelist->get_node(1) ;
    my $fieldname = $node->nodeName ;
    my @title_stringbuffer ;
    my @sorttitle_stringbuffer ;
    my @indextitle_stringbuffer ;
    my @indexsorttitle_stringbuffer ;
    my $nosortprefix ;

    foreach my $child ($node->childNodes) {
        my $type  = $child->nodeType;
        my $value = $child->findvalue("normalize-space()") ;
        next if $value eq '' ;
        # child node is a string
        if ($type == 3) {
            push @title_stringbuffer, $value ;
            push @sorttitle_stringbuffer, $value ;
            push @indextitle_stringbuffer, $value ;
            push @indexsorttitle_stringbuffer, $value ;
        } 
        # child node is an element
        elsif ($type == 1) {
            my $childname = $child->nodeName;
            if ($BIBLATEXML_FORMAT_ELEMENTS{$childname}) {
                my $fstr =  '\\' . $BIBLATEXML_FORMAT_ELEMENTS{$childname} . '{' . $value . '}' ;
                push @title_stringbuffer, $fstr ;
                push @sorttitle_stringbuffer, $value ;
                push @indextitle_stringbuffer, $fstr ;
                push @indexsorttitle_stringbuffer, $value ;
            } 
            elsif ($childname eq 'bib:nosort') {
                push @title_stringbuffer, $value ;
				$nosortprefix = $value if ( $#title_stringbuffer == 0 ) ;
            }
        }
    } ;
    my $title = join(' ', @title_stringbuffer) ; 
    my $sorttitle = join(' ', @sorttitle_stringbuffer) ; 
    $sorttitle =~ s/^(.)/\U$1/ ;
    my $indextitle = join(' ', @indextitle_stringbuffer) ; 
    $indextitle .= ", $nosortprefix" if $nosortprefix ;
    my $indexsorttitle = join(' ', @indexsorttitle_stringbuffer) ; 
    $indexsorttitle .= ", $nosortprefix" if $nosortprefix ;
    $indexsorttitle =~ s/^(.)/\U$1/ ;

    return { 
        title          => $title,
        sorttitle      => $sorttitle,
        indextitle     => $indextitle,
        indexsorttitle => $indexsorttitle
    }
}

sub XML::LibXML::NodeList::_biblatex_value {
    my $nodelist = shift ;
    my $node = $nodelist->get_node(1) ;
    my $fieldname = $node->nodeName ;
    if ( $FIELDS_WITH_CHILDREN{$fieldname} ) {
        my @stringbuffer ;
        foreach my $child ($node->childNodes) {
            my $type  = $child->nodeType;
            my $value = $child->findvalue("normalize-space()") ;
            next if $value eq '' ;
            # child node is a string
            if ($type == 3) {
                push @stringbuffer, $value ;
            } 
            # child node is an element
            elsif ($type == 1) {
                my $childname = $child->nodeName;
                if ($BIBLATEXML_FORMAT_ELEMENTS{$childname}) {
                    push @stringbuffer, 
                      '\\' . $BIBLATEXML_FORMAT_ELEMENTS{$childname} . '{' . $value . '}' ;
                } elsif ($childname eq 'bib:nosort') {
                    push @stringbuffer, $value ; 
                }
            }
        } 
        return join ' ', @stringbuffer
    }
    else {
        return $node->findvalue("normalize-space()")
    }
}

sub XML::LibXML::NodeList::_biblatex_sort_value {
    my $nodelist = shift ;
    my $node = $nodelist->get_node(1) ;
    my $fieldname = $node->nodeName ;
    if ( $FIELDS_WITH_CHILDREN{$fieldname} ) {
        my @stringbuffer ;
        foreach my $child ($node->childNodes) {
            next if $child->nodeName eq 'bib:nosort' ;
            my $value = $child->findvalue("normalize-space()");
            next if $value eq '' ;
            push @stringbuffer, $value ;
        } 
        my $str = join(' ', @stringbuffer) ;
        $str =~ s/^(.)/\U$1/ ;
        return $str;
    }
    else {
        return $node->findvalue("normalize-space()")
    }
}

1 ;

__END__

=pod

=head1 NAME

Biber::BibLaTeXML::Node - internal methods to extract data from BibLaTeXML fields

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

