
perl makewrapper.pl > biber_wrapped
move ..\blib\scripts\biber ..\blib\scripts\biber.orig
move biber_wrapped ..\blib\scripts\biber
cd ..\blib
pp -o biber.exe -a c:\strawberry\perl\site\lib\Unicode\Collate\allkeys.txt  -a lib\Unicode\Collate\latinkeys.txt -M Readonly::XS -M Parse::RecDescent -M XML::Writer -M XML::LibXML::Simple script\biber script\bib2biblatexml script\latex2utf8
move biber.exe ..\
cd ..
