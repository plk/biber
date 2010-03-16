package Biber::Output::BBL;
use base 'Biber::Output::Base';

use Biber::Utils;
use Biber::Constants;
use IO::File;
use Log::Log4perl qw( :no_extra_logdie_message );
my $logger = Log::Log4perl::get_logger('main');



=head2 output

    output($ref_to_bbl_string, $file_name.bbl);

    Write the bbl file for biblatex.

=cut

sub output {
  my $self = shift;
  my $bblstring = shift;
  my $bblfile = shift;

  $logger->debug("Preparing final output using class __PACKAGE__ ...");

  my $mode;

  if ( Biber::Config->getoption('bibencoding') and ! Biber::Config->getoption('unicodebbl') ) {
    $mode = ':encoding(' . Biber::Config->getoption('bibencoding') . ')';
  } else {
    $mode = ":utf8";
  }

  my $BBLFILE = IO::File->new($bblfile, ">$mode")
    or $logger->logcroak("Failed to open $bblfile : $!");

  print $BBLFILE $$bblstring or $logger->logcroak("Failure to write to $bblfile: $!");
  $logger->info("Output to $bblfile");
  close $BBLFILE or $logger->logcroak("Failure to close $bblfile: $!");
  return;
}
