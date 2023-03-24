# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 9;
use Test::Differences;
unified_diff;

use Biber;
use Biber::Output::bbl;
use Log::Log4perl;
chdir("t/tdata");

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

$biber->parse_ctrlfile('sort-complex.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');
# Want to ignore SHORTHAND* fields for the first few tests
Biber::Config->setoption('sourcemap', [
  {
    datatype => "bibtex",
    level => "user",
    map => [
      {
        map_step => [{ map_field_set => "SHORTHAND", map_null => 1 },
                     { map_field_set => "SORTSHORTHAND", map_null => 1 }]
      }]}]);

# Biblatex options
Biber::Config->setblxoption(undef,'labeldateparts', 0);

# Now generate the information
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $bibentries = $section->bibentries;
my $main = $biber->datalists->get_list('nyt/global//global/global/global');
my $shs = $biber->datalists->get_list('shorthand/global//global/global/global', 0, 'list');

my $out = $biber->get_output_obj;

my $ss = { locale => 'en-US',
           spec => [
           [
            {},
            {'presort'    => {}}
           ],
           [
            {'final' => 1},
            {'sortkey'    => {}}
           ],
           [
            {},
            {'labelalpha'    => {}},
           ],
           [
            {},
            {'sortname'   => {}},
            {'author'     => {}},
            {'editor'     => {}},
            {'translator' => {}},
            {'sorttitle'  => {}},
            {'title'      => {}}
           ],
           [
            {},
            {'sortyear'  => {}},
            {'year'      => {}}
           ],
           [
            {},
            {'sorttitle'       => {}},
            {'title'       => {}}
           ],
           [
            {},
            {'volume'     => {}},
            {'0'          => {literal => 1}},
           ],
          ]};

my $l4 = q|    \entry{L4}{book}{}{}
      \true{moreauthor}
      \true{morelabelname}
      \name{author}{1}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{%
           family={Doe},
           familyi={D\bibinitperiod},
           given={John},
           giveni={J\bibinitperiod}}}%
      }
      \list{location}{1}{%
        {Cambridge}%
      }
      \list{publisher}{1}{%
        {Another press}%
      }
      \strng{namehash}{6eb389989020e8246fee90ac93fcecbe}
      \strng{fullhash}{6eb389989020e8246fee90ac93fcecbe}
      \strng{fullhashraw}{6eb389989020e8246fee90ac93fcecbe}
      \strng{bibnamehash}{6eb389989020e8246fee90ac93fcecbe}
      \strng{authorbibnamehash}{6eb389989020e8246fee90ac93fcecbe}
      \strng{authornamehash}{6eb389989020e8246fee90ac93fcecbe}
      \strng{authorfullhash}{6eb389989020e8246fee90ac93fcecbe}
      \strng{authorfullhashraw}{6eb389989020e8246fee90ac93fcecbe}
      \field{extraname}{2}
      \field{labelalpha}{Doe\textbf{+}95}
      \field{sortinit}{D}
      \field{sortinithash}{6f385f66841fb5e82009dc833c761848}
      \field{extraalpha}{2}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{Some title about sorting}
      \field{year}{1995}
    \endentry
|;

my $l1 = q|    \entry{L1}{book}{}{}
      \name{author}{1}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{%
           family={Doe},
           familyi={D\bibinitperiod},
           given={John},
           giveni={J\bibinitperiod}}}%
      }
      \list{location}{1}{%
        {Cambridge}%
      }
      \list{publisher}{1}{%
        {A press}%
      }
      \strng{namehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{fullhash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{fullhashraw}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{bibnamehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authorbibnamehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authornamehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authorfullhash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authorfullhashraw}{bd051a2f7a5f377e3a62581b0e0f8577}
      \field{extraname}{1}
      \field{labelalpha}{Doe95}
      \field{sortinit}{D}
      \field{sortinithash}{6f385f66841fb5e82009dc833c761848}
      \field{extraalpha}{1}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{Algorithms For Sorting}
      \field{year}{1995}
    \endentry
|;

my $l2 = q|    \entry{L2}{book}{}{}
      \name{author}{1}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{%
           family={Doe},
           familyi={D\bibinitperiod},
           given={John},
           giveni={J\bibinitperiod}}}%
      }
      \list{location}{1}{%
        {Cambridge}%
      }
      \list{publisher}{1}{%
        {A press}%
      }
      \strng{namehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{fullhash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{fullhashraw}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{bibnamehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authorbibnamehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authornamehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authorfullhash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authorfullhashraw}{bd051a2f7a5f377e3a62581b0e0f8577}
      \field{extraname}{3}
      \field{labelalpha}{Doe95}
      \field{sortinit}{D}
      \field{sortinithash}{6f385f66841fb5e82009dc833c761848}
      \field{extraalpha}{3}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{Sorting Algorithms}
      \field{year}{1995}
    \endentry
|;

my $l3 = q|    \entry{L3}{book}{}{}
      \name{author}{1}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{%
           family={Doe},
           familyi={D\bibinitperiod},
           given={John},
           giveni={J\bibinitperiod}}}%
      }
      \list{location}{1}{%
        {Cambridge}%
      }
      \list{publisher}{1}{%
        {A press}%
      }
      \strng{namehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{fullhash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{fullhashraw}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{bibnamehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authorbibnamehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authornamehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authorfullhash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authorfullhashraw}{bd051a2f7a5f377e3a62581b0e0f8577}
      \field{extraname}{2}
      \field{labelalpha}{Doe95}
      \field{sortinit}{D}
      \field{sortinithash}{6f385f66841fb5e82009dc833c761848}
      \field{extraalpha}{2}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{More and More Algorithms}
      \field{year}{1995}
    \endentry
|;

my $l5 = q|    \entry{L5}{book}{}{}
      \true{moreauthor}
      \true{morelabelname}
      \name{author}{1}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{%
           family={Doe},
           familyi={D\bibinitperiod},
           given={John},
           giveni={J\bibinitperiod}}}%
      }
      \list{location}{1}{%
        {Cambridge}%
      }
      \list{publisher}{1}{%
        {Another press}%
      }
      \strng{namehash}{6eb389989020e8246fee90ac93fcecbe}
      \strng{fullhash}{6eb389989020e8246fee90ac93fcecbe}
      \strng{fullhashraw}{6eb389989020e8246fee90ac93fcecbe}
      \strng{bibnamehash}{6eb389989020e8246fee90ac93fcecbe}
      \strng{authorbibnamehash}{6eb389989020e8246fee90ac93fcecbe}
      \strng{authornamehash}{6eb389989020e8246fee90ac93fcecbe}
      \strng{authorfullhash}{6eb389989020e8246fee90ac93fcecbe}
      \strng{authorfullhashraw}{6eb389989020e8246fee90ac93fcecbe}
      \field{extraname}{1}
      \field{labelalpha}{Doe\textbf{+}95}
      \field{sortinit}{D}
      \field{sortinithash}{6f385f66841fb5e82009dc833c761848}
      \field{extraalpha}{1}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{Some other title about sorting}
      \field{year}{1995}
    \endentry
|;


is_deeply( $main->get_sortingtemplate, $ss, 'sort template');
eq_or_diff( $out->get_output_entry('L4', $main), $l4, '\alphaothers set by "and others"');
eq_or_diff( $out->get_output_entry('L1', $main), $l1, 'bbl test 1');
eq_or_diff( $out->get_output_entry('L2', $main), $l2, 'bbl test 2');
eq_or_diff( $out->get_output_entry('L3', $main), $l3, 'bbl test 3');
eq_or_diff( $out->get_output_entry('L5', $main), $l5, 'bbl test 4');
is_deeply($main->get_keys, ['L5', 'L4', 'L1', 'L3', 'L2'], 'sortorder - 1');

# This would be the same as $main citeorder as both $main and $shs use same
# global sort spec but here it's null because we've removed all shorthands using a map
# above and the filter for the shorthand list only uses entries with SHORTHAND fields ...
is_deeply($shs->get_keys , [], 'sortorder - 2');

# reset options and regenerate information
Biber::Config->setoption('sourcemap', undef); # no longer ignore shorthand*

# Need to reset all entries due to "skip if already in Entries"
# clause in bibtex.pm. Need to clear the cache as we've modified the T::B objects
# by the sourcemap. Need to clear everykeys otherwise we'll just skip the keys
$bibentries->del_entries;
$section->del_everykeys;
Biber::Input::file::bibtex->init_cache;
$biber->prepare;
$section = $biber->sections->get_section(0);
$shs = $biber->datalists->get_list('shorthand/global//global/global/global', 0, 'list');

# Sort by shorthand
is_deeply($shs->get_keys, ['L1', 'L2', 'L3', 'L4', 'L5'], 'sortorder - 3');

