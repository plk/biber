package Biber::DBXML;
use strict;
use warnings;
use Carp;
use Cwd;
use Sleepycat::DbXml 'simple';
use File::Basename;
use Log::Log4perl qw(:no_extra_logdie_message);
my $logger = Log::Log4perl::get_logger('main');

sub dbxml_to_xml {
  my ($self, $dbxmlfile) = @_;
  my @auxcitekeys = $self->citekeys;
  my $mgr = new XmlManager() or croak;
  my $collname = basename($dbxmlfile);
  my $xmlstring = <<ENDXML
<?xml version="1.0" encoding="UTF-8"?>
<bib:entries xmlns:bib="http://biblatex-biber.sourceforge.net/biblatexml"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
ENDXML
    ;
  eval {
    my $workingdir = getcwd;
    chdir( dirname($dbxmlfile) ) or $logger->logcroak("Cannot chdir: $!");
    my $cont = $mgr->openContainer("$collname");
    my $context = $mgr->createQueryContext();
    $context->setNamespace("bib", "http://biblatex-biber.sourceforge.net/biblatexml");
    foreach my $key (@auxcitekeys) {
      $logger->debug("Querying dbxml for key $key");
      my $query = 'collection("' . $collname . '")//bib:entry[@id="' . $key . '"]';
      my $results = $mgr->query($query, $context);
      my $ressize = $results->size;
      if ($ressize > 1) {
        $logger->warn("Found $ressize entries for key $key!");
      };
      my $xmlvalue = new XmlValue;
      while ($results->next($xmlvalue)) {
        $xmlstring .= $xmlvalue->asString() . "\n    \n";
        last;
      };
      ## now we add the crossref key to the citekeys, if present:
      my $queryx = 'collection("' . $collname . '")//bib:entry[@id="' . $key .
        '"]/bib:crossref/string()';
      my $resultsx = $mgr->query($queryx, $context);
      if ($resultsx->size > 0) {
        my $xmlvaluex = new XmlValue;
        while ($resultsx->next($xmlvaluex)) {
          my $xkey = $xmlvaluex->asString();
          $logger->debug("Adding crossref key $xkey to the stack");

          #FIXME take also care of entryset keys!
          push @auxcitekeys, $xkey;
          last
        }
      }
    }

    chdir( $workingdir );

    };
  if (my $e = catch std::exception) {
    $logger->logwarn("Query failed\n", $e->what() );
    exit ( -1 )
  }
  elsif ($@) {
    $logger->logwarn("Query failed\n", $@ );
    exit( -1 );
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

=pod

=encoding utf-8

=head1 NAME

Biber::DBXML - query entries in a Berkeley DBXML database for further processing by biber

=head1 SYNOPSIS

my $xmlstring = $biber->dbxml_to_xml("biblatex.dbxml");

=head1 FUNCTIONS

=head2 dbxml_to_xml

=head1 AUTHOR

François Charette, C<< <firmicus at gmx.net> >>

=head1 BUGS

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2010 François Charette, all rights reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

=cut

# vim: set tabstop=2 shiftwidth=2 expandtab:
