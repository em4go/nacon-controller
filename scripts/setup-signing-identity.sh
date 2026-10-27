#!/bin/bash
# Creates a local self-signed code-signing certificate so the Accessibility grant survives
# rebuilds. Ad-hoc signing pins the grant to the binary hash, which changes on every build.
#
# Safe to re-run: it only creates the certificate when it is missing and always re-checks trust.
# Nothing is installed outside the login keychain.
set -euo pipefail

# macOS's keychain importer only accepts the legacy PKCS#12 encoding. OpenSSL 3 from Homebrew
# defaults to AES/PBES2, which fails with "MAC verification failed". Apple's LibreSSL produces the
# format the Security framework accepts, so prefer it when present.
OPENSSL_BIN="/usr/bin/openssl"
if [ ! -x "$OPENSSL_BIN" ]; then
    OPENSSL_BIN="$(command -v openssl)"
fi

IDENTITY_NAME="NACON Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning 2>/dev/null | grep -q "$IDENTITY_NAME"; then
    echo "La identidad '$IDENTITY_NAME' ya existe y es válida para firmar. Nada que hacer."
    security find-identity -v -p codesigning | grep "$IDENTITY_NAME"
    exit 0
fi

if security find-certificate -c "$IDENTITY_NAME" "$KEYCHAIN" >/dev/null 2>&1; then
    echo "El certificado ya está en el Llavero; falta marcarlo de confianza."
    CERT_EXISTS=1
else
    CERT_EXISTS=0
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

if [ "$CERT_EXISTS" = "0" ]; then
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

    echo "1/3 Generando certificado autofirmado (validez 10 años)…"
    "$OPENSSL_BIN" req -x509 -newkey rsa:2048 -nodes \
        -keyout "$WORK_DIR/key.pem" \
        -out "$WORK_DIR/cert.pem" \
        -days 3650 \
        -config "$WORK_DIR/openssl.cnf" >/dev/null 2>&1

    echo "2/3 Empaquetando e importando en el Llavero de inicio…"
    "$OPENSSL_BIN" pkcs12 -export \
        -out "$WORK_DIR/identity.p12" \
        -inkey "$WORK_DIR/key.pem" \
        -in "$WORK_DIR/cert.pem" \
        -name "$IDENTITY_NAME" \
        -passout pass:nacon-local >/dev/null 2>&1
    security import "$WORK_DIR/identity.p12" \
        -k "$KEYCHAIN" \
        -P nacon-local \
        -T /usr/bin/codesign \
        -T /usr/bin/security >/dev/null
else
    echo "1-2/3 Certificado ya presente, se omite la creación."
    security find-certificate -c "$IDENTITY_NAME" -p "$KEYCHAIN" > "$WORK_DIR/cert.pem"
fi

echo "3/3 Marcando el certificado como de confianza para firmar (puede pedir aprobación)…"
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
    echo "El certificado está en el Llavero pero no aparece como válido para firmar." >&2
    echo "Ábrelo en Acceso a Llaveros › Mis certificados y marca 'Confiar siempre' en Firma de código." >&2
    exit 1
fi
