# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 15;
use Test::Differences;
unified_diff;

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
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $main = $biber->datalists->get_list('custom/global//global/global/global');
my $shs = $biber->datalists->get_list('shorthands/global//global/global/global', 0, 'list');

my $bibentries = $section->bibentries;

my $set1 = q|    \entry{seta}{set}{}{}
      \set{set:membera,set:memberb,set:memberc}
      \field{labelalpha}{Doe10}
      \field{extraalpha}{1}
      \field{sortinit}{D}
      \field{sortinithash}{6f385f66841fb5e82009dc833c761848}
      \keyw{key1,key2}
    \endentry
|;

my $set2 = q|    \entry{set:membera}{book}{skipbib=true,skipbiblist=true,skiplab=true,uniquelist=false,uniquename=false}{}
      \inset{seta}
      \name{author}{1}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{%
           family={Doe},
           familyi={D\bibinitperiod},
           given={John},
           giveni={J\bibinitperiod}}}%
      }
      \strng{namehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{fullhash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{fullhashraw}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{bibnamehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authorbibnamehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authornamehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authorfullhash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authorfullhashraw}{bd051a2f7a5f377e3a62581b0e0f8577}
      \field{sortinit}{D}
      \field{sortinithash}{6f385f66841fb5e82009dc833c761848}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{Set Member A}
      \field{year}{2010}
      \field{dateera}{ce}
      \keyw{key1,key2}
    \endentry
|;

my $set3 = q|    \entry{set:memberb}{book}{skipbib=true,skipbiblist=true,skiplab=true,uniquelist=false,uniquename=false}{}
      \inset{seta}
      \name{author}{1}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{%
           family={Doe},
           familyi={D\bibinitperiod},
           given={John},
           giveni={J\bibinitperiod}}}%
      }
      \strng{namehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{fullhash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{fullhashraw}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{bibnamehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authorbibnamehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authornamehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authorfullhash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authorfullhashraw}{bd051a2f7a5f377e3a62581b0e0f8577}
      \field{sortinit}{D}
      \field{sortinithash}{6f385f66841fb5e82009dc833c761848}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{Set Member B}
      \field{year}{2010}
      \field{dateera}{ce}
    \endentry
|;

my $set4 = q|    \entry{set:memberc}{book}{skipbib=true,skipbiblist=true,skiplab=true,uniquelist=false,uniquename=false}{}
      \inset{seta}
      \name{author}{1}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{%
           family={Doe},
           familyi={D\bibinitperiod},
           given={John},
           giveni={J\bibinitperiod}}}%
      }
      \strng{namehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{fullhash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{fullhashraw}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{bibnamehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authorbibnamehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authornamehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authorfullhash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authorfullhashraw}{bd051a2f7a5f377e3a62581b0e0f8577}
      \field{sortinit}{D}
      \field{sortinithash}{6f385f66841fb5e82009dc833c761848}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{Set Member C}
      \field{year}{2010}
      \field{dateera}{ce}
    \endentry
|;

my $noset1 = q|    \entry{noseta}{book}{}{}
      \name{author}{1}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{%
           family={Doe},
           familyi={D\bibinitperiod},
           given={John},
           giveni={J\bibinitperiod}}}%
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
      \field{labelalpha}{Doe10}
      \field{sortinit}{D}
      \field{sortinithash}{6f385f66841fb5e82009dc833c761848}
      \field{extradate}{2}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \field{extraalpha}{2}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{Stand-Alone A}
      \field{year}{2010}
      \field{dateera}{ce}
    \endentry
|;

my $noset2 = q|    \entry{nosetb}{book}{}{}
      \name{author}{1}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{%
           family={Doe},
           familyi={D\bibinitperiod},
           given={John},
           giveni={J\bibinitperiod}}}%
      }
      \strng{namehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{fullhash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{fullhashraw}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{bibnamehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authorbibnamehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authornamehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authorfullhash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authorfullhashraw}{bd051a2f7a5f377e3a62581b0e0f8577}
      \field{extraname}{4}
      \field{labelalpha}{Doe10}
      \field{sortinit}{D}
      \field{sortinithash}{6f385f66841fb5e82009dc833c761848}
      \field{extradate}{3}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \field{extraalpha}{3}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{Stand-Alone B}
      \field{year}{2010}
      \field{dateera}{ce}
    \endentry
|;

my $noset3 = q|    \entry{nosetc}{book}{}{}
      \name{author}{1}{}{%
        {{hash=bd051a2f7a5f377e3a62581b0e0f8577}{%
           family={Doe},
           familyi={D\bibinitperiod},
           given={John},
           giveni={J\bibinitperiod}}}%
      }
      \strng{namehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{fullhash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{fullhashraw}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{bibnamehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authorbibnamehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authornamehash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authorfullhash}{bd051a2f7a5f377e3a62581b0e0f8577}
      \strng{authorfullhashraw}{bd051a2f7a5f377e3a62581b0e0f8577}
      \field{extraname}{5}
      \field{labelalpha}{Doe10}
      \field{sortinit}{D}
      \field{sortinithash}{6f385f66841fb5e82009dc833c761848}
      \field{extradate}{4}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \field{extraalpha}{4}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{title}{Stand-Alone C}
      \field{year}{2010}
      \field{dateera}{ce}
    \endentry
|;

my $sk4 = q|    \entry{skip4}{article}{skipbib=true,skipbiblist=true,skiplab=true,uniquelist=false,uniquename=false}{}
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
      \field{sortinit}{D}
      \field{sortinithash}{6f385f66841fb5e82009dc833c761848}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{shorthand}{AWS}
      \field{title}{Algorithms Which Sort}
      \field{year}{1932}
    \endentry
|;

is_deeply($bibentries->entry('skip1')->get_field('options'), ['skipbib'], 'Passing skipbib through');

eq_or_diff($main->get_entryfield('skip2', 'labelalpha'), 'SA', 'Normal labelalpha');
eq_or_diff($bibentries->entry('skip2')->get_field($bibentries->entry('skip2')->get_labeldate_info->{field}{year}), '1995', 'Normal labelyear');
ok(is_undef($bibentries->entry('skip3')->get_field('labelalpha')), 'skiplab - no labelalpha');
eq_or_diff($bibentries->entry('skip3')->get_labeldate_info->{field}{source}, '', 'skiplab - no labelyear');
ok(is_undef($bibentries->entry('skip4')->get_field('labelalpha')), 'dataonly - no labelalpha');
eq_or_diff($out->get_output_entry('skip4', $main), $sk4, 'dataonly - checking output');
eq_or_diff($bibentries->entry('skip4')->get_labeldate_info->{field}{source}, '', 'dataonly - no labelyear');
eq_or_diff($out->get_output_entry('seta', $main), $set1, 'Set parent - with labels');
eq_or_diff($out->get_output_entry('set:membera', $main), $set2, 'Set member - no labels 1');
eq_or_diff($out->get_output_entry('set:memberb', $main), $set3, 'Set member - no labels 2');
eq_or_diff($out->get_output_entry('set:memberc', $main), $set4, 'Set member - no labels 3');
eq_or_diff($out->get_output_entry('noseta', $main), $noset1, 'Not a set member - extradate continues from set 1');
eq_or_diff($out->get_output_entry('nosetb', $main), $noset2, 'Not a set member - extradate continues from set 2');
eq_or_diff($out->get_output_entry('nosetc', $main), $noset3, 'Not a set member - extradate continues from set 3');

