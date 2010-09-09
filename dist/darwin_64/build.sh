#!/bin/bash

pp --compress=0 --link=/opt/local/lib/libbtparse.dylib --link=/opt/local/lib/libxml2.2.dylib --addlist=biber.files --cachedeps=scancache --output=biber /opt/local/bin/biber
