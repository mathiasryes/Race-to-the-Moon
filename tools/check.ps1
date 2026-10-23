# Imports the project and runs all tests headless. Exit code 0 = everything passed.
# Uses $env:GODOT if set, otherwise "godot" on PATH.
$godot = if ($env:GODOT) { $env:GODOT } else { "godot" }
$root = Split-Path -Parent $PSScriptRoot

& $godot --headless --path $root --import
if ($LASTEXITCODE -ne 0) { Write-Error "Import failed"; exit 1 }

& $godot --headless --path $root -s res://tests/framework/run_tests.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $godot --headless --path $root -s res://tests/framework/race_scenarios.gd
exit $LASTEXITCODE
