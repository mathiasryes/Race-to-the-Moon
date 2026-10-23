# Game design

> Living document. Fill in the open questions as a team; the AI keeps the rest up to date.

## Pitch
A 2D vertical platformer. You play the pet (a dog, for now) of an astronaut. The rocket launches without you, so you race it to the moon by climbing.

## The race (core mechanic)
- The rocket flies in the background and moves up/down on screen depending on how fast you climb compared to it.
- If the rocket leaves the **top of the screen**, you lose. Works like a rising-lava level, but the pressure comes from above.
- Starts at the launch pad, ends at the moon.
- Built: see [[rocket-race]] for how it works and the tuning values.

## Zones (bottom → top)
1. **Launch site:** grass and launch pad platforms, launch tower, hills.
2. **Sky:** cloud platforms, birds, airplanes, hot air balloons.
3. **Upper atmosphere:** girder and solar-panel platforms, satellites, curved Earth below.
4. **Space:** asteroid platforms, planets, UFOs, spaceships.
5. **Moon:** moon-rock platforms, the moon as the goal.

See [[art-pipeline]] for the art for each zone.

## Core loop
Climb → keep ahead of the rocket → avoid hazards → climb higher → reach the moon before the rocket.

## Controls
| Action | Keyboard | Gamepad |
|---|---|---|
| Move | A/D or ←/→ | D-pad / left stick |
| Jump | Space, W or ↑ (hold for higher jump) | A / Cross |
| Restart | R or Enter | Start |

## Open questions (team to decide)
- [x] **"Race":** against the owner's rocket (see above).
- [ ] Which animal is the pet? (dog placeholder for now)
- [ ] How fast does the rocket go: constant, or speeding up per zone?
- [ ] One long climb, or separate levels per zone?
- [ ] What happens on falling: restart level, checkpoint, or just fall down and keep climbing?
- [ ] Extra moves: double jump, wall jump, dash?
- [ ] Target platform(s): PC only, web, Steam/itch?
- [ ] Art direction and who makes the art/audio.

## Scope
First milestone: **one polished level** that feels great to play (movement, camera, one hazard, one enemy, goal).
