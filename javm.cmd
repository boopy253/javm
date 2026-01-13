@echo off
:: JAVM: Lightweight Java version manager for Command Prompt
::
:: Manages multiple Java installations and allows switching between them.
:: Stores registered Java versions in versions.map and tracks default version.
::
:: Commands:
::   javm list              - List all registered Java versions
::   javm add <alias> <dir> - Register a new Java installation
::   javm use <alias>       - Switch to a registered Java version
::   javm default [alias]   - View or set the default Java version
::   javm rm <alias>        - Unregister a Java version
::   javm clear             - Restore PATH and unset JAVA_HOME
::   javm current           - Display the currently active Java version

if "%JAVM_HOME%"=="" (
  set "JAVM_HOME=%~dp0"
  if "%JAVM_HOME:~-1%"=="\" set "JAVM_HOME=%JAVM_HOME:~0,-1%"
)

set "JAVM_REG=%JAVM_HOME%\versions.map"
set "JAVM_DEF=%JAVM_HOME%\default"

if not exist "%JAVM_HOME%" mkdir "%JAVM_HOME%" >nul
if not exist "%JAVM_REG%" type nul > "%JAVM_REG%" >nul
if not exist "%JAVM_DEF%" type nul > "%JAVM_DEF%" >nul

if not defined JAVM_PATH_BASE set "JAVM_PATH_BASE=%PATH%"

if /I "%~1"=="" goto :help

if /I "%~1"=="list" goto :list
if /I "%~1"=="ls" goto :list
if /I "%~1"=="add" goto :add
if /I "%~1"=="use" goto :use
if /I "%~1"=="default" goto :default
if /I "%~1"=="rm" goto :remove
if /I "%~1"=="remove" goto :remove
if /I "%~1"=="clear" goto :clear
if /I "%~1"=="current" goto :current

echo Unknown command: %1
goto :eof

:list
for /f "usebackq tokens=1,2 delims=|" %%A in ("%JAVM_REG%") do (
    if not "%%~A"=="" (
        if /I "%%~A"=="%JAVA_ENV_CURRENT%" (
            echo * %%~A    %%~B
        ) else (
            echo   %%~A    %%~B
        )
    )
)
goto :eof

:add
set "alias=%~2"
set "path=%~3"
if "%alias%"=="" (
  echo Usage: javm add ^<alias^> ^<directory^>
  goto :eof
)
if "%path%"=="" set "path=%CD%"
if not exist "%path%\bin\java.exe" (
  echo Error: java.exe not found at %path%\bin\java.exe
  goto :eof
)
set "tmp=%TEMP%\javm_%RANDOM%.tmp"
if exist "%tmp%" del "%tmp%" >nul 2>nul
findstr /R /V /C:"^%alias%|" "%JAVM_REG%" > "%tmp%" 2>nul
>> "%tmp%" echo %alias%^|%path%
move /y "%tmp%" "%JAVM_REG%" >nul
echo Registered: %alias% -^> %path%
goto :eof

:remove
set "alias=%~2"
if "%alias%"=="" (
  echo Usage: javm rm ^<alias^>
  goto :eof
)
set "tmp=%TEMP%\javm_%RANDOM%.tmp"
findstr /R /V /C:"^%alias%|" "%JAVM_REG%" > "%tmp%" 2>nul
move /y "%tmp%" "%JAVM_REG%" >nul
if /I "%JAVA_ENV_CURRENT%"=="%alias%" call :clear >nul
echo Removed: %alias%
goto :eof

:use
set "alias=%~2"
if "%alias%"=="" (
  echo Usage: javm use ^<alias^>
  goto :eof
)
set "found="
for /f "usebackq tokens=1,2 delims=|" %%A in ("%JAVM_REG%") do (
  if /I "%%~A"=="%alias%" (
    set "JAVA_HOME=%%~B"
    set "JAVA_ENV_CURRENT=%%~A"
    set "found=1"
  )
)
if not defined found (
  echo Error: Unknown alias: %alias%
  goto :eof
)
set "PATH=%JAVA_HOME%\bin;%JAVM_PATH_BASE%"
echo Now using %JAVA_ENV_CURRENT% (%JAVA_HOME%)
goto :eof

:default
if "%~2"=="" (
  if exist "%JAVM_DEF%" type "%JAVM_DEF%" else echo (not set)
  goto :eof
)
> "%JAVM_DEF%" echo %~2
call "%~f0" use %~2
goto :eof

:clear
set "PATH=%JAVM_PATH_BASE%"
set "JAVA_HOME="
set "JAVA_ENV_CURRENT="
goto :eof

:current
if defined JAVA_ENV_CURRENT (
  echo %JAVA_ENV_CURRENT% -^> %JAVA_HOME%
) else if defined JAVA_HOME (
  echo (external) -^> %JAVA_HOME%
) else (
  echo (not selected)
)
goto :eof

:help
echo Usage: javm ^<command^>
echo.
echo Commands:
echo   list                    - List registered Java versions
echo   add ^<alias^> ^<dir^>   - Register a Java installation
echo   use ^<alias^>           - Switch to a Java version
echo   default [alias]         - View or set default version
echo   rm ^<alias^>            - Unregister a Java version
echo   clear                   - Clear PATH and JAVA_HOME
echo   current                 - Show current Java version
goto :eof
