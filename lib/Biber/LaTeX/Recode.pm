package Biber::LaTeX::Recode;
use strict;
use warnings;
no warnings 'utf8';
use Unicode::Normalize;
use Exporter;
use base qw(Exporter);

our $VERSION = '0.01';
our @EXPORT  = qw(latex_encode);

=encoding utf-8

=head1 NAME

Biber::LaTeX::Recode - Encode/Decode chars to/from UTF-8/lacros in LaTeX

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

    use Biber::LaTeX:Recode

    my $string       = 'Muḥammad ibn Mūsā al-Khwārizmī';
    my $latex_string = latex_encode($string);
        # => 'Mu\\d{h}ammad ibn M\\=us\=a al-Khw\\=arizm\\={\\i}'

=head1 DESCRIPTION

Allows conversion between Unicode chars and LaTeX macros.

=head1 EXPORT

=head1 FUNCTIONS

=head2 latex_encode($text, @options)

Encodes the given text to LaTeX.

=cut

### DATA

my %WORDSMACROS = (
#	chr(0x22)	=>	'{\\textquotedbl}',
#	chr(0x23)	=>	'{\\texthash}',
    chr(0x23)   =>  '\\#',
#	chr(0x24)	=> 	'{\\textdollar}',
    chr(0x24)   =>  '\\$',
#	chr(0x25)	=>	'{\\textpercent}',
#    chr(0x25)   =>  '\\%',
#	chr(0x26)	=>	'{\\textampersand}',
    chr(0x26)   =>  '\\&',
#	chr(0x27)	=>	'{\\textquotesingle}',
#	chr(0x2a)	=>	'{\\textasteriskcentered}',
#	chr(0x3c)	=>	'{\\textless}',
#	chr(0x3d)	=>	'{\\textequals}',
#	chr(0x3e)	=>	'{\\textgreater}',
#	chr(0x5c)	=>	'{\\textbackslash}',
#	chr(0x5e)	=>	'{\\textasciicircum}',
#    chr(0x5e)  =>  '\\^{ }',
#	chr(0x5f)   =>	'{\\textunderscore}',
    chr(0x5f)   =>  '\\_',
#	chr(0x60)	=>	'{\\textasciigrave}',
#	chr(0x67)	=>	'{\\textg}',
#	chr(0x7b)	=>	'{\\textbraceleft}',
#   chr(0x7b)   =>  '\\{',
#	chr(0x7c)	=>	'{\\textbar}',
#	chr(0x7d)	=>	'{\\textbraceright}',
#   chr(0x7d)   =>  '\\}',
#	chr(0x7e)	=>	'{\\textasciitilde}',
#   chr(0x7e)   =>  '{\\texttildelow}',
#	chr(0xa0)	=>	'{\\nobreakspace}',
    chr(0xa0)   =>  '~',
 	chr(0xa1)	=>	'{\\textexclamdown}',
 	chr(0xa2)	=>	'{\\textcent}',
 	chr(0xa3)	=>	'{\\pounds}',
#	chr(0xa3)	=>	'{\\textsterling}',
 	chr(0xa4)	=>	'{\\textcurrency}',
 	chr(0xa5)	=>	'{\\textyen}',
 	chr(0xa6)	=>	'{\\textbrokenbar}',
	chr(0xa7)	=>	'{\\S}',
#	chr(0xa7)	=>	'{\\textsection}',
	chr(0xa8)	=>	'{\\textasciidieresis}',
#	chr(0xa9)	=>	'{\\copyright}',
	chr(0xa9)	=>	'{\\textcopyright}',
	chr(0xaa)	=>	'{\\textordfeminine}',
	chr(0xab)	=>	'{\\guillemotleft}',
	chr(0xac)	=>	'{\\lnot}',
#	chr(0xac)	=>	'{\\textlogicalnot}',
	chr(0xae)	=>	'{\\textregistered}',
	chr(0xaf)	=>	'{\\textasciimacron}',
	chr(0xb0)	=>	'{\\textdegree}',
#	chr(0xb1)	=>	'{\\pm}',
	chr(0xb1)	=>	'{\\textpm}',
	chr(0xb2)	=>	'{\\texttwosuperior}',
	chr(0xb3)	=>	'{\\textthreesuperior}',
	chr(0xb4)	=>	'{\\textasciiacute}',
#	chr(0xb5)	=>	'{\\mu}',
	chr(0xb5)	=>	'{\\textmu}',
	chr(0xb6)	=>	'{\\P}',
#	chr(0xb6)	=>	'{\\textparagraph}',
	chr(0xb7)	=>	'{\\textcentereddot}',
#	chr(0xb7)	=>	'{\\textperiodcentered}',
	chr(0xb8)	=>	'{\\textasciicedilla}',
	chr(0xb9)	=>	'{\\textonesuperior}',
	chr(0xba)	=>	'{\\textordmasculine}',
	chr(0xbb)	=>	'{\\guillemotright}',
	chr(0xbc)	=>	'{\\textonequarter}',
	chr(0xbd)	=>	'{\\textonehalf}',
	chr(0xbe)	=>	'{\\textthreequarters}',
	chr(0xbf)	=>	'{\\textquestiondown}',
	chr(0xc5)	=>	'{\\AA}',
	chr(0xc6)	=>	'{\\AE}',
	chr(0xd0)	=>	'{\\DH}',
	chr(0xd7)	=>	'{\\texttimes}',
#	chr(0xd7)	=>	'{\\times}',
	chr(0xd8)	=>	'{\\O}',
	chr(0xde)	=>	'{\\TH}',
#	chr(0xde)	=>	'{\\Thorn}',
	chr(0xdf)	=>	'{\\ss}',
	chr(0xe5)	=>	'{\\aa}',
	chr(0xe6)	=>	'{\\ae}',
	chr(0xf0)	=>	'{\\dh}',
#	chr(0xf7)	=>	'{\\div}',
	chr(0xf7)	=>	'{\\textdiv}',
	chr(0xf8)	=>	'{\\o}',
#	chr(0xfe)	=>	'{\\textthorn}',
#	chr(0xfe)	=>	'{\\textthornvari}',
#	chr(0xfe)	=>	'{\\textthornvarii}',
#	chr(0xfe)	=>	'{\\textthornvariii}',
#	chr(0xfe)	=>	'{\\textthornvariv}',
	chr(0xfe)	=>	'{\\th}',
	chr(0x110)	=>	'{\\DJ}',
	chr(0x111)	=>	'{\\dj}',
#	chr(0x111)	=>	'{\\textcrd}',
	chr(0x126)	=>	'{\\textHbar}',
#	chr(0x127)	=>	'{\\textcrh}',
	chr(0x127)	=>	'{\\texthbar}',
	chr(0x131)	=>	'{\\i}',
	chr(0x132)	=>	'{\\IJ}',
	chr(0x133)	=>	'{\\ij}',
	chr(0x138)	=>	'{\\textkra}',
	chr(0x141)	=>	'{\\L}',
	chr(0x142)	=>	'{\\l}',
#	chr(0x142)	=>	'{\\textbarl}',
	chr(0x14a)	=>	'{\\NG}',
	chr(0x14b)	=>	'{\\ng}',
	chr(0x152)	=>	'{\\OE}',
	chr(0x153)	=>	'{\\oe}',
	chr(0x166)	=>	'{\\textTbar}',
#	chr(0x166)	=>	'{\\textTstroke}',
	chr(0x167)	=>	'{\\texttbar}',
#	chr(0x167)	=>	'{\\texttstroke}',
	chr(0x180)	=>	'{\\textcrb}',
	chr(0x181)	=>	'{\\textBhook}',
	chr(0x186)	=>	'{\\textOopen}',
	chr(0x187)	=>	'{\\textChook}',
	chr(0x188)	=>	'{\\textchook}',
#	chr(0x188)	=>	'{\\texthtc}',
	chr(0x189)	=>	'{\\textDafrican}',
	chr(0x18a)	=>	'{\\textDhook}',
	chr(0x18e)	=>	'{\\textEreversed}',
	chr(0x190)	=>	'{\\textEopen}',
	chr(0x191)	=>	'{\\textFhook}',
	chr(0x192)	=>	'{\\textflorin}',
	chr(0x194)	=>	'{\\textGammaafrican}',
	chr(0x195)	=>	'{\\hv}',
#	chr(0x195)	=>	'{\\texthvlig}',
	chr(0x196)	=>	'{\\textIotaafrican}',
	chr(0x198)	=>	'{\\textKhook}',
#	chr(0x199)	=>	'{\\texthtk}',
	chr(0x199)	=>	'{\\textkhook}',
	chr(0x19b)	=>	'{\\textcrlambda}',
	chr(0x19d)	=>	'{\\textNhookleft}',
	chr(0x1a0)	=>	'{\\OHORN}',
	chr(0x1a1)	=>	'{\\ohorn}',
	chr(0x1a4)	=>	'{\\textPhook}',
#	chr(0x1a5)	=>	'{\\texthtp}',
	chr(0x1a5)	=>	'{\\textphook}',
#	chr(0x1a9)	=>	'{\\ESH}',
	chr(0x1a9)	=>	'{\\textEsh}',
	chr(0x1aa)	=>	'{\\textlooptoprevesh}',
	chr(0x1ab)	=>	'{\\textpalhookbelow}',
	chr(0x1ac)	=>	'{\\textThook}',
#	chr(0x1ad)	=>	'{\\texthtt}',
	chr(0x1ad)	=>	'{\\textthook}',
	chr(0x1ae)	=>	'{\\textTretroflexhook}',
	chr(0x1af)	=>	'{\\UHORN}',
	chr(0x1b0)	=>	'{\\uhorn}',
	chr(0x1b2)	=>	'{\\textVhook}',
	chr(0x1b3)	=>	'{\\textYhook}',
	chr(0x1b4)	=>	'{\\textyhook}',
	chr(0x1b7)	=>	'{\\textEzh}',
	chr(0x1dd)	=>	'{\\texteturned}',
	chr(0x250)	=>	'{\\textturna}',
	chr(0x251)	=>	'{\\textscripta}',
	chr(0x252)	=>	'{\\textturnscripta}',
	chr(0x253)	=>	'{\\textbhook}',
#	chr(0x253)	=>	'{\\texthtb}',
	chr(0x254)	=>	'{\\textoopen}',
#	chr(0x254)	=>	'{\\textopeno}',
	chr(0x255)	=>	'{\\textctc}',
#	chr(0x256)	=>	'{\\textdtail}',
	chr(0x256)	=>	'{\\textrtaild}',
	chr(0x257)	=>	'{\\textdhook}',
#	chr(0x257)	=>	'{\\texthtd}',
	chr(0x258)	=>	'{\\textreve}',
	chr(0x259)	=>	'{\\textschwa}',
	chr(0x25a)	=>	'{\\textrhookschwa}',
#	chr(0x25b)	=>	'{\\texteopen}',
	chr(0x25b)	=>	'{\\textepsilon}',
	chr(0x25c)	=>	'{\\textrevepsilon}',
	chr(0x25d)	=>	'{\\textrhookrevepsilon}',
	chr(0x25e)	=>	'{\\textcloserevepsilon}',
	chr(0x25f)	=>	'{\\textbardotlessj}',
	chr(0x260)	=>	'{\\texthtg}',
	chr(0x261)	=>	'{\\textscriptg}',
	chr(0x262)	=>	'{\\textscg}',
	chr(0x263)	=>	'{\\textgamma}',
#	chr(0x263)	=>	'{\\textgammalatinsmall}',
	chr(0x264)	=>	'{\\textramshorns}',
	chr(0x265)	=>	'{\\textturnh}',
	chr(0x266)	=>	'{\\texthth}',
	chr(0x267)	=>	'{\\texththeng}',
	chr(0x268)	=>	'{\\textbari}',
	chr(0x269)	=>	'{\\textiota}',
#	chr(0x269)	=>	'{\\textiotalatin}',
	chr(0x26a)	=>	'{\\textsci}',
	chr(0x26b)	=>	'{\\textltilde}',
	chr(0x26c)	=>	'{\\textbeltl}',
	chr(0x26d)	=>	'{\\textrtaill}',
	chr(0x26e)	=>	'{\\textlyoghlig}',
	chr(0x26f)	=>	'{\\textturnm}',
	chr(0x270)	=>	'{\\textturnmrleg}',
	chr(0x271)	=>	'{\\textltailm}',
#	chr(0x272)	=>	'{\\textltailn}',
	chr(0x272)	=>	'{\\textnhookleft}',
	chr(0x273)	=>	'{\\textrtailn}',
	chr(0x274)	=>	'{\\textscn}',
	chr(0x275)	=>	'{\\textbaro}',
	chr(0x276)	=>	'{\\textscoelig}',
	chr(0x277)	=>	'{\\textcloseomega}',
	chr(0x278)	=>	'{\\textphi}',
	chr(0x279)	=>	'{\\textturnr}',
	chr(0x27a)	=>	'{\\textturnlonglegr}',
	chr(0x27b)	=>	'{\\textturnrrtail}',
	chr(0x27c)	=>	'{\\textlonglegr}',
	chr(0x27d)	=>	'{\\textrtailr}',
	chr(0x27e)	=>	'{\\textfishhookr}',
	chr(0x27f)	=> 	'{\\textlhti}', #?
	chr(0x280)	=>	'{\\textscr}',
	chr(0x281)	=>	'{\\textinvscr}',
	chr(0x282)	=>	'{\\textrtails}',
	chr(0x283)	=>	'{\\textesh}',
	chr(0x284)	=>	'{\\texthtbardotlessj}',
	chr(0x285)	=>	'{\\textraisevibyi}', # ??
	chr(0x286)	=>	'{\\textctesh}',
	chr(0x287)	=>	'{\\textturnt}',
#	chr(0x288)	=>	'{\\textrtailt}',
	chr(0x288)	=>	'{\\texttretroflexhook}',
	chr(0x289)	=>	'{\\textbaru}',
	chr(0x28a)	=>	'{\\textupsilon}',
	chr(0x28b)	=>	'{\\textscriptv}',
#	chr(0x28b)	=>	'{\\textvhook}',
	chr(0x28c)	=>	'{\\textturnv}',
	chr(0x28d)	=>	'{\\textturnw}',
	chr(0x28e)	=>	'{\\textturny}',
	chr(0x28f)	=>	'{\\textscy}',
	chr(0x290)	=>	'{\\textrtailz}',
	chr(0x291)	=>	'{\\textctz}',
#	chr(0x292)	=>	'{\\textezh}',
	chr(0x292)	=>	'{\\textyogh}',
	chr(0x293)	=>	'{\\textctyogh}',
	chr(0x294)	=>	'{\\textglotstop}',
	chr(0x295)	=>	'{\\textrevglotstop}',
	chr(0x296)	=>	'{\\textinvglotstop}',
	chr(0x297)	=>	'{\\textstretchc}',
	chr(0x298)	=>	'{\\textbullseye}',
	chr(0x299)	=>	'{\\textscb}',
	chr(0x29a)	=>	'{\\textcloseepsilon}',
	chr(0x29b)	=>	'{\\texthtscg}',
	chr(0x29c)	=>	'{\\textsch}',
	chr(0x29d)	=>	'{\\textctj}',
	chr(0x29e)	=>	'{\\textturnk}',
	chr(0x29f)	=>	'{\\textscl}',
	chr(0x2a0)	=>	'{\\texthtq}',
	chr(0x2a1)	=>	'{\\textbarglotstop}',
	chr(0x2a2)	=>	'{\\textbarrevglotstop}',
	chr(0x2a3)	=>	'{\\textdzlig}',
	chr(0x2a4)	=>	'{\\textdyoghlig}',
	chr(0x2a5)	=>	'{\\textdctzlig}',
	chr(0x2a6)	=>	'{\\texttslig}',
#	chr(0x2a7)	=>	'{\\texttesh}',
	chr(0x2a7)	=>	'{\\textteshlig}',
	chr(0x2a8)	=>	'{\\texttctclig}',
	chr(0x2be)	=>	'{\\hamza}',
	chr(0x2bf)	=> 	'{\\ain}',
	chr(0x2c8)	=>	'{\\textprimstress}',
	chr(0x2d0)	=>	'{\\textlengthmark}',
	chr(0x2212)	=>	'{\\textminus}',
    chr(0x2013) =>  '--', # \\textendash
    chr(0x2014) =>  '---', #\\textemdash
    chr(0x2018) =>  '`',
    chr(0x2019) =>  "'",
#    chr(0x2018) => \\textquoteleft
#    chr(0x2019) => \\textquoteright
    chr(0x201a) =>  '{\\quotesinglbase}',
    chr(0x201c) =>  '``',
    chr(0x201d) =>  "''",
#    chr(0x201c) => '{\\textquotedblleft}',
#    chr(0x201d) => '{\\textquotedblright}',
    chr(0x201e) => '{\\quotedblbase}',
    chr(0x2020) => '{\\dag}',
    chr(0x2021) => '{\\ddag}',
    chr(0x2022) => '{\\textbullet}',
    chr(0x2026) => '{\\dots}',
    chr(0x2030) => '{\\textperthousand}',
    chr(0x2031) => '{\\textpertenthousand}',
    chr(0x2032) => '{\\prime}',
    chr(0x2033) => '{\\prime\\prime}',
    chr(0x2034) => '{\\prime\\prime\\prime}',
    chr(0x2039) => '{\\guilsinglleft}',
    chr(0x203a) => '{\\guilsinglright}',
    chr(0x203b) => '{\\textreferencemark}',
    chr(0x203d) => '{\\textinterrobang}',
    chr(0x203e) => '{\\textoverline}',
    chr(0x27e8) => '{\\langle}',
    chr(0x27e9) => '{\\rangle}',
);

my %DIACRITICS = (
	chr(0x300)	=>	'\\`',
	chr(0x301)	=>	'\\\'',
	chr(0x302)	=>	'\\^',
	chr(0x303)	=>	'\\~',
	chr(0x304)	=>	'\\=',
	chr(0x306)	=>	'\\u',
	chr(0x307)	=>	'\\.',
	chr(0x308)	=>	'\\"',
#	chr(0x309)	=>	'???', #combining hook above
	chr(0x30a)	=>  '\\r',
	chr(0x30b)	=>  '\\H',
	chr(0x30c)	=>  '\\v',
	chr(0x30f)	=>	'\\G',
	chr(0x314)	=>	'\\textrevcommaabove',
	chr(0x315)	=>	'\\textcommaabover',
	chr(0x316)	=>	'\\textsubgrave',
	chr(0x317)	=>	'\\textsubacute',
	chr(0x318)	=>	'\\textadvancing',
	chr(0x319)	=>	'\\textretracting',
	chr(0x31a)	=>	'\\textlangleabove',
	chr(0x31b)	=>	'\\textrighthorn',
	chr(0x31c)	=>	'\\textsublhalfring',
	chr(0x31d)	=>	'\\textraising',
	chr(0x31e)	=>	'\\textlowering',
	chr(0x31f)	=>	'\\textsubplus',
	chr(0x320)	=>	'\\textsubbar',
#	chr(0x320)	=>	'\\textsubminus',
	chr(0x321)	=>	'\\textpalhookbelow',
	chr(0x322)	=>	'\\M',
	chr(0x322)	=>	'\\textrethookbelow',
	chr(0x323)	=>	'\\d',
#	chr(0x323)	=>	'\\textsubdot',
	chr(0x324)	=>	'\\textsubumlaut',
	chr(0x325)	=>	'\\textsubring',
	chr(0x326)	=>	'\\textcommabelow',
	chr(0x327)	=>	'\\c',
	chr(0x328)	=>	'\\k',
#	chr(0x328)	=>	'\\textpolhook',
	chr(0x329)	=>	'\\textsyllabic',
	chr(0x32a)	=>	'\\textsubbridge',
	chr(0x32b)	=>	'\\textsubw',
	chr(0x32c)	=>	'\\textsubwedge',
	chr(0x32d)	=>	'\\textsubcircnum',
	chr(0x32e)	=>	'\\textsubbreve',
#	chr(0x32e)	=>	'\\textundertie',
	chr(0x32f)	=>	'\\textsubarch',
	chr(0x330)	=>	'\\textsubtilde',
	chr(0x331)	=>	'\\b',
#	chr(0x331)	=>	'\\textsubbar',
	chr(0x333)	=>	'\\subdoublebar',
	chr(0x334)	=>	'\\textsuperimposetilde',
	chr(0x335)	=>	'\\B',
#	chr(0x335)	=>	'\\textsstrokethru',
	chr(0x336)	=>	'\\textlstrokethru',
	chr(0x337)	=>	'\\textsstrikethru',
	chr(0x338)	=>	'\\textlstrikethru',
	chr(0x339)	=>	'\\textsubrhalfring',
	chr(0x33a)	=>	'\\textinvsubbridge',
	chr(0x33b)	=>	'\\textsubsquare',
	chr(0x33c)	=>	'\\textseagull',
	chr(0x33d)	=>	'\\textovercross',
	chr(0x346)	=>	'\\overbridge',
	chr(0x347)	=>	'\\subdoublebar',
	chr(0x348)	=>	'\\subdoublevert',
	chr(0x349)	=>	'\\subcorner',
	chr(0x34a)	=>	'\\crtilde',
	chr(0x34b)	=>	'\\dottedtilde',
	chr(0x34c)	=>	'\\doubletilde',
	chr(0x34d)	=>	'\\spreadlips',
	chr(0x34e)	=>	'\\whistle',
	chr(0x350)	=>	'\\textrightarrowhead',
	chr(0x351)	=>	'\\textlefthalfring',
	chr(0x354)	=>	'\\sublptr',
	chr(0x355)	=>	'\\subrptr',
	chr(0x356)	=>	'\\textrightuparrowhead',
	chr(0x357)	=>	'\\textrighthalfring',
	chr(0x35d)	=>	'\\textdoublebreve',
	chr(0x35e)	=>	'\\textdoublemacron',
	chr(0x35f)	=>	'\\textdoublemacronbelow',
	chr(0x360)	=>	'\\textdoubletilde',
	chr(0x361)	=>	'\\texttoptiebar',
	chr(0x362)	=>	'\\sliding'
);

my $WORDMAC_RE = join('', sort keys %WORDSMACROS);
$WORDMAC_RE = qr{ [$WORDMAC_RE] }x;

my $DIAC_RE = join('', sort keys %DIACRITICS);
$DIAC_RE = qr{ [$DIAC_RE] }x;

my $ACCENT_RE = qr{[\x{300}-\x{304}\x{307}\x{308}]};

sub _get_diac_last {
    my ($a,$b) = @_;
    if ( $b =~ /$ACCENT_RE/) {
        return $a eq 'i' ? '{\\i}' : $a
    }
    else {
        return "{$a}"
    }
}

sub latex_encode {
  my $text = NFD(shift);
  my %opts = @_;
  $text =~ s|([\\{}])|\\$1|g unless $opts{latex_source};
	$text =~ s{
        (\P{M})($DIAC_RE)($DIAC_RE)($DIAC_RE)
        }{
        $DIACRITICS{$4} . '{' . $DIACRITICS{$3} . '{' . $DIACRITICS{$2} . _get_diac_last($1,$2) . '}}'
        }gex;
	$text =~ s{
        (\P{M})($DIAC_RE)($DIAC_RE)
        }{
        $DIACRITICS{$3} . '{' . $DIACRITICS{$2} . _get_diac_last($1,$2) . '}'
        }gex;
	$text =~ s{
        (\P{M})($DIAC_RE)
        }{
        $DIACRITICS{$2} . _get_diac_last($1,$2)
        }gex;
	$text =~ s/($WORDMAC_RE)/$WORDSMACROS{$1}/ge;
	return $text
}

=head1 AUTHOR

François Charette, C<< <firmicus@cpan.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2010 François Charette, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;

# vim: set tabstop=4 shiftwidth=4 expandtab:
