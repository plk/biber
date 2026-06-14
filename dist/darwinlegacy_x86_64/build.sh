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

declare -r perlv='5.32'
declare ucpath="/opt/local/lib/perl5/${perlv}/Unicode/Collate"

# Unicode::Collate has a site_perl version so has been updated since this
# perl was released
if [ -d "/opt/local/lib/perl5/site_perl/${perlv}/darwin-thread-multi-2level/Unicode/Collate" ]
then
  ucpath="/opt/local/lib/perl5/site_perl/${perlv}/darwin-thread-multi-2level/Unicode/Collate"
fi

echo "USING Unicode::Collate at: ${ucpath}"

cp /opt/local/libexec/perl${perlv}/sitebin/biber /tmp/biber-darwin

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
  --link=/opt/local/lib/libz.1.dylib \
  --link=/opt/local/lib/libiconv.2.dylib \
  --link=/opt/local/libexec/perl${perlv}/sitebin/libbtparse.dylib \
  --link=/opt/local/lib/libxml2.2.dylib \
  --link=/opt/local/lib/libxslt.1.dylib \
  --link=/opt/local/lib/libgdbm.6.dylib \
  --link=/opt/local/lib/libexslt.0.dylib \
  --link=/opt/local/libexec/openssl3/lib/libssl.3.dylib \
  --link=/opt/local/libexec/openssl3/lib/libcrypto.3.dylib \
  --link=/opt/local/lib/liblzma.5.dylib \
  --link=/opt/local/lib/libintl.8.dylib \
  --link=/opt/local/lib/libicui18n.67.dylib \
  --link=/opt/local/lib/libicuuc.67.dylib \
  --link=/opt/local/lib/libicudata.67.dylib \
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
  --addfile="/opt/local/lib/perl5/site_perl/${perlv}/Mozilla/CA/cacert.pem;lib/Mozilla/CA/cacert.pem" \
  --addfile="/opt/local/lib/perl5/site_perl/${perlv}/Business/ISBN/RangeMessage.xml;lib/Business/ISBN/RangeMessage.xml" \
  --addfile="/opt/local/lib/perl5/site_perl/${perlv}/darwin-thread-multi-2level/auto/Unicode/LineBreak/LineBreak.bundle;lib/auto/Unicode/LineBreak/LineBreak.bundle" \
  --cachedeps=scancache \
  --output=biber-darwinlegacy_x86_64 \
  /tmp/biber-darwin

\rm -f /tmp/biber-darwin

