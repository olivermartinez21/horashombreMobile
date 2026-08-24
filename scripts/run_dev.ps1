# Ejecutar en modo desarrollo contra el backend en LAN.
# Ajuste $apiBaseUrl con la IP de su máquina (ipconfig).

param(
    [string]$ApiBaseUrl = "http://192.168.100.19:5000/nova",
    [string]$DeviceId = ""
)

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Write-Host "APP_ENV=dev API_BASE_URL=$ApiBaseUrl" -ForegroundColor Cyan
Write-Host "Licencia 3DiVi=assets/license/3divi_face_sdk.lic" -ForegroundColor Cyan

$flutterArgs = @(
    "run",
    "--dart-define=APP_ENV=dev",
    "--dart-define=API_BASE_URL=$ApiBaseUrl"
)
if ($DeviceId) {
    $flutterArgs += "-d", $DeviceId
}

flutter @flutterArgs
