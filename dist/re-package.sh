#!/bin/bash

# Collect all binaries and re-package for CTAN
# re-package.sh <biber version> <releasefolder>
#
# ./re-package.sh 2.19 current

declare -r ROOT='/tmp/biber-repack'

mkdir -p ${ROOT}
cd ${ROOT}
declare VER=$1
declare RELEASE=${2:-"current"}
declare PACKAGEEXT=""
declare PLATFORMS=("linux_x86_32" "linux_x86_64" "MSWIN64" "MSWIN32" "darwinlegacy_x86_64" "darwin_universal")
declare METAPLATFORMS=("linux" "linux" "windows" "windows" "macos" "macos")
declare SFPLATFORMS=("Linux" "Linux" "Windows" "Windows" "MacOS" "MacOS")
declare EXTS=("tar.gz" "tar.gz" "zip" "zip" "tar.gz" "tar.gz")

if [ -z "$VER" ]; then
  echo "Must provide a version e.g. 're-package.sh 2.19'"
  exit 1
fi

function create-readme {
  cat <<EOF>$2
These are biber binaries for the $1 platform(s), released under:
Perl Artistic License, version 2

See https://ctan.org/pkg/biber for documentation, sources, and all else.
EOF
}

# Binaries
for i in "${!PLATFORMS[@]}"; do
    PLATFORM=${PLATFORMS[i]}
    METAPLATFORM=${METAPLATFORMS[i]}
    # CTAN requires top-level dir in lowercase
    SFPLATFORM=${SFPLATFORMS[i]}
    EXT=${EXTS[i]}
    if [ ! -e biber$PACKAGEEXT-$METAPLATFORM/biber$PACKAGEEXT-$VER-$PLATFORM.$EXT ]; then
      echo -n "Retrieving $PLATFORM ... "
      mkdir biber$PACKAGEEXT-$METAPLATFORM 2>/dev/null
      /opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/$RELEASE/binaries/$SFPLATFORM/biber$PACKAGEEXT-$PLATFORM.$EXT -O biber$PACKAGEEXT-$METAPLATFORM/biber$PACKAGEEXT-$VER-$PLATFORM.$EXT >/dev/null 2>&1
      [ $? -eq 0 ] || exit 1
      create-readme $METAPLATFORM biber$PACKAGEEXT-$METAPLATFORM/README
      echo "done"
    fi
done

SMETAPLATFORMS=($(printf "%s\n" "${METAPLATFORMS[@]}" | sort -u))
for i in "${!SMETAPLATFORMS[@]}"; do
  SMETAPLATFORM=${SMETAPLATFORMS[i]}
  echo -n "Packaging $SMETAPLATFORM ... "
  tar zcf biber$PACKAGEEXT-$SMETAPLATFORM.tgz biber$PACKAGEEXT-$SMETAPLATFORM
  \rm -rf biber$PACKAGEEXT-$SMETAPLATFORM
  echo "done"
done

# base
if [ ! -e biber$PACKAGEEXT-base.tgz ]; then
  echo -n "Packaging base ... "
  mkdir biber$PACKAGEEXT 2>/dev/null
  cd biber$PACKAGEEXT
  mkdir source
  mkdir documentation
  /opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/$RELEASE/biblatex-biber.tar.gz -O source/biblatex-biber$PACKAGEEXT.tar.gz >/dev/null 2>&1
  [ $? -eq 0 ] || exit 1
  /opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/$RELEASE/documentation/biber.pdf -O documentation/biber$PACKAGEEXT.pdf >/dev/null 2>&1
  [ $? -eq 0 ] || exit 1
  /opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/$RELEASE/Changes -O documentation/Changes >/dev/null 2>&1
  [ $? -eq 0 ] || exit 1
  /opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/$RELEASE/documentation/utf8-macro-map.html -O documentation/utf8-macro-map.html >/dev/null 2>&1
  [ $? -eq 0 ] || exit 1
  /opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/README.md -O README.md >/dev/null 2>&1
  cd ..
  tar zcf biber$PACKAGEEXT-base.tgz biber$PACKAGEEXT
  \rm -rf biber$PACKAGEEXT
  echo "done"
fi
