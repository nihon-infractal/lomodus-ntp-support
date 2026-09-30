@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Windows Time Sync Setup Tool - Nihon Infractal Inc.

rem ==================================================
rem  Windows Time Sync Setup Tool  v1.1  (2026-09-30)
rem  Nihon Infractal Inc.
rem ==================================================

rem ==================================================
rem  NTP server IP address
rem
rem  Write the IP address here.
rem    Example: set DEFAULT_NTP=192.168.1.1
rem
rem  If you do not write it, this tool uses
rem  the IP address that the PC has now.
rem ==================================================
set DEFAULT_NTP=


rem ==================================================
rem  Do not change the lines below.
rem ==================================================
set "KEY_P=HKLM\SYSTEM\CurrentControlSet\Services\W32Time\Parameters"
set "KEY_C=HKLM\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient"

echo ==================================================
echo  Windows Time Sync Setup Tool  v1.1
echo  Nihon Infractal Inc.
echo ==================================================
echo  This tool sets this PC to get the correct time
echo  from the NTP server on this site.
echo.
echo  Do not use this tool on a PC in a Windows domain.
echo.

rem ---------- Administrator check ----------
net session >nul 2>&1
if errorlevel 1 goto :NoAdmin

rem ---------- Default IP address ----------
set "DEF="
if defined DEFAULT_NTP set "DEF=%DEFAULT_NTP: =%"
if defined DEF goto :AskIP
set "CUR_NTP="
for /f "tokens=2,*" %%a in ('reg query "%KEY_P%" /v NtpServer 2^>nul ^| findstr /i "REG_SZ"') do set "CUR_NTP=%%b"
if defined CUR_NTP for /f "tokens=1 delims=, " %%a in ("!CUR_NTP!") do set "DEF=%%a"
if /i "!DEF!"=="time.windows.com" set "DEF="

rem ---------- Ask IP address ----------
:AskIP
echo --------------------------------------------------
echo  Enter the IP address of the NTP server.
echo.
echo  To use the value in [ ], just press Enter.
echo  To use a different one, type it and press Enter.
echo --------------------------------------------------
set "NTP="
if defined DEF (
  set /p "NTP=NTP server IP address [!DEF!]: "
) else (
  set /p "NTP=NTP server IP address: "
)
if not defined NTP set "NTP=!DEF!"
if not defined NTP goto :NoInput
echo %NTP%| findstr /r /x "[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*" >nul
if errorlevel 1 goto :BadIP
goto :TestIP

:NoInput
echo.
echo  Please enter an IP address.
echo.
goto :AskIP

:BadIP
echo.
echo  This is not an IP address: %NTP%
echo  Example: 192.168.1.1
echo.
goto :AskIP

rem ---------- Connection test ----------
:TestIP
echo.
echo --------------------------------------------------
echo  Checking the connection to %NTP% ...
echo --------------------------------------------------
set "TMPF=%TEMP%\ni_timesync_test.txt"
w32tm /stripchart /computer:%NTP% /samples:1 /dataonly > "%TMPF%" 2>&1
type "%TMPF%"
set "REACH=OK"
findstr /c:"0x8007" "%TMPF%" >nul && set "REACH=NG"
del "%TMPF%" >nul 2>&1
echo.
if "%REACH%"=="NG" goto :NoReach

echo  The number above is the time difference
echo  between this PC and the NTP server.
echo.
echo  *** WARNING ***
echo  If you continue, the clock of this PC will be
echo  corrected at once. If the difference is large,
echo  the clock will jump. This can affect the logs
echo  of SCADA and other software.
echo.
choice /c YN /m " Continue"
if errorlevel 2 goto :Cancel
goto :Apply

:NoReach
echo  *** ERROR ***
echo  This PC cannot connect to the NTP server.
echo  Check the IP address and the network.
echo.
echo  Choose N to stop.
echo  Choose Y only if you want to set it now
echo  and the NTP server will start later.
echo.
choice /c YN /m " Continue"
if errorlevel 2 goto :Cancel

rem ---------- Apply settings ----------
:Apply
echo.
echo --------------------------------------------------
echo  Changing settings...
echo --------------------------------------------------
set "FAIL=0"

echo  [1/6] Start the service automatically
sc config w32time start= auto >nul
if errorlevel 1 set "FAIL=1"

echo  [2/6] Sync type: NTP
reg add "%KEY_P%" /v Type /t REG_SZ /d NTP /f >nul
if errorlevel 1 set "FAIL=1"

echo  [3/6] NTP server: %NTP%,0x9
reg add "%KEY_P%" /v NtpServer /t REG_SZ /d "%NTP%,0x9" /f >nul
if errorlevel 1 set "FAIL=1"

echo  [4/6] Sync interval: 1024 sec
reg add "%KEY_C%" /v SpecialPollInterval /t REG_DWORD /d 1024 /f >nul
if errorlevel 1 set "FAIL=1"

echo  [5/6] Restart the service
net stop w32time >nul 2>&1
net start w32time >nul 2>&1
if errorlevel 1 set "FAIL=1"

if "%FAIL%"=="1" goto :Failed

echo  [6/6] Sync the clock now
set "TRY=0"
:Resync
timeout /t 5 /nobreak >nul
w32tm /resync >nul 2>&1
if not errorlevel 1 goto :SyncOK
set /a TRY+=1
if %TRY% lss 3 goto :Resync
echo.
echo  The settings are done, but the clock is not synced yet.
echo  It will sync automatically within a few minutes.
goto :Verify

:SyncOK
echo.
echo  The clock is synced.

rem ---------- Check the result ----------
:Verify
echo.
if exist "%~dp0NI_TimeSync_Check.bat" (
  call "%~dp0NI_TimeSync_Check.bat" nopause
) else (
  echo  Time source now:
  w32tm /query /source
  echo.
)
echo  Setup is finished.
echo.
pause
endlocal
exit /b 0

:Failed
echo.
echo  ERROR: Some settings could not be changed.
echo  Nothing more was done.
echo  Please check this PC and try again.
echo.
pause
endlocal
exit /b 1

:Cancel
echo.
echo  Canceled. Nothing was changed.
echo.
pause
endlocal
exit /b 0

:NoAdmin
echo  ERROR: This tool needs administrator rights.
echo.
echo  1. Copy this file to the Desktop of this PC.
echo  2. Right-click the file.
echo  3. Choose "Run as administrator".
echo.
pause
endlocal
exit /b 1
