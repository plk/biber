package Biber::BibTeX ;
use strict ;
use warnings ;
use Carp ;
use Text::BibTeX ;
use Biber::Constants ;
use Biber::Utils ;
use Encode ;

sub _text_bibtex_parse {
        
    my ($self, $filename) = @_ ;

    my %bibentries = $self->bib ;
    
    my @localkeys ;

    my $bib = new Text::BibTeX::File $filename
     or croak "Cannot create Text::BibTeX::File object from $filename: $!" ;

    #TODO validate with Text::BibTeX::Structure ?
    my $preamble ;

    while ( my $entry = new Text::BibTeX::Entry $bib ) {

        next if ( $entry->metatype == BTE_MACRODEF ) ;                    

        my $key = $entry->key ;

        print "Processing $key\n" if $self->config('biberdebug') ;

        if ( $bibentries{ $key } ) {
            print "We already have key $key! Ignoring in $filename...\n"
                unless $self->config('quiet') ;
            next ;
        }
        push @localkeys, $key ;
        unless ($entry->parse_ok) {
            carp "Entry $key does not parse correctly: skipping" 
                unless $self->config('quiet') ;
            next ;
        }
        if ( $entry->metatype == BTE_PREAMBLE ) {
            $preamble .= $entry->value ;
        next ;
        }

        my @flist = $entry->fieldlist ;

        my @flistnosplit = array_minus(\@flist, \@ENTRIESTOSPLIT) ;

        if ( $entry->metatype == BTE_REGULAR ) {

            foreach my $f ( @flistnosplit ) {

                my $value = decode_utf8( $entry->get($f) ) ;

                $bibentries{ $key }->{$f} = $value ;

                if ($entry->type eq 'set' and $f eq 'entryset') {
                    
                    my @entrysetkeys = split /\s*,\s*/, $value ; 

                    foreach my $setkey (@entrysetkeys) {
                        $Biber::inset_entries{$setkey} = $key ;
                    }
                }
                elsif ($f eq 'crossref') { ### $entry->type ne 'set' and 
                    $Biber::crossrefkeys{$value}++ ;
                    $Biber::entrieswithcrossref{$key} = $value ;                   
                }
            } ;

            foreach my $f ( @ENTRIESTOSPLIT ) {

                next unless $entry->exists($f) ;

                my @tmp = map { decode_utf8($_) } $entry->split($f) ;

                if ($Biber::is_name_entry{$f}) {

                    # this returns an array of hashes
                    @tmp = map { $self->parsename( $_ , $key) } @tmp ;

                } else {
                    @tmp = map { remove_outer($_) } @tmp ;
                } 
                    
                $bibentries{ $key }->{$f} = [ @tmp ]                 

            } ;

            $bibentries{ $key }->{entrytype} = $entry->type ;

            $bibentries{ $key }->{datatype} = 'bibtex' ;
       
        }

    }

   $self->{bib} = { %bibentries } ;

   return @localkeys

}

1 ;

__END__

=pod

=head1 NAME

Biber::BibTeX - parse a bib database with Text::BibTeX

=head1 DESCRIPTION

Internal method ...

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
