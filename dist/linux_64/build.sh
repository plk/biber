#!/bin/bash

pp --compress=0 --link=/usr/local/lib/libxml2.so.2 --addlist=biber.files --cachedeps=scancache --output=biber /usr/local/bin/biber
