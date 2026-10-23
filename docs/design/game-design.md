# Game design

> Living document. Fill in the open questions as a team; the AI keeps the rest up to date.

## Pitch
A 2D vertical platformer. You play the pet dog (a beagle) of an astronaut. The rocket launches without you, so you race it to the moon by climbing.

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
| Double jump | Jump again in the air (once per jump) | A / Cross |
| Dash | Shift, X or K | X / Square |
| Restart | R or Enter | Start |

## Movement and treats
- **Double jump:** one extra jump in the air, back every time you land.
- **Dash:** a quick horizontal burst. You start with **one**. It does **not** come back on landing.
- **Dog treats** are scattered around the level. Grabbing one **refills the dash**. Many sit on dead ends or spots only a dash can reach, so detours are a gamble against the rocket.

## Level feel
The climb should feel like **finding your own way up**, not following a corridor: forks that rejoin, dead ends, platforms you can't reach, and dash-only shortcuts. See [[level-generation]].

## Open questions (team to decide)
- [x] **"Race":** against the owner's rocket (see above).
- [x] Which animal is the pet? **A dog** (beagle, red collar with a gold name tag).
- [ ] What's the dog's name (and the astronaut's)?
- [ ] How fast does the rocket go: constant, or speeding up per zone?
- [ ] One long climb, or separate levels per zone?
- [ ] What happens on falling: restart level, checkpoint, or just fall down and keep climbing?
- [ ] Extra moves: double jump, wall jump, dash?
- [ ] Target platform(s): PC only, web, Steam/itch?
- [ ] Art direction and who makes the art/audio.

## Scope
First milestone: **one polished level** that feels great to play (movement, camera, one hazard, one enemy, goal).
