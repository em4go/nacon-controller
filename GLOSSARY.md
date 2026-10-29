# Nacon Compact Controller

Aplicación de macOS que lee un mando NACON en modo XInput, muestra su estado y lo usa para emular
ratón y teclado con un mapeo editable por perfil.

## Language

### Mando y entrada

**Mando**:
El NACON Compact Controller conectado por USB.
_Avoid_: dispositivo, gamepad, control

**Control**:
Una pieza del mando que se pulsa o se mueve: un botón, un gatillo, una dirección de la cruceta o un
stick pulsado.
_Avoid_: botón (cuando se habla de gatillos o sticks), tecla

**Informe**:
El paquete de 20 bytes que el mando envía por el endpoint de interrupción.
_Avoid_: paquete, evento, mensaje

**Emulación**:
La aplicación sintetizando pulsaciones de ratón y teclado a partir del mando.
_Avoid_: inyección, simulación

### Perfil y mapeo

**Perfil**:
Un mapeo con nombre, guardado en la biblioteca. Hay uno activo en cada momento.
_Avoid_: configuración, preset, ajuste

**Biblioteca**:
Todos los perfiles guardados más cuál está activo. Es lo que se escribe en disco.
_Avoid_: colección, lista

**Mapeo**:
Lo que envía un control. Es el dato, no la acción de asignarlo.
_Avoid_: asignación, binding

**Acción**:
Lo que un mapeo produce: una combinación de teclas, un botón del ratón, una cantidad de
desplazamiento o un comando.
_Avoid_: salida, gesto

**Comando**:
Varias pulsaciones que un control ejecuta en orden, una por tick, al pulsarlo una vez.
_Avoid_: secuencia, macro

**Paso**:
Una pulsación dentro de un comando.
_Avoid_: elemento, tecla del comando

**Mantener modificador**:
Un mapeo que baja un modificador real mientras el control está pulsado, en lugar de enviar una
combinación.
_Avoid_: tecla modificadora, atajo suelto

### Capa MOD

**Capa MOD**:
Una segunda lectura de los mismos controles que solo se aplica mientras la tecla MOD está pulsada.
Solo guarda lo que redefine.
_Avoid_: perfil alternativo, subperfil

**Tecla MOD**:
El control que abre la capa MOD. No envía nada: elige qué columna se lee.
_Avoid_: modificador, tecla modificadora

**Columna**:
Una de las dos lecturas de un control: **Base** o **MOD**. La capa es el conjunto; la columna es la
celda de un control.
_Avoid_: capa (cuando se habla de una celda), lado

**Resumen de mapeos**:
El panel flotante que enseña lo que envía cada control, con MOD y sin ella.
_Avoid_: ayuda, HUD, overlay

### Captura

**Captura**:
La espera de una pulsación real de teclado que se convertirá en el mapeo de un control.
_Avoid_: grabación, escucha

**Destino de la captura**:
La columna en la que escribe una captura y si reemplaza lo que había o añade un paso. Se decide al
armarla, no al recibir la tecla. En el código: `CaptureIntent` (una `MappingColumn` y un `CaptureMode`),
que viaja dentro de `KeyCaptureSession.Outcome`.
_Avoid_: modo de captura, grabación de destino

### Vistas

**Vista Gráfica**:
El dibujo del mando usado como panel: se señala un control para leerlo y se pulsa para asignarle algo.
_Avoid_: dibujo, imagen

**Vista Tabla**:
La lista de controles con sus dos columnas, Base y MOD.
_Avoid_: editor, grilla
