# 0003 – Tiny built-in test runner

**Date:** 2026-10-23 · **Status:** accepted

## Decision
Tests use a ~60-line runner in `tests/framework/` instead of an addon like GUT or gdUnit4.

## Why
No dependency to install or keep updated, and it runs the same way locally and in CI. Enough for testing gameplay logic (movement math, timers, rules).

## Revisit when
We need scene-level tests (simulating input over many frames, signals, mocks). Then switch to gdUnit4 or GUT.
