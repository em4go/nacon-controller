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
| T2 | S3, S4 | Selector de tecla MOD compartido por las dos vistas | `72ae154` |
| T3 | S3, S5, S7 | Tabla: columna MOD por fila | `500cefd` |
| T4 | S4 | Dibujo: línea con las dos capas y menú por capa | `9ec00bd` |
| T5 | todas | README, aceptación manual | `0093b09` |

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
- **L6.** Rebanada 2 entregada en tres commits en vez de uno de 529 líneas, porque la revisión va
  por unidad: `72ae154` (biblioteca y selector), `500cefd` (columnas de la tabla), `9ec00bd` (franja y
  menú del dibujo). Verificado por el padre con `swift test` (264 tests) y con la app compilada y
  arrancada; la disposición de dos columnas no se vio con una tecla MOD puesta, porque eso exige
  escribir en el perfil del usuario.
- **L7.** Decisión anotada del contrato de «Ninguna»: cerrar la capa conserva sus entradas —quedan
  inertes y vuelven si se elige otra tecla— y «Quitar capa» es la vía destructiva.
- **L8.** El clic del ratón no llevaba cuenta de clics. Con cero, las vistas que piden un clic y no
  una pulsación —enlaces en texto con formato, y un control que nunca había respondido— descartaban
  la pulsación entera. La hipótesis de que el enlace necesitaba ⌘ era falsa: lo que lo arregló fue la
  cuenta. Límite anotado: cada clic se declara el primero, así que un doble clic del mando no se puede
  expresar todavía.
- **L9.** Aceptación manual completa el 2026-10-28: los pasos 8 a 17 de `docs/manual-acceptance.md`
  dan resultado correcto en hardware, incluidos el conmutador que ahora se cierra al soltar, la capa
  MOD con su caso de seguridad, la captura de zona con arrastre y el clic que las vistas daban por no
  ser un clic. La capa MOD queda cerrada; falta solo la decisión de fusionar la rama.
- **L10.** El límite del punto L5 queda cerrado: la captura escribe ahora en la columna que armó el
    menú (`MappingCapture.isLayerCapture`), así que las columnas Base y MOD ofrecen lo mismo —captura,
    catálogo, pasos de comando— y ninguna de las dos es de segunda clase.
- **L11.** La columna MOD no tenía botón «Capturar»: solo el menú, así que el botón de la fila
    escribía en la base y la capa parecía no aceptar teclas. Ahora cada columna tiene el suyo y la fila
    distingue cuál está armada. Detrás había un segundo fallo: los banderines de intención de la captura
    no eran `@Published`, así que la fila podía no enterarse de en qué columna se capturaba; ahora lo son.
    Verificado de punta a punta con un clic sintético en el botón MOD y ⌘A: la capa quedó con ⌘A y la
    base intacta, comprobado además en el archivo de perfiles.
