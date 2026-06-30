@echo off
setlocal

set "WORKSPACE=<abs-path-to-eposforge-clone-on-windows>"
set "NPX=C:\Progra~1\nodejs\npx.cmd"  # or <node-install>\npx.cmd ; adjust for your env

cd /d "%WORKSPACE%"
"%NPX%" -y @google/gemini-cli --include-directories "%WORKSPACE%"
set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
  echo.
  echo Gemini exited with code %EXITCODE%.
  pause
)

exit /b %EXITCODE%
