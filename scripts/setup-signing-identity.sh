#!/bin/bash
# Creates a local self-signed code-signing certificate so the Accessibility grant survives
# rebuilds. Ad-hoc signing pins the grant to the binary hash, which changes on every build.
#
# Run once. It may ask for your login keychain password and for approval to trust the
# certificate. Nothing is installed outside your login keychain.
set -euo pipefail

IDENTITY_NAME="NACON Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning 2>/dev/null | grep -q "$IDENTITY_NAME"; then
    echo "La identidad '$IDENTITY_NAME' ya existe. Nada que hacer."
    exit 0
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

cat > "$WORK_DIR/openssl.cnf" <<'CONF'
[req]
distinguished_name = dn
x509_extensions = extensions
prompt = no

[dn]
CN = NACON Local Signing

[extensions]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
CONF

echo "1/4 Generando certificado autofirmado (validez 10 años)…"
openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$WORK_DIR/key.pem" \
    -out "$WORK_DIR/cert.pem" \
    -days 3650 \
    -config "$WORK_DIR/openssl.cnf" >/dev/null 2>&1

echo "2/4 Empaquetando la identidad…"
openssl pkcs12 -export \
    -out "$WORK_DIR/identity.p12" \
    -inkey "$WORK_DIR/key.pem" \
    -in "$WORK_DIR/cert.pem" \
    -name "$IDENTITY_NAME" \
    -passout pass:nacon-local >/dev/null 2>&1

echo "3/4 Importando en el Llavero de inicio (puede pedir tu contraseña)…"
security import "$WORK_DIR/identity.p12" \
    -k "$KEYCHAIN" \
    -P nacon-local \
    -T /usr/bin/codesign \
    -T /usr/bin/security >/dev/null

echo "4/4 Marcando el certificado como de confianza para firmar (puede pedir aprobación)…"
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$WORK_DIR/cert.pem"

if security find-identity -v -p codesigning 2>/dev/null | grep -q "$IDENTITY_NAME"; then
    echo
    echo "Listo. Identidad disponible:"
    security find-identity -v -p codesigning | grep "$IDENTITY_NAME"
    echo
    echo "Ahora recompila una vez y concede el permiso por última vez:"
    echo "  ./scripts/build-app.sh"
    echo "  tccutil reset Accessibility dev.nacon.diagnostics"
    echo "  open build/NaconDiagnostics.app"
else
    echo "La identidad no aparece como válida para firmar. Revisa el Llavero." >&2
    exit 1
fi
