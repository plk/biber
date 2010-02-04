package Biber::BibLaTeXML;
use strict;
use warnings;
no warnings 'once';
use Carp;
use XML::LibXML;
use Biber::BibLaTeXML::Node;
use Biber::Utils;
use Biber::Entry::Name;
use Biber::Entry::Names;
use Biber::Constants;
use File::Spec;
use Log::Log4perl qw(:no_extra_logdie_message);
our @ISA;

my $logger = Log::Log4perl::get_logger('main');

sub _parse_biblatexml {
  my ($self, $xml) = @_;
  my $parser = XML::LibXML->new();
  my $db;
  my $bibentries = $self->bib;

  # FIXME : a user _could_ want to encode the bbl in LaTeX!
  # ... in which case we would need LaTeX::Encode
  Biber::Config->setoption('unicodebbl', 1);

  if ( $xml =~ /\.dbxml$/ ) {
    require Biber::DBXML;
    push @ISA, 'Biber::DBXML';
    $logger->info("Querying DBXML  ...");
    my $xmlstring = $self->dbxml_to_xml($xml);
    $logger->info("Parsing the XML data ...");
    $db = $parser->parse_string( $xmlstring )
      or $logger->logcroak("Cannot parse xml string");
  } else {
    $logger->info("Parsing the file $xml ...");
    $db = $parser->parse_file($xml)
      or $logger->logcroak("Can't parse file $xml");
  }

  if (Biber::Config->getoption('validate')) {
    require Config;

# FIXME How can we be sure that Biber is installed in sitelib and not vendorlib ?
    my $xmlschema = XML::LibXML::Schema->new(
      location => File::Spec->catfile($Config::Config{sitelibexp}, 'Biber', 'biblatexml.xsd')
      )
      or $logger->warn("Cannot find XML::LibXML::Schema schema for BibLaTeXML. Skipping validation : $!");

    if ($xmlschema) {
      my $validation = eval { $xmlschema->validate($db) ; };

      unless ($validation) {
        $logger->logcroak("The file $xml does not validate against the BibLaTeXML schema!\n$@")
      }
    }
  }

  # keep track of citekeys that were not found in this database
  my %citekeys_to_skip = ();
  my @auxcitekeys = $self->citekeys;

  if (Biber::Config->getoption('allentries')) {
    @auxcitekeys = ();
    my $res = $db->findnodes('/*/bib:entry');
    foreach my $r ($res->get_nodelist) {
      push @auxcitekeys, $r->findnodes('@id')->string_value
    }
  }

  $logger->info("Processing the XML data ...");

  # Contrary to the bibtex approach, we are not extracting all data to
  # the bibentries hash, but only the ones corresponding to @auxcitekeys
  foreach my $citekey (@auxcitekeys) {
    if ( $bibentries->entry_exists($citekey) ) {
      $logger->debug("Entry \"$citekey\" was already found: skipping");
      $citekeys_to_skip{$citekey} = 1;
      next;
    }
    $logger->debug("Looking for $citekey");

    my $xpath = '/*/bib:entry[@id="' . $citekey . '"]';
    my $results = $db->findnodes($xpath);

    if ( $results ) {
      $logger->debug("Found entry \"$citekey\"");
    }
    else {
      $logger->debug("Can't find entry \"$citekey\": skipping");
      $citekeys_to_skip{$citekey} = 1;
      next
    }

    if ( $results->size() > 1 ) {
      $logger->warn("The XML database contains more than one entry with id=\"$citekey\"!\nI'll take the first one.")
    };

    my $bibrecord = $results->get_node(1);

    # if we have an entryset we add the keys to the stack
    if ($bibrecord->findnodes('@entrytype')->string_value eq 'set') {

      my @entrysetkeys = split /,/, $bibrecord->findnodes('bib:entryset')->_normalize_string_value;

      # add all keys of inset_entries to the stack
      push @auxcitekeys, @entrysetkeys;

      foreach my $setkey (@entrysetkeys) {
        Biber::Config->set_setparentkey($setkey, $citekey);
      }
    }

    # if there is a crossref, we increment its citekey in the crossref state
    elsif ( $bibrecord->exists('bib:crossref') ) {

      my $crefkey = $bibrecord->findnodes('bib:crossref')->_normalize_string_value;

      Biber::Config->incr_crossrefkeys($crefkey);
    }

  }

  # add all crossrefs to the stack
  unless ( Biber::Config->getoption('allentries') ) {
    push @auxcitekeys, ( @{Biber::Config->get_crossrefkeys} );
  }

  #--------------------------------------------------

  foreach my $citekey (@auxcitekeys) {
    next if $citekeys_to_skip{$citekey}; # skip entries already found or not present in current xml file
    my $bibentry = new Biber::Entry;

    $logger->debug("Processing entry '$citekey'");
    my $xpath = '/*/bib:entry[@id="' . $citekey . '"]';
    my $results = $db->findnodes($xpath) or croak "Cannot find node $xpath";
    my $bibrecord = $results->get_node(1);

    $bibentry->set_field('entrytype', $bibrecord->findnodes('@entrytype')->string_value);
    if ($bibrecord->exists('@type')) {
      $bibentry->set_field('type', $bibrecord->findnodes('@type')->string_value);
    }
    $bibentry->set_field('datatype', 'xml');

    #TODO get the options field first
    #options/text or option: key+value
    if ($bibrecord->exists("bib:options")) {
      if ($bibrecord->findnodes("bib:options/bib:option")) {
        my @opts;
        foreach my $o ($bibrecord->findnodes("bib:options/bib:option")->get_nodelist) {
          my $k = $o->findnodes("bib:key")->_normalize_string_value;
          my $v = $o->findnodes("bib:value")->_normalize_string_value;
          push @opts, "$k=$v";
        }
        $bibentry->set_field('options', join(",", @opts));
      }
      else {
        $bibentry->set_field('options', $bibrecord->findnodes("bib:options")->_normalize_string_value);
      }
    }

    # then we extract in turn the data from each type of fields

    #First we handle the title:

    my $titlename = "title";

    if ( $bibentry->get_field('entrytype') eq 'periodical') {
      if ($bibrecord->exists("bib:journaltitle")) {
        $titlename = 'journaltitle'
      } elsif ($bibrecord->exists("bib:journal")) {
        $titlename = 'journal'
      }
    }

    if (! $bibrecord->exists("bib:$titlename")) {
      if ( ! $bibrecord->exists("bib:crossref") ) {
        $logger->error("Entry $citekey has no title!")
      }
    }
    else {

      # displaymode
      my $titledm = Biber::Config->get_displaymode($bibentry->get_field('entrytype'), $titlename, $citekey);
      my $titlestrings = $bibrecord->_find_biblatex_nodes($self, $titlename, $titledm)->_biblatex_title_values;
      $bibentry->set_field($titlename, $titlestrings->{'title'});

      my @specialtitlefields = qw/sorttitle indextitle indexsorttitle/;
      foreach my $field (@specialtitlefields) {
        if (! $bibrecord->exists("bib:$field") ) {
          $bibentry->set_field($field, $titlestrings->{$field});
        }
      }
    }

    # then all other literal fields
    foreach my $field (@LITERALFIELDS, @VERBATIMFIELDS) {
      next if $field eq 'title';
      my $dm = Biber::Config->get_displaymode($bibentry->get_field('entrytype'), $field, $citekey);
      $bibentry->set_field($field, $bibrecord->_find_biblatex_nodes($self, $field, $dm)->_biblatex_value) if $bibrecord->exists("bib:$field");
    }

    # list fields
    foreach my $field (@LISTFIELDS) {
      my $dm = Biber::Config->get_displaymode($bibentry->get_field('entrytype'), $field, $citekey);
      my @z;
      if ($bibrecord->exists("bib:$field")) {
        if ($bibrecord->exists("bib:$field/bib:item")) {
          foreach my $item ($bibrecord->_find_biblatex_nodes($self, $field, $dm, "item")->get_nodelist) {
            push @z, $item->_biblatex_value;
          }
        }
        else {
          push @z, $bibrecord->_find_biblatex_nodes($self, $field, $dm)->_biblatex_value
        };
        if ($bibrecord->exists("bib:$field\[\@andothers='true'\]")) {
          push @z, "others"
        };
        $bibentry->set_field($field, [ @z ]);
      }
    }

    # date fields: date, origdate, urldate, eventdate
    # in format YYYY-MM-DD
    # optionally with start and end
    # >>> TODO support field/list/items <<<
    #     (also for fields volume and pages)
    foreach my $field (@DATERANGEFIELDS)  {
      if ($bibrecord->exists("bib:$field\[not(\@type='converted')\]")) {
        if ($bibrecord->exists("bib:$field/bib:start")) {
          my $fieldstart = $bibrecord->findnodes("bib:$field/bib:start")->_normalize_string_value;
          my $fieldend   = $bibrecord->findnodes("bib:$field/bib:end")->_normalize_string_value || undef;

          $bibentry->set_field($field, $fieldstart);

          my $fieldendname = $field;

          # e.g. *date -> *enddate:
          $fieldendname =~ s/date/enddate/;

          $bibentry->set_field($fieldendname, $fieldend);
        }
        else {
          $bibentry->set_field($field,
            $bibrecord->findnodes("bib:$field/text()")->_normalize_string_value);
        }
      }

      # support for dates in non-Gregorian calendars:
      # *date / local*date / *localcalendar
      elsif ($bibrecord->exists("bib:$field\[\@type='converted'\]")) {

        if ($bibrecord->exists("bib:$field/bib:value/bib:start")) {
          my $fieldstart = $bibrecord->findnodes("bib:$field/bib:value/bib:start")->_normalize_string_value;
          my $fieldend   = $bibrecord->findnodes("bib:$field/bib:value/bib:end")->_normalize_string_value || undef;

          $bibentry->set_field($field, $fieldstart);

          my $fieldendname = $field;

          # e.g. *date -> *enddate:
          $fieldendname =~ s/date/enddate/;

          $bibentry->set_field($fieldendname, $fieldend);

        }
        else {
          $bibentry->set_field($field,
            $bibrecord->findnodes("bib:$field/bib:value")->string_value);
        }

        my $prefix = $field;
        $prefix =~ s/date//;

        if ($bibrecord->exists("bib:$field/bib:localvalue/bib:start")) {
          my $fieldstart = $bibrecord->findnodes("bib:$field/bib:localvalue/bib:start")->_normalize_string_value;
          my $fieldend   = $bibrecord->findnodes("bib:$field/bib:localvalue/bib:end")->_normalize_string_value || undef;

          $bibentry->set_field("local$field", $fieldstart);

          my $fieldendname = "local$field";

          # e.g. origdate -> origenddate:
          $fieldendname =~ s/date/enddate/;

          $bibentry->set_field($fieldendname, $fieldend);
        }
        else {
          $bibentry->set_field("local$field",
            $bibrecord->findnodes("bib:$field/bib:localvalue")->_normalize_string_value);
          $bibentry->set_field($prefix."localcalendar",
            $bibrecord->findnodes("bib:$field/bib:localvalue/\@calendar")->string_value);
        }
      }
    }

    ## PAGES
    if ($bibrecord->exists("bib:pages")) {
      if ($bibrecord->exists("bib:pages/bib:start")) {
        my $pagesstart = $bibrecord->findnodes("bib:pages/bib:start")->_normalize_string_value;
        my $pagesend   = $bibrecord->findnodes("bib:pages/bib:end")->_normalize_string_value;
        $bibentry->set_field('pages', "$pagesstart\\bibrangedash $pagesend");
      }
      elsif ($bibrecord->exists("bib:pages/bib:list")) {
        $bibentry->set_field('pages',
          $bibrecord->findnodes("bib:pages/bib:list")->_normalize_string_value);
      }
      else {
        $bibentry->set_field('pages',
          $bibrecord->findnodes("bib:pages")->_normalize_string_value);
      }
    }

    # the name fields are somewhat more complex ...
    foreach my $field (@NAMEFIELDS) {
      my $dm = Biber::Config->get_displaymode($bibentry->get_field('entrytype'), $field, $citekey);
      if ($bibrecord->exists("bib:$field")) {
        my $names = new Biber::Entry::Names;
        my $useprefix = Biber::Config->getblxoption('useprefix', $bibentry->get_field('entrytype'), $citekey);
        if ($bibrecord->exists("bib:$field/bib:person")) {
          foreach my $person ($bibrecord->_find_biblatex_nodes($self, $field, $dm, "person")->get_nodelist) {
            my $lastname;
            my $firstname;
            my $prefix;
            my $suffix;
            my $namestr = "";
            my $nameinitstr = undef;
            if ($person->exists('bib:last')) {
              $lastname = $person->findnodes('bib:last')->_normalize_string_value;
              $firstname = $person->findnodes('bib:first')->_normalize_string_value;
              $prefix = $person->findnodes('bib:prefix')->_normalize_string_value
                if $person->exists('bib:prefix');
              $suffix = $person->findnodes('bib:suffix')->_normalize_string_value
                if $person->exists('bib:suffix');

              #FIXME the following code is a repetition of part of parsename()
              $namestr .= $prefix if $prefix;
              $namestr .= $lastname;
              $namestr .= ", " . $firstname if $firstname;

              $nameinitstr = "";
              $nameinitstr .= substr( $prefix, 0, 1 ) . "_"
                if ( $useprefix and $prefix );
              $nameinitstr .= $lastname;
              $nameinitstr .= "_" . terseinitials($firstname)
                if $firstname;

              $names->add_element(Biber::Entry::Name->new(
                  lastname => $lastname,
                  firstname => $firstname,
                  prefix => $prefix,
                  suffix => $suffix,
                  namestring => $namestr,
                  nameinitstring => $nameinitstr
                  ));
            }

            # Schema allows <person>text<person>
            # If there is no comma in the string,
            # we assume it to be like a protected string
            # in BibTeX (i.e. between curly braces),
            # otherwise we parse it
            else {
              my $namestr = $person->string_value;

              if ($namestr =~ /,\s+/) {
                $names->add_element(parsename(
                    $person->string_value, {useprefix => $useprefix} ));
              } else {
                $names->add_element(Biber::Entry::Name->new(
                    lastname => $namestr,
                    namestring => $namestr,
                    nameinitstring => normalize_string_underscore( $namestr )));
              }
            }
          }
        }

        # only one name as string, without <person>:
        # in this case we assume it is not a personal name
        # and we take it "as is".
        else {
          my $namestr = $bibrecord->findnodes("bib:$field")->string_value;

          $names->add_element(Biber::Entry::Name->new(
              lastname => $namestr,
              namestring => $namestr,
              nameinitstring => normalize_string_underscore( $namestr )));
        }

        if ($bibrecord->exists("bib:$field\[\@andothers='true'\]")) {
          $names->add_element(Biber::Entry::Name->new(
              lastname => 'others',
              namestring => 'others'));
        }

        $bibentry->set_field($field, $names);
      }
    }

    # now we extract the attributes
    my %xmlattributes = (
      'bib:pages/@pagination' => 'pagination',
      'bib:pages/@bookpagination' => 'bookpagination',
      'bib:author/@type' => 'authortype',
      'bib:editor/@type' => 'editortype',
      'bib:editorA/@type' => 'editoratype',
      'bib:editorB/@type' => 'editorbtype',
      'bib:editorC/@type' => 'editorctype',
      'bib:editorA/@class' => 'editoraclass',
      'bib:editorB/@class' => 'editorbclass',
      'bib:editorC/@class' => 'editorcclass',
      'bib:author/@gender' => 'gender',
      ## TODO 'bib:editor/@gender' => 'gender', (ignored for now)
      '@howpublished' => 'howpublished'
      );
    foreach my $attr (keys %xmlattributes) {
      if ($bibrecord->exists($attr)) {
        $bibentry->set_field($xmlattributes{$attr},
          $bibrecord->findnodes($attr)->string_value);
      }
    }
    $bibentries->add_entry($citekey, $bibentry);
  }

  # now we keep only citekeys that actually exist in the database
  $self->{citekeys} = [ grep { $bibentries->entry_exists(lc($_)) } @auxcitekeys ];
  return;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Biber::BibLaTeXML - parse BibLaTeXML database

=head1 METHODS

=head2 _parse_biblatexml

    Internal method to query and parse a BibLaTeXML database.

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
