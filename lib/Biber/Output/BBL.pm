package Biber::Output::BBL;
use base 'Biber::Output::Base';

use Biber::Config;
use Biber::Constants;
use Biber::Entry;
use Biber::Utils;
use IO::File;
use Log::Log4perl qw( :no_extra_logdie_message );
my $logger = Log::Log4perl::get_logger('main');

=encoding utf-8

=head1 NAME

Biber::Output::BBL - class for Biber output of .bbl

=cut

=head2 new

    Initialize a Biber::Output::BBL object

=cut

sub new {
  my $class = shift;
  my $self = $class->SUPER::new($obj);
  my $ctrlver = Biber::Config->getblxoption('controlversion');
  my $beta = $Biber::BETA_VERSION ? '(beta)' : '';

  my $BBLHEAD = <<EOF;
% \$ biblatex auxiliary file \$
% \$ biblatex version $ctrlver \$
% \$ biber version $Biber::VERSION $beta\$
% Do not modify the above lines!
%
% This is an auxiliary file used by the 'biblatex' package.
% This file may safely be deleted. It will be recreated by
% biber or bibtex as required.
%
\\begingroup
\\makeatletter
\\\@ifundefined{ver\@biblatex.sty}
  {\\\@latex\@error
     {Missing 'biblatex' package}
     {The bibliography requires the 'biblatex' package.}
      \\aftergroup\\endinput}
  {}
\\endgroup

EOF

  $self->set_output_head($BBLHEAD);
  return $self;
}

=head2 set_output_target_file

    Set the output target file of a Biber::Output::BBL object
    A convenience around set_output_target so we can keep track of the
    filename

=cut

sub set_output_target_file {
  my $self = shift;
  my $bblfile = shift;
  $self->{output_target_file} = $bblfile;
  my $enc_out;
  if (Biber::Config->getoption('bblencoding')) {
    $enc_out = ':encoding(' . Biber::Config->getoption('bblencoding') . ')';
  }
  my $BBLFILE = IO::File->new($bblfile, ">$enc_out") or $logger->croak("Failed to open $bblfile : $!");
  $self->set_output_target($BBLFILE);
}

=head2 _printfield

  Add the .bbl for a text field to the output accumulator.

=cut

sub _printfield {
  my ($self, $field, $str) = @_;
  my $field_type = 'field';
  # crossref and xref are of type 'strng' in the .bbl
  if (lc($field) eq 'crossref' or
      lc($field) eq 'xref') {
    $field_type = 'strng';
  }
  if (Biber::Config->getoption('wraplines')) {
    ## 12 is the length of '  \field{}{}' or '  \strng{}{}'
    if ( 12 + length($field) + length($str) > 2*$Text::Wrap::columns ) {
      return "    \\${field_type}{$field}{%\n" . wrap('  ', '  ', $str) . "%\n  }\n";
    }
    elsif ( 12 + length($field) + length($str) > $Text::Wrap::columns ) {
      return wrap('    ', '    ', "\\${field_type}{$field}{$str}" ) . "\n";
    }
    else {
      return "    \\${field_type}{$field}{$str}\n";
    }
  }
  else {
    return "    \\${field_type}{$field}{$str}\n";
  }
  return;
}

=head2 set_output_entry

  Set the .bbl output for an entry. This is the meat of
  the .bbl output

=cut

sub set_output_entry {
  my $self = shift;
  my $be = shift; # Biber::Entry object
  my $section = shift; # Section object the entry occurs in
  my $struc = shift; # Structure object
  my $acc = '';
  my $opts = '';
  my $citecasekey; # entry key forced to case of any citations(s) which reference it
  my $secnum = $section->number;

  if ( $be->get_field('citecasekey') ) {
    $citecasekey = $be->get_field('citecasekey');
  }

  if ($be->get_field('options')) {
    $opts = $be->get_field('options');
  }

  $acc .= "% sortstring = " . $be->get_field('sortstring') . "\n"
    if (Biber::Config->getoption('debug') || Biber::Config->getblxoption('debug'));

  $acc .= "  \\entry{$citecasekey}{" . $be->get_field('entrytype') . "}{$opts}\n";

  # Generate set information
  if ( $be->get_field('entrytype') eq 'set' ) {   # Set parents get \set entry ...
    $acc .= "    \\set{" . $be->get_field('entryset') . "}\n";
  }
  else { # Everything else that isn't a set parent ...
    if (my $es = $be->get_field('entryset')) { # ... gets a \inset if it's a set member
      $acc .= "    \\inset{$es}\n";
    }
  }

  # Output name fields

  # first output copy in labelname
  # This is essentially doing the same thing twice but in the future,
  # labelname will have different things attached than the raw name
  my $lnn = $be->get_field('labelnamename'); # save name of labelname field
  my $name_others_deleted = '';
  if (my $ln = $be->get_field('labelname')) {
    if ( $ln->last_element->get_namestring eq 'others' ) {
      $acc .= "    \\true{morelabelname}\n";
      $ln->del_last_element;
      # record that we have deleted "others" from labelname field
      # we will need this below
      $name_others_deleted = $lnn;
    }
    my $total = $ln->count_elements;
    $acc .= "    \\name{labelname}{$total}{%\n";
    foreach my $n (@{$ln->names}) {
      $acc .= $n->name_to_bbl;
    }
    $acc .= "    }\n";
  }

  # then names themselves
  foreach my $namefield (@{$struc->get_field_type('name')}) {
    if ( my $nf = $be->get_field($namefield) ) {
      # If this name is labelname, we've already deleted the "others"
      # so just add the boolean
      if ($name_others_deleted eq $namefield) {
        $acc .= "    \\true{more$namefield}\n";
      }
      # otherwise delete and add the boolean
      elsif ($nf->last_element->get_namestring eq 'others') {
        $acc .= "    \\true{more$namefield}\n";
        $nf->del_last_element;
      }
      my $total = $nf->count_elements;
      $acc .= "    \\name{$namefield}{$total}{%\n";
      foreach my $n (@{$nf->names}) {
        $acc .= $n->name_to_bbl;
      }
      $acc .= "    }\n";
    }
  }

  # Output list fields
  foreach my $listfield (@{$struc->get_field_type('list')}) {
    if ($be->get_field($listfield)) {
      my @lf = @{ $be->get_field($listfield) };
      if ( $be->get_field($listfield)->[-1] eq 'others' ) {
        $acc .= "    \\true{more$listfield}\n";
        pop @lf; # remove the last element in the array
      };
      my $total = $#lf + 1;
      $acc .= "    \\list{$listfield}{$total}{%\n";
      foreach my $f (@lf) {
        $acc .= "      {$f}%\n";
      }
      $acc .= "    }\n";
    }
  }

  my $namehash = $be->get_field('namehash');
  $acc .= "    \\strng{namehash}{$namehash}\n";
  my $fullhash = $be->get_field('fullhash');
  $acc .= "    \\strng{fullhash}{$fullhash}\n";

  if ( Biber::Config->getblxoption('labelalpha', $be->get_field('entrytype')) ) {
    # Might not have been set due to skiplab/dataonly
    if (my $label = $be->get_field('labelalpha')) {
      $acc .= "    \\field{labelalpha}{$label}\n";
    }
  }

  # Skip sortinit if it's undefined from being skipped due to encoding issues
  if ($be->field_exists('sortinit')) {
    $acc .= "    \\field{sortinit}{" . $be->get_field('sortinit') . "}\n";
  }

  # The labelyear option determines whether "extrayear" is output
  # Skip generating extrayear for entries with "skiplab" set
  if ( Biber::Config->getblxoption('labelyear', $be->get_field('entrytype'))) {
    # Might not have been set due to skiplab/dataonly
    if (my $ey = $be->get_field('extrayear')) {
      my $nameyear = $be->get_field('nameyear');
      if ( Biber::Config->get_seennameyear($nameyear) > 1) {
        $acc .= "    \\field{extrayear}{$ey}\n";
      }
    }
    if (my $ly = $be->get_field('labelyear')) {
      $acc .= "    \\field{labelyear}{$ly}\n";
    }
  }

  # The labelalpha option determines whether "extraalpha" is output
  # Skip generating extraalpha for entries with "skiplab" set
  if ( Biber::Config->getblxoption('labelalpha', $be->get_field('entrytype'))) {
    # Might not have been set due to skiplab/dataonly
    if (my $ea = $be->get_field('extraalpha')) {
      my $nameyear = $be->get_field('nameyear');
      if ( Biber::Config->get_seennameyear($nameyear) > 1) {
        $acc .= "    \\field{extraalpha}{$ea}\n";
      }
    }
  }

  if ( Biber::Config->getblxoption('labelnumber', $be->get_field('entrytype')) ) {
    if (my $sh = $be->get_field('shorthand')) {
      $acc .= "    \\field{labelnumber}{$sh}\n";
    }
    elsif (my $lnum = $be->get_field('labelnumber')) {
      $acc .= "    \\field{labelnumber}{$lnum}\n";
    }
  }

  if (my $unopt = Biber::Config->getblxoption('uniquename', $be->get_field('entrytype'))) {
    my $lname = $be->get_field('labelnamename');
    my $name;
    my $lastname;
    my $nameinitstr;
    my $un;

    if ($lname) {
      $name = $be->get_field($lname)->nth_element(1);
      $lastname = $name->get_lastname;
      $nameinitstr = $name->get_nameinitstring;
    }
    # uniquename is requested but there is no labelname or there are more than two names in
    # labelname
    if ($be->get_field('ignoreuniquename')) {
      $un = '0';
    }
    # If there is one entry (hash) for the lastname, then it's unique
    elsif (Biber::Config->get_numofuniquenames($lastname) == 1 ) {
      $un = '0';
    }
    # Otherwise, if there is one entry (hash) for the lastname plus initials,
    # the it needs the initials to make it unique
    elsif (Biber::Config->get_numofuniquenames($nameinitstr) == 1 ) {
      $un = '1';
    }
    # Otherwise the name needs to be full to make it unique
    # but restricted to uniquename biblatex option value just in case
    # this is inits only (1);
    else {
      $un = $unopt;
    }
    $acc .= "    \\count{uniquename}{$un}\n";
  }

  if ( Biber::Config->getblxoption('singletitle', $be->get_field('entrytype'))
    and Biber::Config->get_seennamehash($be->get_field('fullhash')) < 2 )
  {
    $acc .= "    \\true{singletitle}\n";
  }

  foreach my $lfield (@{$struc->get_field_type('literal')}) {
    next if $struc->is_field_type('skipout', $lfield);
    if ( ($struc->is_field_type('nullok', $lfield) and
          $be->field_exists($lfield)) or
         $be->get_field($lfield) ) {
      # we skip outputting the crossref or xref when the parent is not cited
      # (biblatex manual, section 2.23)
      # sets are a special case so always output crossref/xref for them since their
      # children will always be in the .bbl otherwise they make no sense.
      unless ( $be->get_field('entrytype') eq 'set') {
        next if ($lfield eq 'crossref' and
                 not $section->has_citekey($be->get_field('crossref')));
        next if ($lfield eq 'xref' and
                 not $section->has_citekey($be->get_field('xref')));
      }
      $acc .= $self->_printfield( $lfield, $be->get_field($lfield) );
    }
  }

  foreach my $rfield (@{$struc->get_field_type('range')}) {
    if ( $rf = $be->get_field($rfield) ) {
      $rf =~ s/[-–]+/\\bibrangedash /g;
      $acc .= "    \\field{$rfield}{$rf}\n";
    }
  }

  foreach my $vfield (@{$struc->get_field_type('verbatim')}) {
    if ( my $rf = $be->get_field($vfield) ) {
      $acc .= "    \\verb{$vfield}\n";
      $acc .= "    \\verb $rf\n    \\endverb\n";
    }
  }
  if ( $be->get_field('keywords') ) {
    $acc .= "    \\keyw{" . $be->get_field('keywords') . "}\n";
  }

  # Append any warnings to the entry, if any
  if ( my $w = $be->get_field('warnings')) {
    foreach my $warning (@$w) {
      $acc .= "    \\warn{\\item $warning}\n";
    }
  }

  $acc .= "  \\endentry\n\n";

  # Use an array to preserve sort order of entries already generated
  # Also create an index by keyname for easy retrieval
  push @{$self->{output_data}{ENTRIES}{$secnum}{strings}}, \$acc;
  $self->{output_data}{ENTRIES}{$secnum}{index}{lc($citecasekey)} = \$acc;

  return;
}

=head2 set_los

    Set the output list of shorthands for a section

=cut

sub set_los {
  my $self = shift;
  my $shs = shift;
  my $section = shift;
  $self->{output_data}{LOS}{$section} = $shs;
  return;
}

=head2 get_los

    Get the output list of shorthands for a section as an array

=cut

sub get_los {
  my $self = shift;
  my $section = shift;
  return @{$self->{output_data}{LOS}{$section}}
}



=head2 get_output_entry

    Get the output data for a specific entry

=cut

sub get_output_entry {
  my $self = shift;
  my $key = shift;
  my $section = shift;
  $section = '0' if not defined($section); # default - mainly for tests

  return ${$self->{output_data}{ENTRIES}{$section}{index}{lc($key)}};
}

=head2 get_output_entries

    Get the output data for a all entries in an array ref

=cut

sub get_output_entries {
  my $self = shift;
  my $section = shift;
  return [ map {$$_} @{$self->{output_data}{ENTRIES}{$section}{strings}} ];
}


=head2 output

    BBL output method - this takes care to output entries in the explicit order
    derived from the virtual order of the citekeys after sortkey sorting.

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

  $logger->info("Writing '$target_string' with encoding '" . Biber::Config->getoption('bblencoding') . "'");

  print $target $data->{HEAD} or $logger->logcroak("Failure to write head to $target_string: $!");

  foreach my $secnum (sort keys %{$data->{ENTRIES}}) {
    print $target "\n\\refsection{$secnum}\n";
    foreach my $entry (@{$data->{ENTRIES}{$secnum}{strings}}) {
      print $target $$entry or $logger->logcroak("Failure to write entry to $target_string: $!");
    }

    # Output section list of shorthands if there is one
    if ( my $sec_los = $data->{LOS}{$secnum} ) {
      print $target "  \\lossort\n";
      foreach my $sh (@$sec_los) {
        print $target "    \\key{$sh}\n";
      }
      print $target "  \\endlossort\n\n";
    }

    print $target "\\endrefsection\n"
  }

  print $target $data->{TAIL} or $logger->logcroak("Failure to write tail to $target_string: $!");

  $logger->info("Output to $target_string");
  close $target or $logger->logcroak("Failure to close $target_string: $!");
  return;
}


=head1 AUTHORS

François Charette, C<< <firmicus at gmx.net> >>
Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2010 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

1;

# vim: set tabstop=2 shiftwidth=2 expandtab:

