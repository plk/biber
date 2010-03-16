package Biber::Output::BBL;
use base 'Biber::Output::Base';

use Biber::Utils;
use Biber::Config;
use Biber::Constants;
use IO::File;
use Log::Log4perl qw( :no_extra_logdie_message );
my $logger = Log::Log4perl::get_logger('main');


=head2 set_output_target_file

    Set the output target file of a Biber::Output::Base object
    A convenience around set_output_target so we can keep track of the
    filename

=cut

sub set_output_target_file {
  my $self = shift;
  my $bblfile = shift;
  $self->{output_target_file} = $bblfile;

  my $mode;
  if ( Biber::Config->getoption('bibencoding') and ! Biber::Config->getoption('unicodebbl') ) {
    $mode = ':encoding(' . Biber::Config->getoption('bibencoding') . ')';
  } else {
    $mode = ":utf8";
  }
  my $BBLFILE = IO::File->new($bblfile, ">$mode") or $logger->croak("Failed to open $bblfile : $!");
  $self->set_output_target($BBLFILE);
}

