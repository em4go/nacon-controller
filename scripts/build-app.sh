#!/bin/bash
# Builds a runnable NaconDiagnostics.app bundle from the Swift package.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIGURATION="${1:-release}"
swift build -c "$CONFIGURATION" --product NaconDiagnostics
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"

APP_DIR="build/NaconDiagnostics.app"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp "$BIN_DIR/NaconDiagnostics" "$APP_DIR/Contents/MacOS/NaconDiagnostics"

# SwiftPM writes the processed resources of a target as `<paquete>_<target>.bundle` next to the
# executable, and `Bundle.module` looks for exactly that name. This package is `NaconController`, so
# the bundles are `NaconController_NaconDiagnostics.bundle` (the drawing) and
# `NaconController_NaconCore.bundle` (the string catalog); the glob keeps the script working if the
# package or a target is renamed. Every target that ships resources needs its bundle here, or
# `Bundle.module` finds nothing at run time and the lookup silently falls back to the key. The copy
# happens before signing so the seal covers the bundles.
mkdir -p "$RESOURCES_DIR"
for TARGET in NaconDiagnostics NaconCore; do
    RESOURCE_BUNDLES=("$BIN_DIR"/*_"$TARGET".bundle)
    if [ "${#RESOURCE_BUNDLES[@]}" -ne 1 ] || [ ! -d "${RESOURCE_BUNDLES[0]}" ]; then
        echo "error: no se encontró el bundle de recursos (*_$TARGET.bundle) en $BIN_DIR." >&2
        echo "       Sin él la app arranca sin sus recursos (dibujo o catálogo de texto), así que se aborta." >&2
        exit 1
    fi
    RESOURCE_BUNDLE="${RESOURCE_BUNDLES[0]}"
    # `rm -rf "$APP_DIR"` above already drops a previous copy; removing the destination explicitly
    # keeps a second run from nesting a bundle inside a bundle even if that cleanup changes.
    rm -rf "${RESOURCES_DIR:?}/$(basename "$RESOURCE_BUNDLE")"
    cp -R "$RESOURCE_BUNDLE" "$RESOURCES_DIR/"
done

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>NaconDiagnostics</string>
    <key>CFBundleDisplayName</key><string>NACON Diagnostics</string>
    <key>CFBundleIdentifier</key><string>dev.nacon.diagnostics</string>
    <!-- Sin esto la app se anuncia en un solo idioma y toda consulta al catálogo cae al texto base:
         el sistema no puede elegir español porque el bundle no declara que lo hable. -->
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleLocalizations</key><array><string>en</string><string>es</string></array>
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
