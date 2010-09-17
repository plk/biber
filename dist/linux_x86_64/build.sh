#!/bin/bash

/usr/local/perl/bin/pp
  --compress=6 \
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
  --link=/usr/local/perl/lib/libbtparse.so \
  --link=/usr/lib/libxml2.so.2 \
  --addlist=biber.files \
  --cachedeps=scancache \
  --output=biber-linux_x86_64 \
  /usr/local/perl/bin/biber
