# Pruebas débiles pendientes de limpiar

Dos tests que no pueden fallar por la razón correcta. No los borro yo: quedan apuntados aquí para
quien los mantiene.

## 1. `testCancelledCaptureLeavesThePreviousMappingUntouched` — borrar

`Tests/NaconCoreTests/MappingRulesTests.swift:88`

```swift
guard case .cancel = MappingRules.capture(forKeyCode: VirtualKey.escape.rawValue, modifiers: [])
else { return XCTFail("plain Escape must cancel") }

XCTAssertEqual(profile.action(for: .buttonA), before)
```

Solo invoca una función pura que no puede mutar nada y después comprueba que nada cambió. Pasaría
aunque se borrase todo el código de protección.

**Cubierto de verdad por** `KeyCaptureSessionTests.testCancellingLeavesThePreviousMappingUntouched`
(`Tests/NaconCoreTests/KeyCaptureSessionTests.swift:110`), que recorre la sesión real de captura.

## 2. `testRuntimeProfileUsesTheFirstProfileWhenTheSelectionDangles` — arreglar o borrar

`Tests/NaconCoreTests/RuntimeProfileTests.swift:57`

En el fixture, `profiles[0]` **es** el perfil estándar (`libraryWithCustomSelection()`, línea 16). Por
eso «usar el primer perfil» y «caer al perfil estándar» devuelven el mismo valor, y las dos
aserciones no distinguen una conducta de la otra.

- **Si se quiere conservar:** reordenar el fixture para que el primer perfil no sea el estándar.
- **Si se borra:** la reserva ante una selección desconocida sigue cubierta a nivel de archivo por
  `ProfileStoreTests`, que comprueba el caso de un `profiles.json` con una selección desconocida.

## Después de limpiar

```bash
swift test
```

Deben quedar 161 tests menos los borrados, sin fallos.
