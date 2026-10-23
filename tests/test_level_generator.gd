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
