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

    #$str =~ s/\s+$//; 

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

#sub XML::LibXML::NodeList::_biblatex_title_values_flat {
#    my $nodelist = shift ;
#    my $node = $nodelist->get_node(1) ;
#    my @title_stringbuffer ;
#    my @sorttitle_stringbuffer ;
#    my @indextitle_stringbuffer ;
#    my @indexsorttitle_stringbuffer ;
#    my $nosortprefix ;
#
#    foreach my $child ($node->childNodes) {
#        my $type  = $child->nodeType ;
#        my $value = $child->string_value ;
#        # this is like XPath's normalize-string() but we don't want  
#        # to remove a single space at begin and end of a string:
#        $value =~ s/\s+/ /gms ;
#        next if $value eq ' ' ;
#        # child node is a string
#        if ($type == 3) {
#            push @title_stringbuffer, $value ;
#            push @sorttitle_stringbuffer, $value ;
#            push @indextitle_stringbuffer, $value ;
#            push @indexsorttitle_stringbuffer, $value ;
#        } 
#        # child node is an element
#        elsif ($type == 1) {
#            my @childnodes = $child->childNodes;
#            if ( $#childnodes > 0 ) {
#                carp "Sorry, nested formatting elements are not yet supported"
#            } ;
#            my $childname = $child->nodeName;
#            if ($BIBLATEXML_FORMAT_ELEMENTS{$childname}) {
#                my $fstr =  '\\' . $BIBLATEXML_FORMAT_ELEMENTS{$childname} . '{' . $value . '}' ;
#                push @title_stringbuffer, $fstr ;
#                push @sorttitle_stringbuffer, $value ;
#                push @indextitle_stringbuffer, $fstr ;
#                push @indexsorttitle_stringbuffer, $value ;
#            } 
#            elsif ($childname eq 'bib:nosort') {
#                push @title_stringbuffer, $value ;
#				$nosortprefix = $value if ( $#title_stringbuffer == 0 ) ;
#                $nosortprefix =~ s/\s+$// ;
#            }
#        }
#    } ;
#    my $title = join('', @title_stringbuffer) ; 
#    my $sorttitle = join('', @sorttitle_stringbuffer) ; 
#    $sorttitle =~ s/^\s+// ;
#    #$sorttitle =~ s/^(.)/\U$1/ ;
#    my $indextitle = join('', @indextitle_stringbuffer) ; 
#    $indextitle =~ s/^\s+// ;
#    $indextitle .= ", $nosortprefix" if $nosortprefix ;
#    my $indexsorttitle = join('', @indexsorttitle_stringbuffer) ; 
#    $indexsorttitle =~ s/^\s+// ;
#    $indexsorttitle .= ", $nosortprefix" if $nosortprefix ;
#    #$indexsorttitle =~ s/^(.)/\U$1/ ;
#
#    return { 
#        title          => $title,
#        sorttitle      => $sorttitle,
#        indextitle     => $indextitle,
#        indexsorttitle => $indexsorttitle
#    }
#}

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

