# Estructura de la ventana: barra lateral, contenido e inspector

Reordenación de la ventana principal en tres zonas —navegar, trabajar, ajustar— para que admita funciones nuevas sin
volver a la columna única actual. No cambia comportamiento en el primer tramo.

## Specs

S1. La ventana principal tiene tres zonas: **barra lateral** de navegación, **contenido** y **inspector** con los
ajustes del perfil.

S2. El objetivo es de fondo, en palabras del usuario:

> me parece muy bueno el 01, y además me has dicho que puede ser el mejor a largo plazo. Eso es lo que me interesa.
> Tener una UI/UX muy buena a largo plazo y que no impida añadir nuevas funcionalidades, a la vez que facilita las
> acciones al usuario. También veo útil el 04 para configurar con apoyo de la propia aplicación. Qué te parece?

S3. Decisiones tomadas por el usuario, literales:

> Que se pliegue al estrechar (recomendado)
> Clic = cambia el perfil activo (recomendado)
> S1: el esqueleto (recomendado)

S4. El inspector **se pliega** por debajo de ~1000 puntos de ancho y se abre desde la barra de herramientas. El
contenido manda: el inspector nunca deja el mapeo por debajo de un ancho usable.

S5. En la barra lateral, **pulsar un perfil lo hace activo**. Un solo concepto, el de hoy: no existe un «perfil
seleccionado pero no activo». Mientras la emulación está en marcha, la lista no cambia nada.

S6. El primer tramo **no cambia comportamiento**: mismos controles, mismas reglas de bloqueo, mismos textos. Solo
cambian de sitio. Un control que hoy está deshabilitado en una condición sigue deshabilitado en la misma condición.

S7. **Diagnóstico** y **Ajustes de la app** son destinos de la barra lateral. El material técnico —matriz de valores,
trama USB, leyenda del protocolo— deja de estar en la vista principal.

S8. Cada tramo se entrega en un corte revisable de ~400 líneas como máximo, con sus tests y su documentación.

## Tasks

| ID | Qué | Specs | Ruta | Commit |
|---|---|---|---|---|
| T1 | Esqueleto de tres zonas con lo existente recolocado: barra lateral con el mando, destino Mapeo con la sección de perfil entera y la acción principal en la barra de herramientas | S1, S3, S6 | worker + correcciones inline | bb0f676 |
| T2 | Lista de perfiles en la barra lateral, con su color; los cuatro botones a un menú de la barra de herramientas | S5, S6 | delegado | fdedaaa |
| T3 | Inspector con color, perfil siguiente, tecla MOD, sensibilidad y precisión; plegado por ancho | S4, S6 | delegado + correcciones inline | c4f5e60 |
| T4 | Destino Diagnóstico con los valores en vivo, la trama y la leyenda | S7 | delegado | |
| T5 | Destino Ajustes de la app: permiso, emulación, vibración, idioma | S7 | delegado | |
| T6 | Primer arranque (prototipo 04), encima de la estructura definitiva | S3 | delegado | |

## Log

L1. Petición original, literal:

> Aparte de eso, crees que existe algo que se podría mejorar? ahora mismo no me termina de convencer la UI/UX. Puede
> ser muy compleja para alguien que acaba de abrir la aplicación. Quiero prototipar varios diseños que mejoren las
> partes de la aplicación. Puedes usar la web para hacer los prototipos si es que te es más fácil. si no es más
> fácil en web, haz los prototipos nativos en mac, pero de forma que se puedan comparar fácilmente. Quiero que
> investigues sobre buenas prácticas de UX para este tipo de aplicaciones y las uses en los prototipos. Cuando tengas
> varias propuestas para mejorar cada una de las partes que tengan más necesidad, dime cómo verlo y yo elijo qué se
> aplicará después. Puedes usar varios subagentes para investigar en paralelo

L2. Cinco prototipos en `design/ux-redesign/` (01 panel lateral, 02 tres tareas, 03 tarjetas, 04 primer arranque, 05
editor de mapeo), abiertos en el lienzo de gentle-design.

L3. El usuario elige 01 como estructura de largo plazo y 04 como apoyo al primer uso, y acepta las tres
recomendaciones: inspector plegable, clic en perfil = activo, empezar por el esqueleto.

L4. Diagnóstico del inventario que motiva el trabajo: la tabla de mapeo llega a 64 controles interactivos con capa
MOD; el material técnico (matriz de valores, trama USB en hexadecimal, `tccutil`) vive en la ventana diaria; y tras
conceder el permiso de Accesibilidad el conmutador de emulación queda fuera de pantalla a la altura mínima de ventana.

L5. Frontera de entrega: el commit de los prototipos (`17a13b3`) añade 1835 líneas, casi todas HTML de `design/`.
No es un corte de código revisable y no se parte: se revisa como diseño, no como implementación. Los tramos T1 a T6
sí se entregan en cortes de ~400 líneas (S8).

L6. T1 entregado por un worker y corregido aquí antes de commitear. Tres correcciones suyas: los títulos de destino
reutilizaban claves que decían otra cosa («Emulación de ratón y teclado» para Ajustes), así que se añadieron «Mapping»,
«Diagnostics» y «Settings» al catálogo de la ventana; y —la de fondo— dejar el interruptor de emulación solo dentro de
Ajustes convertía en regresión el único paso que un recién llegado necesita, así que la barra de herramientas lleva
ahora la acción principal con la misma regla de permiso que la sección. El inspector se deja para T3, con su regla de
plegado: una tercera columna vacía solo quitaría ancho al mapeo.

L7. Al abrir el mapeo tras meter la barra lateral, las etiquetas largas se cortan («Precisión (ma…», «Alternar clic…»).
El contenido pide 940 de ancho ideal, pero macOS restaura el marco guardado de la ventana anterior, así que la captura
sigue mostrando el ancho viejo. Queda pendiente de verificación visual a 780 de ancho, y T3 es quien lo resuelve de
verdad al agrupar el mapeo en una lista.

L8. El truncado no venía del marco guardado (la ventana ya abría ancha y seguía cortando) sino de la tabla: la
etiqueta de la acción estaba limitada a una línea. Ahora envuelve a dos, sin cambiar ningún texto, así que la
información deja de perderse; el reparto de columnas se ordena de verdad en T3, con la lista agrupada.

L9. T2 entregado y verificado en pantalla: seis perfiles en la barra lateral con su punto de color y el activo marcado,
los cuatro botones ahora en un menú de la barra, y la columna de contenido sin selector ni botones. Las dos preguntas
delicadas —renombrar y eliminar— conservan su alerta y su diálogo destructivo y llaman a `renameSelectedProfile` y
`deleteSelectedProfile`. El worker dejó una duda honesta: la lista se deshabilita al emular porque lo pide S5, y eso es
un endurecimiento deliberado respecto del selector anterior, que no lo estaba. Queda abierto si conviene lo contrario:
durante la emulación el mando ya puede cambiar de perfil, así que la ventana es más restrictiva que el propio mando.

L10. Sobra la clave «Active profile» del catálogo de la ventana, que el selector viejo usaba y ahora nadie resuelve. No
molesta y el test de cobertura no la vigila, porque solo comprueba claves usadas; se limpia cuando se toque el catálogo.

L11. T3 llegó con la suite en rojo: el worker no podía tocar el catálogo y el botón del inspector resolvía dos claves
que no existían («Show inspector» / «Hide inspector»). Es exactamente lo que el test de cobertura vigila, así que se
añadieron con su traducción. Además se corrigieron tres decisiones suyas: el umbral de 1000 dejaba el mapeo por debajo
del ancho usable (ahora 1240, que es la aritmética real: 240 de barra + 620 de contenido + 340 de inspector); el panel
de 300 cortaba las etiquetas de sensibilidad a media palabra, así que mide 340; y por debajo del umbral los ajustes
quedaban inalcanzables, así que el botón puede abrirlo aunque la ventana sea estrecha — una regla de maquetación no
puede convertir un ajuste en inaccesible.

L12. Dos límites de verificación, dichos como son. Primero: la geometría de la ventana la restaura macOS, y con
`.windowResizability(.contentMinSize)` el `.defaultSize(1320×860)` no se aplica; la ventana abre a 900×832 y no puedo
redimensionarla por script porque el proceso no tiene permiso de Accesibilidad. Está verificado que a 900 el inspector
se pliega solo y no se corta nada; **no** está verificado a ojo el caso ancho con el inspector abierto. Segundo: al
forzar el inspector por debajo del umbral el contenido desborda la ventana y se recorta por los dos lados, porque las
tres columnas no caben; se dejó el contenido flexible para reducirlo, pero la solución de fondo es que el umbral no se
fuerce, y eso lo decide quien use la app en pantallas pequeñas.

L13. El usuario concede permiso de Accesibilidad para redimensionar y decide que **la ventana también pueda cambiar de
perfil durante la emulación**. Se hizo con una pulsación que escribe la selección y, si el motor está en marcha, llama a
`EmulationController.switchToProfile`, que delega en `EmulationEngine.switchProfile(to:)` — el mismo camino atómico del
mando, sin reimplementar la liberación. Sin prueba propia: es una envoltura de dos líneas sobre un comportamiento que ya
tiene su test en el motor, y añadir una prueba de la envoltura no probaría nada nuevo.

L14. Verificado en pantalla con la ventana a 1420×860: las tres columnas caben, la tabla de mapeo se lee entera y el
inspector muestra etiqueta y valor en los cinco ajustes del cursor. Queda un defecto menor y conocido: en la columna MOD
el botón «Capturar» se abrevia a «Capt…» porque esa columna es más estrecha; desaparece cuando el mapeo pase a la lista
agrupada prevista en T6.

L15. Queda pendiente revisar el texto de la ayuda del inspector y el estado del permiso de Accesibilidad en el destino
«Ajustes» (T5): hoy el botón de la barra de herramientas se deshabilita sin decir por qué, y ese «por qué» vive en otra
pantalla.
