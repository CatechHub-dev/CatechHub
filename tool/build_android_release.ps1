# Build APK Android ottimizzato: offuscazione Dart, split ABI, tree-shake icone.
# Esegui dalla root del progetto: .\tool\build_android_release.ps1

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

Write-Host "Pub get..."
flutter pub get

Write-Host "Build release (obfuscate + split per ABI)..."
flutter build apk --release `
  --obfuscate `
  --split-debug-info=build/debug-info `
  --split-per-abi `
  --tree-shake-icons

Write-Host ""
Write-Host "APK in build/app/outputs/flutter-apk/"
Write-Host "Simboli debug (conservali per crash report): build/debug-info/"
