extends "res://tests/framework/test_case.gd"

const PlayerScript := preload("res://player/player.gd")
const TreatScript := preload("res://levels/pickups/treat.gd")
const HudScript := preload("res://ui/race_hud.gd")


func test_player_touching_treat_refills_dash_and_emits_collected() -> void:
	var player: Player = PlayerScript.new()
	var treat: Treat = TreatScript.new()
	var counts: Dictionary = {&"collected": 0, &"refilled": 0}
	treat.collected.connect(func() -> void: counts[&"collected"] += 1)
	player.dash_refilled.connect(func() -> void: counts[&"refilled"] += 1)
	player.dash_charges = 0
	treat._on_body_entered(player)
	assert_eq(player.dash_charges, player.max_dash_charges, "dash should be refilled")
	assert_eq(counts[&"refilled"], 1)
	assert_eq(counts[&"collected"], 1)
	assert_true(treat.is_collected)
	assert_true(treat.is_queued_for_deletion(), "a collected treat should go away")
	player.free()


func test_treat_can_only_be_collected_once() -> void:
	var player: Player = PlayerScript.new()
	var treat: Treat = TreatScript.new()
	var counts: Dictionary = {&"collected": 0}
	treat.collected.connect(func() -> void: counts[&"collected"] += 1)
	treat._on_body_entered(player)
	player.dash_charges = 0
	treat._on_body_entered(player)
	assert_eq(counts[&"collected"], 1, "second touch should be ignored")
	assert_eq(player.dash_charges, 0, "second touch should not refill again")
	player.free()


func test_non_player_bodies_are_ignored() -> void:
	var body := Node2D.new()
	var treat: Treat = TreatScript.new()
	var counts: Dictionary = {&"collected": 0}
	treat.collected.connect(func() -> void: counts[&"collected"] += 1)
	treat._on_body_entered(body)
	assert_eq(counts[&"collected"], 0)
	assert_false(treat.is_collected)
	assert_false(treat.is_queued_for_deletion())
	treat.free()
	body.free()


func test_bob_offset_stays_small_and_whole() -> void:
	for i: int in 20:
		var offset: float = TreatScript.bob_offset(i / 20.0, 2.0)
		assert_true(absf(offset) <= 2.0, "bob should stay within its height")
		assert_eq(offset, roundf(offset), "bob should move in whole pixels")


func test_treat_scene_keeps_its_shape() -> void:
	var scene: PackedScene = load("res://levels/pickups/treat.tscn")
	var treat: Node = scene.instantiate()
	assert_true(treat is Treat and treat is Area2D, "treat.tscn root should be an Area2D with the Treat script")
	assert_true(treat.get_node_or_null(^"AnimatedSprite2D") is AnimatedSprite2D)
	assert_true(treat.get_node_or_null(^"CollisionShape2D") is CollisionShape2D)
	var frames: SpriteFrames = (treat.get_node(^"AnimatedSprite2D") as AnimatedSprite2D).sprite_frames
	assert_eq(frames.get_frame_count(&"shine"), 4)
	treat.free()


func test_hud_dash_icons_follow_charges() -> void:
	assert_true(HudScript.is_dash_icon_full(0, 1))
	assert_false(HudScript.is_dash_icon_full(0, 0))
	assert_true(HudScript.is_dash_icon_full(1, 2))
	assert_false(HudScript.is_dash_icon_full(1, 1))
