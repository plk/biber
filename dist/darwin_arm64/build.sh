#!/bin/bash

# The cp/rm steps are so that the packed biber main script is not
# called "biber" as on case-insensitive file systems, this clashes with
# the Biber lib directory and generates a (harmless) warning on first run

# Have to explicitly include the Input* modules as the names of these are dynamically
# constructed in the code so Par::Packer can't auto-detect them.
# Same with some of the output modules.

# Unicode::Collate is bundled with perl but is often updated and this is a critical module
# for biber. There are some parts of this module which must be explicitly bundled by pp.
# Unfortunately, updates to the module go into site_perl and we must bundle the right version
# and so we check if there are any newer versions than came with the version of perl we are using
# by looking to see if there is a site_perl directory for the module. If there is, we use that
# version.

# Have to be very careful about Perl modules with .bundle binary libraries as sometimes
# (LibXML.bundle for example), they include RPATH which means that the PAR cache
# is not searched first, even though it's at the top of LD_LIBRARY_PATH. So, the wrong
# libraries will be found and things may well break. Strip any RPATH out of such libs
# with "install_name_tool -delete_rpath <rpath> <lib.bundle>". Check for presence with "otool -l
# <lib> | fgrep RPATH".
#
# Check all perl binaries with:
# \rm -rf /tmp/out; for file in `find /opt/homebrew/Cellar/perl -name \*.bundle`; do echo $file >> /tmp/out; otool -l $file | fgrep -i rpath >> /tmp/out; done
# and then grep /tmp/out for "RPATH"

# With homebrew, perl libs, when built, will often use system libraries because many things are not
# in /opt/homebrew/lib to find. However, you can't find the libs it linked to as
# they are now hidden, see https://developer.apple.com/documentation/macos-release-notes/macos-big-sur-11_0_1-release-notes#Kernel
# So, extract all the libs to a temp location from the cache first so they can be linked and packed.
# This requires dyld-shared-cache-extractor to be installed (https://github.com/keith/dyld-shared-cache-extractor)
if [ ! -e "/tmp/libraries" ]
then
  dyld-shared-cache-extractor /System/Volumes/Preboot/Cryptexes/OS/System/Library/dyld/dyld_shared_cache_arm64e /tmp/libraries
fi

declare -r perlv='5.38.2_1'
declare -r perlvc=$(echo "$perlv" | perl -pe 's/^(.+)\.\d+(?:_\d+)?$/$1/')
declare ucpath="/opt/homebrew/Cellar/perl/${perlv}/lib/perl5/${perlvc}/Unicode/Collate"

# Unicode::Collate has a site_perl version so has been updated since this
# perl was released

if [ -d "/opt/homebrew/Cellar/perl/${perlv}/lib/perl5/site_perl/${perlvc}/Unicode/Collate" ]
then
  ucpath="/opt/homebrew/Cellar/perl/${perlv}/lib/perl5/site_perl/${perlvc}/Unicode/Collate"
fi

echo "USING Unicode::Collate at: ${ucpath}"

cp /opt/homebrew/Cellar/perl/${perlv}/bin/biber /tmp/biber-darwin

PAR_VERBATIM=1 /opt/homebrew/Cellar/perl/${perlv}/bin/pp \
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
  --link=/opt/homebrew/lib/libgdbm.dylib \
  --link=/opt/homebrew/lib/libintl.8.dylib \
  --link=/tmp/libraries/usr/lib/libz.1.dylib \
  --link=/tmp/libraries/usr/lib/libiconv.2.dylib \
  --link=/tmp/libraries/usr/lib/libssl.dylib \
  --link=/tmp/libraries/usr/lib/libxml2.2.dylib \
  --link=/tmp/libraries/usr/lib/libxslt.1.dylib \
  --link=/tmp/libraries/usr/lib/libcrypto.dylib \
  --link=/tmp/libraries/usr/lib/liblzma.5.dylib \
  --link=/opt/homebrew/Cellar/perl/${perlv}/lib/libbtparse.dylib \
  --link=/opt/homebrew/Cellar/icu4c@77/77.1/lib/libicui18n.77.dylib \
  --link=/opt/homebrew/Cellar/icu4c@77/77.1/lib/libicuuc.77.dylib \
  --link=/opt/homebrew/Cellar/icu4c@77/77.1/lib/libicudata.77.dylib \
  --addfile="../../data/biber-tool.conf;lib/Biber/biber-tool.conf" \
  --addfile="../../data/schemata/config.rnc;lib/Biber/config.rnc" \
  --addfile="../../data/schemata/config.rng;lib/Biber/config.rng" \
  --addfile="../../data/schemata/bcf.rnc;lib/Biber/bcf.rnc" \
  --addfile="../../data/schemata/bcf.rng;lib/Biber/bcf.rng" \
  --addfile="../../lib/Biber/LaTeX/recode_data.xml;lib/Biber/LaTeX/recode_data.xml" \
  --addfile="../../data/bcf.xsl;lib/Biber/bcf.xsl" \
  --addfile="${ucpath}/Locale;lib/Unicode/Collate/Locale" \
  --addfile="${ucpath}/CJK;lib/Unicode/Collate/CJK;lib/Unicode/Collate/CJK" \
  --addfile="${ucpath}/allkeys.txt;lib/Unicode/Collate/allkeys.txt" \
  --addfile="${ucpath}/keys.txt;lib/Unicode/Collate/keys.txt" \
--addfile="/opt/homebrew/Cellar/perl/${perlv}/lib/perl5/site_perl/${perlvc}/Mozilla/CA/cacert.pem;lib/Mozilla/CA/cacert.pem" \
  --addfile="/opt/homebrew/Cellar/perl/${perlv}/lib/perl5/site_perl/${perlvc}/Business/ISBN/RangeMessage.xml;lib/Business/ISBN/RangeMessage.xml" \
  --addfile="/opt/homebrew/Cellar/perl/${perlv}/lib/perl5/site_perl/${perlvc}/darwin-thread-multi-2level/auto/Unicode/LineBreak/LineBreak.bundle;lib/auto/Unicode/LineBreak/LineBreak.bundle" \
  --cachedeps=scancache \
  --output=biber-darwin_arm64 \
  /tmp/biber-darwin

\rm -f /tmp/biber-darwin

if [ -e "/tmp/libraries" ]
then
  \rm -rf /tmp/libraries
fi
