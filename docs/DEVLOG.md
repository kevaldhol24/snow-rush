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
