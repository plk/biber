# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 16;

use Biber;
use Biber::Utils;
use Biber::Output::bbl;
use Log::Log4perl;
chdir("t/tdata");

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

$biber->parse_ctrlfile('skips.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('sortlocale', 'C');
Biber::Config->setoption('fastsort', 1);

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $shs = $biber->sortlists->get_list(0, 'shorthand', 'shorthand');
my $main = $biber->sortlists->get_list(0, 'entry', 'nty');
my $bibentries = $section->bibentries;

my $set1 = q|    \entry{seta}{set}{}
      \set{set:membera,set:memberb,set:memberc}
      \name{labelname}{1}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
      }
      \strng{namehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{fullhash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \field{labelalpha}{Doe10}
      \field{sortinit}{D}
      \field{extrayear}{1}
      \field{labelyear}{2010}
      \field{labeltitle}{Set Member A}
      \field{extraalpha}{1}
      \field{title}{Set Member A}
      \field{year}{2010}
      \keyw{key1, key2}
    \endentry
|;

my $set2 = q|    \entry{set:membera}{book}{}
      \inset{seta}
      \name{labelname}{1}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
      }
      \strng{namehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{fullhash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \field{sortinit}{D}
      \field{labeltitle}{Set Member A}
      \field{title}{Set Member A}
      \field{year}{2010}
      \keyw{key1, key2}
    \endentry
|;

my $set3 = q|    \entry{set:memberb}{book}{}
      \inset{seta}
      \name{labelname}{1}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
      }
      \strng{namehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{fullhash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \field{sortinit}{D}
      \field{labeltitle}{Set Member B}
      \field{title}{Set Member B}
      \field{year}{2010}
    \endentry
|;

my $set4 = q|    \entry{set:memberc}{book}{}
      \inset{seta}
      \name{labelname}{1}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
      }
      \strng{namehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{fullhash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \field{sortinit}{D}
      \field{labeltitle}{Set Member C}
      \field{title}{Set Member C}
      \field{year}{2010}
    \endentry
|;

my $noset1 = q|    \entry{noseta}{book}{}
      \name{labelname}{1}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
      }
      \strng{namehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{fullhash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \field{labelalpha}{Doe10}
      \field{sortinit}{D}
      \field{extrayear}{2}
      \field{labelyear}{2010}
      \field{labeltitle}{Stand-Alone A}
      \field{extraalpha}{2}
      \field{title}{Stand-Alone A}
      \field{year}{2010}
    \endentry
|;

my $noset2 = q|    \entry{nosetb}{book}{}
      \name{labelname}{1}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
      }
      \strng{namehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{fullhash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \field{labelalpha}{Doe10}
      \field{sortinit}{D}
      \field{extrayear}{3}
      \field{labelyear}{2010}
      \field{labeltitle}{Stand-Alone B}
      \field{extraalpha}{3}
      \field{title}{Stand-Alone B}
      \field{year}{2010}
    \endentry
|;

my $noset3 = q|    \entry{nosetc}{book}{}
      \name{labelname}{1}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
      }
      \strng{namehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{fullhash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \field{labelalpha}{Doe10}
      \field{sortinit}{D}
      \field{extrayear}{4}
      \field{labelyear}{2010}
      \field{labeltitle}{Stand-Alone C}
      \field{extraalpha}{4}
      \field{title}{Stand-Alone C}
      \field{year}{2010}
    \endentry
|;

my $sk4 = q|    \entry{skip4}{article}{dataonly}
      \name{labelname}{1}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
      }
      \name{author}{1}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{Doe}{D\bibinitperiod}{John}{J\bibinitperiod}{}{}{}{}}%
      }
      \list{location}{1}{%
        {Cambridge}%
      }
      \list{publisher}{1}{%
        {A press}%
      }
      \strng{namehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{fullhash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \field{sortinit}{D}
      \field{labeltitle}{Algorithms Which Sort}
      \field{shorthand}{AWS}
      \field{title}{Algorithms Which Sort}
      \field{year}{1932}
    \endentry
|;

is_deeply([$shs->get_keys], ['skip1'], 'skiplos - not in LOS');
is($bibentries->entry('skip1')->get_field('options'), 'skipbib', 'Passing skipbib through');
is($bibentries->entry('skip2')->get_field('labelalpha'), 'SA', 'Normal labelalpha');
is($bibentries->entry('skip2')->get_field($bibentries->entry('skip2')->get_labeldate_info->{field}{year}), '1995', 'Normal labelyear');
ok(is_undef($bibentries->entry('skip3')->get_field('labelalpha')), 'skiplab - no labelalpha');
ok(is_undef($bibentries->entry('skip3')->get_labeldate_info), 'skiplab - no labelyear');
ok(is_undef($bibentries->entry('skip4')->get_field('labelalpha')), 'dataonly - no labelalpha');
is($out->get_output_entry('skip4', $main), $sk4, 'dataonly - checking output');
ok(is_undef($bibentries->entry('skip4')->get_labeldate_info), 'dataonly - no labelyear');
is($out->get_output_entry('seta', $main), $set1, 'Set parent - with labels');
is($out->get_output_entry('set:membera', $main), $set2, 'Set member - no labels 1');
is($out->get_output_entry('set:memberb', $main), $set3, 'Set member - no labels 2');
is($out->get_output_entry('set:memberc', $main), $set4, 'Set member - no labels 3');
is($out->get_output_entry('noseta', $main), $noset1, 'Not a set member - extrayear continues from set 1');
is($out->get_output_entry('nosetb', $main), $noset2, 'Not a set member - extrayear continues from set 2');
is($out->get_output_entry('nosetc', $main), $noset3, 'Not a set member - extrayear continues from set 3');

