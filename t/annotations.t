# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 2;
use Test::Differences;
unified_diff;

use Biber;
use Biber::Utils;
use Biber::Output::bbl;
use Log::Log4perl;
use Unicode::Normalize;
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


Biber::Config->setoption('annotation_marker', '-an');
# This is cached at load time so we need to alter the cache too
$Biber::Config::CONFIG_META_MARKERS{annotation} = quotemeta(Biber::Config->getoption('annotation_marker'));
$biber->parse_ctrlfile('annotations.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $main = $biber->datalists->get_list('nty/global//global/global');

my $ann1 = q|    \entry{ann1}{misc}{}
      \name[default][en-us]{author}{3}{}{%
        {{hash=89a9e5097e11e595700540379c9b3a6b}{%
           family={Last1},
           familyi={L\bibinitperiod},
           given={First1},
           giveni={F\bibinitperiod}}}%
        {{hash=7475b6b7b3c24a2ac6bd4d146cdc74dc}{%
           family={Last2},
           familyi={L\bibinitperiod},
           given={First2},
           giveni={F\bibinitperiod}}}%
        {{hash=fd3dffa06a5d1f89c512841df1ccf4d0}{%
           family={Last3},
           familyi={L\bibinitperiod},
           given={First3},
           giveni={F\bibinitperiod}}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Last1},
          familydefaulten-usi={L\bibinitperiod},
          givendefaulten-us={First1},
          givendefaulten-usi={F\bibinitperiod}
      }
      \namepartms{author}{2}{%
          familydefaulten-us={Last2},
          familydefaulten-usi={L\bibinitperiod},
          givendefaulten-us={First2},
          givendefaulten-usi={F\bibinitperiod}
      }
      \namepartms{author}{3}{%
          familydefaulten-us={Last3},
          familydefaulten-usi={L\bibinitperiod},
          givendefaulten-us={First3},
          givendefaulten-usi={F\bibinitperiod}
      }
      \list{language}{2}{%
        {english}%
        {french}%
      }
      \listitemms{language}{1}{%
        defaulten-us={english}
      }
      \listitemms{language}{2}{%
        defaulten-us={french}
      }
      \strng{namehash}{90ae96c82de92e36949bc64254bbde0c}
      \strng{fullhash}{90ae96c82de92e36949bc64254bbde0c}
      \strng{bibnamehash}{90ae96c82de92e36949bc64254bbde0c}
      \strng{authordefaulten-usbibnamehash}{90ae96c82de92e36949bc64254bbde0c}
      \strng{authordefaulten-usnamehash}{90ae96c82de92e36949bc64254bbde0c}
      \strng{authordefaulten-usfullhash}{90ae96c82de92e36949bc64254bbde0c}
      \field{extraname}{1}
      \field{sortinit}{L}
      \strng{sortinithash}{dad3efd0836470093a7b4a7bb756eb8c}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{title}{The Title}
      \annotation{field}{language}{default}{}{}{0}{ann4}
      \annotation[default][en-us]{field}{title}{default}{}{}{0}{one, two}
      \annotation[default][en-us]{item}{author}{default}{2}{}{0}{corresponding}
      \annotation{item}{language}{default}{1}{}{0}{ann1}
      \annotation{item}{language}{default}{2}{}{0}{ann2, ann3}
      \annotation[default][en-us]{part}{author}{default}{1}{family}{0}{student}
      \warn{\item Trying to data annotate non-existent field 'note', ignoring data annotation}
    \endentry
|;

my $ann2 = q|    \entry{ann2}{misc}{}
      \name[default][en-us]{author}{3}{}{%
        {{hash=89a9e5097e11e595700540379c9b3a6b}{%
           family={Last1},
           familyi={L\bibinitperiod},
           given={First1},
           giveni={F\bibinitperiod}}}%
        {{hash=7475b6b7b3c24a2ac6bd4d146cdc74dc}{%
           family={Last2},
           familyi={L\bibinitperiod},
           given={First2},
           giveni={F\bibinitperiod}}}%
        {{hash=fd3dffa06a5d1f89c512841df1ccf4d0}{%
           family={Last3},
           familyi={L\bibinitperiod},
           given={First3},
           giveni={F\bibinitperiod}}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Last1},
          familydefaulten-usi={L\bibinitperiod},
          givendefaulten-us={First1},
          givendefaulten-usi={F\bibinitperiod}
      }
      \namepartms{author}{2}{%
          familydefaulten-us={Last2},
          familydefaulten-usi={L\bibinitperiod},
          givendefaulten-us={First2},
          givendefaulten-usi={F\bibinitperiod}
      }
      \namepartms{author}{3}{%
          familydefaulten-us={Last3},
          familydefaulten-usi={L\bibinitperiod},
          givendefaulten-us={First3},
          givendefaulten-usi={F\bibinitperiod}
      }
      \list{language}{2}{%
        {english}%
        {french}%
      }
      \listitemms{language}{1}{%
        defaulten-us={english}
      }
      \listitemms{language}{2}{%
        defaulten-us={french}
      }
      \strng{namehash}{90ae96c82de92e36949bc64254bbde0c}
      \strng{fullhash}{90ae96c82de92e36949bc64254bbde0c}
      \strng{bibnamehash}{90ae96c82de92e36949bc64254bbde0c}
      \strng{authordefaulten-usbibnamehash}{90ae96c82de92e36949bc64254bbde0c}
      \strng{authordefaulten-usnamehash}{90ae96c82de92e36949bc64254bbde0c}
      \strng{authordefaulten-usfullhash}{90ae96c82de92e36949bc64254bbde0c}
      \field{extraname}{2}
      \field{sortinit}{L}
      \strng{sortinithash}{dad3efd0836470093a7b4a7bb756eb8c}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{title}{The Title}
      \annotation{field}{language}{alt}{}{}{0}{annz}
      \annotation{field}{language}{default}{}{}{0}{ann4}
      \annotation[default][en-us]{field}{title}{default}{}{}{1}{one}
      \annotation[default][en-us]{field}{title}{french}{}{}{1}{un}
      \annotation[default][en-us]{item}{author}{default}{2}{}{0}{corresponding}
      \annotation{item}{language}{alt}{1}{}{0}{annx}
      \annotation{item}{language}{alt}{2}{}{1}{anny}
      \annotation{item}{language}{default}{1}{}{0}{ann1}
      \annotation{item}{language}{default}{2}{}{1}{ann2}
      \annotation[default][en-us]{part}{author}{default}{1}{family}{1}{student}
    \endentry
|;

eq_or_diff( $out->get_output_entry('ann1', $main), $ann1, 'Annotations - 1' );
eq_or_diff( $out->get_output_entry('ann2', $main), $ann2, 'Annotations - 2' );

