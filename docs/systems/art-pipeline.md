# Art pipeline

**Generator:** `tools/art/generate_art.py` → writes `assets/art/**` and previews in `docs/art/`
**Regenerate:** `python tools/art/generate_art.py` (needs Pillow). Output is seeded, so it's identical every run.

All current art is placeholder-quality pixel art drawn by code (no downloaded assets, nothing to credit). Any sprite can later be replaced by a hand-drawn PNG with the same size and frame layout. Once a file is hand-edited, remove it from the generator so it isn't overwritten.

![[mockups.png]]

The palette is also exported for artists: `docs/art/palette.png` (swatches) and `docs/art/palette.gpl` (import into Aseprite/GIMP/Krita). For the artist-facing version of this note, see [[art-and-sound-brief]].

## Assets
| File | Size | Notes |
|---|---|---|
| `player/dog.png` | 8 frames of 24x24 | idle 0-1, run 2-5, jump 6, fall 7. Faces right. Used by `player/dog_frames.tres` |
| `rocket/rocket.png` | 48x112 | owner visible in the window |
| `rocket/flame.png` | 3 frames of 20x34 | engine flame loop |
| `rocket/smoke.png` | 3 frames of 16x16 | launch smoke puffs (small → large) |
| `tiles/platforms.png` | 64x112 atlas | one row per zone: grass, launchpad, cloud, girder, solar, asteroid, moon. Columns: left cap, middle, right cap, single |
| `tiles/dirt_fill.png` | 16x16 | ground fill under grass |
| `backgrounds/sky_gradient.png` | 16x1440 | bottom = Earth sky, top = deep space. Tiles horizontally |
| `backgrounds/stars_far.png`, `stars_near.png` | 320x180 | tileable star layers (parallax) |
| `backgrounds/earth_skyline.png` | 640x180 | mountains, hills, trees at the launch site |
| `backgrounds/earth_horizon.png` | 640x150 | curved Earth seen from space |
| `props/launch_tower.png` | 40x168 | gantry with service arms |
| `props/cloud_big/medium/small.png` | | background clouds |
| `props/airplane.png`, `hot_air_balloon.png`, `bird.png` (2 frames 13x10) | | sky zone |
| `props/satellite.png`, `ufo.png` (2 frames 34x18), `spaceship.png` | | space zone |
| `props/asteroid_small/medium/large.png` | | space zone |
| `props/planet_ringed/red/gas/ice.png`, `moon.png` (132x132) | | space zone, moon = goal |

## How it is used in Godot
- **Player:** `AnimatedSprite2D` with `dog_frames.tres`; `Player.animation_for()` picks idle/run/jump/fall, sprite flips when moving left.
- **Platforms:** `levels/blocks/platform.tscn` (`Platform`, a `@tool` script). Set `zone`, `width_tiles` and `one_way` in the Inspector; the tiles and collision update in the editor. Origin = centre of the top surface.
- **Background:** `levels/background/altitude_background.gd` in a `CanvasLayer` (layer -10). It reads the camera height and shows sky → stars → curved Earth. `climb_height` = pixels until full space (level_01 uses 360 to demo the whole transition; real levels a few thousand).
- **Rocket:** `rocket/rocket.tscn`, origin at the nozzle; `engine_on` toggles the animated flame. Visual only so far.
- **Decor:** loose `Sprite2D` props under a `Decor` node with `z_index = -1`.

## Checking the look
`godot --path . -s res://tests/framework/capture_screenshots.gd` (not headless) saves screenshots of level_01 at three heights to `builds/screenshots/`.

## Related
[[game-design]] · [[0004-procedural-placeholder-art]] · [[player-movement]]
