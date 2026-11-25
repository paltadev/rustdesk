#!/usr/bin/env bash
# Publica un Release ya compilado por GitHub Actions como la versión que bajan los clientes.
# Uso (en la PC, con gh logueado como paltadev):  palta/publicar.sh v1.5.3
#
# 1. Baja el instalador de Windows que dejó el build (rustdesk-<ver>-x86_64.exe).
# 2. Lo vuelve a subir con nombre fijo (PaltaPC-Remoto.exe) + su .sha256 + instalar.ps1.
# 3. Saca el Release de pre-release y lo marca como «Latest».
# Así https://github.com/paltadev/rustdesk/releases/latest/download/... siempre apunta a lo último
# y el comando de los clientes (irm https://paltapc.com/remoto | iex) nunca cambia.
set -euo pipefail

REPO=paltadev/rustdesk
TAG=${1:?Uso: $0 vX.Y.Z}
VER=${TAG#v}; VER=${VER%-*}   # v1.5.3-1 (recompilación de la misma versión) → los assets se llaman rustdesk-1.5.3-…
AQUI=$(cd "$(dirname "$0")" && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "> Bajando rustdesk-$VER-x86_64.exe de $TAG..."
gh release download "$TAG" -R "$REPO" -p "rustdesk-$VER-x86_64.exe" -D "$TMP"
cp "$TMP/rustdesk-$VER-x86_64.exe" "$TMP/PaltaPC-Remoto.exe"

# Controles mínimos: que sea un ejecutable de Windows y que traiga la marca Palta PC.
[ "$(head -c2 "$TMP/PaltaPC-Remoto.exe")" = MZ ] || { echo "No es un .exe de Windows" >&2; exit 1; }
TAM=$(stat -c %s "$TMP/PaltaPC-Remoto.exe")
[ "$TAM" -gt 10000000 ] || { echo "El .exe es demasiado chico ($TAM bytes)" >&2; exit 1; }

(cd "$TMP" && sha256sum PaltaPC-Remoto.exe > PaltaPC-Remoto.exe.sha256)
cp "$AQUI/instalar.ps1" "$TMP/instalar.ps1"
LC_ALL=C grep -qP '[^\x00-\x7F]' "$TMP/instalar.ps1" && { echo "instalar.ps1 tiene caracteres no ASCII" >&2; exit 1; }

echo "> Subiendo PaltaPC-Remoto.exe, .sha256 e instalar.ps1..."
gh release upload "$TAG" -R "$REPO" --clobber \
  "$TMP/PaltaPC-Remoto.exe" "$TMP/PaltaPC-Remoto.exe.sha256" "$TMP/instalar.ps1"

echo "> Marcando $TAG como Latest..."
gh release edit "$TAG" -R "$REPO" --prerelease=false --latest

echo "> Comprobando la descarga pública..."
BASE=https://github.com/$REPO/releases/latest/download
curl -fsSL "$BASE/PaltaPC-Remoto.exe.sha256"
curl -fsSL "$BASE/PaltaPC-Remoto.exe" -o "$TMP/bajado.exe"
(cd "$TMP" && sha256sum bajado.exe | cut -d' ' -f1) | grep -qf <(cut -d' ' -f1 "$TMP/PaltaPC-Remoto.exe.sha256") \
  && echo "OK: latest = $TAG, SHA-256 coincide."
