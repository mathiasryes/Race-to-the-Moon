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
| run_speed | 140 px/s |
| jump_height | 56 px (3.5 tiles) |
| jump_time_to_peak / to_fall | 0.38 s / 0.30 s |
| coyote_time | 0.10 s |
| jump_buffer_time | 0.12 s |

## Connections
- Input actions `move_left`, `move_right`, `jump` (Project Settings → Input Map).
- The `Camera2D` lives inside the player scene and follows them.
- Platforms in [[game-design]] levels are spaced 48px apart vertically to fit the jump height.

## Related
[[0002-pixel-art-640x360]]
