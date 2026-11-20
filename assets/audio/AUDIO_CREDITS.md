# Créditos de audio (A1 — sonidos REALES)

Todos los archivos bajo `assets/audio/real/` son grabaciones reales descargadas de una
fuente con licencia CC0, CC BY 3.0 o CC BY 4.0. Se descargaron a un directorio temporal
nuevo y vacío (`~/.../opencode/a1/stage`), se inspeccionaron con `file`, `unzip -l`,
`7z l` y `ffprobe` y **no se ejecutó ningún archivo descargado**. Después se convirtieron
con ffmpeg a **Ogg Vorbis mono 44,1 kHz, `-q:a 4`**, recortando silencios
(`silenceremove`), aplicando puerta de ruido (`agate`), normalizando (`loudnorm`) y
limitando (`alimiter=limit=0.62:level=0`, pico máximo medido 0,9435). No hay voces ni
ruido de fondo en los clips de disparo.

`assets/audio/real/manifest.json` registra, **archivo por archivo**, su categoría, pico,
duración, fuente y clave de crédito. Las variantes `body_*` (lowpass 240 Hz) y `crack_*`
(highpass 2,6 kHz) se derivan de esas mismas grabaciones reales.

**Presupuesto:** 170 archivos OGG, **1,87 MB** (límite: 30 MB).

| Clave | Nombre / autor | URL | Licencia | Archivos generados (prefijos) |
|---|---|---|---|---|
| michelbaradari | Michel Baradari (subido por qubodup), *Gunshot Sounds* / *11 male human pain/death sounds* | https://opengameart.org/content/gunshot-sounds , https://opengameart.org/content/11-male-human-paindeath-sounds | CC BY 3.0 | `shot_pistol_01`, `shot_rifle_01`, `voice_pain_male_06..11`, `voice_death_male_01..03` |
| vincent | Vincent Sevedge (Tabasco), *Gunshot Sounds* (`sounds/creativecommons.txt`) | https://opengameart.org/content/gunshot-sounds | CC BY 3.0 | `shot_pistol_03`, `shot_smg_01`, `shot_rifle_02`, `shot_sniper_01..02` |
| kurt | kurt, *Gunshots* | https://opengameart.org/content/gunshots | CC0 1.0 | `shot_pistol_02` |
| xcvg | XCVG, *Tactical Weapons And Tactics Sound Pack* | https://opengameart.org/content/tactical-weapons-and-tactics-sound-pack | CC BY 3.0 / CC BY 4.0 | `shot_smg_02`, `shot_rifle_03`, `voice_death_female_04..06`, `explosion_02..03` |
| springo | SpringySpringo, *Gun reload sounds* | https://opengameart.org/content/gun-reload-sounds | CC0 1.0 | `reload_mag_01`, `reload_bolt_01`, `reload_slide_02` |
| zer0 | zer0_sol, *Handgun Reload Sound Effect* | https://opengameart.org/content/handgun-reload-sound-effect | CC0 1.0 | `reload_mag_02` |
| pauliuw | pauliuw, *Gun reload, lock or click sound* | https://opengameart.org/content/gun-reload-lock-or-click-sound | CC0 1.0 | `reload_slide_01` |
| qubodup_metal | qubodup, *Metal Interactions* | https://opengameart.org/content/metal-interactions | CC0 1.0 | `reload_bolt_02` |
| rubberduck | rubberduck, *75 CC0 breaking / falling / hit sfx* | https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx | CC0 1.0 | `impact_*`, `glass_break_01..03`, `melee_04` |
| peludo | Peludo, *Water Splash and sand footsteps* | https://opengameart.org/content/water-splash-and-sand-footsteps | CC0 1.0 | `impact_water_01..02` |
| dklon | dklon, *Super Foley Pack* | https://opengameart.org/content/super-foley-pack | CC BY 3.0 | `impact_flesh_01..02`, `melee_01..03` |
| till | Till Behrend (TinyWorlds), *Glass Break* | https://opengameart.org/content/glass-break | CC0 1.0 | `impact_glass_03`, `glass_break_04` |
| ggbotnet | GGBotNet, *Car Sound Effects Pack* | https://opengameart.org/content/car-sound-effects-pack-low-quality | CC0 1.0 | `engine_03`, `horn_01` |
| congu_female | congusbongus, *Female screams* (grabaciones originales de thanvannispen CC BY 3.0, tcrocker68/pushkin/Archeos CC0) | https://opengameart.org/content/female-screams | CC BY 3.0 (algunas fuentes CC0) | `voice_pain_female_01..04`, `voice_fear_female_01..03`, `voice_death_female_01..03`, `voice_effort_female_01..03` |
| congu_aargh | congusbongus, *Aargh! (male screams)* (creativeheroes/thanvannispen CC BY 3.0; JohnsonBrandEditing CC0) | https://opengameart.org/content/aargh-male-screams | CC BY 3.0 / CC0 | `voice_fear_male_01..08` |
| qubodup_voice | qubodup, *15 vocal male strain/hurt/pain/jump sounds* | https://opengameart.org/content/15-vocal-male-strainhurtpainjump-sounds | CC0 1.0 | `voice_pain_male_01..05`, `voice_fear_male_09..13`, `voice_effort_male_01..04` |
| thebard | thebardofblasphemy, *Grunts of male death and pain* | https://opengameart.org/content/grunts-male-death-and-pain | CC0 1.0 | `voice_death_male_04..08` |
| mikeask | mikeask, *Breathing Tired* | https://opengameart.org/content/breathing-tired | CC0 1.0 | `voice_pant_01..03` |
| starninjas | StarNinjas, *16 Monster Growls* | https://opengameart.org/content/16-monster-growls | CC0 1.0 | `voice_growl_01..08` |
| donkey | DonkeyMan, *Zombie Noises* | https://opengameart.org/content/zombie-noises | CC BY 4.0 | `voice_growl_09..13` |
| nocturnal | Nocturnal_Vanguard, *Maniacal Laughter Pack 1* | https://opengameart.org/content/maniacal-laughter-pack-1 | CC0 1.0 | `voice_laugh_01..05` |
| weaponguy | WeaponGuy, *Sinister Laugh* | https://opengameart.org/content/sinister-laugh | CC0 1.0 | `voice_laugh_06` |
| antum | AntumDeluge, *Old Man Cough* | https://opengameart.org/content/old-man-cough | CC0 1.0 | `voice_cough_01..03` |
| jeanmyna | JeanMyna_VA, *Crying female low tone (voice over)* | https://opengameart.org/content/crying-female-low-tone-voice-over-vocal-sound-for-character | CC BY 3.0 | `voice_cry_01..03` |
| scribe | Scribe, *RTS commands and reports* | https://opengameart.org/content/rts-commands-and-reports | CC0 1.0 | `voice_alert_01..06`, `voice_phrase_01..04` |
| footsteps | congusbongus, *Footsteps on different surfaces* (swuing, Eelke, EminYILDIRIM, Ali_6868, blukotek en Freesound) | https://opengameart.org/content/footsteps-on-different-surfaces | CC BY 3.0 / CC0 | `step_metal_*`, `step_wood_*`, `step_concrete_*`, `step_dirt_*`, `step_grass_*`, `step_water_*` |
| tinyworlds | TinyWorlds, *Explosion* | https://opengameart.org/content/explosion-0 | CC0 1.0 | `explosion_01` |
| domasx2 | domasx2, *Racing car engine sound loops* | https://opengameart.org/content/racing-car-engine-sound-loops | CC0 1.0 | `engine_01..02` |
| sketchman | SketchMan3, *Wind whoosh loop* | https://opengameart.org/content/wind-whoosh-loop | CC0 1.0 | `amb_wind_01` |
| thimras | Thimras, *Park ambiences* | https://opengameart.org/content/park-ambiences | CC0 1.0 | `amb_wind_02`, `amb_birds_01` |
| tcarisland | tcarisland, *City at Night* | https://opengameart.org/content/city-at-night | CC BY 4.0 | `amb_city_01` |
| wolfgang | Wolfgang_, *Crickets ambient noise (loopable)* | https://opengameart.org/content/crickets-ambient-noise-loopable | CC0 1.0 | `amb_crickets_01` |
| derived | Derivado de grabaciones reales (ver `source` en `manifest.json`) | — | misma licencia que la fuente | `body_*`, `crack_*` |

Enlaces de licencia: CC0 https://creativecommons.org/publicdomain/zero/1.0/ ,
CC BY 3.0 https://creativecommons.org/licenses/by/3.0/ ,
CC BY 4.0 https://creativecommons.org/licenses/by/4.0/ .

## Integrados (aportados por el usuario, sin cambios)

| Archivo | Uso | Origen | Licencia | Estado |
|---|---|---|---|---|
| shotgun_fire.wav, shotgun_pump.wav | Escopeta: capa (a) y bombeo | Video del usuario | DESCONOCIDA | En uso por orden del usuario; se conservan tal cual. |
| ak47_single.wav, ak47_burst.wav | AK47/`assault_rifle`: capa (a) y ráfaga | Video del usuario | DESCONOCIDA | En uso por orden del usuario; se conservan tal cual. |

Integración: `core/game/recorded_sfx.gd`, `core/game/sfx_bank.gd`, `core/game/voice_system.gd`.
Pruebas: `tests/test_audio.gd`, `tests/test_recorded_sfx.gd`, `tests/test_real_audio.gd`.
