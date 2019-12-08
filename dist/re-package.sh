#!/bin/bash

# Collect all binaries and re-package for CTAN

declare -r ROOT='/tmp/biber-repack/biber'

mkdir -p ${ROOT}/binaries
mkdir -p ${ROOT}/binaries/Linux
mkdir -p ${ROOT}/binaries/Linux-musl
mkdir -p ${ROOT}/binaries/FreeBSD
mkdir -p ${ROOT}/binaries/OSX_Intel
mkdir -p ${ROOT}/binaries/Solaris_Intel
mkdir -p ${ROOT}/binaries/Cygwin
mkdir -p ${ROOT}/binaries/Windows
mkdir -p ${ROOT}/documentation
mkdir -p ${ROOT}/source

# Linux
cd ${ROOT}/binaries/Linux
if [ ! -e $ROOT/binaries/Linux/biber-linux_x86_64.tar.gz ]; then
  /opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/current/binaries/Linux/biber-linux_x86_64.tar.gz
  [ $? -eq 0 ] || exit 1
fi
if [ ! -e $ROOT/binaries/Linux/biber-linux_x86_32.tar.gz ]; then
  /opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/current/binaries/Linux/biber-linux_x86_32.tar.gz
  [ $? -eq 0 ] || exit 1
fi

# Linux-musl
cd ${ROOT}/binaries/Linux-musl
if [ ! -e $ROOT/binaries/Linux-musl/biber-linux_x86_64-musl.tar.gz ]; then
  /opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/current/binaries/Linux-musl/biber-linux_x86_64-musl.tar.gz
  [ $? -eq 0 ] || exit 1
fi

# FreeBSD
cd ${ROOT}/binaries/FreeBSD
if [ ! -e $ROOT/binaries/FreeBSD/biber-amd64-freebsd.tar.xz ]; then
  /opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/current/binaries/FreeBSD/biber-amd64-freebsd.tar.xz
  [ $? -eq 0 ] || exit 1
fi
if [ ! -e $ROOT/binaries/FreeBSD/biber-i386-freebsd.tar.xz ]; then
  /opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/current/binaries/FreeBSD/biber-i386-freebsd.tar.xz
  [ $? -eq 0 ] || exit 1
fi

# Windows
cd ${ROOT}/binaries/Windows
if [ ! -e $ROOT/binaries/Windows/biber-MSWIN64.zip ]; then
  /opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/current/binaries/Windows/biber-MSWIN64.zip
  [ $? -eq 0 ] || exit 1
fi
if [ ! -e $ROOT/binaries/Windows/biber-MSWIN32.zip ]; then
  /opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/current/binaries/Windows/biber-MSWIN32.zip
  [ $? -eq 0 ] || exit 1
fi

# OSX_Intel (including legacy (10.5<version<10.13))
cd ${ROOT}/binaries/OSX_Intel
if [ ! -e $ROOT/binaries/OSX_Intel/biber-darwinlegacy_x86_64.tar.gz ]; then
  /opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/current/binaries/OSX_Intel/biber-darwinlegacy_x86_64.tar.gz
  [ $? -eq 0 ] || exit 1
fi
if [ ! -e $ROOT/binaries/OSX_Intel/biber-darwin_x86_64.tar.gz ]; then
  /opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/current/binaries/OSX_Intel/biber-darwin_x86_64.tar.gz
  [ $? -eq 0 ] || exit 1
fi

# Solaris_Intel
cd ${ROOT}/binaries/Solaris_Intel
if [ ! -e $ROOT/binaries/Solaris_Intel/biber-x86_64-pc-solaris2.11.tar.xz ]; then
  /opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/current/binaries/Solaris_Intel/biber-x86_64-pc-solaris2.11.tar.xz
  [ $? -eq 0 ] || exit 1
fi
if [ ! -e $ROOT/binaries/Solaris_Intel/biber-i386-pc-solaris2.11.tar.xz ]; then
  /opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/current/binaries/Solaris_Intel/biber-i386-pc-solaris2.11.tar.xz
  [ $? -eq 0 ] || exit 1
fi

# Cygwin
cd ${ROOT}/binaries/Cygwin
if [ ! -e $ROOT/binaries/Cygwin/biber-cygwin64.tar.gz ]; then
  /opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/current/binaries/Cygwin/biber-cygwin64.tar.gz
  [ $? -eq 0 ] || exit 1
fi
if [ ! -e $ROOT/binaries/Cygwin/Cygwin/biber-cygwin32.tar.gz ]; then
  /opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/current/binaries/Cygwin/biber-cygwin32.tar.gz
 [ $? -eq 0 ] || exit 1
fi

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
