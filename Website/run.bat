@echo off
title VertivEra Admin Website
cd /d "%~dp0"
echo ==================================================
echo   Starting VertivEra Admin Console...
echo ==================================================
where node >nul 2>nul
if %errorlevel% neq 0 (
  echo Error: Node.js is not found in your PATH.
  echo Please install Node.js from https://nodejs.org/ to run the server.
  pause
  exit /b 1
)
node server.js
pause

