#!/bin/bash

pp --compress=6 --link=/lib/libdl.so.2 --link=/lib/libc.so.6 --link=/lib64/ld-linux-x86-64.so.2 --link=/lib/libm.so.6 --link=/lib/libpthread.so.0 --link=/lib/libcrypt.so.1  --link=/usr/local/perl/lib/libbtparse.so --link=/usr/lib/libxml2.so.2 --addlist=biber.files --cachedeps=scancache --output=biber-linux_x86_64 /usr/local/bin/biber
