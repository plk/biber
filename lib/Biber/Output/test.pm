package Biber::Output::test;
use v5.24;
use strict;
use warnings;
use parent qw(Biber::Output::base);

use Biber::Config;
use Biber::Constants;
use Biber::Entry;
use Biber::Utils;
use Scalar::Util qw(looks_like_number);
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
  my ($be, $field, $str, $ms) = @_;

  my $field_type = 'field';
  my $dm = Biber::Config->get_dm;

  my $outfield = $dm->get_outcase($field);

  return '' if is_null($str) and not $dm->field_is_nullok($field);

  # crossref and xref are of type 'strng' in the .bbl
  if (lc($field) eq 'crossref' or
      lc($field) eq 'xref') {
    $field_type = 'strng';
  }

  # Output absolute astronomical year by default (with year 0)
  # biblatex will adjust the years when printed with BCE/CE eras
  if ($field =~ m/^(.*)(?!end)year$/) {
    if (my $y = $be->get_field("$1year")) {
      $str = abs($y) if looks_like_number($y);
    }
  }

  # auto-escape TeX special chars if:
  # * The entry is not a BibTeX entry (no auto-escaping for BibTeX data)
  # * It's not a string field
  if ($field_type ne 'strng' and $be->get_field('datatype') ne 'bibtex') {
    $str =~ s/(?<!\\)(\#|\&|\%)/\\$1/gxms;
  }

  if (Biber::Config->getoption('wraplines')) {
    ## 16 is the length of '      \field{}{}' or '      \strng{}{}'
    if ( 16 + Unicode::GCString->new($ms)->length + Unicode::GCString->new($outfield)->length + Unicode::GCString->new($str)->length > 2*$Text::Wrap::columns ) {
      return "      \\${field_type}${ms}{$outfield}{%\n" . wrap('      ', '      ', $str) . "%\n      }\n";
    }
    elsif ( 16 + Unicode::GCString->new($ms)->length + Unicode::GCString->new($outfield)->length + Unicode::GCString->new($str)->length > $Text::Wrap::columns ) {
      return wrap('      ', '      ', "\\${field_type}${ms}{$outfield}{$str}" ) . "\n";
    }
    else {
      return "      \\${field_type}${ms}{$outfield}{$str}\n";
    }
  }
  else {
    return "      \\${field_type}${ms}{$outfield}{$str}\n";
  }
  return;
}

=head2 set_output_entry

  Set the .bbl output for an entry. This is the meat of
  the .bbl output

=cut

sub set_output_entry {
  my ($self, $be, $section, $dm) = @_;
  my $bee = $be->get_field('entrytype');
  my $acc = '';
  my $secnum = $section->number;
  my $dmh = $dm->{helpers};
  my $key = $be->get_field('citekey');
  my $un = Biber::Config->getblxoption($secnum,'uniquename', $bee, $key);
  my $ul = Biber::Config->getblxoption($secnum,'uniquelist', $bee, $key);
  my ($lni, $lnf, $lnl) = $be->get_labelname_info->@*;
  my $nl = $be->get_field($lni, $lnf, $lnl);

  # Per-namelist uniquelist
  if (defined($lni) and $nl->get_uniquelist) {
    $ul = $nl->get_uniquelist;
  }

  # Per-namelist uniquename
  if (defined($lni) and $nl->get_uniquename) {
    $un = $nl->get_uniquename;
  }

  $acc .= "% sortstring = " . $be->get_field('sortstring') . "\n"
    if (Biber::Config->getoption('debug') || Biber::Config->getblxoption(undef,'debug'));

  $acc .= "    \\entry{$key}{$bee}{" . join(',', filter_entry_options($secnum, $be)->@*) . "}\n";

  # Generate set information
  if ($bee eq 'set') {   # Set parents get \set entry ...
    $acc .= "      \\set{" . join(',', $be->get_field('entryset')->@*) . "}\n";

    # Set parents need this - it is the labelalpha from the first entry
    if ( Biber::Config->getblxoption(undef,'labelalpha', $bee, $key) ) {
      $acc .= "      <BDS>LABELALPHA</BDS>\n";
      $acc .= "      <BDS>EXTRAALPHA</BDS>\n";
    }

    # This is special, we have to put a marker for sortinit{hash} and then replace this string
    # on output as it can vary between lists
    $acc .= "      <BDS>SORTINIT</BDS>\n";
    $acc .= "      <BDS>SORTINITHASH</BDS>\n";

    # labelprefix is list-specific. It is only defined if there is no shorthand
    # (see biblatex documentation)
    $acc .= "      <BDS>LABELPREFIX</BDS>\n";

    # Label can be in set parents
    if (my $lab = $be->get_field('label')) {
      $acc .= "      \\field{label}{$lab}\n";
    }

    # Annotation can be in set parents
    if (my $ann = $be->get_field('annotation')) {
      $acc .= "      \\field{annotation}{$ann}\n";
    }

    # Skip everything else
    # labelnumber/labelprefix etc. are generated by biblatex after reading the .bbl
    goto ENDENTRY;

  }
  else { # Everything else that isn't a set parent ...
    if (my $es = $be->get_field('entryset')) { # ... gets a \inset if it's a set member
      $acc .= "      \\inset{" . join(',', $es->@*) . "}\n";
    }
  }


  # Output name fields
  foreach my $namefield ($dm->get_fields_of_type('list', 'name')->@*) {
    next if $dm->field_is_skipout($namefield);
    foreach my $alts ($be->get_alternates_for_field($namefield)->@*) {
      my $nf = $alts->{val};
      my $form = $alts->{form};
      my $lang = $alts->{lang};
      my $nlid = $nf->get_id;

      # Internally, no distinction is made between multiscript and
      # non-multiscript fields but it is on output
      my $ms = '';
      if ($dm->is_multiscript($namefield)) {
        $ms = "[$form][$lang]";
      }

      # Did we have "and others" in the data?
      if ( $nf->get_morenames ) {
        $acc .= "      \\true{more$namefield}\n";
        # Is this name labelname? If so, provide \morelabelname
        if (defined($lni) and $lni eq $namefield) {
          $acc .= "      \\true{morelabelname}\n";
        }
      }

      # Per-name uniquename if this is labelname
      if (defined($lni) and $lni eq $namefield) {
        if (defined($nf->get_uniquename)) {
          $un = $nf->get_uniquename;
        }
      }

      my $total = $nf->count;

      # Add per-list options, if any

      my $nfv = '';

      if (defined($lni) and $lni eq $namefield) {
        # Add uniquelist, if defined
        my @plo;

        # Add uniquelist if requested
        if ($ul ne 'false') {
          push @plo, "<BDS>UL-${nlid}</BDS>";
        }

        # Add per-namelist options
        foreach my $nlo (keys $CONFIG_SCOPEOPT_BIBLATEX{NAMELIST}->%*) {
          if (defined($nf->${\"get_$nlo"})) {
            my $nlov = $nf->${\"get_$nlo"};

            if ($CONFIG_BIBLATEX_OPTIONS{NAMELIST}{$nlo}{OUTPUT}) {
              push @plo, $nlo . '=' . map_boolean($nlo, $nlov, 'tostring');
            }
          }
        }
        $nfv = join(',', @plo);
      }
      $acc .= "      \\name${ms}{$namefield}{$total}{$nfv}{%\n";
      for (my $i = 1; $i <= $total; $i++) {
        $acc .= $nf->names->[$i-1]->name_to_bbl($nf, $un, $i);
      }
      $acc .= "      }\n";
    }
  }

  # List fields
  foreach my $listfield ($dmh->{lists}->@*) {
    foreach my $alts ($be->get_alternates_for_field($listfield)->@*) {
      my $lf = $alts->{val};
      my $form = $alts->{form};
      my $lang = $alts->{lang};

      # Internally, no distinction is made between multiscript and
      # non-multiscript fields but it is on output
      my $ms = '';
      if ($dm->is_multiscript($listfield)) {
        $ms = "[$form][$lang]";
      }

      if ( lc($lf->last_item) eq Biber::Config->getoption('others_string') ) {
        $acc .= "      \\true{more$listfield}\n";
        $lf->del_last_item; # remove the last element in the array
      };
      my $total = $lf->count;
      $acc .= "      \\list${ms}{$listfield}{$total}{%\n";
      foreach my $f ($lf->get_items->@*) {
        $acc .= "        {$f}%\n";
      }
      $acc .= "      }\n";
    }
  }

  # Output labelname hashes
  $acc .= "      <BDS>NAMEHASH</BDS>\n";
  my $fullhash = $be->get_field('fullhash');
  $acc .= "      \\strng{fullhash}{$fullhash}\n" if $fullhash;
  $acc .= "      <BDS>BIBNAMEHASH</BDS>\n";

  # Output namelist hashes
  foreach my $n ($dmh->{namelists}->@*) {
    foreach my $alts ($be->get_alternates_for_field($n)->@*) {
      my $val = $alts->{val};
      my $form = $dm->is_multiscript($n) ? $alts->{form} : '';
      my $lang = $dm->is_multiscript($n) ? $alts->{lang} : '';
      $acc .= "      <BDS>${n}${form}${lang}BIBNAMEHASH</BDS>\n";
      $acc .= "      <BDS>${n}${form}${lang}NAMEHASH</BDS>\n";
      if (my $fullhash = $be->get_field("${n}" . $alts->{form} . $alts->{lang} . "fullhash")) {
        $acc .= "      \\strng{${n}${form}${lang}fullhash}{$fullhash}\n";
      }
    }
  }

  if ( Biber::Config->getblxoption(undef,'labelalpha', $bee, $key) ) {
    $acc .= "      <BDS>LABELALPHA</BDS>\n";
  }

  # This is special, we have to put a marker for sortinit{hash} and then replace this string
  # on output as it can vary between lists
  $acc .= "      <BDS>SORTINIT</BDS>\n";
  $acc .= "      <BDS>SORTINITHASH</BDS>\n";

  # The labeldateparts option determines whether "extradate" is output
  # Skip generating extradate for entries with "skiplab" set
  if ( Biber::Config->getblxoption(undef,'labeldateparts', $bee, $key)) {
    # Might not have been set due to skiplab
    if (my $ey = $be->get_field('extradate')) {
      $acc .= "      <BDS>EXTRADATE</BDS>\n";
    }
    if ($be->field_exists('labeldatesource')) {
      $acc .= "      \\field{labeldatesource}{" . $be->get_field('labeldatesource') .  "}\n";
    }
  }

  # labelprefix is list-specific. It is only defined if there is no shorthand
  # (see biblatex documentation)
  unless ($be->get_field('shorthand')) {
    $acc .= "      <BDS>LABELPREFIX</BDS>\n";
  }

  # The labeltitle option determines whether "extratitle" is output
  if ( Biber::Config->getblxoption(undef,'labeltitle', $bee, $key)) {
    $acc .= "      <BDS>EXTRATITLE</BDS>\n";
  }

  # The labeltitleyear option determines whether "extratitleyear" is output
  if ( Biber::Config->getblxoption(undef,'labeltitleyear', $bee, $key)) {
    $acc .= "      <BDS>EXTRATITLEYEAR</BDS>\n";
  }

  # The labelalpha option determines whether "extraalpha" is output
  if ( Biber::Config->getblxoption(undef,'labelalpha', $bee, $key)) {
    $acc .= "      <BDS>EXTRAALPHA</BDS>\n";
  }

  $acc .= "      <BDS>SINGLETITLE</BDS>\n";
  $acc .= "      <BDS>UNIQUETITLE</BDS>\n";
  $acc .= "      <BDS>UNIQUEBARETITLE</BDS>\n";
  $acc .= "      <BDS>UNIQUEWORK</BDS>\n";
  $acc .= "      <BDS>UNIQUEPRIMARYAUTHOR</BDS>\n";

  # The source field for labelname
  if ($lni) {
    my $fl = "{$lnf}{$lnl}";
    $fl = "{}{}" unless $dm->is_multiscript($lni);
    $acc .= "      \\fieldmssource{labelname}{$lni}$fl\n";
  }

  # The source field for labeltitle
  if (my ($lti, $ltf, $ltl) = $be->get_labeltitle_info->@*) {
    my $fl = "{$ltf}{$ltl}";
    $fl = "{}{}" unless $dm->is_multiscript($lti);
    $acc .= "      \\fieldmssource{labeltitle}{$lti}$fl\n";
  }

  foreach my $field ($dmh->{fields}->@*) {
    foreach my $alts ($be->get_alternates_for_field($field)->@*) {
      my $val = $alts->{val};
      my $form = $alts->{form};
      my $lang = $alts->{lang};

      # Internally, no distinction is made between multiscript and
      # non-multiscript fields but it is on output
      my $ms = '';
      if ($dm->is_multiscript($field)) {
        $ms = "[$form][$lang]";
      }

      if ( length($val) or     # length() catches '0' values, which we want
           ($dm->field_is_nullok($field) and
            $be->field_exists($field, $form, $lang)) ) {

        # we skip outputting the crossref or xref when the parent is not cited
        # (biblatex manual, section 2.2.3)
        # sets are a special case so always output crossref/xref for them since their
        # children will always be in the .bbl otherwise they make no sense.
        unless ($bee eq 'set') {
          next if ($field eq 'crossref' and
                   not $section->has_citekey($be->get_field('crossref')));
          next if ($field eq 'xref' and
                   not $section->has_citekey($be->get_field('xref')));
        }
        $acc .= _printfield($be, $field, $val, $ms);
      }
    }
  }

  # XSV fields
  foreach my $field ($dmh->{xsv}->@*) {
    # keywords is by default field/xsv/keyword but it is in fact
    # output with its own special macro below
    next if $field eq 'keywords';

    foreach my $alts ($be->get_alternates_for_field($field)->@*) {
      my $f = $alts->{val};
      my $form = $alts->{form};
      my $lang = $alts->{lang};

      # Internally, no distinction is made between multiscript and
      # non-multiscript fields but it is on output
      my $ms = '';
      if ($dm->is_multiscript($field)) {
        $ms = "[$form][$lang]";
      }

      $acc .= _printfield($be, $field, join(',', $f->get_items->@*), $ms);
    }
  }

  # Range fields
  foreach my $rfield ($dm->get_fields_of_datatype('range')->@*) {
    if ( my $rf = $be->get_field($rfield)) {
      $rf =~ s/[-–]+/\\bibrangedash /g;
      $acc .= "      \\field{$rfield}{$rf}\n";
      $acc .= "      \\range{$rfield}{" . rangelen($rf) . "}\n";
    }
  }

  # Verbatim fields
  foreach my $vfield (($dm->get_fields_of_datatype('verbatim')->@*,
                       $dm->get_fields_of_datatype('uri')->@*)) {
    if ( my $rf = $be->get_field($vfield) ) {
      $acc .= "      \\verb{$vfield}\n";
      $acc .= "      \\verb $rf\n    \\endverb\n";
    }
  }
  if ( my $k = $be->get_field('keywords') ) {
    $acc .= "      \\keyw{$k}\n";
  }

  # Append any warnings to the entry, if any
  if (my $w = $be->get_warnings) {
    foreach my $warning ($w->@*) {
      $acc .= "      \\warn{\\item $warning}\n";
    }
  }

 ENDENTRY:
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
    $pa = join("%\n", $pa->@*);
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

  foreach my $secnum (sort keys $data->{ENTRIES}->%*) {
    my $section = $self->get_output_section($secnum);
    foreach my $list (sort {$a->get_sortingtemplatename cmp $b->get_sortingtemplatename} $Biber::MASTER->datalists->get_lists_for_section($secnum)->@*) {
      next unless $list->count_keys; # skip empty lists
      my $listtype = $list->get_type;
      foreach my $k ($list->get_keys->@*) {
        my $entry = $data->{ENTRIES}{$secnum}{index}{$k};

        # Instantiate any dynamic, list specific entry information
        my $entry_string = $list->instantiate_entry($section, $entry, $k);

        # If requested to convert UTF-8 to macros ...
        if (Biber::Config->getoption('output_safechars')) {
          $entry_string = latex_recode_output($entry_string);
        }
        out($target, $entry_string);

      }
    }
  }
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
Copyright 2012-2020 Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
