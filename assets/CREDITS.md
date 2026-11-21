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
| all_purpose_cleaner | Limpiador multiusos | 4.624 | CC0 1.0 | `assets/models/props/all_purpose_cleaner/*` |
| american_football | Balón fútbol americano | 4.480 | CC0 1.0 | `assets/models/props/american_football/*` |
| ammo_box_ph | Caja de munición (Poly Haven) | 4.382 | CC0 1.0 | `assets/models/props/ammo_box_ph/*` |
| anthurium_botany_01 | Anthurium (planta) | 4.134 | CC0 1.0 | `assets/models/props/anthurium_botany_01/*` |
| barrel_02 | Barril metálico 02 | 2.688 | CC0 1.0 | `assets/models/props/barrel_02/*` |
| barrel_03_ph | Barril metálico 03 (Poly Haven) | 1.473 | CC0 1.0 | `assets/models/props/barrel_03_ph/*` |
| baseball_01 | Pelota de béisbol | 2.712 | CC0 1.0 | `assets/models/props/baseball_01/*` |
| baseball_bat | Bate de béisbol | 2.672 | CC0 1.0 | `assets/models/props/baseball_bat/*` |
| bench_vice_01 | Tornillo de banco | 2.864 | CC0 1.0 | `assets/models/props/bench_vice_01/*` |
| bleach_bottle | Botella de lejía | 4.052 | CC0 1.0 | `assets/models/props/bleach_bottle/*` |
| brass_pan_01 | Sartén de latón | 4.340 | CC0 1.0 | `assets/models/props/brass_pan_01/*` |
| brass_pot_01 | Olla de latón 01 | 3.760 | CC0 1.0 | `assets/models/props/brass_pot_01/*` |
| brass_pot_02 | Olla de latón 02 | 3.344 | CC0 1.0 | `assets/models/props/brass_pot_02/*` |
| brass_vase_03 | Jarrón de latón 03 | 2.616 | CC0 1.0 | `assets/models/props/brass_vase_03/*` |
| brass_vase_04 | Jarrón de latón 04 | 2.760 | CC0 1.0 | `assets/models/props/brass_vase_04/*` |
| bronze_ray_statue | Estatua de raya bronce | 1.844 | CC0 1.0 | `assets/models/props/bronze_ray_statue/*` |
| bronze_whale_statue | Estatua de ballena bronce | 3.816 | CC0 1.0 | `assets/models/props/bronze_whale_statue/*` |
| can_rusted | Lata oxidada | 3.520 | CC0 1.0 | `assets/models/props/can_rusted/*` |
| carved_wooden_elephant | Elefante madera tallada | 2.752 | CC0 1.0 | `assets/models/props/carved_wooden_elephant/*` |
| carved_wooden_plate | Plato madera tallada | 2.112 | CC0 1.0 | `assets/models/props/carved_wooden_plate/*` |
| cassette_player | Reproductor de casetes | 4.830 | CC0 1.0 | `assets/models/props/cassette_player/*` |
| cement_bag_ph | Saco de cemento (Poly Haven) | 844 | CC0 1.0 | `assets/models/props/cement_bag_ph/*` |
| ceramic_pot | Olla de cerámica | 3.592 | CC0 1.0 | `assets/models/props/ceramic_pot/*` |
| ceramic_vase_01 | Jarrón cerámica 01 | 2.548 | CC0 1.0 | `assets/models/props/ceramic_vase_01/*` |
| ceramic_vase_02 | Jarrón cerámica 02 | 2.756 | CC0 1.0 | `assets/models/props/ceramic_vase_02/*` |
| ceramic_vase_03 | Jarrón cerámica 03 | 2.784 | CC0 1.0 | `assets/models/props/ceramic_vase_03/*` |
| ceramic_vase_04 | Jarrón cerámica 04 | 2.224 | CC0 1.0 | `assets/models/props/ceramic_vase_04/*` |
| cheese_box_01 | Caja de queso | 884 | CC0 1.0 | `assets/models/props/cheese_box_01/*` |
| chinese_armchair | Sillón chino | 2.675 | CC0 1.0 | `assets/models/props/chinese_armchair/*` |
| chinese_screen_panels | Paneles pantalla china | 784 | CC0 1.0 | `assets/models/props/chinese_screen_panels/*` |
| chinese_sofa | Sofá chino | 704 | CC0 1.0 | `assets/models/props/chinese_sofa/*` |
| chinese_stool | Taburete chino | 1.090 | CC0 1.0 | `assets/models/props/chinese_stool/*` |
| chinese_tea_table | Mesa de té china | 2.508 | CC0 1.0 | `assets/models/props/chinese_tea_table/*` |
| classic_nightstand_01 | Mesita de noche clásica | 2.002 | CC0 1.0 | `assets/models/props/classic_nightstand_01/*` |
| cleaner_tin_01 | Lata limpiador 01 | 3.560 | CC0 1.0 | `assets/models/props/cleaner_tin_01/*` |
| coffee_table_round_01 | Mesa centro redonda 01 | 4.044 | CC0 1.0 | `assets/models/props/coffee_table_round_01/*` |
| combination_wrench | Llave combinada | 1.986 | CC0 1.0 | `assets/models/props/combination_wrench/*` |
| croissant | Croissant | 1.990 | CC0 1.0 | `assets/models/props/croissant/*` |
| cross_pein_hammer | Martillo bola cruz | 2.124 | CC0 1.0 | `assets/models/props/cross_pein_hammer/*` |
| crowbar_01 | Palanca 01 | 2.300 | CC0 1.0 | `assets/models/props/crowbar_01/*` |
| dining_table | Mesa comedor | 1.048 | CC0 1.0 | `assets/models/props/dining_table/*` |
| drain_cleaner | Limpiador desagües | 4.338 | CC0 1.0 | `assets/models/props/drain_cleaner/*` |
| drill_01 | Taladro 01 | 2.926 | CC0 1.0 | `assets/models/props/drill_01/*` |
| dustpan | Recogedor | 4.332 | CC0 1.0 | `assets/models/props/dustpan/*` |
| fancy_picture_frame_01 | Marco cuadro elegante 01 | 938 | CC0 1.0 | `assets/models/props/fancy_picture_frame_01/*` |
| fire_alarm | Alarma de incendios | 2.705 | CC0 1.0 | `assets/models/props/fire_alarm/*` |
| fish_knife | Cuchillo pescado | 2.736 | CC0 1.0 | `assets/models/props/fish_knife/*` |
| flathead_screwdriver | Destornillador plano | 2.300 | CC0 1.0 | `assets/models/props/flathead_screwdriver/*` |
| football | Balón fútbol | 4.296 | CC0 1.0 | `assets/models/props/football/*` |
| gothic_commode_01 | Cómoda gótica 01 | 3.897 | CC0 1.0 | `assets/models/props/gothic_commode_01/*` |
| green_chair_01 | Silla verde 01 | 4.213 | CC0 1.0 | `assets/models/props/green_chair_01/*` |
| handsaw_wood | Sierra de mano madera | 2.548 | CC0 1.0 | `assets/models/props/handsaw_wood/*` |
| hanging_picture_frame_01 | Marco cuadro colgante 01 | 2.586 | CC0 1.0 | `assets/models/props/hanging_picture_frame_01/*` |
| hanging_picture_frame_02 | Marco cuadro colgante 02 | 3.678 | CC0 1.0 | `assets/models/props/hanging_picture_frame_02/*` |
| industrial_wall_lamp | Lámpara pared industrial | 4.446 | CC0 1.0 | `assets/models/props/industrial_wall_lamp/*` |
| katana_stand_01 | Soporte katana 01 | 3.780 | CC0 1.0 | `assets/models/props/katana_stand_01/*` |
| leather_cleaner_can | Lata limpiador cuero | 2.296 | CC0 1.0 | `assets/models/props/leather_cleaner_can/*` |
| lemon | Limón | 4.012 | CC0 1.0 | `assets/models/props/lemon/*` |
| lightbulb_01 | Bombilla 01 | 4.372 | CC0 1.0 | `assets/models/props/lightbulb_01/*` |
| long_life_food | Comida larga duración | 4.712 | CC0 1.0 | `assets/models/props/long_life_food/*` |
| machete | Machete | 3.032 | CC0 1.0 | `assets/models/props/machete/*` |
| measuring_tape_01 | Cinta métrica 01 | 2.868 | CC0 1.0 | `assets/models/props/measuring_tape_01/*` |
| medical_box | Botiquín | 3.718 | CC0 1.0 | `assets/models/props/medical_box/*` |
| medical_tape | Cinta médica | 1.408 | CC0 1.0 | `assets/models/props/medical_tape/*` |
| modern_coffee_table_01 | Mesa centro moderna 01 | 4.504 | CC0 1.0 | `assets/models/props/modern_coffee_table_01/*` |
| multi_cleaner_5_litre | Limpiador multi 5L | 4.332 | CC0 1.0 | `assets/models/props/multi_cleaner_5_litre/*` |
| office_notepads | Blocs de notas oficina | 666 | CC0 1.0 | `assets/models/props/office_notepads/*` |
| oil_tin | Lata aceite | 2.834 | CC0 1.0 | `assets/models/props/oil_tin/*` |
| old_tyre_ph | Neumático viejo (Poly Haven) | 2.880 | CC0 1.0 | `assets/models/props/old_tyre_ph/*` |
| ottoman_01 | Otomana 01 | 4.240 | CC0 1.0 | `assets/models/props/ottoman_01/*` |
| painted_wooden_bench | Banco madera pintada | 630 | CC0 1.0 | `assets/models/props/painted_wooden_bench/*` |
| painted_wooden_cabinet | Armario madera pintada | 2.227 | CC0 1.0 | `assets/models/props/painted_wooden_cabinet/*` |
| painted_wooden_cabinet_02 | Armario madera pintada 02 | 966 | CC0 1.0 | `assets/models/props/painted_wooden_cabinet_02/*` |
| painted_wooden_chair_01 | Silla madera pintada 01 | 724 | CC0 1.0 | `assets/models/props/painted_wooden_chair_01/*` |
| painted_wooden_chair_02 | Silla madera pintada 02 | 1.246 | CC0 1.0 | `assets/models/props/painted_wooden_chair_02/*` |
| painted_wooden_nightstand | Mesita noche madera pintada | 470 | CC0 1.0 | `assets/models/props/painted_wooden_nightstand/*` |
| painted_wooden_shelves | Estantes madera pintada | 524 | CC0 1.0 | `assets/models/props/painted_wooden_shelves/*` |
| painted_wooden_stool | Taburete madera pintada | 676 | CC0 1.0 | `assets/models/props/painted_wooden_stool/*` |
| painted_wooden_table | Mesa madera pintada | 600 | CC0 1.0 | `assets/models/props/painted_wooden_table/*` |
| pastic_torch_6v | Antorcha plástico 6V | 4.352 | CC0 1.0 | `assets/models/props/pastic_torch_6v/*` |
| planter_pot_clay | Maceta arcilla | 3.080 | CC0 1.0 | `assets/models/props/planter_pot_clay/*` |
| plastic_container | Contenedor plástico | 4.070 | CC0 1.0 | `assets/models/props/plastic_container/*` |
| plastic_monobloc_chair_01 | Silla monobloc plástico 01 | 3.356 | CC0 1.0 | `assets/models/props/plastic_monobloc_chair_01/*` |
| pliers | Alicates | 4.540 | CC0 1.0 | `assets/models/props/pliers/*` |
| plunger | Desatascador | 3.278 | CC0 1.0 | `assets/models/props/plunger/*` |
| postcard_set_01 | Set postales 01 | 2.720 | CC0 1.0 | `assets/models/props/postcard_set_01/*` |
| propane_torch | Soplete propano | 4.848 | CC0 1.0 | `assets/models/props/propane_torch/*` |
| propane_torch_02 | Soplete propano 02 | 2.960 | CC0 1.0 | `assets/models/props/propane_torch_02/*` |
| rollershutter_door | Puerta persiana | 1.104 | CC0 1.0 | `assets/models/props/rollershutter_door/*` |
| rollershutter_window_01 | Ventana persiana 01 | 1.104 | CC0 1.0 | `assets/models/props/rollershutter_window_01/*` |
| rollershutter_window_02 | Ventana persiana 02 | 1.120 | CC0 1.0 | `assets/models/props/rollershutter_window_02/*` |
| school_desk_01 | Pupitre escolar 01 | 4.162 | CC0 1.0 | `assets/models/props/school_desk_01/*` |
| shelf_01 | Estante 01 | 182 | CC0 1.0 | `assets/models/props/shelf_01/*` |
| sofa_01 | Sofá 01 | 4.101 | CC0 1.0 | `assets/models/props/sofa_01/*` |
| television_01 | Televisor 01 | 1.918 | CC0 1.0 | `assets/models/props/television_01/*` |
| wet_floor_sign_01 | Señal suelo mojado 01 | 228 | CC0 1.0 | `assets/models/props/wet_floor_sign_01/*` |
| wooden_table_01 | Mesa madera 01 | 952 | CC0 1.0 | `assets/models/props/wooden_table_01/*` |
| wooden_table_02 | Mesa madera 02 | 1.514 | CC0 1.0 | `assets/models/props/wooden_table_02/*` |
| wooden_table_03 | Mesa madera 03 | 2.298 | CC0 1.0 | `assets/models/props/wooden_table_03/*` |

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
| City Suburban Kit | Kenney (Kenney.NL) | https://kenney.nl/assets/city-kit-suburban | CC0 1.0 | `building-type-a.glb` ... `building-type-u.glb`, `driveway-long.glb`, `driveway-short.glb`, `fence*.glb`, `path*.glb`, `planter.glb`, `tree-large.glb`, `tree-small.glb`, `Textures/colormap.png` |
| Modular Buildings Kit | Kenney (Kenney.NL) | https://kenney.nl/assets/modular-buildings-kit | CC0 1.0 | `building-block.glb`, `building-corner*.glb`, `building-door*.glb`, `building-sample-*.glb`, `building-steps*.glb`, `building-window*.glb`, `building-windows*.glb`, `detail-ac*.glb`, `door-*.glb`, `roof-*.glb`, `window-*.glb`, `Textures/colormap.png` |
| Retro Urban Kit | Kenney (Kenney.NL) | https://kenney.nl/assets/retro-urban-kit | CC0 1.0 | `balcony-*.glb`, `cliff-*.glb`, `detail-*.glb`, `door-*.glb`, `grass*.glb`, `pallet*.glb`, `planks.glb`, `road-*.glb`, `roof-metal*.glb`, `scaffolding-*.glb`, `tree-*.glb`, `truck-*.glb`, `wall-*.glb`, `window-*.glb`, `Textures/*.png` (64-128px) |
| Survival Kit | Kenney (Kenney.NL) | https://kenney.nl/assets/survival-kit | CC0 1.0 | `barrel*.glb`, `bedroll*.glb`, `bottle*.glb`, `box*.glb`, `bucket.glb`, `campfire*.glb`, `chest.glb`, `fence*.glb`, `fish*.glb`, `floor*.glb`, `grass*.glb`, `metal-panel*.glb`, `patch-grass*.glb`, `resource-*.glb`, `rock-*.glb`, `signpost*.glb`, `structure*.glb`, `tent*.glb`, `tool-*.glb`, `tree*.glb`, `workbench*.glb`, `Textures/colormap.png` (512px) |
| Food Kit | Kenney (Kenney.NL) | https://kenney.nl/assets/food-kit | CC0 1.0 | 200 food/prop models (`apple.glb`, `burger*.glb`, `can*.glb`, `bottle*.glb`, `cake*.glb`, `cheese*.glb`, `fruit*.glb`, `vegetable*.glb`, `bread.glb`, `candy*.glb`, etc.), `Textures/colormap.png` (512px), all < 1.4k tris |
| Mini Market Kit | Kenney (Kenney.NL) | https://kenney.nl/assets/mini-market-kit | CC0 1.0 | `bottle-return.glb`, `cash-register.glb`, `character-employee.glb`, `column.glb`, `display-bread.glb`, `display-fruit.glb`, `fence*.glb`, `floor.glb`, `freezer*.glb`, `shelf-*.glb`, `shopping-basket.glb`, `shopping-cart.glb`, `wall*.glb`, `Textures/colormap.png` (512px), all < 900 tris |
| Mini Forest Kit | Kenney (Kenney.NL) | https://kenney.nl/assets/mini-forest-kit | CC0 1.0 | `bridge.glb`, `building-*.glb`, `character-archer.glb`, `fence.glb`, `flag.glb`, `ladder.glb`, `patch-*.glb`, `plant.glb`, `platform.glb`, `rocks-*.glb`, `stones.glb`, `target.glb`, `tent.glb`, `tree*.glb`, `weapon-*.glb`, `Textures/colormap.png` (512px), all < 850 tris |

---

# Créditos de audio real (A1)

170 grabaciones reales convertidas a Ogg Vorbis mono 44,1 kHz (1,87 MB) en
`assets/audio/real/`. Cada archivo, su fuente exacta, pico y duración están en
`assets/audio/real/manifest.json`; el detalle por autor, URL y licencia está en
`assets/audio/AUDIO_CREDITS.md`.

| Creación | Autor(es) | URL | Licencia | Archivos |
|---|---|---|---|---|
| Disparos pistola/fusil/francotirador | Michel Baradari, Vincent Sevedge (Tabasco), kurt, XCVG | https://opengameart.org/content/gunshot-sounds , https://opengameart.org/content/gunshots , https://opengameart.org/content/tactical-weapons-and-tactics-sound-pack | CC BY 3.0 / CC0 | `assets/audio/real/shot_*.ogg`, `body_*.ogg`, `crack_*.ogg` |
| Recargas y mecanismos | SpringySpringo, zer0_sol, pauliuw, qubodup | https://opengameart.org/content/gun-reload-sounds , https://opengameart.org/content/handgun-reload-sound-effect , https://opengameart.org/content/gun-reload-lock-or-click-sound , https://opengameart.org/content/metal-interactions | CC0 1.0 | `assets/audio/real/reload_*.ogg` |
| Impactos, pasos, golpes, cristales | rubberduck, congusbongus, dklon, Peludo, Till Behrend | https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx , https://opengameart.org/content/footsteps-on-different-surfaces , https://opengameart.org/content/super-foley-pack , https://opengameart.org/content/water-splash-and-sand-footsteps , https://opengameart.org/content/glass-break | CC0 1.0 / CC BY 3.0 | `assets/audio/real/impact_*.ogg`, `step_*.ogg`, `melee_*.ogg`, `glass_break_*.ogg` |
| Voces: dolor, miedo, muerte, jadeos, gruñidos, risa, tos, llanto, alerta | qubodup, Michel Baradari, congusbongus, thebardofblasphemy, mikeask, StarNinjas, DonkeyMan, Nocturnal_Vanguard, WeaponGuy, AntumDeluge, JeanMyna_VA, Scribe, XCVG | https://opengameart.org/content/15-vocal-male-strainhurtpainjump-sounds , https://opengameart.org/content/11-male-human-paindeath-sounds , https://opengameart.org/content/female-screams , https://opengameart.org/content/aargh-male-screams , https://opengameart.org/content/grunts-male-death-and-pain , https://opengameart.org/content/breathing-tired , https://opengameart.org/content/16-monster-growls , https://opengameart.org/content/zombie-noises , https://opengameart.org/content/maniacal-laughter-pack-1 , https://opengameart.org/content/sinister-laugh , https://opengameart.org/content/old-man-cough , https://opengameart.org/content/crying-female-low-tone-voice-over-vocal-sound-for-character , https://opengameart.org/content/rts-commands-and-reports | CC0 1.0 / CC BY 3.0 / CC BY 4.0 | `assets/audio/real/voice_*.ogg` |
| Explosiones, motores, bocinas y ambiente | TinyWorlds, XCVG, domasx2, GGBotNet, SketchMan3, Thimras, tcarisland, Wolfgang_ | https://opengameart.org/content/explosion-0 , https://opengameart.org/content/racing-car-engine-sound-loops , https://opengameart.org/content/car-sound-effects-pack-low-quality , https://opengameart.org/content/wind-whoosh-loop , https://opengameart.org/content/park-ambiences , https://opengameart.org/content/city-at-night , https://opengameart.org/content/crickets-ambient-noise-loopable | CC0 1.0 / CC BY 4.0 | `assets/audio/real/explosion_*.ogg`, `engine_*.ogg`, `horn_*.ogg`, `amb_*.ogg` |

Todos se descargaron a directorios temporales vacíos, se inspeccionaron (`file`, `unzip -l`,
`7z l`, `ffprobe`) y no se ejecutó ningún archivo descargado. Se recomprimieron con ffmpeg
(`silenceremove`, `agate`, `loudnorm`, `alimiter`, Ogg Vorbis q4 mono 44,1 kHz).

---

# Créditos de personajes 3D v2 (C6 P1 — NPC variados)

Once humanoides **rigged** y animados, descargados (no creados ni construidos por código)
de tres packs **CC0 1.0 Universal** de **Quaternius (Laulhet)** distribuidos en
`https://github.com/agentkaerf/FreeModels`. Cada archivo se descargó a un directorio
temporal **nuevo y vacío** (`~/usr/tmp/opencode/c6p1/stage/pick_<id>/`), se inspeccionó
como glTF 2.0 (JSON: versión, triángulos, esqueleto, clips, materiales e imágenes) y solo
después se copió a `res://assets/models/characters/v2/`. Ningún archivo descargado se
ejecutó. Copia de la licencia: `assets/models/characters/v2/licenses/QUATERNIUS_CC0.txt`.

| Id | Rol | Modelo (pack de origen) | Autor | URL | Licencia | Archivo en proyecto | Tris |
|---|---|---|---|---|---|---|---:|
| `civil_man_casual` | civil | Casual 2 (Ultimate Modular Men, Feb 2022) | Quaternius (Laulhet) | https://github.com/agentkaerf/FreeModels , original https://quaternius.com/packs/ultimatemodularcharacters.html | CC0 1.0 | `assets/models/characters/v2/civil_man_casual.gltf` | 5.776 |
| `civil_man_farmer` | civil | Farmer (Ultimate Modular Men, Feb 2022) | Quaternius (Laulhet) | https://github.com/agentkaerf/FreeModels , original https://quaternius.com/packs/ultimatemodularcharacters.html | CC0 1.0 | `assets/models/characters/v2/civil_man_farmer.gltf` | 5.476 |
| `civil_woman_casual` | civil | Casual (Ultimate Modular Women, April 2022) | Quaternius (Laulhet) | https://github.com/agentkaerf/FreeModels , original https://quaternius.com/packs/ultimatemodularcharacters.html | CC0 1.0 | `assets/models/characters/v2/civil_woman_casual.gltf` | 6.424 |
| `civil_woman_formal` | civil | Formal (Ultimate Modular Women, April 2022) | Quaternius (Laulhet) | https://github.com/agentkaerf/FreeModels , original https://quaternius.com/packs/ultimatemodularcharacters.html | CC0 1.0 | `assets/models/characters/v2/civil_woman_formal.gltf` | 6.108 |
| `police_swat` | police | Swat (Ultimate Modular Men, Feb 2022) | Quaternius (Laulhet) | https://github.com/agentkaerf/FreeModels , original https://quaternius.com/packs/ultimatemodularcharacters.html | CC0 1.0 | `assets/models/characters/v2/police_swat.gltf` | 8.794 |
| `soldier_female` | soldier | Soldier (Ultimate Modular Women, April 2022) | Quaternius (Laulhet) | https://github.com/agentkaerf/FreeModels , original https://quaternius.com/packs/ultimatemodularcharacters.html | CC0 1.0 | `assets/models/characters/v2/soldier_female.gltf` | 7.900 |
| `criminal_punk` | criminal | Punk (Ultimate Modular Men, Feb 2022) | Quaternius (Laulhet) | https://github.com/agentkaerf/FreeModels , original https://quaternius.com/packs/ultimatemodularcharacters.html | CC0 1.0 | `assets/models/characters/v2/criminal_punk.gltf` | 5.500 |
| `office_suit` | office | Suit (Ultimate Modular Men, Feb 2022) | Quaternius (Laulhet) | https://github.com/agentkaerf/FreeModels , original https://quaternius.com/packs/ultimatemodularcharacters.html | CC0 1.0 | `assets/models/characters/v2/office_suit.gltf` | 7.674 |

URLs directas de descarga (raw, `https://raw.githubusercontent.com/agentkaerf/FreeModels/main/`):

- `civil_man_casual.gltf`: `Ultimate%20Modular%20Men-%20Feb%202022/Individual%20Characters/glTF/Casual_2.gltf`
- `civil_man_farmer.gltf`: `Ultimate%20Modular%20Men-%20Feb%202022/Individual%20Characters/glTF/Farmer.gltf`
- `civil_woman_casual.gltf`: `Ultimate%20Modular%20Women%20-%20April%202022/Individual%20Characters/glTF/Casual.gltf`
- `civil_woman_formal.gltf`: `Ultimate%20Modular%20Women%20-%20April%202022/Individual%20Characters/glTF/Formal.gltf`
- `police_swat.gltf`: `Ultimate%20Modular%20Men-%20Feb%202022/Individual%20Characters/glTF/Swat.gltf`
- `soldier_female.gltf`: `Ultimate%20Modular%20Women%20-%20April%202022/Individual%20Characters/glTF/Soldier.gltf`
- `criminal_punk.gltf`: `Ultimate%20Modular%20Men-%20Feb%202022/Individual%20Characters/glTF/Punk.gltf`
- `office_suit.gltf`: `Ultimate%20Modular%20Men-%20Feb%202022/Individual%20Characters/glTF/Suit.gltf`

El manifest `assets/models/characters/v2/manifest.json` documenta id, rol, archivo, altura
(1,75 m normalizados en juego; `source_height` es la altura original del glTF), huesos
clave, nombres reales de animaciones y su mapeo a `idle/walk/run/aim/shoot/hit/die`.
Humanos: `Idle`, `Walk`, `Run`, `Idle_Gun_Pointing`, `Gun_Shoot`, `HitRecieve`, `Death`
(24 clips por modelo). Zombis: `Idle`, `Walk`, `Run`, `Idle_Attack`, `Punch`, `HitReact`,
`Death` (16 clips; el `Zombie_Ribcage` no tiene brazos ni ataque: `aim=Idle`, `shoot=Jump`
como fallback documentado en el manifest).

## Presupuesto móvil verificado (C6 P1)

Máximo 8.794 tris por personaje (límite 15k). Los ocho humanoides usan materiales de
color (sin imágenes externas; 5-10 materiales). Tamaño total añadido: ~17,5 MiB
en 8 `.gltf` + `manifest.json` + licencia. No se usaron assets de Mixamo ni Sketchfab.

**Honestidad sobre el realismo:** estos modelos son de estilo *low-poly estilizado* de
Quaternius (con ropa, siluetas y animaciones diferenciadas), no personajes
fotorrealistas. No se encontraron personajes humanos fotorrealistas, riggeados,
animados, con licencia CC0/MIT/CC-BY clara y dentro del presupuesto móvil/VR en las
fuentes permitidas; los sustitutos "realistas" de OpenGameArt/itch.io requieren
registro o licenses ambiguas. Se priorizó variedad de roles, ropa, edad aparente y
cumplimiento estricto de licencia y presupuesto.

---

# Créditos de K1 (volante, claxon y motor reales)

Ningún modelo ni sonido de esta sección fue generado por código. Se descargaron a un
directorio temporal **nuevo y vacío** (`/data/data/com.termux/files/usr/tmp/opencode/k1/stage/wheel/`),
se inspeccionaron (cabecera GLB, JSON interno, mallas, materiales y triángulos; `file`,
`ffprobe` para el audio) y solo después se copiaron al proyecto. No se ejecutó ningún
archivo descargado.

| Asset | Nombre | Autor | URL | Licencia | Archivos en el proyecto |
|---|---|---|---|---|---|
| Volante 3D | Steering wheel (Poly by Google) | Poly by Google | https://poly.pizza/m/bIYbhKwE4L0 | CC BY 3.0 (atribución aquí) | `assets/models/vehicles/steering_wheel.glb` |
| Claxon real | Car Horn (GGBotNet) | GGBotNet | https://opengameart.org/content/car-sound-effects-pack-low-quality | CC0 1.0 | `assets/audio/real/horn_01.ogg` |
| Motor real | Car Engine Loop (GGBotNet) | GGBotNet | https://opengameart.org/content/car-sound-effects-pack-low-quality | CC0 1.0 | `assets/audio/real/engine_03.ogg` |
| Motor real (alternativa) | Racing car engine loops | domasx2 | https://opengameart.org/content/racing-car-engine-sound-loops | CC0 1.0 | `assets/audio/real/engine_01.ogg`, `engine_02.ogg` |

CC BY 3.0: https://creativecommons.org/licenses/by/3.0/ — autor y URL del volante
conservados en esta tabla. El modelo tiene 924 triángulos, 2 materiales y 0 texturas
(23.140 bytes), muy por debajo del límite de 5k tris por prop y 1024px por textura.
Los dos archivos de audio ya estaban descargados y convertidos a Ogg Vorbis en A1
(`assets/audio/real/manifest.json`, `assets/audio/AUDIO_CREDITS.md`) y se reutilizan
aquí en lugar del claxon sintético y del motor ausente.

---

# Créditos de D1 (mod de ejemplo data-driven)

Modelo descargado a un directorio temporal **nuevo y vacío**
(`/data/data/com.termux/files/usr/tmp/opencode/d1_stage/model_revolver/`), inspeccionado
como JSON glTF (1 malla, 1 material, 0 animaciones, 1.446 triángulos, textura PNG embebida
de 512×512) y copiado después al proyecto. No se ejecutó ningún archivo descargado.

| Asset | Nombre | Autor | URL | Licencia | Archivos en el proyecto |
|---|---|---|---|---|---|
| Pistola de ejemplo | Pistol (Zombie Apocalypse Kit - March 2024) | Quaternius (Laulhet) | https://github.com/agentkaerf/FreeModels (pack `Zombie Apocalypse Kit - March 2024`), original: https://quaternius.com/ | CC0 1.0 | `assets/models/weapons/v2/rust_pistol.gltf`, `assets/models/weapons/v2/rust_pistol_Zombie_Atlas.png` (atlas extraído por el importador) |

URL directa de descarga: https://raw.githubusercontent.com/agentkaerf/FreeModels/main/Zombie%20Apocalypse%20Kit%20-%20March%202024/Weapons/glTF/Pistol.gltf

---

# Codigo adaptado de terceros (W4 — weapons attribution)

## Referencias de código adaptado

Los siguientes archivos del sistema de armas (W4) contienen código adaptado de proyectos de referencia open-source. Cada archivo incluye un encabezado de atribución con el proyecto original, archivo de origen y licencia.

| Archivo del proyecto | Referencia principal | Archivo original | Licencia | Licencia en third_party/ |
|---|---|---|---|---|
| `core/game/ammo_system.gd` | GodotFPS-Template (bukkbeek) | `common/autoloads/bullets.gd` | MIT | `GODOTFPS_TEMPLATE_LICENSE.txt` |
| `core/game/weapon_pickup.gd` | GodotFPS-Template (bukkbeek) | `common/utils/ammo_refil.gd`, `common/weapon/weapon.gd` | MIT | `GODOTFPS_TEMPLATE_LICENSE.txt` |
| `core/game/weapon_pickup.gd` | Godot-FPS-Template (AxelReviron) | `objects/weapon_interaction_component.gd` | MIT | `GODOT_FPS_TEMPLATE_LICENSE.txt` |
| `core/game/weapon_shop.gd` | GodotFPS-Template (bukkbeek) | `common/weapon/weapon.gd`, `common/autoloads/bullets.gd` | MIT | `GODOTFPS_TEMPLATE_LICENSE.txt` |
| `core/game/weapon_shop.gd` | Godot-FPS-Template (AxelReviron) | `WeaponController.gd`, `objects/weapon_interaction_component.gd` | MIT | `GODOT_FPS_TEMPLATE_LICENSE.txt` |
| `core/game/weapon_system.gd` | GodotWeapons (JarLowrey) | `core/weapon.gd`, `core/ammunition.gd`, `core/magazine.gd` | MIT | `GODOTWEAPONS_LICENSE.txt` |
| `core/game/weapon_system.gd` | godot_weapon_manager (toledosq) | `WeaponManager.gd` | MIT | `GODOT_WEAPON_MANAGER_LICENSE.txt` |
| `core/game/weapon_system.gd` | Godot-FPS-Template (AxelReviron) | `WeaponController.gd`, `ShootingWeaponState.gd`, `ReloadingWeaponState.gd` | MIT | `GODOT_FPS_TEMPLATE_LICENSE.txt` |
| `core/game/weapon_system.gd` | GodotFPS-Template (bukkbeek) | `common/weapon/weapons_manager.gd`, `common/weapon/weapon.gd` | MIT | `GODOTFPS_TEMPLATE_LICENSE.txt` |
| `core/game/weapon_viewmodel.gd` | Godot-FPS-Template (AxelReviron) | `WeaponViewmodel.gd` | MIT | `GODOT_FPS_TEMPLATE_LICENSE.txt` |
| `core/game/weapon_viewmodel.gd` | GodotFPS-Template (bukkbeek) | `common/weapon/weapon.gd` | MIT | `GODOTFPS_TEMPLATE_LICENSE.txt` |
| `core/game/weapon_viewmodel.gd` | godot_openvr_fps (GodotVR) | `VR_Controller.gd` | MIT | `GODOT_OPENVR_FPS_LICENSE.txt` |
| `core/game/weapon_db.gd` | Godot-FPS-Template (AxelReviron) | `Weapons.gd` | MIT | `GODOT_FPS_TEMPLATE_LICENSE.txt` |
| `core/game/weapon_db.gd` | GodotWeapons (JarLowrey) | `Weapons.gd` | MIT | `GODOTWEAPONS_LICENSE.txt` |
| `core/game/weapon_db.gd` | GodotFPS-Template (bukkbeek) | `common/weapon/weapons.gd` | MIT | `GODOTFPS_TEMPLATE_LICENSE.txt` |
| `core/game/muzzle_fx.gd` | Godot-FPS-Template (AxelReviron) | `WeaponController.gd`, `ShootingWeaponState.gd` | MIT | `GODOT_FPS_TEMPLATE_LICENSE.txt` |
| `core/game/muzzle_fx.gd` | GodotFPS-Template (bukkbeek) | `common/weapon/weapon.gd` | MIT | `GODOTFPS_TEMPLATE_LICENSE.txt` |
| `core/game/muzzle_fx.gd` | GodotWeapons (JarLowrey) | `weapon.gd` | MIT | `GODOTWEAPONS_LICENSE.txt` |
| `core/game/content_registry.gd` | (Original - Godot patterns) | — | MIT | — |
| `core/vr/vr_weapon_hand.gd` | godot_openvr_fps (GodotVR) | `VR_Controller.gd`, `Pistol.gd` | MIT | `GODOT_OPENVR_FPS_LICENSE.txt` |
| `core/vr/vr_weapon_hand.gd` | Godot-FPS-Template (AxelReviron) | `WeaponViewmodel.gd` | MIT | `GODOT_FPS_TEMPLATE_LICENSE.txt` |
| `data/base/ammo.json` | GodotFPS-Template (bukkbeek) | `common/autoloads/bullets.gd` | MIT | `GODOTFPS_TEMPLATE_LICENSE.txt` |
| `data/base/ammo.json` | Godot-FPS-Template (AxelReviron) | Weapon/ammo data patterns | MIT | `GODOT_FPS_TEMPLATE_LICENSE.txt` |
| `data/base/ammo.json` | GodotWeapons (JarLowrey) | `Ammunition.gd` | MIT | `GODOTWEAPONS_LICENSE.txt` |
| `data/base/weapon_shop.json` | GodotFPS-Template (bukkbeek) | `common/weapon/weapon.gd` pricing | MIT | `GODOTFPS_TEMPLATE_LICENSE.txt` |
| `data/base/weapon_shop.json` | Godot-FPS-Template (AxelReviron) | Weapon interaction/store UI | MIT | `GODOT_FPS_TEMPLATE_LICENSE.txt` |
| `data/base/weapons.json` | GodotWeapons (JarLowrey) | `Weapons.gd` definitions | MIT | `GODOTWEAPONS_LICENSE.txt` |
| `data/base/weapons.json` | Godot-FPS-Template (AxelReviron) | `Weapons.gd` resource format | MIT | `GODOT_FPS_TEMPLATE_LICENSE.txt` |
| `data/base/weapons.json` | GodotFPS-Template (bukkbeek) | `common/weapon/weapons.gd` | MIT | `GODOTFPS_TEMPLATE_LICENSE.txt` |
| `data/base/weapons.json` | godot_weapon_manager (toledosq) | `WeaponManager.gd` configs | MIT | `GODOT_WEAPON_MANAGER_LICENSE.txt` |

## Licencias de terceros (copiadas a `third_party/`)

- **GodotWeapons** (James Lowrey, 2017) — MIT License → `third_party/GODOTWEAPONS_LICENSE.txt`
- **Godot-FPS-Template** (Axel Reviron, 2026) — MIT License → `third_party/GODOT_FPS_TEMPLATE_LICENSE.txt`
- **godot_weapon_manager** (Colormatic, 2023) — MIT License → `third_party/GODOT_WEAPON_MANAGER_LICENSE.txt`
- **GodotFPS-Template** (bukkbeek, 2026) — MIT License → `third_party/GODOTFPS_TEMPLATE_LICENSE.txt`
- **godot-fps-template** (MilkAndBanana01) — CC0 1.0 Universal → `third_party/GODOT_FPS_TEMPLATE_CC0_LICENSE.txt`
- **godot_openvr_fps** (Bastiaan Olij & Noah "TwistedTwigleg" Beard, 2019) — MIT License → `third_party/GODOT_OPENVR_FPS_LICENSE.txt`
- **godot-behavior-tree-plugin** (Jeffery Olson, Brandon Lamb, Sebastian Ebert, 2016-2017) — MIT License → `third_party/godot-behavior-tree-plugin/LICENSE`
- **godot-steering-ai-framework** (GDQuest, 2020) — MIT License → `third_party/godot-steering-ai-framework/LICENSE`

## Nota

Todos los archivos listados arriba han sido **adaptados** (no copiados literalmente) para integrarse con la arquitectura del proyecto UNTITLED (ContentRegistry, WeaponDb, AmmoSystem, VrWeaponHand, etc.). La lógica de juego original de cada referencia se ha modificado para trabajar con el sistema de datos JSON (`data/base/*.json`), el registro de contenido y las convenciones de naming del proyecto. No se ha alterado la lógica de juego funcional más allá de la integración.

---

# Codigo adaptado de terceros (AI2 — Steering & Behavior Tree)

## Referencias de código adaptado (Steering)

Los siguientes archivos del sistema de steering (AI2) contienen código adaptado de **godot-steering-ai-framework** (GDQuest, MIT License, Copyright 2020).

| Archivo del proyecto | Archivo original | Licencia | Licencia en third_party/ |
|---|---|---|---|
| `core/npc/steering/agent_location.gd` | `GSAIAgentLocation.gd` | MIT | `godot-steering-ai-framework/LICENSE` |
| `core/npc/steering/group_behavior.gd` | `GSAIGroupBehavior.gd` | MIT | `godot-steering-ai-framework/LICENSE` |
| `core/npc/steering/steering_agent.gd` | `GSAISteeringAgent.gd` | MIT | `godot-steering-ai-framework/LICENSE` |
| `core/npc/steering/steering_behavior.gd` | `GSAISteeringBehavior.gd` | MIT | `godot-steering-ai-framework/LICENSE` |
| `core/npc/steering/target_acceleration.gd` | `GSAITargetAcceleration.gd` | MIT | `godot-steering-ai-framework/LICENSE` |
| `core/npc/steering/utils.gd` | `GSAIUtils.gd` | MIT | `godot-steering-ai-framework/LICENSE` |
| `core/npc/steering/proximities/proximity.gd` | `GSAIProximity.gd` | MIT | `godot-steering-ai-framework/LICENSE` |
| `core/npc/steering/proximities/radius_proximity.gd` | `GSAIRadiusProximity.gd` | MIT | `godot-steering-ai-framework/LICENSE` |
| `core/npc/steering/agents/steering_agent.gd` | `GSAICharacterBody3DAgent.gd` | MIT | `godot-steering-ai-framework/LICENSE` |
| `core/npc/steering/behaviors/arrive.gd` | `GSAIArrive.gd` | MIT | `godot-steering-ai-framework/LICENSE` |
| `core/npc/steering/behaviors/avoid_collisions.gd` | `GSAIAvoidCollisions.gd` | MIT | `godot-steering-ai-framework/LICENSE` |
| `core/npc/steering/behaviors/blend.gd` | `GSAIBlend.gd` | MIT | `godot-steering-ai-framework/LICENSE` |
| `core/npc/steering/behaviors/cohesion.gd` | `GSAICohesion.gd` | MIT | `godot-steering-ai-framework/LICENSE` |
| `core/npc/steering/behaviors/evade.gd` | `GSAIEvade.gd` | MIT | `godot-steering-ai-framework/LICENSE` |
| `core/npc/steering/behaviors/face.gd` | `GSAIFace.gd` | MIT | `godot-steering-ai-framework/LICENSE` |
| `core/npc/steering/behaviors/flee.gd` | `GSAIFlee.gd` | MIT | `godot-steering-ai-framework/LICENSE` |
| `core/npc/steering/behaviors/match_orientation.gd` | `GSAIMatchOrientation.gd` | MIT | `godot-steering-ai-framework/LICENSE` |
| `core/npc/steering/behaviors/priority.gd` | `GSAIPriority.gd` | MIT | `godot-steering-ai-framework/LICENSE` |
| `core/npc/steering/behaviors/pursue.gd` | `GSAIPursue.gd` | MIT | `godot-steering-ai-framework/LICENSE` |
| `core/npc/steering/behaviors/seek.gd` | `GSAISeek.gd` | MIT | `godot-steering-ai-framework/LICENSE` |
| `core/npc/steering/behaviors/separation.gd` | `GSAISeparation.gd` | MIT | `godot-steering-ai-framework/LICENSE` |

## Referencias de código adaptado (Behavior Tree)

Los siguientes archivos del sistema de behavior tree (AI2) contienen código adaptado de **godot-behavior-tree-plugin** (Jeffery Olson, Brandon Lamb, Sebastian Ebert, 2016-2017, MIT License).

| Archivo del proyecto | Archivo original | Licencia | Licencia en third_party/ |
|---|---|---|---|
| `core/npc/bt/bt_node.gd` | `bt_base.gd` | MIT | `godot-behavior-tree-plugin/LICENSE` |
| `core/npc/bt/bt_composite.gd` | `sequence.gd`, `selector.gd`, `parallel.gd` | MIT | `godot-behavior-tree-plugin/LICENSE` |
| `core/npc/bt/bt_selector.gd` | `selector.gd` | MIT | `godot-behavior-tree-plugin/LICENSE` |
| `core/npc/bt/bt_sequence.gd` | `sequence.gd` | MIT | `godot-behavior-tree-plugin/LICENSE` |
| `core/npc/bt/bt_parallel.gd` | `parallel.gd` | MIT | `godot-behavior-tree-plugin/LICENSE` |
| `core/npc/bt/bt_condition.gd` | `condition.gd` | MIT | `godot-behavior-tree-plugin/LICENSE` |
| `core/npc/bt/bt_action.gd` | `action.gd` | MIT | `godot-behavior-tree-plugin/LICENSE` |
| `core/npc/bt/bt_decorator.gd` | `decorator.gd` | MIT | `godot-behavior-tree-plugin/LICENSE` |
| `core/npc/bt/bt_inverter.gd` | `inverter.gd` | MIT | `godot-behavior-tree-plugin/LICENSE` |
| `core/npc/bt/bt_repeater.gd` | `repeater.gd` | MIT | `godot-behavior-tree-plugin/LICENSE` |
| `core/npc/bt/bt_repeat_until.gd` | `repeat_until_succeed.gd`, `repeat_until_fail.gd` | MIT | `godot-behavior-tree-plugin/LICENSE` |
| `core/npc/bt/bt_always_return.gd` | `succeeder.gd`, `failer.gd` | MIT | `godot-behavior-tree-plugin/LICENSE` |
| `core/npc/bt/blackboard.gd` | `blackboard.gd` | MIT | `godot-behavior-tree-plugin/LICENSE` |
| `core/npc/bt/bt_context.gd` | (adapted context) | MIT | `godot-behavior-tree-plugin/LICENSE` |
| `core/npc/bt/behavior_tree.gd` | `behavior_tree.gd` | MIT | `godot-behavior-tree-plugin/LICENSE` |
| `core/npc/bt/bt_cooldown.gd` | (original cooldown decorator) | MIT | `godot-behavior-tree-plugin/LICENSE` |
| `core/npc/bt/conditions/*.gd` | (custom conditions for NPC) | MIT | `godot-behavior-tree-plugin/LICENSE` |
| `core/npc/bt/actions/*.gd` | (custom actions for NPC) | MIT | `godot-behavior-tree-plugin/LICENSE` |

## Licencias de terceros (AI2)

- **godot-steering-ai-framework** (GDQuest, 2020) — MIT License → `third_party/godot-steering-ai-framework/LICENSE`
- **godot-behavior-tree-plugin** (Jeffery Olson, Brandon Lamb, Sebastian Ebert, 2016-2017) — MIT License → `third_party/godot-behavior-tree-plugin/LICENSE`

## Nota AI2

Todos los archivos listados arriba han sido **adaptados** (no copiados literalmente) para integrarse con la arquitectura del proyecto UNTITLED (NPCNavigation, NPCBehavior, NPCLod, ArmedNpc, etc.). La lógica original de cada referencia se ha modificado para trabajar con el sistema de datos JSON (`data/base/npc_types.json`), el registro de contenido y las convenciones de naming del proyecto. No se ha alterado la lógica de juego funcional más allá de la integración.

