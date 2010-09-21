#!/bin/bash

# call with the directory name where these live:
# biber-MSWIN.exe
# biber-darwin_x86_64
# biber-linux_x86_32
# biber-linux_x86_64

# Windows
scp $1/biber-MSWIN.exe philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/development/binaries/Windows/biber.exe
# OSX
scp $1/biber-darwin_x86_64 philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/development/binaries/OSX_Intel/biber
# Linux 32-bit
scp $1/biber-linux_x86_32 philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/development/binaries/Linux_32bit/biber
# Linux 64-bit
scp $1/biber-linux_x86_64 philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/development/binaries/Linux_64bit/biber

