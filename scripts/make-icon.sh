#!/usr/bin/env bash
# Renders the app icon and compiles it into Resources/AppIcon.icns
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Rendering 1024px master icon"
swift scripts/render-icon.swift /tmp/AppIcon_1024.png

echo "==> Building iconset"
ICONSET=$(mktemp -d)/AppIcon.iconset
mkdir -p "$ICONSET"
for spec in "16 16" "32 32" "32 64" "128 128" "128 256" "256 256" "256 512" "512 512" "512 1024"; do
    read -r base size <<< "$spec"
    if [ "$base" = "$size" ]; then
        name="icon_${base}x${base}.png"
    else
        name="icon_${base}x${base}@2x.png"
    fi
    sips -z "$size" "$size" /tmp/AppIcon_1024.png --out "$ICONSET/$name" >/dev/null
done

echo "==> Compiling icns"
mkdir -p Resources
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns

echo "==> Done: Resources/AppIcon.icns"
