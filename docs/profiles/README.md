# Propuesta de perfiles: Ratón, Texto y Dibujo

`raton-texto-dibujo.json` contiene tres perfiles escritos a mano para usar el ordenador con el mando sin
tocar la ventana. No se cargan solos: son una propuesta, no parte de la aplicación.

## La gramática que comparten

Los tres usan **L2 como tecla MOD** y el **mismo gesto de cambio de perfil**: con MOD pulsado, **L3** pasa al
perfil siguiente y **R3** al anterior, con vuelta en los dos sentidos. Que los tres compartan el gesto y la
tecla MOD no es una coincidencia estética: si uno solo lo perdiera, desde ese perfil no habría manera de
volver sin el ratón.

| Perfil | Color | Para qué |
|---|---|---|
| Ratón | azul | Uso general: puntero, clic, arrastre, atajos de edición |
| Texto | verde | Leer, escribir y navegar: portapapeles, principio y fin de línea y de documento |
| Dibujo | morado | Herramientas de dibujo: modificadores en L3 y R3, nudge con flechas, zoom con ⌘+rueda |

## Cómo aplicarlos

1. Cierra la aplicación: carga los perfiles al arrancar y los reescribe con cada cambio, así que con ella
   abierta el archivo que escribas desaparece.
2. Copia `~/Library/Application Support/NaconController/profiles.json` a otro sitio.
3. Añade los objetos de `profiles` al final del array `profiles` del archivo real. Los identificadores son
   únicos: no hace falta tocarlos.
4. Abre la aplicación y comprueba que aparecen los tres.

## Lo que no son

No están probados en uso real: son plausibles, no buenos. El detalle que los hará buenos lo dirá quien los
use, y se cambia en la ventana sin tocar código. Dos decisiones que conviene saber antes de probarlos:

- **⌘ mantenido en R2** (Ratón, Dibujo) y **en □** (Texto) convierte el mando en un modificador vivo: mientras
  lo sostienes, también afecta a lo que teclees en el teclado físico.
- **L3 y R3 como modificadores** (solo Dibujo) pueden dispararse sin querer al empujar el stick; por eso el
  cambio de perfil vive detrás de MOD y no en L3 pelado.
