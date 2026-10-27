# Phase 2 — Diagnostic reader app

Deliverable: a native macOS SwiftUI app that reads the NACON pad through IOUSBHost and shows live
button/stick/trigger state, connection status and disconnect/reconnect handling. No input injection.

## Specs

S1. Show the detected controllers: "Mostrar los mandos detectados."
S2. Show device name and connection state: "Mostrar el nombre del dispositivo y su estado de conexión."
S3. Reflect buttons pressed and released in real time: "Reflejar en tiempo real los botones que pulso y suelto."
S4. Show stick and trigger values when available: "Mostrar los valores de los sticks y los gatillos cuando estén disponibles."
S5. Detect disconnect and reconnect: "Detectar la desconexión y reconexión del mando."
S6. Clearly indicate when no controller is detected: "Indicar claramente cuándo no se ha detectado ningún mando."
S7. Do not assume every control uses the same format; state what is not accessible: "No presupongas que el mando expone todos los controles mediante el mismo formato. Si algunos controles no son accesibles, indícalo."
S8. Simple, diagnostic-oriented UI: "La interfaz debe ser sencilla y estar orientada al diagnóstico. No necesitamos diseño visual elaborado."
S9. Out of scope: "Emulación de teclado o ratón / Inyección global de eventos / Permisos de Accesibilidad / Perfiles de configuración / Atajos de teclado / Movimiento del cursor / Ejecución en segundo plano o en la barra de menús / Drivers, extensiones del kernel ni dependencias externas innecesarias."
S10. Acceptance criterion 5: "El proyecto compila y puedo ejecutarlo siguiendo tus instrucciones."

## Tasks

| ID | Specs | Route | Commit |
| --- | --- | --- | --- |
| T1 | S10 | SPM package, app bundle script | feat: scaffold SPM package |
| T2 | S3, S4, S7 | pure decoder + unit tests | feat: xinput report decoder |
| T3 | S1, S2, S5 | IOUSBHost lifecycle service | feat: usb controller service |
| T4 | S1-S8 | SwiftUI views | feat: diagnostic ui |
| T5 | S10 | README + verification | docs: build and verification |

## Log

L1 (user, verbatim, Phase 2 and constraints):

Solo después del diagnóstico, implementa la prueba mínima necesaria para comprobar las entradas físicas.
Prioriza `GameController`, el framework oficial de Apple. Si el mando no es compatible con él, estudia `CoreHID` como alternativa antes de escribir un parser HID.
Si es viable con el entorno disponible, crea una pequeña aplicación nativa de macOS con Swift y SwiftUI que permita:
- Mostrar los mandos detectados.
- Mostrar el nombre del dispositivo y su estado de conexión.
- Reflejar en tiempo real los botones que pulso y suelto.
- Mostrar los valores de los sticks y los gatillos cuando estén disponibles.
- Detectar la desconexión y reconexión del mando.
- Indicar claramente cuándo no se ha detectado ningún mando.
No presupongas que el mando expone todos los controles mediante el mismo formato. Si algunos controles no son accesibles, indícalo.
La interfaz debe ser sencilla y estar orientada al diagnóstico. No necesitamos diseño visual elaborado.
Si la detección mediante `GameController` falla, no ocultes el problema ni cambies automáticamente a una implementación compleja. Expón los resultados, investiga la causa y propón el siguiente experimento más pequeño posible.
Todavía NO implementes: Emulación de teclado o ratón. Inyección global de eventos. Permisos de Accesibilidad. Perfiles de configuración. Atajos de teclado. Movimiento del cursor. Ejecución en segundo plano o en la barra de menús. Drivers, extensiones del kernel ni dependencias externas innecesarias.

L2 (evidence, Phase 1): GameController and CoreHID cannot see this pad. Its only interface is
0xFF/0x5D/0x01 with a 0x21 descriptor: the Xbox 360 XInput signature. macOS never configures it.
Reading works via IOUSBHost after SET_CONFIGURATION(1) on endpoint 0x81 (verified: 40/40 reports, 20 bytes).

L3 (decision): replace GameController with an IOUSBHost reader; reuse the lifecycle ordering and the
20-byte layout documented by the MIT prior art `llPekoll/madcatz-fightstick-macos`.

L4 (user): "continúa con el trabajo, sigue tu propia recomendación" — authorizes Phase 2 implementation.

L5 (user): "es una lástima que no funcione el touchpad ni la luz del mando... ¿no hay absolutamente
ninguna forma de hacer funcionar lo que falta?" — exploration, not a new requirement. The interface
also exposes an interrupt OUT endpoint (0x02) that the read-only phase never used; LED and rumble
packets are now available as `XInputOutputReport` plus the `nacon-padtest` tool.

L6 (observation): the pad can only be owned by one process at a time. While the app was running it
held the IOUSBHostDevice exclusively and a second reader failed with "Error de acceso".
