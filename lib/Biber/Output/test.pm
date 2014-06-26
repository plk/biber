package Biber::Output::test;
use v5.16;
use strict;
use warnings;
use base 'Biber::Output::base';

use Biber::Config;
use Biber::Constants;
use Biber::Entry;
use Biber::Utils;
use IO::File;
use Log::Log4perl qw( :no_extra_logdie_message );
my $logger = Log::Log4perl::get_logger('main');
use Unicode::Normalize;

=encoding utf-8

=head1 NAME

Biber::Output::test - Output class for loopback testing
Essentially, this outputs to a string so we can look at it internally in tests

=cut


=head2 _printfield

  Add the .bbl for a text field to the output accumulator.

=cut

sub _printfield {
  my ($be, $field, $str) = @_;
  my $field_type = 'field';
  # crossref and xref are of type 'strng' in the .bbl
  if (lc($field) eq 'crossref' or
      lc($field) eq 'xref') {
    $field_type = 'strng';
  }

  # auto-escase TeX special chars if:
  # * The entry is not a bibtex entry (no auto-escaping for bibtex data)
  # * It's not a strng field
  if ($field_type ne 'strng' and $be->get_field('datatype') ne 'bibtex') {
    $str =~ s/(?<!\\)(\#|\&|\%)/\\$1/gxms;
    $str =~ s/\A[\n\s]+//xms;
    $str =~ s/[\n\s]+\z//xms;
  }

  if (Biber::Config->getoption('wraplines')) {
    ## 16 is the length of '      \field{}{}'
    if ( 16 + Unicode::GCString->new($field)->length + Unicode::GCString->new($str)->length > 2*$Text::Wrap::columns ) {
      return "      \\${field_type}{$field}{%\n" . wrap('      ', '      ', $str) . "%\n      }\n";
    }
    elsif ( 16 + Unicode::GCString->new($field)->length + Unicode::GCString->new($str)->length > $Text::Wrap::columns ) {
      return wrap('      ', '      ', "\\${field_type}{$field}{$str}" ) . "\n";
    }
    else {
      return "      \\${field_type}{$field}{$str}\n";
    }
  }
  else {
    return "      \\${field_type}{$field}{$str}\n";
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
  my $bee = $be->get_field('entrytype');
  my $section = shift; # Section the entry occurs in
  my $dm = shift; # Structure object
  my $acc = '';
  my $secnum = $section->number;

  my $key = $be->get_field('citekey');

  $acc .= "% sortstring = " . $be->get_field('sortstring') . "\n"
    if (Biber::Config->getoption('debug') || Biber::Config->getblxoption('debug'));

  $acc .= "    \\entry{$key}{$bee}{" . join(',', @{filter_entry_options($be->get_field('options'))}) . "}\n";

  # Generate set information
  if ( $be->get_field('entrytype') eq 'set' ) {   # Set parents get \set entry ...
    $acc .= "      \\set{" . join(',', @{$be->get_field('entryset')}) . "}\n";
  }
  else { # Everything else that isn't a set parent ...
    if (my $es = $be->get_field('entryset')) { # ... gets a \inset if it's a set member
      $acc .= "      \\inset{" . join(',', @$es) . "}\n";
    }
  }

  # Output name fields

  # first output copy in labelname
  # This is essentially doing the same thing twice but in the future,
  # labelname may have different things attached than the raw name
  my $lni = $be->get_labelname_info;
  my $name_others_deleted = '';
  my $plo; # per-list options

  if (my $ln = $be->get_field('labelname')) {
    my @plo;

    # Add uniquelist, if defined
    if (my $ul = $ln->get_uniquelist){
      push @plo, "uniquelist=$ul";
    }
    $plo =join(',', @plo);

    # Did we have "and others" in the data?
    if ( $ln->get_morenames ) {
      $acc .= "      \\true{morelabelname}\n";
    }

    my $total = $ln->count_names;
    $acc .= "      \\name{labelname}{$total}{$plo}{%\n";
    foreach my $n (@{$ln->names}) {
      $acc .= $n->name_to_bbl;
    }
    $acc .= "      }\n";
  }

  # then names themselves
  foreach my $namefield (@{$dm->get_fields_of_type('list', 'name')}) {
    next if $dm->field_is_skipout($namefield);
    if ( my $nf = $be->get_field($namefield) ) {

      # Did we have "and others" in the data?
      if ( $nf->get_morenames ) {
        $acc .= "      \\true{more$namefield}\n";
      }

      my $total = $nf->count_names;
      # Copy perl-list options to the actual labelname too
      $plo = '' unless (defined($lni) and $namefield eq $lni->{field});
      $acc .= "      \\name{$namefield}{$total}{}{%\n";
      foreach my $n (@{$nf->names}) {
        $acc .= $n->name_to_bbl;
      }
      $acc .= "      }\n";
    }
  }

  foreach my $listfield (@{$dm->get_fields_of_fieldtype('list')}) {
    next if $dm->field_is_datatype('name', $listfield); # name is a special list
    if ( my $lf = $be->get_field($listfield) ) {
      if ( lc($be->get_field($listfield)->[-1]) eq Biber::Config->getoption('others_string') ) {
        $acc .= "      \\true{more$listfield}\n";
        pop @$lf; # remove the last element in the array
      };
      my $total = $#$lf + 1;
      $acc .= "      \\list{$listfield}{$total}{%\n";
      foreach my $f (@$lf) {
        $acc .= "        {$f}%\n";
      }
      $acc .= "      }\n";
    }
  }

  my $namehash = $be->get_field('namehash');
  $acc .= "      \\strng{namehash}{$namehash}\n" if $namehash;
  my $fullhash = $be->get_field('fullhash');
  $acc .= "      \\strng{fullhash}{$fullhash}\n" if $fullhash;

  if ( Biber::Config->getblxoption('labelalpha', $be->get_field('entrytype')) ) {
    # Might not have been set due to skiplab/dataonly
    if (my $label = $be->get_field('labelalpha')) {
      $acc .= "      \\field{labelalpha}{$label}\n";
    }
  }

  # This is special, we have to put a marker for sortinit{hash} and then replace this string
  # on output as it can vary between lists
  $acc .= "      <BDS>SORTINIT</BDS>\n";
  $acc .= "      <BDS>SORTINITHASH</BDS>\n";

  # The labeldate option determines whether "extrayear" is output
  # Skip generating extrayear for entries with "skiplab" set
  if ( Biber::Config->getblxoption('labeldate', $be->get_field('entrytype'))) {
    # Might not have been set due to skiplab/dataonly
    if (my $ey = $be->get_field('extrayear')) {
      my $nameyear_extra = $be->get_field('nameyear_extra');
      if ( Biber::Config->get_seen_nameyear_extra($nameyear_extra) > 1) {
        $acc .= "      <BDS>EXTRAYEAR</BDS>\n";
      }
    }
    if (my $ly = $be->get_field('labelyear')) {
      $acc .= "      \\field{labelyear}{$ly}\n";
    }
    if (my $lm = $be->get_field('labelmonth')) {
      $acc .= "      \\field{labelmonth}{$lm}\n";
    }
    if (my $ld = $be->get_field('labelday')) {
      $acc .= "      \\field{labelday}{$ld}\n";
    }
    if ($be->field_exists('datelabelsource')) {
      $acc .= "      \\field{datelabelsource}{" . $be->get_field('datelabelsource') .  "}\n";
    }
  }

  # The labeltitle option determines whether "extratitle" is output
  if ( Biber::Config->getblxoption('labeltitle', $bee)) {
    # Might not have been set due to skiplab/dataonly
    if (my $nametitle = $be->get_field('nametitle')) {
      if ( Biber::Config->get_seen_nametitle($nametitle) > 1) {
        $acc .= "      <BDS>EXTRATITLE</BDS>\n";
      }
    }
  }

  # The labeltitleyear option determines whether "extratitleyear" is output
  if ( Biber::Config->getblxoption('labeltitleyear', $bee)) {
    # Might not have been set due to skiplab/dataonly
    if (my $titleyear = $be->get_field('titleyear')) {
      if ( Biber::Config->get_seen_titleyear($titleyear) > 1) {
        $acc .= "      <BDS>EXTRATITLEYEAR</BDS>\n";
      }
    }
  }

  # labeltitle is always output
  if (my $lt = $be->get_field('labeltitle')) {
    $acc .= "      \\field{labeltitle}{$lt}\n";
  }

  # The labelalpha option determines whether "extraalpha" is output
  # Skip generating extraalpha for entries with "skiplab" set
  if ( Biber::Config->getblxoption('labelalpha', $be->get_field('entrytype'))) {
    # Might not have been set due to skiplab/dataonly
    if (my $ea = $be->get_field('extraalpha')) {
      my $nameyear_extra = $be->get_field('nameyear_extra');
      if ( Biber::Config->get_seen_nameyear_extra($nameyear_extra) > 1) {
        $acc .= "      <BDS>EXTRAALPHA</BDS>\n";
      }
    }
  }

  if ( Biber::Config->getblxoption('labelnumber', $be->get_field('entrytype')) ) {
    if (my $sh = $be->get_field('shorthand')) {
      $acc .= "      \\field{labelnumber}{$sh}\n";
    }
    elsif (my $ln = $be->get_field('labelnumber')) {
      $acc .= "      \\field{labelnumber}{$ln}\n";
    }
  }

  if (defined($be->get_field('singletitle'))) {
    $acc .= "      \\true{singletitle}\n";
  }

  foreach my $field (sort @{$dm->get_fields_of_type('field', 'entrykey')},
                          @{$dm->get_fields_of_type('field', 'key')},
                          @{$dm->get_fields_of_type('field', 'integer')},
                          @{$dm->get_fields_of_type('field', 'datepart')},
                          @{$dm->get_fields_of_type('field', 'literal')},
                          @{$dm->get_fields_of_type('field', 'code')}) {
    next if $dm->field_is_skipout($field);
    next if $dm->get_fieldformat($field) eq 'xsv';
    if ( ($dm->field_is_nullok($field) and
          $be->field_exists($field)) or
         $be->get_field($field) ) {
      # we skip outputting the crossref or xref when the parent is not cited
      # (biblatex manual, section 2.2.3)
      # sets are a special case so always output crossref/xref for them since their
      # children will always be in the .bbl otherwise they make no sense.
      unless ( $be->get_field('entrytype') eq 'set') {
        next if ($field eq 'crossref' and
                 not $section->has_citekey($be->get_field('crossref')));
        next if ($field eq 'xref' and
                 not $section->has_citekey($be->get_field('xref')));
      }

      $acc .= _printfield($be, $field, $be->get_field($field) );
    }
  }

  foreach my $field (sort @{$dm->get_fields_of_fieldformat('xsv')}) {
    next if $dm->field_is_skipout($field);
    next if $dm->get_datatype($field) eq 'keyword';# This is special in .bbl
    if (my $f = $be->get_field($field)) {
      $acc .= _printfield($be, $field, join(',', @$f) );
    }
  }

  foreach my $rfield (@{$dm->get_fields_of_datatype('range')}) {
    if ( my $rf = $be->get_field($rfield)) {
      $rf =~ s/[-–]+/\\bibrangedash /g;
      $acc .= "      \\field{$rfield}{$rf}\n";
    }
  }

  foreach my $vfield ((@{$dm->get_fields_of_datatype('verbatim')},
                       @{$dm->get_fields_of_datatype('uri')})) {
    if ( my $rf = $be->get_field($vfield) ) {
      $acc .= "      \\verb{$vfield}\n";
      $acc .= "      \\verb $rf\n    \\endverb\n";
    }
  }
  if ( my $k = $be->get_field('keywords') ) {
    $acc .= "      \\keyw{$k}\n";
  }

  # Append any warnings to the entry, if any
  if (my $w = $be->get_field('warnings')) {
    foreach my $warning (@$w) {
      $acc .= "      \\warn{\\item $warning}\n";
    }
  }

  $acc .= "    \\endentry\n";

  # Create an index by keyname for easy retrieval
  $self->{output_data}{ENTRIES}{$secnum}{index}{$key} = \$acc;
  return;
}


=head2 create_output_misc

    Create the output for misc bits and pieces like preamble and closing
    macro call and add to output object.

=cut

sub create_output_misc {
  my $self = shift;

  if (my $pa = $Biber::MASTER->get_preamble) {
    $pa = join("%\n", @$pa);
    # Decode UTF-8 -> LaTeX macros if asked to
    if (Biber::Config->getoption('output_safechars')) {
      $pa = Biber::LaTeX::Recode::latex_encode($pa);
    }
    $self->{output_data}{HEAD} .= "\\preamble{%\n$pa%\n}\n\n";
  }
  $self->{output_data}{TAIL} .= "\\endinput\n\n";
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

  $logger->info("Writing output with encoding '" . Biber::Config->getoption('output_encoding') . "'");
  $logger->info('Converting UTF-8 to TeX macros on output to .bbl') if Biber::Config->getoption('output_safechars');

  foreach my $secnum (sort keys %{$data->{ENTRIES}}) {
    my $section = $self->get_output_section($secnum);
    foreach my $list (sort {$a->get_sortschemename cmp $b->get_sortschemename} @{$Biber::MASTER->sortlists->get_lists_for_section($secnum)}) {
      next unless $list->count_keys; # skip empty lists
      my $listssn = $list->get_sortschemename;
      my $listtype = $list->get_type;
      my $listname = $list->get_name;
      foreach my $k ($list->get_keys) {
        if ($listtype eq 'entry') {
          my $entry = $data->{ENTRIES}{$secnum}{index}{$k};

          # Instantiate any dynamic, list specific entry information
          my $entry_string = $list->instantiate_entry($entry, $k);

          # If requested to convert UTF-8 to macros ...
          if (Biber::Config->getoption('output_safechars')) {
            $entry_string = latex_recode_output($entry_string);
          }
          out($target, $entry_string);
        }
        elsif ($listtype eq 'shorthand') {
          next if Biber::Config->getblxoption('skipbiblist', $section->bibentry($k), $k);
          out($target, $k);
        }
      }
    }
  }
  close $target;
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

Copyright 2009-2014 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
