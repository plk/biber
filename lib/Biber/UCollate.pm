package Biber::UCollate;
use v5.24;

use strict;
use Carp;
use Data::Dump;
use parent qw(Unicode::Collate::Locale);

my $logger = Log::Log4perl::get_logger('main');

# Tailorings for locales which Unicode::Collate::Locale has no tailoring for,
# as Unicode::Collate "entry" definitions. The weights are relative to those of
# other characters, so they are computed from a collator for the table in use.
my %BIBER_TAILORINGS = (
  # Western Frisian, CLDR "fy" (&I<<y<<<Y): y sorts as i, and after it when
  # words are otherwise equal (in, yn; Dykstra, Doele)
  fy => sub {
    my $root = shift;
    my ($i) = $root->viewSortKey('i') =~ m/\[([0-9A-F]+)/;
    return sprintf("0079 ; [.%s.0021.0002] # y\n0059 ; [.%s.0021.0008] # Y\n", $i, $i);
  },
);

=encoding utf-8

=head1 NAME

Biber::UCollate - Biber::UCollate objects

=head2 new

  Instantiate new Unicode::Collate::Locale object with some extra reporting checks.
  We need this also so that we can chain some things during sorting object construction.
  Without an object, we would need to call a regular subroutine but due to the special
  semantics of Schwartzian transforms, we need to chain all sorting elements so that they return
  a boolean value (see Biber.pm). This is much tidier with Foo->new()->change()->cmp than
  with something messy like "my $uc = create_uc_object; $uc->change()->cmp()" etc.

=cut

sub new {
  my $class = shift;
  my ($thislocale, %collopts) = @_;

  # Add tailoring locale for Unicode::Collate
  # Ignore table as this is not valid for U::C::Locale objects
  if ($thislocale and not $collopts{locale}) {
    $collopts{locale} = $thislocale;
    if ($collopts{table}) {
      my $t = delete $collopts{table};
      $logger->info("Ignoring collation table '$t' as locale is set ($thislocale)");
    }
  }

  # Remove locale from options as we need this to make the object
  my $coll_locale = delete $collopts{locale};

  # Fix the old "alternate" alias otherwise we have problems as U::C->change() always
  # returns the new "variable" option and we get confused.
  if (my $alt = delete $collopts{alternate}) {
    $collopts{variable} = $alt;
  }

  # Some options can only be set when creating the object
  my %newopts = map {exists($collopts{$_}) ? ($_ => delete $collopts{$_}) : ()} @Unicode::Collate::ChangeNG;

  # A tailoring of biber's own for the locale, if Unicode::Collate::Locale has
  # none (any user entry comes after it, so can override it)
  my $biber_tailoring = biber_tailoring($coll_locale, %newopts);
  if ($biber_tailoring) {
    $newopts{entry} = $biber_tailoring . ($newopts{entry} // '');
  }

  # Now create the collator object
  my $Collator = eval {$class->SUPER::new(locale => $coll_locale, %newopts)}
    or Biber::Utils::biber_error("Problem creating collation object: " . _collerr($@));
  $Collator->{biber_tailored} = 1 if $biber_tailoring;

  # Show the collation options when debugging
  if ($logger->is_debug()) {# performance tune
    $logger->debug('Collation options: ' . Data::Dump::pp(%collopts));
  }

  # Tailor the collation object and report differences from defaults for locale
  # Have to do this in ->change method as ->new can croak with conflicting tailoring
  # for locales which enforce certain tailorings
  my %coll_changed = eval {$Collator->change( %collopts )};
  if ($@) {
    Biber::Utils::biber_error("Invalid collation options: " . _collerr($@));
  }
  while (my ($k, $v) = each %coll_changed) {
    # If we are changing something that has no override tailoring in the locale, it
    # is undef in this hash and we don't care about such things
    next unless defined($coll_changed{$k});
    if ($coll_changed{$k} ne $collopts{$k}) {
      $logger->info("Overriding locale '$coll_locale' defaults '$k = $v' with '$k = " . $collopts{$k} . "'");
    }
  }

  return $Collator;
}

=head2 biber_tailoring

  The "entry" definitions of biber's own tailoring for a locale, or undef if
  biber has none or Unicode::Collate::Locale has its own for the locale.
  %opts are the options the collator is created with.

=cut

sub biber_tailoring {
  my ($locale, %opts) = @_;
  return undef unless $locale;
  my ($lang) = lc($locale) =~ m/\A([a-z]+)/;
  my $tailoring = $BIBER_TAILORINGS{$lang // ''} or return undef;
  delete $opts{entry};
  my $root = Unicode::Collate::Locale->new(%opts, locale => $locale);
  # Newer versions of Unicode::Collate::Locale may have the locale
  return undef unless $root->getlocale eq 'default';
  return $tailoring->($root);
}

=head2 is_tailored

  Whether the collator has a tailoring for its locale, from
  Unicode::Collate::Locale or from biber

=cut

sub is_tailored {
  my $self = shift;
  return ($self->{biber_tailored} or $self->getlocale ne 'default') ? 1 : 0;
}

=head2 new_sortinit

  A level 1 collator for sortinit hashes, with the same tailoring for the
  locale as the sorting collator

=cut

sub new_sortinit {
  my ($class, $locale) = @_;
  my $entry = biber_tailoring($locale, level => 1);
  return Unicode::Collate::Locale->new(locale => $locale, level => 1,
                                       ($entry ? (entry => $entry) : ()));
}

# Error message from Unicode::Collate without the location
sub _collerr {
  my $err = shift;
  $err =~ s/\s+at\s+\S+\s+line\s+\d+\.?\s*\z//;
  return $err;
}

1;

__END__

=head1 AUTHORS

Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our Github tracker at
L<https://github.com/plk/biber/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2012-2026 Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut





