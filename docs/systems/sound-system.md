# Sound system

**Files:** `autoload/sound.gd` (autoload `Sound`), `audio/race_sounds.gd` (`RaceSounds`), `default_bus_layout.tres`
**Tests:** `tests/test_sound.gd`, `tests/framework/sound_scenarios.gd` (plays the level headless and checks each sound fires)
**Placeholders:** `tools/audio/generate_placeholder_sounds.py` (synth bleeps; don't re-run once real sounds are in)

## How it works
- `Sound` plays sounds **by name**, looking for `assets/audio/<sfx|loops|music>/<name>.ogg|.wav`. Missing files are skipped. Adding audio = dropping in a correctly named file (see [[art-and-sound-brief]] for the list).
- Names are listed in `SFX`, `LOOPS`, `MUSIC` in `sound.gd`. Unknown names log a warning.
- API: `Sound.play(name)`, `Sound.set_loop(name, on)`, `Sound.set_loop_amount(name, 0..1)`, `Sound.play_music(name)`, `Sound.stop_all()`, `Sound.release_all()`.
- One-shots use a pool of 8 players; jump, land, double_jump and dash get slight random pitch. Music and loops are forced to loop whatever the file format.
- **Buses:** Master → `Music` (-6 dB) and `SFX`. Balance in the editor's Audio tab.
- Keeps playing while the game is paused (win/lose screens).
- **Headless** (tests/CI) has no audio device: `Sound` records what would play in `Sound.history` and tracks loops, but starts no audio.

## Where sounds are triggered
Gameplay code only emits signals; `RaceSounds` (a node in the level) maps them to sounds:

| Signal | Sound |
|---|---|
| level starts | music `race` |
| `Player.jumped` / `Player.landed` | `jump` / `land` |
| `Player.double_jumped` / `Player.dashed` | `double_jump` / `dash` |
| `Player.dash_refilled` (a treat was eaten) | `treat` |
| `RaceDirector.countdown_changed` | `countdown_beep` |
| `RaceDirector.lifted_off` | `liftoff` + loop `rocket_engine` |
| `RaceDirector.danger_changed` | `warning` once, loop `warning_alarm` with volume following danger |
| `race_won` / `race_lost` | stop loops and music, then `win` / `lose` |

## Adding a new sound
1. Add the name and a description to `SFX`, `LOOPS` or `MUSIC` in `sound.gd`.
2. Trigger it: emit a signal from the gameplay code and connect it in `RaceSounds` (or a similar node).
3. Add it to the table in [[art-and-sound-brief]] so the sound designer knows about it.
4. Optional placeholder: add a synth for it at the **end** of `main()` in `generate_placeholder_sounds.py` and re-run. The script uses one seeded random generator, so appending keeps every earlier placeholder byte-identical (check `git diff`).

## Related
[[rocket-race]] · [[player-movement]] · [[art-and-sound-brief]]
