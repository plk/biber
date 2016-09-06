package Biber::Output::bbl;
use v5.24;
use strict;
use warnings;
use parent qw(Biber::Output::base);

use Biber::Annotation;
use Biber::Config;
use Biber::Constants;
use Biber::Entry;
use Biber::Utils;
use Encode;
use List::AllUtils qw( :all );
use IO::File;
use Log::Log4perl qw( :no_extra_logdie_message );
use Scalar::Util qw(looks_like_number);
use Text::Wrap;
use Unicode::Normalize;
$Text::Wrap::columns = 80;
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

  $self->{output_data}{HEAD} = <<EOF;
% \$ biblatex auxiliary file \$
% \$ biblatex bbl format version $Biber::Config::BBL_VERSION \$
% Do not modify the above lines!
%
% This is an auxiliary file used by the 'biblatex' package.
% This file may safely be deleted. It will be recreated by
% biber as required.
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
    $pa = join("%\n", $pa->@*);

    # If requested to convert UTF-8 to macros ...
    if (Biber::Config->getoption('output_safechars')) {
      $pa = latex_recode_output($pa);
    }
    else {           # ... or, check for encoding problems and force macros
      my $outenc = Biber::Config->getoption('output_encoding');
      if ($outenc ne 'UTF-8') {
        # Can this entry be represented in the output encoding?
        if (encode($outenc, NFC($pa), sub {"\0"}) =~ /\0/) { # Malformed data encoding char
          # So convert to macro
          $pa = latex_recode_output($pa);
        }
      }
    }
    $self->{output_data}{HEAD} .= "\\preamble{%\n$pa%\n}\n\n";
  }
  $self->{output_data}{TAIL} .= "\\endinput\n\n";
  return;
}

=head2 _printfield

  Add the .bbl for a text field to the output accumulator.

=cut

sub _printfield {
  my ($be, $field, $str) = @_;
  my $field_type = 'field';
  my $dm = Biber::Config->get_dm;

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
  my ($self, $be, $section, $dm) = @_;
  my $bee = $be->get_field('entrytype');
  my $secnum = $section->number;
  my $key = $be->get_field('citekey');
  my $acc = '';
  my $dmh = $dm->{helpers};

  # Skip entrytypes we don't want to output according to datamodel
  return if $dm->entrytype_is_skipout($bee);
  $acc .= "    \\entry{$key}{$bee}{" . join(',', filter_entry_options($be->get_field('options'))->@*) . "}\n";

  # Generate set information
  if ( $bee eq 'set' ) {   # Set parents get \set entry ...
    $acc .= "      \\set{" . join(',', $be->get_field('entryset')->@*) . "}\n";
  }
  else { # Everything else that isn't a set parent ...
    if (my $es = $be->get_field('entryset')) { # ... gets a \inset if it's a set member
      $acc .= "      \\inset{" . join(',', $es->@*) . "}\n";
    }
  }

  # Output name fields
  foreach my $namefield ($dmh->{namelists}->@*) {
    # Performance - as little as possible here - loop over DM fields for every entry
    if ( my $nf = $be->get_field($namefield) ) {
      my $plo = '';

      # Did we have "and others" in the data?
      if ( $nf->get_morenames ) {
        $acc .= "      \\true{more$namefield}\n";
        # Is this name labelname? If so, provide \morelabelname
        if (my $lni = $be->get_labelname_info) {
          if ( $lni eq $namefield ) {
            $acc .= "      \\true{morelabelname}\n";
          }
        }
      }

      my $total = $nf->count_names;

      my $lni = $be->get_labelname_info;
      if (defined($lni) and
          $lni eq $namefield) {
        my @plo;

        # Add uniquelist, if defined
        if (my $ul = $nf->get_uniquelist){
          push @plo, "uniquelist=$ul";
        }

        # Add per-namelist options
        foreach my $ploname (keys $CONFIG_SCOPEOPT_BIBLATEX{NAMELIST}->%*) {
          if (defined($nf->${\"get_$ploname"})) {
            my $plo = $nf->${\"get_$ploname"};
            if ($CONFIG_OPTTYPE_BIBLATEX{lc($ploname)} and
                $CONFIG_OPTTYPE_BIBLATEX{lc($ploname)} eq 'boolean') {
                  push @plo, "$ploname=" . map_boolean($plo, 'tostring');
                }
            else {
              push @plo, "$ploname=$plo";
            }
          }
        }

        $plo = join(',', @plo);
      }
      $acc .= "      \\name{$namefield}{$total}{$plo}{%\n";
      foreach my $n ($nf->names->@*) {
        $acc .= $n->name_to_bbl;
      }
      $acc .= "      }\n";
    }
  }

  # Output list fields
  foreach my $listfield ($dmh->{lists}->@*) {
    # Performance - as little as possible here - loop over DM fields for every entry
    if (my $lf = $be->get_field($listfield)) {
      if ( lc($lf->[-1]) eq Biber::Config->getoption('others_string') ) {
        $acc .= "      \\true{more$listfield}\n";
        pop $lf->@*; # remove the last element in the array
      }
      my $total = $lf->$#* + 1;
      $acc .= "      \\list{$listfield}{$total}{%\n";
      foreach my $f ($lf->@*) {
        $acc .= "        {$f}%\n";
      }
      $acc .= "      }\n";
    }
  }

  # Output labelname hashes
  my $namehash = $be->get_field('namehash');
  $acc .= "      \\strng{namehash}{$namehash}\n" if $namehash;
  my $fullhash = $be->get_field('fullhash');
  $acc .= "      \\strng{fullhash}{$fullhash}\n" if $fullhash;

  # Output namelist hashes
  foreach my $namefield ($dmh->{namelists}->@*) {
    if (my $namehash = $be->get_field("${namefield}namehash")) {
      $acc .= "      \\strng{${namefield}namehash}{$namehash}\n";
      my $fullhash = $be->get_field("${namefield}fullhash");
      $acc .= "      \\strng{${namefield}fullhash}{$fullhash}\n";
    }
  }

  if ( Biber::Config->getblxoption('labelalpha', $bee) ) {
    # Might not have been set due to skiplab/dataonly
    if (my $label = $be->get_field('labelalpha')) {
      $acc .= "      \\field{labelalpha}{$label}\n";
    }
  }

  # This is special, we have to put a marker for sortinit{hash} and then replace this string
  # on output as it can vary between lists
  $acc .= "      <BDS>SORTINIT</BDS>\n";
  $acc .= "      <BDS>SORTINITHASH</BDS>\n";

  # The labeldateparts option determines whether "extrayear" is output
  if (Biber::Config->getblxoption('labeldateparts', $bee)) {
    # Might not have been set due to skiplab/dataonly
    if (my $nameyear = $be->get_field('nameyear')) {
      if ( Biber::Config->get_seen_nameyear($nameyear) > 1) {
        $acc .= "      <BDS>EXTRAYEAR</BDS>\n";
      }
    }
    if ($be->field_exists('labeldatesource')) {
      $acc .= "      \\field{labeldatesource}{" . $be->get_field('labeldatesource') .  "}\n";
    }
  }

  # labelprefix is list-specific. It is only defined is there is no shorthand
  # (see biblatex documentation)
  unless ($be->get_field('shorthand')) {
    $acc .= "      <BDS>LABELPREFIX</BDS>\n";
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

  # The labelalpha option determines whether "extraalpha" is output
  if ( Biber::Config->getblxoption('labelalpha', $bee)) {
    # Might not have been set due to skiplab/dataonly
    if (my $la = $be->get_field('labelalpha')) {
      if (Biber::Config->get_la_disambiguation($la) > 1) {
        $acc .= "      <BDS>EXTRAALPHA</BDS>\n";
      }
    }
  }

  if (defined($be->get_field('crossrefsource'))) {
    $acc .= "      \\true{crossrefsource}\n";
  }

  if (defined($be->get_field('xrefsource'))) {
    $acc .= "      \\true{xrefsource}\n";
  }

  if (defined($be->get_field('singletitle'))) {
    $acc .= "      \\true{singletitle}\n";
  }

  if (defined($be->get_field('uniquetitle'))) {
    $acc .= "      \\true{uniquetitle}\n";
  }

  if (defined($be->get_field('uniquebaretitle'))) {
    $acc .= "      \\true{uniquebaretitle}\n";
  }

  if (defined($be->get_field('uniquework'))) {
    $acc .= "      \\true{uniquework}\n";
  }

  if (defined($be->get_field('uniqueprimaryauthor'))) {
    $acc .= "      \\true{uniqueprimaryauthor}\n";
  }

  # The source field for labelname
  if (my $lni = $be->get_labelname_info) {
    $acc .= "      \\field{labelnamesource}{$lni}\n";
  }

  # The source field for labeltitle
  if (my $lti = $be->get_labeltitle_info) {
    $acc .= "      \\field{labeltitlesource}{$lti}\n";
  }

  if (my $ck = $be->get_field('clonesourcekey')) {
    $acc .= "      \\field{clonesourcekey}{$ck}\n";
  }

  foreach my $field ($dmh->{fields}->@*) {
    # Performance - as little as possible here - loop over DM fields for every entry
    my $val = $be->get_field($field);
    if ( length($val) or # length() catches '0' values, which we want
         ($dm->field_is_nullok($field) and
          $be->field_exists($field)) ) {

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
      $acc .= _printfield($be, $field, $val);
    }
  }

  # Date meta-information
  foreach my $d ($dmh->{datefields}->@*) {
    $d =~ s/date$//;

    # Unspecified granularity
    if (my $unspec = $be->get_field("${d}dateunspecified")) {
      $acc .= "      \\field{${d}dateunspecified}{$unspec}\n";
    }

    # Julian dates
    if ($be->get_field("${d}datejulian")) {
      $acc .= "      \\true{${d}datejulian}\n";
    }
    if ($be->get_field("${d}enddatejulian")) {
      $acc .= "      \\true{${d}enddatejulian}\n";
    }

    # Circa dates
    if ($be->get_field("${d}datecirca")) {
      $acc .= "      \\true{${d}datecirca}\n";
    }
    if ($be->get_field("${d}enddatecirca")) {
      $acc .= "      \\true{${d}enddatecirca}\n";
    }

    # Uncertain dates
    if ($be->get_field("${d}dateuncertain")) {
      $acc .= "      \\true{${d}dateuncertain}\n";
    }
    if ($be->get_field("${d}enddateuncertain")) {
      $acc .= "      \\true{${d}enddateuncertain}\n";
    }

    # Only output era for date if:
    # The field is "year" and it came from splitting a date
    # The field is any other startyear
    if ($be->field_exists("${d}year")) { # use exists test as could be year 0000
      next unless $be->get_field("${d}datesplit");
      if (my $era = $be->get_field("${d}era")) {
        $acc .= "      \\field{${d}dateera}{$era}\n";
      }
      if (my $era = $be->get_field("${d}endera")) {
        $acc .= "      \\field{${d}enddateera}{$era}\n";
      }
    }
  }

  # XSV fields
  foreach my $field ($dmh->{xsv}->@*) {
    if (my $f = $be->get_field($field)) {
      $acc .= _printfield($be, $field, join(',', $f->@*) );
    }
  }

  foreach my $rfield ($dmh->{ranges}->@*) {
    # Performance - as little as possible here - loop over DM fields for every entry
    if ( my $rf = $be->get_field($rfield) ) {
      # range fields are an array ref of two-element array refs [range_start, range_end]
      # range_end can be be empty for open-ended range or undef
      my @pr;
      foreach my $f ($rf->@*) {
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
  foreach my $vfield ($dmh->{vfields}->@*) {
    # Performance - as little as possible here - loop over DM fields for every entry
    if ( my $vf = $be->get_field($vfield) ) {
      $acc .= "      \\verb{$vfield}\n";
      $acc .= "      \\verb $vf\n      \\endverb\n";
    }
  }
  # verbatim lists
  foreach my $vlist ($dmh->{vlists}->@*) {
    if ( my $vlf = $be->get_field($vlist) ) {
      if ( lc($vlf->[-1]) eq Biber::Config->getoption('others_string') ) {
        $acc .= "      \\true{more$vlist}\n";
        pop $vlf->@*; # remove the last element in the array
      }
      my $total = $vlf->$#* + 1;
      $acc .= "      \\lverb{$vlist}{$total}\n";
      foreach my $f ($vlf->@*) {
        $acc .= "      \\lverb $f\n";
      }
      $acc .= "      \\endlverb\n";
    }
  }

  if ( my $k = $be->get_field('keywords') ) {
    $k = join(',', $k->@*);
    $acc .= "      \\keyw{$k}\n";
  }

  # Output annotations
  foreach my $f (Biber::Annotation->get_annotated_fields('field', $key)) {
    my $v = Biber::Annotation->get_annotation('field', $key, $f);
    $acc .= "      \\annotation{field}{$f}{}{}{$v}\n";
  }

  foreach my $f (Biber::Annotation->get_annotated_fields('item', $key)) {
    foreach my $c (Biber::Annotation->get_annotated_items('item', $key, $f)) {
      my $v = Biber::Annotation->get_annotation('item', $key, $f, $c);
      $acc .= "      \\annotation{item}{$f}{$c}{}{$v}\n";
    }
  }

  foreach my $f (Biber::Annotation->get_annotated_fields('part', $key)) {
    foreach my $c (Biber::Annotation->get_annotated_items('part', $key, $f)) {
      foreach my $p (Biber::Annotation->get_annotated_parts('part', $key, $f, $c)) {
        my $v = Biber::Annotation->get_annotation('part', $key, $f, $c, $p);
        $acc .= "      \\annotation{part}{$f}{$c}{$p}{$v}\n";
      }
    }
  }

  # Append any warnings to the entry, if any
  if (my $w = $be->get_field('warnings')) {
    foreach my $warning ($w->@*) {
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

  if ($logger->is_debug()) {# performance tune
    $logger->debug('Preparing final output using class ' . __PACKAGE__ . '...');
  }

  $logger->info("Writing '$target_string' with encoding '" . Biber::Config->getoption('output_encoding') . "'");
  $logger->info('Converting UTF-8 to TeX macros on output to .bbl') if Biber::Config->getoption('output_safechars');

  out($target, $data->{HEAD});

  foreach my $secnum (sort keys $data->{ENTRIES}->%*) {
    if ($logger->is_debug()) {# performance tune
      $logger->debug("Writing entries for section $secnum");
    }

    out($target, "\n\\refsection{$secnum}\n");
    my $section = $self->get_output_section($secnum);

    my @lists; # Need to reshuffle list to put global sort order list at end, see below

    # This sort is cosmetic, just to order the lists in a predictable way in the .bbl
    # but omit the global context list so that we can add this last
    foreach my $list (sort {$a->get_sortschemename cmp $b->get_sortschemename} $Biber::MASTER->sortlists->get_lists_for_section($secnum)->@*) {
      if ($list->get_sortschemename eq Biber::Config->getblxoption('sortscheme') and
          $list->get_sortnamekeyschemename eq 'global' and
          $list->get_labelprefix eq '' and
          $list->get_type eq 'entry') {
        next;
      }
      push @lists, $list;
    }

    # biblatex requires the last list in the .bbl to be the global sort  list
    # due to its sequential reading of the .bbl as the final list overrides the
    # previously read ones and the global list determines the order of labelnumber
    # and sortcites etc. when not using defernumbers
    push @lists, $Biber::MASTER->sortlists->get_list($secnum, Biber::Config->getblxoption('sortscheme') . '/global/', 'entry', Biber::Config->getblxoption('sortscheme'), 'global', '');

    foreach my $list (@lists) {
      next unless $list->count_keys; # skip empty lists
      my $listssn = $list->get_sortschemename;
      my $listsnksn = $list->get_sortnamekeyschemename;
      my $listpn = $list->get_labelprefix;
      my $listtype = $list->get_type;
      my $listname = $list->get_name;

      if ($logger->is_debug()) {# performance tune
        $logger->debug("Writing entries in '$listname' list of type '$listtype' with sortscheme '$listssn', sort name key scheme '$listsnksn' and labelprefix '$listpn'");
      }

      out($target, "  \\sortlist[$listtype]{$listname}\n");

      # The order of this array is the sorted order
      foreach my $k ($list->get_keys) {
        if ($logger->is_debug()) {# performance tune
          $logger->debug("Writing entry for key '$k'");
        }

        my $entry = $data->{ENTRIES}{$secnum}{index}{$k};

        # Instantiate any dynamic, list specific entry information
        my $entry_string = $list->instantiate_entry($entry, $k);

        # If requested to convert UTF-8 to macros ...
        if (Biber::Config->getoption('output_safechars')) {
          $entry_string = latex_recode_output($entry_string);
        }
        else { # ... or, check for encoding problems and force macros
          my $outenc = Biber::Config->getoption('output_encoding');
          if ($outenc ne 'UTF-8') {
            # Can this entry be represented in the output encoding?
            # We must have an ASCII-safe replacement string for encode which is unlikely to be
            # in the string. Default is "?" which could easily be in URLS so we choose ASCII null
            if (encode($outenc, NFC($entry_string), sub {"\0"})  =~ /\0/) { # Malformed data encoding char
              # So convert to macro
              $entry_string = latex_recode_output($entry_string);
              biber_warn("The entry '$k' has characters which cannot be encoded in '$outenc'. Recoding problematic characters into macros.");
            }
          }
        }

        # If requested, add a printable sorting key to the output - useful for debugging
        if (Biber::Config->getoption('sortdebug')) {
          $entry_string = "    % sorting key for '$k':\n    % " . $list->get_sortdata($k)->[0] . "\n" . $entry_string;
        }

        # Now output
        out($target, $entry_string);
      }

      out($target, "  \\endsortlist\n");

    }

    # Aliases
    foreach my $ks (values $data->{ALIAS_ENTRIES}{$secnum}{index}->%*) {
      out($target, $$ks);
    }

    # Missing keys
    foreach my $ks (values $data->{MISSING_ENTRIES}{$secnum}{index}->%*) {
      out($target, $$ks);
    }

    out($target, "\\endrefsection\n");
  }

  out($target, $data->{TAIL});

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

Please report any bugs or feature requests on our Github tracker at
L<https://github.com/plk/biber/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2016 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
