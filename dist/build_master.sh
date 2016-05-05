#!/bin/bash

# build_master.sh <dir> <release> <branch> <justbuild> <deletescancache>

# <dir> is where the binaries are
# <release> is a SF subdir of /home/frs/project/biblatex-biber/biblatex-biber/
# <branch> is a git branch to checkout on the build farm servers
# <justbuild> is a boolean which says to just build and stop without uploading
# <deletescancache> is a boolean which says to delete the scancache

# Example: build_master.sh ~/Desktop/b development dev 1

BASE="/Users/philkime/data/code/biblatex-biber"
DOCDIR=$BASE/doc
DRIVERDIR=$BASE/lib/Biber/Input/
BINDIR=$BASE/dist
XSLDIR=$BASE/data
DIR=${1:-"/Users/philkime/Desktop/b"}
RELEASE=${2:-"development"}
BRANCH=${3:-"dev"}
JUSTBUILD=${4:-"0"}
DSCANCACHE=${5:-"0"}

export COPYFILE_DISABLE=true # no resource forks in archives - non-macs don't like them

echo "** Checking out branch '$BRANCH' on farm servers **"
echo "** If this is not correct, Ctrl-C now **"
sleep 5

# Make binary dir if it doesn't exist
if [ ! -e $DIR ]; then
  mkdir $DIR
fi

# Stop here if JUSTBUILD is set
if [ "$DSCANCACHE" = "1" ]; then
  echo "Deleting scan caches before builds";
  SCANCACHE="rm -f scancache;"
fi

# Create the binaries from the build farm if they don't exist

# Build farm OSX 64-bit intel
# ntpdate is because Vbox doesn't timesync OSX and ntp never works because the
# time difference is too great between boots
if [ ! -e $DIR/biber-darwin_x86_64.tar.gz ]; then
  ssh vbox@park "VBoxHeadless --startvm bbf-osx10.6 </dev/null >/dev/null 2>&1 &"
  sleep 5
  ssh bbf-osx10.6 "sudo ntpdate ch.pool.ntp.org;cd biblatex-biber;git checkout $BRANCH;git pull;perl ./Build.PL;sudo ./Build installdeps;sudo ./Build install;cd dist/darwin_x86_64;$SCANCACHE./build.sh;cd ~/biblatex-biber;sudo ./Build realclean"
  scp bbf-osx10.6:biblatex-biber/dist/darwin_x86_64/biber-darwin_x86_64 $DIR/
  ssh bbf-osx10.6 "\\rm -f biblatex-biber/dist/darwin_x86_64/biber-darwin_x86_64"
  ssh vbox@park "VBoxManage controlvm bbf-osx10.6 savestate"
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
  ssh vbox@park "VBoxHeadless --startvm bbf-osx10.5 </dev/null >/dev/null 2>&1 &"
  sleep 5
  ssh bbf-osx10.5 "sudo ntpdate ch.pool.ntp.org;cd biblatex-biber;git checkout $BRANCH;git pull;perl ./Build.PL;sudo ./Build installdeps;sudo ./Build install;cd dist/darwin_x86_i386;$SCANCACHE./build.sh;cd ~/biblatex-biber;sudo ./Build realclean"
  scp bbf-osx10.5:biblatex-biber/dist/darwin_x86_i386/biber-darwin_x86_i386 $DIR/
  ssh bbf-osx10.5 "\\rm -f biblatex-biber/dist/darwin_x86_i386/biber-darwin_x86_i386"
  ssh vbox@park "VBoxManage controlvm bbf-osx10.5 savestate"
  cd $DIR
  mv biber-darwin_x86_i386 biber
  chmod +x biber
  tar cf biber-darwin_x86_i386.tar biber
  gzip biber-darwin_x86_i386.tar
  \rm biber
  cd $BASE
fi


# Build farm MSWIN32
# DON'T FORGET THAT installdeps WON'T WORK FOR STRAWBERRY INSIDE CYGWIN
# SO YOU HAVE TO INSTALL MODULE UPDATES MANUALLY
if [ ! -e $DIR/biber-MSWIN32.zip ]; then
  ssh vbox@park "VBoxHeadless --startvm bbf-wxp32 </dev/null >/dev/null 2>&1 &"
  sleep 10
  ssh bbf-wxp32 "cd biblatex-biber;git checkout $BRANCH;git pull;perl ./Build.PL;./Build install;cd dist/MSWIN32;$SCANCACHE./build.bat;cd ~/biblatex-biber;./Build realclean"
  scp bbf-wxp32:biblatex-biber/dist/MSWIN32/biber-MSWIN32.exe $DIR/
  ssh bbf-wxp32 "\\rm -f biblatex-biber/dist/MSWIN32/biber-MSWIN32.exe"
  ssh vbox@park "VBoxManage controlvm bbf-wxp32 savestate"
  cd $DIR
  mv biber-MSWIN32.exe biber.exe
  chmod +x biber.exe
  /usr/bin/zip biber-MSWIN32.zip biber.exe
  \rm -f biber.exe
  cd $BASE
fi

# Build farm MSWIN64
# DON'T FORGET THAT installdeps WON'T WORK FOR STRAWBERRY INSIDE CYGWIN
# SO YOU HAVE TO INSTALL MODULE UPDATES MANUALLY
if [ ! -e $DIR/biber-MSWIN364.zip ]; then
  ssh vbox@park "VBoxHeadless --startvm bbf-w1064 </dev/null >/dev/null 2>&1 &"
  sleep 10
  ssh bbf-w1064 "cd biblatex-biber;git checkout $BRANCH;git pull;perl ./Build.PL;./Build install;cd dist/MSWIN64;$SCANCACHE./build.bat;cd ~/biblatex-biber;./Build realclean"
  scp bbf-w1064:biblatex-biber/dist/MSWIN64/biber-MSWIN64.exe $DIR/
  ssh bbf-w1064 "\\rm -f biblatex-biber/dist/MSWIN64/biber-MSWIN64.exe"
  ssh vbox@park "VBoxManage controlvm bbf-w1064 savestate"
  cd $DIR
  mv biber-MSWIN64.exe biber.exe
  chmod +x biber.exe
  /usr/bin/zip biber-MSWIN64.zip biber.exe
  \rm -f biber.exe
  cd $BASE
fi

# Build farm Linux 32
if [ ! -e $DIR/biber-linux_x86_32.tar.gz ]; then
  ssh vbox@park "VBoxHeadless --startvm bbf-l32 </dev/null >/dev/null 2>&1 &"
  sleep 10
  ssh bbf-l32 "sudo ntpdate ch.pool.ntp.org;cd biblatex-biber;git checkout $BRANCH;git pull;/usr/local/perl/bin/perl ./Build.PL;sudo ./Build installdeps;sudo ./Build install;cd dist/linux_x86_32;$SCANCACHE./build.sh;cd ~/biblatex-biber;sudo ./Build realclean"
  scp bbf-l32:biblatex-biber/dist/linux_x86_32/biber-linux_x86_32 $DIR/
  ssh bbf-l32 "\\rm -f biblatex-biber/dist/linux_x86_32/biber-linux_x86_32"
  ssh vbox@park "VBoxManage controlvm bbf-l32 savestate"
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
  ssh vbox@park "VBoxHeadless --startvm bbf-l64 </dev/null >/dev/null 2>&1 &"
  sleep 10
  ssh bbf-l64 "sudo ntpdate ch.pool.ntp.org;cd biblatex-biber;git checkout $BRANCH;git pull;/usr/local/perl/bin/perl ./Build.PL;sudo ./Build installdeps;sudo ./Build install;cd dist/linux_x86_64;$SCANCACHE./build.sh;cd ~/biblatex-biber;sudo ./Build realclean"
  scp bbf-l64:biblatex-biber/dist/linux_x86_64/biber-linux_x86_64 $DIR/
  ssh bbf-l64 "\\rm -f biblatex-biber/dist/linux_x86_64/biber-linux_x86_64"
  ssh vbox@park "VBoxManage controlvm bbf-l64 savestate"
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

# Windows 32-bit
if [ -e $DIR/biber-MSWIN32.zip ]; then
  scp biber-MSWIN32.zip philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/biblatex-biber/biblatex-biber/$RELEASE/binaries/Windows/biber-MSWIN32.zip
fi

# Windows 64-bit
if [ -e $DIR/biber-MSWIN64.zip ]; then
  scp biber-MSWIN64.zip philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/biblatex-biber/biblatex-biber/$RELEASE/binaries/Windows/biber-MSWIN64.zip
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
$BINDIR/xsl-transform.pl $BASE/lib/Biber/LaTeX/recode_data.xml $XSLDIR/texmap.xsl
scp $BASE/lib/Biber/LaTeX/recode_data.xml.html philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/biblatex-biber/biblatex-biber/$RELEASE/documentation/utf8-macro-map.html
\rm -f $BASE/lib/Biber/LaTeX/recode_data.xml.html

# source
cd $BASE
./Build dist
scp $BASE/biblatex-biber-*.tar.gz philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/biblatex-biber/biblatex-biber/$RELEASE/biblatex-biber.tar.gz
\rm -f $BASE/biblatex-biber-*.tar.gz

cd $BASE
