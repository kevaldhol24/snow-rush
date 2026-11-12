# Snow Rush — Roadmap

> **How to use:** work top to bottom. Each phase ends with a debug APK on Keval's phone (Oppo Reno 16c) and his **go / no-go**. Tick boxes as you go and update **Current status**. Never start the next phase without his go.

## Current status
- **Phase:** 1 ✅ done (merged to `main`). **Phase 2 (look-dev) in progress** on branch `phase-2-wip`: step 1 done (snow shader, inverted-normals fix, carve trails).
- **Last build:** `SnowRush-v0.4.0-phase2-debug.apk` (versionCode 6): Phase 2 step 1 look check. Previous: v0.3.1 (Phase 1 final).
- **Waiting on Keval:** the asset packs in `ASSETS.md` (Quaternius Stylized Nature MegaKit + Universal Animation Library / a rigged body, Kenney Nature + Holiday kits, ambientCG snow/rock textures). The cloud session can't download them; commit to `assets/third_party/` or upload the zips in a session. Phase 2 starts with the parts that need no packs.

---

## Phase 0: Prototype + plan ✅
- [x] v0.1 lane prototype (procedural visuals, tricks, shop, save, CI APK)
- [x] Design discussion with Keval → decisions D-003 … D-013
- [x] Docs: GDD, ART_DIRECTION, ASSETS, TECH, ROADMAP, DECISIONS, CLAUDE.md

## Phase 1: Core feel (go/no-go for the whole direction) ✅
Goal: it **feels** fast, downhill and free. Visuals can stay prototype-grade, but they must not be worse than v0.1.
- [x] Restructure folders per `TECH.md §3` (core/player/world/fx/ui/dev); keep the game running after each step
- [x] Slope space + world transform: tilted slope, floating origin, upright props, camera looking down the fall line
- [x] Free-steer rider: drag carve, flick jump/tricks, board yaw/lean, carve spray; keyboard controls
- [x] Speed curve 20 → 36 m/s, steepness effect, tuck → **26 → 50 m/s** (D-015), carving across the slope bleeds speed (D-014)
- [x] Terrain: rollers, steeps/flats, **cliff drops**, **rock/wind lips**, outcrops, crevasses, frozen river (procedural meshes for now)
- [x] Safe-line spline + section generator + Poisson scatter + validation bot
- [x] Analytic collision (cylinders/capsules/boxes, spatial hash), surface normal landing
- [x] Landing grades (Perfect/Good/Sketchy/Crash) on the existing flip/spin system
- [x] Coins on the safe line + trick arcs; magnet/boost/2× ported
- [ ] Object pooling; no `queue_free` in play (props/coins pooled ✔; feature visuals — cliff bands, lip rocks, river planes — still new/free per feature)
- [x] Dev: perf HUD (FPS, draw calls), updated autopilot, `--section=` forcing, screenshot tooling
- [x] Settings: steering sensitivity (3 levels), quality Low/High (shadows on/off at least)
- [x] Autotest 10 seeds: no errors, median bot survival ≥ 1500 m (2026-11-12: ghost_fail 0, median ≈ 17.9 km)
- [x] Feedback round 1 (v0.2.0): smoother surface (no bump hops), no accidental tricks / impossible late flips, camera follows sideways, board turns instead of bike-lean, pine hitbox = canopy, decor outside the rideable width, rocks not buried
- [x] Carve steering (D-014): board heading up to ±62°, arcs, travel along the board, speed bleed; run widened to 36 m; flat sections removed (D-015)
- [x] Steering tune on device: sensitivity softened in v0.3.1 (finger travel, response curve, turn rate)
- [ ] Readability at 180 km/h (re-check during Phase 2 with real props)
- [x] APK → Keval (v0.2.0 … v0.3.1). **Go given 2026-11-12** ("it is good … let's now work on phase 2"). **Acceptance:** feels downhill + fast from the start; carving is comfortable one-handed; cliffs/lips feel natural; ≥ 55 FPS on Reno.

## Phase 2: Look-dev and visual overhaul
Goal: store-screenshot quality (see `ART_DIRECTION.md`). Approval gates at each ★.
- [ ] Import pipeline for third-party packs (scale, origin, shared materials, LOD/impostor), `assets/third_party` excluded from export
- [x] `snow.gdshader`: wrap lighting, blue shadows, view-dependent glitter, slope tint, powder rim (v0.4.0)
- [ ] Snow detail normal maps + rock blend on very steep faces (needs ambientCG textures)
- [x] Fix: inverted normals on all procedural meshes (props were lit from behind since v0.1)
- [x] **Board carve trails** (ribbon) (v0.4.0)
- [ ] Landing decals
- [ ] `prop.gdshader`: snow cap by normal, wind sway, rim, fog
- [ ] Trees (3–4 pines + dead + birch), rocks, cliff bands and lips from packs; tree LOD/impostors
- [ ] **Obstacle readability** (Keval, 2026-11-12): every colliding obstacle must be clearly visible at 30+ m (rocks: snow caps + contrast; no prop half-buried). Every visible prop is either colliding or clearly outside the run (no pass-through)
- [ ] Sky shader (gradient, sun, clouds), layered mountain silhouettes, height fog
- [ ] Biome system + 2 biomes fully dressed (Pine Forest morning, Frozen Lakes golden hour) ★
- [ ] Particles: powder spray (lit), landing burst, falling snow layers, speed lines, coin sparkle, tree puff, crash burst
- [ ] Rider: new stylized snowboarder (pack body + winter gear), sideways stance, procedural poses/IK (carve lean, crouch, air, flip tuck, land absorb, crash tumble) ★
- [ ] Snowboard model + top-sheet texture system; 4 designs + trails ★
- [ ] Camera polish: carve lean, air pull-back, cliff reveal, Perfect slow-mo
- [ ] Menu scene: rider on a scenic ridge, slow orbit
- [ ] Quality presets hold budget (`ART_DIRECTION.md §11`)
- [ ] APK → Keval. **Acceptance:** Keval approves the look on device; FPS budget met on High (or auto-Low)

## Phase 3: Content and trick depth
- [ ] Remaining biomes: Rocky Ridge, Birch Valley sunset, Night Village (+ aurora)
- [ ] Moving obstacles: deer, skiers, rolling snowballs, snowmobile
- [ ] Set pieces: avalanche chase, cable-car pylons, frozen lake
- [ ] Grabs (hold), 720 / chains, frontflip, near-miss bonus + branch puff
- [ ] Style meter → Rush mode
- [ ] Shield power-up
- [ ] Difficulty curve tuning with autotest stats
- [ ] APK → Keval

## Phase 4: Juice, audio, UI
- [ ] Music: menu + 2–3 gameplay loops (licensed per `ASSETS.md`), crossfade per biome
- [ ] SFX set: carve loop by speed, wind, landings by grade, tricks, coins, UI, crash, avalanche
- [ ] Haptics (light on land, heavy on crash), toggle in settings
- [ ] UI restyle: icon set, frosted panels, coin fly, count-ups, trick stamps, combo meter
- [ ] Screens: results (breakdown + mission progress), settings, pause, credits/licences
- [ ] Interactive tutorial (first run: carve, jump, flip, land)
- [ ] APK → Keval

## Phase 5: Meta and economy
- [ ] Missions (3 active, ~60 mission defs), rider level + rewards
- [ ] Daily reward (7-day), daily challenge seed
- [ ] Characters (≈6) + boards (8–12) with 3D shop preview
- [ ] Economy balancing (coins per run, prices) + save migration v1 → v2
- [ ] APK → Keval

## Phase 6: Services and hardening
- [ ] Switch release builds to gradle; AAB; private release keystore via GitHub secrets
- [ ] AdMob: rewarded (revive, 2× coins), interstitial with frequency caps; consent (UMP) for EEA
- [ ] Google Play Billing: Remove Ads, coin packs, starter pack
- [ ] Analytics (Firebase/GameAnalytics) + crash reporting
- [ ] Quality auto-detect benchmark; low-end device pass; APK/AAB size ≤ 80 MB
- [ ] Pause/resume/back-button/interrupt edge cases, offline behaviour

## Phase 7: Release
- [ ] Store listing: icon, feature graphic, 6–8 screenshots, short video (captured in-game)
- [ ] Privacy policy (host on kditlabs.com), Data safety form, content rating, target SDK check
- [ ] Credits screen with the asset register
- [ ] Closed testing (≥ 12 testers / 14 days if still on a personal Play account) → production
