package Biber::Output::bibtex;
use v5.16;
use strict;
use warnings;
use base 'Biber::Output::base';

use Biber;
use Biber::Config;
use Biber::Constants;
use Biber::Utils;
use List::AllUtils qw( :all );
use Encode;
use IO::File;
use Log::Log4perl qw( :no_extra_logdie_message );
use Text::Wrap;
$Text::Wrap::columns = 80;
use Unicode::Normalize;
my $logger = Log::Log4perl::get_logger('main');

=encoding utf-8

=head1 NAME

Biber::Output::bibtex - class for bibtex output

=cut


=head2 set_output_target_file

    Set the output target file of a Biber::Output::bibtex object
    A convenience around set_output_target so we can keep track of the
    filename

=cut

sub set_output_target_file {
  my $self = shift;
  my $outfile = shift;
  $self->{output_target_file} = $outfile;
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
  my $mss = Biber::Config->getoption('mssplit');
  if (Biber::Config->getoption('output_fieldcase') eq 'upper') {
    $casing = sub {my $s = shift;
                   my @s = split(/$mss/, $s);
                   join($mss, uc(shift(@s)), @s)};
  }
  elsif (Biber::Config->getoption('output_fieldcase') eq 'lower') {
    $casing = sub {my $s = shift;
                   my @s = split(/$mss/, $s);
                   join($mss, lc(shift(@s)), @s)};
  }
  elsif (Biber::Config->getoption('output_fieldcase') eq 'title') {
    $casing = sub {my $s = shift;
                   my @s = split(/$mss/, $s);
                   join($mss, ucfirst(shift(@s)), @s)};
  }

  $acc .= '@';
  $acc .= $casing->($bee);
  $acc .=  "\{$key,\n";

  my $max_field_len;
  if (Biber::Config->getoption('output_align')) {
    $max_field_len = max map {Unicode::GCString->new($_)->length} $be->rawfields;
  }

  foreach my $f ($be->rawfields) {
    # If CROSSREF and XDATA have been resolved, don't output them
    # We can't use the usual skipout test for fields not to be output
    # as this only refers to .bbl output and not to bibtex output since this
    # latter is not really a "processed" output, it is supposed to be something
    # which could be again used as input and so we don't want to resolve/skip
    # fields like DATE etc.
    if (Biber::Config->getoption('output_resolve')) {
      next if first {lc($f) eq $_}  ('xdata', 'crossref');
    }

    my $value = $be->get_rawfield($f);
    $acc .= ' ' x Biber::Config->getoption('output_indent');
    $acc .= $casing->($f);
    $acc .= ' ' x ($max_field_len - Unicode::GCString->new($f)->length) if Biber::Config->getoption('output_align');
    $acc .= ' = ';

    # Don't wrap field which should be macros in braces
    my $mfs = Biber::Config->getoption('output_macro_fields');
    if (defined($mfs) and first {lc($f) eq $_} map {lc($_)} split(/\s*,\s*/, $mfs) ) {
      $acc .= "$value,\n";
    }
    else {
      $acc .= "\{$value\},\n";
    }
  }

  $acc .= "}\n\n";

  # If requested to convert UTF-8 to macros ...
  if (Biber::Config->getoption('output_safechars')) {
    $acc = latex_recode_output($acc);
  }
  else {             # ... or, check for encoding problems and force macros
    my $outenc = Biber::Config->getoption('output_encoding');
    if ($outenc ne 'UTF-8') {
      # Can this entry be represented in the output encoding?
      if (encode($outenc, NFC($acc)) =~ /\?/) { # Malformed data encoding char
        # So convert to macro
        $acc = latex_recode_output($acc);
        biber_warn("The entry '$key' has characters which cannot be encoded in '$outenc'. Recoding problematic characters into macros.");
      }
    }
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

  my $target_string = "Target"; # Default
  if ($self->{output_target_file}) {
    $target_string = $self->{output_target_file};
  }

  # Instantiate output file now that input is read in case we want to do in-place
  # output for tool mode
  my $enc_out;
  if (Biber::Config->getoption('output_encoding')) {
    $enc_out = ':encoding(' . Biber::Config->getoption('output_encoding') . ')';
  }
  my $target = IO::File->new($target_string, ">$enc_out");

  # for debugging mainly
  unless ($target) {
    $target = new IO::File '>-';
  }

  $logger->debug('Preparing final output using class ' . __PACKAGE__ . '...');

  $logger->info("Writing '$target_string' with encoding '" . Biber::Config->getoption('output_encoding') . "'");
  $logger->info('Converting UTF-8 to TeX macros on output') if Biber::Config->getoption('output_safechars');

  out($target, $data->{HEAD});

  $logger->debug("Writing entries in bibtex format");

  # Bibtex output uses just one special section, always sorted by global sorting spec
  foreach my $key ($Biber::MASTER->sortlists->get_list(99999, Biber::Config->getblxoption('sortscheme'), 'entry', Biber::Config->getblxoption('sortscheme'))->get_keys) {
    out($target, ${$data->{ENTRIES}{99999}{index}{$key}});
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


  # We rely on the order of this array for the order of the .bbl
  foreach my $k ($section->get_citekeys) {
    # Regular entry
    my $be = $section->bibentry($k) or biber_error("Cannot find entry with key '$k' to output");
    $self->set_output_entry($be, $section, Biber::Config->get_dm);
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

Please report any bugs or feature requests on our Github tracker at
L<https://github.com/plk/biber/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2015 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
