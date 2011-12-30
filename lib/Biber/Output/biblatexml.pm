package Biber::Output::biblatexml;
use 5.014000;
use strict;
use warnings;
use base 'Biber::Output::base';

use Biber::Config;
use Biber::Constants;
use Biber::Entry;
use Biber::Utils;
use XML::Writer;
use XML::Writer::String;
use List::AllUtils qw( :all );
use IO::File;
use Log::Log4perl qw( :no_extra_logdie_message );
my $logger = Log::Log4perl::get_logger('main');
my $bp = 'http://biblatex-biber.sourceforge.net/biblatexml';

=encoding utf-8

=head1 NAME

  Biber::Output::biblatexml - class for Biber output of .bltxml
  This is slighty odd output format as it's asctually an input format
  so we are essentially reverse engineering the internal data model.
  The point of this format is to help in the migration to BibLaTeXML
  eventually.

=cut

=head2 new

    Initialize a Biber::Output::biblatexml object

=cut

sub new {
  my $class = shift;
  my $obj = shift;
  my $self = $class->SUPER::new($obj);

  my $xml = XML::Writer->new(OUTPUT => XML::Writer::String->new(),
                             DATA_MODE => 1,
                             DATA_INDENT => 2,
                             NAMESPACES => 1,
                             PREFIX_MAP => {$bp => 'bib'});
  $xml->xmlDecl();
  $self->{output_data} = $xml;
  return $self;
}


=head2 set_output_target_file

    Set the output target file of a Biber::Output::biblatexml object
    A convenience around set_output_target so we can keep track of the
    filename

=cut

sub set_output_target_file {
  my $self = shift;
  my $bltxmlfile = shift;
  $self->{output_target_file} = $bltxmlfile;
  my $enc_out;
  $enc_out = ':encoding(UTF-8)';
  my $BLTXMLFILE = IO::File->new($bltxmlfile, ">$enc_out");
  $self->set_output_target($BLTXMLFILE);
}


=head2 set_output_entry

  Set the XML output for an entry. Empty stub.

=cut

sub set_output_entry {
  return;
}

=head2 create_output_section

    Create the output from the sections data and push it into the
    output object.

=cut

sub create_output_section {
  return;
}



=head2 output

    BibLaTeXML output method

=cut

sub output {
  my $self = shift;
  my $biber = $Biber::MASTER;
  my $data = $self->{output_data};
  my $target = $self->{output_target};
  my $target_string = "Target"; # Default
  my $struc = Biber::Config->get_structure;
  my $xml = $self->{output_data};
  if ($self->{output_target_file}) {
    $target_string = $self->{output_target_file};
  }

  # for debugging mainly
  unless ($target) {
    $target = new IO::File '>-';
  }

  $logger->debug('Preparing final output using class ' . __PACKAGE__ . '...');
  $logger->info("Writing '$target_string' with encoding 'UTF-8'");

  $xml->startTag([$bp, 'entries']);

  # Loop over sections.
  foreach my $section (@{$biber->sections->get_sections}) {

    # Loop over entries
ENTRIES:    foreach my $be ($section->bibentries->entries) {
      my $citekey = $be->get_field('citekey');

      $xml->startTag([$bp, 'entry'], 'id' => $citekey, 'entrytype' => $be->get_field('entrytype'));

      # entry options
      if (my $options = $be->get_field('rawoptions')) {
        $xml->startTag([$bp, 'options']);
        my @entryoptions = split /\s*,\s*/, $options;
        foreach (@entryoptions) {
          m/^([^=]+)(=?)(.+)?$/;
          my $val;
          if ($2) {
            given ($3) {
              when ('true') {
                $val = 1;
              }
              when ('false') {
                $val = 0;
              }
              default {
                $val = $3;
              }
            }
            $xml->emptyTag('option', 'key' => $1, 'value' => $3);
          }
          else {
            $xml->emptyTag('option', 'key' => $1, 'value' => 1);
          }
        }
        $xml->endTag([$bp, 'options']);
      }

      # Citekey aliases
      foreach my $alias ($section->get_citekey_aliases) {
        my $realkey = $section->get_citekey_alias($alias);
        if ($realkey eq $citekey) {
          $xml->dataElement([$bp, 'id'], $alias);
        }
      }

      # Generate set information
      if ( $be->get_field('entrytype') eq 'set' ) { # Set parents get \set entry ...
        $xml->startTag([$bp, 'entryset']);
        my @entryset = split /\s*,\s*/, $be->get_field('entryset');
        foreach (@entryset) {
          $xml->dataElement([$bp, 'item'], $_);
        }
        $xml->endTag([$bp, 'entryset']);
        $xml->endTag([$bp, 'entry']);
        next ENTRIES; # to avoid putting the crossrefe'd stuff in
      }

      # Output name fields
      foreach my $namefield (@{$struc->get_field_type('name')}) {
        if ( my $nf = $be->get_field($namefield) ) {

          # Did we have "and others" in the data?
          if ( $nf->get_morenames ) {
            $xml->startTag([$bp, $namefield], 'morenames' => 1);
          }
          else {
            $xml->startTag([$bp, $namefield]);
          }

          foreach my $n (@{$nf->names}) {
            $n->name_to_bltxml($xml, $bp);
          }
          $xml->endTag([$bp, $namefield]);
        }
      }

      # Output list fields
      foreach my $listfield (@{$struc->get_field_type('list')}) {
        if (my $lf = $be->get_field($listfield)) {
          if ( lc($be->get_field($listfield)->[-1]) eq 'others' ) {
            $xml->startTag([$bp, $listfield], 'morelist' => 1);
            pop @$lf;           # remove the last element in the array
          }
          else {
            $xml->startTag([$bp, $listfield]);
          }
          foreach my $f (@$lf) {
            $xml->dataElement([$bp, 'item'], $f);
          }
          $xml->endTag([$bp, $listfield]);
        }
      }

      # Output literal fields
      foreach my $lfield (@{$struc->get_field_type('literal')}) {
        if (my $lf = $be->get_field($lfield)) {
          $xml->dataElement([$bp, $lfield], $lf);
        }
      }

      # Output date fields
      foreach my $dp (('', 'event', 'orig', 'url')) {
        if (my $date = $be->get_orig_field($dp . 'date')) {
          $dp ? $xml->startTag([$bp, 'date'], 'datetype' => $dp) : $xml->startTag([$bp, 'date']);
          if ($date =~ m|\A([^\/]+)/(.+)?\z|) {
            $xml->dataElement([$bp, 'start'], $1);
            $xml->dataElement([$bp, 'end'], $2) if $2;
          }
          else {
            $xml->characters($date);
          }
          $xml->endTag([$bp, 'date']);
        }
      }

      # Range fields
      foreach my $rfield (@{$struc->get_field_type('range')}) {
        if (my $rf = $be->get_field($rfield)) {
          $xml->startTag([$bp, $rfield]);
          # range fields are an array ref of two-element array refs [range_start, range_end]
          # range_end can be be empty for open-ended range or undef
          $xml->startTag([$bp, 'list']);
          foreach my $f (@$rf) {
            $xml->startTag([$bp, 'item']);
            $xml->dataElement([$bp, 'start'], $f->[0]);
            $xml->dataElement([$bp, 'end'], $f->[1]);
            $xml->endTag([$bp, 'item']);
          }
          $xml->endTag([$bp, 'list']);
          $xml->endTag([$bp, $rfield]);
        }
      }

      # Verbatim fields
      foreach my $vfield (@{$struc->get_field_type('verbatim')}) {
        if (my $vf = $be->get_field($vfield)) {
          $xml->dataElement([$bp, $vfield], $vf);
        }
      }

      # csv fields
      foreach my $csvfield (@{$struc->get_field_type('csv')}) {
        if (my $csvf = $be->get_field($csvfield)) {
          $xml->startTag([$bp, $csvfield]);
          my @f = split /\s*,\s*/, $csvf;
          foreach (@f) {
            $xml->dataElement([$bp, 'item'], $_);
          }
          $xml->endTag([$bp, $csvfield]);
        }
      }
      $xml->endTag([$bp, 'entry']);
    }
  }
  $xml->endTag([$bp, 'entries']);
  $xml->end();

  print $target $xml->getOutput->value();

  $logger->info("Output to $target_string");
  close $target;
  return;
}

1;

__END__

=head1 AUTHORS

François Charette, C<< <firmicus at ankabut.net> >>
Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2012 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
