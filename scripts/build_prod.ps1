# Compilar APK de producción.
# Ajuste $apiBaseUrl con la URL definitiva del servidor.
# La licencia 3DiVi va en assets/license/3divi_face_sdk.lic (ligada al App ID de release).

param(
    [string]$ApiBaseUrl = "https://nova.tu-dominio.com/nova"
)

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Write-Host "APP_ENV=prod API_BASE_URL=$ApiBaseUrl" -ForegroundColor Cyan

flutter build apk --release `
    --dart-define=APP_ENV=prod `
    --dart-define=API_BASE_URL=$ApiBaseUrl
