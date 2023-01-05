@REM author: wzdnzd
@REM date: 2022-08-24
@REM describe: auto update clash, geosite.dat, geoip.dat

@echo off & PUSHD %~DP0 & cd /d "%~dp0"

@REM change encoding
chcp 65001 >nul 2>nul

@REM output with color
call :setESC

@REM https://blog.csdn.net/sanqima/article/details/37818115
setlocal enableDelayedExpansion

@REM call workflow
goto :workflow


@REM ########################
@REM function define blow ###
@REM ########################

@REM process pipeline
:workflow
@REM batch file name
set "batname=%~nx0"

@REM help flag
set "helpflag=0"

@REM check
set "checkflag=0"

@REM repair
set "repair=0"

@REM only reload
set "reloadonly=0"

@REM restart clash.exe
set "restartflag=0"

@REM close proxy
set "killflag=0"

@REM update
set "updateflag=0"

@REM only update subscriptions and rulesets
set "quickflag=0"

@REM don't update subscription
set "exclude=0"

@REM use clash.meta
set "clashmeta=0"

@REM alpha version allowed
set "alpha=0"

@REM yacd dashboard, see https://github.com/MetaCubeX/Yacd-meta
set "yacd=0"

@REM run on background
set "asdaemon=0"

@REM show window
set "show=0"

@REM setting workspace
set "dest="

@REM parse arguments
call :argsparse %*

@REM arguments error occured
if "!helpflag!" == "1" exit /b 0

@REM close network proxy
if "!killflag!" == "1" goto :closeproxy

@REM regular file path
if "!dest!" == "" set "dest=%~dp0"
call :pathregular dest "!dest!"

@REM config file path
set "configfile=!dest!\config.yaml"

@REM github proxy
set "ghproxy=https://ghproxy.com"

@REM exit if config file not exists
if not exist "!configfile!" exit /b 1

@REM connectivity test
if "!checkflag!" == "1" goto :checkconnect 1

@REM reload config
if "!reloadonly!" == "1" goto :reload

@REM update
if "!restartflag!" == "1" goto :restartprogram

@REM check issues
if "!repair!" == "1" goto :resolveissues

@REM update
if "!updateflag!" == "1" goto :updateplugins

@REM unknown command
if "!helpflag!" == "0" goto :usage
exit /b


@REM fix network issues
:resolveissues
@REM mandatory use of the stable version
set "alpha=0"

@echo [%ESC%[95minfo%ESC%[0m] start checking and fixing proxy network problems

@REM check status
call :checkconnect available 0
set "lazycheck=0"
if "!available!" == "1" (
    choice /t 5 /d n /n /m "[%ESC%[97mwarning%ESC%[0m] network proxy is %ESC%[95mworking fine%ESC%[0m, %ESC%[91mno fixes needed%ESC%[0m, do you want to continue (%ESC%[97mY%ESC%[0m/%ESC%[97mN%ESC%[0m)? "
    if !errorlevel! == 2 exit /b 1
) else (
    @REM running detect
    call :isrunning status
    if "!status!" == "0" (
        call :checkwapper continue 1
        if "!continue!" == "0" exit /b
    ) else set "lazycheck=1"
)

@REM O: Reload | R: Restart | U: Restore | N: Cancel
choice /t 6 /c ORUN /d R /n /m "[%ESC%[97mwarning%ESC%[0m] press %ESC%[97mO%ESC%[0m to %ESC%[97mReload%ESC%[0m, press %ESC%[97mR%ESC%[0m to %ESC%[97mRestart%ESC%[0m, press %ESC%[97mU%ESC%[0m to %ESC%[97mRestore%ESC%[0m to default, press %ESC%[97mN%ESC%[0m to %ESC%[97mCancel%ESC%[0m. (%ESC%[97mO%ESC%[0m/%ESC%[97mR%ESC%[0m/%ESC%[97mU%ESC%[0m/%ESC%[97mN%ESC%[0m) "

if !errorlevel! == 1 (
    call :reload
) else if !errorlevel! == 2 (
    call :restartprogram
) else if !errorlevel! == 3 (
    @REM kill clash process
    call :killprocesswrapper

    @REM wait 3 seconds
    timeout /t 3 /nobreak >nul 2>nul

    @REM lazy check
    if "!lazycheck!" == "1" (
        call :checkwapper continue 0
        if "!continue!" == "0" exit /b
    )

    @REM wintun.dll
    call :downloadwintun

    @REM restore plugins
    call :updateplugins
) else (
    :: cancel
    exit /b
)

@REM wait 3 seconds
timeout /t 3 /nobreak >nul 2>nul

@REM recheck
call :checkconnect available 0
if "!available!" == "1" (
    @echo [%ESC%[95minfo%ESC%[0m] issues has been %ESC%[95mfixed%ESC%[0m and now the network proxy can be used %ESC%[95mnormally%ESC%[0m
) else (
    @echo [%ESC%[91merror%ESC%[0m] the problem repair %ESC%[91mfailed%ESC%[0m, the network proxy is still %ESC%[91munavailable%ESC%[0m, please try other methods
)
goto :eof


@REM check if the network is available
:checkwapper <result> <enable>
set "%~1=1"
call :trim loglevel "%~2"
if "!loglevel!" == "" set "loglevel=1"

call :isavailable available 0 "https://www.baidu.com"
if "!available!" == "0" (
    @echo [%ESC%[91merror%ESC%[0m] your network is %ESC%[91munavailable%ESC%[0m, but proxy program is %ESC%[91mnot running%ESC%[0m. please check the network first

    @REM should terminate
    set "%~1=0"
    exit /b
)

if "!loglevel!" == "1" (
    @echo [%ESC%[97mwarning%ESC%[0m] network proxy is %ESC%[91mnot running%ESC%[0m, recommend you choose %ESC%[97mRestart%ESC%[0m to execute it
)
goto :eof

@REM update workflow
:updateplugins
if "!quickflag!" == "1" goto :quickupdate

@REM run as admin
if "!asdaemon!" == "1" (
    cacls "%SystemDrive%\System Volume Information" >nul 2>&1 || (start "" mshta vbscript:CreateObject^("Shell.Application"^).ShellExecute^("%~snx0"," %*","","runas",!show!^)^(window.close^)&exit /b)
)

@REM dashboard directory name
call :extractpath

@REM confirm download url and filename
call :versioned

@REM confirm donwload url
call :confirmurl

@REM precleann workspace
call :cleanworkspace "!temp!"

@REM update dashboard
call :dashboardupdate

@REM update subscriptions
if "!exclude!" == "0" call :updatesubs

@REM update rulefiles
call :updaterules

@REM download clah.exe and geoip.data and so on
call :donwloadfiles filenames

@REM judge file changed with md5
call :detect changed "!filenames!"

@REM no new version found
if "!changed!" == "0" (
    @echo [%ESC%[95minfo%ESC%[0m] don't need update due to not found new version
) else (
    @REM wait for overwrite files
    timeout /t 3 /nobreak >nul 2>nul
)

@REM postclean
call :cleanworkspace "!temp!"

@REM startup
call :startclash
goto :eof


@REM parse and validate arguments
:argsparse
set result=false

if "%1" == "-a" set result=true
if "%1" == "--alpha" set result=true
if "!result!" == "true" (
    set "alpha=1"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-c" set result=true
if "%1" == "--check" set result=true
if "!result!" == "true" (
    set "checkflag=1"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-d" set result=true
if "%1" == "--daemon" set result=true
if "!result!" == "true" (
    set "asdaemon=1"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-e" set result=true
if "%1" == "--exclude" set result=true
if "!result!" == "true" (
    set "exclude=1"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-f" set result=true
if "%1" == "--fix" set result=true
if "!result!" == "true" (
    set "repair=1"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-h" set result=true
if "%1" == "--help" set result=true
if "!result!" == "true" (
    call :usage
)

if "%1" == "-k" set result=true
if "%1" == "--kill" set result=true
if "!result!" == "true" (
    set "killflag=1"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-m" set result=true
if "%1" == "--meta" set result=true
if "!result!" == "true" (
    set "clashmeta=1"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-o" set result=true
if "%1" == "--overload" set result=true
if "!result!" == "true" (
    set "reloadonly=1"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-q" set result=true
if "%1" == "--quick" set result=true
if "!result!" == "true" (
    set "quickflag=1"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-r" set result=true
if "%1" == "--restart" set result=true
if "!result!" == "true" (
    set "restartflag=1"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-s" set result=true
if "%1" == "--show" set result=true
if "!result!" == "true" (
    set "show=1"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-u" set result=true
if "%1" == "--update" set result=true
if "!result!" == "true" (
    set "updateflag=1"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-w" set result=true
if "%1" == "--workspace" set result=true
if "!result!" == "true" (
    @REM validate argument
    call :trim directory "%~2"
    if "!directory!" == "" set result=false
    if "!directory:~0,2!" == "--" set result=false
    if "!directory:~0,1!" == "-" set result=false

    if "!result!" == "false" (
        @echo [%ESC%[91merror%ESC%[0m] invalid argument, if you set "%ESC%[97m--workspace%ESC%[0m" you must specify an absolute path
        @echo.
        goto :usage
    )

    if not exist "!directory!" (
        @echo [%ESC%[91merror%ESC%[0m] the specified path "%ESC%[97m!directory!%ESC%[0m" for "%ESC%[97m--workspace%ESC%[0m" does %ESC%[91mnot exist%ESC%[0m, must be an %ESC%[97mabsolute path%ESC%[0m
        @echo.
        goto :usage
    )

    set "dest=!directory!"
    set result=false
    shift & shift & goto :argsparse
)

if "%1" == "-y" set result=true
if "%1" == "--yacd" set result=true
if "!result!" == "true" (
    set "yacd=1"
    set result=false
    shift & goto :argsparse
)

if "%1" NEQ "" (
    call :trim syntax "%~1"
    if "!syntax!" == "goto" (
        call :trim funcname "%~2"
        if "!funcname!" == "" (
            @echo [%ESC%[91merror%ESC%[0m] invalid syntax, function name cannot by empty when use goto
            goto :usage
        )

        for /f "tokens=1-2,* delims= " %%a in ("%*") do set "params=%%c"
        if "!params!" == "" (
            call !funcname!
            exit /b
        ) else (
            call !funcname! !params!
            exit /b
        )
    )

    @echo [%ESC%[91merror%ESC%[0m] arguments error, unknown: %ESC%[91m%1%ESC%[0m
    @echo.
    goto :usage
)
goto :eof


@REM help
:usage
@echo Usage: !batname! [OPTIONS]
@echo.
@echo arguments: support long options and short options
@echo -a, --alpha          alpha version allowed for clash, the stable version is used by default, %ESC%[97muse with --update%ESC%[0m
@echo -c, --check          check whether the network proxy is available
@echo -d, --daemon         run on background as daemon, default is false, %ESC%[97muse with --update%ESC%[0m
@echo -e, --exclude        ignore subscriptions when updating, %ESC%[97muse with --update%ESC%[0m
@echo -f, --fix            overwrite all plugins to fix network issues
@echo -h, --help           display this help and exit
@echo -k, --kill           close network proxy by kill clash process
@echo -m, --meta           use clash.meta instead of clash premium, %ESC%[97muse with --update%ESC%[0m
@echo -o, --overload       only reload configuration files
@echo -q, --quick          quick updates, only subscriptions and rulesets are refreshed, %ESC%[97muse with --update%ESC%[0m
@echo -r, --restart        kill and restart clash process
@echo -s, --show           show running window, hide by default, %ESC%[97muse with --update%ESC%[0m
@echo -u, --update         perform update operations on plugins, subscriptions, and rulesets
@echo -w, --workspace      specify the absolute path of clash workspace, default is the path where the current script is located
@echo -y, --yacd           use yacd to replace the standard dashboard, %ESC%[97muse with --update%ESC%[0m

set "helpflag=1"
goto :eof


@REM confirm download url and filename according parameters
:versioned
set "content="
set "geositeneed=0"

for /f "tokens=*" %%i in ('findstr /i /r "GEOSITE,.*" !configfile!') do set "content=!content!;%%i"
call :searchrules "!content!"

@REM rulesets include GEOSITE, must be clash.meta
if "!notfound!" == "0" (
    set "clashmeta=1"
    set "geositeneed=1"
    goto :eof
)

set "content="
for /f "tokens=*" %%i in ('findstr /i /r "SCRIPT,.*" !configfile!') do set "content=!content!;%%i"
call :searchrules "!content!"

@REM rulesets include SCRIPT, must be clash.premium
if "!notfound!" == "0" (
    set "clashmeta=0"
)
goto :eof


@REM quickly update subscriptions and rulesets
:quickupdate
@REM subscriptions
if "!exclude!" == "0" call :updatesubs

@REM rulesets
call :updaterules

@REM reload
if "!changed!" == "1" (goto :reload) else (goto :eof)


@REM check if special rules are included
:searchrules
set "rulesets=%~1"
set "notfound=1"

for /F "tokens=1* delims=;" %%f in ("!rulesets!") do (
    :: set "rule=%%f"
    call :trim rule "%%f"
    if /i "!rule:~0,1!"=="-" (
        set "notfound=0"
        goto :eof
    )

    if "%%g" NEQ "" call :searchrules "%%g"
)
goto :eof


@REM update subscriptions
:updatesubs
@echo [%ESC%[95minfo%ESC%[0m] subscriptions are being updated, only those with type "http" will be updated
call :filerefresh changed "^\s+health-check:(\s+)?$" "www.gstatic.com"
goto :eof


:splitpath <directory> <filename> <filepath>
set "%~1=%~dp3"
set "%~2=%~nx3"

if "!%~1:~-1!" == "\" set "%~1=!%~1:~0,-1!"
goto :eof


@REM to absolute path
:pathconvert <result> <filename>
call :trim filepath %~2
set "%~1="

if "!filepath!" == "" (
    goto :eof
)

@echo "!filepath!" | findstr ":" >nul 2>nul && goto :eof || (
    set "filepath=!filepath:/=\!"

    if "!filepath:~0,3!" == ".\\" (
        set "%~1=!dest!\!filepath:~3!"
    ) else if "!filepath:~0,2!" == ".\" (
        set "%~1=!dest!\!filepath:~2!"
    ) else (
        set "%~1=!dest!\!filepath!"
    )
)
goto :eof


@REM connectivity
:checkconnect <result> <allowed>
@REM running status
set "%~1=0"
call :trim enable "%~2"
if "!enable!" == "" set "enable=1"

call :isrunning status
if "!status!" == "0" (
    if "!enable!" == "1" (
        @echo [%ESC%[97mwarning%ESC%[0m] network proxy is %ESC%[91mnot available%ESC%[0m because clash.exe is %ESC%[91mnot running%ESC%[0m
    )

    goto :eof
)

@REM detect network is available
call :isavailable status !enable! "https://www.google.com"
set "%~1=!status!"
goto :eof


@REM check network
:isavailable <result> <allowed> <url>
set "%~1=0"
call :trim enable "%~2"
call :trim url "%~3"
if "!enable!" == "" set "enable=1"
if "!url!" == "" set "url=https://www.google.com"

@REM check
set "statuscode=000"
for /f %%a in ('curl --retry 3 --retry-max-time 10 -m 5 --connect-timeout 5 -L -s -o nul -w "%%{http_code}" "!url!"') do set "statuscode=%%a"

if "!statuscode!" == "200" (
    set "%~1=1"
    if "!enable!" == "1" (
        @echo [%ESC%[95minfo%ESC%[0m] network proxy is not a problem and %ESC%[95mworks fine%ESC%[0m
    )
) else (
    set "%~1=0"
    if "!enable!" == "1" (
        @echo [%ESC%[97mwarning%ESC%[0m] network proxy is %ESC%[91mnot available%ESC%[0m, you can %ESC%[97mreload%ESC%[0m it with "%ESC%[97m!batname! -o%ESC%[0m" or %ESC%[97mrestart%ESC%[0m it with "%ESC%[97m!batname! -r%ESC%[0m" or "%ESC%[97m!batname! -f%ESC%[0m" to try to %ESC%[97mfix%ESC%[0m the problem
    )
)
goto :eof


@REM create if directory not exists
:makedirs <directory>
call :trim directory %~1
if "!directory!" == "" (
    @echo [%ESC%[97mwarning%ESC%[0m] skip mkdir because file path is empty
    goto :eof
)

if not exist "!directory!" (
    mkdir "!directory!" >nul 2>nul
)
goto :eof


@REM wintun
:downloadwintun
set "content="
set "wintunurl=https://www.wintun.net"

for /f delims^=^"^ tokens^=2 %%a in ('curl --retry 5 -s -L "!wintunurl!" ^| findstr /i /r "builds/wintun-.*.zip"') do set "content=%%a"
call :trim content !content!

if "!content!" == "" (
    @echo [%ESC%[97mwarning%ESC%[0m] cannot extract wintun download link
    goto :eof
)

set "wintunurl=!wintunurl!/!content!"
@echo [%ESC%[95minfo%ESC%[0m] begin to download wintun for overwrite wintun.dll, link: "!wintunurl!"
curl.exe --retry 5 -m 90 --connect-timeout 15 -s -L -C - -o "!temp!\wintun.zip" "!wintunurl!"
if exist "!temp!\wintun.zip" (
    @REM unzip
    tar -xzf "!temp!\wintun.zip" -C !temp!

    @REM clean workspace
    del /f /q "!temp!\wintun.zip" >nul 2>nul

    set "wintunfile=!temp!\wintun\bin\amd64\wintun.dll"
    if exist "!wintunfile!" (
        if exist "!dest!\wintun.dll" del /f /q "!dest!\wintun.dll" >nul 2>nul
        move "!wintunfile!" "!dest!" >nul 2>nul
    ) else (
        @echo [%ESC%[97mwarning%ESC%[0m] not found wintun.dll, there may be an error downloading
    )
) else (
    @echo [%ESC%[97mwarning%ESC%[0m] wintun download failed, please check link is correct
)
goto :eof


@REM download binary file and data
:donwloadfiles <filenames>
@echo [%ESC%[95minfo%ESC%[0m] downloading clash.exe, domain site and IP address data
set "dfiles="

@REM download clash
if "!clashurl!" NEQ "" (
    curl.exe --retry 5 -m 120 --connect-timeout 20 -s -L -C - -o "!temp!\clash.zip" "!clashurl!"

    if exist "!temp!\clash.zip" (
        @REM unzip
        tar -xzf "!temp!\clash.zip" -C !temp!

        @REM clean workspace
        del /f /q "!temp!\clash.zip"
    ) else (
        @echo [%ESC%[91merror%ESC%[0m] clash download failed, link: "!clashurl!"
    )

    if exist "!temp!\!clashexe!" (
        @REM rename file
        ren "!temp!\!clashexe!" clash.exe

        set "dfiles=clash.exe"
    ) else (
        @echo [%ESC%[91merror%ESC%[0m] not found "!temp!\!clashexe!", download link: "!clashurl!"
    )
) else (
    @echo [%ESC%[91merror%ESC%[0m] skip download clash.exe because link is empty
)

@REM download Country.mmdb
if "!countryurl!" NEQ "" (
    curl.exe --retry 5 -m 120 --connect-timeout 20 -s -L -C - -o "!temp!\!countryfile!" "!countryurl!"
    if exist "!temp!\!countryfile!" (
        if "!dfiles!" == "" (
            set "dfiles=!countryfile!"
        ) else (
            set "dfiles=!dfiles!;!countryfile!"
        )
    ) else (
        @echo [%ESC%[91merror%ESC%[0m] not found "!temp!\!countryfile!", download link: "!countryurl!"
    )
)

@REM download GeoSite.dat
if "!geositeurl!" NEQ "" (
    curl.exe --retry 5 -m 120 --connect-timeout 20 -m 120 --connect-timeout 20 -s -L -C - -o "!temp!\!geositefile!" "!geositeurl!"

    if exist "!temp!\!geositefile!" (
        if "!dfiles!" == "" (
            set "dfiles=!geositefile!"
        ) else (
            set "dfiles=!dfiles!;!geositefile!"
        )
    ) else (
        @echo [%ESC%[91merror%ESC%[0m] "!temp!\!geositefile!" not exists, download link: "!geositeurl!"
    )
)

@REM download GeoIP.dat
if "!geoipurl!" NEQ "" (
    curl.exe --retry 5 -m 120 --connect-timeout 20 -s -L -C - -o "!temp!\!geoipfile!" "!geoipurl!"

    if exist "!temp!\!geoipfile!" (
        if "!dfiles!" == "" (
            set "dfiles=!geoipfile!"
        ) else (
            set "dfiles=!dfiles!;!geoipfile!"
        )
    ) else (
        @echo [%ESC%[91merror%ESC%[0m] cannot found file "!temp!\!geoipfile!", download link: "!geoipurl!"
    )
)

set "%~1=!dfiles!"
goto :eof


@REM compare
:detect <result> <filenames>
set "%~1=0"
set "filenames=%~2"

for %%a in (!filenames!) do (
    set "fname=%%a"

    if "!repair!" == "1" (
        @REM delete for triggering upgrade
        del /f /q "!dest!\!fname!" >nul 2>nul
    )

    @REM found new file
    if not exist "!dest!\!fname!" (
        set "%~1=1"
        @echo [%ESC%[95minfo%ESC%[0m] missing file found, filename: !fname!, recreate it in directory "!dest!"
        goto :upgrade
    )

    set "original=" & for /F "skip=1 delims=" %%h in ('2^> nul CertUtil -hashfile "!temp!\!fname!" MD5') do if not defined original set "original=%%h"

    set "received=" & for /F "skip=1 delims=" %%h in ('2^> nul CertUtil -hashfile "!dest!\!fname!" MD5') do if not defined received set "received=%%h"

    if "!original!" NEQ "!received!" (
        set "%~1=1"
        @echo [%ESC%[95minfo%ESC%[0m] new version found, filename: %ESC%[97m!fname!%ESC%[0m, omd5: !original!, nmd5: !received!
        goto :upgrade
    )
)
goto :eof


@REM update clash.exe and data
:upgrade
@REM make sure the file exists
set "existfiles="
for %%a in (!filenames!) do (
    if exist "!temp!\%%a" (
        if "!existfiles!" == "" (
            set "existfiles=%%a"
        ) else (
            set "existfiles=!existfiles!;%%a"
        )
    )
)

@REM file missing
if "!existfiles!" == "" goto :terminate

@REM stop clash
call :killprocesswrapper

@REM copy file
for %%a in (!filenames!) do (
    set "fname=%%a"

    @REM delete if old file exists
    if exist "!dest!\!fname!" (
        del /f /q "!dest!\!fname!" >nul 2>nul
    )
    
    @REM move new file to dest
    move "!temp!\!fname!" "!dest!" >nul 2>nul
)
goto :eof


@REM start
:startclash
call :isrunning status

if "!status!" == "0" (
    @REM startup clash
    goto :executewrapper
) else (
    @echo [%ESC%[95minfo%ESC%[0m] subscriptions and rulesets have been updated, and the reload operation is about to be performed
    goto :reload
)
goto :eof


@REM privilege escalation
:privilege <args> <show>
set "hidewindow=0"

@REM parse window parameter
call :trim param "%~2"
set "display=" & for /f "delims=0123456789" %%i in ("!param!") do set "display=%%i"
if defined display (set "hidewindow=0") else (set "hidewindow=!param!")
if "!hidewindow!" NEQ "0" set "hidewindow=1"

cacls "%SystemDrive%\System Volume Information" >nul 2>&1 && goto :killprocess || (start "" mshta vbscript:CreateObject^("Shell.Application"^).ShellExecute^("%~snx0","%~1","","runas",!hidewindow!^)^(window.close^)&exit /b)


@REM execute
:execute <config>
call :trim cfile "%~1"

if "!cfile!" == "" (
    @echo [%ESC%[95minfo%ESC%[0m] cannot execute clash.exe, invalid config path
    goto :eof
)

call :splitpath filepath filename "!cfile!"
if not exist "!filepath!\clash.exe" (
    @echo [%ESC%[91merror%ESC%[0m] failed to startup process, file "!filepath!\clash.exe" is missing
    goto :eof
)

if not exist "!cfile!" (
    @echo [%ESC%[91merror%ESC%[0m] failed to startup process, not found config file "!cfile!"
    goto :eof
)
 
"!filepath!\clash.exe" -d "!filepath!" -f "!cfile!"
goto :eof


@REM privilege escalation
:executewrapper
call :privilege "goto :execute !configfile!" !show!

@REM waiting
timeout /t 3 /nobreak >nul 2>nul

@REM check running status
call :isrunning status

if "!status!" == "1" (
    @echo [%ESC%[95minfo%ESC%[0m] execute clash.exe %ESC%[95msuccess%ESC%[0m, network proxy is %ESC%[95menabled%ESC%[0m
) else (
    @echo [%ESC%[91merror%ESC%[0m] execute clash.exe %ESC%[91mfailed%ESC%[0m, please check if the %ESC%[91mconfiguration%ESC%[0m is correct
)
goto :eof


@REM restart program
:restartprogram
@REM check running status
call :isrunning status
if "!status!" == "1" (
    @REM kill process
    call :killprocesswrapper

    @REM waiting for process exit
    timeout /t 3 /nobreak >nul 2>nul

    @REM check running status
    call :isrunning status

    if "!status!" == "1" (
        @echo [%ESC%[97mwarning%ESC%[0m] restart clash.exe %ESC%[91mfailed%ESC%[0m due to %ESC%[97mcannot stop%ESC%[0m it
        goto :eof
    )
)

@REM startup
goto :executewrapper


@REM run as admin
:killprocesswrapper
@echo [%ESC%[95minfo%ESC%[0m] kill clash process with administrator permission
call :privilege "goto :killprocess" 0

@REM wait a moment
timeout /t 3 /nobreak >nul 2>nul

@REM detect
call :isrunning status
if "!status!" == "0" (
    @echo [%ESC%[95minfo%ESC%[0m] network proxy program has exited %ESC%[95msuccessfully%ESC%[0m. if you want to restart it you can execute with "%ESC%[97m!batname! -r%ESC%[0m"
) else (
    @echo [%ESC%[97mwarning%ESC%[0m] kill network proxy process %ESC%[91mfailed%ESC%[0m, you can close it manually in %ESC%[97mtask manager%ESC%[0m
)
goto :eof


@REM stop
:killprocess
tasklist | findstr /i "clash.exe" >nul 2>nul && taskkill /im "clash.exe" /f >nul 2>nul
set "exitcode=!errorlevel!"

@REM waiting for release
timeout /t 2 /nobreak >nul 2>nul

@REM detect running status
call :isrunning status

if "!status!" == "0" (
    @echo [%ESC%[95minfo%ESC%[0m] clash.exe process exits successfully, and the network proxy is closed
) else (
    @echo [%ESC%[91merror%ESC%[0m] failed to close network proxy, cannot exit clash process, status: !exitcode!
)
goto :eof


@REM delect running status
:isrunning <result>
tasklist | findstr /i "clash.exe" >nul 2>nul && set "%~1=1" || set "%~1=0"
goto :eof

@REM donwload url
:confirmurl
@REM country data
set "countryurl=https://raw.githubusercontent.com/Hackl0us/GeoIP2-CN/release/Country.mmdb"

@REM geosite/geoip filename
set "countryfile=Country.mmdb"
set "geositefile=GeoSite.dat"
set "geoipfile=GeoIP.dat"

@REM dashboard url
set "dashboardurl=https://github.com/Dreamacro/clash-dashboard/archive/refs/heads/gh-pages.zip"
set "dashdirectory=clash-dashboard-gh-pages"

if "!clashmeta!" == "0" (
    set "clashexe=clash-windows-amd64.exe"

    if "!alpha!" == "0" (
        for /f "tokens=1* delims=:" %%a in ('curl --retry 5 -s -L "https://api.github.com/repos/Dreamacro/clash/releases/tags/premium" ^| findstr /i /r /c:"https://github.com/Dreamacro/clash/releases/download/premium/clash-windows-amd64-[^v][^3].*.zip"') do set "clashurl=%%b"
        
        @REM remove whitespace
        call :trim clashurl "!clashurl!"
        if !clashurl! == "" (
            @echo [%ESC%[91merror%ESC%[0m] cannot extract download url for clash.premium, version: stable
            goto :eof
        )
        set "clashurl=!clashurl:~1,-1!"
    ) else (
        set "clashurl=https://release.dreamacro.workers.dev/latest/clash-windows-amd64-latest.zip"
    )

    if "!yacd!" == "1" (
        set "dashboardurl=https://github.com/haishanh/yacd/archive/refs/heads/gh-pages.zip"
        set "dashdirectory=yacd-gh-pages"
    )
) else (
    set "clashexe=Clash.Meta-windows-amd64.exe"
    set "geositeurl=https://raw.githubusercontent.com/Loyalsoldier/domain-list-custom/release/geosite.dat"
    set "geoipurl=https://raw.githubusercontent.com/Loyalsoldier/geoip/release/geoip-only-cn-private.dat"

    if "!alpha!" == "1" (
        for /f "tokens=1* delims=:" %%a in ('curl --retry 5 -s -L "https://api.github.com/repos/MetaCubeX/Clash.Meta/releases?prerelease=true&per_page=10" ^| findstr /i /r "https://github.com/MetaCubeX/Clash.Meta/releases/download/Prerelease-Alpha/Clash.Meta-windows-amd64-alpha-.*.zip"') do set "clashurl=%%b"
    ) else (
        for /f "tokens=1* delims=:" %%a in ('curl --retry 5 -s -L "https://api.github.com/repos/MetaCubeX/Clash.Meta/releases/latest?per_page=1" ^| findstr /i /r "https://github.com/MetaCubeX/Clash.Meta/releases/download/.*/Clash.Meta-windows-amd64-.*.zip"') do set "clashurl=%%b"
    )

    call :trim clashurl "!clashurl!"
    if !clashurl! == "" (
        @echo [%ESC%[91merror%ESC%[0m] cannot extract download url for clash.meta
        goto :eof
    )

    set "clashurl=!clashurl:~1,-1!"

    @REM geodata-mode
    set "geodatamode=false"

    for /f "tokens=1,2 delims=:" %%a in ('findstr /i /r /c:"^[ ][ ]*geodata-mode:[ ][ ]*" !configfile!') do (
        call :trim gmode %%a

        @REM commented
        if /i "!gmode:~0,1!" NEQ "#" call :trim geodatamode %%b
    )

    @REM geosite.data download url
    if "!geositeneed!" == "0" (
        set "geositeurl="
    ) else (
        for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"^[ ][ ]*geosite:[ ][ ]*" !configfile!') do (
            call :trim geositekey %%a

            @REM commented
            if /i "!geositekey:~0,1!" NEQ "#" call :trim geositeurl %%b
        )
    )

    @REM geoip.data
    if "!geodatamode!" == "false" (
        set "geoipurl="

        for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"^[ ][ ]*mmdb:[ ][ ]*" !configfile!') do (
            call :trim mmdbkey %%a

            @REM commented
            if /i "!mmdbkey:~0,1!" NEQ "#" call :trim countryurl %%b
        )
    ) else (
        set "countryurl="

        for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"^[ ][ ]*geoip:[ ][ ]*http.*://" !configfile!') do (
            call :trim geoipkey %%a
            
            @REM commented
            if /i "!geoipkey:~0,1!" NEQ "#" call :trim geoipurl %%b
        )
    )

    if "!yacd!" == "1" (
        set "dashboardurl=https://github.com/MetaCubeX/Yacd-meta/archive/refs/heads/gh-pages.zip"
        set "dashdirectory=Yacd-meta-gh-pages"
    )
)

@REM don't need dashboard
if "!dashboard!" == "" (
    set "dashboardurl="
)

@REM ghproxy for clashurl
call :ghproxywrapper clashurl !clashurl!

@REM ghproxy for dashboardurl
call :ghproxywrapper dashboardurl !dashboardurl!

@REM ghproxy for countryurl
call :ghproxywrapper countryurl !countryurl!

@REM ghproxy for geositeurl
call :ghproxywrapper geositeurl !geositeurl!

@REM ghproxy for geoipurl
call :ghproxywrapper geoipurl !geoipurl!
goto :eof


@REM leading and trailing whitespace
:trim <result> <rawtext>
set "rawtext=%~2"
set "%~1="
if "!rawtext!" == "" goto :eof

for /f "tokens=* delims= " %%a in ("!rawtext!") do set "rawtext=%%a"
for /l %%a in (1,1,100) do if "!rawtext:~-1!"==" " set "rawtext=!rawtext:~0,-1!"

set "%~1=!rawtext!"
goto :eof


@REM wrapper github
:ghproxywrapper <result> <rawurl>
call :trim rawurl %~2

if "!rawurl:~0,18!" == "https://github.com" set "rawurl=!ghproxy!/!rawurl!"
if "!rawurl:~0,33!" == "https://raw.githubusercontent.com" set "rawurl=!ghproxy!/!rawurl!"
if "!rawurl:~0,34!" == "https://gist.githubusercontent.com" set "rawurl=!ghproxy!/!rawurl!"

set "%~1=!rawurl!"
goto :eof


@REM search keywords with powershell
:findby <filepath> <regex> <resultfile>
call :trim filepath %~1
if "!filepath!" == "" goto :eof

set "regex=%~2"
if "!regex!" == "" goto :eof

call :trim result %~3
if "!result!" == "" goto :eof

powershell -command "& {&'Get-Content' '!filepath!' | &'Select-String' -Pattern '!regex!' -Context 5,5 | &'Set-Content' -Encoding 'utf8' '!result!'}";
goto :eof


@REM reload config
:reload
if not exist "!configfile!" goto :eof

@REM clash api address
for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"external-controller:[ ][ ]*" !configfile!') do set "clashapi=%%b"
call :trim clashapi "!clashapi!"
set "clashapi=http://!clashapi!/configs?force=true"

@REM clash api secret
for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"secret:[ ][ ]*" !configfile!') do set "secret=%%b"
call :trim secret "!secret!"
set "secret=!secret:~1,-1!"

@REM running detect
call :isrunning status

if "!status!" == "1" (
    @REM '\' to '\\'
    set "filepath=!configfile:\=\\!"

    @REM call api for reload
    set "statuscode=000"
    set "output=!temp!\clashout.txt"
    if exist "!output!" del /f /q "!output!" >nul 2>nul

    for /f %%a in ('curl --retry 3 -L -s -o "!output!" -w "%%{http_code}" -H "Content-Type: application/json" -H "Authorization: Bearer !secret!" -X PUT -d "{""path"":""!filepath!""}" "!clashapi!"') do set "statuscode=%%a"

    if "!statuscode!" == "204" (
        @echo [%ESC%[95minfo%ESC%[0m] proxy program reload %ESC%[95msucceeded%ESC%[0m, wish you a happy use
    ) else (
        set "content="

        if exist "!output!" (
            @REM read output
            for /f "delims=" %%a in (!output!) do set "content=%%a"
        )

        @echo [%ESC%[91merror%ESC%[0m] reload %ESC%[91mfailed%ESC%[0m, please check if your configuration file is valid and try again
        if "!content!" NEQ "" (
            @echo [%ESC%[91merror%ESC%[0m] error message: "!content!"
        )

        @echo.
    )

    @REM delete
    del /f /q "!output!" >nul 2>nul
) else (
    @echo [%ESC%[91merror%ESC%[0m] clash.exe is %ESC%[91mnot running%ESC%[0m, skip reload. you can start it with command "%ESC%[97m!batname! -r%ESC%[0m"
)
goto :eof


@REM update rules
:updaterules
@echo [%ESC%[95minfo%ESC%[0m] checking and updating rulesets of type "http"
call :filerefresh changed "^\s+behavior:\s+.*" "www.gstatic.com"
goto :eof


@REM refresh subsribe and rulesets
:filerefresh <result> <regex> <filter>
set "%~1=0"
set "regex=%~2"

call :trim filter "%~3"
if "!filter!" == "" set "filter=www.gstatic.com"

if "!regex!" == "" (
    @echo [%ESC%[97mwarning%ESC%[0m] skip update, keywords cannot empty
    goto :eof
)

set texturls=
set localfiles=

if not exist "!configfile!" goto :eof

@REM temp file
set "tempfile=!temp!\clashupdate.txt"

call :findby "!configfile!" "!regex!" "!tempfile!"
if not exist "!tempfile!" (
    @echo [%ESC%[97mwarning%ESC%[0m] ignore download file due to cannot extract config from file "!configfile!"
    goto :eof
)

@REM urls and file path
for /f "tokens=1* delims=:" %%i in ('findstr /i /r /c:"^[ ][ ]*url:[ ][ ]*http.*://.*" !tempfile!') do (
    @echo "%%j" | findstr "!filter!" >nul 2>nul || set "texturls=!texturls!,%%j"
)

for /f "tokens=1* delims=:" %%i in ('findstr /i /r /c:"^[ ][ ]*path:[ ][ ]*.*" !tempfile!') do set "localfiles=!localfiles!,%%j"

for %%u in (!texturls!) do (
    call :trim url %%u
    for /f "tokens=1* delims=," %%r in ("!localfiles!") do (
        if /i "!url:~0,8!"=="https://" (
            @REM ghproxy
            call :ghproxywrapper url !url!

            @REM generate file path
            call :pathconvert tfile %%r
            if "!tfile!" == "" (
                @echo [%ESC%[91merror%ESC%[0m] refresh error because config is invalid
                goto :eof  
            )

            @REM get directory
            call :splitpath filepath filename "!tfile!"

            @REM mkdir if not exists
            call :makedirs "!filepath!"

            @REM request and save
            curl.exe --retry 5 -m 90 --connect-timeout 15 -s -L -C - "!url!" > "!temp!\!filename!"

            @REM check file
            set "filesize=0"
            if exist "!temp!\!filename!" (
                for %%a in ("!temp!\!filename!") do set "filesize=%%~za"
            )

            if !filesize! GTR 16 (
                @REM delete if old file exists
                if exist "!tfile!" (
                    del /f /q "!tfile!" >nul 2>nul
                )
                
                @REM move new file to dest
                move "!temp!\!filename!" "!filepath!" >nul 2>nul
                
                @REM changed status 
                set "%~1=1"
            ) else (
                @echo [%ESC%[91merror%ESC%[0m] %ESC%[97m!filename!%ESC%[0m download error, link: "!url!"
            )
            
            set "localfiles=%%s"
        )
    )
)

@REM delete tempfile
if exist "!tempfile!" del /f /q "!tempfile!" >nul 2>nul
goto :eof


@REM extract dashboard path
:extractpath
if not exist "!configfile!" (
    set "dashboard="
    goto :eof
)

set "content="
for /f "tokens=*" %%i in ('findstr /i /r /c:"external-ui:[ ][ ]*" !configfile!') do set "content=%%i"

@REM not found 'external-ui' configuration in config file
if "!content!" == "" (
    set "dashboard="
    goto :eof
)

for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"external-ui:[ ][ ]*" !configfile!') do (
    call :trim uikey "%%a"

    @REM commented
    if /i "!uikey:~0,1!"=="#" (
        set "dashboard="
        goto :eof
    )

    call :trim dashboard "%%b"
)
goto :eof


@REM upgrade dashboard
:dashboardupdate
if "!dashboardurl!" == "" (
    @echo [%ESC%[95minfo%ESC%[0m] %ESC%[97mskip%ESC%[0m update dashboard because it's %ESC%[97mnot enabled%ESC%[0m
    goto :eof
)

call :pathconvert directory "!dashboard!"
if "!directory!" == "" (
    @echo [%ESC%[91merror%ESC%[0m] parse dashboard directory error, dashboard: "!dashboard!"
    goto :eof
)

call :makedirs "!directory!"

@echo [%ESC%[95minfo%ESC%[0m] start download and upgrading the dashboard
curl.exe --retry 5 -m 120 --connect-timeout 20 -s -L -C - -o "!temp!\dashboard.zip" "!dashboardurl!"

if not exist "!temp!\dashboard.zip" (
    @echo [%ESC%[97mwarning%ESC%[0m] fail to download dashboard, link: "!dashboardurl!"
    goto :eof
)

@REM unzip
tar -xzf "!temp!\dashboard.zip" -C !temp!
del /f /q "!temp!\dashboard.zip" >nul 2>nul

@REM base path and directory name
call :splitpath dashpath dashname "!directory!"
if "!dashpath!" == "" (
    @echo [%ESC%[91merror%ESC%[0m] cannot extract base path for dashboard
    goto :eof
)

if "!dashname!" == "" (
    @echo [%ESC%[91merror%ESC%[0m] cannot extract dashboard directory name
    goto :eof
)

@REM rename
ren "!temp!\!dashdirectory!" !dashname!

@REM replace if dashboard download success
dir /a /s /b "!temp!\!dashname!" | findstr . >nul && (
    call :replacedir "!temp!\!dashname!" "!directory!"
    @echo [%ESC%[95minfo%ESC%[0m] dashboard has been updated to the latest version
) || (
    @echo [%ESC%[97mwarning%ESC%[0m] occur error when download dashboard, link: "!dashboardurl!"
)
goto :eof


@REM overwrite files
:replacedir <src> <dest>
set "src=%~1"
set "target=%~2"

if "!src!" == "" (
    @echo [%ESC%[97mwarning%ESC%[0m] skip to replace files because resource path is empty
    goto :eof
)

if "!target!" == "" (
    @echo [%ESC%[97mwarning%ESC%[0m] skip to replace files because destination path is empty
    goto :eof
)

if not exist "!src!" (
    @echo [%ESC%[91merror%ESC%[0m] overwrite files error, directory not exist, resource: "!src!"
    goto :eof  
)

@REM delete old folder if exists
if exist "!target!" rd "!target!" /s /q >nul 2>nul

@REM copy to dest
xcopy "!src!" "!target!" /h /e /y /q /i >nul 2>nul

@REM delete source dashboard
rd "!src!" /s /q >nul 2>nul
goto :eof


@REM delete if file exists
:cleanworkspace
set "directory=%~1"
if "!directory!" == "" set "directory=!temp!"

if exist "!directory!\clash.zip" del /f /q "!directory!\clash.zip" 
if exist "!directory!\clash.exe" del /f /q "!directory!\clash.exe"

@REM wintun
if exist "!directory!\wintun.zip" del /f /q "!directory!\wintun.zip"
if exist "!directory!\wintun" rd "!directory!\wintun" /s /q

if "!clashexe!" NEQ "" (
    if exist "!directory!\!clashexe!" del /f /q "!directory!\!clashexe!"
)

if "!countryfile!" NEQ "" (
    if exist "!directory!\!countryfile!" del /f /q "!directory!\!countryfile!"
)

if "!geositefile!" NEQ "" (
    if exist "!directory!\!geositefile!" del /f /q "!directory!\!geositefile!"
)

if "!geoipfile!" NEQ "" (
    if exist "!directory!\!geoipfile!" del /f /q "!directory!\!geoipfile!"
)

@REM delete directory
if "!dashdirectory!" NEQ "" (
    if exist "!directory!\!dashdirectory!" rd "!directory!\!dashdirectory!" /s /q
)

if "!dashboard!" == "" goto :eof
if exist "!directory!\!dashboard!.zip" del /f /q "!directory!\!dashboard!.zip"
if exist "!directory!\!dashboard!" rd "!directory!\!dashboard!" /s /q
goto :eof


@REM replace '\\' to '\' for directory 
:pathregular <result> <directory>
set "%~1="
call :trim directory "%~2"

if "!directory!" == "" goto :eof

@REM '\\' to '\'
set "directory=!directory:\\=\!"

@REM '/' to '\'
set "directory=!directory:/=\!"

@REM remove last '\'
if "!directory:~-1!" == "\" set "directory=!directory:~0,-1!"
set "%~1=!directory!"
goto :eof


@REM define exit function
:terminate
@echo [%ESC%[91merror%ESC%[0m] update failed, file clash.exe Country.mmdb or dashboard missing
call :cleanworkspace "!temp!"
exit /b 1
goto :eof


@REM close
:closeproxy
call :isrunning status
if "!status!" == "0" (
    @echo [%ESC%[95minfo%ESC%[0m] no need to kill because network proxy %ESC%[97mis not running%ESC%[0m
    goto :eof
)

choice /t 6 /d y /n /m "[%ESC%[97mwarning%ESC%[0m] this action will close network proxy, do you want to continue (%ESC%[97mY%ESC%[0m/%ESC%[97mN%ESC%[0m)? "
if !errorlevel! == 2 exit /b 1
goto :killprocesswrapper

@REM output with color
:setESC
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do (
  set ESC=%%b
  exit /B 0
)
exit /B 0

endlocal