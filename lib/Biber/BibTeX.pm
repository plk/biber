package Biber::BibTeX;
use strict;
use warnings;
use Carp;
use Text::BibTeX;
use Biber::Constants;
use Biber::Utils;
use Encode;

sub _text_bibtex_parse {
    
    my ($self, $filename) = @_;

    my @auxcitekeys = $self->citekeys;
    
    my %bibentries = $self->bib;
    
    my @localkeys;

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

   $self->{bib} = { %bibentries } ;

   return @localkeys
}

1;
