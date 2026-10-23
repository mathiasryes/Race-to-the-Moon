---
name: wrap-up
description: Update the docs/ Obsidian vault and CLAUDE.md at the end of a task in Race to the Moon. Use when finishing a feature or fix, or when asked to "update the docs", "log this" or "wrap up".
---

# Wrap up a task

Update only what actually changed. Short and accurate beats long.

1. **System notes.** For each system you touched, update `docs/systems/<system>.md`: what it does, the files involved, key tuning values, and how it connects to other systems. Create the note if missing (copy `docs/templates/system.md`) and link it from `docs/README.md`.
2. **Decisions.** If you chose between real alternatives (a design rule, an architecture approach, a tool), add `docs/decisions/NNNN-short-title.md` from `docs/templates/decision.md`. Use the next number.
3. **Devlog.** Append 1-3 bullet points to today's `docs/devlog/YYYY-MM-DD.md` (create it if needed): what changed and who/which branch.
4. **Design doc.** If gameplay rules changed, update `docs/design/game-design.md`.
5. **CLAUDE.md.** Only edit if a rule, command or folder changed, or if you hit a repeated mistake worth a rule. Keep it short.
6. Use Obsidian `[[wiki links]]` between notes (e.g. `[[player-movement]]`).
