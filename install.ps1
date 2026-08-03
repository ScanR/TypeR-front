# TypeR web installer (Windows)
# Usage : irm https://typer.hayasaku.fr/install.ps1 | iex
# Pas de param() ni de exit : le script doit rester compatible avec iex
# (param y est illégal, exit fermerait le shell de l'utilisateur)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {}

$script:TyperLang = "en"
try { $script:TyperLang = (Get-Culture).TwoLetterISOLanguageName } catch {}

function TyperMsg($en, $fr) {
    if ($script:TyperLang -eq "fr") { return $fr }
    return $en
}

function Install-TypeR {
    Write-Host ""
    Write-Host "+------------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "|                          TypeR Installer                         |" -ForegroundColor Cyan
    Write-Host "+------------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""

    # --- 1. Derniere release GitHub ---
    Write-Host (TyperMsg "Fetching latest release info..." "Recuperation des informations de la derniere version...")
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/ScanR/TypeR/releases/latest" -UseBasicParsing
    $version = "$($release.tag_name)" -replace '^v', ''

    # Uniquement un asset compile TypeR*.zip : le zip "Source code" ne contient
    # pas le dossier app/ genere par webpack et donnerait une installation cassee
    $asset = @($release.assets | Where-Object { $_.name -match '(?i)typer.*\.zip$' }) | Select-Object -First 1
    if (-not $asset) {
        throw (TyperMsg "No TypeR zip found in the latest release." "Aucune archive TypeR trouvee dans la derniere release.")
    }

    # --- 2. Telechargement + extraction dans le TEMP ---
    $workDir = Join-Path $env:TEMP "TypeR_WebInstall"
    if (Test-Path $workDir) { Remove-Item $workDir -Recurse -Force }
    New-Item -Path $workDir -ItemType Directory -Force | Out-Null
    $zipPath = Join-Path $workDir "TypeR.zip"

    Write-Host ((TyperMsg "Downloading TypeR v{0}..." "Telechargement de TypeR v{0}...") -f $version)
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing

    Write-Host (TyperMsg "Extracting..." "Extraction...")
    $extractDir = Join-Path $workDir "extracted"
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

    # Racine de l'extension = dossier parent de CSXS\manifest.xml
    $manifest = Get-ChildItem -Path $extractDir -Recurse -Filter "manifest.xml" |
        Where-Object { $_.Directory.Name -eq "CSXS" } | Select-Object -First 1
    if (-not $manifest) {
        throw (TyperMsg "Invalid package: CSXS\manifest.xml not found." "Archive invalide : CSXS\manifest.xml introuvable.")
    }
    $sourceRoot = $manifest.Directory.Parent.FullName

    # --- 3. PlayerDebugMode (HKCU, pas besoin d'admin) ---
    6..18 | ForEach-Object {
        $regPath = "HKCU:\Software\Adobe\CSXS.$_"
        if (Test-Path $regPath) {
            Set-ItemProperty -Path $regPath -Name "PlayerDebugMode" -Value 1 -Type String -ErrorAction SilentlyContinue
        }
    }

    # --- 4. Installation ---
    # On ne remplace que les dossiers applicatifs : les reglages de
    # l'utilisateur (storage*) ne sont jamais touches
    $targetDir = Join-Path $env:APPDATA "Adobe\CEP\extensions\typertools"
    New-Item -Path $targetDir -ItemType Directory -Force | Out-Null

    Write-Host (TyperMsg "Installing..." "Installation...")
    foreach ($folder in @("app", "CSXS", "icons", "locale")) {
        $src = Join-Path $sourceRoot $folder
        $dst = Join-Path $targetDir $folder
        if (Test-Path $src) {
            if (Test-Path $dst) { Remove-Item $dst -Recurse -Force -ErrorAction SilentlyContinue }
            Copy-Item $src -Destination $dst -Recurse -Force
        }
    }
    $themesSrc = Join-Path $sourceRoot "themes"
    if (Test-Path $themesSrc) {
        $themesDst = Join-Path $targetDir "app\themes"
        if (-not (Test-Path $themesDst)) { New-Item $themesDst -ItemType Directory -Force | Out-Null }
        Copy-Item "$themesSrc\*" -Destination $themesDst -Recurse -Force
    }

    # --- 5. Nettoyage ---
    Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue

    # --- 6. Fin ---
    Write-Host ""
    Write-Host ((TyperMsg "TypeR v{0} installed successfully!" "TypeR v{0} installe avec succes !") -f $version) -ForegroundColor Green
    $psRunning = $false
    try { $psRunning = [bool](Get-Process -Name "Photoshop" -ErrorAction SilentlyContinue) } catch {}
    if ($psRunning) {
        Write-Host (TyperMsg "Restart Photoshop, then open [Window] > [Extensions] > [TypeR]." "Redemarrez Photoshop, puis ouvrez [Fenetre] > [Extensions] > [TypeR].") -ForegroundColor Cyan
    } else {
        Write-Host (TyperMsg "Open Photoshop, then [Window] > [Extensions] > [TypeR]." "Ouvrez Photoshop, puis [Fenetre] > [Extensions] > [TypeR].") -ForegroundColor Cyan
    }
    Write-Host ""
}

try {
    Install-TypeR
} catch {
    Write-Host ""
    Write-Host ((TyperMsg "Installation failed: {0}" "Echec de l'installation : {0}") -f $_.Exception.Message) -ForegroundColor Red
    Write-Host (TyperMsg "Manual download: https://github.com/ScanR/TypeR/releases/latest" "Telechargement manuel : https://github.com/ScanR/TypeR/releases/latest") -ForegroundColor Yellow
    Write-Host ""
}
