# Script PowerShell per codificare il keystore in base64
# Questo script aiuta a preparare il segreto KEYSTORE_FILE per GitHub

param(
    [Parameter(Mandatory=$true)]
    [string]$KeystorePath
)

if (-not (Test-Path $KeystorePath)) {
    Write-Host "Errore: File non trovato: $KeystorePath" -ForegroundColor Red
    exit 1
}

try {
    $fileContent = [Convert]::ToBase64String([IO.File]::ReadAllBytes($KeystorePath))
    Write-Host "✓ Keystore codificato con successo" -ForegroundColor Green
    Write-Host ""
    Write-Host "Copia il valore qui sotto e incollalo come segreto KEYSTORE_FILE su GitHub:" -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Gray
    Write-Host $fileContent
    Write-Host "================================================================================" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Istruzioni:" -ForegroundColor Yellow
    Write-Host "1. Vai su: https://github.com/YOUR_OWNER/YOUR_REPO/settings/secrets/actions"
    Write-Host "2. Clicca 'New repository secret'"
    Write-Host "3. Name: KEYSTORE_FILE"
    Write-Host "4. Value: (incolla il contenuto qui sopra)"
    Write-Host "5. Clicca 'Add secret'"
}
catch {
    Write-Host "Errore durante la codifica: $_" -ForegroundColor Red
    exit 1
}
