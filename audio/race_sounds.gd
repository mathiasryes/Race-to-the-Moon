class_name RaceSounds
extends Node
## Connects player and race events to the Sound autoload. Add one to a level and point it at the
## player and the race director. Gameplay code only emits signals; all sound choices live here.

@export var player: Player
@export var director: RaceDirector

var _in_danger: bool = false


func _ready() -> void:
	Sound.stop_all()  # a restart shouldn't keep the previous run's loops going
	if player:
		player.jumped.connect(Sound.play.bind(&"jump"))
		player.landed.connect(Sound.play.bind(&"land"))
		player.double_jumped.connect(Sound.play.bind(&"double_jump"))
		player.dashed.connect(Sound.play.bind(&"dash"))
		player.dash_refilled.connect(Sound.play.bind(&"treat"))
	if director:
		director.countdown_changed.connect(_on_countdown_changed)
		director.lifted_off.connect(_on_lifted_off)
		director.danger_changed.connect(_on_danger_changed)
		director.race_won.connect(_on_race_over.bind(&"win"))
		director.race_lost.connect(_on_race_over.bind(&"lose"))
	Sound.play_music(&"race")


func _exit_tree() -> void:
	Sound.release_all()  # level closed or restarted: nothing from this race should keep playing


func _on_countdown_changed(seconds_left: int) -> void:
	if seconds_left > 0:
		Sound.play(&"countdown_beep")


func _on_lifted_off() -> void:
	Sound.play(&"liftoff")
	Sound.set_loop(&"rocket_engine", true)


func _on_danger_changed(amount: float) -> void:
	var in_danger: bool = amount > 0.0
	if in_danger != _in_danger:
		_in_danger = in_danger
		if in_danger:
			Sound.play(&"warning")
		Sound.set_loop(&"warning_alarm", in_danger)
	Sound.set_loop_amount(&"warning_alarm", amount)


func _on_race_over(jingle: StringName) -> void:
	Sound.stop_all()
	Sound.play(jingle)
