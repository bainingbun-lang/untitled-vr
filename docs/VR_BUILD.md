# VR_BUILD — exportación Quest / OpenXR (G10)

Estado: **DOCUMENTACIÓN DE PROCEDIMIENTO, NO VERIFICADA EN HARDWARE**.
Aquí solo se ha ejecutado Godot en Linux arm64 `--headless`. No hay casco conectado,
no hay `adb`, no se ha generado APK VR y no se ha instalado nada en un Quest.
Por tanto **no se afirma que este juego funciona en Quest**. Cada línea marcada
como pendiente necesita una sesión real con el dispositivo.

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
  4.7 aparece además `openxr/reference_space=2` (Stage). Configurar en
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
  por código, más dos `VrWeaponHand`. El viewport debe activarsalida XR
  (`get_viewport().use_xr = true`) en el arranque real; eso no se hace aquí porque
  este corte no posee el autoload de arranque.
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
