# VR_BUILD — exportación Quest / OpenXR (G10)

Estado: **APK VR GENERADO Y VERIFICADO ESTÁTICAMENTE; NO PROBADO EN HARDWARE**.
El build headless en Termux aarch64 produce un APK firmado (§10). No hay casco
conectado, no se ha instalado nada en un Quest y no se ha ejecutado `adb` contra
un dispositivo. Por tanto **no se afirma que este juego funciona en Quest**.
Cada línea marcada como pendiente necesita una sesión real con el dispositivo.

## 1. Qué se ha verificado aquí

- `tests/test_vr_rig.gd`: 78 aserciones, `PASS (78 assertions)`, `EXIT=0`.
  Cubre: sin OpenXR el rig no se activa ni crashea; construcción del rig con sonda
  simulada; zona del bolso; sacar/guardar; un arma por mano; disparo con una mano;
  locomoción; apuntado a una y dos manos; retroceso/temblor; guardamanos.
- `tools/check_platform_compat.sh`: sin hallazgos graves (ver resultado al final).
- Esas pruebas usan fuentes de entrada simuladas. `XRServer.find_interface("OpenXR")`
  no devuelve una sesión iniciada en este entorno; el código detecta eso con
  `ClassDB.class_exists("OpenXRInterface")` + `find_interface` + `is_initialized()`
  y se queda en modo pantalla.

## 2. Archivos de este corte

- `core/vr/vr_rig.gd` — `VrRig`: origen/cámara/mandos por código, locomoción,
  viñeta, teleport opcional, proveedor de entrada inyectable.
- `core/vr/vr_weapon_hand.gd` — `VrWeaponHand`: bolso → mano, agarre, disparo,
  recarga, háptica, puntería a una/dos manos, retroceso y temblor.
- `scenes/vr/vr_rig.tscn` — escena mínima con el `VrRig` como raíz (`Node3D`).
- `tests/test_vr_rig.gd` — prueba headless sin XRServer real.

`VrRig` y `VrWeaponHand` no tocan `project.godot`, `export_presets.cfg` ni el
manifiesto. Esos cambios los hace el responsable de plataforma.

## 3. Requisitos previos (Android, según documentación oficial 4.7)

- OpenJDK 17 (el editor recomienda 17; superiores funcionan pero no son la referencia).
- Android SDK con Platform-Tools 35.0.0+, Build-Tools 35.0.1, Platform 35,
  Command-line Tools, NDK r28b (28.1.13356709) y CMake 3.10.2.4988404.
- En Ajustes del editor → Android: `Java SDK Path` y `Android SDK Path`
  (el directorio debe contener `platform-tools/adb`).
- Para Quest: activar modo desarrollador en el casco y autorizar depuración USB.
- Sin Gradle build no se puede incluir el loader del proveedor; ver §5.

## 4. Plugin Godot OpenXR Vendors

Procedimiento exacto (documentación oficial de Godot 4.7, *Deploying to Android*):

1. Descargar el plugin desde el Asset Store buscando **"OpenXR vendors"**, o desde
   `https://github.com/GodotVR/godot_openxr_vendors/releases`.
2. Copiar la carpeta `assets/addons/godotopenxrvendors` del ZIP a
   `addons/godotopenxrvendors` dentro del proyecto.
3. En el editor: **Project → Project Settings → Plugins**, marcar el plugin
   *Godot OpenXR Vendors* como Enabled.
4. **Project → Install Android Build Template...**. Esto crea la carpeta `android/`
   en el proyecto; es necesaria para el build Gradle.
5. Reiniciar el editor para que los ajustes XR del plugin aparezcan en la exportación.

Nota oficial: desde Godot 4.6 el plugin es opcional pero recomendado; Godot puede
exportar directamente a muchos dispositivos Android XR. El plugin aporta loaders
específicos y ajustes de proveedor, y puede ser necesario para publicar en tiendas.

## 5. Preset de exportación Android para Quest

1. **Project → Export... → Add... → Android**.
2. Nombre del preset: `Meta Quest` (un preset distinto por dispositivo: cada uno
   lleva su propio loader).
3. Marcar **Use Gradle Build**.
4. **XR Mode = OpenXR**. En `export_presets.cfg` esto corresponde a la clave
   `xr_mode`; **no escribir un valor numérico a mano**: dejar que el editor
   guarde el valor del enum para esta versión y confirmarlo en el archivo.
5. Si se quiere despliegue de un clic: marcar **Runnable**.
6. En **XR Features**, seleccionar la entrada del headset (Meta Quest) aportada
   por el plugin; si no aparece, seleccionar el plugin Khronos. Revisar además la
   sección **Meta XR Features** al final de la lista de opciones.
7. Firma: configurar keystore de debug/release (alias y contraseña). Sin firma
   válida no se instala el APK en el casco.
8. Exportar con **Export With Debug** desmarcado para release.

Rutas y ajustes XR reproducibles en el proyecto (sin los valores numéricos que el
editor genera):

- Renderizador móvil, decisión del brief: en `[rendering]`
  `renderer/rendering_method="mobile"` y `renderer/rendering_method.mobile="mobile"`.
  Hay un conflicto documental registrado en `DECISIONS.md` / R1: la página
  *Deploying to Android* aconseja Compatibility para dispositivos XR Android,
  mientras *Setting up XR* recomienda Mobile para Quest 3. El proyecto elige
  **Mobile**; queda pendiente medirlo en dispositivo.
- OpenXR, en `[xr]`: `openxr/enabled=true`. En el demo oficial de hand tracking
  4.7: `openxr/reference_space` es 0=Local, 1=Stage, 2=Local Floor; la build VR usa **2 (Local Floor)**. Configurar en
  **Project Settings → XR → OpenXR**:
  - Enabled: on (necesario con el backend Vulkan/Mobile).
  - Form Factor: **Head Mounted**.
  - View Configuration: **Stereo**.
  - Reference Space: **Stage** (el rig hace movimiento virtual; *Local Floor*
    se desaconseja con movimiento virtual porque el reciclaje del casco puede
    teletransportar al jugador).
  - Environment Blend Mode: **Opaque** (VR, no passthrough).
  - Startup Alert: off (la aplicación tiene modo pantalla de respaldo; el rig
    comprueba `is_initialized()` por código).
  - Extensions → Hand Tracking: off para la beta de mandos (por defecto viene
    activada por compatibilidad; ver `docs/VR_INPUT_ARCHITECTURE.md`).
  - Opcional en Mobile: foveación fija (en Compatibility usa el ajuste de
    OpenXR; en Mobile/Forward+ se usa `Viewport.vrs_mode = VRS_XR`).

Los nombres de clave anteriores son los que escribe el editor; si este difiere,
prevalece lo que guarde **Project Settings** y el `export_presets.cfg` generado.

## 6. Permisos y manifiesto

- En el preset Android, sección **Permissions**, marcar solo lo que el juego use.
  Las hápticas de este corte pasan por `XRController3D.trigger_haptic`, es decir,
  por la acción OpenXR del runtime: **no** añadir `android.permission.VIBRATE`
  salvo que se añada vibración nativa Android separada.
- No añadir permisos de red, almacenamiento ni body tracking para esta beta
  (body tracking es otra tecnología, fuera de alcance: ver
  `docs/VR_INPUT_ARCHITECTURE.md`).
- Con **Use Gradle Build**, el manifiesto se genera en `android/build/` y el
  loader del plugin inyecta sus propias entradas. Solo editar el manifiesto de la
  plantilla `android/` si se añaden `meta-data` propias de la app; no tratar el
  archivo generado como fuente de verdad.
- Si se sustituye el loader por Khronos (sin plugin de proveedor), usar un preset
  independiente; no mezclar loaders de distintos dispositivos en el mismo APK.

## 7. Arranque en el juego

- La escena `res://scenes/vr/vr_rig.tscn` se puede instanciar siempre. Si no hay
  OpenXR inicializado, `build()` devuelve `false`, no crea nodos XR y el juego
  continúa en modo pantalla.
- Si hay OpenXR, `VrRig` crea `XROrigin3D`, `XRCamera3D` y dos `XRController3D`
  por código, más dos `VrWeaponHand`. La salida XR del viewport la activa
  `VrBootstrap` (ver 7.1); `use_xr` es de `Viewport`, no de `Camera3D`.

### 7.1 Secuencia de arranque VR (build VR, APK híbrido)

Solo la copia `build/vr_project` usa `run/main_scene="res://scenes/vr/vr_boot.tscn"`;
el proyecto principal sigue arrancando en `main_menu.tscn`.

1. `vr_boot.gd._ready` → `VrBootstrap.boot(viewport)`:
   `XRServer.find_interface("OpenXR")` → `initialize()` → `is_initialized()` →
   `XRServer.primary_interface` → vsync off → `viewport.use_xr = true` →
   foveación (nivel de `VrPerformance`, dinámica) → refresco (la tasa disponible
   más alta ≤ 72 Hz de `VrPerformance`, también fija `physics_ticks_per_second`)
   → señales del ciclo de vida. Devuelve `{xr_active, reason}`
   (`ok`, `no_openxr_interface`, `initialize_failed`, `not_initialized`, `no_viewport`).
2. `xr_active=false` (teléfono: la interfaz OpenXR existe pero `initialize()`
   falla) → `change_scene_to_file(main_menu.tscn)`: modo pantalla idéntico al normal.
3. `xr_active=true` → `XROrigin3D` + `XRCamera3D` + 2 `XRController3D` (pose `aim`)
   con láser; `VrGameMode.build_start_menu` crea el panel 3D, que se recoloca
   frente a la cabeza al recibir foco o `pose_recentered`. Gatillo (`trigger` >0.6)
   pulsa. Elegir JUGAR/OTRO MAPA → `GameSession.start` → mundo con `VrRig`.
   Carga el perfil de `VrCalibration` si existe (sin UI de calibración guiada aún).
4. `GameSession.detect_platform()` devuelve `vr` solo si `VrBootstrap.is_xr_active()`
   (antes bastaba `get_interface_count()>0`, que es >0 incluso en headless/teléfono).
5. Ciclo de vida: `session_visible` (menú del sistema/Guardian), `session_stopping`,
   `session_loss_pending` y `user_presence_changed(false)` (casco quitado,
   `XR_EXT_user_presence`) → `SceneTree.paused=true`; `session_focussed` o
   presencia de vuelta con foco → reanuda. Nunca quita una pausa puesta por el juego.
   `session_begun` reaplica el refresco.
6. Opciones XR de la copia (validadas por `build_vr.sh`, `VR_PROJECT_SETTINGS_OK`):
   `openxr/enabled=true`, `shaders/enabled=true`, `reference_space=2`,
   `environment_blend_mode=0` (opaco), `foveation_level=1`, `foveation_dynamic=true`,
   `extensions/user_presence=true`.

### 7.2 Qué revisar en el Quest (no verificable sin casco)

- Arranca dentro del casco (no ventana 2D flotante) y el menú aparece delante a la altura de los ojos.
- Láser visible en ambos mandos y el gatillo pulsa JUGAR / OTRO MAPA.
- `adb logcat -s godot` sin errores OpenXR; refresco real 72 Hz (OVR Metrics).
- Suelo a la altura correcta (Local Floor) y recentrar (botón Meta largo) recoloca el menú.
- Botón Meta / quitarse el casco pausa; volver reanuda.
- En un teléfono el mismo APK abre el menú plano (y aparece en el lanzador).
- Los nombres de acción usados son `grip`, `trigger` y `thumbstick` (vector2).
  Deben existir en el action map de OpenXR del proyecto; si el mapa usa otros
  nombres, hay que enlazarlos en `VrRig.get_stick/is_grip_pressed/is_trigger_pressed`.
- Las armas salen del bolso llevando la mano a la zona trasera/lateral/inferior
  de la cabeza y apretando `grip`. El gatillo dispara con una sola mano. La mano
  secundaria, al entrar en el guardamanos y apretar `grip`, solo cambia la
  dirección de apuntado; nunca es obligatoria para disparar.

## 8. Cómo se verificó en este entorno

```
grun ~/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64 --headless \
  --path ~/UNTITLED --script res://tests/test_vr_rig.gd ; echo EXIT=$?
bash tools/check_platform_compat.sh
```

Resultados de esta ejecución: `PASS (78 assertions)`, `EXIT=0`, y
`RESULTADO: LIMPIO (sin hallazgos graves)`.

## 9. Pendiente de hardware (criterios de aceptación, NO comprobados)

1. Instalar el APK firmado en Quest 3S con modo desarrollador y ver que arranca.
2. Confirmar `XRServer.find_interface("OpenXR")` e `is_initialized()` en el casco,
   y que `use_xr` muestra estereoscopía sin distorsión.
3. Comprobar que los mandos siguen la mano y que `grip` saca/guarda el arma del bolso.
4. Verificar locomoción suave/por pasos, viñeta y teleport, y medir malestar.
5. Verificar disparo con una mano, apuntado a dos manos, recarga por gesto y
   háptica real (frecuencia/amplitud/intensidad).
6. Medir FPS con render activo con el renderizador Mobile; decidir R1 con datos.
7. Repetir la prueba de recentrado del casco con Reference Space = Stage.

Hasta completar esa lista, cualquier mención de "VR funciona" se refiere
únicamente a lógica simulada en headless, nunca al Quest.

## 10. Build real del APK Quest desde Termux (V1)

Script reproducible: `tools/build_vr.sh [ruta_apk]` (por defecto
`~/untitled-control/builds/untitled_vr_debug.apk`). Todo lo específico de VR se
aplica a la copia aislada `build/vr_project/`: el `project.godot` principal, el
preset `Android` y los presets de escritorio no se modifican. Antes de introducir
el preset `Quest VR` se guardó `~/untitled-control/export_presets.cfg.bak-V1-20261120-010607`.

Detalles del addon y del build:

- `Godot OpenXR Vendors 5.2.0-stable` (MIT), descargado de
  `https://github.com/GodotVR/godot_openxr_vendors/releases/tag/5.2.0-stable`,
  verificado por SHA-256. `plugin.gdextension` declara
  `compatibility_minimum = "4.6"`, compatible con Godot 4.7; no hay release
  etiquetada específicamente como 4.7. El ZIP no contiene `plugin.cfg`: el addon
  se habilita como GDExtension (`android_aar_plugin = true`) y sus opciones de
  exportación aparecen en el preset `Quest VR` (`xr_features/enable_meta_plugin=true`,
  `meta_xr_features/quest_3_support=true`). Licencia copiada como
  `addons/godotopenxrvendors/LICENSE-MIT.txt`.
- La plantilla Gradle se instala descomprimiendo
  `~/.local/share/godot/export_templates/4.7.stable/android_source.zip` en
  `build/vr_project/android/build`, con `android/.build_version=4.7.stable`.
- `build/vr_project/android/.gdignore` evita que `--import` escanee la plantilla:
  sin él Godot genera `res/*.webp.import` dentro de `android/build/res` y aapt2
  falla con `The file name must end with .xml or .png`.
- `gradle.properties` de la copia: `org.gradle.daemon=false`,
  `org.gradle.jvmargs=-Xmx1200m -XX:MaxMetaspaceSize=384m`,
  `org.gradle.workers.max=2`, `org.gradle.parallel=false`,
  `kotlin.daemon.jvm.options=-Xmx512m`,
  `android.aapt2FromMavenOverride=$HOME/Android/Sdk/build-tools/34.0.0/aapt2`
  (aapt2 nativo) y `doNotStrip=true` (evita el `llvm-strip` x86-64 del NDK, que
  no puede ejecutarse en aarch64).
- Se usa `JAVA_HOME=$PREFIX/lib/jvm/java-17-openjdk`,
  `ANDROID_HOME=$ANDROID_SDK_ROOT=$HOME/Android/Sdk` y `termux-chroot` porque
  Gradle necesita `/tmp`. Tanto `ANDROID_HOME` como `ANDROID_SDK_ROOT` deben
  apuntar al mismo SDK o AGP aborta con "different paths to the SDK".
- Método: `grun GODOT --headless --path build/vr_project --export-debug 'Quest VR' ...`.
- Escena inicial de la copia: `res://scenes/vr/vr_boot.tscn` (ver 7.1); decide
  VR o pantalla en tiempo de ejecución según `VrBootstrap`.

Comandos ejecutados y códigos de salida (sesión final, 2026-11-20):

```
bash tools/build_vr.sh
IMPORT_EXIT=0 IMPORT_ERRORS=0 IMPORT_FILES=76
EXPORT_EXIT=0 ERRORS=0
SIG_OK / GODOT_LIB_OK / OPENXR_LIB_OK / VR_FEATURE_OK
BUILD_SCRIPT_EXIT=0
grun GODOT --headless --path ~/UNTITLED --script res://tests/test_vr_rig.gd          # EXIT=0, PASS (78 assertions)
grun GODOT --headless --path ~/UNTITLED --script res://tests/test_vr_game_mode.gd    # EXIT=0, PASS (31 assertions)
grun GODOT --headless --path ~/UNTITLED --script res://tests/test_vr_grab_system.gd  # EXIT=0, PASS (104 assertions)
grun GODOT --headless --path ~/UNTITLED --script res://tests/test_vr_reload_gestures.gd # EXIT=0, PASS (72 assertions)
grun GODOT --headless --path ~/UNTITLED --script res://tests/test_game_flow.gd       # EXIT=0, PASS (80 assertions)
bash tools/check_platform_compat.sh                                                 # EXIT=0, LIMPIO (0 graves, 1 informativo)
```

Artefacto: `~/untitled-control/builds/untitled_vr_debug.apk`, 123767488 bytes,
SHA-256 `e487c5eebf0020f77a5397ffe01fa2a50156ef6de2360dbee2ba723208f307ce`.
Verificación: `apksigner verify` OK (v2), `package=org.untitled.vr`,
`uses-feature-not-required android.hardware.vr.headtracking`, permisos
`org.khronos.openxr.permission.OPENXR[_SYSTEM]`, categorías
`com.oculus.intent.category.VR` y `org.khronos.openxr.intent.category.IMMERSIVE_HMD`,
metadatos `com.oculus.supportedDevices`, `com.oculus.vr.focusaware` y
`org.godotengine.plugin.v2.GodotOpenXR`; contiene
`lib/arm64-v8a/libgodot_android.so`, `libgodotopenxrvendors.so` y
`libopenxr_loader.so`. No hay `SCRIPT ERROR` en la exportación ni en las pruebas.

**NO verificado**: arranque real en Quest, sesión OpenXR en el casco,
estereoscopía, seguimiento de mandos, agarre/recarga/hápticas, rendimiento/FPS
ni instalación vía `adb`. El resultado de §9 sigue siendo obligatorio antes de
afirmar que el juego funciona en VR.
