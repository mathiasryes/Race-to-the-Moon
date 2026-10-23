extends Node
## Global sound player (autoload "Sound"). Plays sounds by name if a matching file exists, so audio can be
## added by dropping files into the folders below with the right names. No code changes needed:
##   assets/audio/sfx/<name>.wav or .ogg     one-shot effects (names in SFX)
##   assets/audio/loops/<name>.ogg or .wav   looping sounds (names in LOOPS)
##   assets/audio/music/<name>.ogg or .wav   music, loops automatically (names in MUSIC)
## Missing files are skipped silently, so the game runs fine with no audio at all.
## Volumes are balanced on the "Music" and "SFX" buses (Audio tab at the bottom of the Godot editor).

const SFX: Dictionary = {
	&"jump": "player leaves the ground",
	&"land_grass": "player lands on grass (also the fallback for unknown surfaces)",
	&"land_metal": "player lands on a launch pad, girder or solar panel",
	&"land_cloud": "player lands on a cloud",
	&"land_rock": "player lands on an asteroid or moon rock",
	&"land_heavy": "player lands after a long fall (more than a full double jump), any surface",
	&"double_jump": "player jumps again in mid-air",
	&"dash": "player dashes (any of 8 directions)",
	&"woof": "the dog barks as the rocket lifts off without it",
	&"treat": "player picks up a dog treat (dash refilled)",
	&"countdown_beep": "each second of the countdown (3, 2, 1)",
	&"liftoff": "the rocket ignites",
	&"warning": "the rocket starts getting away (once, when the warning appears)",
	&"win": "player reaches the moon first",
	&"lose": "the rocket leaves the screen",
}
const LOOPS: Dictionary = {
	&"rocket_engine": "rocket engine while it flies",
	&"warning_alarm": "while the warning shows; louder as the rocket gets closer to escaping",
}
const MUSIC: Dictionary = {
	&"race": "music during the climb",
}

const AUDIO_DIR := "res://assets/audio"
const EXTENSIONS: Array[String] = ["ogg", "wav"]
const VOICES: int = 8
## Random pitch change for these effects so repeats don't sound identical.
const PITCH_VARIATION: Dictionary = {
	&"jump": 0.06, &"double_jump": 0.04, &"dash": 0.05,
	&"land_grass": 0.08, &"land_metal": 0.08, &"land_cloud": 0.08, &"land_rock": 0.08, &"land_heavy": 0.05,
}
## Volume range for loops whose loudness follows a 0..1 amount (see set_loop_amount).
const QUIET_DB: float = -18.0

## The most recent sound names played (newest last). Useful for tests and debugging.
var history: Array[StringName] = []

## Headless runs (tests, CI) have no audio device: track what would play, but don't start any audio.
var _silent: bool = DisplayServer.get_name() == "headless"
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _loops: Dictionary = {}  # StringName -> AudioStreamPlayer
var _active_loops: Dictionary = {}  # StringName -> true while the loop is on
var _music: AudioStreamPlayer
var _music_name: StringName = &""
var _streams: Dictionary = {}  # cache: "folder/name" -> AudioStream (or null when there's no file)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep playing on the paused win/lose screen
	for i: int in VOICES:
		_voices.append(_new_player(&"SFX"))
	_music = _new_player(&"Music")


func _exit_tree() -> void:
	release_all()


## Stops every sound and drops all loaded audio. Scripts that quit right after should wait a couple of
## frames first, so the audio engine can let go of the sounds (otherwise Godot reports them as leaks).
func release_all() -> void:
	_active_loops.clear()
	for player: AudioStreamPlayer in _voices + _loops.values() + [_music]:
		player.stop()
		player.stream = null
	_streams.clear()


## Plays a one-shot effect. Returns false if the name has no audio file yet.
func play(sound: StringName) -> bool:
	_check_known(sound, SFX)
	_remember(sound)
	var stream: AudioStream = _stream("sfx", sound)
	if stream == null:
		return false
	if _silent:
		return true
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream
	var variation: float = PITCH_VARIATION.get(sound, 0.0)
	voice.pitch_scale = 1.0 + randf_range(-variation, variation)
	voice.play()
	return true


## Starts or stops a looping sound.
func set_loop(sound: StringName, on: bool) -> void:
	_check_known(sound, LOOPS)
	if on:
		if is_looping(sound):
			return
		_remember(sound)
		var stream: AudioStream = _stream("loops", sound)
		if stream == null:
			return
		_active_loops[sound] = true
		if _silent:
			return
		var player: AudioStreamPlayer = _loops.get(sound, null)
		if player == null:
			player = _new_player(&"SFX")
			_loops[sound] = player
		player.stream = _looping(stream)
		player.volume_db = 0.0
		player.play()
	else:
		_active_loops.erase(sound)
		if _loops.has(sound):
			(_loops[sound] as AudioStreamPlayer).stop()


## Loudness of a running loop from 0 (quiet) to 1 (full volume).
func set_loop_amount(sound: StringName, amount: float) -> void:
	if _loops.has(sound):
		(_loops[sound] as AudioStreamPlayer).volume_db = lerpf(QUIET_DB, 0.0, clampf(amount, 0.0, 1.0))


func is_looping(sound: StringName) -> bool:
	return _active_loops.has(sound)


## Plays a music track (keeps going if it's already playing). An empty name stops the music.
func play_music(track: StringName) -> void:
	if track == _music_name and _music.playing:
		return
	_music.stop()
	_music_name = track
	if track == &"":
		return
	_check_known(track, MUSIC)
	_remember(track)
	var stream: AudioStream = _stream("music", track)
	if stream != null and not _silent:
		_music.stream = _looping(stream)
		_music.play()


## Stops loops and music, e.g. when the race ends or the level restarts.
func stop_all() -> void:
	_active_loops.clear()
	for player: AudioStreamPlayer in _loops.values():
		player.stop()
	play_music(&"")


## File path for a sound, or "" if no file exists yet. `folder` is "sfx", "loops" or "music".
static func path_for(folder: String, sound: StringName) -> String:
	for extension: String in EXTENSIONS:
		var path: String = "%s/%s/%s.%s" % [AUDIO_DIR, folder, sound, extension]
		if ResourceLoader.exists(path):
			return path
	return ""


static func is_known(sound: StringName) -> bool:
	return SFX.has(sound) or LOOPS.has(sound) or MUSIC.has(sound)


func _stream(folder: String, sound: StringName) -> AudioStream:
	var key: String = folder + "/" + sound
	if not _streams.has(key):
		var path: String = path_for(folder, sound)
		_streams[key] = load(path) if path != "" else null
	return _streams[key]


## Makes music and loops repeat, whichever file format they were given in.
func _looping(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	return stream


func _new_player(bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


func _remember(sound: StringName) -> void:
	history.append(sound)
	if history.size() > 64:
		history.pop_front()


func _check_known(sound: StringName, names: Dictionary) -> void:
	if not names.has(sound):
		push_warning("Sound: unknown name '%s'. Add it to the lists in autoload/sound.gd." % sound)
