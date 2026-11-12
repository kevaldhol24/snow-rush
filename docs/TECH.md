# Snow Rush — Technical Design

## 1. Stack
- Godot **4.3-stable**, GDScript, **GL Compatibility** renderer (see `DECISIONS.md` D-007), portrait 720×1280 reference, `canvas_items` stretch, `expand` aspect.
- Android export, non-gradle for test builds (debug keystore in `ci/`). Phase 5 moves release builds to gradle (needed for the AdMob plugin) + AAB + private release keystore (GitHub secret).
- CI: `.github/workflows/android.yml` builds a debug APK on push to `main` → download from Actions artifacts.

## 2. Current code (v0.1 prototype, tag `v0.1-prototype`)
| File | Role | Fate in v0.2 |
|---|---|---|
| `scripts/game.gd` | States (MENU/PLAY/PAUSED/DEAD), swipe input, scoring, pickups, camera, env, audio, autopilot, screenshot tooling | Split: `game.gd` (state/score) + `input.gd` + `camera_rig.gd` + `env_manager.gd` + `dev_tools.gd` |
| `scripts/level.gd` | Lane pattern generator, chunk streaming, collisions | **Rewrite** as `world/` (slope, safe line, sections, spawner, pools) |
| `scripts/player.gd` | Lane movement, jump/ramp physics, tricks, anim | **Rewrite** movement (free carve, slope space); keep the trick state machine |
| `scripts/terrain.gd` | Height fn + chunk mesh | **Rewrite** for slope + features (cliffs, rollers, crevasses) |
| `scripts/meshes.gd` | Procedural meshes | Keep for VFX/utility meshes; props come from asset packs |
| `scripts/ui.gd` | All UI in code | Keep; restyle in Phase 3; split per screen when it grows |
| `scripts/save.gd` | Autoload: save + catalogue | Keep; move catalogue to `data/*.tres` or JSON; add versioned migration |
| `shaders/world.gdshader` | Fake curve + fog + piste pattern | Replace with `snow.gdshader` + `prop.gdshader` (snow cap) |
| `shaders/water.gdshader` | River + ice | Keep, upgrade |

## 3. Target architecture (v0.2+)
```
scripts/
  core/      game.gd, save.gd (autoload), settings.gd (autoload: quality, sensitivity, audio), events.gd (autoload signal bus)
  player/    rider.gd (physics), rider_visual.gd (anims/poses/IK), tricks.gd, input.gd
  world/     slope.gd (coords + height), safe_line.gd, section_gen.gd, sections/*.gd, spawner.gd, pool.gd, chunk_mesh.gd, biome.gd
  fx/        trail_ribbon.gd, particles.gd, camera_rig.gd, env_manager.gd
  ui/        hud.gd, menu.gd, shop.gd, results.gd, missions.gd, widgets.gd
  meta/      missions.gd, economy.gd, daily.gd
  services/  ads.gd, iap.gd, analytics.gd (all with no-op stubs for desktop/CI)
  dev/       autopilot.gd, shots.gd, perf_hud.gd
data/        boards.json, characters.json, missions.json, sections.json, biomes.json
```

### 3.1 Coordinates: slope space
- Gameplay lives in **slope space**: `a` = distance down the fall line (m, monotonic), `x` = lateral offset (m), `h` = height above the *nominal* slope plane.
- The **nominal slope** descends with pitch θ(a) (base 16°, varies per section). The world-space position of slope point (x, a, h): integrate the slope profile. Keep it simple: `Y(a) = −∫ tan θ(a) da`, `Z(a) = −a`. Lateral meander via the safe-line spline `cx(a)`: world X = `cx(a) + x`.
- Terrain height above nominal = rollers + features (cliff = step in `Y`, lip = bump, crevasse = negative gap).
- **The player node does not move forward in world space**. Instead, the world root is moved/rotated so the player sits near the origin (floating origin, rebase every 500 m). Props are placed upright in world space (trees vertical, not perpendicular to the slope). This is what sells "downhill".
- The camera is behind/above, looking down the fall line.

### 3.2 Generation
1. `safe_line.gd`: a Catmull-Rom spline of control points every 40–80 m. Lateral offset changes are limited by speed (max lateral accel ~6 m/s²).
2. `section_gen.gd`: picks section templates by weight × difficulty × biome. A section knows its length and emits features (cliff at a, lips, outcrops, obstacles, coins, power-ups).
3. `spawner.gd`: Poisson-disc scatter of trees/rocks outside the safe-line radius, denser toward the corridor edges; deterministic per seed.
4. Chunks (24–32 m): terrain mesh built on a worker thread (`WorkerThreadPool`), applied on the main thread.
5. Validation: a kinematic bot rides the safe line. Failure → regenerate the section with a new seed.

### 3.3 Collision
Keep custom analytic collision (fast, deterministic):
- Obstacles = vertical cylinders (trees) / spheres-capsules (rocks, snowmen) / boxes (fences) in slope space, with a spatial hash by `a` bucket (5 m).
- The ground query `surface(x, a)` returns height + normal; the rider snaps or flies.
- No Godot physics bodies needed (cheaper, deterministic for the autotest).

### 3.4 Pooling (fixes v0.1's create/free churn)
`pool.gd` keeps per-type free lists for props, coins and decals. Chunks reuse MultiMesh buffers. Zero `queue_free` during play.

### 3.5 Rendering
- Shared materials: `snow.gdshader` (terrain), `prop.gdshader` (props, with snow-cap-by-normal, wind sway for trees, rim, fog), `rider` (StandardMaterial + rim via next_pass or custom shader).
- Fog: shader distance fog (Compat-safe) blended to the biome horizon colour.
- `env_manager.gd` interpolates biome presets (sky, sun, ambient, fog, particle tint).
- Quality presets (`settings.gd`): High / Medium / Low → shadows, render scale, MSAA, particle amounts, tree density, LOD distances. Auto-detect on first launch from a 3 s benchmark, then let the user change it.

### 3.6 Save
`user://save.cfg`, with a `version` key and migrations. Save on run end, purchase and settings change. Later: Google Play Games cloud save (Phase 5, optional).

### 3.7 Services (Phase 5)
- **Ads:** AdMob via the Poing Studios `godot-admob-android` plugin (gradle build required). Wrapper `ads.gd` with stubs.
- **IAP:** Google Play Billing via Godot's official `GodotGooglePlayBilling` plugin.
- **Analytics:** Firebase (via plugin), or GameAnalytics. Events: run_start/end (dist, score, cause), purchase, ad_watch, mission_complete, fps_avg.

## 4. Dev environment (cloud session bootstrap)
Claude sessions start empty. Set up like this (≈3 min):
```bash
# Godot + export templates (GitHub releases are reachable)
mkdir -p ~/tools && cd ~/tools
curl -sSLO https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip && unzip -oq Godot_v4.3-stable_linux.x86_64.zip
curl -sSL -o templates.tpz https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz
mkdir -p ~/.local/share/godot/export_templates/4.3.stable
unzip -oj -q templates.tpz 'templates/android_debug.apk' 'templates/android_release.apk' 'templates/version.txt' -d ~/.local/share/godot/export_templates/4.3.stable
# Android SDK (dl.google.com is reachable)
mkdir -p ~/android && cd ~/android
curl -sSL -o clt.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip && unzip -oq clt.zip
mkdir -p sdk/cmdline-tools && mv cmdline-tools sdk/cmdline-tools/latest
yes | sdk/cmdline-tools/latest/bin/sdkmanager --sdk_root=$HOME/android/sdk "platform-tools" "build-tools;34.0.0" "platforms;android-34"
# Editor settings for export (keystore is committed in ci/)
mkdir -p ~/.config/godot && cat > ~/.config/godot/editor_settings-4.3.tres <<EOF
[gd_resource type="EditorSettings" format=3]
[resource]
export/android/android_sdk_path = "$HOME/android/sdk"
export/android/java_sdk_path = "/usr/lib/jvm/java-21-openjdk-amd64"
export/android/debug_keystore = "$PWD/ci/debug.keystore"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
EOF
```
Note: `$HOME` is `/root`, not `/home/claude`. Keep paths absolute.

### Common commands (run from the repo root; `G=~/tools/Godot_v4.3-stable_linux.x86_64`)
| Task | Command |
|---|---|
| Import | `$G --headless --path . --import` |
| Parse-check a script | `$G --headless --path . --check-only --script scripts/x.gd` (autoload names show as errors here; that's expected) |
| Headless autopilot run | `$G --headless --path . --fixed-fps 60 -- --autotest --quit_on_death --seed=12` |
| Screenshots (software GL) | `xvfb-run -a -s "-screen 0 720x1280x24" $G --path . --rendering-driver opengl3 --resolution 720x1280 -- --shots=/abs/outdir --shot_times=4,9 --autotest` |
| Force patterns (v0.1) | add `--force=river,ramp` |
| Start run without autopilot | `--run` |
| Shop screenshot | `--shop` |
| Debug APK | `mkdir -p build && $G --headless --path . --export-debug "Android" build/SnowRush.apk` |

Notes:
- Software rendering runs ~4 FPS, and game timers use real time, so screenshots at "t seconds" show less distance than on device. Use `--force`/`--seed` to reach content quickly.
- "Parameter m is null" and shader-global errors in **headless** mode come from the dummy renderer and are harmless.
- GDScript: avoid `:=` when the right side is Variant (array element, `abs()`, `lerp()`, `clamp()`). Use an explicit type, or the parser errors out.

## 5. Testing checklist per phase
- Headless autotest: 10 seeds, no script errors; bot survival median noted in the PR.
- Screenshots of the menu, gameplay (3 moments), results and shop, attached in the session.
- APK built and sent to Keval for on-device feel/FPS test (Oppo Reno 16c).
