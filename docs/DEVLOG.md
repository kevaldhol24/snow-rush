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
