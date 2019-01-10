#!/bin/bash

# Note that our perl location is in non-standard place

PAR_VERBATIM=1 /usr/local/perl-5.24.0/bin/pp \
  --unicode \
  --module=deprecate \
  --module=Biber::Input::file::bibtex \
  --module=Biber::Input::file::biblatexml \
  --module=Biber::Output::dot \
  --module=Biber::Output::bbl \
  --module=Biber::Output::bblxml \
  --module=Biber::Output::bibtex \
  --module=Biber::Output::biblatexml \
  --module=Pod::Simple::TranscodeSmart \
  --module=Pod::Simple::TranscodeDumb \
  --module=List::MoreUtils::XS \
  --module=List::SomeUtils::XS \
  --module=List::MoreUtils::PP \
  --module=HTTP::Status \
  --module=HTTP::Date \
  --module=Encode:: \
  --module=File::Find::Rule \
  --module=IO::Socket::SSL \
  --module=IO::String \
  --module=PerlIO::utf8_strict \
  --module=Text::CSV_XS \
  --module=DateTime \
  --link=/usr/local/perl-5.24.0/lib/libbtparse.so \
  --link=/usr/lib/arm-linux-gnueabi/libxml2.so.2 \
  --link=/lib/arm-linux-gnueabi/libz.so.1 \
  --link=/usr/lib/arm-linux-gnueabi/libxslt.so.1 \
  --link=/usr/lib/arm-linux-gnueabi/libexslt.so.0 \
  --link=/usr/lib/arm-linux-gnueabi/libssl.so.1.0.0 \
  --link=/usr/lib/arm-linux-gnueabi/libcrypto.so.1.0.0 \
  --addlist=biber.files \
  --cachedeps=scancache \
  --output=biber-linux_armel \
  /usr/local/perl-5.24.0/bin/biber
