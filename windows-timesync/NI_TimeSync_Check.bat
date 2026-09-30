@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Windows Time Sync Check Tool - Nihon Infractal Inc.

rem ==================================================
rem  Windows Time Sync Check Tool  v1.1  (2026-09-30)
rem  Nihon Infractal Inc.
rem
rem  This tool only checks. It does not change anything.
rem  Run this tool as administrator.
rem  (Right-click the file and choose "Run as administrator".)
rem ==================================================

set "KEY_P=HKLM\SYSTEM\CurrentControlSet\Services\W32Time\Parameters"
set "KEY_C=HKLM\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient"

echo ==================================================
echo  Windows Time Sync Check Tool  v1.1
echo  Nihon Infractal Inc.
echo ==================================================
echo  This tool checks the time settings of this PC.
echo  It does not change anything.
echo.

rem ---------- Administrator check ----------
net session >nul 2>&1
if errorlevel 1 goto :NoAdmin

echo  Checking...
echo.

rem ---------- Service ----------
set "J_RUN=NG"
sc query w32time | findstr /i "RUNNING" >nul && set "J_RUN=OK"
set "J_AUTO=NG"
sc qc w32time | findstr /i "AUTO_START" >nul && set "J_AUTO=OK"

rem ---------- Settings ----------
set "CUR_TYPE="
for /f "tokens=2,*" %%a in ('reg query "%KEY_P%" /v Type 2^>nul ^| findstr /i "REG_SZ"') do set "CUR_TYPE=%%b"
set "CUR_NTP="
for /f "tokens=2,*" %%a in ('reg query "%KEY_P%" /v NtpServer 2^>nul ^| findstr /i "REG_SZ"') do set "CUR_NTP=%%b"
set "CUR_SPI="
for /f "tokens=2,*" %%a in ('reg query "%KEY_C%" /v SpecialPollInterval 2^>nul ^| findstr /i "REG_DWORD"') do set /a CUR_SPI=%%b

set "NTP_IP="
if defined CUR_NTP for /f "tokens=1 delims=, " %%a in ("!CUR_NTP!") do set "NTP_IP=%%a"

set "J_TYPE=NG"
if /i "!CUR_TYPE!"=="NTP" set "J_TYPE=OK"
set "J_NTP=NG"
if defined NTP_IP if /i "!CUR_NTP!"=="!NTP_IP!,0x9" set "J_NTP=OK"
set "J_SPI=NG"
if "!CUR_SPI!"=="1024" set "J_SPI=OK"

rem ---------- Time source ----------
set "SRC=service is not running"
set "J_SRC=NG"
if "%J_RUN%"=="OK" for /f "delims=" %%a in ('w32tm /query /source 2^>nul') do set "SRC=%%a"
if defined NTP_IP (
  set "TMP=!SRC:%NTP_IP%=!"
  if not "!TMP!"=="!SRC!" set "J_SRC=OK"
)

rem ---------- Total ----------
set "ALL=OK"
for %%v in (J_RUN J_AUTO J_TYPE J_NTP J_SPI J_SRC) do if not "!%%v!"=="OK" set "ALL=NG"

echo --------------------------------------------------
echo  Result
echo --------------------------------------------------
echo  [!J_RUN!] Service is running
echo  [!J_AUTO!] Service starts automatically
echo  [!J_TYPE!] Sync type     : !CUR_TYPE!
echo  [!J_NTP!] NTP server    : !CUR_NTP!
echo  [!J_SPI!] Sync interval : !CUR_SPI! sec
echo  [!J_SRC!] Time source   : !SRC!
echo.
echo  Correct values:
echo    Sync type     = NTP
echo    NTP server    = IP address,0x9   Example: 192.168.1.1,0x9
echo    Sync interval = 1024 sec
echo    Time source   = the same IP address as NTP server
echo.

echo --------------------------------------------------
echo  Last sync status
echo --------------------------------------------------
if "%J_RUN%"=="OK" (
  w32tm /query /status
) else (
  echo  Service is not running.
)
echo.

echo --------------------------------------------------
echo  Time difference between this PC and NTP server
echo --------------------------------------------------
if defined NTP_IP (
  w32tm /stripchart /computer:%NTP_IP% /samples:3 /dataonly
) else (
  echo  NTP server is not set.
)
echo.

echo ==================================================
if "%ALL%"=="OK" goto :AllOK
echo  Some items are NG.
echo  To fix them, run NI_TimeSync_Setup.bat
echo  as administrator.
echo.
echo  Note: Just after the service starts,
echo  "Time source" can be NG for a short time.
echo  Wait a few minutes and check again.
goto :Finish

:AllOK
echo  All items are OK.

:Finish
echo ==================================================
echo.
if /i not "%~1"=="nopause" pause
endlocal
exit /b 0

:NoAdmin
echo  ERROR: This tool needs administrator rights.
echo.
echo  1. Copy this file to the Desktop of this PC.
echo  2. Right-click the file.
echo  3. Choose "Run as administrator".
echo.
if /i not "%~1"=="nopause" pause
endlocal
exit /b 1
