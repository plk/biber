#!/bin/bash

# call with the directory name where these live:
# biber-MSWIN.exe
# biber-darwin_x86_64
# biber-linux_x86_32
# biber-linux_x86_64

BASE="/Users/philkime/data/code/biblatex-biber"
DOCDIR=$BASE/doc
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
