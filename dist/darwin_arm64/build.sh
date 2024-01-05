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

declare -r perlv='5.38.0'
declare ucpath="/opt/homebrew/Cellar/perl/${perlv}/lib/perl5/${perlv%.0}/Unicode/Collate"

# Unicode::Collate has a site_perl version so has been updated since this
# perl was released

if [ -d "/opt/homebrew/Cellar/perl/${perlv}/lib/perl5/site_perl/${perlv%.0}/Unicode/Collate" ]
then
  ucpath="/opt/homebrew/Cellar/perl/${perlv}/lib/perl5/site_perl/${perlv%.0}/Unicode/Collate"
fi

echo "USING Unicode::Collate at: ${ucpath}"

cp /opt/homebrew/Cellar/perl/${perlv}/bin/biber /tmp/biber-darwin

PAR_VERBATIM=1 pp \
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
  --link=/opt/homebrew/lib/libz3.dylib \
  --link=/opt/homebrew/Cellar/libiconv/1.17/lib/libiconv.2.dylib \
  --link=/opt/homebrew/Cellar/perl/${perlv}/lib/libbtparse.dylib \
  --link=/opt/homebrew/Cellar/libxml2/2.11.5_1/lib/libxml2.dylib \
  --link=/opt/homebrew/Cellar/libxslt/1.1.38_1/lib/libxslt.dylib \
  --link=/opt/homebrew/lib/libgdbm.6.dylib \
  --link=/opt/homebrew/Cellar/libxslt/1.1.38_1/lib/libexslt.dylib \
  --link=/opt/homebrew/lib/libssl.3.dylib \
  --link=/opt/homebrew/lib/libcrypto.3.dylib \
  --link=/opt/homebrew/lib/liblzma.5.dylib \
  --link=/opt/homebrew/lib/libintl.8.dylib \
  --link=/opt/homebrew/Cellar/icu4c/73.2/lib/libicui18n.73.dylib \
  --link=/opt/homebrew/Cellar/icu4c/73.2/lib/libicuuc.73.dylib \
  --link=/opt/homebrew/Cellar/icu4c/73.2/lib/libicudata.73.dylib \
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
--addfile="/opt/homebrew/Cellar/perl/${perlv}/lib/perl5/site_perl/${perlv%.0}/Mozilla/CA/cacert.pem;lib/Mozilla/CA/cacert.pem" \
  --addfile="/opt/homebrew/Cellar/perl/${perlv}/lib/perl5/site_perl/${perlv%.0}/Business/ISBN/RangeMessage.xml;lib/Business/ISBN/RangeMessage.xml" \
  --addfile="/opt/homebrew/Cellar/perl/${perlv}/lib/perl5/site_perl/${perlv%.0}/darwin-thread-multi-2level/auto/Unicode/LineBreak/LineBreak.bundle;lib/auto/Unicode/LineBreak/LineBreak.bundle" \
  --cachedeps=scancache \
  --output=biber-darwin_arm64 \
  /tmp/biber-darwin

\rm -f /tmp/biber-darwin

