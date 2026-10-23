# Level generation

**Files:** `levels/generation/level_generator.gd` (`LevelGenerator`), used by `levels/level_01.tscn`
**Tests:** `tests/test_level_generator.gd`

## Goal
Playtest feedback: "the map feels empty, and the path feels very forced". So the level is built to feel like a place you **find your way up**, not a corridor: about twice as many platforms as before (~175 instead of ~88, about 20 per screen), several ways up, dead ends, platforms you can see but never reach, and ledges only the dash gets you to.

## What it builds (in this order)
Order matters: things that must stay out of reach claim their space first, and everything added later checks it doesn't spoil them.

1. **Main route** (`kind: "main"`, also `main_path`). Steps up from the floor to the moon. **Always climbable with jump + double jump, never needs the dash.**
   - ~75% of steps are single jumps (rise 32 px up to 80% of the jump height). ~25% (`DOUBLE_STEP_CHANCE`) rise 96-115 px, too high for one jump, so the **double jump** matters.
   - It still **sweeps from side to side** (targets 170-250 px out on alternating sides, sometimes a stop in the middle; every step moves at least 60% of the reachable distance sideways).
2. **Unreachable platforms** (`"unreachable"`, ~11, sometimes in pairs). Placed only where nothing can get to them, even with a dash: out of reach by height (more than jump + double jump, 144 px) or by distance (dash reach + 24 px margin). Later platforms are never placed where they'd make one reachable.
3. **Dash-only ledges** (`"dash"`, 2-8 per level, small 2-3 tiles). Each is within one dash of a platform you can reach, but at least 12 px beyond the no-dash reach from every platform. **Each holds a treat** (a dash spent there is given back).
4. **Forks** (`"fork"`, 1-3 per level). The route splits: a second chain of single jumps leaves a route platform, stays at least 100 px away sideways from the route, and rejoins it 3-5 steps later. Both ways are climbable (a test removes the route platforms in between and checks the fork alone still gets there).
5. **Dead ends** (`"dead_end"`, ~15 chains). Side chains of 1-3 platforms from a reachable platform; the last one has nothing higher within reach. Many hold a treat.
6. **Treats.** About one per 300-500 px of climb (7-8 per level). Mostly on dash-only ledges and dead ends, sometimes (15%) on the route. Every treat is reachable: by jumping, or with one dash from a platform you can jump to.
7. **Extra stepping stones** (`"extra"`, ~80). Reachable from an existing platform, spread evenly up the level. These give most of the choices: ~85% of reachable platforms have two or more higher platforms to go to next.
8. **More unreachable platforms** in the spots that are still empty (12-18 unreachable in total).

Platforms never overlap: at least 16 px between edges at similar heights, and stacked platforms are at least 32 px apart (the dog is ~16 px tall).

**Regions by height** decide platform style, width and background props:

| Region | Starts at | Platform styles | Widths (tiles) | Background props |
|---|---|---|---|---|
| Launch | 0% | launch pad, grass | 3-5 | (tower and rocket are in the scene) |
| Sky | 8% | cloud | 2-5 | clouds, balloon, airplane |
| Upper atmosphere | 40% | girder, solar | 2-4 | satellite, small cloud, spaceship |
| Space | 60% | asteroid (×2), solar | 2-4 | planets, asteroids, UFO, spaceship, satellite |
| Moon | 93% | moon rock | 3-5 | small asteroids |

**Finish.** A 6-tile moon-rock platform at the very top (nothing else within 48 px of it); the `Goal` and the moon sprite are moved there. The background's `climb_height` is set to the level height.

## Settings
In the Inspector (LevelGenerator):

| Value | Default | Effect |
|---|---|---|
| level_seed | 0 | 0 = a new level every run. Any other number = always the same level |
| level_height | 3200 px | length of the climb |
| extra_density | 2.5 | extra stepping stones per 100 px of climb (more = more ways up) |
| decor_spacing | 140 px | how dense the background props are |

Constants at the top of the script (grouped as Reach, Spacing, Main route, Exploration, Treats): `DOUBLE_STEP_CHANCE` (0.25), `FORK_SPACING` (350-700 px), `DEAD_END_SPACING` (70-130 px), `UNREACHABLE_PER_1000` (3.5) + `LATE_UNREACHABLE_PER_1000` (2.5), `TREAT_SPACING` (300-500 px), `DASH_TREAT_CHANCE` (0.55), `MAIN_TREAT_CHANCE` (0.15), `MIN_DASH_LEDGES` (2), plus the region tables.

`generate_layout(rng, height, jump, density)` is static and pure: it returns a `Layout` with `platforms` (dicts with `x, y, width, zone, main, kind`), `treats` (centres, 12 px above a platform) and `forks` (route index pairs). The node then spawns platforms and `res://levels/pickups/treat.tscn` instances.

## How reach is worked out
`LevelGenerator.Jump` copies the player's jump, double jump and dash settings. Three moves:
- **Single jump:** `max_edge_gap(rise)`. Air time from `jump_height`, `jump_time_to_peak`, `jump_time_to_fall` (with the fall speed cap), times `run_speed`, minus time spent speeding up, times 75% (`REACH_SAFETY`). Rises up to 80% of `jump_height` (70 px).
- **Jump + double jump:** `max_double_jump_gap(rise)`. Same, with the double jump used at the top of the first jump (peak 88 + 56 = 144 px). Rises up to 80% of that (115 px).
- **Dash:** `max_dash_gap(rise)` = double-jump reach + 90% of `get_dash_distance()` (51 px).

`can_reach(from, to, jump, move)` combines these (moves to lower platforms count down to a 64 px drop). Tests simulate real jumps, with and without a double jump at the apex, using the player's own movement functions, and check the formulas never allow a gap the dog can't clear. **If you retune the jump, levels adapt automatically.**

**Honest limits:** reach uses a safety margin, so a very good player may sometimes make a "dash-only" ledge or a "dead end" jump without the dash. Unreachable platforms use a generous rule (real jump height, dash reach + 24 px), but "unreachable" means *from below*: you can still drop onto one from far higher up, which never helps you climb. The dash is assumed to be horizontal; an upward dash would need these rules revisited.

## Tests (over 40-60 seeds)
Route reachable without the dash; 15-35% double-jump steps; a reachability graph (BFS with jump + double jump) reaches the moon, has ≥5 unreachable platforms, ≥1 dash-only platform, ≥8 dead ends, and ≥50% of reachable platforms offer a choice; forks are climbable on their own; every treat reachable; no overlaps; both sides visited every 600 px; ≥150 platforms and ≥10 per screen; same seed = same level.

## Not built yet
- Obstacles per region (birds, satellites, asteroids, UFO): see the open question in [[game-design]].
- Moving or crumbling platforms.
- Background clouds can look like cloud platforms; may need a different look.
- Launch-site platforms can overlap the launch tower and rocket in the background.
- Dash-only ledges and dead ends look the same as other platforms; a small visual hint could help.

## Related
[[rocket-race]] · [[player-movement]] · [[art-pipeline]] · [[0005-procedural-levels]]
