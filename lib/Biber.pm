#===============================================================================
#
#         FILE:  Biber.pm
#
#  DESCRIPTION:  Base module for biber
#
#       AUTHOR:  François Charette <firmicus ατ gmx δοτ net>
#      VERSION:  0.4
#      CREATED:  24/02/2009 11:00:33 CET
#     REVISION:  ---
#===============================================================================
package Biber;
use strict;
use warnings;
use Carp;
use IO::File;
use Encode;

# TODO 
# if have bib data:
use LaTeX::Decode; # bundled with Biber
	# if bibtex is installed:
use Text::BibTeX ;
	# else:
# use Parse::RecDescent;
use Regexp::Common qw{ balanced };
	#endfi
#else we have xml:
	#use XML::LibXML
#else we have dbxml:
use Sleepycat::DbXml 'simple';
use File::Basename;
#endfi

use Biber::Constants ;
use Biber::Internals ;
use Biber::Utils ;
use base 'Biber::Internals';

our $VERSION = '0.4';

#TODO read config file (e.g. $HOME/.biber.conf to change default options)

#FIXME better put the followings in the Biber object ?
our %seenkeys    = () ;
our %crossrefkeys = ();
our %entrieswithcrossref = ();
our %localoptions = ();
our %namehashcount  = ();
our %seenuniquename = ();
our %seenauthoryear = ();
our %seenlabelyear = ();

sub new {
    my ($class, $opts) = @_ ;
    my %params = %$opts;
    my $self = bless {}, $class ;
    $self->_initopts();
    for (keys %params) {
        $self->{config}->{$_} = $params{$_} ;
    };

    return $self
}

sub config {
    my ($self, $opt) = @_ ;
    return $self->{config}->{$opt} 
}

sub _initopts {
    my $self = shift;
    for (keys %CONFIG_DEFAULT) {
        $self->{config}->{$_} = $CONFIG_DEFAULT{$_}
    };
    return
}

sub citekeys {
    my $self = shift;
    if ( $self->{citekeys} ) {
        return @{ $self->{citekeys} }
    } else {
        return ()
    }
}

sub bibentry {
    my ($self, $key) = @_;
    return %{ $self->{bib}->{$key} }
}

sub bib {
    my $self = shift;
    if ( $self->{bib} ) {
        return %{ $self->{bib} } 
    }
    else {
        return 
    }
}

sub shorthands {
    my $self = shift;
    if ( $self->{shorthands} ) {
        return @{ $self->{shorthands} }
    } else {
        return
    }
}

sub _addshorthand {
    my ($self, $key) = @_;
    my @los;
    if ( $self->{shorthands} ) {
        @los = @{ $self->{shorthands} } 
    } else {
        @los = ();
    };
    push @los, $key;
    $self->{shorthands} = [ @los ];    
    return
}

sub parse_auxfile {
    my $self = shift;
    my $auxfile = shift; 
    my @bibdatafiles = $self->{config}->{bibdata};
    my @auxcitekeys = $self->citekeys;
    croak "Cannot find file '$auxfile'!\n" unless -f $auxfile;
    croak "File '$auxfile' is not an .aux file!\n" unless $auxfile =~ m/\.aux$/;
    my $aux = new IO::File "<$auxfile" or croak "Failed to open $auxfile : $!";

    my $ctrl_file = "";

    local $/ = "\n";
    while (<$aux>) {
        if ( $_ =~ /^\\bibdata/ ) { 
            # There can be more than one bibdata file! 
            # We can parse many bib and/or xml files
            # Datafile given as option -d should be parsed first, then the other ones
            (my $bibdatastring) = m/^\\bibdata{ #{ for readability in vim
                                               ([^}]+)
                                                      }/x;
            
            my @tmp = split/,/, $bibdatastring; 
            
            $ctrl_file = shift @tmp; 
            
            if (defined $bibdatafiles[0]) {
                push (@bibdatafiles, @tmp);
            }
            else {
                @bibdatafiles = @tmp
            }

            $self->{config}->{bibdata} = [ @bibdatafiles ] ;
        }

        if ( $_ =~ /^\\citation/ ) { 
            m/^\\citation{ #{ for readability in vim
                          ([^}]+)
                                 }/x;  
            unless ( $seenkeys{$1} or $1 eq "biblatex-control" or $1 eq '*' ) {
                push @auxcitekeys, decode_utf8($1);
                $seenkeys{$1}++
            } 
            if ( $1 eq '*' ) {
                $self->{config}->{allentries} = 1 
            }
        }
    }

    if (-f $ctrl_file) {
        parse_ctrlfile($ctrl_file) 
    }
#    else {
#        parse_ctrlfile("$basefile-blx") <<< IGNORE IT IF NOT MENTIONED IN aux FILE
#    }
    
    unless (@bibdatafiles) {
        croak "No database is provided in the file '$auxfile'!\nExiting\n"
    }

    unless ($self->config('allentries') or @auxcitekeys) {
        croak "The file '$auxfile' does not contain any citations!\n"
    }

    print "Found ", $#auxcitekeys+1 , " citekeys in aux file\n" 
        unless ( $self->config('quiet') or $self->config('allentries') );

    @auxcitekeys = sort @auxcitekeys if $self->config('biberdebug');

    print "The citekeys are:\n", "@auxcitekeys", "\n\n" if $self->config('biberdebug');
    
    $self->{citekeys} = [ @auxcitekeys ] ;

    return
}

#=====================================================
# PARSE CONTROL FILE with simple regex matching...
#=====================================================
#this is needed to generate the control macros in the bbl
#  version            = 0.8
#  ctrl-debug       = 0,
#  ctrl-bibtex8     = 0,     ignore
#  ctrl-terseinits  = 0,     package option (boolean)
#  ctrl-useprefix   = 0,     package option (boolean)
#  ctrl-useauthor   = 1,     package option (boolean)
#  ctrl-useeditor   = 1,     package option (boolean)
#  ctrl-labelalpha  = 0,     package option (boolean)
#  ctrl-labelyear   = 0,     package option (boolean)
#  ctrl-singletitle = 0,     package option (boolean)
#  ctrl-uniquename  = 0,     package option (0=false, 1=true, 2=init)
#  ctrl-sorting     = 1,     package option (key)
#  ctrl-sortlos     = 1,     package option (boolean)
#  ctrl-maxnames    = 3,     counter
#  ctrl-minnames    = 1,     counter
#  ctrl-maxline     = 79,    package option (counter: min value=49)
#  ctrl-alphaothers = {+}    string

#TODO warn instead and skip the following,
#     since we have the default values already...

sub parse_ctrlfile {
    my ($self, $ctrl_file) = @_ ;

    croak "Cannot find control file '$ctrl_file.bib'!\n" unless -f "$ctrl_file.bib";

    my $ctrl = new IO::File "<$ctrl_file.bib"
          or croak "Cannot open $ctrl_file.bib: $!";

    while (<$ctrl>) {
        
        next unless /^\s*ctrl-options/;
        
        (my $opts) = /{(.+)}/;
    
        (my $controlversion,
        $self->{config}->{debug},
        $self->{config}->{bibtex8},
        $self->{config}->{terseinits},
        $self->{config}->{useprefix},
        $self->{config}->{useauthor},
        $self->{config}->{useeditor},
        $self->{config}->{labelalpha},
        $self->{config}->{labelyear},
        $self->{config}->{singletitle},
        $self->{config}->{uniquename},
        $self->{config}->{sorting},
        $self->{config}->{sortlos},
        $self->{config}->{maxnames},
        $self->{config}->{minnames},
        $self->{config}->{maxline},
        $self->{config}->{alphaothers}) = split /:/, $opts; 

        carp "Warning: You are not using biblatex version $BIBLATEX_VERSION!\n" 
            unless substr($controlversion,0,2) eq $BIBLATEX_VERSION ;
    }
    
    return
}

#=====================================================
# Parse BIB file
#=====================================================


sub parse_bibtex {
    my ($self, $filename) = @_ ;
    # citekeys that are in this database
    my @localkeys;
    
    print "Processing bibtex file $filename\n" unless $self->config('quiet');

    my %citekeysnotfound = ();
    my @auxcitekeys = $self->citekeys;
    my %bibentries = $self->bib;

    if ( !$self->config('unicodebib') && $self->config('unicodebbl') ) {
        require File::Slurp;    #
        my $ufilename = "$filename.utf8";
        my $ubib      = new IO::File ">$ufilename";
        $ubib->binmode(':utf8');
        my $buf       = File::Slurp::read_file($filename) or croak "Can't read $filename";

        #TODO decode $buf if encoding is not UTF-8 : cmd-line option --inputencoding
        print $ubib latex_decode($buf) or croak "Can't write to $ufilename : $!";
        $ubib->close or croak "Can't close filehandle to $ufilename: $!";
        $filename    = $ufilename;
        $self->{config}->{unicodebib} = 1;
    }

    if ( !$self->config('useprd') && eval { require Text::BibTeX; 1 } ) {

        require Text::BibTeX ;
        my $bib = new Text::BibTeX::File $filename
          or croak "Cannot create Text::BibTeX::File object from $filename: $!";

        #TODO validate with Text::BibTeX::Structure ?
        my $preamble;

        while ( my $entry = new Text::BibTeX::Entry $bib ) {

            next if ( $entry->metatype == BTE_MACRODEF ) ;                    

            my $key = $entry->key ;

            print "Processing $key\n" if $self->config('biberdebug');

            if ( $bibentries{ $key } ) {
                print "We already have key $key! Ignoring in $filename...\n"
                    unless $self->config('quiet');
                next;
            }
            push @localkeys, $key;
            unless ($entry->parse_ok) {
                carp "Entry $key does not parse correctly: skipping" 
                    unless $self->config('quiet') ;
                next ;
            }
            if ( $entry->metatype == BTE_PREAMBLE ) {
                $preamble .= $entry->value;
				next;
            }

            my @flist = $entry->fieldlist ;
			my @flistnosplit = array_minus(\@flist, \@ENTRIESTOSPLIT);

			if ( $entry->metatype == BTE_REGULAR ) {
                foreach my $f ( @flistnosplit ) {
                    $bibentries{ $key }->{$f} =
                      decode_utf8( $entry->get($f) );
                };
				foreach my $f ( @ENTRIESTOSPLIT ) {
					next unless $entry->exists($f);
					my @tmp = map { decode_utf8($_) } $entry->split($f);
					$bibentries{ $key }->{$f} = [ @tmp ] 
				};

                $bibentries{ $key }->{entrytype} = $entry->type;
                $bibentries{ $key }->{datatype} = 'bibtex';
            }
        }
    }
    else {
        require Parse::RecDescent;
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
    }

    unlink "$filename.utf8" if -f "$filename.utf8";


    # Handling of crossrefs
    foreach my $citekey (@localkeys) {
        if ($bibentries{$citekey}->{crossref}) {
            my $crefkey = $bibentries{$citekey}->{crossref};
            $crossrefkeys{$crefkey}++;
            $entrieswithcrossref{$citekey} = $crefkey;
        }
    }
    
    # parse name entries into hashes containing the different parts of each name
	foreach my $citekey (@localkeys) {
		my $be = $bibentries{$citekey};
        foreach my $field (@NAMEFIELDS) {
	        next unless $be->{$field};
            my @names = @{ $be->{$field} };
            my @nameAoH;    # array of hashes
            foreach my $name (@names) {
                push @nameAoH, $self->parsename( $name, $citekey );
            };
        	$be->{$field} = [@nameAoH];
        }
	}

    $self->{bib} = { %bibentries };

    $self->{citekeys} = [ keys %{ $self->{bib} } ];

    return

}

sub parse_biblatexml {
    my ($self, $xml) = @_ ;
    require XML::LibXML;
    my $parser = XML::LibXML->new();
    my $db;

    print "Parsing the xml data ...\n" unless $self->config('quiet') ;

    if ( $xml =~ /\.dbxml$/ ) {
        my $xmlstring = $self->dbxml_to_xml($xml);
        $db = $parser->parse_string( $xmlstring ) 
            or croak "Cannot parse xml string";
    } else {
        $db = $parser->parse_file($xml) 
            or croak "Can't parse file $xml";
    }
    # TODO : add option "validate xml" 
    # if ($validatexml) {
    #         my $rngschema = XML::LibXML::RelaxNG->new( location => "biblatexml.rng");
    #         my $validation = eval { $rngschema->validate($db) ; } ; 
    #         unless ($validation) {
    #             carp "The file $xmlfile does not validate against the biblatexml RelaxNG schema!\n$@"
    #         };
    # };
    
    # keep track of citekeys that were not found in this database
    my %citekeysnotfound = ();
    my @auxcitekeys = $self->citekeys;
    my %bibentries = $self->bib;
    
    if ($self->config('allentries')) {
        @auxcitekeys = ();
        my $res = $db->findnodes('/*/bib:entry');
        foreach my $r ($res->get_nodelist) {
            push @auxcitekeys, $r->findnodes('@id')->string_value
        };
    };
    
    print "Processing the xml data ...\n" unless $self->config('quiet') ;

    # Contrary to the bibtex approach, we are not extracting all data to
    # the bibentries hash, but only the ones corresponding to @auxcitekeys
    foreach my $citekey (@auxcitekeys) {
        next if $bibentries{$citekey}; # skip if this is already found in another database
        print "Looking for $citekey\n" if $self->config('biberdebug');
        my $xpath = '/*/bib:entry[@id="' . $citekey . '"]';
        my $results = $db->findnodes($xpath);
        unless ( $results ) {
            # print "Can't find entry with citekey $citekey... skipping\n";
            # we remove $citekey from @auxcitekeys
            $citekeysnotfound{$citekey} = 1;
            #@auxcitekeys = grep { $_ ne $citekey } @auxcitekeys;
            next
        };
        if ( $results->size() > 1 ) { 
            carp "The database contains more than one bib:entry with id=\"$citekey\" !" 
        };
        my $bibrecord = $results->get_node(1); 

        # if there is a crossref, we increment its citekey in %crossrefkeys
        if ( $bibrecord->findnodes('bib:crossref') ) {
            my $crefkey = $bibrecord->findnodes('bib:crossref')->string_value ;
            $crossrefkeys{$crefkey}++;
            $entrieswithcrossref{$citekey} = $crefkey;
        };
    };

    foreach my $k ( keys %crossrefkeys ) {
        push @auxcitekeys, $k unless $self->config('allentries') ;
    };
    #--------------------------------------------------

    foreach my $citekey (@auxcitekeys) {
        next if $citekeysnotfound{$citekey};
        next if $bibentries{$citekey}; # skip if this is already found in another database
        print "Processing key $citekey\n" if $self->config('biberdebug');
        my $xpath = '/*/bib:entry[@id="' . $citekey . '"]';
        my $results = $db->findnodes($xpath);
        my $bibrecord = $results->get_node(1); 

        $bibentries{ $citekey }->{entrytype} = $bibrecord->findnodes('@entrytype')->string_value;
        $bibentries{ $citekey }->{datatype} = 'xml';

        #TODO get the options field first 
        #options/text or option: key+value
        if ($bibrecord->findnodes("bib:options")) {
            if ($bibrecord->findnodes("bib:options/bib:option")) {
                my @opts; 
                foreach my $o ($bibrecord->findnodes("bib:options/bib:option")->get_nodelist) {
                    my $k = $o->findnodes("bib:key")->string_value; 
                    my $v = $o->findnodes("bib:value")->string_value;
                    push @opts, "$k=$v";
                };
                $bibentries{$citekey}->{options} = join(",", @opts);
            }
            else {
                $bibentries{$citekey}->{options} = $bibrecord->findnodes("bib:options")->string_value;
            }
        };
        
        # then we extract in turn the data from each type of fields

        foreach my $f (@LITERALFIELDS, @VERBATIMFIELDS) {
            $bibentries{$citekey}->{$f} = $bibrecord->findnodes("bib:$f")->string_value 
                if $bibrecord->findnodes("bib:$f");
        };

        foreach my $lf (@LISTFIELDS) {
            my @z;
            if ($bibrecord->findnodes("bib:$lf")) {
                if ($bibrecord->findnodes("bib:$lf/bib:item")) {
                    foreach my $item ($bibrecord->findnodes("bib:$lf/bib:item")->get_nodelist) {
                        push @z, $item->string_value;
                    }
                }
                else {
                     push @z, $bibrecord->findnodes("bib:$lf")->string_value
                };
                if ($bibrecord->findnodes("bib:$lf\[\@andothers='true'\]")) {
                    push @z, "others"
                };
                $bibentries{$citekey}->{$lf} = [ @z ]
            }
        };

        foreach my $rf (@RANGEFIELDS) {
            if ($bibrecord->findnodes("bib:$rf")) {
                if ($bibrecord->findnodes("bib:$rf/bib:start")) {
                     my $fieldstart = $bibrecord->findnodes("bib:$rf/bib:start")->string_value;
                     my $fieldend   = $bibrecord->findnodes("bib:$rf/bib:end")->string_value;
                    $bibentries{$citekey}->{$rf} = "$fieldstart--$fieldend";
                }
                elsif ($bibrecord->findnodes("bib:$rf/bib:list")) {
                    $bibentries{$citekey}->{$rf} = 
                        $bibrecord->findnodes("bib:$rf/bib:list")->string_value
                }
                else {
                    $bibentries{$citekey}->{$rf} = 
                        $bibrecord->findnodes("bib:$rf")->string_value
                }
            };
        };

        #the name fields are somewhat more complex
        foreach my $nf (@NAMEFIELDS) {
            if ($bibrecord->findnodes("bib:$nf")) {
                my @z;
                if ($bibrecord->findnodes("bib:$nf/bib:person")) {
                    foreach my $person ($bibrecord->findnodes("bib:$nf/bib:person")->get_nodelist) {
                        my $lastname; 
                        my $firstname; 
                        my $prefix; 
                        my $suffix;
                        my $namestr = "";
                        my $nameinitstr = undef;
                        if ($person->findnodes('bib:last')) {
                            $lastname = $person->findnodes('bib:last')->string_value ;
                            $firstname = $person->findnodes('bib:first')->string_value ; 
                            $prefix = $person->findnodes('bib:prefix')->string_value 
                                if $person->findnodes('bib:prefix');
                            $suffix = $person->findnodes('bib:suffix')->string_value
                                if $person->findnodes('bib:suffix');
                            $namestr .= $prefix if $prefix;
                            $namestr .= $lastname;
                            $namestr .= ", " . $firstname if $firstname;
                            if ( $self->config('uniquename') == 2 ) {
                                $nameinitstr = "";
                                $nameinitstr .= substr( $prefix, 0, 1 ) . " "
                                  if ( $self->getoption($citekey, 'useprefix') and $prefix );
                                $nameinitstr .= $lastname;
                                $nameinitstr .= ", " . terseinitials($firstname) 
                                    if $firstname;
                            } ;

                            push @z, 
                                { lastname => $lastname, firstname => $firstname, 
                                  prefix => $prefix, suffix => $suffix,
                                  namestring => $namestr, 
                                  nameinitstring => $nameinitstr }
                          }
                          # Schema allows <person>text<person>
                          else {
                              push @z, $self->parsename( $person->string_value, $citekey )
                          }
                    };
                } 
                # only one name as string, without <person>
                else {
                    push @z, $self->parsename( $bibrecord->findnodes("bib:$nf")->string_value, $citekey )
                };

                if ($bibrecord->findnodes("bib:$nf\[\@andothers='true'\]")) {
                    push @z, { lastname => "others", namestring => "others" }
                };
                
                $bibentries{$citekey}->{$nf} = [ @z ]
            }
        };

        # now we extract the attributes
        my %xmlattributes = ( 
            'bib:pages/@pagination' => 'pagination',
            'bib:pages/@bookpagination' => 'bookpagination',
            'bib:author/@type' => 'authortype',
            'bib:editor/@type' => 'editortype',
            'bib:author/@gender' => 'gender',
            # 'bib:editor/@gender' => 'gender', (ignored for now)
            '@howpublished' => 'howpublished'
            ); 
        foreach my $attr (keys %xmlattributes) {
            if ($bibrecord->findnodes($attr)) {
                $bibentries{ $citekey }->{ $xmlattributes{$attr} } 
                    = $bibrecord->findnodes($attr)->string_value ;
            }
        }
    };

    $self->{bib} = { %bibentries };

    # now we keep only citekeys that actually exist in the database
    $self->{citekeys} = [ grep { defined $self->{bib}->{$_} } @auxcitekeys ];

    return
}


###############################################
# internal post-processing to prepare output

#------------------------------------------------
# parse names, generate namehash and strings for "uniquename", "labelyear",
# "labelalpha", "sortstrings", etc

#TODO flesh out this monster into several internal subs
sub postprocess {
    my $self = shift;

    foreach my $citekey ( $self->citekeys ) {
        unless ( $self->{bib}->{$citekey} ) {
            print "Could not find key $citekey in the database(s)! Skipping...\n" ;
            next;
        };
        my $be = $self->{bib}->{$citekey};
        print "postprocessing $citekey\n" if $self->config('biberdebug');
        my $dt = $be->{datatype};
        
        # get day month year from date field if no year is supplied
        if ( $be->{date} && !$be->{year} ) {
            my $date = $be->{date};
            $be->{year}  = substr $date, 0, 4;
            $be->{month} = substr $date, 5, 2 if length $date > 6;
            $be->{day}   = substr $date, 8, 2 if length $date > 9;
        }
        
        ## set local options to override global options for individual entries
        if ( $be->{options} ) {
            my @entryoptions = split /\s*,\s*/, $be->{options};
            foreach (@entryoptions) {
                m/^([^=]+)=?(.+)?$/;
                if ( $2 and $2 eq "false" ) {
                    $localoptions{$citekey}->{$1} = 0;
                }
                elsif ( $2 and $2 eq "true" ) {
                    $localoptions{$citekey}->{$1} = 1;
                }
                elsif ($2) {
                    $localoptions{$citekey}->{$1} = $2;
                }
                else {
                    $localoptions{$citekey}->{$1} = 1;
                }
            }
        }

        ### determine "namehash" field for biblatex
        my $namehash;
        my $fullhash;
        my $nameid;
        my $nameinitid;
        if ( $be->{sortname}
             and (   $self->getoption( $citekey, "useauthor" ) 
                  or $self->getoption( $citekey, "useeditor" ) 
                 )
           )
        {
            my @aut = @{ $be->{sortname} };
            $namehash   = $self->getnameinitials( $citekey, @aut );
            $fullhash   = $self->getallnameinitials( $citekey, @aut );
            $nameid     = makenameid(@aut);
            $nameinitid = makenameinitid(@aut)
              if ( $self->config('uniquename') == 2 );
        }
        elsif ( $self->getoption( $citekey, "useauthor" ) 
                and $be->{author} ) {
            my @aut = @{ $be->{author} };
            $namehash   = $self->getnameinitials( $citekey, @aut );
            $fullhash   = $self->getallnameinitials( $citekey, @aut );
            $nameid     = makenameid(@aut);
            $nameinitid = makenameinitid(@aut)
              if ( $self->config('uniquename') == 2 );
        }
        elsif ( ($be->{entrytype} =~ /^(collection|proceedings)/ #<<-- keep this? FIXME
                    and $self->getoption( $citekey, "useeditor" ) )
                 and $be->{editor} ) 
        {
            my @edt = @{ $be->{editor} };
            $namehash   = $self->getnameinitials( $citekey, @edt );
            $fullhash   = $self->getallnameinitials( $citekey, @edt );
            $nameid     = makenameid(@edt);
            $nameinitid = makenameinitid(@edt)
              if ( $self->config('uniquename') == 2 );
        }
        elsif ( $self->getoption( $citekey, "usetranslator" ) 
                and $be->{translator} ) {
            my @trs = @{ $be->{translator} };
            $namehash   = $self->getnameinitials( $citekey, @trs );
            $fullhash   = $self->getallnameinitials( $citekey, @trs );
            $nameid     = makenameid(@trs);
            $nameinitid = makenameinitid(@trs)
              if ( $self->config('uniquename') == 2 );
        }
        else {    # initials of title
            if ( $be->{sorttitle} ) {
                $namehash   = terseinitials( $be->{sorttitle} ) ; 
                $fullhash   = $namehash;
                $nameid     = cleanstring( $be->{sorttitle} );
                $nameinitid = $nameid if ( $self->config('uniquename') == 2 );
            }
            else {
                $namehash   = terseinitials( $be->{title} ) ; 
                $fullhash   = $namehash;
                $nameid     = cleanstring( $be->{title} );
                $nameinitid = $nameid if ( $self->config('uniquename') == 2 );
            }
        }

        my $hashsuffix = 1;

        # FIXME FIXME

        if ( $namehashcount{$namehash}{$nameid} ) {
            $hashsuffix = $namehashcount{$namehash}{$nameid}
        }
        elsif ($namehashcount{$namehash}) {
            my $count = scalar keys %{ $namehashcount{$namehash} };
            $hashsuffix = $count + 1 ;
            $namehashcount{$namehash}{$nameid} = $hashsuffix ;
        }
        else {
            $namehashcount{$namehash} = { $nameid => 1 }
        } ;
             
        $namehash .= $hashsuffix;
        $fullhash .= $hashsuffix;

        $be->{namehash} = $namehash;
        $be->{fullhash} = $fullhash;

        if ( $self->config('uniquename') == 2 ) {
            $seenuniquename{$nameinitid}++;
            $be->{uniquename} = $nameinitid;
        }
        else {
            $seenuniquename{$nameid}++;
            $be->{uniquename} = $nameid;
        }

        ### Generate the labelalpha --- TODO : check for labelname ??
        if ( $self->config('labelalpha') ) {
            my $label;

            if ($be->{shorthand}) 
            {
                $label = $be->{shorthand} 
            }
            else 
            {
                if ($be->{label}) 
                {
                    $label = $be->{label}
                } 
                elsif ( $be->{author} and $self->getoption( $citekey, "useauthor" ) ) 
                { 
                # TODO option $useprefix needs to be taken into account!
                # TODO CHECK FOR  $useauthor and $useeditor also in $bibentry{$citekey}->{options}
                    my @names     = @{ $be->{author} };
                    my @lastnames = map { normalize_string( $_->{lastname}, $dt ) } @names;
                    my $noofauth  = scalar @names;
                    if ( $noofauth > 3 ) {
                        $label =
                          substr( $lastnames[0], 0, 3 ) . $self->config('alphaothers');
                    }
                    elsif ( $noofauth == 1 ) {
                        $label = substr( $lastnames[0], 0, 3 );
                    }
                    else {
                        foreach my $n (@lastnames) {
                            $n =~ s/\P{Lu}//g;
                            $label .= $n;
                        }
                    }
                }
                elsif ( $be->{editor} and $self->getoption( $citekey, "useeditor" ) )
                {
                    my @names     = @{ $be->{editor} };
                    my @lastnames = map { normalize_string( $_->{lastname}, $dt ) } @names;
                    my $noofauth  = scalar @names;
                    if ( $noofauth > 3 ) {
                        $label =
                          substr( $lastnames[0], 0, 3 ) . $self->config('alphaothers');
                    }
                    elsif ( $noofauth == 1 ) {
                        $label = substr( $lastnames[0], 0, 3 );
                    }
                    else {
                        foreach my $n (@lastnames) {
                            $n =~ s/\P{Lu}//g;
                            $label .= $n;
                        }
                    }
                }
                else 
                {
                    $label = "Zzz"    # ??? FIXME
                };
                my $yr;
                if ( $be->{year} ) {
                    $yr = substr $be->{year}, 2, 2;
                }
                else {
                    $yr = "00";
                }

                $label .= $yr;
            };

            $be->{labelalpha} = $label;
        }

        my $tmp = $self->getnamestring($citekey) . " " . $self->getyearstring($citekey);
        $seenauthoryear{$tmp}++;
        $be->{authoryear} = $tmp;

        if ( $be->{shorthand} ) {
            $self->_addshorthand($citekey);
        }
        ### MAKE SORT STRINGS ###
        if ( $self->config('sorting') == 1 ) {    # name title year
            $be->{sortstring} =
              lc(   $self->getinitstring($citekey) . " "
                  . $self->getnamestring($citekey) . " "
                  . $self->gettitlestring($citekey) . " "
                  . $self->getyearstring($citekey) . " "
                  . $self->getvolumestring($citekey) );
        }
        elsif ( $self->config('sorting') == 2 or $self->config('sorting') == 12 )
        {                                        # <alpha> name year title
            $be->{sortstring} =
              lc(   $self->getinitstring($citekey) . " "
                  . $self->getnamestring($citekey) . " "
                  . $self->getyearstring($citekey) . " "
                  . $self->gettitlestring($citekey) . " "
                  . $self->getvolumestring($citekey) );
        }
        elsif ( $self->config('sorting') == 3 or $self->config('sorting') == 13 )
        {                                        # <alpha> name year volume title
            $be->{sortstring} =
              lc(   $self->getinitstring($citekey) . " "
                  . $self->getnamestring($citekey) . " "
                  . $self->getyearstring($citekey) . " "
                  . $self->getvolumestring($citekey) . " "
                  . $self->gettitlestring($citekey) );
        }
        elsif ( $self->config('sorting') == 21 ) {    # year name title
            $be->{sortstring} =
              lc(   $self->getyearstring($citekey) . " "
                  . $self->getnamestring($citekey) . " "
                  . $self->gettitlestring($citekey) );
        }
        elsif ( $self->config('sorting') == 22 ) {    # year_decreasing name title
            $be->{sortstring} =
              lc(   $self->getdecyearstring($citekey) . " "
                  . $self->getnamestring($citekey) . " "
                  . $self->gettitlestring($citekey) );

        #} TODO elsif ($self->config('sorting') == 99) { #DEBUG ???
        }
        else {
            # do nothing!
            carp "Warning: the sorting code " . $self->config('sorting') . 
                 " is not defined, ignoring!\n";
        }

        $self->{bib}->{$citekey} = $be
    };

    print "Finished postprocessing entries\n" if $self->config('biberdebug');

    return
}

sub prepare {
    my $self = shift ;
    $self->process_crossrefs;
    $self->postprocess;
    $self->sortentries;
    return
}


#===========================
# SORTING
#===========================

sub sortentries {
    my $self = shift ;
    my %bibentries = $self->bib ;
    my @auxcitekeys = $self->citekeys ;
    
    if ( $self->config('sorting') ) {

        print "Sorting entries...\n" if $self->config('biberdebug');
    
        if ( $self->config('fastsort') ) {
            @auxcitekeys = sort {
                $bibentries{$a}->{sortstring} cmp $bibentries{$b}->{sortstring}
            } @auxcitekeys;
        }
        else {
            require Unicode::Collate ;
            my $Collator = Unicode::Collate->new( level => 2 ) ;
            @auxcitekeys = sort {
                $Collator->cmp( $bibentries{$a}->{sortstring},
                    $bibentries{$b}->{sortstring} )
            } @auxcitekeys ;
        }
    $self->{citekeys} = [ @auxcitekeys ] ;
    }
    
    return
}


#=====================================================
# OUTPUT .BBL FILE FOR BIBLATEX
#=====================================================

sub output_to_bbl {
    my $self = shift;
    my $bblfile = shift;
    my @auxcitekeys = $self->citekeys;

    print "Preparing final output...\n" if $self->config('biberdebug');

    my $BBLFILE = IO::File->new($bblfile, '>') or croak "Failed to open $bblfile : $!";
    $BBLFILE->binmode(':utf8') if $self->config('unicodebbl');

    my $BBL = <<"EOF"
% \$ biblatex auxiliary file \$
% \$ biblatex version 0.8 \$
% Do not modify the above lines!
%
% This is an auxiliary file used by the 'biblatex' package.
% This file may safely be deleted. It will be recreated as
% required.
%
\\begingroup
\\makeatletter
\\\@ifundefined{ver\@biblatex.sty}
{\\\@latex\@error
    {Missing `biblatex' package}
    {The bibliography requires the `biblatex' package.}
    \\aftergroup\\endinput}
{}
\\endgroup

EOF
    ;

    $BBL .= "\\preamble{%\n" . $self->{bib}->{preamble} . "\n}\n" 
        if $self->{bib}->{preamble};

    foreach my $k (@auxcitekeys) {
        next if $crossrefkeys{$k};
        $BBL .= $self->_print_for_biblatex($k);
    }
    if ( $self->config('sortlos') and $self->shorthands ) {
        $BBL .= "\\lossort\n";
        foreach my $sh ($self->shorthands) {
            $BBL .= "  \\key{$sh}\n";
        }
        $BBL .= "\\endlossort\n";
    }
    $BBL .= "\\endinput\n";
    carp "The output does not appear to be valid UTF-8!" unless Encode::is_utf8($BBL);

    #$BBL = decode('utf8', $BBL) ; #if $self->config('unicodebbl');
    print $BBLFILE $BBL or croak "Failure to write to $bblfile: $!";
    print "Output to $bblfile\n" unless $self->config('quiet');
    close $BBLFILE or croak "Failure to close $bblfile: $!";
    return
}

### TEST ###
sub dbxml_to_xml {
    my ($self, $dbxmlfile) = @_;
    my @auxcitekeys = $self->citekeys;
    my $mgr = new XmlManager() or croak ;
    my $collname = basename($dbxmlfile);
    #my $xmldoc = XML::LibXML::Document->new("1.0", "UTF-8");
    #$xmldoc->createElementNS("http://ankabut.net/biblatexml", "bib:entries");
    my $xmlstring = <<ENDXML
<?xml version="1.0" encoding="UTF-8"?>
<bib:entries xmlns:bib="http://ankabut.net/biblatexml"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
ENDXML
    ;
    eval {
        chdir( dirname($dbxmlfile)) or croak "Cannot chdir: $!";
        my $cont = $mgr->openContainer("$collname");
        my $context = $mgr->createQueryContext() ;
        $context->setNamespace("bib", "http://ankabut.net/biblatexml");
        foreach my $key (@auxcitekeys) {
            print "Querying dbxml for key $key\n" if $self->config('biberdebug');
            my $query = 'collection("' . $collname . '")//bib:entry[@id="' . $key . '"]';
            my $results = $mgr->query($query, $context) ;
            my $ressize = $results->size;
            if ($ressize > 1) {
                carp "Found $ressize entries for key $key!";
            };
            my $xmlvalue = new XmlValue;
            while ($results->next($xmlvalue)) {
                $xmlstring .= $xmlvalue->asString() . "\n    \n";
                last;
            };
            ## now we add the crossref key to the citekeys, if present:
            my $queryx = 'collection("' . $collname . '")//bib:entry[@id="' . $key . 
                '"]/bib:crossref/string()';
            my $resultsx = $mgr->query($queryx, $context) ;
            if ($resultsx->size > 0) {
                my $xmlvaluex = new XmlValue;
                while ($resultsx->next($xmlvaluex)) {
                    my $xkey = $xmlvaluex->asString() ;
                    print "Adding crossref key $xkey to the stack\n" if $self->config('biberdebug');
                    push @auxcitekeys, "$xkey";
                    last
                }
            }
        }
    };
    if (my $e = catch std::exception) {
        carp "Query failed\n";
        carp $e->what() . "\n";
        exit( -1 );
    }
    elsif ($@) {
        carp "Query failed\n" ;
        carp $@ ;
        exit( -1 ) ;
    };

    $xmlstring .= "\n</bib:entries>\n";

    return $xmlstring;
}

1;

# vim: set tabstop=4 shiftwidth=4: 

__END__


#METHODS TO ADD FOR DBXML support
#
sub get_entry_xml {
    my $citekey = shift;
    my $xpath = '/*/bib:entry[@id="' . $citekey . '"]';
    return $db->findnodes($xpath)
}



sub get_entry_dbxml {
    my $citekey = shift;
    my $query = 'collection("biblatex.dbxml")//bib:entry[@id="' . $citekey . '"]';
    my $results = $mgr->query($query, $context);
    my $xmlvalue = new XmlValue;
    while ($results->next($xmlvalue)) {
        return $xmlvalue->asString();
        last;
    }

    return
}

sub process_entry {
    my $bibrecord = shift;

}



#===============================================================================
package Biber::Bib;
use strict;
use warnings;

sub new {
    my $class = shift ;
    my $self = bless {}, $class ;
    return $self
}

sub getentry {
    my ($self, $key) = @_ ;
    return $self->{$key}
}

sub addentry {
    my ($self, $key, $hashref) = @_ ;
    $self->{$key} = { $hashref } ;
}

1;
