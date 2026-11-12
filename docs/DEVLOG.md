# Dev log

One entry per task or session, **newest at the top**. Append; never rewrite history (fix mistakes with a new entry).

**Entry template**
```
## YYYY-MM-DD: <short title>
**Phase:** <n> · **Commits:** <hashes> · **Build:** <APK sent? version>
**What:** what was done (bullets)
**Why:** the reason / feedback / decision (link D-xxx)
**How:** notable implementation details, tools, gotchas
**Result / feedback:** test results, screenshots taken, Keval's feedback
**Next:** what's left or next up
```

---

## 2026-11-12: Phase 2 step 3: blockers cleared (Quaternius via itch, Poly Haven), new rider ★, snow detail
**Phase:** 2 · **Commits:** `47157a9`, `7b4e9c9` + this docs/build commit · **Build:** `SnowRush-v0.5.0-phase2-debug.apk` (versionCode 8, 56.6 MB, sent in chat for the ★ rider look gate)
**Context:** Keval linked GitHub and opened network access ("you have all the access now, work on blockers"). Pushed `main` (Phase 1, CI green), `phase-1-wip`, `phase-2-wip`. Access probe: `quaternius.itch.io` + itch's R2 CDN work after Keval added `*.itch.io`; `dl.polyhaven.org` works (but `api.polyhaven.com` is blocked); ambientCG pages work but its file host `acg-download.struffelproductions.com` is blocked (not needed now).
**What:**
- **itch free-download script** (`tools/itch_dl.sh`): the same requests as itch's own JS (POST `/download_url`, then POST `/file/<upload_id>?source=game_download&after_download_lightbox=1&as_props=1`; sending a `key` returned "invalid key"). Downloaded (all CC0): Universal Base Characters, Universal Animation Library 1 + 2, Stylized Nature MegaKit (Standard tiers).
- **D-016:** big raw packs (~250 MB zipped) stay out of git → `assets/raw_packs/` (git-ignored, export-excluded), re-download with `bash tools/fetch_assets.sh`. Only processed, used files are committed.
- **New rider (D-017, ★ gate):** Quaternius male base body (65-bone UE-style rig; textures downscaled 2K → 1K). The free body is a bare mannequin in shorts, so `tools/paint_outfit.py` labels each triangle by rest-pose body region and paints jacket (orange, teal shoulders), snow pants (navy, knee panels), gloves, boots into UV space (face kept). Beanie (yellow, pom-pom) + goggles on a BoneAttachment3D at the Head bone; rim light. 13 UAL clips extracted into `rider_anims.res` (281 KB instead of 15 MB of GLBs). `RiderPose` (SkeletonModifier3D, after the AnimationPlayer): body turned 90° on the board (regular stance), head/shoulders turned toward travel, arms out, stance widened 6°, riding crouch (pelvis drop 0.9·(1−cos a), thigh/calf/foot rotations keep the feet flat). The ride clip is `Idle` + crouch (`Crouch_Idle` is a kneeling sneak). Scale 1.05 (~1.9 m, so it reads on a phone). The existing lean node now gives toe/heel-side lean naturally.
- **Snowboard mesh:** 1.6 × 0.32 m, rounded kicked tips, top-sheet stripes in the board colours, dark edges, explicit normals (the old 2 × 0.68 m slab's winding broke when `_finish()` started flipping normals).
- **Snow detail normals:** Poly Haven `snow_02` normal (CC0), two scales, fading out by 45 m. Terrain chunks have no tangents → per-pixel cotangent frame from `dFdx/dFdy` (Compat-safe).
- Menu/shop camera reframed for the taller rider (menu: whole body under the title; shop: rider + board above the panel).

**Result:** autotest 10 seeds: ghost_fail 0, no script errors, same outcomes as before (deterministic). Headless sim covers ~30% fewer km in the same wall time (skinned rider + modifier): on-device FPS needs Keval's check (FPS meter in Settings). APK 56.6 MB (+6.4 MB). Screenshots: menu, shop, carving, air.
**Known rough edges (rider):** a few skin patches at the collar/shoulder seams of the painted outfit; air and crash still use the riding pose (no grab/tuck/tumble yet); the old KayKit `rider.glb` is kept until Keval approves.
**Next:** Keval's ★ verdict on the rider. Then: air/landing/crash poses (UAL NinjaJump/Death/Hit clips + RiderPose), outfit seam cleanup, particles, sky shader, board top-sheet designs, dead trees/rocks from the MegaKit.

## 2026-11-12: Phase 2 step 2: Kenney packs for trees/rocks/snowmen + fairness fixes at top speed
**Phase:** 2 · **Commits:** `941fc5b`, `94eba3e` + this docs/build commit · **Build:** `SnowRush-v0.4.1-phase2-debug.apk` (versionCode 7, 50.2 MB, sent in chat)
**Context:** Keval opened network access ("you should be able to download now"). Probed: **kenney.nl, quaternius.com, dl.google.com reachable**; itch.io, Google Drive, Poly Haven, ambientCG still blocked (proxy 403). Quaternius packs download via itch.io, so they're still unreachable (rider body + Stylized Nature MegaKit). GitHub push still blocked (account not linked to Claude).
**What:**
- Downloaded **Kenney Holiday Kit + Nature Kit 2.1 (CC0)** via kenney.nl's signed download links (recipe in ASSETS.md). Raw GLBs + licences in `assets/third_party/` (`.gdignore`, excluded from export); 24 used models + the Holiday colormap atlas in `assets/models/env/kenney/`.
- **`PackProps`** (scripts/world/pack_props.gd): runtime pipeline. Bakes the GLB node transform + target size + base-centred origin into a cached ArrayMesh, recolours Nature Kit summer materials for winter (`leafsDark` → pine green, `dirt` → slate rock, rock `grass` tops → snow), and puts every surface on `world.gdshader` (same fog/lighting; new `albedo_tex` for the atlas; optional snow cap). `scenes/dev/pack_probe.tscn` lists sizes/materials.
- **Obstacles:** snowy pines (`tree-snow-a/b/c`, 6 m, hitbox 1.25·s ≈ ⅔ of the canopy, still ≥ 0.8 m inside SAFE_CLEAR); rocks (`rock_tallA/B`, `rocks-medium`) at 2 m × 1.4 m with snow tops, hit height 1.4 (taller = readable at speed, Keval's ask); boulders (`rocks-large`, `rock_tallA`); snowmen (with/without hat); logs (`log_large`). **Decor:** snowy pines + tall Nature pines with the shader snow cap; rock clusters.
- **Fairness bugs found by the ghost at D-015 speeds** (exposed because the new props shifted the generator's RNG stream):
  - Seed 4, a = 15839: at 51 m/s a fixed 1.5 m river lip left the ghost 0.4 m short of the far bank → lip height now `1.5 + 0.035·(speed − 28)`.
  - Seed 10, a = 9501: two rivers back to back. The first jump flew **86 m** at 54 m/s and landed on the second lip's crest at −41 m/s → no launch → water. River run-in is now `max(35, 1.7·speed)`.
- **Autotest reproducibility:** the bot's trick choices used the unseeded `randf()` → landing mods → speed → generator, so runs differed between invocations. `--autotest --seed=N` now seeds the global RNG.
- **Bot:** dodges toward the safe line instead of "whichever side I'm on" (seed 2 hit a pine at 208 m: dodged away from the guaranteed-clear line; slower D-014 turning made that fatal).

**Result:** 10 seeds: **ghost_fail 0**, no script errors; 7/10 alive at the 200 s cap (22+ km), deaths: boulders at 2.6 / 12.8 / 16.6 km (bot skill). APK 50.2 MB (+0.3 MB); no third_party files inside. Before/after sheets sent (v0.4.0 vs v0.4.1, same seeds).
**Next:** Keval's look feedback. Rider still the v0.1 KayKit rogue: needs a Quaternius rigged body (itch.io blocked; Keval to upload the zip) or an alternative. Phase 2 step 3 (no packs needed): particles (lit powder, landing burst, speed lines), sky shader, snowboard model + top sheets, cliff/lip rocks from Nature Kit cliff pieces.

## 2026-11-12: Phase 2 step 1: snow shader, inverted-normals fix, carve trails (branch `phase-2-wip`)
**Phase:** 2 (look-dev, step 1) · **Commits:** `44fede3`, `c478029` + this docs/build commit · **Build:** `SnowRush-v0.4.0-phase2-debug.apk` (versionCode 6, sent in chat for a look check)
**Why:** Keval: "let's now work on phase 2, looks and graphics". The asset packs are still not in the repo, so step 1 covers the ART_DIRECTION items that need none: the snow material (§4, 60% of the screen), board tracks (§4, "the key detail that sells snow"), lighting (§2/§3).
**What:**
- **Bug fix (since v0.1): every procedural mesh had inverted normals.** `Meshes._finish()` called `generate_normals()`, which pointed normals inward for our `_tri()` winding. New `scenes/dev/normal_probe.tscn` measured the tops of rocks/pines/snowman at normal.y ≈ −0.55. Props were lit from behind, hence the dark navy rocks, flat blue-teal pines and no visible snow. Fixed with `generate_normals(true)` (tops now +0.87). This is likely a big part of "looks not impressive".
- Retuned for correct lighting: rock tones darker (`ROCK` 0.29/0.30/0.36, `ROCK_DARK` 0.19/0.20/0.25) and snow only on the top ring, so rocks stay easy to spot (Keval's note). Coins: emission 0.3, metallic 0, rim 0.1 (they had washed out to pale lemon).
- **`shaders/snow.gdshader`:** wrap lighting (0.35), blue shadow fill (#9DB4E8), sun gain 0.78 (lit snow ≈ 243/254/255, just under clipping), view-dependent glitter in 5 cm world cells (only near the camera), powder rim, slope tint, wind patches + fall-line streaks. Custom `light()` is Compat-safe; glitter distance passed fragment→light via a varying (`CAMERA_POSITION_WORLD` isn't available in `light()`). Gotcha: `LIGHT_COLOR` already includes π, so fill terms need `/PI`.
- `world.gdshader`: optional `snow_cap` by world normal. Off for procedural props (from above it whitened whole rocks); meant for the imported packs.
- **Carve trails** (`fx/carve_trail.gd` + `carve_trail.gdshader`): ribbon with two soft edge grooves + pressed base, alpha-blended toward shadow blue (`blend_mul` rendered as a solid dark band in GL Compat). Width/depth scale with carve intensity; breaks in the air and over openings; fades over 70 m; 128-sample ring, no allocations. Vertices are computed once in node-local space; the node sits under `World.root`, which World already shifts on rebase (an explicit shift would have doubled it). Verified past a rebase (a = 397).
- Sun colour #FFF2DC (Pine Forest morning).

**Result:** autotest 10 seeds: ghost_fail 0, no script errors, no ImmediateMesh errors; bot results identical to before (visual-only change). Before/after sheets sent (same seeds/sections, rendered from `main` vs `phase-2-wip`).
**Still to do in Phase 2 (see ROADMAP):** detail normal maps (need ambientCG textures), landing decals, lit powder spray, sky shader, particles, rider + board models, trees/rocks from packs, biomes, menu scene, quality presets.
**Blocked on Keval:** asset packs (rider body + nature props) → upload or commit to `assets/third_party/`.
**Next:** Keval's look feedback on v0.4.0, then step 2: particles (lit powder, landing burst, speed lines), sky shader, snowboard model + top sheets (scripted, no packs needed).

## 2026-11-12: Steering sensitivity + Phase 1 sign-off, merged to main
**Phase:** 1 → **done** (Keval's go) · **Commits:** sensitivity commit + this docs/merge commit · **Build:** `SnowRush-v0.3.1-phase1-debug.apk` (versionCode 5, sent in chat)
**Feedback (Keval, on v0.3.0):** "it is good but now it is a little bit uncontrollable, like too much sensitive. And let's now work on phase 2, looks and graphics." → treated as the Phase 1 go, with the sensitivity fix included.
**What:** full lock needs more finger travel (0.36/0.27/0.20 of screen width, was 0.24/0.17/0.12); response curve `|x|^1.6`; max heading 62 → 55°; heading chase 6.5 → 4.0/s; max yaw rate 2.4 → 1.6 rad/s; camera heading swing 0.4 → 0.3, smoothed on its own (3/s).
**Result:** autotest 10 seeds: ghost_fail 0, no errors, median ≈ 17.7 km (min 2.5 km on seed 3, max 60+ km).
**Merge:** `phase-1-wip` merged into `main` locally (with Keval's `de811d0` pointer commit; CLAUDE.md note updated for Phase 2). Push is still blocked from the cloud session (GitHub not linked), so it ships as a git bundle with `main` + `phase-1-wip`.
**Not done from Phase 1 (carried to Phase 2):** feature visuals still `queue_free` per feature; on-device FPS measurement.
**Next:** Phase 2 look-dev. Asset packs are still not in the repo (Quaternius/Kenney sites are blocked from the cloud; only KayKit adventurers + Kenney starter kits are on GitHub). Start with what needs no packs: snow shader, carve trails, lighting/sky, particles.

## 2026-11-12: Carve steering (D-014), always downhill + faster (D-015)
**Phase:** 1 (awaiting go/no-go) · **Commits:** `580643c` + this docs/build commit · **Build:** `SnowRush-v0.3.0-phase1-debug.apk` (versionCode 4, sent in chat)
**Feedback (Keval, on v0.2.1):** "the steering is still not satisfying, not matching with how real skiing works." He shared a YouTube reference (`youtu.be/sPD1V024ziM`), but YouTube is not reachable from the cloud session, so I asked him for the file or the game name. Discussed options; he chose heading-based carving: "okay lets do that". Also: "make the way downhill only … long way for flat surface, I want to remove that, it should be like constant downhill", "increase initial speed and move the upper limit far more".
**What:**
- **Rider (`rider.gd`):** new `heading` (board/travel direction vs the fall line, max ±62°) and `steer_step()`. Drag = target heading; the board chases it (`TURN_K` 6.5, max `TURN_RATE` 2.4 rad/s, 25% in the air). Release → back to the fall line. Travel: `du = v·sin(h)`, `da = v·cos(h)` (Game splits it). At the run edge the bank turns the board back in. Lean = `atan(v·ω/g)·0.45`, clamped ±18° (from the turn, not the sideways speed). Visual yaw = true heading. Spray scales with carve intensity.
- **Speed (`game.gd`):** speed is now a state. Target = curve `26 + 8(1−e^{−t/10}) + 0.07t`, capped at 50 m/s (≈ 4 min), × slope/tuck/landing mods × `(1 − 0.45·(1−cos h))`. It approaches the target at +6 m/s² and bleeds at −10 m/s². So cutting across the slope costs speed, and pointing down earns it back.
- **Camera:** swings 40% behind the heading (position + look point); roll from yaw rate; the FOV ramp now spans 26–50 m/s.
- **Run width:** `HALF_W` 12 → 18, `EDGE` 13.5 → 19.5; scatter count × `HALF_W/12` keeps obstacle density per m².
- **Downhill only:** "flat" (12°) removed from the section weights (forced `--section=flat` now 18°); power-ups moved to cruise (50%). Min slope ~18°.
- **Bot:** aims the board at the safe-line point `0.55·v` ahead; `--weave` makes it carve S-turns (screenshots).

**Why:** D-014, D-015 (see DECISIONS).
**Result:**
- Autotest 10 seeds: **ghost_fail 0**, no script errors, no bad_landing. Deaths (m): 6463, 7654, 9496, 17133, 17590; 5 alive at the 240 s cap (44–45 km, 50 m/s).
- `--weave` screenshots: body turned to the travel direction, lean into the turn, camera swung behind the board, 95–103 km/h at the start.

**Watch on device:** turn rate (2.4 rad/s ≈ 12 m radius at 30 m/s: maybe too tight or too loose); speed bleed when carving (`SCRUB`, the 0.45 factor); finger travel for full lock (sensitivity setting); readability at 180 km/h (obstacle reaction time; may need lower density at top speed).
**Next:** Keval tests v0.3.0 → tune turn rate / bleed / sensitivity from his notes → go/no-go.

## 2026-11-12: Phase 1 feedback round 1: bumps, steering feel, no-obstacle crashes, pass-through props
**Phase:** 1 (awaiting go/no-go) · **Commits:** `35e4e9d`, `8ed0ae1`, `25efb0e` + this docs/build commit · **Build:** `SnowRush-v0.2.1-phase1-debug.apk` (versionCode 3, sent in chat)
**Feedback (Keval, on v0.2.0-phase1):** "the surface has too many bumps, not feeling good." "Touch input works but the way it reacts feels a little off." "Sometimes it crashes without obstacles, maybe because of bumps." On steering: "the player tilts, which is not the correct way to steer on snow"; "when the player is on the far sides the camera stays in the center, feels off." Also: "some rocks are hiding under snow, impossible to spot, and trees and some rocks are transparent, the player goes through. Keep this in the plan so we don't miss it."
**What / why / how:**
- **Bumps (measured):** new `scenes/dev/bump_probe.tscn` rides feature-free terrain at 22/30/36 m/s. Before: **26 hops/km at 30 m/s, 52/km at 36 m/s** (0.25 s each), RMS vertical accel 74–140 m/s². The 8.5 m roller wave and ~12 m-wavelength noise exceeded gravity + stick at speed. Fix: rollers 48 m + 27 m swells; noise 0.18 → 0.04 on the run (rough only near the banks). After: **~0 hops/km**, RMS 7–17 m/s².
- **No-obstacle crashes (root cause):** in the air, flick-up always started a backflip, even 0.1 s before touchdown. Landing with > 35% of the flip left = `bad_landing`. Bump hops + accidental up-flicks while steering = random crashes. Fix: flips need ≥ 0.34 s to touchdown (worst case "sketchy"), otherwise the flick is ignored.
- **Accidental gestures:** a vertical flick now needs 70 px (was 55) and a 1.8:1 ratio (was 1.4). Sideways (spin) flicks only count within 0.3 s of touch-down, so steering corrections never trigger a 360.
- **Rider tilt:** max roll ~30° → ~10°; the board/body yaws toward the direction of travel instead (1.4× → 1.7×). The proper sideways stance and poses stay in Phase 2 (D-011).
- **Camera:** lateral follow 0.75 → 1.0. With the narrow portrait view (±19° horizontal), at u = 12 the rider was ~21° off-axis, i.e. at or past the screen edge.
- **Pass-through trees:** pine hitbox 0.65 → 1.15 m (canopy ~1.8–2.6 m). Still clear of the safe line (SAFE_CLEAR 2.6 m).
- **Pass-through decor:** non-colliding scatter (pines from u = 13.8, rocks from **12.5**, poles at 12.6) overlapped the rider clamp (13.5). Now everything starts at `EDGE + radius`.
- **Buried rocks:** rocks/boulders are flat-bottomed and centred on the ground point, so the uphill side buried them. Now they sit on the highest ground under the footprint, are taller (y 0.9 → 1.25) and have hit height 0.85 → 1.05.

**Result:** 10-seed autotest: ghost_fail 0 on all, no script errors, **0 bad_landing deaths** (2 before). 5 bots alive at the 240 s cap (37+ km), shortest run 3.9 km (pine). Screenshots (rocks, forest) sent: smoother snow, rider centred, subtle lean, rocks standing proud.
**Still open / planned (added to ROADMAP):** rock readability at distance (small dark shapes; real rock models with snow caps in Phase 2); Keval to re-test whether steering still feels off. If it does, next candidates: the moving finger anchor (finger center shifts after an overshoot), and a "slides sideways rather than carves" feel (max lateral 8.5 m/s ≈ 16° across the slope). Both need discussion before changing.
**Next:** Keval tests v0.2.1 → go/no-go.

## 2026-11-12: Phase 1: downhill look, camera, cliff edge, 10-seed autotest, first Phase 1 APK
**Phase:** 1 (awaiting Keval's go/no-go) · **Commits:** `f466684`, `eb16e86`, `574159a` + this docs/build commit · **Build:** `SnowRush-v0.2.0-phase1-debug.apk` (versionCode 2, sent in chat; installs over v0.1)
**What:**
- **Camera framing** (`camera_rig.gd`): back 6.0 → 7.6 m, height +2.3 → +3.7 m. Rider now sits at ~68–70% screen height; horizon at ~15–20%; pitch down the fall line ~23°.
- **Downhill read** (`Meshes.mountains()` → camera-relative backdrop): a hazy forested valley floor 150 m *below* the camera (250–880 m out) with two broad mountain ranges rising out of it to about eye level. Replaces the 650 m ring of tall spikes whose bases hid behind the slope edge.
- Sky "ground" colour = valley haze (anything below the horizon is never snow-white); fog colour bluer `(0.72, 0.80, 0.93)`.
- Terrain shader: faint streaks along the fall line (UV = lateral m / along-path m) as a perspective cue for slope direction and pitch.
- **Cliff edge** (`Meshes.cliff_band`): jagged lip where ~45% of columns break through as rock, standing 0.35–0.8 m proud; rock crags (`_crag`) rise above the edge on both sides, **outside** the rideable width (centres ≥ `EDGE + 3.2` m). Visual only, no collision change.
- Version bumped to `0.2.0-phase1` / code 2.

**Why:** DEVLOG NEXT items 1–5. Keval: "doesn't feel like downhill" (D-004). Diagnosis from the baseline stills: the far terrain faded into a whitish fog, and the sky's below-horizon colour was the same white, so the snow seemed to run on to the horizon. The mountain bases sat behind the slope edge, so the peaks looked like they rose from snow at the rider's own level. Nothing in view was clearly *below* you. The cliff from the chase cam was a flat blue stripe (the rock face points downhill, away from the camera).

**How:**
- Geometry reasoning: the slope's far edge sits ~19–20° below horizontal. The valley floor and mountain bases only show if they're at a *smaller* depression angle (otherwise the near slope covers them). Hence valley Y −150 at 700–880 m (≈10–12°) and peaks at about eye level, so they fit in the band between the horizon and the slope edge.
- Portrait FOV is narrow (±5 m of slope at 13 m distance), so the side crags only show on the approach, 30–60 m out. Checked with `--section=cruise,cliff` shots at t = 12–16.5 s.
- **Toolchain gotcha:** `dl.google.com` is now **blocked** in cloud sessions, so TECH.md §4's Android SDK step fails. Workaround (now in TECH.md §4): build `apksigner` from the AOSP apksig source mirror on GitHub (`LineageOS/android_tools_apksig`) with the local JDK 21 (stub out the one conscrypt line) and install it as `sdk/build-tools/34.0.0/apksigner`, plus a stub `sdk/platform-tools/adb`. Godot's non-gradle export only needs those; the APK verifies with v1+v2+v3 signatures.
- The `gh` API isn't linked in this session (code search fails), but plain `git clone` of public repos works.

**Result:**
- Screenshots (sent in chat): before/after on seed 12, forest/valley, cliff approach + edge, crevasse, frozen river, lips. Rider ~70% height ✔. The downhill read is clearly better in stills, but final judgement needs the phone at speed.
- Cliff/crevasse/river visuals checked with `--section` shots: cliff OK after the fix; crevasse = dark hole with jagged walls (prototype-grade, OK); river = cracked-ice band + jump (OK).
- **Autotest, 10 seeds** (`--autotest --quit_on_death --seed=1..10`, 240 s cap): all 10 died eventually, **ghost_fail = 0 on all**, no script errors. Distances (m): 6674, 9700, 10683, 12610, 17715, 18135, 25087, 25949, 27944, 31044 → **median ≈ 17.9 km** (target ≥ 1.5 km). Deaths: pine ×6, bad_landing ×2, log, boulder, all at 6+ km and top speed.
- Only log noise: the known headless `Parameter "m" is null` and exit leaks; one `Tweener` "target freed" warning.
- Pool high-water mark rises slowly with difficulty (seed 4: 146 at 2 min → 236 at 14 min, levelling off). Peak per-type demand, not a leak.

**Known gaps (not done, left unticked in ROADMAP):**
- Feature visuals (cliff bands, lip rocks, river planes) are still `new` + `queue_free` per feature (a few per section), so "no queue_free in play" isn't strictly true yet.
- On-device FPS not measured (needs Keval's phone; FPS + draw calls in Settings → FPS meter).
- From the last entry: `tuck` HUD feedback polish, revive edge-case check.

**Next:** Keval tests the APK on the Reno 16c → go/no-go on Phase 1 acceptance (downhill + fast from the start, one-handed carving, cliffs/lips feel natural, ≥ 55 FPS). On go: merge `phase-1-wip` → `main`. On no-go: fix per feedback. Nothing is merged until he approves.

## 2026-11-12: Phase 1 WIP: free steer + real downhill (branch `phase-1-wip`, NOT merged)
**Phase:** 1 (in progress) · **Commits:** see branch `phase-1-wip` · **Build:** none yet (no APK sent)
**What (done, runs headless + renders):**
- Restructured into `scripts/core|world|player|fx|ui|dev`. Old `level.gd`, `terrain.gd` and lane logic removed.
- `world/track.gd`: path space (u lateral, a along path). A meandering path (heading = sum of sines, radius > 250 m) and slope profile tables (per metre, 64-bit), with cliffs as steps in the drop table. Local terrain: banks, rollers, lips (kickers), crevasses, rivers. Floating origin via `to_render()` / `rebase()`.
- `world/terrain_builder.gd`: chunk meshes from direct arrays with analytic normals, plus decor MultiMesh scatter (pines, rocks, poles).
- `world/generator.gd`: sections (intro, cruise, forest, lips, cliff, rocks, logs, steep, flat, crevasse, river) on a safe-line spline. Obstacles are scattered away from the safe line and feature zones. A **ghost rider** using the real physics places coins (arcs match real jumps) and counts `ghost_failures` (fairness check).
- `world/world.gd`: streaming, pooling (`pool.gd`, no `queue_free` in play), hit tests, near-miss, feature visuals (cliff rock bands, lip rocks, river water).
- `player/rider.gd`: free carve (steer -1..1), natural take-off when the ground falls away (`surface_step`, shared with the ghost), ollie, backflip/360 in the air, slam, landing grades (perfect / good / sketchy / crash).
- `player/touch_input.gd`: drag-to-carve with a moving anchor + flicks (up = jump/flip, down = tuck/slam, left/right = spin). Keys: A/D, W/Space, S, Q/E.
- `fx/camera_rig.gd`: chase cam looking down the slope, FOV by speed, carve lean, menu orbit.
- `core/game.gd`: speed 20 → 36 m/s curve (+ slope bonus, tuck, landing speed mods), revive past openings, autotest status prints.
- UI: settings screen (steering sensitivity, graphics low/high, sound, FPS meter), landing stamps, km/h label, new tutorial text. `save.gd` gained `settings` (save version 2).
- Shaders: curved-world code removed. Terrain gets snow patch variation + glitter.
- Dev: `--section=lips,cliff` forces sections, `--autotest` bot follows the safe line, `--shots`.

**Results so far:** headless autotest seed 12: 200 s / 6.2 km, 0 ghost failures, 18 tricks, pool ~170 nodes (stable). Screenshots: lips and air work, shadows OK.

**Open issues / NEXT (pick up here):**
1. **"Downhill" read is still weak in stills.** Last tweaks (uncommitted → now in this commit): slope base 19° (steep 26°), mountain ring lowered (-260) with taller peaks, camera look point `rider_y - 5.2` 18 m ahead. Re-screenshot (`--section=cruise,cliff`) and judge. Ideas if still flat: a distant hazy valley-floor plane far below, bluer fog/haze, stronger cliff reveal.
2. The rider still sits mid-screen. Tune `camera_rig.gd` (back 6.0, height +2.3, look offset) so the rider is at ~70% screen height.
3. Verify cliff visuals (rock band) + crevasse + river visuals with `--section=cliff`, `crevasse`, `river` screenshots.
4. Run the 10-seed autotest (`--autotest --quit_on_death --seed=N`); the bot should rarely die and `ghost_fail` must be 0.
5. Then build the APK, send it to Keval, update ROADMAP checkboxes, merge `phase-1-wip` → `main`.
6. Not done yet from the Phase 1 list: perf validation on device, `tuck` HUD feedback polish, a revive edge-case check.

## 2026-11-12: Dev log started
**Phase:** 0 · **Commits:** (this commit) · **Build:** —
**What:** Added `docs/DEVLOG.md` and a rule in `CLAUDE.md` to log every task/session here.
**Why:** Keval wants one place to look back at what was done, how and why.
**Next:** Phase 1 on Keval's go.

## 2026-11-12: Repo set up + design docs
**Phase:** 0 · **Commits:** `6a25503`, `513695b`, `f5c9e16` · **Build:** — (CI builds v0.1 on push)
**What:**
- Pushed the v0.1 prototype to `kevaldhol24/snow-rush` (`main`).
- Wrote `CLAUDE.md`, `docs/GDD.md`, `ART_DIRECTION.md`, `ASSETS.md`, `TECH.md`, `ROADMAP.md`, `DECISIONS.md`.

**Why:** Keval wants a production-quality game built in phases, with docs detailed enough that a fresh session can continue without context.
**How:**
- Plan agreed in chat: free steer (D-003), real downhill slope (D-004), natural cliffs/lips (D-005), faster start (D-006), snowboard (D-008), endless + missions (D-009), visual overhaul as a release blocker (D-010/011).
- Researched free assets. Cloud sessions can only download from GitHub/npm/PyPI, so Keval downloads the other packs and commits them to `assets/third_party/` (D-012, proposed).
- Git tag push is rejected by the session proxy, so the prototype is referenced by commit `6a25503` instead of a tag.

**Result / feedback:** Docs approved in principle ("i like all you suggested"). Keval stressed the visuals must be much better than v0.1.
**Next:** Keval: download the asset packs (`ASSETS.md`). Claude: Phase 1 (core feel).

## 2026-11-12: v0.1 prototype built + playtested
**Phase:** 0 · **Commits:** `6a25503` · **Build:** `SnowRush-v0.1-debug.apk` (sent in chat)
**What:**
- Godot 4.3 lane-based (3-lane) snowboard runner.
- Procedural terrain/trees/rocks/ramps/rivers, curved-world shader, coins, magnet/boost/2×.
- Tricks: backflip on swipe up in the air, 360 on swipe left/right in the air.
- Shop: 5 boards + 3 upgrades. Save, menu/HUD/pause/game over UI, CI APK workflow.

**Why:** Keval asked for a Subway Surfers-like skiing prototype in Godot with free models, to test the fun quickly.
**How:**
- Rider: KayKit `Rogue_Hooded` (CC0, from GitHub). SFX/font: Kenney Starter Kit.
- Everything else is procedural, because Quaternius/Kenney/itch downloads are blocked in the cloud.
- Tested with a headless autopilot (`--autotest`) and xvfb screenshots. APK exported locally with the Android SDK + debug keystore (`ci/debug.keystore`).
- Gotcha: GDScript `:=` with Variant values fails to parse.

**Result / feedback (Keval):**
- Likes jumps, flips and 360 spins.
- The start is too slow.
- It doesn't feel downhill.
- Ramps look artificial; he wants natural cliffs.
- Asked about free steer vs lanes, which led to the D-003 switch.
- Not impressed by the looks.

**Next:** Design discussion → docs (entry above).
