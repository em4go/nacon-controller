# Localización: reglas y plan

Lo que Apple recomienda hoy para traducir una interfaz en Swift, y cómo se aplica a este proyecto.
Escrito para que el plan se pueda ejecutar por entregas sin volver a decidir nada.

## Reglas

R1. **Un String Catalog por target**, `Localizable.xcstrings`, versionado. Xcode extrae las claves del
    código y avisa de las que faltan. No se mantienen `.strings` a mano.
R2. **El texto base es la clave**, en inglés, y el español es una traducción más. Se lee en el diff y
    se revisa sin diccionario.
R3. **Nunca concatenar texto.** `Text("a" + "b")` produce un `String`, que no es una clave, y deja al
    traductor dos trozos que no puede reordenar. Se usa **una** clave con hueco tipado
    (`"Scroll up \(lines) lines"`), no `%@` suelto.
R4. **`LocalizedStringResource` para lo que se resuelve tarde**: guarda clave, bundle y locale, y se
    convierte en `String` en el borde. Es la forma de que el núcleo devuelva texto traducible sin
    depender de SwiftUI.
R5. **Plurales como variantes** del catálogo (`zero/one/other`), nunca con `"s"` condicional.
R6. **`InfoPlist.xcstrings`** para los textos de permisos. El de Accesibilidad hay que localizarlo
    aparte: no basta con el `Info.plist`.
R7. **No se traducen los datos**: nombres de perfil, modelo del mando, identificadores. Se marcan
    `shouldTranslate: false`.
R8. **Formato, no traducción**: fechas, números y unidades con `FormatStyle`; nada compuesto a mano.
R9. **Diseño tolerante**: `leading/trailing` en vez de `left/right`, nada de anchos fijos, y probar con
    el pseudo-idioma «Double-Length».
R10. **Las pruebas afirman claves o fijan el idioma.** Un test que compara texto traducido se rompe al
     traducir y no prueba nada.
R11. **Seguir el idioma del sistema** es el patrón de Apple. Un selector propio es legítimo, pero
     obliga a probar cada pantalla en los dos idiomas.
R12. **Traductores**: `xcodebuild -exportLocalizations` / `-importLocalizations` con XLIFF.

## Punto de partida medido

- `Sources/NaconDiagnostics`: ~190 cadenas en 11 archivos, **33 de ellas concatenadas** en 7 archivos.
- `Sources/NaconCore`: etiquetas de `ControlFacts` (17 controles), `MappingRules` (acciones y
  controles), `SystemShortcuts` (14 nombres + 4 títulos), `KeyCatalog` (6 palabras), mensajes de
  `ControllerService` y `ProfileStore`.
- `Tests/`: **19 aserciones** que comparan texto en español.
- No hay ningún `.xcstrings`, y el paquete no declara `defaultLocalization`.

## Plan por entregas

Cada entrega es revisable por separado y deja la app funcionando y probada.

### S0. Andamiaje (media entrega)

- `defaultLocalization: "en"` en `Package.swift`; `Localizable.xcstrings` en `NaconCore` (hoy no tiene
  recursos) y en `NaconDiagnostics` (ya tiene bundle, para el dibujo).
- Un punto de resolución en el núcleo con **locale inyectable**, para que las pruebas y el selector de
  idioma no dependan del proceso.
- Guion `scripts/localization-report.sh`: cuenta cadenas sin traducir por archivo, para ver el avance.

*Criterio*: `swift test` verde, una clave de prueba se resuelve en `en` y en `es`, y `Bundle.module`
encuentra el catálogo dentro del `.app`.

### S1. El núcleo deja de devolver español (una entrega, la que más desbloquea)

- `ControlFacts.label`, `MappingRules.label(for:)`, `MappingRules.controlLabel`,
  `SystemShortcuts.name`, `SystemShortcuts.Category.title` y las palabras de `KeyCatalog` pasan a
  `LocalizedStringResource`.
- La resolución ocurre en el borde: vistas, menú de asignación y ventana del resumen.
- Las 19 aserciones se reescriben para fijar el idioma o afirmar la clave.

*Criterio*: ninguna cadena de interfaz en español dentro de `Sources/NaconCore`; un test comprueba
«Left click» en inglés y «Clic izquierdo» en español.

### S2. Interfaz estática (una entrega)

- `ContentView`, `EmulationSection`, `SensitivitySection`, `ProfileSection`: títulos, subtítulos,
  avisos, alertas y `.help`.

*Criterio*: cero literales de texto en esos archivos, y captura de la ventana en `en` y en `es`.

### S3. Interfaz compuesta (una entrega)

- `MappingEditor`, `PadGraphView`, `AssignMenu`, `MappingSummaryWindow`: las 33 concatenaciones pasan a
  claves con huecos tipados; los anchos fijos se vuelven elásticos.

*Criterio*: no queda ningún `+ "` en `Sources/`; la tabla y el resumen caben en los dos idiomas.

### S4. Sistema y errores (media entrega)

- `InfoPlist.xcstrings` con el texto de Accesibilidad; mensajes de `ProfileStore` (cuarentena, archivo
  ilegible) y de `ControllerService` (conexión, desconexión).

*Criterio*: con el sistema en inglés, el aviso de permisos y los errores salen en inglés.

### S5. Selector y pruebas (media entrega)

- Preferencia «Seguir el sistema / English / Español», persistida, resuelta por el punto de S0.
- Test que lee el catálogo y exige que toda clave tenga `en` y `es`; pruebas con `-AppleLanguages`;
  pseudo-idioma para las capturas.

*Criterio*: paso 21 de aceptación manual, con capturas en ambos idiomas.

## Orden y por qué

El núcleo va primero porque **produce la mayoría de las etiquetas dinámicas** —nombres de controles,
acciones, catálogo— y todo lo demás las muestra. Traducir la interfaz antes obliga a inventar tablas
provisionales que después se tiran.

El selector de idioma va al final a propósito: es una función encima de una app ya traducida, y hasta
que todo no resuelva por el mismo punto no hay nada que seleccionar.

## Lo que no se traduce

Nombres de perfil, nombre del mando, claves del JSON, nombres de archivos de máscara, mensajes de
registro y esta documentación: el README y `docs/` se quedan en español.
