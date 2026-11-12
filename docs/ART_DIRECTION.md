# Snow Rush — Art Direction

> Goal: **every frame looks like a store screenshot.** The v0.1 prototype plays well but looks programmer-art: pale flat snow, cone trees, a chibi rogue, plank boards. This doc defines the target and how to get there with **free assets + shaders + effects**, within a mid-range Android budget.

## 1. Style target
**Stylized low-poly / soft-shaded, bright and saturated, cinematic light.** Think *Alto's Odyssey* mood and colour, in 3D, with the crisp readability of *Subway Surfers*.
- Clean, chunky shapes with clear silhouettes and gentle bevels. No noisy realism.
- Strong **light vs shadow**: warm sun, **blue/violet shadows** on snow, glowing rim light on the rider.
- **Depth through atmosphere:** layered mountain silhouettes, height fog, light shafts, falling snow.
- Each biome has its own **time of day** and palette, so the run evolves visually.

## 2. Palettes (starting points, tune in look-dev)
| Biome | Sky top → horizon | Sun | Snow lit / shadow | Accent |
|---|---|---|---|---|
| Pine Forest (morning) | `#3E7BD8` → `#CFE3F7` | warm white `#FFF2DC` | `#F4F7FF` / `#9DB4E8` | pine `#1F5E4A`, coins gold |
| Rocky Ridge (noon) | `#2F6BD6` → `#E2EEFA` | white | `#FFFFFF` / `#A6B9E6` | rock `#6B7088` |
| Frozen Lakes (golden hour) | `#5B6FD0` → `#FFC9A3` | orange `#FFB070` | `#FFE9D6` / `#8A8FD8` | ice `#8FE3FF` |
| Birch Valley (sunset) | `#7A4FC0` → `#FF9C7A` | `#FF8A55` | `#FFD3C0` / `#7D6CC8` | birch white, red leaves |
| Night Village | `#0D1838` → `#2A3C7A` | moon `#AFC6FF` | `#C9D8FF` / `#3A4A8A` | warm window lights `#FFC46B`, aurora |

Biome transitions blend sky, sun, fog and ambient over ~150 m.

## 3. Lighting
- One **directional sun** with shadows (cascade 1–2, ~40 m distance on High, off on Low) and **ambient from a gradient sky**.
- **Fake bounce:** the snow shader adds light from below (cool tint) on characters via a rim/fill term.
- **Baked-feel AO:** vertex colour darkening at tree bases, rock crevices and cliff bottoms. Contact "shadow blobs" under props on Low quality.
- **Rider rim light** in the shader (always readable against the snow).
- **Sun disc + lens glow sprite** in some biomes; god-rays as additive billboard cards through trees (cheap).
- Night: point lights are expensive. Use **emissive + glow sprites** for windows/lamps, and one moving light at most.

## 4. Snow, the most important material
The snow covers 60% of the screen, so it carries the look.
- **Base:** near-white albedo with a subtle blue tint, soft wrap lighting (lambert wrap ~0.3) so shadows go blue, not grey.
- **Detail normal map** (tiling CC0 snow texture, two scales) for sparkle-catching micro-bumps.
- **Glitter:** view-dependent sparkle points (hash in world space, gated by `dot(reflect, light)`), not the v0.1 random squares.
- **Fresnel/rim** for a soft powder edge on ridges.
- **Slope tint:** steep faces slightly darker/bluer, exposed rock where very steep (blend by normal).
- **Board tracks ("marks"):** the rider leaves a **carve trail**. It's a ribbon mesh laid on the surface (2 lines for the board edges, slightly darker and blue, normal-perturbed), which fades after ~60 m. Hard carves leave deeper and wider marks. Landings stamp an **impact decal**. This is the key detail that sells "snow".
- **Tree-brush puff:** passing near a tree drops snow from the branches (particles).

## 5. Particles and VFX (all must have a Low-quality fallback)
| Effect | When | Notes |
|---|---|---|
| Powder spray | Always while riding; bigger when carving | Soft round sprites, lit (tinted by sun colour), sideways on carves |
| Snow trail mist | High speed | Faint long ribbon behind the board |
| Landing burst | Every landing; size by fall height | Ring of powder plus a camera shake |
| Perfect landing | Perfect grade | Sparkle ring + "PERFECT" UI stamp |
| Falling snow | Ambient, per biome intensity | Depth layers: near flakes motion-stretched by speed |
| Speed lines | Speed above 30 m/s, boost | Screen-space streaks (UI layer) |
| Wind streaks | Ridges | Thin white ribbons along the ground |
| Coin pickup | Coin | Sparkle + slight UI coin fly to counter |
| Power-up aura | Magnet/Boost/Shield active | Rider aura colour + trail colour |
| Board trail | Per board | Unique trail colour/particles (shop sell point) |
| Crash | Crash | Snow explosion, board flies off, ragdoll-ish tumble |
| Tree snow puff | Near miss / brushing | Branch snow fall |
| Avalanche | Set piece | Large rolling billboard sheets + fog wall |
| Aurora | Night biome | Animated shader ribbon in sky |

## 6. Rider
- Requirement: a **stylized, appealing human snowboarder** (beanie/helmet, goggles, puffy jacket, gloves) with a **snowboard stance**. The v0.1 forward-facing chibi rogue is not acceptable for release.
- Reality check: there is **no free CC0 rigged character with snowboard animations**. Plan:
  1. **Body:** a free CC0 stylized rigged humanoid (candidates in `ASSETS.md`; Quaternius character packs or KayKit), ideally on a **humanoid rig compatible with the Quaternius Universal Animation Library**, so we can reuse many free animations.
  2. **Outfit:** winter gear (beanie, goggles, scarf, jacket colours) as attached meshes and material swaps, which also gives us cheap **skins**.
  3. **Snowboard animations:** author the stance, carve-lean left/right, crouch-to-ollie, air pose, grabs, flip tuck, land-absorb and crash, as **poses blended in code** (Skeleton3D bone overrides + IK for feet on the board), or bake them with Blender (`bpy` via pip, scripted) into the GLB. Poses are few and simple, so this is feasible.
  4. The rider rides **sideways** (regular/goofy stance) and the camera is behind-and-above, the classic snowboard look.
- Characters for the shop: 6 at launch = 2–3 bodies × outfit colours/hats + 1–2 fun ones (yeti, penguin mascot, robot) if free models exist.

## 7. Boards
- **Proper snowboard shape** (twin-tip, slight camber, bindings) as one GLB authored by script (Blender bpy) or carefully generated mesh, with a **UV for a top graphic**.
- Each board = base model + **top-sheet texture** (graphic design: flames, aurora, mountain, gold, pixel, etc.) + base colour + **trail effect**. Designs are made as textures (procedural or drawn), so 8–12 boards are cheap and high-impact.
- The shop shows a **rotating 3D board preview** under good light.

## 8. Environment
- **Trees:** high-quality stylized pines (3–4 variants, snow-laden, plus a bare dead tree and birch for Birch Valley) from free packs, recoloured and with a snow cap via the shader (snow on up-facing normals) so any tree becomes snowy. Use MultiMesh plus 2 LODs (mesh → billboard impostor beyond ~120 m).
- **Rocks/cliffs:** modular rock pieces (free packs) combined into cliff bands. Snow on top via the shader.
- **Props:** fences, signs, flags, cabins, ski-lift pylons, lamps, tents, snowmen, logs, sled.
- **Far scenery:** layered mountain silhouettes (2–3 depth layers, parallax), cloud cards, a distant valley with town lights at night.
- **Sky:** gradient + sun + clouds via shader (cheap). Poly Haven CC0 HDRI panoramas are optional for the menu backdrop.
- **Water/ice:** an upgraded river shader (depth tint, ice floes with refraction-ish highlight, foam edges).

## 9. Camera
Behind and above the rider, **looking down the slope** (pitch about −20°). FOV 62→78 with speed. The camera lags and leans into carves, pulls back on big air, and goes slow-mo for 0.3 s on a Perfect + big combo. On a cliff drop, the camera lifts for a dramatic reveal. Light shake on landings. Menu: a slow orbit of the rider on a scenic ridge.

## 10. UI style
- Chunky rounded font (current Lilita One is fine), white with deep-blue outline, gold for coins.
- Frosted panels (semi-transparent white with soft shadow), bright 3D buttons with press animation.
- **Juice:** numbers count up, coins fly to the counter, trick names stamp in with scale bounce, combo meter.
- Icons: a proper icon set (free CC0 game-icons or custom) in place of text like "SND" / "II".
- App icon + store graphics: rendered from the game's own scene (rider mid-air in front of a mountain at golden hour).

## 11. Performance budget (Phase 1 must measure on Oppo Reno 16c)
| | High | Low |
|---|---|---|
| Target FPS | 60 | 60 (min 45) |
| Draw calls | ≤ 250 | ≤ 120 |
| Triangles on screen | ≤ 300k | ≤ 120k |
| Shadows | 1 cascade, 2048 | Off (blob shadows) |
| Particles | Full | 50% |
| Render scale | 1.0 | 0.8 |
| MSAA | 2× | Off |
Renderer: **GL Compatibility** (widest device support) unless the look-dev proves the Mobile/Vulkan renderer is needed and Reno performance holds. See `DECISIONS.md`.

## 12. Look-dev process
1. Build a **look-dev scene** (`scenes/lookdev.tscn`): a 150 m slope with every feature type and one rider, and a biome switcher.
2. Capture fixed-camera screenshots per biome (scripted: `--shots`) and compare against this doc.
3. Keval approves each biome look **before** content is scaled up.
