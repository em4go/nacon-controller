# Resumen de mapeos (MOD + PS)

Un modal estilo Spotlight que muestra de un vistazo qué hace cada control del perfil activo. Se abre
y se cierra con **MOD + PS**, que nadie reasignará: PS es el interruptor de la emulación y está
reservada.

## Specs

S1. Con la tecla MOD pulsada, pulsar PS abre o cierra el resumen; **no** cambia la emulación: leer el
    mapa no puede apagar el pad.
S2. PS sin MOD sigue haciendo lo de siempre: encender o apagar la emulación.
S3. El resumen funciona con la emulación apagada (MOD+PS abre el modal sin encender nada).
S4. Muestra cada control remapeado con su acción en la base y, si el perfil tiene capa MOD, su acción
    en la capa. Los controles sin asignar no aparecen.
S5. El modal no roba el foco ni bloquea el ratón: es un panel flotante que se puede ignorar.
S6. Apagar la emulación cierra el resumen si estaba abierto.
S7. Los perfiles guardados sin este cambio siguen funcionando: el resumen solo lee, no escribe nada.

## Tasks

| ID | Specs | Ruta | Commit |
| --- | --- | --- | --- |
| T1 | S1, S2, S3 | motor: PS con MOD → `onSummaryPress`, sin tocar el toggle | `e2d6412` |
| T2 | S4, S5, S6 | panel flotante con la tabla de mapeos y su cableado | pendiente de commit |
| T3 | S7 | documentación y aceptación | — |

## Log

L1. «me gustaría añadir una forma de recordar los comandos según están creados en la app. Es posible
    poner algún atajo para que en la pantalla salga un modal con un resumen de los mapeos? algo
    similar a lo que hace spotlight pero para mostrar lo que pido. El atajo podría ser mod+PS, ya que
    nadie va a configurar PS por ser la que enciende y apaga el control con el mando»

L2. El panel se verificó con capturas reales, no solo compilando: primero no aparecía. La causa fue la
    suscripción a `$isEnabled`, que entrega el valor actual al instalarse y con la emulación apagada
    cerraba el panel recién abierto; se arregló con `dropFirst`. Con un perfil con capa se comprobaron
    las tres columnas y el «—» de los controles que la capa no redefine.

L3. Se añadió un argumento de desarrollo (`--show-summary`) que abre el panel sin mando, para poder
    capturarlo. Es la única forma de ver un panel flotante sin hardware.
