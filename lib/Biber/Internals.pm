package Biber::Internals ;
use strict ;
use warnings ;
use Carp ;
use Biber::Constants ;
use Biber::Utils ;
use Text::Wrap ;
use List::Util qw( first );

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

    if ( $#aut < $self->getblxoption('maxnames', $citekey ) ) {    # 1 to 3 authors
        foreach my $a (@aut) {
            if ( $a->{prefix} and $self->getblxoption('useprefix', $citekey ) ) {
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
    { # more than 3 authors: only take initials of first getblxoption('minnames', $citekey)
        foreach my $i ( 0 .. $self->getblxoption('minnames', $citekey ) - 1 ) {
            if ( $aut[$i]->{prefix} and $self->getblxoption('useprefix', $citekey) ) {
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
        if ( $a->{prefix} and $self->getblxoption('useprefix', $citekey ) ) {
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
    my $alphaothers = $self->getblxoption('alphaothers', $citekey) ;
    my $useprefix = $self->getblxoption('useprefix', $citekey) ;
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
=head2 getblxoption

getblxoption('option', 'citekey') returns the value of option. In order of decreasing preference, returns:
1. Biblatex option defined for entry
2. Biblatex option defined for entry type
3. Biblatex option defined globally

=cut

sub getblxoption {
    my ($self, $opt, $citekey, $et) = @_ ;
		# return global option value if no citekey is passed
		return $self->{config}{biblatex}{global}{$opt} unless defined($citekey);
		# Else get the entrytype and continue to check local, then type, then global options
		# If entrytype is passed explicitly, use it (for cases where the object doesn't yet know
		# its entrytype since this sub is being called as it's being constructed)
		my $entrytype = defined($et) ? $et : $self->{bib}{$citekey}{entrytype};
    if ( defined $Biber::localoptions{$citekey} and defined $Biber::localoptions{$citekey}{$opt}) {
        return $Biber::localoptions{$citekey}{$opt} ;
    }
		elsif (defined $self->{config}{biblatex}{$entrytype} and defined $self->{config}{biblatex}{$entrytype}{$opt}) {
			return $self->{config}{biblatex}{$entrytype}{$opt};
		}
    else {
        return $self->{config}{biblatex}{global}{$opt};
    }
}


#########
# Sorting
#########

our $sorting_sep = '0';

# The keys are defined by BibLaTeX and passed in the control file
our $dispatch_sorting = {
                         '0000'         =>  \&_sort_0000,
												 '9999'         =>  \&_sort_9999,
												 'author'       =>  \&_sort_author,
												 'editor'       =>  \&_sort_editor,
												 'issuetitle'   =>  \&_sort_issuetitle,
												 'journal'      =>  \&_sort_journal,
												 'labelalpha'   =>  \&_sort_labelalpha,
                         'mm'           =>  \&_sort_mm,
                         'presort'      =>  \&_sort_presort,
												 'sortkey'      =>  \&_sort_sortkey,
												 'sortname'     =>  \&_sort_sortname,
												 'sorttitle'    =>  \&_sort_sorttitle,
												 'sortyear'     =>  \&_sort_sortyear,
												 'sortyearD'    =>  \&_sort_sortyear_descend,
												 'title'        =>  \&_sort_title,
												 'translator'   =>  \&_sort_translator,
                         'volume'       =>  \&_sort_volume,
                         'year'         =>  \&_sort_year,
                         'yearD'        =>  \&_sort_year_descend,
};

# Main sorting dispath method
sub _dispatch_sorting {
  my ($self, $sortfield, $citekey) = @_;
  return &{$dispatch_sorting->{$sortfield}}($self,$citekey);
};

# Conjunctive set of sorting sets
sub _generatesortstring {
	my ($self, $citekey) = @_ ;
	my $be = $self->{bib}{$citekey} ;
	my $sortscheme = $self->getblxoption('sorting', $citekey);
  my $sortstring;
  $BIBER_SORT_FINAL = 0; # reset sorting short-circuit
  foreach my $sortset (@{$sortscheme}) {
    # always append $sorting_sep, even if sortfield returns the empty string.
    # This makes it easier to read sortstring for debugging etc.
    $sortstring .= $self->_sortset($sortset, $citekey) . $sorting_sep;
    if ($BIBER_SORT_FINAL) { # Last sortfield was specified in attributes as the last
      last;
    }
  }
  $sortstring =~ s/0\z//xms; # strip off the last '0' added by _sortset()
  $be->{sortstring} = lc($sortstring);
  return;
}

# Disjunctive sorting set
sub _sortset {
	my ($self, $sortset, $citekey) = @_ ;
  foreach my $sortelement (@{$sortset}) {
    my ($sortelementname, $sortelementattributes) = %{$sortelement};
    my $string = $self->_dispatch_sorting($sortelementname,$citekey);
    if ($string) { # sort returns something for this key
      if (first {$_ eq 'final'} @{$sortelementattributes} ) { # set short-circuit flag if specified
        $BIBER_SORT_FINAL = 1;
      }
      return $string;
    }
  }
}

##############################################
# Sort dispatch routines
#############################################

sub _sort_0000 {
	return '0000';
}

sub _sort_9999 {
	return '9999';
}

sub _sort_author {
  my ($self, $citekey) = @_ ;
  my $be = $self->{bib}{$citekey} ;
	if ($self->getblxoption('useauthor', $citekey) and $be->{author}) {
		return $self->_namestring($citekey, 'author');
	}
	else {
		return '';
	}
}

sub _sort_editor {
  my ($self, $citekey) = @_ ;
  my $be = $self->{bib}{$citekey} ;
	if ($self->getblxoption('useeditor', $citekey) and $be->{editor}) {
		return $self->_namestring($citekey, 'editor');
	}
	else {
		return '';
	}
}

sub _sort_issuetitle {
  my ($self, $citekey) = @_ ;
  my $be = $self->{bib}{$citekey} ;
	my $no_decode = $self->_nodecode($citekey);
  if ($be->{issuetitle}) {
		return normalize_string( $be->{issuetitle}, $no_decode );
	}
	else {
		return '';
	}
}

sub _sort_journal {
  my ($self, $citekey) = @_ ;
  my $be = $self->{bib}{$citekey} ;
	my $no_decode = $self->_nodecode($citekey);
  if ($be->{journal}) {
		return normalize_string( $be->{journal}, $no_decode );
	}
	else {
		return '';
	}
}

sub _sort_mm {
	return 'mm';
}

sub _sort_labelalpha {
  my ($self, $citekey) = @_ ;
  my $be = $self->{bib}{$citekey} ;
	return $be->{labelalpha} ? $be->{labelalpha} : '';
}

sub _sort_presort {
  my ($self, $citekey) = @_ ;
  my $be = $self->{bib}{$citekey} ;
	return $be->{presort} ? $be->{presort} : '';
}

sub _sort_sortkey {
  my ($self, $citekey) = @_ ;
  my $be = $self->{bib}{$citekey};
  if ($be->{sortkey}) {
    my $sortkey = lc($be->{sortkey});
    $sortkey = latex_decode($sortkey) unless $self->_nodecode($citekey);
    return $sortkey;
  }
  else {
    return '';
  }
}

sub _sort_sortname {
  my ($self, $citekey) = @_ ;
  my $be = $self->{bib}{$citekey} ;
  # see biblatex manual §3.4 - sortname is ignored if no use<name> option is defined
	if ($be->{sortname} and
			($self->getblxoption('useauthor', $citekey) or
			 $self->getblxoption('useeditor', $citekey) or
			 $self->getblxoption('useetranslator', $citekey))) {
		return $self->_namestring($citekey, 'sortname');
	}
	else {
		return '';
	}
}

sub _sort_sorttitle {
  my ($self, $citekey) = @_ ;
  my $be = $self->{bib}{$citekey} ;
	my $no_decode = $self->_nodecode($citekey);
	if ($be->{sorttitle}) {
		return normalize_string( $be->{sorttitle}, $no_decode );
	}
	else {
		return '';
	}
}

sub _sort_sortyear {
  my ($self, $citekey) = @_ ;
  my $be = $self->{bib}{$citekey} ;
	if ($be->{sortyear}) {
		return substr( $be->{sortyear}, 0, 4 ) ;
	}
	else {
		return '';
	}
}

sub _sort_sortyear_descend {
  my ($self, $citekey) = @_ ;
  my $be = $self->{bib}{$citekey} ;
	if ($be->{sortyear}) {
		return 9999 - substr($be->{sortyear}, 0, 4);
    }
	else {
		return '';
	}
}

sub _sort_title {
  my ($self, $citekey) = @_ ;
  my $be = $self->{bib}{$citekey} ;
	my $no_decode = $self->_nodecode($citekey);
  if ($be->{title}) {
		return normalize_string( $be->{title}, $no_decode );
	}
	else {
		return '';
	}
}

sub _sort_translator {
  my ($self, $citekey) = @_ ;
  my $be = $self->{bib}{$citekey} ;
	if ($self->getblxoption('usetranslator', $citekey) and $be->{translator}) {
		return $self->_namestring($citekey, 'translator');
	}
	else {
		return '';
	}
}

sub _sort_volume {
  my ($self, $citekey) = @_ ;
  my $be = $self->{bib}{$citekey} ;
  if ($be->{volume}) {
    return sprintf( "%04s", $be->{volume});
  }
  else {
    return '' ;
  }
}

sub _sort_year {
  my ($self, $citekey) = @_ ;
  my $be = $self->{bib}{$citekey} ;
	if ($be->{year}) {
		return substr( $be->{year}, 0, 4 ) ;
	}
	else {
		return '';
	}
}

sub _sort_year_descend {
  my ($self, $citekey) = @_ ;
  my $be = $self->{bib}{$citekey} ;
	if ($be->{year}) {
		return 9999 - substr($be->{year}, 0, 4);
    }
	else {
		return '';
	}
}

#========================================================
# Utiltly subs used elsewhere but relying on sorting code
#========================================================

sub _nodecode {
	my ($self, $citekey) = @_ ;
	my $no_decode = ($self->{config}->{unicodebib} or
								   $self->{config}->{fastsort} or
									 $self->{bib}->{$citekey}->{datatype} eq 'xml');
	return $no_decode;
}

sub _getyearstring {
  my ($self, $citekey) = @_ ;
  my $be = $self->{bib}{$citekey} ;
  my $string;
  $string = $self->_dispatch_sorting('sortyear',$citekey);
  return $string if $string;
  $string = $self->_dispatch_sorting('year',$citekey);
  return $string if $string;
  return '';
}

sub _getnamestring {
  my ($self, $citekey) = @_ ;
  my $be = $self->{bib}{$citekey} ;
  my $string;
  $string = $self->_dispatch_sorting('sortname',$citekey);
  return $string if $string;
  $string = $self->_dispatch_sorting('author',$citekey);
  return $string if $string;
  $string = $self->_dispatch_sorting('editor',$citekey);
  return $string if $string;
  $string = $self->_dispatch_sorting('translator',$citekey);
  return $string if $string;
  return '';
}

sub _namestring {
	my ( $self, $citekey, $field ) = @_ ;
  my $be = $self->{bib}->{$citekey} ;
	
	my $str = "" ;
  my @names = @{ $be->{$field} } ;
  my $truncated = 0 ;
  ## perform truncation according to options minnames, maxnames
  if ( $#names + 1 > $self->getblxoption('maxnames', $citekey) ) {
    $truncated = 1 ;
    @names = splice(@names, 0, $self->getblxoption('minnames', $citekey) )
  }
  ;
  foreach ( @names ) {
    $str .= $_->{prefix} . "2"
      if ( $_->{prefix} and $self->getblxoption('useprefix', $citekey ) ) ;
    $str .= $_->{lastname} . "2" ;
    $str .= $_->{firstname} . "2" if $_->{firstname} ;
    $str .= $_->{suffix} if $_->{suffix} ;
    $str =~ s/2$// ;
    $str .= "1" ;
  }
  ;
  $str =~ s/\s+1/1/g;
  $str =~ s/1$//;
  $str = normalize_string($str, $self->_nodecode($citekey));
  #TODO append "zzzz" if it has been truncated
  $str .= "1zzzz" if $truncated ;
  return $str
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
	my ($self, $au, $citekey) = @_ ;
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
    if ( $self->getblxoption('terseinits', $citekey) ) {
        $lni = tersify($lni) ;
        $fni = tersify($fni) ;
        $prei = tersify($prei) ;
        $sufi = tersify($sufi) ;
    } ;
    return "    {{$ln}{$lni}{$fn}{$fni}{$pre}{$prei}{$suf}{$sufi}}%\n" ;
}

sub _printfield {
    my ($self, $field, $str) = @_ ;
    my $width = $self->getblxoption('maxline') ;

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

    $str .= "% sortstring = " . $be->{sortstring} . "\n" if $self->getblxoption('debug') ;

    $str .= "\\entry{$origkey}{" . $be->{entrytype} . "}{$opts}\n" ;

    if ( $be->{entrytype} eq 'set' ) {
        $str .= "  \\entryset{" . $be->{entryset} . "}\n" ;
    }

    if ($Biber::inset_entries{$citekey}) {
        ## NB should be equal to $be->{entryset} but we prefer to make it optional
        # TODO check against $be->entryset and warn if different!
        $str .= "  \\inset{" . $Biber::inset_entries{$citekey} . "}\n" ;
    }

#    delete $be->{entrytype}; #forgot why this is needed!

		# make labelname a copy of the right thing before output of name lists
		if (_defined_and_nonempty($be->{labelnamename})) { # avoid unitialised variable warnings
			$be->{labelname} = $be->{$be->{labelnamename}};
		}

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
                $str .= $self->_print_name($n, $citekey) ;
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
    if ( $self->getblxoption('labelalpha', $citekey) ) {
        my $label = $be->{labelalpha} ;
        $str .= "  \\field{labelalpha}{$label}\n" ;
    }
    $str .= "  \\field{sortinit}{$sortinit}\n" ;
    
    if ( $self->getblxoption('labelyear', $citekey) ) {
        my $authoryear = $be->{authoryear} ;
        if ( $Biber::seenauthoryear{$authoryear} > 1) {
            $Biber::seenlabelyear{$authoryear}++ ;
            $str .= "  \\field{labelyear}{" 
              . $Biber::seenlabelyear{$authoryear} . "}\n" ;
        }
    }

    if ( $self->getblxoption('extraalpha', $citekey) ) {
        my $authoryear = $be->{authoryear} ;
        if ( $Biber::seenauthoryear{$authoryear} > 1) {
            $Biber::seenlabelyear{$authoryear}++ ;
            $str .= "  \\field{extraalpha}{" 
              . $Biber::seenlabelyear{$authoryear} . "}\n" ;
        }
    }

    if ( $self->getblxoption('labelnumber', $citekey) ) {
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
        my $lname = $be->{labelnamename} ;
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

    if ( $self->getblxoption('singletitle', $citekey)
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
