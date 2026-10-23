---
name: new-feature
description: Implement a gameplay feature end to end in Race to the Moon - branch, build, test, document, open a PR. Use when asked to add or change a mechanic, enemy, hazard, level piece or UI element.
---

# New feature workflow

1. **Understand it.** Read `CLAUDE.md` and any related note in `docs/systems/` and `docs/design/`. If the request leaves a gameplay choice open (numbers, feel, rules), ask one short question instead of guessing.
2. **Branch.** `git switch main && git pull`, then `git switch -c feature/<short-name>`.
3. **Build it small.**
   - Make a new scene + script in the right feature folder rather than growing an existing big scene.
   - Expose tuning values as `@export` properties with sensible defaults and a `##` doc comment.
   - Keep pure logic (math, timers, rules) in plain functions so it can be tested without running the game.
4. **Test it.** Add `test_*` methods in `tests/test_<feature>.gd` (extend `res://tests/framework/test_case.gd`). Run `tools/check.ps1` (or `tools/check.sh`) and `godot --headless --path . --quit-after 120`. Fix everything until both are clean.
5. **Document it.** Run the `wrap-up` skill.
6. **Commit and PR.** Small, clear commits. Push and open a PR with `gh pr create`, describing what changed, how to try it in the game, and anything a teammate must do in the editor.
7. Tell the user what to try in the game (which keys, which level) since feel can't be tested headless.
