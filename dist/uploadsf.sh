#!/bin/bash

# call with the directory name where these live:
# biber-MSWIN.exe
# biber-darwin_x86_64
# biber-linux_x86_32
# biber-linux_x86_64

DIR=${1:-"~/Desktop/b"}
RELEASE=${2:-"development"}


# Windows
scp $DIR/biber-MSWIN.exe philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/$RELEASE/binaries/Windows/biber.exe
# OSX
scp $DIR/biber-darwin_x86_64 philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/$RELEASE/binaries/OSX_Intel/biber
# Linux 32-bit
scp $DIR/biber-linux_x86_32 philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/$RELEASE/binaries/Linux_32bit/biber
# Linux 64-bit
scp $DIR/biber-linux_x86_64 philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/$RELEASE/binaries/Linux_64bit/biber

