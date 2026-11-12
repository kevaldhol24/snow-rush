# Decision log

Newest at the bottom. Format: ID — date — decision — why — status.

- **D-001 — 2026-11-12 — Godot 4.3, Android first, portrait.** Same stack as Keval's other games (cart-runner, horror-bmx); native APK runs better than web on low-end phones. *Accepted.*
- **D-002 — 2026-11-12 — v0.1 prototype was lane-based (3 lanes, Subway style).** Fastest way to test the fun. Keval liked jumps, flips and 360s. *Superseded by D-003.*
- **D-003 — 2026-11-12 — Switch to free steer (drag to carve, flicks for jump/tricks).** Lanes made the game feel artificial, prevented natural cliffs and curving paths, and made it one more 3-lane clone. Free carve = snowboarding feel + differentiation. Cost: rewrite player movement + generator. *Accepted by Keval.*
- **D-004 — 2026-11-12 — Real downhill slope geometry instead of the curved-world shader trick.** Keval: "downhill doesn't feel like downhill". The shader bend reads as cresting a hill. A tilted slope with vertical trees, a camera looking down the fall line, and terrain rollers/steeps fixes it. *Accepted.*
- **D-005 — 2026-11-12 — Natural terrain features (cliff drops, rock/wind lips, outcrops, crevasses) replace wedge ramps.** Keval: ramps look artificial; wants natural cliffs. *Accepted.*
- **D-006 — 2026-11-12 — Starting speed ~20 m/s (was 13), cap ~36 m/s, fast early ramp.** Keval: start felt too slow. *Accepted; tune on device.*
- **D-007 — 2026-11-12 — Renderer stays GL Compatibility for now.** Widest device support; the look comes from custom shaders/VFX. Revisit after Phase 2 look-dev if the visuals can't hit the target. *Open; revisit.*
- **D-008 — 2026-11-12 — Snowboard (not skis).** Tricks read better, boards are a strong upgrade/cosmetic line. *Accepted (Keval agreed to all suggestions).*
- **D-009 — 2026-11-12 — Endless runs + missions/biomes for structure (no level mode).** *Accepted.*
- **D-010 — 2026-11-12 — Visual quality is a release blocker.** Keval is not impressed by v0.1 looks; wants the best free models, lighting, particles, snow marks, rider, boards, trees and environment. A dedicated look-dev phase with approval gates (see `ART_DIRECTION.md`). *Accepted.*
- **D-011 — 2026-11-12 — Rider style: stylized (not realistic), proper snowboarder outfit + sideways stance; final model chosen in look-dev.** The v0.1 chibi rogue is not acceptable for release. *Accepted; model TBD.*
- **D-012 — 2026-11-12 — Third-party packs that the cloud session can't download are downloaded by Keval and committed under `assets/third_party/`.** Cloud sessions can only reach GitHub/npm/PyPI. *Proposed — needs Keval's OK.*
- **D-013 — 2026-11-12 — Work in phases; each phase ends with an APK on Keval's phone and his go/no-go.** *Accepted.*
- **D-014 — 2026-11-12 — Carve steering: the board has a heading and you travel along it.** Keval on v0.2.1: steering "not matching how real skiing works". The old model kept the rider facing down the fall line and slid him sideways (max ~16°), like a smooth lane change. New: drag sets the target heading (up to ±62°), the board arcs toward it at a limited turn rate (~2.4 rad/s), release = back to the fall line. Carving across the slope bleeds speed, pointing down regains it. Lean comes from the turn (v × yaw rate), and the camera swings partly behind the heading. The run is widened 24 → 36 m to make room. Refines D-003 (free steer stays). *Accepted by Keval ("okay lets do that").*
- **D-015 — 2026-11-12 — Always clearly downhill; faster start and much higher top speed.** Keval: wants constant downhill, no long flat stretches; start faster; "move the upper limit far more". Flat sections (12°) removed (min slope ~18°); start speed 20 → 26 m/s (94 km/h); cap 36 → 50 m/s (180 km/h), reached after ~4 min. Supersedes D-006's numbers. *Accepted.*
