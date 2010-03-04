use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 9;

use Biber;
use Biber::Utils;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

my $biber = Biber->new( unicodebbl => 1, fastsort => 1, noconf => 1 );

chdir("t/tdata") ;
$biber->parse_auxfile('uniqueness.aux');

my $bibfile = Biber::Config->getoption('bibdata')->[0] . ".bib";
Biber::Config->setblxoption('uniquelist', 1);
$biber->parse_bibtex($bibfile);
$biber->prepare;
Biber::Config->dump;
my $bibentries = $biber->bib;
use Data::Dump;dd($bibentries);
is($bibentries->entry('un1')->get_field($bibentries->entry('un1')->get_field('labelnamename'))->nth_element(1)->get_uniquename, '2', 'Uniquename requiring full name expansion - 1');
is($bibentries->entry('un2')->get_field($bibentries->entry('un2')->get_field('labelnamename'))->nth_element(1)->get_uniquename, '1', 'Uniquename requiring initials name expansion');
is($bibentries->entry('un3')->get_field($bibentries->entry('un3')->get_field('labelnamename'))->nth_element(1)->get_uniquename, '2', 'Uniquename requiring full name expansion - 2');
is($bibentries->entry('un4')->get_field('namehash'), 'DJ+1', 'Namehash and fullhash different due to maxnames setting - 1');
is($bibentries->entry('un4')->get_field('fullhash'), 'DJMM1', 'Namehash and fullhash different due to maxnames setting - 2');
is($bibentries->entry('un5')->get_field('namehash'), 'C1', 'Fullnamshash ignores SHORT* names - 1');
is($bibentries->entry('un5')->get_field('fullhash'), 'DJMM1', 'Fullnamshash ignores SHORT* names - 2');
is($bibentries->entry('ul1')->get_field($bibentries->entry('ul1')->get_field('labelnamename'))->get_uniquelist, '3', 'Uniquelist - 1');
is($bibentries->entry('ul2')->get_field($bibentries->entry('ul2')->get_field('labelnamename'))->get_uniquelist, '4', 'Uniquelist - 2');






unlink "$bibfile.utf8";
