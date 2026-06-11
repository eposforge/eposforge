@echo off
setlocal

set "WORKSPACE=D:\src\git\gh\eposforge\eposforge"
set "NPX=C:\Progra~1\nodejs\npx.cmd"

cd /d "%WORKSPACE%"
"%NPX%" -y @google/gemini-cli --include-directories "%WORKSPACE%"
set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
  echo.
  echo Gemini exited with code %EXITCODE%.
  pause
)

exit /b %EXITCODE%
