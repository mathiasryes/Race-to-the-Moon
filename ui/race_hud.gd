class_name RaceHud
extends CanvasLayer
## Countdown, "rocket is getting away" warning and the win/lose screen. Keeps running while the game is paused
## so the player can restart.

const LOSE_TEXT := "The rocket left without you!"
const WIN_TEXT := "You beat the rocket to the moon!"

@export var director: RaceDirector

var _blink_time: float = 0.0
var _danger: float = 0.0

@onready var _center_label: Label = $CenterLabel
@onready var _warning: Label = $Warning
@onready var _end_screen: Control = $EndScreen
@onready var _end_title: Label = $EndScreen/Title


func _ready() -> void:
	_warning.hide()
	_end_screen.hide()
	director.countdown_changed.connect(_on_countdown_changed)
	director.lifted_off.connect(_on_lifted_off)
	director.danger_changed.connect(_on_danger_changed)
	director.race_lost.connect(_show_end.bind(LOSE_TEXT))
	director.race_won.connect(_show_end.bind(WIN_TEXT))


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
