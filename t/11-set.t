use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 3;

use Biber;
use Biber::Output::BBL;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
chdir("t/tdata") ;

# Set up Biber object
my $biber = Biber->new(noconf => 1);
$biber->parse_ctrlfile('set.bcf');
$biber->set_output_obj(Biber::Output::BBL->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('fastsort', 1);
Biber::Config->setoption('unicodebbl', 1);

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;

my $string1 = q|  \entry{Elias1955}{set}{}
    \set{Elias1955a,Elias1955b}
    \name{labelname}{1}{}{%
      {{}{Elias}{E.}{P.}{P.}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{}{Elias}{E.}{P.}{P.}{}{}{}{}}%
    }
    \strng{namehash}{EP1}
    \strng{fullhash}{EP1}
    \field{sortinit}{0}
    \field{extrayear}{1}
    \field{labelyear}{1955}
    \field{year}{1955}
    \field{month}{3}
    \field{title}{Predictive coding--I}
    \field{journaltitle}{IRE Transactions on Information Theory}
    \field{abstract}{Predictive coding is a procedure for transmitting messages which are sequences of magnitudes. In this coding method, the transmitter and the receiver store past message terms, and from them estimate the value of the next message term. The transmitter transmits, not the message term, but the difference between it and its predicted value. At the receiver this error term is added to the receiver prediction to reproduce the message term. This procedure is defined and messages, prediction, entropy, and ideal coding are discussed to provide a basis for Part II, which will give the mathematical criterion for the best predictor for use in the predictive coding of particular messages, will give examples of such messages, and will show that the error term which is transmitted in predictive coding may always be coded efficiently.}
    \field{issn}{0096-1000}
    \field{number}{1}
    \field{volume}{1}
    \strng{crossref}{Elias1955a}
    \field{pages}{16\bibrangedash 24}
    \verb{doi}
    \verb 10.1109/TIT.1955.1055126
    \endverb
  \endentry

|;

my $string2 = q|  \entry{Elias1955a}{article}{}
    \inset{Elias1955}
    \name{labelname}{1}{}{%
      {{}{Elias}{E.}{P.}{P.}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{}{Elias}{E.}{P.}{P.}{}{}{}{}}%
    }
    \strng{namehash}{EP1}
    \strng{fullhash}{EP1}
    \field{sortinit}{0}
    \field{year}{1955}
    \field{month}{3}
    \field{title}{Predictive coding--I}
    \field{journaltitle}{IRE Transactions on Information Theory}
    \field{abstract}{Predictive coding is a procedure for transmitting messages which are sequences of magnitudes. In this coding method, the transmitter and the receiver store past message terms, and from them estimate the value of the next message term. The transmitter transmits, not the message term, but the difference between it and its predicted value. At the receiver this error term is added to the receiver prediction to reproduce the message term. This procedure is defined and messages, prediction, entropy, and ideal coding are discussed to provide a basis for Part II, which will give the mathematical criterion for the best predictor for use in the predictive coding of particular messages, will give examples of such messages, and will show that the error term which is transmitted in predictive coding may always be coded efficiently.}
    \field{issn}{0096-1000}
    \field{number}{1}
    \field{volume}{1}
    \field{pages}{16\bibrangedash 24}
    \verb{doi}
    \verb 10.1109/TIT.1955.1055126
    \endverb
  \endentry

|;

my $string3 = q|  \entry{Elias1955b}{article}{}
    \inset{Elias1955}
    \name{labelname}{1}{}{%
      {{}{Elias}{E.}{P.}{P.}{}{}{}{}}%
    }
    \name{author}{1}{}{%
      {{}{Elias}{E.}{P.}{P.}{}{}{}{}}%
    }
    \strng{namehash}{EP1}
    \strng{fullhash}{EP1}
    \field{sortinit}{0}
    \field{year}{1955}
    \field{month}{3}
    \field{title}{Predictive coding--II}
    \field{journaltitle}{IRE Transactions on Information Theory}
    \field{abstract}{In Part I predictive coding was defined and messages, prediction, entropy, and ideal coding were discussed. In the present paper the criterion to be used for predictors for the purpose of predictive coding is defined: that predictor is optimum in the information theory (IT) sense which minimizes the entropy of the average error-term distribution. Ordered averages of distributions are defined and it is shown that if a predictor gives an ordered average error term distribution it will be a best IT predictor. Special classes of messages are considered for which a best IT predictor can easily be found, and some examples are given. The error terms which are transmitted in predictive coding are treated as if they were statistically independent. If this is indeed the case, or a good approximation, then it is still necessary to show that sequences of message terms which are statistically independent may always be coded efficiently, without impractically large memory requirements, in order to show that predictive coding may be practical and efficient in such cases. This is done in the final section of this paper.}
    \field{issn}{0096-1000}
    \field{number}{1}
    \field{volume}{1}
    \field{pages}{24\bibrangedash 33}
    \verb{doi}
    \verb 10.1109/TIT.1955.1055116
    \endverb
  \endentry

|;

is($out->get_output_entry('elias1955'), $string1, 'Set test 1');
is($out->get_output_entry('elias1955a'), $string2, 'Set test 2');
is($out->get_output_entry('elias1955b'), $string3, 'Set test 3');

unlink "*.utf8";
