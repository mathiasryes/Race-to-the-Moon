# 0005 – Procedural levels, slower pace, higher jumps

**Date:** 2026-10-23 · **Status:** accepted

## Context
Hand-placed platforms don't scale to a long climb through five regions, and every run felt the same.

## Decision
- Generate the platforms at startup (`LevelGenerator`), with a guaranteed reachable main route plus optional side platforms.
- Retune for more platform options: jump height 56 → 88 px, peak/fall time 0.38/0.30 → 0.45/0.36 s, run speed 140 → 115 px/s.
- Slow the rocket to match: cruise 55 → 40 px/s, acceleration 3 → 4 s.

## Why
Higher jumps make more platforms reachable from each spot, so the generator can offer real choices. A slower dog and rocket keep the race readable over a ~1 minute climb.

## Consequences
- Platform gaps are derived from the jump settings, so retuning the jump changes every level. Tests check generated gaps against real jump physics.
- `level_seed` = 0 gives a new level each run. Set a seed for repeatable levels (tests and screenshots use fixed seeds).
