# NACON Compact Controller — lector de diagnóstico para macOS

Aplicación nativa de macOS (Swift + SwiftUI) que lee el mando **NACON / Bigben Compact Controller
(USB `146B:0603`)** y muestra en tiempo real botones, sticks y gatillos, además del estado de
conexión y la reconexión.

Esta etapa **solo lee**. No emula teclado ni ratón, no inyecta eventos, no mueve el cursor, no pide
permisos de Accesibilidad, no usa perfiles y no corre en segundo plano.

## Por qué no se usa GameController

El mando no es un dispositivo HID. Su única interfaz USB es `0xFF / 0x5D / 0x01` con un descriptor
extra de tipo `0x21`: la firma del protocolo **Xbox 360 (XInput)**. macOS no configura ese
dispositivo y `GameController` / `CoreHID` no pueden verlo. Por eso se lee con `IOUSBHost` hablando
XInput directamente.

Consecuencia práctica: macOS deja el dispositivo sin configurar (`kUSBCurrentConfiguration` ausente,
cero interfaces). La aplicación envía `SET_CONFIGURATION(1)`, tras lo cual la interfaz aparece y se
pueden leer los informes de 20 bytes del endpoint de interrupción `0x81`.

## Requisitos

- macOS 13 o superior (probado en macOS 27.0.1, Apple M5)
- Xcode 27 o las Command Line Tools (`xcode-select -p`)
- Swift 6.x

Sin dependencias externas. Sin kexts. Sin permisos de administrador.

## Compilar y ejecutar

Ejecución directa, sin empaquetar:

```bash
swift run NaconDiagnostics
```

Aplicación empaquetada (recomendado para uso normal):

```bash
./scripts/build-app.sh
open build/NaconDiagnostics.app
```

Comprobación rápida sin interfaz, útil para verificar el enlace USB:

```bash
swift run nacon-selftest 8
```

Imprime una línea por cambio de estado y termina con el número de informes recibidos. Sale con
código 0 si llegó al menos un informe.

Tests del decodificador:

```bash
swift test
```

## Qué deberías observar

1. **El mando aparece** en «Mandos detectados» con nombre, `VID:PID`, número de serie y modo.
2. **Estado «Conectado»** con el contador de informes subiendo continuamente.
3. **Botones**: cada pulsación y cada suelte se reflejan al instante.
4. **Sticks y gatillos**: los valores crudos cambian al moverlos (sticks −32768…32767, gatillos 0…255).
5. **Desconexión**: al desconectar el cable aparece «Mando desconectado» y el panel de «ningún mando».
   Al reconectarlo vuelve solo a «Conectado» sin reiniciar la aplicación.
6. **Sin mando**: se muestra explícitamente «NO SE HA DETECTADO NINGÚN MANDO».

## Emulación de ratón y teclado

La ventana incluye un interruptor **Emulación activa**, apagado por defecto.

| Control | Acción por defecto |
| --- | --- |
| Stick izquierdo | Mueve el cursor (zona muerta radial + curva) |
| Stick derecho (vertical) | Desplazamiento |
| A / B / X | Clic izquierdo / derecho / central |
| Y | Escape |
| Cruceta | Flechas |
| LB / RB | Tab / Return |
| Back / Start | Borrar / Espacio |
| Guide (Xbox) | **Detiene la emulación al instante** |

Reglas de seguridad que el código garantiza:

- La emulación **nunca arranca activada**.
- Desactivarla **suelta todas las teclas y botones** retenidos: no puede quedar nada pulsado.
- Pulsar **Guide** la detiene sin usar el ratón.
- Si el mando se **desconecta**, la emulación se detiene y suelta lo que tuviera retenido.

### Sensibilidad por perfil

Cada perfil guarda su propia velocidad máxima, zona muerta, curva y velocidad de desplazamiento, así
que un perfil de diseño y uno de juego pueden moverse distinto sin reajustar nada a mano. Los controles
están en **Sensibilidad del cursor**, se aplican al arrancar la emulación y se bloquean mientras corre
por la misma razón que el editor de mapeos. **Restablecer** devuelve los valores estándar sin tocar la
dirección del eje vertical, que es una propiedad de la unidad y no una preferencia.

Cada valor se acota a su rango antes de guardarse: un archivo editado a mano no puede dejar el cursor
a 0 pt/s, que se vería exactamente igual que un cursor congelado.

### Luz y vibración

- **Luz**: por defecto es un indicador de emulación, encendida mientras corre y apagada al detenerla.
  Se puede pasar a control manual.
- **Vibración**: un interruptor la usa como aviso al arrancar y detener, con intensidad ajustable, y
  **Probar** lanza una ráfaga corta.

Las dos son estado de ejecución, no ajustes de perfil. La app envía la orden de parada al terminar,
pero un cierre forzado puede dejar la luz encendida o los motores girando: es una limitación aceptada
y está dicha también junto a los controles.

### Firma estable (recomendado antes de la primera concesión)

La firma ad-hoc ancla el permiso de Accesibilidad al hash del binario, así que **cada recompilación
invalida el permiso**. Para evitarlo, crea una vez una identidad local autofirmada:

```bash
./scripts/setup-signing-identity.sh
```

Puede pedir la contraseña del Llavero y una aprobación. A partir de ahí `build-app.sh` firma con esa
identidad automáticamente y el permiso sobrevive a las recompilaciones. Solo habría que volver a
concederlo si cambia el `CFBundleIdentifier`, si el certificado caduca (10 años) o si se borra.

Si no existe la identidad, `build-app.sh` sigue funcionando con firma ad-hoc y avisa por consola.

### Permiso de Accesibilidad

macOS descarta los eventos sintetizados sin este permiso. La app lo comprueba, lo solicita y
muestra el estado. Concédelo en **Ajustes del Sistema › Privacidad y seguridad › Accesibilidad**.

Importante: usa siempre `build/NaconDiagnostics.app`. Si ejecutas `swift run`, el binario no tiene
identidad estable y macOS volverá a pedir el permiso o lo ignorará.

## Qué no se puede leer

Esta vía no accede a controles que el mando solo expone en otros modos:

- **Touchpad**: medido en los dos modos alcanzables y **no está expuesto en ninguno**. En modo
  XInput no produce ninguna señal: sus seis bytes reservados (14-19) permanecen a cero y la
  pulsación no aparece en la máscara de botones, comprobado con control positivo en
  `nacon-touchpad` (el botón A sí se registra, máscara `0x1000`). En la ventana de modo PS4
  (`146B:0D05`, ~0,23 s) su descriptor HID tampoco declara la página de digitizer. Retener ese
  modo no habría dado acceso al touchpad. Detalle y evidencia en
  [`docs/ps4-mode-window.md`](docs/ps4-mode-window.md).
- **Jack de audio**: exclusivo del modo PS4 (`146B:0D05`), cuya ventana dura unas décimas de
  segundo al conectar y se cierra sola.

En cambio, **la luz y la vibración sí funcionan en modo XInput** y está verificado en hardware:

- El paquete de vibración (`00 08 00 L R 00 00 00`) hace vibrar el mando.
- El paquete de LED (`01 03 XX`) enciende en azul la pequeña luz situada bajo el botón PS
  (`0x06`) o la apaga (`0x00`).

Ambos se probaron con `swift run nacon-padtest both`, que alterna vibración y luz para poder
distinguir un canal de salida muerto de una luz no controlable.
- **Modo bootloader** (`2F24:0001`, «Updater»): se alcanza manteniendo `SHARE` + `OPTIONS` al
  conectar y sirve para actualizar firmware. No envía entradas.
- La aplicación **no** interpreta esos modos: los detecta, los muestra y avisa.

## Estructura

```
Sources/NaconCore/XInputReport.swift      Decodificador puro del informe de 20 bytes
Sources/NaconCore/NaconDevice.swift       Identidades USB y modos conocidos
Sources/NaconCore/ControllerService.swift Ciclo de vida IOUSBHost, lectura y reconexión
Sources/NaconTouchWatch/main.swift      Observador del touchpad en modo XInput
Sources/NaconPS4Probe/main.swift        Sonda de la ventana de modo PS4
Sources/NaconDiagnostics/                 Aplicación SwiftUI
Sources/NaconSelfTest/                    Comprobación headless del enlace
Tests/NaconCoreTests/                     Tests del decodificador
scripts/build-app.sh                      Empaquetado .app
odd/tasks/phase2-diagnostics.md           Especificación y registro de la tarea
```

## Limitaciones conocidas

- El mando solo admite **un dueño a la vez**: si la app está abierta, otro programa no puede leerlo,
  y si otro programa lo captura, la app deja de recibir informes.
- La emulación no se ha validado todavía de extremo a extremo: requiere que concedas el permiso de
  Accesibilidad. La lógica está cubierta por 175 tests con un emisor simulado, pero el envío real de
  eventos a otras aplicaciones solo se puede comprobar con el permiso concedido.
- `ControllerService.swift` supera las 400 líneas; conviene extraer el acceso al registro IOKit a su
  propio archivo cuando se toque de nuevo.

- Solo se soporta el mando **Bigben/NACON en modo XInput** (`146B:0603`). Otros mandos XInput
  necesitarían ampliar la tabla de identidades.
- El significado de cada bit está fijado por el protocolo Xbox 360. Si una unidad concreta
  intercambiara botones, la tabla está en un único sitio (`XInputReport.swift`).
- La luz y la vibración se controlan desde la app. La orden de parada de ambas se envía al terminar,
  así que un cierre forzado puede dejarlas en el estado anterior.
