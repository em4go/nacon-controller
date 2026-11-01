# Perfiles con color y cambio desde el mando

El mando tiene un LED multicolor que hasta ahora solo se usaba encendido en azul. Este trabajo hace que el
color sea el del perfil activo y que el perfil se pueda cambiar sin ratón, con la tecla MOD intacta.

## Specs

S1. El LED es multicolor, no azul. Medido en la unidad con una sonda que recorre los patrones del protocolo
XInput: `player1` da **azul**, `player2` **rojo**, `player3` **verde**, `player4` **morado**. El protocolo no
transporta color: transporta el patrón que el fabricante decidió asociar a cada color.

S2. «creo que podría ser guay usar el color como un modo del mando, igual que existen los modos de vim, pero
para el manejo del ordenador. Crees que esto podría tener sentido? sería como mejorar la tecla mod»

S3. «podría ser incluso cambiar entre perfiles simplemente. así sería prácticamente lo mismo que hay ahora
pero se podría cambiar de forma accesible, y manteniendo la tecla mod por si se quiere usar. qué te parece?
antes de empezar»

S4. El color se guarda **en el perfil**. Mientras la emulación corre, la luz del mando es la del perfil
activo; al parar, se apaga. Un perfil cargado de un archivo anterior, sin color, sale azul.

S5. El cambio de perfil desde el mando es **atómico**: antes de cargar el perfil nuevo se suelta todo lo que el
anterior tenía pulsado (teclas, modificadores y botones fijados), y el perfil nuevo se aplica entero, nunca a
medias. Es la única regla que este trabajo no puede saltarse: sin ella, un botón fijado en el perfil anterior
sigue pulsado en el nuevo y el sistema arrastra sin que nadie sepa por qué.

S6. Se ofrecen dos acciones asignables —**perfil siguiente** y **perfil anterior**— que funcionan en la columna
base y en la MOD, como cualquier otra acción. «Anterior» existe porque equivocarse de perfil desde el mando no
debe obligar a coger el ratón.

S7. La tecla MOD no cambia. Es momentánea y el perfil es latente: son dos mecanismos distintos y este trabajo
no los mezcla.

S8. Dos perfiles pueden compartir color. Es decisión del usuario y no se valida; queda anotado como límite.

## Tasks

| ID | Qué | Specs | Ruta | Commit |
| --- | --- | --- | --- | --- |
| T1 | `ProfileColour` en el modelo, con su patrón, y `color` en `InputProfile` con decodificación por defecto | S1, S4 | inline | `b5ff634` |
| T2 | Motor y controlador: las dos acciones, el cambio atómico y la recarga del perfil | S5, S6 | worker | `b5ff634` |
| T3 | La luz toma el color del perfil activo y se apaga al parar | S4 | worker | |
| T4 | Selector de color en la sección de perfiles y entradas de menú, en inglés y español | S2, S6 | worker | |
| T5 | README y paso de aceptación | — | inline | |
| T6 | Verificación: tests, build, app reconstruida y prueba con el mando | S1–S7 | inline | |

## Log

L1. «creo que podría ser guay usar el color como un modo del mando, igual que existen los modos de vim, pero
para el manejo del ordenador. Crees que esto podría tener sentido? sería como mejorar la tecla mod»

L2. «podría ser incluso cambiar entre perfiles simplemente. así sería prácticamente lo mismo que hay ahora
pero se podría cambiar de forma accesible, y manteniendo la tecla mod por si se quiere usar. qué te parece?
antes de empezar»

L3. «he visto 4 colores: azul, rojo, verde y morado. en ese orden»

L4. Decisión: se descarta la entidad «modos» del diseño inicial y se usa el perfil, que ya existe. Se incluyen
las dos acciones (siguiente y anterior) y se deja sin validar la unicidad de colores.

L5. «adelante, pues vamos a por ello»

L6. T1 y T2 se entregan juntos en `b5ff634`, 603 líneas. No se partió porque ambos tocan los mismos archivos
(`InputProfile.swift` lleva el campo de color y la acción de cambio de perfil, `ProfileCoding.swift` los dos)
y un corte por mitades dejaría un commit que no compila. Queda registrado como límite de entrega consciente,
no como descuido: los tramos siguientes van separados —T3/T4 por un lado y documentación por otro—.

L7. T3 y T4 en `d415a33`. La feature completa suma 743 líneas en tres commits (`b5ff634` modelo y cambio de
perfil, `b95d3dd` el registro del límite, `d415a33` la luz y el selector). Se sube la rama `feature/profile-colour`
en lugar de partir más: los tres commits compilan y pasan la suite por separado, y el corte de revisión ya está
identificado en L6. Queda pendiente la prueba con el mando —pasos 32 a 34— y la fusión a `main`, que decide el
usuario.

L8. Pasos 32, 33 y 34 verificados con el mando el 2026-11-01: el color sigue al perfil y cambia en caliente, el
cambio suelta lo fijado y lo mantenido, y el recorrido da la vuelta en ambos sentidos. Fusionada a `main` en
`f9b3758` con `--no-ff`; la rama de trabajo se borra.
