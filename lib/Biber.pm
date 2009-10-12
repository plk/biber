package Biber;
use strict;
use warnings;
use Carp;
use IO::File;
use File::Spec;
use Encode;
use POSIX qw( locale_h ); # for sorting with built-in "sort"
use IPC::Cmd qw( can_run run );
use Cwd qw( abs_path );
use Biber::Constants;
use List::Util qw( first );
use Biber::Internals;
use Biber::Utils;
use LaTeX::Decode;
use Storable qw( dclone );
use Log::Log4perl qw( :no_extra_logdie_message );
use base 'Biber::Internals';
use Config::General qw( ParseConfig );
use Data::Dump;
our @ISA;

=encoding utf-8

=head1 NAME

Biber - main module for biber, a bibtex replacement for users of biblatex

=head1 VERSION

Version 0.5

=cut

our $VERSION = '0.5';

=head1 SYNOPSIS

    use Biber;

    my $biber = Biber->new();
    $biber->parse_auxfile("example.aux");
    $biber->prepare;
    $biber->print_to_bbl("example.bbl");

=cut

#TODO read config file (e.g. $HOME/.biber.conf to change default options)

#TODO put the following hashes in a Biber::Config object ?

our %seenkeys    = ();
our %crossrefkeys = ();
our %entrieswithcrossref = ();
our %inset_entries = ();
our %localoptions = ();
our %seennamehash = ();
our %uniquenamecount = ();
our %seenauthoryear = ();
our %seenlabelyear = ();
our %is_name_entry = map { $_ => 1 } @NAMEFIELDS;

my $logger = Log::Log4perl::get_logger('main');

=head1 FUNCTIONS

=head2 new

    Initialize the Biber object, optionally passing options as argument in a hashref.

    my $opts = { fastsort => 1, datafile => 'biblatex.xml', outfile => 'test.bbl' };
    my $biber = Biber->new($opts);

=cut

sub new {
    my ($class, $opts) = @_;
    my $self = bless {}, $class;
    if (defined $opts->{configfile}) {
        $self->_initopts( $opts->{configfile} );
    } else {
        $self->_initopts();
    }
    if ($opts) {
        my %params = %$opts;
        foreach (keys %params) {
          $self->{config}{setoncmdline}{$_} = $self->{config}{$_} = $params{$_};
        }
    };
    return $self
}

=head2 config

    Returns the value of a biber configuration parameter.

    $biber->config('param');

=cut

sub config {
    my ($self, $opt) = @_;
    return $self->{config}->{$opt};
}

=head2 _init

    Reset internal hashes to defaults. This is needed for tests when ->prepare is used more than once

=cut

sub _init {
  %localoptions = ();
  %seennamehash = ();
  %uniquenamecount = ();
  %seenauthoryear = ();
  %seenlabelyear = ();
}

=head2 _initopts

    Initialise default options, optionally with config file as argument

=cut


sub _initopts {
    my ($self, $conffile) = @_;
    my %LOCALCONF = ();

    # if a config file was given as cmd-line arg, it overrides everything else
    unless ( defined $conffile and -f $conffile ) {
        $conffile = $self->config_file
    }

    if (defined $conffile) {
        %LOCALCONF = ParseConfig(-ConfigFile => $conffile, -UTF8 => 1) or 
            $logger->logcarp("Failure to read config file " . $conffile . "\n $@");
    }
    my %CONFIG = (%CONFIG_DEFAULT, %LOCALCONF);
    foreach (keys %CONFIG) {
        $self->{config}->{$_} = $CONFIG{$_}
    }
    return;
}

=head2 config_file

Returns the full path of the B<Biber> configuration file. 
If returns the first file found among:
=over
 =item C<biber.conf> in the current directory
 =item C<$HOME/.biber.conf> 
 =item the output of C<kpsewhich biber.conf> (if available on the system).
=back
If no file is found, it returns C<undef>.

=cut

sub config_file {
    my $self = shift;

    my $biberconf;
    if ( -f "$BIBER_CONF_NAME" ) {
        $biberconf = abs_path($BIBER_CONF_NAME);
    }
    elsif ( -f "$ENV{HOME}/.$BIBER_CONF_NAME" ) {
        $biberconf = "$ENV{HOME}/.$BIBER_CONF_NAME";
    }
    elsif ( can_run("kpsewhich") ) {
        scalar run( command => [ 'kpsewhich', $BIBER_CONF_NAME ], 
                    verbose => 0, 
                    buffer => \$biberconf );
   }
   else {
        $biberconf = undef;
   }
   return $biberconf
}



=head2 citekeys

    my @citekeys = $biber->citekeys;
    
    Returns the array of all citation keys currently registered by Biber.

=cut

sub citekeys {
    my $self = shift;
    if ( $self->{citekeys} ) {
        return @{ $self->{citekeys} }
    } else {
        return ()
    }
}

=head2 bibentry

    my %bibentry = $biber->bibentry($citekey);
    
    Returns a hash containing the data of bibliographic entry for a given citekey.

=cut

sub bibentry {
    my ($self, $key) = @_;
    return %{ $self->{bib}->{$key} }
}

=head2 bib

    Return a hash containing all bibliographic data.

=cut

sub bib {
    my $self = shift;
    if ( $self->{bib} ) {
        return %{ $self->{bib} } 
    }
    else {
        return 
    }
}

=head2 shorthands
    
    Returns the list of all shorthands. 

=cut

sub shorthands {
    my $self = shift;
    if ( $self->{shorthands} ) {
        return @{ $self->{shorthands} }
    } else {
        return
    }
}

sub _addshorthand {
    my ($self, $key) = @_;
    my @los;
    if ( $self->{shorthands} ) {
        @los = @{ $self->{shorthands} } 
    } else {
        @los = ();
    };
    push @los, $key;
    $self->{shorthands} = [ @los ];
    return
}

=head2 parse_auxfile

    Read the .aux file generated by LaTeX, identify all citekeys and configuration
    parameters, and store them in the Biber object.

=cut

sub parse_auxfile {

    my $self = shift;
    my $auxfile = shift;
    my @bibdatafiles = ();
    if ($self->config('bibdata')) { 
        @bibdatafiles = @{ $self->{config}->{bibdata} }
    };

    my @auxcitekeys = $self->citekeys;

    $logger->logdie("Cannot find file '$auxfile'!") unless -f $auxfile;
    $logger->logcroak("File '$auxfile' is not an .aux file!") unless $auxfile =~ m/\.aux$/;

    my $aux = new IO::File "<$auxfile" or $logger->logcroak("Failed to open $auxfile : $!");

    my $ctrl_file = "";

    local $/ = "\n";

    $logger->info("Reading $auxfile");
    
    while (<$aux>) {
    
        if ( $_ =~ /^\\bibdata/ ) { 
        
            # There can be more than one bibdata file! 
            # We can parse many bib and/or xml files
            # Datafile given as option -d should be parsed first, then the other ones
            (my $bibdatastring) = $_ =~ m/^\\bibdata{ #{ <- for balancing brackets in vim
                                               ([^}]+)
                                                      }/x;
            
            my @tmp = split/,/, $bibdatastring;
            
            $ctrl_file = shift @tmp;

            $logger->debug("control file is $ctrl_file.bib");
            
            if (defined $bibdatafiles[0]) {

                push (@bibdatafiles, @tmp);

            }
            else {

                @bibdatafiles = @tmp;

            }

            $self->{config}->{bibdata} = [ @bibdatafiles ];
        }

        if ( $_ =~ /^\\citation/ ) { 
            m/^\\citation{ #{ for readability in vim
                          ([^}]+)
                                 }/x;
            if ( $1 eq '*' ) {

                $self->{config}->{allentries} = 1;

                $logger->info("Processing all citekeys"); 

                # we stop reading the aux file as soon as we encounter \citation{*}
                last

            } elsif ( ! $seenkeys{$1} && ( $1 ne "biblatex-control" ) ) {

                push @auxcitekeys, decode_utf8($1);

                $seenkeys{$1}++

            }
        }
    }

    $self->parse_ctrlfile($ctrl_file) if $ctrl_file;
    
    unless (@bibdatafiles) {
        $logger->logcroak("No database is provided in the file '$auxfile'! Exiting");
    }

    unless ($self->config('allentries') or @auxcitekeys) {
        $logger->logcroak("The file '$auxfile' does not contain any citations!")
    }

    $logger->info("Found ", $#auxcitekeys+1 , " citekeys in aux file") 
        unless $self->config('allentries') ;

    @auxcitekeys = sort @auxcitekeys if $self->config('debug');

    $logger->debug("The citekeys are:\n", "@auxcitekeys", "\n\n") 
        unless $self->config('allentries') ;
    
    $self->{citekeys} = [ @auxcitekeys ];

    return;
}


=head2 parse_auxfile_v2

    * VERSION 2 experimental code *
    Read the .aux file generated by LaTeX, identify all citekeys and configuration
    parameters, and store them in the Biber object.

=cut

#V2
sub parse_auxfile_v2 {

    my $self = shift;
    my $auxfile = shift;
    my @bibdatafiles = ();
    if ($self->config('bibdata')) {
        @bibdatafiles = @{ $self->{config}->{bibdata} }
    };

    my @auxcitekeys = $self->citekeys;

    $logger->logcroak("Cannot find file '$auxfile'!") unless -f $auxfile;
    $logger->logcroak("File '$auxfile' is not an .aux file!") unless $auxfile =~ m/\.aux$/;

    my $aux = new IO::File "<$auxfile" or $logger->logcroak("Failed to open $auxfile : $!");

    my $ctrl_file = "";

    local $/ = "\n";

    $logger->info("Reading $auxfile"); 

    while (<$aux>) {

        if ( $_ =~ /^\\bibdata/ ) { 

            # There can be more than one bibdata file! 
            # We can parse many bib and/or xml files
            # Datafile given as option -d should be parsed first, then the other ones
            (my $bibdatastring) = $_ =~ m/^\\bibdata{ #{ <- for balancing brackets in vim
                                               ([^}]+)
                                                      }/x;

            my @tmp = split/,/, $bibdatastring;

                        $ctrl_file = $auxfile;
                        $ctrl_file =~ s/\.aux\z//xms;

            $logger->debug("control file is $ctrl_file.bcf");

            if (defined $bibdatafiles[0]) {

                push (@bibdatafiles, @tmp);

            }
            else {

                @bibdatafiles = @tmp;

            }

            $self->{config}{bibdata} = [ @bibdatafiles ];
        }

        if ( $_ =~ /^\\citation/ ) { 
            m/^\\citation{ #{ for readability in vim
                          ([^}]+)
                                 }/x;
            if ( $1 eq '*' ) {

                $self->{config}{allentries} = 1;

                $logger->info("Processing all citekeys"); 

                # we stop reading the aux file as soon as we encounter \citation{*}
                last

            } elsif ( ! $seenkeys{$1} ) {

                push @auxcitekeys, decode_utf8($1);

                $seenkeys{$1}++

            }
        }
    }

    $self->parse_ctrlfile_v2($ctrl_file) if $ctrl_file;

    unless (@bibdatafiles) {
        $logger->logcroak("No database is provided in the file '$auxfile'! Exiting")
    }

    unless ($self->config('allentries') or @auxcitekeys) {
        $logger->logcroak("The file '$auxfile' does not contain any citations!")
    }

    $logger->info("Found ", $#auxcitekeys+1 , " citekeys in aux file") 
        unless $self->config('allentries') ;

    if ($self->config('debug')) {
      my @debug_auxcitekeys = sort @auxcitekeys;
      unless ($self->config('allentries')) {
        $logger->debug("The citekeys are:\n", "@debug_auxcitekeys", "\n");
      }
    }

    $self->{citekeys} = [ @auxcitekeys ];
    # Preserve the original cite order for citekeys sort
    $self->{orig_order_citekeys} = [ @auxcitekeys ];

    return;
}

=head2 parse_ctrlfile

    This method is automatically called by parse_auxfile. It reads the control file
    generated by biblatex to figure out the various biblatex options.

=cut

sub parse_ctrlfile {
    my ($self, $ctrl_file) = @_;

    $logger->warn("Cannot find control file '$ctrl_file.bib'!") unless -f "$ctrl_file.bib";

    my $ctrl = new IO::File "<$ctrl_file.bib"
          or $logger->logcroak("Cannot open $ctrl_file.bib: $!");

    $logger->info("Reading $ctrl_file.bib") ;

    while (<$ctrl>) {

        next unless /^\s*ctrl-options/;

        (my $opts) = /{(.+)}/; ## ex: {0.8b:0:0:0:0:1:1:0:0:1:0:1:2:1:3:1:79:+}
        ($self->{config}{biblatex}{global}{controlversion},
        $self->{config}{biblatex}{global}{debug},
        my $ignore,
        $self->{config}{biblatex}{global}{terseinits},
        $self->{config}{biblatex}{global}{useprefix},
        $self->{config}{biblatex}{global}{useauthor},
        $self->{config}{biblatex}{global}{useeditor},
        $self->{config}{biblatex}{global}{usetranslator},
        $self->{config}{biblatex}{global}{labelalpha},
        $self->{config}{biblatex}{global}{labelyear},
        $self->{config}{biblatex}{global}{singletitle},
        $self->{config}{biblatex}{global}{uniquename},
        $self->{config}{biblatex}{global}{sorting_label},
        $self->{config}{biblatex}{global}{sortlos},
        $self->{config}{biblatex}{global}{maxnames},
        $self->{config}{biblatex}{global}{minnames},
        my $ignore_again,
        $self->{config}{biblatex}{global}{alphaothers}) = split /:/, $opts;

        my $controlversion = $self->{config}{biblatex}{global}{controlversion};
        $logger->warn("You are using biblatex version $controlversion : 
            biber is more likely to work with version $BIBLATEX_VERSION.") 
            unless substr($controlversion, 0, 3) eq $BIBLATEX_VERSION;
    }

    if ($self->{config}{biblatex}{global}{labelyear}) {
      $self->{config}{biblatex}{global}{labelyear} = [ 'year' ]; # set default
    }
    $self->{config}{biblatex}{global}{labelname} = ['shortauthor', 'author', 'shorteditor', 'editor', 'translator']; # set default 
    my $sorting = ($self->{config}{biblatex}{global}{sorting_label} or '1');
    if ($sorting == 1) { # nty
      $self->{config}{biblatex}{global}{sorting_label} = [
                                                    [
                                                     {'presort'    => {}},
                                                     {'mm'         => {}},
                                                    ],
                                                    [
                                                     {'sortkey'    => {'final' => 1}}
                                                    ],
                                                    [
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}}
                                                    ],
                                                    [
                                                     {'volume'     => {}},
                                                     {'0000'       => {}}
                                                    ]
                                                   ];
    } elsif ($sorting == 2) { # nyt
      $self->{config}{biblatex}{global}{sorting_label} = [
                                                    [
                                                     {'presort'    => {}},
                                                     {'mm'         => {}},
                                                    ],
                                                    [
                                                     {'sortkey'    => {'final' => 1}}
                                                    ],
                                                    [
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}}
                                                    ],
                                                    [
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {'volume'     => {}},
                                                     {'0000'       => {}}
                                                    ]
                                                   ];
    } elsif ($sorting == 3) { # nyvt
      $self->{config}{biblatex}{global}{sorting_label} = [
                                                    [
                                                     {'presort'    => {}},
                                                     {'mm'         => {}},
                                                    ],
                                                    [
                                                     {'sortkey'    => {'final' => 1}}
                                                    ],
                                                    [
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}}
                                                    ],
                                                    [
                                                     {'volume'     => {}},
                                                     {'0000'       => {}}
                                                    ],
                                                    [
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ]
                                                   ];
    } elsif ($sorting == 12) { # anyt
      $self->{config}{biblatex}{global}{sorting_label} = [
                                                    [
                                                     {'presort'    => {}},
                                                     {'mm'         => {}},
                                                    ],
                                                    [
                                                     {'labelalpha' => {}}
                                                    ],
                                                    [
                                                     {'sortkey'    => {'final' => 1}}
                                                    ],
                                                    [
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}}
                                                    ],
                                                    [
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {'sorttitle'  => {}},
                                                     {'0000'       => {}}
                                                    ]
                                                   ];

    } elsif ($sorting == 13) { # anyvt
      $self->{config}{biblatex}{global}{sorting_label} = [
                                                    [
                                                     {'presort'    => {}},
                                                     {'mm'         => {}},
                                                    ],
                                                    [
                                                     {'labelalpha' => {}}
                                                    ],
                                                    [
                                                     {'sortkey'    => {'final' => 1}}
                                                    ],
                                                    [
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}}
                                                    ],
                                                    [
                                                     {'volume'     => {}},
                                                     {'0000'       => {}}
                                                    ],
                                                    [
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ]
                                                   ];

    } elsif ($sorting == 21) { # ynt
      $self->{config}{biblatex}{global}{sorting_label} = [
                                                    [
                                                     {'presort'    => {}},
                                                     {'mm'         => {}},
                                                    ],
                                                    [
                                                     {'sortkey'    => {'final' => 1}}
                                                    ],
                                                    [
                                                     {'sortyear'   => {}},
                                                     {'year'       => {}},
                                                     {'9999'       => {}}
                                                    ],
                                                    [
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                   ];

    } elsif ($sorting == 22) { # ydnt
      $self->{config}{biblatex}{global}{sorting_label} = [
                                                    [
                                                     {'presort'    => {}},
                                                     {'mm'         => {}},
                                                    ],
                                                    [
                                                     {'sortkey'    => {'final' => 1}}
                                                    ],
                                                    [
                                                     {'sortyearD'  => {}},
                                                     {'yearD'      => {}},
                                                     {'9999'       => {}}
                                                    ],
                                                    [
                                                     {'sortname'   => {}},
                                                     {'author'     => {}},
                                                     {'editor'     => {}},
                                                     {'translator' => {}},
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                    [
                                                     {'sorttitle'  => {}},
                                                     {'title'      => {}}
                                                    ],
                                                   ];
    } elsif ($sorting == 99) { # debug
      $self->{config}{biblatex}{global}{sorting_label} = [
                                                    [
                                                     {'debug'    => {}},
                                                    ],
                                                   ];
    }
    $self->{config}{biblatex}{global}{sorting_final} = dclone($self->{config}{biblatex}{global}{sorting_label});

    return;
}

=head2 parse_ctrlfile_v2

    * VERSION 2 experimental code *
    This method is automatically called by parse_auxfile. It reads the control file
    generated by biblatex to figure out the various biblatex options.
    See Constants.pm for defaults and example of the data structure being built here.

=cut

#V2
sub parse_ctrlfile_v2 {
  my ($self, $ctrl_file) = @_;

  $logger->warn("Cannot find control file '$ctrl_file.bcf'!") unless -f "$ctrl_file.bcf";

  # Validate if asked to
  if ($self->config('validate')) {
    require Config;
    require XML::LibXML;

    # Set up XML parser
    my $CFxmlparser = XML::LibXML->new();
    $CFxmlparser->line_numbers(1); # line numbers for more informative errors

    # Set up schema
    # FIXME How can we be sure that Biber is installed in sitelib and not vendorlib ?
    my $CFxmlschema = XML::LibXML::RelaxNG->new( 
          location => File::Spec->catfile($Config::Config{sitelibexp}, 'Biber', 'bcf.rng') 
        )
        or $logger->warn("Cannot find XML::LibXML::RelaxNG schema. Skipping validation : $!");

    # basic parse and XInclude processing
    my $CFxp = $CFxmlparser->parse_file("$ctrl_file.bcf");

    # XPath context
    my $CFxpc = XML::LibXML::XPathContext->new($CFxp);
    $CFxpc->registerNs('bcf', 'https://sourceforge.net/projects/biblatex');

    # Validate against schema. Dies if it fails.
    if ($CFxmlschema) {
        eval { $CFxmlschema->validate($CFxp) };
        if (ref($@)) {
        $logger->debug( $@->dump() );
        $logger->logcroak("BibLaTeX control file \"$ctrl_file.bcf\" FAILED TO VALIDATE\n$@");
        }
        elsif ($@) {
        $logger->logcroak("BibLaTeX control file \"$ctrl_file.bcf\" FAILED TO VALIDATE\n$@");
        }
        else {
        $logger->info("BibLaTeX control file \"$ctrl_file.bcf\" validates");
        }
    }

  }

  my $ctrl = new IO::File "<$ctrl_file.bcf"
    or $logger->logcroak("Cannot open $ctrl_file.bcf: $!");

  $logger->info("Reading $ctrl_file.bcf");

  # Read control file
  require XML::LibXML::Simple;
  my $bcfxml = XML::LibXML::Simple::XMLin($ctrl, 'ForceArray' => 1, 'NsStrip' => 1, KeyAttr => []);

  my $controlversion = $self->{config}{biblatex}{global}{controlversion} = $bcfxml->{'version'};
  $logger->warn("Warning: You are using biblatex version $controlversion :
        biber is more likely to work with version $BIBLATEX_VERSION.")
    unless substr($controlversion, 0, 3) eq $BIBLATEX_VERSION;

  # Look at control file and populate our main data structure with its information

  # OPTIONS
  foreach my $bcfopts (@{$bcfxml->{options}}) {
    # Biber options
    if ($bcfopts->{component} eq 'biber') {
      # Global options
      if ($bcfopts->{type} eq 'global') {
        foreach my $bcfopt (@{$bcfopts->{option}}) {
          unless ($self->{config}{setoncmdline}{$bcfopt->{key}}) { # already set on cmd line
            if ($bcfopt->{type} eq 'singlevalued') {
              $self->{config}{$bcfopt->{key}} = $bcfopt->{value};
            } elsif ($bcfopt->{type} eq 'multivalued') {
              $self->{config}{$bcfopt->{key}} =
                [ map {$_->{content}} sort {$a->{order} <=> $b->{order}} @{$bcfopt->{value}} ];
            }
          }
        }
      }
    }
    # BibLaTeX options
    if ($bcfopts->{component} eq 'biblatex') {
      # Global options
      if ($bcfopts->{type} eq 'global') {
        foreach my $bcfopt (@{$bcfopts->{option}}) {
          if ($bcfopt->{type} eq 'singlevalued') {
            $self->{config}{biblatex}{global}{$bcfopt->{key}} = $bcfopt->{value};
          } elsif ($bcfopt->{type} eq 'multivalued') {
            $self->{config}{biblatex}{global}{$bcfopt->{key}} =
              [ map {$_->{content}} sort {$a->{order} <=> $b->{order}} @{$bcfopt->{value}} ];
          }
        }
      }
      # Entrytype options
      else {
        my $entrytype = $bcfopts->{type};
        foreach my $bcfopt (@{$bcfopts->{option}}) {
          if ($bcfopt->{type} eq 'singlevalued') {
            $self->{config}{biblatex}{$entrytype}{$bcfopt->{key}} = $bcfopt->{value};
          } elsif ($bcfopt->{type} eq 'multivalued') {
            $self->{config}{biblatex}{$entrytype}{$bcfopt->{key}} =
              [ map {$_->{content}} sort {$a->{order} <=> $b->{order}} @{$bcfopt->{value}} ];
          }
        }
      }
    }
  }
  # SORTING schemes
  foreach my $sortschemes (@{$bcfxml->{sorting}}) {
    my $sorting_label = [];
    my $sorting_final = [];
    foreach my $sort (sort {$a->{order} <=> $b->{order}} @{$sortschemes->{sort}}) {
      my $sortingitems_label;
      my $sortingitems_final;

      # Determine which sorting pass(es) to include the item in
      my $whichpass = ($sort->{pass} or 'both');

      # Generate sorting pass structures
      foreach my $sortitem (sort {$a->{order} <=> $b->{order}} @{$sort->{sortitem}}) {
        my $sortitemattributes = {};
        if (defined($sortitem->{final})) { # Found a sorting short-circuit marker
          $sortitemattributes->{final} = 1;
        }
        if (defined($sortitem->{substring_side})) { # Found sorting substring side attribute
          $sortitemattributes->{substring_side} = $sortitem->{substring_side};
        }
        if (defined($sortitem->{substring_width})) { # Found sorting substring length attribute
          $sortitemattributes->{substring_width} = $sortitem->{substring_width};
        }
        if (defined($sortitem->{pad_width})) { # Found sorting pad length attribute
          $sortitemattributes->{pad_width} = $sortitem->{pad_width};
        }
        if (defined($sortitem->{pad_char})) { # Found sorting pad char attribute
          $sortitemattributes->{pad_char} = $sortitem->{pad_char};
        }
        if (defined($sortitem->{pad_side})) { # Found sorting pad side attribute
          $sortitemattributes->{pad_side} = $sortitem->{pad_side};
        }
        if (defined($sortitem->{sort_direction})) { # Found sorting direction attribute
          $sortitemattributes->{sort_direction} = $sortitem->{sort_direction};
        }
        # No pass specified, sortitem is included in both sort passes
        # Note that we're cloning the sortitemattributes object so as not to have pointers
        # from one structure to the other
        if ($whichpass eq 'both') {
          push @{$sortingitems_label}, {$sortitem->{content} => $sortitemattributes};
          push @{$sortingitems_final}, {$sortitem->{content} => dclone($sortitemattributes)};
        }
        # "label" specified, sortitem is included only on "label" sort pass
        elsif ($whichpass eq 'label') {
          push @{$sortingitems_label}, {$sortitem->{content} => $sortitemattributes};
        }
        # "final" specified, sortitem is included only on "final" sort pass
        elsif ($whichpass eq 'final') {
          push @{$sortingitems_final}, {$sortitem->{content} => $sortitemattributes};
        }
      }

      # Only push a sortitem if defined. If the item has a conditional "pass"
      # attribute, it may be ommitted in which case we don't want an empty array ref
      # pushing
      push @{$sorting_label}, $sortingitems_label if defined($sortingitems_label);
      push @{$sorting_final}, $sortingitems_final if defined($sortingitems_final);
    }
    $self->{config}{biblatex}{$sortschemes->{type}}{sorting_label} = $sorting_label;
    $self->{config}{biblatex}{$sortschemes->{type}}{sorting_final} = $sorting_final;

  }

  # BIB SECTIONS
  foreach my $section (@{$bcfxml->{section}}) {
    push @{$self->{config}{biblatex}{global}{bibsections}{$section->{number}}}, @{$section->{citekey}};
  }
  return;
}

#=====================================================
# Parse BIB file
#=====================================================

=head2 parse_bibtex

    This is a wrapper method to parse a bibtex database. If available it will
    pass the job to Text::BibTeX via Biber::BibTeX, otherwise it relies on a
    slower pure Perl parser implemented in Biber::BibTeX::PRD.

    $biber->parse_bibtex("data.bib");

=cut

sub parse_bibtex {
    my ($self, $filename) = @_;
    
    $logger->info("Processing bibtex file $filename");

    my @localkeys = ();

    my $ufilename = "$filename.utf8";

    if ( !$self->config('unicodebib') && $self->config('unicodebbl') ) {
        require LaTeX::Decode;
        require File::Slurp;
        my $ubib = IO::File->new( $ufilename, ">:utf8" );
        # $ubib->binmode(':utf8');

        my $mode = "";

#        if ( $self->config('bibencoding') ) {
#            $mode = ':encoding(' . $self->config('bibencoding') . ')';
#        } else {
#            $mode = "";
#        };
        
        my $infile = IO::File->new( $filename, "<$mode" );

        my $buf    = File::Slurp::read_file($infile) 
           or $logger->logcroak("Can't read $filename");

        if ( $self->config('bibencoding') ) {
            $buf = decode($self->config('bibencoding'), $buf)
        };

        print $ubib LaTeX::Decode::latex_decode($buf) 
          or $logger->logcroak("Can't write to $ufilename : $!");
        $ubib->close or $logger->logcroak("Can't close filehandle to $ufilename: $!");

        $filename  = $ufilename;
        
        $self->{config}->{unicodebib} = 1;
    }

    unless ( eval "require Text::BibTeX; 1" ) {
        $self->{config}->{useprd} = 1
    }

    unless ( $self->config('useprd') ) {
        
        require Biber::BibTeX;
        push @ISA, 'Biber::BibTeX';

        @localkeys = $self->_text_bibtex_parse($filename);
        
    }
    else {

        require Biber::BibTeX::PRD;
        push @ISA, 'Biber::BibTeX::PRD';

        $logger->info("Using a Parse::RecDescent parser...");

        # we only add this warning if the bib file is larger than 20KB
        if (-s $filename > 20000 ) {
            $logger->warn("Note that it can be very slow with large bib files!\n",
                          "You are advised to install Text::BibTeX for faster processing!");
        };
        
        @localkeys = $self->_bibtex_prd_parse($filename);
    }

    #FIXME optional?
    unlink $ufilename if -f $ufilename;

    if ($self->config('allentries')) {
        map { $seenkeys{$_}++ } @localkeys
    }
    
    my %bibentries = $self->bib;

    # if allentries, push all bibdata keys into citekeys (if they are not already there)
    # Can't just make citekeys = bibdata keys as this loses information about citekeys
    # that are missing data entries.
    if ($self->config('allentries')) {
        foreach my $bibkey (keys %{$self->{bib}}) {
            push @{$self->{citekeys}}, $bibkey 
                unless (first {$bibkey eq $_} @{$self->{citekeys}});
        }
    }

    return;

}

=head2 parse_biblatexml

    $biber->parse_biblatexml('data.xml');

    Parse a database in the BibLaTeXML format with Biber::BibLaTeXML (via
    XML::LibXML). If the suffix is dbxml, then the database is assumed to
    be stored in a Berkeley DBXML container and will be queried through the
    Sleepycat::DbXml interface.

=cut

sub parse_biblatexml {
    my ($self, $xml) = @_;
    require Biber::BibLaTeXML;
    push @ISA, 'Biber::BibLaTeXML';
    $self->_parse_biblatexml($xml);
}

=head2 process_crossrefs
    
    $biber->process_crossrefs;

    Ensures proper inheritance of data from cross-references. 
    This method is automatically called by C<prepare>.

=cut

sub process_crossrefs {
    my $self = shift;
    my %bibentries = $self->bib;
    $logger->debug("Processing crossrefs for keys:");
    foreach my $citekeyx (keys %entrieswithcrossref) {
        $logger->debug("   * '$citekeyx'");
        my $xref = $entrieswithcrossref{$citekeyx};
        my $type = $bibentries{$citekeyx}->{entrytype};
        if ($type eq 'review') {
                #TODO
        }
        if ($type =~ /^in(proceedings|collection|book)$/) {
            # inherit all that is undefined, except title etc
            foreach my $field (keys %{$bibentries{$xref}}) {
                next if $field =~ /title/;
                if (! $bibentries{$citekeyx}->{$field}) {
                    $bibentries{$citekeyx}->{$field} = $bibentries{$xref}->{$field};
                }
            }
            # inherit title etc as booktitle etc
            $bibentries{$citekeyx}->{booktitle} = $bibentries{$xref}->{title};
            if ($bibentries{$xref}->{titleaddon}) {
                $bibentries{$citekeyx}->{booktitleaddon} = $bibentries{$xref}->{titleaddon}
            }
            if ($bibentries{$xref}->{subtitle}) {
                $bibentries{$citekeyx}->{booksubtitle} = $bibentries{$xref}->{subtitle}
            }
        }
        else { # inherits all
            foreach my $field (keys %{$bibentries{$xref}}) {
                if (! $bibentries{$citekeyx}->{$field}) {
                    $bibentries{$citekeyx}->{$field} = $bibentries{$xref}->{$field};
                }
            }
       }
       if ($type eq 'inbook') {
            $bibentries{$citekeyx}->{bookauthor} = $bibentries{$xref}->{author} 
        }
        # MORE?
        #$bibentries{$citekeyx}->{} = $bibentries{$xref}->{} 
    }

    # we make sure that crossrefs that are directly cited or cross-referenced 
    # at least $mincrossrefs times are included in the bibliography
    foreach my $k ( keys %crossrefkeys ) {
        if ( $seenkeys{$k} || $crossrefkeys{$k} >= $self->config('mincrossrefs') ) {
            $logger->debug("Removing unneeded crossrefkey $k");
            delete $crossrefkeys{$k};
        }
    }

    $self->{bib} = { %bibentries }
}

=head2 postprocess

    Various postprocessing operations, mostly to generate special fields for
    biblatex. This method is automatically called by C<prepare>.

=cut

###############################################
# internal post-processing to prepare output

# Here we parse names, generate the "namehash" and the strings for
# "labelname", "labelyear", "labelalpha", "sortstrings", etc.

#TODO flesh out this monster into several internal subs :)

sub postprocess {
    my $self = shift;

    my %namehashcount = ();
    my @foundkeys     = ();

    foreach my $citekey ( $self->citekeys ) {

        my $origkey = $citekey;

        # try lc($citekey), uc($citekey) and ucinit($citekey) before giving up
        if ( !$self->{bib}{$citekey} ) {

            if ( $self->{bib}{ lc($citekey) } ) {

                $citekey = lc($citekey);

            }
            elsif ( $self->{bib}{ uc($citekey) } ) {

                $citekey = uc($citekey);

            }
            elsif ( $self->{bib}{ ucinit($citekey) } ) {

                $citekey = ucinit($citekey);

            }
            else {
                $logger->warn("I didn't find a database entry for '$citekey'");
                $self->{warnings}++;
                next;
            }
        }

        my $be = $self->{bib}{$citekey};

        push @foundkeys, $citekey;

        $be->{origkey} = $origkey;

        $logger->debug("Postprocessing entry '$citekey'");

        ##############################################################
        # 1. DATES
        ##############################################################

        # Here we do some sanity checking on date fields and then parse the
        # *DATE fields into their components, collecting any warnings to put
        # into the .bbl later

        # Quick check on YEAR and MONTH fields which are the only date related
        # components which can be directly set and therefore don't go through
        # the date parsing below
        foreach my $ymfield ('year', 'month') {
          if ($be->{$ymfield} and $be->{$ymfield} !~ /\A\d+\z/xms) {
            $logger->warn("Invalid format of field '$ymfield' - ignoring field in entry '$citekey'");
            $self->{warnings}++;
            $be->{warnings} .= "\\item Invalid format of field '$ymfield' - ignoring field\n";
            delete $be->{$ymfield};
          }
        }

        # Both DATE and YEAR specified
        if ($be->{date} and $be->{year}) {
          $logger->warn("Field conflict - both 'date' and 'year' used - ignoring field 'year' in '$citekey'");
          $self->{warnings}++;
          $be->{warnings} .= "\\item Field conflict - both 'date' and 'year' used - ignoring field 'year'\n";
          delete $be->{year};
        }

        # Both DATE and MONTH specified
        if ($be->{date} and $be->{month}) {
          $logger->warn("Field conflict - both 'date' and 'month' used - ignoring field 'month' in '$citekey'");
          $self->{warnings}++;
          $be->{warnings} .= "\\item Field conflict - both 'date' and 'month' used - ignoring field 'month'\n";
          delete $be->{month};
        }

        # Generate date components from *DATE fields
        foreach my $datetype ('', 'orig', 'event', 'url') {
          if ($be->{$datetype . 'date'}) {
            my $date_re = qr|(\d{4})(?:-(\d{2}))?(?:-(\d{2}))?|xms;
            if ($be->{$datetype . 'date'} =~ m|\A$date_re(/)?(?:$date_re)?\z|xms) {
              $be->{$datetype . 'year'}      = $1 if $1;
              $be->{$datetype . 'month'}     = $2 if $2;
              $be->{$datetype . 'day'}       = $3 if $3;
              $be->{$datetype . 'endmonth'}  = $6 if $6;
              $be->{$datetype . 'endday'}    = $7 if $7;
              if ($4 and $5) { # normal range
                $be->{$datetype . 'endyear'} = $5;
              }
              elsif ($4 and not $5) { # open ended range - endyear is defined but empty
                $be->{$datetype . 'endyear'} = '';                  
              }
            } else {
              $logger->warn("Invalid format of field '" . $datetype . 'date' . "' - ignoring field in entry '$citekey'");
              $self->{warnings}++;
              $be->{warnings} .= "\\item Invalid format of field '" . $datetype . 'date' . "' - ignoring field\n";
              delete $be->{$datetype . 'date'};
            }
          }
        }

        # Now more carefully check the individual date components
        my $opt_dm = qr/(?:event|orig|url)?(?:end)?/xms;
        foreach my $dcf (@DATECOMPONENTFIELDS) {
          my $bad_format = '';
          if ($be->{$dcf}) {
            # months must be in right range
            if ($dcf =~ /\A$opt_dm month\z/xms) {
              unless ($be->{$dcf} >= 1 and $be->{$dcf} <= 12) {
                $bad_format = 1;
              }
            }
            # days must be in right range
            if ($dcf =~ /\A$opt_dm day\z/xms) {
              unless ($be->{$dcf} >= 1 and $be->{$dcf} <= 31) {
                $bad_format = 1;
              }
            }
            if ($bad_format) {
              $logger->warn("Warning--Value out bounds for field/date component '$dcf' - ignoring in entry '$citekey'");
              $self->{warnings}++;
              $be->{warnings} .= "\\item Value out of bounds for field/date component '$dcf' - ignoring\n";
              delete $be->{$dcf};
            }
          }
        }

        ##############################################################
        # 2. set local options to override global options for individual entries
        ##############################################################

        if ( $be->{options} ) {
            my @entryoptions = split /\s*,\s*/, $be->{options};
            foreach (@entryoptions) {
                m/^([^=]+)=?(.+)?$/;
                if ( $2 and $2 eq "false" ) {
                    $localoptions{$citekey}->{$1} = 0;
                }
                elsif ( $2 and $2 eq "true" ) {
                    $localoptions{$citekey}->{$1} = 1;
                }
		# labelname and labelyear are special and need to be array refs
		# They would not be specified as a list in an individual entry
		# since this would make no sense - in an individual entry,
		# you would want to force them to a specific field
                elsif (($1 eq 'labelyear') or ($1 eq 'labelname')) {
                    $localoptions{$citekey}->{$1} = [ $2 ];
                }
                elsif ($2) {
                    $localoptions{$citekey}->{$1} = $2;
                }
                else {
                    $localoptions{$citekey}->{$1} = 1;
                }
            }
        }

        ##############################################################
        # 3. post process "set" entries:
        ##############################################################

        if ( $be->{entrytype} eq 'set' ) {

            my @entrysetkeys = split /\s*,\s*/, $be->{entryset};
            unless (@entrysetkeys) {
                $logger->warn("No entryset found for entry $citekey of type 'set'");
                $self->{warnings}++;
            }
            if ( $be->{crossref}
                and ( $be->{crossref} ne $entrysetkeys[0] ) )
            {

                $logger->warn( "Problem with entry $citekey :\n"
                      . "\tcrossref ("
                      . $be->{crossref}
                      . ") should be identical to the first element of the entryset"
                );
                $self->{warnings}++;
                $be->{crossref} = $entrysetkeys[0];

            }
            elsif ( !$be->{crossref} ) {

                $be->{crossref} = $entrysetkeys[0];
            }
        }

        ##############################################################
        # 4a. generate labelname name
        ##############################################################

        # Here, "labelnamename" is the name of the labelname field
        # and "labelname" is the actual copy of the relevant field

        my $lnamescheme = $self->getblxoption( 'labelname', $citekey );

        foreach my $ln ( @{$lnamescheme} ) {
            my $lnameopt;
            if ( $ln =~ /\Ashort(.+)\z/ ) {
                $lnameopt = $1;
            }
            else {
                $lnameopt = $ln;
            }
            if (    $be->{$ln}
                and $self->getblxoption( "use$lnameopt", $citekey ) )
            {
                $be->{labelnamename} = $ln;
                last;
            }
        }

        unless ( $be->{labelnamename} ) {
            $logger->debug(
                "Could not determine the labelname of entry $citekey");
        }

        ##############################################################
        # 4b. generate labelyear name
        ##############################################################

        # Here, "labelyearname" is the name of the labelyear field
        # and "labelyear" is the actual copy of the relevant field

        my $lyearscheme = $self->getblxoption( 'labelyear', $citekey );

        if ($lyearscheme) {
          foreach my $ly ( @{$lyearscheme} ) {
            if ($be->{$ly}) {
              $be->{labelyearname} = $ly;
              last;
            }
          }

          unless ( $be->{labelyearname} ) {
            $logger->debug(
                           "Could not determine the labelname of entry $citekey");
          }
        }

        ##############################################################
        # 5a. determine namehash and fullhash
        ##############################################################

        my $namehash;
        my $fullhash;
        my $nameid;
        my $nameinitid;
        if (
            $be->{sortname}
            and (  $self->getblxoption( 'useauthor', $citekey )
                or $self->getblxoption( 'useeditor', $citekey ) )
           )
        {
            $namehash = $self->_getnameinitials( $citekey, $be->{sortname} );
            $fullhash = $self->_getallnameinitials( $citekey, $be->{sortname} );
            $nameid = makenameid( $be->{sortname} );
            $nameinitid = makenameinitid( $be->{sortname} )
              if ( $self->getblxoption( 'uniquename', $citekey ) == 2 );
        }
        elsif ( $self->getblxoption( 'useauthor', $citekey ) and $be->{author} )
        {
            $namehash = $self->_getnameinitials( $citekey, $be->{author} );
            $fullhash   = $self->_getallnameinitials( $citekey, $be->{author} );
            $nameid     = makenameid( $be->{author} );
            $nameinitid = makenameinitid( $be->{author} )
              if ( $self->getblxoption( 'uniquename', $citekey ) == 2 );
        }
        elsif (
            (  # keep this? FIXME
                $be->{entrytype} =~ /^(collection|proceedings)/ 
                and $self->getblxoption( 'useeditor', $citekey )
            )
            and $be->{editor}
          )
        {
            $namehash   = $self->_getnameinitials( $citekey, $be->{editor} );
            $fullhash   = $self->_getallnameinitials( $citekey, $be->{editor} );
            $nameid     = makenameid( $be->{editor} );
            $nameinitid = makenameinitid( $be->{editor} )
              if ( $self->getblxoption( 'uniquename', $citekey ) == 2 );
        }
        elsif ( 
            $self->getblxoption( 'usetranslator', $citekey )
            and $be->{translator} 
              )
        {
            $namehash   = $self->_getnameinitials( $citekey, $be->{translator} );
            $fullhash   = $self->_getallnameinitials( $citekey, $be->{translator} );
            $nameid     = makenameid( $be->{translator} );
            $nameinitid = makenameinitid( $be->{translator} )
              if ( $self->getblxoption( 'uniquename', $citekey ) == 2 );
        }
        else {    # initials of title
            if ( $be->{sorttitle} ) {
                $namehash = terseinitials( $be->{sorttitle} );
                $fullhash = $namehash;
                $nameid   = normalize_string_underscore( $be->{sorttitle}, 1 );
                $nameinitid = $nameid
                  if ( $self->getblxoption( 'uniquename', $citekey ) == 2 );
            }
            else {
                $namehash   = terseinitials( $be->{title} );
                $fullhash   = $namehash;
                $nameid     = normalize_string_underscore( $be->{title}, 1 );
                $nameinitid = $nameid
                  if ( $self->getblxoption( 'uniquename', $citekey ) == 2 );
            }
        }

        ## hash suffix

        my $hashsuffix = 1;

        if ( $namehashcount{$namehash}{$nameid} ) {
            $hashsuffix = $namehashcount{$namehash}{$nameid};
        }
        elsif ( $namehashcount{$namehash} ) {
            my $count = scalar keys %{ $namehashcount{$namehash} };
            $hashsuffix = $count + 1;
            $namehashcount{$namehash}{$nameid} = $hashsuffix;
        }
        else {
            $namehashcount{$namehash} = { $nameid => 1 };
        }

        $namehash .= $hashsuffix;
        $fullhash .= $hashsuffix;

        $be->{namehash} = $namehash;
        $be->{fullhash} = $fullhash;

        $seennamehash{$fullhash}++;

        ##############################################################
        # 5b. Populate the uniquenamecount hash to later determine
        #     the uniquename counter
        ##############################################################

        my $lname = $be->{labelnamename};
        {    # Keep these variables scoped over the new few blocks
            my $lastname;
            my $namestring;
            my $singlename;

            if ($lname) {
                if ( $lname =~ m/\Ashort/xms )
                {    # short* fields are just strings, not complex data
                    $lastname   = $be->{$lname};
                    $namestring = $be->{$lname};
                    $singlename = 1;
                }
                else {
                    $lastname   = $be->{$lname}->[0]->{lastname};
                    $namestring = $be->{$lname}->[0]->{nameinitstring};
                    $singlename = scalar @{ $be->{$lname} };
                }
            }

            if (    $lname
                and $self->getblxoption( 'uniquename', $citekey )
                and $singlename == 1 )
            {

                if ( !$uniquenamecount{$lastname}{$namehash} ) {
                    if ( $uniquenamecount{$lastname} ) {
                        $uniquenamecount{$lastname}{$namehash} = 1;
                    }
                    else {
                        $uniquenamecount{$lastname} = { $namehash => 1 };
                    }
                }

                if ( !$uniquenamecount{$namestring}{$namehash} ) {
                    if ( $uniquenamecount{$namestring} ) {
                        $uniquenamecount{$namestring}{$namehash} = 1;
                    }
                    else {
                        $uniquenamecount{$namestring} = { $namehash => 1 };
                    }
                }
            }
            else {
                $be->{ignoreuniquename} = 1;
            }
        }

        ##############################################################
        # 6. track author/year
        ##############################################################

        my $tmp =
            $self->_getnamestring($citekey) . "0"
          . $self->_getyearstring($citekey);
        $seenauthoryear{$tmp}++;
        $be->{authoryear} = $tmp;

        ##############################################################
        # 7. Generate the labelalpha and also the variant for sorting
        ##############################################################

        if ( $self->getblxoption( 'labelalpha', $citekey ) ) {
            my $label;
            my $sortlabel;

            if ( $be->{shorthand} ) {
                $sortlabel = $label = $be->{shorthand};
            }
            else {
                if ( $be->{label} ) {
                    $sortlabel = $label = $be->{label};
                }
                elsif ( $be->{labelnamename} and $be->{ $be->{labelnamename} } )
                {
                    ( $label, $sortlabel ) =
                      @{ $self->_getlabel( $citekey, $be->{labelnamename} ) };
                }
                else {
                    $sortlabel = $label = '';
                }
                my $yr;
                if ( $be->{year} ) {
                    $yr = substr $be->{year}, 2, 2;
                }
                else {
                    $yr = '00';
                }
                $label     .= $yr;
                $sortlabel .= $yr;
            }
            $be->{labelalpha}     = $label;
            $be->{sortlabelalpha} = $sortlabel;
        }

        ##############################################################
        # 8. track shorthands
        ##############################################################

        if ( $be->{shorthand} ) {
            $self->_addshorthand($citekey);
        }

        ##############################################################
        # 9. when type of patent is not stated, simply assume 'patent'
        ##############################################################

        if ( ( $be->{entrytype} eq 'patent' ) && ( !$be->{type} ) ) {
            $be->{type} = 'patent';
        }

        ##############################################################
        # 10. First-pass sorting to generate basic labels
        ##############################################################

        $self->_generatesortstring( $citekey,
            $self->getblxoption( 'sorting_label', $citekey ) );

        ##############################################################
        # 11. update the entry in the biber object
        ##############################################################

        $self->{bib}->{$citekey} = $be;
    }

    $self->{citekeys} = [@foundkeys];

    $logger->debug("Finished postprocessing entries");

    return;
}

=head2 generate_final_sortinfo

    Generate:

      * extraalpha
      * extrayear

    For use in final sorting and generate final pass sort string

=cut

sub generate_final_sortinfo {
  my $self = shift;
  foreach my $citekey ($self->citekeys) {
    my $be = $self->{bib}{$citekey};
    my $authoryear = $be->{authoryear};
    if ($Biber::seenauthoryear{$authoryear} > 1) {
      $Biber::seenlabelyear{$authoryear}++;
      if ( $self->getblxoption('labelyear', $citekey) ) {
        $be->{extrayear} = $Biber::seenlabelyear{$authoryear};
      }
      if ( $self->getblxoption('labelalpha', $citekey) ) {
        $be->{extraalpha} = $Biber::seenlabelyear{$authoryear};
      }
    }
    $self->_generatesortstring($citekey, $self->getblxoption('sorting_final', $citekey));
  }
  return;
}

=head2 sortentries

    Sort the entries according to a certain sorting scheme.
    This method is automatically called by C<prepare>.

=cut

#===========================
# SORTING
#===========================

sub sortentries {
  my $self = shift;
  my %bibentries = $self->bib;
  my @auxcitekeys = $self->citekeys;


  if ( $self->config('fastsort') ) {
    if ($self->config('locale')) {
      my $thislocale = $self->config('locale');
      $logger->debug("Sorting entries with built-in sort (with locale $thislocale) ...");
      setlocale( LC_ALL, $thislocale ) 
        or $logger->warn("Unavailable locale $thislocale")
    } else {
      $logger->debug("Sorting entries with built-in sort (with locale ", $ENV{LC_COLLATE}, ") ...");
    }
    @auxcitekeys = sort {
      $bibentries{$a}->{sortstring} cmp $bibentries{$b}->{sortstring}
    } @auxcitekeys;
  } else {
    require Unicode::Collate;
    my $collopts = $self->config('collate_options');
    my $Collator = Unicode::Collate->new( $collopts ) 
        or $logger->logcarp("Problem with Unicode::Collate options: $@");
    my $UCAversion = $Collator->version();
    my $opts = Data::Dump->dump($collopts);
    $logger->info("Sorting with Unicode::Collate ($opts, UCA version: $UCAversion)"); 
    @auxcitekeys = sort {
      $Collator->cmp( $bibentries{$a}->{sortstring},
                      $bibentries{$b}->{sortstring} )
    } @auxcitekeys;
  }
  $self->{citekeys} = [ @auxcitekeys ];

  return;
}

=head2 prepare

    Post-process and sort all entries before writing the bbl output.
    This is a convenience method that calls C<process_crossref>, C<postprocess>
    and C<sortentries>.

=cut

sub prepare {
    my $self = shift;

    $self->_init;
    $self->process_crossrefs;
    $self->postprocess; # in here we generate the label sort string
    $self->sortentries; # then we do a label sort pass
    $self->generate_final_sortinfo; # in here we generate the final sort string
    $self->sortentries; # and then we do a final sort pass
    return;
}

=head2 output_to_bbl

    $biber->output_to_bbl("output.bbl");

    Write the bbl file for biblatex.

=cut

#=====================================================
# OUTPUT .BBL FILE FOR BIBLATEX
#=====================================================

sub output_to_bbl {
    my $self = shift;
    my $bblfile = shift;
    my @auxcitekeys = $self->citekeys;

    $logger->debug("Preparing final output...");

    my $mode;

    if ( $self->config('bibencoding') and ! $self->config('unicodebbl') ) {
        $mode = ':encoding(' . $self->config('bibencoding') . ')';
    } else {
        $mode = ":utf8";
    };

    my $BBLFILE = IO::File->new($bblfile, ">$mode") 
      or $logger->logcroak("Failed to open $bblfile : $!");

    # $BBLFILE->binmode(':utf8') if $self->config('unicodebbl');

    my $ctrlver = $self->getblxoption('controlversion');
    my $BBL = <<"EOF";
% \$ biblatex auxiliary file \$
% \$ biblatex version $ctrlver \$
% \$ biber version $VERSION \$
% Do not modify the above lines!
%
% This is an auxiliary file used by the 'biblatex' package.
% This file may safely be deleted. It will be recreated by
% biber or bibtex as required.
%
\\begingroup
\\makeatletter
\\\@ifundefined{ver\@biblatex.sty}
  {\\\@latex\@error
     {Missing 'biblatex' package}
     {The bibliography requires the 'biblatex' package.}
      \\aftergroup\\endinput}
  {}
\\endgroup

EOF

    $BBL .= "\\preamble{%\n" . $self->{preamble} . "%\n}\n" 
        if $self->{preamble};

    foreach my $k (@auxcitekeys) {
        ## skip crossrefkeys (those that are directly cited or 
        #  crossref'd >= mincrossrefs were previously removed)
        next if ( $crossrefkeys{$k} );
        $BBL .= $self->_print_biblatex_entry($k);
    }
    if ( $self->getblxoption('sortlos') and $self->shorthands ) {
        $BBL .= "\\lossort\n";
        foreach my $sh ($self->shorthands) {
            $BBL .= "  \\key{$sh}\n";
        }
        $BBL .= "\\endlossort\n";
    }
    $BBL .= "\\endinput\n";

#    if ( $self->config('bibencoding') and ! $self->config('unicodebbl') ) {
#        $BBL = encode($self->config('bibencoding'), $BBL) 
#    };


    print $BBLFILE $BBL or $logger->logcroak("Failure to write to $bblfile: $!");
    $logger->info("Output to $bblfile");
    close $BBLFILE or $logger->logcroak("Failure to close $bblfile: $!");
    return
}

=head2 _filedump and _stringdump

    Dump the biber object with Data::Dump for debugging

=cut

sub _filedump {
    my ($self, $file) = @_;
    my $fh = IO::File->new($file, '>') or croak "Can't open file $file for writing";
    print $fh Data::Dump::pp($self);
    close $fh;
    return
}

sub _stringdump {
    my $self = shift ;
    return Data::Dump::pp($self);
}

=head1 AUTHORS

François Charette, C<< <firmicus at gmx.net> >>
Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>. 

=head1 COPYRIGHT & LICENSE

Copyright 2009 François Charette and Philip Kime, all rights reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

=cut

1;

# vim: set tabstop=4 shiftwidth=4 expandtab:
