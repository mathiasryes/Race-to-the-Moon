# Level generation

**Files:** `levels/generation/level_generator.gd` (`LevelGenerator`), used by `levels/level_01.tscn`
**Tests:** `tests/test_level_generator.gd`

## Goal
First playtest: "the map feels empty, and the path feels very forced". So the level is built to feel like a place you **find your way up**, not a corridor: several ways up, dead ends, platforms you can see but never reach, and ledges only the dash gets you to.

Second playtest (the owner): "There needs to be less platforms overall. It is very easy right now with the double jump." So the level is now **sparser and harder**: about 100 platforms per 3200 px level (was ~175), i.e. ~11 per 360 px screen, and about **half the route's steps need the double jump** (was ~25%). The filler stepping stones were cut most. The dash became 8-directional at the same time, and the reach rules below know about that.

## What it builds (in this order)
Order matters: things that must stay out of reach claim their space first, and everything added later checks it doesn't spoil them.

1. **Main route** (`kind: "main"`, also `main_path`). Steps up from the floor to the moon. **Always climbable with jump + double jump, never needs the dash.**
   - ~50% of steps (`DOUBLE_STEP_CHANCE`, nudged towards 50% as the route is built) rise 96-115 px, too high for one jump, so the **double jump** is needed. The rest are single jumps that rise 44-70 px (`SINGLE_STEP_MIN` up to 80% of the jump height), so no easy small hops.
   - It **sweeps from side to side** (targets 170-250 px out on alternating sides, sometimes a stop in the middle). Every step moves at least 85% (`MIN_SIDE_STEP`) of the sideways distance it can safely reach, so single jumps are less forgiving horizontally too.
   - ~40 steps per level.
2. **Forks** (`"fork"`, 2-3 per level, at least 1). The route splits: a second chain of single jumps leaves a route platform, stays at least 100 px away sideways from the route, and rejoins it 3-5 steps later. Built right after the route, because unreachable platforms now need so much room that they would crowd forks out.
3. **Unreachable platforms** (`"unreachable"`, ~6 placed now and up to ~3 more at the end; 6-9 on most levels). Placed only where no platform you can stand on could ever get to them, **even with an upward dash** (see "How reach is worked out"). Free spots are rare, so every spot on a 24-column × 16 px grid is tried in random order. They end up mostly on the far side where the route turns.
4. **Dash-only ledges** (`"dash"`, 2-8 per level, small 2-3 tiles). Each is within one dash of a platform you can reach, but at least 12 px beyond the no-dash reach from every platform. Two kinds, mixed (a level that has only one kind so far gets the other next):
   - **sideways** ledges: at about the same height, too far to jump to;
   - **upward** ledges: higher than any jump + double jump can get (144 px + 12, using the real heights) and only reachable with a straight-up or diagonal dash. They are also kept out of reach of a **sideways** dash from any climbable platform, so they really need the dash pointed up. Upward ledges are easiest to fit above dead ends, away from the route, so leftover treats go there until a level has 2 (`MIN_UP_DASH_LEDGES`).
   **Each holds a treat** (a dash spent there is given back).
5. **Dead ends** (`"dead_end"`, ~7-12 chains of 1-2 platforms). Side chains from a reachable platform; the last one has nothing higher within reach without the dash. Many hold a treat or have an upward-dash ledge above them.
6. **Treats.** About one per 300-500 px of climb (6-9 per level). Mostly on dash-only ledges and dead ends, sometimes (15%) on the route, else on another off-route platform. Every treat is reachable: by jumping, or with one dash in any of the 8 directions from a platform you can jump to.
7. **Extra stepping stones** (`"extra"`, ~26, `extra_density` 0.8 per 100 px). Mostly sideways (rise −24 to +44 px), so they give choices without becoming a ladder that skips the route's double-jump steps. They fill the emptiest stretches first.
8. **More unreachable platforms** in the spots that are still free.

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

## Typical numbers (3200 px level, 200 seeds)
| | Typical | Range |
|---|---|---|
| Platforms | ~103 (~11.6 per screen) | 96-115 |
| Route steps needing the double jump | ~48% | 43-53% |
| Forks | 2 | 2-3 |
| Dead-end chains | ~9 | 4-13 |
| Unreachable | 7-9 | 2-9 (rarely below 5) |
| Dash-only ledges (upward + sideways) | 3-5 (1-2 up) | 2-8 |
| Treats | 7-8 | 6-9 |

## Settings
In the Inspector (LevelGenerator):

| Value | Default | Effect |
|---|---|---|
| level_seed | 0 | 0 = a new level every run. Any other number = always the same level |
| level_height | 3200 px | length of the climb |
| extra_density | 0.8 | extra stepping stones per 100 px of climb (more = more ways up, fuller and easier) |
| decor_spacing | 140 px | how dense the background props are |

Constants at the top of the script (grouped as Reach, Spacing, Main route, Exploration, Treats): `DOUBLE_STEP_CHANCE` (0.5), `SINGLE_STEP_MIN` (44 px), `MIN_SIDE_STEP` (0.85), `FORK_SPACING` (600-1100 px), `DEAD_END_SPACING` (140-240 px), `UNREACHABLE_PER_1000` (2) + `LATE_UNREACHABLE_PER_1000` (1), `UP_DASH_LEDGE_CHANCE` (0.6), `TREAT_SPACING` (300-500 px), `DASH_TREAT_CHANCE` (0.55), `MAIN_TREAT_CHANCE` (0.15), `MIN_DASH_LEDGES` (2), `MIN_UP_DASH_LEDGES` (2), plus the region tables.

`generate_layout(rng, height, jump, density)` is static and pure: it returns a `Layout` with `platforms` (dicts with `x, y, width, zone, main, kind`), `treats` (centres, 12 px above a platform) and `forks` (route index pairs). The node then spawns platforms and `res://levels/pickups/treat.tscn` instances.

## How reach is worked out
`LevelGenerator.Jump` copies the player's jump, double jump and dash settings (`Jump.from_player`). Nothing is hard-coded: with today's values the jump is 88 px, the double jump 56 px, and the dash `get_dash_distance()` = 340 px/s × 0.24 s ≈ 82 px.

Moves the generator **plans with** (safety-reduced, so normal players make them):
- **Single jump:** `max_edge_gap(rise)`. Air time from `jump_height`, `jump_time_to_peak`, `jump_time_to_fall` (with the fall speed cap), times `run_speed`, minus time spent speeding up, times 75% (`REACH_SAFETY`). Rises up to 80% of `jump_height` (70 px).
- **Jump + double jump:** `max_double_jump_gap(rise)`. Same, with the double jump used at the top of the first jump (peak 88 + 56 = 144 px). Rises up to 80% of that (115 px).
- **Jump + double jump + one dash in a direction:** `max_dash_gap(rise, direction)`. The dash is **8-directional** (normalised, so always ~82 px along its direction, no gravity). When it ends the dog keeps `run_speed` along the dash, so after an upward dash it coasts up another `run_speed² / (2 × jump gravity)` ≈ 8 px (`post_dash_rise`). The generator plans the dash at the top of the double jump in three directions (left/right mirror):
  - **sideways** (`DASH_SIDE`): double-jump reach + 90% (`DASH_SAFETY`) of the dash distance sideways (+74 px). Rises up to 115 px.
  - **diagonal** (`DASH_DIAGONAL`): d/√2 up and d/√2 sideways. Rises up to 115 + 90% × (58 + 4) ≈ 171 px.
  - **straight up** (`DASH_UP`): `dash_rise` = dash distance + coast ≈ 89 px up. Rises up to 115 + 90% × 89 ≈ 196 px. Sideways it only gets the (longer) jump drift, and it has to speed up sideways again after the dash.
  `can_reach(from, to, jump, Move.DASH)` takes the best of the three; `can_dash_to(from, to, jump, direction)` checks one.

`can_reach(from, to, jump, move)` combines these (moves to lower platforms count down to a 64 px drop). Tests simulate real jumps, with and without a double jump at the apex, using the player's own movement functions, and check the formulas never allow a gap the dog can't clear. A test also simulates jump + double jump + a straight-up dash and checks the peak (≈ 233 px) matches `highest_ever`. **If you retune the jump or dash, levels adapt automatically.**

**Unreachable** uses a separate, generous rule, `could_ever_reach`: what a *perfect* player could do. Real heights, no safety factors, full run speed from the start, a dash in any direction (sampled from sideways to straight up) at any moment, and the fall broken into 3 pieces (a late double jump and a mid-fall dash both stop a fall, which buys air time). That gives:
- up to `highest_ever` = 88 + 56 + 82 + 8 ≈ **233 px** of rise,
- about 276 px of sideways gap at the same height (vs 179 px the generator plans with),
- plus a 24 px margin (`UNREACHABLE_MARGIN`) on top of both.
It is looked up from a table by whole-pixel rise (`ever_gap`, cached on the `Jump`), because every unreachable check uses it.

**Honest limits:**
- Reach uses safety margins, so a very good player may sometimes make a sideways "dash-only" ledge or a "dead end" jump without the dash. Upward ledges are above the real double-jump height from their base, but another platform may sit a little closer.
- "Unreachable" means *from below*: you can still drop onto one from far higher up, which never helps you climb. Coyote time (walking off a ledge before jumping) isn't modelled; the 24 px margin covers it.
- The generous rule makes unreachable spots rare. A few random levels end up with only 2-4 unreachable platforms (1 of the first 200 seeds had 2).
- The `ever_gaps` table is filled on first use; change a `Jump`'s fields only before using it.

## Tests (over 40-60 seeds)
Route reachable without the dash; 45-55% double-jump steps overall (38-62% per level); single-jump route steps rise ≥ 44 px; 85-120 platforms per level (90-110 on average) and 6-24 per screen; the upward-dash formula (dash distance + `run_speed²/(2 × jump gravity)`) from the player's values; a simulated jump + double jump + up dash peak; direction checks (high up needs an up dash, far out a sideways one; the generous rule always allows at least the planned dash reach); a reachability graph (BFS with jump + double jump; then one 8-way dash) reaches the moon, has ≥5 unreachable platforms, ≥2 dash-only platforms, ≥5 dead ends and ≥30% of reachable platforms offer a choice; over all seeds, dash-only platforms that need an upward/diagonal dash and ones a sideways dash reaches both appear; unreachable platforms survive the generous rule and every planned dash direction plus the margin; forks are climbable on their own (≥1 per level); every treat reachable and mostly off the route; no overlaps; both sides visited every 600 px; same seed = same level.

## Not built yet
- Obstacles per region (birds, satellites, asteroids, UFO): see the open question in [[game-design]].
- Moving or crumbling platforms.
- Background clouds can look like cloud platforms; may need a different look.
- Launch-site platforms can overlap the launch tower and rocket in the background.
- Dash-only ledges and dead ends look the same as other platforms; a small visual hint could help (especially for upward-dash ledges, which can be off screen above a dead end).

## Related
[[rocket-race]] · [[player-movement]] · [[art-pipeline]] · [[0005-procedural-levels]] · [[0006-exploration-dash-and-treats]]
