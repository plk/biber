#!/bin/bash

# For some reason, PAR::Packer on linux is clever and when processing link lines
# resolves any symlinks but names the packed lib the same as the link name. This is
# a good thing. This is a feature of PAR::Packer on ELF systems.

# Have to be very careful about Perl modules with .so binary libraries as sometimes
# (LibXML.so for example), they include RPATH which means that the PAR cache
# is not searched first, even though it's at the top of LD_LIBRARY_PATH. So, the wrong
# libraries will be found and things may well break. Strip any RPATH out of such libs
# with "chrpath -d <lib>". Check for presence with "readelf -d <lib>".
# 
# Check all perl binaries with:
# for file in `find /usr/local/perl/lib* -name \*.so`; do echo $file >> /tmp/out ;readelf -d $file >> /tmp/out; done
# and then grep the file for "RPATH"

# Had to add /etc/ld.so.conf.d/biber.conf and put "/usr/local/perl/lib" in there
# and then run "sudo ldconfig" so that libbtparse.so is found. Doesn't really make
# a difference to the build, just the running of Text::BibTeX itself.

# Using an newer locally build libxml2 (and rebuilt XL::LibXML) in /usr/local because
# beginning with 32-bit Debian Wheezy, the older ones would segfault

# Have to explicitly include the Input* modules as the names of these are dynamically
# constructed in the code so Par::Packer can't auto-detect them.

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
  --module=File::Find::Rule \
  --module=Readonly::XS \
  --module=IO::Socket::SSL \
  --link=/usr/local/perl/lib/libbtparse.so \
  --link=/usr/local/lib/libxml2.so.2 \
  --link=/usr/lib/libxslt.so.1 \
  --link=/usr/lib/libexslt.so.0 \
  --link=/lib/libssl.so.0.9.8 \
  --link=/lib/libcrypto.so.0.9.8 \
  --addlist=biber.files \
  --cachedeps=scancache \
  --output=biber-linux_x86_32 \
  /usr/local/perl/bin/biber
