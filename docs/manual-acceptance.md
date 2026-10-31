# Aceptación manual

Lo que ningún test automático puede comprobar en este proyecto: el mando real, los permisos del
sistema y el cableado de AppKit. Se ejecuta antes de dar por buena una entrega que toque esas zonas.

Ejecutado por última vez el 2026-10-29, con resultado correcto en los veintiún pasos y ninguno
pendiente. Repetir los pasos 2, 3 y 19 siempre que cambie el código de captura de pulsaciones, el 12 y
el 13 siempre que cambie la capa MOD, y el 21 siempre que cambie el catálogo de textos o la forma en que
se resuelve el idioma.

## Preparación

```bash
./scripts/build-app.sh
open build/NaconDiagnostics.app
```

El mando debe estar conectado y el permiso de Accesibilidad concedido.

## Pasos

| # | Acción | Resultado esperado |
| --- | --- | --- |
| 1 | Pulsar «Nuevo perfil» | Aparece un perfil llamado «Perfil» que parte del mapeo estándar |
| 2 | En el editor, control A → «Capturar» → pulsar **H** | La fila de A muestra `H` |
| 3 | «Capturar» → pulsar **Escape** | Cancela y conserva el mapeo anterior |
| 4 | Cerrar y reabrir la app | El perfil y el mapeo siguen ahí |
| 5 | Iniciar emulación y pulsar **A** con un editor de texto delante | Escribe `h` |
| 6 | Con la emulación activa, mirar el editor | Está bloqueado, con su aviso, y el eje Y también |
| 7 | Pulsar **PS** | Detiene la emulación al instante; pulsarlo de nuevo la activa |
| 8 | Con la emulación activa, activarla desde el mando con **PS** y pasar a otra aplicación; mover el stick | El cursor va igual de rápido que con la ventana de la app delante |
| 9 | Asignar un control a **⌘⇥** desde el catálogo, pulsarlo y soltarlo; después escribir en un editor de texto | Cambia de aplicación una vez y **⌘ no queda pulsado**: lo que se escriba sale normal, sin atajos |
| 10 | Empujar el stick derecho a media inclinación en un documento largo, y luego mover el control «Velocidad de desplazamiento» | El desplazamiento es continuo, sin saltos de línea, y la velocidad cambia con el control al reiniciar la emulación |
| 11 | En Hex, atajo ⌃⇧ y modo **Hold**; asignar un control del mando a «Mantener modificador → ⌃⇧» y mantenerlo pulsado | Dicta mientras se mantiene, transcribe al soltar, y al soltar **⌃ y ⇧ no quedan pulsados**: el teclado sigue escribiendo normal |
| 12 | Elegir «Tecla MOD: Share»; en la tabla, asignar ✕ en la base a ⌘ y ✕ en la columna MOD a ⌥; después mantener Share y pulsar ✕ | Con Share pulsado, ✕ envía ⌥; sin Share, ✕ envía ⌘; y Share solo, sin más botones, no envía nada |
| 13 | Con Share pulsado y ✕ mantenido, soltar Share y después ✕; luego pulsar ○ con Share pulsado | ✕ sigue enviando ⌥ hasta que se suelta ✕, y al final no queda ninguna tecla pulsada; ○, que no tiene entrada en la capa, envía lo de la base |
| 14 | Con □ asignado a «Mantener modificador → ⌘» y L1 a ⇥, mantener □, pulsar L1 y soltar los dos | El conmutador de aplicaciones aparece y **desaparece al soltar**: no se queda en pantalla, y ⌘ no queda pulsado |
| 15 | Asignar un botón a «Mantener modificador → ⌃⇧», pulsarlo y soltarlo; después usar ⌘⇥ | ⌘⇥ cambia de aplicación una vez, sin comportarse como ⇧⌘⇥, y ⇧ no queda pulsado: escribir sale normal |
| 16 | Asignar el atajo de captura de zona (Shottr, o ⇧⌘4), pulsarlo, hacer clic con el mando y arrastrar con el stick | La selección **crece mientras se arrastra** y al soltar se captura la zona elegida, no una vacía |
| 17 | Hacer clic con el mando en un enlace de un texto con formato (terminal, markdown o web) y en un control que antes no respondía | El enlace se abre con un clic normal, sin ⌘: lo que faltaba era la cuenta de clics del evento |
| 18 | En un editor de texto, asignar ⌘A a un control y añadirle un paso ⌘C desde **Elegir… › Añadir paso al comando…**; pulsarlo con texto en el documento | Selecciona todo y copia; mantener el botón no lo repite; soltarlo enseguida no deja ninguna tecla pulsada |
| 19 | Con una tecla MOD elegida: en la columna MOD de un control, capturar una tecla y añadirle un paso; repetirlo desde el dibujo, con **Asignar con MOD › Capturar tecla…**; comprobar que la base quedó intacta | Las dos vistas ofrecen las mismas entradas; la captura escribe solo en la columna desde la que se armó, en cualquiera de las dos vistas, y «Cancelar» cancela también una captura de paso |
| 20 | Mantener la tecla MOD y pulsar PS; cerrarlo con Esc; abrirlo otra vez y hacer clic fuera; abrirlo y pulsar PS solo | El panel aparece y desaparece **sin** cambiar la emulación; Esc y el clic fuera lo cierran; PS solo sigue encendiendo y apagando; apagar la emulación lo cierra |
| 21 | Con el sistema en español, elegir **English** en la sección Idioma; cambiar de vista y volver; cerrar y reabrir | Toda la ventana pasa a inglés, incluido el rótulo de estado; los nombres de perfil no cambian; al reabrir sigue en inglés; volviendo a «Idioma del sistema» vuelve al español |
| 22 | En **Sensibilidad del cursor**, elegir **Tecla de precisión: L1** y bajar el factor al 30 %; arrancar la emulación y mover el stick izquierdo con L1 pulsado y sin pulsar | Con L1 el cursor va a menos de un tercio de la velocidad y el desplazamiento también baja; sin L1 vuelve a la velocidad normal; L1 no envía ninguna tecla |
| 23 | Asignar ✕ a **Alternar clic izquierdo**; pulsarlo una vez y arrastrar con el stick; pulsarlo otra vez; después dejarlo pulsado y apagar la emulación con PS | El primer toque deja el botón izquierdo pulsado y el stick arrastra; el segundo lo suelta; apagar la emulación lo suelta aunque siguiera pulsado |
| 24 | Con el mando conectado: pulsar el icono de la barra, encender y apagar la emulación desde él, cambiar de perfil, cerrar la ventana y reabrirla desde **Abrir la ventana** | El icono aparece y cambia con la emulación; el menú enciende y apaga sin abrir la ventana; cerrar la ventana **no** cierra la app; reabrirla funciona; **Salir** termina la app y apaga la luz del mando |
| 25 | Con la emulación en marcha y un clic fijado pendiente, desenchufar el mando; volver a enchufarlo | Aparece el aviso de que el mando dejó de enviar; el botón y las teclas pulsadas se sueltan solos; al reconectar no se pulsa nada por sí mismo y la emulación sigue activa |
| 26 | **Sin mando**: elegir un perfil con **Tecla MOD: Ninguna** y mirar la sección de perfiles; pulsar **Ver mapeo** | Bajo el selector de la tecla MOD aparece el aviso de que sin tecla MOD no hay capa ni gesto MOD+PS en el mando, y de que PS sola enciende y apaga; el panel se abre igualmente y se queda abierto |
| 27 | **Con el mando**, en ese perfil sin tecla MOD: pulsar PS estando apagada, y otra vez estando encendida | La primera pulsación enciende la emulación y la segunda la apaga; el resumen **no** aparece en ningún momento |

## Qué NO cubre

- La inyección en otras aplicaciones se comprueba a ojo en el paso 5; no hay aserción automática.
- El LED y la vibración se prueban aparte con `swift run nacon-padtest both`.
- La lectura del mando se puede comprobar sin interfaz con `swift run nacon-selftest 8`.
