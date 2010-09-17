#!/bin/bash

pp --compress=6 \
  --module=Encode::Byte \
  --module=Encode::CN \
  --module=Encode::CJKConstants \
  --module=Encode::EBCDIC \
  --module=Encode::Encoder \
  --module=Encode::GSM0338 \
  --module=Encode::Guess \
  --module=Encode::JP \
  --module=Encode::KR \
  --module=Encode::MIME::Header \
  --module=Encode::Symbol \
  --module=Encode::TW \
  --module=Encode::Unicode \
  --module=Encode::Unicode::UTF7 \
  --link=/opt/local/lib/libz.1.dylib \
  --link=/opt/local/lib/libiconv.2.dylib \
  --link=/opt/local/lib/libbtparse.dylib \
  --link=/opt/local/lib/libxml2.2.dylib \
  --addlist=biber.files \
  --cachedeps=scancache \
  --output=biber-darwin_x86_64 \
  /opt/local/bin/biber

