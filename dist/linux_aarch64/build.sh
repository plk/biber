#!/bin/bash

# Main comments see: dist/linux_x86_64.
#
# We directly use Unicode::Collate from site_perl (must be updated by cpan Unicode::Collate!).

# -r: Readonly.
declare -r PERL_VERSION='5.36.0'

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
  --link=/lib/aarch64-linux-gnu/libz.so.1 \
  --link=/lib/aarch64-linux-gnu/libgpg-error.so.0 \
  --link=/lib/aarch64-linux-gnu/libcrypt.so.1 \
  --link=/lib/aarch64-linux-gnu/libgcrypt.so.20 \
  --link=/usr/local/lib/libbtparse.so \
  --link=/usr/lib/aarch64-linux-gnu/libxslt.so \
  --link=/usr/lib/aarch64-linux-gnu/libexslt.so \
  --link=/usr/lib/aarch64-linux-gnu/libxml2.so \
  --link=/usr/lib/aarch64-linux-gnu/libicui18n.so.63 \
  --link=/usr/lib/aarch64-linux-gnu/libicuuc.so \
  --link=/usr/lib/aarch64-linux-gnu/libicudata.so \
  --link=/usr/lib/aarch64-linux-gnu/liblzma.so \
  --link=/usr/lib/aarch64-linux-gnu/libssl.so \
  --addfile="../../data/biber-tool.conf;lib/Biber/biber-tool.conf" \
  --addfile="../../data/schemata/config.rnc;lib/Biber/config.rnc" \
  --addfile="../../data/schemata/config.rng;lib/Biber/config.rng"\
  --addfile="../../data/schemata/bcf.rnc;lib/Biber/bcf.rnc" \
  --addfile="../../data/schemata/bcf.rng;lib/Biber/bcf.rng" \
  --addfile="../../lib/Biber/LaTeX/recode_data.xml;lib/Biber/LaTeX/recode_data.xml" \
  --addfile="../../data/bcf.xsl;lib/Biber/bcf.xsl" \
  --addfile="/usr/local/lib/perl5/site_perl/${PERL_VERSION}/Business/ISBN/RangeMessage.xml" \
  --addfile="/usr/local/lib/perl5/site_perl/${PERL_VERSION}/Mozilla/CA/cacert.pem" \
  --addfile="/usr/local/lib/perl5/site_perl/${PERL_VERSION}/aarch64-linux-gnu/PerlIO" \
  --addfile="/usr/local/lib/perl5/site_perl/${PERL_VERSION}/aarch64-linux-gnu/Unicode/Collate/Locale;lib/Unicode/Collate/Locale" \
  --addfile="/usr/local/lib/perl5/site_perl/${PERL_VERSION}/aarch64-linux-gnu/Unicode/Collate/CJK;lib/Unicode/Collate/CJK" \
  --addfile="/usr/local/lib/perl5/site_perl/${PERL_VERSION}/aarch64-linux-gnu/Unicode/Collate/allkeys.txt;lib/Unicode/Collate/allkeys.txt" \
  --addfile="/usr/local/lib/perl5/site_perl/${PERL_VERSION}/aarch64-linux-gnu/Unicode/Collate/keys.txt;lib/Unicode/Collate/keys.txt" \
  --cachedeps=scancache \
  --output=biber-linux_arm64 \
  /usr/local/bin/biber
