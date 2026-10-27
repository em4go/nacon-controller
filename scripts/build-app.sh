#!/bin/bash
# Builds a runnable NaconDiagnostics.app bundle from the Swift package.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIGURATION="${1:-release}"
swift build -c "$CONFIGURATION" --product NaconDiagnostics
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"

APP_DIR="build/NaconDiagnostics.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp "$BIN_DIR/NaconDiagnostics" "$APP_DIR/Contents/MacOS/NaconDiagnostics"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>NaconDiagnostics</string>
    <key>CFBundleDisplayName</key><string>NACON Diagnostics</string>
    <key>CFBundleIdentifier</key><string>dev.nacon.diagnostics</string>
    <key>CFBundleExecutable</key><string>NaconDiagnostics</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

IDENTITY="NACON Local Signing"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
    codesign --force --sign "$IDENTITY" --timestamp=none "$APP_DIR"
    echo "Firmado con la identidad local '$IDENTITY' (el permiso sobrevive a las recompilaciones)."
else
    codesign --force --sign - "$APP_DIR" >/dev/null 2>&1 || echo "warning: ad-hoc signing skipped"
    echo "AVISO: firmado ad-hoc. Cada recompilación invalidará el permiso de Accesibilidad."
    echo "       Ejecuta ./scripts/setup-signing-identity.sh una vez para evitarlo."
fi
echo "Built $APP_DIR"
