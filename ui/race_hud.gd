class_name RaceHud
extends CanvasLayer
## Countdown, "rocket is getting away" warning and the win/lose screen. Keeps running while the game is paused
## so the player can restart. Also shows the player's dash charges (paw icons) in the top-left corner.

const LOSE_TEXT := "The rocket left without you!"
const WIN_TEXT := "You beat the rocket to the moon!"
const DASH_ICON: Texture2D = preload("res://assets/art/ui/dash_icon.png")
const DASH_ICON_SIZE: int = 12
## How long the refill flash/pop on the dash icons lasts, in seconds.
const REFILL_POP_TIME: float = 0.25

@export var director: RaceDirector
## The player whose dashes are shown. Leave empty to hide the dash indicator.
@export var player: Player

var _blink_time: float = 0.0
var _danger: float = 0.0
var _dash_icons: Array[TextureRect] = []
var _dash_full: AtlasTexture
var _dash_empty: AtlasTexture

@onready var _center_label: Label = $CenterLabel
@onready var _warning: Label = $Warning
@onready var _end_screen: Control = $EndScreen
@onready var _end_title: Label = $EndScreen/Title
@onready var _dash_indicator: HBoxContainer = $DashIndicator


func _ready() -> void:
	_warning.hide()
	_end_screen.hide()
	director.countdown_changed.connect(_on_countdown_changed)
	director.lifted_off.connect(_on_lifted_off)
	director.danger_changed.connect(_on_danger_changed)
	director.race_lost.connect(_show_end.bind(LOSE_TEXT))
	director.race_won.connect(_show_end.bind(WIN_TEXT))
	_setup_dash_indicator()


func _process(delta: float) -> void:
	if _warning.visible:
		_blink_time += delta * (3.0 + _danger * 9.0)  # blinks faster as the rocket gets closer to escaping
		_warning.modulate.a = 0.55 + 0.45 * sin(_blink_time * TAU * 0.5)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().paused = false
		get_tree().reload_current_scene()


func _on_countdown_changed(seconds_left: int) -> void:
	_center_label.text = str(seconds_left)
	_center_label.show()


func _on_lifted_off() -> void:
	_center_label.text = "LIFTOFF!"
	get_tree().create_timer(1.0).timeout.connect(_center_label.hide)


func _on_danger_changed(amount: float) -> void:
	_danger = amount
	_warning.visible = amount > 0.0 and not _end_screen.visible


func _show_end(title: String) -> void:
	_center_label.hide()
	_warning.hide()
	_end_title.text = title
	_end_screen.show()


## Whether the dash icon at `index` shows as full when the player has `charges` dashes left.
static func is_dash_icon_full(index: int, charges: int) -> bool:
	return index < charges


func _setup_dash_indicator() -> void:
	_dash_indicator.visible = player != null
	if player == null:
		return
	_dash_full = _dash_icon_frame(0)
	_dash_empty = _dash_icon_frame(1)
	for i: int in player.max_dash_charges:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(DASH_ICON_SIZE, DASH_ICON_SIZE)
		icon.pivot_offset = Vector2(DASH_ICON_SIZE, DASH_ICON_SIZE) * 0.5
		_dash_indicator.add_child(icon)
		_dash_icons.append(icon)
	player.dash_charges_changed.connect(_update_dash_icons)
	player.dash_refilled.connect(_on_dash_refilled)
	_update_dash_icons(player.dash_charges)


## dash_icon.png holds two frames side by side: full, then empty.
func _dash_icon_frame(index: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = DASH_ICON
	texture.region = Rect2(index * DASH_ICON_SIZE, 0, DASH_ICON_SIZE, DASH_ICON_SIZE)
	return texture


func _update_dash_icons(charges: int) -> void:
	for i: int in _dash_icons.size():
		_dash_icons[i].texture = _dash_full if is_dash_icon_full(i, charges) else _dash_empty


func _on_dash_refilled() -> void:
	for icon: TextureRect in _dash_icons:
		icon.scale = Vector2(1.6, 1.6)
		icon.modulate = Color(2.0, 2.0, 2.0)  # bright flash that fades back to normal
		var tween: Tween = create_tween().set_parallel()
		tween.tween_property(icon, ^"scale", Vector2.ONE, REFILL_POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(icon, ^"modulate", Color.WHITE, REFILL_POP_TIME)
