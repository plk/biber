#!/bin/sh

# For some reason, PAR::Packer on linux is clever and when processing link lines
# resolves any symlinks but names the packed lib the same as the link name. This is
# a good thing.

# Have to explicitly include the Input* modules as the names of these are dynamically
# constructed in the code so Par::Packer can't auto-detect them

# -----------------------------------------------------------------------------

PAR_VERBATIM=1
export PAR_VERBATIM

/usr/local/bin/pp -vv \
  --unicode \
  --module=deprecate \
  --module=App::Packer::PAR \
  --module=Biber::Input::file::bibtex \
  --module=Biber::Input::file::biblatexml \
  --module=Biber::Output::dot \
  --module=Biber::Output::bbl \
  --module=Biber::Output::bblxml \
  --module=Biber::Output::bibtex \
  --module=Biber::Output::biblatexml \
  --module=HTTP::Status \
  --module=HTTP::Date \
  --module=Encode:: \
  --module=Pod::Simple::TranscodeSmart \
  --module=Pod::Simple::TranscodeDumb \
  --module=Pod::Perldoc \
  --module=List::MoreUtils::XS \
  --module=List::SomeUtils::XS \
  --module=List::MoreUtils::PP \
  --module=Readonly::XS \
  --module=IO::Socket::SSL \
  --module=IO::String \
  --module=PerlIO::utf8_strict \
  --module=File::Find::Rule \
  --module=Text::CSV_XS \
  --module=DateTime \
  --link=/usr/local/lib/libbtparse.so \
  --link=/usr/local/lib/libiconv.so.3 \
  --link=/usr/local/lib/libxml2.so.5 \
  --link=/usr/local/lib/libxslt.so.2 \
  --link=/usr/local/lib/libexslt.so.8 \
  --link=/usr/local/lib/libgdbm.so.4 \
  --link=`ls /lib/libz.so.*` \
  --link=`ls /lib/libcrypt.so.*` \
  --link=`ls /lib/libutil.so.*` \
  --link=`ls /lib/libcrypto.so.*` \
  --link=`ls /usr/lib/libssl.so.*` \
  --addlist=biber.files \
  --cachedeps=scancache \
  --output=biber-2.8.`uname -m`-freebsd`uname -r | sed 's/\..*//' | sed 's/8/8,9,10,11,12/'` \
  /usr/local/bin/biber
