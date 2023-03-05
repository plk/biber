#!/bin/bash
# The paths sometimes change, check here: https://sourceforge.net/p/forge/documentation/SCP/
# For interactive login, use ssh -t philkime@shell.sourceforge.net create

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
mkdir -p /tmp/sftree/binaries/MacOS
mkdir -p /tmp/sftree/binaries/Windows
mkdir -p /tmp/sftree/binaries/ARM

chmod -R 777 /tmp/sftree

# Need to use -O for legacy compat since scp is too new for the SF servers
# https://unix.stackexchange.com/questions/730328/scp-requires-directory-of-same-name-to-exist-on-target-server
scp -O -r /tmp/sftree/* philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/biblatex-biber/$1/

\rm -rf /tmp/sftree
