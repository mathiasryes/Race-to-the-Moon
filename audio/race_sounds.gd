class_name RaceSounds
extends Node
## Connects player and race events to the Sound autoload. Add one to a level and point it at the
## player and the race director. Gameplay code only emits signals; all sound choices live here.

@export var player: Player
@export var director: RaceDirector
## Falls longer than this (pixels) play the heavy landing instead of the surface sound.
@export var heavy_landing_height: float = 160.0
## Delay after liftoff before the dog barks at the departing rocket.
@export var woof_delay: float = 0.6

var _in_danger: bool = false


func _ready() -> void:
	Sound.stop_all()  # a restart shouldn't keep the previous run's loops going
	if player:
		player.jumped.connect(Sound.play.bind(&"jump"))
		player.landed.connect(_on_landed)
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


## Landing sound for a surface (a Platform.Zone, or -1 if unknown) after falling `fall_height` pixels.
static func landing_sound(zone: int, fall_height: float, heavy_height: float) -> StringName:
	if fall_height > heavy_height:
		return &"land_heavy"
	match zone:
		Platform.Zone.LAUNCHPAD, Platform.Zone.GIRDER, Platform.Zone.SOLAR:
			return &"land_metal"
		Platform.Zone.CLOUD:
			return &"land_cloud"
		Platform.Zone.ASTEROID, Platform.Zone.MOON:
			return &"land_rock"
	return &"land_grass"


func _on_landed() -> void:
	Sound.play(landing_sound(player.floor_zone(), player.last_fall_height, heavy_landing_height))


func _on_lifted_off() -> void:
	Sound.play(&"liftoff")
	Sound.set_loop(&"rocket_engine", true)
	get_tree().create_timer(woof_delay).timeout.connect(Sound.play.bind(&"woof"))


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
