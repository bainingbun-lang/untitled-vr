# Map Standard

## Mandatory Requirements (OBLIGATORIO)
- **Main Scene**: Every map must have a single entry point scene.
- **Scale**: Consistent scale according to project global units.
- **Collisions**: All walkable surfaces must have defined collision shapes.
- **Navigation**: NavigationMesh must be baked and present for NPC movement.
- **Spawn Points**: At least one designated player spawn point.
- **Forbidden Zones**: Defined areas where players/NPCs cannot enter.
- **Boundaries and Exits**: Clear map boundaries and defined exit portals/zones.
- **Unique Identifier**: Every map must have a unique ID.
- **Metadata**: Versioning and author information.
- **License**: Valid project license must be specified.

## Optional Requirements (OPCIONAL)
- **VR Compatibility**: Optimized layouts for VR movement.
- **Android Compatibility**: Reduced poly-count or specific LODs for mobile.
- **Lighting**: Baked lighting for improved performance.
- **LOD (Level of Detail)**: Implementation of LOD levels for distant objects.
- **Zones**: Named areas for event triggering.
- **Performance Profiles**: Defined resource limits for different hardware.
- **Platforms (`platforms`)**: Declared target platforms.
- **Tags (`tags`)**: Free-form labels used to discover maps.
- **Player count (`players_min` / `players_max`)**: Supported player-count range.

## Optional Metadata Fields (OPCIONAL, retrocompatible)

All four fields are optional. A map that omits them keeps exactly the same
validation status as before the amendment; they never relax or replace a
mandatory requirement.

| Field | Type | Rules | Default when omitted |
| --- | --- | --- | --- |
| `platforms` | Array of String | Every value must be `android`, `pc` or `vr` (case-insensitive). An empty list is valid. | `[]` |
| `tags` | Array of String | Every element must be a String. An empty list is valid. | `[]` |
| `players_min` | Integer | `>= 1`. Whole JSON numbers (for example `2.0`) are accepted as integers. | `1` |
| `players_max` | Integer | `>= 1` and `players_min <= players_max` when both are present. | `1` |

`MapValidator` reports a wrong type, an unknown platform, a non-string tag, a
non-integer or a `players_min > players_max` range as `REQUIRES_ADAPTATION`.
`MapAdapter` normalizes aliases and textual values before validation:
`platform`/`supported_platforms` -> `platforms`, `tag` -> `tags`,
`min_players`/`min_player_count` -> `players_min`,
`max_players`/`max_player_count` -> `players_max`, and `players`/`player_count`
-> both player bounds. Platform names are lowercased and `mobile`, `desktop`
and `quest` are accepted as `android`, `pc` and `vr` respectively.

`MapCatalog.filter()` accepts the canonical names and the aliases above.
Criteria are combined with AND; a map must satisfy every supplied criterion
in addition to any compatibility/status criterion.

- `platforms` / `platform` / `supported_platforms`: the map must declare every
  requested platform.
- `tags` / `tag`: the map must carry every requested tag (case-insensitive).
- `players_min` / `min_players` / `min_player_count`: the map's `players_max`
  must be at least the requested value (the map can host that many players).
- `players_max` / `max_players` / `max_player_count`: the map's `players_min`
  must be at most the requested value.
- `players` / `player_count`: the requested count must fall inside the map's
  `[players_min, players_max]` range.

A map with no player metadata does not match player-count criteria, but it is
still returned by `filter({})` and by status-only filters. Invalid criteria or
values are rejected with a controlled error and an empty result.
