extends "res://tests/framework/test_case.gd"

const Generator := preload("res://levels/generation/level_generator.gd")
const PlayerScript := preload("res://player/player.gd")

const HEIGHT := 3200.0
## Collision box width of the player; a jump must clear the gap plus this to land safely.
const BODY_WIDTH := 14.0
## Seeds checked by the reachability tests.
const SEEDS := 40
const FLOOR: Dictionary = {"x": 0.0, "y": 0.0, "width": 40, "kind": "floor"}

## Generated levels and their reachability, by seed (shared by all tests in this file).
static var _layouts: Dictionary = {}
static var _graphs: Dictionary = {}


func _jump() -> Generator.Jump:
	var player: Player = PlayerScript.new()
	var jump: Generator.Jump = Generator.Jump.from_player(player)
	player.free()
	return jump


func _generate(level_seed: int) -> Generator.Layout:
	var rng := RandomNumberGenerator.new()
	rng.seed = level_seed
	return Generator.generate_layout(rng, HEIGHT, _jump())


func _layout(level_seed: int) -> Generator.Layout:
	if not _layouts.has(level_seed):
		_layouts[level_seed] = _generate(level_seed)
	return _layouts[level_seed]


func _platforms(level_seed: int) -> Array[Dictionary]:
	return _layout(level_seed).platforms


## Reachability of one level, worked out here from the reach rules (not from the generator's bookkeeping):
## { "nodes": floor + platforms, "walk": nodes reachable from the floor with jump + double jump,
##   "dash": nodes not in "walk" that one dash from a "walk" node reaches }.
func _graph(level_seed: int) -> Dictionary:
	if _graphs.has(level_seed):
		return _graphs[level_seed]
	var jump: Generator.Jump = _jump()
	var nodes: Array[Dictionary] = [FLOOR]
	nodes.append_array(_platforms(level_seed))
	var walk: Dictionary = _search(nodes, 0, jump, {})
	var dash: Dictionary = {}
	for i: int in walk:
		for j: int in nodes.size():
			if not walk.has(j) and Generator.can_reach(nodes[i], nodes[j], jump, Generator.Move.DASH):
				dash[j] = true
	var graph: Dictionary = {"nodes": nodes, "walk": walk, "dash": dash}
	_graphs[level_seed] = graph
	return graph


## Breadth-first search with jump + double jump from nodes[start], skipping `blocked` indices.
func _search(nodes: Array[Dictionary], start: int, jump: Generator.Jump, blocked: Dictionary) -> Dictionary:
	var seen: Dictionary = {start: true}
	var queue: Array[int] = [start]
	while not queue.is_empty():
		var i: int = queue.pop_front()
		for j: int in nodes.size():
			if seen.has(j) or blocked.has(j):
				continue
			if Generator.can_reach(nodes[i], nodes[j], jump, Generator.Move.DOUBLE_JUMP):
				seen[j] = true
				queue.append(j)
	return seen


func _higher_reachable_neighbours(nodes: Array[Dictionary], i: int, walk: Dictionary, jump: Generator.Jump) -> int:
	var count: int = 0
	for j: int in walk:
		if float(nodes[j]["y"]) < float(nodes[i]["y"]) and \
				Generator.can_reach(nodes[i], nodes[j], jump, Generator.Move.DOUBLE_JUMP):
			count += 1
	return count


func test_regions_by_height() -> void:
	assert_eq(Generator.region_at(0.0, 1000.0), Generator.Region.LAUNCH)
	assert_eq(Generator.region_at(100.0, 1000.0), Generator.Region.SKY)
	assert_eq(Generator.region_at(500.0, 1000.0), Generator.Region.UPPER_ATMOSPHERE)
	assert_eq(Generator.region_at(700.0, 1000.0), Generator.Region.SPACE)
	assert_eq(Generator.region_at(1000.0, 1000.0), Generator.Region.MOON)


func test_reach_grows_with_double_jump_and_dash() -> void:
	var jump: Generator.Jump = _jump()
	for rise: float in [0.0, 30.0, 60.0]:
		var single: float = Generator.max_edge_gap(rise, jump)
		var double: float = Generator.max_double_jump_gap(rise, jump)
		var dash: float = Generator.max_dash_gap(rise, jump)
		assert_true(single > 0.0 and double > single and dash > double,
			"rise %.0f: single %.0f, double %.0f, dash %.0f" % [rise, single, double, dash])
		assert_almost_eq(dash - double, jump.dash_distance * Generator.DASH_SAFETY, 0.01)
	assert_true(Generator.max_rise(Generator.Move.DOUBLE_JUMP, jump) > Generator.max_rise(Generator.Move.SINGLE_JUMP, jump))
	var low: Dictionary = {"x": 0.0, "y": 0.0, "width": 2}
	var high: Dictionary = {"x": 0.0, "y": -100.0, "width": 2}
	assert_false(Generator.can_reach(low, high, jump, Generator.Move.SINGLE_JUMP), "100 px is too high for one jump")
	assert_true(Generator.can_reach(low, high, jump, Generator.Move.DOUBLE_JUMP), "100 px is fine with a double jump")


## The dash goes 8 ways: straight up it adds its distance plus the coast afterwards, using the player's values.
func test_upward_dash_rise_formula() -> void:
	var player: Player = PlayerScript.new()
	var jump: Generator.Jump = Generator.Jump.from_player(player)
	var coast: float = player.run_speed * player.run_speed / (2.0 * player.get_jump_gravity())
	var expected: float = player.get_dash_distance() + coast
	assert_almost_eq(Generator.dash_rise(jump), expected, 0.01)
	assert_almost_eq(Generator.post_dash_rise(1.0, jump), coast, 0.01)
	assert_almost_eq(Generator.highest_ever(jump), player.jump_height + player.double_jump_height + expected, 0.01)
	assert_true(Generator.max_rise(Generator.Move.DASH, jump) > Generator.max_rise(Generator.Move.DOUBLE_JUMP, jump) \
		+ player.get_dash_distance() * 0.8, "an upward dash should add most of the dash distance to the reach")
	assert_true(Generator.max_dash_rise(Generator.DASH_UP, jump) > Generator.max_dash_rise(Generator.DASH_DIAGONAL, jump))
	assert_true(Generator.max_dash_rise(Generator.DASH_DIAGONAL, jump) > Generator.max_dash_rise(Generator.DASH_SIDE, jump))
	player.free()


## Simulates jump + double jump + a straight-up dash at the top, with the player's own gravity: the peak is
## where the generator thinks it is (the dash is fixed speed with no gravity, then it leaves run_speed upwards).
func test_upward_dash_peak_matches_settings() -> void:
	var player: Player = PlayerScript.new()
	var jump: Generator.Jump = Generator.Jump.from_player(player)
	var dt: float = 1.0 / 240.0
	var y: float = 0.0
	var peak: float = 0.0
	var stage: int = 0  # 0 = jump, 1 = double jump, 2 = after the dash
	player.velocity = Vector2(0.0, player.get_jump_velocity())
	for i: int in 2000:
		player.velocity.y = minf(player.velocity.y + player.current_gravity() * dt, player.max_fall_speed)
		if stage == 0 and player.velocity.y >= 0.0:
			player.velocity.y = player.get_double_jump_velocity()
			stage = 1
		elif stage == 1 and player.velocity.y >= 0.0:
			y -= player.get_dash_distance()  # the dash: dash_speed for dash_time, straight up, no gravity
			player.velocity.y = -player.run_speed
			stage = 2
		y += player.velocity.y * dt
		peak = maxf(peak, -y)
		if stage == 2 and player.velocity.y > 0.0:
			break
	var expected: float = Generator.highest_ever(jump)
	assert_true(absf(peak - expected) <= 6.0, "jump + double jump + up dash peaks at %.1f px, expected %.0f" % [
		peak, expected])
	player.free()


## Which dash direction gets you where: high up needs an upward dash, far out a sideways one.
func test_dash_reach_depends_on_direction() -> void:
	var jump: Generator.Jump = _jump()
	var base: Dictionary = {"x": 0.0, "y": 0.0, "width": 3}
	var rise: float = jump.height + jump.double_jump_height + 16.0
	var overhead: Dictionary = {"x": 40.0, "y": -rise, "width": 2}
	assert_false(Generator.can_reach(base, overhead, jump, Generator.Move.DOUBLE_JUMP), "too high without the dash")
	assert_false(Generator.can_dash_to(base, overhead, jump, Generator.DASH_SIDE), "a sideways dash doesn't climb")
	assert_true(Generator.can_dash_to(base, overhead, jump, Generator.DASH_UP), "an upward dash gets %.0f px up" % rise)
	assert_true(Generator.can_reach(base, overhead, jump, Generator.Move.DASH))
	var gap: float = Generator.max_double_jump_gap(0.0, jump) + 40.0
	var far: Dictionary = {"x": gap + 40.0, "y": 0.0, "width": 2}
	assert_false(Generator.can_reach(base, far, jump, Generator.Move.DOUBLE_JUMP), "too far without the dash")
	assert_true(Generator.can_dash_to(base, far, jump, Generator.DASH_SIDE), "a sideways dash crosses %.0f px" % gap)
	assert_false(Generator.can_dash_to(base, far, jump, Generator.DASH_UP), "a straight-up dash doesn't go sideways")
	for r: float in [-60.0, 0.0, 60.0, 120.0, 180.0, 220.0]:
		# The generous "could anyone ever get there" rule must allow at least what the generator plans with.
		assert_true(Generator.ever_gap(r, jump) >= Generator.best_dash_gap(r, jump),
			"rise %.0f: generous gap %.0f < planned dash gap %.0f" % [r, Generator.ever_gap(r, jump),
			Generator.best_dash_gap(r, jump)])
		assert_true(Generator.ever_gap(r, jump) >= Generator.max_ever_gap(r, jump) - 0.01)
	assert_true(Generator.max_rise(Generator.Move.DASH, jump) < Generator.highest_ever(jump))


func test_every_step_of_the_route_is_reachable_without_the_dash() -> void:
	var jump: Generator.Jump = _jump()
	for level_seed: int in range(1, 61):
		var previous: Dictionary = FLOOR
		for platform: Dictionary in _layout(level_seed).main:
			var rise: float = previous["y"] - platform["y"]
			assert_true(rise >= Generator.MIN_GAP_Y - 0.5, "seed %d: rise %.1f too small" % [level_seed, rise])
			assert_true(Generator.can_reach(previous, platform, jump, Generator.Move.DOUBLE_JUMP),
				"seed %d: route step at height %.0f needs more than a double jump" % [level_seed, -platform["y"]])
			previous = platform
		if not failures.is_empty():
			return


## Playtest: "very easy with the double jump". About half the route's steps now need it.
func test_about_half_the_route_steps_need_the_double_jump() -> void:
	var jump: Generator.Jump = _jump()
	var steps: int = 0
	var doubles: int = 0
	for level_seed: int in range(1, SEEDS + 1):
		var previous: Dictionary = FLOOR
		var level_steps: int = 0
		var level_doubles: int = 0
		for platform: Dictionary in _layout(level_seed).main:
			level_steps += 1
			if not Generator.can_reach(previous, platform, jump, Generator.Move.SINGLE_JUMP):
				level_doubles += 1
			previous = platform
		var level_share: float = float(level_doubles) / level_steps
		assert_true(level_share >= 0.38 and level_share <= 0.62, "seed %d: %d of %d route steps need the double jump" % [
			level_seed, level_doubles, level_steps])
		steps += level_steps
		doubles += level_doubles
	var share: float = float(doubles) / steps
	assert_true(share >= 0.45 and share <= 0.55, "%.0f%% of route steps need the double jump" % (share * 100.0))


## Single-jump steps of the route are big too: they climb at least SINGLE_STEP_MIN (except near the moon).
func test_single_jump_steps_are_not_tiny() -> void:
	var jump: Generator.Jump = _jump()
	for level_seed: int in range(1, SEEDS + 1):
		var route: Array[Dictionary] = _layout(level_seed).main
		var previous: Dictionary = FLOOR
		for k: int in route.size() - 2:  # the last steps squeeze in under the moon
			var rise: float = float(previous["y"]) - float(route[k]["y"])
			assert_true(rise >= Generator.SINGLE_STEP_MIN - 1.0, "seed %d: route step %d only rises %.0f px" % [
				level_seed, k, rise])
			previous = route[k]
		if not failures.is_empty():
			return
	assert_true(Generator.SINGLE_STEP_MIN > Generator.max_rise(Generator.Move.SINGLE_JUMP, jump) * 0.5)


func test_platforms_stay_inside_the_walls() -> void:
	for level_seed: int in range(1, 31):
		for platform: Dictionary in _platforms(level_seed):
			var half: float = platform["width"] * 8.0
			assert_true(absf(platform["x"]) + half <= Generator.HALF_WIDTH + 0.5,
				"seed %d: platform at x %.0f sticks out" % [level_seed, platform["x"]])
		if not failures.is_empty():
			return


## Platforms side by side keep 8 px between them; stacked ones leave room for the dog (16 px + 8 px platform).
func test_platforms_do_not_overlap() -> void:
	for level_seed: int in range(1, 31):
		var platforms: Array[Dictionary] = [FLOOR]
		platforms.append_array(_platforms(level_seed))
		for i: int in platforms.size():
			for j: int in range(i + 1, platforms.size()):
				var a: Dictionary = platforms[i]
				var b: Dictionary = platforms[j]
				if Generator.edge_gap(a, b) < 8.0:
					assert_true(absf(float(a["y"]) - float(b["y"])) >= 24.0, "seed %d: platforms at (%.0f, %.0f) and (%.0f, %.0f) overlap" % [
						level_seed, a["x"], a["y"], b["x"], b["y"]])
		if not failures.is_empty():
			return


func test_route_ends_on_the_moon() -> void:
	var layout: Generator.Layout = _layout(7)
	var top: Dictionary = layout.main[-1]
	assert_almost_eq(top["y"], -HEIGHT)
	assert_eq(top["zone"], Platform.Zone.MOON)
	assert_true(top["main"])
	for platform: Dictionary in layout.platforms:
		assert_true(platform == top or -float(platform["y"]) <= HEIGHT - Generator.TOP_CLEARANCE,
			"a platform crowds the moon at height %.0f" % -float(platform["y"]))


func test_styles_follow_the_regions() -> void:
	for platform: Dictionary in _platforms(3):
		var region: int = Generator.region_at(-platform["y"], HEIGHT)
		assert_true(Generator.REGION_STYLES[region].has(platform["zone"]),
			"style %d doesn't belong in region %d" % [platform["zone"], region])


func test_same_seed_same_level() -> void:
	var a: Generator.Layout = _generate(42)
	var b: Generator.Layout = _generate(42)
	assert_eq(a.platforms, b.platforms)
	assert_eq(a.treats, b.treats)
	assert_eq(a.forks, b.forks)
	assert_true(a.platforms != _generate(43).platforms, "different seeds should give different levels")


## A full left-right-left sweep of the route takes roughly 600 px of climbing.
func test_route_visits_both_sides_every_600_px() -> void:
	var window: float = 600.0
	for level_seed: int in range(1, 61):
		var route: Array[Dictionary] = _platforms(level_seed)
		var window_bottom: float = 0.0
		while window_bottom < HEIGHT - window:
			var left: bool = false
			var right: bool = false
			for platform: Dictionary in route:
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
		var platforms: Array[Dictionary] = _platforms(level_seed)
		for platform: Dictionary in platforms:
			var x: float = platform["x"]
			counts[0 if x < -100.0 else (2 if x > 100.0 else 1)] += 1
		for i: int in 3:
			assert_true(counts[i] >= platforms.size() * 0.15,
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


## Playtest: "less platforms overall". About 90-110 per 3200 px level (10-12 per screen), none of it empty.
func test_platform_count() -> void:
	var total: int = 0
	for level_seed: int in range(1, SEEDS + 1):
		var platforms: Array[Dictionary] = _platforms(level_seed)
		total += platforms.size()
		assert_true(platforms.size() >= 85 and platforms.size() <= 120, "seed %d: %d platforms" % [
			level_seed, platforms.size()])
		var screen_bottom: float = 0.0
		while screen_bottom < HEIGHT - 360.0:
			var count: int = 0
			for platform: Dictionary in platforms:
				if -platform["y"] > screen_bottom and -platform["y"] <= screen_bottom + 360.0:
					count += 1
			assert_true(count >= 6 and count <= 24, "seed %d: %d platforms between %.0f and %.0f px" % [
				level_seed, count, screen_bottom, screen_bottom + 360.0])
			screen_bottom += 180.0
		if not failures.is_empty():
			return
	var average: float = float(total) / SEEDS
	assert_true(average >= 90.0 and average <= 110.0, "%.1f platforms per level on average" % average)


## The heart of the level design: the moon is reachable without the dash, and around the route there are
## dead ends, platforms you can never reach, dash-only ledges and real choices of where to go next.
func test_reachability_graph() -> void:
	var jump: Generator.Jump = _jump()
	var dash_total: int = 0
	var up_total: int = 0
	var side_total: int = 0
	for level_seed: int in range(1, SEEDS + 1):
		var graph: Dictionary = _graph(level_seed)
		var nodes: Array[Dictionary] = graph["nodes"]
		var walk: Dictionary = graph["walk"]
		var dash: Dictionary = graph["dash"]
		var top: int = nodes.find(_layout(level_seed).main[-1])
		assert_true(walk.has(top), "seed %d: the moon can't be reached without the dash" % level_seed)

		var unreachable: int = nodes.size() - walk.size() - dash.size()
		var dead_ends: int = 0
		var choices: int = 0
		for i: int in walk:
			var higher: int = _higher_reachable_neighbours(nodes, i, walk, jump)
			if higher == 0 and i != top:
				dead_ends += 1
			elif higher >= 2:
				choices += 1
		assert_true(unreachable >= 5, "seed %d: only %d unreachable platforms" % [level_seed, unreachable])
		assert_true(dash.size() >= 2, "seed %d: only %d dash-only platforms" % [level_seed, dash.size()])
		dash_total += dash.size()
		# A dash-only platform "needs a sideways dash" if a sideways dash from somewhere reachable gets there,
		# otherwise it needs an upward or diagonal one.
		for j: int in dash:
			var sideways: bool = false
			for i: int in walk:
				if Generator.can_dash_to(nodes[i], nodes[j], jump, Generator.DASH_SIDE):
					sideways = true
					break
			if sideways:
				side_total += 1
			else:
				up_total += 1
		assert_true(dead_ends >= 5, "seed %d: only %d dead ends" % [level_seed, dead_ends])
		assert_true(choices >= walk.size() * 0.3, "seed %d: only %d of %d reachable platforms offer a choice" % [
			level_seed, choices, walk.size()])
		if not failures.is_empty():
			return
	assert_true(dash_total >= SEEDS * 3, "only %d dash-only platforms in %d levels" % [dash_total, SEEDS])
	assert_true(up_total >= SEEDS * 0.5, "only %d dash-only platforms need an upward dash in %d levels" % [up_total, SEEDS])
	assert_true(side_total >= SEEDS * 0.5, "only %d dash-only platforms need a sideways dash in %d levels" % [
		side_total, SEEDS])


## Platforms the generator marks as unreachable are out of reach even by the generous rule, and even with an
## upward, diagonal or sideways dash given the full unreachable margin on top.
func test_unreachable_platforms_stay_out_of_reach() -> void:
	var jump: Generator.Jump = _jump()
	for level_seed: int in range(1, SEEDS + 1):
		var graph: Dictionary = _graph(level_seed)
		var nodes: Array[Dictionary] = graph["nodes"]
		for j: int in nodes.size():
			if nodes[j]["kind"] != "unreachable":
				continue
			assert_false(graph["walk"].has(j) or graph["dash"].has(j),
				"seed %d: unreachable platform %d can be reached" % [level_seed, j])
			for i: int in nodes.size():
				if nodes[i]["kind"] == "unreachable":
					continue
				assert_false(Generator.could_ever_reach(nodes[i], nodes[j], jump),
					"seed %d: platform %d could reach unreachable platform %d" % [level_seed, i, j])
				for direction: Vector2 in Generator.DASH_DIRECTIONS:
					assert_false(Generator.can_dash_to(nodes[i], nodes[j], jump, direction, Generator.UNREACHABLE_MARGIN),
						"seed %d: a %s dash from platform %d reaches unreachable platform %d" % [
						level_seed, direction, i, j])
				# Straight up: nothing gets higher than jump + double jump + an upward dash.
				var rise: float = float(nodes[i]["y"]) - float(nodes[j]["y"])
				if Generator.edge_gap(nodes[i], nodes[j]) <= 0.0 and rise > 0.0:
					assert_true(rise > Generator.highest_ever(jump),
						"seed %d: unreachable platform %d is only %.0f px above platform %d" % [level_seed, j, rise, i])
		if not failures.is_empty():
			return


## Both sides of every fork are climbable: the fork alone (route platforms in between removed) still gets there.
func test_forks_are_real_alternative_paths() -> void:
	var jump: Generator.Jump = _jump()
	var total: int = 0
	for level_seed: int in range(1, SEEDS + 1):
		var layout: Generator.Layout = _layout(level_seed)
		var nodes: Array[Dictionary] = [FLOOR]
		nodes.append_array(layout.platforms)
		total += layout.forks.size()
		assert_true(layout.forks.size() >= 1, "seed %d: no forks" % level_seed)
		for fork: Vector2i in layout.forks:
			var blocked: Dictionary = {}
			for k: int in range(fork.x + 1, fork.y):
				blocked[nodes.find(layout.main[k])] = true
			var start: int = nodes.find(layout.main[fork.x])
			var end: int = nodes.find(layout.main[fork.y])
			assert_true(_search(nodes, start, jump, blocked).has(end),
				"seed %d: the fork from route step %d to %d is not climbable" % [level_seed, fork.x, fork.y])
		if not failures.is_empty():
			return
	assert_true(total >= SEEDS * 1.3, "only %d forks in %d levels" % [total, SEEDS])


func test_treats_are_spread_out_and_reachable() -> void:
	for level_seed: int in range(1, SEEDS + 1):
		var layout: Generator.Layout = _layout(level_seed)
		var graph: Dictionary = _graph(level_seed)
		var nodes: Array[Dictionary] = graph["nodes"]
		var count: int = layout.treats.size()
		assert_true(count >= floori(HEIGHT / 500.0) and count <= ceili(HEIGHT / 300.0),
			"seed %d: %d treats" % [level_seed, count])
		var off_route: int = 0
		for treat: Vector2 in layout.treats:
			var holder: int = -1
			for i: int in nodes.size():
				if Vector2(nodes[i]["x"], float(nodes[i]["y"]) - Generator.TREAT_LIFT) == treat:
					holder = i
			assert_true(holder >= 0, "seed %d: treat at %s floats in the air" % [level_seed, treat])
			if holder < 0:
				continue
			assert_true(graph["walk"].has(holder) or graph["dash"].has(holder),
				"seed %d: treat at %s can't be reached" % [level_seed, treat])
			if not nodes[holder]["main"]:
				off_route += 1
		assert_true(off_route * 2 >= count, "seed %d: most treats are on the route" % level_seed)
		var heights: Array[float] = []
		for treat: Vector2 in layout.treats:
			heights.append(-treat.y)
		heights.sort()
		for k: int in range(1, heights.size()):
			assert_true(heights[k] - heights[k - 1] <= 800.0, "seed %d: no treat between %.0f and %.0f px" % [
				level_seed, heights[k - 1], heights[k]])
		if not failures.is_empty():
			return


## Cross-checks the generator's reach formulas against the player's own movement code.
func test_reach_formula_matches_player_physics() -> void:
	var player: Player = PlayerScript.new()
	var jump: Generator.Jump = Generator.Jump.from_player(player)
	for rise: float in [0.0, 20.0, 40.0, 60.0, Generator.max_rise(Generator.Move.SINGLE_JUMP, jump)]:
		var reached: float = _simulate_jump(player, rise, false)
		var allowed: float = Generator.max_edge_gap(rise, jump)
		assert_true(reached >= allowed + BODY_WIDTH,
			"rise %.0f: a real jump reaches %.1f px, generator allows gaps of %.1f" % [rise, reached, allowed])
	for rise: float in [0.0, 40.0, 80.0, 100.0, Generator.max_rise(Generator.Move.DOUBLE_JUMP, jump)]:
		var reached: float = _simulate_jump(player, rise, true)
		var allowed: float = Generator.max_double_jump_gap(rise, jump)
		assert_true(reached >= allowed + BODY_WIDTH,
			"rise %.0f: a real double jump reaches %.1f px, generator allows gaps of %.1f" % [rise, reached, allowed])
	player.free()


## Unreachable platforms rely on the jump + double jump never getting higher than their two heights added up.
func test_double_jump_peak_matches_settings() -> void:
	var player: Player = PlayerScript.new()
	var dt: float = 1.0 / 60.0
	var y: float = 0.0
	var peak: float = 0.0
	var used_double: bool = false
	player.velocity = Vector2(0.0, player.get_jump_velocity())
	for i: int in 600:
		player.velocity.y = minf(player.velocity.y + player.current_gravity() * dt, player.max_fall_speed)
		if not used_double and player.velocity.y >= 0.0:
			player.velocity.y = player.get_double_jump_velocity()
			used_double = true
		y += player.velocity.y * dt
		peak = maxf(peak, -y)
		if used_double and player.velocity.y > 0.0:
			break
	var expected: float = player.jump_height + player.double_jump_height
	assert_true(absf(peak - expected) <= 6.0, "jump + double jump peaks at %.1f px, expected %.0f" % [peak, expected])
	player.free()


## Horizontal distance covered by a jump from standstill (holding right) when it comes back down to `rise`.
## With `double_jump` the second jump is used at the top of the first.
func _simulate_jump(player: Player, rise: float, double_jump: bool) -> float:
	var dt: float = 1.0 / 60.0
	var x: float = 0.0
	var y: float = 0.0
	var speed_x: float = 0.0
	var used_double: bool = not double_jump
	player.velocity = Vector2(0.0, player.get_jump_velocity())
	for i: int in 600:
		player.velocity.y = minf(player.velocity.y + player.current_gravity() * dt, player.max_fall_speed)
		if not used_double and player.velocity.y >= 0.0:
			player.velocity.y = player.get_double_jump_velocity()
			used_double = true
		speed_x = player.next_horizontal_speed(speed_x, 1.0, dt, false)
		x += speed_x * dt
		y += player.velocity.y * dt
		if used_double and player.velocity.y > 0.0 and y >= -rise:
			break
	return x
