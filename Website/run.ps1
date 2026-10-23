Set-Location -LiteralPath $PSScriptRoot
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Starting VertivEra Admin Console..." -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Node.js is not found in your PATH." -ForegroundColor Red
    Write-Host "Please install Node.js from https://nodejs.org/ to run the server." -ForegroundColor Yellow
    exit 1
}

node server.js

