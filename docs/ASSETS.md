# Snow Rush — Assets: sourcing, licences, pipeline

## Rules
- **Only** CC0 / public domain, or licences that allow commercial use in games **without** redistribution issues. Record **every** third-party asset in the table at the bottom (name, source URL, licence, author, where it's used). This is needed for the store listing and the credits screen.
- Raw downloads go in `assets/third_party/<pack-name>/` with the pack's own LICENSE file. Game-ready, edited copies go in `assets/models|textures|audio/...`.
- Prefer **glTF/GLB**. FBX is OK (Godot imports FBX via ufbx in 4.3).

## Important limitation of the cloud dev environment
Claude's cloud sessions can download from **GitHub, npm and PyPI**, plus (since 2026-11-12, Keval opened access) **kenney.nl, quaternius.com and dl.google.com**. Still **blocked**: itch.io (so Quaternius packs, which download via itch), Google Drive, Poly Haven, ambientCG, Sketchfab, Mixamo, Pixabay, freesound.
→ Kenney download from a session: GET the asset page with a browser User-Agent + cookie jar, read `data-download-id`, GET `https://kenney.nl/download-link/<id>` (JSON with a signed URL), then download that URL with the same cookies.
→ **Keval downloads the packs below on his PC and commits them to `assets/third_party/`** (or uploads the zips to a session). After that, Claude processes them (import, recolour, LOD, snow-cap shader, etc.).
→ Packs that already live on GitHub (KayKit, Kenney starter kits) can be pulled by Claude directly.

## Shortlist (verify licence on download; all believed CC0 unless noted)
### Characters and animation
| Pack | Use | Where | Status |
|---|---|---|---|
| Quaternius **Universal Animation Library** + **Ultimate Modular Men/Women** or "Ultimate Animated Character" | Rider body on a standard humanoid rig + large free animation set | quaternius.com (Google Drive / itch) | Keval used the UAL in cart-runner → likely has it locally |
| KayKit **Adventurers** (`Rogue_Hooded` used in v0.1) | Fallback / extra characters | GitHub `KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0` | In repo |
| Mixamo (Adobe, free with account; not CC0, but royalty-free in games, raw files can't be redistributed) | Optional extra mocap (crouch, balance, falls) retargeted to the rig | mixamo.com | Optional; keep the source FBX out of the public repo |
| Snowboard poses | Authored by Claude in code / Blender bpy | — | Phase 2 |

### Environment
| Pack | Use |
|---|---|
| Quaternius **Stylized Nature MegaKit** (CC0, free "standard" tier) | Main pines, dead trees, rocks, cliffs, bushes. Top priority |
| Quaternius **Ultimate Nature / Ultimate Stylized Nature** | Extra tree/rock variety, birches |
| Kenney **Nature Kit** (CC0) | Extra props, rocks, fences, logs, tents |
| Kenney **Holiday Kit** (CC0) | Winter props: snowmen, presents, lamps, cabins, festive decor (Night Village) |
| KayKit **Forest Nature Pack** (CC0 free version on itch) | Alternative stylized trees/rocks |
| Kenney / Quaternius **buildings, fences, signs** | Cabins, ski-lift pylons, signposts |

### Textures, sky, audio
| Source | Use |
|---|---|
| **ambientCG** (CC0) | Snow, ice and rock normal/roughness maps (download 1K versions) |
| **Poly Haven** (CC0) | Optional HDRI for menu / reflections, snow textures |
| **Kenney audio packs** (CC0: Impact, Interface, RPG audio) | UI + impact SFX |
| **freesound.org** (filter CC0 only) | Wind, snow carve, whoosh, crowd cheer, avalanche rumble |
| **Music:** OpenGameArt CC0 tracks, or Pixabay Music (Pixabay licence: free commercial use, no attribution) | 1 menu track + 2–3 gameplay loops (upbeat chill / lo-fi electronic) |
| **game-icons.net** (CC BY 3.0, needs attribution) or Kenney **Game Icons** (CC0) | UI icons |

### To make ourselves (scripted, so reproducible)
- Snowboard meshes + top-sheet graphics (8–12 designs).
- Snow trail ribbon, decals, particle textures (soft dot, streak, sparkle, snow puff).
- Cliff bands / rock lips assembled from rock pieces + snow shader.
- Sky/aurora shaders, mountain silhouette layers.
- App icon / feature graphic rendered from in-game.

## Pipeline
1. Drop the pack into `assets/third_party/<pack>/` (keep LICENSE). The folder has a `.gdignore` (not imported) and is excluded from export (`exclude_filter`).
2. Copy only the models the game uses into `assets/models/env/<pack>/`. At runtime `PackProps.mesh(model, size, snow_cap)` (scripts/world/pack_props.gd) bakes transform + size + base-centred origin, recolours summer materials for winter (`RECOLOR`) and puts all surfaces on `world.gdshader` (fog, texture atlas, snow cap). `scenes/dev/pack_probe.tscn` lists model sizes/materials.
3. (Original plan) Claude writes an import script (`tools/` or a Godot `EditorScenePostImport`) to: scale to metres, recentre the origin at the base, assign the shared `world.gdshader` material with the pack texture (snow cap + curve + fog), generate LOD/impostor, and save to `assets/models/<category>/`.
3. Add a row below.
4. Check APK size: target **≤ 80 MB** AAB download. Strip unused pack files from the export via `export_presets.cfg` exclude filters (`assets/third_party/*` is not exported; only processed copies are).

## Asset register
| Asset | Source | Licence | Author | Used for |
|---|---|---|---|---|
| Rogue_Hooded.glb (→ `assets/models/rider.glb`) | github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0 | CC0 | Kay Lousberg | v0.1 rider (to be replaced) |
| coin/jump/land/fall/break .ogg | github.com/KenneyNL/Starter-Kit-3D-Platformer | CC0 (Kenney) | Kenney | SFX |
| Lilita One font | via Kenney Starter Kit 3D Platformer | SIL OFL 1.1 | Juan Montoreano | UI font |
| wind/whoosh/splash/powerup .wav | generated (Python) | own | KDIT Labs | SFX |
| All trees/rocks/ramps/coins/terrain in v0.1 | procedural code | own | KDIT Labs | v0.1 visuals (partly replaced in v0.4.1) |
| Kenney **Holiday Kit** (raw: `assets/third_party/kenney_holiday_kit/`) → `tree-snow-a/b/c`, `snowman`, `snowman-hat`, `rocks-large`, `rocks-medium`, `sled`, `lantern` + `Textures/colormap.png` in `assets/models/env/kenney/` | kenney.nl/assets/holiday-kit | CC0 | Kenney | Snowy pine obstacles + decor, snowmen, rock obstacles/boulders/decor (v0.4.1) |
| Kenney **Nature Kit** 2.1 (raw: `assets/third_party/kenney_nature_kit/`) → `tree_pineTallA–D_detailed`, `tree_pineRoundA/C`, `rock_largeA–D`, `rock_tallA/B/E`, `log_large`, `stump_old`, `stump_round` in `assets/models/env/kenney/` | kenney.nl/assets/nature-kit | CC0 | Kenney | Tall pine decor (recoloured + shader snow cap), rock obstacles, logs (v0.4.1) |
