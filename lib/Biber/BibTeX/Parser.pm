package Biber::BibTeX::Parser;
use Parse::RecDescent;

{ my $ERRORS;


package Parse::RecDescent::Biber::BibTeX::Parser;
use strict;
use vars qw($skip $AUTOLOAD  );
@Parse::RecDescent::Biber::BibTeX::Parser::ISA = ();
$skip = '\s*';


{
local $SIG{__WARN__} = sub {0};
# PRETEND TO BE IN Parse::RecDescent NAMESPACE
*Parse::RecDescent::Biber::BibTeX::Parser::AUTOLOAD   = sub
{
    no strict 'refs';
    $AUTOLOAD =~ s/^Parse::RecDescent::Biber::BibTeX::Parser/Parse::RecDescent/;
    goto &{$AUTOLOAD};
}
}

push @Parse::RecDescent::Biber::BibTeX::Parser::ISA, 'Parse::RecDescent';
# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Biber::BibTeX::Parser::BibEntry
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"BibEntry"};
    
    Parse::RecDescent::_trace(q{Trying rule: [BibEntry]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{BibEntry},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $expectation = new Parse::RecDescent::Expectation(q{'@'});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: ['@' Typename '\{' Key ',' Field '\}' /\\n*/]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{BibEntry},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{BibEntry});
        %item = (__RULE__ => q{BibEntry});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying terminal: ['@']},
                      Parse::RecDescent::_tracefirst($text),
                      q{BibEntry},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ s/\A\@//)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(qq{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                            if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $& . q{])},
                          Parse::RecDescent::_tracefirst($text))
                            if defined $::RD_TRACE;
        push @item, $item{__STRING1__}=$&;
        

        Parse::RecDescent::_trace(q{Trying subrule: [Typename]},
                  Parse::RecDescent::_tracefirst($text),
                  q{BibEntry},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{Typename})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Biber::BibTeX::Parser::Typename($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [Typename]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{BibEntry},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [Typename]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{BibEntry},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{Typename}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying terminal: ['\{']},
                      Parse::RecDescent::_tracefirst($text),
                      q{BibEntry},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{'\{'})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ s/\A\{//)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(qq{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                            if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $& . q{])},
                          Parse::RecDescent::_tracefirst($text))
                            if defined $::RD_TRACE;
        push @item, $item{__STRING2__}=$&;
        

        Parse::RecDescent::_trace(q{Trying subrule: [Key]},
                  Parse::RecDescent::_tracefirst($text),
                  q{BibEntry},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{Key})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Biber::BibTeX::Parser::Key($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [Key]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{BibEntry},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [Key]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{BibEntry},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{Key}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying terminal: [',']},
                      Parse::RecDescent::_tracefirst($text),
                      q{BibEntry},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{','})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ s/\A\,//)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(qq{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                            if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $& . q{])},
                          Parse::RecDescent::_tracefirst($text))
                            if defined $::RD_TRACE;
        push @item, $item{__STRING3__}=$&;
        

        Parse::RecDescent::_trace(q{Trying repeated subrule: [Field]},
                  Parse::RecDescent::_tracefirst($text),
                  q{BibEntry},
                  $tracelevel)
                    if defined $::RD_TRACE;
        $expectation->is(q{Field})->at($text);
        
        unless (defined ($_tok = $thisparser->_parserepeat($text, \&Parse::RecDescent::Biber::BibTeX::Parser::Field, 1, 100000000, $_noactions,$expectation,sub { \@arg }))) 
        {
            Parse::RecDescent::_trace(q{<<Didn't match repeated subrule: [Field]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{BibEntry},
                          $tracelevel)
                            if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched repeated subrule: [Field]<< (}
                    . @$_tok . q{ times)},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{BibEntry},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{Field(s)}} = $_tok;
        push @item, $_tok;
        


        Parse::RecDescent::_trace(q{Trying terminal: ['\}']},
                      Parse::RecDescent::_tracefirst($text),
                      q{BibEntry},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{'\}'})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ s/\A\}//)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(qq{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                            if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $& . q{])},
                          Parse::RecDescent::_tracefirst($text))
                            if defined $::RD_TRACE;
        push @item, $item{__STRING4__}=$&;
        

        Parse::RecDescent::_trace(q{Trying terminal: [/\\n*/]}, Parse::RecDescent::_tracefirst($text),
                      q{BibEntry},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{/\\n*/})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ s/\A(?:\n*)//)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $& . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$&;
        

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{BibEntry},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do { 
          my %data = map { %$_ } @{$item[6]} ;
          $return = { $item[4] => {entrytype => lc($item[2]), %data } } 
};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: ['@' Typename '\{' Key ',' Field '\}' /\\n*/]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{BibEntry},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{BibEntry},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{BibEntry},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{BibEntry},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{BibEntry},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Biber::BibTeX::Parser::String
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"String"};
    
    Parse::RecDescent::_trace(q{Trying rule: [String]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{String},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $expectation = new Parse::RecDescent::Expectation(q{/\\@STRING/i});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [/\\@STRING/i StringArg]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{String},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{String});
        %item = (__RULE__ => q{String});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying terminal: [/\\@STRING/i]}, Parse::RecDescent::_tracefirst($text),
                      q{String},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ s/\A(?:\@STRING)//i)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $& . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$&;
        

        Parse::RecDescent::_trace(q{Trying subrule: [StringArg]},
                  Parse::RecDescent::_tracefirst($text),
                  q{String},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{StringArg})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Biber::BibTeX::Parser::StringArg($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [StringArg]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{String},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [StringArg]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{String},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{StringArg}} = $_tok;
        push @item, $_tok;
        
        }


        Parse::RecDescent::_trace(q{>>Matched production: [/\\@STRING/i StringArg]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{String},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{String},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{String},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{String},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{String},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Biber::BibTeX::Parser::Comment
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"Comment"};
    
    Parse::RecDescent::_trace(q{Trying rule: [Comment]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{Comment},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $expectation = new Parse::RecDescent::Expectation(q{/\\@COMMENT/i});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [/\\@COMMENT/i StringArg]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{Comment},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{Comment});
        %item = (__RULE__ => q{Comment});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying terminal: [/\\@COMMENT/i]}, Parse::RecDescent::_tracefirst($text),
                      q{Comment},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ s/\A(?:\@COMMENT)//i)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $& . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$&;
        

        Parse::RecDescent::_trace(q{Trying subrule: [StringArg]},
                  Parse::RecDescent::_tracefirst($text),
                  q{Comment},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{StringArg})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Biber::BibTeX::Parser::StringArg($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [StringArg]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{Comment},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [StringArg]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{Comment},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{StringArg}} = $_tok;
        push @item, $_tok;
        
        }


        Parse::RecDescent::_trace(q{>>Matched production: [/\\@COMMENT/i StringArg]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{Comment},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{Comment},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{Comment},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{Comment},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{Comment},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Biber::BibTeX::Parser::StringArg
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"StringArg"};
    
    Parse::RecDescent::_trace(q{Trying rule: [StringArg]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{StringArg},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $expectation = new Parse::RecDescent::Expectation(q{});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: []},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{StringArg},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{StringArg});
        %item = (__RULE__ => q{StringArg});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{StringArg},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do { 
          my $value = extract_bracketed($text, '{}') ;
          $value =~ s/\s*\n\s*/ /g ;
          ($return) = $value =~ /^{(.*)}$/s if $value ;
};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: []<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{StringArg},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{StringArg},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{StringArg},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{StringArg},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{StringArg},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Biber::BibTeX::Parser::Component
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"Component"};
    
    Parse::RecDescent::_trace(q{Trying rule: [Component]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{Component},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $expectation = new Parse::RecDescent::Expectation(q{Preamble, or String, or Comment, or BibEntry});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [Preamble]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{Component},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{Component});
        %item = (__RULE__ => q{Component});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying repeated subrule: [Preamble]},
                  Parse::RecDescent::_tracefirst($text),
                  q{Component},
                  $tracelevel)
                    if defined $::RD_TRACE;
        $expectation->is(q{})->at($text);
        
        unless (defined ($_tok = $thisparser->_parserepeat($text, \&Parse::RecDescent::Biber::BibTeX::Parser::Preamble, 1, 100000000, $_noactions,$expectation,sub { \@arg }))) 
        {
            Parse::RecDescent::_trace(q{<<Didn't match repeated subrule: [Preamble]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{Component},
                          $tracelevel)
                            if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched repeated subrule: [Preamble]<< (}
                    . @$_tok . q{ times)},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{Component},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{Preamble(s)}} = $_tok;
        push @item, $_tok;
        


        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{Component},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do { 
          my @preambles = @{$item[1]};
          $return = { 'preamble' => \@preambles } 
      };
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [Preamble]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{Component},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [String]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{Component},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[1];
        $text = $_[1];
        my $_savetext;
        @item = (q{Component});
        %item = (__RULE__ => q{Component});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying repeated subrule: [String]},
                  Parse::RecDescent::_tracefirst($text),
                  q{Component},
                  $tracelevel)
                    if defined $::RD_TRACE;
        $expectation->is(q{})->at($text);
        
        unless (defined ($_tok = $thisparser->_parserepeat($text, \&Parse::RecDescent::Biber::BibTeX::Parser::String, 1, 100000000, $_noactions,$expectation,sub { \@arg }))) 
        {
            Parse::RecDescent::_trace(q{<<Didn't match repeated subrule: [String]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{Component},
                          $tracelevel)
                            if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched repeated subrule: [String]<< (}
                    . @$_tok . q{ times)},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{Component},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{String(s)}} = $_tok;
        push @item, $_tok;
        


        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{Component},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do { 
          my @str = @{$item[1]} ;
          $return = { 'strings' => \@str } ;
          # we perform the substitutions now
          foreach (@str) {
             my ($a, $b) = split(/\s*=\s*/, $_, 2) ;
             $b =~ s/^\s*"|"\s*$//g ;
             $text =~ s/$a\s*#?\s*(\{?)/$1$b/g
          }
      };
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [String]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{Component},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [Comment]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{Component},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[2];
        $text = $_[1];
        my $_savetext;
        @item = (q{Component});
        %item = (__RULE__ => q{Component});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying repeated subrule: [Comment]},
                  Parse::RecDescent::_tracefirst($text),
                  q{Component},
                  $tracelevel)
                    if defined $::RD_TRACE;
        $expectation->is(q{})->at($text);
        
        unless (defined ($_tok = $thisparser->_parserepeat($text, \&Parse::RecDescent::Biber::BibTeX::Parser::Comment, 1, 100000000, $_noactions,$expectation,sub { \@arg }))) 
        {
            Parse::RecDescent::_trace(q{<<Didn't match repeated subrule: [Comment]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{Component},
                          $tracelevel)
                            if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched repeated subrule: [Comment]<< (}
                    . @$_tok . q{ times)},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{Component},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{Comment(s)}} = $_tok;
        push @item, $_tok;
        


        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{Component},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do { };
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [Comment]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{Component},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [BibEntry]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{Component},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[3];
        $text = $_[1];
        my $_savetext;
        @item = (q{Component});
        %item = (__RULE__ => q{Component});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying repeated subrule: [BibEntry]},
                  Parse::RecDescent::_tracefirst($text),
                  q{Component},
                  $tracelevel)
                    if defined $::RD_TRACE;
        $expectation->is(q{})->at($text);
        
        unless (defined ($_tok = $thisparser->_parserepeat($text, \&Parse::RecDescent::Biber::BibTeX::Parser::BibEntry, 1, 100000000, $_noactions,$expectation,sub { \@arg }))) 
        {
            Parse::RecDescent::_trace(q{<<Didn't match repeated subrule: [BibEntry]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{Component},
                          $tracelevel)
                            if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched repeated subrule: [BibEntry]<< (}
                    . @$_tok . q{ times)},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{Component},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{BibEntry(s)}} = $_tok;
        push @item, $_tok;
        


        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{Component},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do { 
          my @entries = @{$item[1]} ; 
          $return = { 'entries' => \@entries } 
      };
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [BibEntry]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{Component},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{Component},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{Component},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{Component},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{Component},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Biber::BibTeX::Parser::BibFile
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"BibFile"};
    
    Parse::RecDescent::_trace(q{Trying rule: [BibFile]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{BibFile},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $expectation = new Parse::RecDescent::Expectation(q{});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        local $skip = defined($skip) ? $skip : $Parse::RecDescent::skip;
        Parse::RecDescent::_trace(q{Trying production: [<skip: qr{ \s* (\%+[^\n]*\s*)* }x> Component]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{BibFile},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{BibFile});
        %item = (__RULE__ => q{BibFile});
        my $repcount = 0;


        

        Parse::RecDescent::_trace(q{Trying directive: [<skip: qr{ \s* (\%+[^\n]*\s*)* }x>]},
                    Parse::RecDescent::_tracefirst($text),
                      q{BibFile},
                      $tracelevel)
                        if defined $::RD_TRACE; 
        $_tok = do { my $oldskip = $skip; $skip= qr{ \s* (\%+[^\n]*\s*)* }x; $oldskip };
        if (defined($_tok))
        {
            Parse::RecDescent::_trace(q{>>Matched directive<< (return value: [}
                        . $_tok . q{])},
                        Parse::RecDescent::_tracefirst($text))
                            if defined $::RD_TRACE;
        }
        else
        {
            Parse::RecDescent::_trace(q{<<Didn't match directive>>},
                        Parse::RecDescent::_tracefirst($text))
                            if defined $::RD_TRACE;
        }
        
        last unless defined $_tok;
        push @item, $item{__DIRECTIVE1__}=$_tok;
        

        Parse::RecDescent::_trace(q{Trying repeated subrule: [Component]},
                  Parse::RecDescent::_tracefirst($text),
                  q{BibFile},
                  $tracelevel)
                    if defined $::RD_TRACE;
        $expectation->is(q{Component})->at($text);
        
        unless (defined ($_tok = $thisparser->_parserepeat($text, \&Parse::RecDescent::Biber::BibTeX::Parser::Component, 1, 100000000, $_noactions,$expectation,sub { \@arg }))) 
        {
            Parse::RecDescent::_trace(q{<<Didn't match repeated subrule: [Component]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{BibFile},
                          $tracelevel)
                            if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched repeated subrule: [Component]<< (}
                    . @$_tok . q{ times)},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{BibFile},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{Component(s)}} = $_tok;
        push @item, $_tok;
        



        Parse::RecDescent::_trace(q{>>Matched production: [<skip: qr{ \s* (\%+[^\n]*\s*)* }x> Component]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{BibFile},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{BibFile},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{BibFile},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{BibFile},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{BibFile},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Biber::BibTeX::Parser::Typename
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"Typename"};
    
    Parse::RecDescent::_trace(q{Trying rule: [Typename]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{Typename},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $expectation = new Parse::RecDescent::Expectation(q{/[A-Za-z\\.\\-]+/});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [/[A-Za-z\\.\\-]+/]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{Typename},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{Typename});
        %item = (__RULE__ => q{Typename});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying terminal: [/[A-Za-z\\.\\-]+/]}, Parse::RecDescent::_tracefirst($text),
                      q{Typename},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ s/\A(?:[A-Za-z\.\-]+)//)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $& . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$&;
        


        Parse::RecDescent::_trace(q{>>Matched production: [/[A-Za-z\\.\\-]+/]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{Typename},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{Typename},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{Typename},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{Typename},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{Typename},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Biber::BibTeX::Parser::PreambleString
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"PreambleString"};
    
    Parse::RecDescent::_trace(q{Trying rule: [PreambleString]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{PreambleString},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $expectation = new Parse::RecDescent::Expectation(q{});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: []},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{PreambleString},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{PreambleString});
        %item = (__RULE__ => q{PreambleString});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{PreambleString},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do { 
          my $value = extract_bracketed($text, '{}') ;
          $value =~ s/^{(.*)}$/$1/s if $value ;
          $value =~ s/"\s*\n*\s*#\s*\n*\s*"/%\n/mg ;
          $value =~ s/^\s*"\s*//mg ;
          $value =~ s/\s*"\s*$//mg ;
          ($return) = $value if $value ;
};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: []<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{PreambleString},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{PreambleString},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{PreambleString},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{PreambleString},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{PreambleString},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Biber::BibTeX::Parser::Field
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"Field"};
    
    Parse::RecDescent::_trace(q{Trying rule: [Field]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{Field},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $expectation = new Parse::RecDescent::Expectation(q{Fieldname});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [Fieldname /\\s*=\\s*/ Fielddata /,?/]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{Field},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{Field});
        %item = (__RULE__ => q{Field});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying subrule: [Fieldname]},
                  Parse::RecDescent::_tracefirst($text),
                  q{Field},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Biber::BibTeX::Parser::Fieldname($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [Fieldname]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{Field},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [Fieldname]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{Field},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{Fieldname}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying terminal: [/\\s*=\\s*/]}, Parse::RecDescent::_tracefirst($text),
                      q{Field},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{/\\s*=\\s*/})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ s/\A(?:\s*=\s*)//)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $& . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$&;
        

        Parse::RecDescent::_trace(q{Trying subrule: [Fielddata]},
                  Parse::RecDescent::_tracefirst($text),
                  q{Field},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{Fielddata})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Biber::BibTeX::Parser::Fielddata($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [Fielddata]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{Field},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [Fielddata]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{Field},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{Fielddata}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying terminal: [/,?/]}, Parse::RecDescent::_tracefirst($text),
                      q{Field},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{/,?/})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ s/\A(?:,?)//)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $& . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN2__}=$&;
        

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{Field},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {
          $return = { lc($item[1]) => $item[3] } 
};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [Fieldname /\\s*=\\s*/ Fielddata /,?/]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{Field},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{Field},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{Field},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{Field},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{Field},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Biber::BibTeX::Parser::Fielddata
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"Fielddata"};
    
    Parse::RecDescent::_trace(q{Trying rule: [Fielddata]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{Fielddata},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $expectation = new Parse::RecDescent::Expectation(q{/[^,]+/});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: []},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{Fielddata},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{Fielddata});
        %item = (__RULE__ => q{Fielddata});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{Fielddata},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do { 
          my $value = extract_bracketed($text, '{}') ;
          $value =~ s/\s*\n\s*/ /g ;
          ($return) = $value =~ /^{(.*)}$/s if $value ;
};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: []<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{Fielddata},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: []},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{Fielddata},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[1];
        $text = $_[1];
        my $_savetext;
        @item = (q{Fielddata});
        %item = (__RULE__ => q{Fielddata});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{Fielddata},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do { my $value = extract_delimited($text, '"') ;#"'
          $value =~ s/\s*\n\s*/ /g ;
          ($return) = $value =~ /^"(.*)"$/s if $value ;
};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: []<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{Fielddata},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [/[^,]+/]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{Fielddata},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[2];
        $text = $_[1];
        my $_savetext;
        @item = (q{Fielddata});
        %item = (__RULE__ => q{Fielddata});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying terminal: [/[^,]+/]}, Parse::RecDescent::_tracefirst($text),
                      q{Fielddata},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ s/\A(?:[^,]+)//)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $& . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$&;
        

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{Fielddata},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do { 
          $return = $item[1] 
};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [/[^,]+/]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{Fielddata},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{Fielddata},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{Fielddata},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{Fielddata},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{Fielddata},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Biber::BibTeX::Parser::Fieldname
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"Fieldname"};
    
    Parse::RecDescent::_trace(q{Trying rule: [Fieldname]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{Fieldname},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $expectation = new Parse::RecDescent::Expectation(q{/\\S+/});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [/\\S+/]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{Fieldname},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{Fieldname});
        %item = (__RULE__ => q{Fieldname});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying terminal: [/\\S+/]}, Parse::RecDescent::_tracefirst($text),
                      q{Fieldname},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ s/\A(?:\S+)//)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $& . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$&;
        


        Parse::RecDescent::_trace(q{>>Matched production: [/\\S+/]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{Fieldname},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{Fieldname},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{Fieldname},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{Fieldname},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{Fieldname},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Biber::BibTeX::Parser::Preamble
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"Preamble"};
    
    Parse::RecDescent::_trace(q{Trying rule: [Preamble]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{Preamble},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $expectation = new Parse::RecDescent::Expectation(q{/\\@PREAMBLE/i});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [/\\@PREAMBLE/i PreambleString]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{Preamble},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{Preamble});
        %item = (__RULE__ => q{Preamble});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying terminal: [/\\@PREAMBLE/i]}, Parse::RecDescent::_tracefirst($text),
                      q{Preamble},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ s/\A(?:\@PREAMBLE)//i)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $& . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$&;
        

        Parse::RecDescent::_trace(q{Trying subrule: [PreambleString]},
                  Parse::RecDescent::_tracefirst($text),
                  q{Preamble},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{PreambleString})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Biber::BibTeX::Parser::PreambleString($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [PreambleString]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{Preamble},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [PreambleString]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{Preamble},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{PreambleString}} = $_tok;
        push @item, $_tok;
        
        }


        Parse::RecDescent::_trace(q{>>Matched production: [/\\@PREAMBLE/i PreambleString]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{Preamble},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{Preamble},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{Preamble},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{Preamble},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{Preamble},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Biber::BibTeX::Parser::Key
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"Key"};
    
    Parse::RecDescent::_trace(q{Trying rule: [Key]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{Key},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $expectation = new Parse::RecDescent::Expectation(q{/[^,\\s\\n]+/});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [/[^,\\s\\n]+/]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{Key},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{Key});
        %item = (__RULE__ => q{Key});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying terminal: [/[^,\\s\\n]+/]}, Parse::RecDescent::_tracefirst($text),
                      q{Key},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ s/\A(?:[^,\s\n]+)//)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $& . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$&;
        


        Parse::RecDescent::_trace(q{>>Matched production: [/[^,\\s\\n]+/]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{Key},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{Key},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{Key},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{Key},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{Key},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}
}
package Biber::BibTeX::Parser; sub new { my $self = bless( {
                 '_AUTOTREE' => undef,
                 'localvars' => '',
                 'startcode' => '',
                 '_check' => {
                               'thisoffset' => '',
                               'itempos' => '',
                               'prevoffset' => '',
                               'prevline' => '',
                               'prevcolumn' => '',
                               'thiscolumn' => ''
                             },
                 'namespace' => 'Parse::RecDescent::Biber::BibTeX::Parser',
                 '_AUTOACTION' => undef,
                 'rules' => {
                              'BibEntry' => bless( {
                                                     'impcount' => 0,
                                                     'calls' => [
                                                                  'Typename',
                                                                  'Key',
                                                                  'Field'
                                                                ],
                                                     'changed' => 0,
                                                     'opcount' => 0,
                                                     'prods' => [
                                                                  bless( {
                                                                           'number' => '0',
                                                                           'strcount' => 4,
                                                                           'dircount' => 0,
                                                                           'uncommit' => undef,
                                                                           'error' => undef,
                                                                           'patcount' => 1,
                                                                           'actcount' => 1,
                                                                           'items' => [
                                                                                        bless( {
                                                                                                 'pattern' => '@',
                                                                                                 'hashname' => '__STRING1__',
                                                                                                 'description' => '\'@\'',
                                                                                                 'lookahead' => 0,
                                                                                                 'line' => 37
                                                                                               }, 'Parse::RecDescent::Literal' ),
                                                                                        bless( {
                                                                                                 'subrule' => 'Typename',
                                                                                                 'matchrule' => 0,
                                                                                                 'implicit' => undef,
                                                                                                 'argcode' => undef,
                                                                                                 'lookahead' => 0,
                                                                                                 'line' => 37
                                                                                               }, 'Parse::RecDescent::Subrule' ),
                                                                                        bless( {
                                                                                                 'pattern' => '{',
                                                                                                 'hashname' => '__STRING2__',
                                                                                                 'description' => '\'\\{\'',
                                                                                                 'lookahead' => 0,
                                                                                                 'line' => 37
                                                                                               }, 'Parse::RecDescent::Literal' ),
                                                                                        bless( {
                                                                                                 'subrule' => 'Key',
                                                                                                 'matchrule' => 0,
                                                                                                 'implicit' => undef,
                                                                                                 'argcode' => undef,
                                                                                                 'lookahead' => 0,
                                                                                                 'line' => 37
                                                                                               }, 'Parse::RecDescent::Subrule' ),
                                                                                        bless( {
                                                                                                 'pattern' => ',',
                                                                                                 'hashname' => '__STRING3__',
                                                                                                 'description' => '\',\'',
                                                                                                 'lookahead' => 0,
                                                                                                 'line' => 37
                                                                                               }, 'Parse::RecDescent::Literal' ),
                                                                                        bless( {
                                                                                                 'subrule' => 'Field',
                                                                                                 'expected' => undef,
                                                                                                 'min' => 1,
                                                                                                 'argcode' => undef,
                                                                                                 'max' => 100000000,
                                                                                                 'matchrule' => 0,
                                                                                                 'repspec' => 's',
                                                                                                 'lookahead' => 0,
                                                                                                 'line' => 37
                                                                                               }, 'Parse::RecDescent::Repetition' ),
                                                                                        bless( {
                                                                                                 'pattern' => '}',
                                                                                                 'hashname' => '__STRING4__',
                                                                                                 'description' => '\'\\}\'',
                                                                                                 'lookahead' => 0,
                                                                                                 'line' => 37
                                                                                               }, 'Parse::RecDescent::Literal' ),
                                                                                        bless( {
                                                                                                 'pattern' => '\\n*',
                                                                                                 'hashname' => '__PATTERN1__',
                                                                                                 'description' => '/\\\\n*/',
                                                                                                 'lookahead' => 0,
                                                                                                 'rdelim' => '/',
                                                                                                 'line' => 37,
                                                                                                 'mod' => '',
                                                                                                 'ldelim' => '/'
                                                                                               }, 'Parse::RecDescent::Token' ),
                                                                                        bless( {
                                                                                                 'hashname' => '__ACTION1__',
                                                                                                 'lookahead' => 0,
                                                                                                 'line' => 37,
                                                                                                 'code' => '{ 
          my %data = map { %$_ } @{$item[6]} ;
          $return = { $item[4] => {entrytype => lc($item[2]), %data } } 
}'
                                                                                               }, 'Parse::RecDescent::Action' )
                                                                                      ],
                                                                           'line' => undef
                                                                         }, 'Parse::RecDescent::Production' )
                                                                ],
                                                     'name' => 'BibEntry',
                                                     'vars' => '',
                                                     'line' => 37
                                                   }, 'Parse::RecDescent::Rule' ),
                              'String' => bless( {
                                                   'impcount' => 0,
                                                   'calls' => [
                                                                'StringArg'
                                                              ],
                                                   'changed' => 0,
                                                   'opcount' => 0,
                                                   'prods' => [
                                                                bless( {
                                                                         'number' => '0',
                                                                         'strcount' => 0,
                                                                         'dircount' => 0,
                                                                         'uncommit' => undef,
                                                                         'error' => undef,
                                                                         'patcount' => 1,
                                                                         'actcount' => 0,
                                                                         'items' => [
                                                                                      bless( {
                                                                                               'pattern' => '\\@STRING',
                                                                                               'hashname' => '__PATTERN1__',
                                                                                               'description' => '/\\\\@STRING/i',
                                                                                               'lookahead' => 0,
                                                                                               'rdelim' => '/',
                                                                                               'line' => 30,
                                                                                               'mod' => 'i',
                                                                                               'ldelim' => '/'
                                                                                             }, 'Parse::RecDescent::Token' ),
                                                                                      bless( {
                                                                                               'subrule' => 'StringArg',
                                                                                               'matchrule' => 0,
                                                                                               'implicit' => undef,
                                                                                               'argcode' => undef,
                                                                                               'lookahead' => 0,
                                                                                               'line' => 30
                                                                                             }, 'Parse::RecDescent::Subrule' )
                                                                                    ],
                                                                         'line' => undef
                                                                       }, 'Parse::RecDescent::Production' )
                                                              ],
                                                   'name' => 'String',
                                                   'vars' => '',
                                                   'line' => 30
                                                 }, 'Parse::RecDescent::Rule' ),
                              'Comment' => bless( {
                                                    'impcount' => 0,
                                                    'calls' => [
                                                                 'StringArg'
                                                               ],
                                                    'changed' => 0,
                                                    'opcount' => 0,
                                                    'prods' => [
                                                                 bless( {
                                                                          'number' => '0',
                                                                          'strcount' => 0,
                                                                          'dircount' => 0,
                                                                          'uncommit' => undef,
                                                                          'error' => undef,
                                                                          'patcount' => 1,
                                                                          'actcount' => 0,
                                                                          'items' => [
                                                                                       bless( {
                                                                                                'pattern' => '\\@COMMENT',
                                                                                                'hashname' => '__PATTERN1__',
                                                                                                'description' => '/\\\\@COMMENT/i',
                                                                                                'lookahead' => 0,
                                                                                                'rdelim' => '/',
                                                                                                'line' => 36,
                                                                                                'mod' => 'i',
                                                                                                'ldelim' => '/'
                                                                                              }, 'Parse::RecDescent::Token' ),
                                                                                       bless( {
                                                                                                'subrule' => 'StringArg',
                                                                                                'matchrule' => 0,
                                                                                                'implicit' => undef,
                                                                                                'argcode' => undef,
                                                                                                'lookahead' => 0,
                                                                                                'line' => 36
                                                                                              }, 'Parse::RecDescent::Subrule' )
                                                                                     ],
                                                                          'line' => undef
                                                                        }, 'Parse::RecDescent::Production' )
                                                               ],
                                                    'name' => 'Comment',
                                                    'vars' => '',
                                                    'line' => 36
                                                  }, 'Parse::RecDescent::Rule' ),
                              'StringArg' => bless( {
                                                      'impcount' => 0,
                                                      'calls' => [],
                                                      'changed' => 0,
                                                      'opcount' => 0,
                                                      'prods' => [
                                                                   bless( {
                                                                            'number' => '0',
                                                                            'strcount' => 0,
                                                                            'dircount' => 0,
                                                                            'uncommit' => undef,
                                                                            'error' => undef,
                                                                            'patcount' => 0,
                                                                            'actcount' => 1,
                                                                            'items' => [
                                                                                         bless( {
                                                                                                  'hashname' => '__ACTION1__',
                                                                                                  'lookahead' => 0,
                                                                                                  'line' => 31,
                                                                                                  'code' => '{ 
          my $value = extract_bracketed($text, \'{}\') ;
          $value =~ s/\\s*\\n\\s*/ /g ;
          ($return) = $value =~ /^{(.*)}$/s if $value ;
}'
                                                                                                }, 'Parse::RecDescent::Action' )
                                                                                       ],
                                                                            'line' => undef
                                                                          }, 'Parse::RecDescent::Production' )
                                                                 ],
                                                      'name' => 'StringArg',
                                                      'vars' => '',
                                                      'line' => 31
                                                    }, 'Parse::RecDescent::Rule' ),
                              'Component' => bless( {
                                                      'impcount' => 0,
                                                      'calls' => [
                                                                   'Preamble',
                                                                   'String',
                                                                   'Comment',
                                                                   'BibEntry'
                                                                 ],
                                                      'changed' => 0,
                                                      'opcount' => 0,
                                                      'prods' => [
                                                                   bless( {
                                                                            'number' => '0',
                                                                            'strcount' => 0,
                                                                            'dircount' => 0,
                                                                            'uncommit' => undef,
                                                                            'error' => undef,
                                                                            'patcount' => 0,
                                                                            'actcount' => 1,
                                                                            'items' => [
                                                                                         bless( {
                                                                                                  'subrule' => 'Preamble',
                                                                                                  'expected' => undef,
                                                                                                  'min' => 1,
                                                                                                  'argcode' => undef,
                                                                                                  'max' => 100000000,
                                                                                                  'matchrule' => 0,
                                                                                                  'repspec' => 's',
                                                                                                  'lookahead' => 0,
                                                                                                  'line' => 2
                                                                                                }, 'Parse::RecDescent::Repetition' ),
                                                                                         bless( {
                                                                                                  'hashname' => '__ACTION1__',
                                                                                                  'lookahead' => 0,
                                                                                                  'line' => 2,
                                                                                                  'code' => '{ 
          my @preambles = @{$item[1]};
          $return = { \'preamble\' => \\@preambles } 
      }'
                                                                                                }, 'Parse::RecDescent::Action' )
                                                                                       ],
                                                                            'line' => undef
                                                                          }, 'Parse::RecDescent::Production' ),
                                                                   bless( {
                                                                            'number' => '1',
                                                                            'strcount' => 0,
                                                                            'dircount' => 0,
                                                                            'uncommit' => undef,
                                                                            'error' => undef,
                                                                            'patcount' => 0,
                                                                            'actcount' => 1,
                                                                            'items' => [
                                                                                         bless( {
                                                                                                  'subrule' => 'String',
                                                                                                  'expected' => undef,
                                                                                                  'min' => 1,
                                                                                                  'argcode' => undef,
                                                                                                  'max' => 100000000,
                                                                                                  'matchrule' => 0,
                                                                                                  'repspec' => 's',
                                                                                                  'lookahead' => 0,
                                                                                                  'line' => 6
                                                                                                }, 'Parse::RecDescent::Repetition' ),
                                                                                         bless( {
                                                                                                  'hashname' => '__ACTION1__',
                                                                                                  'lookahead' => 0,
                                                                                                  'line' => 6,
                                                                                                  'code' => '{ 
          my @str = @{$item[1]} ;
          $return = { \'strings\' => \\@str } ;
          # we perform the substitutions now
          foreach (@str) {
             my ($a, $b) = split(/\\s*=\\s*/, $_, 2) ;
             $b =~ s/^\\s*"|"\\s*$//g ;
             $text =~ s/$a\\s*#?\\s*(\\{?)/$1$b/g
          }
      }'
                                                                                                }, 'Parse::RecDescent::Action' )
                                                                                       ],
                                                                            'line' => 6
                                                                          }, 'Parse::RecDescent::Production' ),
                                                                   bless( {
                                                                            'number' => '2',
                                                                            'strcount' => 0,
                                                                            'dircount' => 0,
                                                                            'uncommit' => undef,
                                                                            'error' => undef,
                                                                            'patcount' => 0,
                                                                            'actcount' => 1,
                                                                            'items' => [
                                                                                         bless( {
                                                                                                  'subrule' => 'Comment',
                                                                                                  'expected' => undef,
                                                                                                  'min' => 1,
                                                                                                  'argcode' => undef,
                                                                                                  'max' => 100000000,
                                                                                                  'matchrule' => 0,
                                                                                                  'repspec' => 's',
                                                                                                  'lookahead' => 0,
                                                                                                  'line' => 16
                                                                                                }, 'Parse::RecDescent::Repetition' ),
                                                                                         bless( {
                                                                                                  'hashname' => '__ACTION1__',
                                                                                                  'lookahead' => 0,
                                                                                                  'line' => 16,
                                                                                                  'code' => '{ }'
                                                                                                }, 'Parse::RecDescent::Action' )
                                                                                       ],
                                                                            'line' => 16
                                                                          }, 'Parse::RecDescent::Production' ),
                                                                   bless( {
                                                                            'number' => '3',
                                                                            'strcount' => 0,
                                                                            'dircount' => 0,
                                                                            'uncommit' => undef,
                                                                            'error' => undef,
                                                                            'patcount' => 0,
                                                                            'actcount' => 1,
                                                                            'items' => [
                                                                                         bless( {
                                                                                                  'subrule' => 'BibEntry',
                                                                                                  'expected' => undef,
                                                                                                  'min' => 1,
                                                                                                  'argcode' => undef,
                                                                                                  'max' => 100000000,
                                                                                                  'matchrule' => 0,
                                                                                                  'repspec' => 's',
                                                                                                  'lookahead' => 0,
                                                                                                  'line' => 17
                                                                                                }, 'Parse::RecDescent::Repetition' ),
                                                                                         bless( {
                                                                                                  'hashname' => '__ACTION1__',
                                                                                                  'lookahead' => 0,
                                                                                                  'line' => 17,
                                                                                                  'code' => '{ 
          my @entries = @{$item[1]} ; 
          $return = { \'entries\' => \\@entries } 
      }'
                                                                                                }, 'Parse::RecDescent::Action' )
                                                                                       ],
                                                                            'line' => 17
                                                                          }, 'Parse::RecDescent::Production' )
                                                                 ],
                                                      'name' => 'Component',
                                                      'vars' => '',
                                                      'line' => 2
                                                    }, 'Parse::RecDescent::Rule' ),
                              'BibFile' => bless( {
                                                    'impcount' => 0,
                                                    'calls' => [
                                                                 'Component'
                                                               ],
                                                    'changed' => 0,
                                                    'opcount' => 0,
                                                    'prods' => [
                                                                 bless( {
                                                                          'number' => '0',
                                                                          'strcount' => 0,
                                                                          'dircount' => 1,
                                                                          'uncommit' => undef,
                                                                          'error' => undef,
                                                                          'patcount' => 0,
                                                                          'actcount' => 0,
                                                                          'items' => [
                                                                                       bless( {
                                                                                                'hashname' => '__DIRECTIVE1__',
                                                                                                'name' => '<skip: qr{ \\s* (\\%+[^\\n]*\\s*)* }x>',
                                                                                                'lookahead' => 0,
                                                                                                'line' => 1,
                                                                                                'code' => 'my $oldskip = $skip; $skip= qr{ \\s* (\\%+[^\\n]*\\s*)* }x; $oldskip'
                                                                                              }, 'Parse::RecDescent::Directive' ),
                                                                                       bless( {
                                                                                                'subrule' => 'Component',
                                                                                                'expected' => undef,
                                                                                                'min' => 1,
                                                                                                'argcode' => undef,
                                                                                                'max' => 100000000,
                                                                                                'matchrule' => 0,
                                                                                                'repspec' => 's',
                                                                                                'lookahead' => 0,
                                                                                                'line' => 1
                                                                                              }, 'Parse::RecDescent::Repetition' )
                                                                                     ],
                                                                          'line' => undef
                                                                        }, 'Parse::RecDescent::Production' )
                                                               ],
                                                    'name' => 'BibFile',
                                                    'vars' => '',
                                                    'line' => 1
                                                  }, 'Parse::RecDescent::Rule' ),
                              'Typename' => bless( {
                                                     'impcount' => 0,
                                                     'calls' => [],
                                                     'changed' => 0,
                                                     'opcount' => 0,
                                                     'prods' => [
                                                                  bless( {
                                                                           'number' => '0',
                                                                           'strcount' => 0,
                                                                           'dircount' => 0,
                                                                           'uncommit' => undef,
                                                                           'error' => undef,
                                                                           'patcount' => 1,
                                                                           'actcount' => 0,
                                                                           'items' => [
                                                                                        bless( {
                                                                                                 'pattern' => '[A-Za-z\\.\\-]+',
                                                                                                 'hashname' => '__PATTERN1__',
                                                                                                 'description' => '/[A-Za-z\\\\.\\\\-]+/',
                                                                                                 'lookahead' => 0,
                                                                                                 'rdelim' => '/',
                                                                                                 'line' => 41,
                                                                                                 'mod' => '',
                                                                                                 'ldelim' => '/'
                                                                                               }, 'Parse::RecDescent::Token' )
                                                                                      ],
                                                                           'line' => undef
                                                                         }, 'Parse::RecDescent::Production' )
                                                                ],
                                                     'name' => 'Typename',
                                                     'vars' => '',
                                                     'line' => 41
                                                   }, 'Parse::RecDescent::Rule' ),
                              'PreambleString' => bless( {
                                                           'impcount' => 0,
                                                           'calls' => [],
                                                           'changed' => 0,
                                                           'opcount' => 0,
                                                           'prods' => [
                                                                        bless( {
                                                                                 'number' => '0',
                                                                                 'strcount' => 0,
                                                                                 'dircount' => 0,
                                                                                 'uncommit' => undef,
                                                                                 'error' => undef,
                                                                                 'patcount' => 0,
                                                                                 'actcount' => 1,
                                                                                 'items' => [
                                                                                              bless( {
                                                                                                       'hashname' => '__ACTION1__',
                                                                                                       'lookahead' => 0,
                                                                                                       'line' => 22,
                                                                                                       'code' => '{ 
          my $value = extract_bracketed($text, \'{}\') ;
          $value =~ s/^{(.*)}$/$1/s if $value ;
          $value =~ s/"\\s*\\n*\\s*#\\s*\\n*\\s*"/%\\n/mg ;
          $value =~ s/^\\s*"\\s*//mg ;
          $value =~ s/\\s*"\\s*$//mg ;
          ($return) = $value if $value ;
}'
                                                                                                     }, 'Parse::RecDescent::Action' )
                                                                                            ],
                                                                                 'line' => undef
                                                                               }, 'Parse::RecDescent::Production' )
                                                                      ],
                                                           'name' => 'PreambleString',
                                                           'vars' => '',
                                                           'line' => 22
                                                         }, 'Parse::RecDescent::Rule' ),
                              'Field' => bless( {
                                                  'impcount' => 0,
                                                  'calls' => [
                                                               'Fieldname',
                                                               'Fielddata'
                                                             ],
                                                  'changed' => 0,
                                                  'opcount' => 0,
                                                  'prods' => [
                                                               bless( {
                                                                        'number' => '0',
                                                                        'strcount' => 0,
                                                                        'dircount' => 0,
                                                                        'uncommit' => undef,
                                                                        'error' => undef,
                                                                        'patcount' => 2,
                                                                        'actcount' => 1,
                                                                        'items' => [
                                                                                     bless( {
                                                                                              'subrule' => 'Fieldname',
                                                                                              'matchrule' => 0,
                                                                                              'implicit' => undef,
                                                                                              'argcode' => undef,
                                                                                              'lookahead' => 0,
                                                                                              'line' => 43
                                                                                            }, 'Parse::RecDescent::Subrule' ),
                                                                                     bless( {
                                                                                              'pattern' => '\\s*=\\s*',
                                                                                              'hashname' => '__PATTERN1__',
                                                                                              'description' => '/\\\\s*=\\\\s*/',
                                                                                              'lookahead' => 0,
                                                                                              'rdelim' => '/',
                                                                                              'line' => 43,
                                                                                              'mod' => '',
                                                                                              'ldelim' => '/'
                                                                                            }, 'Parse::RecDescent::Token' ),
                                                                                     bless( {
                                                                                              'subrule' => 'Fielddata',
                                                                                              'matchrule' => 0,
                                                                                              'implicit' => undef,
                                                                                              'argcode' => undef,
                                                                                              'lookahead' => 0,
                                                                                              'line' => 43
                                                                                            }, 'Parse::RecDescent::Subrule' ),
                                                                                     bless( {
                                                                                              'pattern' => ',?',
                                                                                              'hashname' => '__PATTERN2__',
                                                                                              'description' => '/,?/',
                                                                                              'lookahead' => 0,
                                                                                              'rdelim' => '/',
                                                                                              'line' => 43,
                                                                                              'mod' => '',
                                                                                              'ldelim' => '/'
                                                                                            }, 'Parse::RecDescent::Token' ),
                                                                                     bless( {
                                                                                              'hashname' => '__ACTION1__',
                                                                                              'lookahead' => 0,
                                                                                              'line' => 43,
                                                                                              'code' => '{
          $return = { lc($item[1]) => $item[3] } 
}'
                                                                                            }, 'Parse::RecDescent::Action' )
                                                                                   ],
                                                                        'line' => undef
                                                                      }, 'Parse::RecDescent::Production' )
                                                             ],
                                                  'name' => 'Field',
                                                  'vars' => '',
                                                  'line' => 43
                                                }, 'Parse::RecDescent::Rule' ),
                              'Fielddata' => bless( {
                                                      'impcount' => 0,
                                                      'calls' => [],
                                                      'changed' => 0,
                                                      'opcount' => 0,
                                                      'prods' => [
                                                                   bless( {
                                                                            'number' => '0',
                                                                            'strcount' => 0,
                                                                            'dircount' => 0,
                                                                            'uncommit' => undef,
                                                                            'error' => undef,
                                                                            'patcount' => 0,
                                                                            'actcount' => 1,
                                                                            'items' => [
                                                                                         bless( {
                                                                                                  'hashname' => '__ACTION1__',
                                                                                                  'lookahead' => 0,
                                                                                                  'line' => 47,
                                                                                                  'code' => '{ 
          my $value = extract_bracketed($text, \'{}\') ;
          $value =~ s/\\s*\\n\\s*/ /g ;
          ($return) = $value =~ /^{(.*)}$/s if $value ;
}'
                                                                                                }, 'Parse::RecDescent::Action' )
                                                                                       ],
                                                                            'line' => undef
                                                                          }, 'Parse::RecDescent::Production' ),
                                                                   bless( {
                                                                            'number' => '1',
                                                                            'strcount' => 0,
                                                                            'dircount' => 0,
                                                                            'uncommit' => undef,
                                                                            'error' => undef,
                                                                            'patcount' => 0,
                                                                            'actcount' => 1,
                                                                            'items' => [
                                                                                         bless( {
                                                                                                  'hashname' => '__ACTION1__',
                                                                                                  'lookahead' => 0,
                                                                                                  'line' => 52,
                                                                                                  'code' => '{ my $value = extract_delimited($text, \'"\') ;#"\'
          $value =~ s/\\s*\\n\\s*/ /g ;
          ($return) = $value =~ /^"(.*)"$/s if $value ;
}'
                                                                                                }, 'Parse::RecDescent::Action' )
                                                                                       ],
                                                                            'line' => 52
                                                                          }, 'Parse::RecDescent::Production' ),
                                                                   bless( {
                                                                            'number' => '2',
                                                                            'strcount' => 0,
                                                                            'dircount' => 0,
                                                                            'uncommit' => undef,
                                                                            'error' => undef,
                                                                            'patcount' => 1,
                                                                            'actcount' => 1,
                                                                            'items' => [
                                                                                         bless( {
                                                                                                  'pattern' => '[^,]+',
                                                                                                  'hashname' => '__PATTERN1__',
                                                                                                  'description' => '/[^,]+/',
                                                                                                  'lookahead' => 0,
                                                                                                  'rdelim' => '/',
                                                                                                  'line' => 56,
                                                                                                  'mod' => '',
                                                                                                  'ldelim' => '/'
                                                                                                }, 'Parse::RecDescent::Token' ),
                                                                                         bless( {
                                                                                                  'hashname' => '__ACTION1__',
                                                                                                  'lookahead' => 0,
                                                                                                  'line' => 56,
                                                                                                  'code' => '{ 
          $return = $item[1] 
}'
                                                                                                }, 'Parse::RecDescent::Action' )
                                                                                       ],
                                                                            'line' => 56
                                                                          }, 'Parse::RecDescent::Production' )
                                                                 ],
                                                      'name' => 'Fielddata',
                                                      'vars' => '',
                                                      'line' => 47
                                                    }, 'Parse::RecDescent::Rule' ),
                              'Fieldname' => bless( {
                                                      'impcount' => 0,
                                                      'calls' => [],
                                                      'changed' => 0,
                                                      'opcount' => 0,
                                                      'prods' => [
                                                                   bless( {
                                                                            'number' => '0',
                                                                            'strcount' => 0,
                                                                            'dircount' => 0,
                                                                            'uncommit' => undef,
                                                                            'error' => undef,
                                                                            'patcount' => 1,
                                                                            'actcount' => 0,
                                                                            'items' => [
                                                                                         bless( {
                                                                                                  'pattern' => '\\S+',
                                                                                                  'hashname' => '__PATTERN1__',
                                                                                                  'description' => '/\\\\S+/',
                                                                                                  'lookahead' => 0,
                                                                                                  'rdelim' => '/',
                                                                                                  'line' => 46,
                                                                                                  'mod' => '',
                                                                                                  'ldelim' => '/'
                                                                                                }, 'Parse::RecDescent::Token' )
                                                                                       ],
                                                                            'line' => undef
                                                                          }, 'Parse::RecDescent::Production' )
                                                                 ],
                                                      'name' => 'Fieldname',
                                                      'vars' => '',
                                                      'line' => 46
                                                    }, 'Parse::RecDescent::Rule' ),
                              'Preamble' => bless( {
                                                     'impcount' => 0,
                                                     'calls' => [
                                                                  'PreambleString'
                                                                ],
                                                     'changed' => 0,
                                                     'opcount' => 0,
                                                     'prods' => [
                                                                  bless( {
                                                                           'number' => '0',
                                                                           'strcount' => 0,
                                                                           'dircount' => 0,
                                                                           'uncommit' => undef,
                                                                           'error' => undef,
                                                                           'patcount' => 1,
                                                                           'actcount' => 0,
                                                                           'items' => [
                                                                                        bless( {
                                                                                                 'pattern' => '\\@PREAMBLE',
                                                                                                 'hashname' => '__PATTERN1__',
                                                                                                 'description' => '/\\\\@PREAMBLE/i',
                                                                                                 'lookahead' => 0,
                                                                                                 'rdelim' => '/',
                                                                                                 'line' => 21,
                                                                                                 'mod' => 'i',
                                                                                                 'ldelim' => '/'
                                                                                               }, 'Parse::RecDescent::Token' ),
                                                                                        bless( {
                                                                                                 'subrule' => 'PreambleString',
                                                                                                 'matchrule' => 0,
                                                                                                 'implicit' => undef,
                                                                                                 'argcode' => undef,
                                                                                                 'lookahead' => 0,
                                                                                                 'line' => 21
                                                                                               }, 'Parse::RecDescent::Subrule' )
                                                                                      ],
                                                                           'line' => undef
                                                                         }, 'Parse::RecDescent::Production' )
                                                                ],
                                                     'name' => 'Preamble',
                                                     'vars' => '',
                                                     'line' => 21
                                                   }, 'Parse::RecDescent::Rule' ),
                              'Key' => bless( {
                                                'impcount' => 0,
                                                'calls' => [],
                                                'changed' => 0,
                                                'opcount' => 0,
                                                'prods' => [
                                                             bless( {
                                                                      'number' => '0',
                                                                      'strcount' => 0,
                                                                      'dircount' => 0,
                                                                      'uncommit' => undef,
                                                                      'error' => undef,
                                                                      'patcount' => 1,
                                                                      'actcount' => 0,
                                                                      'items' => [
                                                                                   bless( {
                                                                                            'pattern' => '[^,\\s\\n]+',
                                                                                            'hashname' => '__PATTERN1__',
                                                                                            'description' => '/[^,\\\\s\\\\n]+/',
                                                                                            'lookahead' => 0,
                                                                                            'rdelim' => '/',
                                                                                            'line' => 42,
                                                                                            'mod' => '',
                                                                                            'ldelim' => '/'
                                                                                          }, 'Parse::RecDescent::Token' )
                                                                                 ],
                                                                      'line' => undef
                                                                    }, 'Parse::RecDescent::Production' )
                                                           ],
                                                'name' => 'Key',
                                                'vars' => '',
                                                'line' => 42
                                              }, 'Parse::RecDescent::Rule' )
                            }
               }, 'Parse::RecDescent' );
}
__END__

=pod

=encoding utf-8

=head1 NAME

C<Biber::BibTeX::Parser> - A Parse::RecDescent BibTeX parser

=head1 DESCRIPTION

This file was automatically generated by Parse::RecDescent from the file PRDgrammar

=head1 METHODS

=head2 new

This is to please Test::Pod::Coverage :)

=head1 AUTHOR

François Charette, C<< <firmicus at gmx.net> >>

=head1 BUGS

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>. 

=head1 COPYRIGHT & LICENSE

Copyright 2009-2010 François Charette, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# vim: set tabstop=4 shiftwidth=4 expandtab:


