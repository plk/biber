use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 1;
use XML::LibXML;
use Biber;
chdir('t');
# Set up XML parser
my $CFxmlparser = XML::LibXML->new();

# Set up schema
my $CFxmlschema = XML::LibXML::RelaxNG->new(location => '../data/schemata/bcf.rng');

# basic parse and XInclude processing
my $CFxp = $CFxmlparser->parse_file('tdata/style-authoryear.bcf');

# XPath context
my $CFxpc = XML::LibXML::XPathContext->new($CFxp);
$CFxpc->registerNs('bcf', 'https://sourceforge.net/projects/biblatex');

# Validate against schema. Dies if it fails.
$CFxmlschema->validate($CFxp);
is($@, '', 'Validation of bcf');
