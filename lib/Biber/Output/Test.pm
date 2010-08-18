package Biber::Output::Test;
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

Biber::Output::Test - Output class for loopback testing
Essentially, this outputs to a string so we can look at it internally in tests

=cut


=head2 _printfield

  Add the .bbl for a text field to the output accumulator.

=cut

sub _printfield {
  my ($self, $field, $str) = @_;
  if (Biber::Config->getoption('wraplines')) {
    ## 12 is the length of '  \field{}{}'
    if ( 12 + length($field) + length($str) > 2*$Text::Wrap::columns ) {
      return "    \\field{$field}{%\n" . wrap('  ', '  ', $str) . "%\n  }\n";
    }
    elsif ( 12 + length($field) + length($str) > $Text::Wrap::columns ) {
      return wrap('    ', '    ', "\\field{$field}{$str}" ) . "\n";
    }
    else {
      return "    \\field{$field}{$str}\n";
    }
  }
  else {
    return "    \\field{$field}{$str}\n";
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
  my $section = shift ; # Section the entry occurs in
  my $acc = '';
  my $opts    = '';
  my $citecasekey; # entry key forced to case of any citations(s) which reference it
  if ( $be->get_field('citecasekey') ) {
    $citecasekey = $be->get_field('citecasekey');
  }

  if ( is_def_and_notnull($be->get_field('options')) ) {
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

  foreach my $namefield (@NAMEFIELDS) {
    next if $SKIPFIELDS{$namefield};
    if ( my $nf = $be->get_field($namefield) ) {
      if ( $nf->last_element->get_namestring eq 'others' ) {
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

  foreach my $listfield (@LISTFIELDS) {
    next if $SKIPFIELDS{$listfield};
    if ( is_def_and_notnull($be->get_field($listfield)) ) {
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
  $acc .= "    \\field{sortinit}{" . $be->get_field('sortinit') . "}\n";

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
    if ($be->get_field('shorthand')) {
      $acc .= "    \\field{labelnumber}{"
        . $be->get_field('shorthand') . "}\n";
    }
    elsif ($be->get_field('labelnumber')) {
      $acc .= "    \\field{labelnumber}{"
        . $be->get_field('labelnumber') . "}\n";
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

  foreach my $ifield (@DATECOMPONENTFIELDS) {
    next if $SKIPFIELDS{$ifield};
    # Here we do want to output if the field is null as this means something
    # for example in open-ended ranges
    if ( $be->field_exists($ifield) ) {
      $acc .= $self->_printfield( $ifield, $be->get_field($ifield) );
    }
  }

  foreach my $lfield (@LITERALFIELDS) {
    next if $SKIPFIELDS{$lfield};
    if ( is_def_and_notnull($be->get_field($lfield)) ) {
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

      my $lfieldprint = $lfield;
      if ($lfield eq 'journal') {
        $lfieldprint = 'journaltitle'
      };
      $acc .= $self->_printfield( $lfieldprint, $be->get_field($lfield) );
    }
  }

  # this is currently "pages" only
  foreach my $rfield (@RANGEFIELDS) {
    next if $SKIPFIELDS{$rfield};
    if ( is_def_and_notnull($be->get_field($rfield)) ) {
      my $rf = $be->get_field($rfield);
      $rf =~ s/[-–]+/\\bibrangedash /g;
      $acc .= "    \\field{$rfield}{$rf}\n";
    }
  }

  foreach my $vfield (@VERBATIMFIELDS) {
    next if $SKIPFIELDS{$vfield};
    if ( is_def_and_notnull($be->get_field($vfield)) ) {
      my $rf = $be->get_field($vfield);
      $acc .= "    \\verb{$vfield}\n";
      $acc .= "    \\verb $rf\n    \\endverb\n";
    }
  }
  if ( is_def_and_notnull($be->get_field('keywords')) ) {
    $acc .= "    \\keyw{" . $be->get_field('keywords') . "}\n";
  }

  # Append any warnings to the entry, if any
  if ($be->get_field('warnings')) {
    foreach my $warning (@{$be->get_field('warnings')}) {
      $acc .= "    \\warn{\\item $warning}\n";
    }
  }

  $acc .= "  \\endentry\n\n";

  # Use an array to preserve sort order of entries already generated
  # Also create an index by keyname for easy retrieval
  push @{$self->{output_data}{ENTRIES}{$section}{strings}}, \$acc;
  $self->{output_data}{ENTRIES}{$section}{index}{lc($citecasekey)} = \$acc;

  return;
}



=head2 output

    BBL output method - this takes care to output entries in the explicit order
    derived from the virtual order of the auxcitekeys after sortkey sorting.

=cut

sub output {
  my $self = shift;
  my $data = $self->{output_data};
  my $target = $self->{output_target};

  $logger->info("Writing output with encoding '" . Biber::Config->getoption('inputenc') . "'");

  foreach my $secnum (sort keys %{$data->{ENTRIES}}) {
    foreach my $entry (@{$data->{ENTRIES}{$secnum}{strings}}) {
      print $target $$entry;
    }
  }

  close $target;
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

