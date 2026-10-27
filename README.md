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

## Qué no se puede leer

Esta vía no accede a controles que el mando solo expone en otros modos:

- **Touchpad, jack de audio, luz y vibración**: existen en modo PS4 (`146B:0D05`), que es HID, no en
  modo XInput. Esa ventana dura unas décimas de segundo al conectar y se cierra sola.
- **Modo bootloader** (`2F24:0001`, «Updater»): se alcanza manteniendo `SHARE` + `OPTIONS` al
  conectar y sirve para actualizar firmware. No envía entradas.
- La aplicación **no** interpreta esos modos: los detecta, los muestra y avisa.

## Estructura

```
Sources/NaconCore/XInputReport.swift      Decodificador puro del informe de 20 bytes
Sources/NaconCore/NaconDevice.swift       Identidades USB y modos conocidos
Sources/NaconCore/ControllerService.swift Ciclo de vida IOUSBHost, lectura y reconexión
Sources/NaconDiagnostics/                 Aplicación SwiftUI
Sources/NaconSelfTest/                    Comprobación headless del enlace
Tests/NaconCoreTests/                     Tests del decodificador
scripts/build-app.sh                      Empaquetado .app
odd/tasks/phase2-diagnostics.md           Especificación y registro de la tarea
```

## Limitaciones conocidas

- Solo se soporta el mando **Bigben/NACON en modo XInput** (`146B:0603`). Otros mandos XInput
  necesitarían ampliar la tabla de identidades.
- El significado de cada bit está fijado por el protocolo Xbox 360. Si una unidad concreta
  intercambiara botones, la tabla está en un único sitio (`XInputReport.swift`).
- La vibración y el LED no se controlan todavía; el mando enciende su LED solo.
