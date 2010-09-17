#!/usr/bin/bash
# This runs under cygwin as .bat scripts are awful

cp /cygdrive/c/strawberry/perl/site/bin/biber /tmp/biber-MSWIN

pp \
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
  --link=/cygdrive/c/WINDOWS/libbtparse.dll \
  --link=/cygdrive/c/strawberry/c/bin/libz_.dll \
  --link=/cygdrive/c/strawberry/c/bin/libxml2-2_.dll \
  --link=/cygdrive/c/strawberry/c/bin/libiconv-2_.dll \
  --addlist=biber.files \
  --cachedeps=scancache \
  --info=ProductName=biber \
  --icon=biber.ico \
  --output=biber-MSWIN.exe \
  /tmp/biber-MSWIN

rm /tmp/biber-MSWIN
