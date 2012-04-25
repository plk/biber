package Biber::Output::bbl;
use 5.014000;
use strict;
use warnings;
use base 'Biber::Output::base';

use Biber::Config;
use Biber::Constants;
use Biber::Entry;
use Biber::Utils;
use List::AllUtils qw( :all );
use IO::File;
use Log::Log4perl qw( :no_extra_logdie_message );
my $logger = Log::Log4perl::get_logger('main');

=encoding utf-8

=head1 NAME

Biber::Output::bbl - class for Biber output of .bbl

=cut

=head2 new

    Initialize a Biber::Output::bbl object

=cut

sub new {
  my $class = shift;
  my $obj = shift;
  my $self = $class->SUPER::new($obj);
  my $ctrlver = Biber::Config->getblxoption('controlversion');
  my $beta = $Biber::Config::BETA_VERSION ? ' (beta)' : '';

  $self->{output_data}{HEAD} = <<EOF;
% \$ biblatex auxiliary file \$
% \$ biblatex version $ctrlver \$
% \$ biber version $Biber::Config::VERSION$beta \$
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

  return $self;
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
    if (Biber::Config->getoption('bblsafechars')) {
      $pa = Biber::LaTeX::Recode::latex_encode($pa);
    }
    $self->{output_data}{HEAD} .= "\\preamble{%\n$pa%\n}\n\n";
  }
  $self->{output_data}{TAIL} .= "\\endinput\n\n";
  return;
}

=head2 set_output_target_file

    Set the output target file of a Biber::Output::bbl object
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
  my $BBLFILE = IO::File->new($bblfile, ">$enc_out");
  $self->set_output_target($BBLFILE);
}

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

  # auto-escape TeX special chars if:
  # * The entry is not a BibTeX entry (no auto-escaping for BibTeX data)
  # * It's not a strng field
  if ($field_type ne 'strng' and $be->get_field('datatype') ne 'bibtex') {
    $str =~ s/(?<!\\)(\#|\&|\%)/\\$1/gxms;
  }

  if (Biber::Config->getoption('wraplines')) {
    ## 16 is the length of '      \field{}{}' or '      \strng{}{}'
    if ( 16 + length($field) + length($str) > 2*$Text::Wrap::columns ) {
      return "      \\${field_type}{$field}{%\n" . wrap('      ', '      ', $str) . "%\n      }\n";
    }
    elsif ( 16 + length($field) + length($str) > $Text::Wrap::columns ) {
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

=head2 set_output_keyalias

  Set the output for a key which is an alias to another key

=cut

sub set_output_keyalias {
  my $self = shift;
  my $alias = shift;
  my $key = shift;
  my $section = shift;
  my $secnum = $section->number;

  my $acc = "  \\keyalias{$alias}{$key}\n";

  # Create an index by keyname for easy retrieval
  $self->{output_data}{ALIAS_ENTRIES}{$secnum}{index}{$alias} = \$acc;

  return;

}


=head2 set_output_undefkey

  Set the .bbl output for an undefined key

=cut

sub set_output_undefkey {
  my $self = shift;
  my $key = shift; # undefined key
  my $section = shift; # Section object the entry occurs in
  my $secnum = $section->number;

  my $acc = "  \\missing{$key}\n";

  # Create an index by keyname for easy retrieval
  $self->{output_data}{MISSING_ENTRIES}{$secnum}{index}{$key} = \$acc;

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
  my $secnum = $section->number;
  my $key = $be->get_field('citekey');

  if ($be->field_exists('options')) {
    $opts = filter_entry_options($be->get_field('options'));
  }

  $acc .= "    \\entry{$key}{" . $be->get_field('entrytype') . "}{$opts}\n";

  # Generate set information
  if ( $be->get_field('entrytype') eq 'set' ) {   # Set parents get \set entry ...
    $acc .= "      \\set{" . $be->get_field('entryset') . "}\n";
  }
  else { # Everything else that isn't a set parent ...
    if (my $es = $be->get_field('entryset')) { # ... gets a \inset if it's a set member
      $acc .= "      \\inset{$es}\n";
    }
  }

  # Output name fields

  # first output copy in labelname
  # This is essentially doing the same thing twice but in the future,
  # labelname may have different things attached than the raw name
  my $lnn = $be->get_field('labelnamename'); # save name of labelname field
  my $plo = ''; # per-list options

  if (my $ln = $be->get_field('labelname')) {
    my @plo;
    # Add uniquelist, if defined
    if (my $ul = $ln->get_uniquelist){
      push @plo, "uniquelist=$ul";
    }
    $plo = join(',', @plo);

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
  foreach my $namefield (@{$struc->get_field_type('name')}) {
    next if $struc->is_field_type('skipout', $namefield);
    if ( my $nf = $be->get_field($namefield) ) {

      # Did we have "and others" in the data?
      if ( $nf->get_morenames ) {
        $acc .= "      \\true{more$namefield}\n";
      }

      my $total = $nf->count_names;
      # Copy per-list options to the actual labelname too
      $plo = '' unless (defined($lnn) and $namefield eq $lnn);
      $acc .= "      \\name{$namefield}{$total}{$plo}{%\n";
      foreach my $n (@{$nf->names}) {
        $acc .= $n->name_to_bbl;
      }
      $acc .= "      }\n";
    }
  }

  # Output list fields
  foreach my $listfield (@{$struc->get_field_type('list')}) {
    next if $struc->is_field_type('skipout', $listfield);
    if (my $lf = $be->get_field($listfield)) {
      if ( lc($be->get_field($listfield)->[-1]) eq 'others' ) {
        $acc .= "      \\true{more$listfield}\n";
        pop @$lf; # remove the last element in the array
      }
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

  # This is special, we have to put a marker for sortinit and then replace this string
  # on output as it can vary between lists
  $acc .= "      <BDS>SORTINIT</BDS>\n";

  # The labelyear option determines whether "extrayear" is output
  if ( Biber::Config->getblxoption('labelyear', $be->get_field('entrytype'))) {
    # Might not have been set due to skiplab/dataonly
    if (my $nameyear = $be->get_field('nameyear')) {
      if ( Biber::Config->get_seen_nameyear($nameyear) > 1) {
        $acc .= "      <BDS>EXTRAYEAR</BDS>\n";
      }
    }
    if (my $ly = $be->get_field('labelyear')) {
      $acc .= "      \\field{labelyear}{$ly}\n";
    }
  }

  # The labelalpha option determines whether "extraalpha" is output
  if ( Biber::Config->getblxoption('labelalpha', $be->get_field('entrytype'))) {
    # Might not have been set due to skiplab/dataonly
    if (my $la = $be->get_field('labelalpha')) {
      if (Biber::Config->get_la_disambiguation($la) > 1) {
        $acc .= "      <BDS>EXTRAALPHA</BDS>\n";
      }
    }
  }

  if ( Biber::Config->getblxoption('labelnumber', $be->get_field('entrytype')) ) {
    if (my $sh = $be->get_field('shorthand')) {
      $acc .= "      \\field{labelnumber}{$sh}\n";
    }
    elsif (my $lnum = $be->get_field('labelnumber')) {
      $acc .= "      \\field{labelnumber}{$lnum}\n";
    }
  }

  if (defined($be->get_field('singletitle'))) {
    $acc .= "      \\true{singletitle}\n";
  }

  foreach my $lfield (sort (@{$struc->get_field_type('literal')}, @{$struc->get_field_type('datepart')})) {
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
      $acc .= _printfield($be, $lfield, $be->get_field($lfield) );
    }
  }

  foreach my $rfield (@{$struc->get_field_type('range')}) {
    if ( my $rf = $be->get_field($rfield) ) {
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
    }
  }

  foreach my $vfield (@{$struc->get_field_type('verbatim')}) {
    if ( my $vf = $be->get_field($vfield) ) {
      $acc .= "      \\verb{$vfield}\n";
      $acc .= "      \\verb $vf\n      \\endverb\n";
    }
  }
  if ( my $k = $be->get_field('keywords') ) {
    $acc .= "      \\keyw{$k}\n";
  }

  # Append any warnings to the entry, if any
  if ( my $w = $be->get_field('warnings')) {
    foreach my $warning (@$w) {
      $acc .= "      \\warn{\\item $warning}\n";
    }
  }

  $acc .= "    \\endentry\n";

  # Create an index by keyname for easy retrieval
  $self->{output_data}{ENTRIES}{$secnum}{index}{$key} = \$acc;

  return;
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
  $logger->info('Converting UTF-8 to TeX macros on output to .bbl') if Biber::Config->getoption('bblsafechars');

  print $target $data->{HEAD};

  foreach my $secnum (sort keys %{$data->{ENTRIES}}) {
    $logger->debug("Writing entries for section $secnum");

    print $target "\n\\refsection{$secnum}\n";
    my $section = $self->get_output_section($secnum);

    # This sort is cosmetic, just to order the lists in a predictable way in the .bbl
    foreach my $list (sort {$a->get_label cmp $b->get_label} @{$Biber::MASTER->sortlists->get_lists_for_section($secnum)}) {
      next unless $list->count_keys; # skip empty lists
      my $listlabel = $list->get_label;
      my $listtype = $list->get_type;
      $logger->debug("Writing entries in '$listtype' list '$listlabel'");

      print $target "  \\sortlist{$listtype}{$listlabel}\n";

      # The order of this array is the sorted order
      foreach my $k ($list->get_keys) {
        $logger->debug("Writing entry for key '$k'");
        if ($listtype eq 'entry') {
          my $entry = $data->{ENTRIES}{$secnum}{index}{$k};

          # Instantiate any dynamic, list specific entry information
          my $entry_string = $list->instantiate_entry($entry, $k);

          # If requested to convert UTF-8 to macros ...
          if (Biber::Config->getoption('bblsafechars')) {
            $entry_string = latex_recode_output($entry_string);
          }

          print $target $entry_string;
        }
        elsif ($listtype eq 'shorthand') {
          print $target "    \\key{$k}\n";
        }
      }

      print $target "  \\endsortlist\n";

    }

    # Aliases
    while (my ($k, $ks) = each %{$data->{ALIAS_ENTRIES}{$secnum}{index}}) {
      print $target $$ks;
    }

    # Missing keys
    while (my ($k, $ks) = each %{$data->{MISSING_ENTRIES}{$secnum}{index}}) {
      print $target $$ks;
    }

    print $target "\\endrefsection\n"
  }

  print $target $data->{TAIL};

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
