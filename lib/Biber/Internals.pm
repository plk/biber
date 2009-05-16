package Biber::Internals ;
use strict ;
use warnings ;
use Carp ;
use Biber::Constants ;
use Biber::Utils ;
use Text::Wrap ;

=head1 NAME

Biber::Internals - Internal methods for processing the bibliographic data

=head1 METHODS


=head2 getnameinitials

=cut

#TODO $namefield instead of @aut as 2nd argument!
sub _getnameinitials {
    my ($self, $citekey, @aut) = @_ ;
    my $initstr = "" ;
    ## my $nodecodeflag = $self->_decode_or_not($citekey) ;

    if ( $#aut < $self->getoption( $citekey, "maxnames" ) ) {    # 1 to 3 authors
        foreach my $a (@aut) {
            if ( $a->{prefix} and $self->getoption( $citekey, "useprefix" ) ) {
                $initstr .= terseinitials( $a->{prefix} ) 
            }
            $initstr .= terseinitials( $a->{lastname} ) ; 

            #FIXME suffix ?
            if ( $a->{firstname} ) {
                $initstr .= terseinitials( $a->{firstname} ) 
            }
        }
    }
    else
    { # more than 3 authors: only take initials of first getoption($citekey,"minnames")
        foreach my $i ( 0 .. $self->getoption( $citekey, "minnames" ) - 1 ) {
            if ( $aut[$i]->{prefix} and $self->getoption( $citekey, "useprefix" ) ) {
                $initstr .= terseinitials( $aut[$i]->{prefix} ) ; 
            }
            my $tmp = $aut[$i]->{lastname} ;

            #FIXME suffix ?
            $initstr .= terseinitials($tmp) ; 
            if ( $aut[$i]->{firstname} ) {
                $tmp = $aut[$i]->{firstname} ;
                $initstr .= terseinitials($tmp) ; 
            }
            $initstr .= "+" ;
        }
    }
    return $initstr ;
}


#TODO $namefield instead of @aut as 2nd argument!
sub _getallnameinitials {
    my ($self, $citekey, @aut) = @_ ;
    my $initstr = "" ;
    
    foreach my $a (@aut) {
        if ( $a->{prefix} and $self->getoption( $citekey, "useprefix" ) ) {
            $initstr .= terseinitials( $a->{prefix} ) 
        }
        $initstr .= terseinitials( $a->{lastname} ) ;

        #FIXME suffix ?
        if ( $a->{firstname} ) {
            $initstr .= terseinitials( $a->{firstname} ) ;
        }
    }
    return $initstr ;
}

sub _getlabel {
    my ($self, $citekey, $namefield) = @_ ;
    
    my @names = @{ $self->{bib}->{$citekey}->{$namefield} } ;
    my $dt = $self->{bib}->{$citekey}->{datatype} ;
    my $alphaothers = $self->config('alphaothers') ;
    my $useprefix = $self->getoption($citekey,'useprefix') ;
    my $label = "";

    my @lastnames = map { normalize_string( $_->{lastname}, $dt ) } @names ;
    my @prefixes  = map { $_->{prefix} } @names ;
    my $noofauth  = scalar @names ;
    
    if ( $noofauth > 3 ) {
        if ($useprefix and $prefixes[0]) {
            $label .= substr( $prefixes[0], 0, 1 ) ; 
            $label .= substr( $lastnames[0], 0, 2 ) . $alphaothers
        } else {
            $label  = substr( $lastnames[0], 0, 3 ) . $alphaothers ;
        }
    }
    elsif ( $noofauth == 1 ) {
        if ($useprefix and $prefixes[0]) {
            $label .= substr( $prefixes[0], 0, 1 ) ;  
            $label .= substr( $lastnames[0], 0, 2 )
        } else {
            $label = substr( $lastnames[0], 0, 3 ) ;
        }
    }
    else {
        if ($useprefix) {
            for (my $i=0; $i<$noofauth; $i++) {
                $label .= substr($prefixes[$i] , 0, 1) if $prefixes[$i] ;
                $label .= substr($lastnames[$i], 0, 1) ;
            }
        } else {
            for (my $i=0; $i<$noofauth; $i++) {
                $label .= substr($lastnames[$i], 0, 1) ;
            }
        }
    }

    return $label
}

=head2 getoption

getoption($citekey, $option) returns the value of option, taking into account
the option locally decined for $citekey, if available.

=cut

sub getoption {
    my ($self, $citekey, $opt) = @_ ;
    if ( defined $Biber::localoptions{$citekey} and defined $Biber::localoptions{$citekey}->{$opt} ) {
        return $Biber::localoptions{$citekey}->{$opt} ;
    }
    else {
        return $self->config($opt) ;
    }
}


#=====================================================
# INTERNAL SUBS for SORT STRINGS
#=====================================================


sub _nodecode {
    my ($self, $citekey) = @_ ;
    my $no_decode = ( $self->{config}->{unicodebib} 
                        or $self->{config}->{fastsort} 
                        or $self->{bib}->{$citekey}->{datatype} eq 'xml' ) ;
    return $no_decode
}

sub _getinitstring {
    my ($self, $citekey) = @_ ;
    my $be = $self->{bib}->{$citekey} ;
    my $str ;
    if ( $be->{presort} ) {
        $str = $be->{presort} ;
    }
    else {
        $str = "mm" ;
    }
    #FIXME labelalpha should be at the beginning!!!
    if ( $be->{labelalpha} ) {
        $str .= "0" . $be->{labelalpha} ;
    }
    return $str ;
}


sub _getnamestring {
    my ($self, $citekey) = @_ ;
    my $be = $self->{bib}->{$citekey} ;

    # see biblatex manual §3.4 "if both are disabled, the sortname field is ignored as well"
    if (
        $be->{sortname}
        and (     $self->getoption( $citekey, "useauthor" )
               or $self->getoption( $citekey, "useeditor" )
               or $self->getoption( $citekey, "usetranslator" )
            )
      )
    {
		return $self->_namestring($citekey, 'sortname') ;
    }
    elsif ( $self->getoption( $citekey, "useauthor" ) 
			and $be->{author} ) {
		return $self->_namestring($citekey, 'author')
    }
    elsif ( $self->getoption( $citekey, "useeditor" ) 
			and $be->{editor} ) {
        return $self->_namestring($citekey, 'editor')
    }
    elsif ( $self->getoption( $citekey, "usetranslator" ) 
			and $be->{translator} ) {
        return $self->_namestring($citekey, 'translator')
    }
    else {
        return $self->_gettitlestring($citekey) ;
    }
}

sub _namestring {
	my ( $self, $citekey, $field ) = @_ ;
    my $be = $self->{bib}->{$citekey} ;
	
	my $str = "" ;
    my @names = @{ $be->{$field} } ;
    my $truncated = 0 ;
    ## perform truncation according to options minnames, maxnames
    if ( $#names + 1 > $self->config('maxnames') ) {
        $truncated = 1 ;
        @names = splice(@names, 0, $self->config('minnames') )
    } ;
    foreach ( @names ) {
        $str .= $_->{prefix} . "2"
          if ( $_->{prefix} and $self->getoption( $citekey, "useprefix" ) ) ;
        $str .= $_->{lastname} . "2" ;
        $str .= $_->{firstname} . "2" if $_->{firstname} ;
        $str .= $_->{suffix} if $_->{suffix} ;
        $str =~ s/2$// ;
        $str .= "1" ;
    } ;
    $str =~ s/\s+1/1/g;
    $str =~ s/1$//;
    $str = normalize_string($str, $self->_nodecode($citekey));
    #TODO append "zzzz" if it has been truncated
    $str .= "1zzzz" if $truncated ;
    return $str
}


sub _getyearstring {
    my ($self, $citekey) = @_ ;
    my $be = $self->{bib}->{$citekey} ;
    if ( $be->{sortyear} ) {
        return substr( $be->{sortyear}, 0, 4 ) ;
    }
    elsif ( $be->{year} ) {
        return substr( $be->{year}, 0, 4 )

          #     } elsif ($be->{date}) {
          #          return substr($be->{date}, 0, 4)
    }
    elsif (($self->config('sorting') == 21) or
           ($self->config('sorting') == 22)) {
      return "9999" ;
    }
    else {
      return '';
    }
}


sub _getdecyearstring {
    my ($self, $citekey) = @_ ;
    my $be = $self->{bib}->{$citekey} ;
    if ( $be->{sortyear} ) {
        return 9999 - substr( $be->{sortyear}, 0, 4 ) ;
    }
    elsif ( $be->{year} ) {
        return 9999 - substr( $be->{year}, 0, 4 )

          #     } elsif ($be->{date}) {
          #          return 9999 - substr($be->{date}, 0, 4)
    }
    elsif (($self->config('sorting') == 21) or
           ($self->config('sorting') == 22)) {
      return "9999" ;
    }
    else {
      return '';
    }
}


sub _gettitlestring {
    my ($self, $citekey) = @_ ;
    my $be = $self->{bib}->{$citekey} ;
    my $no_decode = $self->_nodecode($citekey) ;

    if ( $be->{sorttitle} ) {
        return normalize_string( $be->{sorttitle}, $no_decode ) ;
    }
    elsif ( $be->{title} ) {
        return normalize_string( $be->{title}, $no_decode ) ;
    }
    elsif ($be->{issuetitle}) {
        return normalize_string( $be->{issuetitle}, $no_decode ) ;
    }
    elsif ($be->{journal}) {
        return normalize_string( $be->{journal}, $no_decode ) ;
    }
    else {
        croak "No title available for key $citekey"
    }
}

sub _getvolumestring {
    my ($self, $citekey) = @_ ;
    my $be = $self->{bib}->{$citekey} ;
    if ( $be->{volume} ) {
        my $vol = $be->{volume} ;

        #          if ($vol =~ /^[0-9]+/) {
        #               $vol =~ s/^([0-9]+).*$/$1/ ;
        #               return sprintf("%04d", $vol)
        #          } else {
        return sprintf( "%04s", $vol )

          #          }
    }
    else {
        return "0000" ;
    }
}


sub _generatesortstring {
    my ($self, $citekey) = @_ ;
    my $be = $self->{bib}->{$citekey} ;

    if ( $self->config('sorting') == 1 ) {    # name title year
        $be->{sortstring} =
          lc(   $self->_getinitstring($citekey) . "0"
              . $self->_getnamestring($citekey) . "0"
              . $self->_gettitlestring($citekey) . "0"
              . $self->_getyearstring($citekey) . "0"
              . $self->_getvolumestring($citekey) ) ;
    }
    elsif ( $self->config('sorting') == 2 or $self->config('sorting') == 12 )
    {                                        # <alpha> name year title
        $be->{sortstring} =
          lc(   $self->_getinitstring($citekey) . "0"
              . $self->_getnamestring($citekey) . "0"
              . $self->_getyearstring($citekey) . "0"
              . $self->_gettitlestring($citekey) . "0"
              . $self->_getvolumestring($citekey) ) ;
    }
    elsif ( $self->config('sorting') == 3 or $self->config('sorting') == 13 )
    {                                        # <alpha> name year volume title
        $be->{sortstring} =
          lc(   $self->_getinitstring($citekey) . "0"
              . $self->_getnamestring($citekey) . "0"
              . $self->_getyearstring($citekey) . "0"
              . $self->_getvolumestring($citekey) . "0"
              . $self->_gettitlestring($citekey) ) ;
    }
    elsif ( $self->config('sorting') == 21 ) {    # year name title
        $be->{sortstring} =
          lc(   $self->_getyearstring($citekey) . "0"
              . $self->_getnamestring($citekey) . "0"
              . $self->_gettitlestring($citekey) ) ;
    }
    elsif ( $self->config('sorting') == 22 ) {    # year_decreasing name title
        $be->{sortstring} =
          lc(   $self->_getdecyearstring($citekey) . "0"
              . $self->_getnamestring($citekey) . "0"
              . $self->_gettitlestring($citekey) ) ;

    } elsif ($self->config('sorting') == 99) { 
        $be->{sortstring} = $citekey
    }
    else {
        # do nothing!
        carp "Warning: the sorting code " . $self->config('sorting') . 
             " is not defined, assuming 'debug'\n" ;
        $be->{sortstring} = $citekey
    } 

    return
}

#=====================================================
# OUTPUT SUBS 
#=====================================================

# This is to test whether the fields " $be->{$field} " are defined and non empty
# (empty fields allow to suppress crossref inheritance)
sub _defined_and_nonempty {
    my $arg = shift ;
    if (defined $arg) {
        if (ref \$arg eq 'SCALAR') {
            if ($arg ne '') {
                return 1
            } else {
                return 0
            }
        } elsif (ref $arg eq 'ARRAY') {
            my @arr = @$arg ;
            if ( $#arr > -1 ) {
                return 1
            } else {
                return 0
            }
        } elsif (ref $arg eq 'HASH') {
            my @arr = keys %$arg ;
            if ($#arr > -1 ) {
                return 1
            } else {
                return 0
            }
        } else {
            return 0
        }
    } else {
        return 0
    }
}

#TODO this could be done earlier as a method and stored in the object
sub _print_name {
	my ($self, $au) = @_ ;
    my %nh  = %{$au} ;
    my $ln  = $nh{lastname} ;
    my $lni = getinitials($ln) ;
    my $fn  = "" ;
    $fn = $nh{firstname} if $nh{firstname} ;
    my $fni = "" ;
    $fni = getinitials($fn) if $nh{firstname} ;
    my $pre = "" ;
    $pre = $nh{prefix} if $nh{prefix} ;
    my $prei = "" ;
    $prei = getinitials($pre) if $nh{prefix} ;
    my $suf = "" ;
    $suf = $nh{suffix} if $nh{suffix} ;
    my $sufi = "" ;
    $sufi = getinitials($suf) if $nh{suffix} ;
    #FIXME The following is done by biblatex.bst, but shouldn't it be optional? 
    $fn =~ s/(\p{Lu}\.)\s+/$1~/g; # J. Frank -> J.~Frank
    $fn =~ s/\s+(\p{Lu}\.)/~$1/g; # Bernard H. -> Bernard~H.
    if ( $self->config('terseinits') ) {
        $lni = tersify($lni) ;
        $fni = tersify($fni) ;
        $prei = tersify($prei) ;
        $sufi = tersify($sufi) ;
    } ;
    return "    {{$ln}{$lni}{$fn}{$fni}{$pre}{$prei}{$suf}{$sufi}}%\n" ;
}

sub _printfield {
    my ($self, $field, $str) = @_ ;
    my $width = $self->config('maxline') ;

    ## 12 is the length of '  \field{}{}'
    if ( 12 + length($field) + length($str) > 2*$width ) {
        return "  \\field{$field}{%\n" . wrap('  ', '  ', $str) . "%\n  }\n" ;
    } elsif ( 12 + length($field) + length($str) > $width ) {
        return wrap('  ', '  ', "\\field{$field}{$str}" ) . "\n" ;
    } else {
        return "  \\field{$field}{$str}\n" ;
    }
}

sub _print_biblatex_entry {
    
    my ($self, $citekey) = @_ ;
    my $be      = $self->{bib}->{$citekey} or croak "Cannot find $citekey" ;
    my $opts      = "" ;
    my $origkey = $citekey ;
    if ( $be->{origkey} ) {
        $origkey = $be->{origkey}
    }

    if ( _defined_and_nonempty($be->{options}) ) {
        $opts = $be->{options} ;
    }

    my $str = "" ;
    
    $str .= "% sortstring = " . $be->{sortstring} . "\n" if $self->config('debug') ;

    $str .= "\\entry{$origkey}{" . $be->{entrytype} . "}{$opts}\n" ;

    if ( $be->{entrytype} eq 'set' ) {
        $str .= "  \\entryset{" . $be->{entryset} . "}\n" ;
    }
    
    if ($Biber::inset_entries{$citekey}) {
        ## NB should be equal to $be->{entryset} but we prefer to make it optional
        # TODO check against $be->entryset and warn if different!
        $str .= "  \\inset{" . $Biber::inset_entries{$citekey} . "}\n" ;
    }
    
    delete $be->{entrytype}; #forgot why this is needed!
    
    foreach my $namefield (@NAMEFIELDS) {
        next if $SKIPFIELDS{$namefield} ;
        if ( _defined_and_nonempty($be->{$namefield}) ) {
            my @nf    = @{ $be->{$namefield} } ;
            if ( $be->{$namefield}->[-1]->{namestring} eq 'others' ) {
                $str .= "  \\true{more$namefield}\n" ;
                pop @nf; # remove the last element in the array
            } ;
            my $total = $#nf + 1 ;
            $str .= "  \\name{$namefield}{$total}{%\n" ;
            foreach my $n (@nf) {
                $str .= $self->_print_name($n) ;
            }
            $str .= "  }\n" ;
        }
    }
    
    foreach my $listfield (@LISTFIELDS) {
        next if $SKIPFIELDS{$listfield} ;
        if ( _defined_and_nonempty($be->{$listfield}) ) {
            my @lf    = @{ $be->{$listfield} } ;
            if ( $be->{$listfield}->[-1] eq 'others' ) {
                $str .= "  \\true{more$listfield}\n" ;
                pop @lf; # remove the last element in the array
            } ;
            my $total = $#lf + 1 ;
            $str .= "  \\list{$listfield}{$total}{%\n" ;
            foreach my $f (@lf) {
                my $tmpstr ;
                if ( $be->{datatype} eq 'bibtex') { 
                    $tmpstr = $f
                }
                else {
                    $tmpstr = latexescape($f) ;
                } ;
                $str .= "    {$tmpstr}%\n" ;
            }
            $str .= "  }\n" ;
        }
    }

    my $namehash = $be->{namehash} ;
    my $sortinit = substr $namehash, 0, 1 ;
    $str .= "  \\strng{namehash}{$namehash}\n" ;
    my $fullhash = $be->{fullhash} ;
    $str .= "  \\strng{fullhash}{$fullhash}\n" ;
    if ( $self->config('labelalpha') ) {
        my $label = $be->{labelalpha} ;
        $str .= "  \\field{labelalpha}{$label}\n" ;
    }
    $str .= "  \\field{sortinit}{$sortinit}\n" ;
    
    if ( $self->config('labelyear') ) {
        my $authoryear = $be->{authoryear} ;
        if ( $Biber::seenauthoryear{$authoryear} > 1) {
            $Biber::seenlabelyear{$authoryear}++ ;
            $str .= "  \\field{labelyear}{" 
              . $Biber::seenlabelyear{$authoryear} . "}\n" ;
        }
    }

    if ( $self->config('extraalpha') ) {
        my $authoryear = $be->{authoryear} ;
        if ( $Biber::seenauthoryear{$authoryear} > 1) {
            $Biber::seenlabelyear{$authoryear}++ ;
            $str .= "  \\field{extraalpha}{" 
              . $Biber::seenlabelyear{$authoryear} . "}\n" ;
        }
    }

    if ( $self->config('labelnumber') ) {
        if ($be->{shorthand}) {
            $str .= "  \\field{labelnumber}{"
              . $be->{shorthand} . "}\n" ;
        } 
        elsif ($be->{labelnumber}) {
            $str .= "  \\field{labelnumber}{"
              . $be->{labelnumber} . "}\n" ;
        } 
    }
    
    if ( $be->{ignoreuniquename} ) {

        $str .= "  \\count{uniquename}{0}\n" ;

    } else {
        my $lname = $be->{labelname} ;
        my $name ;
        my $lastname ;
        my $nameinitstr ;

				if ($lname) {
					if ($lname =~ m/\Ashort/xms) { # short* fields are just strings, not complex data
						$lastname    = $be->{$lname} ;
						$nameinitstr = $be->{$lname} ;
					} else {
						$name = $be->{$lname}->[0] ;
						$lastname = $name->{lastname} ;
						$nameinitstr = $name->{nameinitstring} ;
					}
				}

        if (scalar keys %{ $Biber::uniquenamecount{$lastname} } == 1 ) { 
            $str .= "  \\count{uniquename}{0}\n" ;
        } elsif (scalar keys %{ $Biber::uniquenamecount{$nameinitstr} } == 1 ) {
            $str .= "  \\count{uniquename}{1}\n" ;
        } else { 
            $str .= "  \\count{uniquename}{2}\n" ;
        }
    }

    if ( $self->config('singletitle')
        and $Biber::seennamehash{ $be->{fullhash} } < 2 )
    {
        $str .= "  \\true{singletitle}\n" ;
    }

    foreach my $lfield (@LITERALFIELDS) {
        next if $SKIPFIELDS{$lfield} ;
        if ( _defined_and_nonempty($be->{$lfield}) ) {
            next if ( $lfield eq 'crossref' and 
                       $Biber::seenkeys{ $be->{crossref} } ) ; # belongs to @auxcitekeys 
                       
            my $lfieldprint = $lfield ;
            if ($lfield eq 'journal') {
                $lfieldprint = 'journaltitle' 
            } ;
            my $tmpstr ;
            if ( $be->{datatype} eq 'bibtex') { 
                $tmpstr = $be->{$lfield} ;
            }
            else {
                $tmpstr = latexescape($be->{$lfield}) ;
            }

            $str .= $self->_printfield( $lfieldprint, $tmpstr ) ;
        }
    }
    foreach my $rfield (@RANGEFIELDS) {
        next if $SKIPFIELDS{$rfield} ;
        if ( _defined_and_nonempty($be->{$rfield}) ) {
            my $rf = $be->{$rfield} ;
            $rf =~ s/[-–]+/\\bibrangedash /g ;
            $str .= "  \\field{$rfield}{$rf}\n" ;
        }
    }
    foreach my $vfield (@VERBATIMFIELDS) {
        next if $SKIPFIELDS{$vfield} ;
        if ( _defined_and_nonempty($be->{$vfield}) ) {
            my $rf = $be->{$vfield} ;
            $str .= "  \\verb{$vfield}\n" ;
            $str .= "  \\verb $rf\n  \\endverb\n" ;
        }
    }
    if ( _defined_and_nonempty($be->{keywords}) ) {
        $str .= "  \\keyw{" . $be->{keywords} . "}\n" ;
    }

    $str .= "\\endentry\n\n" ;

    #     $str = encode_utf8($str) if $self->config('unicodebbl') ;
    return $str ;
}

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

1 ;

# vim: set tabstop=4 shiftwidth=4: 
