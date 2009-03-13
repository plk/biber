package Biber::DBXML;
use strict;
use warnings;
use Carp;
use Sleepycat::DbXml 'simple';
use File::Basename;

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

