# ¿Tiene el mando sensores de movimiento?

Pregunta: este mando, ¿publica acelerómetro o giroscopio que la app pueda usar?

Herramienta: `nacon-motion` (`swift run nacon-motion [segundos]`), escrita para esta pregunta.

## Por qué se mira en los bytes 14-19

El informe XInput tiene 20 bytes y el protocolo describe 14 útiles. Los seis últimos van como
reservados, y la app los ignora. **Si el mando tuviera sensores y los publicara en este modo, su rastro
estaría exactamente ahí**, porque no queda otro sitio.

La sonda no interpreta nada: cuenta valores distintos por byte y avisa de cada cambio. Así, mover el
mando en el aire se ve —o no se ve— sin que nadie tenga que creer una interpretación.

## Medición (2026-10-29)

30 s con el mando en la mano, moviéndolo en el aire, sin pulsar botones ni el touchpad.

| Byte | Valores distintos | Cambios |
| --- | --- | --- |
| 14 | 1 (`00`) | 0 |
| 15 | 1 (`00`) | 0 |
| 16 | 1 (`00`) | 0 |
| 17 | 1 (`00`) | 0 |
| 18 | 1 (`00`) | 0 |
| 19 | 1 (`00`) | 0 |

**7.542 informes recibidos** (≈251 por segundo, el ritmo de 4 ms del mando) y ni un solo cambio en esos
bytes. El resto del paquete sí responde: es el mismo camino que la app usa para botones y sticks, así
que no es una prueba ciega.

## Veredicto

En modo XInput el mando **no publica movimiento**. Dos causas posibles y no distinguibles desde el
anfitrión: el hardware no lleva sensores, o el firmware no los expone en este modo.

La nota que inclina la balanza: en la ventana de modo PS4 el descriptor HID **sí declara** los ejes
`Rx`/`Ry` y un bloque de 54 bits en la página de proveedor, que es donde un DualShock 4 lleva el
movimiento. Pero esa ventana dura 0,23 s y no entrega ni un informe (`docs/ps4-mode-window.md`), así que
por esa vía no se puede leer nada hoy.

## Qué haría falta para asegurarlo

- **Linux como anfitrión**: sus controladores para `146b:0603` son más habladores que macOS en este
  dispositivo, y el RFC de Bilotta sobre este mismo mando es el punto de partida.
- **Documentación del fabricante** o una captura del bus en la ventana de PS4. Sin alguna de las dos, que
  el mando tenga sensores es una posibilidad, no un hecho.

## Lo que no merece la pena

Sostener la ventana de PS4 enviando paquetes de salida durante ese cuarto de segundo. La ventana se
cierra por el firmware, no por falta de tráfico del anfitrión: la prueba de control y la de tratamiento
se solaparon en el tiempo de vida (0,225–0,232 s frente a 0,244–0,248 s) pero en ninguna llegó un
informe utilizable. Si algún día se quiere intentar, ya existe `nacon-ps4probe` para hacerlo con medición
delante.
