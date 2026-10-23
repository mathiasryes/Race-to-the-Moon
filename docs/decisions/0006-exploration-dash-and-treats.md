# 0006 – Exploration levels, double jump, dash and treats

**Date:** 2026-10-23 · **Status:** accepted

## Context
Playtest feedback: the map felt empty and the route felt forced, "like a path" instead of finding your own way up.

## Decision
- **Levels:** denser platforms with forks that rejoin, dead ends, unreachable platforms and dash-only spots. The guaranteed route needs jump + double jump only, never the dash.
- **Double jump:** one air jump, restored on landing.
- **Dash:** horizontal burst, **one charge at the start, not restored on landing**. **Dog treats** refill it.

## Why
- Dead ends and unreachable platforms make the level read as a place to explore instead of a corridor.
- A scarce dash turns treats into decisions: detour for a treat (and lose time to the rocket) or keep climbing.
- Keeping the dash off the required route means a player can never get stuck after spending it.

## Consequences
- The generator's reach model now covers the double jump and the dash; tests check reachability with a graph search.
- Treat placement and dash-only spots are tuning knobs for difficulty and reward.
