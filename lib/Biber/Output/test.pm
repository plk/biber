package Biber::Output::test;
use v5.16;
use strict;
use warnings;
use parent 'Biber::Output::base';

use Biber::Config;
use Biber::Constants;
use Biber::Entry;
use Biber::Utils;
use IO::File;
use Log::Log4perl qw( :no_extra_logdie_message );
use Unicode::GCString;
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
  my ($be, $field) = @_;
  my $acc;
  my $key = $be->get_field_nv('citekey');

  # crossref and xref are of type 'strng' in the .bbl
  if (lc($field) eq 'crossref' or lc($field) eq 'xref') {
    my $f = $be->get_field_nv($field);
    if (Biber::Config->getoption('wraplines')) {
      ## 16 is the length of '      \strng{}{}'
      if ( 16 + Unicode::GCString->new($field)->length + Unicode::GCString->new($f)->length > 2*$Text::Wrap::columns ) {
        $acc .= "      \\strng{$field}{%\n" . wrap('      ', '      ', $f) . "%\n      }\n";
      }
      elsif ( 16 + Unicode::GCString->new($field)->length + Unicode::GCString->new($f)->length > $Text::Wrap::columns ) {
        $acc .= wrap('      ', '      ', "\\strng{$field}{$f}" ) . "\n";
      }
      else {
        $acc .= "      \\strng{$field}{$f}\n";
      }
    }
    else {
      $acc .= "      \\strng{$field}{$f}\n";
    }
  }
  else {
    my $dm = Biber::Config->get_dm;
    if ($dm->field_is_variant_enabled($field)) {
      foreach my $form ($be->get_field_form_names($field)) {
        foreach my $lang ($be->get_field_form_lang_names($field, $form)) {
          my $f = $be->get_field($field, $form, $lang);

          # auto-escape TeX special chars if:
          # * The entry is not a BibTeX entry (no auto-escaping for BibTeX data)
          # * It's not a \\strng field
          if ($be->get_field_nv('datatype') ne 'bibtex') {
            $f =~ s/(?<!\\)(\#|\&|\%)/\\$1/gxms;
          }

          if (Biber::Config->getoption('wraplines')) {
            # 18 is the length of '      \field[]{}{}'
            if ( 18 + Unicode::GCString->new($form)->length + Unicode::GCString->new($lang)->length + length($field) + Unicode::GCString->new($f)->length > 2*$Text::Wrap::columns ) {
              $acc .= "      \\field[form=$form,lang=$lang]{$field}{%\n" . wrap('      ', '      ', $f) . "%\n      }\n";
            }
            elsif ( 18 + Unicode::GCString->new($form)->length + Unicode::GCString->new($lang)->length + Unicode::GCString->new($field)->length + Unicode::GCString->new($f)->length > $Text::Wrap::columns ) {
              $acc .= wrap('      ', '      ', "\\field[form=$form,lang=$lang]{$field}{$f}" ) . "\n";
            }
            else {
              $acc .= "      \\field[form=$form,lang=$lang]{$field}{$f}\n";
            }
          }
          else {
            $acc .= "      \\field[form=$form,lang=$lang]{$field}{$f}\n";
          }
        }
      }
    }
    else {
      my $f = $be->get_field_nv($field);

      # xSV fields are not strings yet
      if ($dm->get_fieldformat($field) eq 'xsv') {
        $f = join(',', @$f);
      }

      # auto-escape TeX special chars if:
      # * The entry is not a BibTeX entry (no auto-escaping for BibTeX data)
      # * It's not a \\strng field
      if ($be->get_field_nv('datatype') ne 'bibtex') {
        $f =~ s/(?<!\\)(\#|\&|\%)/\\$1/gxms;
      }

      if (Biber::Config->getoption('wraplines')) {
        # 16 is the length of '      \field{}{}'
        if ( 16 + length($field) + Unicode::GCString->new($f)->length > 2*$Text::Wrap::columns ) {
          $acc .= "      \\field{$field}{%\n" . wrap('      ', '      ', $f) . "%\n      }\n";
        }
        elsif ( 16 + Unicode::GCString->new($field)->length + Unicode::GCString->new($f)->length > $Text::Wrap::columns ) {
          $acc .= wrap('      ', '      ', "\\field{$field}{$f}" ) . "\n";
        }
        else {
          $acc .= "      \\field{$field}{$f}\n";
        }
      }
      else {
        $acc .= "      \\field{$field}{$f}\n";
      }
    }
  }
  return $acc;
}


=head2 set_output_entry

  Set the .bbl output for an entry. This is the meat of
  the .bbl output

=cut

sub set_output_entry {
  my $self = shift;
  my $be = shift; # Biber::Entry object
  my $bee = $be->get_field_nv('entrytype');
  my $section = shift; # Section object the entry occurs in
  my $dm = shift; # Data Model object
  my $acc = '';
  my $secnum = $section->number;
  my $key = $be->get_field_nv('citekey');

  # Skip entrytypes we don't want to output according to datamodel
  return if $dm->entrytype_is_skipout($bee);

  $acc .= "    \\entry{$key}{$bee}{" . join(',', @{filter_entry_options($be->get_field_nv('options'))}) . "}\n";

  # Generate set information
  if ( $bee eq 'set' ) {   # Set parents get \set entry ...
    $acc .= "      \\set{" . join(',', @{$be->get_field_nv('entryset')}) . "}\n";
  }
  else { # Everything else that isn't a set parent ...
    if (my $es = $be->get_field_nv('entryset')) { # ... gets a \inset if it's a set member
      $acc .= "      \\inset{" . join(',', @$es) . "}\n";
    }
  }

  # Output name fields
  foreach my $namefield (@{$dm->get_fields_of_type('list', 'name')}) {
    next if $dm->field_is_skipout($namefield);
    # Names are not necessarily variant enabled - for example, if a style
    # defines a custom name field which isn't. This is guaranteed only in the
    # default biblatex datamodel
    if ($dm->field_is_variant_enabled($namefield)) {

      # Did we have "and others" in the data?
      # Don't need a per-form/lang more<name> field
      if ( $be->field_exists($namefield) and
           $be->get_field_any_variant($namefield)->get_morenames ) {
        $acc .= "      \\true{more$namefield}\n";
      }

      # loop over all name forms and langs
      foreach my $form ($be->get_field_form_names($namefield)) {
        foreach my $lang ($be->get_field_form_lang_names($namefield, $form)) {
          if (my $nf = $be->get_field($namefield, $form, $lang)) {

            my $plo = '';

            my $total = $nf->count_names;

            # Add per-list options, if any
            my $lni = $be->get_labelname_info;
            if (defined($lni) and
                $lni eq $namefield) {
              # Add uniquelist, if defined
              my @plo;
              if (my $ul = $nf->get_uniquelist) {
                push @plo, "uniquelist=$ul";
              }
              $plo = join(',', @plo);
            }

            $acc .= "      \\name[form=$form,lang=$lang]{$namefield}{$total}{$plo}{%\n";
            foreach my $n (@{$nf->names}) {
              $acc .= $n->name_to_bbl;
            }
            $acc .= "      }\n";
          }
        }
      }
    }
    else {
      if (my $nf = $be->get_field_nv($namefield)) {
        # Did we have "and others" in the data?
        # Don't need a per-form/lang more<name> field
        if ($nf->get_morenames) {
          $acc .= "      \\true{more$namefield}\n";
        }

        my $plo = '';

        my $total = $nf->count_names;

        # Add per-list options, if any
        my $lni = $be->get_labelname_info;
        if (defined($lni) and
            $lni eq $namefield) {
          # Add uniquelist, if defined
          my @plo;
          if (my $ul = $nf->get_uniquelist) {
            push @plo, "uniquelist=$ul";
          }
          $plo = join(',', @plo);
        }

        $acc .= "      \\name{$namefield}{$total}{$plo}{%\n";
        foreach my $n (@{$nf->names}) {
          $acc .= $n->name_to_bbl;
        }
        $acc .= "      }\n";
      }
    }
  }

  # Output list fields
  foreach my $listfield (@{$dm->get_fields_of_fieldtype('list')}) {
    next if $dm->field_is_datatype('name', $listfield); # name is a special list
    next if $dm->field_is_datatype('verbatim', $listfield); # special lists
    next if $dm->field_is_datatype('uri', $listfield); # special lists
    next if $dm->field_is_skipout($listfield);

    if ($dm->field_is_variant_enabled($listfield)) {
    # Don't need a per-form/lang more<list> field
      if (my $lf = $be->get_field_any_variant($listfield)) {
        if (lc($lf->[-1]) eq Biber::Config->getoption('others_string')) {
          $acc .= "      \\true{more$listfield}\n";
        }
      }

      # loop over all list forms and langs
      foreach my $form ($be->get_field_form_names($listfield)) {
        foreach my $lang ($be->get_field_form_lang_names($listfield, $form)) {
          if (my $lf = $be->get_field($listfield, $form, $lang)) {
            if ( lc($lf->[-1]) eq Biber::Config->getoption('others_string') ) {
              pop @$lf;         # remove the last element in the array
            }
            my $total = $#$lf + 1;

            $acc .= "      \\list[form=$form,lang=$lang]{$listfield}{$total}{%\n";
            foreach my $f (@$lf) {
              $acc .= "        {$f}%\n";
            }
            $acc .= "      }\n";
          }
        }
      }
    }
    else {
      # Don't need a per-form/lang more<list> field
      if (my $lf = $be->get_field_nv($listfield)) {
        if (lc($lf->[-1]) eq Biber::Config->getoption('others_string')) {
          $acc .= "      \\true{more$listfield}\n";
        }

        if ( lc($lf->[-1]) eq Biber::Config->getoption('others_string') ) {
          pop @$lf;             # remove the last element in the array
        }
        my $total = $#$lf + 1;

        $acc .= "      \\list{$listfield}{$total}{%\n";
        foreach my $f (@$lf) {
          $acc .= "        {$f}%\n";
        }
        $acc .= "      }\n";
      }
    }
  }

  my $namehash = $be->get_field_nv('namehash');
  $acc .= "      \\strng{namehash}{$namehash}\n" if $namehash;
  my $fullhash = $be->get_field_nv('fullhash');
  $acc .= "      \\strng{fullhash}{$fullhash}\n" if $fullhash;

  if ( Biber::Config->getblxoption('labelalpha', $bee) ) {
    # Might not have been set due to skiplab/dataonly
    if (my $label = $be->get_field_nv('labelalpha')) {
      $acc .= "      \\field{labelalpha}{$label}\n";
    }
  }

  # This is special, we have to put a marker for sortinit{hash} and then replace this string
  # on output as it can vary between lists
  $acc .= "      <BDS>SORTINIT</BDS>\n";
  $acc .= "      <BDS>SORTINITHASH</BDS>\n";

  # The labeldate option determines whether "extrayear" is output
  if ( Biber::Config->getblxoption('labeldate', $bee)) {
    # Might not have been set due to skiplab/dataonly
    if (my $nameyear = $be->get_field_nv('nameyear')) {
      if (Biber::Config->get_seen_nameyear($nameyear) > 1) {
        $acc .= "      <BDS>EXTRAYEAR</BDS>\n";
      }
    }
    if (my $ly = $be->get_field_nv('labelyear')) {
      $acc .= "      \\field{labelyear}{$ly}\n";
    }
    if (my $lm = $be->get_field_nv('labelmonth')) {
      $acc .= "      \\field{labelmonth}{$lm}\n";
    }
    if (my $ld = $be->get_field_nv('labelday')) {
      $acc .= "      \\field{labelday}{$ld}\n";
    }
    if ($be->field_exists('datelabelsource')) {
      $acc .= "      \\field{datelabelsource}{" . $be->get_field_nv('datelabelsource') .  "}\n";
    }
  }

  # The labeltitle option determines whether "extratitle" is output
  if ( Biber::Config->getblxoption('labeltitle', $bee)) {
    # Might not have been set due to skiplab/dataonly
    if (my $nametitle = $be->get_field_nv('nametitle')) {
      if ( Biber::Config->get_seen_nametitle($nametitle) > 1) {
        $acc .= "      <BDS>EXTRATITLE</BDS>\n";
      }
    }
  }

  # The labeltitleyear option determines whether "extratitleyear" is output
  if ( Biber::Config->getblxoption('labeltitleyear', $bee)) {
    # Might not have been set due to skiplab/dataonly
    if (my $titleyear = $be->get_field_nv('titleyear')) {
      if ( Biber::Config->get_seen_titleyear($titleyear) > 1) {
        $acc .= "      <BDS>EXTRATITLEYEAR</BDS>\n";
      }
    }
  }

  # The labelalpha option determines whether "extraalpha" is output
  if ( Biber::Config->getblxoption('labelalpha', $bee)) {
    # Might not have been set due to skiplab/dataonly
    if (my $la = $be->get_field_nv('labelalpha')) {
      if (Biber::Config->get_la_disambiguation($la) > 1) {
        $acc .= "      <BDS>EXTRAALPHA</BDS>\n";
      }
    }
  }

  if ( Biber::Config->getblxoption('labelnumber', $bee) ) {
    if (my $sh = $be->get_field_nv('shorthand')) {
      $acc .= "      \\field{labelnumber}{$sh}\n";
    }
    elsif (my $lnum = $be->get_field_nv('labelnumber')) {
      $acc .= "      \\field{labelnumber}{$lnum}\n";
    }
  }

  if (defined($be->get_field_nv('singletitle'))) {
    $acc .= "      \\true{singletitle}\n";
  }

  # The source field for labelname
  if (my $lni = $be->get_labelname_info) {
    $acc .= "      \\field{labelnamesource}{$lni}\n";
  }

  # The source field for labeltitle
  if (my $lti = $be->get_labeltitle_info) {
    $acc .= "      \\field{labeltitlesource}{$lti}\n";
  }

  if (my $ck = $be->get_field_nv('clonesourcekey')) {
    $acc .= "      \\field{clonesourcekey}{$ck}\n";
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
         ($dm->field_is_variant_enabled($field) and
          $be->get_field_variants($field)) or
          $be->get_field_nv($field)) {
      # We skip outputting the crossref or xref when the parent is not cited.
      # Sets are a special case so always output crossref/xref for them since their
      # children will always be in the .bbl otherwise they make no sense.
      unless ($bee eq 'set') {
        next if ($field eq 'crossref' and
                 not $section->has_citekey($be->get_field_nv('crossref')));
        next if ($field eq 'xref' and
                 not $section->has_citekey($be->get_field_nv('xref')));
      }
      $acc .= _printfield($be, $field);
    }
  }

  foreach my $field (sort @{$dm->get_fields_of_fieldformat('xsv')}) {
    next if $dm->field_is_skipout($field);
    next if $dm->get_datatype($field) eq 'keyword';# This is special in .bbl
    if (my $f = $be->get_field_nv($field)) {
      $acc .= _printfield($be, $field, join(',', @$f) );
    }
  }

  foreach my $rfield (@{$dm->get_fields_of_datatype('range')}) {
    next if $dm->field_is_skipout($rfield);
    if ( my $rf = $be->get_field_nv($rfield) ) {
      # range fields are an array ref of two-element array refs [range_start, range_end]
      # range_end can be be empty for open-ended range or undef
      my @pr;
      foreach my $f (@$rf) {
        if (defined($f->[1])) {
          push @pr, $f->[0] . '\bibrangedash' . ($f->[1] ? ' ' . $f->[1] : '');
        }
        else {
          push @pr, $f->[0];
        }
      }
      my $bbl_rf = join('\bibrangessep ', @pr);
      $acc .= "      \\field{$rfield}{$bbl_rf}\n";
      $acc .= "      \\range{$rfield}{" . rangelen($rf) . "}\n";
    }
  }

  # verbatim fields
  foreach my $vfield ((@{$dm->get_fields_of_type('field', 'verbatim')},
                       @{$dm->get_fields_of_type('field', 'uri')})) {
    next if $dm->field_is_skipout($vfield);
    if ( my $vf = $be->get_field_nv($vfield) ) {
      $acc .= "      \\verb{$vfield}\n";
      $acc .= "      \\verb $vf\n      \\endverb\n";
    }
  }
  # verbatim lists
  foreach my $vlist ((@{$dm->get_fields_of_type('list', 'verbatim')},
                      @{$dm->get_fields_of_type('list', 'uri')})) {
    next if $dm->field_is_skipout($vlist);
    if ( my $vlf = $be->get_field_nv($vlist) ) {
      if ( lc($vlf->[-1]) eq Biber::Config->getoption('others_string') ) {
        $acc .= "      \\true{more$vlist}\n";
        pop @$vlf; # remove the last element in the array
      }
      my $total = $#$vlf + 1;
      $acc .= "      \\lverb{$vlist}{$total}\n";
      foreach my $f (@$vlf) {
        $acc .= "      \\lverb $f\n";
      }
      $acc .= "      \\endlverb\n";
    }
  }

  if ( my $k = $be->get_field_nv('keywords') ) {
    $k = join(',', @$k);
    $acc .= "      \\keyw{$k}\n";
  }

  # Append any warnings to the entry, if any
  if (my $w = $be->get_field_nv('warnings')) {
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

Copyright 2009-2015 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
