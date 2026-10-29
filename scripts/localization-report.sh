#!/bin/bash
# Cuánto texto de interfaz queda sin pasar por el catálogo.
#
# Cuenta literales con letras acentuadas o eñes fuera de los catálogos: es una aproximación honesta,
# no una prueba. Sirve para ver el avance entre entregas, no para dar una entrega por buena.
set -u
cd "$(dirname "$0")/.." || exit 1

count() {
    # shellcheck disable=SC2086
    grep -rhoE '"[^"]*[áéíóúÁÉÍÓÚñÑ¿¡][^"]*"' $1 2>/dev/null | wc -l | tr -d ' '
}

echo "Texto con acentos fuera del catálogo (aprox.):"
echo "  NaconCore:        $(count 'Sources/NaconCore/*.swift Sources/NaconCore/**/*.swift')"
echo "  NaconDiagnostics: $(count 'Sources/NaconDiagnostics/*.swift Sources/NaconDiagnostics/**/*.swift')"
echo "  Pruebas:          $(count 'Tests/NaconCoreTests/*.swift')"
echo
echo "Claves en el catálogo del núcleo:"
python3 - <<'PY'
import json, pathlib
for path in ["Sources/NaconCore/Resources/Localizable.xcstrings",
             "Sources/NaconDiagnostics/Resources/Localizable.xcstrings"]:
    p = pathlib.Path(path)
    if not p.exists():
        print(f"  {path}: no existe")
        continue
    data = json.loads(p.read_text())
    keys = data.get("strings", {})
    missing = [k for k, v in keys.items()
               if "es" not in (v.get("localizations") or {})]
    print(f"  {path}: {len(keys)} claves, {len(missing)} sin español")
    for k in missing:
        print(f"    falta: {k}")
PY
