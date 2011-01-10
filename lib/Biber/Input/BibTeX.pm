package Biber::Input::BibTeX;
use sigtrap qw(handler TBSIG SEGV);
use strict;
use warnings;
use Carp;

use Text::BibTeX 0.42 qw(:nameparts :joinmethods :metatypes);
use Text::BibTeX::Name;
use Text::BibTeX::NameFormat;
use Biber::Constants;
use Biber::Entries;
use Biber::Entry;
use Biber::Entry::Names;
use Biber::Entry::Name;
use Biber::Sections;
use Biber::Section;
use Biber::Structure;
use Biber::Utils;
use Biber::Config;
use Encode;
use File::Spec;
use Log::Log4perl qw(:no_extra_logdie_message);
use base 'Exporter';
use List::AllUtils qw(first);

my $logger = Log::Log4perl::get_logger('main');

our @EXPORT = qw{ parsename };

=head2 TBSIG

     Signal handler to catch fatal Text::BibTex SEGFAULTS. It has bugs
     and we want to say at least something when it coredumps

=cut

sub TBSIG {
  my $sig = shift;
    $logger->logcroak("Caught signal: $sig\nLikely your .bib has a bad entry: $!");
}


=head2 parsename

    Given a name string, this function returns a Biber::Entry::Name object
    with all parts of the name resolved according to the BibTeX conventions.

    parsename('John Doe')
    returns an object which internally looks a bit like this:

    { firstname     => 'John',
      firstname_i   => 'J.',
      firstname_it  => 'J',
      lastname      => 'Doe',
      lastname_i    => 'D.',
      lastname_it   => 'D',
      prefix        => undef,
      prefix_i      => undef,
      prefix_it     => undef,
      suffix        => undef,
      suffix_i      => undef,
      suffix_it     => undef,
      namestring    => 'Doe, John',
      nameinitstring => 'Doe_J',
      strip          => {'firstname' => 0,
                         'lastname'  => 0,
                         'prefix'    => 0,
                         'suffix'    => 0}
      }

=cut

sub parsename {
  my ($namestr, $fieldname, $opts) = @_;
  $logger->debug("   Parsing namestring '$namestr'");
  my $usepre = $opts->{useprefix};
  # First sanitise the namestring due to Text::BibTeX::Name limitations on whitespace
  $namestr =~ s/\A\s*//xms; # leading whitespace
  $namestr =~ s/\s*\z//xms; # trailing whitespace
  $namestr =~ s/\s+/ /g;    # Collapse internal whitespace

  open OLDERR, '>&', \*STDERR;
  open STDERR, '>', '/dev/null';
  my $name = new Text::BibTeX::Name($namestr);
  open STDERR, '>&', \*OLDERR;

  # Formats so we can get BibTeX compatible nbsp inserted
  # We can't use formats to get initials as Text::BibTeX < 0.42 as it
  # has a problem dealing with braced names when extracting initials
  my $l_f = new Text::BibTeX::NameFormat('l', 0);
  my $f_f = new Text::BibTeX::NameFormat('f', 0);
  my $p_f = new Text::BibTeX::NameFormat('v', 0);
  my $s_f = new Text::BibTeX::NameFormat('j', 0);
  $l_f->set_options(BTN_LAST,  0, BTJ_MAYTIE, BTJ_NOTHING);
  $f_f->set_options(BTN_FIRST, 0, BTJ_MAYTIE, BTJ_NOTHING);
  $p_f->set_options(BTN_VON,   0, BTJ_MAYTIE, BTJ_NOTHING);
  $s_f->set_options(BTN_JR,    0, BTJ_MAYTIE, BTJ_NOTHING);

  # Generate name parts
  my $lastname  = decode_utf8($name->format($l_f));
  my $firstname = decode_utf8($name->format($f_f));
  my $prefix    = decode_utf8($name->format($p_f));
  my $suffix    = decode_utf8($name->format($s_f));

  # Variables to hold either the Text::BibTeX::NameFormat generated initials
  # or our own generated ones in case we are using a broken version of Text::BibTeX
  my $gen_lastname_i;
  my $gen_lastname_it;
  my $gen_firstname_i;
  my $gen_firstname_it;
  my $gen_prefix_i;
  my $gen_prefix_it;
  my $gen_suffix_i;
  my $gen_suffix_it;

  # Use a copy of $name so that when we generate the
  # initials, we do so without diacritics. This is easier than trying
  # hack the diacritics code into btparse ...

  # Initials formats
  my $li_f = new Text::BibTeX::NameFormat('l', 1);
  my $fi_f = new Text::BibTeX::NameFormat('f', 1);
  my $pi_f = new Text::BibTeX::NameFormat('v', 1);
  my $si_f = new Text::BibTeX::NameFormat('j', 1);

  # Truncated initials formats
  my $lit_f = new Text::BibTeX::NameFormat('l', 1);
  my $fit_f = new Text::BibTeX::NameFormat('f', 1);
  my $pit_f = new Text::BibTeX::NameFormat('v', 1);
  my $sit_f = new Text::BibTeX::NameFormat('j', 1);

  # first name doesn't need this customisation as it's automatic for
  # an abbreviated first name format but we'll do it anyway for consistency
  my $nd_name = new Text::BibTeX::Name(strip_nosort($namestr, $fieldname));

  # Period following normal initials
  $li_f->set_text(BTN_LAST,  undef, undef, undef, '.');
  $fi_f->set_text(BTN_FIRST, undef, undef, undef, '.');
  $pi_f->set_text(BTN_VON,   undef, undef, undef, '.');
  $si_f->set_text(BTN_JR,    undef, undef, undef, '.');
  $li_f->set_options(BTN_LAST,  1, BTJ_MAYTIE, BTJ_NOTHING);
  $fi_f->set_options(BTN_FIRST, 1, BTJ_MAYTIE, BTJ_NOTHING);
  $pi_f->set_options(BTN_VON,   1, BTJ_MAYTIE, BTJ_NOTHING);
  $si_f->set_options(BTN_JR,    1, BTJ_MAYTIE, BTJ_NOTHING);

  # Nothing following truncated initials
  $lit_f->set_text(BTN_LAST,  undef, undef, undef, '');
  $fit_f->set_text(BTN_FIRST, undef, undef, undef, '');
  $pit_f->set_text(BTN_VON,   undef, undef, undef, '');
  $sit_f->set_text(BTN_JR,    undef, undef, undef, '');
  $lit_f->set_options(BTN_LAST,  1, BTJ_NOTHING, BTJ_NOTHING);
  $fit_f->set_options(BTN_FIRST, 1, BTJ_NOTHING, BTJ_NOTHING);
  $pit_f->set_options(BTN_VON,   1, BTJ_NOTHING, BTJ_NOTHING);
  $sit_f->set_options(BTN_JR,    1, BTJ_NOTHING, BTJ_NOTHING);

  $gen_lastname_i    = decode_utf8($nd_name->format($li_f));
  $gen_lastname_it   = decode_utf8($nd_name->format($lit_f));
  $gen_firstname_i   = decode_utf8($nd_name->format($fi_f));
  $gen_firstname_it  = decode_utf8($nd_name->format($fit_f));
  $gen_prefix_i      = decode_utf8($nd_name->format($pi_f));
  $gen_prefix_it     = decode_utf8($nd_name->format($pit_f));
  $gen_suffix_i      = decode_utf8($nd_name->format($si_f));
  $gen_suffix_it     = decode_utf8($nd_name->format($sit_f));

  # Only warn about lastnames since there should always be one
  $logger->warn("Couldn't determine Last Name for name \"$namestr\"") unless $lastname;

  my $namestring = '';
  # prefix
  my $ps;
  my $prefix_stripped;
  my $prefix_i;
  my $prefix_it;
  if ($prefix) {
    $prefix_i        = $gen_prefix_i;
    $prefix_it       = $gen_prefix_it;
    $prefix_stripped = remove_outer($prefix);
    $ps = $prefix ne $prefix_stripped ? 1 : 0;
    $namestring .= "$prefix_stripped ";
  }
  # lastname
  my $ls;
  my $lastname_stripped;
  my $lastname_i;
  my $lastname_it;
  if ($lastname) {
    $lastname_i        = $gen_lastname_i;
    $lastname_it       = $gen_lastname_it;
    $lastname_stripped = remove_outer($lastname);
    $ls = $lastname ne $lastname_stripped ? 1 : 0;
    $namestring .= "$lastname_stripped, ";
  }
  # suffix
  my $ss;
  my $suffix_stripped;
  my $suffix_i;
  my $suffix_it;
  if ($suffix) {
    $suffix_i        = $gen_suffix_i;
    $suffix_it       = $gen_suffix_it;
    $suffix_stripped = remove_outer($suffix);
    $ss = $suffix ne $suffix_stripped ? 1 : 0;
    $namestring .= "$suffix_stripped, ";
  }
  # firstname
  my $fs;
  my $firstname_stripped;
  my $firstname_i;
  my $firstname_it;
  if ($firstname) {
    $firstname_i        = $gen_firstname_i;
    $firstname_it       = $gen_firstname_it;
    $firstname_stripped = remove_outer($firstname);
    $fs = $firstname ne $firstname_stripped ? 1 : 0;
    $namestring .= "$firstname_stripped";
  }

  # Remove any trailing comma and space if, e.g. missing firstname
  # Replace any nbspes
  $namestring =~ s/,\s+\z//xms;
  $namestring =~ s/~/ /gxms;

  # Construct $nameinitstring
  my $nameinitstr = '';
  $nameinitstr .= $prefix_it . '_' if ( $usepre and $prefix );
  $nameinitstr .= $lastname if $lastname;
  $nameinitstr .= '_' . $suffix_it if $suffix;
  $nameinitstr .= '_' . $firstname_it if $firstname;
  $nameinitstr =~ s/\s+/_/g;
  $nameinitstr =~ s/~/_/g;

  # The "strip" entry tells us which of the name parts had outer braces
  # stripped during processing so we can add them back when printing the
  # .bbl so as to maintain maximum BibTeX compatibility
  return Biber::Entry::Name->new(
    firstname       => $firstname      eq '' ? undef : $firstname_stripped,
    firstname_i     => $firstname      eq '' ? undef : $firstname_i,
    firstname_it    => $firstname      eq '' ? undef : $firstname_it,
    lastname        => $lastname       eq '' ? undef : $lastname_stripped,
    lastname_i      => $lastname       eq '' ? undef : $lastname_i,
    lastname_it     => $lastname       eq '' ? undef : $lastname_it,
    prefix          => $prefix         eq '' ? undef : $prefix_stripped,
    prefix_i        => $prefix         eq '' ? undef : $prefix_i,
    prefix_it       => $prefix         eq '' ? undef : $prefix_it,
    suffix          => $suffix         eq '' ? undef : $suffix_stripped,
    suffix_i        => $suffix         eq '' ? undef : $suffix_i,
    suffix_it       => $suffix         eq '' ? undef : $suffix_it,
    namestring      => $namestring,
    nameinitstring  => $nameinitstr,
    strip           => {'firstname' => $fs,
                        'lastname'  => $ls,
                        'prefix'    => $ps,
                        'suffix'    => $ss}
    );
}

sub _text_bibtex_parse {
  my ($self, $filename) = @_;
  my $secnum = $self->get_current_section;
  my $section = $self->sections->get_section($secnum);
  my $struc = Biber::Config->get_structure;

  my $basefilename = $filename;
  $basefilename =~ s/\.utf8$//;

  # Text::BibTeX can't be controlled by Log4perl so we have to do something clumsy
  if (Biber::Config->getoption('quiet')) {
    open OLDERR, '>&', \*STDERR;
    open STDERR, '>', '/dev/null';
  }

  my $bibentries = $section->bibentries;

  my @localkeys;

  my $bib = Text::BibTeX::File->new( $filename, '<' )
    or $logger->logcroak("Cannot create Text::BibTeX::File object from $filename: $!");

  my @preamble = ();
  my $count = 0;

BIBLOOP:  while ( my $entry = new Text::BibTeX::Entry $bib ) {
    $count++;

    if ( $entry->metatype == BTE_PREAMBLE ) {
      # Only push the preambles from the file if we haven't seen this data file before
      unless ($BIBER_DATAFILE_REFS{$basefilename} > 1) {
        push @preamble, decode_utf8($entry->value);
      }
      next;
    }

    next if ( $entry->metatype == BTE_MACRODEF or $entry->metatype == BTE_UNKNOWN
      or $entry->metatype == BTE_COMMENT );

    unless ( $entry->key ) {
      $logger->warn("Cannot get the key of entry no $count : Skipping");
      $self->{warnings}++;
      next;
    }

    # Text::BibTeX >= 0.46 passes through all citekey bits, thus allowing utf8 keys
    my $origkey = decode_utf8($entry->key);

    if (!defined $origkey or $origkey =~ /\s/ or $origkey eq '') {
      $logger->warn("Invalid BibTeX key! Skipping...");
      $self->{warnings}++;
      next;
    }

    # Want a version of the key that is the same case as any citations which
    # reference it, in case they are different. We use this as the .bbl
    # entry key
    my $citecasekey = first {lc($origkey) eq lc($_)} $section->get_citekeys;
    $citecasekey = $origkey unless $citecasekey;
    my $lc_key = lc($origkey);

    $logger->debug("Processing entry '$origkey'");

    if ( $bibentries->entry_exists($origkey) ) {
      $self->{errors}++;
      my (undef,undef,$f) = File::Spec->splitpath( $filename );
      $logger->warn("Repeated entry---key $origkey in file $f\nI'm skipping whatever remains of this entry");
      $self->{warnings}++;
      next;
    }

    push @localkeys, $lc_key;

    unless ($entry->parse_ok) {
      $self->{errors}++;
      $logger->warn("Entry $origkey does not parse correctly: skipping");
      $self->{warnings}++;
      next;
    }

    my $bibentry = new Biber::Entry;
    $bibentry->set_field('origkey', $origkey);
    $bibentry->set_field('citecasekey', $citecasekey);

    # all fields used for this entry
    my @flist = $entry->fieldlist;

    # here we only keep those that do not require splitting
    my @flistnosplit = reduce_array(\@flist, $struc->get_field_type('split'));

    if ( $entry->metatype == BTE_REGULAR ) {
      foreach my $f ( @flistnosplit ) {
        next unless $entry->exists($f);
        my $value = decode_utf8($entry->get($f));

        $bibentry->set_datafield($f, $value);

        # We have to process local options as early as possible in order
        # to make them available for things that need them like parsename()
        if (lc($f) eq 'options') {
          $self->process_entry_options($bibentry);
        }
      }

      # Set entrytype. This may be changed later in process_aliases
      $bibentry->set_field('entrytype', $entry->type);

      foreach my $f ( @{$struc->get_field_type('split')} ) {
        next unless $entry->exists($f);
        my @tmp = $entry->split($f);

        if ($struc->is_field_type('name', $f)) {
          my $useprefix = Biber::Config->getblxoption('useprefix', $bibentry->get_field('entrytype'), $lc_key);
          my $names = new Biber::Entry::Names;
          foreach my $name (@tmp) {

            # Consecutive "and" causes Text::BibTeX::Name to segfault
            unless ($name) {
              $logger->warn("Name in key '$origkey' is empty (probably consecutive 'and'): skipping name");
              $self->{errors}++;
              $section->del_citekey($origkey);
              next;
            }

            $name = decode_utf8($name);

            # Check for malformed names in names which aren't completely escaped

            # Too many commas
            unless ($name =~ m/\A{.+}\z/xms) { # Ignore these tests for escaped names
              my @commas = $name =~ m/,/g;
              if ($#commas > 1) {
                $logger->warn("Name \"$name\" has too many commas: skipping entry $origkey");
                $self->{errors}++;
                $section->del_citekey($origkey);
                next BIBLOOP;
              }

              # Consecutive commas cause Text::BibTeX::Name to segfault
              if ($name =~ /,,/) {
                $logger->warn("Name \"$name\" is malformed (consecutive commas): skipping entry $origkey");
                $self->{errors}++;
                $section->del_citekey($origkey);
                next BIBLOOP;
              }
            }

            $names->add_element(parsename($name, $f, {useprefix => $useprefix}));
          }
          $bibentry->set_datafield($f, $names);

        }
        else {
          # Name fields are decoded during parsing, others here
          @tmp = map { decode_utf8($_) } @tmp;
          @tmp = map { remove_outer($_) } @tmp;
          $bibentry->set_datafield($f, [ @tmp ]);
        }
      }

      $bibentry->set_field('datatype', 'bibtex');
      $bibentries->add_entry($lc_key, $bibentry);
    }
  }

  $bib->close;

  push @{$self->{preamble}}, @preamble if @preamble;

  if (Biber::Config->getoption('quiet')) {
    open STDERR, '>&', \*OLDERR;
  }

  return @localkeys;

}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Biber::Input::BibTeX - parse a bib database with Text::BibTeX

=head1 DESCRIPTION

Internal method ...

=head1 AUTHOR

François Charette, C<< <firmicus at gmx.net> >>
Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2011 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# vim: set tabstop=2 shiftwidth=2 expandtab:
