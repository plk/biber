# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 13;
use Test::Differences;
unified_diff;

use Biber;
use Biber::Output::bbl;
use Log::Log4perl;
chdir("t/tdata") ;

# Set up Biber object
my $biber = Biber->new(noconf => 1);
my $LEVEL = 'ERROR';
my $l4pconf = qq|
    log4perl.category.main                             = $LEVEL, Screen
    log4perl.category.screen                           = $LEVEL, Screen
    log4perl.appender.Screen                           = Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.utf8                      = 1
    log4perl.appender.Screen.Threshold                 = $LEVEL
    log4perl.appender.Screen.stderr                    = 0
    log4perl.appender.Screen.layout                    = Log::Log4perl::Layout::SimpleLayout
|;
Log::Log4perl->init(\$l4pconf);

$biber->parse_ctrlfile('related.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');

# Now generate the information
$biber->prepare;
my $out = $biber->get_output_obj;
my $section = $biber->sections->get_section(0);
my $shs = $biber->sortlists->get_list(0, 'shorthands/global/', 'list', 'shorthands', 'global', '');
my $main = $biber->sortlists->get_list(0, 'nty/global/', 'entry', 'nty', 'global', '');
my $bibentries = $section->bibentries;

my $k1 = q|    \entry{key1}{article}{}
      \name{author}{1}{}{%
        {{hash=a517747c3d12f99244ae598910d979c5}{%
           family={Author},
           familyi={A\bibinitperiod}}}%
      }
      \strng{namehash}{a517747c3d12f99244ae598910d979c5}
      \strng{fullhash}{a517747c3d12f99244ae598910d979c5}
      \strng{authornamehash}{a517747c3d12f99244ae598910d979c5}
      \strng{authorfullhash}{a517747c3d12f99244ae598910d979c5}
      \field{sortinit}{1}
      \field{sortinithash}{27a2bc5dfb9ed0a0422134d636544b5d}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{journaltitle}{Journal Title}
      \field{number}{5}
      \field{relatedtype}{reprintas}
      \field{shorthand}{RK1}
      \field{title}{Original Title}
      \field{volume}{12}
      \field{year}{1998}
      \field{dateera}{ce}
      \field{related}{78f825aaa0103319aaa1a30bf4fe3ada,3631578538a2d6ba5879b31a9a42f290}
      \field{pages}{125\bibrangedash 150}
      \range{pages}{26}
    \endentry
|;

my $k2 = q|    \entry{key2}{inbook}{}
      \name{author}{1}{}{%
        {{hash=a517747c3d12f99244ae598910d979c5}{%
           family={Author},
           familyi={A\bibinitperiod}}}%
      }
      \list{location}{1}{%
        {Location}%
      }
      \list{publisher}{1}{%
        {Publisher}%
      }
      \strng{namehash}{a517747c3d12f99244ae598910d979c5}
      \strng{fullhash}{a517747c3d12f99244ae598910d979c5}
      \strng{authornamehash}{a517747c3d12f99244ae598910d979c5}
      \strng{authorfullhash}{a517747c3d12f99244ae598910d979c5}
      \field{sortinit}{2}
      \field{sortinithash}{0aa614ace9f3a40ef5a67e7f7a184048}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{booktitle}{Booktitle}
      \field{relatedstring}{First}
      \field{relatedtype}{reprintof}
      \field{shorthand}{RK2}
      \field{title}{Reprint Title}
      \field{year}{2009}
      \field{dateera}{ce}
      \field{related}{c2add694bf942dc77b376592d9c862cd}
      \field{pages}{34\bibrangedash 60}
      \range{pages}{27}
    \endentry
|;


my $kck1 = q|    \entry{c2add694bf942dc77b376592d9c862cd}{article}{dataonly}
      \name{author}{1}{}{%
        {{hash=a517747c3d12f99244ae598910d979c5}{%
           family={Author},
           familyi={A\bibinitperiod}}}%
      }
      \strng{namehash}{a517747c3d12f99244ae598910d979c5}
      \strng{fullhash}{a517747c3d12f99244ae598910d979c5}
      \strng{authornamehash}{a517747c3d12f99244ae598910d979c5}
      \strng{authorfullhash}{a517747c3d12f99244ae598910d979c5}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{clonesourcekey}{key1}
      \field{journaltitle}{Journal Title}
      \field{number}{5}
      \field{relatedtype}{reprintas}
      \field{shorthand}{RK1}
      \field{title}{Original Title}
      \field{volume}{12}
      \field{year}{1998}
      \field{related}{78f825aaa0103319aaa1a30bf4fe3ada,3631578538a2d6ba5879b31a9a42f290}
      \field{pages}{125\bibrangedash 150}
      \range{pages}{26}
    \endentry
|;

my $kck2 = q|    \entry{78f825aaa0103319aaa1a30bf4fe3ada}{inbook}{dataonly}
      \name{author}{1}{}{%
        {{hash=a517747c3d12f99244ae598910d979c5}{%
           family={Author},
           familyi={A\bibinitperiod}}}%
      }
      \list{location}{1}{%
        {Location}%
      }
      \list{publisher}{1}{%
        {Publisher}%
      }
      \strng{namehash}{a517747c3d12f99244ae598910d979c5}
      \strng{fullhash}{a517747c3d12f99244ae598910d979c5}
      \strng{authornamehash}{a517747c3d12f99244ae598910d979c5}
      \strng{authorfullhash}{a517747c3d12f99244ae598910d979c5}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{clonesourcekey}{key2}
      \field{booktitle}{Booktitle}
      \field{relatedstring}{First}
      \field{relatedtype}{reprintof}
      \field{shorthand}{RK2}
      \field{title}{Reprint Title}
      \field{year}{2009}
      \field{related}{c2add694bf942dc77b376592d9c862cd}
      \field{pages}{34\bibrangedash 60}
      \range{pages}{27}
    \endentry
|;

my $kck3 = q|    \entry{3631578538a2d6ba5879b31a9a42f290}{inbook}{dataonly}
      \name{author}{1}{}{%
        {{hash=a517747c3d12f99244ae598910d979c5}{%
           family={Author},
           familyi={A\bibinitperiod}}}%
      }
      \list{location}{1}{%
        {Location}%
      }
      \list{publisher}{1}{%
        {Publisher2}%
      }
      \strng{namehash}{a517747c3d12f99244ae598910d979c5}
      \strng{fullhash}{a517747c3d12f99244ae598910d979c5}
      \strng{authornamehash}{a517747c3d12f99244ae598910d979c5}
      \strng{authorfullhash}{a517747c3d12f99244ae598910d979c5}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{clonesourcekey}{key3}
      \field{booktitle}{Booktitle}
      \field{relatedtype}{translationof}
      \field{shorthand}{RK3}
      \field{title}{Reprint Title}
      \field{year}{2010}
      \field{related}{caf8e34be07426ae7127c1b4829983c1}
      \field{pages}{33\bibrangedash 57}
      \range{pages}{25}
    \endentry
|;

my $kck4 = q|    \entry{caf8e34be07426ae7127c1b4829983c1}{inbook}{dataonly,useeditor=false,uniquename=false}
      \name{author}{1}{}{%
        {{hash=a517747c3d12f99244ae598910d979c5}{%
           family={Author},
           familyi={A\bibinitperiod}}}%
      }
      \list{location}{1}{%
        {Location}%
      }
      \list{publisher}{1}{%
        {Publisher2}%
      }
      \strng{namehash}{a517747c3d12f99244ae598910d979c5}
      \strng{fullhash}{a517747c3d12f99244ae598910d979c5}
      \strng{authornamehash}{a517747c3d12f99244ae598910d979c5}
      \strng{authorfullhash}{a517747c3d12f99244ae598910d979c5}
      \field{labeldatesource}{}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{clonesourcekey}{key4}
      \field{booktitle}{Booktitle}
      \field{shorthand}{RK4}
      \field{title}{Orig Language Title}
      \field{year}{2011}
      \field{pages}{33\bibrangedash 57}
      \range{pages}{25}
    \endentry
|;

my $c1 = q|    \entry{c1}{book}{}
      \field{sortinit}{3}
      \field{sortinithash}{197da6d6c34c6b20ce45c4d4baace5a4}
      \field{related}{9ab62b5ef34a985438bfdf7ee0102229}
    \endentry
|;

my $c2k = q|    \entry{9ab62b5ef34a985438bfdf7ee0102229}{book}{dataonly}
      \field{clonesourcekey}{c2}
      \field{related}{0a3d72134fb3d6c024db4c510bc1605b}
    \endentry
|;

my $c3k = q|    \entry{0a3d72134fb3d6c024db4c510bc1605b}{book}{dataonly}
      \field{clonesourcekey}{c3}
      \field{related}{9ab62b5ef34a985438bfdf7ee0102229}
    \endentry
|;

my $s1 = q|    \entry{8ddf878039b70767c4a5bcf4f0c4f65e}{book}{dataonly,skipbib=false,usecustom=false}
      \name{author}{1}{}{%
        {{hash=a517747c3d12f99244ae598910d979c5}{%
           family={Author},
           familyi={A\\bibinitperiod}}}%
      }
      \strng{namehash}{a517747c3d12f99244ae598910d979c5}
      \strng{fullhash}{a517747c3d12f99244ae598910d979c5}
      \strng{authornamehash}{a517747c3d12f99244ae598910d979c5}
      \strng{authorfullhash}{a517747c3d12f99244ae598910d979c5}
      \field{labelnamesource}{author}
      \field{labeltitlesource}{title}
      \field{clonesourcekey}{s1}
      \field{title}{Title 1}
    \endentry
|;

eq_or_diff( $out->get_output_entry('key1', $main), $k1, 'Related entry test 1' ) ;
eq_or_diff( $out->get_output_entry('key2', $main), $k2, 'Related entry test 2' ) ;
# Key k3 is used only to create a related entry clone but since it isn't cited itself
# it shouldn't be in the .bbl
eq_or_diff( $out->get_output_entry('key3', $main), undef, 'Related entry test 3' ) ;
eq_or_diff( $out->get_output_entry('c2add694bf942dc77b376592d9c862cd', $main), $kck1, 'Related entry test 4' ) ;
eq_or_diff( $out->get_output_entry('78f825aaa0103319aaa1a30bf4fe3ada', $main), $kck2, 'Related entry test 5' ) ;
eq_or_diff( $out->get_output_entry('3631578538a2d6ba5879b31a9a42f290', $main), $kck3, 'Related entry test 6' ) ;
eq_or_diff( $out->get_output_entry('caf8e34be07426ae7127c1b4829983c1', $main), $kck4, 'Related entry test 7' ) ;
# Key k4 is used only to create a related entry clone but since it isn't cited itself
# it shouldn't be in the .bbl
eq_or_diff( $out->get_output_entry('key4', $main), undef, 'Related entry test 8' ) ;
is_deeply([$shs->get_keys], [
                             "key1",
                             "key2",
                             "caf8e34be07426ae7127c1b4829983c1",
                             "78f825aaa0103319aaa1a30bf4fe3ada",
                             "3631578538a2d6ba5879b31a9a42f290",
                             "c2add694bf942dc77b376592d9c862cd",
  ], 'Related entry test 9');
# Testing circular dependencies
eq_or_diff( $out->get_output_entry('c1', $main), $c1, 'Related entry test 10' ) ;
eq_or_diff( $out->get_output_entry('9ab62b5ef34a985438bfdf7ee0102229', $main), $c2k, 'Related entry test 11' ) ;
eq_or_diff( $out->get_output_entry('0a3d72134fb3d6c024db4c510bc1605b', $main), $c3k, 'Related entry test 12' ) ;

# Testing custom relatedoptions
eq_or_diff( $out->get_output_entry('8ddf878039b70767c4a5bcf4f0c4f65e', $main), $s1, 'Custom options - 1' ) ;
