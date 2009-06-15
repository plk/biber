package Biber::BibLaTeXML::Node ;
use strict;
use warnings;
use Carp ;
use XML::LibXML ;
use base 'XML::LibXML::Node' ;
use Biber::Constants ;

sub _biblatex_value {
    my $node = shift ;
    my $fieldname = $node->nodeName ;
    if ( $FIELDS_WITH_CHILDREN{"bib:$fieldname"} ) {
        my @stringbuffer ;
        foreach my $child ($node->childNodes) {
            my $type = $child->nodeType;
            # child node is a string
            if ($type == 3) {
                push @stringbuffer, $child->findvalue("normalize-space()") ;
            } 
            # child node is an element
            elsif ($type == 1) {
                my $childname = $child->nodeName;
                my $value    = $child->findvalue("normalize-space()") ;
                if ($value ne '') {
                    if ($BIBLATEXML_FORMAT_ELEMENTS{$childname}) {
                        push @stringbuffer, 
                          "\\", $BIBLATEXML_FORMAT_ELEMENTS{$childname}, "{", $value, "}" ;
                    } elsif ($childname eq 'bib:nosort') {
                        push @stringbuffer, $value ;
                        # TODO record $nosortprefix somewhere to autogenerate index$field if needed
                    }
                }
            }
        } 
        return join '', @stringbuffer
    }
    else {
        return $node->string_value
    }
}

sub _biblatex_sort_value {
    my $node = shift ;
    my $fieldname = $node->nodeName ;
    if ( $FIELDS_WITH_CHILDREN{"bib:$fieldname"} ) {
        my @stringbuffer ;
        foreach my $child ($node->childNodes) {
            next if $child->nodeName eq 'bib:nosort' ;
            push @stringbuffer, $child->findvalue("normalize-space()") ;
        } 
        return join '', @stringbuffer
    }
    else {
        return $node->string_value
    }
}


sub _process_field_with_children {
    my $node = shift;
    my $nodeiter = 1;
    foreach my $node ($res->get_nodelist) {
        say "*** Node $nodeiter: ***";
        say $node->toString ;
        say "---";
        my @children = $node->childNodes;
        say "The children nodes are:";
        my $jiter = 0;
        my @titlestring;
        my @sortstring;
        my $nosortprefix;
        foreach my $child (@children) {
            $jiter++;
            my $value;
            my $type = $child->nodeType;
            if ($type == 3) {
                $value = $child->findvalue("normalize-space()") ;
                say "$jiter : '$value'" ;
                if ($value ne '') {
                    push @titlestring, $value ;
                    push  @sortstring, $value ;
                }
            }  
            elsif ( $type == 1 ) {
                my $nodename = $child->nodeName;
                $value = $child->findvalue("normalize-space()") ;
                say "$jiter (" . $nodename . ") : " . "'". $value ."'" ;
                if ($value ne '') {
                    if ($nodename eq 'bib:emphasis') {
                        push @titlestring, "\\emph{$value}" ;
                        push @sortstring, $value ;
                    } 
                    elsif ($nodename eq 'bib:superscript') {
                        push @titlestring, "\\textsuperscript{$value}" ;
                        push @sortstring, $value ;
                    } 
                    elsif ($nodename eq 'bib:subscript') {
                        push @titlestring, "\\textsubscript{$value}" ;
                        push @sortstring, $value ;
                    } 
                    elsif ($nodename eq 'bib:nosort') {
                        push @titlestring, $value ;
                        $nosortprefix = $value if ( $#titlestring == 0 );
                    } 
                };
            }
        } ;

        say "------------------------" ;
        say "Title = " . join(" ", @titlestring) ;
        my $sorttitle = join(" ", @sortstring) ;
        $sorttitle =~ s/^(.)/\U$1/ ;
        say "Sorttitle = $sorttitle" ;
        if ($nosortprefix) { 
            say "Indextitle = $sorttitle, $nosortprefix"
        } ;
        $nodeiter++;
    }
}


1 ;

__END__

=pod

=head1 NAME

Biber::BibLaTeXML - parse BibLaTeXML database

=head1 METHODS

=head2 _parse_biblatexml

    Internal method to query and parse a BibLaTeXML database.

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

