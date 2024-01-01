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
use URI;

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

  $self->{output_data}{HEAD} = <<~EOF;
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

  if ($Text::Wrap::columns = Biber::Config->getoption('wraplines')) {
    ## 16 is the length of '      \field{}{}' or '      \strng{}{}'
    if ( 16 + Unicode::GCString->new($outfield)->length + Unicode::GCString->new($str)->length > 2*$Text::Wrap::columns ) {
      return "      \\${field_type}{$outfield}{%\n" . wrap('      ', '      ', $str) . "%\n      }\n";
    }
    elsif ( 16 + Unicode::GCString->new($outfield)->length + Unicode::GCString->new($str)->length > $Text::Wrap::columns ) {
      return wrap('      ', '      ', "\\${field_type}{$outfield}{$str}" ) . "\n";
    }
    else {
      return "      \\${field_type}{$outfield}{$str}\n";
    }
  }
  else {
    return "      \\${field_type}{$outfield}{$str}\n";
  }
  return;
}

=head2 set_output_keyalias

  Set the output for a key which is an alias to another key

=cut

sub set_output_keyalias {
  my ($self, $alias, $key, $section) = @_;
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
  my ($self, $key, $section) = @_;
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
  my $outtype = $dm->get_outcase($bee) // $bee;
  my $secnum = $section->number;
  my $key = $be->get_field('citekey');
  my $acc = '';
  my $dmh = $dm->{helpers};
  my $un = Biber::Config->getblxoption($secnum, 'uniquename', $bee, $key);
  my $ul = Biber::Config->getblxoption($secnum, 'uniquelist', $bee, $key);
  my $lni = $be->get_labelname_info;
  my $nl = $be->get_field($lni);

  # Per-namelist uniquelist
  if (defined($lni) and $nl->get_uniquelist) {
    $ul = $nl->get_uniquelist;
  }

  # Per-namelist uniquename
  if (defined($lni) and $nl->get_uniquename) {
    $un = $nl->get_uniquename;
  }

  # Skip entrytypes we don't want to output according to datamodel
  return if $dm->entrytype_is_skipout($bee);
  my $kc = $section->get_citecount($key);
  $acc .= "    \\entry{$key}{$outtype}{" . join(',', filter_entry_options($secnum, $be)->@*) . '}{' .
      ($kc==-1 ? '' : $kc) . "}\n";

  # Generate set information.
  # Set parents are special and need very little
  if ($bee eq 'set') { # Set parents get \set entry ...
    $acc .= "      <BDS>ENTRYSET</BDS>\n";

    # Set parents need this - it is the labelalpha from the first entry
    if (Biber::Config->getblxoption(undef, 'labelalpha', $bee, $key)) {
      $acc .= "      <BDS>LABELALPHA</BDS>\n";
      $acc .= "      <BDS>EXTRAALPHA</BDS>\n";
    }

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

    # Sets can have shorthands
    if ( my $sh = $be->get_field('shorthand') ) {
      $acc .= "      \\field{shorthand}{$sh}\n";
    }

    # Keyword is necessary in some cases
    if ( my $k = $be->get_field('keywords') ) {
      $k = join(',', $k->@*);
      $acc .= "      \\keyw{$k}\n";
    }

    # Skip everything else
    # labelnumber is generated by biblatex after reading the .bbl
    goto ENDENTRY;
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
      my $nlid = $nf->get_id;

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

      my $nfv = '';

      if (defined($lni) and $lni eq $namefield) {
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

      $acc .= "      \\name{$namefield}{$total}{$nfv}{%\n";
      foreach my $n ($nf->names->@*) {
        $acc .= $n->name_to_bbl($un);
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
  $acc .= "      <BDS>NAMEHASH</BDS>\n";
  $acc .= "      <BDS>FULLHASH</BDS>\n";
  $acc .= "      <BDS>FULLHASHRAW</BDS>\n";
  $acc .= "      <BDS>BIBNAMEHASH</BDS>\n";

  # Output namelist hashes
  foreach my $namefield ($dmh->{namelists}->@*) {
    next unless $be->get_field($namefield);
    $acc .= "      <BDS>${namefield}BIBNAMEHASH</BDS>\n";
    $acc .= "      <BDS>${namefield}NAMEHASH</BDS>\n";
    $acc .= "      <BDS>${namefield}FULLHASH</BDS>\n";
    $acc .= "      <BDS>${namefield}FULLHASHRAW</BDS>\n";
  }

  # Output extraname if there is a labelname
  if ($lni) {
    $acc .= "      <BDS>EXTRANAME</BDS>\n";
  }

  if ( Biber::Config->getblxoption(undef, 'labelalpha', $bee, $key) ) {
    $acc .= "      <BDS>LABELALPHA</BDS>\n";
  }

  $acc .= "      <BDS>SORTINIT</BDS>\n";
  $acc .= "      <BDS>SORTINITHASH</BDS>\n";

  # The labeldateparts option determines whether "extradate" is output
  if (Biber::Config->getblxoption(undef, 'labeldateparts', $bee, $key)) {
    $acc .= "      <BDS>EXTRADATE</BDS>\n";
    if (my $edscope = $be->get_field('extradatescope')) {
      $acc .= "      \\field{extradatescope}{$edscope}\n";
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
  if ( Biber::Config->getblxoption(undef, 'labeltitle', $bee, $key)) {
    $acc .= "      <BDS>EXTRATITLE</BDS>\n";
  }

  # The labeltitleyear option determines whether "extratitleyear" is output
  if ( Biber::Config->getblxoption(undef, 'labeltitleyear', $bee, $key)) {
    $acc .= "      <BDS>EXTRATITLEYEAR</BDS>\n";
  }

  # The labelalpha option determines whether "extraalpha" is output
  if ( Biber::Config->getblxoption(undef, 'labelalpha', $bee, $key)) {
    $acc .= "      <BDS>EXTRAALPHA</BDS>\n";
  }

  if (defined($be->get_field('crossrefsource'))) {
    $acc .= "      \\true{crossrefsource}\n";
  }

  if (defined($be->get_field('xrefsource'))) {
    $acc .= "      \\true{xrefsource}\n";
  }

  $acc .= "      <BDS>SINGLETITLE</BDS>\n";
  $acc .= "      <BDS>UNIQUETITLE</BDS>\n";
  $acc .= "      <BDS>UNIQUEBARETITLE</BDS>\n";
  $acc .= "      <BDS>UNIQUEWORK</BDS>\n";
  $acc .= "      <BDS>UNIQUEPRIMARYAUTHOR</BDS>\n";

  # The source field for labelname
  if ($lni) {
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
    if ($be->get_field("${d}dateapproximate")) {
      $acc .= "      \\true{${d}datecirca}\n";
    }
    if ($be->get_field("${d}enddateapproximate")) {
      $acc .= "      \\true{${d}enddatecirca}\n";
    }

    # Uncertain dates
    if ($be->get_field("${d}dateuncertain")) {
      $acc .= "      \\true{${d}dateuncertain}\n";
    }
    if ($be->get_field("${d}enddateuncertain")) {
      $acc .= "      \\true{${d}enddateuncertain}\n";
    }

    # Unknown dates
    if ($be->get_field("${d}dateunknown")) {
      $acc .= "      \\true{${d}dateunknown}\n";
    }
    if ($be->get_field("${d}enddateunknown")) {
      $acc .= "      \\true{${d}enddateunknown}\n";
    }

    # Output enddateera
    if ($be->field_exists("${d}endyear")) { # use exists test as could be year 0000
      if (my $era = $be->get_field("${d}endera")) {
        $acc .= "      \\field{${d}enddateera}{$era}\n";
      }
    }
    # Only output era for date if:
    # The field is "year" and it came from splitting a date
    # The field is any other startyear
    if ($be->field_exists("${d}year")) { # use exists test as could be year 0000
      next unless $be->get_field("${d}datesplit");
      if (my $era = $be->get_field("${d}era")) {
        $acc .= "      \\field{${d}dateera}{$era}\n";
      }
    }
  }

  # XSV fields
  foreach my $field ($dmh->{xsv}->@*) {
    # keywords is by default field/xsv/keyword but it is in fact
    # output with its own special macro below
    next if $field eq 'keywords';
    if (my $f = $be->get_field($field)) {
      $acc .= _printfield($be, $field, join(',', $f->@*) );
    }
  }

  # Output nocite boolean
  if ($be->get_field('nocite')) {
    $acc .= "      \\true{nocite}\n";
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
      if ($dm->get_datatype($vfield) eq 'uri') {
        $acc .= "      \\verb{${vfield}raw}\n";
        $acc .= "      \\verb $vf\n      \\endverb\n";
        # Unicode NFC boundary (before hex encoding)
        $vf = URI->new(NFC($vf))->as_string;
      }
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

      # Raw URL list - special case
      if ($dm->get_datatype($vlist) eq 'uri') {
        $acc .= "      \\lverb{${vlist}raw}{$total}\n";
        foreach my $f ($vlf->@*) {
          $acc .= "      \\lverb $f\n";
        }
        $acc .= "      \\endlverb\n";
      }

      $acc .= "      \\lverb{$vlist}{$total}\n";
      foreach my $f ($vlf->@*) {
        # Encode URL lists
        if ($dm->get_datatype($vlist) eq 'uri') {
          # Unicode NFC boundary (before hex encoding)
          $f = URI->new(NFC($f))->as_string;
        }
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
    foreach my $n (Biber::Annotation->get_annotations('field', $key, $f)) {
      my $v = Biber::Annotation->get_annotation('field', $key, $f, $n);
      my $l = Biber::Annotation->is_literal_annotation('field', $key, $f, $n);
      $acc .= "      \\annotation{field}{$f}{$n}{}{}{$l}{$v}\n";
    }
  }

  foreach my $f (Biber::Annotation->get_annotated_fields('item', $key)) {
    foreach my $n (Biber::Annotation->get_annotations('item', $key, $f)) {
      foreach my $c (Biber::Annotation->get_annotated_items('item', $key, $f, $n)) {
        my $v = Biber::Annotation->get_annotation('item', $key, $f, $n, $c);
        my $l = Biber::Annotation->is_literal_annotation('item', $key, $f, $n, $c);
        $acc .= "      \\annotation{item}{$f}{$n}{$c}{}{$l}{$v}\n";
      }
    }
  }

  foreach my $f (Biber::Annotation->get_annotated_fields('part', $key)) {
    foreach my $n (Biber::Annotation->get_annotations('part', $key, $f)) {
      foreach my $c (Biber::Annotation->get_annotated_items('part', $key, $f, $n)) {
        foreach my $p (Biber::Annotation->get_annotated_parts('part', $key, $f, $n, $c)) {
          my $v = Biber::Annotation->get_annotation('part', $key, $f, $n, $c, $p);
          my $l = Biber::Annotation->is_literal_annotation('part', $key, $f, $n, $c, $p);
          $acc .= "      \\annotation{part}{$f}{$n}{$c}{$p}{$l}{$v}\n";
        }
      }
    }
  }

  # Append any warnings to the entry, if any
  if (my $w = $be->get_field('warnings')) {
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

  if (not $target or $target_string eq '-') {
    my $enc_out;
    if (Biber::Config->getoption('output_encoding')) {
      $enc_out = ':encoding(' . Biber::Config->getoption('output_encoding') . ')';
  }
    $target = new IO::File ">-$enc_out";
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
    # but omit global sort lists so that we can add them last
    foreach my $list (sort {$a->get_sortingtemplatename cmp $b->get_sortingtemplatename} $Biber::MASTER->datalists->get_lists_for_section($secnum)->@*) {
      if ($list->get_sortingtemplatename eq Biber::Config->getblxoption(undef, 'sortingtemplatename') and
          $list->get_type eq 'entry') {
        next;
      }
      push @lists, $list;
    }

    # biblatex requires the last list in the .bbl to be the global sort list
    # due to its sequential reading of the .bbl as the final list overrides the
    # previously read ones and the global list determines the order of labelnumber
    # and sortcites etc. when not using defernumbers
    push @lists, $Biber::MASTER->datalists->get_lists_by_attrs(section => $secnum,
                                                               type    => 'entry',
                                                               sortingtemplatename => Biber::Config->getblxoption(undef, 'sortingtemplatename'))->@*;

    foreach my $list (@lists) {
      next unless $list->count_keys; # skip empty lists
      my $listtype = $list->get_type;
      my $listname = $list->get_name;

      if ($logger->is_debug()) {# performance tune
        $logger->debug("Writing entries in '$listname' list of type '$listtype'");
      }

      out($target, "  \\datalist[$listtype]{$listname}\n");

      # The order of this array is the sorted order
      foreach my $k ($list->get_keys->@*) {
        if ($logger->is_debug()) {# performance tune
          $logger->debug("Writing entry for key '$k'");
        }

        my $entry = $data->{ENTRIES}{$secnum}{index}{$k};

        # Instantiate any dynamic, list specific entry information
        my $entry_string = $list->instantiate_entry($section, $entry, $k);

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
          $entry_string = "    % sorting key for '$k':\n    % " . $list->get_sortdata_for_key($k)->[0] . "\n" . $entry_string;
        }

        # Now output
        out($target, $entry_string);
      }

      out($target, "  \\enddatalist\n");

    }

    # Aliases
    # Use sort to guarantee deterministic order for things like latexmk
    foreach my $ks (sort keys $data->{ALIAS_ENTRIES}{$secnum}{index}->%*) {
      out($target, $data->{ALIAS_ENTRIES}{$secnum}{index}{$ks}->$*);
    }

    # Missing keys
    # Use sort to guarantee deterministic order for things like latexmk
    foreach my $ks (sort keys $data->{MISSING_ENTRIES}{$secnum}{index}->%*) {
      out($target, $data->{MISSING_ENTRIES}{$secnum}{index}{$ks}->$*);
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
