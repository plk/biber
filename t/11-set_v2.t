use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 2;

use Biber;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

my $biber = Biber->new( unicodebbl => 1, fastsort => 1 );

isa_ok($biber, "Biber");
chdir("t/tdata") ;
$biber->parse_auxfile_v2('80-set_v2.aux');

my $bibfile = Biber::Config->getoption('bibdata')->[0] . ".bib";
$biber->parse_bibtex($bibfile);


$biber->prepare;
my $bibentries = $biber->bib;
my $string1 = $biber->create_bbl_string_body;
my $string1p = q|\entry{Elias1955}{set}{}
  \set{Elias1955a,Elias1955b}
  \name{author}{1}{%
    {{Elias}{E.}{P.}{P.}{}{}{}{}}%
  }
  \strng{namehash}{EP1}
  \strng{fullhash}{EP1}
  \field{sortinit}{E}
  \field{extrayear}{1}
  \field{labelyear}{1955}
  \count{uniquename}{0}
  \field{year}{1955}
  \field{month}{3}
  \field{title}{Predictive coding--I}
  \field{journaltitle}{IRE Transactions on Information Theory}
  \field{abstract}{Predictive coding is a procedure for transmitting messages which are sequences of magnitudes. In this coding method, the transmitter and the receiver store past message terms, and from them estimate the value of the next message term. The transmitter transmits, not the message term, but the difference between it and its predicted value. At the receiver this error term is added to the receiver prediction to reproduce the message term. This procedure is defined and messages, prediction, entropy, and ideal coding are discussed to provide a basis for Part II, which will give the mathematical criterion for the best predictor for use in the predictive coding of particular messages, will give examples of such messages, and will show that the error term which is transmitted in predictive coding may always be coded efficiently.}
  \field{issn}{0096-1000}
  \field{number}{1}
  \field{volume}{1}
  \field{crossref}{Elias1955a}
  \field{pages}{16\bibrangedash 24}
  \verb{doi}
  \verb 10.1109/TIT.1955.1055126
  \endverb
\endentry

\entry{Elias1955a}{article}{}
  \inset{Elias1955}
  \name{author}{1}{%
    {{Elias}{E.}{P.}{P.}{}{}{}{}}%
  }
  \strng{namehash}{EP1}
  \strng{fullhash}{EP1}
  \field{sortinit}{E}
  \field{extrayear}{2}
  \field{labelyear}{1955}
  \count{uniquename}{0}
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

\entry{Elias1955b}{article}{}
  \inset{Elias1955}
  \name{author}{1}{%
    {{Elias}{E.}{P.}{P.}{}{}{}{}}%
  }
  \strng{namehash}{EP1}
  \strng{fullhash}{EP1}
  \field{sortinit}{E}
  \field{extrayear}{3}
  \field{labelyear}{1955}
  \count{uniquename}{0}
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

\endinput

|;

is($$string1 , $string1p, 'Set test 1');

unlink "$bibfile.utf8";
