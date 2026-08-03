#!/bin/bash
# TypeR web installer (macOS)
# Usage : curl -fsSL https://typer.hayasaku.fr/install.sh | bash
set -euo pipefail

if [ "$(uname)" != "Darwin" ]; then
    echo "This installer is for macOS. On Windows, run:" >&2
    echo "  irm https://typer.hayasaku.fr/install.ps1 | iex" >&2
    exit 1
fi

LANG_CODE="${LANG:-en}"
fr() { case "$LANG_CODE" in fr*) return 0 ;; *) return 1 ;; esac; }

echo ""
echo "+------------------------------------------------------------------+"
echo "|                          TypeR Installer                         |"
echo "+------------------------------------------------------------------+"
echo ""

# --- 1. Dernière release GitHub ---
if fr; then echo "Récupération des informations de la dernière version..."; else echo "Fetching latest release info..."; fi
RELEASE_JSON="$(curl -fsSL https://api.github.com/repos/ScanR/TypeR/releases/latest)"
VERSION="$(printf '%s' "$RELEASE_JSON" | grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed -E 's/.*"(v?[^"]+)"$/\1/' | sed 's/^v//')"

# Uniquement un asset compilé TypeR*.zip : le zip "Source code" ne contient
# pas le dossier app/ généré par webpack et donnerait une installation cassée
DOWNLOAD_URL="$(printf '%s' "$RELEASE_JSON" \
    | grep -oE '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]+"' \
    | grep -iE 'typer[^"]*\.zip"' | head -1 | sed -E 's/.*"(https[^"]+)"$/\1/')"

if [ -z "$DOWNLOAD_URL" ]; then
    if fr; then echo "Aucune archive TypeR trouvée dans la dernière release." >&2; else echo "No TypeR zip found in the latest release." >&2; fi
    echo "https://github.com/ScanR/TypeR/releases/latest" >&2
    exit 1
fi

# --- 2. Téléchargement + extraction ---
WORK_DIR="$(mktemp -d /tmp/typer_webinstall.XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

if fr; then echo "Téléchargement de TypeR v$VERSION..."; else echo "Downloading TypeR v$VERSION..."; fi
curl -fsSL -o "$WORK_DIR/TypeR.zip" "$DOWNLOAD_URL"

if fr; then echo "Extraction..."; else echo "Extracting..."; fi
unzip -o -q "$WORK_DIR/TypeR.zip" -d "$WORK_DIR/extracted"

# Racine de l'extension = dossier parent de CSXS/manifest.xml
MANIFEST="$(find "$WORK_DIR/extracted" -type f -path '*/CSXS/manifest.xml' | head -1)"
if [ -z "$MANIFEST" ]; then
    if fr; then echo "Archive invalide : CSXS/manifest.xml introuvable." >&2; else echo "Invalid package: CSXS/manifest.xml not found." >&2; fi
    exit 1
fi
SOURCE_ROOT="$(dirname "$(dirname "$MANIFEST")")"

# --- 3. PlayerDebugMode ---
for i in $(seq 6 18); do
    defaults write "com.adobe.CSXS.$i" PlayerDebugMode 1 2>/dev/null || true
done

# --- 4. Installation ---
# On ne remplace que les dossiers applicatifs : les réglages de
# l'utilisateur (storage*) ne sont jamais touchés
TARGET_DIR="$HOME/Library/Application Support/Adobe/CEP/extensions/typertools"
mkdir -p "$TARGET_DIR"

if fr; then echo "Installation..."; else echo "Installing..."; fi
for folder in app CSXS icons locale; do
    if [ -d "$SOURCE_ROOT/$folder" ]; then
        rm -rf "$TARGET_DIR/$folder"
        cp -R "$SOURCE_ROOT/$folder" "$TARGET_DIR/$folder"
    fi
done
if [ -d "$SOURCE_ROOT/themes" ]; then
    mkdir -p "$TARGET_DIR/app/themes"
    cp -R "$SOURCE_ROOT/themes/." "$TARGET_DIR/app/themes/"
fi

# --- 5. Fin ---
echo ""
if fr; then echo "TypeR v$VERSION installé avec succès !"; else echo "TypeR v$VERSION installed successfully!"; fi
if pgrep -f "Adobe Photoshop.app/Contents/MacOS" >/dev/null 2>&1; then
    if fr; then echo "Redémarrez Photoshop, puis ouvrez [Fenêtre] > [Extensions] > [TypeR]."; else echo "Restart Photoshop, then open [Window] > [Extensions] > [TypeR]."; fi
else
    if fr; then echo "Ouvrez Photoshop, puis [Fenêtre] > [Extensions] > [TypeR]."; else echo "Open Photoshop, then [Window] > [Extensions] > [TypeR]."; fi
fi
echo ""
