# Snow Rush

Endless downhill snowboard runner for Android (Subway Surfers-style), built in **Godot 4.3** (GL Compatibility renderer, portrait).

## Play
- Swipe **left / right**: change lane (3 lanes)
- Swipe **up**: jump. **In the air**, swipe up for a **backflip**
- Swipe **left / right in the air**: lane change + **360 spin**
- Swipe **down in the air**: slam down fast
- Desktop: arrows / WASD / Space, Esc = pause

Land a trick before you touch the snow or it's a **bad landing** (crash). Trick points are only banked when you land clean; chaining tricks in one jump multiplies them (x2, x3...).

## What's in it
| System | Notes |
|---|---|
| Procedural world | Infinite terrain chunks (snowy valley, banks, forest via MultiMesh), curved-world shader that bends the slope down and left/right so the run winds |
| Obstacles | Pine trees and snowmen (dodge), rocks and fallen logs (jump), rocky ramps (big air), frozen rivers (jump or take a ramp) |
| Pattern generator | `scripts/level.gd`: weighted patterns (trees, rocks, log, ramp, river, slalom, mixed, coin runs) with a reaction gap that scales with speed, so you always have a way through |
| Speed | 13 m/s, rising 0.12 m/s every second up to a 30 m/s cap |
| Pickups | Coins, Magnet, Avalanche Boost (faster + smashes obstacles), 2x Score |
| Meta | Coins saved, 5 boards (jump/trick/handling/coin bonuses), 3 power-up upgrades x5 levels, best score, one coin revive per run |

## Project layout
```
scenes/main.tscn        # just a root node running scripts/game.gd
scripts/game.gd        # states, input (swipes), scoring, camera, audio, autopilot test
scripts/level.gd       # chunk streaming, obstacle patterns, collision queries
scripts/player.gd      # rider physics, ramps, tricks, animation
scripts/terrain.gd     # height function + terrain chunk mesh
scripts/meshes.gd      # procedural low-poly meshes (pines, rocks, ramps, logs, snowman, coins...)
scripts/ui.gd          # menu, HUD, shop, pause, game over (all built in code)
scripts/save.gd        # autoload: save file + shop catalogue (boards, upgrades)
shaders/world.gdshader # curved world + fog + piste pattern
shaders/water.gdshader # river with drifting ice
```

## Assets (all free)
- Rider: KayKit Adventurers `Rogue_Hooded` by Kay Lousberg, CC0
- Sounds (coin/jump/land/fall/break) + Lilita One font: Kenney Starter Kit 3D Platformer (sounds CC0, font OFL)
- Everything else (trees, rocks, ramps, coins, terrain, water, wind/whoosh/splash sounds) is generated in code

## Build
GitHub Actions (`.github/workflows/android.yml`) builds a debug APK on each push to `main`. Download it from the run's **Artifacts**.
The debug keystore in `ci/` is for test builds only. Use a separate private keystore for Play Store releases.

Local: Godot 4.3 → Project → Export → Android.

## Dev testing
```
godot --path . -- --autotest              # autopilot plays
godot --headless --path . --fixed-fps 60 -- --autotest --quit_on_death --seed=12
godot --path . -- --autotest --force=river,ramp   # force specific patterns
```
