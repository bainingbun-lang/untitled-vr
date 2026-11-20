# Créditos de personajes 3D (H2)

Cuatro humanoides **rigged** con animaciones, todos **CC0 1.0** (dominio público, sin
obligación de atribución). Copia local de la sección registrada en `assets/CREDITS.md`.

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

## Presupuesto móvil verificado

| Modelo | Tris | Texturas | Animaciones |
|---|---:|---|---|
| civil_casual_hoodie | 6.206 | sin imágenes externas (materiales de color) | 24 |
| soldier_swat | 8.794 | sin imágenes externas (materiales de color) | 24 |
| enemy_zombie_basic | 7.822 | 1 atlas PNG embebido | 16 |
| robot_blocky | 2.504 | paleta 256×256 embebida | 10 |

Todos quedan por debajo del límite de 15k tris por personaje y 1024px por textura.

## Nombres de huesos documentados (ragdoll / gore)

Quaternius (62 huesos): `Root`, `Body`, `Hips`, `Abdomen`, `Torso`, `Chest`, `Neck`, `Head`,
`Shoulder.L`, `UpperArm.L`, `LowerArm.L`, `Wrist.L`, dedos, `UpperLeg.L`, `LowerLeg.L`,
`UpperLeg.R`, `LowerLeg.R`, `Foot.L`, `PT.L`, `Foot.R`, `PT.R`.

Zombi (50 huesos): `Root`, `Foot.L`, `Body`, `Hips`, `Abdomen`, `Torso`, `Neck`, `Head`,
`Tongue1..5`, `Eyelid.L/R`, brazos y dedos, `UpperLeg.L/R`, `LowerLeg.L/R`,
`PoleTarget.L/R`, `Foot.R`.

Robot Vuena (22 huesos, Mixamo): `mixamorig_Hips`, `mixamorig_Spine`, `mixamorig_Spine1`,
`mixamorig_Spine2`, `mixamorig_Neck`, `mixamorig_Head`, `mixamorig_LeftArm`, etc. Godot
importa el prefijo como `mixamorig_`; el código acepta `mixamorig:` y `mixamorig_`.
