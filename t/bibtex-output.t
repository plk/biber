# -*- cperl -*-
use strict;
use warnings;
use Test::More tests => 6;
use Test::Differences;
unified_diff;


use Encode;
use Biber;
use Biber::Utils;
use Biber::Output::bibtex;
use Log::Log4perl;
use Unicode::Normalize;
chdir("t/tdata");
no warnings 'utf8';
use utf8;

# Set up Biber object
my $biber = Biber->new(noconf => 1);
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

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options

# THIS IS NOT TOOL MODE

Biber::Config->setoption('output_resolve_xdata', 1);
Biber::Config->setoption('output_resolve_crossrefs', 1);
Biber::Config->setoption('output_format', 'bibtex');
Biber::Config->setoption('output_align', '1');
Biber::Config->setoption('tool', '1');
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');
$biber->parse_ctrlfile('bibtex-output.bcf');
$biber->set_output_obj(Biber::Output::bibtex->new());

# Now generate the information
$biber->prepare;
my $main = $biber->datalists->get_list(Biber::Config->getblxoption(undef, 'sortingtemplatename') . '/global//global/global/global', 99999, 'entry');

my $out = $biber->get_output_obj;

my $b1 = q|@ARTICLE{murray,
  AUTHOR       = {Hostetler, Michael J. and Wingate, Julia E. and Zhong, Chuan-Jian and Harris, Jay E. and Vachet, Richard W. and Clark, Michael R. and Londono, J. David and Green, Stephen J. and Stokes, Jennifer J. and Wignall, George D. and Glish, Gary L. and Porter, Marc D. and Evans, Neal D. and Murray, Royce W.},
  ANNOTATION   = {An \texttt{article} entry with \arabic{author} authors. By default, long author and editor lists are automatically truncated. This is configurable},
  DATE         = {1998},
  INDEXTITLE   = {Alkanethiolate gold cluster molecules},
  JOURNALTITLE = {Langmuir},
  LANGID       = {english},
  LANGIDOPTS   = {variant=american},
  NUMBER       = {1},
  PAGES        = {17--30},
  SHORTTITLE   = {Alkanethiolate gold cluster molecules},
  SUBTITLE     = {Core and monolayer properties as a function of core size},
  TITLE        = {Alkanethiolate gold cluster molecules with core diameters from 1.5 to 5.2~nm},
  VOLUME       = {14},
}

|;

my $b2 = q|@BOOK{b1,
  LOCATION            = {London and Edinburgh},
  LOCATION+an:default = {1=ann1;2=ann2},
  DATE                = {1999},
  MAINSUBTITLE        = {Mainsubtitle},
  MAINTITLE           = {Maintitle},
  MAINTITLEADDON      = {Maintitleaddon},
  TITLE               = {Booktitle},
  TITLE+an:default    = {=ann1, ann2},
}

|;

my $b3 = q|@BOOK{xd1,
  AUTHOR    = {Ellington, Edward Paul},
  LOCATION  = {New York and London},
  PUBLISHER = {Macmillan},
  DATE      = {2001},
  NOTE      = {A Note},
}

|;

my $bo1 = q|@BOOK{bo1,
  AUTHOR = {Smith, Simon},
  IDS    = {box1,box2},
}

|;

eq_or_diff($out->get_output_entry('murray',), $b1, 'bibtex output 1');
eq_or_diff($out->get_output_entry('b1',), $b2, 'bibtex output 2');
eq_or_diff($out->get_output_entry('xd1',), $b3, 'bibtex output 3');
eq_or_diff($out->get_output_entry('bo1',), $bo1, 'bibtex output 4');
ok(is_undef($out->get_output_entry('reese')), 'bibtex output 5');
is_deeply($main->get_keys, ['murray', 'kant:ku', 'b1', 'xd1', 'bo1', 'mv1'], 'non-tool mode bibtex output sorting');
