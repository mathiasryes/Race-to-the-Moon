class_name LevelGenerator
extends Node2D
## Builds the climb at startup: platforms from the ground up to the moon, styled by height region,
## plus background props for each region. Moves the goal and moon to the top.
## Platform gaps come from the player's jump settings, so retuning the jump keeps every level beatable.

enum Region { LAUNCH, SKY, UPPER_ATMOSPHERE, SPACE, MOON }

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
const TILE: float = 16.0
## Platform centres stay inside the side walls by this much.
const HALF_WIDTH: float = 304.0
const MIN_GAP_Y: float = 32.0
## Only this fraction of the jump height is used for vertical gaps.
const RISE_FRACTION: float = 0.8
## Only this fraction of the possible horizontal reach is used, leaving room for imperfect jumps.
const REACH_SAFETY: float = 0.75
const TOP_PLATFORM_TILES: int = 6
## Each step moves sideways by at least this fraction of the reachable distance (unless the target is closer).
const MIN_SIDE_STEP: float = 0.6
## The route heads for a target on the other side this far out from the centre...
## (Must stay reachable for the widest platform, whose centre can't go past HALF_WIDTH - 48.)
const SIDE_TARGET_RANGE: Vector2 = Vector2(170.0, 250.0)
## ...or, with this chance, for a target near the middle.
const MIDDLE_TARGET_CHANCE: float = 0.15

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
## Chance per step of an extra side platform, giving the player a choice of route.
@export_range(0.0, 1.0) var branch_chance: float = 0.45
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

	static func from_player(p: Player) -> Jump:
		var jump := Jump.new()
		jump.height = p.jump_height
		jump.time_to_peak = p.jump_time_to_peak
		jump.time_to_fall = p.jump_time_to_fall
		jump.run_speed = p.run_speed
		jump.air_acceleration = p.air_acceleration
		return jump


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	if level_seed != 0:
		rng.seed = level_seed
	else:
		rng.randomize()

	var layout: Array[Dictionary] = generate_layout(rng, level_height, Jump.from_player(player), branch_chance)
	for entry: Dictionary in layout:
		_spawn_platform(entry)
		if entry["main"]:
			main_path.append(Vector2(entry["x"], entry["y"]))
	_spawn_decor(rng)

	var top: Vector2 = main_path[-1]
	if goal:
		goal.global_position = top
	if moon:
		moon.global_position = top + Vector2(0, -110)
	if background:
		background.climb_height = level_height


## Builds the list of platforms: { x, y, width (tiles), zone (Platform.Zone), main (on the guaranteed route) }.
static func generate_layout(rng: RandomNumberGenerator, height: float, jump: Jump, branches: float) -> Array[Dictionary]:
	var layout: Array[Dictionary] = []
	var max_rise: float = jump.height * RISE_FRACTION
	var previous: Dictionary = {"x": 0.0, "y": 0.0, "width": 40}  # the floor
	var y: float = 0.0
	# The route sweeps from side to side; `last_side` is the side it most recently headed for.
	var last_side: float = -1.0 if rng.randf() < 0.5 else 1.0
	var target: float = next_target(rng, last_side, false)
	while height + y > max_rise:
		if absf(target - previous["x"]) < 24.0:
			var was_middle: bool = absf(target) <= 60.0
			if not was_middle:
				last_side = signf(target)
			target = next_target(rng, last_side, not was_middle)
		var remaining: float = height + y
		var rise: float = rng.randf_range(MIN_GAP_Y, minf(max_rise, remaining - MIN_GAP_Y))
		y -= rise
		var region: int = region_at(-y, height)
		var width: int = rng.randi_range(REGION_WIDTHS[region].x, REGION_WIDTHS[region].y)
		var styles: Array = REGION_STYLES[region]
		var platform: Dictionary = {
			"x": _pick_x(rng, previous, width, rise, jump, target), "y": y, "width": width,
			"zone": styles[rng.randi() % styles.size()], "main": true,
		}
		layout.append(platform)
		if rng.randf() < branches:
			var branch: Dictionary = _pick_branch(rng, previous, platform, jump, styles)
			if not branch.is_empty():
				layout.append(branch)
		previous = platform

	var top_rise: float = height + y
	layout.append({
		"x": _pick_x(rng, previous, TOP_PLATFORM_TILES, top_rise, jump, 0.0), "y": -height,
		"width": TOP_PLATFORM_TILES, "zone": Platform.Zone.MOON, "main": true,
	})
	return layout


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


## Largest horizontal gap between platform edges that a jump rising `rise` pixels can safely cross.
## Assumes the player starts the jump standing still and holds the direction the whole time.
static func max_edge_gap(rise: float, jump: Jump) -> float:
	if rise > jump.height:
		return 0.0
	var fall_gravity: float = 2.0 * jump.height / (jump.time_to_fall * jump.time_to_fall)
	var air_time: float = jump.time_to_peak + sqrt(2.0 * (jump.height - rise) / fall_gravity)
	var speed_up_loss: float = jump.run_speed / (2.0 * jump.air_acceleration)  # time lost getting to full speed
	return maxf(0.0, jump.run_speed * (air_time - speed_up_loss) * REACH_SAFETY)


## Moves sideways from `from` towards `target` by a reachable amount.
static func _pick_x(rng: RandomNumberGenerator, from: Dictionary, width: int, rise: float, jump: Jump, target: float) -> float:
	var half: float = width * TILE / 2.0
	var limit: float = HALF_WIDTH - half
	var max_dx: float = max_edge_gap(rise, jump) + half + from["width"] * TILE / 2.0
	var to_target: float = target - from["x"]
	var step: float = minf(absf(to_target), rng.randf_range(MIN_SIDE_STEP, 1.0) * max_dx)
	return clampf(roundf(from["x"] + signf(to_target) * step), -limit, limit)


## An optional extra platform beside `main`, also reachable from `from`. Empty if there's no room.
static func _pick_branch(rng: RandomNumberGenerator, from: Dictionary, main: Dictionary, jump: Jump, styles: Array) -> Dictionary:
	var width: int = rng.randi_range(2, 4)
	var half: float = width * TILE / 2.0
	var rise: float = clampf(from["y"] - main["y"] + rng.randf_range(-16.0, 16.0), MIN_GAP_Y, jump.height * RISE_FRACTION)
	var y: float = roundf(from["y"] - rise)
	var reach: float = max_edge_gap(rise, jump)
	var sides: Array[float] = [-1.0, 1.0]
	if rng.randf() < 0.5:
		sides.reverse()
	for side: float in sides:
		var x: float = roundf(main["x"] + side * (main["width"] * TILE / 2.0 + half + rng.randf_range(24.0, 72.0)))
		var in_bounds: bool = absf(x) <= HALF_WIDTH - half
		var edge_gap: float = absf(x - from["x"]) - (width + from["width"]) * TILE / 2.0
		if in_bounds and edge_gap <= reach:
			return {"x": x, "y": y, "width": width, "zone": styles[rng.randi() % styles.size()], "main": false}
	return {}


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
