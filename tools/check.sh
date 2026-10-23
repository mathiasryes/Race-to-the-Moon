#!/usr/bin/env bash
# Imports the project and runs all tests headless. Exit code 0 = everything passed.
# Uses $GODOT if set, otherwise "godot" on PATH.
set -euo pipefail
GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

"$GODOT" --headless --path "$ROOT" --import
"$GODOT" --headless --path "$ROOT" -s res://tests/framework/run_tests.gd
"$GODOT" --headless --path "$ROOT" -s res://tests/framework/race_scenarios.gd
"$GODOT" --headless --path "$ROOT" -s res://tests/framework/sound_scenarios.gd
