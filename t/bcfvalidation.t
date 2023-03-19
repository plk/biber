# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 53;
use XML::LibXML;
use Biber;
chdir('t');

# Validate all .bcfs used in tests

# Set up schema
my $CFxmlschema = XML::LibXML::RelaxNG->new(location => '../data/schemata/bcf.rng');

foreach my $bcf (<tdata/*.bcf>) {
# Set up XML parser
  my $CFxmlparser = XML::LibXML->new();

  # basic parse and XInclude processing
  my $CFxp = $CFxmlparser->parse_file($bcf);

  # XPath context
  my $CFxpc = XML::LibXML::XPathContext->new($CFxp);
  $CFxpc->registerNs('bcf', 'https://sourceforge.net/projects/biblatex');

  # Validate against schema. Dies if it fails.
  $CFxmlschema->validate($CFxp);
  is($@, '', "Validation of $bcf");
}
