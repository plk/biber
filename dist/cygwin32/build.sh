#!/bin/bash

# The cp/rm steps are so that the packed biber main script is not
# called "biber" as on case-insensitive file systems, this clashes with
# the Biber lib directory and generates a (harmless) warning on first run
# Also, pp resolves symlinks and copies the symlink targets of linked libs
# which then don't have the right names and so things that link to them
# through the link name break. So, we copy them to the link names first and
# and package those.

# There’s no need to link cygssp-0.dll, because it’s present in a
# minimal Cygwin installation.  And we shouldn’t link cygcrypt-0.dll,
# because it is a dependency of the cygperl DLL and needs to be
# treated as an embedded file by PAR::Packer.  See
# https://rt.cpan.org/Public/Bug/Display.html?id=118053.

# Have to explicitly include the Input* modules as the names of these are dynamically
# constructed in the code so Par::Packer can't auto-detect them.
# Same with some of the output modules.

cp /usr/local/bin/biber /tmp/biber-cygwin

declare -r perlv='5.32'
declare ucpath="/usr/share/perl5/${perlv}/Unicode/Collate"

# Unicode::Collate has a vendor_perl version so has been updated since this
# perl was released
if [ -d "/usr/lib/perl5/vendor_perl/${perlv}/i686-cygwin-threads-64int/Unicode/Collate" ]
then
  ucpath="/usr/lib/perl5/vendor_perl/${perlv}/i686-cygwin-threads-64int/Unicode/Collate"
fi

echo "USING Unicode::Collate at: ${ucpath}"

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
   --module=IO::Socket::SSL \
   --module=IO::String \
   --module=PerlIO::utf8_strict \
   --module=File::Find::Rule \
   --module=Text::CSV_XS \
   --module=DateTime \
   --link=/usr/bin/cygz.dll \
   --link=/usr/bin/cyggcrypt-20.dll \
   --link=/usr/bin/cygiconv-2.dll \
   --link=/usr/bin/cyggpg-error-0.dll \
   --link=/usr/bin/libbtparse.dll \
   --link=/usr/bin/cygxml2-2.dll \
   --link=/usr/bin/cygxslt-1.dll \
   --link=/usr/bin/cygexslt-0.dll \
   --link=/usr/bin/cygcrypto-1.0.0.dll \
   --link=/usr/bin/cygssl-1.0.0.dll \
   --link=/usr/bin/cygdatrie-1.dll \
   --link=/usr/bin/cygthai-0.dll \
   --addfile="../../data/biber-tool.conf;lib/Biber/biber-tool.conf" \
   --addfile="../../data/schemata/config.rnc;lib/Biber/config.rnc" \
   --addfile="../../data/schemata/config.rng;lib/Biber/config.rng" \
   --addfile="../../data/schemata/bcf.rnc;lib/Biber/bcf.rnc" \
   --addfile="../../data/schemata/bcf.rng;lib/Biber/bcf.rng" \
   --addfile="../../lib/Biber/LaTeX/recode_data.xml;lib/Biber/LaTeX/recode_data.xml" \
   --addfile="../../data/bcf.xsl;lib/Biber/bcf.xsl" \
   --addfile="${ucpath}/Locale;lib/Unicode/Collate/Locale" \
   --addfile="${ucpath}/CJK;lib/Unicode/Collate/CJK" \
   --addfile="${ucpath}/allkeys.txt;lib/Unicode/Collate/allkeys.txt" \
   --addfile="${ucpath}/keys.txt;lib/Unicode/Collate/keys.txt" \
   --addfile="/usr/lib/perl5/${perlv}/i686-cygwin-threads-64int/PerlIO;lib/PerlIO" \
   --addfile="/usr/lib/perl5/${perlv}/i686-cygwin-threads-64int/auto/PerlIO;lib/auto/PerlIO" \
   --addfile="/usr/share/perl5/vendor_perl/${perlv}/Business/ISBN/RangeMessage.xml;lib/Business/ISBN/RangeMessage.xml" \
   --cachedeps=scancache \
   --output=biber-cygwin32.exe \
   /tmp/biber-cygwin

\rm -f /tmp/biber-cygwin
