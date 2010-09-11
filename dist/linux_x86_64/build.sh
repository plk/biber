#!/bin/bash

pp --compress=6 --link=/usr/local/lib/libbtparse.so --link=/usr/lib/libxml2.so.2 --addlist=biber.files --cachedeps=scancache --output=biber /usr/local/bin/biber
