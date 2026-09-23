# Compilar APK release firmado (requerido por la licencia 3DiVi).
# Apunta a QA mientras se validan pruebas en dispositivo.

param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d{6}$')]
    [string]$KioskAdminPin,
    [string]$ApiBaseUrl = "http://ec2-54-237-104-7.compute-1.amazonaws.com:8080/nova"
)

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Write-Host "APP_ENV=qa API_BASE_URL=$ApiBaseUrl" -ForegroundColor Cyan
Write-Host "Modo=release (firma keys/horas-hombre-release.jks)" -ForegroundColor Cyan

flutter build apk --release `
    --dart-define=APP_ENV=qa `
    --dart-define=API_BASE_URL=$ApiBaseUrl `
    --dart-define=KIOSK_ADMIN_PIN=$KioskAdminPin
