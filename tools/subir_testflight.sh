#!/bin/bash
# Sube la IPA ARCHIVADA de Minesweeper a App Store Connect (TestFlight).
#
#   bash tools/subir_testflight.sh <build>
#
# Molde: ~/.appstoreconnect/nona-upload-testflight.sh. Las mismas dos
# decisiones, por los mismos motivos:
# - Sube desde ~/Minesweeper-releases, no desde app/build: lo que se sube es lo
#   que quedó archivado con su sha256, nunca un fichero de ruta fija que la
#   build siguiente pisa sin avisar.
# - Mira DENTRO de la IPA el bundle id y el número de build antes de subir: un
#   número equivocado sube bien y luego no se puede adjuntar a la versión, y
#   App Store Connect no deja repetir número nunca más.
# La llave es la del equipo SENDA (VC5Y48T3Z4, en
# ~/.appstoreconnect/private_keys/, fuera de git), la misma de Nona y CINCO.
set -euo pipefail
N="${1:-}"
[ -z "$N" ] && { echo "uso: subir_testflight.sh <build>"; exit 2; }
IPA="$(ls "$HOME"/Minesweeper-releases/minesweeper-*-"$N".ipa 2>/dev/null | head -1 || true)"
[ -z "$IPA" ] && { echo "NO ESTÁ ARCHIVADA la IPA de la build $N en ~/Minesweeper-releases"; exit 1; }
( cd "$HOME/Minesweeper-releases" && grep "$(basename "$IPA")" ./*-"$N".sha256 | shasum -a 256 -c - ) \
  || { echo "LA IPA NO COINCIDE CON SU .sha256 — no subo"; exit 1; }
PL="$(unzip -p "$IPA" 'Payload/*.app/Info.plist' | plutil -p -)"
BID="$(awk -F'"' '/"CFBundleIdentifier"/{print $4}' <<<"$PL")"
VC="$(awk -F'"' '/"CFBundleVersion"/{print $4}' <<<"$PL")"
SV="$(awk -F'"' '/"CFBundleShortVersionString"/{print $4}' <<<"$PL")"
echo "IPA: $IPA  ($BID $SV build $VC)"
[ "$BID" != "com.sendallc.minesweeper" ] && { echo "ESA IPA NO ES DE MINESWEEPER ($BID)"; exit 1; }
[ "$VC" != "$N" ] && { echo "CFBundleVersion $VC != $N — no subo"; exit 1; }
xcrun altool --upload-app --type ios --file "$IPA" \
  --apiKey VC5Y48T3Z4 --apiIssuer 3369eaea-1a5c-45c4-b2a0-b84d20215436
