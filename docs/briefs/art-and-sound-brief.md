# Art & sound brief

For whoever makes the art and sound for **Race to the Moon**. Everything you need should be on this page. Ask Mathias if anything is unclear.

## The game in 30 seconds
- A 2D **vertical pixel-art platformer**. You play an astronaut's pet dog. The rocket launches without you, so you **race it to the moon by climbing**.
- The rocket flies in the background. If it leaves the top of the screen, you lose. Reach the moon first to win.
- The climb passes through **five regions**: launch site → sky → upper atmosphere → space → moon. Platforms, background and props change per region.
- The dog can **double jump** and **dash** once. The dash only comes back by eating a **dog treat** floating in the level.
- Tone: cheerful, slightly silly, arcade-y. Short runs (about a minute), instant restarts.

![[mockups.png]]

## Getting set up
1. Get invited to the GitHub repo (ask Mathias): `mathiasryes/Race-to-the-Moon`.
2. Install **Git** (with Git LFS) and **Godot 4.7.x** (standard build, not .NET). Run `git lfs install` once, then clone the repo.
3. Open Godot → Import → `project.godot` → press **F5** to play.
4. Optional: open the `docs/` folder in **Obsidian** to browse these notes.

You don't need to write code. **Files with the right name in the right folder are picked up automatically** (details below).

---

## Art

### Technical rules
| Rule | Value |
|---|---|
| Game resolution | **640x360**, scaled up by whole numbers (sharp pixels) |
| Tile size | **16x16 px** |
| Format | **PNG with transparency** (RGBA), no anti-aliasing / soft edges |
| Palette | 36 colours: `docs/art/palette.png`, or import `docs/art/palette.gpl` into Aseprite / GIMP / Krita. Extra colours are fine if they fit the look |
| Outlines | 1 px, dark `#181425`, around characters, platforms and props (background layers can skip them) |
| Light | from the **top-left** |
| Sprite sheets | frames side by side in **one row**, all frames the same size |

### Replacing existing art (the easy way)
All current art is **placeholder art drawn by a script**. To replace any of it:
1. Draw your version at the **same size and frame layout** (see the table).
2. Save it over the old file with the **same name**, e.g. `assets/art/player/dog.png`.
3. Press F5. It's in the game.
4. Tell the coders which files are now hand-made. They remove them from the generator script (`tools/art/generate_art.py`) so it never overwrites your work.

Different size or frame count? That's fine too, just mention it in your pull request and the code gets adjusted.

### Current assets
Previews: `docs/art/asset-sheet.png` (every sprite at 2×) and `docs/art/mockups.png` (how they look together).

| File (in `assets/art/`) | Size | Notes |
|---|---|---|
| `player/dog.png` | 8 frames × 24x24 | **idle 1-2, run 3-6, jump 7, fall 8**. Faces **right** (the game mirrors it for left). Feet touch the bottom row. The hitbox is ~14x12 px at the bottom centre, so keep the body around there |
| `rocket/rocket.png` | 48x112 | the owner is visible in the window. Nozzle at the bottom centre |
| `rocket/flame.png` | 3 frames × 20x34 | looping engine flame, attaches below the nozzle |
| `rocket/smoke.png` | 3 frames × 16x16 | launch smoke puffs, small → large |
| `tiles/platforms.png` | 64x112 atlas | **one row per style**: grass, launch pad, cloud, girder, solar panel, asteroid, moon rock. **Columns: left end, middle (must tile seamlessly), right end, single-tile platform**. The walkable surface is the top 1-2 px of each 16x16 tile |
| `tiles/dirt_fill.png` | 16x16 | ground under the grass, tiles seamlessly |
| `backgrounds/sky_gradient.png` | 16x1440 | sky from Earth (bottom) to space (top). Repeats sideways |
| `backgrounds/stars_far.png`, `stars_near.png` | 320x180 | must tile in all directions (two layers that scroll at different speeds) |
| `backgrounds/earth_skyline.png` | 640x180 | mountains/hills/trees at the launch site |
| `backgrounds/earth_horizon.png` | 640x150 | curved Earth seen from space |
| `props/launch_tower.png` | 40x168 | gantry next to the rocket, arms reaching right |
| `props/cloud_big`, `cloud_medium`, `cloud_small` | 96x40, 64x28, 40x20 | background clouds |
| `props/airplane`, `hot_air_balloon` | 36x14, 24x32 | sky props |
| `props/bird.png` | 2 frames × 13x10 | flapping |
| `props/satellite`, `spaceship` | 44x22, 40x18 | upper atmosphere / space |
| `props/ufo.png` | 2 frames × 34x18 | blinking lights |
| `props/asteroid_small/medium/large` | 16, 24, 36 px | space props |
| `props/planet_ringed/red/gas/ice` | various | space props |
| `props/moon.png` | 132x132 | the goal at the top |
| `pickups/treat.png` | 4 frames × 14x10 | **dog treat** (bone-shaped biscuit) floating in the level; eating one refills the dash. Frame 1 plain (shown longest), 2-3 a glint sliding across, 4 a sparkle. The game bobs it up and down and pops it when eaten, so draw it still and centred |
| `ui/dash_icon.png` | 2 frames × 12x12 | dash indicator in the top-left corner (paw print): frame 1 = dash ready, frame 2 = used up (dim). One icon per dash |

### Changing the animal
The team may swap the dog for another animal. Keep the same `player/dog.png` layout (8 frames of 24x24, same order, facing right), or tell the coders the new layout. The file can keep its name or be renamed, just say so.

### Art we don't have yet (wishlist, roughly by priority)
1. **Better versions of the dog and rocket**: the stars of the show.
2. **Movement effects** (3-4 frames, ~16x16): landing dust / jump puff, a little air puff under the dog for the **double jump**, a speed trail or streaks for the **dash**, crumbs or sparkles when a **treat** is eaten. A dash pose for the dog (ears back, stretched out) would also help.
3. **Obstacles per region** (design not final yet): birds (sky), satellites/space junk (upper atmosphere), asteroids and a UFO (space). 2-4 frame animations.
4. **Title screen / logo** "Race to the Moon".
5. **UI**: a pixel font (or pick a free one), countdown numbers, warning icon, win/lose screen art, a nicer dash icon.
6. **Region transitions**: richer clouds layer, aurora or atmosphere glow between sky and space.

---

## Sound

### How it works
Drop files into these folders with **exactly these names**. They play automatically, no code needed. Missing files are skipped, so add them one at a time.

| Folder | Formats | Used for |
|---|---|---|
| `assets/audio/sfx/` | `.wav` (preferred) or `.ogg` | short one-shot effects |
| `assets/audio/loops/` | `.ogg` or `.wav` | sounds that loop while something lasts |
| `assets/audio/music/` | `.ogg`, `.mp3` or `.wav` | music, loops automatically |

**Placeholder bleeps** fill in any sound that isn't made yet, so you can hear where each sound goes. Replace them with your own files (same name; if you switch to `.ogg`, delete the `.wav`). The placeholder script never overwrites existing files.

### Sound list
**Status:** ✅ = real sound in the game (first delivery, 2026-10-23) · 🔲 = still a placeholder.

| Name | Folder | When it plays | Notes | Status |
|---|---|---|---|---|
| `jump` | sfx | the dog jumps | very frequent: short (< 0.2 s), light. Pitch varies slightly each time automatically | ✅ |
| `land_grass` | sfx | the dog lands on grass (and anything without its own sound) | very frequent: soft and short | ✅ |
| `land_metal` | sfx | lands on a launch pad, girder or solar panel | short clank | ✅ |
| `land_cloud` | sfx | lands on a cloud | soft puff | ✅ |
| `land_rock` | sfx | lands on an asteroid or moon rock | short crunch | ✅ |
| `land_heavy` | sfx | lands after a long fall (more than ~160 px), any surface | bigger thud | ✅ |
| `double_jump` | sfx | the dog jumps again in mid-air | like `jump` but higher/lighter so the two are easy to tell apart; short (< 0.15 s) | ✅ |
| `dash` | sfx | the dog dashes (any of 8 directions) | quick whoosh/swish, ~0.2-0.3 s | ✅ |
| `treat` | sfx | the dog eats a treat (dash refilled) | happy, rewarding chime or crunch, < 0.3 s (delivered as `pickup_snack.wav`) | ✅ |
| `woof` | sfx | the dog barks just after liftoff, as the rocket leaves without it | short bark | ✅ |
| `countdown_beep` | sfx | 3, 2, 1 before liftoff | one beep per second | 🔲 |
| `liftoff` | sfx | rocket ignites | big moment: rumble/whoosh, 1-4 s | ✅ |
| `rocket_engine` | loops | the whole time the rocket flies | must loop **seamlessly**; steady rumble, not too loud (plays for a minute) | ✅ |
| `warning` | sfx | the rocket starts getting away | short alert, plays once when the warning appears | 🔲 |
| `warning_alarm` | loops | while the warning shows | seamless loop. The game makes it **louder the closer** the rocket is to escaping | 🔲 |
| `win` | sfx | reached the moon first | happy jingle, 1-4 s | ✅ |
| `lose` | sfx | the rocket escaped | "aww" jingle, 1-3 s | ✅ |
| `below_atmosphere` | music | from the launch pad up through the atmosphere (first 60% of the climb) | "Stellar Ascent", loops; `.mp3` is fine | ✅ |
| `above_atmosphere` | music | once in space (last 40%), crossfades in over ~2 s | "Vector Ascent", loops; `.mp3` is fine | ✅ |

Ideas for later (tell the coders and they'll add the hooks): music per region (launch / sky / space), menu music, UI clicks, obstacle hits, more barks or whines (e.g. on losing), ambient wind in the sky, quiet space ambience.

### Audio specs
- **44.1 kHz**, 16-bit. Mono is fine for effects, stereo for music.
- Trim silence at the start of effects so they feel instant.
- Peak around **-1 dBFS**; keep effects at similar loudness to each other.
- Loops must loop **without a click**: start and end at matching points.
- Overall balance is done in Godot's **Audio** tab (bottom panel), which has **Music** and **SFX** volume sliders. Music starts at -6 dB.

---

## Handing work over
- **Best:** make a branch (e.g. `art/dog-redesign` or `sound/first-pass`), add your files, open a pull request, and list what changed (and any size/layout changes).
- **Also fine:** send the files to Mathias, who will get them integrated.
- Big source files (`.aseprite`, `.psd`, project files) can go in the repo too. Git LFS handles them. Put them next to the exports or in a `source/` subfolder.

## Related notes
[[art-pipeline]] · [[game-design]] · [[rocket-race]] · [[sound-system]]
