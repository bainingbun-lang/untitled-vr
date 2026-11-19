# TOKEN_BUDGET

## Proveedores y modelos conocidos

| Elemento | Estado |
|---|---|
| OpenCode 1.19.5 | Operativo |
| Modelos listados (`opencode models`, 2026-11-18) | 12: 11 con sufijo `-free` + `opencode/big-pickle` |
| Coste declarado por OpenCode | 0 en input/output para los 12 modelos (metadatos del catálogo, NO verificado contra facturación) |
| Coste de `opencode/big-pickle` | DESCONOCIDO. No usar hasta verificarlo (instrucción del usuario) |
| Modelo recomendado para rutina | `opencode/deepseek-v4.1-flash-free` (usado en T-EXPORT-TRIAGE sin incidencias registradas) |
| Cuota / consumo real | DESCONOCIDO (sin datos de consumo) |
| Límites de uso de los modelos `-free` | DESCONOCIDO |
| Modelo usado en T-EXPORT-TRIAGE | `deepseek-v4.1-flash-free` |

## Delegación a OpenCode (T1–T6)

| Tarea | Contenido | Modelo | Resultado | Verificación |
|---|---|---|---|---|
| T1 | Validador de `mod.json` y prueba | `opencode/deepseek-v4.1-flash-free` | ACEPTADA (`c85d736`) | `test_mod_manifest.gd` PASS |
| T2 | Validador de conflictos con propietario (opción A) | `opencode/deepseek-v4.1-flash-free` | ACEPTADA (`08e8abd`) | `test_mod_manifest.gd` PASS |
| T3 | Resolver de dependencias y bus de eventos | `opencode/deepseek-v4.1-flash-free` | ACEPTADA (`a3bed28`) | `test_mod_resolver.gd`, `test_event_bus.gd` PASS |
| T4 | Registro, API por módulo, carga y descarga | `opencode/deepseek-v4.1-flash-free` | ACEPTADA (`d808b94`) | `test_mod_registry.gd` PASS |
| T5 | Mod de ejemplo PCK y prueba de carga/descarga | `opencode/deepseek-v4.1-flash-free` | ACEPTADA (`de457b2`) | `test_example_mod.gd` PASS |
| T6 | Documentos de estado y guía `docs/MOD_SYSTEM.md` | `opencode/deepseek-v4.1-flash-free` | EJECUTADA, pendiente de revisión | `bash tests/run_all.sh` PASS |

Coste de T1–T6: DESCONOCIDO. El catálogo declara 0 en input/output para el modelo, no verificado contra facturación. No se usó `opencode/big-pickle`.

## Estrategia

- Rutina y tareas mecánicas: OpenCode con modelos `-free`.
- Decisiones de diseño, arbitraje y revisión: Claude.
- Día sin Claude: domingo.

## Reglas

- No afirmar cifras de coste o cuota sin medición.
- Registrar consumo real cuando exista una fuente de datos.
