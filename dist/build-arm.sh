#!/bin/bash

# Local OSX 64-bit ARM

# build-arm.sh <release> <branch> <justbuild> <deletescancache> <codesign>
#
# ./build-arm.sh development dev 1 0 1
# 
# <release> is a SF subdir of /home/frs/project/biblatex-biber/biblatex-biber/
# <branch> is a git branch to checkout on the build farm servers
# <justbuild> is a boolean which says to just build and stop without uploading
# <deletescancache> is a boolean which says to delete the scancache
# <codesign> is a boolean which says to not codesign OSX binary

BASE=~/extcode/biber
DOCDIR=$BASE/doc
BINDIR=$BASE/dist
XSLDIR=$BASE/data
RELEASE=${1:-"development"}
BRANCH=${2:-"dev"}
JUSTBUILD=${3:-"0"}
DSCANCACHE=${4:-"0"}
CODESIGN=${5:-"1"}

# Set scancache deletion if requested
if [ "$DSCANCACHE" = "1" ]; then
  echo "Deleting scan caches before builds";
  SCANCACHE="rm -f scancache;"
fi

cd $BASE
git checkout $BRANCH
git pull
perl ./Build.PL
sudo ./Build installdeps
sudo ./Build install
cd dist/darwin_arm
$SCANCACHE./build.sh
~/bin/pp_osx_codesign_fix biber-darwin_arm
cd $BASE
sudo ./Build realclean

cd $BINDIR/darwin_arm
\rm -rf biber-darwin_arm.tar.gz

if [ "$CODESIGN" = "1" ]; then
    echo "Signing binary"
    security unlock-keychain -p $(</Users/philkime/.pw) login.keychain
    codesign --verbose --sign 45MA3H23TG --force --timestamp --options runtime biber-darwin_arm
fi

mv biber-darwin_arm biber
chmod +x biber
tar cf biber-darwin_arm.tar biber
gzip biber-darwin_arm.tar
\rm biber

# Stop here if JUSTBUILD is set
if [ "$JUSTBUILD" = "1" ]; then
  echo "JUSTBUILD is set, will not upload anything";
  exit 0;
fi

scp biber-darwin_arm.tar.gz philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/biblatex-biber/biblatex-biber/$RELEASE/binaries/OSX_Arm64/biber-darwin_arm.tar.gz


