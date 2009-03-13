package Biber::BibTeX::PRD;
use strict;
use warnings;
use Carp;
use Biber::Constants;
use Biber::Utils;
use Parse::RecDescent;
use Regexp::Common qw{ balanced };

sub _bibtex_prd_parse {
    
    my ($self, $filename) = @_;

    my @auxcitekeys = $self->citekeys;
    
    my %bibentries = $self->bib;

    my @localkeys;

    my $grammar = q{
         BibFile : <skip: qr{\s* (\%+[^\n]*\s*)*}x> Component(s) 
         #Comment(s) {1;} # { $return = { 'comments' => \@{$item[1]} } }
        Component : Preamble { 
                        $return = { 'preamble' => $item[1] } 
                           } 
               | String(s) { 
                         my @str = @{$item[1]};
                         $return = { 'strings' => \@str } ;
                         # we perform the substitutions now
                         foreach (@str) {
                         my ($a, $b) = split(/\s*=\s*/, $_, 2);
                         $b =~ s/^\s*"|"\s*$//g;
                         $text =~ s/$a\s*#?\s*(\{?)/$1$b/g
                         }
                     } 
               | BibEntry(s) { 
                        my @entries = @{$item[1]}; 
                        $return = { 'entries' => \@entries } 
                   } 
               #     Comment : /\%+/ /[^\n]*\n+/  
         Preamble : '@PREAMBLE' PreambleString
         PreambleString : { 
                        my $value = extract_bracketed($text, '{}') ;
                        $value =~ s/^{(.*)}$/$1/s if $value;
                        $value =~ s/"\s*\n+\s*#/\n/mg;
                        #     $value =~ s/\n\s*/\n/g;
                        #   $value =~ s/^\s*{\s*(.+)\s*}\s*$/$1/s;
                        $value =~ s/^\s*"\s*//mg;
                        $value =~ s/\s*"\s*$//mg;
                        ($return) = $value if $value;
                   }
         String : '@STRING' StringArg 
         StringArg : { 
                        my $value = extract_bracketed($text, '{}') ;
                        $value =~ s/\s*\n\s*/ /g;
                        ($return) = $value =~ /^{(.*)}$/s if $value;
                   }
         BibEntry : '@' Typename '{' Key ',' Field(s) '}' /\n*/ { 
                       my %data = map { %$_ } @{$item[6]} ;
                        $return = { $item[4] => {entrytype => lc($item[2]), %data } } 
                   }
         Typename : /[A-Za-z]+/ 
         Key : /[^,\s\n]+/
         Field : Fieldname /\s*=\s*/ Fielddata /,?/ {
                        $return = { $item[1] => $item[3] } 
                   }
         Fieldname : /[A-Za-z]+/
         Fielddata : { 
                        my $value = extract_bracketed($text, '{}') ;
                        $value =~ s/\s*\n\s*/ /g;
                        ($return) = $value =~ /^{(.*)}$/s if $value;
                 } 
                 | { my $value = extract_delimited($text, '"') ;#"'
                        $value =~ s/\s*\n\s*/ /g;
                        ($return) = $value =~ /^"(.*)"$/s if $value;
                   } 
                   | /[^,]+/ { 
                        $return = $item[1] 
                   } # {} or "" are not compulsory if on single line 
    };
    undef $/;

   #my $bib = new IO::File "<$filename" or croak "Failed to open $filename: $!";
   #TODO specify another encoding if not UTF-8 : cmd-line option --inputencoding
    open my $bib, "<:encoding(utf8)",
      $filename or croak "Failed to open $filename: $!";

    #$bib =~ s/\%+.*$//mg; # this gets rid of all comments

    my $btparser = Parse::RecDescent->new($grammar) or croak "Bad grammar: $!";
    my $bf       = $btparser->BibFile(<$bib>)       or croak "bad bib: $!";
    close $bib;

    my @tmp = @$bf;

    for my $n ( 0 .. $#tmp ) {
        my @tmpk   = keys %{ $tmp[$n] };
        my $tmpkey = $tmpk[0];
        if ( $tmpkey eq 'preamble' ) {
            my $preamble = $tmp[$n]->{preamble};
        }
        elsif ( $tmpkey eq 'entries' ) {
            my @entries = @{ $tmp[$n]->{entries} };
            foreach my $i ( 0 .. $#entries ) {
                my @tmpa   = keys %{ $entries[$i] };
                my $tmpkey = $tmpa[0];
                if ( $bibentries{ $tmpkey } ) {
                    carp "We already have key $tmpkey! Ignoring in $filename...";
                    next;
                }
                push @localkeys, $tmpkey;
                $bibentries{$tmpkey} = $entries[$i]->{$tmpkey};
                $bibentries{$tmpkey}->{datatype} = 'bibtex';
            }
        }
    }

	foreach my $key ( @localkeys ) {
		foreach my $ets (@ENTRIESTOSPLIT) {
			if ( exists $bibentries{$key}->{$ets} ) {
				my $tmp = $bibentries{$key}->{$ets};
				# next if ref($tmp) neq 'SCALAR'; # we skip those that have been split

				# "and" within { } must be preserved: see biblatex manual §2.3.3
				#      (this can probably be optimized)
				foreach my $x ( $tmp =~ m/($RE{balanced}{-parens => '{}'})/gx ) {
					( my $xr = $x ) =~ s/\s+and\s+/_\x{ff08}_/g;
					$tmp =~ s/\Q$x/$xr/g;
				}
				my @y = split /\s+and\s+/, $tmp;
				my @z;
				foreach (@y) {
					s/_\x{ff08}_/ and /g;
					push @z, $_;
				}
				$bibentries{$key}->{$ets} = [@z];
			}
		}
	}

   $self->{bib} = { %bibentries } ;

   return @localkeys

}

1;
