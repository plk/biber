package Biber::BibTeX::PRD;
use strict;
use warnings;
use Carp;
use Biber::Constants;
use Biber::Utils;
use Biber::Entries;
use Biber::Entry;
use Biber::Entry::Names;
use Biber::Entry::Name;
use Parse::RecDescent;
use Regexp::Common qw{ balanced };
use Biber::BibTeX::Parser;
use File::Spec;
use Encode;
use List::AllUtils qw(first);
use Log::Log4perl qw(:no_extra_logdie_message);
use base 'Exporter';

my $logger = Log::Log4perl::get_logger('main');

our @EXPORT = qw{ parsename };

=head2 parsename

    Given a name string, this function returns a Biber::Entry:Name object
    with all parts of the name resolved according to the BibTeX conventions.

    parsename('John Doe')
    returns an object which internally looks a bit like this:

    { firstname => 'John',
      lastname => 'Doe',
      prefix => undef,
      suffix => undef,
      namestring => 'Doe, John',
      nameinitstring => 'Doe_J' }

    parsename('von Berlichingen zu Hornberg, Johann G{\"o}tz')
    returns:

    { firstname => 'Johann G{\"o}tz',
      lastname => 'Berlichingen zu Hornberg',
      prefix => 'von',
      suffix => undef,
      namestring => 'Berlichingen zu Hornberg, Johann Gotz',
      nameinitstring => 'Berlichingen_zu_Hornberg_JG' }

=cut

sub parsename {
  my ($namestr, $opts) = @_;
  $logger->debug("   Parsing namestring '$namestr'");
  # Change small spaces to something else in the Unicode private zone
  # temporarily to make parsing easier. We rely on looking for commas
  # to parse names and latex small spaces confuse things a lot
  $namestr =~ s/\\,\s*|{\\,\s*}/{\x{e35a}}/g;
  my $usepre = $opts->{useprefix};

  my $lastname;
  my $firstname;
  my $prefix;
  my $suffix;
  my $nameinitstr;

  my $PREFIX_RE = qr/
                {?
                \p{Ll} # prefix starts with lowercase
                [^\p{Lu},]+ # e.g. van der
                }?
                \s+
/x ;
  my $NAME_RE = qr/
                [^,]+
               |
                $RE{balanced}{-parens=>'{}'}
/x;
  my $SUFFIX_RE = $NAME_RE;
  my $NAME_SEQ_RE = qr/ (?:(?:\p{Lu}\S*|{\p{Lu}\S*})[\s~]*)+ /x ;

  if ( $namestr =~ /^$RE{balanced}{-parens => '{}'}$/ )
  {
    $logger->debug("   Caught namestring of type '{Some protected name string}'");
    $namestr = remove_outer($namestr);
    $lastname = $namestr;
  }
  elsif ( $namestr =~ /[^\\],.+[^\\],/ )    # pre? Lastname, suffix, Firstname
  {
    $logger->debug("   Caught namestring of type 'prefix? Lastname, suffix, Firstname'");
    ( $prefix, $lastname, $suffix, $firstname ) = $namestr =~
      m/\A( # prefix?
                $PREFIX_RE
               )?
               ( # last name
                $NAME_RE
               )
               ,
               \s*
               ( # suffix
                $SUFFIX_RE
               )
               ,
               \s*
               ( # first name
                $NAME_RE
               )
\z/xms;

    $logger->warn("Couldn't determine Last Name for name \"$namestr\"") unless $lastname;
    $logger->warn("Couldn't determine First Name for name \"$namestr\"") unless $firstname;
    if ($lastname) {$lastname =~ s/^{(.+)}$/$1/g;}
    if ($firstname) {$firstname =~ s/^{(.+)}$/$1/g;}
    $prefix =~ s/\s+$// if $prefix;
    $prefix =~ s/^{(.+)}$/$1/ if $prefix;
    $suffix =~ s/\s+$//;
    $suffix =~ s/^{(.+)}$/$1/;
    $namestr = "";
    $namestr .= "$prefix " if ($prefix && $usepre);
    $namestr .= "$lastname, $suffix, $firstname";
  }
  elsif ( $namestr =~ /[^\\],/ )   # <pre> Lastname, Firstname
  {
    $logger->debug("   Caught namestring of type 'prefix? Lastname, Firstname'");

    ( $prefix, $lastname, $firstname ) = $namestr =~
      m/^( # prefix?
                $PREFIX_RE
               )?
               ( # last name
                $NAME_RE
               )
               ,
               \s*
               ( # first name
                $NAME_RE
               )
$/x;

    $logger->warn("Couldn't determine Last Name for name \"$namestr\"") unless $lastname;
    $logger->warn("Couldn't determine First Name for name \"$namestr\"") unless $firstname;
    if ($lastname) {$lastname =~ s/^{(.+)}$/$1/g;}
    if ($firstname) {$firstname =~ s/^{(.+)}$/$1/g;}
    $prefix =~ s/\s+$// if $prefix;
    $prefix =~ s/^{(.+)}$/$1/ if $prefix;
    $namestr = "";
    $namestr .= "$prefix " if ($prefix && $usepre);
    $namestr .= "$lastname, $firstname";
  }
  elsif ( $namestr =~ /\s/ ) # Firstname pre? Lastname
  {
    if ( $namestr =~ /^$RE{balanced}{-parens => '{}'}.*\s+$RE{balanced}{-parens => '{}'}$/ )
    {
      $logger->debug("   Caught namestring of type '{Firstname} prefix? {Lastname}'");
      ( $firstname, $prefix, $lastname ) = $namestr =~
        m/^( # first name
                    $RE{balanced}{-parens=>'{}'}
                )
                    \s+
                ( # prefix?
                    $PREFIX_RE
                )?
                ( # last name
                    $RE{balanced}{-parens=>'{}'}
                )
$/x;
    }
    elsif ( $namestr =~ /^.+\s+$RE{balanced}{-parens => '{}'}$/ )
    {
      $logger->debug("   Caught namestring of type 'Firstname prefix? {Lastname}'");
      ( $firstname, $prefix, $lastname ) = $namestr =~
        m/^( # first name
                    $NAME_SEQ_RE
                )
                    \s+
                ( # prefix?
                    $PREFIX_RE
                )?
                ( # last name
                    $RE{balanced}{-parens=>'{}'}
                )
$/x;
    }
    elsif ( $namestr =~ /^$RE{balanced}{-parens => '{}'}.+$/ )
    {
      $logger->debug("   Caught namestring of type '{Firstname} prefix? Lastname'");
      ( $firstname, $prefix, $lastname ) = $namestr =~
        m/^( # first name
                    $RE{balanced}{-parens=>'{}'}
                )
                    \s+
                ( # prefix?
                    $PREFIX_RE
                )?
                ( # last name
                    .+
                )
$/x;
    }
   else {
      $logger->debug("   Caught namestring of type 'Firstname prefix? Lastname'");
      ( $firstname, $prefix, $lastname ) = $namestr =~
        m/^( # first name
                    $NAME_SEQ_RE
                )
                 \s+
                ( # prefix?
                    $PREFIX_RE
                )?
                ( # last name
                    $NAME_SEQ_RE
                )
$/x;
    }

    $logger->warn("Couldn't determine Last Name for name \"$namestr\"") unless $lastname;
    $logger->warn("Couldn't determine First Name for name \"$namestr\"") unless $firstname;
    if ($lastname) {$lastname =~ s/^{(.+)}$/$1/;}
    if ($firstname) {$firstname =~ s/^{(.+)}$/$1/;}
    $firstname =~ s/\s+$// if $firstname;

    $prefix =~ s/\s+$// if $prefix;
    $prefix =~ s/^{(.+)}$/$1/ if $prefix;
    $namestr = "";
    $namestr = "$prefix " if $prefix;
    $namestr .= $lastname if $lastname;
    $namestr .= ", " . $firstname if $firstname;
  }
  else
  {    # Name alone
    $logger->debug("   Caught namestring of type 'Isolated_name_string'");
    $lastname = $namestr;
  }

  # Now put the LaTeX small spaces back again since we're finished parsing
  $namestr =~ s/{\x{e35a}}/{\\,}/g if $namestr;
  $firstname =~ s/{\x{e35a}}/{\\,}/g if $firstname;
  $lastname =~ s/{\x{e35a}}/{\\,}/g if $lastname;
  $prefix =~ s/{\x{e35a}}/{\\,}/g if $prefix;
  $suffix =~ s/{\x{e35a}}/{\\,}/g if $suffix;

  # Construct $namestring, initials and terseinitials
  my $ps;
  my $prefix_stripped;
  my $prefix_i;
  my $prefix_it;
  if ($prefix and $usepre) {
    $prefix_i     = getinitials($prefix);
    $prefix_it    = terseinitials($prefix_i);
    $prefix_stripped = remove_outer($prefix);
    $ps = $prefix ne $prefix_stripped ? 1 : 0;
  }
  my $ls;
  my $lastname_stripped;
  my $lastname_i;
  my $lastname_it;
  if ($lastname) {
    $lastname_i   = getinitials($lastname);
    $lastname_it  = terseinitials($lastname_i);
    $lastname_stripped = remove_outer($lastname);
    $ls = $lastname ne $lastname_stripped ? 1 : 0;
  }
  my $ss;
  my $suffix_stripped;
  my $suffix_i;
  my $suffix_it;
  if ($suffix) {
    $suffix_i     = getinitials($suffix);
    $suffix_it     = terseinitials($suffix_i);
    $suffix_stripped = remove_outer($suffix);
    $ss = $suffix ne $suffix_stripped ? 1 : 0;
  }
  my $fs;
  my $firstname_stripped;
  my $firstname_i;
  my $firstname_it;
  if ($firstname) {
    $firstname_i  = getinitials($firstname);
    $firstname_it = terseinitials($firstname_i);
    $firstname_stripped = remove_outer($firstname);
    $fs = $firstname ne $firstname_stripped ? 1 : 0;
  }



  $nameinitstr = "";
  $nameinitstr .= substr( $prefix, 0, 1 ) . " " if ( $usepre and $prefix );
  $nameinitstr .= $lastname if $lastname;
  $nameinitstr .= " " . terseinitials($suffix)
    if $suffix;
  $nameinitstr .= " " . terseinitials($firstname)
    if $firstname;
  $nameinitstr =~ s/\s+/_/g;

  return Biber::Entry::Name->new(
    firstname => $firstname,
    firstname_i => $firstname_i,
    firstname_it => $firstname_it,
    lastname  => $lastname,
    lastname_i => $lastname_i,
    lastname_it => $lastname_it,
    namestring => $namestr,
    nameinitstring => $nameinitstr,
    prefix => $prefix,
    prefix_i => $prefix_i,
    prefix_it => $prefix_it,
    suffix => $suffix,
    suffix_i => $suffix_i,
    suffix_it => $suffix_it,
    strip           => {'firstname' => $fs,
                        'lastname'  => $ls,
                        'prefix'    => $ps,
                        'suffix'    => $ss}

    );
}

sub _bibtex_prd_parse {

  my ($self, $filename) = @_;

  my @auxcitekeys = $self->citekeys;

  my $bibentries = $self->bib;

  my @localkeys;

  my $mode;

  if ( Biber::Config->getoption('bibencoding') and
    not Biber::Config->getoption('unicodebbl') ) {
    $mode = ':encoding(' . Biber::Config->getoption('bibencoding') . ')';
  } else {
    $mode = ":utf8";
  }


  ## TODO
  # $::RD_TRACE = 1 if Biber::Config->getoption('parserdebug');

  undef $/;

  my $bib = IO::File->new( $filename, "<$mode" )
    or $logger->logcroak("Failed to open $filename : $!");

  my $btparser = Biber::BibTeX::Parser->new
    or $logger->logcroak("Cannot create Biber::BibTeX::Parser object: $!");

  my $bf       = $btparser->BibFile(<$bib>)
    or $logger->logcroak("Can't parse file $filename : Are you certain it is a BibTeX file?\n\t$!");

  close $bib;

  my @tmp = @$bf;

  my $preamble = undef;

  for my $n ( 0 .. $#tmp ) {

    my @tmpk   = keys %{ $tmp[$n] };
    my $tmpkey = $tmpk[0];

    if ( $tmpkey eq 'preamble' ) {

      $preamble = join("%\n", @{ $tmp[$n]->{preamble} });
    }
    elsif ( $tmpkey eq 'entries' ) {

      my @entries = @{ $tmp[$n]->{entries} };

      foreach my $i ( 0 .. $#entries ) {

        my @tmpa   = keys %{ $entries[$i] };
        my $origkey = $tmpa[0];

        my $citecasekey = first {lc($origkey) eq lc($_)} $self->citekeys;
        $citecasekey = $origkey unless $citecasekey;
        my $key = lc($origkey);

        if ( $bibentries->entry_exists($origkey) or $bibentries->entry_exists($key)) {
          $self->{errors}++;
          my (undef,undef,$f) = File::Spec->splitpath( $filename );
          $logger->warn("Repeated entry---key $origkey in file $f\nI'm skipping whatever remains of this entry");
          next;
        }

        push @localkeys, $key;

        my $bibentry = new Biber::Entry($entries[$i]->{$origkey});

        $bibentry->set_field('datatype', 'bibtex');
        $bibentry->set_field('origkey', $origkey);
        $bibentry->set_field('citecasekey', $citecasekey);
        $bibentries->add_entry($key, $bibentry);
      }
    }
  }

  foreach my $key ( @localkeys ) {

    $logger->debug("Processing entry '$key'");

    my $bibentry = $bibentries->entry($key);

    foreach my $alias (keys %ALIASES) {

      if ( $bibentry->get_field($alias) ) {
        my $field = $ALIASES{$alias};
        $bibentry->set_field($field, $bibentry->get_field($alias));
        $bibentry->del_field($alias);
      }
    }

    foreach my $ets (@ENTRIESTOSPLIT) {

      if ( $bibentry->get_field($ets) ) {

        my $stringtosplit = $bibentry->get_field($ets);

        # next if ref($tmp) neq 'SCALAR'; # we skip those that have been split

        # "and" within { } must be preserved: see biblatex manual §2.3.3
        #      (this can probably be optimized)

        foreach my $x ( $stringtosplit =~ m/($RE{balanced}{-parens => '{}'})/gx ) {

          ( my $xr = $x ) =~ s/\s+and\s+/_\x{ff08}_/g;

          $stringtosplit =~ s/\Q$x/$xr/g;

        };

        my @tmp = split /\s+and\s+/, $stringtosplit;

        sub _restore_and {
          s/_\x{ff08}_/ and /g;
          return $_
        };

        @tmp = map { _restore_and($_) } @tmp;

        if (is_name_field($ets)) {
          my $useprefix = Biber::Config->getblxoption('useprefix', $bibentry->get_field('entrytype'), $key);
          my $names = new Biber::Entry::Names;
          foreach my $name (@tmp) {
            $names->add_element(parsename($name, {useprefix => $useprefix}));
          }
          $bibentry->set_field($ets, $names);

        } else {
          @tmp = map { remove_outer($_) } @tmp;
          $bibentry->set_field($ets, [ @tmp ]);
        }

      }
    }

    if ($bibentry->get_field('entrytype') eq 'set') {

      my @entrysetkeys = split /\s*,\s*/, $bibentry->get_field('entryset');

      foreach my $setkey (@entrysetkeys) {
        Biber::Config->set_setparentkey($setkey, $key);
      }
    }

    if ( $bibentry->get_field('crossref') ) {

      my $crkey = $bibentry->get_field('crossref');

      Biber::Config->incr_crossrefkey($crkey);

    };
  }

  $self->{preamble} .= $preamble if $preamble;

  return @localkeys;

}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Biber::BibTeX::PRD - Pure Perl BibTeX parser with Parse::RecDescent

=head1 METHODS

=head2 _bibtex_prd_parse

Internal method for parsing BibTeX data in Pure Perl instead of using
the btparse C library with Text::BibTeX

=head1 AUTHOR

François Charette, C<< <firmicus at gmx.net> >>

=head1 BUGS

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2010 François Charette, all rights reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

=cut

# vim: set tabstop=2 shiftwidth=2 expandtab:
