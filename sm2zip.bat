@echo off
set thispath=%~d0%~p0\bin\
set path=%path%;%thispath%
set name=%~0
set version=0.9
set configfile=config\smconfig.cfg
set tmptxt=temp\tempt.txt
set tmphtml=temp\temp.html
set tmpexe=temp\temp.exe
REM Creazione delle cartelle utilizzate dallo script (nel caso non siano presenti)
if not exist temp md temp
if not exist archive md archive


REM Removing comment from config file
REM Getting configuration from cfg file
ssed "/^\s*#.*/d" %configfile% > %tmptxt%
FOR /F "delims=== tokens=1,2" %%i in (%tmptxt%) do set %%i=%%j

REM Reading commandline (very roughly)

echo %* > %tmphtml%
ssed "s/\s\+/\n/g" %tmphtml% > %tmptxt%
REM Short option to long option
ssed -e "{s/^-h$/--help/I;s/^-l$/--last/I;s/^-u\b/--launcher/I;s/^-d\b/--dict/I;s/^-s\b/--sleep/I;s/^-g=/--lang=/I;s/^-t=/--archivetype=/I;s/^-z=/--level=/I;}" %tmptxt% > %tmphtml%
REM now parse the commandline, first remove all invalid preferences (lines not starting with --)
REM put to true option that not have a second argument (=)
ssed -e "s/^--\(launcher\|dict\|sleep\|help\|last\)\s*$/--\1=true/" %tmphtml% > %tmptxt%

ssed   -n -e "/^--help\|--last\|--launcher\|--dict\|--sleep\|--lang\|--archivetype\|--level=[-013579a-zA-Z]\+\s*$/{s/--//;p}" %tmptxt% > %tmphtml%
for  /f "delims== tokens=1,2" %%i in (%tmphtml%) do  set %%i=%%j

if %help%==true goto help

cls
color %color%
type logo.png
echo.
echo Mozilla Italia Release2Zip Suite
echo %app%2Zip %version%
echo Scarica e crea il pacchetto ZIP per l'ultima versione di %app%
echo Applicazione rilasciata as-is, per info consultare https://r2z.gioxx.org
echo Per maggiori informazioni digitare %name% --help
echo ---
echo;


set useragent="MozillaItalia-Downloader/1.0"
REM Use the first parameter to override the channel preference
if "%1" neq "" set channel=%1
if "%channel:~0,4%"=="http" (
set url=%1
goto buildarchive
)

REM parsing channel preference for validity
call set page=%%%channel%%%
set p1=%page:~0,4%
set p2=%page:~7,3%
if "%p2%"=="ftp" goto ftp
if "%p1%"=="http" goto http

REM no valid channel, somthing go wrong (old version are not supported)
:other:
set channel=release
set ver=%1
REM Spazio FTP dismesso, rilancio su HTTP (Gioxx 20150817)
REM set url=http://pv-mirror02.mozilla.org/pub/mozilla.org/%lowerapp%/releases/%ver%/win32/%lang%/%app%%%20Setup%%20%ver%.exe
set url=http://ftp.mozilla.org/pub/%lowerapp%/releases/%ver%/win32/%lang%/%app%%%20Setup%%20%ver%.exe
goto buildarchive

REM Parse the html page where are stored info about the latest version available
:http:
set sed= "/<a href=.#.*>SeaMonkey [0-9\.*]*<\/a>/{s/.*#\([\[0-9b\.]*\).*/\1/;p;q}"
if %channel%==beta set sed= "/<a href=.#.*>SeaMonkey [0-9\.*]* .*<\/a>/{s/.*#\([\[0-9b\.]*\).*/\1/;p;q}"
wget -U %useragent%  %page% -O %tmphtml% -q
if %errorlevel% neq 0 (
set errmsg=Si e` verificato un errore tentando di scaricare %url%
goto error)
ssed -n -e %sed% %tmphtml% > %tmptxt%
for /f %%i in (%tmptxt%) do set ver=%%i
set url="http://download.mozilla.org/?product=%lowerapp%-%ver%&os=win&lang=%lang%"
goto buildarchive

:ftp:
set url=%page%
if "%last%"=="true" set lang=en-US

REM if %lang% neq en-US set url=%url%-l10n
if %lang% neq en-US set url=%url%/win32/it
wget -U %useragent% %url% -O %tmphtml% -q
set sed="/<a href=.%lowerapp%-.*\.%lang%\.win32\.installer\.exe.>%lowerapp%-.*\.%lang%\.win32\.installer\.exe<\/a>/{s/.*>%lowerapp%-\([0-9a\.]*\)\.%lang%\.win32\.installer\.exe<.*/\1/;p}"
ssed -n -e %sed% %tmphtml% > %tmptxt%
for /f %%i in (%tmptxt%) do set ver=%%i
REM set url=%url%/%lowerapp%-%ver%.%lang%.win32.installer.exe
set url=%url%/%app%%%20Setup%%20%ver%.exe
goto buildarchive



REM now download the file and extract files
:buildarchive:
wget -U %useragent% %url% -O %tmpexe%
if %errorlevel% neq 0 (
set errmsg=Si e` verificato un errore tentando di scaricare %url%
goto error
)
REM Extracting downloaded file
7z x %tmpexe% core
set foldername=%lowerapp%
if not %channel%==release set foldername=%foldername%-%channel%
set output=%foldername%-%ver%-%lang%.win32.%archivetype%
if exist %foldername% rd /S /Q %foldername%
if %sleep%==true ping -n 5 127.0.0.1>NUL
ren core %foldername%
if %sleep%==true ping -n 5 127.0.0.1>NUL
if "%dict%"=="true" goto dict
:nodict:
if "%launcher%"=="true" goto launcher
:nolauncher:
goto createarchive

:dict:
if not exist dictionaries call dwdict %lang%
if not exist %foldername%\dictionaries md %foldername%\dictionaries
if not exist %foldername%\hyphenation md %foldername%\hyphenation
move /Y dictionaries\hyph*  %foldername%\hyphenation
copy dictionaries\* %foldername%\dictionaries
copy %foldername%\hyphenation\* dictionaries
goto nodict

:launcher:
set sed="s/#app#/%lowerapp%/"
ssed -e %sed% launcher\launcher_prototype.bat > %foldername%\launcher.bat
xcopy /E launcher\* %foldername% /exclude:config\exclude.txt
goto nolauncher

:createarchive:
7z a -t%archivetype% "%output%" %foldername% -mx%level%
if %sleep%==true ping -n 5 127.0.0.1>NUL
rd /s /q %foldername%
if %sleep%==true ping -n 5 127.0.0.1>NUL
move "%output%" archive
if %sleep%==true ping -n 5 127.0.0.1>NUL
goto end

:error:
echo ATTENZIONE
echo %errmsg%
echo Riprova piu' tardi o contatta gli sviluppatori se il problema persiste
echo;
rd /s /q temp
color 0f
exit /b 1

:help:
set sed="{s/$version/%version%/g;s/$name/%name%/g;s/$allowedchannel/%allowedchannel%/g}"
ssed %sed% help.txt
rd /s /q temp
exit /b 0


:end:
if exist temp rd /S /Q temp
REM md5sum %output% > md5.txt
echo;
echo OK, verificare che il pacchetto sia correttamente funzionante.
:end:
echo.
pause
color 0f


