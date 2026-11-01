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
| T1 | Esqueleto de tres zonas con lo existente recolocado: barra lateral con el mando, destino Mapeo con la sección de perfil entera, inspector vacío, ventana a 780 de ancho sin romperse | S1, S3, S6 | inline | |
| T2 | Lista de perfiles en la barra lateral, con su color; los cuatro botones a un menú de la barra de herramientas | S5, S6 | delegado | |
| T3 | Inspector con color, perfil siguiente, tecla MOD, sensibilidad y precisión; plegado por ancho | S4, S6 | delegado | |
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
