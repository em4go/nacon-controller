# Comandos personalizados

Catálogo de comandos con nombre (Copiar, Pegar…) y acciones de varios pasos, sin capturar cada uno a
mano. Rama `main`.

## Specs

S1. En el menú de asignación aparecen, con su nombre, «copiar (cmd + c)», «pegar (cmd + v)», cortar,
    deshacer, rehacer, seleccionar todo, guardar, buscar, imprimir, nueva pestaña, cerrar pestaña y
    pegar sin formato. No hace falta capturarlos con el teclado.
S2. Una acción puede ser una **secuencia**: «un botón que hace ⌘A y después ⌘C, en orden».
S3. Los pasos se emiten en orden, uno por tick del motor. Una pulsación ejecuta la secuencia una vez;
    mantener el botón no la repite.
S4. Soltar el botón cancela los pasos que falten y no deja ninguna tecla pulsada.
S5. Un perfil guardado sin secuencias se lee igual que hoy. Una secuencia ilegible no rompe el perfil:
    se descarta la acción, no la asignación.
S6. La interfaz muestra una secuencia como «⌘A luego ⌘C» y permite añadir y quitar pasos.
S7. Las acciones que ya existen no cambian: un `.key` sigue siendo un `.key`, y el catálogo nuevo
    escribe exactamente lo que escribiría una captura de esa misma combinación.

## Tasks

| ID | Specs | Ruta | Commit |
| --- | --- | --- | --- |
| T1 | S2, S5 | modelo `MappedAction.sequence` y su codificación | — |
| T2 | S3, S4 | motor: ejecución por ticks y cancelación al soltar | — |
| T3 | S1, S7 | catálogo con nombres de edición | — |
| T4 | S6 | interfaz: menú, editor de pasos, etiqueta | — |

## Log

L1. «ahora quiero que se puedan añadir comandos personalizados complejos, como por ejemplo: copiar
    (cmd + c), pegar (cmd + v), etc.»

L2. Decisión del usuario sobre el alcance: «Las dos cosas» — el catálogo con nombres y además poder
    encadenar varios pasos en un mismo comando.
