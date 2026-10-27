# Perfiles guardados y atajos configurables

Feature document. Read until `## Log` before starting a task.

## Specs

- **S1**. El usuario puede guardar varios perfiles con nombre y recuperarlos al arrancar la app.
- **S2**. Cada perfil guarda el mapeo completo de los controles del mando y también los ajustes de
  cursor y repetición, para que un perfil sea un esquema cerrado y no dependa del estado global.
- **S3**. Cualquier control reasignable puede apuntar a: una tecla, una combinación con
  modificadores (⌘, ⌥, ⌃, ⇧), un botón del ratón, líneas de desplazamiento, o nada.
- **S4**. El usuario puede crear, duplicar, renombrar y eliminar perfiles.
- **S5**. Un perfil nuevo parte del perfil estándar, no de un mapeo vacío.
- **S6**. Los cambios se guardan en disco solos: no hay botón de guardar.
- **S7**. Si el archivo no existe, está corrupto o es de una versión anterior, la app arranca con el
  perfil estándar y sigue funcionando. Nunca pierde el control por un archivo ilegible.
- **S8**. El perfil seleccionado se recuerda entre ejecuciones.

## Tasks

| ID | Specs | Ruta | Estado |
| --- | --- | --- | --- |
| T1 | S1, S2, S6, S7 | Modelo persistible, catálogo de teclas y almacén con tests (NaconCore) | pendiente |
| T2 | S4, S5, S8 | Selector de perfiles y alta, duplicado, renombrado y borrado (UI) | pendiente |
| T3 | S3 | Editor de mapeos por control con captura de pulsaciones | pendiente |
| T4 | S1, S8 | Conectar el perfil activo con el motor de emulación y el arranque | pendiente |

Decisiones tomadas:

- Un perfil guarda el `InputProfile` completo, no solo los botones. El modelo ya lo contiene y así
  exponer más adelante la sensibilidad por perfil no obliga a migrar el archivo.
- La captura de atajos acepta la pulsación real del usuario, incluidos los modificadores, en lugar
  de ofrecer una lista cerrada de teclas.
- El almacén recibe su directorio por inyección para que los tests trabajen en un directorio temporal
  y nunca toquen `~/Library/Application Support`.

## Log

- L1 (user, verbatim): «Ahora vamos con los perfiles guardados y los atajos configurables»
- L2 (user, verbatim): «la documentación la puedes dejar como está»
- L3 (decisión): la documentación del repositorio se queda en español; el código sigue en inglés.
