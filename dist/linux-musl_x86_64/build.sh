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

# Had to add /etc/ld.so.conf.d/biber.conf and put "/usr/local/perl/lib64" in there
# and then run "sudo ldconfig" so that libbtparse.so is found. Doesn't really make
# a difference to the build, just the running of Text::BibTeX itself.

# Using a newer locally built libz and libxml2 (and rebuilt XML::LibXML) in /usr/local because
# beginning with 32-bit Debian Wheezy, the older ones would segfault

# Have to explicitly include the Input* modules as the names of these are dynamically
# constructed in the code so Par::Packer can't auto-detect them
# Same with some of the output modules.

# Added libz as some linux distros like SUSE 11.3 have a slightly older zlib
# which doesn't have gzopen64 in it.

# Unicode::Collate is bundled with perl but is often updated and this is a critical module
# for biber. There are some parts of this module which must be explicitly bundled by pp.
# Unfortunately, updates to the module go into site_perl and we must bundle the right version
# and so we check if there are any newer versions than came with the version of perl we are using
# by looking to see if there is a site_perl directory for the module. If there is, we use that
# version.

declare -r perlv='5.36.0'
declare ucpath="/usr/share/perl5/core_perl/Unicode/Collate"

# Unicode::Collate has a site_perl version so has been updated since this
# perl was released
if [ -d "/usr/local/perl/lib/site_perl/${perlv}/x86_64-linux-thread-multi/Unicode/Collate" ]
then
  ucpath="/usr/local/perl/lib/site_perl/${perlv}/x86_64-linux-thread-multi/Unicode/Collate"
fi

echo "USING Unicode::Collate at: ${ucpath}"

PAR_VERBATIM=1 /usr/local/bin/pp \
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
  --link=/usr/local/lib/libbtparse.so \
  --link=/usr/lib/libxml2.so \
  --link=/lib/libz.so \
  --link=/usr/lib/liblzma.so \
  --link=/usr/lib/libxslt.so \
  --link=/usr/lib/libexslt.so \
  --link=/usr/lib/libssl.so \
  --link=/usr/lib/libcrypto.so \
  --link=/usr/lib/libgcrypt.so \
  --link=/usr/lib/libgpg-error.so \
  --addfile="../../data/biber-tool.conf;lib/Biber/biber-tool.conf" \
  --addfile="../../data/schemata/config.rnc;lib/Biber/config.rnc" \
  --addfile="../../data/schemata/config.rng;lib/Biber/config.rng"\
  --addfile="../../data/schemata/bcf.rnc;lib/Biber/bcf.rnc" \
  --addfile="../../data/schemata/bcf.rng;lib/Biber/bcf.rng" \
  --addfile="../../lib/Biber/LaTeX/recode_data.xml;lib/Biber/LaTeX/recode_data.xml" \
  --addfile="../../data/bcf.xsl;lib/Biber/bcf.xsl" \
  --addfile="${ucpath}/Locale;lib/Unicode/Collate/Locale" \
  --addfile="${ucpath}/CJK;lib/Unicode/Collate/CJK" \
  --addfile="${ucpath}/allkeys.txt;lib/Unicode/Collate/allkeys.txt" \
  --addfile="${ucpath}/keys.txt;lib/Unicode/Collate/keys.txt" \
  --addfile="/usr/local/share/perl5/site_perl/Mozilla/CA/cacert.pem" \
  --addfile="/usr/local/lib/perl5/site_perl/PerlIO" \
  --addfile="/usr/local/share/perl5/site_perl/Business/ISBN/RangeMessage.xml" \
  --cachedeps=scancache \
  --output=/opt/biber \
  /usr/local/bin/biber
