# Race to the Moon

A 2D vertical platformer made in Godot 4.7 by a team of three.

## Getting started (each teammate)
1. Install **Git** (with Git LFS, included in Git for Windows), **Godot 4.7.x** (standard build, not .NET), and **VS Code**.
   On Windows: `winget install GodotEngine.GodotEngine GitHub.cli Microsoft.VisualStudioCode`
2. Run `git lfs install` once, then clone the repo.
3. Open Godot → **Import** → select `project.godot`. Press **F5** to play.
4. Optional: open `docs/` in Obsidian as a vault.

## Controls
Move: A/D or arrow keys · Jump: Space / W / ↑ (hold to jump higher) · Restart: R / Enter · Gamepad supported.

Beat the rocket to the moon: if it leaves the top of the screen, you lose.

## Making art or sound?
Read [docs/briefs/art-and-sound-brief.md](docs/briefs/art-and-sound-brief.md): specs, file names and how to hand work over. Sounds and art are picked up automatically when dropped into `assets/` with the right names.

## Editor setup (VS Code)
Install the recommended extensions when VS Code asks (godot-tools, EditorConfig, Claude Code).
In Godot: *Editor Settings → Text Editor → External* → enable **Use External Editor**, set *Exec Path* to VS Code and *Exec Flags* to `{project} --goto {file}:{line}:{col}`.
Keep the Godot editor open while coding: godot-tools uses it for autocompletion.

## Working together
- One branch per feature: `feature/short-name`. Open a pull request to `main`; another teammate reviews.
- Talk before editing the same scene as someone else. Godot scenes are text, but merge conflicts in them are painful.
- CI runs tests on every pull request and builds a Windows version on every merge to `main` (download it from the **Actions** tab).
- Run checks locally: `pwsh tools/check.ps1` (Windows) or `tools/check.sh` (macOS/Linux). Set `GODOT` to your Godot executable if `godot` isn't on your PATH.

## Working with AI (Claude Code)
- `CLAUDE.md` holds the shared rules every AI session follows. Personal preferences go in `CLAUDE.local.md` (not committed).
- Shared skills in `.claude/skills/`: `new-feature`, `run-and-check`, `wrap-up`.
- The AI updates `docs/` at the end of each task. Review those changes in PRs like code.

## Layout
`player/` · `levels/` · `ui/` · `autoload/` · `assets/` (Git LFS) · `tests/` · `docs/` (Obsidian vault) · `tools/`
