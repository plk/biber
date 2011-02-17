#!/bin/bash

# call with the directory name where these live:
# biber-MSWIN.exe
# biber-darwin_x86_64
# biber-linux_x86_32
# biber-linux_x86_64

BASE="/Users/philkime/data/code/biblatex-biber"
DOCDIR=$BASE/doc
DRIVERDIR=$BASE/lib/Biber/Input/
BINDIR=$BASE/dist
XSLDIR=$BASE/data
DIR=${1:-"/Users/philkime/Desktop/b"}
RELEASE=${2:-"development"}
export COPYFILE_DISABLE=true # no resource forks - TL doesn't like them

cd $DIR
# Windows
cp biber-MSWIN.exe biber.exe
chmod +x biber.exe
/usr/bin/zip biber.zip biber.exe
scp biber.zip philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/$RELEASE/binaries/Windows/biber.zip
\rm biber.zip biber.exe
# OSX
cp biber-darwin_x86_64 biber
chmod +x biber
tar cf biber.tar biber
gzip biber.tar
scp biber.tar.gz philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/$RELEASE/binaries/OSX_Intel/biber.tar.gz
\rm biber.tar.gz biber
# Linux 32-bit
cp biber-linux_x86_32 biber
chmod +x biber
tar cf biber.tar biber
gzip biber.tar
scp biber.tar.gz philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/$RELEASE/binaries/Linux_32bit/biber.tar.gz
\rm biber.tar.gz biber
# Linux 64-bit
cp biber-linux_x86_64 biber
chmod +x biber
tar cf biber.tar biber
gzip biber.tar
scp biber.tar.gz philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/$RELEASE/binaries/Linux_64bit/biber.tar.gz
\rm biber.tar.gz biber
# Doc
scp $DOCDIR/biber.pdf philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/$RELEASE/documentation/biber.pdf
# Changes file
scp $BASE/Changes philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/$RELEASE/Changes
# Driver control file docs
find $DRIVERDIR -name \*.dcf | xargs -i{} cp {} ~/Desktop/
for dcf in ~/Desktop/*.dcf
do
$BINDIR/make-pretty-dcsf.pl $file $XSLDIR/dcf.xsl
scp $file.html $philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/$RELEASE/documentation/
\rm -f $file*
done

if [ $RELEASE != "development" ]; then
# Perl dist tree
scp $BASE/biblatex-biber-*.tar.gz philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/$RELEASE/biblatex-biber.tar.gz
rm $BASE/biblatex-biber-*.tar.gz
# Make TLContrib main package (docs only)
mkdir -p ~/Desktop/doc/biber
cp $DOCDIR/biber.pdf ~/Desktop/doc/biber/
\rm -f ~/Desktop/doc/.DS_Store
\rm -f ~/Desktop/doc/biber/.DS_Store
tar cvf ~/Desktop/biber.tar -C ~/Desktop doc
gzip ~/Desktop/biber.tar
\rm -rf ~/Desktop/doc
fi
