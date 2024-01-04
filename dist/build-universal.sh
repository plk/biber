#!/bin/bash

# Local MacOS 64-bit ARM build and universal binary construction

# build-universal.sh <release> <branch> <binaryname> <justbuild> <deletescancache> <codesign>
#
# ./build-universal.sh development dev biber 0 0 1
#
# <release> is a SF subdir of /home/frs/project/biblatex-biber/
# <branch> is a git branch to checkout on the build farm servers
# <binaryname> is the name of the biber binary to use for the release.
# <justbuild> is a boolean which says to just build and stop without uploading
# <deletescancache> is a boolean which says to delete the scancache
# <codesign> is a boolean which says to not codesign OSX binary

BASE=~/extcode/biber
DOCDIR=$BASE/doc
BINDIR=$BASE/dist
XSLDIR=$BASE/data
RELEASE=${1:-"development"}
BRANCH=${2:-"dev"}
BINARYNAME=${3:-"biber"}
JUSTBUILD=${4:-"0"}
DSCANCACHE=${5:-"0"}
CODESIGN=${6:-"1"}


# Set scancache deletion if requested
if [ "$DSCANCACHE" = "1" ]; then
  echo "Deleting scan caches before builds";
  SCANCACHE="rm -f scancache;"
fi

cd $BASE
git checkout $BRANCH
git pull
perl ./Build.PL
./Build installdeps
./Build install
cd $BINDIR/darwin_arm64
$SCANCACHE./build.sh
~/bin/pp_osx_codesign_fix biber-darwin_arm64
cd $BASE
./Build realclean

cd $BINDIR/darwin_arm64
\rm -rf biber-darwin_arm64.tar.gz

if [ "$CODESIGN" = "1" ]; then
    echo "Signing binary"
    security unlock-keychain -p $(</Users/philkime/.pw) login.keychain
    codesign --verbose --sign 45MA3H23TG --force --timestamp --options runtime biber-darwin_arm64
fi

echo "Downloading x86_64 binary ... make sure it's the one you want"
\rm -rf biber-darwin_universal.tar.gz
\rm -rf biber-darwin_x86_64.tar.gz
\rm -rf $BINARYNAME
/opt/homebrew/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/$RELEASE/binaries/MacOS/biber-darwin_x86_64.tar.gz -O biber-darwin_x86_64.tar.gz
gtar zxf biber-darwin_x86_64.tar.gz
mv $BINARYNAME biber-darwin_x86_64
/usr/bin/lipo -create -output $BINARYNAME biber-darwin_x86_64 biber-darwin_arm64
chmod +x $BINARYNAME
gtar cf biber-darwin_universal.tar $BINARYNAME
gzip biber-darwin_universal.tar
\rm biber-darwin_arm*
\rm biber-darwin_x86_64*
\rm $BINARYNAME

# Stop here if JUSTBUILD is set
if [ "$JUSTBUILD" = "1" ]; then
  echo "JUSTBUILD is set, will not upload anything";
  exit 0;
fi

scp biber-darwin_universal.tar.gz philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/biblatex-biber/biblatex-biber/$RELEASE/binaries/MacOS/biber-darwin_universal.tar.gz
