extends "res://tests/framework/test_case.gd"

const Generator := preload("res://levels/generation/level_generator.gd")
const PlayerScript := preload("res://player/player.gd")

const HEIGHT := 3200.0
## Collision box width of the player; a jump must clear the gap plus this to land safely.
const BODY_WIDTH := 14.0


func _jump() -> Generator.Jump:
	var player: Player = PlayerScript.new()
	var jump: Generator.Jump = Generator.Jump.from_player(player)
	player.free()
	return jump


func _layout(level_seed: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = level_seed
	return Generator.generate_layout(rng, HEIGHT, _jump(), 0.45)


func test_regions_by_height() -> void:
	assert_eq(Generator.region_at(0.0, 1000.0), Generator.Region.LAUNCH)
	assert_eq(Generator.region_at(100.0, 1000.0), Generator.Region.SKY)
	assert_eq(Generator.region_at(500.0, 1000.0), Generator.Region.UPPER_ATMOSPHERE)
	assert_eq(Generator.region_at(700.0, 1000.0), Generator.Region.SPACE)
	assert_eq(Generator.region_at(1000.0, 1000.0), Generator.Region.MOON)


func test_every_step_of_the_route_is_reachable() -> void:
	var jump: Generator.Jump = _jump()
	var max_rise: float = jump.height * Generator.RISE_FRACTION
	for level_seed: int in range(1, 61):
		var previous: Dictionary = {"x": 0.0, "y": 0.0, "width": 40}
		for platform: Dictionary in _layout(level_seed):
			if not platform["main"]:
				continue
			var rise: float = previous["y"] - platform["y"]
			var gap: float = absf(platform["x"] - previous["x"]) - (platform["width"] + previous["width"]) * 8.0
			assert_true(rise >= Generator.MIN_GAP_Y - 0.5 and rise <= max_rise + 0.5,
				"seed %d: rise %.1f out of range" % [level_seed, rise])
			assert_true(gap <= Generator.max_edge_gap(rise, jump) + 1.0,
				"seed %d: gap %.1f too wide for rise %.1f" % [level_seed, gap, rise])
			previous = platform
		if not failures.is_empty():
			return


func test_platforms_stay_inside_the_walls() -> void:
	for level_seed: int in range(1, 31):
		for platform: Dictionary in _layout(level_seed):
			var half: float = platform["width"] * 8.0
			assert_true(absf(platform["x"]) + half <= Generator.HALF_WIDTH + 0.5,
				"seed %d: platform at x %.0f sticks out" % [level_seed, platform["x"]])
		if not failures.is_empty():
			return


func test_route_ends_on_the_moon() -> void:
	var layout: Array[Dictionary] = _layout(7)
	var top: Dictionary = layout[-1]
	assert_almost_eq(top["y"], -HEIGHT)
	assert_eq(top["zone"], Platform.Zone.MOON)
	assert_true(top["main"])


func test_styles_follow_the_regions() -> void:
	for platform: Dictionary in _layout(3):
		var region: int = Generator.region_at(-platform["y"], HEIGHT)
		assert_true(Generator.REGION_STYLES[region].has(platform["zone"]),
			"style %d doesn't belong in region %d" % [platform["zone"], region])


func test_same_seed_same_level() -> void:
	assert_eq(_layout(42), _layout(42))
	assert_true(_layout(42) != _layout(43), "different seeds should give different levels")


## A full left-right-left sweep takes roughly 600 px of climbing.
func test_route_visits_both_sides_every_600_px() -> void:
	var window: float = 600.0
	for level_seed: int in range(1, 61):
		var layout: Array[Dictionary] = _layout(level_seed)
		var window_bottom: float = 0.0
		while window_bottom < HEIGHT - window:
			var left: bool = false
			var right: bool = false
			for platform: Dictionary in layout:
				if -platform["y"] > window_bottom and -platform["y"] <= window_bottom + window:
					left = left or platform["x"] < -80.0
					right = right or platform["x"] > 80.0
			assert_true(left and right, "seed %d: platforms between %.0f and %.0f px stay on one side" % [
				level_seed, window_bottom, window_bottom + window])
			window_bottom += 90.0
		if not failures.is_empty():
			return


func test_platforms_use_both_sides_and_the_middle() -> void:
	for level_seed: int in range(1, 31):
		var counts: Array[int] = [0, 0, 0]  # left, middle, right
		var layout: Array[Dictionary] = _layout(level_seed)
		for platform: Dictionary in layout:
			var x: float = platform["x"]
			counts[0 if x < -100.0 else (2 if x > 100.0 else 1)] += 1
		for i: int in 3:
			assert_true(counts[i] >= layout.size() * 0.15,
				"seed %d: left/middle/right counts %s are lopsided" % [level_seed, counts])
		if not failures.is_empty():
			return


func test_side_targets_are_reachable_for_every_platform_width() -> void:
	var widest: int = Generator.TOP_PLATFORM_TILES
	for widths: Vector2i in Generator.REGION_WIDTHS:
		widest = maxi(widest, widths.y)
	var limit: float = Generator.HALF_WIDTH - widest * 8.0
	assert_true(Generator.SIDE_TARGET_RANGE.y <= limit,
		"side targets go to %.0f but a %d-tile platform stops at %.0f" % [Generator.SIDE_TARGET_RANGE.y, widest, limit])


func test_route_heads_for_the_other_side_or_the_middle() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i: int in 50:
		var from_right: float = Generator.next_target(rng, 1.0, true)
		assert_true(from_right <= 60.0, "after the right side the route went to %.0f" % from_right)
		var from_left: float = Generator.next_target(rng, -1.0, true)
		assert_true(from_left >= -60.0, "after the left side the route went to %.0f" % from_left)
		var after_middle: float = Generator.next_target(rng, -1.0, false)
		assert_true(after_middle >= Generator.SIDE_TARGET_RANGE.x, "no two middle stops in a row (went to %.0f)" % after_middle)


func test_level_offers_side_routes() -> void:
	var branches: int = 0
	for platform: Dictionary in _layout(5):
		if not platform["main"]:
			branches += 1
	assert_true(branches >= 10, "only %d side platforms" % branches)


## Cross-checks the generator's reach formula against the player's own movement code.
func test_reach_formula_matches_player_physics() -> void:
	var player: Player = PlayerScript.new()
	var jump: Generator.Jump = Generator.Jump.from_player(player)
	for rise: float in [0.0, 20.0, 40.0, 60.0, jump.height * Generator.RISE_FRACTION]:
		var reached: float = _simulate_jump(player, rise)
		var allowed: float = Generator.max_edge_gap(rise, jump)
		assert_true(reached >= allowed + BODY_WIDTH,
			"rise %.0f: a real jump reaches %.1f px, generator allows gaps of %.1f" % [rise, reached, allowed])
	player.free()


## Horizontal distance covered by a jump from standstill (holding right) when it comes back down to `rise`.
func _simulate_jump(player: Player, rise: float) -> float:
	var dt: float = 1.0 / 60.0
	var x: float = 0.0
	var y: float = 0.0
	var speed_x: float = 0.0
	player.velocity = Vector2(0.0, player.get_jump_velocity())
	for i: int in 600:
		player.velocity.y = minf(player.velocity.y + player.current_gravity() * dt, player.max_fall_speed)
		speed_x = player.next_horizontal_speed(speed_x, 1.0, dt, false)
		x += speed_x * dt
		y += player.velocity.y * dt
		if player.velocity.y > 0.0 and y >= -rise:
			break
	return x
