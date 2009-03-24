package Biber::BibLaTeXML ;
use strict ;
use warnings ;
use Carp ;
use XML::LibXML ;
use Biber::Utils ;
use Biber::Constants ;
our @ISA ;


sub _parse_biblatexml {
    my ($self, $xml) = @_ ;
    my $parser = XML::LibXML->new() ;
    my $db ;

    # FIXME : a user _could_ want to encode the bbl in LaTeX!
    $self->{config}->{unicodebbl} = 1 ;

    print "Parsing the xml data ...\n" unless $self->config('quiet') ;

    if ( $xml =~ /\.dbxml$/ ) {
        require Biber::DBXML ;
        push @ISA, 'Biber::DBXML' ;
        my $xmlstring = $self->dbxml_to_xml($xml) ;
        $db = $parser->parse_string( $xmlstring ) 
            or croak "Cannot parse xml string" ;
    } else {
        $db = $parser->parse_file($xml) 
            or croak "Can't parse file $xml" ;
    }

#    if ($self->config('validate')) {
#        my $rngschema = XML::LibXML::RelaxNG->new( location => "biblatexml.rng") ;
#        
#        my $validation = eval { $rngschema->validate($db) ; } ; 
#
#        unless ($validation) {
#            carp "!!!\nThe file $outfile does not validate against the BibLaTeXML RelaxNG schema\n!!!\n$@"
#        } 
#    }
    
    # keep track of citekeys that were not found in this database
    my %citekeysnotfound = () ;
    my @auxcitekeys = $self->citekeys ;
    my %bibentries = $self->bib ; 
    
    if ($self->config('allentries')) {
        @auxcitekeys = () ;
        my $res = $db->findnodes('/*/bib:entry') ;
        foreach my $r ($res->get_nodelist) {
            push @auxcitekeys, $r->findnodes('@id')->string_value
        } ;
    } ;
    
    print "Processing the xml data ...\n" unless $self->config('quiet') ;

    # Contrary to the bibtex approach, we are not extracting all data to
    # the bibentries hash, but only the ones corresponding to @auxcitekeys
    foreach my $citekey (@auxcitekeys) {
        next if $bibentries{$citekey} ; # skip if this is already found in another database
        print "Looking for $citekey\n" if $self->config('biberdebug') ;
        my $xpath = '/*/bib:entry[@id="' . $citekey . '"]' ;
        my $results = $db->findnodes($xpath) ;

        unless ( $results ) {

            carp "Can't find entry with citekey $citekey... skipping"
                 unless $self->config('quiet') ;
            
            $citekeysnotfound{$citekey} = 1 ;
            next
        } ;

        if ( $results->size() > 1 ) { 
            carp "The database contains more than one bib:entry with id=\"$citekey\" !" 
        } ;

        my $bibrecord = $results->get_node(1) ; 

        # if we have an entryset we add the keys to the stack
        if ($bibrecord->findnodes('@entrytype')->string_value eq 'set') {
            
            my @entrysetkeys = split /,/, $bibrecord->findnodes('bib:entryset')->string_value ;

            push @auxcitekeys, @entrysetkeys ;

            foreach my $setkey (@entrysetkeys) {
                $Biber::inset_entries{$setkey} = $citekey ;
            }
        }
        # if there is a crossref, we increment its citekey in %crossrefkeys
        elsif ( $bibrecord->findnodes('bib:crossref') ) {

            my $crefkey = $bibrecord->findnodes('bib:crossref')->string_value ;

            $Biber::crossrefkeys{$crefkey}++ ;
            $Biber::entrieswithcrossref{$citekey} = $crefkey ;
        }

    } ;

    # now we add all crossrefs to the stack
    unless ( $self->config('allentries') ) {
        push @auxcitekeys, ( keys %Biber::crossrefkeys ) ;
    } ;
    #--------------------------------------------------

    foreach my $citekey (@auxcitekeys) {
        next if $citekeysnotfound{$citekey} ;
        next if $bibentries{$citekey} ; # skip if this is already found in another database
        print "Processing key $citekey\n" if $self->config('biberdebug') ;
        my $xpath = '/*/bib:entry[@id="' . $citekey . '"]' ;
        my $results = $db->findnodes($xpath) ;
        my $bibrecord = $results->get_node(1) ; 

        $bibentries{ $citekey }->{entrytype} = $bibrecord->findnodes('@entrytype')->string_value ;
        if ($bibrecord->findnodes('@type')) {
            $bibentries{ $citekey }->{type} = $bibrecord->findnodes('@type')->string_value ;
        } ;
        $bibentries{ $citekey }->{datatype} = 'xml' ;

        #TODO get the options field first 
        #options/text or option: key+value
        if ($bibrecord->findnodes("bib:options")) {
            if ($bibrecord->findnodes("bib:options/bib:option")) {
                my @opts ; 
                foreach my $o ($bibrecord->findnodes("bib:options/bib:option")->get_nodelist) {
                    my $k = $o->findnodes("bib:key")->string_value ; 
                    my $v = $o->findnodes("bib:value")->string_value ;
                    push @opts, "$k=$v" ;
                } ;
                $bibentries{$citekey}->{options} = join(",", @opts) ;
            }
            else {
                $bibentries{$citekey}->{options} = $bibrecord->findnodes("bib:options")->string_value ;
            }
        } ;
        
        # then we extract in turn the data from each type of fields

        foreach my $f (@LITERALFIELDS, @VERBATIMFIELDS) {
            $bibentries{$citekey}->{$f} = $bibrecord->findnodes("bib:$f")->string_value 
                if $bibrecord->findnodes("bib:$f") ;
        } ;
        
        foreach my $lf (@LISTFIELDS) {
            my @z ;
            if ($bibrecord->findnodes("bib:$lf")) {
                if ($bibrecord->findnodes("bib:$lf/bib:item")) {
                    foreach my $item ($bibrecord->findnodes("bib:$lf/bib:item")->get_nodelist) {
                        push @z, $item->string_value ;
                    }
                }
                else {
                     push @z, $bibrecord->findnodes("bib:$lf")->string_value
                } ;
                if ($bibrecord->findnodes("bib:$lf\[\@andothers='true'\]")) {
                    push @z, "others"
                } ;
                $bibentries{$citekey}->{$lf} = [ @z ]
            }
        } ;

        foreach my $rf (@RANGEFIELDS) {
            if ($bibrecord->findnodes("bib:$rf")) {
                if ($bibrecord->findnodes("bib:$rf/bib:start")) {
                     my $fieldstart = $bibrecord->findnodes("bib:$rf/bib:start")->string_value ;
                     my $fieldend   = $bibrecord->findnodes("bib:$rf/bib:end")->string_value ;
                    $bibentries{$citekey}->{$rf} = "$fieldstart--$fieldend" ;
                }
                elsif ($bibrecord->findnodes("bib:$rf/bib:list")) {
                    $bibentries{$citekey}->{$rf} = 
                        $bibrecord->findnodes("bib:$rf/bib:list")->string_value
                }
                else {
                    $bibentries{$citekey}->{$rf} = 
                        $bibrecord->findnodes("bib:$rf")->string_value
                }
            } ;
        } ;

        #the name fields are somewhat more complex
        foreach my $nf (@NAMEFIELDS) {
            if ($bibrecord->findnodes("bib:$nf")) {
                my @z ;
                if ($bibrecord->findnodes("bib:$nf/bib:person")) {
                    foreach my $person ($bibrecord->findnodes("bib:$nf/bib:person")->get_nodelist) {
                        my $lastname ; 
                        my $firstname ; 
                        my $prefix ; 
                        my $suffix ;
                        my $namestr = "" ;
                        my $nameinitstr = undef ;
                        if ($person->findnodes('bib:last')) {
                            $lastname = $person->findnodes('bib:last')->string_value ;
                            $firstname = $person->findnodes('bib:first')->string_value ; 
                            $prefix = $person->findnodes('bib:prefix')->string_value 
                                if $person->findnodes('bib:prefix') ;
                            $suffix = $person->findnodes('bib:suffix')->string_value
                                if $person->findnodes('bib:suffix') ;
                            
                            #FIXME the following code is a repetition of part of parsename() 
                            $namestr .= $prefix if $prefix ;
                            $namestr .= $lastname ;
                            $namestr .= ", " . $firstname if $firstname ;

                            $nameinitstr = "" ;
                            $nameinitstr .= substr( $prefix, 0, 1 ) . "_"
                              if ( $self->getoption($citekey, 'useprefix') and $prefix ) ;
                            $nameinitstr .= $lastname ;
                            $nameinitstr .= "_" . terseinitials($firstname) 
                                if $firstname ;

                            push @z, 
                                { lastname => $lastname, firstname => $firstname, 
                                  prefix => $prefix, suffix => $suffix,
                                  namestring => $namestr, 
                                  nameinitstring => $nameinitstr }
                        }
                        # Schema allows <person>text<person>
                        else {
                            my $useprefix = $self->getoption($citekey, 'useprefix') ;

                            push @z, parsename( $person->string_value, {useprefix => $useprefix} )
                        }
                    } 
                } 
                # only one name as string, without <person>
                else {
                    my $useprefix = $self->getoption($citekey, 'useprefix') ;

                    push @z, parsename( $bibrecord->findnodes("bib:$nf")->string_value, {useprefix => $useprefix} )
                } ;

                if ($bibrecord->findnodes("bib:$nf\[\@andothers='true'\]")) {
                    push @z, { lastname => "others", namestring => "others" }
                } ;
                
                $bibentries{$citekey}->{$nf} = [ @z ]
            }
        } ;

        # now we extract the attributes
        my %xmlattributes = ( 
            'bib:pages/@pagination' => 'pagination',
            'bib:pages/@bookpagination' => 'bookpagination',
            'bib:author/@type' => 'authortype',
            'bib:editor/@type' => 'editortype',
            'bib:author/@gender' => 'gender',
            # 'bib:editor/@gender' => 'gender', (ignored for now)
            '@howpublished' => 'howpublished'
            ) ; 
        foreach my $attr (keys %xmlattributes) {
            if ($bibrecord->findnodes($attr)) {
                $bibentries{ $citekey }->{ $xmlattributes{$attr} } 
                    = $bibrecord->findnodes($attr)->string_value ;
            }
        }
    } ;

    $self->{bib} = { %bibentries } ;

    # now we keep only citekeys that actually exist in the database
    $self->{citekeys} = [ grep { defined $self->{bib}->{$_} } @auxcitekeys ] ;

    return
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

# vim: set tabstop=4 shiftwidth=4: 
