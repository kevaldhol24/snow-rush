# Snow Rush — Game Design Document

> Source of truth for *what* the game is. Art lives in `ART_DIRECTION.md`, code in `TECH.md`, work order in `ROADMAP.md`, choices + reasons in `DECISIONS.md`.

## 1. Pitch
Endless downhill **snowboarding** on a wild mountain. You carve freely through forests, launch off natural cliffs and rock lips, throw flips and spins, and see how far you get before you wipe out. Every run is a fresh mountain.

- **Platform:** Android first (Google Play), portrait, one hand. Studio: KDIT Labs. Package `com.kditlabs.snowrush`.
- **Engine:** Godot 4.3 (GDScript).
- **Session:** 1–4 minute runs, instant restart.
- **Feel references:** the moment-to-moment of SSX / Alto's Odyssey (flow, air, landing) with the readability and meta of Subway Surfers (coins, missions, upgrades).
- **USP:** most mobile runners are 3-lane. Snow Rush is **free-carve 3D** with natural terrain, which feels different every run.

## 2. Pillars
1. **Speed and flow.** The slope must *feel* steep and fast from second one.
2. **Natural mountain.** No artificial ramps or lanes. Cliffs, rock lips, rollers, crevasses and frozen rivers.
3. **Big air, clean landings.** Tricks are easy to start and only risky if you're greedy.
4. **Beautiful.** Every screenshot should look like a store screenshot (see `ART_DIRECTION.md`).
5. **Fair.** A death should always feel like the player's fault.

## 3. Core loop
Run → collect coins, do tricks, complete missions → crash → results (score, coins, mission progress, revive offer) → spend in shop (boards, characters, upgrades) → run again.

## 4. Controls (free steer)
| Input | On ground | In air |
|---|---|---|
| Drag finger left/right (hold) | Carve. Lateral speed ∝ drag offset from touch-down point, clamped. Release = straighten. | No steering (tiny air control, ~10%) |
| Quick flick up | Jump (ollie) | Backflip (flip on X axis) |
| Quick flick left/right | — (drag already steers) | 360 spin left/right |
| Quick flick down | Tuck: brief speed boost, lower stance | Slam: fall fast |
| Hold 2nd finger / hold after flick (Phase 3) | — | Grab (holds pose, adds points per 0.25 s) |

- Flick = swipe > 45 px within < 180 ms. Anything else is a drag.
- Desktop/dev: A/D or arrows steer, W/Space jump/flip, S tuck/slam, Q/E spins.
- Phase 1 must ship an options toggle "Steering sensitivity" (3 levels) and record which one feels right.

## 5. Movement model
- The world is a **tilted slope plane** (base pitch 16°, varies by section). Player physics runs in **slope space**: `x` lateral (m), `a` distance down the fall line (m), `y` height above the local surface (m).
- **Speed:** `v` along the fall line. Starts at **20 m/s**, target speed rises quickly to 26 in the first 20 s, then slowly to a cap of **36 m/s** at ~3 min. Steeper sections add up to +4 m/s, flats remove it, and tuck adds +3 for 1.5 s.
- **Carving:** lateral velocity up to `8 m/s × handling`. Hard carves cost a little forward speed (≤ 5%) and throw a big snow spray. The board yaws up to 35° toward the carve direction (visual).
- **Track width:** the playable corridor is ~**28 m** wide (soft edges). Past the edges, trees get dense and the terrain rises steeply; touching the dense forest is a crash. The corridor meanders (real curves, not a shader fake) following a generated spline.
- **Air:** gravity 27 m/s². Ollie gives vy 9.6 × board jump multiplier. Lips and cliffs launch the player because the surface falls away. Landing aligns to the surface normal.
- **Landing grades** (by remaining trick rotation and board alignment): **Perfect** (+50% trick points, small speed boost), **Good**, **Sketchy** (points ×0.5, speed loss), **Crash** (more than 35% of the trick rotation left, or landing upside down / sideways > 70°).

## 6. Terrain features (procedural, natural looking)
| Feature | Gameplay | Notes |
|---|---|---|
| Rollers | Small undulations. Pop off the crest for small air. | Constant variety, never empty. |
| Rock lips / wind lips | Natural kickers (1–2.5 m). Launch. | Snow-covered rock, organic shape. Replaces wedge ramps. |
| **Cliff drops** | The slope steps down 4–12 m at a rocky edge. Big air, prime trick moment. | Approach has a visible rock band. The drop is always across the full width or has a marked bypass. |
| Rock outcrops | Ride over the low side for air; hitting the face = crash. | Readable face vs ramp side via silhouette + snow cap. |
| Crevasses | Gap across part of the corridor. Jump or steer around. | Blue ice walls, dark depth. |
| Frozen river | Gap across the full width with cracked ice and open water. Jump it (a lip is always provided before it at higher difficulty). | Existing water shader, upgraded. |
| Moguls field (Phase 2) | Bumpy section, many small airs. | |
| Steeps / flats | Speed variation sections. | Sell "downhill". |

## 7. Obstacles
- **Static:** pines (various sizes; clusters), dead trees, boulders, logs, snowmen, fences, signposts, abandoned sled, cabins at the edges (decor only).
- **Moving (Phase 2):** deer crossing, other skiers (slow, AI), rolling snowballs from the side, snowmobile (later sections), falling rocks after a cliff.
- **Set pieces (Phase 2):** avalanche chase (the camera shows the wall behind, so you need to keep speed), cable car pylons, frozen lake section, a village run at dusk.
- **Brushing** a tree's edge (near miss < 0.6 m) = **Near Miss** bonus + snow puff falls from the branches.

## 8. Generation rules (fairness)
1. The generator first creates a **safe line**: a smooth spline down the corridor with max curvature limited by current speed and handling.
2. Features are then placed in **sections** (60–150 m) chosen from a weighted table by difficulty. Each section template defines where along the safe line it may sit.
3. Obstacles are scattered with Poisson-disc sampling, **never within 2.2 m of the safe line**, and density scales with difficulty.
4. Big features (cliffs, rivers, crevasses) must have a lead-in of at least `1.4 s × speed` with no other hazards.
5. Validation pass: a cheap simulated "bot" rides the safe line at current speed. If it can't make it, the section is regenerated. The headless autotest (see `TECH.md`) is the regression check.
6. **Biome sections** change every ~800–1200 m: Pine Forest → Rocky Ridge → Frozen Lakes → Birch Valley → Night Village (lights) and loop with higher difficulty and a palette shift.

## 9. Tricks and scoring
- Tricks: Backflip (400), Frontflip (400, flick down after a big launch, Phase 3), 360 (250), 720 (two spins chained, 600), grabs (Phase 3: Indy, Method, Melon, 100 + 40 per 0.25 s held).
- A combo inside one jump multiplies by the trick count. Points are banked only on a clean landing.
- **Style meter** (Phase 3): tricks, near misses and perfect landings fill it. When full, flick down for **Rush mode** (5 s: speed + invincible + 2× score).
- Score = distance (1/m) × section multiplier + banked trick points. Coins are separate currency.

## 10. Pickups and power-ups
Coins (lines/arcs on the safe line and on trick trajectories), **Magnet**, **Avalanche Boost** (speed + smash), **2× Score**, **Shield** (one free crash, Phase 2). Durations are upgradable.

## 11. Progression and economy
- **Boards** (≈ 8 at launch): stats are jump, handling, trick multiplier, coin bonus. Each has a unique model/texture and trail colour. Prices rise from 0 → 25 000 coins. One or two are premium (gems or IAP).
- **Characters** (≈ 6 at launch, cosmetic + small perk). Unlocked by coins, missions or IAP.
- **Upgrades:** Magnet / Boost / 2× / Shield durations, 5 levels each.
- **Missions:** 3 active (e.g. "Do 3 backflips in one run", "Land 2 Perfect landings", "Ride 2 km in Rocky Ridge"). Completing a set raises the **Rider Level**, which raises the base score multiplier and pays a reward.
- **Daily reward** (7-day loop), **daily challenge seed** (the same mountain for everyone that day; later a leaderboard).
- **Target pacing:** an average 2-minute run pays ~150–300 coins. The 2nd board (~1 500) is reachable on day 1, mid boards in week 1, the top board after a few weeks. Tune with analytics.

## 12. Monetization (Phase 5)
- **Rewarded ads:** revive (1 per run, a second one costs gems), double coins on the results screen, free spin / daily bonus.
- **Interstitials:** at most 1 per 3 runs and never within the first 5 runs of a session. They show only after the results screen.
- **IAP:** Remove Ads (no interstitials, keeps optional rewarded), coin packs, starter pack (board + character + coins), premium board(s).
- No pay-to-win beyond what grinding gives.

## 13. Out of scope (for now)
Multiplayer, level editor, iOS, real-money leaderboards prizes.
