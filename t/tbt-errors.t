# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 7;

use Biber;
use Biber::Output::bbl;
use Log::Log4perl;
chdir("t/tdata");

# Text::BibTeX errors and warnings are reported through biber with the
# name of the original data source and the line numbers in it

my $biber = Biber->new(noconf => 1);
my $l4pconf = q|
    log4perl.category.main                = WARN, Buffer
    log4perl.appender.Buffer              = Log::Log4perl::Appender::TestBuffer
    log4perl.appender.Buffer.layout       = Log::Log4perl::Layout::SimpleLayout
|;
Log::Log4perl->init(\$l4pconf);

$biber->parse_ctrlfile('tbt-errors.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());
Biber::Config->setoption('nodieonerror', 1); # the data has syntax errors

my @perlwarnings;
{
  local $SIG{__WARN__} = sub { push @perlwarnings, @_ };
  $biber->prepare;
}

my @warnings = grep { /BibTeX subsystem/ } $biber->{warnings}->@*;
my $log = Log::Log4perl::Appender::TestBuffer->by_name('Buffer')->buffer;

is_deeply(\@warnings,
          ['BibTeX subsystem: tbt-errors.bib, line 12, warning: undefined macro "nosuchmacro"',
           'BibTeX subsystem: tbt-errors.bib, line 17, name 2, warning: empty name'],
          'Text::BibTeX warnings with original file name and line');

like($log, qr/^ERROR - BibTeX subsystem: tbt-errors\.bib, line 24, syntax error: found "\{No equals sign\}", expected "="$/m,
     'syntax error with original file name and line');
like($log, qr/^ERROR - BibTeX subsystem: tbt-errors\.bib, line 32, syntax error: found "\@BOOK", expected end of entry/m,
     'missing closing brace reported at the following entry');
unlike($log, qr/\.utf8\b/, 'the preprocessed temporary file is not mentioned');

my @keys = sort $biber->sections->get_section(0)->get_citekeys;
ok((grep { $_ eq 'afterunclosed' } @keys), 'entry after an unclosed entry is still read');
ok((grep { $_ eq 'good' } @keys), 'good entry read');

is_deeply(\@perlwarnings, [], 'no Perl warnings');
