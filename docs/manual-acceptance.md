# Aceptación manual

Lo que ningún test automático puede comprobar en este proyecto: el mando real, los permisos del
sistema y el cableado de AppKit. Se ejecuta antes de dar por buena una entrega que toque esas zonas.

Ejecutado por última vez el 2026-10-27, con resultado correcto en los siete primeros pasos. Repetir los
pasos 2 y 3 siempre que cambie el código de captura de pulsaciones.

## Preparación

```bash
./scripts/build-app.sh
open build/NaconDiagnostics.app
```

El mando debe estar conectado y el permiso de Accesibilidad concedido.

## Pasos

| # | Acción | Resultado esperado |
| --- | --- | --- |
| 1 | Pulsar «Nuevo perfil» | Aparece un perfil llamado «Perfil» que parte del mapeo estándar |
| 2 | En el editor, control A → «Capturar» → pulsar **H** | La fila de A muestra `H` |
| 3 | «Capturar» → pulsar **Escape** | Cancela y conserva el mapeo anterior |
| 4 | Cerrar y reabrir la app | El perfil y el mapeo siguen ahí |
| 5 | Iniciar emulación y pulsar **A** con un editor de texto delante | Escribe `h` |
| 6 | Con la emulación activa, mirar el editor | Está bloqueado, con su aviso, y el eje Y también |
| 7 | Pulsar **PS** | Detiene la emulación al instante; pulsarlo de nuevo la activa |
| 8 | Con la emulación activa, activarla desde el mando con **PS** y pasar a otra aplicación; mover el stick | El cursor va igual de rápido que con la ventana de la app delante |

## Qué NO cubre

- La inyección en otras aplicaciones se comprueba a ojo en el paso 5; no hay aserción automática.
- El LED y la vibración se prueban aparte con `swift run nacon-padtest both`.
- La lectura del mando se puede comprobar sin interfaz con `swift run nacon-selftest 8`.
