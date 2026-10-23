# Level generation

**Files:** `levels/generation/level_generator.gd` (`LevelGenerator`), used by `levels/level_01.tscn`
**Tests:** `tests/test_level_generator.gd`

## What it does
At startup the generator builds the whole climb from the ground to the moon:
1. **Main route.** Steps upward one platform at a time. Each step rises 32 px up to 80% of the jump height, and the sideways gap is kept within what the dog can actually reach. So **every level is beatable**.
2. **Side routes.** With `branch_chance` (45%) an extra platform appears beside the main one, also reachable from below. These give the player choices; some may be dead ends.
3. **Regions by height.** Platform style, width and background props depend on the height:

| Region | Starts at | Platform styles | Widths (tiles) | Background props |
|---|---|---|---|---|
| Launch | 0% | launch pad, grass | 3-5 | (tower and rocket are in the scene) |
| Sky | 8% | cloud | 2-5 | clouds, balloon, airplane |
| Upper atmosphere | 40% | girder, solar | 2-4 | satellite, small cloud, spaceship |
| Space | 60% | asteroid (×2), solar | 2-4 | planets, asteroids, UFO, spaceship, satellite |
| Moon | 93% | moon rock | 3-5 | small asteroids |

4. **Finish.** A 6-tile moon-rock platform at the very top; the `Goal` and the moon sprite are moved there. The background's `climb_height` is set to the level height so the sky turns to space on the way up.

## Settings (LevelGenerator in the Inspector)
| Value | Default | Effect |
|---|---|---|
| level_seed | 0 | 0 = a new level every run. Any other number = always the same level (good for testing or a "daily" level) |
| level_height | 3200 px | length of the climb (~50-60 s at a good pace) |
| branch_chance | 0.45 | how many side platforms |
| decor_spacing | 140 px | how dense the background props are |

Region boundaries, styles, widths and props are constants at the top of the script.

## How reachability is worked out
`max_edge_gap(rise, jump)` computes the jump's air time from the player's `jump_height`, `jump_time_to_peak` and `jump_time_to_fall`. It multiplies that by `run_speed`, subtracts the time spent speeding up, and keeps only 75% (`REACH_SAFETY`) for slack. A test simulates a real jump with the player's own movement code and checks the formula never allows a gap the dog can't clear. **If you retune the jump, levels adapt automatically.**

## Not built yet
- Obstacles per region (birds, satellites, asteroids, UFO): see the open question in [[game-design]].
- Moving or crumbling platforms.
- Background clouds can look like cloud platforms; may need a different look.

## Related
[[rocket-race]] · [[player-movement]] · [[art-pipeline]] · [[0005-procedural-levels]]
