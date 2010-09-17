REM The COPY/DEL steps as so that the packed biber main script is not
REM called "biber" as on case-insensitive file systems, this clashes with
REM the Biber lib directory and generates a (harmless) warning on first run

COPY C:\strawberry\perl\site\bin\biber C:\WINDOWS\Temp\biber-MSWIN

CALL pp ^
  --compress=6 ^
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
  --link=C:\WINDOWS\libbtparse.dll ^
  --link=C:\strawberry\c\bin\libz_.dll ^
  --link=C:\strawberry\c\bin\libxml2-2_.dll ^
  --link=C:\strawberry\c\bin\libiconv-2_.dll ^
  --addlist=biber.files ^
  --cachedeps=scancache ^
  --info=ProductName=biber ^
  --icon=biber.ico ^
  --output=biber-MSWIN.exe ^
  C:\WINDOWS\Temp\biber-MSWIN

DEL C:\WINDOWS\Temp\biber-MSWIN
