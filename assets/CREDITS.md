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
