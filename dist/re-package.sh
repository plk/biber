#!/bin/bash

# Collect all binaries and re-package for CTAN
# re-package.sh <biber version>

declare -r ROOT='/tmp/biber-repack'

mkdir -p ${ROOT}
cd ${ROOT}
declare VER=$1
declare RELEASE="current"
declare PLATFORMS=("linux_x86_64" "MSWIN64" "MSWIN32" "darwinlegacy_x86_64" "darwin_universal")
declare SFPLATFORMS=("Linux" "Windows" "Windows" "MacOS" "MacOS")
declare EXTS=("tar.gz" "zip" "zip" "tar.gz" "tar.gz")

function create-readme {
  cat <<EOF>$2
These are biber binaries for the $1 platform(s).
See https://ctan.org/pkg/biber for documentation, sources, and all else.
EOF
}

# Binaries
for i in "${!PLATFORMS[@]}"; do
    PLATFORM=${PLATFORMS[i]}
    # CTAN requires top-level dir in lowercase
    LCPLATFORM=$(echo "$PLATFORM" | tr '[:upper:]' '[:lower:]')
    SFPLATFORM=${SFPLATFORMS[i]}
    EXT=${EXTS[i]}
    if [ ! -e biber-$PLATFORM.tgz ]; then
      echo -n "Packaging $PLATFORM ... "
      mkdir biber-$LCPLATFORM 2>/dev/null
      /opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/$RELEASE/binaries/$SFPLATFORM/biber-$PLATFORM.$EXT -O biber-$LCPLATFORM/biber-$VER-$PLATFORM.$EXT >/dev/null 2>&1
      [ $? -eq 0 ] || exit 1
      create-readme $PLATFORM biber-$LCPLATFORM/README
      tar zcf biber-$PLATFORM.tgz biber-$LCPLATFORM
      \rm -rf biber-$LCPLATFORM
      echo "done"
  fi
done

# base
if [ ! -e biber-base.tgz ]; then
  echo -n "Packaging base ... "
  mkdir biber 2>/dev/null
  cd biber
  mkdir source
  mkdir documentation
  /opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/$RELEASE/biblatex-biber.tar.gz -O source/biblatex-biber.tar.gz >/dev/null 2>&1
  [ $? -eq 0 ] || exit 1
  /opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/$RELEASE/documentation/biber.pdf -O documentation/biber.pdf >/dev/null 2>&1
  [ $? -eq 0 ] || exit 1
  /opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/$RELEASE/Changes -O documentation/Changes >/dev/null 2>&1
  [ $? -eq 0 ] || exit 1
  /opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/$RELEASE/documentation/utf8-macro-map.html -O documentation/utf8-macro-map.html >/dev/null 2>&1
  [ $? -eq 0 ] || exit 1
  /opt/local/bin/wget --content-disposition --level=0 -c https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/README.md -O README.md >/dev/null 2>&1
  cd ..
  tar zcf biber-base.tgz biber
  \rm -rf biber
  echo "done"
fi
