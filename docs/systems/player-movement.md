# Player movement

**Files:** `player/player.gd`, `player/player.tscn`, tests in `tests/test_player.gd`

## What it does
`Player` is a `CharacterBody2D` with run and jump. The jump is tuned by **height and timing** instead of raw gravity, so designers can say "jump 56px high, reach the peak in 0.38s".

- **Variable jump height:** releasing jump early multiplies upward speed by `jump_cut_multiplier`.
- **Coyote time:** jumping still works for `coyote_time` seconds after walking off a ledge.
- **Jump buffer:** pressing jump up to `jump_buffer_time` seconds before landing still jumps on landing.
- **Faster fall:** fall gravity is stronger than rise gravity (snappier feel).

## Key tuning values (exported, editable in the Inspector)
| Value | Default |
|---|---|
| run_speed | 115 px/s |
| jump_height | 88 px (5.5 tiles) |
| jump_time_to_peak / to_fall | 0.45 s / 0.36 s |
| coyote_time | 0.10 s |
| jump_buffer_time | 0.12 s |

## Connections
- Input actions `move_left`, `move_right`, `jump` (Project Settings → Input Map).
- The `Camera2D` lives inside the player scene and follows them.
- Visuals: `AnimatedSprite2D` with `dog_frames.tres` (see [[art-pipeline]]). Collision box is 14x12.
- Platforms are one-way by default, so the player jumps up through them from below.
- The [[level-generation]] spaces platforms from these jump values, so changing them changes every level (and stays beatable).
- The camera is locked horizontally (limits ±320) since the level is exactly one screen wide.

## Related
[[0002-pixel-art-640x360]]
