@echo off
:: JAVM initialization hook for Command Prompt
:: Automatically exposes the javm command and loads the default Java version
:: This file is sourced by cmd.exe when the shell starts

set "JAVM_HOME=%~dp0"
if "%JAVM_HOME:~-1%"=="\" set "JAVM_HOME=%JAVM_HOME:~0,-1%"

if not defined JAVM_PATH_BASE set "JAVM_PATH_BASE=%PATH%"

doskey javm="%JAVM_HOME%\javm.cmd" $*

if exist "%JAVM_HOME%\default" (
  set /p __JAVM_DEFAULT=<"%JAVM_HOME%\default"
  if not "%__JAVM_DEFAULT%"=="" (
    call "%JAVM_HOME%\javm.cmd" use %__JAVM_DEFAULT% >nul 2>nul
  )
)
set "__JAVM_DEFAULT="
