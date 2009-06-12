package Biber::BibTeX ;
use strict ;
use warnings ;
use Carp ;
use Text::BibTeX ;
use Biber::Constants ;
use Biber::Utils ;
use Encode ;
use File::Spec ;

sub _text_bibtex_parse {
        
    my ($self, $filename) = @_ ;

    my %bibentries = $self->bib ;
    
    my @localkeys ;

    my $encoding ;    

    if ( $self->config('bibencoding') && ! $self->config('unicodebbl') ) {
        $encoding = $self->config('bibencoding') ;
    } else {
        $encoding = "utf8" ;
    } ;

    my $bib = Text::BibTeX::File->new( $filename, "<" )
        or croak "Cannot create Text::BibTeX::File object from $filename: $!" ;

    #TODO validate with Text::BibTeX::Structure ?

    my @preamble = () ;
    my $count = 0 ;

    while ( my $entry = new Text::BibTeX::Entry $bib ) {

        $count++ ;

        if ( $entry->metatype == BTE_PREAMBLE ) {
            push @preamble, $entry->value ;
            next ;
        }

        next if ( $entry->metatype == BTE_MACRODEF or $entry->metatype == BTE_UNKNOWN 
                or $entry->metatype == BTE_COMMENT ) ; #or $entry->type =~ m/^comment$/i

        unless ( $entry->key ) {
            warn "Warning--Cannot get the key of entry no $count : Skipping\n" ;
            next 
        }

        my $origkey = $entry->key ;
        my $key = lc($origkey) ;

        if (!defined $origkey or $origkey =~ /\s/ or $origkey eq '') {
            carp "Invalid Key! Skipping...\n" ;
            next
        }

        print "Processing $key\n" if $self->config('debug') ;

        if ( $bibentries{ $origkey } or $bibentries{ $key } ) {
            $self->{errors}++;
            my (undef,undef,$f) = File::Spec->splitpath( $filename );
            print "Repeated entry---key $origkey in file $f\nI'm skipping whatever remains of this entry\n"
                unless $self->config('quiet') ;
            next ;
        }

        push @localkeys, $key ;

        unless ($entry->parse_ok) {
            carp "Entry $origkey does not parse correctly: skipping" 
                unless $self->config('quiet') ;
            next ;
        }


        # all fields used for this entry
        my @flist = $entry->fieldlist ;

        #here we only keep those that do not require splitting
        my @flistnosplit = array_minus(\@flist, \@ENTRIESTOSPLIT) ;

        if ( $entry->metatype == BTE_REGULAR ) {

            foreach my $f ( @flistnosplit ) {

                #my $value = decode_utf8( $entry->get($f) ) ;
                my $value = decode( $encoding, $entry->get($f) ) ;

                my $af = $f ;

                if ( $ALIASES{$f} ) {
                    $af = $ALIASES{$f}
                }

                $bibentries{ $key }->{$af} = $value ;

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

						if (lc($entry->type) eq 'phdthesis') {
                $bibentries{ $key }->{entrytype} = 'thesis' ;
                $bibentries{ $key }->{type} = 'phdthesis' ;
            } elsif (lc($entry->type) eq 'mathesis') {
                $bibentries{ $key }->{entrytype} = 'thesis' ;
                $bibentries{ $key }->{type} = 'mathesis' ;
            } else {
                $bibentries{ $key }->{entrytype} = $entry->type ;
            }

            foreach my $f ( @ENTRIESTOSPLIT ) {

                next unless $entry->exists($f) ;

                #my @tmp = map { decode_utf8($_) } $entry->split($f) ;
                my @tmp = map { decode($encoding, $_) } $entry->split($f) ;

                if ($Biber::is_name_entry{$f}) {
									# This is a special case - we need to get the option value even though the passed
									# $self object isn't fully built yet so getblxoption() can't ask $self for the
									# $entrytype for $key. So, we have to pass it explicitly.
									my $useprefix = $self->getblxoption('useprefix', $key, $bibentries{$key}{entrytype}) ;

									@tmp = map { parsename( $_ , {useprefix => $useprefix}) } @tmp ;

                } else {
                    @tmp = map { remove_outer($_) } @tmp ;
                } 

                my $af = $f ;

                if ( $ALIASES{$f} ) {
                    $af = $ALIASES{$f}
                }
                
                $bibentries{ $key }->{$af} = [ @tmp ]                 

            } ;

            $bibentries{ $key }->{datatype} = 'bibtex' ;
        }

    }

   $self->{bib} = { %bibentries } ;

   $self->{preamble} = join( "%\n", @preamble ) if @preamble ;

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
Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>. 

=head1 COPYRIGHT & LICENSE

Copyright 2009 François Charette and Philip Kime, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# vim: set tabstop=2 shiftwidth=2 expandtab: 
