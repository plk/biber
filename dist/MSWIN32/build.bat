:: The COPY/DEL steps are so that the packed biber main script is not
:: called "biber" as on case-insensitive file systems, this clashes with
:: the Biber lib directory and generates a (harmless) warning on first run.

:: XML::LibXSLT has a workaround for LibXSLT.dll conflicting with libxslt.dll on
:: windows due to case-insensitivity. The Makefile.PL for XML::LibXSLT forces its
:: .dll to end in ".xs.dll" which avoids the conflict but breaks when packaged with pp.
:: Since strawberry perl includes its own libxslt with a non-default name, it is therefore
:: safe to use the default XML::LibXSLT .dll name which does work when packed with pp.
:: To do this, you have to install your own XML::LibXSLT in strawberry perl:
:: edit the Makefile.PL, line 195 or thereabouts and change it to:
::
::     $config{DLEXT} = 'dll' if ($is_Win32);
::
:: then build and install as usual (this seems ok with the included
:: XML::LibXSLT with strawberry perl 5.16 for some reason)

:: Have to explicitly include the Input* modules as the names of these are dynamically
:: constructed in the code so Par::Packer can't auto-detect them.
:: Same with some of the output modules.

:: Unicode::Collate is bundled with perl but is often updated and this is a critical module
:: for biber. There are some parts of this module which must be explicitly bundled by pp.
:: Unfortunately, updates to the module go into site_perl and we must bundle the right version
:: and so we check if there are any newer versions than came with the version of perl we are using
:: by looking to see if there is a site_perl directory for the module. If there is, we use that
:: version.

set UCPATH=C:/strawberry/perl/lib/Unicode/Collate

IF exist C:\strawberry\perl\site\lib\Unicode\Collate\ (set UCPATH=C:/strawberry/perl/site/lib/Unicode/Collate)

ECHO USING Unicode::Collate at: %UCPATH%

COPY C:\strawberry\perl\site\bin\biber %TEMP%\biber-MSWIN32

SET PAR_VERBATIM=1

CALL pp ^
  --module=deprecate ^
  --module=Biber::Input::file::bibtex ^
  --module=Biber::Input::file::biblatexml ^
  --module=Biber::Output::dot ^
  --module=Biber::Output::bbl ^
  --module=Biber::Output::bblxml ^
  --module=Biber::Output::bibtex ^
  --module=Biber::Output::biblatexml ^
  --module=Pod::Simple::TranscodeSmart ^
  --module=Pod::Simple::TranscodeDumb ^
  --module=List::MoreUtils::XS ^
  --module=List::SomeUtils::XS ^
  --module=List::MoreUtils::PP ^
  --module=HTTP::Status ^
  --module=HTTP::Date ^
  --module=Encode:: ^
  --module=IO::Socket::SSL ^
  --module=IO::String ^
  --module=PerlIO::utf8_strict ^
  --module=File::Find::Rule ^
  --module=Text::CSV_XS ^
  --module=DateTime ^
  --module=Win32::Unicode ^
  --link=C:\WINDOWS\system32\libbtparse.dll ^
  --link=C:\strawberry\c\bin\libxslt-1_.dll ^
  --link=C:\strawberry\c\bin\libexslt-0_.dll ^
  --link=C:\strawberry\c\bin\zlib1_.dll ^
  --link=C:\strawberry\c\bin\libxml2-2_.dll ^
  --link=C:\strawberry\c\bin\libiconv-2_.dll ^
  --link=C:\strawberry\c\bin\libssl-1_1_.dll ^
  --link=C:\strawberry\c\bin\libcrypto-1_1_.dll ^
  --link=C:\strawberry\c\bin\liblzma-5_.dll ^
  --addfile="../../data/biber-tool.conf;lib/Biber/biber-tool.conf" ^
  --addfile="../../data/schemata/config.rnc;lib/Biber/config.rnc" ^
  --addfile="../../data/schemata/config.rng;lib/Biber/config.rng" ^
  --addfile="../../data/schemata/bcf.rnc;lib/Biber/bcf.rnc" ^
  --addfile="../../data/schemata/bcf.rng;lib/Biber/bcf.rng" ^
  --addfile="../../lib/Biber/LaTeX/recode_data.xml;lib/Biber/LaTeX/recode_data.xml" ^
  --addfile="../../data/bcf.xsl;lib/Biber/bcf.xsl" ^
  --addfile="%UCPATH%/Locale;lib/Unicode/Collate/Locale" ^
  --addfile="%UCPATH%/CJK;lib/Unicode/Collate/CJK" ^
  --addfile="%UCPATH%/allkeys.txt;lib/Unicode/Collate/allkeys.txt" ^
  --addfile="%UCPATH%/keys.txt;lib/Unicode/Collate/keys.txt" ^
  --addfile="C:/strawberry/perl/vendor/lib/Mozilla/CA/cacert.pem;lib/Mozilla/CA/cacert.pem" ^
  --addfile="C:/strawberry/perl/site/lib/Business/ISBN/RangeMessage.xml;lib/Business/ISBN/RangeMessage.xml" ^
  --cachedeps=scancache ^
  --output=biber-MSWIN32.exe ^
  %TEMP%\biber-MSWIN32

DEL %TEMP%\biber-MSWIN32
