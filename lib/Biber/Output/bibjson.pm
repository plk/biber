package Biber::Output::bibjson;
use v5.24;
use strict;
use warnings;
use parent qw(Biber::Output::base);

use Biber::Annotation;
use Biber::Config;
use Biber::Constants;
use Biber::Utils;
use List::AllUtils qw( :all );
use Encode;
use IO::File;
use JSON::Streaming::Writer;
use Log::Log4perl qw( :no_extra_logdie_message );
use Unicode::Normalize;
my $logger = Log::Log4perl::get_logger('main');

=encoding utf-8

=head1 NAME

Biber::Output::bibjson - class for bibjson output
https://okfnlabs.org/bibjson/

=cut


=head2 new

    Initialize a Biber::Output::bibjson object

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

  return $self;
}


=head2 set_output_target_file

    Set the output target file of a Biber::Output::bibjson object
    A convenience around set_output_target so we can keep track of the
    filename

=cut

sub set_output_target_file {
  my ($self, $toolfile, $init) = @_;

  # bibjson output is only in tool mode and so we are looking at a data source name in
  # $ARGV[0]

  $self->{output_target_file} = $toolfile;

  # Initialise any output object like an JSON writer
  if ($init) {
    my $of;
    if ($toolfile eq '-') {
      open($of, '>&:encoding(UTF-8)', STDOUT);
    }
    else {
      $of = IO::File->new($toolfile, '>:encoding(UTF-8)');
    }
    $of->autoflush;             # Needed for running tests to string refs

    my $json = JSON::Streaming::Writer->for_stream($of);
    $json->pretty_output(1);
    $json->start_array();
    return $json;
  }
  return;
}

=head2 set_output_entry

  Set the output for an entry

=cut

sub set_output_entry {
  my ($self, $be, $section, $dm) = @_;
  my $bee = $be->get_field('entrytype');
  my $dmh = Biber::Config->get_dm_helpers;
  my $secnum = $section->number;
  my $key = $be->get_field('citekey');
  my $json = $self->{output_target};

  $json->start_object();
  $json->add_property("id" => NFC($key));
  $json->add_property("type" => NFC($bee));

  # Filter aliases which point to this key and insert them
  if (my @ids = sort grep {$section->get_citekey_alias($_) eq $key} $section->get_citekey_aliases) {
    $json->start_property("ids");
    $json->start_array();
    foreach my $id (@ids) {
      $json->add_string(NFC($id));
    }
    $json->end_array();
    $json->end_property();# ids
  }

  # If CROSSREF and XDATA have been resolved, don't output them
  # We can't use the usual skipout test for fields not to be output
  # as this only refers to .bbl output and not to biblatexml output since this
  # latter is not really a "processed" output, it is supposed to be something
  # which could be again used as input and so we don't want to resolve/skip
  # fields like DATE etc.
  # This only applies to the XDATA field as more granular XDATA will already
  # have/have not been resolved on the basis of this variable
  unless (Biber::Config->getoption('output_resolve_xdata')) {
    if (my $xdata = $be->get_field('xdata')) {
      $json->start_property("xdata");
      $json->start_array();
      foreach my $xd ($xdata->@*) {
        $json->add_property("xdatum" => NFC($xd));
      }
      $json->end_array();
      $json->end_property();# xdata
    }
  }
  unless (Biber::Config->getoption('output_resolve_crossrefs')) {
    if (my $crossref = $be->get_field('crossref')) {
      $json->add_property("crossref" => NFC($crossref));
    }
  }

  # Per-entry options
  my %entryoptions;
  foreach my $opt (Biber::Config->getblxentryoptions($secnum, $key)) {
    $entryoptions{$opt} = Biber::Config->getblxoption($secnum, $opt, undef, $key);
  }
  if (%entryoptions) {
    $json->start_property('options');
    $json->start_object();
    while (my ($option, $val) = each %entryoptions) {
      $json->add_property($option => NFC($val));
    }
    $json->end_object();
    $json->end_property();# options
  }

  # Output name fields
  foreach my $namefield ($dm->get_fields_of_type('list', 'name')->@*) {

    # Name loop
    if (my $nf = $be->get_field($namefield)) {

      $json->start_property($namefield);
      $json->start_object();

      # XDATA is special
      if (not Biber::Config->getoption('output_resolve_xdata') or
         not $be->is_xdata_resolved($namefield)) {
        if (my $xdata = $nf->get_xdata) {
          $json->add_property('xdata' => NFC(xdatarefout($xdata, 1)));
          $json->end_object();
          next;
        }
      }

      my %attrs;

      # Did we have "and others" in the data?
      if ( $nf->get_morenames ) {
        $attrs{morenames} = 1;
      }

      # Add per-namelist options
      foreach my $nlo (keys $CONFIG_SCOPEOPT_BIBLATEX{NAMELIST}->%*) {
        if (defined($nf->${\"get_$nlo"})) {
          my $nlov = $nf->${\"get_$nlo"};

          if ($CONFIG_BIBLATEX_OPTIONS{NAMELIST}{$nlo}{OUTPUT}) {
            $attrs{$nlo} = map_boolean($nlo, $nlov, 'tostring');
          }
        }
      }

      if (%attrs) {
        $json->start_property('options');
        $json->start_object();
        while (my ($option, $val) = each %attrs) {
          $json->add_property($option => NFC($val));
        }
        $json->end_object();
        $json->end_property();
      }

      $json->start_property('value');
      $json->start_array();

      for (my $i = 0; $i <= $nf->names->$#*; $i++) {
        my $n = $nf->names->[$i];

        # XDATA is special
        if (not Biber::Config->getoption('output_resolve_xdata') or
           not $be->is_xdata_resolved($namefield, $i+1)) {
          if (my $xdata = $n->get_xdata) {
            $json->add_property('xdata' => NFC(xdatarefout($xdata, 1)));
            next;
          }
        }

        $json->start_object();
        $n->name_to_bibjson($self, $json, $key, $namefield, $n->get_index);
        $json->end_object();
      }

      $json->end_array();
      $json->end_property();
      $json->end_object();
      $json->end_property();
    }
  }

  # Output list fields
  foreach my $listfield (sort $dm->get_fields_of_fieldtype('list')->@*) {
    next if $dm->field_is_datatype('name', $listfield); # name is a special list

    # List loop
    if (my $lf = $be->get_field($listfield)) {

      $json->start_property($listfield);
      $json->start_object();

      # XDATA is special
      if (not Biber::Config->getoption('output_resolve_xdata') or
          not $be->is_xdata_resolved($listfield)) {
        if (my $val = xdatarefcheck($lf, 1)) {
          $json->add_property('xdata' => NFC(xdatarefout($val, 1)));
          $json->end_object();
          next;
        }
      }

      my %attrs;
      # Did we have a "more" list?
      if (lc($lf->[-1]) eq Biber::Config->getoption('others_string') ) {
        $attrs{morelist} = 1;
        pop $lf->@*;               # remove the last element in the array
      }

      if (%attrs) {
        $json->start_property('options');
        $json->start_object();
        while (my ($option, $val) = each %attrs) {
          $json->add_property($option => NFC($val));
        }

        $json->end_object();
        $json->end_property();
      }

      $json->start_property('value');
      $json->start_array();

      # List loop
      my $itemcount = 1;

      for (my $i = 0; $i <= $lf->$#*; $i++) {
        my $f = $lf->[$i];

        # XDATA is special
        if (not Biber::Config->getoption('output_resolve_xdata') or
            not $be->is_xdata_resolved($listfield, $i+1)) {
          if (my $val = xdatarefcheck($f, 1)) {
            $json->start_object();
            $json->add_property('xdata' => NFC(xdatarefout($val, 1)));
            $json->end_object();
            next;
          }
        }

        $json->add_string(NFC($f));
      }

      $json->end_array();
      $json->end_property();
      $json->end_object();
      $json->end_property();
    }
  }

  # Standard fields
  foreach my $field (sort $dm->get_fields_of_type('field',
                                                  ['entrykey',
                                                   'key',
                                                   'literal',
                                                   'code',
                                                   'integer',
                                                   'verbatim',
                                                   'uri'])->@*) {
    my $val = $be->get_field($field);

    # XDATA is special
    if (not Biber::Config->getoption('output_resolve_xdata') or
        not $be->is_xdata_resolved($field)) {

      if (my $xval = xdatarefcheck($val, 1)) {
        $json->start_property($field);
        $json->start_object();
        $json->add_property('xdata' => NFC($xval));
        $json->end_object();
        $json->end_property();
        next;
      }
    }

    if (length($val) or # length() catches '0' values, which we want
      ($dm->field_is_nullok($field) and
       $be->field_exists($field))) {
      next if $dm->get_fieldformat($field) eq 'xsv';
      next if $field eq 'crossref'; # this is handled above

      $json->add_property($field => NFC($val));
    }
  }

  # xsv fields
  foreach my $xsvf ($dm->get_fields_of_type('field', 'xsv')->@*) {
    if (my $f = $be->get_field($xsvf)) {
      next if $xsvf eq 'ids'; # IDS is special
      next if $xsvf eq 'xdata'; # XDATA is special

      # XDATA is special
      if (not Biber::Config->getoption('output_resolve_xdata') or
          not $be->is_xdata_resolved($xsvf)) {
        if (my $val = xdatarefcheck($f, 1)) {
          $json->start_property($xsvf);
          $json->start_object();
          $json->add_property('xdata' => NFC($val));
          $json->end_object();
          next;
        }
      }

      $json->add_property($xsvf => NFC(join(',', $f->@*)));
    }
  }

  # Range fields
  foreach my $rfield (sort $dm->get_fields_of_datatype('range')->@*) {
    if ( my $rf = $be->get_field($rfield) ) {

      $json->start_property($rfield);

      # XDATA is special
      if (not Biber::Config->getoption('output_resolve_xdata') or
          not $be->is_xdata_resolved($rfield)) {
        if (my $val = xdatarefcheck($rf, 1)) {
          $json->start_object();
          $json->add_property('xdata' => NFC($val));
          $json->end_object();
          next;
        }
      }

      $json->start_array();

      # range fields are an array ref of two-element array refs [range_start, range_end]
      # range_end can be be empty for open-ended range or undef

      foreach my $f ($rf->@*) {
        if (defined($f->[1])) {
          $json->start_object();
          $json->add_property('start' => NFC($f->[0]));
          $json->add_property('end' => NFC($f->[1]));
          $json->end_object();
        }
        else {
          $json->add_string(NFC($f->[0]));
        }
      }
      $json->end_array();
      $json->end_property();
    }
  }

  # Date fields
  my %dinfo;
  foreach my $datefield (sort $dm->get_fields_of_datatype('date')->@*) {
    my @attrs;
    my @start;
    my @end;
    my $overridey;
    my $overridem;
    my $overrideem;
    my $overrided;

    my ($d) = $datefield =~ m/^(.*)date$/;
    if (my $sf = $be->get_field("${d}year") ) { # date exists if there is a year

      $json->start_property("${d}date");

      # Uncertain and approximate dates
      if ($be->get_field("${d}dateuncertain") and
          $be->get_field("${d}dateapproximate")) {
        $sf .= '%';
      }
      else {
        # Uncertain dates
        if ($be->get_field("${d}dateuncertain")) {
          $sf .= '?';
        }

        # Approximate dates
        if ($be->get_field("${d}dateapproximate")) {
          $sf .= '~';
        }
      }

      # Unknown dates
      if ($be->get_field("${d}dateunknown")) {
        $sf = 'unknown';
      }

      my %yeardivisions = ( 'spring'  => 21,
                            'summer'  => 22,
                            'autumn'  => 23,
                            'winter'  => 24,
                            'springN' => 25,
                            'summerN' => 26,
                            'autumnN' => 27,
                            'winterN' => 28,
                            'springS' => 29,
                            'summerS' => 30,
                            'autumnS' => 31,
                            'WinterS' => 32,
                            'Q1'      => 33,
                            'Q2'      => 34,
                            'Q3'      => 35,
                            'Q4'      => 36,
                            'QD1'     => 37,
                            'QD2'     => 38,
                            'QD3'     => 39,
                            'S1'      => 40,
                            'S2'      => 41 );

      # Did the date fields come from interpreting an ISO8601-2 unspecified date?
      # If so, do the reverse of Biber::Utils::parse_date_unspecified()
      if (my $unspec = $be->get_field("${d}dateunspecified")) {

        # 1990/1999 -> 199X
        if ($unspec eq 'yearindecade') {
          my ($decade) = $be->get_field("${d}year") =~ m/^(\d+)\d$/;
          $overridey = "${decade}X";
          $be->del_field("${d}endyear");
        }
        # 1900/1999 -> 19XX
        elsif ($unspec eq 'yearincentury') {
          my ($century) = $be->get_field("${d}year") =~ m/^(\d+)\d\d$/;
          $overridey = "${century}XX";
          $be->del_field("${d}endyear");
        }
        # 1999-01/1999-12 => 1999-XX
        elsif ($unspec eq 'monthinyear') {
          $overridem = 'XX';
          $be->del_field("${d}endyear");
          $be->del_field("${d}endmonth");
        }
        # 1999-01-01/1999-01-31 -> 1999-01-XX
        elsif ($unspec eq 'dayinmonth') {
          $overrided = 'XX';
          $be->del_field("${d}endyear");
          $be->del_field("${d}endmonth");
          $be->del_field("${d}endday");
        }
        # 1999-01-01/1999-12-31 -> 1999-XX-XX
        elsif ($unspec eq 'dayinyear') {
          $overridem = 'XX';
          $overrided = 'XX';
          $be->del_field("${d}endyear");
          $be->del_field("${d}endmonth");
          $be->del_field("${d}endday");
        }
      }

      # Seasons derived from EDTF dates
      if (my $s = $be->get_field("${d}yeardivision")) {
        $overridem = $yeardivisions{$s};
      }
      if (my $s = $be->get_field("${d}endyeardivision")) {
        $overrideem = $yeardivisions{$s};
      }
      $sf = $overridey || $sf;

      # strip undefs
      push @start,
        grep {$_}
          $sf,
            date_monthday($overridem || $be->get_field("${d}month")),
              date_monthday($overrided || $be->get_field("${d}day"));
      push @end,
        grep {defined($_)} # because end can be def but empty
          $be->get_field("${d}endyear"),
            date_monthday($overrideem || $be->get_field("${d}endmonth")),
              date_monthday($be->get_field("${d}endday"));
      # Date range
      if (@end) {
        $json->start_object();

        my $start = NFC(join('-', @start));
        my $end = NFC(join('-', @end));

        # If start hour, there must be minute and second
        if (my $sh = $be->get_field("${d}hour")) {
          $start .= NFC('T' . sprintf('%.2d', $sh) . ':' .
            sprintf('%.2d', $be->get_field("${d}minute")) . ':' .
              sprintf('%.2d', $be->get_field("${d}second")));
        }

        # start timezone
        if (my $stz = $be->get_field("${d}timezone")) {
          $stz =~ s/\\bibtzminsep\s+/:/;
          $start .= NFC($stz);
        }

        # If end hour, there must be minute and second
        if (my $eh = $be->get_field("${d}endhour")) {
          $end .= NFC('T' . sprintf('%.2d', $eh) . ':' .
            sprintf('%.2d', $be->get_field("${d}endminute")) . ':' .
              sprintf('%.2d', $be->get_field("${d}endsecond")));
        }

        # end timezone
        if (my $etz = $be->get_field("${d}endtimezone")) {
          $etz =~ s/\\bibtzminsep\s+/:/;
          $end .= NFC($etz);
        }

        $json->add_property('start' => $start);
        $json->add_property('end' => $end);
        $json->end_object();
      }
      else { # simple date
        my $sd;
        $sd .= join('-', @start);

        # If start hour, there must be minute and second
        if (my $sh = $be->get_field("${d}hour")) {
          $sd .= 'T' . sprintf('%.2d', $sh) . ':' .
            sprintf('%.2d', $be->get_field("${d}minute")) . ':' .
              sprintf('%.2d', $be->get_field("${d}second"));
        }

        # start timezone
        if (my $stz = $be->get_field("${d}timezone")) {
          $stz =~ s/\\bibtzminsep\s+/:/;
          $sd .= $stz;
        }
        $json->add_string(NFC($sd));
      }
      $json->end_property();
    }
  }

  # Annotations
  foreach my $f (Biber::Annotation->get_annotated_fields('field', $key)) {
    foreach my $n (Biber::Annotation->get_annotations('field', $key, $f)) {
      my $v = Biber::Annotation->get_annotation('field', $key, $f, $n);
      my $l = Biber::Annotation->is_literal_annotation('field', $key, $f, $n);
      $json->start_property('annotation');
      $json->start_object();
      $json->add_property('value' => $v);
      $json->add_property('field' => $f);
      $json->add_property('name' => $n);
      $json->start_property('literal');
      $json->add_boolean($l);
      $json->end_property();
      $json->end_object();
      $json->end_property();
    }
  }

  foreach my $f (Biber::Annotation->get_annotated_fields('item', $key)) {
    foreach my $n (Biber::Annotation->get_annotations('item', $key, $f)) {
      foreach my $c (Biber::Annotation->get_annotated_items('item', $key, $f, $n)) {
        my $v = Biber::Annotation->get_annotation('item', $key, $f, $n, $c);
        my $l = Biber::Annotation->is_literal_annotation('item', $key, $f, $n, $c);
        $json->start_property('annotation');
        $json->start_object();
        $json->add_property('value' => $v);
        $json->add_property('field' => $f);
        $json->add_property('name' => $n);
        $json->add_property('item' => $c);
        $json->start_property('literal');
        $json->add_boolean($l);
        $json->end_property();
        $json->end_object();
        $json->end_property();
      }
    }
  }

  foreach my $f (Biber::Annotation->get_annotated_fields('part', $key)) {
    foreach my $n (Biber::Annotation->get_annotations('part', $key, $f)) {
      foreach my $c (Biber::Annotation->get_annotated_items('part', $key, $f, $n)) {
        foreach my $p (Biber::Annotation->get_annotated_parts('part', $key, $f, $n, $c)) {
          my $v = Biber::Annotation->get_annotation('part', $key, $f, $n, $c, $p);
          my $l = Biber::Annotation->is_literal_annotation('part', $key, $f, $n, $c, $p);
          $json->start_property('annotation');
          $json->start_object();
          $json->add_property('value' => $v);
          $json->add_property('field' => $f);
          $json->add_property('name' => $n);
          $json->add_property('item' => $c);
          $json->add_property('part' => $p);
          $json->start_property('literal');
          $json->add_boolean($l);
          $json->end_property();
          $json->end_object();
          $json->end_property();
        }
      }
    }
  }

  $json->end_object();

  return;
}

=head2 output

    Tool output method

=cut

sub output {
  my $self = shift;
  my $data = $self->{output_data};
  my $json = $self->{output_target};
  my $target_string = "Target"; # Default
  my $dm = Biber::Config->get_dm;
  if ($self->{output_target_file}) {
    $target_string = $self->{output_target_file};
  }

  if ($logger->is_debug()) {# performance tune
    $logger->debug('Preparing final output using class ' . __PACKAGE__ . '...');
    $logger->debug("Writing entries in tool mode");
  }
  $json->end_array();

  $logger->info("Output to $target_string");
  my $exts = join('|', values %DS_EXTENSIONS);
  my $schemafile = Biber::Config->getoption('dsn') =~ s/\.(?:$exts)$/.json/r;

  # Generate schema to accompany output
  # unless (Biber::Config->getoption('no_bibjson_schema')) {
  #   $dm->generate_bibjson_schema($schemafile);
  # }

  if (Biber::Config->getoption('validate_bibjson')) {
    validate_biber_json($target_string, $schemafile);
  }

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

  # We rely on the order of this array for the order of the output
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

Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our Github tracker at
L<https://github.com/plk/biber/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2012 François Charette and Philip Kime, all rights reserved.
Copyright 2012-2022 Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
