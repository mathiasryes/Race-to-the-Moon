---
name: run-and-check
description: Import the Godot project, run all tests and a short headless game run, then fix any errors found. Use after editing any .gd, .tscn or .tres file, or when asked to "check", "test" or "verify" the game.
---

# Run and check

1. Find Godot: use `$GODOT` if set, else `godot` on PATH. If neither works, ask the user for the path to their Godot 4.7 executable (on Windows the `_console.exe` variant prints output).
2. Run the checks:
   - Windows: `pwsh tools/check.ps1`
   - macOS/Linux: `tools/check.sh`
3. Run the main scene briefly: `godot --headless --path . --quit-after 120`.
4. Read the output carefully. Treat these as failures to fix: `SCRIPT ERROR`, `Parse Error`, `ERROR:`, failed tests, and warnings about untyped declarations.
5. Fix the cause (not the test) and run again until clean. Report the final test count and anything you could not fix.

Headless runs can't judge how the game *feels*. When feel matters, tell the user exactly what to try in the editor (F5 runs the game, F6 runs the open scene).
