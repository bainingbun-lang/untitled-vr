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

## Estrategia

- Rutina y tareas mecánicas: OpenCode con modelos `-free`.
- Decisiones de diseño, arbitraje y revisión: Claude.
- Día sin Claude: domingo.

## Reglas

- No afirmar cifras de coste o cuota sin medición.
- Registrar consumo real cuando exista una fuente de datos.
