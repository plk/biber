#!/bin/bash

# Collect all binaries and re-package for CTAN

declare -r ROOT='/tmp/biber-repack/biber'

mkdir -p ${ROOT}/binaries
mkdir -p ${ROOT}/binaries/Linux
mkdir -p ${ROOT}/binaries/FreeBSD
mkdir -p ${ROOT}/binaries/OSX_Intel
mkdir -p ${ROOT}/binaries/Solaris_Intel
mkdir -p ${ROOT}/binaries/ARM
mkdir -p ${ROOT}/binaries/Cygwin
mkdir -p ${ROOT}/binaries/Windows
mkdir -p ${ROOT}/documentation
mkdir -p ${ROOT}/source

# Linux
cd ${ROOT}/binaries/Linux
/opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/current/binaries/Linux/biber-linux_x86_64.tar.gz
[ $? -eq 0 ] || exit 1
/opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/current/binaries/Linux/biber-linux_x86_32.tar.gz
[ $? -eq 0 ] || exit 1

# FreeBSD
cd ${ROOT}/binaries/FreeBSD
/opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/current/binaries/FreeBSD/biber-amd64-freebsd.tar.xz
[ $? -eq 0 ] || exit 1
/opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/current/binaries/FreeBSD/biber-i386-freebsd.tar.xz
[ $? -eq 0 ] || exit 1

# Windows
cd ${ROOT}/binaries/Windows
/opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/current/binaries/Windows/biber-MSWIN64.zip
[ $? -eq 0 ] || exit 1
/opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/current/binaries/Windows/biber-MSWIN32.zip
[ $? -eq 0 ] || exit 1

# OSX_Intel
cd ${ROOT}/binaries/OSX_Intel
/opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/current/binaries/OSX_Intel/biber-darwin_x86_i386.tar.gz
[ $? -eq 0 ] || exit 1
/opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/current/binaries/OSX_Intel/biber-darwin_x86_64.tar.gz
[ $? -eq 0 ] || exit 1

# Solaris_Intel
cd ${ROOT}/binaries/Solaris_Intel
/opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/current/binaries/Solaris_Intel/biber-x86_64-pc-solaris2.11.tar.xz
[ $? -eq 0 ] || exit 1

# Cygwin
cd ${ROOT}/binaries/Cygwin
/opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/current/binaries/Cygwin/biber-cygwin64.tar.gz
[ $? -eq 0 ] || exit 1
/opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/current/binaries/Cygwin/biber-cygwin32.tar.gz
[ $? -eq 0 ] || exit 1

# ARM
cd ${ROOT}/binaries/ARM
/opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/current/binaries/ARM/biber-linux_armel.tar.gz
#[ $? -eq 0 ] || exit 1

# Documentation
cd ${ROOT}/documentation
/opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/current/documentation/biber.pdf
[ $? -eq 0 ] || exit 1
/opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/current/documentation/utf8-macro-map.html
[ $? -eq 0 ] || exit 1
cp ~/data/code/biblatex-biber/Changes .

# Source
cd ${ROOT}/source/
/opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/current/biblatex-biber.tar.gz

# README
cd ${ROOT}
/opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/README.md
[ $? -eq 0 ] || exit 1

# Pack and upload
cd /tmp/biber-repack
tar czf biber.tgz biber
cp /tmp/biber-repack/biber.tgz ~/Dropbox/
cd /tmp
\rm -rf /tmp/biber-repack

# Make empty archive
cd ~/Desktop
echo "Please retrieve file from location in comments" > ~/Desktop/biber.txt
tar zcf biber.tgz biber.txt
\rm -f biber.txt
echo "Empty archive is: ~/Desktop/biber.tgz"
