#!/bin/bash

# To ensure more consistent stand-aloneness across OS revisions,
# we are packing the dependant OS libs too.
# Use otool -L to determine these, running it on the biber executable
# and also on all added libs. Some are symlinks in which case we
# have to copy them to the otool name and then link them in since
# the pp '--link' option resolved links to the target names.

# These dependencies are sym-linked to specific versions
cp /usr/lib/libutil1.0.dylib ./libutil.dylib
cp /usr/lib/libstdc++.6.0.9.dylib ./libstdc++.6.dylib

pp --compress=6 --link=/usr/lib/system/libmathCommon.A.dylib --link=./libstdc++.6.dylib --link=./libutil.dylib --link=/usr/lib/libSystem.B.dylib --link=/opt/local/lib/libz.1.dylib --link=/opt/local/lib/libiconv.2.dylib --link=/opt/local/lib/libbtparse.dylib --link=/opt/local/lib/libxml2.2.dylib --addlist=biber.files --cachedeps=scancache --output=biber /opt/local/bin/biber

\rm ./libutil.dylib
\rm ./libstdc++.6.dylib
