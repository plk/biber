#!/bin/bash

# The cp/rm steps are so that the packed biber main script is not
# called "biber" as on case-insensitive file systems, this clashes with
# the Biber lib directory and generates a (harmless) warning on first run

# Don't try to build 32-bit 10.5 binaries on >10.5 by manipulating macports
# flags and SDKs. It doesn't work. You need a real 10.5 box/VM.
#
# Have to explicitly include the Input* modules as the names of these are dynamically
# constructed in the code so Par::Packer can't auto-detect them.
# Same with some of the output modules.

cp /opt/local/libexec/perl5.24/sitebin/biber /tmp/biber-darwin

PAR_VERBATIM=1 pp \
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
  --module=IO::Socket::SSL \
  --module=PerlIO::utf8_strict \
  --module=File::Find::Rule \
  --module=Text::CSV_XS \
  --module=DateTime \
  --link=/opt/local/lib/libz.1.dylib \
  --link=/opt/local/lib/libiconv.2.dylib \
  --link=/opt/local/libexec/perl5.24/sitebin/libbtparse.dylib \
  --link=/opt/local/lib/libxml2.2.dylib \
  --link=/opt/local/lib/libxslt.1.dylib \
  --link=/opt/local/lib/libssl.1.0.0.dylib \
  --link=/opt/local/lib/libcrypto.1.0.0.dylib \
  --link=/opt/local/lib/libgdbm.4.dylib \
  --link=/opt/local/lib/libexslt.0.dylib \
  --link=/opt/local/lib/liblzma.5.dylib \
  --link=/opt/local/lib/libintl.8.dylib \
  --addlist=biber.files \
  --cachedeps=scancache \
  --output=biber-darwin_x86_i386 \
  /tmp/biber-darwin

\rm -f /tmp/biber-darwin
