#!/bin/bash

# call with the directory name where these live:
# biber-MSWIN.exe
# biber-darwin_x86_64
# biber-linux_x86_32
# biber-linux_x86_64

DIR=${1:-"/Users/philkime/Desktop/b"}
RELEASE=${2:-"development"}


# Windows
mv $DIR/biber-MSWIN.exe $DIR/biber.exe
/usr/bin/zip $DIR/biber.zip $DIR/biber.exe
scp $DIR/biber.zip philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/$RELEASE/binaries/Windows/biber.zip
\rm $DIR/biber.zip $DIR/biber.exe
# OSX
mv $DIR/biber-darwin_x86_64 $DIR/biber
tar cf $DIR/biber.tar $DIR/biber
gzip $DIR/biber.tar
scp $DIR/biber.tar.gz philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/$RELEASE/binaries/OSX_Intel/biber.tar.gz
\rm $DIR/biber.tar.gz $DIR/biber
# Linux 32-bit
mv $DIR/biber-linux_x86_32 $DIR/biber
tar cf $DIR/biber.tar $DIR/biber
gzip $DIR/biber.tar
scp $DIR/biber.tar.gz philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/$RELEASE/binaries/Linux_32bit/biber.tar.gz
\rm $DIR/biber.tar.gz $DIR/biber
# Linux 64-bit
mv $DIR/biber-linux_x86_64 $DIR/biber
tar cf $DIR/biber.tar $DIR/biber
gzip $DIR/biber.tar
scp $DIR/biber.tar.gz philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/$RELEASE/binaries/Linux_64bit/biber.tar.gz
\rm $DIR/biber.tar.gz $DIR/biber
