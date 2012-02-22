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
:: then build and install as usual.

:: Have to explicitly include the Input* modules as the names of these are dynamically
:: constructed in the code so Par::Packer can't auto-detect them.

COPY C:\strawberry\perl\bin\biber C:\WINDOWS\Temp\biber-MSWIN

CALL pp ^
  --compress=6 ^
  --module=deprecate ^
  --module=Biber::Input::file::bibtex ^
  --module=Biber::Input::file::biblatexml ^
  --module=Biber::Input::file::ris ^
  --module=Biber::Input::file::zoterordfxml ^
  --module=Biber::Input::file::endnotexml ^
  --module=Pod::Simple::TranscodeSmart ^
  --module=Pod::Simple::TranscodeDumb ^
  --module=Encode::Byte ^
  --module=Encode::CN ^
  --module=Encode::CJKConstants ^
  --module=Encode::EBCDIC ^
  --module=Encode::Encoder ^
  --module=Encode::GSM0338 ^
  --module=Encode::Guess ^
  --module=Encode::JP ^
  --module=Encode::KR ^
  --module=Encode::MIME::Header ^
  --module=Encode::Symbol ^
  --module=Encode::TW ^
  --module=Encode::Unicode ^
  --module=Encode::Unicode::UTF7 ^
  --module=Readonly::XS ^
  --module=IO::Socket::SSL ^
  --link=C:\WINDOWS\system32\libbtparse.dll ^
  --link=C:\strawberry\c\bin\libxslt-1_.dll ^
  --link=C:\strawberry\c\bin\libexslt-0_.dll ^
  --link=C:\strawberry\c\bin\libz_.dll ^
  --link=C:\strawberry\c\bin\libxml2-2_.dll ^
  --link=C:\strawberry\c\bin\libiconv-2_.dll ^
  --link=C:\strawberry\c\bin\libssl32_.dll ^
  --link=C:\strawberry\c\bin\libeay32_.dll ^
  --addlist=biber.files ^
  --cachedeps=scancache ^
  --icon=biber.ico ^
  --output=biber-MSWIN.exe ^
  C:\WINDOWS\Temp\biber-MSWIN

DEL C:\WINDOWS\Temp\biber-MSWIN
