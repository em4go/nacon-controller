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
| T1 | S1, S2, S6, S7 | Modelo persistible, catálogo de teclas y almacén con tests (NaconCore) | hecho — `8b6e45f` |
| T2 | S4, S5, S8 | Selector de perfiles y alta, duplicado, renombrado y borrado (UI) | pendiente — en curso |
| T3 | S3 | Editor de mapeos por control con captura de pulsaciones | hecho — `6e5e107` |
| T4 | S1, S8 | Conectar el perfil activo con el motor de emulación y el arranque | hecho — `8394214` |

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
- L4 (evidencia): T1 `8b6e45f`, T2 `da9bf98`, T3 `6e5e107`, T4 `8394214`.
- L5 (pendiente): la interacción de captura y la persistencia entre reinicios solo están
  verificadas por compilación; falta la prueba manual en la app real.
- L6 (user, verbatim): «He probado todos los pasos y todo funciona correctamente»
- L7 (evidencia de aceptación manual, siete pasos): creación de perfil desde el estándar, captura de
  la tecla H para el control A, cancelación con Escape, persistencia tras cerrar y reabrir la app,
  la tecla llegando a otra aplicación con la emulación activa, editor bloqueado mientras la emulación
  corre, y Guide deteniendo la emulación.

## Cierre

Feature terminada y aceptada en hardware real.

| Tarea | Commit |
| --- | --- |
| T1 modelo, catálogo de teclas y almacén | `8b6e45f` |
| T2 perfiles en la ventana | `da9bf98` |
| T3 editor de mapeos y captura | `6e5e107` |
| T4 perfil activo en el motor | `8394214` |

137 tests automáticos. Invariantes de seguridad verificados por código y por prueba manual: Guide
sigue siendo la parada de emergencia y no es mapeable; el editor se bloquea con la emulación activa.

Riesgo declarado: la interacción de captura de pulsaciones no tiene test automático posible con el
objetivo de tests actual (SwiftUI + NSEvent); su cobertura es la aceptación manual del paso L7.

## Verificación independiente y arreglos

Un verificador independiente revisó los cuatro commits. Siete afirmaciones comprobadas: cinco PASS,
dos con salvedades. Encontró cinco defectos, ya corregidos en el commit siguiente a este documento.

| Defecto | Gravedad | Arreglo |
| --- | --- | --- |
| Una entrada corrupta descartaba toda la biblioteca y el autoguardado sobrescribía el archivo | Pérdida de datos | Rescate por entrada + cuarentena del archivo ilegible como `profiles.unreadable-<marca>.json` |
| `profiles.json` editado a mano podía mapear Guide; solo el motor lo neutralizaba | Invariante de seguridad en un único punto | Se elimina cualquier mapeo de Guide al decodificar |
| El interruptor de eje Y seguía activo con la emulación en marcha pero no surtía efecto | Inconsistencia visible | Bloqueado mientras la emulación corre, con aviso de que aplica al arrancar |
| `attach` no era idempotente: un segundo `onAppear` duplicaba temporizador y observadores | Fuga | Segunda llamada sin efecto |
| Una captura armada podía escribir en el perfil equivocado si cambiabas de perfil antes de pulsar | Escritura cruzada | La captura queda ligada al perfil con el que se armó y descarta la escritura si cambió |

Riesgos aceptados, con motivo:

- Los archivos `profiles.unreadable-*` se acumulan y la app no los menciona. Conservar datos vale más
  que la limpieza automática.
- Borrar o renombrar el perfil en uso durante la emulación está permitido: el motor ya capturó el
  perfil al arrancar, así que ninguna pulsación queda trabada y la operación es una decisión de datos
  del usuario.
- `save` sin `load` previo sobrescribiría; no es alcanzable desde la app, que siempre carga al iniciar.
- Dos tests son débiles: el de captura cancelada reafirma una constante y el de selección colgante no
  distingue los dos caminos de reserva. Se dejan como están, anotados.
- F3, F4 y F5 viven en el ejecutable, sin objetivo de tests: verificados por compilación y razonamiento,
  y F3 y F5 además por la prueba manual del usuario.
