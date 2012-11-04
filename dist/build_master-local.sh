#!/bin/bash

# This version of the build script can be run on the server hosting the VMs instead of a remote
# client

# build_master.sh <dir> <release> <branch> <justbuild>

# <dir> is where the binaries are
# <release> is a SF subdir of /home/frs/project/biblatex-biber/biblatex-biber/
# <branch> is a git branch to checkout on the build farm servers
# <justbuild> is a boolean which says to just build and stop without uploading

function vmon {
  VM=$(pgrep -f -- "-startvm bbf-$1")
  if [ ! -z "$VM" ]; then
    echo "Biber build farm VM already running with PID: $VM"
  else
    nohup VBoxHeadless --startvm bbf-$1 &
  fi
}

function vmoff {
  VBoxManage controlvm bbf-$1 savestate
}

# Example: build_master.sh ~/Desktop/b development dev 1

BASE="/usr/local/data/code/biblatex-biber"
DOCDIR=$BASE/doc
DRIVERDIR=$BASE/lib/Biber/Input/
BINDIR=$BASE/dist
XSLDIR=$BASE/data
DIR=${1:-"/tmp/b"}
RELEASE=${2:-"development"}
BRANCH=${3:-"dev"}
JUSTBUILD=${4:-"0"}

echo "** Checking out branch '$BRANCH' on farm servers **"
echo "** If this is not correct, Ctrl-C now **"
sleep 5

# Make binary dir if it doesn't exist
if [ ! -e $DIR ]; then
  mkdir $DIR
fi

# Create the binaries from the build farm if they don't exist

# Build farm OSX 64-bit intel
# ntpdate is because Vbox doesn't timesync OSX and ntp never works because the
# time difference is too great between boots
if [ ! -e $DIR/biber-darwin_x86_64.tar.gz ]; then
  vmon osx10.6
  sleep 10
  ssh philkime@bbf-osx10.6 "sudo ntpdate ch.pool.ntp.org;cd biblatex-biber;git checkout $BRANCH;git pull;perl ./Build.PL;sudo ./Build installdeps;sudo ./Build install;cd dist/darwin_x86_64;./build.sh;cd ~/biblatex-biber;sudo ./Build realclean"
  scp philkime@bbf-osx10.6:biblatex-biber/dist/darwin_x86_64/biber-darwin_x86_64 $DIR/
  ssh philkime@bbf-osx10.6 "\\rm -f biblatex-biber/dist/darwin_x86_64/biber-darwin_x86_64"
  vmoff osx10.6
  cd $DIR
  mv biber-darwin_x86_64 biber
  chmod +x biber
  tar cf biber-darwin_x86_64.tar biber
  gzip biber-darwin_x86_64.tar
  \rm biber
  cd $BASE
fi

# Build farm OSX 32-bit intel (universal)
# ntpdate is because Vbox doesn't timesync OSX and ntp never works because the
# time difference is too great between boots
if [ ! -e $DIR/biber-darwin_x86_i386.tar.gz ]; then
  vmon osx10.5
  sleep 10
  ssh philkime@bbf-osx10.5 "sudo ntpdate ch.pool.ntp.org;cd biblatex-biber;git checkout $BRANCH;git pull;perl ./Build.PL;sudo ./Build installdeps;sudo ./Build install;cd dist/darwin_x86_i386;./build.sh;cd ~/biblatex-biber;sudo ./Build realclean"
  scp philkime@bbf-osx10.5:biblatex-biber/dist/darwin_x86_i386/biber-darwin_x86_i386 $DIR/
  ssh philkime@bbf-osx10.5 "\\rm -f biblatex-biber/dist/darwin_x86_i386/biber-darwin_x86_i386"
  vmoff osx10.5
  cd $DIR
  mv biber-darwin_x86_i386 biber
  chmod +x biber
  tar cf biber-darwin_x86_i386.tar biber
  gzip biber-darwin_x86_i386.tar
  \rm biber
  cd $BASE
fi


# Build farm WinXP
# We run "Build realclean" at the end as we are using the same tree for
# win and cygwin builds
# DON'T FORGET THAT installdeps WON'T WORK FOR STRAWBERRY INSIDE CYGWIN
# SO YOU HAVE TO INSTALL MODULE UPDATES MANUALLY
if [ ! -e $DIR/biber-MSWIN.zip ]; then
  vmon wxp32
  sleep 20
  ssh philkime@bbf-wxp32 "cd biblatex-biber;git checkout $BRANCH;git pull;perl ./Build.PL;./Build install;cd dist/MSWin32;./build.bat;cd ~/biblatex-biber;./Build realclean"
  scp philkime@bbf-wxp32:biblatex-biber/dist/MSWin32/biber-MSWIN.exe $DIR/
  ssh philkime@bbf-wxp32 "\\rm -f biblatex-biber/dist/MSWin32/biber-MSWIN.exe"
  vmoff wxp32  
  cd $DIR
  mv biber-MSWIN.exe biber.exe
  chmod +x biber.exe
  /usr/bin/zip biber-MSWIN.zip biber.exe
  \rm -f biber.exe
  cd $BASE
fi

# Build farm cygwin
# We run "Build realclean" at the end as we are using the same tree for
# win and cygwin builds
if [ ! -e $DIR/biber-cygwin32.tar.gz ]; then
  vmon wxp32
  sleep 20
  # We have to move aside the windows libbtparse.dll otherwise it's picked up by cygwin
  ssh philkime@bbf-wxp32 ". bin/set-biber-cyg-build-env.sh;mv /cygdrive/c/WINDOWS/system32/libbtparse.dll /cygdrive/c/WINDOWS/system32/libbtparse.dll.DIS;cd biblatex-biber;git checkout $BRANCH;git pull;perl ./Build.PL;./Build installdeps;./Build install;cd dist/cygwin32;./build.sh;mv /cygdrive/c/WINDOWS/system32/libbtparse.dll.DIS /cygdrive/c/WINDOWS/system32/libbtparse.dll;cd ~/biblatex-biber;./Build realclean"
  scp philkime@bbf-wxp32:biblatex-biber/dist/cygwin32/biber-cygwin32.exe $DIR/
  ssh philkime@bbf-wxp32 "\\rm -f biblatex-biber/dist/cygwin32/biber-cygwin32.exe"
  vmoff wxp32
  cd $DIR
  mv biber-cygwin32.exe biber.exe
  chmod +x biber.exe
  tar cf biber-cygwin32.tar biber.exe
  gzip biber-cygwin32.tar
  \rm -f biber.exe
  cd $BASE
fi

# Build farm Linux 32
if [ ! -e $DIR/biber-linux_x86_32.tar.gz ]; then
  vmon jj32
  sleep 20
  ssh philkime@bbf-jj32 "cd biblatex-biber;git checkout $BRANCH;git pull;/usr/local/perl/bin/perl ./Build.PL;sudo ./Build installdeps;sudo ./Build install;cd dist/linux_x86_32;./build.sh;cd ~/biblatex-biber;sudo ./Build realclean"
  scp philkime@bbf-jj32:biblatex-biber/dist/linux_x86_32/biber-linux_x86_32 $DIR/
  ssh philkime@bbf-jj32 "\\rm -f biblatex-biber/dist/linux_x86_32/biber-linux_x86_32"
  vmoff jj32
  cd $DIR
  mv biber-linux_x86_32 biber
  chmod +x biber
  tar cf biber-linux_x86_32.tar biber
  gzip biber-linux_x86_32.tar
  \rm biber
  cd $BASE
fi

# Build farm Linux 64
if [ ! -e $DIR/biber-linux_x86_64.tar.gz ]; then
  vmon jj64
  sleep 20
  ssh philkime@bbf-jj64 "cd biblatex-biber;git checkout $BRANCH;git pull;/usr/local/perl/bin/perl ./Build.PL;sudo ./Build installdeps;sudo ./Build install;cd dist/linux_x86_64;./build.sh;cd ~/biblatex-biber;sudo ./Build realclean"
  scp philkime@bbf-jj64:biblatex-biber/dist/linux_x86_64/biber-linux_x86_64 $DIR/
  ssh philkime@bbf-jj64 "\\rm -f biblatex-biber/dist/linux_x86_64/biber-linux_x86_64"
  vmoff jj64
  cd $DIR
  mv biber-linux_x86_64 biber
  chmod +x biber
  tar cf biber-linux_x86_64.tar biber
  gzip biber-linux_x86_64.tar
  \rm biber
  cd $BASE
fi

# Stop here if JUSTBUILD is set
if [ "$JUSTBUILD" = "1" ]; then
  echo "JUSTBUILD is set, will not upload anything";
  exit 0;
fi

cd $DIR
# OSX 64-bit
if [ -e $DIR/biber-darwin_x86_64.tar.gz ]; then
  scp biber-darwin_x86_64.tar.gz philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/biblatex-biber/biblatex-biber/$RELEASE/binaries/OSX_Intel/biber-darwin_x86_64.tar.gz
fi

# OSX 32-bit universal
if [ -e $DIR/biber-darwin_x86_i386.tar.gz ]; then
  scp biber-darwin_x86_i386.tar.gz philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/biblatex-biber/biblatex-biber/$RELEASE/binaries/OSX_Intel/biber-darwin_x86_i386.tar.gz
fi

# Windows
if [ -e $DIR/biber-MSWIN.zip ]; then
  scp biber-MSWIN.zip philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/biblatex-biber/biblatex-biber/$RELEASE/binaries/Windows/biber-MSWIN.zip
fi

# Cygwin
if [ -e $DIR/biber-cygwin32.tar.gz ]; then
  scp biber-cygwin32.tar.gz philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/biblatex-biber/biblatex-biber/$RELEASE/binaries/Cygwin/biber-cygwin32.tar.gz
fi

# Linux 32-bit
if [ -e $DIR/biber-linux_x86_32.tar.gz ]; then
  scp biber-linux_x86_32.tar.gz philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/biblatex-biber/biblatex-biber/$RELEASE/binaries/Linux/biber-linux_x86_32.tar.gz
fi

# Linux 64-bit
if [ -e $DIR/biber-linux_x86_64.tar.gz ]; then
  scp biber-linux_x86_64.tar.gz philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/biblatex-biber/biblatex-biber/$RELEASE/binaries/Linux/biber-linux_x86_64.tar.gz
fi

# Doc
scp $DOCDIR/biber.pdf philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/biblatex-biber/biblatex-biber/$RELEASE/documentation/biber.pdf

# Changes file
scp $BASE/Changes philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/biblatex-biber/biblatex-biber/$RELEASE/Changes

# Unicode <-> LaTeX macro mapping doc
perl $BINDIR/xsl-transform.pl $BASE/lib/Biber/LaTeX/recode_data.xml $XSLDIR/texmap.xsl
scp $BASE/lib/Biber/LaTeX/recode_data.xml.html philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/biblatex-biber/biblatex-biber/$RELEASE/documentation/utf8-macro-map.html
\rm -f $BASE/lib/Biber/LaTeX/recode_data.xml.html

# source
cd $BASE
./Build dist
scp $BASE/biblatex-biber-*.tar.gz philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/biblatex-biber/biblatex-biber/$RELEASE/biblatex-biber.tar.gz
\rm -f $BASE/biblatex-biber-*.tar.gz

cd $BASE
