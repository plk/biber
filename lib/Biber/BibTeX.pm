package Biber::BibTeX;
use strict;
use warnings;
use Carp;
use Text::BibTeX;
use Biber::Constants;
use Biber::Entries;
use Biber::Entry;
use Biber::Utils;
use Encode;
use File::Spec;
use Log::Log4perl qw(:no_extra_logdie_message);

my $logger = Log::Log4perl::get_logger('main');

sub _text_bibtex_parse {

    my ($self, $filename) = @_;

    # Text::BibTeX can't be controlled by Log4perl so we have to do something clumsy
    if (Biber::Config->getoption('quiet')) {
      open STDERR, '>/dev/null';
    }

    my $bibentries = $self->bib;

    my @localkeys;

    my $encoding;

    if ( Biber::Config->getoption('bibencoding') and
         not Biber::Config->getoption('unicodebbl') ) {
      $encoding = Biber::Config->getoption('bibencoding');
    } else {
        $encoding = "utf8";
    }

    my $bib = Text::BibTeX::File->new( $filename, "<" )
        or $logger->logcroak("Cannot create Text::BibTeX::File object from $filename: $!");

    #TODO validate with Text::BibTeX::Structure ?

    my @preamble = ();
    my $count = 0;

    while ( my $entry = new Text::BibTeX::Entry $bib ) {

        $count++;

        if ( $entry->metatype == BTE_PREAMBLE ) {
            push @preamble, $entry->value;
            next;
        }

        next if ( $entry->metatype == BTE_MACRODEF or $entry->metatype == BTE_UNKNOWN
                or $entry->metatype == BTE_COMMENT ); #or $entry->type =~ m/^comment$/i

        unless ( $entry->key ) {
            $logger->warn("Cannot get the key of entry no $count : Skipping");
            next;
        }

        my $origkey = $entry->key;
        my $lc_key = lc($origkey);

        if (!defined $origkey or $origkey =~ /\s/ or $origkey eq '') {
            $logger->warn("Invalid BibTeX key! Skipping...");
            next;
        }

        $logger->debug("Processing entry '$origkey'");

        if ( $bibentries->entry_exists($origkey) ) {
            $self->{errors}++;
            my (undef,undef,$f) = File::Spec->splitpath( $filename );
            $logger->warn("Repeated entry---key $origkey in file $f\nI'm skipping whatever remains of this entry");
            next;
        }

        push @localkeys, $lc_key;

        unless ($entry->parse_ok) {
            $self->{errors}++;
            $logger->warn("Entry $origkey does not parse correctly: skipping");
            next;
        }

        my $bibentry = new Biber::Entry;

        # all fields used for this entry
        my @flist = $entry->fieldlist;

        #here we only keep those that do not require splitting
        my @flistnosplit = reduce_array(\@flist, \@ENTRIESTOSPLIT);

        if ( $entry->metatype == BTE_REGULAR ) {

            foreach my $f ( @flistnosplit ) {

                #my $value = decode_utf8( $entry->get($f) );
                my $value = decode( $encoding, $entry->get($f) );

                my $af = $f;

                if ( $ALIASES{$f} ) {
                  $af = $ALIASES{$f};
                }

                $bibentry->set_field($af, $value);

                if ($entry->type eq 'set' and $f eq 'entryset') {

                    my @entrysetkeys = split /\s*,\s*/, $value;

                    foreach my $setkey (@entrysetkeys) {
                        Biber::Config->setstate('inset_entries', lc($setkey), $lc_key);
                    }
                }
                elsif ($f eq 'crossref') { ### $entry->type ne 'set' and
                    Biber::Config->incrstate('crossrefkeys', $value);
                    Biber::Config->setstate('entrieswithcrossref', $lc_key, $value);
                }
            }

            if (lc($entry->type) eq 'phdthesis') {
                $bibentry->set_field('entrytype', 'thesis');
                $bibentry->set_field('type', 'phdthesis');
            } elsif (lc($entry->type) eq 'mathesis') {
                $bibentry->set_field('entrytype', 'thesis');
                $bibentry->set_field('type', 'mathesis');
            } else {
                $bibentry->set_field('entrytype', $entry->type);
            }

            foreach my $f ( @ENTRIESTOSPLIT ) {

                next unless $entry->exists($f);

                my $af = $f;

                # support for legacy BibTeX field names as aliases
                if ( $ALIASES{$f} ) {
                    $af = $ALIASES{$f};
                    # ignore field e.g. "address" if "location" also exists
                    next if $entry->exists($af);
                }

                my @tmp = map { decode($encoding, $_) } $entry->split($f);

                if (Biber::Config->getstate('is_name_entry', $f)) {
                  # This is a special case - we need to get the option value even though the passed
                  # $self object isn't fully built yet so getblxoption() can't ask $self for the
                  # $entrytype for $lc_key. So, we have to pass it explicitly.
                  my $useprefix = Biber::Config->getblxoption('useprefix', $bibentry->get_field('entrytype'), $lc_key);

                  @tmp = map { parsename( $_ , {useprefix => $useprefix}) } @tmp;
                } else {
                    @tmp = map { remove_outer($_) } @tmp;
                }

                $bibentry->set_field($af, [ @tmp ]);

            }

            $bibentry->set_field('datatype', 'bibtex');
            $bibentries->add_entry($lc_key, $bibentry);

          }
      }

    $self->{preamble} = join( "%\n", @preamble ) if @preamble;


   if (Biber::Config->getoption('quiet')) {
      close STDERR;
    }

  return @localkeys;

}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Biber::BibTeX - parse a bib database with Text::BibTeX

=head1 DESCRIPTION

Internal method ...

=head1 AUTHOR

François Charette, C<< <firmicus at gmx.net> >>
Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2010 François Charette and Philip Kime, all rights reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

=cut

# vim: set tabstop=4 shiftwidth=4 expandtab:
