#!/bin/sh

bib=`mktemp` || exit 1
xclip -o > $bib || exit 1
bib2biblatexml $bib || exit 1
if [ -f $bib.xml ]; then
  xclip -i $bib.xml
else
  xclip -i $bib
fi

