package Biber::Output::Base;

use Biber::Utils;
use Biber::Constants;
use IO::File;
use Log::Log4perl qw( :no_extra_logdie_message );
my $logger = Log::Log4perl::get_logger('main');

=head2 new

    Initialize a Biber::Output::Base object

=cut

sub new {
  my $class = shift;
  my $obj = shift;
  my $self;
  if (defined($obj) and ref($obj) eq 'HASH') {
    $self = bless $obj, $class;
  }
  else {
    $self = bless {}, $class;
  }
  return $self;
}

=head2 output

    Generic base output method

=cut

sub output {
  my $self = shift;
  my $string = shift;
  my $file = shift;

  $logger->debug("Preparing final output using class __PACKAGE__ ...");

  my $mode;

  my $FILE = IO::File->new($file, '>')
    or $logger->logcroak("Failed to open $file : $!");

  print $FILE $$string or $logger->logcroak("Failure to write to $file: $!");
  $logger->info("Output to $file");
  close $FILE or $logger->logcroak("Failure to close $file: $!");
  return;
}

