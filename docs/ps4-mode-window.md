# La ventana de modo PS4, medida

Pregunta: el mando aparece unos instantes como `146B:0D05` antes de re-enumerarse como XInput.
¿Por qué se cierra, y ese modo expone el touchpad?

Herramienta: `nacon-ps4probe` (`swift run nacon-ps4probe [segundos] [--no-open]`).

## Método

Dos capturas de 40 s, cada una con dos reconexiones del mando:

- **Control** (`--no-open`): solo se observa la aparición y la desaparición.
- **Tratamiento**: además se abre el dispositivo HID y se registra un lector de informes,
  para probar la hipótesis del vigilante («watchdog») que documenta `evdev-keepalive` para
  mandos 8BitDo: el firmware reinicia el dispositivo si no ve tráfico del anfitrión.

## Duración de la ventana

| Captura | Repetición 1 | Repetición 2 |
| --- | --- | --- |
| Control | 0,225 s | 0,232 s |
| Tratamiento | 0,244 s | 0,248 s |

Abrir el dispositivo y leer sus informes alarga la ventana unos 16–19 ms (≈7 %). La diferencia
es consistente y los dos grupos no se solapan, pero **no cambia nada**: en el tratamiento tampoco
se recibió ni un solo valor de entrada. La ventana sigue siendo demasiado corta para usarla, y no
se acerca a sostenerse.

## El descriptor HID que presenta en esa ventana

171 bytes, capturados en `/tmp/nacon-rdesc-0D05.bin`, guardados aquí como evidencia:

```
00000000: 0501 0905 a101 8501 0930 0931 0932 0935  .........0.1.2.5
00000010: 1500 26ff 0075 0895 0481 0209 3915 0025  ..&..u......9..%
00000020: 0735 0046 3b01 6514 7504 9501 8142 6500  .5.F;.e.u....Be.
00000030: 0509 1901 290e 1500 2501 7501 950e 8102  ....)...%.u.....
00000040: 0600 ff09 2075 0695 0181 0205 0109 3309  .... u........3.
00000050: 3415 0026 ff00 7508 9502 8102 0600 ff09  4..&..u.........
00000060: 2195 3681 0285 0509 2295 1f91 0285 030a  !.6.....".......
00000070: 2127 952f b102 0680 ff85 e009 5795 02b1  !'./........W...
00000080: 02c0 06f0 ff09 40a1 0185 f009 4795 3fb1  ......@.....G.?..
00000090: 0285 f109 4895 3fb1 0285 f209 4995 0fb1  ....H.?.....I...
000000a0: 0285 f30a 0147 9507 b102 c0              .....G.....
```

Interpretación de sus ítems:

| Contenido | Detalle |
| --- | --- |
| Página de uso `0x01`, uso `0x05` | Ratón/teclado genéricos: **Game Pad** |
| Ejes X, Y, Z, Rz | 4 ejes de 8 bits, rango 0–255 |
| Hat switch | 4 bits, 0–7, unidades de 315° |
| Página `0x09`, usos 1–14 | 14 botones |
| Rx, Ry | 2 ejes más de 8 bits |
| Páginas de proveedor `0xFF00`, `0xFF80`, `0xFFF0` | Canales propietarios de entrada, salida y *feature* |
| **Página `0x0D` (Digitizer)** | **ausente** |

Un DualShock 4 auténtico declara la página `0x0D` con el uso *Touch Pad* (0x05), además de
giroscopio y acelerómetro, en un descriptor de unos 467 bytes con identificadores de informe
del `0x01` al `0x11`. Este descriptor no se parece a eso: es un gamepad genérico con canales
de proveedor.

## Conclusión

El touchpad **no está expuesto al anfitrión en ningún modo alcanzable**:

- En modo XInput no produce ninguna señal, medido con control positivo (`nacon-touchpad`).
- En la ventana de modo PS4 tampoco: el descriptor no declara ni la página de digitizer, y no se
  recibió ningún informe.

No es un problema de tiempo ni de handshake: aunque la ventana durase para siempre, no habría
touchpad que leer. Perseguir el protocolo de PlayStation 4 no habría dado acceso a él.
