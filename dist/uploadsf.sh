#!/bin/bash

# call with the directory name where these live:
# biber-MSWIN.exe
# biber-darwin_x86_64
# biber-linux_x86_32
# biber-linux_x86_64

DIR=${1:-"/Users/philkime/Desktop/b"}
RELEASE=${2:-"development"}

cd $DIR
# Windows
mv biber-MSWIN.exe biber.exe
/usr/bin/zip biber.zip biber.exe
scp biber.zip philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/$RELEASE/binaries/Windows/biber.zip
\rm biber.zip biber.exe
# OSX
mv biber-darwin_x86_64 biber
tar cf biber.tar biber
gzip biber.tar
scp biber.tar.gz philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/$RELEASE/binaries/OSX_Intel/biber.tar.gz
\rm $DIR/biber.tar.gz biber
# Linux 32-bit
mv biber-linux_x86_32 biber
tar cf biber.tar biber
gzip biber.tar
scp biber.tar.gz philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/$RELEASE/binaries/Linux_32bit/biber.tar.gz
\rm biber.tar.gz biber
# Linux 64-bit
mv biber-linux_x86_64 biber
tar cf biber.tar biber
gzip biber.tar
scp biber.tar.gz philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/$RELEASE/binaries/Linux_64bit/biber.tar.gz
\rm biber.tar.gz biber

