#!/bin/bash

pp --compress=6 --link=/lib/tls/i686/cmov/libcrypt.so.1 --link=/lib/tls/i686/cmov/libpthread.so.0 --link=/lib/ld-linux.so.2 --link=/lib/tls/i686/cmov/libm.so.6  --link=/lib/tls/i686/cmov/libc.so.6 --link=/lib/tls/i686/cmov/libdl.so.2 --link=/usr/local/lib/libbtparse.so --link=/usr/lib/libxml2.so.2 --addlist=biber.files --cachedeps=scancache --output=biber-linux_x86_32 /usr/local/bin/biber
