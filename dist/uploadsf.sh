#!/bin/bash
IFS=$'\n'

echo "$*" | xargs -I {} scp {} philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/development/binaries/
