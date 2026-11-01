# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 18;
use Test::Differences;
unified_diff;

use Biber;
use Biber::Utils;
use Biber::Output::bbl;
use Log::Log4perl;
chdir("t/tdata");

# Custom name parts (biblatex \DeclareNameTemplate, extended name format):
# names with patronymics and papponymics, CJK name parts, and names with no
# family part at all, which are valid when the name parts are given
# explicitly.

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

$biber->parse_ctrlfile('nameparts.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Biber options
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $main = $biber->datalists->get_list('nyt/global//global/global/global');

is_deeply($biber->{warnings} // [], [], 'no warnings (names without a family part are fine)');

# The first name in an entry's .bbl output: its uniqueness attributes, its
# name parts (with their uniqueness values) and sortinit. Hashes are used
# because the order of attributes in the output is not fixed.
sub name_info {
  my $key = shift;
  my $entry = $out->get_output_entry($key, $main) // '';
  my ($attrs, $parts) = $entry =~ m/\\name\{\w+\}\{\d+\}\{[^}]*\}\{%\n\s*\{\{([^}]*)\}\{%\n(.*?)\}\}%/s;
  my %attrs = map { split(/=/, $_, 2) } split(/,/, $attrs // '');
  my %parts;
  while (($parts // '') =~ m/^\s*(\w+)=\{([^}]*)\}/mg) {
    $parts{$1} = $2 unless $1 =~ m/i\z/; # skip initials
  }
  while (($parts // '') =~ m/^\s*(\w+un)=(\d+)/mg) {
    $parts{$1} = $2;
  }
  my ($sortinit) = $entry =~ m/\\field\{sortinit\}\{([^}]*)\}/;
  return {un         => $attrs{un},
          uniquepart => $attrs{uniquepart},
          parts      => \%parts,
          sortinit   => $sortinit};
}

my %expected = (
  # Ethiopian names: given, patronymic and papponymic, no family part
  'demeke'   => [2, 'papponymic', {given => 'Kebede', patronymic => 'Daniel', patronymicun => 2, papponymic => 'Demeke', papponymicun => 2}, 'K'],
  'dameke'   => [2, 'papponymic', {given => 'Kebede', patronymic => 'Daniel', patronymicun => 2, papponymic => 'Dameke', papponymicun => 2}, 'K'],
  'james'    => [2, 'patronymic', {given => 'Kebede', patronymic => 'James', patronymicun => 2, papponymic => 'Demeke', papponymicun => 0}, 'K'],
  'jonathan' => [2, 'patronymic', {given => 'Kebede', patronymic => 'Jonathan', patronymicun => 2, papponymic => 'Kebede', papponymicun => 0}, 'K'],
  'william'  => [2, 'patronymic', {given => 'Kebede', patronymic => 'William', patronymicun => 2, papponymic => 'Kebede', papponymicun => 0}, 'K'],

  # Russian names: family, given and patronymic
  'tolstoy'      => [0, 'base', {family => 'Толстой', given => 'Лев', givenun => 0, patronymic => 'Николаевич', patronymicun => 0}, 'T'],
  'bulgakov'     => [1, 'given', {family => 'Булгаков', given => 'Михаил', givenun => 1, patronymic => 'Афанасьевич', patronymicun => 0}, 'B'],
  'bulgakov:val' => [1, 'given', {family => 'Булгаков', given => 'Валентин', givenun => 1, patronymic => 'Фёдорович', patronymicun => 0}, 'B'],
  'dosto:1'      => [2, 'given', {family => 'Достоевский', given => 'Александр', givenun => 2, patronymic => 'Андреевич', patronymicun => 0}, 'D'],
  'dosto:2'      => [2, 'given', {family => 'Достоевский', given => 'Андрей', givenun => 2, patronymic => 'Андреевич', patronymicun => 0}, 'D'],

  # CJK names: disambiguated by the cjk part
  'zhangx1' => [2, 'cjk', {family => 'Zhang', given => 'Xuecheng', givenun => 2, cjk => '章學成', cjkun => 2}, 'Z'],
  'zhangx2' => [2, 'cjk', {family => 'Zhang', given => 'Xuecheng', givenun => 2, cjk => '張學成', cjkun => 2}, 'Z'],

  # Ordinary BibTeX format names
  'bronte:c'    => [1, 'given', {family => 'Brontë', given => 'Charlotte', givenun => 1}, 'B'],
  'bronte:e'    => [1, 'given', {family => 'Brontë', given => 'Emily', givenun => 1}, 'B'],
  'austen:jane' => [2, 'given', {family => 'Austen', given => 'Jane', givenun => 2}, 'A'],
  'austen:john' => [2, 'given', {family => 'Austen', given => 'John', givenun => 2}, 'A'],
);

is_deeply([sort $biber->sections->get_section(0)->get_citekeys], [sort keys %expected],
          'all entries created');

foreach my $key (sort keys %expected) {
  my ($un, $uniquepart, $parts, $sortinit) = $expected{$key}->@*;
  eq_or_diff(name_info($key), {un => $un, uniquepart => $uniquepart, parts => $parts, sortinit => $sortinit},
             "name parts and uniqueness - $key");
}
