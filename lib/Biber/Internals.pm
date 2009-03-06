#
#===============================================================================
#
#         FILE:  Utils.pm
#
#  DESCRIPTION:  
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:   (), <>
#      COMPANY:  
#      VERSION:  1.0
#      CREATED:  26/02/2009 19:25:22 CET
#     REVISION:  ---
#===============================================================================
package Biber::Internals;
use Biber::Constants;
use Biber::Utils;
use strict;
use warnings;
use Carp;

our $VERSION = '0.1';

#=====================================================
# ADDITIONAL METHODS FOR PROCESSING THE PARSED ENTRIES
#=====================================================

sub parsename {
    my ($self, $namestr, $citekey) = @_;
    my $usepre = $self->getoption($citekey, "useprefix") ;
    my $lastname ;
    my $firstname ;
    my $prefix ;
    my $suffix ;
    my $nameinitstr ;
    
    #  Arabic last names could begin with diacritics like ʿ or ‘ (e.g. ʿAlī)
    my $diacritics = qr/[\x{2bf}\x{2018}]/; # more? FIXME
    #  Arabic names may be prefixed with an article (e.g. al-Hasan, as-Saleh)
    my $articleprefix = qr/\p{Ll}{2}-/; # etc

    if ( $namestr =~ /[^\\],.+[^\\],/ ) {    # pre? Lastname, suffix, Firstname
        ( $prefix, $lastname, $suffix, $firstname ) = $namestr =~
            m/^(
                \p{Ll}
                (?:\p{Ll}|\s)+
               )?
               \s*
               (
                [^,]+
               |
                {[^,]+}
               )
               ,
               \s+
               ([^,]+)
               ,
               \s+
               ([^,]+)
             $/x;

        #$lastname =~ s/^{(.+)}$/$1/g ;
        #$firstname =~ s/^{(.+)}$/$1/g ;
        $prefix =~ s/\s+$// if $prefix;
    }
    elsif ( $namestr =~ /[^\\],/ ) {    # <pre> Lastname, Firstname
        ( $prefix, $lastname, $firstname ) = $namestr =~
            m/^(
                \p{Ll} # prefix starts with lowercase
                (?:\p{Ll}|\s)+ # e.g. van der
                \s+
               )?
               (
                $articleprefix?$diacritics?
                [^,]+
                |
                {[^,]+}
               ),
               \s+
               (
                [^,]+
                |
                {.+}
               )
               $/x;

        #$lastname =~ s/^{(.+)}$/$1/g ;
        #$firstname =~ s/^{(.+)}$/$1/g ;
        $prefix =~ s/\s+$// if $prefix;
    }
    elsif ( $namestr =~ /\s/ and $namestr !~ /^{.+}$/ ) {  # Firstname pre? Lastname
        ( $firstname, $prefix, $lastname ) =
          $namestr =~ /^(
                         {.+}
                        |
                         (?:\p{Lu}\p{Ll}+\s*)+
                        )
                        \s+
                        (
                         (?:\p{Ll}|\s)+
                        )?
                        (.+)
                        $/x;

        #$lastname =~ s/^{(.+)}$/$1/;
        $firstname =~ s/\s+$// if $firstname;

        #$firstname =~ s/^{(.+)}$/$1/ if $firstname;
        $prefix =~ s/\s+$// if $prefix;
        $namestr = "";
        $namestr = $prefix if $prefix;
        $namestr .= $lastname;
        $namestr .= ", " . $firstname if $firstname;
    }
    else {    # Name alone
        $lastname = $namestr;

        #$lastname =~ s/^{(.+)}$/$1/;
    }

    #TODO? $namestr =~ s/[\p{P}\p{S}\p{C}]+//g;
    ## remove punctuation, symbols, separator and control ???

    if ( $self->config('uniquename') == 2 ) {
        $nameinitstr = "";
        $nameinitstr .= substr( $prefix, 0, 1 ) . " " if ( $usepre and $prefix );
        $nameinitstr .= $lastname;
        $nameinitstr .= ", " . terseinitials($firstname) ##, $self->_decode_or_not($citekey) ) 
            if $firstname;
    };

    return {
            namestring     => $namestr,
            nameinitstring => $nameinitstr,
            lastname       => $lastname,
            firstname      => $firstname,
            prefix         => $prefix,
            suffix         => $suffix
           }
}

#sub _decode_or_not {
#    my ($self, $citekey) = @_;
#    my $no_decode = ( $self->{config}->{unicodebib} 
#                        or $self->{config}->{fastsort} 
#                        or $self->{bib}->{$citekey}->{datatype} eq 'xml' );
#    return $no_decode
#}

sub getnameinitials {
    my ($self, $citekey, @aut) = @_;
    my $initstr = "";
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
            #TODO
        foreach my $i ( 0 .. $self->getoption( $citekey, "minnames" ) - 1 ) {
            if ( $aut[$i]->{prefix} and $self->getoption( $citekey, "useprefix" ) ) {
                $initstr .= terseinitials( $aut[$i]->{prefix} ) ; 
            }
            my $tmp = $aut[$i]->{lastname};

            #FIXME suffix ?
            $initstr .= terseinitials($tmp) ; 
            if ( $aut[$i]->{firstname} ) {
                $tmp = $aut[$i]->{firstname};
                $initstr .= terseinitials($tmp) ; 
            }
            $initstr .= "+";
        }
    }
    return $initstr;
}

sub getallnameinitials {
    my ($self, $citekey, @aut) = @_;
    my $initstr = "";
    ## my $nodecodeflag = $self->_decode_or_not($citekey) ;
    
    foreach my $a (@aut) {
        if ( $a->{prefix} and $self->getoption( $citekey, "useprefix" ) ) {
            $initstr .= terseinitials( $a->{prefix} ) 
        }
        $initstr .= terseinitials( $a->{lastname} ); 

        #FIXME suffix ?
        if ( $a->{firstname} ) {
            $initstr .= terseinitials( $a->{firstname} ); 
        }
    }
    return $initstr;
}

#sub gettitleinitials {
#     my $title = shift;
#     $title =~ s/\b(\p{L})\S*\b\s*/$1/g;
#     $title =~ s/\P{L}//g;
#     return $title
#}

sub getoption {
    my ($self, $citekey, $opt) = @_;
    if ( defined $Biber::localoptions{$citekey} and defined $Biber::localoptions{$citekey}->{$opt} ) {
        return $Biber::localoptions{$citekey}->{$opt};
    }
    else {
        return $self->config($opt);
    }
}


#=====================================================
# SUBS for SORT STRINGS
#=====================================================

sub getinitstring {
    my ($self, $citekey) = @_;
    my $be = $self->{bib}->{$citekey};
    my $str;
    if ( $be->{presort} ) {
        $str = $be->{presort};
    }
    else {
        $str = "mm";
    }
    if ( $be->{labelalpha} ) {
        $str .= $be->{labelalpha};
    }
    return $str;
}

sub getnamestring {
    my ($self, $citekey) = @_;
    my $be = $self->{bib}->{$citekey};

    # see biblatex manual §3.4 "if both are disabled, the sortname field is ignored as well"
    if (
        $be->{sortname}
        and (     $self->getoption( $citekey, "useauthor" )
               or $self->getoption( $citekey, "useeditor" )  
            )
      )
    {
        return $be->{sortname};
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
        return $self->gettitlestring($citekey);
    }
}

sub _namestring {
	my ( $self, $citekey, $field ) = @_;
    my $be = $self->{bib}->{$citekey};
    my $no_decode = ( $self->{config}->{unicodebib} 
                        or $self->{config}->{fastsort} 
                        or $be->{datatype} eq 'xml' );
	
	my $str = "";
    foreach ( @{ $be->{$field} } ) {
        $str .= $_->{prefix} . " "
          if ( $_->{prefix} and $self->getoption( $citekey, "useprefix" ) );
        $str .= $_->{lastname} . " ";
        $str .= $_->{firstname} . " " if $_->{firstname};
        $str .= $_->{suffix} if $_->{suffix};
        $str .= " ";
    };
    $str =~ s/\s+$//;
    return normalize_string($str, $no_decode)
}

sub getyearstring {
    my ($self, $citekey) = @_;
    my $be = $self->{bib}->{$citekey};
    if ( $be->{sortyear} ) {
        return substr( $be->{sortyear}, 0, 4 );
    }
    elsif ( $be->{year} ) {
        return substr( $be->{year}, 0, 4 )

          #     } elsif ($be->{date}) {
          #          return substr($be->{date}, 0, 4)
    }
    else {
        return "9999";
    }
}

sub getdecyearstring {
    my ($self, $citekey) = @_;
    my $be = $self->{bib}->{$citekey};
    if ( $be->{sortyear} ) {
        return 9999 - substr( $be->{sortyear}, 0, 4 );
    }
    elsif ( $be->{year} ) {
        return 9999 - substr( $be->{year}, 0, 4 )

          #     } elsif ($be->{date}) {
          #          return 9999 - substr($be->{date}, 0, 4)
    }
    else {
        return "9999";
    }
}

sub gettitlestring {
    my ($self, $citekey) = @_;
    my $be = $self->{bib}->{$citekey};
    my $no_decode = ( $self->{config}->{unicodebib} 
                        or $self->{config}->{fastsort} 
                        or $be->{datatype} eq 'xml' );
    if ( $be->{sorttitle} ) {
        return normalize_string( $be->{sorttitle}, $no_decode );
    }
    elsif ( $be->{title} ) {
        return normalize_string( $be->{title}, $no_decode );
    }
    elsif ($be->{issuetitle}) {
        return normalize_string( $be->{issuetitle}, $no_decode );
    }
    elsif ($be->{journal}) {
        return normalize_string( $be->{journal}, $no_decode );
    }
    else {
        croak "No title available for gettitlestring()"
    }
}

sub getvolumestring {
    my ($self, $citekey) = @_;
    my $be = $self->{bib}->{$citekey};
    if ( $be->{volume} ) {
        my $vol = $be->{volume};

        #          if ($vol =~ /^[0-9]+/) {
        #               $vol =~ s/^([0-9]+).*$/$1/;
        #               return sprintf("%04d", $vol)
        #          } else {
        return sprintf( "%04s", $vol )

          #          }
    }
    else {
        return "0000";
    }
}

sub getpartinitials {
    my ($self, $part) = @_;
    $part = terseinitials($part); 
    unless ( $self->config('terseinits') ) {
        $part =~ s/(\p{L})/$1\.~/g ;
        $part =~ s/~-/-/g ; 
        $part =~ s/~$//;
    }
    return $part;
}

sub process_crossrefs {
	my $self = shift;
	my %bibentries = $self->bib;
    foreach my $citekeyx (keys %Biber::entrieswithcrossref) {
        my $xref = $Biber::entrieswithcrossref{$citekeyx}; 
        my $type = $bibentries{$citekeyx}->{entrytype};
        if ($type eq 'review') {
                #TODO
        }
    	if ($type =~ /^in(proceedings|collection|book)$/) {
            # inherit all that is undefined, except title etc
            foreach my $field (keys %{$bibentries{$xref}}) {
                next if $field =~ /title/;
                if (! $bibentries{$citekeyx}->{$field}) {
                    $bibentries{$citekeyx}->{$field} = $bibentries{$xref}->{$field};
                }
            }
            # inherit title etc as booktitle etc
            $bibentries{$citekeyx}->{booktitle} = $bibentries{$xref}->{title}; 
            if ($bibentries{$xref}->{titleaddon}) {
                $bibentries{$citekeyx}->{booktitleaddon} = $bibentries{$xref}->{titleaddon}
            }
            if ($bibentries{$xref}->{subtitle}) {
                $bibentries{$citekeyx}->{booksubtitle} = $bibentries{$xref}->{subtitle}
            }
		}
		else { # inherits all
            foreach my $field (keys %{$bibentries{$xref}}) {
                if (! $bibentries{$citekeyx}->{$field}) {
                    $bibentries{$citekeyx}->{$field} = $bibentries{$xref}->{$field};
                }
            }
	   }
       if ($type eq 'inbook') {
            $bibentries{$citekeyx}->{bookauthor} = $bibentries{$xref}->{author} 
        }
        # MORE?
        #$bibentries{$citekeyx}->{} = $bibentries{$xref}->{} 
    }

    # we make sure that keys that are cross-referenced 
    # less than $mincrossrefs are not included the bibliography
    foreach my $k ( keys %Biber::crossrefkeys ) {
        if ( $Biber::crossrefkeys{$k} >= $self->config('mincrossrefs') ) {
            delete $Biber::crossrefkeys{$k};
        }
    }

	$self->{bib} = { %bibentries }
}

# TODO "D[onald] E. Knuth" -> prints as D. E. Knuth but is sorted with Donald E. Knuth
sub _print_name {
	my ($self, $au) = @_;
    my %nh  = %{$au};
    my $ln  = $nh{lastname};
    my $lni = $self->getpartinitials($ln);
    my $fn  = "";
    $fn = $nh{firstname} if $nh{firstname};
    my $fni = "";
    $fni = $self->getpartinitials($fn) if $nh{firstname};
    my $pre = "";
    $pre = $nh{prefix} if $nh{prefix};
    my $prei = "";
    $prei = $self->getpartinitials($pre) if $nh{prefix};
    my $suf = "";
    $suf = $nh{suffix} if $nh{suffix};
    my $sufi = "";
    $sufi = $self->getpartinitials($suf) if $nh{suffix};
    return "    {{$ln}{$lni}{$fn}{$fni}{$pre}{$prei}{$suf}{$sufi}}%\n";
}

sub _print_for_biblatex {
    my ($self, $citekey) = @_ ;
    my $be      = $self->{bib}->{$citekey} or croak "Cannot find $citekey hash";
    my $kw      = "";
    if ( $be->{keywords} ) {
        $kw = $be->{keywords};
    }
    my $str = "\\entry{$citekey}{" . $be->{entrytype} . "}{$kw}\n";
    delete $be->{entrytype};
    foreach my $namefield (@NAMEFIELDS) {
        if ( defined $be->{$namefield} ) {
            my @nf    = @{ $be->{$namefield} };
            if ( $be->{$namefield}->[-1]->{namestring} eq 'others' ) {
                $str .= "  \\true{more$namefield}\n";
                pop @nf; # remove the last element in the array
            };
            my $total = $#nf + 1;
            $str .= "  \\name{$namefield}{$total}{%\n";
            foreach my $n (@nf) {
                $str .= $self->_print_name($n);
            }
            $str .= "  }\n";
        }
    }
    foreach my $listfield (@LISTFIELDS) {
        if ( defined $be->{$listfield} ) {
            my @nf    = @{ $be->{$listfield} };
            if ( $be->{$listfield}->[-1] eq 'others' ) {
                $str .= "  \\true{more$listfield}\n";
                pop @nf; # remove the last element in the array
            };
            my $total = $#nf + 1;
            $str .= "  \\list{$listfield}{$total}{%\n";
            foreach my $n (@nf) {
                my $tmpstr;
                if ( $be->{datatype} eq 'bibtex') { 
                    $tmpstr = $n
                }
                else {
                    $tmpstr = latexescape($n);
                };
                $str .= "    {$tmpstr}%\n";
            }
            $str .= "  }\n";
        }
    }

    my $namehash = $be->{namehash};
    my $sortinit = substr $namehash, 0, 1;
    $str .= "  \\strng{namehash}{$namehash}\n";
    my $fullhash = $be->{fullhash};
    $str .= "  \\strng{fullhash}{$fullhash}\n";
    if ( $self->config('labelalpha') ) {
        my $label = $be->{labelalpha};
        $str .= "  \\field{labelalpha}{$label}\n";
    }
    $str .= "  \\field{sortinit}{$sortinit}\n";
    
    if ( $self->config('labelyear') ) {
        my $authoryear = $be->{authoryear};
        if ( $Biber::seenauthoryear{$authoryear} > 1) {
            $Biber::seenlabelyear{$authoryear}++;
            $str .= "  \\field{labelyear}{" 
              . $Biber::seenlabelyear{$authoryear} . "}\n";
        }
    }

    if ( $self->config('extraalpha') ) {
        my $authoryear = $be->{authoryear};
        if ( $Biber::seenauthoryear{$authoryear} > 1) {
            $Biber::seenlabelyear{$authoryear}++;
            $str .= "  \\field{extraalpha}{" 
              . $Biber::seenlabelyear{$authoryear} . "}\n";
        }
    }

    if ( $self->config('labelnumber') ) {
        if ($be->{shorthand}) {
            $str .= "  \\field{labelnumber}{"
              . $be->{shorthand} . "}\n";
        } 
        elsif ($be->{labelnumber}) {
            $str .= "  \\field{labelnumber}{"
              . $be->{labelnumber} . "}\n";
        } 
    }

    # FIXME : currently bibtex only outputs \count{uniquename}{0} !
    if ( $self->config('uniquename') > 0 ) {
        $str .= "  \\count{uniquename}{"
          . $Biber::seenuniquename{ $be->{uniquename} } . "}\n";
    }

    if ( $self->config('singletitle')
        and $Biber::seenuniquename{ $be->{uniquename} } < 2 )
    {
        $str .= "  \\true{singletitle}\n";
    }

    foreach my $lfield (@LITERALFIELDS) {
        if ( defined $be->{$lfield} ) {
            next
              if $lfield eq "crossref"
                  and $Biber::seenkeys{ $be->{crossref} };  # belongs to @auxcitekeys ;
            my $lfieldprint = $lfield ;
            if ($lfield eq 'journal') {
                $lfieldprint = 'journaltitle' 
            };
            my $tmpstr;
            if ( $be->{datatype} eq 'bibtex') { 
                $tmpstr = $be->{$lfield};
            }
            else {
                $tmpstr = latexescape($be->{$lfield});
            }
            $str .= "  \\field{$lfieldprint}{$tmpstr}\n";
        }
    }
    foreach my $rfield (@RANGEFIELDS) {
        if ( defined $be->{$rfield} ) {
            my $rf = $be->{$rfield};
            $rf =~ s/-+/\\bibrangedash /g;
            $str .= "  \\field{$rfield}{$rf}\n";
        }
    }
    foreach my $vfield (@VERBATIMFIELDS) {
        if ( defined $be->{$vfield} ) {
            my $rf = $be->{$vfield};
            $str .= "  \\verb{$vfield}\n";
            $str .= "  \\verb $rf\n  \\endverb\n";
        }
    }
    if ( defined $be->{options} ) {
        $str .= "  \\options{" . $be->{options} . "}\n";
    }

    #TODO generate special fields : see manual §4.2.4
    $str .= "\\endentry\n\n";

    #     $str = encode_utf8($str) if $self->config('unicodebbl');
    return $str;
}

1;
# vim: set tabstop=4 shiftwidth=4: 
