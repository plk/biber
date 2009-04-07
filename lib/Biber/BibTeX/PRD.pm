package Biber::BibTeX::PRD ;
use strict ;
use warnings ;
use Carp ;
use Biber::Constants ;
use Biber::Utils ;
use Parse::RecDescent ;
use Regexp::Common qw{ balanced } ;
use Biber::BibTeX::Parser ;

sub _bibtex_prd_parse {

    my ($self, $filename) = @_ ;

    my @auxcitekeys = $self->citekeys ;
    
    my %bibentries = $self->bib ;

    my @localkeys ;

    ## TODO 
    # $::RD_TRACE = 1 if $self->config('parserdebug') ;

    undef $/ ;

    my $mode = "";

    if ( $self->config('inputencoding') && ! $self->config('unicodebbl') ) {
        $mode = ':encoding(' . $self->config('inputencoding') . ')' ;
    } else {
        $mode = ":utf8" ;
    } ;

    my $bib = IO::File->new( $filename, "<$mode" )
        or croak "Failed to open $filename : $!" ;

    my $btparser = Biber::BibTeX::Parser->new 
        or croak "Cannot create Biber::BibTeX::Parser object: $!" ;
    
    my $bf       = $btparser->BibFile(<$bib>) 
        or croak "Can't parse file $filename : Are you certain it is a BibTeX file?\n\t$!" ;
    
    close $bib ;

    my @tmp = @$bf ;

    for my $n ( 0 .. $#tmp ) {
    
        my @tmpk   = keys %{ $tmp[$n] } ;
        my $tmpkey = $tmpk[0] ;
        
        if ( $tmpkey eq 'preamble' ) {

            my $preamble = $tmp[$n]->{preamble} ;
        }
        elsif ( $tmpkey eq 'entries' ) {

            my @entries = @{ $tmp[$n]->{entries} } ;
        
            foreach my $i ( 0 .. $#entries ) {
               
                my @tmpa   = keys %{ $entries[$i] } ;
                my $tmpkey = lc( $tmpa[0] ) ;
            
                if ( $bibentries{ $tmpkey } ) {
                    carp "We already have key $tmpkey! Ignoring in $filename..." ;
                    next ;
                }

                push @localkeys, $tmpkey ;
                
                $bibentries{$tmpkey} = $entries[$i]->{$tmpkey} ;
                
                $bibentries{$tmpkey}->{datatype} = 'bibtex' ;
            }
        }
    }

    foreach my $key ( @localkeys ) {

        print "Processing $key\n" if $self->config('biberdebug') ;

        foreach my $ets (@ENTRIESTOSPLIT) {

            if ( exists $bibentries{$key}->{$ets} ) {
                
                my $stringtosplit = $bibentries{$key}->{$ets} ;
                
                # next if ref($tmp) neq 'SCALAR' ; # we skip those that have been split

                # "and" within { } must be preserved: see biblatex manual §2.3.3
                #      (this can probably be optimized)
                
                foreach my $x ( $stringtosplit =~ m/($RE{balanced}{-parens => '{}'})/gx ) {

                    ( my $xr = $x ) =~ s/\s+and\s+/_\x{ff08}_/g ;

                    $stringtosplit =~ s/\Q$x/$xr/g ;

                } ;
                
                my @tmp = split /\s+and\s+/, $stringtosplit ;

                sub _restore_and {
                    s/_\x{ff08}_/ and /g;
                    return $_
                };

                @tmp = map { _restore_and($_) } @tmp ;
                
                if ($Biber::is_name_entry{$ets}) {
                    
                    my $useprefix = $self->getoption($key, 'useprefix') ;

                    @tmp = map { parsename( $_ , {useprefix => $useprefix}) } @tmp ;


                } else {
                    @tmp = map { remove_outer($_) } @tmp ;
                } 

                $bibentries{ $key }->{$ets} = [ @tmp ] 

            }
        } ;

        if ($bibentries{ $key }->{'entrytype'} eq 'set') {
            
            my @entrysetkeys = split /\s*,\s*/, $bibentries{$key}->{'entryset'} ; 

            foreach my $setkey (@entrysetkeys) {
                $Biber::inset_entries{$setkey} = $key ;
            }
        }

        if ( $bibentries{$key}->{'crossref'} ) {

            my $crkey = $bibentries{$key}->{'crossref'} ;
        
            $Biber::crossrefkeys{$crkey}++ ;
            $Biber::entrieswithcrossref{$key} = $crkey ;

        } ;
    }

    $self->{bib} = { %bibentries } ;

    return @localkeys

}

1 ;

__END__

=pod

=head1 NAME

Biber::BibTeX::PRD - Pure Perl BibTeX parser with Parse::RecDescent

=head1 METHODS

=head2 _bibtex_prd_parse

Internal method for parsing BibTeX data in Pure Perl instead of using 
the btparse C library with Text::BibTeX

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
