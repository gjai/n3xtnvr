#!/usr/bin/env bash
# Dépendances optionnelles pour développement / diagnostic (Apple Silicon, Homebrew).
set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew non trouvé. Installez-le depuis https://brew.sh puis relancez ce script."
  exit 1
fi

ARCH="$(uname -m)"
if [[ "${ARCH}" != "arm64" ]]; then
  echo "Attention : ce script vise Apple Silicon (arm64). Machine détectée : ${ARCH}"
fi

echo "Installation de ffmpeg (ffplay/ffprobe) pour tests RTSP en ligne de commande…"
brew list ffmpeg >/dev/null 2>&1 || brew install ffmpeg

echo "Pour tester un flux RTSP manuellement :"
echo '  ffplay -rtsp_transport tcp "rtsp://user:pass@192.168.1.100:554/cam/realmonitor?channel=1&subtype=0"'
echo
echo "Terminé. Ouvrez N3xtNVR.xcodeproj dans Xcode et compilez (⌘B)."
