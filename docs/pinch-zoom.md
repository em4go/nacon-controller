# ¿Se puede imitar el pellizco del trackpad?

El pellizco sería el zoom ideal: una sola forma de hacer zoom que funciona en cualquier aplicación, y con la
magnitud controlada por quien lo hace. Este documento recoge qué se midió, porque la conclusión no es una
opinión y conviene que no se repita el trabajo desde cero.

**Respuesta corta: no, no con lo que este proyecto puede usar. Y lo medido no fue la falta de formato, sino
que el sistema descarta el evento.**

## Lo que se sabe de antemano, sin instrumentos

Leído en las cabeceras del SDK de macOS 27:

| Dato | Dónde |
| --- | --- |
| `NSEventTypeGesture = 29`, `NSEventTypeMagnify = 30` existen | `AppKit/NSEvent.h` |
| Existe el tipo `CGGesturePhase` (began, changed, ended, cancelled) | `CoreGraphics/CGEventTypes.h` |
| **No hay ningún campo público de `CGEvent` para la magnificación ni para la fase** | `CGEventTypes.h` |

Se puede *etiquetar* un evento como gesto pero no hay, en la API pública, dónde escribir cuánto amplía.

## Lo que se midió

Andamiaje en la rama local `spike/private-gesture` (nunca fusionada): un receptor AppKit que anota lo que
recibe, y una herramienta que publica eventos. El control es lo primero, porque sin control una ausencia no
significa nada:

| Qué se publicó | Qué llegó a la aplicación |
| --- | --- |
| Rueda normal (control) | sí — `deltaY=30` |
| ⌘+rueda | sí — `deltaY=40`, flags `0x100400` intactos |
| Gesto tipo 29, tres construcciones distintas (campo `0x71`, campo `0x76`, y el contenedor tal cual) | **nada** |
| Las tres fases (`began`, `changed`, `ended`) y dos magnitudes (0,05 y 0,4) | **nada** |
| Gesto tipo 30, y tipo 29 con posición explícita | **nada** |
| Gesto enviado al proceso del receptor con `postToPid` | **nada** — mientras una rueda al mismo proceso sí llega |

El evento, sin embargo, **sí entra en la corriente del sistema** con la carga correcta: un testigo pasivo lee
`tipo=29 subtipo=6 fase=1 mag=0.05` en el mismo instante. Es decir: el contenedor estaba bien construido y
el descarte ocurre después, en el servidor de ventanas, antes de que ninguna aplicación lo vea.

## Conclusión

El formato de los registros no era el ingrediente que faltaba. Lo que falta es lo que sí trae la referencia
ajena (`calftrail/Touch`, GPL) y que esta prueba **no** portó: una cabecera `IOHIDSystemQueueElement` con datos
de dedos del digitizador, para que el evento parezca venir de hardware real. Eso es lo caro:

- formato binario indocumentado, y por tanto a merced de cada versión de macOS;
- requiere un banco de pruebas por versión (este andamiaje lo sería);
- sigue siendo rompible en silencio: el día que cambie, la función desaparece sin avisar;
- y su referencia más conocida es GPL, así que habría que reimplementarlo, no copiarlo.

## Decisión

No se persigue. El zoom queda en lo que sí funciona y está medido en este equipo:

- **⌘+rueda** donde la aplicación lo acepte (confirmado en Figma);
- **⌃+rueda**, que es exactamente lo que macOS entrega a las aplicaciones web cuando se pellizca;
- **⌘+ / ⌘−** en las aplicaciones nativas, con escalón fijo del programa;
- el **zoom de pantalla** de accesibilidad, que es continuo y universal pero amplía la pantalla y depende de
  una opción de Ajustes del Sistema.

Si algún día se retoma, la rama `spike/private-gesture` tiene el andamiaje y el banco de pruebas; lo que falta
es el payload de dispositivo, y la pregunta a contestar antes de escribirlo es si el esfuerzo se justifica para
una función que puede morir en la siguiente actualización del sistema.
