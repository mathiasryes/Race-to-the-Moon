# Player movement

**Files:** `player/player.gd`, `player/player.tscn`, tests in `tests/test_player.gd`

## What it does
`Player` is a `CharacterBody2D` with run and jump. The jump is tuned by **height and timing** instead of raw gravity, so designers can say "jump 56px high, reach the peak in 0.38s".

- **Variable jump height:** releasing jump early multiplies upward speed by `jump_cut_multiplier`.
- **Coyote time:** jumping still works for `coyote_time` seconds after walking off a ledge.
- **Jump buffer:** pressing jump up to `jump_buffer_time` seconds before landing still jumps on landing.
- **Faster fall:** fall gravity is stronger than rise gravity (snappier feel).
- **Double jump:** pressing jump in the air (after coyote time is over) with `air_jumps` left gives an extra jump that reaches `double_jump_height` above where it started. Air jumps come back on landing. It only fires on a fresh press: a press buffered for landing stays a normal ground jump, and a press during coyote time is a normal jump. Releasing jump early cuts it like a normal jump. Emits `double_jumped`; uses the `jump` animation.
- **Dash:** pressing `dash` with a charge left dashes sideways at `dash_speed` for `dash_time` (≈ 51 px) in the held direction, or the facing direction if none is held. No gravity and no vertical movement during the dash; afterwards the dog keeps `run_speed` in that direction. Works on the ground and in the air. Emits `dashed` and `dash_charges_changed(charges)`; uses the `dash` animation (a run frame).
- **Dash charges do NOT come back on landing.** The dog starts with `max_dash_charges` (1). Treats call `refill_dash()`, which restores the max and emits `dash_charges_changed` + `dash_refilled`. `_ready()` emits `dash_charges_changed` (deferred) so a HUD can show the starting value.
- Logic lives in small testable functions: `update_timers`, `can_jump`, `can_double_jump`, `try_dash`, `advance_dash`, `get_dash_velocity`, `update_facing`, `next_horizontal_speed`, static `animation_for(velocity, on_floor, dashing)`.

## Controls
| Action | Keys |
|---|---|
| Move | `move_left` / `move_right` |
| Jump / double jump | `jump` |
| Dash | `dash`: Shift / X / K / gamepad X |

## Key tuning values (exported, editable in the Inspector)
| Value | Default |
|---|---|
| run_speed | 115 px/s |
| jump_height | 88 px (5.5 tiles) |
| jump_time_to_peak / to_fall | 0.45 s / 0.36 s |
| coyote_time | 0.10 s |
| jump_buffer_time | 0.12 s |
| air_jumps | 1 |
| double_jump_height | 56 px (3.5 tiles) |
| dash_speed / dash_time | 320 px/s / 0.16 s (≈ 51 px) |
| max_dash_charges | 1 |

## Connections
- Input actions `move_left`, `move_right`, `jump`, `dash` (Project Settings → Input Map).
- Treats (`levels/pickups/treat.tscn`) call `refill_dash()`.
- The `Camera2D` lives inside the player scene and follows them.
- Visuals: `AnimatedSprite2D` with `dog_frames.tres` (see [[art-pipeline]]). Collision box is 14x12.
- Platforms are one-way by default, so the player jumps up through them from below.
- The [[level-generation]] spaces platforms from these jump values, so changing them changes every level (and stays beatable).
- The camera is locked horizontally (limits ±320) since the level is exactly one screen wide.

## Related
[[0002-pixel-art-640x360]]
