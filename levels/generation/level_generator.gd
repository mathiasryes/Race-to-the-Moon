class_name LevelGenerator
extends Node2D
## Builds the climb at startup: platforms from the ground up to the moon, styled by height region,
## plus dog treats and background props. Moves the goal and moon to the top.
## The level is meant to feel like a place you find your way up, not a corridor:
## a guaranteed route (jump + double jump, never the dash; about half its steps need the double jump),
## forks that split and rejoin, dead ends, a few extra stepping stones, platforms you can't reach (even with
## an upward dash), and dash-only ledges holding treats (some need a sideways dash, some an upward one).
## All distances come from the player's jump settings, so retuning the jump keeps every level beatable.

enum Region { LAUNCH, SKY, UPPER_ATMOSPHERE, SPACE, MOON }
## How the player gets from one platform to the next. Each move can do everything the one before it can.
enum Move { SINGLE_JUMP, DOUBLE_JUMP, DASH }

## Height (fraction of level_height) where each Region starts.
const REGION_STARTS: Array[float] = [0.0, 0.08, 0.4, 0.6, 0.93]
## Platform styles each Region picks from (repeat a style to make it more common).
const REGION_STYLES: Array = [
	[Platform.Zone.LAUNCHPAD, Platform.Zone.GRASS],
	[Platform.Zone.CLOUD],
	[Platform.Zone.GIRDER, Platform.Zone.SOLAR],
	[Platform.Zone.ASTEROID, Platform.Zone.ASTEROID, Platform.Zone.SOLAR],
	[Platform.Zone.MOON],
]
## Min/max platform width in tiles per Region.
const REGION_WIDTHS: Array[Vector2i] = [Vector2i(3, 5), Vector2i(2, 5), Vector2i(2, 4), Vector2i(2, 4), Vector2i(3, 5)]
## Background props per Region (file names in assets/art/props/).
const REGION_DECOR: Array = [
	[],
	["cloud_big", "cloud_medium", "cloud_small", "cloud_small", "hot_air_balloon", "airplane"],
	["satellite", "cloud_small", "spaceship"],
	["planet_ringed", "planet_red", "planet_gas", "planet_ice", "asteroid_small", "asteroid_medium",
		"asteroid_large", "ufo", "spaceship", "satellite"],
	["asteroid_small"],
]

const PLATFORM_SCENE: PackedScene = preload("res://levels/blocks/platform.tscn")
const TREAT_SCENE: PackedScene = preload("res://levels/pickups/treat.tscn")
const TILE: float = 16.0
## Platform centres stay inside the side walls by this much.
const HALF_WIDTH: float = 304.0
## The floor in level_01 (40 tiles wide, top at y = 0).
const FLOOR_TILES: int = 40

# Reach
## Only this fraction of the jump height (single, or jump + double jump) is used for vertical gaps.
const RISE_FRACTION: float = 0.8
## Only this fraction of the possible horizontal jump reach is used, leaving room for imperfect jumps.
const REACH_SAFETY: float = 0.75
## Fraction of the dash distance (and the small rise after an upward dash) counted on top of the jump reach.
const DASH_SAFETY: float = 0.9
## Moves to a lower platform are only counted down to this drop (anything lower is "falling back").
const DROP_LIMIT: float = 64.0
## Dash directions the generator plans with (Godot axes: -y is up). The dash is 8-directional and
## left/right mirror each other, so sideways, diagonally up and straight up cover every useful case.
const DASH_SIDE: Vector2 = Vector2(1.0, 0.0)
const DASH_DIAGONAL: Vector2 = Vector2(0.70710678, -0.70710678)
const DASH_UP: Vector2 = Vector2(0.0, -1.0)
const DASH_DIRECTIONS: Array[Vector2] = [DASH_SIDE, DASH_DIAGONAL, DASH_UP]
## Upward share of the dash checked by the generous "could anyone ever get there" rule (0 = sideways, 1 = up).
const EVER_DASH_SAMPLES: int = 10
## The generous rule lets the fall be broken up this many times (the double jump and the dash both
## stop a fall and start a new one, and a fall in pieces lasts longer than one long fall).
const EVER_FALL_PIECES: int = 3

# Spacing
## Platforms that overlap sideways are at least this far apart vertically (the dog is ~16 px tall).
const MIN_GAP_Y: float = 32.0
## Platforms at similar heights keep at least this much space between their edges.
const MIN_GAP_X: float = 16.0
const TOP_PLATFORM_TILES: int = 6
## Nothing but the moon platform within this distance of the top.
const TOP_CLEARANCE: float = 48.0

# Main route
## Chance that a step of the route is too high for a single jump (needs the double jump).
const DOUBLE_STEP_CHANCE: float = 0.5
## Double-jump steps rise at least this much more than a full single jump.
const DOUBLE_STEP_EXTRA: float = 8.0
## Single-jump steps of the route rise at least this much (up to RISE_FRACTION of the jump height).
const SINGLE_STEP_MIN: float = 44.0
## Each step moves sideways by at least this fraction of the reachable distance (unless the target is closer).
const MIN_SIDE_STEP: float = 0.85
## The route heads for a target on the other side this far out from the centre...
## (Must stay reachable for the widest platform, whose centre can't go past HALF_WIDTH - 48.)
const SIDE_TARGET_RANGE: Vector2 = Vector2(170.0, 250.0)
## ...or, with this chance, for a target near the middle.
const MIDDLE_TARGET_CHANCE: float = 0.15

# Exploration
## Climb between forks (alternative paths that split off the route and rejoin it).
const FORK_SPACING: Vector2 = Vector2(600.0, 1100.0)
## A fork bypasses this many route steps.
const FORK_STEPS: Vector2i = Vector2i(3, 5)
## Average rise per hop on a fork.
const FORK_HOP: float = 56.0
## A fork must get at least this far (sideways) from the route to count as a different path.
const FORK_MIN_SEPARATION: float = 100.0
## Climb between attempts to add a dead end (a short side chain that leads nowhere).
const DEAD_END_SPACING: Vector2 = Vector2(140.0, 240.0)
## Platforms per dead-end chain.
const DEAD_END_LENGTH: Vector2i = Vector2i(1, 2)
## Unreachable platforms per 1000 px of climb (placed only where nothing can reach them).
const UNREACHABLE_PER_1000: float = 2.0
## More unreachable platforms per 1000 px added at the end, which fills the emptier spots.
const LATE_UNREACHABLE_PER_1000: float = 1.0
## Grid of spots tried for unreachable platforms: columns across the level, one row every this many pixels.
const UNREACHABLE_COLUMNS: int = 24
const UNREACHABLE_ROW_STEP: float = 16.0
## Extra distance (and drop) beyond the most generous dash reach that keeps unreachable platforms out of reach.
const UNREACHABLE_MARGIN: float = 24.0
## Dash-only ledges sit at least this much beyond the no-dash reach from every platform.
const DASH_ONLY_MARGIN: float = 12.0
## Chance a new dash-only ledge needs an upward or diagonal dash (otherwise a sideways one). The generator
## also evens them out so a level with two or more ledges has both kinds when there's room.
const UP_DASH_LEDGE_CHANCE: float = 0.6
## Random placements tried per dash-only ledge (and kind).
const DASH_LEDGE_TRIES: int = 150

# Treats
## Climb between treats.
const TREAT_SPACING: Vector2 = Vector2(300.0, 500.0)
## Treat centre above the platform's top surface.
const TREAT_LIFT: float = 12.0
## Chance a treat goes on the main route instead of somewhere off it.
const MAIN_TREAT_CHANCE: float = 0.15
## Chance a treat goes on a new dash-only ledge (otherwise a dead end, if one is near).
const DASH_TREAT_CHANCE: float = 0.55
## Every level gets at least this many dash-only ledges (if there's room).
const MIN_DASH_LEDGES: int = 2
## Treats left over after the dead ends are built go on upward-dash ledges above dead ends until a level has
## this many upward-dash ledges (if there's room).
const MIN_UP_DASH_LEDGES: int = 2

## Rows of this height bucket platforms for fast neighbour lookups.
const ROW_HEIGHT: float = 64.0

@export var player: Player
## Moved onto the top platform.
@export var goal: Node2D
## Moved above the top platform.
@export var moon: Node2D
## Its climb_height is set to level_height so the sky turns to space on the way up.
@export var background: AltitudeBackground

## 0 = a new level every run. Any other number always builds the same level.
@export var level_seed: int = 0
@export var level_height: float = 3200.0
## Extra stepping stones per 100 px of climb (more = more ways up, and an easier, fuller level).
@export_range(0.0, 3.0) var extra_density: float = 0.8
## Average vertical distance between background props.
@export var decor_spacing: float = 140.0

## Centres of the guaranteed route, bottom to top (the moon platform is last).
var main_path: Array[Vector2] = []


## The parts of the player's movement that decide how far a jump reaches.
class Jump:
	var height: float
	var time_to_peak: float
	var time_to_fall: float
	var run_speed: float
	var air_acceleration: float
	var max_fall_speed: float = INF
	var double_jump_height: float = 0.0
	var dash_distance: float = 0.0
	## max_ever_gap by whole-pixel rise, filled in on first use (see LevelGenerator.ever_gap).
	var ever_gaps: PackedFloat32Array = PackedFloat32Array()

	static func from_player(p: Player) -> Jump:
		var jump := Jump.new()
		jump.height = p.jump_height
		jump.time_to_peak = p.jump_time_to_peak
		jump.time_to_fall = p.jump_time_to_fall
		jump.run_speed = p.run_speed
		jump.air_acceleration = p.air_acceleration
		jump.max_fall_speed = p.max_fall_speed
		jump.double_jump_height = p.double_jump_height if p.air_jumps > 0 else 0.0
		jump.dash_distance = p.get_dash_distance() if p.max_dash_charges > 0 else 0.0
		return jump

	func rise_gravity() -> float:
		return 2.0 * height / (time_to_peak * time_to_peak)

	func fall_gravity() -> float:
		return 2.0 * height / (time_to_fall * time_to_fall)

	## Seconds to fall `distance` pixels from rest, with the fall speed cap.
	func fall_time(distance: float) -> float:
		if distance <= 0.0:
			return 0.0
		var gravity: float = fall_gravity()
		var cap_distance: float = max_fall_speed * max_fall_speed / (2.0 * gravity)
		if distance <= cap_distance:
			return sqrt(2.0 * distance / gravity)
		return max_fall_speed / gravity + (distance - cap_distance) / max_fall_speed

	## Seconds the double jump rises before it peaks.
	func double_jump_rise_time() -> float:
		return sqrt(2.0 * double_jump_height / rise_gravity())


## A generated level. `platforms` and `treats` are what gets built; the rest is bookkeeping.
class Layout:
	## Every platform: { x, y (top surface), width (tiles), zone (Platform.Zone), main (bool), kind (String) }.
	## kind: "main" (guaranteed route), "fork" (alternative path), "dead_end", "extra" (stepping stone),
	## "dash" (dash-only ledge) or "unreachable".
	var platforms: Array[Dictionary] = []
	## Treat centres.
	var treats: Array[Vector2] = []
	## Each fork as (index in `main` where it splits off, index in `main` where it rejoins).
	var forks: Array[Vector2i] = []
	## The guaranteed route, bottom to top (the moon platform is last).
	var main: Array[Dictionary] = []
	var height: float
	var jump: Jump
	## The floor plus every platform the player can reach without the dash.
	var reachable: Array[Dictionary] = []
	## Tips of dead ends: reachable, but nothing higher is reachable from them.
	var dead_ends: Array[Dictionary] = []
	var unreachable: Array[Dictionary] = []
	var dash_ledges: Array[Dictionary] = []
	## The dash-only ledges planned for an upward or diagonal dash (the rest are planned for a sideways one).
	var up_dash_ledges: Array[Dictionary] = []
	## Row index -> platforms in that row (includes the floor).
	var rows: Dictionary = {}


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	if level_seed != 0:
		rng.seed = level_seed
	else:
		rng.randomize()

	var layout: Layout = generate_layout(rng, level_height, Jump.from_player(player), extra_density)
	for entry: Dictionary in layout.platforms:
		_spawn_platform(entry)
	for entry: Dictionary in layout.main:
		main_path.append(Vector2(entry["x"], entry["y"]))
	for treat_position: Vector2 in layout.treats:
		var treat: Node2D = TREAT_SCENE.instantiate()
		treat.position = treat_position
		add_child(treat)
	_spawn_decor(rng)

	var top: Vector2 = main_path[-1]
	if goal:
		goal.global_position = top
	if moon:
		moon.global_position = top + Vector2(0, -110)
	if background:
		background.climb_height = level_height


## Builds the whole level. Same rng seed = same level.
static func generate_layout(rng: RandomNumberGenerator, height: float, jump: Jump, density: float = 0.8) -> Layout:
	var layout := Layout.new()
	layout.height = height
	layout.jump = jump
	var floor_platform: Dictionary = {
		"x": 0.0, "y": 0.0, "width": FLOOR_TILES, "zone": Platform.Zone.GRASS, "main": false, "kind": "floor",
	}
	_index(layout, floor_platform)
	layout.reachable.append(floor_platform)

	# Order matters: things that must stay out of reach (unreachable platforms, dash-only ledges, dead ends)
	# claim their space first, and everything added later checks it doesn't spoil them.
	# Forks come right after the route: with the 8-way dash, unreachable platforms need so much room that
	# they would otherwise crowd out the forks.
	_build_main_route(layout, rng)
	_build_forks(layout, rng)
	_build_unreachable(layout, rng, roundi(height / 1000.0 * UNREACHABLE_PER_1000))
	var treat_slots: Array[Vector2] = _plan_treats(layout, rng)
	treat_slots = _place_dash_treats(layout, rng, treat_slots)
	_build_dead_ends(layout, rng)
	_place_other_treats(layout, rng, treat_slots)
	_build_extras(layout, rng, density)
	# More unreachable scenery: by now only the emptier spots are still out of reach, so these fill them.
	_build_unreachable(layout, rng, layout.unreachable.size() + roundi(height / 1000.0 * LATE_UNREACHABLE_PER_1000))
	layout.treats.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y > b.y)
	return layout


# --- Reach ------------------------------------------------------------------------------------------

## Highest rise (pixels) the generator uses for a move.
static func max_rise(move: Move, jump: Jump) -> float:
	match move:
		Move.SINGLE_JUMP:
			return jump.height * RISE_FRACTION
		Move.DOUBLE_JUMP:
			return (jump.height + jump.double_jump_height) * RISE_FRACTION
	return max_dash_rise(DASH_UP, jump)


## How far the dog keeps rising after a dash ends: the dash leaves it moving at run_speed along the dash,
## so `up` (the upward share of the dash direction, 0-1) of that speed coasts up against jump gravity.
static func post_dash_rise(up: float, jump: Jump) -> float:
	var speed: float = up * jump.run_speed
	return speed * speed / (2.0 * jump.rise_gravity())


## Height a straight-up dash adds on top of a jump: the dash distance plus the coast after it
## (dash_distance + run_speedÂ² / (2 * jump gravity)).
static func dash_rise(jump: Jump) -> float:
	return jump.dash_distance + post_dash_rise(1.0, jump)


## Highest rise the generator uses for jump + double jump + one dash in `direction` (unit vector, -y up).
static func max_dash_rise(direction: Vector2, jump: Jump) -> float:
	if jump.dash_distance <= 0.0:
		return max_rise(Move.DOUBLE_JUMP, jump)
	var up: float = maxf(0.0, -direction.y)
	return max_rise(Move.DOUBLE_JUMP, jump) + (jump.dash_distance * up + post_dash_rise(up, jump)) * DASH_SAFETY


## Seconds in the air for a jump from standstill that comes down `rise` pixels higher (negative = lower).
## With `double_jump` the second jump is used right at the top of the first. -1 if it can't get that high.
static func air_time(rise: float, jump: Jump, double_jump: bool) -> float:
	var peak: float = jump.height
	var time: float = jump.time_to_peak
	if double_jump:
		peak += jump.double_jump_height
		time += jump.double_jump_rise_time()
	if rise > peak:
		return -1.0
	return time + jump.fall_time(peak - rise)


## Largest horizontal gap between platform edges that a single jump rising `rise` pixels can safely cross.
## Assumes the player starts the jump standing still and holds the direction the whole time.
static func max_edge_gap(rise: float, jump: Jump) -> float:
	return _safe_gap(air_time(rise, jump, false), jump)


## Same as max_edge_gap, but with the double jump used at the top of the first jump.
static func max_double_jump_gap(rise: float, jump: Jump) -> float:
	return _safe_gap(air_time(rise, jump, true), jump)


## Same as max_double_jump_gap, plus one dash in `direction` (unit vector, -y up; only its size sideways
## matters, left and right are the same) at the top of the double jump. -1 if the rise is too high for it.
## The dash covers dash_distance along the direction with no gravity, then the dog coasts up a little
## (post_dash_rise), falls, and has to speed up sideways again from what the dash left it with.
static func max_dash_gap(rise: float, jump: Jump, direction: Vector2 = DASH_SIDE) -> float:
	if rise > max_dash_rise(direction, jump):
		return -1.0
	var up: float = maxf(0.0, -direction.y)
	var side: float = absf(direction.x)
	var gravity: float = jump.rise_gravity()
	var peak: float = jump.height + jump.double_jump_height + jump.dash_distance * up + post_dash_rise(up, jump)
	var time: float = jump.time_to_peak + jump.double_jump_rise_time() + up * jump.run_speed / gravity \
		+ jump.fall_time(peak - rise)
	# After the dash the dog moves sideways at side * run_speed and has to speed up to run_speed again.
	var restart_loss: float = pow(jump.run_speed * (1.0 - side), 2.0) / (2.0 * jump.air_acceleration)
	return maxf(0.0, _safe_gap(time, jump) - restart_loss * REACH_SAFETY + jump.dash_distance * side * DASH_SAFETY)


## Largest gap at `rise` with jump + double jump + one dash in the best of DASH_DIRECTIONS, or -1 if none.
static func best_dash_gap(rise: float, jump: Jump) -> float:
	var best: float = -1.0
	for direction: Vector2 in DASH_DIRECTIONS:
		best = maxf(best, max_dash_gap(rise, jump, direction))
	return best


## Largest gap for `move` at `rise`, or -1 if the rise is too high for that move.
static func max_gap(rise: float, jump: Jump, move: Move) -> float:
	if rise > max_rise(move, jump):
		return -1.0
	match move:
		Move.SINGLE_JUMP:
			return max_edge_gap(rise, jump)
		Move.DOUBLE_JUMP:
			return max_double_jump_gap(rise, jump)
	return best_dash_gap(rise, jump)


static func _safe_gap(time: float, jump: Jump) -> float:
	if time < 0.0:
		return 0.0
	var speed_up_loss: float = jump.run_speed / (2.0 * jump.air_acceleration)  # time lost getting to full speed
	return maxf(0.0, jump.run_speed * (time - speed_up_loss) * REACH_SAFETY)


## Horizontal space between the edges of two platforms (negative when they overlap sideways).
static func edge_gap(a: Dictionary, b: Dictionary) -> float:
	return absf(float(a["x"]) - float(b["x"])) - (int(a["width"]) + int(b["width"])) * TILE / 2.0


## True if the player can get from platform `from` onto platform `to` using `move` (or anything weaker).
## `margin` makes the check more generous (used to keep platforms clearly out of reach).
static func can_reach(from: Dictionary, to: Dictionary, jump: Jump, move: Move, margin: float = 0.0) -> bool:
	var rise: float = float(from["y"]) - float(to["y"])
	var highest: float = max_rise(move, jump)
	if rise > highest + margin or rise < -DROP_LIMIT - margin:
		return false
	return edge_gap(from, to) <= max_gap(minf(rise, highest), jump, move) + margin


## Like can_reach with Move.DASH, but only with a dash in `direction`.
static func can_dash_to(from: Dictionary, to: Dictionary, jump: Jump, direction: Vector2, margin: float = 0.0) -> bool:
	var rise: float = float(from["y"]) - float(to["y"])
	var highest: float = max_dash_rise(direction, jump)
	if rise > highest + margin or rise < -DROP_LIMIT - margin:
		return false
	return edge_gap(from, to) <= max_dash_gap(minf(rise, highest), jump, direction) + margin


## Highest anyone could ever get above a platform: full jump + full double jump + a straight-up dash.
static func highest_ever(jump: Jump) -> float:
	return jump.height + jump.double_jump_height + dash_rise(jump)


## Upper bound on the gap a perfect player could cross at `rise` with jump + double jump + one dash in any
## direction, at any moment. No safety factors, full speed from the start, and the fall broken into
## EVER_FALL_PIECES equal pieces (the double jump and the dash each stop a fall, which buys air time).
## -1 if even that can't get so high.
static func max_ever_gap(rise: float, jump: Jump) -> float:
	var best: float = -1.0
	var gravity: float = jump.rise_gravity()
	for sample: int in EVER_DASH_SAMPLES + 1:
		var up: float = float(sample) / EVER_DASH_SAMPLES
		var peak: float = jump.height + jump.double_jump_height + jump.dash_distance * up + post_dash_rise(up, jump)
		if rise > peak + 0.01:
			continue
		var time: float = jump.time_to_peak + jump.double_jump_rise_time() + up * jump.run_speed / gravity \
			+ EVER_FALL_PIECES * jump.fall_time((peak - rise) / EVER_FALL_PIECES)
		best = maxf(best, jump.run_speed * time + jump.dash_distance * sqrt(1.0 - up * up))
	return best


## Generous check used for unreachable platforms: true unless `to` is clearly out of reach from `from`,
## even for a perfect player with jump + double jump + a dash in any of the 8 directions (up included).
static func could_ever_reach(from: Dictionary, to: Dictionary, jump: Jump) -> bool:
	var rise: float = float(from["y"]) - float(to["y"])
	if rise > highest_ever(jump) + UNREACHABLE_MARGIN / 3.0:
		return false
	if rise < -DROP_LIMIT - UNREACHABLE_MARGIN:
		return false
	return edge_gap(from, to) <= ever_gap(rise, jump) + UNREACHABLE_MARGIN


## max_ever_gap, looked up by rise rounded down to a whole pixel (a lower rise never allows a smaller gap,
## so rounding down keeps the rule generous). Used for every unreachable check, so it has to be fast.
static func ever_gap(rise: float, jump: Jump) -> float:
	var lowest: int = -ceili(DROP_LIMIT + UNREACHABLE_MARGIN)
	var highest: int = ceili(highest_ever(jump))
	if jump.ever_gaps.is_empty():
		for whole: int in range(lowest, highest + 1):
			jump.ever_gaps.append(max_ever_gap(minf(float(whole), highest_ever(jump)), jump))
	var index: int = clampi(floori(rise), lowest, highest) - lowest
	return jump.ever_gaps[index]


# --- Main route -------------------------------------------------------------------------------------

static func _build_main_route(layout: Layout, rng: RandomNumberGenerator) -> void:
	var jump: Jump = layout.jump
	var height: float = layout.height
	var single_rise: float = max_rise(Move.SINGLE_JUMP, jump)
	var double_rise: float = max_rise(Move.DOUBLE_JUMP, jump)
	var double_min: float = jump.height + DOUBLE_STEP_EXTRA
	var previous: Dictionary = layout.reachable[0]  # the floor
	var y: float = 0.0
	# The route sweeps from side to side; `last_side` is the side it most recently headed for.
	var last_side: float = -1.0 if rng.randf() < 0.5 else 1.0
	var target: float = next_target(rng, last_side, false)
	var steps: int = 0
	var doubles: int = 0
	while height + y > single_rise:
		if absf(target - float(previous["x"])) < 24.0:
			var was_middle: bool = absf(target) <= 60.0
			if not was_middle:
				last_side = signf(target)
			target = next_target(rng, last_side, not was_middle)
		var remaining: float = height + y
		# Lean towards DOUBLE_STEP_CHANCE: a route that has had few double-jump steps so far gets more.
		var double_chance: float = clampf(DOUBLE_STEP_CHANCE + (DOUBLE_STEP_CHANCE * steps - doubles) * 0.2, 0.1, 0.9)
		var move: Move = Move.SINGLE_JUMP
		if rng.randf() < double_chance and remaining - MIN_GAP_Y >= double_min and double_rise > double_min:
			move = Move.DOUBLE_JUMP
			doubles += 1
		steps += 1
		var rise: float
		if move == Move.DOUBLE_JUMP:
			rise = floorf(rng.randf_range(double_min, minf(double_rise, remaining - MIN_GAP_Y)))
		else:
			var highest: float = minf(single_rise, remaining - MIN_GAP_Y)
			rise = floorf(rng.randf_range(minf(SINGLE_STEP_MIN, highest), highest))
		y -= rise
		var width: int = _random_width(rng, y, height)
		var platform: Dictionary = _new_platform(rng, _pick_x(rng, previous, width, rise, jump, target, move), y,
			width, height, "main")
		_add(layout, platform, true)
		layout.main.append(platform)
		previous = platform

	var top_rise: float = height + y
	var top: Dictionary = {
		"x": _pick_x(rng, previous, TOP_PLATFORM_TILES, top_rise, jump, 0.0, Move.SINGLE_JUMP), "y": -height,
		"width": TOP_PLATFORM_TILES, "zone": Platform.Zone.MOON, "main": true, "kind": "main",
	}
	_add(layout, top, true)
	layout.main.append(top)


## Where the route heads next: usually far out on the side opposite `last_side`, sometimes a stop in the middle.
static func next_target(rng: RandomNumberGenerator, last_side: float, allow_middle: bool) -> float:
	if allow_middle and rng.randf() < MIDDLE_TARGET_CHANCE:
		return roundf(rng.randf_range(-60.0, 60.0))
	return roundf(-last_side * rng.randf_range(SIDE_TARGET_RANGE.x, SIDE_TARGET_RANGE.y))


## Which Region a height (pixels above the ground) belongs to.
static func region_at(height_above_ground: float, height: float) -> int:
	var fraction: float = height_above_ground / height
	for region: int in range(REGION_STARTS.size() - 1, -1, -1):
		if fraction >= REGION_STARTS[region]:
			return region
	return Region.LAUNCH


## Moves sideways from `from` towards `target` by an amount reachable with `move`.
static func _pick_x(rng: RandomNumberGenerator, from: Dictionary, width: int, rise: float, jump: Jump, target: float,
		move: Move) -> float:
	var half: float = width * TILE / 2.0
	var limit: float = HALF_WIDTH - half
	var max_dx: float = maxf(0.0, max_gap(rise, jump, move)) + half + int(from["width"]) * TILE / 2.0
	var to_target: float = target - float(from["x"])
	var step: float = floorf(minf(absf(to_target), rng.randf_range(MIN_SIDE_STEP, 1.0) * max_dx))  # floor: never too far
	return clampf(float(from["x"]) + signf(to_target) * step, -floorf(limit), floorf(limit))


# --- Forks: a second way up that splits off the route and rejoins it ---------------------------------

static func _build_forks(layout: Layout, rng: RandomNumberGenerator) -> void:
	var next_fork_at: float = rng.randf_range(FORK_SPACING.x * 0.5, FORK_SPACING.y * 0.5)
	var i: int = 0
	while i < layout.main.size() - 2:
		var start: Dictionary = layout.main[i]
		if -float(start["y"]) >= next_fork_at:
			var end_index: int = mini(i + 1 + rng.randi_range(FORK_STEPS.x, FORK_STEPS.y), layout.main.size() - 2)
			if end_index - i >= 3 and _try_fork(layout, rng, start, layout.main[end_index]):
				layout.forks.append(Vector2i(i, end_index))
				next_fork_at = -float(layout.main[end_index]["y"]) + rng.randf_range(FORK_SPACING.x, FORK_SPACING.y)
				i = end_index
				continue
		i += 1


## Tries to build a chain of single jumps from `start` to `end` that stays well away from the route.
static func _try_fork(layout: Layout, rng: RandomNumberGenerator, start: Dictionary, end: Dictionary) -> bool:
	var jump: Jump = layout.jump
	var single_rise: float = max_rise(Move.SINGLE_JUMP, jump)
	var total: float = float(start["y"]) - float(end["y"])
	var hops: int = maxi(3, ceili(total / FORK_HOP))
	if total < hops * MIN_GAP_Y:
		return false
	# Conservative sideways distance one hop can always cover (narrowest platforms, highest rise).
	var per_hop: float = max_edge_gap(single_rise, jump) + 2.0 * TILE
	var chain: Array[Dictionary] = []
	var previous: Dictionary = start
	var y: float = float(start["y"])
	var widest: float = 0.0
	for hop: int in range(1, hops):
		var hops_left: int = hops - hop + 1  # including this one
		var remaining: float = y - float(end["y"])
		var low: float = maxf(MIN_GAP_Y, remaining - (hops_left - 1) * single_rise)
		var high: float = minf(single_rise, remaining - (hops_left - 1) * MIN_GAP_Y)
		if low > high:
			return false
		y -= floorf(clampf(remaining / hops_left + rng.randf_range(-12.0, 12.0), low, high))
		var best: Dictionary = {}
		var best_score: float = -1.0
		for attempt: int in 14:
			var width: int = _random_width(rng, y, layout.height)
			var limit: float = HALF_WIDTH - width * TILE / 2.0
			var candidate: Dictionary = _new_platform(rng, roundf(rng.randf_range(-limit, limit)), y, width,
				layout.height, "fork")
			if not can_reach(previous, candidate, jump, Move.SINGLE_JUMP) or not _fits(layout, candidate):
				continue
			if _spoils_secrets(layout, candidate):
				continue
			if hops_left - 1 == 1:
				if not can_reach(candidate, end, jump, Move.DOUBLE_JUMP):
					continue
			elif absf(float(candidate["x"]) - float(end["x"])) > (hops_left - 1) * per_hop:
				continue
			var score: float = _distance_from_route(layout, candidate)
			if score > best_score:
				best = candidate
				best_score = score
		if best.is_empty():
			return false
		widest = maxf(widest, best_score)
		chain.append(best)
		previous = best
	if widest < FORK_MIN_SEPARATION:
		return false
	for platform: Dictionary in chain:
		_add(layout, platform, true)
	return true


## Sideways distance from `platform` to the nearest route platform at a similar height.
static func _distance_from_route(layout: Layout, platform: Dictionary) -> float:
	var nearest: float = 1000.0
	for other: Dictionary in _nearby(layout, float(platform["y"]), 72.0, 72.0):
		if other["kind"] == "main":
			nearest = minf(nearest, absf(float(other["x"]) - float(platform["x"])))
	return nearest


# --- Dead ends: short side chains that lead nowhere --------------------------------------------------

static func _build_dead_ends(layout: Layout, rng: RandomNumberGenerator) -> void:
	var at: float = rng.randf_range(DEAD_END_SPACING.x, DEAD_END_SPACING.y)
	while at < layout.height - 160.0:
		_try_dead_end(layout, rng, at)
		at += rng.randf_range(DEAD_END_SPACING.x, DEAD_END_SPACING.y)


static func _try_dead_end(layout: Layout, rng: RandomNumberGenerator, at: float) -> void:
	var jump: Jump = layout.jump
	var bases: Array[Dictionary] = _reachable_near(layout, at, 80.0)
	if bases.is_empty():
		return
	for attempt: int in 10:
		var base: Dictionary = bases[rng.randi() % bases.size()]
		var length: int = rng.randi_range(DEAD_END_LENGTH.x, DEAD_END_LENGTH.y)
		var side: float = -1.0 if rng.randf() < 0.5 else 1.0
		var chain: Array[Dictionary] = []
		var previous: Dictionary = base
		for step: int in length:
			var rise: float = floorf(rng.randf_range(8.0, 64.0))
			var gap: float = rng.randf_range(MIN_GAP_X, max_edge_gap(rise, jump) * 0.9)
			var y: float = float(previous["y"]) - rise
			var width: int = _random_width(rng, y, layout.height)
			var x: float = roundf(float(previous["x"]) + side * (gap + (int(previous["width"]) + width) * TILE / 2.0))
			var candidate: Dictionary = _new_platform(rng, x, y, width, layout.height, "dead_end")
			if not _fits(layout, candidate, chain) or _spoils_secrets(layout, candidate):
				break
			chain.append(candidate)
			previous = candidate
		# Keep the longest part of the chain whose last platform really leads nowhere.
		while not chain.is_empty() and not _is_dead_end(layout, chain[-1], chain):
			chain.pop_back()
		if chain.is_empty():
			continue
		for platform: Dictionary in chain:
			_add(layout, platform, true)
		layout.dead_ends.append(chain[-1])
		return


## True if nothing higher can be reached from `tip` without the dash (`extra` = platforms not added yet).
static func _is_dead_end(layout: Layout, tip: Dictionary, extra: Array[Dictionary]) -> bool:
	var reach: float = max_rise(Move.DOUBLE_JUMP, layout.jump)
	var others: Array[Dictionary] = _nearby(layout, float(tip["y"]), 0.0, reach)
	others.append_array(extra)
	for other: Dictionary in others:
		if float(other["y"]) < float(tip["y"]) and can_reach(tip, other, layout.jump, Move.DOUBLE_JUMP):
			return false
	return true


## True if a new reachable platform would give an existing dead end a way up.
static func _blocks_dead_end(layout: Layout, platform: Dictionary) -> bool:
	for tip: Dictionary in layout.dead_ends:
		if float(platform["y"]) < float(tip["y"]) and can_reach(tip, platform, layout.jump, Move.DOUBLE_JUMP):
			return true
	return false


# --- Unreachable platforms: scenery you can see but never get to --------------------------------------

## Adds unreachable platforms until there are `wanted`. With the upward dash the reach is big, so free spots
## are rare (mostly on the far side where the route turns); every spot on a coarse grid is tried, in random
## order, instead of hoping random picks find them.
static func _build_unreachable(layout: Layout, rng: RandomNumberGenerator, wanted: int) -> void:
	if layout.unreachable.size() >= wanted:
		return
	var spots: Array[Vector2] = []
	var h: float = ceilf(highest_ever(layout.jump) + UNREACHABLE_MARGIN + 16.0)
	while h < layout.height - 160.0:
		for column: int in UNREACHABLE_COLUMNS:
			spots.append(Vector2(lerpf(-HALF_WIDTH, HALF_WIDTH, (column + 0.5) / UNREACHABLE_COLUMNS), -h))
		h += UNREACHABLE_ROW_STEP
	for i: int in range(spots.size() - 1, 0, -1):  # shuffle with the level's rng (Array.shuffle isn't seeded)
		var j: int = rng.randi_range(0, i)
		var swap: Vector2 = spots[i]
		spots[i] = spots[j]
		spots[j] = swap
	for spot: Vector2 in spots:
		if layout.unreachable.size() >= wanted:
			return
		var width: int = _random_width(rng, spot.y, layout.height)
		var limit: float = floorf(HALF_WIDTH - width * TILE / 2.0)
		var x: float = clampf(roundf(spot.x + rng.randf_range(-12.0, 12.0)), -limit, limit)
		var candidate: Dictionary = _new_platform(rng, x, spot.y, width, layout.height, "unreachable")
		if not _fits(layout, candidate) or _could_be_reached(layout, candidate):
			continue
		_add(layout, candidate, false)
		layout.unreachable.append(candidate)


## True if any platform except other unreachable ones could get onto `platform`, even with a dash.
static func _could_be_reached(layout: Layout, platform: Dictionary) -> bool:
	var jump: Jump = layout.jump
	var below: float = highest_ever(jump) + UNREACHABLE_MARGIN
	for other: Dictionary in _nearby(layout, float(platform["y"]), below, DROP_LIMIT + UNREACHABLE_MARGIN):
		if other["kind"] != "unreachable" and could_ever_reach(other, platform, jump):
			return true
	return false


## True if `platform` would let the player get to an unreachable platform.
static func _touches_unreachable(layout: Layout, platform: Dictionary) -> bool:
	for other: Dictionary in layout.unreachable:
		if could_ever_reach(platform, other, layout.jump):
			return true
	return false


# --- Extra stepping stones: more ways up -------------------------------------------------------------

static func _build_extras(layout: Layout, rng: RandomNumberGenerator, density: float) -> void:
	var jump: Jump = layout.jump
	var wanted: int = roundi(layout.height / 100.0 * density)
	var placed: int = 0
	for attempt: int in wanted * 8:
		if placed >= wanted:
			return
		# Fill the emptiest stretches first: of a few random heights, take the one with the fewest platforms
		# around it, then a reachable platform near it.
		var at: float = rng.randf_range(0.0, layout.height)
		var fewest: int = _nearby(layout, -at, 90.0, 90.0).size()
		for other_try: int in 2:
			var other_at: float = rng.randf_range(0.0, layout.height)
			var count: int = _nearby(layout, -other_at, 90.0, 90.0).size()
			if count < fewest:
				at = other_at
				fewest = count
		var bases: Array[Dictionary] = _reachable_near(layout, at, 80.0)
		var base: Dictionary = layout.reachable[0] if bases.is_empty() else bases[rng.randi() % bases.size()]
		# Mostly sideways: extras give choices, not a ladder that skips the route's double-jump steps.
		var rise: float = floorf(rng.randf_range(-24.0, SINGLE_STEP_MIN))
		var gap: float = rng.randf_range(MIN_GAP_X, maxf(MIN_GAP_X, max_edge_gap(rise, jump)))
		var y: float = float(base["y"]) - rise
		var width: int = _random_width(rng, y, layout.height)
		var side: float = -1.0 if rng.randf() < 0.5 else 1.0
		var x: float = roundf(float(base["x"]) + side * (gap + (int(base["width"]) + width) * TILE / 2.0))
		if base["kind"] == "floor":  # the floor is wide; start from anywhere on it
			x = roundf(rng.randf_range(-HALF_WIDTH, HALF_WIDTH))
		var candidate: Dictionary = _new_platform(rng, x, y, width, layout.height, "extra")
		if not can_reach(base, candidate, jump, Move.SINGLE_JUMP) or not _fits(layout, candidate):
			continue
		if _spoils_secrets(layout, candidate):
			continue
		_add(layout, candidate, true)
		placed += 1


# --- Treats and dash-only ledges ---------------------------------------------------------------------

## Heights for the treats, each with a dice roll that decides where it goes: (height, roll).
static func _plan_treats(layout: Layout, rng: RandomNumberGenerator) -> Array[Vector2]:
	var slots: Array[Vector2] = []
	var at: float = rng.randf_range(TREAT_SPACING.x * 0.6, TREAT_SPACING.y * 0.8)
	while at < layout.height - 120.0:
		slots.append(Vector2(at, rng.randf()))
		at += rng.randf_range(TREAT_SPACING.x, TREAT_SPACING.y)
	return slots


## Puts the treats meant for dash-only ledges on new ledges. Returns the slots still without a treat.
static func _place_dash_treats(layout: Layout, rng: RandomNumberGenerator, slots: Array[Vector2]) -> Array[Vector2]:
	var left: Array[Vector2] = []
	for slot: Vector2 in slots:
		var spot: Dictionary = {}
		if slot.y >= MAIN_TREAT_CHANCE and slot.y < MAIN_TREAT_CHANCE + DASH_TREAT_CHANCE:
			spot = _try_dash_ledge(layout, rng, slot.x)
		if spot.is_empty():
			left.append(slot)
		else:
			layout.treats.append(_treat_position(spot))
	# Make sure every level has a few.
	for slot: Vector2 in left.duplicate():
		if layout.dash_ledges.size() >= MIN_DASH_LEDGES:
			break
		var ledge: Dictionary = _try_dash_ledge(layout, rng, slot.x)
		if not ledge.is_empty():
			layout.treats.append(_treat_position(ledge))
			left.erase(slot)
	return left


## The other treats: on the route (sometimes), else on an upward-dash ledge over a dead end (while the level
## has few upward ones), else on a nearby dead end, else a new dash ledge, else the route.
static func _place_other_treats(layout: Layout, rng: RandomNumberGenerator, slots: Array[Vector2]) -> void:
	var route: Array[Dictionary] = layout.main.slice(0, layout.main.size() - 1)  # not the moon platform
	for slot: Vector2 in slots:
		var spot: Dictionary = {}
		if slot.y < MAIN_TREAT_CHANCE:
			spot = _nearest(layout, route, slot.x, 1000.0)
		if spot.is_empty() and layout.up_dash_ledges.size() < MIN_UP_DASH_LEDGES:
			spot = _try_ledge_over_dead_end(layout, rng, slot.x)
		if spot.is_empty():
			spot = _nearest(layout, layout.dead_ends, slot.x, TREAT_SPACING.x * 0.5)
		if spot.is_empty():
			spot = _try_dash_ledge(layout, rng, slot.x)
		if spot.is_empty():  # any other platform off the route (fork, dead end, stepping stone)
			var off_route: Array[Dictionary] = []
			for platform: Dictionary in layout.reachable:
				if platform["kind"] != "main" and platform["kind"] != "floor":
					off_route.append(platform)
			spot = _nearest(layout, off_route, slot.x, TREAT_SPACING.x * 0.8)
		if spot.is_empty():
			spot = _nearest(layout, route, slot.x, 1000.0)
		if not spot.is_empty():
			layout.treats.append(_treat_position(spot))


static func _treat_position(platform: Dictionary) -> Vector2:
	return Vector2(float(platform["x"]), float(platform["y"]) - TREAT_LIFT)


## The platform from `candidates` nearest to height `at` (within `within`) that has no treat yet.
static func _nearest(layout: Layout, candidates: Array[Dictionary], at: float, within: float) -> Dictionary:
	var best: Dictionary = {}
	var best_distance: float = within
	for platform: Dictionary in candidates:
		var distance: float = absf(-float(platform["y"]) - at)
		if distance <= best_distance and not layout.treats.has(_treat_position(platform)):
			best = platform
			best_distance = distance
	return best


## How far above its base a dash-only ledge of each kind usually is (so bases can be picked to put the ledge
## near a wanted height).
static func _typical_dash_rise(jump: Jump, upward: bool) -> float:
	if upward:
		return (jump.height + jump.double_jump_height + max_dash_rise(DASH_UP, jump)) / 2.0
	return 30.0


## Tries to add an upward-dash ledge above the tip of a dead end near height `at`: a dead end that isn't one
## if you still have a dash. Upward ledges are easiest to fit there, away from the route.
static func _try_ledge_over_dead_end(layout: Layout, rng: RandomNumberGenerator, at: float) -> Dictionary:
	if layout.jump.dash_distance <= 0.0:
		return {}
	var base_at: float = at - _typical_dash_rise(layout.jump, true)
	var tips: Array[Dictionary] = []
	for tip: Dictionary in layout.dead_ends:
		if absf(-float(tip["y"]) - base_at) <= TREAT_SPACING.x * 0.5:
			tips.append(tip)
	if tips.is_empty():
		return {}
	return _try_dash_ledge_kind(layout, rng, at, true, tips)


## Tries to add a small ledge near height `at` that is reachable only with a dash from a reachable platform.
static func _try_dash_ledge(layout: Layout, rng: RandomNumberGenerator, at: float) -> Dictionary:
	var jump: Jump = layout.jump
	if jump.dash_distance <= 0.0:
		return {}
	# Mix the two kinds: usually a coin flip, but a level that has only one kind so far gets the other.
	var ups: int = layout.up_dash_ledges.size()
	var sides: int = layout.dash_ledges.size() - ups
	var upward: bool = rng.randf() < UP_DASH_LEDGE_CHANCE
	if ups != sides and mini(ups, sides) == 0:
		upward = ups == 0
	var ledge: Dictionary = _try_dash_ledge_kind(layout, rng, at, upward)
	if ledge.is_empty():
		ledge = _try_dash_ledge_kind(layout, rng, at, not upward)
	return ledge


## Tries to add a dash-only ledge near height `at` that needs an upward/diagonal dash (`upward`) or a
## sideways one, from one of `bases` (default: reachable platforms at a fitting height).
static func _try_dash_ledge_kind(layout: Layout, rng: RandomNumberGenerator, at: float, upward: bool,
		bases: Array[Dictionary] = []) -> Dictionary:
	var jump: Jump = layout.jump
	if bases.is_empty():
		bases = _reachable_near(layout, at - _typical_dash_rise(jump, upward), 140.0)
	if bases.is_empty():
		return {}
	for attempt: int in DASH_LEDGE_TRIES:
		var base: Dictionary = bases[rng.randi() % bases.size()]
		var direction: Vector2 = DASH_SIDE
		var rise: float
		var low: float
		var high: float
		if upward:
			# Higher than any jump + double jump can get (real heights, not safety-reduced) plus the margin.
			direction = DASH_UP if rng.randf() < 0.5 else DASH_DIAGONAL
			var lowest_rise: float = jump.height + jump.double_jump_height + DASH_ONLY_MARGIN
			var highest_rise: float = max_dash_rise(direction, jump)
			if lowest_rise >= highest_rise:
				continue
			rise = floorf(rng.randf_range(lowest_rise, highest_rise))
			low = -TILE  # one-way platforms: the dog can dash up through one that hangs right overhead
			high = max_dash_gap(rise, jump, direction)
		else:
			rise = floorf(rng.randf_range(-24.0, 80.0))
			low = max_double_jump_gap(rise, jump) + DASH_ONLY_MARGIN
			high = max_dash_gap(rise, jump, direction)
		if low >= high:
			continue
		var width: int = rng.randi_range(2, 3)
		var side: float = -1.0 if rng.randf() < 0.5 else 1.0
		var gap: float = rng.randf_range(low, high)
		var x: float = roundf(float(base["x"]) + side * (gap + (int(base["width"]) + width) * TILE / 2.0))
		var y: float = float(base["y"]) - rise
		var candidate: Dictionary = _new_platform(rng, x, y, width, layout.height, "dash")
		if not can_dash_to(base, candidate, jump, direction) or not _fits(layout, candidate):
			continue
		if _touches_unreachable(layout, candidate) or _reached_without_dash(layout, candidate):
			continue
		if upward and _reached_by_side_dash(layout, candidate):
			continue
		_add(layout, candidate, false)
		layout.dash_ledges.append(candidate)
		if upward:
			layout.up_dash_ledges.append(candidate)
		return candidate
	return {}


## True if a new reachable platform would make an unreachable platform reachable, let the player onto a
## dash-only ledge without the dash (or onto an upward-dash ledge with a sideways dash), or give a dead end
## a way up.
static func _spoils_secrets(layout: Layout, platform: Dictionary) -> bool:
	return _touches_unreachable(layout, platform) or _reaches_dash_ledge(layout, platform) \
		or _blocks_dead_end(layout, platform)


## True if a new reachable platform would let the player onto a dash-only ledge without the dash, or onto an
## upward-dash ledge with just a sideways dash.
static func _reaches_dash_ledge(layout: Layout, platform: Dictionary) -> bool:
	for ledge: Dictionary in layout.dash_ledges:
		if can_reach(platform, ledge, layout.jump, Move.DOUBLE_JUMP, DASH_ONLY_MARGIN):
			return true
	for ledge: Dictionary in layout.up_dash_ledges:
		if can_dash_to(platform, ledge, layout.jump, DASH_SIDE, DASH_ONLY_MARGIN):
			return true
	return false


## True if a sideways dash from any platform you can climb to gets onto `platform` (with DASH_ONLY_MARGIN).
static func _reached_by_side_dash(layout: Layout, platform: Dictionary) -> bool:
	var jump: Jump = layout.jump
	var below: float = max_dash_rise(DASH_SIDE, jump) + DASH_ONLY_MARGIN
	for other: Dictionary in _nearby(layout, float(platform["y"]), below, DROP_LIMIT + DASH_ONLY_MARGIN):
		if other["kind"] == "unreachable" or other["kind"] == "dash":
			continue
		if can_dash_to(other, platform, jump, DASH_SIDE, DASH_ONLY_MARGIN):
			return true
	return false


## True if any platform could get onto `platform` without the dash (with DASH_ONLY_MARGIN to spare).
static func _reached_without_dash(layout: Layout, platform: Dictionary) -> bool:
	var jump: Jump = layout.jump
	var below: float = max_rise(Move.DOUBLE_JUMP, jump) + DASH_ONLY_MARGIN
	for other: Dictionary in _nearby(layout, float(platform["y"]), below, DROP_LIMIT + DASH_ONLY_MARGIN):
		if can_reach(other, platform, jump, Move.DOUBLE_JUMP, DASH_ONLY_MARGIN):
			return true
	return false


# --- Helpers -----------------------------------------------------------------------------------------

static func _random_width(rng: RandomNumberGenerator, y: float, height: float) -> int:
	var widths: Vector2i = REGION_WIDTHS[region_at(-y, height)]
	return rng.randi_range(widths.x, widths.y)


static func _new_platform(rng: RandomNumberGenerator, x: float, y: float, width: int, height: float,
		kind: String) -> Dictionary:
	var styles: Array = REGION_STYLES[region_at(-y, height)]
	return {
		"x": x, "y": y, "width": width, "zone": styles[rng.randi() % styles.size()], "main": kind == "main",
		"kind": kind,
	}


## True if `platform` is inside the walls, below the top clearance and keeps its distance from the others.
static func _fits(layout: Layout, platform: Dictionary, extra: Array[Dictionary] = []) -> bool:
	var x: float = platform["x"]
	var y: float = platform["y"]
	if absf(x) + int(platform["width"]) * TILE / 2.0 > HALF_WIDTH:
		return false
	if -y > layout.height - TOP_CLEARANCE or -y < MIN_GAP_Y:
		return false
	var others: Array[Dictionary] = _nearby(layout, y, MIN_GAP_Y, MIN_GAP_Y)
	others.append_array(extra)
	for other: Dictionary in others:
		if absf(float(other["y"]) - y) < MIN_GAP_Y and edge_gap(other, platform) < MIN_GAP_X:
			return false
	return true


static func _add(layout: Layout, platform: Dictionary, reachable: bool) -> void:
	layout.platforms.append(platform)
	_index(layout, platform)
	if reachable:
		layout.reachable.append(platform)


static func _index(layout: Layout, platform: Dictionary) -> void:
	var row: int = floori(-float(platform["y"]) / ROW_HEIGHT)
	if not layout.rows.has(row):
		var empty: Array[Dictionary] = []
		layout.rows[row] = empty
	(layout.rows[row] as Array[Dictionary]).append(platform)


## Platforms (and the floor) from `below` pixels under height y up to `above` pixels over it.
static func _nearby(layout: Layout, y: float, below: float, above: float) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var low: float = -y - below
	var high: float = -y + above
	for row: int in range(floori(low / ROW_HEIGHT), floori(high / ROW_HEIGHT) + 1):
		if not layout.rows.has(row):
			continue
		for platform: Dictionary in layout.rows[row]:
			var h: float = -float(platform["y"])
			if h >= low and h <= high:
				found.append(platform)
	return found


## Reachable platforms (not the floor) within `within` pixels of height `at`.
static func _reachable_near(layout: Layout, at: float, within: float) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for platform: Dictionary in layout.reachable:
		if platform["kind"] != "floor" and absf(-float(platform["y"]) - at) <= within:
			found.append(platform)
	return found


func _spawn_platform(entry: Dictionary) -> void:
	var platform: Platform = PLATFORM_SCENE.instantiate()
	platform.zone = entry["zone"]
	platform.width_tiles = entry["width"]
	platform.position = Vector2(entry["x"], entry["y"])
	add_child(platform)


func _spawn_decor(rng: RandomNumberGenerator) -> void:
	var y: float = -decor_spacing
	while -y < level_height:
		var props: Array = REGION_DECOR[region_at(-y, level_height)]
		if not props.is_empty():
			var prop_name: String = props[rng.randi() % props.size()]
			var sprite := Sprite2D.new()
			sprite.texture = load("res://assets/art/props/%s.png" % prop_name)
			if prop_name == "ufo":  # two-frame sheet: show the first frame
				sprite.region_enabled = true
				sprite.region_rect = Rect2(0, 0, 34, 18)
			sprite.position = Vector2(roundf(rng.randf_range(-280.0, 280.0)), roundf(y + rng.randf_range(-40.0, 40.0)))
			sprite.z_index = -2
			sprite.modulate = Color(0.85, 0.85, 0.95)  # a little dimmer so it reads as background
			add_child(sprite)
		y -= decor_spacing * rng.randf_range(0.7, 1.3)
