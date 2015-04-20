#!/bin/bash

# The cp/rm steps are so that the packed biber main script is not
# called "biber" as on case-insensitive file systems, this clashes with
# the Biber lib directory and generates a (harmless) warning on first run
# Also, pp resolves symlinks and copies the symlink targets of linked libs
# which then don't have the right names and so things that link to them
# through the link name break. So, we copy them to the link names first and
# and package those. This is because OSX is not ELF object format, unlike Linux
# and so PAR::Packer doesn't understand how to follow the links.

# Don't try to build 32-bit 10.5 binaries on >10.5 by manipulating macports
# flags and SDKs. It doesn't work. You need a real 10.5 box/VM.
#
# Have to explicitly include the Input* modules as the names of these are dynamically
# constructed in the code so Par::Packer can't auto-detect them.
# Same with some of the output modules.

cp /opt/local/libexec/perl5.20/sitebin/biber /tmp/biber-darwin
cp /opt/local/lib/libz.1.2.7.dylib /tmp/libz.1.dylib

PAR_VERBATIM=1 pp --compress=6 \
  --module=deprecate \
  --module=Biber::Input::file::bibtex \
  --module=Biber::Input::file::biblatexml \
  --module=Biber::Input::file::ris \
  --module=Biber::Input::file::zoterordfxml \
  --module=Biber::Input::file::endnotexml \
  --module=Biber::Output::dot \
  --module=Biber::Output::bbl \
  --module=Biber::Output::bibtex \
  --module=Biber::Output::biblatexml \
  --module=Pod::Simple::TranscodeSmart \
  --module=Pod::Simple::TranscodeDumb \
  --module=List::MoreUtils::XS \
  --module=List::MoreUtils::PP \
  --module=Encode::Byte \
  --module=Encode::CN \
  --module=HTTP::Status \
  --module=HTTP::Date \
  --module=Encode::Locale \
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
  --module=Encode::EUCJPASCII \
  --module=Encode::JIS2K \
  --module=Encode::HanExtra \
  --module=IO::Socket::SSL \
  --module=File::Find::Rule \
  --link=/tmp/libz.1.dylib \
  --link=/opt/local/lib/libiconv.2.dylib \
  --link=/opt/local/libexec/perl5.20/sitebin/libbtparse.dylib \
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
\rm -f /tmp/libz.1.dylib
