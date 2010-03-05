use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 16;

use Biber;
use Biber::Utils;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

my $biber = Biber->new( unicodebbl => 1, fastsort => 1, noconf => 1 );

chdir("t/tdata") ;
$biber->parse_auxfile('uniqueness.aux');

my $bibfile = Biber::Config->getoption('bibdata')->[0] . ".bib";
my $bibentries;

Biber::Config->setblxoption('uniquelist', 1);
Biber::Config->setblxoption('uniqueness', ['name', 'namelist', 'year']);
$biber->parse_bibtex($bibfile);
$biber->prepare;
$bibentries = $biber->bib;

is($bibentries->entry('un1')->get_field($bibentries->entry('un1')->get_field('labelnamename'))->nth_element(1)->get_uniquename, '2', 'Uniquename requiring full name expansion - 1');
is($bibentries->entry('un2')->get_field($bibentries->entry('un2')->get_field('labelnamename'))->nth_element(1)->get_uniquename, '2', 'Uniquename requiring full name expansion - 2');
is($bibentries->entry('un5')->get_field($bibentries->entry('un5')->get_field('labelnamename'))->nth_element(1)->get_uniquename, '2', 'Uniquename requiring full name expansion - 3');
is($bibentries->entry('un3')->get_field($bibentries->entry('un2')->get_field('labelnamename'))->nth_element(1)->get_uniquename, '1', 'Uniquename requiring initials name expansion - 1');
is($bibentries->entry('un4')->get_field($bibentries->entry('un4')->get_field('labelnamename'))->nth_element(1)->get_uniquename, '1', 'Uniquename requiring initials name expansion - 2');
is($bibentries->entry('un6')->get_field('namehash'), 'AJ+1', 'Namehash and fullhash different due to maxnames setting - 1');
is($bibentries->entry('un6')->get_field('fullhash'), 'AJBM1', 'Namehash and fullhash different due to maxnames setting - 2');
is($bibentries->entry('un7')->get_field('namehash'), 'C1', 'Fullnamshash ignores SHORT* names - 1');
is($bibentries->entry('un7')->get_field('fullhash'), 'AJBM1', 'Fullnamshash ignores SHORT* names - 2');

# Set maxnames to 4 to unhide some names from the uniquename code
Biber::Config->setblxoption('maxnames', 4);
$biber->{bib} = bless {}, 'Biber::Entries';
$biber->parse_bibtex($bibfile);
$biber->prepare;
$bibentries = $biber->bib;

is($bibentries->entry('un8')->get_field($bibentries->entry('un8')->get_field('labelnamename'))->get_uniquelist, '3', 'Uniquelist - 1');
is($bibentries->entry('un9')->get_field($bibentries->entry('un9')->get_field('labelnamename'))->get_uniquelist, '4', 'Uniquelist - 2');
is($bibentries->entry('un10')->get_field($bibentries->entry('un10')->get_field('labelnamename'))->nth_element(3)->get_uniquename, '1', 'name <- namelist, initials needed');

# Set maxnames to 2 to test uniqueness = ['namelist', 'name'] order
Biber::Config->setblxoption('uniqueness', ['namelist', 'name', 'year', 'title']);
Biber::Config->setblxoption('maxnames', 2);
$biber->{bib} = bless {}, 'Biber::Entries';
$biber->parse_bibtex($bibfile);
$biber->prepare;
$bibentries = $biber->bib;

is($bibentries->entry('un5')->get_field($bibentries->entry('un5')->get_field('labelnamename'))->nth_element(1)->get_uniquename, '2', 'Uniquename requiring full name expansion - 2');
is($bibentries->entry('un8')->get_field($bibentries->entry('un8')->get_field('labelnamename'))->get_uniquelist, '3', 'Uniquelist - 1');
is($bibentries->entry('un9')->get_field($bibentries->entry('un9')->get_field('labelnamename'))->get_uniquelist, '4', 'Uniquelist - 2');
is($bibentries->entry('un10')->get_field($bibentries->entry('un10')->get_field('labelnamename'))->nth_element(3)->get_uniquename, '0', 'namelist <- name, initials not needed');




unlink "$bibfile.utf8";
