# Ejecutar release en dispositivo (requerido por la licencia 3DiVi) contra QA.

param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d{6}$')]
    [string]$KioskAdminPin,
    [string]$ApiBaseUrl = "http://ec2-54-237-104-7.compute-1.amazonaws.com:8080/nova",
    [string]$DeviceId = ""
)

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Write-Host "APP_ENV=qa API_BASE_URL=$ApiBaseUrl" -ForegroundColor Cyan
Write-Host "Modo=release Licencia 3DiVi=assets/license/3divi_face_sdk.lic" -ForegroundColor Cyan

$flutterArgs = @(
    "run",
    "--release",
    "--dart-define=APP_ENV=qa",
    "--dart-define=API_BASE_URL=$ApiBaseUrl",
    "--dart-define=KIOSK_ADMIN_PIN=$KioskAdminPin"
)
if ($DeviceId) {
    $flutterArgs += "-d", $DeviceId
}

flutter @flutterArgs
