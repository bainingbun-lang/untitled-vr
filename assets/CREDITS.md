# Créditos de assets (H1 entorno realista)

Todos los assets de este archivo son **CC0 1.0** (dominio público; agradecimiento opcional).
Se descargaron a directorios temporales vacíos, se inspeccionaron (ZIP/JSON/`file`) y
después se copiaron a `res://assets/`. Ningún archivo descargado fue ejecutado.
Las texturas JPEG se recomprimieron con ffmpeg (`-q:v 5`) manteniendo 1024x1024.
Se conservaron los mapas `Color`, `NormalGL` y `Roughness` (+ `Metalness` en metal).

## Texturas PBR (ambientCG)

| Superficie | Asset | Autor | URL | Licencia | Archivos en el proyecto |
|---|---|---|---|---|---|
| ground | Ground037 | ambientCG (Lenka Dohnalova) | https://ambientcg.com/view?id=Ground037 | CC0 1.0 | `assets/textures/ground/ground_{albedo,normal,roughness}.jpg` |
| concrete | Concrete046 | ambientCG (Lenka Dohnalova) | https://ambientcg.com/view?id=Concrete046 | CC0 1.0 | `assets/textures/concrete/concrete_{albedo,normal,roughness}.jpg` |
| metal | Metal021 | ambientCG (Lenka Dohnalova) | https://ambientcg.com/view?id=Metal021 | CC0 1.0 | `assets/textures/metal/metal_{albedo,normal,roughness,metalness}.jpg` |
| wood | Wood089 | ambientCG (Lenka Dohnalova) | https://ambientcg.com/view?id=Wood089 | CC0 1.0 | `assets/textures/wood/wood_{albedo,normal,roughness}.jpg` |
| brick | Bricks051 | ambientCG (Lenka Dohnalova) | https://ambientcg.com/view?id=Bricks051 | CC0 1.0 | `assets/textures/brick/brick_{albedo,normal,roughness}.jpg` |
| asphalt | Asphalt033 | ambientCG (Lenka Dohnalova) | https://ambientcg.com/view?id=Asphalt033 | CC0 1.0 | `assets/textures/asphalt/asphalt_{albedo,normal,roughness}.jpg` |

Fuente de descarga: `https://ambientcg.com/get?file=<AssetID>_1K-JPG.zip`.
Licencia: https://ambientcg.com/license

## HDRI (Poly Haven)

| Asset | Autor | URL | Licencia | Archivo |
|---|---|---|---|---|
| Qwantani Sunset (Pure Sky), 1k EXR | Greg Zaal / Poly Haven | https://polyhaven.com/a/qwantani_sunset_puresky | CC0 1.0 | `assets/hdri/qwantani_sunset_puresky_1k.exr` |

Usado como `PanoramaSkyMaterial.panorama` en `WorldEnvironment`.
Licencia: https://polyhaven.com/license

## Props 3D (Poly Haven, modelos glTF 1k)

Todos los modelos proceden de `https://polyhaven.com/a/<id>`, con autor
"Poly Haven community / Poly Haven" y licencia CC0 1.0. Cada carpeta contiene
`model.gltf`, `<id>.bin` y `textures/*_{diff,nor_gl,arm}_1k.jpg` (recomprimidos).

| id | Descripción | Tris | Licencia | Archivos |
|---|---|---:|---|---|
| Barrel_01 | Barril metálico | 2.682 | CC0 1.0 | `assets/models/props/barrel_01/*` |
| barrel_03 | Barril metálico variante | 1.473 | CC0 1.0 | `assets/models/props/barrel_03/*` |
| old_tyre | Neumático | 2.880 | CC0 1.0 | `assets/models/props/old_tyre/*` |
| wooden_crate_02 | Caja de madera | 5.176 | CC0 1.0 | `assets/models/props/wooden_crate_02/*` |
| cement_bag | Saco de cemento | 844 | CC0 1.0 | `assets/models/props/cement_bag/*` |
| ammo_box | Caja metálica de munición | 4.382 | CC0 1.0 | `assets/models/props/ammo_box/*` |
| trashbag | Saco de basura | 4.482 | CC0 1.0 | `assets/models/props/trashbag/*` |
| security_light | Farola/proyector de seguridad | 4.668 | CC0 1.0 | `assets/models/props/security_light/*` |
| plastic_crate_02 | Caja plástica industrial | 5.840 | CC0 1.0 | `assets/models/props/plastic_crate_02/*` |

Nota: `assets/models/props/barrel_01/` conserva los nombres internos de textura
`Barrel_01_*` tal como los referencia su `model.gltf` (no se renombraron para no
romper las referencias del glTF).

---

# Créditos de modelos 3D (armas / H3)

Los seis modelos de armas son **CC0 1.0** (dominio público) de **Quaternius (Laulhet)**,
distribuidos también como CC0 en Poly Pizza. No exigen atribución, pero se registra aquí
el origen completo. Ningún archivo descargado se ejecutó: se bajaron a un directorio
temporal vacío (`~/h3_weapon_stage`), se inspeccionó su cabecera GLB / JSON interno
(magics `glTF`, versión 2, mallas, materiales y triángulos) y solo después se copiaron
a `assets/models/weapons/`.

| Id en `weapon_db.gd` | Archivo | Modelo | Autor | URL de origen | Licencia | Archivos |
|---|---|---|---|---|---|---|
| `pistol` | `pistol.glb` | Pistol (Low Poly Weapons) | Quaternius (Laulhet) | https://poly.pizza/m/J3i9KDQ3kt , original: https://quaternius.com/packs/ultimategun.html | CC0 1.0 | `pistol.glb`, `licenses/QUATERNIUS_CC0.txt` |
| `submachine_gun` | `submachine_gun.glb` | Submachine Gun (Low Poly Weapons) | Quaternius (Laulhet) | https://poly.pizza/m/7ehatxr7FY , original: https://quaternius.com/packs/ultimategun.html | CC0 1.0 | `submachine_gun.glb`, `licenses/QUATERNIUS_CC0.txt` |
| `assault_rifle` | `assault_rifle.glb` | Assault Rifle (Low Poly Weapons) | Quaternius (Laulhet) | https://poly.pizza/m/Bgvuu4CUMV , original: https://quaternius.com/packs/ultimategun.html | CC0 1.0 | `assault_rifle.glb`, `licenses/QUATERNIUS_CC0.txt` |
| `shotgun` | `shotgun.glb` | Shotgun (Low Poly Weapons) | Quaternius (Laulhet) | https://poly.pizza/m/ZmPTnh7njL , original: https://quaternius.com/packs/ultimategun.html | CC0 1.0 | `shotgun.glb`, `licenses/QUATERNIUS_CC0.txt` |
| `sniper_rifle` | `sniper_rifle.glb` | Sniper Rifle (Low Poly Weapons) | Quaternius (Laulhet) | https://poly.pizza/m/ASOMZIErq3 , original: https://quaternius.com/packs/ultimategun.html | CC0 1.0 | `sniper_rifle.glb`, `licenses/QUATERNIUS_CC0.txt` |
| `bat` | `bat.glb` | Wooden Bat Barbed (Low Poly Weapons) | Quaternius (Laulhet) | https://poly.pizza/m/HSM4KnggSz , original: https://quaternius.com/ | CC0 1.0 | `bat.glb`, `bat_Zombie_Atlas.png` (extraído por el importador del GLB), `licenses/QUATERNIUS_CC0.txt` |

URLs directas de descarga (CDN de Poly Pizza, espejo autorizado del pack CC0):

- `pistol.glb`: https://static.poly.pizza/f5a88c73-af97-49ca-8650-4bde579d2f80.glb
- `submachine_gun.glb`: https://static.poly.pizza/fb8ae707-d5b9-4eb8-ab8c-1c78d3c1f710.glb
- `assault_rifle.glb`: https://static.poly.pizza/9a0e478c-de82-4773-9b70-a0219bb0057c.glb
- `shotgun.glb`: https://static.poly.pizza/f71d6771-f512-4374-bd23-ba00b564db68.glb
- `sniper_rifle.glb`: https://static.poly.pizza/f03e21b7-e3b7-49fd-b47d-d1908649fcee.glb
- `bat.glb`: https://static.poly.pizza/15d6d0a7-f748-42e7-b0ef-013f63f12194.glb

## Presupuesto móvil verificado (armas)

| Modelo | Tris | Materiales | Texturas |
|---|---:|---:|---|
| pistol | 968 | 3 | sin imágenes (colores de material) |
| submachine_gun | 1.374 | 4 | sin imágenes |
| assault_rifle | 1.930 | 3 | sin imágenes |
| shotgun | 978 | 4 | sin imágenes |
| sniper_rifle | 1.382 | 5 | sin imágenes |
| bat | 2.188 | 1 | 1 atlas PNG embebido (~6 KB) |

Todos quedan muy por debajo del límite de 8k tris por arma y 1024px por textura.

`WeaponViewmodel` ajusta la escala de cada modelo en tiempo de ejecución a partir de su
AABB, de modo que la orientación y el tamaño en pantalla se normalizan sin modificar los
archivos originales. El mismo modelo puede colgarse de una mano VR mediante `attach_to()`.

---

# Créditos de personajes 3D (H2)

Cuatro humanoides **rigged** con animaciones, todos **CC0 1.0** (dominio público, sin
obligación de atribución). Se descargaron a un directorio temporal vacío, se inspeccionó
su JSON/GLB (mallas, huesos, clips, texturas) y solo después se copiaron al proyecto.
Ningún archivo descargado fue ejecutado. Copia local de esta sección:
`assets/models/characters/CREDITS.md`.

| Id en `CharacterModel` | Archivo | Modelo | Autor | URL de origen | Licencia | Archivos |
|---|---|---|---|---|---|---|
| `civil` | `civil_casual_hoodie.gltf` | Ultimate Modular Men - Casual Hoodie | Quaternius (Laulhet) | https://github.com/agentkaerf/FreeModels (pack `Ultimate Modular Men- Feb 2022`), original: https://quaternius.com/packs/ultimatemodularcharacters.html | CC0 1.0 | `civil_casual_hoodie.gltf`, `licenses/QUATERNIUS_CC0.txt` |
| `soldier` | `soldier_swat.gltf` | Ultimate Modular Men - SWAT | Quaternius (Laulhet) | https://github.com/agentkaerf/FreeModels (pack `Ultimate Modular Men- Feb 2022`), original: https://quaternius.com/packs/ultimatemodularcharacters.html | CC0 1.0 | `soldier_swat.gltf`, `licenses/QUATERNIUS_CC0.txt` |
| `enemy` | `enemy_zombie_basic.gltf` | Zombie Apocalypse Kit - Zombie Basic | Quaternius (Laulhet) | https://github.com/agentkaerf/FreeModels (pack `Zombie Apocalypse Kit - March 2024`), original: https://quaternius.com/ | CC0 1.0 | `enemy_zombie_basic.gltf`, `licenses/QUATERNIUS_CC0.txt` |
| `robot` | `robot_blocky.glb` | Free Low-Poly Characters - Robot | Vuena / Popyca | https://github.com/Vuena/free-low-poly-characters-cc0 | CC0 1.0 | `robot_blocky.glb`, `licenses/VUENA_CC0.txt` |

URLs directas de descarga (raw):

- `civil_casual_hoodie.gltf`: https://raw.githubusercontent.com/agentkaerf/FreeModels/main/Ultimate%20Modular%20Men-%20Feb%202022/Individual%20Characters/glTF/Casual_Hoodie.gltf
- `soldier_swat.gltf`: https://raw.githubusercontent.com/agentkaerf/FreeModels/main/Ultimate%20Modular%20Men-%20Feb%202022/Individual%20Characters/glTF/Swat.gltf
- `enemy_zombie_basic.gltf`: https://raw.githubusercontent.com/agentkaerf/FreeModels/main/Zombie%20Apocalypse%20Kit%20-%20March%202024/Characters/glTF/Zombie_Basic.gltf
- `robot_blocky.glb`: https://raw.githubusercontent.com/Vuena/free-low-poly-characters-cc0/main/GLB/blocky_08_robot.glb

## Presupuesto móvil verificado (personajes)

| Modelo | Tris | Texturas | Animaciones |
|---|---:|---|---|
| civil_casual_hoodie | 6.206 | sin imágenes externas (materiales de color) | 24 |
| soldier_swat | 8.794 | sin imágenes externas (materiales de color) | 24 |
| enemy_zombie_basic | 7.822 | 1 atlas PNG embebido | 16 |
| robot_blocky | 2.504 | paleta 256×256 embebida | 10 |

Todos quedan por debajo del límite de 15k tris por personaje y 1024px por textura.
Los clips lógicos `idle`, `walk`, `run`, `aim`, `shoot`, `hit`, `die` se resuelven contra
los nombres reales (`Idle`, `Walk`, `Run`, `Idle_Gun_Pointing`, `Gun_Shoot`, `HitRecieve`,
`Death`; en el zombi `HitReact`/`Punch`; en el robot `idle`/`punch`/`death`) con fallback
seguro si falta algún clip.

## Nombres de huesos documentados (ragdoll / gore)

Quaternius (62 huesos, esqueleto compartido civil/SWAT): `Root`, `Body`, `Hips`, `Abdomen`,
`Torso`, `Chest`, `Neck`, `Head`, `Shoulder.L`, `UpperArm.L`, `LowerArm.L`, `Wrist.L`, dedos
`Index*`, `Middle*`, `Ring*`, `Pinky*`, `Thumb*`, `Shoulder.R`, `UpperArm.R`, `LowerArm.R`,
`Wrist.R`, ídem dedos `.R`, `UpperLeg.L`, `LowerLeg.L`, `UpperLeg.R`, `LowerLeg.R`, `Foot.L`,
`PT.L`, `Foot.R`, `PT.R`.

Zombi (50 huesos): `Root`, `Foot.L`, `Body`, `Hips`, `Abdomen`, `Torso`, `Neck`, `Head`,
`Tongue1..5`, `Eyelid.L/R`, brazos y dedos `.L/.R`, `UpperLeg.L/R`, `LowerLeg.L/R`,
`PoleTarget.L/R`, `Foot.R`.

Robot Vuena (22 huesos, esquema Mixamo): `mixamorig_Hips`, `mixamorig_Spine`,
`mixamorig_Spine1`, `mixamorig_Spine2`, `mixamorig_Neck`, `mixamorig_Head`,
`mixamorig_LeftShoulder/LeftArm/LeftForeArm/LeftHand`,
`mixamorig_RightShoulder/RightArm/RightForeArm/RightHand`,
`mixamorig_LeftUpLeg/LeftLeg/LeftFoot/LeftToeBase`,
`mixamorig_RightUpLeg/RightLeg/RightFoot/RightToeBase`.

Godot importa los huesos Mixamo del robot con `_` en vez de `:`; el código acepta ambos
prefijos. `apply_wound()` / `detach_limb()` aceptan además alias como `arm.L`, `leg.R`,
`head`, `hand.L`, etc.

---

# Dependencia de build VR (V1) — licencia MIT

No es un asset visual del juego: es el plugin nativo usado solo en la compilación
Quest/OpenXR de `build/vr_project`. Se descargó a un directorio temporal vacío y se
inspeccionó (ZIP, `plugin.gdextension`, AAR) sin ejecutar nada.

| Nombre | Autor | URL | Licencia | Archivos |
|---|---|---|---|---|
| Godot OpenXR Vendors 5.2.0-stable | GodotVR / Godot OpenXR contributors | https://github.com/GodotVR/godot_openxr_vendors/releases/tag/5.2.0-stable | MIT | `build/vr_project/addons/godotopenxrvendors/*` (reescrito por `tools/build_vr.sh`), copia de licencia en `LICENSE-MIT.txt`; caché en `~/untitled-control/vendor/godotopenxrvendors-5.2.0-stable/` |

---

# Créditos de modelos 3D (W3 — armas reales, brazos y manos)

Modelos descargados (no generados con primitivas ni por código) a directorios temporales
vacíos bajo `/data/data/com.termux/files/usr/tmp/opencode/w3/`, inspeccionados como
GLB/glTF (JSON interno, triángulos, nodos, huesos, animaciones y texturas) y copiados
después a `res://assets/`. Ningún archivo descargado fue ejecutado. Los modelos con
licencia CC BY 3.0 se atribuyen aquí con autor, URL y archivos; los CC0 se registran
igualmente por trazabilidad.

## Armas (`assets/models/weapons/v2/`)

| Id | Modelo | Autor | URL | Licencia | Archivo | Tris |
|---|---|---|---|---|---|---:|
| `pistol` | Glock | J-Toastie | https://poly.pizza/m/q3lsX3tSta | CC BY 3.0 | `pistol.glb` | 5.105 |
| `submachine_gun` | MPX | austincford | https://poly.pizza/m/p7sAqeuUWR | CC BY 3.0 | `submachine_gun.glb` | 6.869 |
| `assault_rifle` | AKM | J-Toastie | https://poly.pizza/m/ZBBoDqAn0A | CC BY 3.0 | `assault_rifle.glb` | 5.247 |
| `shotgun` | Shotgun Pump West | Pichuliru | https://poly.pizza/m/NfQETBKOiw | CC0 1.0 | `shotgun.glb` | 1.069 |
| `sniper_rifle` | Sniper Rifle | J-Toastie | https://poly.pizza/m/vGAzj2Of5M | CC BY 3.0 | `sniper_rifle.glb` | 4.963 |
| `bat` | Baseball Bat (nails) | CreativeTrio | https://poly.pizza/m/K24oYy6R7c | CC0 1.0 | `bat.glb` | 1.076 |

CC BY 3.0: https://creativecommons.org/licenses/by/3.0/ — se conservan autor y URL de
cada modelo derivado de Poly Pizza. El manifest `assets/models/weapons/v2/manifest.json`
documenta archivo, escala, offset de agarre, longitud real, nodos y roles por pieza.
Las mallas skinneadas (AKM, escopeta) no exponen pivotes Node3D estables: sus piezas se
resuelven por corte AABB sobre el modelo importado; el resto usa los nodos reales del GLB.

## Brazos FPS (`assets/models/weapons/v2/`)

| Modelo | Autor | URL | Licencia | Archivo | Tris | Huesos/animaciones |
|---|---|---|---|---|---:|---|
| WRAD Arms (rigged) | wwwriks | https://github.com/wwwriks/wrad-arms | CC0 1.0 | `fps_arms.glb` | 1.196 | ~50 huesos |
| Fps Rig AKM | J-Toastie | https://poly.pizza/m/U6l6wjxFhC | CC BY 3.0 | `fps_arms_akm.glb` | 7.679 | 28 huesos; `Armature|Idle`, `Armature|Reload`, `Armature|Shoot` |

Copia local de la licencia CC0 de WRAD Arms: `assets/models/weapons/v2/licenses/WRAD_ARMS_CC0.txt`.

## Manos VR (`assets/models/hands/`)

| Modelo | Autor | URL | Licencia | Archivos |
|---|---|---|---|---|
| Godot XR Tools low-poly hands | DigitalN8m4r3 (Miodrag Sejic) | https://github.com/GodotVR/godot-xr-tools/tree/master/addons/godot-xr-tools/hands | CC0 1.0 | `Hand_low_L.gltf`, `Hand_low_R.gltf`, `caucasian_baseColor.png`, `hands_normal.png`, `hands_occlusionRoughnessMetallic.png`, `LICENSE-CC0-GODOTXR.md`, `About.md` |

Manos con esqueleto de 26 huesos each (dedos completos), buffers embebidos y texturas
1024x1024. Licencia local: `assets/models/hands/LICENSE-CC0-GODOTXR.md`.

## Presupuesto móvil verificado (W3)

Ningún arma supera 8.000 triángulos (máximo: SMG, 6.869). Las texturas embebidas o
externas son <=1024px (atlas de bate 256x256; manos 1024x1024). Tamaño total añadido:
aprox. 7 MB (3,3 MB en `weapons/v2` + 3,7 MB en `hands`).

## Mapas 3D temáticos (`assets/models/maps/`)

Kits Kenney descargados desde `https://raw.githubusercontent.com/shorepine/kenney/main/3d/`
a un directorio temporal vacío, inspeccionados como GLB/JSON (AABB, triángulos y materiales)
y copiados sin ejecutarlos. Licencia CC0 1.0; copia local:
`assets/models/maps/LICENSE-CC0-KENNEY.txt`. Todos los GLB usan la textura compartida `colormap.png`
de 1024x1024 o menos y están por debajo del límite de 5.000 tris por prop.

| Kit | Autor | URL | Licencia | Archivos |
|---|---|---|---|---|
| City Roads Kit | Kenney (Kenney.NL) | https://kenney.nl/assets/city-roads-kit | CC0 1.0 | `construction-barrier.glb`, `construction-cone.glb`, `light-square.glb`, `road-bend-sidewalk.glb`, `road-crossing.glb`, `road-crossroad.glb`, `road-side-barrier.glb`, `road-side.glb`, `road-straight.glb`, `tile-high.glb`, `tile-low.glb`, `Textures/colormap.png` |
| City Commercial Kit | Kenney (Kenney.NL) | https://kenney.nl/assets/city-commercial-kit | CC0 1.0 | `building-a.glb` ... `building-n.glb`, `detail-awning-wide.glb`, `Textures/colormap.png` |
| City Industrial Kit | Kenney (Kenney.NL) | https://kenney.nl/assets/city-industrial-kit | CC0 1.0 | `building-a.glb`, `building-b.glb`, `building-c.glb`, `building-d.glb`, `chimney-large.glb`, `detail-tank.glb`, `Textures/colormap.png` |
| Building Kit | Kenney (Kenney.NL) | https://kenney.nl/assets/building-kit | CC0 1.0 | `border.glb`, `column.glb`, `door-rotate-square-a.glb`, `floor.glb`, `roof-flat-center.glb`, `stairs-center.glb`, `wall-doorway-wide-square.glb`, `wall-window-square.glb`, `wall.glb`, `Textures/colormap.png` |
| Car Kit | Kenney (Kenney.NL) | https://kenney.nl/assets/car-kit | CC0 1.0 | `ambulance.glb`, `police.glb`, `sedan.glb`, `taxi.glb`, `truck.glb`, `van.glb`, `Textures/colormap.png` |
| Factory Kit | Kenney (Kenney.NL) | https://kenney.nl/assets/factory-kit | CC0 1.0 | `catwalk-straight.glb`, `structure-doorway-wide.glb`, `structure-wall.glb`, `Textures/colormap.png` |
| Furniture Kit | Kenney (Kenney.NL) | https://kenney.nl/assets/furniture-kit | CC0 1.0 | `bookcaseOpen.glb`, `chairDesk.glb`, `computerScreen.glb`, `desk.glb`, `floorFull.glb`, `kitchenBar.glb`, `lampSquareCeiling.glb`, `loungeSofa.glb`, `pottedPlant.glb`, `wall.glb`, `wallDoorwayWide.glb`, `wallWindow.glb` (+25 GLB del kit) |
| Nature Kit | Kenney (Kenney.NL) | https://kenney.nl/assets/nature-kit | CC0 1.0 | `fence_simple.glb`, `grass_large.glb`, `ground_grass.glb`, `ground_pathStraight.glb`, `plant_bush.glb`, `rock_largeA.glb`, `tree_default.glb`, `tree_oak.glb`, `tree_pineDefaultA.glb` |
| Car Kit (vehiculos jugables G5) | Kenney (Kenney.NL), espejo https://github.com/Arslan12216775/kenney_car-kit | https://kenney.nl/assets/car-kit | CC0 1.0 | `assets/models/vehicles/`: `sedan.glb`, `truck.glb`, `sedan-sports.glb`, `delivery.glb`, `kart-oobi.glb`, `suv.glb`, `race.glb` (ruedas separadas, texturas embebidas; manifest.json) |
