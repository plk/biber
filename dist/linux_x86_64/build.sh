#!/bin/bash

# For some reason, PAR::Packer on linux is clever and when processing link lines
# resolves any symlinks but names the packed lib the same as the link name. This is
# a good thing.

# Had to add /etc/ld.so.conf.d/biber.conf and put "/usr/local/perl/lib64" in there
# and then run "sudo ldconfig" so that libbtparse.so is found. Doesn't really make
# a difference to the build, just the running of Text::BibTeX itself.

# Have to explicitly include the Input* modules as the names of these are dynamically
# constructed in the code so Par::Packer can't auto-detect them
# Added libz as some linux distros like SUSE 11.3 have a slightly older zlib
# which doesn't have gzopen64 in it.

# Also, pp resolves symlinks and copies the symlink targets of linked libs
# which then don't have the right names and so things that link to them
# through the link name break. So, we copy them to the link names first and
# and package those.

cp /lib/libz.so.1.2.3.3 /tmp/libz.so.1
cp /usr/lib/libxml2.so.2.6.32 /tmp/libxml2.so.2
cp /usr/lib/libxslt.so.1.1.24 /tmp/libxslt.so.1
cp /usr/lib/libexslt.so.0.8.13 /tmp/libexslt.so.0

/usr/local/perl/bin/pp \
  --compress=6 \
  --module=deprecate \
  --module=Biber::Input::file::bibtex \
  --module=Biber::Input::file::biblatexml \
  --module=Biber::Input::file::ris \
  --module=Biber::Input::file::zoterordfxml \
  --module=Biber::Input::file::endnotexml \
  --module=Pod::Simple::TranscodeSmart \
  --module=Pod::Simple::TranscodeDumb \
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
  --module=Readonly::XS \
  --module=IO::Socket::SSL \
  --link=/usr/local/perl/lib64/libbtparse.so \
  --link=/tmp/libxml2.so.2 \
  --link=/tmp/libxslt.so.1 \
  --link=/tmp/libexslt.so.0 \
  --link=/tmp/libz.so.1 \
  --link=/lib/libcrypto.so.0.9.8 \
  --link=/lib/libssl.so.0.9.8 \
  --addlist=biber.files \
  --cachedeps=scancache \
  --output=biber-linux_x86_64 \
  /usr/local/perl/bin/biber

\rm -f /tmp/libz.so.1
\rm -f /tmp/libxml2.so.2
\rm -rf /tmp/libxslt.so.1
\rm -rf /tmp/libexslt.so.0
