# Rocket race

**Files:** `levels/race/race_director.gd`, `levels/race/goal.tscn`, `ui/race_hud.tscn` + `ui/race_hud.gd`, `rocket/rocket.tscn`
**Tests:** `tests/test_race.gd` (math), `tests/framework/race_scenarios.gd` (plays the level headless with scripted climbers)

## How it works
1. **Countdown** (`countdown_time`, 3 s). The player can already climb: it's a head start.
2. **Liftoff.** The rocket's flame turns on. It speeds up over `acceleration_time` seconds, then climbs at `cruise_speed` px/s.
3. The rocket is a real object in the world (behind the platforms), and the camera follows the player. So **the rocket drifts up the screen when it's faster than you and down when you're faster**.
4. **Warning:** when the rocket's nozzle gets within `danger_zone` px of the top of the screen, a red "The rocket is getting away!" warning blinks, faster as it gets closer.
5. **Lose:** the nozzle leaves the top of the screen. **Win:** the player enters the `Goal` area (on the moon platform).
6. Both end states pause the game and show the end screen. **R / Enter / Start** restarts (works at any time).

## Tuning (RaceDirector in the Inspector)
| Value | Default | Effect |
|---|---|---|
| countdown_time | 3 s | head start |
| cruise_speed | 55 px/s | main difficulty knob |
| acceleration_time | 3 s | how gentle liftoff is |
| danger_zone | 100 px | how early the warning shows |

With the defaults in level_01 (8 platforms, 48 px apart): standing still loses after ~11 s, one platform per second wins, one platform per 2.5 s loses at platform 4. `race_scenarios.gd` checks exactly this, so update it if you retune.

## Signals (for sound, effects, UI)
`countdown_changed(seconds_left)`, `lifted_off`, `danger_changed(amount 0..1)`, `race_lost`, `race_won`.

## Adding the race to a new level
Add a `Rocket` (in the decor, behind platforms), a `Goal`, a `RaceDirector` node pointing at both, and a `RaceHud` pointing at the director. See `levels/level_01.tscn`.

## Ideas not built yet
- Rocket speeds up per zone, or rubber-bands (slows a bit when far ahead).
- Off-screen arrow showing where the rocket is when it's below you.
- Owner waving from the window; the rocket shaking as it nears the top.

## Related
[[game-design]] · [[art-pipeline]] · [[player-movement]]
