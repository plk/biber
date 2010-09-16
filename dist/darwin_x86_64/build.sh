#!/bin/bash

pp --compress=6 --link=/opt/local/lib/libz.1.dylib --link=/opt/local/lib/libiconv.2.dylib --link=/opt/local/lib/libbtparse.dylib --link=/opt/local/lib/libxml2.2.dylib --addlist=biber.files --cachedeps=scancache --output=biber-darwin_x86_64 /opt/local/bin/biber

