# Capa MOD

Una tecla del mando que cambia lo que hacen los demás botones mientras está pulsada.
La base y la capa MOD se editan a la vista, sin conmutador de modo.

## Specs

- **S1.** La capa se lee al pulsar el botón y se mantiene hasta que se suelta. Soltar la tecla MOD
  con un botón aún pulsado **no** cambia lo que ese botón está enviando: lo que se pulsó es lo que se
  suelta. (Decisión del usuario: «Sigue con la acción de la capa hasta soltar el botón»).
- **S2.** Un control sin entrada en la capa MOD usa su acción de la base. La MOD solo cambia lo que se
  redefine. (Decisión del usuario: «Usa la acción de la base»).
- **S3.** La tabla muestra dos columnas por fila, «Base» y «MOD», sin conmutador de modo.
  (Decisión del usuario: «Dos columnas en cada fila»).
- **S4.** El dibujo ofrece las mismas dos capas que la tabla: la línea bajo el dibujo muestra las dos
  y su menú permite asignar a cualquiera de ellas. Misma lista de destinos en ambas vistas.
- **S5.** PS no puede ser la tecla MOD: es la salida de emergencia. Mientras un control es la tecla
  MOD no emite nada; es un selector de capa, no un «mantener modificador».
- **S6.** Un perfil sin tecla MOD se comporta exactamente como hoy, y los perfiles ya guardados se
  leen sin cambios: la capa empieza vacía.
- **S7.** La capa se congela al arrancar la emulación, como el resto del perfil: editarla mientras
  corre no tendría efecto, así que la edición queda bloqueada.

## Tasks

| ID | Spec | Ruta | Commit |
| --- | --- | --- | --- |
| T1 | S1, S2, S5, S6 | Modelo (`ProfileLayer`), codificación, motor y tests | `0445e24` |
| T2 | S3, S4 | Selector de tecla MOD compartido por las dos vistas | — |
| T3 | S3, S5, S7 | Tabla: columna MOD por fila | — |
| T4 | S4 | Dibujo: línea con las dos capas y menú por capa | — |
| T5 | todas | README, aceptación manual | — |

## Log

- **L1.** «quiero hacer posible que exista una tecla que sirva de mod, de forma que si pulso un botón
  sin la tecla mod signifique algo (por ejemplo, cmd) y si lo pulso a la vez que la tecla mod
  signifique otra cosa (por ejemplo, opt). Es viable esto? Habría que pensar una buena ui/ux para
  hacerlo simple de entender y de modificar»
- **L2.** Decisiones del usuario: «Sigue con la acción de la capa hasta soltar el botón»; «Usa la
  acción de la base»; «Dos columnas en cada fila».
- **L3.** Viable: el motor ya guarda en `heldActions` la acción emitida por cada control y la suelta
  en su flanco de subida, así que la capa no puede dejar una tecla pegada. La resolución pasa a ser
  `action(for:control:layerActive:)`. Las entradas «Mantener modificador» siguen siendo otra cosa: esas
  emiten ⌘ al sistema, la capa no emite nada.
- **L4.** Rebanada 1 cerrada en `0445e24` (T1): 435 líneas, por encima del límite de revisión de
  ~400. De aquí en adelante la entrega va partida en tres rebanadas con commits separados: 1) modelo,
  motor y tests (hecha); 2) interfaz: selector de tecla MOD, columna MOD de la tabla y las dos capas
  en el dibujo; 3) documentación y aceptación. Cada rebanada se revisa por separado.
- **L5.** Límite conocido de la rebanada 2: la captura de teclado arma la capa base. Una asignación a
  la capa MOD se elige del menú (ratón, desplazamiento, catálogo del sistema y modificadores
  sostenidos), no se captura. Hacer la captura consciente de la capa toca `KeyCaptureSession` y sus
  tests, y queda fuera de esta rebanada.
