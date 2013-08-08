# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 3;

use Biber;
use Biber::Output::bbl;
use Log::Log4perl;
chdir("t/tdata");

# Set up Biber object
my $biber = Biber->new( configfile => 'biber-test.conf');
my $LEVEL = 'ERROR';
my $l4pconf = qq|
    log4perl.category.main                             = $LEVEL, Screen
    log4perl.category.screen                           = $LEVEL, Screen
    log4perl.appender.Screen                           = Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.utf8                      = 1
    log4perl.appender.Screen.Threshold                 = $LEVEL
    log4perl.appender.Screen.stderr                    = 0
    log4perl.appender.Screen.layout                    = Log::Log4perl::Layout::SimpleLayout
|;
Log::Log4perl->init(\$l4pconf);

$biber->parse_ctrlfile('zoterordfxml.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# THERE IS A CONFIG FILE BEING READ TO TEST USER MAPS TOO!

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('sortlocale', 'C');

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $main = $biber->sortlists->get_list(0, 'entry', 'nty');
my $bibentries = $section->bibentries;

my $l1 = q|    \entry{http://0-muse.jhu.edu.pugwash.lib.warwick.ac.uk:80/journals/theory_and_event/v005/5.3ranciere.html}{article}{}
      \name{labelname}{1}{}{%
        {{hash=2d6c91380dc6798fd8219e73cf91f468}{Rancière}{R\bibinitperiod}{Jacques}{J\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{hash=2d6c91380dc6798fd8219e73cf91f468}{Rancière}{R\bibinitperiod}{Jacques}{J\bibinitperiod}{}{}{}{}}%
      }
      \name{translator}{2}{}{%
        {{hash=c95c30a625fdc9f3e9339afb92cf7161}{Panagia}{P\bibinitperiod}{Davide}{D\bibinitperiod}{}{}{}{}}%
        {{hash=2e68c1ae590a37eeceab55f5594589f7}{Bowlby}{B\bibinitperiod}{Rachel}{R\bibinitperiod}{}{}{}{}}%
      }
      \strng{namehash}{2d6c91380dc6798fd8219e73cf91f468}
      \strng{fullhash}{2d6c91380dc6798fd8219e73cf91f468}
      \field{sortinit}{R}
      \field{labelyear}{2001}
      \field{datelabelsource}{}
      \field{labeltitle}{ten theses on politics}
      \field{journaltitle}{Theory \& Event}
      \field{library}{Project MUSE}
      \field{note}{Volume 5, Issue 3, 2001}
      \field{number}{3}
      \field{title}{ten theses on politics}
      \field{volume}{5}
      \field{year}{2001}
      \verb{url}
      \verb http://0-muse.jhu.edu.pugwash.lib.warwick.ac.uk:80/journals/theory_and_event/v005/5.3ranciere.html
      \endverb
    \endentry
|;

my $l2 = q|    \entry{urn:isbn:0713990023}{book}{}
      \name{labelname}{1}{}{%
        {{hash=984e5967448051538555a64aac11ed21}{Foucault}{F\bibinitperiod}{Michel}{M\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{hash=984e5967448051538555a64aac11ed21}{Foucault}{F\bibinitperiod}{Michel}{M\bibinitperiod}{}{}{}{}}%
      }
      \list{location}{1}{%
        {London}%
      }
      \list{publisher}{1}{%
        {Allen Lane}%
      }
      \strng{namehash}{984e5967448051538555a64aac11ed21}
      \strng{fullhash}{984e5967448051538555a64aac11ed21}
      \field{sortinit}{F}
      \field{labelyear}{1988}
      \field{datelabelsource}{}
      \field{labeltitle}{The History of Sexuality volume 3: The Care of the Self}
      \field{isbn}{0713990023}
      \field{library}{webcat.warwick.ac.uk Library Catalog}
      \field{pagetotal}{279}
      \field{title}{The History of Sexuality volume 3: The Care of the Self}
      \field{year}{1988}
    \endentry
|;

my $l3 = q|    \entry{item_54}{inbook}{}
      \name{labelname}{1}{}{%
        {{hash=984e5967448051538555a64aac11ed21}{Foucault}{F\bibinitperiod}{Michel}{M\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{hash=984e5967448051538555a64aac11ed21}{Foucault}{F\bibinitperiod}{Michel}{M\bibinitperiod}{}{}{}{}}%
      }
      \name{editor}{1}{}{%
        {{hash=59e41b906187fcc9bff2bddd24f99eca}{Lotringer}{L\bibinitperiod}{Sylvère}{S\bibinitperiod}{}{}{}{}}%
      }
      \name{translator}{2}{}{%
        {{hash=0826582066ef5e3af124decf97f18d39}{Hochroth}{H\bibinitperiod}{Lysa}{L\bibinitperiod}{}{}{}{}}%
        {{hash=d3cb970ad9fd48a90099fc50aec54981}{Johnston}{J\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
      }
      \list{location}{1}{%
        {New York}%
      }
      \list{publisher}{1}{%
        {Semiotext(e)}%
      }
      \strng{namehash}{984e5967448051538555a64aac11ed21}
      \strng{fullhash}{984e5967448051538555a64aac11ed21}
      \field{sortinit}{F}
      \field{labelyear}{1996}
      \field{labelmonth}{03\bibdatedash 04}
      \field{labelday}{04\bibdatedash 07}
      \field{datelabelsource}{}
      \field{labeltitle}{The Ethics of the Concern for Self as a Practice of Freedom}
      \field{booktitle}{Foucault Live: Interviews, 1961-1984}
      \field{day}{04}
      \field{endday}{07}
      \field{endmonth}{04}
      \field{endyear}{1996}
      \field{month}{03}
      \field{title}{The Ethics of the Concern for Self as a Practice of Freedom}
      \field{year}{1996}
      \field{pages}{432\bibrangedash 449}
    \endentry
|;

is( $out->get_output_entry('http://0-muse.jhu.edu.pugwash.lib.warwick.ac.uk:80/journals/theory_and_event/v005/5.3ranciere.html', $main), $l1, 'Basic Zotero RDF/XML test - 1') ;
is( $out->get_output_entry('urn:isbn:0713990023', $main), $l2, 'Basic Zotero RDF/XML test - 2') ;
is( $out->get_output_entry('item_54', $main), $l3, 'Basic Zotero RDF/XML test - 3') ;
