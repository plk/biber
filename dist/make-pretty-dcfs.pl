#!/opt/local/bin/perl

use XML::LibXML;
use XML::LibXSLT;
use Carp;

my $xslt = XML::LibXSLT->new();

my $xml = $ARGV[0];
my $xsl = $ARGV[1];

croak "No XML file given" unless $xml;
croak "No XSL file given" unless $xsl;

croak "Can't find XML file" unless -e $xml;
croak "Can't find XSL file" unless -e $xsl;

my $style = XML::LibXML->load_xml( location => $xsl, no_cdata=>1 );
my $data = XML::LibXML->load_xml(location => $xml);
my $stylesheet = $xslt->parse_stylesheet($style);
my $out = $stylesheet->transform($data);
$stylesheet->output_file($out, $xml . '.html');

