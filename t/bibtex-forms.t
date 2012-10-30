# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 17;

use Biber;
use Biber::Utils;
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

$biber->parse_ctrlfile("bibtex-forms.bcf");
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
my $bibentries = $section->bibentries;
my $main = $biber->sortlists->get_list(0, 'entry', 'nty');

is($bibentries->entry('forms1')->get_field('title'), 'Мухаммад ибн муса ал-Хорезми. Около 783 – около 850', 'forms - 1');
is($bibentries->entry('forms1')->get_field('title', 'original'), 'Мухаммад ибн муса ал-Хорезми. Около 783 – около 850', 'forms - 2');
is($bibentries->entry('forms1')->get_field('title', 'romanised'), 'Mukhammad al-Khorezmi. Okolo 783 – okolo 850', 'forms - 3');
is($bibentries->entry('forms1')->get_field('title', 'translated'), 'Mukhammad al-Khorezmi. Ca. 783 – ca. 850', 'forms - 4');
is($bibentries->entry('forms1')->get_field('publisher', 'original')->[0], 'Наука', 'forms - 5');
is($bibentries->entry('forms1')->get_field('author')->nth_name(2)->get_firstname, 'Борис', 'forms - 6');
# global labelname form
is($bibentries->entry('forms1')->get_field('labelname')->nth_name(2)->get_firstname, 'Борис', 'labelname - 1');
# per-type labelname form
is($bibentries->entry('forms2')->get_field('labelname')->nth_name(1)->get_firstname, 'Boris', 'labelname - 2');
# per-entry labelname form
is($bibentries->entry('forms3')->get_field('labelname')->nth_name(1)->get_firstname, 'Борис', 'labelname - 3');
# global labeltitle form
is($bibentries->entry('forms1')->get_field('labeltitle'), 'Мухаммад ибн муса ал-Хорезми. Около 783 – около 850', 'labeltitle - 1');
# per-type labeltitle form
is($bibentries->entry('forms2')->get_field('labeltitle'), 'Mukhammad al-Khorezmi. Okolo 783 – okolo 850', 'labeltitle - 2');
# per-entry labeltitle form
is($bibentries->entry('forms3')->get_field('labeltitle'), 'Mukhammad al-Khorezmi. Ca. 783 – ca. 850', 'labeltitle - 3');

my $S = [
         [
          {},
          {'author'     => {'form' => 'uniform'}},
          {'author'     => {}},
         ],
         [
          {},
          {'title'      => {'form' => 'translated', 'lang' => 'lang1'}},
          {'title'      => {'form' => 'translated', 'lang' => 'lang2'}},
          {'title'      => {}}
         ],
         [
          {},
          {'year'  => {}},
         ],
        ];

$main->set_sortscheme($S);

$biber->set_output_obj(Biber::Output::bbl->new());
$biber->prepare;
$section = $biber->sections->get_section(0);
is_deeply([$main->get_keys], ['forms5', 'forms4', 'forms6', 'forms3', 'forms1', 'forms2'], 'Forms sorting - 1');

# reset options and regenerate information
Biber::Config->setblxoption('labelalphatemplate', {
  labelelement => [
             {
               labelpart => [
                 {
                  content                   => "author",
                  form                      => "uniform",
                  substring_width           => "3",
                  substring_side            => "left"
                 },
               ],
               order => 1,
             },
             {
               labelpart => [
                 {
                  content                   => "title",
                  form                      => "translated",
                  lang                      => "lang1",
                  substring_width           => "3",
                  substring_side            => "left"
                 },
                 {
                  content                   => "title",
                  substring_width           => "3",
                  substring_side            => "left"
                 },
               ],
               order => 2,
             },
           ],
  type  => "global",
});


foreach my $k ($section->get_citekeys) {
  $bibentries->entry($k)->del_field('sortlabelalpha');
  $bibentries->entry($k)->del_field('labelalpha');
  $main->set_extraalphadata_for_key($k, undef);
}

$biber->prepare;
$section = $biber->sections->get_section(0);
$main = $biber->sortlists->get_list(0, 'entry', 'nty');
$bibentries = $section->bibentries;

is($bibentries->entry('forms1')->get_field('sortlabelalpha'), 'BulRosМух', 'labelalpha forms - 1');
is($bibentries->entry('forms4')->get_field('sortlabelalpha'), 'F t', 'labelalpha forms - 2');
is($bibentries->entry('forms5')->get_field('sortlabelalpha'), 'A t', 'labelalpha forms - 3');
is($bibentries->entry('forms6')->get_field('sortlabelalpha'), 'Z t', 'labelalpha forms - 4');

