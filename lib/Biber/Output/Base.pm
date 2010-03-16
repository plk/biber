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

=head2 set_output_target_file

    Set the output target file of a Biber::Output::Base object
    A convenience around set_output_target so we can keep track of the
    filename

=cut

sub set_output_target_file {
  my $self = shift;
  my $file = shift;
  $self->{output_target_file} = $file;
  my $TARGET = IO::File->new($file, '>') or $logger->croak("Failed to open $file : $!");
  $self->set_output_target($TARGET);
}


=head2 set_output_target

    Set the output target of a Biber::Output::Base object

=cut

sub set_output_target {
  my $self = shift;
  my $target = shift;
  $logger->croak('Output target must be a IO::Handle object!') unless $target->isa('IO::Handle');
  $self->{output_target} = $target;
  return;
}

=head2 set_output_data

    Set the output data of a Biber::Output::Base object
    $data could be anything - the caller is expected to know.

=cut

sub set_output_data {
  my $self = shift;
  my $data = shift;
  $self->{output_data} = $data;
  return;
}

=head2 add_output_data

    Add to the output data of a Biber::Output::Base object
    The base class method just does a string append

=cut

sub add_output_data {
  my $self = shift;
  my $data = shift;
  $self->{output_data} .= $data;
  return;
}


=head2 output

    Generic base output method

=cut

sub output {
  my $self = shift;
  my $data = $self->{output_data};
  my $target = $self->{output_target};
  my $target_string = "Target"; # Default
  if ($self->{output_target_file}) {
    $target_string = $self->{output_target_file};
  }

  $logger->debug("Preparing final output using class __PACKAGE__ ...");

  print $target $data or $logger->logcroak("Failure to write to $target_string: $!");
  $logger->info("Output to $target_string");
  close $target or $logger->logcroak("Failure to close $target_string: $!");
  return;
}

