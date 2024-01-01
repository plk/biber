package Biber::Output::base;
use v5.24;
use strict;
use warnings;

use Biber::Entry;
use Biber::Utils;
use Encode;
use IO::File;
use Text::Wrap;
$Text::Wrap::columns = 80;
use Log::Log4perl qw( :no_extra_logdie_message );
use Unicode::Normalize;
my $logger = Log::Log4perl::get_logger('main');

=encoding utf-8

=head1 NAME

Biber::Output::base - base class for Biber output modules.

=cut

=head2 new

    Initialize a Biber::Output::base object

=cut

sub new {
  my $class = shift;
  my $obj = shift;
  my $self;
  if (defined($obj) and ref($obj) eq 'HASH') {
    $self = bless $obj, $class;
  }
  else {
    $self = bless {}, $class;
  }

  $self->{output_data}{HEAD} = '';
  $self->{output_data}{TAIL} = '';

  return $self;
}

=head2 set_output_target_file

    Set the output target file of a Biber::Output::base object
    A convenience around set_output_target so we can keep track of the
    filename. Returns an IO::File object for the target

=cut

sub set_output_target_file {
  my ($self, $file, $init) = @_;

  $self->{output_target_file} = $file;
  my $enc_out;
  if (my $enc = Biber::Config->getoption('output_encoding')) {
    $enc_out = ":encoding($enc)";
  }
  return IO::File->new($file, ">$enc_out");
}

=head2 get_output_target_file

  Get the output target file name

=cut

sub get_output_target_file {
  my $self = shift;
  return $self->{output_target_file};
}

=head2 set_output_target

    Set the output target of a Biber::Output::base object

=cut

sub set_output_target {
  my $self = shift;
  my $target = shift;
  $self->{output_target} = $target;
  return;
}

=head2 set_output_head

    Set the output head of a Biber::Output::base object
    $data could be anything - the caller is expected to know.

=cut

sub set_output_head {
  my $self = shift;
  my $data = shift;
  $self->{output_data}{HEAD} = $data;
  return;
}

=head2 set_output_tail

    Set the output tail of a Biber::Output::base object
    $data could be anything - the caller is expected to know.

=cut

sub set_output_tail {
  my $self = shift;
  my $data = shift;
  $self->{output_data}{TAIL} = $data;
  return;
}


=head2 get_output_head

    Get the output head of a Biber::Output object
    $data could be anything - the caller is expected to know.
    Mainly used in debugging

=cut

sub get_output_head {
  my $self = shift;
  return $self->{output_data}{HEAD};
}

=head2 get_output_tail

    Get the output tail of a Biber::Output object
    $data could be anything - the caller is expected to know.
    Mainly used in debugging

=cut

sub get_output_tail {
  my $self = shift;
  return $self->{output_data}{TAIL};
}


=head2 add_output_head

    Add to the head output data of a Biber::Output::base object
    The base class method just does a string append

=cut

sub add_output_head {
  my $self = shift;
  my $data = shift;
  $self->{output_data}{HEAD} .= $data;
  return;
}

=head2 add_output_tail

    Add to the tail output data of a Biber::Output::base object
    The base class method just does a string append

=cut

sub add_output_tail {
  my $self = shift;
  my $data = shift;
  $self->{output_data}{TAIL} .= $data;
  return;
}


=head2 set_output_section

  Records the section object in the output object
  We need some information from this when writing the output

=cut

sub set_output_section {
  my $self = shift;
  my $secnum = shift;
  my $section = shift;
  $self->{section}{$secnum} = $section;
  return;
}

=head2 get_output_section

  Retrieve the output section object

=cut

sub get_output_section {
  my $self = shift;
  my $secnum = shift;
  return $self->{section}{$secnum};
}


=head2 get_output_entries

    Get the sorted order output data for all entries in a list as array ref
    Used really only in tests as it instantiates list dynamic information so
    we can see it in tests. As a result, we have to NFC() the result to mimic
    real output since UTF-8 output is assumed in most tests.

=cut

sub get_output_entries {
  my $self = shift;
  my $section = shift;
  my $list = shift;
  return [ map {$self->{output_data}{ENTRIES}{$section}{index}{$_} ||
                $self->{output_data}{MISSING_ENTRIES}{$section}{index}{$_} ||
                $self->{output_data}{ALIAS_ENTRIES}{$section}{index}{$_}} $list->get_keys->@*];
}


=head2 get_output_macros

    Get the output macros for tool mode tests

=cut

sub get_output_macros {
  my $self = shift;
  return [sort $self->{output_data}{MACROS}->@*];
}

=head2 get_output_comments

    Get the output comments for tool mode tests

=cut

sub get_output_comments {
  my $self = shift;
  return [sort $self->{output_data}{COMMENTS}->@*];
}

=head2 clear_output_macros

    Clear the output macros

=cut

sub clear_output_macros {
  my $self = shift;
  delete $self->{output_data}{MACROS};
}

=head2 clear_output_comments

    Clear the output comments

=cut

sub clear_output_comments {
  my $self = shift;
  delete $self->{output_data}{COMMENTS};
}

=head2 get_output_entry

    Get the output data for a specific entry.
    Used really only in tests as it instantiates list dynamic information so
    we can see it in tests. As a result, we have to NFC() the result to mimic
    real output since UTF-8 output is assumed in most tests.

=cut

sub get_output_entry {
  my ($self, $key, $list, $secnum) = @_;

  # defaults - mainly for tests
  if (not defined($secnum)) {
    if (Biber::Config->getoption('tool') or
        Biber::Config->getoption('output_format') eq 'bibtex') {
      $secnum = 99999;
    }
    else {
      $secnum = 0;
    }
  }

  my $section = $self->get_output_section($secnum);

  # Force a return of undef if there is no output for this key to avoid
  # dereferencing errors in tests
  my $out = $self->{output_data}{ENTRIES}{$secnum}{index}{$key} ||
            $self->{output_data}{MISSING_ENTRIES}{$secnum}{index}{$key} ||
            $self->{output_data}{ALIAS_ENTRIES}{$secnum}{index}{$key};
  my $out_string = $list ? $list->instantiate_entry($section, $out, $key) : $out;

  # If requested to convert UTF-8 to macros ...
  if (Biber::Config->getoption('output_safechars')) {
    $out_string = latex_recode_output($out_string);
  }
  else { # ... or, check for encoding problems and force macros
    my $outenc = Biber::Config->getoption('output_encoding');
    if ($outenc ne 'UTF-8') {
      # Can this entry be represented in the output encoding?
      if (encode($outenc, NFC($out_string)) =~ /\?/) { # Malformed data encoding char
        # So convert to macro
        $out_string = latex_recode_output($out_string);
        biber_warn("The entry '$key' has characters which cannot be encoded in '$outenc'. Recoding problematic characters into macros.");
      }
    }
  }

  # Sometimes $out_string might still be a scalar ref (tool mode, for example which doesn't use
  # sort lists)
  return $out ? (ref($out_string) eq 'SCALAR' ? NFC($$out_string) : NFC($out_string)) : undef;
}

=head2 set_output_entry

    Add an entry output to a Biber::Output::base object
    The base class method just does a dump

=cut

sub set_output_entry {
  my $self = shift;
  my $entry = shift;
  my $secnum = shift;
  my $struc = shift;
  $self->{output_data}{ENTRIES}{$secnum}{index}{$entry->get_field('citekey')} = $entry->dump;
  return;
}


=head2 create_output_misc

    Create the output for misc bits and pieces like preamble and closing
    macro call and add to output object.

=cut

sub create_output_misc {
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

  # We rely on the order of this array for the order of the ouput
  foreach my $k ($section->get_citekeys) {
    # Regular entry
    my $be = $section->bibentry($k) or biber_error("Cannot find entry with key '$k' to output");
    $self->set_output_entry($be, $section, Biber::Config->get_dm);
  }

  # Make sure the output object knows about the output section
  $self->set_output_section($secnum, $section);

  # undef citekeys are global to a section
  # Missing citekeys
  foreach my $k ($section->get_undef_citekeys) {
    $self->set_output_undefkey($k, $section);
  }

  # alias citekeys are global to a section
  foreach my $k ($section->get_citekey_aliases) {
    my $realkey = $section->get_citekey_alias($k);
    $self->set_output_keyalias($k, $realkey, $section)
  }

  return;
}


=head2 set_output_keyalias

  Set the output for a key which is an alias to another key

=cut

sub set_output_keyalias {
  return;
}


=head2 set_output_undefkey

  Set the output for an undefined key

=cut

sub set_output_undefkey {
  return;
}

=head2 output

    Generic base output method

=cut

sub output {
  my $self = shift;
  my $data = $self->{output_data};
  my $target = $self->{output_target};
  my $target_string = "Target"; # Default
  if ($self->{output_target_file}) {
    $target_string = $self->{output_target_file};
  }

  if ($logger->is_debug()) {# performance tune
    $logger->debug('Preparing final output using class ' . __PACKAGE__ . '...');
  }

  $logger->info("Writing '$target_string' with encoding '" . Biber::Config->getoption('output_encoding') . "'");

  out($target, $data->{HEAD});

  foreach my $secnum (sort keys $data->{ENTRIES}->%*) {
    out($target, "SECTION: $secnum\n\n");
    my $section = $self->get_output_section($secnum);
    foreach my $list ($section->get_lists->@*) {
      my $listlabel = $list->get_label;
      my $listtype = $list->get_type;
      out($target, "  LIST: $listlabel\n\n");
      foreach my $k ($list->get_keys->@*) {
        my $entry_string = $data->{ENTRIES}{$secnum}{index}{$k};
        out($target, $entry_string);
      }
    }
  }

  out($target, $data->{TAIL});

  $logger->info("Output to $target_string");
  close $target;
  return;
}

1;

__END__

=head1 AUTHORS

Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our Github tracker at
L<https://github.com/plk/biber/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2012 François Charette and Philip Kime, all rights reserved.
Copyright 2012-2024 Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
