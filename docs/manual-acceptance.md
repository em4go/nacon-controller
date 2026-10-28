# Aceptación manual

Lo que ningún test automático puede comprobar en este proyecto: el mando real, los permisos del
sistema y el cableado de AppKit. Se ejecuta antes de dar por buena una entrega que toque esas zonas.

Ejecutado por última vez el 2026-10-28, con resultado correcto en los diecisiete pasos. Repetir los
pasos 2 y 3 siempre que cambie el código de captura de pulsaciones, y el 12 y el 13 siempre que cambie
la capa MOD.

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
| 18 | En un editor de texto, asignar ⌘A a un control y añadirle un paso ⌘C desde **Elegir… › Añadir paso al comando…**; pulsarlo con texto en el documento | Selecciona todo y copia; mantener el botón no lo repite; soltarlo enseguida no deja ninguna tecla pulsada |
| 17 | Hacer clic con el mando en un enlace de un texto con formato (terminal, markdown o web) y en un control que antes no respondía | El enlace se abre con un clic normal, sin ⌘: lo que faltaba era la cuenta de clics del evento |
| 16 | Asignar el atajo de captura de zona (Shottr, o ⇧⌘4), pulsarlo, hacer clic con el mando y arrastrar con el stick | La selección **crece mientras se arrastra** y al soltar se captura la zona elegida, no una vacía |
| 15 | Asignar un botón a «Mantener modificador → ⌃⇧», pulsarlo y soltarlo; después usar ⌘⇥ | ⌘⇥ cambia de aplicación una vez, sin comportarse como ⇧⌘⇥, y ⇧ no queda pulsado: escribir sale normal |
| 14 | Con □ asignado a «Mantener modificador → ⌘» y L1 a ⇥, mantener □, pulsar L1 y soltar los dos | El conmutador de aplicaciones aparece y **desaparece al soltar**: no se queda en pantalla, y ⌘ no queda pulsado |
| 12 | Elegir «Tecla MOD: Share»; en la tabla, asignar ✕ en la base a ⌘ y ✕ en la columna MOD a ⌥; después mantener Share y pulsar ✕ | Con Share pulsado, ✕ envía ⌥; sin Share, ✕ envía ⌘; y Share solo, sin más botones, no envía nada |
| 13 | Con Share pulsado y ✕ mantenido, soltar Share y después ✕; luego pulsar ○ con Share pulsado | ✕ sigue enviando ⌥ hasta que se suelta ✕, y al final no queda ninguna tecla pulsada; ○, que no tiene entrada en la capa, envía lo de la base |
| 11 | En Hex, atajo ⌃⇧ y modo **Hold**; asignar un control del mando a «Mantener modificador → ⌃⇧» y mantenerlo pulsado | Dicta mientras se mantiene, transcribe al soltar, y al soltar **⌃ y ⇧ no quedan pulsados**: el teclado sigue escribiendo normal |
| 10 | Empujar el stick derecho a media inclinación en un documento largo, y luego mover el control «Velocidad de desplazamiento» | El desplazamiento es continuo, sin saltos de línea, y la velocidad cambia con el control al reiniciar la emulación |
| 9 | Asignar un control a **⌘⇥** desde el catálogo, pulsarlo y soltarlo; después escribir en un editor de texto | Cambia de aplicación una vez y **⌘ no queda pulsado**: lo que se escriba sale normal, sin atajos |
| 8 | Con la emulación activa, activarla desde el mando con **PS** y pasar a otra aplicación; mover el stick | El cursor va igual de rápido que con la ventana de la app delante |

## Qué NO cubre

- La inyección en otras aplicaciones se comprueba a ojo en el paso 5; no hay aserción automática.
- El LED y la vibración se prueban aparte con `swift run nacon-padtest both`.
- La lectura del mando se puede comprobar sin interfaz con `swift run nacon-selftest 8`.
