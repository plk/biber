package Biber::Output::bibtex;
use v5.16;
use strict;
use warnings;
use base 'Biber::Output::base';

use Biber::Config;
use Biber::Constants;
use Biber::Utils;
use List::AllUtils qw( :all );
use Encode;
use IO::File;
use Log::Log4perl qw( :no_extra_logdie_message );
use Text::Wrap;
$Text::Wrap::columns = 80;
my $logger = Log::Log4perl::get_logger('main');

=encoding utf-8

=head1 NAME

Biber::Output::bibtex - class for bibtex output of tool mode

=cut


=head2 set_output_target_file

    Set the output target file of a Biber::Output::bbl object
    A convenience around set_output_target so we can keep track of the
    filename

=cut

sub set_output_target_file {
  my $self = shift;
  my $toolfile = shift;
  $self->{output_target_file} = $toolfile;
  my $enc_out;
  if (Biber::Config->getoption('output_encoding')) {
    $enc_out = ':encoding(' . Biber::Config->getoption('output_encoding') . ')';
  }
  my $TOOLFILE = IO::File->new($toolfile, ">$enc_out");
  $self->set_output_target($TOOLFILE);
}

=head2 set_output_entry

  Set the output for an entry

=cut

sub set_output_entry {
  my $self = shift;
  my $be = shift; # Biber::Entry object
  my $bee = $be->get_field('entrytype');
  my $section = shift; # Section object the entry occurs in
  my $dm = shift; # Data Model object
  my $acc = '';
  my $secnum = $section->number;
  my $key = $be->get_field('citekey');

  # Make the right casing function
  my $casing;
  given (Biber::Config->getoption('tool_fieldcase')) {
    when ('upper') {
      $casing = sub {uc(shift)};
    }
    when ('lower') {
      $casing = sub {lc(shift)};
    }
    when ('title') {
      $casing = sub {ucfirst(shift)};
    }
  }

  $acc .= '@';
  $acc .= $casing->($bee);
  $acc .=  "\{$key,\n";

  my $max_field_len;
  if (Biber::Config->getoption('tool_align')) {
    $max_field_len = max map {Unicode::GCString->new($_)->length} $be->rawfields;
  }

  foreach my $f ($be->rawfields) {
    # If IDS, CROSSREF and XDATA have been resolved, don't output them
    # We can't use the usual skipout test for fields not to be output
    # as this only refers to .bbl output and not to bibtex ouput since this
    # latter is not reall a "processed" output, it is supposed to be something
    # which could be again used as input and so we don't want to resolve/skip
    # fields like DATE etc.
    if (Biber::Config->getoption('tool_resolve')) {
      next if lc($f) ~~ ['ids', 'xdata', 'crossref'];
    }
    # Save post-mapping data for tool mode
    my $value = decode_utf8($be->get_rawfield($f));
    $acc .= ' ' x Biber::Config->getoption('tool_indent');
    $acc .= $casing->($f);
    $acc .= ' ' x ($max_field_len - Unicode::GCString->new($f)->length) if Biber::Config->getoption('tool_align');
    $acc .= ' = ';
    $acc .= "\{$value\},\n";
  }

  $acc .= "}\n\n";

  # If requested to convert UTF-8 to macros ...
  if (Biber::Config->getoption('output_safechars')) {
    $acc = latex_recode_output($acc);
  }

  # Create an index by keyname for easy retrieval
  $self->{output_data}{ENTRIES}{$secnum}{index}{$key} = \$acc;

  return;
}


=head2 output

    Tool output method

=cut

sub output {
  my $self = shift;
  my $data = $self->{output_data};
  my $target = $self->{output_target};
  my $target_string = "Target"; # Default
  if ($self->{output_target_file}) {
    $target_string = $self->{output_target_file};
  }

  # for debugging mainly
  unless ($target) {
    $target = new IO::File '>-';
  }

  $logger->debug('Preparing final output using class ' . __PACKAGE__ . '...');

  $logger->info("Writing '$target_string' with encoding '" . Biber::Config->getoption('output_encoding') . "'");
  $logger->info('Converting UTF-8 to TeX macros on output') if Biber::Config->getoption('output_safechars');

  out($target, $data->{HEAD});

  $logger->debug("Writing entries in tool mode");

  foreach my $key (@{$self->{output_data}{ENTRIES_ORDER}}) {
    # There is only a (pseudo) section "0" in tool mode
    out($target, ${$data->{ENTRIES}{0}{index}{$key}});
  }

  out($target, $data->{TAIL});

  $logger->info("Output to $target_string");
  close $target;
  return;
}

=head2 create_output_section

    Create the output from the sections data and push it into the
    output object.

=cut

sub create_output_section {
  my $self = shift;
  my $secnum = $Biber::MASTER->get_current_section;
  my $section = $Biber::MASTER->sections->get_section($secnum);

  # We rely on the order of this array for the order of the output
  foreach my $key ($section->get_orig_order_citekeys) {
    my $be = $section->bibentry($key);
    $self->set_output_entry($be, $section, Biber::Config->get_dm);

    # Preserve order as we won't sort later in tool mode and we need original bib order
    push @{$self->{output_data}{ENTRIES_ORDER}}, $key;
  }

  # Make sure the output object knows about the output section
  $self->set_output_section($secnum, $section);

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

Copyright 2009-2013 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
