#!/bin/bash

if [ -z "$1" ]; then
  echo "No folder name provided!"
  exit 1
fi

mkdir -p /tmp/sftree/documentation
mkdir -p /tmp/sftree/binaries/Cygwin
mkdir -p /tmp/sftree/binaries/Linux
mkdir -p /tmp/sftree/binaries/Linux-musl
mkdir -p /tmp/sftree/binaries/Solaris_Intel
mkdir -p /tmp/sftree/binaries/FreeBSD
mkdir -p /tmp/sftree/binaries/OSX_Intel
mkdir -p /tmp/sftree/binaries/Windows
mkdir -p /tmp/sftree/binaries/ARM

chmod -R 777 /tmp/sftree

scp -r /tmp/sftree/* philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/biblatex-biber/biblatex-biber/$1

\rm -rf /tmp/sftree
