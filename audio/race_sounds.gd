class_name RaceSounds
extends Node
## Connects player and race events to the Sound autoload. Add one to a level and point it at the
## player and the race director. Gameplay code only emits signals; all sound choices live here.

@export var player: Player
@export var director: RaceDirector
## Used for the level height, to switch music when the player leaves the atmosphere. Optional.
@export var generator: LevelGenerator

@export_group("Music")
## Fraction of the climb where "above_atmosphere" music takes over (0.6 = where space starts).
@export_range(0.0, 1.0) var space_music_from: float = 0.6
## Climbing back down this far below the switch point goes back to the lower track (avoids flip-flopping).
@export_range(0.0, 0.2) var music_switch_margin: float = 0.03
## Crossfade length when the track changes, in seconds.
@export var music_fade_time: float = 2.0

@export_group("Sound effects")
## Falls longer than this (pixels) play the heavy landing instead of the surface sound.
@export var heavy_landing_height: float = 160.0
## Delay after liftoff before the dog barks at the departing rocket.
@export var woof_delay: float = 0.6

var _in_danger: bool = false
var _race_over: bool = false


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
	Sound.play_music(&"below_atmosphere")


func _physics_process(_delta: float) -> void:
	if _race_over or player == null or generator == null:
		return
	var climbed: float = -player.global_position.y / generator.level_height
	var track: StringName = music_for(climbed, Sound.current_music(), space_music_from, music_switch_margin)
	Sound.play_music(track, music_fade_time)


## Which music fits a climb fraction (0 = ground, 1 = moon). Switches up at `space_from` but only back down
## once below `space_from - margin`, so hovering around the boundary doesn't flip-flop the music.
static func music_for(climbed: float, current: StringName, space_from: float, margin: float) -> StringName:
	if climbed >= space_from:
		return &"above_atmosphere"
	if current == &"above_atmosphere" and climbed > space_from - margin:
		return &"above_atmosphere"
	return &"below_atmosphere"


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
	_race_over = true
	Sound.stop_all()
	Sound.play(jingle)
