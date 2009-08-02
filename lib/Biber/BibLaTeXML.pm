package Biber::BibLaTeXML;
use strict;
use warnings;
use Carp;
use XML::LibXML;
use Biber::BibLaTeXML::Node;
use Biber::Utils;
use Biber::Constants;
use File::Spec;
use Log::Log4perl qw(:no_extra_logdie_message);
our @ISA;

my $logger = Log::Log4perl::get_logger('main');


sub _parse_biblatexml {
    my ($self, $xml) = @_;
    my $parser = XML::LibXML->new();
    my $db;

    # FIXME : a user _could_ want to encode the bbl in LaTeX!
    # ... in which case we would need LaTeX::Encode
    $self->{config}->{unicodebbl} = 1;


    if ( $xml =~ /\.dbxml$/ ) {
        require Biber::DBXML;
        push @ISA, 'Biber::DBXML';
        $logger->info("Querying DBXML  ...");
        my $xmlstring = $self->dbxml_to_xml($xml);
        $logger->info("Parsing the XML data ...");
        $db = $parser->parse_string( $xmlstring ) 
            or $logger->logcroak("Cannot parse xml string");
    } else {
        $logger->info("Parsing the XML data ...");
        $db = $parser->parse_file($xml) 
            or $logger->logcroak("Can't parse file $xml");
    }

    if ($self->config('validate')) {
        require Config;
        # FIXME How can we be sure that Biber is installed in sitelib and not vendorlib ?
        my $xmlschema = XML::LibXML::Schema->new( 
              location => File::Spec->catfile($Config::Config{sitelibexp}, 'Biber', 'biblatexml.xsd')
            ) 
            or $logger->warn("Cannot find XML::LibXML::Schema schema for BibLaTeXML. Skipping validation : $!");

        if ($xmlschema) {
            my $validation = eval { $xmlschema->validate($db) ; };
    
            unless ($validation) {
                $logger->logcroak("The file $xml does not validate against the BibLaTeXML schema!\n$@")
            } 
        }
    }
    
    # keep track of citekeys that were not found in this database
    my %citekeysnotfound = ();
    my @auxcitekeys = $self->citekeys;
    
    if ($self->config('allentries')) {
        @auxcitekeys = ();
        my $res = $db->findnodes('/*/bib:entry');
        foreach my $r ($res->get_nodelist) {
            push @auxcitekeys, $r->findnodes('@id')->string_value
        };
    };
    
   $logger->info("Processing the XML data ...");

    # Contrary to the bibtex approach, we are not extracting all data to
    # the bibentries hash, but only the ones corresponding to @auxcitekeys
    foreach my $citekey (@auxcitekeys) {
        next if $self->{bib}->{$citekey}; # skip if this is already found in another database
        $logger->debug("Looking for $citekey");
        my $xpath = '/*/bib:entry[@id="' . $citekey . '"]';
        my $results = $db->findnodes($xpath);

        unless ( $results ) {
            $logger->info("Can't find entry with citekey $citekey... skipping");
            
            $citekeysnotfound{$citekey} = 1;
            next
        };

        if ( $results->size() > 1 ) { 
            $logger->warn("The database contains more than one bib:entry with id=\"$citekey\" !") 
        };

        my $bibrecord = $results->get_node(1);

        # if we have an entryset we add the keys to the stack
        if ($bibrecord->findnodes('@entrytype')->string_value eq 'set') {
            
            my @entrysetkeys = split /,/, $bibrecord->findnodes('bib:entryset')->string_value;

            push @auxcitekeys, @entrysetkeys;

            foreach my $setkey (@entrysetkeys) {
                $Biber::inset_entries{$setkey} = $citekey;
            }
        }
        # if there is a crossref, we increment its citekey in %crossrefkeys
        elsif ( $bibrecord->exists('bib:crossref') ) {

            my $crefkey = $bibrecord->findnodes('bib:crossref')->string_value;

            $Biber::crossrefkeys{$crefkey}++;
            $Biber::entrieswithcrossref{$citekey} = $crefkey;
        }

    };

    # now we add all crossrefs to the stack
    unless ( $self->config('allentries') ) {
        push @auxcitekeys, ( keys %Biber::crossrefkeys );
    };
    #--------------------------------------------------

    foreach my $citekey (@auxcitekeys) {
        next if $citekeysnotfound{$citekey};
        next if $self->{bib}->{$citekey}; # skip if this is already found in another database
        $logger->debug("Processing entry '$citekey'");
        my $xpath = '/*/bib:entry[@id="' . $citekey . '"]';
        my $results = $db->findnodes($xpath);
        my $bibrecord = $results->get_node(1);

        $self->{bib}->{$citekey}->{entrytype} = $bibrecord->findnodes('@entrytype')->string_value;
        if ($bibrecord->exists('@type')) {
            $self->{bib}->{$citekey}->{type} = $bibrecord->findnodes('@type')->string_value;
        };
        $self->{bib}->{$citekey}->{datatype} = 'xml';

        #TODO get the options field first 
        #options/text or option: key+value
        if ($bibrecord->exists("bib:options")) {
            if ($bibrecord->findnodes("bib:options/bib:option")) {
                my @opts;
                foreach my $o ($bibrecord->findnodes("bib:options/bib:option")->get_nodelist) {
                    my $k = $o->findnodes("bib:key")->string_value;
                    my $v = $o->findnodes("bib:value")->string_value;
                    push @opts, "$k=$v";
                };
                $self->{bib}->{$citekey}->{options} = join(",", @opts);
            }
            else {
                $self->{bib}->{$citekey}->{options} = $bibrecord->findnodes("bib:options")->string_value;
            }
        };
        
        # then we extract in turn the data from each type of fields

        #First we handle the title:
       
        my $titlename = "title";
        
        if ( $self->{bib}->{$citekey}->{entrytype} eq 'periodical') {
            if ($bibrecord->exists("bib:journaltitle")) {
                $titlename = 'journaltitle'
            } else {
                $titlename = 'journal'
            }
        }

        if (! $bibrecord->exists("bib:$titlename")) {
            if ( ! $bibrecord->exists("bib:crossref") ) {
                $logger->error("Entry $citekey has no title!")
            }
        }
        else {

            my $titlestrings = $bibrecord->findnodes("bib:$titlename")->_biblatex_title_values;

            $self->{bib}->{$citekey}->{$titlename} = $titlestrings->{'title'};

            my @specialtitlefields = qw/sorttitle indextitle indexsorttitle/;
            foreach my $field (@specialtitlefields) {
                if (! $bibrecord->exists("bib:$field") ) {
                    $self->{bib}->{$citekey}->{$field} = $titlestrings->{$field}
                }
            }
        }

        # then all other literal fields
        foreach my $field (@LITERALFIELDS, @VERBATIMFIELDS) {
            next if $field eq 'title';
            $self->{bib}->{$citekey}->{$field} = $bibrecord->findnodes("bib:$field")->_biblatex_value 
                if $bibrecord->exists("bib:$field");
        } 
        
        # list fields
        foreach my $field (@LISTFIELDS) {
            my @z;
            if ($bibrecord->exists("bib:$field")) {
                if ($bibrecord->exists("bib:$field/bib:item")) {
                    foreach my $item ($bibrecord->findnodes("bib:$field/bib:item")->get_nodelist) {
                        push @z, $item->_biblatex_value;
                    }
                }
                else {
                     push @z, $bibrecord->findnodes("bib:$field")->_biblatex_value
                };
                if ($bibrecord->exists("bib:$field\[\@andothers='true'\]")) {
                    push @z, "others"
                };
                $self->{bib}->{$citekey}->{$field} = [ @z ]
            }
        } 
        
        # range fields
        foreach my $field (@RANGEFIELDS) {
            if ($bibrecord->exists("bib:$field")) {
                if ($bibrecord->exists("bib:$field/bib:start")) {
                     my $fieldstart = $bibrecord->findnodes("bib:$field/bib:start")->string_value;
                     my $fieldend   = $bibrecord->findnodes("bib:$field/bib:end")->string_value;
                    $self->{bib}->{$citekey}->{$field} = "$fieldstart\\bibrangedash $fieldend";
                }
                elsif ($bibrecord->exists("bib:$field/bib:list")) {
                    $self->{bib}->{$citekey}->{$field} = 
                        $bibrecord->findnodes("bib:$field/bib:list")->string_value
                }
                else {
                    $self->{bib}->{$citekey}->{$field} = 
                        $bibrecord->findnodes("bib:$field")->string_value
                }
            } 
        } 

        # the name fields are somewhat more complex ...
        foreach my $field (@NAMEFIELDS) {
            if ($bibrecord->exists("bib:$field")) {
                my @z;
                if ($bibrecord->exists("bib:$field/bib:person")) {
                    foreach my $person ($bibrecord->findnodes("bib:$field/bib:person")->get_nodelist) {
                        my $lastname;
                        my $firstname;
                        my $prefix;
                        my $suffix;
                        my $namestr = "";
                        my $nameinitstr = undef;
                        if ($person->exists('bib:last')) {
                            $lastname = $person->findnodes('bib:last')->string_value;
                            $firstname = $person->findnodes('bib:first')->string_value;
                            $prefix = $person->findnodes('bib:prefix')->string_value 
                                if $person->exists('bib:prefix');
                            $suffix = $person->findnodes('bib:suffix')->string_value
                                if $person->exists('bib:suffix');
                            
                            #FIXME the following code is a repetition of part of parsename() 
                            $namestr .= $prefix if $prefix;
                            $namestr .= $lastname;
                            $namestr .= ", " . $firstname if $firstname;

                            $nameinitstr = "";
                            $nameinitstr .= substr( $prefix, 0, 1 ) . "_"
                              if ( $self->getblxoption('useprefix', $citekey) and $prefix );
                            $nameinitstr .= $lastname;
                            $nameinitstr .= "_" . terseinitials($firstname) 
                                if $firstname;

                            push @z, 
                                { lastname => $lastname, firstname => $firstname, 
                                  prefix => $prefix, suffix => $suffix,
                                  namestring => $namestr, 
                                  nameinitstring => $nameinitstr }
                        }
                        # Schema allows <person>text<person>
                        # If there is no comma in the string,
                        # we assume it to be like a protected string 
                        # in BibTeX (i.e. between curly braces),
                        # otherwise we parse it
                        else {
                            my $namestr = $person->string_value;

                            if ($namestr =~ /,\s+/) {
                                my $useprefix = $self->getblxoption('useprefix', $citekey);
                                push @z, parsename( 
                                     $person->string_value, {useprefix => $useprefix} )
                            } else {
                                push @z, 
                                    { lastname => $namestr, firstname => undef, 
                                    prefix => undef, suffix => undef,
                                    namestring => $namestr, 
                                    nameinitstring => normalize_string_underscore( $namestr ) }
                            }
                        }
                    } 
                } 
                # only one name as string, without <person>:
                # in this case we assume it is not a personal name 
                # and we take it "as is".
                else {
                    my $namestr = $bibrecord->findnodes("bib:$field")->string_value;

                    push @z, 
                        {   lastname => $namestr, firstname => undef, 
                            prefix => undef, suffix => undef,
                            namestring => $namestr, 
                            nameinitstring => normalize_string_underscore( $namestr ) }
                };

                if ($bibrecord->exists("bib:$field\[\@andothers='true'\]")) {
                    push @z, { lastname => "others", namestring => "others" }
                };
                
                $self->{bib}->{$citekey}->{$field} = [ @z ]
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
            if ($bibrecord->exists($attr)) {
                $self->{bib}->{$citekey}->{ $xmlattributes{$attr} } 
                    = $bibrecord->findnodes($attr)->string_value;
            }
        }
    };

    # now we keep only citekeys that actually exist in the database
    $self->{citekeys} = [ grep { defined $self->{bib}->{$_} } @auxcitekeys ];

    return
}

1;

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

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

=cut

# vim: set tabstop=4 shiftwidth=4 expandtab: 
