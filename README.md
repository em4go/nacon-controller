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
| ✕ / ○ / □ | Clic izquierdo / derecho / central |
| △ | Escape |
| Cruceta | Flechas |
| L1 / R1 | Tab / Return |
| Share / Options | Borrar / Espacio |
| PS | **Activa y desactiva la emulación al instante** |

Reglas de seguridad que el código garantiza:

- La emulación **nunca arranca activada**.
- Desactivarla **suelta todas las teclas y botones** retenidos: no puede quedar nada pulsado.
- Pulsar **PS** la activa si está parada y la detiene si está en marcha, sin usar el ratón.
- Si el mando se **desconecta**, la emulación se detiene y suelta lo que tuviera retenido.

### Dos vistas del perfil

El perfil activo se puede leer de dos maneras con el selector **Vista**, y la elección se recuerda
entre arranques:

- **Gráfica** (por defecto): el propio dibujo del mando es el control. Al pasar el ratón por un
  botón se ilumina su forma —el trazo que ya está dibujado, sin cajas ni etiquetas encima— y una
  franja debajo del dibujo dice qué control está señalado y qué envía ahora. Al pulsarlo se arma la
  captura de tecla para ese control; el botón PS se describe pero nunca se reasigna. Mientras la
  emulación corre, el resaltado se atenúa y deja de responder porque el mapeo está bloqueado.
- **Tabla**: el editor de siempre, una fila por control, donde se captura la tecla o se elige la
  acción.

La fila del botón PS aparece en las dos vistas: no es reasignable porque es el interruptor de la
emulación.

El dibujo procede del paquete de prompts de Xelu, publicado con licencia CC0 1.0 (dominio público):
`Sources/NaconDiagnostics/Resources/PS4_Controller.png` es la variante que ya imprime ✕ ○ □ △ y el
logo PS. Las máscaras de resaltado —una por control, con el canal alfa de ese mismo dibujo— están en
`Sources/NaconDiagnostics/Resources/masks/diagram-*.png` y se generan con
`prototype/tools/make-masks.py`.

### Sensibilidad por perfil

Cada perfil guarda su propia velocidad máxima, zona muerta, curva y velocidad de desplazamiento, así
como su tope, con un rango que llega a 80 líneas/s. El desplazamiento se emite en píxeles y no en
líneas: un evento de línea solo puede llevar líneas enteras, así que a poca velocidad la vista
saltaba una línea cada varios ciclos. En píxeles la fracción se arrastra de un ciclo al siguiente y el
movimiento es continuo. `Scroll.pixelsPerLine` (16) es el puente entre la unidad que ves y la que
recibe el sistema, y es una estimación: macOS no fija cuántos píxeles mide una línea.
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

### Atajos del sistema listos

El menú **Elegir…** de cada control ofrece, además de las teclas que captures, un catálogo de acciones
con nombre. Hay dos grupos.

**Editar y documentos** reúne lo que cualquier app de macOS con texto entiende: copiar (⌘C), pegar (⌘V),
pegar sin formato (⌥⇧⌘V), cortar, deshacer, rehacer, seleccionar todo, guardar, buscar, imprimir, nueva
pestaña, borrar la palabra anterior (⌥⌫) e ir al principio o al final de la línea (⌘←, ⌘→).

**Sistema** reúne los atajos de macOS: Mission Control, mostrar las ventanas de la app, escritorio a la
izquierda y a la derecha, cerrar la ventana, cambiar de aplicación, ventana siguiente de la misma app,
cerrar la aplicación, forzar la salida, Spotlight y las capturas de pantalla.

## Comandos de varios pasos

Un control puede encadenar varias pulsaciones: ⌘A y después ⌘C, por ejemplo, para seleccionar todo y
copiar con un solo botón.

Se construye desde el menú **Elegir…** del propio control:

1. Captura la primera tecla del comando, como cualquier otra asignación.
2. En **Elegir…**, elige **Añadir paso al comando…** y pulsa la siguiente tecla. Repite por cada paso.
   Funciona igual en la columna Base y en la columna MOD: **cada columna tiene su propio botón
   «Capturar»** y su propio menú, y lo que capturas en una no toca la otra.
3. **Quitar el último paso** acorta el comando, y la etiqueta del control muestra el resultado:
   «⌘A luego ⌘C».

Cómo se ejecuta: el primer paso sale al pulsar y los demás a un paso por tick, para que la app de
destino tenga tiempo de actuar entre ellos —⌘A tiene que surtir efecto antes del ⌘C—. Un comando es
una ejecución, no una tecla mantenida: mantener el botón no lo repite. Si sueltas el botón antes de que
termine, se descartan los pasos que faltaban, y cada paso es una pulsación completa, así que nunca queda
ni una tecla ni un modificador pulsado.

Son combinaciones de teclas normales, así que el mando envía exactamente lo mismo que el teclado: no
hacen falta permisos nuevos ni APIs privadas. El límite es el mismo que el del teclado:

- Solo funcionan si el atajo sigue activo en **Ajustes del Sistema › Teclado › Atajos de teclado**.
  Ofrecer el nombre no comprueba que esté vivo: si lo desactivaste, el mando enviará la combinación y
  no pasará nada.
- Los que cambian de escritorio o de aplicación hacen lo que tengas configurado en el sistema (cuántos
  escritorios existen, qué hace ⌘+Tab), no algo propio de la app.
- Un atajo con ⌘+Q cierra la aplicación que esté delante, no una en concreto: el catálogo no elige por
  ti, y no necesita el permiso de Automatización.

### Un control que mantiene modificadores

El mismo menú tiene **Mantener modificador**: ⌃, ⌥, ⇧, ⌘ y fn por separado, y las diez parejas entre
ellos. Un control asignado a una de esas entradas se comporta como la tecla física —baja mientras lo
mantienes y sube al soltarlo—, y las teclas se envían de verdad, no como banderas sobre otra tecla.

Los modificadores que envía son siempre **los de la izquierda** —⌃ ⌥ ⇧ ⌘ fn—, que es lo que necesita
una aplicación que distingue lados, como las de dictado que preguntan «Left / Either / Right»: el lado
viaja en el código de la tecla, no en la bandera.

Sirve para dos cosas. La primera, recorrer el conmutador de aplicaciones: ⌘ en un control y ⇥ en otro,
mantienes el primero y tocas el segundo. La segunda, **dictar**: una app que escuche una combinación
de solo modificadores —⌃⇧ es lo habitual— se puede gobernar con un botón del mando si mantienes el
control mientras hablas y lo sueltas al terminar.

La captura del teclado no puede grabar una pulsación de solo modificadores, porque escucha teclas y no
cambios de modificador; esas entradas se eligen del menú.

### La capa MOD

Una tecla del mando puede hacer de **selector de capa**: mientras la mantienes, los botones envían lo
que diga su columna **MOD**; al soltarla vuelven a la columna **Base**. Se elige en **«Tecla MOD:»**,
encima del editor, y PS no puede serlo: es la salida de emergencia y tiene que seguir siéndolo.

Se edita a la vista, sin conmutadores: la tabla muestra **las dos columnas en la misma fila** y el
dibujo las enseña en su franja —`⌘ · MOD ⌥`— y en su menú, con «Asignar a la base» y «Asignar con
MOD». Las dos vistas ofrecen la misma lista de destinos porque comparten una sola definición.

Cuatro reglas que conviene saber:

- **La capa se lee al pulsar.** Si sueltas la tecla MOD con un botón aún pulsado, ese botón sigue
  enviando lo de la capa hasta que lo sueltes. Lo que se pulsó es lo que se suelta, y así no puede
  quedar una tecla pegada.
- **Un control sin entrada en la capa usa su acción de la base.** La MOD solo cambia lo que tú
  redefines, así que añadir una excepción cuesta una sola fila.
- **La tecla MOD no envía nada.** No es «mantener ⌘»: esas entradas del menú emiten el modificador al
  sistema, la capa no emite nada y solo elige qué columna se lee.
- **La capa se congela al arrancar la emulación**, como el resto del perfil.

Un perfil sin tecla MOD se comporta exactamente como antes, y los perfiles ya guardados se leen sin
cambios: la capa empieza vacía. La captura de teclado escribe en la base; una asignación de la capa
se elige del menú.

### Resumen de mapeos

Mantén la tecla MOD y pulsa PS: aparece un panel flotante con lo que envía cada control, en la base y
—si el perfil tiene capa— con MOD. Se cierra con **Esc**, con un **clic fuera** del panel, volviendo a
pulsar MOD+PS, solo a los ocho segundos, o al apagar la emulación.

Para Esc y el clic fuera se usan dos monitores de eventos, uno global y otro local, porque ninguno basta
solo: el global solo ve lo que va a otras aplicaciones y el local solo lo que llega a la nuestra. Si no
concedes el permiso de Accesibilidad, el cierre con Esc desde otra aplicación no funcionará; las demás
formas de cerrarlo, sí.

Es un panel que no roba el foco ni el ratón, así que puedes leerlo encima de la aplicación en la que
estés trabajando, como Spotlight. PS sin MOD sigue haciendo lo suyo: encender y apagar la emulación.
El resumen funciona con la emulación apagada: mirar el mapa no enciende nada.

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
