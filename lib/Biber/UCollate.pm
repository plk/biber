package Biber::UCollate;
use v5.24;

use strict;
use Carp;
use Data::Dump;
use parent qw(Unicode::Collate::Locale);

my $logger = Log::Log4perl::get_logger('main');

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

  # Now create the collator object
  my $Collator = $class->SUPER::new(locale => $coll_locale)
    or $logger->logcarp("Problem creating Unicode::Collate::Locale object: $@");

  # Fix the old "alternate" alias otherwise we have problems as U::C->change() always
  # returns the new "variable" option and we get confused.
  if (my $alt = delete $collopts{alternate}) {
    $collopts{variable} = $alt;
  }

  # Show the collation options when debugging
  if ($logger->is_debug()) {# performance tune
    $logger->debug('Collation options: ' . Data::Dump::pp(%collopts));
  }

  # Tailor the collation object and report differences from defaults for locale
  # Have to do this in ->change method as ->new can croak with conflicting tailoring
  # for locales which enforce certain tailorings
  my %coll_changed = $Collator->change( %collopts );
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

1;

__END__

=head1 AUTHORS

Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our Github tracker at
L<https://github.com/plk/biber/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2012-2024 Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut





