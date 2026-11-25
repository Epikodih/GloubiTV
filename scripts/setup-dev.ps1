# Installe l'environnement de dev (Windows) : Flutter à la version de la CI
# (fixée dans .fvmrc, installée par fvm dans .fvm\), puis vérifie Rust.
# Relançable sans risque. fvm crée un lien symbolique : activer le « Mode
# développeur » de Windows (Paramètres > Système > Pour les développeurs).
#
#   just setup        (ou : powershell -ExecutionPolicy Bypass -File scripts\setup-dev.ps1)
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

$version = (Get-Content .fvmrc -Raw | ConvertFrom-Json).flutter
Write-Host "==> Flutter $version (fvm)"
if (-not (Get-Command fvm -ErrorAction SilentlyContinue)) {
  if (Get-Command choco -ErrorAction SilentlyContinue) {
    choco install fvm -y
  } elseif (Get-Command dart -ErrorAction SilentlyContinue) {
    dart pub global activate fvm
    $env:Path += ";$env:LOCALAPPDATA\Pub\Cache\bin"
  } else {
    throw 'Installe fvm : https://fvm.app/documentation/getting-started/installation'
  }
}
# Télécharge la version si besoin et crée .fvm\flutter_sdk (utilisé par just).
fvm use $version --force
& .fvm\flutter_sdk\bin\flutter.bat --version | Select-Object -First 1

Write-Host '==> Rust'
if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
  throw 'Installe Rust : https://rustup.rs'
}
cargo --version

Write-Host '==> Prêt : just core, puis just tv'
