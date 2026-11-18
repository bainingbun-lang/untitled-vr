# PLATFORM_ARCHITECTURE — UNTITLED como plataforma de creación

Estado: **PROPUESTA — PENDIENTE DE APROBACIÓN**. Nada de este documento está implementado.

Leyenda:
- **[CONFIRMADO]**: decisión explícita del usuario (`DECISIONS.md`).
- **[VERIFICADO]**: probado en spike (ver `spikes/RESULTS.md`), en Linux arm64 headless. No es Android dentro de Godot.
- **[NO PROBADO]**: afirmación sin prueba. No se debe presentar como capacidad.
- **[PROPUESTA]**: diseño nuevo que requiere aprobación.

---

## 1. Arquitectura general

- **[CONFIRMADO]** Motor: Godot 4.7. Objetivo: Android, PC y VR desde el diseño.
- **[CONFIRMADO]** Mods en GDScript (T2) y sin límite de lenguaje.
- **[VERIFICADO]** Carga de PCK de mod en tiempo de ejecución (`ProjectSettings.load_resource_pack`).
- **[VERIFICADO]** Lua 5.4.9 y wasmtime 50.0.2 funcionan en VM de Termux, con corte de bucle y límite de memoria.
- **[NO PROBADO]** Lua/wasm/GDExtension dentro de Godot en Android.

**[PROPUESTA]** Tres capas:

```
┌──────────────────────────────────────────────┐
│ Experiencia (escenas, reglas, misiones)      │  ← lo que crea el modder
├──────────────────────────────────────────────┤
│ Módulos (paquetes PCK + manifiesto)           │  ← sustituibles/desactivables
├──────────────────────────────────────────────┤
│ Núcleo (bus de eventos, registro, ciclo de   │  ← mínimo, estable, versionado
│ vida, carga de módulos, permisos, perfilado) │
└──────────────────────────────────────────────┘
```

Regla: el núcleo no conoce ningún sistema de juego concreto (cámara, IA, armas). Esos sistemas son módulos del juego base que usan la misma API pública que cualquier mod.

## 2. Separación núcleo / módulos

| Núcleo (no reemplazable) | Módulos (reemplazables) |
|---|---|
| Registro de módulos y dependencias | Cámara, movimiento, controles |
| Bus de eventos y señales | Física de objetos, colisiones |
| Carga/descarga de PCK | Inventario, objetos, interacciones |
| Permisos y aislamiento | IA, NPC, vehículos, combate |
| Guardado (formato versionado) | Interfaz, audio, misiones, economía |
| Perfilado y registro de errores | Generación de mundos, construcción |

**[PROPUESTA]** El juego base UNTITLED es un módulo más (`untitled.base`), con prioridad mínima. Así el modo "videojuego" y el modo "plataforma" usan el mismo mecanismo.

**[PENDIENTE]** Protección del núcleo: el PCK base debe cargarse antes que los mods (TASKS #8). El spike M1 mostró que `replace_files=false` **no** protege `res://` del proyecto; solo protege archivos ya cargados desde otro PCK (ERRORS.md).

## 3. Sistema de extensiones

Puntos de extensión propuestos:

| Punto | Mecanismo | Estado |
|---|---|---|
| Nuevo tipo de objeto | Registro por `id` con `Resource` base | PROPUESTA |
| Sustituir comportamiento | Módulo declara `replaces: [id]`; el núcleo elige el de mayor prioridad | PROPUESTA |
| Añadir estado/evento | Bus de eventos con nombres `namespace.evento` | PROPUESTA |
| Sustituir escena/script | Override de ruta `res://` tras carga de PCK | VERIFICADO con `replace_files=true`; semántica de conflicto PENDIENTE |
| Lógica en Lua/wasm | Host sandbox que expone API limitada | NO PROBADO en Godot |

**[PROPUESTA]** Módulos declaran qué sustituyen. Dos módulos sobre el mismo `id` sin prioridad explícita producen **error de carga**, no comportamiento indefinido.

## 4. API pública

**[PROPUESTA]** Capas de API, de estable a experimental:

1. **Estable** (versionada semver): eventos, registro de objetos, recursos, ciclo de vida de módulo.
2. **Extendida**: acceso a escena, física, IA mediante interfaces. Puede cambiar en minor con aviso.
3. **Avanzada / código fuente**: acceso al código del base. Sin garantías, documentado como tal.

No ocultar funcionalidades: lo que existe en el núcleo se documenta. Las restricciones se explican, no se esconden.

## 5. Comparación de lenguajes

| Lenguaje | Rendimiento | Android | VR | Estado en proyecto |
|---|---|---|---|---|
| GDScript | Adecuado para lógica de juego (N1: 8000 agentes ≈ 10.6 ms/tick, solo CPU) | Nativo | Nativo | **[CONFIRMADO]** |
| Lua | 25.8 ns/llamada (VM Termux) | Sin verificar | Sin verificar | VM probada; integración NO PROBADA |
| WebAssembly (wasmtime) | Bucle 5M ≈ 30 ms (VM Termux); límites OK | Sin verificar | Sin verificar | VM probada; integración NO PROBADA |
| C# (Godot Mono) | No medido | **NO VERIFICADO** | **NO VERIFICADO** | No evaluado |
| GDExtension nativa | No medido | Requiere compilar por ABI | Requiere compilar por ABI | No evaluado |

No se elige un lenguaje único. La recomendación es GDScript como lenguaje base de mods y una segunda vía (Lua o wasm) para sandbox, tras probarla dentro de Godot en Android. Esto **no está aprobado**.

## 6. Diseño del SDK

**[PROPUESTA]** Componentes:

- Plantilla de proyecto de mod (`mod.json` + escena/recursos + tests).
- Validador de manifiesto y de dependencias.
- Empaquetador a PCK.
- Inspector de eventos y objetos registrados.
- Ejecutor de pruebas dentro del editor sin reconstruir el juego.

Prerrequisito: el empaquetado PCK funciona [VERIFICADO], pero el flujo de exportación de mods en Android sigue **NO VERIFICADO** (JDK 17 y editor Android pendientes, TASKS #1–#4).

## 7. Herramientas para creadores

**[PROPUESTA]** Por fases, de menor a mayor coste:

1. Documentación y ejemplos en el repositorio.
2. Recursos editables (`Resource` tipados) que se pueden crear desde el inspector de Godot.
3. Editores de dominio (mapas, NPC, misiones) construidos sobre el inspector.

No construir editores de dominio antes de tener la API estable: serían reescrituras.

## 8. Compatibilidad Android, PC y VR

- **[CONFIRMADO]** VR (Quest) se diseña desde el principio.
- **[PENDIENTE]** Renderizador: Mobile vs Compatibility para XR (R1 bloqueado; conflicto documental en DECISIONS.md).
- **[PROPUESTA]** Cada módulo declara plataformas soportadas en su manifiesto. Un mod no se considera multiplataforma sin prueba en cada plataforma declarada.
- **[PROPUESTA]** Restricciones a documentar por plataforma: permisos de Android para escritura y carga de archivos, disponibilidad de extensiones nativas, y cualquier limitación de la tienda.

## 9. Gestión de dependencias

**[PROPUESTA]** Manifiesto `mod.json`:

```json
{
  "id": "autor.nombre",
  "version": "1.2.0",
  "engine": "4.7",
  "api": "1.x",
  "depends": { "untitled.base": ">=1.0 <2.0" },
  "replaces": ["untitled.base:inventory"],
  "priority": 100,
  "platforms": ["android", "pc"],
  "permissions": ["filesystem.read"],
  "rating": "18+"
}
```

- Resolución de dependencias con versiones semver.
- Orden de carga = topológico, luego por `priority`.
- Conflictos: mismo `replaces` sin prioridad distinta → error.
- Perfiles: conjunto de mods activos guardado por separado; el guardado registra qué mods lo usaron.

## 10. Seguridad

- **[CONFIRMADO]** Mods T2 en GDScript con advertencia y elección explícita.
- **[PROPUESTA]** El usuario ve y aprueba permisos antes de instalar (lectura de archivos, red, acceso a guardado).
- **[PROPUESTA]** GDScript y GDExtension tienen acceso completo al proceso; no hay sandbox en esos casos. Esto debe mostrarse al usuario.
- **[PROPUESTA]** Lua y wasm como vía con aislamiento; sus límites de memoria y CPU se verificaron fuera de Godot, no dentro.
- Firma de paquetes: **[PENDIENTE]** no evaluada.

## 11. Rendimiento

- **[VERIFICADO]** `load_resource_pack` de PCK pequeño: 1.6–5.7 ms (Linux arm64). No es medición de Android.
- **[VERIFICADO]** N1: solo CPU, sin render ni física. Tendencia, no capacidad de juego.
- **[PROPUESTA]** Carga bajo demanda por módulo, descarga explícita, y simulación por proximidad (niveles de detalle).
- **[PROPUESTA]** Perfilado por módulo: tiempo por evento y memoria, expuesto en el SDK.
- Objetivo 60 FPS en S25 FE: **[CONFIRMADO]** como objetivo, **[PENDIENTE]** de medición.

## 12. Plan de implementación por etapas

Ninguna etapa empieza sin aprobación.

| Etapa | Contenido | Depende de |
|---|---|---|
| E0 | Verificar editor Android y JDK 17 (TASKS #1–#4) | Acceso al teléfono |
| E1 | PCK base + carga ordenada (TASKS #8) | E0 |
| E2 | Núcleo: registro, bus de eventos, manifiesto, dependencias | E1 |
| E3 | Módulo de referencia `untitled.base` con cámara y controles | E2 |
| E4 | SDK mínimo: plantilla, validador, empaquetador | E2 |
| E5 | Sandbox Lua o wasm dentro de Godot en Android (prueba) | E2, E0 |
| E6 | Perfilado y diagnóstico de conflictos | E2 |
| E7 | Distribución manual de paquetes y documentación | E4 |

## Estado de aprobación (2026-11-18)

Aprobado por el usuario (registrado en `DECISIONS.md`):
- Tres capas; núcleo mínimo independiente de los sistemas del juego.
- `mod.json` como formato inicial, versionado y extensible.
- Error de carga ante sustitución del mismo sistema sin prioridad explícita; dependencias y conflictos documentados.
- GDScript como base. Lua y WASM: alternativas por investigar, **no integrar** hasta verificarlas en Android, PC y VR.
- Etapas E0–E7 como enfoque progresivo; orden reorganizable con razón técnica documentada.
- Firma de paquetes: investigar integridad, procedencia y confianza; instalación manual de no verificados con advertencia.
- Todas las plataformas modificables; mods no limitados a contenido.

Requisito del usuario, incorporado como propuesta (no aprobado todavía como decisión):
- Libertad tecnológica: cualquier lenguaje, framework, biblioteca o herramienta útil, sin que el lenguaje limite lo que un creador puede hacer. Se evalúa caso por caso; no implica integrar todo.

## Libertad tecnológica e interoperabilidad (PROPUESTA)

**Principio:** el lenguaje no determina la capacidad del mod. Cada tarea usa la tecnología más adecuada, y la plataforma define qué puede cargarse.

**Clasificación de tecnologías por mecanismo de integración:**

| Mecanismo | Ejemplos | Cómo se conecta | Coste |
|---|---|---|---|
| Script nativo de Godot | GDScript | Directo | Bajo |
| Extensión nativa de Godot | GDExtension (C, C++, Rust) | Biblioteca compartida por plataforma | Alto: compilación por ABI y por plataforma |
| Módulo en VM embebida | Lua, WASM (wasmtime, etc.) | Host expone API limitada | Medio |
| Proceso externo | Python, Java/Kotlin, JavaScript, herramientas de contenido | IPC (socket, pipes, stdin/stdout) o ficheros | Alto en Android y VR; posible solo en PC |
| Herramientas de build | Compiladores, SDK | Solo en el flujo de creación, no en runtime | No aplica en runtime |

**Interoperabilidad entre módulos de distintos lenguajes (PROPUESTA):**
- Contrato común: todas las capacidades se expresan como eventos y llamadas con un formato de datos neutro (JSON o MessagePack), versionado en la API.
- Un módulo nunca llama directamente a otro lenguaje. Pasa siempre por el bus de eventos del núcleo o por un adaptador de su mecanismo.
- Un adaptador por mecanismo (GDScript, Lua, WASM, GDExtension, proceso externo). Añadir un lenguaje nuevo = añadir un adaptador, sin tocar el núcleo.

**Estado por plataforma (NO VERIFICADO salvo lo indicado):**

| Tecnología | PC (Linux/Windows) | Android | VR (Quest) |
|---|---|---|---|
| GDScript | Funciona en el editor/Linux [VERIFICADO: M1, N1] | No probado en Android dentro de Godot | No probado |
| Carga de PCK | [VERIFICADO: Linux arm64 headless] | NO VERIFICADO | NO VERIFICADO |
| Lua | VM probada en Termux [VERIFICADO: M2] | NO PROBADO dentro de Godot | NO PROBADO |
| WASM (wasmtime) | VM probada en Termux [VERIFICADO: M2] | NO PROBADO dentro de Godot | NO PROBADO |
| GDExtension | NO PROBADO | NO PROBADO (requiere binarios por ABI) | NO PROBADO |
| Proceso externo | Posible en principio; NO PROBADO | Restringido por el sistema; NO VERIFICADO | No aplicable sin verificar |
| C# (Godot Mono) | NO PROBADO | NO VERIFICADO | NO VERIFICADO |

**Restricciones reales a documentar:**
- Android: sin acceso libre al sistema de archivos ni ejecución de binarios arbitrarios desde la app; las extensiones nativas deben empaquetarse por arquitectura (arm64).
- VR: mismas restricciones de Android en Quest; el rendimiento de VM embebidas debe medirse con el renderizado activo.
- PC: menos restricciones, pero no debe ser la única plataforma donde funciona un mod.

**Pruebas necesarias antes de declarar cualquier tecnología compatible:** carga en Godot dentro de Android (APK instalado), ejecución del mod y medición de rendimiento. Hasta entonces, cada entrada permanece NO PROBADA.

**Acceso avanzado para desarrolladores (PROPUESTA):** API pública documentada; acceso al código fuente del núcleo y del juego base; herramientas de inspección de eventos y objetos. Ninguna funcionalidad se oculta sin motivo técnico documentado.

## Decisiones de la propuesta inicial (resueltas, ver sección anterior)

1. Tres capas (núcleo / módulos / experiencia) y regla de no conocimiento del núcleo sobre sistemas de juego.
2. Manifiesto `mod.json` y sus campos.
3. Error ante conflictos sin prioridad explícita.
4. Lenguaje base GDScript más una segunda vía sandbox (Lua o wasm), pendiente de prueba en Android.
5. Orden de etapas E0–E7.
6. Firma de paquetes: evaluar o descartar.

## Riesgos técnicos

- Sandbox Lua/wasm dentro de Godot en Android: NO PROBADO. Puede no ser viable.
- Override de `res://` sin garantía de protección del núcleo sin PCK base.
- C# en Android: NO VERIFICADO.
- Renderizador XR sin decidir (R1 bloqueado).
- Carga de PCK en Android: NO VERIFICADO (solo Linux arm64).
- Distribución fuera de Play: depende de permisos de instalación y de la política de cada tienda.
